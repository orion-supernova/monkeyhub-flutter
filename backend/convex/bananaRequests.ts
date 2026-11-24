/**
 * A child asking a guardian to unlock something (docs/design/bananas-and-unlocks.html).
 *
 * Cost: ask reads <= 4 (guardianships, wallet, the item's rows, open rows) and
 * writes 1 row + 1 push per guardian; answer reads 3 (request, two wallets)
 * and writes up to 5 (request, two wallets, two ledger rows) + 1 push. Open
 * rows expire after 7 days, checked on read: no cron, no sweep.
 *
 * Pushes are English-only, like every other server-side approval push
 * (`notifications.sendApprovalPush`).
 */
import { v } from "convex/values";
import { mutation, query } from "./functions";
import { internal } from "./_generated/api";
import {
  isKnownItem,
  isOwnedItem,
  itemLabel,
  itemPrice,
  membersOf,
} from "./catalog";
import {
  applyWallet,
  walletRow,
  weekOrdinal,
  withOwned,
} from "./bananaCore";
import { guardiansOf, isGuardianOf, assertGuardian } from "./childGuard";

export const REQUEST_TTL_MS = 7 * 86_400_000;
export const COOLDOWN_MS = 24 * 3_600_000;
export const MAX_OPEN = 3;
export const MAX_GIFT = 1000;

export const isExpired = (row: any, now: number) =>
  row.status === "open" && now - row.createdAt > REQUEST_TTL_MS;

/** One push through the same path the family approvals use. */
export async function pushTo(
  ctx: any,
  userIds: any[],
  title: string,
  body: string,
  extra?: Record<string, string>,
) {
  if (userIds.length === 0) return;
  await ctx.scheduler.runAfter(0, internal.notifications.sendApprovalPush, {
    userIds: userIds.map((u: any) => u.toString()),
    title,
    body,
    ...(extra ? { extra } : {}),
  });
}

/** The data the app reads to celebrate (or soften) a banana answer. */
export function answerData(
  status: string,
  guardianId: any,
  guardianName: string,
  requestId?: any,
  item?: string,
): Record<string, string> {
  const fields: Record<string, string> = {
    type: "bananaRequest",
    status,
    guardianId: guardianId.toString(),
    guardianName,
    ...(requestId ? { requestId: requestId.toString() } : {}),
    ...(item ? { item } : {}),
  };
  // The native tap handlers forward only `focus` for an approval push (the
  // same verbatim carrier a room push uses), so the celebration's fields ride
  // in it too, query-encoded. Dart parses `banana?...` in the requests tap.
  return { ...fields, focus: `banana?${new URLSearchParams(fields).toString()}` };
}

async function nameOf(ctx: any, userId: any, fallback: string) {
  const u = await ctx.db.get(userId);
  return u?.name ?? u?.username ?? fallback;
}

/**
 * The guardian pays the CURRENT price of [item] for [childId], and it lands
 * on the child's `owned`. Throws NO_BANANAS when the guardian is short.
 * Returns the price paid (0: the child already had it all, nothing moves) and
 * the guardian's balance.
 */
export async function payForChild(
  ctx: any,
  guardianId: any,
  childId: any,
  item: string,
  childRow?: any,
) {
  const child = childRow === undefined ? await walletRow(ctx, childId) : childRow;
  const owned: string[] = child?.owned ?? [];
  const price = itemPrice(item, owned) ?? 0;
  const guardian = await walletRow(ctx, guardianId);
  if (price === 0) return { price, guardianBalance: guardian?.balance ?? 0, child };
  if ((guardian?.balance ?? 0) < price) throw new Error("NO_BANANAS");
  const g = await applyWallet(ctx, guardianId, guardian, -price, "paidFor", {
    item,
    otherUserId: childId,
  });
  const c = await applyWallet(ctx, childId, child, 0, "unlockedBy", {
    item,
    otherUserId: guardianId,
  }, { owned: withOwned(owned, membersOf(item)) });
  return { price, guardianBalance: g.balance as number, child: c };
}

