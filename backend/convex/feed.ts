import { mutation, query } from "./_generated/server";
import { v } from "convex/values";

import { assertChildPolicy } from "./childGuard";
import { deleteStored } from "./files";
import { MAX_GUESSES, SLOTS, answerFor, pegsForSlots, score } from "./puzzle";
import { lensFor } from "./visibility";

/**
 * The Feed board — "TODAY".
 *
 * Everything here is scoped to one local calendar day. A moment is visible to
 * friends for 24 hours and then drops off their boards; the row and its blob
 * survive forever in the author's own archive.
 *
 * ## The tag collapse
 *
 * A highlight and a point are the same row. `tag` absent = a highlight; `tag`
 * set = it also scores on the standings board. Everything below therefore
 * serves both features, and the standings board needs no writer of its own.
 *
 * ## Two rules this file must never break
 *
 * 1. **`board` is subscribed, so it must not read a `users` document.** Doing
 *    so joins the invalidation set of every presence heartbeat (one per friend
 *    per 90s) and the board re-renders forever. Author name and avatar are
 *    denormalized onto the moment at write time for exactly this reason.
 * 2. **Identity is the `userId` argument.** There is no `ctx.auth` anywhere in
 *    this deployment. Every function re-derives permission from the argument,
 *    and nothing returns a field the caller could not already see.
 */

/** How long a moment stays on friends' boards. */
const VISIBLE_MS = 24 * 60 * 60 * 1000;

/** The tags a moment may carry. Mirrored in lib/models/moment.dart. */
const TAGS = new Set(["fate", "jinx", "luck", "calledIt", "npc"]);

/**
 * Per-day, per-tag cap on self-awarded points.
 *
 * Five, not twenty. Points are self-reported and unverifiable — that is the
 * joke, and it works between friends — but the cap is what keeps a number
 * meaning something. Twenty was high enough that nobody would ever hit it,
 * which makes it not a cap at all; five is low enough that the fifth JINX of
 * the day is a real decision about whether it earned the slot.
 *
 * Enforced server-side because a client-side cap is a suggestion. Untagged
 * highlights are NOT capped: there is no scoreboard to distort, and rate
 * limiting someone's photos would be hostile.
 */
const MAX_TAGGED_PER_DAY = 5;

/** Longest caption we will store. Matches the composer's own counter. */
const MAX_CAPTION = 280;

/**
 * How many friends the board will fan out over.
 *
 * The board issues one indexed read per friend. That is fine at this app's
 * scale (a private friends app; friend counts are tens) and far cheaper than a
 * global scan, but it must not be unbounded — a subscribed query that grows
 * without limit is how a small box falls over. Beyond this the board shows the
 * most recently added friends; nothing breaks, it just stops growing.
 */
const MAX_FANOUT = 200;

/**
 * A moment as any viewer may see it.
 *
 * Hand-built rather than spread, following friends.ts: the literal shape of
 * this object IS the access-control boundary, and a `...moment` would ship
 * whatever field someone adds to the table next.
 */
