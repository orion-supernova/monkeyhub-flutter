import { internalMutation } from "./_generated/server";
import { internal } from "./_generated/api";
import { mutation, query } from "./functions";
import { v } from "convex/values";
import type { Doc, Id } from "./_generated/dataModel";
import { GAMES } from "./games";
import { CODE_GAME, extendStreak, reactionsOn } from "./recordBook";
import { lensFor } from "./visibility";
import { byNameThenId, competitionPlaces, shownSeconds } from "./ranking";

/**
 * ALL-TIME RECORDS — everyone's best at every game, and the friends cheering it.
 *
 * `games.standings` and the puzzle scoreboard answer "who was fastest today".
 * This answers the question a daily cannot: who is fastest, full stop — your
 * best Queens ever against every friend's, the fewest guesses anybody has
 * cracked the code in — and it lets friends react to a record the way they
 * react to a highlight.
 *
 * ## Where the numbers come from
 *
 * `gameRecords`, one row per player per game, kept by `recordBook.noteSolve`
 * on every solve. See the table's own comment for why it is denormalized rather than
 * derived; [backfill] fills it for results that predate it.
 *
 * ## What a reaction is FOR
 *
 * A specific achievement, not a person: each reaction carries the
 * `achievedAt` of the record it cheered, and beating the record sweeps them.
 * Otherwise the 🔥 somebody left on a 2:10 would sit under the 1:31 that
 * replaced it, applauding a time nobody set.
 *
 * ## Privacy
 *
 * The same `visibility.puzzle` switch every daily scoreboard already obeys —
 * "my daily scores are not comparable" was said about all of them — and the
 * same accepted-friends audience, capped at the same 200.
 *
 * ## Query budget
 *
 * One-shot, like `games.standings`: a leaderboard of personal bests moves when
 * somebody beats one, and a subscription here would re-run on every friend's
 * presence heartbeat for the sake of an answer that changes a few times a week.
 */

/** Every game a record can be held in, in the order the hub lists them. */
export const RECORD_GAMES: readonly string[] = [CODE_GAME, ...GAMES];

/**
 * What a friend may react with. A fixed handful rather than the whole emoji
 * set: a record gets cheered, not discussed, and six choices keep the row a
 * one-tap decision. Mirrored by `kRecordReactions` in Dart.
 */
export const RECORD_REACTIONS = ["🔥", "👏", "🤯", "🐐", "😮", "😂"];

/** Rows per game the board returns — plus the viewer's own, wherever it is. */
const TOP = 25;

/** Reactor names returned per record, for the "who" line. */
const MAX_REACTORS = 12;

/** Same fan-out cap as `games.standings`, `feed.board` and `socialPush`. */
const MAX_FRIENDS = 200;

function isHidden(user: any): boolean {
  return (user?.visibility?.puzzle ?? "friends") === "nobody";
}

async function acceptedFriendIds(ctx: any, userId: Id<"users">) {
  const links = await ctx.db
    .query("friendships")
    .withIndex("by_user", (q: any) => q.eq("userId", userId))
    .collect();
  return links
    .filter((f: any) => f.status === "accepted")
    .slice(0, MAX_FRIENDS)
    .map((f: any) => f.friendId as Id<"users">);
}

async function isAcceptedFriend(
  ctx: any,
  userId: Id<"users">,
  otherId: Id<"users">,
): Promise<boolean> {
  const link = await ctx.db
    .query("friendships")
    .withIndex("by_pair", (q: any) =>
      q.eq("userId", userId).eq("friendId", otherId),
    )
    .first();
  return link?.status === "accepted";
}

/**
 * The all-time board: for every game, the viewer and their friends ranked by
 * their best, with the reactions on each.
 *
 * Every person who has a record appears in the ranking, but only the top
 * [TOP] per game — and the viewer's own row, wherever it falls — are returned,
 * each carrying its real 1-based rank. Reactions are read for those rows only.
 */
