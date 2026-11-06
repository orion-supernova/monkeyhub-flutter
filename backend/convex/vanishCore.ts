import { internal } from "./_generated/api";

/**
 * Vanish mode: the state machine, with no dependency on messages.ts (so
 * messages.ts, roomAdmin.ts and the deletion steps can import it without a
 * cycle). The public functions and the two job bodies live in vanish.ts.
 *
 * ## The idea in four lines
 *
 *  * A vanishing message is stamped `vanishUntil = createdAt + 24h` at send.
 *    Nothing else is written or scheduled by a send.
 *  * Each member has a "seen" cursor, `vanishSeenAt ?? joinedAt`. It only
 *    advances for reads the reader agreed to share (the client says so when it
 *    calls markRoomRead).
 *  * Everything at or below the lowest cursor was seen by everyone; one burn
 *    job per room deletes that range `afterSeen` seconds after it was reached.
 *  * One deadline job per room deletes whatever reached `vanishUntil`, then
 *    schedules itself for the oldest survivor.
 *
 * ## "Everyone it was sent to", per sender
 *
 * A message is not held by its own sender. Holding the lowest and the
 * second-lowest cursor is enough to answer that for every sender at once:
 * the message of anyone but the lowest reader waits for the lowest; the lowest
 * reader's own messages wait only for the second-lowest. So a DM where one
 * person never shares: their messages burn after the other reads them, the
 * other's messages wait the full 24 hours. A burn target is therefore a pair:
 * "everything up to `u1`, plus `who`'s own messages up to `u2`".
 *
 * ## Cost
 *
 * See the budget table in docs/design/swipe-up-fork.html. In short: a normal
 * room pays nothing (the client sends no `vanish` hint); a vanishing room's
 * read pays one vanishState read, plus one member range only when the reader
 * is one of the two cached lowest cursors.
 */

export const VANISH_TTL_MS = 24 * 60 * 60 * 1000;
export const DEFAULT_AFTER_SEEN_SECONDS = 10;
export const AFTER_SEEN_OPTIONS: readonly number[] = [10, 60, 3600];
/** Groups bigger than this never compute a floor: their messages keep the 24h clock. */
export const MEMBER_SCAN_CAP = 2000;

/** What the chat list and a lock-screen push say instead of the message. */
export const VANISH_PREVIEW = "Vanishing message";

export function isSecretRoom(room: any): boolean {
  return room?.type === "secret" || room?.type === "Chamber of Secrets";
}

/** A secret room whose lifetime counts from "seen" instead of "sent". */
export function isSeenClockRoom(room: any): boolean {
  return isSecretRoom(room) && room?.messageClock === "seen";
}

/** Messages sent here are stamped with `vanishUntil`. */
export function isVanishRoom(room: any): boolean {
  if (!room) return false;
  if (isSecretRoom(room)) return room.messageClock === "seen";
  return room.vanishMode === true;
}

/** Seconds of grace after everyone has seen a message. */
export function graceSecondsOf(room: any): number {
  if (isSecretRoom(room)) {
    return room.messageLifetime && room.messageLifetime > 0
      ? room.messageLifetime
      : DEFAULT_AFTER_SEEN_SECONDS;
  }
  return room?.vanishAfterSeen ?? DEFAULT_AFTER_SEEN_SECONDS;
}

/** `vanishUntil` for a message sent at [sentAt] into [room], or undefined. */
export function vanishUntilFor(room: any, sentAt: number): number | undefined {
  return isVanishRoom(room) ? sentAt + VANISH_TTL_MS : undefined;
}

/**
 * Past its promise. Queries drop these so a late job never lets an expired
 * message render. Rows without the field are never hidden.
 */
export function vanishExpired(m: { vanishUntil?: number }, now: number): boolean {
  return m.vanishUntil !== undefined && m.vanishUntil <= now;
}

export async function vanishStateOf(ctx: any, roomId: any) {
  return await ctx.db
    .query("vanishState")
    .withIndex("by_room", (q: any) => q.eq("roomId", roomId))
    .first();
}

/** Cancels a scheduled job, tolerating one that already ran or is gone. */
export async function cancelJob(ctx: any, id: any): Promise<void> {
  if (!id) return;
  try {
    await ctx.scheduler.cancel(id);
  } catch {
    // Already executed or never existed: nothing to cancel.
  }
}

/** The (re)armed deadline job: exactly one per room. */
async function armDeadline(ctx: any, state: any, at: number): Promise<void> {
  if (state.deadlineJobId) await cancelJob(ctx, state.deadlineJobId);
  const id = await ctx.scheduler.runAt(
    new Date(at),
    internal.vanish.vanishDeadline,
    { roomId: state.roomId, at },
  );
  await ctx.db.patch(state._id, { deadlineJobId: id, deadlineAt: at });
}