function momentView(
  m: any,
  opts: {
    reactions: any[];
    seen: boolean;
    mine: boolean;
    viewerId: any;
    /**
     * Whether the viewer may see the author's face on this row.
     *
     * `authorAvatarStorageId` is denormalized onto the moment at post time, so
     * it is NOT covered by the author's `feed`/`points` settings — those decide
     * whether the row appears at all, and the avatar control decides whose face
     * rides along with it. Resolved once per author by the caller (which
     * already holds the users row) rather than per row.
     */
    authorAvatarVisible: boolean;
  }
) {
  // An ARRAY of {emoji, count}, never an object keyed by the emoji.
  //
  // Convex field names must be non-control ASCII, so `counts["❤️"] = 1` builds
  // fine, survives the whole handler, and then throws in `convexToJson` on the
  // way out — taking the entire board with it. One reaction anywhere in the
  // payload emptied highlights, points, activity and the puzzle at once, and
  // because the failure is in serialization rather than the query, nothing in
  // the handler could catch it.
  //
  // Emoji as a VALUE is legal; only as a KEY is it rejected. This is also the
  // house pattern already — see messages.ts, which ships raw `reactions` rows
  // as an array and has never hit this.
  const tally = new Map<string, number>();
  for (const r of opts.reactions) {
    tally.set(r.emoji, (tally.get(r.emoji) ?? 0) + 1);
  }
  const counts = Array.from(tally, ([emoji, count]) => ({ emoji, count }));
  return {
    _id: m._id,
    userId: m.userId,
    dayKey: m.dayKey,
    tag: m.tag,
    caption: m.caption,
    mediaStorageId: m.mediaStorageId,
    posterStorageId: m.posterStorageId,
    mediaKind: m.mediaKind,
    createdAt: m.createdAt,
    expiresAt: m.expiresAt,
    authorName: m.authorName,
    authorUsername: m.authorUsername,
    authorAvatarStorageId: opts.authorAvatarVisible
      ? m.authorAvatarStorageId
      : undefined,
    reactionCounts: counts,
    // Who's behind each count. A flat array of (emoji, name) pairs, not an
    // object keyed by emoji — same reason `reactionCounts` is an array above.
    // Rows written before `userName` existed are filtered out rather than
    // shown with a blank name; they age out the first time that person
    // reacts to anything again.
    reactors: opts.reactions
      .filter((r: any) => typeof r.userName === "string" && r.userName)
      .map((r: any) => ({
        emoji: r.emoji,
        userId: r.userId,
        name: r.userName,
      })),
    // Resolved here rather than patched onto the result by each caller. Both
    // call sites used to do that themselves, which is one caller away from a
    // surface that silently reports nobody's own reactions.
    myReactions: opts.reactions
      .filter((r: any) => r.userId === opts.viewerId)
      .map((r: any) => r.emoji),
    seen: opts.seen,
    mine: opts.mine,
  };
}

/**
 * Resolves one user's Feed visibility, applying the defaults.
 *
 * The whole `users.visibility` object fails closed — an absent key means
 * "nobody" — and that is right for avatar and presence. The Feed inverts it
 * for two of its three keys, because a board nobody opted into is a dead
 * board: `feed` and `puzzle` default to sharing with friends, `pointsPast`
 * defaults to today-only. Spelled out once, here, so no caller re-derives it.
 */
function visibilityOf(user: any) {
  const vis = user?.visibility ?? {};
  return {
    feed: vis.feed !== "nobody",
    points: vis.points !== "nobody",
    puzzle: vis.puzzle !== "nobody",
    pointsPast: vis.pointsPast === "friends",
  };
}

/**
 * Whether [viewerId] may see [moment], honouring its author's settings.
 *
 * Centralised because "every surface respects the setting" is not something
 * three separate hand-written checks can promise — one of them will drift. Any
 * new read path calls THIS, and the only correct way to skip it is to be the
 * author.
 *
 * Note the split: a tagged row is a POINT and obeys `points`; an untagged row
 * is a HIGHLIGHT and obeys `feed`. They are separate settings because sharing
 * your running joke but not your camera roll is a reasonable position.
 */
async function canSeeMoment(ctx: any, viewerId: any, moment: any) {
  if (moment.userId === viewerId) return true;
  const link = await ctx.db
    .query("friendships")
    .withIndex("by_pair", (q: any) =>
      q.eq("userId", viewerId).eq("friendId", moment.userId)
    )
    .first();
  if (!link || link.status !== "accepted") return false;
  const author = await ctx.db.get(moment.userId);
  if (!author) return false;
  const vis = visibilityOf(author);
  return moment.tag === undefined ? vis.feed : vis.points;
}

/** The ids of everyone [userId] has an accepted friendship with. */
async function friendIdsOf(ctx: any, userId: any): Promise<any[]> {
  const rows = await ctx.db
    .query("friendships")
    .withIndex("by_user", (q: any) => q.eq("userId", userId))
    .collect();
  // An accepted friendship is always TWO directed rows, so scanning by_user
  // alone is complete. Pending rows are one-directional and must not appear.
  return rows
    .filter((f: any) => f.status === "accepted")
    .slice(0, MAX_FANOUT)
    .map((f: any) => f.friendId);
}

/**
 * Everything the board renders for one day, in one payload.
 *
 * ONE subscription, deliberately. This app runs ~15 live queries app-wide and
 * the codebase repeatedly refuses to add more; four pillars modelled as four
 * subscriptions would be a 25% increase for one screen. The activity tail
 * pages separately through `archive`, which is a one-shot read.
 */
