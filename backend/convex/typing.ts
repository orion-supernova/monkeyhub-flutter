import { mutation, query } from "./functions";
import { v } from "convex/values";
import { canSeeAs } from "./visibilityPoint";
import { canReadRoom } from "./roomAccess";
import { copiesOn, nameResolver } from "./profileCopyGate";

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
function typistOf(canSeeAvatar: boolean, row: any, name: string, face: any) {
  return {
    _id: row.userId,
    username: "",
    name,
    // When this indicator stops being true, by the server's clock. A query
    // that compares against `Date.now()` is cached until the table changes,
    // not until time passes, so a typist whose phone died mid-word kept
    // "typing" in every subscription, and a client opening the room minutes
    // later was served that cached answer. The client hides the typist once
    // this passes (see `ChatRepository.typingIn`). Old builds ignore it.
    typingUntil: row.updatedAt + TYPING_TTL_MS,
    avatarStorageId: canSeeAvatar ? face.avatarStorageId : undefined,
  };
}

/** Most live typists one room read returns; a room never has this many at once. */
const MAX_LIVE_TYPISTS = 20;
/** Most rooms one `getTypingForUser` call may watch via `roomIds`. */
export const TYPING_ROOM_IDS_CAP = 30;

/**
 * The room's rows that are still true, read as an index RANGE so expired rows
 * (people who stopped typing long ago, and rows `clearTyping` zeroed) are
 * outside what the subscription reads at all, instead of being collected and
 * filtered. Costs ~one doc per live typist, not one per person who ever typed.
 */
async function liveTypingRows(ctx: any, roomId: any, now: number) {
  return await ctx.db
    .query("typingIndicators")
    .withIndex("by_room_updated", (q: any) =>
      q.eq("roomId", roomId).gt("updatedAt", now - TYPING_TTL_MS),
    )
    .take(MAX_LIVE_TYPISTS);
}

/**
 * A typist's avatar and its visibility level: the profile row (a point read,
 * and profiles rarely change, so safe in a subscription), else the copy on the
 * typing row while it is written. Never a `users` read.
 */
async function faceOf(ctx: any, row: any) {
  const profile = await ctx.db
    .query("profiles")
    .withIndex("by_user", (q: any) => q.eq("userId", row.userId))
    .first();
  if (profile) {
    return { avatarStorageId: profile.avatarStorageId, level: profile.avatarLevel };
  }
  return { avatarStorageId: row.avatarStorageId, level: row.avatarVisibility };
}

