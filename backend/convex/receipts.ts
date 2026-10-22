import { v } from "convex/values";
import { internal } from "./_generated/api";
import { internalMutation } from "./_generated/server";
import { appendReceiptLog, type ReceiptLogEntry } from "./receiptLog";

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
    if (m.seenVisibility !== seen) await ctx.db.patch(m._id, { seenVisibility: seen });
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