export const board = query({
  args: {
    userId: v.id("users"),
    // The viewer's local day. The server cannot derive this — it has no idea
    // what zone the phone is in, and guessing UTC puts everyone west of
    // Greenwich on yesterday's board all evening.
    dayKey: v.string(),
  },
  handler: async (ctx, { userId, dayKey }) => {
    const now = Date.now();
    const friendIds = await friendIdsOf(ctx, userId);
    const lens = await lensFor(ctx, userId);

    // Blocking: `blockUser` deletes both friendship rows, so a blocked person
    // is already absent from the fan-out above and their content cannot reach
    // this board. Nothing further to filter — but that is a consequence of the
    // friendship model, not an accident, so it is written down here.
    const authorIds = [userId, ...friendIds];

    const out: any[] = [];
    for (const authorId of authorIds) {
      const mine = authorId === userId;

      // Highlights and points are SEPARATE surfaces with separate settings, so
      // this resolves both and filters per row below rather than skipping the
      // author wholesale. Someone who shares their points but not their photos
      // is a real and reasonable position, and the old single check made it
      // unrepresentable.
      let allowHighlights = true;
      let allowPoints = true;
      let authorAvatarVisible = true;
      if (!mine) {
        // One users read per FRIEND (not per moment). This is the one place
        // the board touches a users row, and it is the reason `board` re-fires
        // on a friend's presence heartbeat. Accepted as the cost of the
        // settings being real; denormalizing a privacy flag onto every moment
        // would mean a change to it silently not applying to older rows.
        const author = await ctx.db.get(authorId);
        if (!author) continue;
        const vis = visibilityOf(author);
        allowHighlights = vis.feed;
        allowPoints = vis.points;
        authorAvatarVisible = lens.canSee(author, "avatar");
        if (!allowHighlights && !allowPoints) continue;
      }

      const rows = await ctx.db
        .query("moments")
        .withIndex("by_user_day", (q: any) =>
          q.eq("userId", authorId).eq("dayKey", dayKey)
        )
        .collect();

      for (const m of rows) {
        // Your own expired moments stay on your board for the rest of your
        // local day — you should be able to see what you posted this morning
        // even once friends can't.
        if (!mine && m.expiresAt <= now) continue;
        // A tagged row is a POINT, an untagged one is a HIGHLIGHT, and each
        // obeys its own setting.
        if (!mine && !(m.tag === undefined ? allowHighlights : allowPoints)) {
          continue;
        }

        const reactions = await ctx.db
          .query("momentReactions")
          .withIndex("by_moment", (q: any) => q.eq("momentId", m._id))
          .collect();

        const seenRow = mine
          ? null
          : await ctx.db
              .query("momentViews")
              .withIndex("by_moment_viewer", (q: any) =>
                q.eq("momentId", m._id).eq("viewerId", userId)
              )
              .first();

        out.push(
          momentView(m, {
            reactions,
            seen: mine || seenRow !== null,
            mine,
            viewerId: userId,
            authorAvatarVisible,
          })
        );
      }
    }

    out.sort((a, b) => b.createdAt - a.createdAt);

    // ── The daily puzzle ────────────────────────────────────────────────────
    // Carried in THIS payload rather than a query of its own. Four pillars
    // modelled as four subscriptions would be a 25% increase in the app's
    // whole live-query budget for one screen; folding the puzzle in also means
    // a friend's score lands on your board the instant they finish, which is
    // most of the point of having a scoreboard at all.
    const answer = answerFor(dayKey);
    const scores: any[] = [];
    let mine: any = null;

    for (const playerId of authorIds) {
      const isMe = playerId === userId;
      let playerName = "";
      if (!isMe) {
        const player = await ctx.db.get(playerId);
        if (!player) continue;
        if (!visibilityOf(player).puzzle) continue;
        // The scoreboard needs a name, and this row is already loaded for the
        // visibility check — so it costs nothing here, where a separate lookup
        // per score would be another users read inside a subscribed query.
        playerName = player.name ?? player.username;
      }
      const row = await ctx.db
        .query("puzzleResults")
        .withIndex("by_user_day", (q: any) =>
          q.eq("userId", playerId).eq("dayKey", dayKey)
        )
        .first();
      if (!row) continue;

      const finished = row.solved || row.guesses.length >= MAX_GUESSES;
      if (isMe) {
        mine = {
          guesses: row.guesses,
          // Ordered per-slot status, unlike `scores[].feedback` below — this
          // is the player's own attempt, so revealing which slot is right
          // leaks nothing to anyone who hasn't played.
          feedback: row.guesses.map((g: number[]) => ({
            ...score(g, answer),
            slots: pegsForSlots(g, answer),
          })),
          solved: row.solved,
          done: finished,
          // Same rule as the guess mutation: the code is revealed only once
          // the player can no longer act on it.
          answer: finished && !row.solved ? answer : undefined,
        };
      }
      // A friend's IN-PROGRESS attempt is deliberately not exposed — not the
      // guess count, not the feedback. Knowing someone is on their fifth try
      // leaks how hard today is, and watching a live counter turns a quiet
      // daily puzzle into a race.
      if (!finished) continue;
      scores.push({
        userId: playerId,
        name: playerName,
        solved: row.solved,
        guessCount: row.guesses.length,
        finishedAt: row.finishedAt ?? row.updatedAt,
        // The emoji grid is derived from feedback, so it ships as counts and
        // the client renders it — no second encoding to keep in step.
        feedback: row.guesses.map((g: number[]) => score(g, answer)),
      });
    }

    // Solved first, then fewest guesses, then earliest finish. Ties broken by
    // id so equal results hold a stable order rather than reshuffling on every
    // board render — the leaderboard animates rows by identity.
    scores.sort((a, b) => {
      if (a.solved !== b.solved) return a.solved ? -1 : 1;
      if (a.guessCount !== b.guessCount) return a.guessCount - b.guessCount;
      if (a.finishedAt !== b.finishedAt) return a.finishedAt - b.finishedAt;
      return a.userId < b.userId ? -1 : 1;
    });

    return {
      moments: out,
      serverNow: now,
      puzzle: { slots: SLOTS, maxGuesses: MAX_GUESSES, mine, scores },
    };
  },
});

