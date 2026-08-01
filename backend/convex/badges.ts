import { internalQuery } from "./_generated/server";
import { v } from "convex/values";
import { isReleasedToRecipient } from "./childGuard";

/**
 * Per-room unread counts and the single "needs attention" number that drives
 * the OS app-icon badge.
 *
 * Lives in its own file because both `rooms.listUserRooms` (which surfaces the
 * per-room count to the client) and `notifications.*` (which stamps an
 * absolute `ios_badgeCount` into every push) need identical arithmetic, and
 * neither module is a natural owner. Divergence between the two would show up
 * as a room list and an app icon that disagree.
 */

/**
 * Hard ceiling on how many unread rows we'll count in one room. The client
 * renders "99+" past this. Bounds the read set so a room someone abandoned
 * six months ago can't turn a cheap subscription into a full table scan.
 */
export const UNREAD_CAP = 99;

/**
 * Unread count for one room, given the caller's read cursor.
 *
 * Messages the user sent themselves never count — otherwise sending a message
 * would badge your own device.
 *
 * [hasMention] rides along because the rows it needs are the rows already in
 * hand: "was I named in anything I haven't read" is a filter over `fresh`, not
 * a second query. That is what makes an `@` marker in the room list free, and
 * it is why the alternative — a counter on `roomMembers` — was not taken: that
 * table is read by three reactive queries, so a per-send write there would fan
 * a subscription storm out across every member of the room.
 *
 * One documented limit: only `UNREAD_CAP + 1` rows are ever read, so a mention
 * buried under more than 99 unread messages is not seen. The count already
 * renders as "99+" at that point, so the room is shouting either way.
 */
export async function unreadForRoom(
  ctx: any,
  roomId: any,
  userId: any,
  lastReadAt: number | undefined | null,
): Promise<{ count: number; capped: boolean; hasMention: boolean }> {
  const cursor = lastReadAt ?? 0;
  const rows = await ctx.db
    .query("messages")
    .withIndex("by_room_time", (q: any) =>
      q.eq("roomId", roomId).gt("createdAt", cursor),
    )
    .take(UNREAD_CAP + 1);

  const mine = userId.toString();
  const fresh = rows.filter((r: any) => r.userId.toString() !== mine);
  const hasMention = fresh.some(
    (r: any) =>
      r.mentionsEveryone === true ||
      (r.mentions ?? []).some((m: any) => m.userId.toString() === mine),
  );
  return {
    count: Math.min(fresh.length, UNREAD_CAP),
    capped: rows.length > UNREAD_CAP,
    hasMention,
  };
}

/**
 * Everything the badge aggregates for one user: unread messages across every
 * room they're in, plus friend/direct requests sitting in their queue.
 *
 * The request half mirrors `friends.listIncomingDirectRequests` exactly —
 * including the `isReleasedToRecipient` gate, so a supervised request a
 * guardian hasn't released yet stays invisible in the badge too. Leaking its
 * existence via a badge increment would defeat the whole hold.
 */
export async function badgeTotalFor(
  ctx: any,
  userId: any,
): Promise<{
  total: number;
  perRoom: Array<{ roomId: any; count: number }>;
}> {
  const memberships = await ctx.db
    .query("roomMembers")
    .withIndex("by_user", (q: any) => q.eq("userId", userId))
    .collect();

  const perRoom: Array<{ roomId: any; count: number }> = [];
  let unread = 0;
  for (const m of memberships) {
    const { count } = await unreadForRoom(ctx, m.roomId, userId, m.lastReadAt);
    if (count > 0) {
      perRoom.push({ roomId: m.roomId, count });
      unread += count;
    }
  }

  const friendRows = await ctx.db
    .query("friendships")
    .withIndex("by_friend", (q: any) => q.eq("friendId", userId))
    .collect();
  const requests = friendRows.filter(
    (f: any) => f.status === "pending" && isReleasedToRecipient(f.stage),
  ).length;

  return { total: unread + requests, perRoom };
}

/**
 * Absolute badge value per user, for stamping into push payloads.
 *
 * Actions can't read the database directly, so `notifications.*` reaches this
 * through `ctx.runQuery` before building each recipient's payload.
 */
export const badgeSnapshot = internalQuery({
  args: { userIds: v.array(v.id("users")) },
  handler: async (ctx, { userIds }) => {
    const out: Record<string, number> = {};
    for (const userId of userIds) {
      const { total } = await badgeTotalFor(ctx, userId);
      out[userId.toString()] = total;
    }
    return out;
  },
});
