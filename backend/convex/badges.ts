import {
  guardianPendingCount,
  isReleasedToRecipient,
} from "./childGuard";
import { resolveMute } from "./mute";
import { isTombstoned } from "./deletionCore";
import { computePendingCounts } from "./userDerivedCore";
import { stateBackfilled } from "./roomState";
import { roomUnread } from "./unread";

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
 * The unread-messages share of the badge, and the per-room breakdown. Isolated
 * so the read-cursor redesign can replace it without touching the rest.
 */
async function unreadBadgePart(
  ctx: any,
  userId: any,
): Promise<{ unread: number; perRoom: Array<{ roomId: any; count: number }> }> {
  // C1: one `roomUserState` row and one room doc per room, no message scans.
  const states = await ctx.db
    .query("roomUserState")
    .withIndex("by_user_archived", (q: any) => q.eq("userId", userId))
    .collect();

  const now = Date.now();
  const perRoom: Array<{ roomId: any; count: number }> = [];
  let unread = 0;
  for (const s of states) {
    if (resolveMute(s, now).badges) continue;
    const room = await ctx.db.get(s.roomId);
    // A room being deleted counts for nothing (row already in hand).
    if (!room || isTombstoned(room)) continue;
    const { count } = await roomUnread(ctx, room, s, now);
    if (count > 0) {
      perRoom.push({ roomId: s.roomId, count });
      unread += count;
    }
  }

  // Memberships the backfill has not reached keep the legacy arithmetic.
  if (!(await stateBackfilled(ctx))) {
    const have = new Set<string>(states.map((s: any) => s.roomId.toString()));
    const memberships = await ctx.db
      .query("roomMembers")
      .withIndex("by_user", (q: any) => q.eq("userId", userId))
      .collect();
    for (const m of memberships) {
      if (have.has(m.roomId.toString())) continue;
      if (resolveMute(m, now).badges) continue;
      const room = await ctx.db.get(m.roomId);
      if (!room || isTombstoned(room)) continue;
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
  }
  return { unread, perRoom };
}

/**
 * Pending friend requests and group invites released to this person (the same
 * `isReleasedToRecipient` gate as before). Reads the derived `userBadgeCounts`
 * row, kept by the `friendships`/`roomInvitations` write hooks; a user with no
 * row yet gets the scan (every friendship pointing at them) until the backfill
 * reaches them.
 */
async function pendingBadgePart(
  ctx: any,
  userId: any,
): Promise<{ requests: number; invites: number }> {
  const row = await ctx.db
    .query("userBadgeCounts")
    .withIndex("by_user", (q: any) => q.eq("userId", userId))
    .first();
  if (row) return { requests: row.requests, invites: row.invites };
  return await computePendingCounts(ctx.db, userId);
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
  const { unread, perRoom } = await unreadBadgePart(ctx, userId);
  const { requests, invites } = await pendingBadgePart(ctx, userId);

  // Anything waiting on this person AS A GUARDIAN.
  //
  // Without it the app icon was silent about the one category of push this
  // app sends that somebody else is blocked on. A parent who missed the
  // banner had nothing left telling them their child was waiting — the icon
  // said zero, and the icon is what people actually look at. One indexed
  // lookup for the ~everyone who has no children; see `guardianPendingCount`.
  const approvals = await guardianPendingCount(ctx, userId);

  return { total: unread + requests + invites + approvals, perRoom };
}

// `badgeSnapshot` used to live here: a batched internalQuery the push actions
// called before building each recipient's payload. `push._loadAlertTargets`
// now calls `badgeTotalFor` directly as part of the one query it already makes
// for devices and read cursors, so the separate round trip has no reason to
// exist.
