import { mutation, query } from "./functions";
import { v } from "convex/values";
import { sanitizeViewOnce } from "./messages";

/**
 * Ceiling on pins per room.
 *
 * Enforced here and not in the client because it is not a UI nicety: this is
 * the ceiling on how large `listForRoom`'s payload can get, and that payload is
 * pushed to every member of the room on every change. A client-side cap is not
 * a cap.
 */
const MAX_PINS_PER_ROOM = 50;

export const pin = mutation({
  args: {
    messageId: v.id("messages"),
    userId: v.id("users"),
  },
  handler: async (ctx, { messageId, userId }) => {
    const msg = await ctx.db.get(messageId);
    if (!msg) throw new Error("MESSAGE_NOT_FOUND");

    // Any member may pin, mirroring `rooms:updateRoom` ("any member can
    // update"). Owner-only would be unusable: `roomMembers.role` is fixed at
    // join time with no promote/demote mutation anywhere, so a room whose owner
    // left could never be pinned in again — and in a DM only the initiator is
    // ever "owner", which would leave one side of every DM locked out.
    const membership = await ctx.db
      .query("roomMembers")
      .withIndex("by_room_user", (q) =>
        q.eq("roomId", msg.roomId).eq("userId", userId)
      )
      .first();
    if (!membership) throw new Error("NOT_A_MEMBER");

    // Idempotent, like `reactions:addReaction`. Mutations are serializable, so
    // a racing second pin loses its OCC check and re-runs this probe rather
    // than inserting a twin.
    const existing = await ctx.db
      .query("pinnedMessages")
      .withIndex("by_room_message", (q) =>
        q.eq("roomId", msg.roomId).eq("messageId", messageId)
      )
      .first();
    if (existing) return existing._id;

    // `take(MAX)` rather than `collect()`: this only has to answer "are we at
    // the cap", and collecting an unbounded set to measure it is the thing the
    // cap exists to prevent.
    const held = await ctx.db
      .query("pinnedMessages")
      .withIndex("by_room_message", (q) => q.eq("roomId", msg.roomId))
      .take(MAX_PINS_PER_ROOM);
    if (held.length >= MAX_PINS_PER_ROOM) throw new Error("PIN_LIMIT_REACHED");

    return await ctx.db.insert("pinnedMessages", {
      // Server-derived, never an argument. This is what makes a cross-room pin
      // unrepresentable rather than merely rejected.
      roomId: msg.roomId,
      messageId,
      userId,
      pinnedAt: Date.now(),
    });
  },
});

export const unpin = mutation({
  args: {
    messageId: v.id("messages"),
    userId: v.id("users"),
  },
  handler: async (ctx, { messageId, userId }) => {
    const msg = await ctx.db.get(messageId);
    // The message is already gone, so `removeMessageAndFanout` has already
    // dropped its pin. Silent rather than a throw: the banner is one
    // subscription frame behind at all times, so a tap on a pin that expired
    // mid-gesture is ordinary, not an error.
    if (!msg) return;

    // `reactions:removeReaction` needs no membership check because it can only
    // ever remove the caller's own row. This removes shared room state, so a
    // non-member must not be able to strip a room's pins.
    const membership = await ctx.db
      .query("roomMembers")
      .withIndex("by_room_user", (q) =>
        q.eq("roomId", msg.roomId).eq("userId", userId)
      )
      .first();
    if (!membership) throw new Error("NOT_A_MEMBER");

    // `collect` rather than `first`: one row is the invariant, but deleting
    // every match makes this converge even if that invariant ever breaks.
    const rows = await ctx.db
      .query("pinnedMessages")
      .withIndex("by_room_message", (q) =>
        q.eq("roomId", msg.roomId).eq("messageId", messageId)
      )
      .collect();
    for (const row of rows) await ctx.db.delete(row._id);
  },
});

/**
 * Every pinned message in a room, oldest message first.
 *
 * Returns the full message document, not just an id. A pin's whole purpose is
 * to reach something that has scrolled away, so a pinned message is almost
 * always outside the 100 the client holds — ids alone would mean a fetch per
 * pin on every room open, with no liveness and a loading state in the banner.
 *
 * The cost of that is this subscription refiring whenever a pinned document is
 * patched. In practice that is rare: only `messages.editMessage` patches a
 * message's own row (inside its 15-minute window), and the other patches a
 * message receives land on its *children*, not on it. When it does fire it
 * re-sends at most MAX_PINS_PER_ROOM rows for one room, not a transcript —
 * and an edited pinned message updating in the banner is the behaviour a
 * reader would call correct anyway.
 *
 * Deliberately does NOT check room membership. Reading `roomMembers` from a
 * subscribed query makes it refire on every `markRoomRead` patch — the cascade
 * `messages:getThreadPage` documents. Exposure is unchanged either way: this is
 * keyed by room id exactly like `messages:list`, and returns a strict subset of
 * what that already hands out.
 */
export const listForRoom = query({
  identityArg: "viewerUserId" as const,
  args: {
    roomId: v.id("rooms"),
    // Only used to tell this viewer whether they personally opened a pinned
    // view-once message. Optional so already-shipped clients keep working.
    viewerUserId: v.optional(v.id("users")),
  },
  handler: async (ctx, { roomId, viewerUserId }) => {
    const rows = await ctx.db
      .query("pinnedMessages")
      .withIndex("by_room_message", (q) => q.eq("roomId", roomId))
      .collect();

    const resolved = await Promise.all(
      rows.map(async (row) => {
        const msg = await ctx.db.get(row.messageId);
        // Defensive. `removeMessageAndFanout` drops the pin with the message,
        // so a dangling row means that path was bypassed — return nothing
        // rather than a pin the client can neither render nor clear.
        if (!msg) return null;
        // Mandatory, not optional. Without it this becomes the one read path
        // that hands out a view-once mediaStorageId.
        const safe = await sanitizeViewOnce(ctx, msg, viewerUserId);
        return {
          pinnedAt: row.pinnedAt,
          pinnedBy: row.userId,
          message: safe,
        };
      })
    );

    // Sorted by when the message was SENT, not when it was pinned: the banner
    // and the transcript have to agree on order, or cycling through pins would
    // walk the room in an order the reader can't see. Done in JS because the
    // set is capped at 50 — an index on pinnedAt would cost a write and give
    // the wrong order anyway.
    return resolved
      .filter((p): p is NonNullable<typeof p> => p !== null)
      .sort((a, b) => a.message.createdAt - b.message.createdAt);
  },
});
