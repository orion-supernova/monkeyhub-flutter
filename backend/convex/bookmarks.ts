import { mutation, query } from "./_generated/server";
import { v } from "convex/values";
import { sanitizeViewOnce } from "./messages";

/**
 * Per-reader message bookmarks — "SAVE" in the bubble menu, "Saved messages" in
 * room info.
 *
 * Deliberately NOT the `dm:self:<userId>` Saved Messages room, which is a place
 * you forward a copy to. Nothing here copies anything: a bookmark marks a
 * message where it already is, for one reader, so getting back to it also gets
 * you back to the conversation around it. See the `messageBookmarks` comment in
 * schema.ts for why the table is named the way it is.
 *
 * Structurally this is `pins.ts` with the audience narrowed from "the room" to
 * "one member", and most of that file's reasoning transfers verbatim. Where it
 * does not, the difference is called out below — those are the only interesting
 * lines in here.
 */

/**
 * Ceiling on bookmarks per reader per room.
 *
 * Same number as `MAX_PINS_PER_ROOM` and the same kind of reason, one step
 * softer: this payload goes to one person rather than to every member, but it
 * is still a subscription that re-sends whole message documents, and it is
 * still the thing that decides how tall the room-info section can get. That
 * section renders its rows in a plain Column — see `SavedMessagesSection` — and
 * this constant is what makes an unbounded-looking widget bounded in fact.
 */
const MAX_BOOKMARKS_PER_ROOM = 50;

export const save = mutation({
  args: {
    messageId: v.id("messages"),
    userId: v.id("users"),
  },
  handler: async (ctx, { messageId, userId }) => {
    const msg = await ctx.db.get(messageId);
    if (!msg) throw new Error("MESSAGE_NOT_FOUND");

    // Membership, not authorship: you save things other people said far more
    // often than your own. What it rules out is a non-member minting rows
    // against a room they cannot read — which matters more here than it does
    // for a pin, because `listForRoom` below does not re-check (see there).
    const membership = await ctx.db
      .query("roomMembers")
      .withIndex("by_room_user", (q) =>
        q.eq("roomId", msg.roomId).eq("userId", userId)
      )
      .first();
    if (!membership) throw new Error("NOT_A_MEMBER");

    // Idempotent, like `pins:pin` and `reactions:addReaction`. Mutations are
    // serializable, so a racing second save loses its OCC check and re-runs
    // this probe rather than inserting a twin.
    const existing = await ctx.db
      .query("messageBookmarks")
      .withIndex("by_room_user_message", (q) =>
        q.eq("roomId", msg.roomId).eq("userId", userId).eq("messageId", messageId)
      )
      .first();
    if (existing) return existing._id;

    // `take(MAX)` rather than `collect()`: this only has to answer "are we at
    // the cap", and collecting an unbounded set to measure it is the thing the
    // cap exists to prevent.
    const held = await ctx.db
      .query("messageBookmarks")
      .withIndex("by_room_user_message", (q) =>
        q.eq("roomId", msg.roomId).eq("userId", userId)
      )
      .take(MAX_BOOKMARKS_PER_ROOM);
    if (held.length >= MAX_BOOKMARKS_PER_ROOM) {
      throw new Error("SAVE_LIMIT_REACHED");
    }

    return await ctx.db.insert("messageBookmarks", {
      // Server-derived, never an argument — the same guarantee `pins:pin`
      // makes. A bookmark naming a room its message doesn't live in is
      // unrepresentable rather than merely rejected.
      roomId: msg.roomId,
      messageId,
      userId,
      savedAt: Date.now(),
    });
  },
});

export const unsave = mutation({
  args: {
    messageId: v.id("messages"),
    userId: v.id("users"),
  },
  handler: async (ctx, { messageId, userId }) => {
    const msg = await ctx.db.get(messageId);
    // The message is already gone, so `removeMessageAndFanout` has already
    // dropped its bookmarks. Silent rather than a throw, for the reason
    // `pins:unpin` gives: the list is one subscription frame behind at all
    // times, so unsaving something that expired mid-gesture is ordinary.
    if (!msg) return;

    // No membership check, and that is not an oversight — this is the
    // `reactions:removeReaction` case rather than the `pins:unpin` one. The
    // index range below is scoped to the caller's own `userId`, so there is no
    // shared state here to strip and nothing a non-member could reach that
    // isn't already theirs.
    //
    // `collect` rather than `first`: one row is the invariant, but deleting
    // every match makes this converge even if that invariant ever breaks.
    const rows = await ctx.db
      .query("messageBookmarks")
      .withIndex("by_room_user_message", (q) =>
        q.eq("roomId", msg.roomId).eq("userId", userId).eq("messageId", messageId)
      )
      .collect();
    for (const row of rows) await ctx.db.delete(row._id);
  },
});

/**
 * One reader's bookmarks in one room, most recently saved first.
 *
 * Returns whole message documents rather than ids, for the reason
 * `pins:listForRoom` gives: a saved message is almost always outside the 100
 * the client holds, so ids alone would mean a fetch per bookmark on every room
 * open, with no liveness and a loading state in the section.
 *
 * Ordered by `savedAt` descending, and pointedly NOT by `message.createdAt` the
 * way pins are. A pin has to agree with the transcript because the banner
 * cycles through the room in reading order; this is a personal shelf, and the
 * thing you reach for is the thing you put there last.
 *
 * ── On the missing membership check ────────────────────────────────────────
 *
 * Deliberately absent, exactly as in `pins:listForRoom`: reading `roomMembers`
 * from a subscribed query makes it refire on every `markRoomRead` patch, and
 * this one would re-resolve up to MAX_BOOKMARKS_PER_ROOM message documents each
 * time it did.
 *
 * That argument alone would be weaker here than it is there, because a pin list
 * is a strict subset of what `messages:list` already hands out for the same
 * room id, whereas this additionally says WHICH of those messages a named
 * person kept. What closes the gap is `rooms:leave`, which sweeps a departing
 * member's rows: someone who is not in the room has no rows here to return. So
 * the residue is "what did this member save", to a caller who already holds the
 * room's transcript and that member's user id — and in a deployment where
 * identity is a client-supplied argument throughout (see the note in feed.ts),
 * a membership read would not have bounded that anyway.
 */
export const listForRoom = query({
  args: {
    roomId: v.id("rooms"),
    userId: v.id("users"),
  },
  handler: async (ctx, { roomId, userId }) => {
    const rows = await ctx.db
      .query("messageBookmarks")
      .withIndex("by_room_user_message", (q) =>
        q.eq("roomId", roomId).eq("userId", userId)
      )
      .collect();

    const resolved = await Promise.all(
      rows.map(async (row) => {
        const msg = await ctx.db.get(row.messageId);
        // Defensive. `removeMessageAndFanout` drops the bookmark with the
        // message, so a dangling row means that path was bypassed — return
        // nothing rather than a row the client can neither render nor clear.
        if (!msg) return null;
        // Mandatory, not optional, for the reason `pins:listForRoom` states:
        // without it this becomes a read path that hands out a view-once
        // mediaStorageId. A burned view-once message keeps its row and its
        // ghost bubble, so this is a live case rather than a theoretical one.
        const safe = await sanitizeViewOnce(ctx, msg, userId);
        return { savedAt: row.savedAt, message: safe };
      })
    );

    // Sorted in JS because the set is capped at 50. An index on `savedAt` would
    // cost a write on every save to order a list this short.
    return resolved
      .filter((b): b is NonNullable<typeof b> => b !== null)
      .sort((a, b) => b.savedAt - a.savedAt);
  },
});
