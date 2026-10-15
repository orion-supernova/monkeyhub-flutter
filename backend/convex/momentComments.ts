import { mutation, query } from "./functions";
import { internal } from "./_generated/api";
import { v } from "convex/values";

import { ACCOUNT_CHILD, assertChildPolicy } from "./childGuard";
import { canSeeMoment, isReactionEmoji, MAX_MOMENT_REACTIONS_PER_PERSON } from "./feed";
import { expressionFieldsFor } from "./messages";
import { lensFor } from "./visibility";
import { hasHit } from "./contentFilter";
import { screenAndReport } from "./moderationCore";

/**
 * Comments on a highlight — and their replies, and the reactions on both.
 *
 * ## Shape
 *
 * Instagram's, deliberately: words, a sticker, or a GIF; one level of
 * threading; emoji reactions on every comment. See `momentComments` in
 * schema.ts for why a reply never nests deeper than one and why a photo is
 * never a comment.
 *
 * ## Who sees what
 *
 * A comment is visible to exactly the people who can see the moment it is on
 * — `feed.canSeeMoment`, the same gate the board, the viewer and reactions all
 * use. That is wider than the viewer's own friends: two people who both know
 * the author will see each other's comments, which is the point of a comment
 * as opposed to a DM, and which `reactors` on a moment already does with
 * names.
 *
 * With ONE carve-out, for supervised accounts. A child's contacts are built by
 * guardian approval precisely because who the child talks to is the thing
 * being supervised, and a comment thread on a friend's highlight would
 * otherwise be a room full of people nobody approved. So:
 *
 *   * a CHILD viewer sees only comments from themselves, the moment's author
 *     and people they are friends with;
 *   * a child's OWN comments are shown only to the author, the child's
 *     friends and their guardian.
 *
 * Both are applied in `list`, the only read path.
 *
 * ## Cost
 *
 * `list` is subscribed while the comments sheet is open, and reads one `users`
 * row per distinct commenter for names, faces and the child rule. That joins
 * those rows' presence heartbeats to its invalidation set — acceptable for a
 * sheet that is open for a minute over a conversation of tens of people, and
 * NOT something the board may ever do (see feed.ts). The board instead reads
 * `moments.commentCount`, which is why that counter exists.
 */

/** Longest comment we store. Instagram allows 2,200; a highlight needs less. */
const MAX_COMMENT = 500;

/**
 * How many comments one moment may carry, replies included. Also the read cap
 * in `list`, so nothing the server accepted is ever silently not shown.
 */
const MAX_COMMENTS_PER_MOMENT = 500;

/**
 * Removes one comment, its replies when it is a thread root, and every
 * reaction on any of them. Returns how many comments went, for the counter.
 */
async function deleteCommentCascade(ctx: any, c: any): Promise<number> {
  const doomed = [c];
  if (c.parentId === undefined) {
    doomed.push(
      ...(await ctx.db
        .query("momentComments")
        .withIndex("by_parent", (q: any) => q.eq("parentId", c._id))
        .collect()),
    );
  }
  for (const row of doomed) {
    for (const r of await ctx.db
      .query("momentCommentReactions")
      .withIndex("by_comment", (q: any) => q.eq("commentId", row._id))
      .collect()) {
      await ctx.db.delete(r._id);
    }
    await ctx.db.delete(row._id);
  }
  return doomed.length;
}

/** Moves a moment's comment counter, never below zero. */
async function bumpCount(ctx: any, momentId: any, delta: number) {
  const m = await ctx.db.get(momentId);
  if (!m) return;
  const next = Math.max(0, (m.commentCount ?? 0) + delta);
  if (next !== (m.commentCount ?? 0)) {
    await ctx.db.patch(momentId, { commentCount: next });
  }
}

/**
 * Everything hanging off one moment's conversation, for `feed.remove` and the
 * account purge. Does not touch the counter — the moment is going too.
 */
export async function purgeMomentComments(ctx: any, momentId: any) {
  for (const r of await ctx.db
    .query("momentCommentReactions")
    .withIndex("by_moment", (q: any) => q.eq("momentId", momentId))
    .collect()) {
    await ctx.db.delete(r._id);
  }
  for (const c of await ctx.db
    .query("momentComments")
    .withIndex("by_moment_created", (q: any) => q.eq("momentId", momentId))
    .collect()) {
    await ctx.db.delete(c._id);
  }
}

/**
 * Everything one person said under OTHER people's moments, for the account
 * purge — their comments (with the replies under them, which would otherwise
 * hang off nothing), and their reactions to comments.
 */
