import { convexTest } from "convex-test";
import { describe, expect, test } from "vitest";
import { api, internal } from "./_generated/api";
import schema from "./schema";
import { answerFor } from "./puzzle";
import { ADS_PER_DAY, FREE_HINTS } from "./lifelines";
import { derToRaw, parseSsv } from "./adSsv";

/**
 * Rewarded-ad lifelines: the wallet (credit, bonus, cap, dedupe, free daily),
 * and every spend's gate. docs/design/rewarded-ads.md.
 */

const DAY = "2026-10-07";

type Who = { token: string; userId: any };

async function signUp(t: ReturnType<typeof convexTest>, username: string) {
  return (await t.mutation(api.auth.signup, {
    username,
    name: username,
    passwordHash: `hash-${username}`,
    recoveryKeyHash: `recovery-${username}`,
    deviceId: `device-${username}`,
  })) as Who;
}

const wallet = (t: any, me: Who) =>
  t.query(api.lifelines.mine, { sessionToken: me.token, userId: me.userId });

const credit = (t: any, me: Who, txId: string) =>
  t.mutation(internal.lifelines.creditAd, { userId: me.userId, txId });

const spend = (t: any, me: Who, args: any) =>
  t.mutation(api.lifelines.spend, {
    sessionToken: me.token,
    userId: me.userId,
    ...args,
  });

describe("the wallet", () => {
  test("ads pay one, every third pays two, a retried callback pays nothing", async () => {
    const t = convexTest(schema);
    const me = await signUp(t, "me");
    expect(await credit(t, me, "a")).toBe(1);
    expect(await credit(t, me, "a")).toBe(0);
    expect(await credit(t, me, "b")).toBe(1);
    expect(await credit(t, me, "c")).toBe(2);
    const w: any = await wallet(t, me);
    expect(w.balance).toBe(4);
    expect(w.adsToday).toBe(3);
    expect(w.nextBonusIn).toBe(3);
  });

  test("the daily cap stops crediting", async () => {
    const t = convexTest(schema);
    const me = await signUp(t, "me");
    for (let i = 0; i < ADS_PER_DAY; i++) await credit(t, me, `tx${i}`);
    expect(await credit(t, me, "over")).toBe(0);
    expect(((await wallet(t, me)) as any).adsLeft).toBe(0);
  });

  test("the free banana comes once a day", async () => {
    const t = convexTest(schema);
    const me = await signUp(t, "me");
    const claim = () =>
      t.mutation(api.lifelines.claimFree, {
        sessionToken: me.token,
        userId: me.userId,
      });
    expect(((await claim()) as any).claimed).toBe(true);
    expect(((await claim()) as any).claimed).toBe(false);
    expect(((await wallet(t, me)) as any).balance).toBe(1);
  });

  test("an empty wallet buys nothing", async () => {
    const t = convexTest(schema);
    const me = await signUp(t, "me");
    await expect(spend(t, me, { kind: "undo" })).rejects.toThrow("NO_BANANAS");
    await credit(t, me, "a");
    expect(((await spend(t, me, { kind: "undo" })) as any).balance).toBe(0);
  });
});

describe("the code puzzle", () => {
  test("out of guesses: hidden answer, buy a guess, then concede", async () => {
    const t = convexTest(schema);
    const me = await signUp(t, "me");
    const wrong = [...answerFor(DAY)].reverse();
    const guess = (attempt: number) =>
      t.mutation(api.puzzle.guess, {
        sessionToken: me.token,
        userId: me.userId,
        dayKey: DAY,
        guess: wrong,
        attempt,
      });
    // A reversed answer could be the answer only if it is a palindrome; the
    // codes use distinct symbols, so it never is.
    let board: any;
    for (let i = 0; i < 6; i++) board = await guess(i);
    expect(board.done).toBe(false);
    expect(board.answer).toBeUndefined();
    expect(board.extraLeft).toBe(3);
    await expect(guess(6)).rejects.toThrow("OUT_OF_GUESSES");

    await expect(spend(t, me, { kind: "guess", dayKey: DAY })).rejects.toThrow(
      "NO_BANANAS",
    );
    await credit(t, me, "a");
    await spend(t, me, { kind: "guess", dayKey: DAY });
    board = await guess(6);
    expect(board.guesses).toHaveLength(7);
    expect(board.limit).toBe(7);
    expect(board.done).toBe(false);

    const out: any = await t.mutation(api.puzzle.concede, {
      sessionToken: me.token,
      userId: me.userId,
      dayKey: DAY,
    });
    expect(out.done).toBe(true);
    expect(out.answer).toEqual(answerFor(DAY));
  });

  test("a guess cannot be bought while guesses remain", async () => {
    const t = convexTest(schema);
    const me = await signUp(t, "me");
    await t.mutation(api.puzzle.guess, {
      sessionToken: me.token,
      userId: me.userId,
      dayKey: DAY,
      guess: [...answerFor(DAY)].reverse(),
      attempt: 0,
    });
    await credit(t, me, "a");
    await expect(spend(t, me, { kind: "guess", dayKey: DAY })).rejects.toThrow(
      "NOT_NEEDED",
    );
    expect(((await wallet(t, me)) as any).balance).toBe(1);
  });
});

