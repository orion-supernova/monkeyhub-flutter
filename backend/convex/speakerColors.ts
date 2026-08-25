import { mutation, query } from "./functions";
import { v } from "convex/values";

/**
 * Manual per-speaker colour choices — "make jun the teal one".
 *
 * Colours are normally DERIVED on the client and stored nowhere: a hash of the
 * user id picks a palette slot, collisions resolve in join order, and every
 * device arrives at the same answer without anyone writing anything down. This
 * file is only for the exceptions, so most readers and most rooms have no rows
 * here at all.
 *
 * Two properties are the whole point, and both are easy to lose:
 *
 *   * **A write reaches nobody else.** See the `speakerColors` comment in
 *     schema.ts. Every read below is scoped to one `viewerId`, so a Convex
 *     subscription to [mine] is invalidated by that reader's own writes and by
 *     nothing else — no other member's device does any work when somebody picks
 *     a colour. Putting this on `roomMembers` instead would have re-run
 *     `rooms:getMembers` for the entire room.
 *
 *   * **There is exactly ONE subscription for the whole app**, not one per
 *     room: [mine] returns every override this reader holds, across every room,
 *     because the set is tiny by construction (see [MAX_OVERRIDES_PER_ROOM])
 *     and because a per-room subscription would be a second live query opened
 *     and closed on every room entry for a feature almost nobody uses.
 */

/**
 * Ceiling on overrides per reader per room.
 *
 * The palette has twelve slots, so twelve pins is the point past which there is
 * nothing left to express — a thirteenth would be pinning somebody onto a
 * colour already spoken for, which the client allows but which stops being a
 * *choice* once every slot is taken. Bounding it here is also what lets [mine]
 * be one unpaginated app-wide read: rooms × 12 is a set a phone can hold.
 */
const MAX_OVERRIDES_PER_ROOM = 12;

/** Palette size — must match `kSpeakerSlotCount` in lib/theme/speaker_colors.dart. */
const SLOT_COUNT = 12;

/**
 * Every override this reader holds, across every room.
 *
 * Shaped as `{ [roomId]: { [subjectId]: slot } }` rather than as a flat list
 * because that is the shape the client indexes into per bubble — a list would
 * be rebuilt into exactly this map on arrival, once per delivery.
 */
export const mine = query({
  args: { viewerId: v.id("users") },
  handler: async (ctx, { viewerId }) => {
    const rows = await ctx.db
      .query("speakerColors")
      .withIndex("by_viewer_room_subject", (q) => q.eq("viewerId", viewerId))
      .collect();
    const out: Record<string, Record<string, number>> = {};
    for (const r of rows) {
      const room = r.roomId.toString();
      (out[room] ??= {})[r.subjectId.toString()] = r.slot;
    }
    return out;
  },
});

/**
 * Pins [subjectId] to [slot] for [viewerId] in [roomId], or clears the pin when
 * [slot] is null — one mutation rather than a set/clear pair, because "back to
 * automatic" is a value of the same control rather than a different action.
 *
 * Deliberately permissive about collisions: two people pinned to one slot is a
 * choice the client warns about and honours. Refusing it here would mean a
 * mutation that silently disagrees with the picker the user is looking at.
 */