export const setTyping = mutation({
  args: {
    roomId: v.id("rooms"),
    userId: v.id("users"),
  },
  handler: async (ctx, { roomId, userId }) => {
    if (!(await canReadRoom(ctx, roomId, userId))) return;
    const existing = await ctx.db
      .query("typingIndicators")
      .withIndex("by_room_user", (q) => q.eq("roomId", roomId).eq("userId", userId))
      .first();

    const now = Date.now();

    // Still fresh — the row already says "typing" and will keep saying it for
    // seconds yet. Returning here skips the users read below as well as the
    // write, so a suppressed beat costs one indexed lookup and nothing else.
    if (
      existing &&
      now - (existing.writtenAt ?? existing.updatedAt) < TYPING_REFRESH_MS
    ) {
      return;
    }

    // Denormalized onto the row so neither typing query has to read the
    // typist's `users` document — see `typistOf`. Read here, in a mutation,
    // where a read creates no subscription.
    const user = await ctx.db.get(userId);
    // Only while the copies are written (PROFILE_COPIES); the readers resolve
    // name and face through the profile.
    const stamp = copiesOn()
      ? {
          userName: user?.name ?? user?.username ?? "",
          avatarStorageId: user?.avatarStorageId,
          avatarVisibility: user?.visibility?.avatar,
        }
      : {};

    if (existing) {
      await ctx.db.patch(existing._id, { updatedAt: now, writtenAt: now, ...stamp });
    } else {
      await ctx.db.insert("typingIndicators", {
        roomId,
        userId,
        updatedAt: now,
        writtenAt: now,
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
    // Hidden, not deleted: an absent row let the next `setTyping` skip the
    // refresh throttle, so a set/clear loop wrote on every call. `writtenAt`
    // is left alone so the throttle still counts the last real write. Zeroed
    // and idle rows are swept after a day (`retention.gcIdleTyping`), so the
    // table no longer keeps a row for everyone who ever typed.
    if (existing && existing.updatedAt !== 0) {
      await ctx.db.patch(existing._id, { updatedAt: 0 });
    }
  },
});

/// Returns { roomId: [typerName, …] } for all rooms the user belongs to.
/// A single subscription gives live typing state for the whole room list.
///
/// With `roomId` it reads that one room only (still keyed by room id, empty
/// when the user is not in it or nobody else is typing), so a screen that shows
/// one conversation does not subscribe to every room of the user. Without it
/// the old whole-session behaviour stays, for app builds that do not send it.
///
/// Intentionally still plain names, not the richer `typistOf` shape: the room
/// list only renders a label, and changing this to objects would garble the
/// typing text on every app build already in users' hands. The in-room
/// indicator, which does need avatars, uses `getTypingUsers` below.
export const getTypingForUser = query({
  args: {
    userId: v.id("users"),
    roomId: v.optional(v.id("rooms")),
    /**
     * Answer `{ rooms, until }` instead of the bare map: `until[roomId]` is
     * when that room's newest indicator expires, for the same reason as
     * `typingUntil` in `getTypingUsers`. Opt-in, because builds already in
     * people's hands read every key of the bare map as a room.
     */
    withUntil: v.optional(v.boolean()),
    /**
     * The rooms on screen (capped at [TYPING_ROOM_IDS_CAP]). When given, access
     * is one point read per room and nothing else is read: no scan of the
     * viewer's `roomMembers` rows, which every read/delivery/pin/mute write
     * would otherwise re-run. Absent = the old whole-session scan, for builds
     * that do not send it.
     */
    roomIds: v.optional(v.array(v.id("rooms"))),
  },
  handler: async (ctx, { userId, roomId, withUntil, roomIds }) => {
    const now = Date.now();
    // Access through `roomAccess` (a churn-free row per membership), never a
    // `roomMembers` scan: those rows are rewritten by roster changes, and the
    // legacy whole-session branch below used to re-run on every one of them.
    const memberships: { roomId: any }[] = [];
    if (!roomIds) {
      if (roomId) {
        if (await canReadRoom(ctx, roomId, userId)) memberships.push({ roomId });
      } else {
        const grants = await ctx.db
          .query("roomAccess")
          .withIndex("by_user", (q) => q.eq("userId", userId))
          .collect();
        for (const g of grants) memberships.push({ roomId: g.roomId });
      }
    }

    if (roomIds) {
      const seen = new Set<string>();
      for (const id of roomIds.slice(0, TYPING_ROOM_IDS_CAP)) {
        if (seen.has(id.toString())) continue;
        seen.add(id.toString());
        if (await canReadRoom(ctx, id, userId)) memberships.push({ roomId: id });
      }
    }

    const result: Record<string, string[]> = {};
    const until: Record<string, number> = {};
    // One profile lookup per distinct typist across every room.
    const nameFor = nameResolver(ctx);
    for (const m of memberships) {
      const indicators = await liveTypingRows(ctx, m.roomId, now);

      const active = indicators.filter(
        (t: any) => t.userId.toString() !== userId.toString(),
      );

      if (active.length > 0) {
        // Legacy rows written a moment before this field existed have no
        // `userName` yet — they age out of the TTL within seconds, same as
        // any other stale row, rather than being resolved with a users read.
        const names = (
          await Promise.all(active.map((t: any) => nameFor(t.userId, t.userName)))
        ).filter((n): n is string => Boolean(n));
        if (names.length > 0) {
          result[m.roomId.toString()] = names;
          until[m.roomId.toString()] =
            Math.max(...active.map((t: any) => t.updatedAt)) + TYPING_TTL_MS;
        }
      }
    }
    return withUntil ? { rooms: result, until } : result;
  },
});

export const getTypingUsers = query({
  args: { roomId: v.id("rooms"), currentUserId: v.id("users") },
  handler: async (ctx, { roomId, currentUserId, userId }) => {
    if (!(await canReadRoom(ctx, roomId, userId))) return [];
    const now = Date.now();
    const indicators = await liveTypingRows(ctx, roomId, now);

    // Self is dropped; expired rows were never read (see `liveTypingRows`).
    const active = indicators.filter(
      (t: any) => t.userId.toString() !== currentUserId.toString(),
    );

    // Legacy rows written a moment before this field existed have no
    // `userName` yet — they age out of the TTL within seconds, same as any
    // other stale row, rather than being resolved with a users read.
    const nameFor = nameResolver(ctx);
    const typists = await Promise.all(
      active.map(async (t: any) => {
        const name = await nameFor(t.userId, t.userName);
        // A deleted (or unresolvable) typist is not shown.
        if (name === "") return null;
        const face = await faceOf(ctx, t);
        // Point probes for the 1-2 typists, not `lensFor`'s scan of every
        // friendship the viewer has.
        const canSeeAvatar = await canSeeAs(
          ctx,
          currentUserId,
          t.userId,
          face.level,
          "avatar",
        );
        return typistOf(canSeeAvatar, t, name, face);
      }),
    );
    return typists.filter((x) => x !== null);
  },
});