export async function purgeUserComments(ctx: any, userId: any) {
  for (const r of await ctx.db
    .query("momentCommentReactions")
    .withIndex("by_user", (q: any) => q.eq("userId", userId))
    .collect()) {
    await ctx.db.delete(r._id);
  }
  for (const c of await ctx.db
    .query("momentComments")
    .withIndex("by_user", (q: any) => q.eq("userId", userId))
    .collect()) {
    // Already gone as part of an earlier root's cascade in this same loop.
    if ((await ctx.db.get(c._id)) === null) continue;
    const n = await deleteCommentCascade(ctx, c);
    await bumpCount(ctx, c.momentId, -n);
  }
}

/**
 * One moment's conversation, oldest first, with replies flattened alongside
 * their roots (the client threads them by `parentId`).
 *
 * Null when the moment is gone or the viewer may not see it — the sheet closes
 * on that rather than showing an empty conversation that is not really empty.
 */
export const list = query({
  args: { userId: v.id("users"), momentId: v.id("moments") },
  handler: async (ctx, { userId, momentId }) => {
    const m = await ctx.db.get(momentId);
    if (!m) return null;
    if (!(await canSeeMoment(ctx, userId, m))) return null;

    const rows = await ctx.db
      .query("momentComments")
      .withIndex("by_moment_created", (q: any) => q.eq("momentId", momentId))
      .take(MAX_COMMENTS_PER_MOMENT);
    if (rows.length === 0) return { comments: [] };

    const lens = await lensFor(ctx, userId);
    const people = new Map<string, any>();
    for (const id of new Set(rows.map((r: any) => r.userId.toString()))) {
      people.set(id, await ctx.db.get(id as any));
    }
    const viewer = people.get(userId.toString()) ?? (await ctx.db.get(userId));
    const viewerIsChild = viewer?.accountType === ACCOUNT_CHILD;

    // The supervised-account carve-out — see the header.
    const shown = (c: any) => {
      const authorId = c.userId;
      if (lens.isSelf(authorId) || authorId === m.userId) return true;
      if (viewerIsChild && !lens.isFriend(authorId)) return false;
      const author = people.get(authorId.toString());
      if (author?.accountType === ACCOUNT_CHILD) {
        return (
          userId === m.userId ||
          lens.isFriend(authorId) ||
          lens.isGuardian(authorId)
        );
      }
      return true;
    };
    const visibleRoots = new Set(
      rows
        .filter((c: any) => c.parentId === undefined && shown(c))
        .map((c: any) => c._id.toString()),
    );
    const visible = rows.filter((c: any) =>
      c.parentId === undefined
        ? visibleRoots.has(c._id.toString())
        : visibleRoots.has(c.parentId.toString()) && shown(c),
    );

    const reactions = await ctx.db
      .query("momentCommentReactions")
      .withIndex("by_moment", (q: any) => q.eq("momentId", momentId))
      .collect();
    const byComment = new Map<string, any[]>();
    for (const r of reactions) {
      const k = r.commentId.toString();
      if (!byComment.has(k)) byComment.set(k, []);
      byComment.get(k)!.push(r);
    }

    const comments = visible.map((c: any) => {
      const author = people.get(c.userId.toString());
      const rs = byComment.get(c._id.toString()) ?? [];
      // An ARRAY of {emoji, count}, never an emoji-keyed object — see
      // `feed.momentView` for the serialization failure that would cause.
      const tally = new Map<string, number>();
      for (const r of rs) tally.set(r.emoji, (tally.get(r.emoji) ?? 0) + 1);
      // Hand-built, field by field: this literal IS the access boundary.
      return {
        _id: c._id,
        userId: c.userId,
        // The live name where there is one, so a rename shows; the stored one
        // for an account that has since gone.
        userName: author?.name ?? author?.username ?? c.userName,
        userAvatarStorageId:
          author && lens.canSee(author, "avatar")
            ? author.avatarStorageId
            : undefined,
        parentId: c.parentId,
        replyToUserId: c.replyToUserId,
        replyToName: c.replyToName,
        text: c.text,
        expressionKind: c.expressionKind,
        mediaSource: c.mediaSource,
        mediaUrl: c.mediaUrl,
        mediaPreviewUrl: c.mediaPreviewUrl,
        mediaRef: c.mediaRef,
        mediaWidth: c.mediaWidth,
        mediaHeight: c.mediaHeight,
        stickerId: c.stickerId,
        stickerStorageId: c.stickerStorageId,
        stickerFormat: c.stickerFormat,
        alt: c.alt,
        createdAt: c.createdAt,
        isAuthor: c.userId === m.userId,
        mine: c.userId === userId,
        // The commenter, or the moment's author — Instagram's rule: it is your
        // post, so what is said under it is yours to take down.
        canDelete: c.userId === userId || m.userId === userId,
        reactionCounts: Array.from(tally, ([emoji, count]) => ({ emoji, count })),
        myReactions: rs
          .filter((r: any) => r.userId === userId)
          .map((r: any) => r.emoji),
        reactors: rs
          .filter((r: any) => typeof r.userName === "string" && r.userName)
          .map((r: any) => ({ emoji: r.emoji, userId: r.userId, name: r.userName })),
      };
    });
    return { comments };
  },
});

