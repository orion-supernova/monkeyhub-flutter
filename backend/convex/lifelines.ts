/**
 * Lifelines ("bananas"): the currency rewarded ads pay in.
 *
 * Earned by watching a rewarded ad (credited only by AdMob's server-side
 * verification callback, `adSsv.ts`, never by the app) and by one free banana
 * a day. Spent on: one more guess in the Code puzzle, one more hint in a daily,
 * an undo or a continue against a bot, and saving a streak that missed one
 * day. Design and cost table: docs/design/rewarded-ads.md.
 *
 * Cost: every call reads the caller's own `lifelines` row (one indexed read)
 * and at most one game row, and writes at most those two. The wallet query is
 * subscribed only by its owner and re-runs only on the owner's own spends and
 * credits. No jobs, no fan-out, nothing for people who never use it.
 */
import { v } from "convex/values";
import { mutation, query } from "./functions";
import { internalMutation } from "./dbHooks";
import { dayOrdinal } from "./dayKeys";
import { MAX_EXTRA_GUESSES, MAX_GUESSES } from "./puzzle";
import { LAUNCH_AT, LAUNCH_GIFT, LIST_PRICES } from "./catalog";
import { applyWallet, hasGuardian, walletRow, weekOrdinal } from "./bananaCore";
import { isGuardianOf } from "./childGuard";

/** Hints a daily gives for free; each one past these costs a banana. */
export const FREE_HINTS = 3;
/** Hints a daily sells on top of the free ones. */
export const MAX_BOUGHT_HINTS = 3;
/** Rewarded ads credited per UTC day. Past it the callback is ignored. */
export const ADS_PER_DAY = 15;
/** Every Nth ad of the day pays double. */
export const BONUS_EVERY = 3;
/** Saving a streak that missed one day. */
export const STREAK_SAVE_COST = 2;

const TX_MEMORY = 20;

const utcDay = (now: number) => new Date(now).toISOString().slice(0, 10);

function dayBefore(dayKey: string): string {
  return new Date((dayOrdinal(dayKey) - 1) * 86_400_000)
    .toISOString()
    .slice(0, 10);
}

async function walletOf(ctx: any, userId: any) {
  return await ctx.db
    .query("lifelines")
    .withIndex("by_user", (q: any) => q.eq("userId", userId))
    .first();
}

/** How a child account may spend (`child.spend`): unset means everything. */
export type SpendPolicy = "all" | "lifelines" | "none";

/** A child's banana rules as the app reads them; null for an adult. */
export function childView(row: any) {
  return {
    ask: row?.askOff !== true,
    spend: (row?.spend ?? "all") as SpendPolicy,
  };
}

/** The wallet as the app draws it. [child]: the account is a child's. */
export function walletView(row: any, now: number, child = false) {
  const today = utcDay(now);
  const adsToday = row?.adDay === today ? (row?.adsToday ?? 0) : 0;
  return {
    balance: row?.balance ?? 0,
    adsToday,
    adsLeft: Math.max(0, ADS_PER_DAY - adsToday),
    // 1..BONUS_EVERY: how many more ads until the one that pays double.
    nextBonusIn: BONUS_EVERY - (adsToday % BONUS_EVERY),
    freeReady: row?.freeDay !== today,
    // Unlocks (catalog.ts). `prices` is the list price of every single and
    // bundle; a bundle's complete-the-set price is the app's to compute from
    // `owned`, so a price change ships with no app release.
    owned: (row?.owned ?? []) as string[],
    firstPickReady: row?.firstPickUsed !== true,
    firstPackBonus: row?.firstPackUsed !== true,
    prices: LIST_PRICES,
    child: child ? childView(row) : null,
  };
}

/** The caller's own wallet. */
export const mine = query({
  args: { userId: v.id("users") },
  handler: async (ctx, { userId }) => {
    const row = await walletOf(ctx, userId);
    // Not `isChild`: that reads the users row, which every profile edit and
    // presence write re-runs (R2). A child always has a guardianship row.
    return walletView(row, Date.now(), await hasGuardian(ctx, userId));
  },
});

