import { mutation, query, internalMutation } from "./_generated/server";
import { internal } from "./_generated/api";
import { v } from "convex/values";

export const send = mutation({
  args: {
    roomId: v.id("rooms"),
    userId: v.id("users"),
    content: v.string(),
    type: v.optional(v.string()),          // "text" | "image" | "video" | "audio" | "url" | "system"
    mediaStorageId: v.optional(v.id("_storage")),
    senderName: v.optional(v.string()),
  },
  handler: async (ctx, { roomId, userId, content, type, mediaStorageId, senderName }) => {
    // Verify membership
    const membership = await ctx.db
      .query("roomMembers")
      .withIndex("by_room_user", (q) => q.eq("roomId", roomId).eq("userId", userId))
      .first();
    if (!membership) throw new Error("NOT_A_MEMBER");

    const msgType = type ?? "text";

    // Resolve senderName if not provided
    let resolvedSenderName = senderName;
    if (!resolvedSenderName) {
      const user = await ctx.db.get(userId);
      resolvedSenderName = user?.name ?? user?.username ?? "Unknown";
    }

    const room = await ctx.db.get(roomId);

    // DM block enforcement.
    //
    // Group rooms allow blocks to be one-way (the blocker hides the blockee
    // client-side). For DMs we hard-stop sends in either direction so the
    // block is absolute. The error is intentionally generic — never reveal
    // to the sender that they're the one being blocked.
    if (room?.name?.startsWith("dm:")) {
      const otherMember = await ctx.db
        .query("roomMembers")
        .withIndex("by_room", (q) => q.eq("roomId", roomId))
        .collect();
      const otherId = otherMember.find(
        (m) => m.userId.toString() !== userId.toString()
      )?.userId;
      if (otherId) {
        const iBlockedThem = await ctx.db
          .query("blocks")
          .withIndex("by_pair", (q) =>
            q.eq("userId", userId).eq("blockedUserId", otherId)
          )
          .first();
        const theyBlockedMe = await ctx.db
          .query("blocks")
          .withIndex("by_pair", (q) =>
            q.eq("userId", otherId).eq("blockedUserId", userId)
          )
          .first();
        if (iBlockedThem) throw new Error("UNBLOCK_FIRST");
        if (theyBlockedMe) throw new Error("MESSAGE_FAILED");
      }
    }

    // Check if the room has a message lifetime (Chamber of Secrets)
    const expiresAt = room?.messageLifetime
      ? Date.now() + room.messageLifetime * 1000
      : undefined;

    const messageId = await ctx.db.insert("messages", {
      roomId,
      userId,
      content,
      createdAt: Date.now(),
      type: msgType,
      mediaStorageId,
      senderName: resolvedSenderName,
      expiresAt,
    });

    // Schedule server-side deletion for self-destructing messages
    if (expiresAt !== undefined) {
      await ctx.scheduler.runAt(
        new Date(expiresAt),
        internal.messages.expireMessage,
        { messageId }
      );
    }

    // Update room's last message preview
    const preview = msgType === "text" ? content.slice(0, 100) : `[${msgType}]`;
    await ctx.db.patch(roomId, {
      lastMessage: preview,
      lastMessageTime: Date.now(),
    });

    // Fire push notifications in background (non-blocking)
    await ctx.scheduler.runAfter(0, internal.notifications.sendMessagePush, {
      roomId,
      messageId,
      senderId: userId,
      senderName: resolvedSenderName,
      content: preview,
      type: msgType,
    });

    return messageId;
  },
});

export const deleteMessage = mutation({
  args: {
    messageId: v.id("messages"),
    userId: v.id("users"),
  },
  handler: async (ctx, { messageId, userId }) => {
    const msg = await ctx.db.get(messageId);
    if (!msg) throw new Error("MESSAGE_NOT_FOUND");

    // Only sender or room owner can delete
    if (msg.userId.toString() !== userId.toString()) {
      const membership = await ctx.db
        .query("roomMembers")
        .withIndex("by_room_user", (q) => q.eq("roomId", msg.roomId).eq("userId", userId))
        .first();
      if (!membership || membership.role !== "owner") {
        throw new Error("NOT_AUTHORIZED");
      }
    }

    // Delete all reactions for this message
    const reactions = await ctx.db
      .query("reactions")
      .withIndex("by_message", (q) => q.eq("messageId", messageId))
      .collect();
    for (const r of reactions) await ctx.db.delete(r._id);

    // Delete associated file from storage if present
    if (msg.mediaStorageId) {
      await ctx.storage.delete(msg.mediaStorageId);
    }

    await ctx.db.delete(messageId);
  },
});