/**
 * Posts a comment, or a reply.
 *
 * [replyToId] is the comment being answered, root or reply. The row is filed
 * under that comment's thread root either way, and answering a reply records
 * who it answered so the client can lead with "@name".
 *
 * Throws `NOT_A_FRIEND` when the moment is not the caller's to see,
 * `COMMENT_TOO_LONG`, `EMPTY_COMMENT`, `COMMENTS_FULL` at the per-moment cap,
 * and `CHILD_NOT_ALLOWED` when a supervised account sends a picture from
 * outside the app's own sticker packs with media switched off.
 */
export const add = mutation({
  args: {
    userId: v.id("users"),
    momentId: v.id("moments"),
    text: v.optional(v.string()),
    replyToId: v.optional(v.id("momentComments")),
    // A GIF or sticker, named the way `messages:send` names one. The server
    // resolves what lands on the row; see `expressionFieldsFor`.
    type: v.optional(v.string()),
    stickerId: v.optional(v.id("stickers")),
    mediaSource: v.optional(v.string()),
    mediaUrl: v.optional(v.string()),
    mediaPreviewUrl: v.optional(v.string()),
    mediaRef: v.optional(v.string()),
    mediaWidth: v.optional(v.number()),
    mediaHeight: v.optional(v.number()),
  },
  handler: async (ctx, args) => {
    const { userId, momentId } = args;
    const m = await ctx.db.get(momentId);
    if (!m) throw new Error("MOMENT_NOT_FOUND");
    if (!(await canSeeMoment(ctx, userId, m))) throw new Error("NOT_A_FRIEND");

    let text = args.text?.trim() || undefined;
    if (text !== undefined && text.length > MAX_COMMENT) {
      throw new Error("COMMENT_TOO_LONG");
    }
    // The objectionable-text filter. Strict when a child is on either end:
    // the commenter, or the moment's author it is addressed to. Both reads
    // happen only on a hit.
    if (text !== undefined && hasHit(text)) {
      const [author, owner] = await Promise.all([
        ctx.db.get(userId),
        ctx.db.get(m.userId),
      ]);
      text = await screenAndReport(ctx, {
        text,
        authorId: userId,
        childInvolved:
          author?.accountType === ACCOUNT_CHILD ||
          owner?.accountType === ACCOUNT_CHILD,
        surface: "comment",
      });
    }

    let expression: Record<string, any> | null = null;
    if (args.type !== undefined) {
      expression = await expressionFieldsFor(ctx, args.type, args);
      // A picture from outside — KLIPY, or a sticker cut out of somebody's
      // photo — needs the media grant, exactly as it does in a chat. Our own
      // packs are text-shaped; see `messages.permissionsFor`.
      if (expression && expression.mediaSource !== "pack") {
        await assertChildPolicy(ctx, userId, "mediaEnabled");
      }
    }
    if (text === undefined && expression === null) {
      throw new Error("EMPTY_COMMENT");
    }

    const existing = await ctx.db
      .query("momentComments")
      .withIndex("by_moment_created", (q: any) => q.eq("momentId", momentId))
      .take(MAX_COMMENTS_PER_MOMENT);
    if (existing.length >= MAX_COMMENTS_PER_MOMENT) {
      throw new Error("COMMENTS_FULL");
    }

    let parentId: any;
    let replyToUserId: any;
    let replyToName: string | undefined;
    if (args.replyToId !== undefined) {
      const target = await ctx.db.get(args.replyToId);
      // Answering something deleted a moment ago posts as a top-level comment
      // rather than failing — the words were still meant for this moment.
      if (target && target.momentId === momentId) {
        parentId = target.parentId ?? target._id;
        if (target.parentId !== undefined && target.userId !== userId) {
          replyToUserId = target.userId;
          replyToName = target.userName;
        }
      }
    }

    const me = await ctx.db.get(userId);
    const userName = me?.name ?? me?.username ?? "";
    const id = await ctx.db.insert("momentComments", {
      momentId,
      userId,
      userName,
      parentId,
      replyToUserId,
      replyToName,
      text,
      ...(expression
        ? {
            expressionKind: args.type,
            mediaSource: expression.mediaSource,
            mediaUrl: expression.mediaUrl,
            mediaPreviewUrl: expression.mediaPreviewUrl,
            mediaRef: expression.mediaRef,
            mediaWidth: expression.mediaWidth,
            mediaHeight: expression.mediaHeight,
            stickerId: expression.stickerId,
            stickerStorageId: expression.stickerStorageId,
            stickerFormat: expression.stickerFormat,
            alt: expression.alt,
          }
        : {}),
      createdAt: Date.now(),
    });
    await ctx.db.patch(momentId, { commentCount: existing.length + 1 });

    // Off the transaction, as `feed.post` schedules its own push: a
    // notification that cannot be assembled must never cost anyone their
    // comment. Every gate lives in `socialPush._commentAudience`.
    await ctx.scheduler.runAfter(0, internal.socialPush.sendCommentPush, {
      commentId: id,
    });
    return id;
  },
});