export const board = query({
  args: { userId: v.id("users") },
  handler: async (ctx, { userId }) => {
    type Person = { id: Id<"users">; name: string; isMe: boolean };
    // Faces by person, for the holders and the cheerers: through the lens the
    // Feed draws authors with, so a friend who keeps their picture from
    // friends is a monogram here too. Read off the user rows this loop
    // already fetches; the viewer's own costs one more.
    const lens = await lensFor(ctx, userId);
    const avatars: Record<string, string> = {};
    const me: any = await ctx.db.get(userId);
    // The viewer's REAL name, for ordering a tie; emitted as "" below.
    const people: Person[] = [
      { id: userId, name: me?.name ?? me?.username ?? "", isMe: true },
    ];
    if (me?.avatarStorageId) avatars[userId] = me.avatarStorageId;
    for (const friendId of await acceptedFriendIds(ctx, userId)) {
      const friend: any = await ctx.db.get(friendId);
      if (!friend || isHidden(friend)) continue;
      if (friend.avatarStorageId && lens.canSee(friend, "avatar")) {
        avatars[friendId] = friend.avatarStorageId;
      }
      people.push({
        id: friendId,
        name: friend.name ?? friend.username ?? "",
        isMe: false,
      });
    }

    const byGame = new Map<string, Array<{ r: Doc<"gameRecords">; p: Person }>>();
    for (const g of RECORD_GAMES) byGame.set(g, []);
    for (const p of people) {
      const records: Array<Doc<"gameRecords">> = await ctx.db
        .query("gameRecords")
        .withIndex("by_user_game", (q: any) => q.eq("userId", p.id))
        .collect();
      // A record holder with no clean solve yet has nothing to rank.
      for (const r of records) {
        if (r.best !== undefined) byGame.get(r.game)?.push({ r, p });
      }
    }

    const games: Record<string, any[]> = {};
    for (const g of RECORD_GAMES) {
      const rows = byGame.get(g)!;
      // Best first, compared at the precision the board prints: guesses for
      // the code, whole seconds for a timed game. Equal shown bests SHARE a
      // `rank` (1, 1, 2); who set it first, the milliseconds and the id are
      // hidden and decide nothing. Within a tie the order is by name for
      // stability; the client re-sorts tied names in its own locale.
      const shown = (x: { r: Doc<"gameRecords"> }) =>
        g === CODE_GAME ? x.r.best! : shownSeconds(x.r.best);
      rows.sort((a, b) => {
        const d = shown(a) - shown(b);
        if (d !== 0) return d;
        return byNameThenId(
          { name: a.p.name, userId: a.p.id },
          { name: b.p.name, userId: b.p.id },
        );
      });
      const places = competitionPlaces(rows, shown);
      const out: any[] = [];
      for (let i = 0; i < rows.length; i++) {
        const { r, p } = rows[i];
        // The cut is by PLACE, not position: a tie group that starts inside
        // the top [TOP] comes in whole rather than being split mid-tie.
        if (places[i] > TOP && !p.isMe) continue;
        const live = (await reactionsOn(ctx, r._id)).filter(
          (x: any) => x.achievedAt === r.achievedAt,
        );
        const counts = new Map<string, number>();
        for (const x of live) counts.set(x.emoji, (counts.get(x.emoji) ?? 0) + 1);
        out.push({
          recordId: r._id,
          userId: p.id,
          // Empty for the viewer, as on every other scoreboard: the client
          // says "you" in the viewer's own language.
          name: p.isMe ? "" : p.name,
          rank: places[i],
          best: r.best,
          dayKey: r.dayKey,
          achievedAt: r.achievedAt,
          solves: r.solves,
          // Arrays rather than an emoji-keyed object: an emoji is not a safe
          // Convex field name.
          reactions: [...counts.entries()]
            .sort((a, b) => b[1] - a[1])
            .map(([emoji, count]) => ({ emoji, count })),
          reactors: live
            .sort((a: any, b: any) => b.createdAt - a.createdAt)
            .slice(0, MAX_REACTORS)
            .map((x: any) => ({
              userId: x.userId,
              name: x.userName ?? "",
              emoji: x.emoji,
            })),
          mine: live.find((x: any) => x.userId === userId)?.emoji ?? null,
        });
      }
      games[g] = out;
    }
    return { games, palette: RECORD_REACTIONS, avatars };
  },
});

/**
 * Reacts to a friend's record, or changes the reaction already there.
 *
 * Refusals, each a way the board could otherwise be written to by somebody it
 * does not belong to: an emoji off the palette, your own record, a record
 * whose holder is not your accepted friend, and one whose holder keeps their
 * scores to themselves.
 */
export const react = mutation({
  args: {
    userId: v.id("users"),
    recordId: v.id("gameRecords"),
    emoji: v.string(),
  },
  handler: async (ctx, { userId, recordId, emoji }) => {
    if (!RECORD_REACTIONS.includes(emoji)) throw new Error("BAD_REACTION");
    const record = await ctx.db.get(recordId);
    if (!record) throw new Error("RECORD_NOT_FOUND");
    if (record.userId === userId) throw new Error("OWN_RECORD");
    if (!(await isAcceptedFriend(ctx, userId, record.userId))) {
      throw new Error("NOT_FRIENDS");
    }
    const holder = await ctx.db.get(record.userId);
    if (!holder || isHidden(holder)) throw new Error("RECORD_PRIVATE");

    const now = Date.now();
    const existing = await ctx.db
      .query("recordReactions")
      .withIndex("by_record_user", (q: any) =>
        q.eq("recordId", recordId).eq("userId", userId),
      )
      .first();
    if (existing) {
      if (existing.emoji === emoji && existing.achievedAt === record.achievedAt) {
        return null;
      }
      await ctx.db.patch(existing._id, {
        emoji,
        achievedAt: record.achievedAt,
        createdAt: now,
      });
      return null;
    }
    const reactor = await ctx.db.get(userId);
    await ctx.db.insert("recordReactions", {
      recordId,
      achievedAt: record.achievedAt,
      userId,
      userName: reactor?.name ?? reactor?.username,
      emoji,
      createdAt: now,
    });
    return null;
  },
});