describe("hints", () => {
  test("free hints run out, a banana buys one more", async () => {
    const t = convexTest(schema);
    const me = await signUp(t, "me");
    const base = {
      sessionToken: me.token,
      userId: me.userId,
      dayKey: DAY,
      game: "futoshiki",
    };
    await t.mutation(api.games.start, base);
    await t.run(async (ctx: any) => {
      const row = await ctx.db.query("gameResults").first();
      await ctx.db.patch(row._id, { hintsUsed: FREE_HINTS });
    });
    await expect(
      t.mutation(api.games.hint, { ...base, board: [], seq: FREE_HINTS }),
    ).rejects.toThrow("OUT_OF_HINTS");
    await credit(t, me, "a");
    await spend(t, me, { kind: "hint", dayKey: DAY, game: "futoshiki" });
    const row: any = await t.run(async (ctx: any) =>
      ctx.db.query("gameResults").first(),
    );
    expect(row.hintsBought).toBe(1);
  });
});

describe("streak save", () => {
  test("saves a run that missed exactly one day", async () => {
    const t = convexTest(schema);
    const me = await signUp(t, "me");
    await t.run(async (ctx: any) => {
      await ctx.db.insert("gameRecords", {
        userId: me.userId,
        game: "code",
        dayKey: "2026-10-05",
        achievedAt: 0,
        solves: 5,
        streak: 5,
        bestStreak: 5,
        lastSolvedDayKey: "2026-10-05",
      });
    });
    const savable: any = await t.query(api.lifelines.savableStreaks, {
      sessionToken: me.token,
      userId: me.userId,
      dayKey: DAY,
    });
    expect(savable).toEqual([{ game: "code", streak: 5 }]);
    await credit(t, me, "a");
    await expect(
      spend(t, me, { kind: "streak", dayKey: DAY, game: "code" }),
    ).rejects.toThrow("NO_BANANAS");
    await credit(t, me, "b");
    await spend(t, me, { kind: "streak", dayKey: DAY, game: "code" });
    const rec: any = await t.run(async (ctx: any) =>
      ctx.db.query("gameRecords").first(),
    );
    expect(rec.lastSolvedDayKey).toBe("2026-10-06");
  });
});

describe("SSV parsing", () => {
  test("the signed message is everything before the signature", () => {
    const p = parseSsv(
      "?ad_network=1&ad_unit=2127467203&reward_amount=1&reward_item=lifeline&timestamp=1&transaction_id=tx&user_id=u&signature=MEUC&key_id=3335741209",
    )!;
    expect(p.message).toBe(
      "ad_network=1&ad_unit=2127467203&reward_amount=1&reward_item=lifeline&timestamp=1&transaction_id=tx&user_id=u",
    );
    expect(p.keyId).toBe("3335741209");
    expect(parseSsv("?ad_unit=1")).toBeNull();
  });

  test("DER signatures become raw r||s", () => {
    // r = 0x00 0x81.. (33 bytes, leading zero), s = 0x01 (1 byte)
    const r = [0x00, ...new Array(32).fill(0x81)];
    const der = new Uint8Array([0x30, 2 + 33 + 2 + 1, 0x02, 33, ...r, 0x02, 1, 0x01]);
    const raw = derToRaw(der)!;
    expect(raw.length).toBe(64);
    expect(raw[0]).toBe(0x81);
    expect(raw[63]).toBe(0x01);
    expect(raw[62]).toBe(0x00);
  });
});