export const ask = mutation({
  args: {
    userId: v.id("users"),
    item: v.string(),
    note: v.optional(v.string()),
    sticker: v.optional(v.string()),
  },
  handler: async (ctx, { userId, item, note, sticker }) => {
    const guardians = await guardiansOf(ctx, userId);
    if (guardians.length === 0) throw new Error("NOT_CHILD");
    const wallet = await walletRow(ctx, userId);
    if (wallet?.askOff === true) throw new Error("ASK_OFF");
    if (!isKnownItem(item)) throw new Error("UNKNOWN_ITEM");
    if (isOwnedItem(wallet?.owned, item)) throw new Error("OWNED");

    const now = Date.now();
    // Newest rows for this item: an open one, or a recent decline.
    const same = await ctx.db
      .query("bananaRequests")
      .withIndex("by_child_item", (q: any) =>
        q.eq("childId", userId).eq("item", item),
      )
      .order("desc")
      .take(6);
    for (const r of same) {
      if (r.status === "open" && !isExpired(r, now)) throw new Error("ALREADY_ASKED");
      if (r.status === "declined" && now - (r.decidedAt ?? 0) < COOLDOWN_MS) {
        throw new Error("COOLDOWN");
      }
    }
    const open = await ctx.db
      .query("bananaRequests")
      .withIndex("by_child_status", (q: any) =>
        q.eq("childId", userId).eq("status", "open"),
      )
      .take(MAX_OPEN + 5);
    if (open.filter((r: any) => !isExpired(r, now)).length >= MAX_OPEN) {
      throw new Error("TOO_MANY");
    }

    const price = itemPrice(item, wallet?.owned)!;
    const cleanNote = note?.trim().slice(0, 140) || undefined;
    const cleanSticker = sticker?.trim().slice(0, 16) || undefined;
    const row = {
      childId: userId,
      item,
      price,
      ...(cleanNote ? { note: cleanNote } : {}),
      ...(cleanSticker ? { sticker: cleanSticker } : {}),
      createdAt: now,
    };
    const who = await nameOf(ctx, userId, "Your child");

    // Auto-yes: the guardian who set a weekly budget pre-approved this.
    const week = weekOrdinal(now);
    const limit = wallet?.autoYesPerWeek ?? 0;
    const spent = wallet?.autoYesWeek === week ? (wallet?.autoYesSpent ?? 0) : 0;
    const auto = wallet?.autoYesFrom;
    if (limit > 0 && auto && spent + price <= limit && (await isGuardianOf(ctx, auto, userId))) {
      const guardian = await walletRow(ctx, auto);
      if ((guardian?.balance ?? 0) >= price) {
        const paid = await payForChild(ctx, auto, userId, item, wallet);
        await ctx.db.patch(paid.child._id, {
          autoYesWeek: week,
          autoYesSpent: spent + price,
        });
        const id = await ctx.db.insert("bananaRequests", {
          ...row,
          status: "approved",
          decidedBy: auto,
          decidedAt: now,
        });
        await pushTo(ctx, [auto], "Banana OK", `${who} got ${itemLabel(item)} (auto OK)`);
        await pushTo(
          ctx,
          [userId],
          "Unlocked!",
          `${itemLabel(item)} is yours`,
          answerData("approved", auto, await nameOf(ctx, auto, "A grown-up"), id, item),
        );
        return { requestId: id, status: "approved" };
      }
    }

    const id = await ctx.db.insert("bananaRequests", { ...row, status: "open" });
    await pushTo(ctx, guardians, "Needs your OK", `${who} wants ${itemLabel(item)}`);
    return { requestId: id, status: "open" };
  },
});

export const withdraw = mutation({
  args: { userId: v.id("users"), requestId: v.id("bananaRequests") },
  handler: async (ctx, { userId, requestId }) => {
    const req = await ctx.db.get(requestId);
    if (!req || req.childId !== userId) throw new Error("NOT_FOUND");
    if (req.status !== "open") throw new Error("ALREADY_ANSWERED");
    await ctx.db.patch(requestId, { status: "withdrawn", decidedAt: Date.now() });
    return null;
  },
});

