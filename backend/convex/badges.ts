import { isReleasedToRecipient } from "./childGuard";
import { resolveMute } from "./mute";

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
  // The room's `lastMessageTime`, when the caller already holds the room.
  // Every path that inserts a message bumps it (`sendCore`, `forwardToRoom`,
  // the friend-request transcript, the diagnostics log) and the delete
  // fan-out repairs it, so a cursor at or past it proves there is nothing
  // newer to count — and the scan below is skipped. `listUserRooms` runs this
  // once per room the viewer is in, on every message in ANY of them; nearly
  // all of those rooms are quiet at that moment, and this is what stops each
  // quiet one from costing an index scan apiece every time somebody types
  // somewhere else.
  lastMessageTime?: number | null,
): Promise<{ count: number; capped: boolean; hasMention: boolean }> {
  const cursor = lastReadAt ?? 0;
  if (lastMessageTime != null && lastMessageTime <= cursor) {
    return { count: 0, capped: false, hasMention: false };
  }
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
 *
 * A room whose `muteBadges` is live is skipped entirely — not counted with a
 * zero, not listed in `perRoom`. That is what the second mute switch DOES:
 * this function is the app-icon number, so dropping the room here is the whole
 * mechanism. Note the asymmetry with `muteNotifications`, which is enforced in
 * `push.sendAlert` and has no effect at all on this arithmetic: someone who
 * silenced the banner but kept their counts still gets every one of those
 * unread messages added up here, and `notifications.sendMessagePush` sends
 * them a silent push carrying the new total so their icon moves without their
 * phone making a sound.
 *
 * Resolved lazily against `Date.now()`, so a mute that lapsed a minute ago
 * puts its room straight back into the count with no sweep having run — see
 * `mute.ts`.
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

  const now = Date.now();
  const perRoom: Array<{ roomId: any; count: number }> = [];
  let unread = 0;
  for (const m of memberships) {
    if (resolveMute(m, now).badges) continue;
    const room = await ctx.db.get(m.roomId);
    if (!room) continue;
    const { count } = await unreadForRoom(
      ctx,
      m.roomId,
      userId,
      m.lastReadAt,
      room.lastMessageTime,
    );
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

// `badgeSnapshot` used to live here: a batched internalQuery the push actions
// called before building each recipient's payload. `push._loadAlertTargets`
// now calls `badgeTotalFor` directly as part of the one query it already makes
// for devices and read cursors, so the separate round trip has no reason to
// exist.
