import { mutation, query } from "./functions";
import { v } from "convex/values";

export const addReaction = mutation({
  args: {
    messageId: v.id("messages"),
    userId: v.id("users"),
    emoji: v.string(),
  },
  handler: async (ctx, { messageId, userId, emoji }) => {
    // Verify message exists
    const msg = await ctx.db.get(messageId);
    if (!msg) throw new Error("MESSAGE_NOT_FOUND");

    // Verify user is a member of the room
    const membership = await ctx.db
      .query("roomMembers")
      .withIndex("by_room_user", (q) => q.eq("roomId", msg.roomId).eq("userId", userId))
      .first();
    if (!membership) throw new Error("NOT_A_MEMBER");

    // Idempotent: one reaction per user per emoji per message
    const existing = await ctx.db
      .query("reactions")
      .withIndex("by_message_user", (q) =>
        q.eq("messageId", messageId).eq("userId", userId)
      )
      .filter((q) => q.eq(q.field("emoji"), emoji))
      .first();
    if (existing) return existing._id;

    const id = await ctx.db.insert("reactions", {
      messageId,
      userId,
      emoji,
      createdAt: Date.now(),
    });
    // Flip the read-path flag in the SAME transaction as the row — see
    // `messages.hasReactions` in schema.ts. Only on the transition: a second
    // reaction on the same message must not patch it again and re-fire every
    // transcript over it for nothing.
    if (msg.hasReactions !== true) {
      await ctx.db.patch(messageId, { hasReactions: true });
    }
    return id;
  },
});

export const removeReaction = mutation({
  args: {
    messageId: v.id("messages"),
    userId: v.id("users"),
    emoji: v.string(),
  },
  handler: async (ctx, { messageId, userId, emoji }) => {
    const existing = await ctx.db
      .query("reactions")
      .withIndex("by_message_user", (q) =>
        q.eq("messageId", messageId).eq("userId", userId)
      )
      .filter((q) => q.eq(q.field("emoji"), emoji))
      .first();
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
  handler: async (ctx, { messageId }) => {
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
  handler: async (ctx, { messageIds }) => {
    const result: Record<string, unknown[]> = {};
    for (const messageId of messageIds) {
      const reactions = await ctx.db
        .query("reactions")
        .withIndex("by_message", (q) => q.eq("messageId", messageId))
        .collect();
      result[messageId] = reactions;
    }
    return result;
  },
});
