import { mutation, query } from "./functions";
import { v } from "convex/values";
import { lensFor } from "./visibility";

const TYPING_TTL_MS = 8000; // safety net — clearTyping fires after 3s inactivity, heartbeat every 2s

/**
 * How stale a typing row must be before a heartbeat actually rewrites it.
 *
 * The client beats every 2s while a key is moving, and each beat used to patch
 * the row unconditionally. That patch is not a cheap write: it re-fires
 * `getTypingUsers` for everyone in the room AND `getTypingForUser` — a global,
 * whole-session subscription that walks every room the viewer is in — for every
 * member. Four people typing at once meant two writes a second, each fanning
 * out across the room, on the machine already struggling to serve their
 * messages. Typing indicators are the least important thing on the screen and
 * they were among the loudest things on the wire.
 *
 * Skipping the write while the row is fresh makes most beats pure reads, at no
 * cost to what anyone sees: the indicator is driven by `TYPING_TTL_MS`, so all
 * that matters is that the row is rewritten comfortably before it ages out.
 * At a 2s beat this halves the writes and leaves a 4s margin — even a client
 * that misses a beat entirely refreshes at 6s, still inside the 8s window.
 *
 * Keep this comfortably below [TYPING_TTL_MS], for the same reason
 * `PRESENCE_WRITE_INTERVAL_MS` sits below `PRESENCE_OFFLINE_MS`: cross them and
 * a user who is actively typing starts flickering out of their own indicator.
 */
const TYPING_REFRESH_MS = 4000;

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

    const now = Date.now();

    // Still fresh — the row already says "typing" and will keep saying it for
    // seconds yet. Returning here skips the users read below as well as the
    // write, so a suppressed beat costs one indexed lookup and nothing else.
    if (existing && now - existing.updatedAt < TYPING_REFRESH_MS) return;

    // Denormalized onto the row so neither typing query has to read the
    // typist's `users` document — see `typistOf`. Read here, in a mutation,
    // where a read creates no subscription.
    const user = await ctx.db.get(userId);
    const stamp = {
      userName: user?.name ?? user?.username ?? "",
      avatarStorageId: user?.avatarStorageId,
      avatarVisibility: user?.visibility?.avatar,
    };

    if (existing) {
      await ctx.db.patch(existing._id, { updatedAt: now, ...stamp });
    } else {
      await ctx.db.insert("typingIndicators", {
        roomId,
        userId,
        updatedAt: now,
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