/**
 * Opened with the Games tab. Pays, once each: the launch gift (every account
 * created before LAUNCH_AT, +LAUNCH_GIFT) and, for a child, this ISO week's
 * allowance from the guardian who set it (skipped, never owed, when that
 * guardian is short). Idempotent; the common call (nothing due) is one wallet
 * read and, for an adult, no write.
 */
export const welcome = mutation({
  args: { userId: v.id("users") },
  handler: async (ctx, { userId }) => {
    let row = await walletOf(ctx, userId);
    let gift = 0;
    let allowance = 0;

    if (!row?.launchGiftAt) {
      const user = await ctx.db.get(userId);
      if (user && user.deletingAt === undefined && user.createdAt < LAUNCH_AT) {
        gift = LAUNCH_GIFT;
        row = await applyWallet(ctx, userId, row, gift, "launchGift", {}, {
          launchGiftAt: Date.now(),
        });
      }
    }

    const week = weekOrdinal(Date.now());
    const amount = row?.allowancePerWeek ?? 0;
    if (amount > 0 && row.allowanceFrom && row.allowanceWeek !== week) {
      const from = row.allowanceFrom;
      if (await isGuardianOf(ctx, from, userId)) {
        const payer = await walletOf(ctx, from);
        if ((payer?.balance ?? 0) >= amount) {
          await applyWallet(ctx, from, payer, -amount, "allowanceSent", {
            otherUserId: userId,
          });
          row = await applyWallet(ctx, userId, row, amount, "allowance", {
            otherUserId: from,
          }, { allowanceWeek: week });
          allowance = amount;
        }
      }
    }
    return { gift, allowance, balance: row?.balance ?? 0 };
  },
});

/**
 * Today's free banana. Idempotent: a second claim the same day is a no-op.
 * Every account, children included: it is the videos a child is kept from,
 * not bananas.
 */
export const claimFree = mutation({
  args: { userId: v.id("users") },
  handler: async (ctx, { userId }) => {
    const now = Date.now();
    const today = utcDay(now);
    const row = await walletOf(ctx, userId);
    if (row?.freeDay === today) return { claimed: false };
    if (row) {
      await ctx.db.patch(row._id, {
        balance: row.balance + 1,
        freeDay: today,
        updatedAt: now,
      });
    } else {
      await ctx.db.insert("lifelines", {
        userId,
        balance: 1,
        freeDay: today,
        updatedAt: now,
      });
    }
    return { claimed: true };
  },
});

/**
 * One verified rewarded ad. Called only by the SSV route after the signature
 * checked out. Returns how many bananas it paid (0: duplicate, cap, child).
 */
export const creditAd = internalMutation({
  args: { userId: v.id("users"), txId: v.string() },
  handler: async (ctx, { userId, txId }) => {
    const user = await ctx.db.get(userId);
    if (!user || user.accountType === "child") return 0;
    const now = Date.now();
    const today = utcDay(now);
    const row = await walletOf(ctx, userId);
    if (row?.recentTx?.includes(txId)) return 0;
    const before = row?.adDay === today ? (row?.adsToday ?? 0) : 0;
    if (before >= ADS_PER_DAY) return 0;
    const adsToday = before + 1;
    const gain = adsToday % BONUS_EVERY === 0 ? 2 : 1;
    const recentTx = [...(row?.recentTx ?? []), txId].slice(-TX_MEMORY);
    if (row) {
      await ctx.db.patch(row._id, {
        balance: row.balance + gain,
        adDay: today,
        adsToday,
        recentTx,
        totalAds: (row.totalAds ?? 0) + 1,
        updatedAt: now,
      });
    } else {
      await ctx.db.insert("lifelines", {
        userId,
        balance: gain,
        adDay: today,
        adsToday,
        recentTx,
        totalAds: 1,
        updatedAt: now,
      });
    }
    return gain;
  },
});

/**
 * Spends bananas on one thing. Refusals, so the app can say why:
 * `NO_BANANAS`, `NOT_NEEDED` (there is nothing to buy yet: guesses or free
 * hints left), `LIMIT` (this puzzle sold all it sells), `NOT_STARTED`,
 * `ALREADY_FINISHED`, `NOTHING_TO_SAVE`.
 *
 * `undo` and `continue` are bot games, played on the device: the server only
 * takes the banana, and the app grants the move when this resolves.
 */