/**
 * Makes sure [room] has a vanishState row and a live deadline chain. Called
 * when vanish turns on and when a seen-clock secret room is made. Idempotent:
 * a second call changes nothing but `active`/`afterSeen`.
 */
export async function ensureVanishState(
  ctx: any,
  room: any,
  now: number,
): Promise<any> {
  const afterSeen = graceSecondsOf(room);
  let state = await vanishStateOf(ctx, room._id);
  if (state) {
    const patch: Record<string, unknown> = {};
    if (!state.active) patch.active = true;
    if (state.afterSeen !== afterSeen) patch.afterSeen = afterSeen;
    if (Object.keys(patch).length > 0) {
      await ctx.db.patch(state._id, patch);
      state = { ...state, ...patch };
    }
    if (!state.deadlineJobId) await armDeadline(ctx, state, now + VANISH_TTL_MS);
    return state;
  }
  const id = await ctx.db.insert("vanishState", {
    roomId: room._id,
    active: true,
    afterSeen,
    floor: 0,
  });
  state = await ctx.db.get(id);
  await armDeadline(ctx, state, now + VANISH_TTL_MS);
  return state;
}

/** A member's seen cursor. */
export function seenOf(m: { vanishSeenAt?: number; joinedAt: number }): number {
  return m.vanishSeenAt ?? m.joinedAt;
}

/** Rows the own-messages probe looks at before it gives up and says "maybe". */
const PROBE_ROWS = 10;

/**
 * Does the target range hold anything to delete? One probe for the range
 * everyone has seen, and a short look at the slowest reader's own range. When
 * the own range is small and holds none of theirs, `scannedThrough` records
 * that it was looked at (so the next probe starts after it). A full look with
 * no match answers "maybe" and lets the burn job do the real scan.
 */
async function burnable(
  ctx: any,
  state: any,
  target: { u1: number; who: any; u2: number },
): Promise<{ any: boolean; scannedThrough?: number }> {
  const first = await ctx.db
    .query("messages")
    .withIndex("by_room_vanish", (q: any) =>
      q.eq("roomId", state.roomId).gt("vanishUntil", 0).lte("vanishUntil", target.u1 + VANISH_TTL_MS),
    )
    .first();
  if (first) return { any: true };
  if (target.u2 <= target.u1) return { any: false };
  const from =
    state.sideWho?.toString() === target.who.toString()
      ? Math.max(target.u1, state.sideDone ?? 0)
      : target.u1;
  if (target.u2 <= from) return { any: false };
  const rows = await ctx.db
    .query("messages")
    .withIndex("by_room_vanish", (q: any) =>
      q
        .eq("roomId", state.roomId)
        .gt("vanishUntil", from + VANISH_TTL_MS)
        .lte("vanishUntil", target.u2 + VANISH_TTL_MS),
    )
    .take(PROBE_ROWS);
  if (rows.some((m: any) => m.userId.toString() === target.who.toString())) {
    return { any: true };
  }
  if (rows.length === PROBE_ROWS) return { any: true };
  return { any: false, scannedThrough: target.u2 };
}

/**
 * Re-derives the two lowest cursors from the members and queues a burn when
 * the answer moved. One member range read; one state patch; at most one job.
 *
 * [state] is the row the caller already read. Returns whether a burn was
 * queued or recorded.
 */
