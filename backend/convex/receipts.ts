import { v } from "convex/values";
import { internal } from "./_generated/api";
import { internalMutation } from "./dbHooks";
import { receiptOf } from "./roomState";
import {
  RECEIPT_LOG_CAP,
  appendReceiptLog,
  receiptTimeFor,
  type ReceiptLogEntry,
} from "./receiptLog";

/**
 * Where the per-cursor receipt logs live (plan 4C).
 *
 * They used to be `roomMembers.readLog` / `deliveredLog`, ~4 KB each, which
 * made a membership row ~8 KB and every receipt a rewrite of it, re-reading
 * the whole row for every member on every `getReadState` run. They now live in
 * `receiptLogs`, one row per (room, user, kind), written only by the reader's
 * own receipt and read only by `getReceiptTimes`.
 *
 * Migration (deploy, migrate, deploy):
 *  - readers prefer the `receiptLogs` row and fall back to the member row's
 *    legacy field ([receiptEntries]);
 *  - writers write only `receiptLogs` and clear the member row's legacy field
 *    in the patch they are making anyway ([writeReceiptLog]);
 *  - [moveLogs] moves whatever is left and unsets the fields.
 * The schema fields stay optional until a later deploy removes them.
 */

export type ReceiptKind = "read" | "delivered";

const LEGACY_FIELD = { read: "readLog", delivered: "deliveredLog" } as const;

async function logRow(ctx: any, roomId: any, userId: any, kind: ReceiptKind) {
  return await ctx.db
    .query("receiptLogs")
    .withIndex("by_room_user_kind", (q: any) =>
      q.eq("roomId", roomId).eq("userId", userId).eq("kind", kind),
    )
    .first();
}

/**
 * The log for [member]'s [kind] cursor: the `receiptLogs` row when there is
 * one, else the member row's legacy field (not yet moved), else undefined.
 */
export async function receiptEntries(
  ctx: any,
  member: any,
  kind: ReceiptKind,
): Promise<ReceiptLogEntry[] | undefined> {
  const row = await logRow(ctx, member.roomId, member.userId, kind);
  if (row) return row.entries;
  return member[LEGACY_FIELD[kind]];
}

/**
 * Append the cursor move [before] -> [upTo] at [at] to [member]'s [kind] log
 * (or, with [upTo] null, only move a legacy log out), writing `receiptLogs`.
 *
 * Returns the fields to merge into the member patch the caller is already
 * making: the legacy field unset, or `{}` when the row has none. Never touches
 * the member row itself.
 */
export async function writeReceiptLog(
  ctx: any,
  member: any,
  kind: ReceiptKind,
  move: { before: number; upTo: number; at: number } | null,
): Promise<Record<string, undefined>> {
  const field = LEGACY_FIELD[kind];
  const legacy: ReceiptLogEntry[] | undefined = member[field];
  const clear: Record<string, undefined> =
    legacy !== undefined ? { [field]: undefined } : {};
  const row = await logRow(ctx, member.roomId, member.userId, kind);
  if (!move && !legacy) return clear;
  if (!move && row) return clear;

  let base: ReceiptLogEntry[] | undefined = row ? row.entries : legacy;
  // A log that ends past the cursor belongs to an earlier stay in the room
  // (the member left, the membership row went, the log row was left behind).
  // Start fresh rather than splice a new stay onto it.
  if (move && base && base.length > 0 && base[base.length - 1].upTo > move.before) {
    base = undefined;
  }
  const entries = move
    ? appendReceiptLog(base, move.before, move.upTo, move.at)
    : base!;
  if (row) {
    await ctx.db.patch(row._id, { entries });
  } else {
    await ctx.db.insert("receiptLogs", {
      roomId: member.roomId,
      userId: member.userId,
      kind,
      entries,
    });
  }
  return clear;
}

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
// Old history (receiptLogs rows / legacy member fields) is copied in lazily by
// the first move a member makes after the deploy, and in bulk by
// [backfillMoves]. Readers fall back to the old logs only until the
// `receiptMoves` marker says the bulk copy is done.

