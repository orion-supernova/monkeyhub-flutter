import { v } from "convex/values";
import { internal } from "./_generated/api";
import { internalMutation } from "./dbHooks";
import { RECEIPT_LOG_CAP, type ReceiptLogEntry } from "./receiptLog";

export type ReceiptKind = "read" | "delivered";

// ── receiptMoves: one small row per cursor move ───────────────────────────────
//
// `receiptLogs.entries` was rewritten whole (up to 200 entries) on every
// cursor move. Each move is now one ~100 B row in `receiptMoves`:
//   at     the cursor position the move reached (a message createdAt)
//   clock  wall-clock time of the move; 0 = "time not known" (a marker)
//   seq    per (room, user, kind) counter, so trimming needs no count
// "When did this cursor first cover message M" is the first row with
// `at >= M`: one indexed range read. Depth is the same 200 moves.
//
// The old per-member logs (`receiptLogs` rows, `roomMembers.readLog` /
// `deliveredLog`) were copied in and are gone; no reader falls back to them.

function movesFor(ctx: any, roomId: any, userId: any, kind: ReceiptKind) {
  return ctx.db
    .query("receiptMoves")
    .withIndex("by_room_user_kind_at", (q: any) =>
      q.eq("roomId", roomId).eq("userId", userId).eq("kind", kind),
    );
}

/** Insert [entries] (oldest first) as moves; returns the last seq used. */
async function insertMoves(
  ctx: any,
  roomId: any,
  userId: any,
  kind: ReceiptKind,
  entries: ReceiptLogEntry[],
  seqBase: number,
): Promise<number> {
  let seq = seqBase;
  for (const e of entries) {
    seq++;
    await ctx.db.insert("receiptMoves", {
      roomId,
      userId,
      kind,
      at: e.upTo,
      clock: e.at,
      seq,
    });
  }
  return seq;
}

/**
 * Record the cursor move [before] -> [upTo] at [at] for [member]'s [kind]
 * cursor: one insert (plus one delete + one patch once past the cap).
 * [member] is any row with `roomId` and `userId` (the `roomReceipts` row).
 */
export async function appendReceiptMove(
  ctx: any,
  member: any,
  kind: ReceiptKind,
  move: { before: number; upTo: number; at: number },
): Promise<void> {
  const { roomId, userId } = member;
  let newest = await movesFor(ctx, roomId, userId, kind).order("desc").first();
  // A history that ends past the cursor belongs to an earlier stay in the room
  // (the membership row went, the moves were left behind). Start fresh rather
  // than splice a new stay onto it.
  if (newest && newest.at > move.before) {
    const stale = await movesFor(ctx, roomId, userId, kind).take(
      RECEIPT_LOG_CAP + 50,
    );
    for (const r of stale) await ctx.db.delete(r._id);
    newest = null;
  }
  let seq = newest?.seq ?? 0;
  // The cursor stood somewhere the history does not account for: close the gap
  // with an unknown-time move so the next one cannot claim that stretch.
  if (move.before > (newest?.at ?? 0)) {
    seq = await insertMoves(ctx, roomId, userId, kind, [
      { upTo: move.before, at: 0 },
    ], seq);
  }
  seq = await insertMoves(ctx, roomId, userId, kind, [
    { upTo: move.upTo, at: move.at },
  ], seq);
  // Trim: past the cap, drop the oldest move and turn the next-oldest into an
  // unknown-time marker (it no longer knows where its stretch began).
  // A gap marker plus the move is two inserts, so up to two may go.
  const oldest = await movesFor(ctx, roomId, userId, kind).take(3);
  let first = 0;
  while (oldest.length - first >= 2 && seq - oldest[first].seq + 1 > RECEIPT_LOG_CAP) {
    await ctx.db.delete(oldest[first]._id);
    first++;
  }
  if (first > 0 && oldest[first].clock !== 0) {
    await ctx.db.patch(oldest[first]._id, { clock: 0 });
  }
}

/**
 * When [member]'s [kind] cursor first covered a message stamped [createdAt]:
 * the first move at or past it. Null when unknown.
 */
export async function receiptTimeAt(
  ctx: any,
  member: any,
  kind: ReceiptKind,
  createdAt: number,
): Promise<number | null> {
  const hit = await ctx.db
    .query("receiptMoves")
    .withIndex("by_room_user_kind_at", (q: any) =>
      q
        .eq("roomId", member.roomId)
        .eq("userId", member.userId)
        .eq("kind", kind)
        .gte("at", createdAt),
    )
    .first();
  if (hit) return hit.clock > 0 ? hit.clock : null;
  return null;
}

const RESTAMP_PAGE = 100;

/**
 * One page of the `roomReceipts.seenVisibility` re-stamp after a user changes
 * their SEND READ RECEIPTS level. Stamps the user's CURRENT level (read here,
 * not passed in), so overlapping edits converge on the last one. Returns the
 * next cursor, or null when done. See `users.updateVisibility`.
 */
export async function restampSeenPage(
  ctx: any,
  userId: any,
  cursor: string | null,
): Promise<string | null> {
  const user = await ctx.db.get(userId);
  const seen = user?.visibility?.seen as string | undefined;
  const page = await ctx.db
    .query("roomReceipts")
    .withIndex("by_user", (q: any) => q.eq("userId", userId))
    .paginate({ numItems: RESTAMP_PAGE, cursor });
  for (const receipt of page.page) {
    if (receipt.seenVisibility !== seen) {
      await ctx.db.patch(receipt._id, { seenVisibility: seen });
    }
  }
  return page.isDone ? null : page.continueCursor;
}

export const restampSeenVisibility = internalMutation({
  args: { userId: v.id("users"), cursor: v.string() },
  handler: async (ctx, { userId, cursor }) => {
    const next = await restampSeenPage(ctx, userId, cursor);
    if (next !== null) {
      await ctx.scheduler.runAfter(0, internal.receipts.restampSeenVisibility, {
        userId,
        cursor: next,
      });
    }
  },
});