export async function recomputeFloor(
  ctx: any,
  state: any,
  now: number,
): Promise<boolean> {
  const members = await ctx.db
    .query("roomMembers")
    .withIndex("by_room_user", (q: any) => q.eq("roomId", state.roomId))
    .take(MEMBER_SCAN_CAP + 1);
  if (members.length > MEMBER_SCAN_CAP || members.length === 0) return false;
  // C1: a migrated member's vanish cursor is on `roomReceipts`; the roster row
  // answers only for memberships the backfill has not reached.
  const receipts = await ctx.db
    .query("roomReceipts")
    .withIndex("by_room_user", (q: any) => q.eq("roomId", state.roomId))
    .take(MEMBER_SCAN_CAP + 1);
  const receiptOfUser = new Map<string, any>(
    receipts.map((r: any) => [r.userId.toString(), r]),
  );

  const rows = members
    .map((m: any) => {
      const r = receiptOfUser.get(m.userId.toString());
      return {
        userId: m.userId,
        seen: Math.min(r ? r.vanishSeenAt : seenOf(m), now),
      };
    })
    .sort((a: any, b: any) =>
      a.seen !== b.seen ? a.seen - b.seen : a.userId.toString().localeCompare(b.userId.toString()),
    );
  const low = rows[0];
  const second = rows[1];
  const u1: number = low.seen;
  const who = low.userId;
  // Alone in the room: nobody it was sent to, so the lowest reader's own
  // messages are already "seen by everyone".
  const u2: number = second ? second.seen : now;

  const sameWho = state.slowestUserId?.toString() === who.toString();
  const advanced =
    u1 > state.floor ||
    (!sameWho && u2 > u1) ||
    u2 > (state.floor2 ?? 0);

  const patch: Record<string, unknown> = {
    slowestUserId: who,
    secondUserId: second ? second.userId : undefined,
    floor: Math.max(state.floor, u1),
    floor2: sameWho ? Math.max(state.floor2 ?? 0, u2) : u2,
  };

  if (advanced) {
    const target = { u1: Math.max(state.floor, u1), who, u2: Math.max(u2, u1) };
    if (state.burnUpTo === undefined) {
      // A job only when there is something for it to delete: the floor moves
      // on nearly every read by a holder, and most moves pass no messages
      // (the lowest reader's own messages, or none at all). Two indexed probes.
      const probe = await burnable(ctx, state, target);
      if (probe.scannedThrough !== undefined) {
        patch.sideWho = who;
        patch.sideDone = probe.scannedThrough;
      }
      if (!probe.any) {
        await ctx.db.patch(state._id, patch);
        return false;
      }
    }
    if (state.burnUpTo === undefined) {
      const burnAt = now + state.afterSeen * 1000;
      const id = await ctx.scheduler.runAt(
        new Date(burnAt),
        internal.vanish.burnVanished,
        { roomId: state.roomId },
      );
      Object.assign(patch, {
        burnUpTo: target.u1,
        burnWho: target.who,
        burnUpTo2: target.u2,
        burnAt,
        burnJobId: id,
      });
    } else {
      // One pending burn at most: record where we got to and when. The running
      // job reschedules itself for `nextReachedAt + afterSeen`. The LATEST
      // reach time, so no message gets less than its full grace.
      Object.assign(patch, {
        nextUpTo: target.u1,
        nextWho: target.who,
        nextUpTo2: target.u2,
        nextReachedAt: now,
      });
    }
  }
  await ctx.db.patch(state._id, patch);
  return advanced;
}

/**
 * A counted read by [userId] landed. Reads the room's vanishState (one read)
 * and rescans the members only when the reader is the lowest or second-lowest
 * cursor, the only readers whose move can change the answer. A reader who is
 * neither can only push their own cursor further up.
 */
export async function vanishAfterRead(
  ctx: any,
  roomId: any,
  userId: any,
  now: number,
): Promise<void> {
  const state = await vanishStateOf(ctx, roomId);
  if (!state) return;
  const id = userId.toString();
  const holder =
    state.slowestUserId === undefined ||
    state.secondUserId === undefined ||
    state.slowestUserId.toString() === id ||
    state.secondUserId.toString() === id;
  if (!holder) return;
  await recomputeFloor(ctx, state, now);
}

/**
 * A member left or was removed. Recompute only if they were one of the two
 * cached lowest (the others' order cannot have changed).
 */
export async function vanishAfterLeave(
  ctx: any,
  roomId: any,
  userId: any,
): Promise<void> {
  const state = await vanishStateOf(ctx, roomId);
  if (!state) return;
  const id = userId.toString();
  const holder =
    state.slowestUserId?.toString() === id ||
    state.secondUserId?.toString() === id;
  if (!holder) return;
  await recomputeFloor(ctx, state, Date.now());
}

/** Seconds a seen-clock secret room may use as its grace. */
export function assertSeenTimer(seconds: number | undefined): void {
  if (seconds === undefined || !AFTER_SEEN_OPTIONS.includes(seconds)) {
    throw new Error("BAD_VANISH_TIMER");
  }
}

/**
 * Brings a secret room's vanishState in line with its clock: a "seen" room gets
 * a row and a deadline chain; one switched back to "sent" stops being active
 * (the row drains on its own). [room] is the room AFTER the change.
 */
export async function syncSecretClock(
  ctx: any,
  room: any,
  now: number,
): Promise<void> {
  if (isSeenClockRoom(room)) {
    await ensureVanishState(ctx, room, now);
    return;
  }
  if (!isSecretRoom(room)) return;
  const state = await vanishStateOf(ctx, room._id);
  if (state && state.active) await ctx.db.patch(state._id, { active: false });
}
