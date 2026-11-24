/**
 * Shared wallet plumbing for bananas and unlocks: the one place a balance
 * changes together with its ledger row. Cost: callers read the wallet row once
 * (`walletRow`) and pass it back in; each change is one patch + one ledger
 * insert. Design: docs/design/bananas-and-unlocks.html section 11.
 */
import { isFreeGame, ownsGame } from "./catalog";

export const MAX_OWNED = 60;

export async function walletRow(ctx: any, userId: any) {
  return await ctx.db
    .query("lifelines")
    .withIndex("by_user", (q: any) => q.eq("userId", userId))
    .first();
}

/** True when [userId] has a guardian: the only marker of a child account that
 * does not read the users row (R2). */
export async function hasGuardian(ctx: any, userId: any): Promise<boolean> {
  const g = await ctx.db
    .query("guardianships")
    .withIndex("by_child", (q: any) => q.eq("childId", userId))
    .first();
  return !!g;
}

export type LedgerExtra = {
  item?: string;
  storeTx?: string;
  otherUserId?: any;
};

/**
 * Moves [delta] (signed) on [userId]'s wallet and appends the ledger row.
 * [row] is the wallet as already read (or null: it is created). Returns the
 * wallet as it is now, so a second change in the same mutation builds on it.
 */
export async function applyWallet(
  ctx: any,
  userId: any,
  row: any,
  delta: number,
  kind: string,
  extra: LedgerExtra = {},
  patch: Record<string, unknown> = {},
) {
  const now = Date.now();
  const balance = (row?.balance ?? 0) + delta;
  const fields = { balance, updatedAt: now, ...patch };
  let next: any;
  if (row) {
    await ctx.db.patch(row._id, fields);
    next = { ...row, ...fields };
  } else {
    const _id = await ctx.db.insert("lifelines", { userId, ...fields });
    next = { _id, userId, ...fields };
  }
  await ctx.db.insert("bananaLedger", {
    userId,
    kind,
    amount: delta,
    at: now,
    ...(extra.item !== undefined ? { item: extra.item } : {}),
    ...(extra.storeTx !== undefined ? { storeTx: extra.storeTx } : {}),
    ...(extra.otherUserId !== undefined ? { otherUserId: extra.otherUserId } : {}),
  });
  return next;
}

/** [owned] plus [members], de-duplicated. */
export function withOwned(owned: string[] | undefined, members: string[]) {
  return [...new Set([...(owned ?? []), ...members])].slice(0, MAX_OWNED);
}

/** Refuses with LOCKED_GAME unless [game] is free or [userId] owns it. Free
 * games cost no read; a locked one reads the caller's wallet row. */
export async function assertOwnsGame(ctx: any, userId: any, game: string) {
  if (isFreeGame(game)) return;
  const row = await walletRow(ctx, userId);
  if (!ownsGame(row?.owned, game)) throw new Error("LOCKED_GAME");
}

/** ISO week ordinal (weeks since the epoch, Monday-first). */
export function weekOrdinal(now: number): number {
  return Math.floor((Math.floor(now / 86_400_000) + 3) / 7);
}