export const BACKFILL_MARKER = "receiptMoves";

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
 * Copy [member]'s old-format history for [kind] into `receiptMoves`, unless
 * moves already exist. [dropOld] deletes the `receiptLogs` row afterwards (the
 * lazy path, which owns it); the bulk backfill keeps it. Returns the newest
 * move afterwards, or null.
 */
async function seedMoves(
  ctx: any,
  member: any,
  kind: ReceiptKind,
  dropOld: boolean,
): Promise<any | null> {
  const row = await logRow(ctx, member.roomId, member.userId, kind);
  const entries: ReceiptLogEntry[] | undefined =
    row?.entries ?? member[LEGACY_FIELD[kind]];
  if (row && dropOld) await ctx.db.delete(row._id);
  if (!entries || entries.length === 0) return null;
  const kept = entries.slice(-RECEIPT_LOG_CAP);
  await insertMoves(ctx, member.roomId, member.userId, kind, kept, 0);
  return await movesFor(ctx, member.roomId, member.userId, kind)
    .order("desc")
    .first();
}

/**
 * Record the cursor move [before] -> [upTo] at [at] for [member]'s [kind]
 * cursor: one insert (plus one delete + one patch once past the cap).
 *
 * Returns the fields to merge into the member patch the caller is already
 * making (the legacy log field unset), like [writeReceiptLog].
 */
export async function appendReceiptMove(
  ctx: any,
  member: any,
  kind: ReceiptKind,
  move: { before: number; upTo: number; at: number },
): Promise<Record<string, undefined>> {
  const field = LEGACY_FIELD[kind];
  const clear: Record<string, undefined> =
    member[field] !== undefined ? { [field]: undefined } : {};
  const { roomId, userId } = member;
  let newest = await movesFor(ctx, roomId, userId, kind).order("desc").first();
  if (!newest) newest = await seedMoves(ctx, member, kind, true);
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
  return clear;
}

/** True once [backfillMoves] has copied every old log. One point read. */
export async function receiptMovesBackfilled(ctx: any): Promise<boolean> {
  const m = await ctx.db
    .query("migrationMarkers")
    .withIndex("by_name", (q: any) => q.eq("name", BACKFILL_MARKER))
    .first();
  return m !== null;
}

/**
 * When [member]'s [kind] cursor first covered a message stamped [createdAt]:
 * the first move at or past it. Null when unknown. Falls back to the old log
 * format only while [backfilled] is false and the member has no moves yet.
 */
export async function receiptTimeAt(
  ctx: any,
  member: any,
  kind: ReceiptKind,
  createdAt: number,
  backfilled: boolean,
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
  if (backfilled) return null;
  // No covering move. Either the cursor has not reached it (the caller checks
  // that) or the history is still in the old format.
  const any = await movesFor(ctx, member.roomId, member.userId, kind).first();
  if (any) return null;
  return receiptTimeFor(await receiptEntries(ctx, member, kind), createdAt);
}

/**
 * One-off: copy every `receiptLogs` row into `receiptMoves`, then set the
 * marker that retires the readers' fallback. Paged, self-chaining, idempotent:
 * a (room, user, kind) that already has moves is skipped (a writer seeded it,
 * and its moves are newer). Run `moveLogs` first so no legacy member-row logs
 * are left. Keeps the `receiptLogs` rows; delete them in a later deploy.
 *
 *     npx convex run receipts:backfillMoves '{}'
 */