/** Takes your reaction off a record. Absent is not an error. */
export const unreact = mutation({
  args: { userId: v.id("users"), recordId: v.id("gameRecords") },
  handler: async (ctx, { userId, recordId }) => {
    const existing = await ctx.db
      .query("recordReactions")
      .withIndex("by_record_user", (q: any) =>
        q.eq("recordId", recordId).eq("userId", userId),
      )
      .first();
    if (existing) await ctx.db.delete(existing._id);
    return null;
  },
});

/**
 * One-off: builds `gameRecords` from every result that predates it.
 *
 * Walks USERS rather than results, and recomputes each person's records from
 * scratch — best, the day and moment it was set, the solve count, and the
 * current and longest streak — then writes them. That makes it idempotent and safe to re-run or resume: a solve
 * that lands while it runs is either already in the rows it reads, or counted
 * by `noteSolve` on top of a record that is then recomputed to the same
 * answer. A person's whole history is read in one transaction, which at four
 * games and one puzzle a day stays far inside Convex's per-mutation limits.
 *
 * Self-chains through the scheduler. Run once per deployment, after deploying:
 *
 *     npx convex run records:backfill '{}'
 */
export const backfill = internalMutation({
  args: {
    cursor: v.optional(v.string()),
    users: v.optional(v.number()),
    written: v.optional(v.number()),
  },
  handler: async (ctx, { cursor, users, written }) => {
    const page = await ctx.db
      .query("users")
      .paginate({ numItems: 20, cursor: cursor ?? null });
    let totalUsers = users ?? 0;
    let totalWritten = written ?? 0;

    for (const user of page.page) {
      totalUsers++;
      type Tally = { best?: number; dayKey: string; achievedAt: number; solves: number };
      const tally = new Map<string, Tally>();
      // Every day each game was solved on, for the streaks below.
      const days = new Map<string, string[]>();
      const note = (
        game: string,
        score: number,
        dayKey: string,
        at: number,
        clean: boolean,
      ) => {
        days.set(game, [...(days.get(game) ?? []), dayKey]);
        const t = tally.get(game);
        if (!t) {
          tally.set(game, {
            ...(clean ? { best: score } : {}),
            dayKey,
            achievedAt: at,
            solves: 1,
          });
          return;
        }
        t.solves++;
        // Same rule as `noteSolve`: a hinted solve never sets the best;
        // strictly better replaces; a tie keeps the earlier.
        if (!clean) return;
        if (
          t.best === undefined ||
          score < t.best ||
          (score === t.best && at < t.achievedAt)
        ) {
          t.best = score;
          t.dayKey = dayKey;
          t.achievedAt = at;
        }
      };

      for (const row of await ctx.db
        .query("gameResults")
        .withIndex("by_user_day_game", (q: any) => q.eq("userId", user._id))
        .collect()) {
        if (!row.solved || row.durationMs === undefined) continue;
        note(
          row.game,
          row.durationMs,
          row.dayKey,
          row.finishedAt ?? row.startedAt,
          (row.hintsUsed ?? 0) === 0,
        );
      }
      for (const row of await ctx.db
        .query("puzzleResults")
        .withIndex("by_user", (q: any) => q.eq("userId", user._id))
        .collect()) {
        if (!row.solved) continue;
        note(
          CODE_GAME,
          row.guesses.length,
          row.dayKey,
          row.finishedAt ?? row.updatedAt,
          true,
        );
      }

      for (const [game, base] of tally) {
        // The streaks, replayed through the same rule `noteSolve` applies one
        // solve at a time, in day order: what the row would hold had streaks
        // existed from the first solve.
        let run: { streak?: number; bestStreak?: number; lastSolvedDayKey?: string } = {};
        for (const day of [...days.get(game)!].sort()) {
          run = { ...run, ...extendStreak(run, day) };
        }
        const t = { ...base, ...run };
        const existing = await ctx.db
          .query("gameRecords")
          .withIndex("by_user_game", (q: any) =>
            q.eq("userId", user._id).eq("game", game),
          )
          .first();
        if (!existing) {
          await ctx.db.insert("gameRecords", { userId: user._id, game, ...t });
          totalWritten++;
          continue;
        }
        if (
          existing.best !== t.best ||
          existing.achievedAt !== t.achievedAt ||
          existing.solves !== t.solves ||
          existing.dayKey !== t.dayKey ||
          existing.streak !== t.streak ||
          existing.bestStreak !== t.bestStreak ||
          existing.lastSolvedDayKey !== t.lastSolvedDayKey
        ) {
          await ctx.db.patch(existing._id, t);
          totalWritten++;
        }
      }
    }

    if (!page.isDone) {
      await ctx.scheduler.runAfter(0, internal.records.backfill, {
        cursor: page.continueCursor,
        users: totalUsers,
        written: totalWritten,
      });
    } else {
      console.log(
        `records.backfill done: ${totalUsers} users, ${totalWritten} records written`,
      );
    }
    return { users: totalUsers, written: totalWritten, done: page.isDone };
  },
});
