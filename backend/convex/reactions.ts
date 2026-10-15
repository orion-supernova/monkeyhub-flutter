import { mutation, query } from "./functions";
import { internal } from "./_generated/api";
import { v } from "convex/values";
import { assertRoomAllowsById } from "./roomPolicy";
import { canReadRoom } from "./roomAccess";

/**
 * How many distinct emoji one person may leave on one message.
 *
 * Per person, not per message: the thing prevented is one reactor spraying
 * the whole picker onto a bubble, while ten different people each adding one
 * is exactly what reactions are for. Mirrored client-side as
 * `kMaxMessageReactionsPerPerson` (lib/models/reaction_limits.dart), which only
 * checks first so the friendly alert can open before anything is sent — this
 * is the one that enforces it.
 */
export const MAX_REACTIONS_PER_PERSON = 10;

export const addReaction = mutation({
  args: {
    messageId: v.id("messages"),
    userId: v.id("users"),
    emoji: v.string(),
    // A reaction to the whole album this message heads. See
    // `reactions.album` in schema.ts.
    album: v.optional(v.boolean()),
  },
  handler: async (ctx, { messageId, userId, emoji, album }) => {
    const toAlbum = album === true;
    // Verify message exists
    const msg = await ctx.db.get(messageId);
    if (!msg) throw new Error("MESSAGE_NOT_FOUND");

    // Verify user is a member of the room
    const membership = await ctx.db
      .query("roomMembers")
      .withIndex("by_room_user", (q) => q.eq("roomId", msg.roomId).eq("userId", userId))
      .first();
    if (!membership) throw new Error("NOT_A_MEMBER");

    // The room's posting policy (see `roomPolicy.ts`): a reaction is a mark
    // everyone in the room sees, so a read-only room refuses it. Removing one
    // is left open, so nobody is stuck with a mark they made before.
    await assertRoomAllowsById(ctx, msg.roomId, userId, { actions: ["react"] });

    // Idempotent: one reaction per user per emoji per message. Read as the
    // viewer's whole set rather than a filtered `.first()`, because the cap
    // below needs the count anyway and the set is at most ten rows.
    // The album's reactions and the photo's are separate sets that happen to
    // share a message: each has its own uniqueness and its own cap.
    const mine = (
      await ctx.db
        .query("reactions")
        .withIndex("by_message_user", (q) =>
          q.eq("messageId", messageId).eq("userId", userId)
        )
        .collect()
    ).filter((r) => (r.album === true) === toAlbum);
    const existing = mine.find((r) => r.emoji === emoji);
    if (existing) return existing._id;
    // Checked after the idempotency return on purpose: re-adding one you
    // already have at the cap is a no-op, not a refusal.
    if (mine.length >= MAX_REACTIONS_PER_PERSON) {
      throw new Error("REACTION_LIMIT");
    }

    const id = await ctx.db.insert("reactions", {
      messageId,
      userId,
      emoji,
      createdAt: Date.now(),
      ...(toAlbum ? { album: true } : {}),
    });
    // Flip the read-path flag in the SAME transaction as the row — see
    // `messages.hasReactions` in schema.ts. Only on the transition: a second
    // reaction on the same message must not patch it again and re-fire every
    // transcript over it for nothing.
    if (msg.hasReactions !== true) {
      await ctx.db.patch(messageId, { hasReactions: true });
    }
    // Only a NEW row tells anyone anything — the idempotent return above
    // never gets here. Who hears it (the author, not the reactor, mute, …)
    // is the sender's business; see `notifications.sendReactionPush`.
    await ctx.scheduler.runAfter(0, internal.notifications.sendReactionPush, {
      reactionId: id,
    });
    return id;
  },
});

export const removeReaction = mutation({
  args: {
    messageId: v.id("messages"),
    userId: v.id("users"),
    emoji: v.string(),
    album: v.optional(v.boolean()),
  },
  handler: async (ctx, { messageId, userId, emoji, album }) => {
    const toAlbum = album === true;
    const existing = (
      await ctx.db
        .query("reactions")
        .withIndex("by_message_user", (q) =>
          q.eq("messageId", messageId).eq("userId", userId)
        )
        .filter((q) => q.eq(q.field("emoji"), emoji))
        .collect()
    ).find((r) => (r.album === true) === toAlbum);
    if (!existing) return;
    await ctx.db.delete(existing._id);

    // Last one out clears the flag, so the transcript queries stop looking.
    // One extra indexed read on a remove — rare next to a `list` run, which
    // is what the flag is saving. The read sees this transaction's own
    // delete. A clear that is somehow missed leaves a stale `true`, which
    // only costs reads; see schema.ts.
    const remaining = await ctx.db
      .query("reactions")
      .withIndex("by_message", (q) => q.eq("messageId", messageId))
      .first();
    if (remaining === null) {
      const msg = await ctx.db.get(messageId);
      if (msg && msg.hasReactions === true) {
        await ctx.db.patch(messageId, { hasReactions: false });
      }
    }
  },
});

export const getReactions = query({
  args: { messageId: v.id("messages") },
  handler: async (ctx, { messageId, userId }) => {
    const msg = await ctx.db.get(messageId);
    if (!msg || !(await canReadRoom(ctx, msg.roomId, userId))) return [];
    return await ctx.db
      .query("reactions")
      .withIndex("by_message", (q) => q.eq("messageId", messageId))
      .order("asc")
      .collect();
  },
});

// Bulk-fetch reactions for multiple messages (used when loading a room)
export const getReactionsForMessages = query({
  args: { messageIds: v.array(v.id("messages")) },
  handler: async (ctx, { messageIds, userId }) => {
    const result: Record<string, unknown[]> = {};
    const readable = new Map<string, boolean>();
    for (const messageId of messageIds.slice(0, 200)) {
      const msg = await ctx.db.get(messageId);
      if (!msg) continue;
      const key = msg.roomId.toString();
      if (!readable.has(key)) {
        readable.set(key, await canReadRoom(ctx, msg.roomId, userId));
      }
      if (!readable.get(key)) continue;
      const reactions = await ctx.db
        .query("reactions")
        .withIndex("by_message", (q) => q.eq("messageId", messageId))
        .collect();
      result[messageId] = reactions;
    }
    return result;
  },
});