/**
 * Deletes a comment — and, when it is a thread root, the replies under it.
 * Allowed to the commenter and to the moment's author. Absent is not an error.
 */
export const remove = mutation({
  args: { userId: v.id("users"), commentId: v.id("momentComments") },
  handler: async (ctx, { userId, commentId }) => {
    const c = await ctx.db.get(commentId);
    if (!c) return;
    const m = await ctx.db.get(c.momentId);
    if (c.userId !== userId && m?.userId !== userId) {
      throw new Error("NOT_YOUR_COMMENT");
    }
    const n = await deleteCommentCascade(ctx, c);
    await bumpCount(ctx, c.momentId, -n);
  },
});

/**
 * Adds a reaction to a comment. One row per (comment, user, emoji); re-adding
 * is a no-op; at most `MAX_MOMENT_REACTIONS_PER_PERSON` different ones per
 * person, the same cap as on the highlight itself.
 */
export const react = mutation({
  args: {
    userId: v.id("users"),
    commentId: v.id("momentComments"),
    emoji: v.string(),
  },
  handler: async (ctx, { userId, commentId, emoji }) => {
    const c = await ctx.db.get(commentId);
    if (!c) throw new Error("COMMENT_NOT_FOUND");
    const m = await ctx.db.get(c.momentId);
    if (!m) throw new Error("MOMENT_NOT_FOUND");
    if (!(await canSeeMoment(ctx, userId, m))) throw new Error("NOT_A_FRIEND");
    if (!isReactionEmoji(emoji)) throw new Error("INVALID_EMOJI");

    const mine = await ctx.db
      .query("momentCommentReactions")
      .withIndex("by_comment_user", (q: any) =>
        q.eq("commentId", commentId).eq("userId", userId),
      )
      .collect();
    const existing = mine.find((r: any) => r.emoji === emoji);
    if (existing) return existing._id;
    if (mine.length >= MAX_MOMENT_REACTIONS_PER_PERSON) {
      throw new Error("REACTION_LIMIT");
    }

    const me = await ctx.db.get(userId);
    const id = await ctx.db.insert("momentCommentReactions", {
      commentId,
      momentId: c.momentId,
      userId,
      userName: me?.name ?? me?.username,
      emoji,
      createdAt: Date.now(),
    });
    await ctx.scheduler.runAfter(0, internal.socialPush.sendReactionPush, {
      commentReactionId: id,
    });
    return id;
  },
});

/** Removes one of your own reactions on a comment. Absent is not an error. */
export const unreact = mutation({
  args: {
    userId: v.id("users"),
    commentId: v.id("momentComments"),
    emoji: v.string(),
  },
  handler: async (ctx, { userId, commentId, emoji }) => {
    const existing = await ctx.db
      .query("momentCommentReactions")
      .withIndex("by_comment_user", (q: any) =>
        q.eq("commentId", commentId).eq("userId", userId),
      )
      .filter((q: any) => q.eq(q.field("emoji"), emoji))
      .first();
    if (existing) await ctx.db.delete(existing._id);
  },
});