export const backfillMoves = internalMutation({
  args: {
    cursor: v.optional(v.string()),
    batchSize: v.optional(v.number()),
    scanned: v.optional(v.number()),
    copied: v.optional(v.number()),
  },
  handler: async (ctx, { cursor, batchSize, scanned, copied }) => {
    // Up to 200 inserts per row: 20 rows is ~4,000 writes, half Convex's
    // per-mutation ceiling, whatever an operator passes.
    const numItems = Math.min(batchSize ?? 20, 20);
    const page = await ctx.db
      .query("receiptLogs")
      .paginate({ numItems, cursor: cursor ?? null });
    let totalScanned = scanned ?? 0;
    let totalCopied = copied ?? 0;
    for (const row of page.page) {
      totalScanned++;
      const existing = await movesFor(ctx, row.roomId, row.userId, row.kind).first();
      if (existing) continue;
      const kept = row.entries.slice(-RECEIPT_LOG_CAP);
      await insertMoves(ctx, row.roomId, row.userId, row.kind, kept, 0);
      totalCopied++;
    }
    if (!page.isDone) {
      await ctx.scheduler.runAfter(0, internal.receipts.backfillMoves, {
        cursor: page.continueCursor,
        batchSize: numItems,
        scanned: totalScanned,
        copied: totalCopied,
      });
      return { done: false, scanned: totalScanned, copied: totalCopied };
    }
    const marker = await ctx.db
      .query("migrationMarkers")
      .withIndex("by_name", (q) => q.eq("name", BACKFILL_MARKER))
      .first();
    if (!marker) {
      await ctx.db.insert("migrationMarkers", {
        name: BACKFILL_MARKER,
        doneAt: Date.now(),
      });
    }
    console.log(
      `receipts.backfillMoves complete: scanned ${totalScanned}, copied ${totalCopied}`,
    );
    return { done: true, scanned: totalScanned, copied: totalCopied };
  },
});

/**
 * Backfill: move every remaining legacy log out of `roomMembers` and unset the
 * fields. Paged and self-chaining; re-running is a no-op (a `receiptLogs` row
 * that already exists wins, because a writer made it and it is newer).
 *
 *     npx convex run receipts:moveLogs '{}'
 */
export const moveLogs = internalMutation({
  args: {
    cursor: v.optional(v.string()),
    batchSize: v.optional(v.number()),
    scanned: v.optional(v.number()),
    moved: v.optional(v.number()),
  },
  handler: async (ctx, { cursor, batchSize, scanned, moved }) => {
    // Legacy rows are ~8 KB each; keep the page well under the read limit.
    const numItems = Math.min(batchSize ?? 40, 100);
    const page = await ctx.db
      .query("roomMembers")
      .paginate({ numItems, cursor: cursor ?? null });
    let totalScanned = scanned ?? 0;
    let totalMoved = moved ?? 0;
    for (const m of page.page) {
      totalScanned++;
      if (m.readLog === undefined && m.deliveredLog === undefined) continue;
      const clear = {
        ...(await writeReceiptLog(ctx, m, "read", null)),
        ...(await writeReceiptLog(ctx, m, "delivered", null)),
      };
      await ctx.db.patch(m._id, clear as any);
      totalMoved++;
    }
    if (!page.isDone) {
      await ctx.scheduler.runAfter(0, internal.receipts.moveLogs, {
        cursor: page.continueCursor,
        batchSize: numItems,
        scanned: totalScanned,
        moved: totalMoved,
      });
      return { done: false, scanned: totalScanned, moved: totalMoved };
    }
    console.log(
      `receipts.moveLogs complete: scanned ${totalScanned}, moved ${totalMoved}`,
    );
    return { done: true, scanned: totalScanned, moved: totalMoved };
  },
});

const RESTAMP_PAGE = 100;

/**
 * One page of the `roomMembers.seenVisibility` re-stamp after a user changes
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
    .query("roomMembers")
    .withIndex("by_user", (q: any) => q.eq("userId", userId))
    .paginate({ numItems: RESTAMP_PAGE, cursor });
  for (const m of page.page) {
    // C1: a migrated membership's stamp lives on its `roomReceipts` row.
    const receipt = await receiptOf(ctx, m.roomId, m.userId);
    if (receipt) {
      if (receipt.seenVisibility !== seen) {
        await ctx.db.patch(receipt._id, { seenVisibility: seen });
      }
    } else if (m.seenVisibility !== seen) {
      await ctx.db.patch(m._id, { seenVisibility: seen });
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
