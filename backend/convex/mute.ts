/**
 * Per-room mute: two silences on one clock, and the arithmetic that says
 * whether either is still in force.
 *
 * Lives in its own file for the same reason `badges.ts` does: three unrelated
 * modules need the identical answer and none of them owns it. `push.ts` asks
 * before it sends, `badges.ts` asks before it counts, and `rooms.ts` asks on
 * behalf of the client. Divergence between any two of them is a user who
 * muted a room and still got buzzed by it.
 *
 * ── Why expiry is lazy rather than swept ───────────────────────────────────
 *
 * There is no cron for this, deliberately. `crons.ts` opens by noting that
 * every sweep is an index scan plus a write loop on a small self-hosted box,
 * and that the jobs there are backstops for paths that already clean up
 * inline. A mute sweep would be neither cheap nor a backstop:
 *
 *  - It would not make anything more correct. Every decision point — send this
 *    push, count this room, describe this state — already reads the membership
 *    row and can compare `mutedUntil` against the wall clock for free. That
 *    answer is exact to the millisecond. A sweep's answer is only as fresh as
 *    the last time it ran, so adding one would make expiry LESS accurate while
 *    costing more.
 *  - It would be actively expensive in the one way this schema avoids. Zeroing
 *    an expired mute is a write to `roomMembers`, which `badges.ts` explains is
 *    read by several reactive queries — so a sweep that expired fifty mutes at
 *    3am would fan a subscription storm out across every one of those members
 *    at once, to change nothing anybody could observe.
 *
 * The one thing lazy expiry does not give you is reactivity: a client sitting
 * open past its own `mutedUntil` sees no database change, so its `listUserRooms`
 * subscription does not re-fire. That is why the client re-resolves the same
 * arithmetic itself at render time (`lib/models/room_mute.dart`) rather than
 * trusting a boolean off the wire. Nothing about the mute's TRUTH depends on
 * the client doing so — the push path resolves against `Date.now()` at the
 * instant of sending, which is the only moment that matters.
 */

/**
 * "Always", stored as an instant rather than a null or a flag.
 *
 * This is 8_640_000_000_000_000 — the largest value `new Date()` accepts in JS
 * and the largest `DateTime.fromMillisecondsSinceEpoch` accepts in Dart (both
 * cap at ±100,000,000 days from the epoch), and comfortably inside float64's
 * exact-integer range, so it survives Convex's number encoding and the Dart
 * client unchanged. It is a real, orderable instant in the year 275760.
 *
 * The alternative — `mutedUntil: null` or `undefined` meaning "forever" — was
 * rejected on failure direction. Both encodings need every reader to
 * special-case the sentinel; the question is what a reader that FORGETS does.
 * With null-as-forever, a forgetful `now < mutedUntil` reads a permanent mute
 * as expired and the app starts buzzing about a chat the user silenced. With
 * this sentinel the same forgetful comparison says "still muted", which is the
 * answer the user asked for. A mute that fails safe is worth a magic number.
 */
export const MUTE_ALWAYS = 8640000000000000;

/** The three mute columns as they sit on a `roomMembers` document. */
export type MuteRow = {
  muteNotifications?: boolean;
  muteBadges?: boolean;
  mutedUntil?: number;
};

/** What is actually silenced right now. Both false when nothing is. */
export type ResolvedMute = {
  notifications: boolean;
  badges: boolean;
};

export const NOT_MUTED: ResolvedMute = { notifications: false, badges: false };

/**
 * What [row] silences at [now].
 *
 * `mutedUntil` is the single gate: absent means no mute was ever set, and a
 * value in the past means one lapsed. Neither case is cleaned up — an expired
 * mute is simply read as nothing, and the next `muteRoom` overwrites all three
 * columns anyway. That is what makes "re-mute an already-muted room" a plain
 * overwrite with no before-state to reason about.
 *
 * The two booleans are read independently and never imply each other, which is
 * the whole point: silencing notifications must leave the unread count
 * climbing, because "stop buzzing me" and "hide this from me entirely" are
 * different requests and the second is much stronger.
 *
 * Tolerates a null row so callers can pass a `.first()` result straight in —
 * someone who is not a member of the room has nothing muted.
 */
export function resolveMute(
  row: MuteRow | null | undefined,
  now: number,
): ResolvedMute {
  if (!row) return NOT_MUTED;
  const until = row.mutedUntil;
  if (until === undefined || until === null || now >= until) return NOT_MUTED;
  return {
    notifications: row.muteNotifications === true,
    badges: row.muteBadges === true,
  };
}