/** The child's open requests (expired ones filtered out). */
export const mine = query({
  args: { userId: v.id("users") },
  handler: async (ctx, { userId }) => {
    const now = Date.now();
    const rows = await ctx.db
      .query("bananaRequests")
      .withIndex("by_child_status", (q: any) =>
        q.eq("childId", userId).eq("status", "open"),
      )
      .take(MAX_OPEN + 5);
    return rows
      .filter((r: any) => !isExpired(r, now))
      .map((r: any) => ({
        _id: r._id,
        item: r.item,
        price: r.price,
        status: r.status,
        createdAt: r.createdAt,
      }));
  },
});

/**
 * A guardian answers. `approve` pays the CURRENT price from the guardian's own
 * wallet (`NO_BANANAS` if short); `gift` sends `amount` (1..1000) bananas
 * instead and closes the request as "gifted"; `decline` closes it. The first
 * answer wins (`ALREADY_ANSWERED`); an old one is `EXPIRED`.
 */
export const answer = mutation({
  args: {
    userId: v.id("users"),
    requestId: v.id("bananaRequests"),
    action: v.union(
      v.literal("approve"),
      v.literal("decline"),
      v.literal("gift"),
    ),
    amount: v.optional(v.number()),
  },
  handler: async (ctx, { userId, requestId, action, amount }) => {
    const req = await ctx.db.get(requestId);
    if (!req) throw new Error("NOT_FOUND");
    await assertGuardian(ctx, userId, req.childId);
    if (req.status !== "open") throw new Error("ALREADY_ANSWERED");
    const now = Date.now();
    if (isExpired(req, now)) throw new Error("EXPIRED");
    const who = await nameOf(ctx, userId, "A grown-up");
    let status: string;
    let guardianBalance: number;

    if (action === "approve") {
      const paid = await payForChild(ctx, userId, req.childId, req.item);
      guardianBalance = paid.guardianBalance;
      status = paid.price === 0 ? "done" : "approved";
      if (status === "approved") {
        await pushTo(ctx, [req.childId], "Unlocked!", `${who} got you ${itemLabel(req.item)}`,
          answerData("approved", userId, who, requestId, req.item));
      }
    } else if (action === "gift") {
      if (!Number.isInteger(amount) || amount! < 1 || amount! > MAX_GIFT) {
        throw new Error("BAD_AMOUNT");
      }
      guardianBalance = await sendBananas(ctx, userId, req.childId, amount!, requestId, req.item);
      status = "gifted";
    } else {
      guardianBalance = (await walletRow(ctx, userId))?.balance ?? 0;
      status = "declined";
      await pushTo(ctx, [req.childId], "Not this time", `${who} said not now for ${itemLabel(req.item)}`,
        answerData("declined", userId, who, requestId, req.item));
    }
    await ctx.db.patch(requestId, { status, decidedBy: userId, decidedAt: now });
    return { status, guardianBalance };
  },
});

/** Guardian wallet -> child wallet, with both ledger rows and a push to the child. */
export async function sendBananas(
  ctx: any,
  guardianId: any,
  childId: any,
  amount: number,
  requestId?: any,
  item?: string,
) {
  const guardian = await walletRow(ctx, guardianId);
  if ((guardian?.balance ?? 0) < amount) throw new Error("NO_BANANAS");
  const g = await applyWallet(ctx, guardianId, guardian, -amount, "giftSent", {
    otherUserId: childId,
  });
  await applyWallet(ctx, childId, await walletRow(ctx, childId), amount, "giftReceived", {
    otherUserId: guardianId,
  });
  const who = await nameOf(ctx, guardianId, "A grown-up");
  await pushTo(ctx, [childId], "Bananas!", `${who} sent you ${amount} bananas`,
    answerData("gifted", guardianId, who, requestId, item));
  return g.balance as number;
}
