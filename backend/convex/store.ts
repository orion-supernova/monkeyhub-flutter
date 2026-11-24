/**
 * Banana packs bought in the stores, credited by RevenueCat's webhook
 * (`POST /revenuecat`, http.ts). The app never credits itself: same shape as
 * AdMob SSV (`adSsv.ts`).
 *
 * Env: `REVENUECAT_WEBHOOK_AUTH`, the exact value RevenueCat sends in the
 * `Authorization` header (webhook settings > Authorization header value).
 * Unset: every call is refused with 401.
 *
 * Cost per event: 2 reads (ledger by store transaction, wallet) + 2 writes
 * (wallet, ledger). Nothing for people who never buy.
 */
import { v } from "convex/values";
import { internalMutation } from "./dbHooks";
import { PACKS } from "./catalog";
import { applyWallet, walletRow } from "./bananaCore";
import { isTombstoned } from "./deletionCore";

/** Constant-time string compare (length is not hidden, content is). */
export function safeEqual(a: string, b: string): boolean {
  const enc = new TextEncoder();
  const x = enc.encode(a);
  const y = enc.encode(b);
  let diff = x.length ^ y.length;
  const n = Math.max(x.length, y.length);
  for (let i = 0; i < n; i++) diff |= (x[i] ?? 0) ^ (y[i] ?? 0);
  return diff === 0;
}

export function webhookAuthOk(header: string | null): boolean {
  const want = (globalThis as any).process?.env?.REVENUECAT_WEBHOOK_AUTH as
    | string
    | undefined;
  return !!want && header !== null && safeEqual(header, want);
}

/**
 * Credits a pack ("credit") or takes it back after a refund ("refund").
 * Returns what moved (0: duplicate, unknown product or account). A refund may
 * leave the balance negative: the bananas may already be spent.
 */
export const apply = internalMutation({
  args: {
    kind: v.union(v.literal("credit"), v.literal("refund")),
    appUserId: v.string(),
    productId: v.string(),
    transactionId: v.string(),
  },
  handler: async (ctx, { kind, appUserId, productId, transactionId }) => {
    const base = PACKS[productId];
    const userId = ctx.db.normalizeId("users", appUserId);
    if (base === undefined || !userId || !transactionId) return 0;
    const user = await ctx.db.get(userId);
    if (!user || isTombstoned(user)) return 0;

    const key = kind === "credit" ? transactionId : `refund:${transactionId}`;
    const seen = await ctx.db
      .query("bananaLedger")
      .withIndex("by_storeTx", (q) => q.eq("storeTx", key))
      .first();
    if (seen) return 0;
    const row = await walletRow(ctx, userId);

    if (kind === "credit") {
      const double = row?.firstPackUsed !== true;
      const amount = double ? base * 2 : base;
      await applyWallet(ctx, userId, row, amount, "pack", {
        item: productId,
        storeTx: key,
      }, double ? { firstPackUsed: true } : {});
      return amount;
    }

    // Refund: take back exactly what that purchase paid.
    const original = await ctx.db
      .query("bananaLedger")
      .withIndex("by_storeTx", (q) => q.eq("storeTx", transactionId))
      .first();
    const amount = original?.amount ?? base;
    await applyWallet(ctx, userId, row, -amount, "refund", {
      item: productId,
      storeTx: key,
    });
    return -amount;
  },
});