export const setSlot = mutation({
  args: {
    viewerId: v.id("users"),
    roomId: v.id("rooms"),
    subjectId: v.id("users"),
    slot: v.union(v.number(), v.null()),
  },
  handler: async (ctx, { viewerId, roomId, subjectId, slot }) => {
    // Membership of the READER, not of the subject. Pinning a colour on someone
    // who has since left is harmless — the transcript still carries their old
    // messages, and that is exactly when a reader wants to tell them apart —
    // but a non-member minting rows against a room they cannot open is just an
    // unbounded write path with no UI behind it.
    const membership = await ctx.db
      .query("roomMembers")
      .withIndex("by_room_user", (q) =>
        q.eq("roomId", roomId).eq("userId", viewerId),
      )
      .first();
    if (!membership) throw new Error("NOT_A_MEMBER");

    if (slot !== null && (!Number.isInteger(slot) || slot < 0 || slot >= SLOT_COUNT)) {
      throw new Error("BAD_SLOT");
    }

    const existing = await ctx.db
      .query("speakerColors")
      .withIndex("by_viewer_room_subject", (q) =>
        q.eq("viewerId", viewerId).eq("roomId", roomId).eq("subjectId", subjectId),
      )
      .first();

    if (slot === null) {
      // Clearing an override that was never set is a no-op, not an error: the
      // picker's AUTO chip is always tappable, including when it is already the
      // answer.
      if (existing) await ctx.db.delete(existing._id);
      return null;
    }

    if (existing) {
      // Same slot re-picked — return without a write, so re-tapping the swatch
      // you are already on does not invalidate this reader's subscription and
      // re-deliver their whole override set for nothing.
      if (existing.slot === slot) return null;
      await ctx.db.patch(existing._id, { slot });
      return null;
    }

    // `take(MAX)` rather than `collect()`, for the reason `bookmarks.save`
    // gives: this only has to answer "are we at the cap", and collecting an
    // unbounded set to measure it is what the cap is for.
    const held = await ctx.db
      .query("speakerColors")
      .withIndex("by_viewer_room_subject", (q) =>
        q.eq("viewerId", viewerId).eq("roomId", roomId),
      )
      .take(MAX_OVERRIDES_PER_ROOM);
    if (held.length >= MAX_OVERRIDES_PER_ROOM) throw new Error("OVERRIDE_LIMIT");

    await ctx.db.insert("speakerColors", { viewerId, roomId, subjectId, slot });
    return null;
  },
});

/**
 * Drops every override [viewerId] holds in [roomId] — the picker's "reset the
 * whole room" affordance, and cheaper than the client firing one [setSlot] per
 * pinned member and invalidating its own subscription that many times.
 */
export const clearRoom = mutation({
  args: { viewerId: v.id("users"), roomId: v.id("rooms") },
  handler: async (ctx, { viewerId, roomId }) => {
    const rows = await ctx.db
      .query("speakerColors")
      .withIndex("by_viewer_room_subject", (q) =>
        q.eq("viewerId", viewerId).eq("roomId", roomId),
      )
      .collect();
    for (const r of rows) await ctx.db.delete(r._id);
    return null;
  },
});

/**
 * Both halves of one person's departure from one room, for
 * `roomAdmin.removeMembership`.
 *
 * The second half is the one that is easy to miss. Sweeping only the leaver's
 * OWN overrides leaves everyone else's pins ON them in place — rows naming
 * somebody who is no longer in the room, each still holding a palette slot shut
 * against whoever joins next.
 *
 * A plain helper rather than a Convex function, matching `roomCleanup`: callers
 * pass their own `ctx`.
 */
export async function purgeSpeakerColorsForMember(
  ctx: any,
  roomId: any,
  userId: any,
) {
  const theirs = await ctx.db
    .query("speakerColors")
    .withIndex("by_viewer_room_subject", (q: any) =>
      q.eq("viewerId", userId).eq("roomId", roomId),
    )
    .collect();
  for (const r of theirs) await ctx.db.delete(r._id);

  const aboutThem = await ctx.db
    .query("speakerColors")
    .withIndex("by_room_subject", (q: any) =>
      q.eq("roomId", roomId).eq("subjectId", userId),
    )
    .collect();
  for (const r of aboutThem) await ctx.db.delete(r._id);
}

/** Every override in a room, for `roomCleanup.wipeRoomContents`. */
export async function purgeSpeakerColorsForRoom(ctx: any, roomId: any) {
  const rows = await ctx.db
    .query("speakerColors")
    .withIndex("by_room_subject", (q: any) => q.eq("roomId", roomId))
    .collect();
  for (const r of rows) await ctx.db.delete(r._id);
}

/**
 * Every override this account is either side of, for `auth.purgeUser` — the
 * ones they set, and the ones other people set about them.
 */
export async function purgeSpeakerColorsForUser(ctx: any, userId: any) {
  const theirs = await ctx.db
    .query("speakerColors")
    .withIndex("by_viewer_room_subject", (q: any) => q.eq("viewerId", userId))
    .collect();
  for (const r of theirs) await ctx.db.delete(r._id);

  const aboutThem = await ctx.db
    .query("speakerColors")
    .withIndex("by_subject", (q: any) => q.eq("subjectId", userId))
    .collect();
  for (const r of aboutThem) await ctx.db.delete(r._id);
}
