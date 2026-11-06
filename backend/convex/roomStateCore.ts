import { GAP_HORIZON_MS, MAX_OWN_RUNS } from "./roomState";

/**
 * The write-hook half of C1 (docs/backend/c1-cursors-design.md): per-room
 * message sequence numbers, the sender's own bookkeeping, and gap rows for
 * deleted messages. A leaf module for the same reason as `contentCountsCore`:
 * `dbHooks.ts` needs it and every mutation module needs `dbHooks.ts`.
 *
 * Sequence order MUST match `createdAt` order for the rows `markRoomRead`
 * resolves against. Insert-site audit (2026-11-06): `sendCore` and
 * `forwardToRoom` stamp `Date.now()`, vanish/huddle/call lines stamp the same
 * clock, the report and moderation rooms offset by one millisecond per row in
 * insertion order, and the friend-request transcript writes a brand-new room's
 * messages ascending. The only skew is two concurrent mutations committing
 * out of clock order (milliseconds); `markRoomRead` tolerates that by taking
 * the highest `seq` of the few newest candidates (see `resolveReadSeq`).
 */

/** A `rooms` insert is born with a sequence: 0 messages so far. */
export function prepareRoomInsert(value: any): any {
  return value.lastSeq === undefined ? { ...value, lastSeq: 0 } : value;
}

/**
 * A `messages` insert: stamp the next sequence number and bump the room.
 * `db` is the RAW db (no re-entering the hooks). A room with no `lastSeq` yet
 * (the backfill has not reached it) is left alone: the migration assigns the
 * message its number when it gets there.
 */
export async function prepareMessageInsert(db: any, value: any): Promise<any> {
  if (value.seq !== undefined || !value.roomId) return value;
  const room = await db.get(value.roomId);
  if (!room || room.lastSeq === undefined) return value;
  const seq = room.lastSeq + 1;
  await db.patch(room._id, { lastSeq: seq });
  return { ...value, seq };
}

/**
 * After a message insert: the sender's own bookkeeping on their state row.
 * Never touches `readAt` or `roomReceipts`: seen-by must stay honest.
 */
export async function noteOwnMessage(db: any, msg: any): Promise<void> {
  const seq: number | undefined = msg.seq;
  if (seq === undefined) return;
  const state = await db
    .query("roomUserState")
    .withIndex("by_room_user", (q: any) =>
      q.eq("roomId", msg.roomId).eq("userId", msg.userId),
    )
    .first();
  if (!state) return; // legacy membership: its unread has no own-run to keep

  if (state.readSeq === seq - 1) {
    // Caught up: the new message is read by definition.
    const patch: Record<string, unknown> = { readSeq: seq };
    if (state.ownRuns !== undefined) patch.ownRuns = undefined;
    if (state.ownOverflow !== undefined) patch.ownOverflow = undefined;
    await db.patch(state._id, patch);
    return;
  }
  // Already overflowed: nothing to add, and no write per send.
  if (state.ownOverflow === true) return;

  const runs: { from: number; to: number }[] = [...(state.ownRuns ?? [])];
  const last = runs[runs.length - 1];
  if (last && last.to === seq - 1) {
    runs[runs.length - 1] = { from: last.from, to: seq };
  } else if (runs.length >= MAX_OWN_RUNS) {
    // A 9th run: never move `readSeq` past unread messages. Drop the runs and
    // let unread use the capped scan until the reader catches up.
    await db.patch(state._id, { ownOverflow: true, ownRuns: undefined });
    return;
  } else {
    runs.push({ from: seq, to: seq });
  }
  await db.patch(state._id, { ownRuns: runs });
}

/**
 * After a message delete: one ~50 byte hole marker, unless the room is gone or
 * going (teardown inserts nothing), the message never had a sequence, or it is
 * older than the horizon (a cursor that old uses the scan anyway).
 */
export async function noteDeletedMessage(db: any, before: any): Promise<void> {
  if (before.seq === undefined || !before.roomId) return;
  if (Date.now() - (before.createdAt ?? 0) >= GAP_HORIZON_MS) return;
  const room = await db.get(before.roomId);
  if (!room || room.deletingAt !== undefined) return;
  await db.insert("messageGaps", {
    roomId: before.roomId,
    seq: before.seq,
    at: before.createdAt,
  });
}
