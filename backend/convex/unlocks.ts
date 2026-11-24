/**
 * Spending bananas on catalog items (catalog.ts). One wallet read, one child
 * probe (a `guardianships` index lookup), one wallet patch, one ledger insert.
 * No jobs, no fan-out. Design: docs/design/bananas-and-unlocks.html.
 */
import { v } from "convex/values";
import { mutation } from "./functions";
import {
  firstPickEligible,
  isKnownItem,
  isOwnedItem,
  itemPrice,
  membersOf,
} from "./catalog";
import { applyWallet, hasGuardian, walletRow, withOwned } from "./bananaCore";

/**
 * Unlocks [item] for the caller. Refusals: `UNKNOWN_ITEM`, `OWNED`,
 * `NO_BANANAS`, `FIRST_PICK_USED`, `NOT_ELIGIBLE` (a first pick must be a
 * single fighter or stage worth at most 90), `CHILD_ASK` (a child whose
 * spending rule is not "all" asks a guardian instead; the first free pick is
 * not spending, so a child may use it).
 */
export const buy = mutation({
  args: {
    userId: v.id("users"),
    item: v.string(),
    firstPick: v.optional(v.boolean()),
  },
  handler: async (ctx, { userId, item, firstPick }) => {
    if (!isKnownItem(item)) throw new Error("UNKNOWN_ITEM");
    const row = await walletRow(ctx, userId);
    const owned: string[] = row?.owned ?? [];
    if (isOwnedItem(owned, item)) throw new Error("OWNED");

    let price = 0;
    if (firstPick) {
      if (!firstPickEligible(item)) throw new Error("NOT_ELIGIBLE");
      if (row?.firstPickUsed) throw new Error("FIRST_PICK_USED");
    } else {
      if ((await hasGuardian(ctx, userId)) && (row?.spend ?? "all") !== "all") {
        throw new Error("CHILD_ASK");
      }
      price = itemPrice(item, owned)!;
      if ((row?.balance ?? 0) < price) throw new Error("NO_BANANAS");
    }

    const nextOwned = withOwned(owned, membersOf(item));
    const next = await applyWallet(
      ctx,
      userId,
      row,
      -price,
      firstPick ? "firstPick" : "unlock",
      { item },
      { owned: nextOwned, ...(firstPick ? { firstPickUsed: true } : {}) },
    );
    return { balance: next.balance as number, owned: nextOwned };
  },
});