/**
 * Publishes a moment.
 *
 * Takes `dayKey` from the client for the timezone reason above, but derives
 * `createdAt`/`expiresAt` from the server clock so a wrong device clock cannot
 * pin something to the top of a friend's board indefinitely.
 */
export const post = mutation({
  args: {
    userId: v.id("users"),
    dayKey: v.string(),
    tag: v.optional(v.string()),
    caption: v.optional(v.string()),
    mediaStorageId: v.optional(v.id("_storage")),
    posterStorageId: v.optional(v.id("_storage")),
    mediaKind: v.optional(v.string()),
  },
  handler: async (
    ctx,
    { userId, dayKey, tag, caption, mediaStorageId, posterStorageId, mediaKind }
  ) => {
    const user = await ctx.db.get(userId);
    if (!user) throw new Error("USER_NOT_FOUND");

    if (tag !== undefined && !TAGS.has(tag)) throw new Error("UNKNOWN_TAG");

    // A moment has to be *something*. Media-less tagged points are legitimate
    // ("washed the car, it rained" needs no photo) but an empty row is not.
    const text = caption?.trim();
    if (!mediaStorageId && !text) throw new Error("EMPTY_MOMENT");
    if (text && text.length > MAX_CAPTION) throw new Error("CAPTION_TOO_LONG");

    // Parental controls. Only the media path is gated: a child writing a
    // one-line point to their own family board is not what mediaEnabled is
    // defending against, and gating it would be surprising. Server-side first
    // — the client gate is cosmetic, as FamilyService's own doc says.
    if (mediaStorageId) await assertChildPolicy(ctx, userId, "mediaEnabled");

    if (tag !== undefined) {
      const today = await ctx.db
        .query("moments")
        .withIndex("by_user_tag_day", (q: any) =>
          q.eq("userId", userId).eq("tag", tag).eq("dayKey", dayKey)
        )
        .collect();
      if (today.length >= MAX_TAGGED_PER_DAY) throw new Error("DAILY_CAP_REACHED");
    }

    const now = Date.now();
    return await ctx.db.insert("moments", {
      userId,
      dayKey,
      // Written only when set — an untagged row must have NO tag field at all,
      // or it lands inside the scanned prefix of by_user_tag_day. See schema.
      ...(tag !== undefined ? { tag } : {}),
      ...(text ? { caption: text } : {}),
      ...(mediaStorageId ? { mediaStorageId } : {}),
      ...(posterStorageId ? { posterStorageId } : {}),
      ...(mediaKind ? { mediaKind } : {}),
      createdAt: now,
      expiresAt: now + VISIBLE_MS,
      authorName: user.name ?? user.username,
      authorUsername: user.username,
      ...(user.avatarStorageId
        ? { authorAvatarStorageId: user.avatarStorageId }
        : {}),
    });
  },
});

