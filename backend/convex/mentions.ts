import { internalMutation } from "./_generated/server";
import { internal } from "./_generated/api";
import { mutation, query } from "./functions";
import { v } from "convex/values";
import { isTombstoned } from "./deletionCore";

/**
 * The in-room `@` badge: every message that named the reader and that they
 * have not yet seen on screen, oldest first.
 *
 * Seen means seen. A row leaves only when a client reports the message's
 * bubble was actually in the viewport ([markSeen]), or the reader clears the
 * stack on purpose ([markAllSeen]). Opening the room moves the read cursor to
 * the newest message at once, so the cursor cannot carry this — a mention
 * forty messages up would be "read" the moment the room opened.
 *
 * Cost, at scale: writes happen only when somebody is named (explicit
 * mentions are capped at 20 per message by `resolveMentions`; `@everyone`
 * fans out in pages, see [fanOutEveryone]). The one subscription,
 * [pendingForRoom], is mounted only for the room on screen and reads only the
 * caller's own index range, so another member's mention never invalidates it.
 */

/** The most a stack ever shows. The badge renders "99+" past it. */
export const MENTION_STACK_CAP = 99;

/** Members inserted per `@everyone` fan-out page. */
const FAN_OUT_PAGE = 200;

/**
 * Insert one row per named reader. Idempotent per (message, reader), so an
 * edit that re-names somebody already waiting does not stack them twice.
 */
export async function recordMentions(
  ctx: any,
  {
    roomId,
    messageId,
    createdAt,
    userIds,
  }: { roomId: any; messageId: any; createdAt: number; userIds: any[] },
): Promise<void> {
  for (const userId of userIds) {
    const existing = await ctx.db
      .query("mentionInbox")
      .withIndex("by_message_user", (q: any) =>
        q.eq("messageId", messageId).eq("userId", userId),
      )
      .first();
    if (existing) continue;
    await ctx.db.insert("mentionInbox", { userId, roomId, messageId, createdAt });
  }
}

/**
 * `@everyone`, one page of the roster at a time. Scheduled by `sendCore` and
 * `editMessage` rather than run inline: an admin may address a room of
 * thousands, and a send must not pay for that in its own transaction.
 */
export const fanOutEveryone = internalMutation({
  args: {
    roomId: v.id("rooms"),
    messageId: v.id("messages"),
    senderId: v.id("users"),
    cursor: v.optional(v.union(v.string(), v.null())),
  },
  returns: v.null(),
  handler: async (ctx, { roomId, messageId, senderId, cursor }) => {
    const msg = await ctx.db.get(messageId);
    // Deleted, or edited out of `@everyone` before the page ran.
    if (!msg || isTombstoned(msg as any) || (msg as any).mentionsEveryone !== true) {
      return null;
    }
    const page = await ctx.db
      .query("roomMembers")
      .withIndex("by_room_user", (q) => q.eq("roomId", roomId))
      .paginate({ cursor: cursor ?? null, numItems: FAN_OUT_PAGE });
    const sender = senderId.toString();
    await recordMentions(ctx, {
      roomId,
      messageId,
      createdAt: msg.createdAt,
      userIds: page.page
        .map((m) => m.userId)
        .filter((id) => id.toString() !== sender),
    });
    if (!page.isDone) {
      await ctx.scheduler.runAfter(0, internal.mentions.fanOutEveryone, {
        roomId,
        messageId,
        senderId,
        cursor: page.continueCursor,
      });
    }
    return null;
  },
});

/**
 * The reader's unseen mentions in one room, oldest first.
 *
 * Each row is checked against its message before it is returned: one that has
 * been deleted, expired, or edited so it no longer names the reader is
 * dropped here rather than relied on to have been cleaned up. That makes the
 * stack self-healing, and it is why [recordMentions] never has to delete.
 */
export const pendingForRoom = query({
  args: {
    roomId: v.id("rooms"),
  },
  returns: v.object({
    items: v.array(
      v.object({ messageId: v.id("messages"), createdAt: v.number() }),
    ),
    capped: v.boolean(),
  }),
  handler: async (ctx, { roomId, userId }) => {
    // Scoped to the caller's own index range, so no membership check is
    // needed to keep anyone else's data out; a reader who left simply has
    // no rows (leaving purges them).
    const rows = await ctx.db
      .query("mentionInbox")
      .withIndex("by_user_room", (q) =>
        q.eq("userId", userId).eq("roomId", roomId),
      )
      .take(MENTION_STACK_CAP + 1);
    const me = userId.toString();
    const now = Date.now();
    const items: Array<{ messageId: any; createdAt: number }> = [];
    for (const r of rows) {
      if (items.length >= MENTION_STACK_CAP) break;
      const msg: any = await ctx.db.get(r.messageId);
      if (!msg || isTombstoned(msg)) continue;
      if (typeof msg.expiresAt === "number" && msg.expiresAt <= now) continue;
      const named =
        msg.mentionsEveryone === true ||
        (msg.mentions ?? []).some((m: any) => m.userId.toString() === me);
      if (!named) continue;
      items.push({ messageId: r.messageId, createdAt: r.createdAt });
    }
    return { items, capped: rows.length > MENTION_STACK_CAP };
  },
});

/** The reader saw these bubbles on screen. Silently ignores unknown ids. */
export const markSeen = mutation({
  args: {
    roomId: v.id("rooms"),
    messageIds: v.array(v.id("messages")),
  },
  returns: v.null(),
  handler: async (ctx, { roomId, userId, messageIds }) => {
    // Bounded: the client batches what one scroll revealed, never a backlog.
    for (const messageId of messageIds.slice(0, MENTION_STACK_CAP + 1)) {
      const rows = await ctx.db
        .query("mentionInbox")
        .withIndex("by_message_user", (q) =>
          q.eq("messageId", messageId).eq("userId", userId),
        )
        .collect();
      for (const r of rows) {
        if (r.roomId.toString() === roomId.toString()) await ctx.db.delete(r._id);
      }
    }
    return null;
  },
});

/** "Mark all as read" on the `@` button's long-press: empties the stack. */
export const markAllSeen = mutation({
  args: {
    roomId: v.id("rooms"),
  },
  returns: v.null(),
  handler: async (ctx, { roomId, userId }) => {
    const rows = await ctx.db
      .query("mentionInbox")
      .withIndex("by_user_room", (q) =>
        q.eq("userId", userId).eq("roomId", roomId),
      )
      .take(500);
    for (const r of rows) await ctx.db.delete(r._id);
    return null;
  },
});

/** Leaving a room (or being removed): nothing there is addressed to you now. */
export async function purgeMentionsForMember(
  ctx: any,
  roomId: any,
  userId: any,
): Promise<void> {
  const rows = await ctx.db
    .query("mentionInbox")
    .withIndex("by_room_user", (q: any) =>
      q.eq("roomId", roomId).eq("userId", userId),
    )
    .take(500);
  for (const r of rows) await ctx.db.delete(r._id);
}