export const spend = mutation({
  args: {
    userId: v.id("users"),
    kind: v.union(
      v.literal("guess"),
      v.literal("hint"),
      v.literal("undo"),
      v.literal("continue"),
      v.literal("streak"),
    ),
    dayKey: v.optional(v.string()),
    game: v.optional(v.string()),
  },
  handler: async (ctx, { userId, kind, dayKey, game }) => {
    const wallet = await walletOf(ctx, userId);
    const cost = kind === "streak" ? STREAK_SAVE_COST : 1;
    // A guardian can switch a child's spending off entirely.
    if (wallet?.spend === "none") throw new Error("SPEND_OFF");
    if (!wallet || wallet.balance < cost) throw new Error("NO_BANANAS");
    const now = Date.now();

    if (kind === "guess") {
      if (!dayKey) throw new Error("NOT_STARTED");
      const row = await ctx.db
        .query("puzzleResults")
        .withIndex("by_user_day", (q: any) =>
          q.eq("userId", userId).eq("dayKey", dayKey),
        )
        .first();
      if (!row) throw new Error("NOT_STARTED");
      if (row.solved || row.finishedAt !== undefined) {
        throw new Error("ALREADY_FINISHED");
      }
      const extra = row.extraGuesses ?? 0;
      if (extra >= MAX_EXTRA_GUESSES) throw new Error("LIMIT");
      if (row.guesses.length < MAX_GUESSES + extra) throw new Error("NOT_NEEDED");
      await ctx.db.patch(row._id, { extraGuesses: extra + 1, updatedAt: now });
    } else if (kind === "hint") {
      if (!dayKey || !game) throw new Error("NOT_STARTED");
      const row = await ctx.db
        .query("gameResults")
        .withIndex("by_user_day_game", (q: any) =>
          q.eq("userId", userId).eq("dayKey", dayKey).eq("game", game),
        )
        .first();
      if (!row) throw new Error("NOT_STARTED");
      if (row.finishedAt !== undefined) throw new Error("ALREADY_FINISHED");
      const bought = row.hintsBought ?? 0;
      if (bought >= MAX_BOUGHT_HINTS) throw new Error("LIMIT");
      if (row.hintsUsed < FREE_HINTS + bought) throw new Error("NOT_NEEDED");
      await ctx.db.patch(row._id, { hintsBought: bought + 1 });
    } else if (kind === "streak") {
      if (!dayKey || !game) throw new Error("NOTHING_TO_SAVE");
      const rec = await ctx.db
        .query("gameRecords")
        .withIndex("by_user_game", (q: any) =>
          q.eq("userId", userId).eq("game", game),
        )
        .first();
      // Exactly one day missed: the last solve was the day before yesterday.
      // The save moves it to yesterday, so today's solve extends the run.
      if (
        !rec?.streak ||
        !rec.lastSolvedDayKey ||
        dayOrdinal(dayKey) - dayOrdinal(rec.lastSolvedDayKey) !== 2
      ) {
        throw new Error("NOTHING_TO_SAVE");
      }
      await ctx.db.patch(rec._id, { lastSolvedDayKey: dayBefore(dayKey) });
    }

    await ctx.db.patch(wallet._id, {
      balance: wallet.balance - cost,
      updatedAt: now,
    });
    return { balance: wallet.balance - cost };
  },
});

/** Streaks [userId] could save today with [STREAK_SAVE_COST] bananas. */
export const savableStreaks = query({
  args: { userId: v.id("users"), dayKey: v.string() },
  handler: async (ctx, { userId, dayKey }) => {
    const rows = await ctx.db
      .query("gameRecords")
      .withIndex("by_user_game", (q: any) => q.eq("userId", userId))
      .take(20);
    const today = dayOrdinal(dayKey);
    return rows
      .filter(
        (r: any) =>
          (r.streak ?? 0) > 0 &&
          r.lastSolvedDayKey &&
          today - dayOrdinal(r.lastSolvedDayKey) === 2,
      )
      .map((r: any) => ({ game: r.game, streak: r.streak }));
  },
});