export const list = query({
  args: { roomId: v.id("rooms"), limit: v.optional(v.number()) },
  handler: async (ctx, { roomId, limit }) => {
    const msgs = await ctx.db
      .query("messages")
      .withIndex("by_room_time", (q) => q.eq("roomId", roomId))
      .order("desc")
      .take(limit ?? 100);

    const enriched = await Promise.all(
      msgs.map(async (msg) => {
        const user = await ctx.db.get(msg.userId);
        const reactions = await ctx.db
          .query("reactions")
          .withIndex("by_message", (q) => q.eq("messageId", msg._id))
          .collect();
        return {
          ...msg,
          username: user?.username ?? "unknown",
          name: user?.name ?? user?.username ?? "unknown",
          reactions,
        };
      })
    );
    return enriched.reverse();
  },
});

export const listBefore = query({
  args: {
    roomId: v.id("rooms"),
    beforeTimestamp: v.number(),
    limit: v.optional(v.number()),
  },
  handler: async (ctx, { roomId, beforeTimestamp, limit }) => {
    const msgs = await ctx.db
      .query("messages")
      .withIndex("by_room_time", (q) =>
        q.eq("roomId", roomId).lt("createdAt", beforeTimestamp)
      )
      .order("desc")
      .take(limit ?? 30);

    const enriched = await Promise.all(
      msgs.map(async (msg) => {
        const user = await ctx.db.get(msg.userId);
        const reactions = await ctx.db
          .query("reactions")
          .withIndex("by_message", (q) => q.eq("messageId", msg._id))
          .collect();
        return {
          ...msg,
          username: user?.username ?? "unknown",
          name: user?.name ?? user?.username ?? "unknown",
          reactions,
        };
      })
    );
    return enriched.reverse(); // chronological order
  },
});

// MARK: - Chamber of Secrets: scheduled self-destruction

export const expireMessage = internalMutation({
  args: { messageId: v.id("messages") },
  handler: async (ctx, { messageId }) => {
    const msg = await ctx.db.get(messageId);
    if (!msg) return; // Already deleted (e.g. manually deleted before expiry)

    // Delete all reactions for this message
    const reactions = await ctx.db
      .query("reactions")
      .withIndex("by_message", (q) => q.eq("messageId", messageId))
      .collect();
    for (const r of reactions) await ctx.db.delete(r._id);

    // Delete associated media from storage if present
    if (msg.mediaStorageId) {
      await ctx.storage.delete(msg.mediaStorageId);
    }

    await ctx.db.delete(messageId);
  },
});

// ─────────────────────────────── Read receipts ───────────────────────────────

/**
 * Mark a room as "read up to now" for the given user. Persisted on the
 * roomMembers row so the relationship is O(rooms × members) rather than
 * O(messages × members).
 *
 * Idempotent — calling repeatedly only updates the timestamp.
 */
export const markRoomRead = mutation({
  args: { roomId: v.id("rooms"), userId: v.id("users") },
  handler: async (ctx, { roomId, userId }) => {
    const membership = await ctx.db
      .query("roomMembers")
      .withIndex("by_room_user", (q) =>
        q.eq("roomId", roomId).eq("userId", userId)
      )
      .first();
    if (!membership) return; // not a member, silently no-op
    await ctx.db.patch(membership._id, { lastReadAt: Date.now() });
  },
});

/**
 * Returns each member's lastReadAt timestamp for a room. The client uses
 * this to render a "seen" indicator on its own messages.
 */
export const getReadState = query({
  args: { roomId: v.id("rooms") },
  handler: async (ctx, { roomId }) => {
    const members = await ctx.db
      .query("roomMembers")
      .withIndex("by_room", (q) => q.eq("roomId", roomId))
      .collect();
    return members.map((m) => ({
      userId: m.userId,
      lastReadAt: m.lastReadAt ?? 0,
    }));
  },
});
