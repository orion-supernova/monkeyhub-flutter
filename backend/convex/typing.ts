import { mutation, query } from "./_generated/server";
import { v } from "convex/values";

const TYPING_TTL_MS = 8000; // safety net — clearTyping fires after 3s inactivity, heartbeat every 2s

/**
 * Shape both typing queries return per typist. Deliberately mirrors the keys
 * `ChatUser.fromJson` reads on the client, so the indicator can render a real
 * `UserAvatar` without a bespoke model. Avatars are unfiltered here for the
 * same reason `rooms.getMembers` leaves them unfiltered: everyone in this list
 * is already a member of a room the viewer is in.
 */
async function typistOf(ctx: any, userId: any) {
  const user = await ctx.db.get(userId);
  if (!user) return null;
  return {
    _id: user._id,
    username: user.username ?? "",
    name: user.name ?? user.username ?? "",
    avatarStorageId: user.avatarStorageId,
  };
}

export const setTyping = mutation({
  args: {
    roomId: v.id("rooms"),
    userId: v.id("users"),
  },
  handler: async (ctx, { roomId, userId }) => {
    const existing = await ctx.db
      .query("typingIndicators")
      .withIndex("by_room_user", (q) => q.eq("roomId", roomId).eq("userId", userId))
      .first();

    if (existing) {
      await ctx.db.patch(existing._id, { updatedAt: Date.now() });
    } else {
      await ctx.db.insert("typingIndicators", {
        roomId,
        userId,
        updatedAt: Date.now(),
      });
    }
  },
});

export const clearTyping = mutation({
  args: {
    roomId: v.id("rooms"),
    userId: v.id("users"),
  },
  handler: async (ctx, { roomId, userId }) => {
    const existing = await ctx.db
      .query("typingIndicators")
      .withIndex("by_room_user", (q) => q.eq("roomId", roomId).eq("userId", userId))
      .first();
    if (existing) await ctx.db.delete(existing._id);
  },
});

/// Returns { roomId: [typerName, …] } for all rooms the user belongs to.
/// A single subscription gives live typing state for the whole room list.
///
/// Intentionally still plain names, not the richer `typistOf` shape: the room
/// list only renders a label, and changing this to objects would garble the
/// typing text on every app build already in users' hands. The in-room
/// indicator, which does need avatars, uses `getTypingUsers` below.
export const getTypingForUser = query({
  args: { userId: v.id("users") },
  handler: async (ctx, { userId }) => {
    const now = Date.now();
    const memberships = await ctx.db
      .query("roomMembers")
      .withIndex("by_user", (q) => q.eq("userId", userId))
      .collect();

    const result: Record<string, string[]> = {};
    for (const m of memberships) {
      const indicators = await ctx.db
        .query("typingIndicators")
        .withIndex("by_room", (q) => q.eq("roomId", m.roomId))
        .collect();

      const active = indicators.filter(
        (t) =>
          t.userId.toString() !== userId.toString() &&
          now - t.updatedAt < TYPING_TTL_MS
      );

      if (active.length > 0) {
        const names = (
          await Promise.all(
            active.map(async (t) => {
              const user = await ctx.db.get(t.userId);
              return user?.name ?? user?.username ?? null;
            })
          )
        ).filter(Boolean) as string[];
        if (names.length > 0) result[m.roomId.toString()] = names;
      }
    }
    return result;
  },
});

export const getTypingUsers = query({
  args: { roomId: v.id("rooms"), currentUserId: v.id("users") },
  handler: async (ctx, { roomId, currentUserId }) => {
    const now = Date.now();
    const indicators = await ctx.db
      .query("typingIndicators")
      .withIndex("by_room", (q) => q.eq("roomId", roomId))
      .collect();

    // Filter out stale entries and self
    const active = indicators.filter(
      (t) =>
        t.userId.toString() !== currentUserId.toString() &&
        now - t.updatedAt < TYPING_TTL_MS
    );

    const enriched = await Promise.all(
      active.map((t) => typistOf(ctx, t.userId))
    );
    return enriched.filter(Boolean);
  },
});