/**
 * Removes a moment and everything hanging off it.
 *
 * The blob goes too — this is the author asking for it to be gone, which is a
 * different act from a moment merely expiring off friends' boards. Released
 * through `deleteStored` (never `ctx.storage.delete`, which throws on an
 * already-deleted blob and would abort the rest of this teardown), and only
 * when no other moment still points at the same bytes.
 */
export const remove = mutation({
  args: { userId: v.id("users"), momentId: v.id("moments") },
  handler: async (ctx, { userId, momentId }) => {
    const m = await ctx.db.get(momentId);
    if (!m) return;
    if (m.userId !== userId) throw new Error("NOT_YOUR_MOMENT");

    for (const r of await ctx.db
      .query("momentReactions")
      .withIndex("by_moment", (q: any) => q.eq("momentId", momentId))
      .collect()) {
      await ctx.db.delete(r._id);
    }
    for (const vw of await ctx.db
      .query("momentViews")
      .withIndex("by_moment", (q: any) => q.eq("momentId", momentId))
      .collect()) {
      await ctx.db.delete(vw._id);
    }
    await ctx.db.delete(momentId);

    for (const id of [m.mediaStorageId, m.posterStorageId]) {
      if (!id) continue;
      const others = await ctx.db
        .query("moments")
        .withIndex("by_media", (q: any) => q.eq("mediaStorageId", id))
        .first();
      if (!others) await deleteStored(ctx, id);
    }
  },
});

/**
 * Marks moments seen, so their unseen ring clears.
 *
 * Batched because the viewer swipes through a rail and firing one mutation per
 * card would be a write storm on a screen the user is passing through.
 * Idempotent — a re-view is not an error and must not insert a second row.
 */
export const markSeen = mutation({
  args: { userId: v.id("users"), momentIds: v.array(v.id("moments")) },
  handler: async (ctx, { userId, momentIds }) => {
    const now = Date.now();
    for (const momentId of momentIds) {
      const existing = await ctx.db
        .query("momentViews")
        .withIndex("by_moment_viewer", (q: any) =>
          q.eq("momentId", momentId).eq("viewerId", userId)
        )
        .first();
      if (existing) continue;
      const m = await ctx.db.get(momentId);
      // Silently skip a moment that vanished mid-swipe rather than throwing —
      // the viewer did nothing wrong and there is no useful client recovery.
      if (!m || m.userId === userId) continue;
      // Also skip anything this viewer is not entitled to. Writing a view row
      // for a hidden moment would leak nothing directly, but it would put the
      // viewer's id on a stranger's content and survive a later privacy change.
      if (!(await canSeeMoment(ctx, userId, m))) continue;
      await ctx.db.insert("momentViews", { momentId, viewerId: userId, viewedAt: now });
    }
  },
});

/** Adds a reaction. One row per (moment, user, emoji); re-adding is a no-op. */
export const react = mutation({
  args: {
    userId: v.id("users"),
    momentId: v.id("moments"),
    emoji: v.string(),
  },
  handler: async (ctx, { userId, momentId, emoji }) => {
    const m = await ctx.db.get(momentId);
    if (!m) throw new Error("MOMENT_NOT_FOUND");

    // Friendship alone is NOT enough: an author who shares highlights but not
    // points has friends who must not be able to react to a point. Re-checked
    // server-side rather than trusted from the board payload — a client can
    // call this with any moment id, and the board is not an auth token.
    if (!(await canSeeMoment(ctx, userId, m))) throw new Error("NOT_A_FRIEND");

    const existing = await ctx.db
      .query("momentReactions")
      .withIndex("by_moment_user", (q: any) =>
        q.eq("momentId", momentId).eq("userId", userId)
      )
      .filter((q: any) => q.eq(q.field("emoji"), emoji))
      .first();
    if (existing) return existing._id;

    // Safe to read here — this is a mutation, not the subscribed `board`
    // query, so it doesn't join anyone's invalidation set.
    const reactor = await ctx.db.get(userId);
    const userName = reactor?.name ?? reactor?.username;

    return await ctx.db.insert("momentReactions", {
      momentId,
      userId,
      emoji,
      createdAt: Date.now(),
      userName,
    });
  },
});

