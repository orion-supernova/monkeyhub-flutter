import { mutation, query } from "./_generated/server";
import { v } from "convex/values";
import { lensFor } from "./visibility";

const TYPING_TTL_MS = 8000; // safety net — clearTyping fires after 3s inactivity, heartbeat every 2s

/**
 * Shape both typing queries return per typist. Deliberately mirrors the keys
 * `ChatUser.fromJson` reads on the client, so the indicator can render a real
 * `UserAvatar` without a bespoke model.
 *
 * Built entirely off the denormalized row — never `ctx.db.get(userId)` — so
 * neither query subscribes to the typist's `users` document. See the
 * `userName`/`avatarStorageId`/`avatarVisibility` comment in schema.ts for
 * why: `getTypingForUser` is a global, whole-session subscription, and a
 * users-doc read there used to refire on every typist's presence heartbeat.
 * The avatar still goes through the viewer's lens — `canSee` only reads
 * `subject._id`/`subject.visibility`, both of which a synthetic subject built
 * from the row supplies, so this reuses the one real privacy check in
 * `visibility.ts` rather than re-deriving it.
 */
function typistOf(lens: any, row: any) {
  const subject = { _id: row.userId, visibility: { avatar: row.avatarVisibility } };
  return {
    _id: row.userId,
    username: "",
    name: row.userName ?? "",
    avatarStorageId: lens.canSee(subject, "avatar")
      ? row.avatarStorageId
      : undefined,
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

    const user = await ctx.db.get(userId);
    const stamp = {
      userName: user?.name ?? user?.username ?? "",
      avatarStorageId: user?.avatarStorageId,
      avatarVisibility: user?.visibility?.avatar,
    };

    if (existing) {
      await ctx.db.patch(existing._id, { updatedAt: Date.now(), ...stamp });
    } else {
      await ctx.db.insert("typingIndicators", {
        roomId,
        userId,
        updatedAt: Date.now(),
        ...stamp,
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
        .withIndex("by_room_user", (q) => q.eq("roomId", m.roomId))
        .collect();

      const active = indicators.filter(
        (t) =>
          t.userId.toString() !== userId.toString() &&
          now - t.updatedAt < TYPING_TTL_MS
      );

      if (active.length > 0) {
        // Legacy rows written a moment before this field existed have no
        // `userName` yet — they age out of the TTL within seconds, same as
        // any other stale row, rather than being resolved with a users read.
        const names = active
          .map((t) => t.userName)
          .filter((n): n is string => Boolean(n));
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
      .withIndex("by_room_user", (q) => q.eq("roomId", roomId))
      .collect();

    // Filter out stale entries and self
    const active = indicators.filter(
      (t) =>
        t.userId.toString() !== currentUserId.toString() &&
        now - t.updatedAt < TYPING_TTL_MS
    );

    const lens = await lensFor(ctx, currentUserId);
    // Legacy rows written a moment before this field existed have no
    // `userName` yet — they age out of the TTL within seconds, same as any
    // other stale row, rather than being resolved with a users read.
    return active
      .filter((t) => t.userName != null)
      .map((t) => typistOf(lens, t));
  },
});