/** Removes one of your own reactions. Absent is not an error. */
export const unreact = mutation({
  args: {
    userId: v.id("users"),
    momentId: v.id("moments"),
    emoji: v.string(),
  },
  handler: async (ctx, { userId, momentId, emoji }) => {
    const existing = await ctx.db
      .query("momentReactions")
      .withIndex("by_moment_user", (q: any) =>
        q.eq("momentId", momentId).eq("userId", userId)
      )
      .filter((q: any) => q.eq(q.field("emoji"), emoji))
      .first();
    if (existing) await ctx.db.delete(existing._id);
  },
});

/**
 * A person's moment history, newest first.
 *
 * Timestamp-cursor pagination in the shape roomContent.ts uses — NOT
 * `.paginate()`, which appears only in migrations.ts here.
 *
 * Your own archive is complete and permanent. A friend's is gated on their
 * `pointsPast` setting, which defaults to off: today is shared, history is
 * opt-in. That default is the whole reason the setting exists, so a missing
 * value must never read as "yes".
 */
export const archive = query({
  args: {
    userId: v.id("users"),
    // Absent means "my own archive".
    ofUserId: v.optional(v.id("users")),
    beforeTimestamp: v.optional(v.number()),
    limit: v.optional(v.number()),
  },
  handler: async (ctx, { userId, ofUserId, beforeTimestamp, limit }) => {
    const target = ofUserId ?? userId;
    const mine = target === userId;

    if (!mine) {
      const link = await ctx.db
        .query("friendships")
        .withIndex("by_pair", (q: any) =>
          q.eq("userId", userId).eq("friendId", target)
        )
        .first();
      if (!link || link.status !== "accepted") throw new Error("NOT_A_FRIEND");

      const author = await ctx.db.get(target);
      if (!author) throw new Error("USER_NOT_FOUND");
      const vis = visibilityOf(author);
      // History is gated first — it is the setting that says "you may look
      // back at all". Then each row still has to clear its own type's setting,
      // below, so opening your past does not retroactively share a category
      // you keep private today.
      if (!vis.pointsPast) throw new Error("HISTORY_PRIVATE");
      if (!vis.feed && !vis.points) throw new Error("HISTORY_PRIVATE");
    }

    // Resolved once for the whole page rather than per row: `canSeeMoment`
    // would re-read the same users doc for every item, and inside a paged read
    // that is the difference between one lookup and sixty.
    let allowHighlights = true;
    let allowPoints = true;
    let authorAvatarVisible = true;
    if (!mine) {
      const author = await ctx.db.get(target);
      const vis = visibilityOf(author);
      allowHighlights = vis.feed;
      allowPoints = vis.points;
      const lens = await lensFor(ctx, userId);
      authorAvatarVisible = lens.canSee(author, "avatar");
    }

    const take = Math.min(limit ?? 30, 60);
    const rows = await ctx.db
      .query("moments")
      .withIndex("by_user_created", (q: any) => {
        const base = q.eq("userId", target);
        return beforeTimestamp === undefined
          ? base
          : base.lt("createdAt", beforeTimestamp);
      })
      .order("desc")
      .take(take + 1);

    const page = rows.slice(0, take);
    const items = [];
    for (const m of page) {
      if (!mine && !(m.tag === undefined ? allowHighlights : allowPoints)) {
        continue;
      }
      const reactions = await ctx.db
        .query("momentReactions")
        .withIndex("by_moment", (q: any) => q.eq("momentId", m._id))
        .collect();
      items.push(
        momentView(m, {
          reactions,
          seen: true,
          mine,
          viewerId: userId,
          authorAvatarVisible,
        })
      );
    }
    return { items, hasMore: rows.length > take };
  },
});
