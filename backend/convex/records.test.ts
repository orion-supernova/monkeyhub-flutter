import { convexTest } from "convex-test";
import { describe, expect, test } from "vitest";
import { api, internal } from "./_generated/api";
import schema from "./schema";
import { answerFor } from "./puzzle";
import { noteSolve, purgeRecordsOf } from "./recordBook";

/**
 * All-time records, and the friends reacting to them.
 *
 * Claims that are promises to a user rather than behaviours:
 *
 *   1. **A record is the best, and only a better one replaces it.** A tie
 *      keeps the earlier holder; every solve still counts.
 *   2. **The board is friends, and only the ones who share.** Strangers never
 *      appear, and `visibility.puzzle: "nobody"` hides a friend exactly as it
 *      does on every daily scoreboard.
 *   3. **A reaction is for an achievement.** Beating the record clears the
 *      cheers the old one had.
 *   4. **Only a friend reacts, and not to themselves.**
 *   5. **The backfill is idempotent** — re-running it changes nothing.
 *   6. **The code puzzle can be shared once, like the other four.**
 *   7. **A streak is consecutive days solved,** per game: a skipped or
 *      surrendered day restarts it, and it stays alive until the day after
 *      the last solve is over.
 */

const DEVICE = "device-a";
const DAY = "2026-09-06";

type Who = { token: string; userId: any };

async function signUp(t: ReturnType<typeof convexTest>, username: string) {
  return (await t.mutation(api.auth.signup, {
    username,
    name: username,
    passwordHash: `hash-${username}`,
    recoveryKeyHash: `recovery-${username}`,
    deviceId: DEVICE,
  })) as Who;
}

async function befriend(
  t: ReturnType<typeof convexTest>,
  a: Who,
  b: Who,
  bName: string,
) {
  await t.mutation(api.friends.sendRequest, {
    sessionToken: a.token,
    userId: a.userId,
    friendUsername: bName,
  });
  await t.mutation(api.friends.acceptRequest, {
    sessionToken: b.token,
    userId: b.userId,
    requesterId: a.userId,
  });
}

async function solve(
  t: ReturnType<typeof convexTest>,
  userId: any,
  game: string,
  score: number,
  achievedAt: number,
  dayKey = DAY,
) {
  await t.run(async (ctx: any) => {
    await noteSolve(ctx, { userId, game, score, dayKey, achievedAt });
  });
}

async function board(t: ReturnType<typeof convexTest>, who: Who) {
  return (await t.query(api.records.board, {
    sessionToken: who.token,
    userId: who.userId,
  })) as any;
}

async function recordOf(t: ReturnType<typeof convexTest>, userId: any, game: string) {
  return await t.run(async (ctx: any) =>
    ctx.db
      .query("gameRecords")
      .withIndex("by_user_game", (q: any) =>
        q.eq("userId", userId).eq("game", game),
      )
      .first(),
  );
}

describe("a record", () => {
  test("is the best, and a tie keeps the earlier holder", async () => {
    const t = convexTest(schema);
    const me = await signUp(t, "me");
    await solve(t, me.userId, "queens", 90_000, 1);
    await solve(t, me.userId, "queens", 120_000, 2);
    await solve(t, me.userId, "queens", 90_000, 3);

    const r: any = await recordOf(t, me.userId, "queens");
    expect(r.best).toBe(90_000);
    expect(r.achievedAt).toBe(1);
    expect(r.solves).toBe(3);

    await solve(t, me.userId, "queens", 61_000, 4);
    const better: any = await recordOf(t, me.userId, "queens");
    expect(better.best).toBe(61_000);
    expect(better.achievedAt).toBe(4);
    expect(better.solves).toBe(4);
  });

  test("the code puzzle records a solve by its guess count", async () => {
    const t = convexTest(schema);
    const me = await signUp(t, "me");
    const answer = answerFor(DAY);
    const wrong = [...answer].reverse();
    await t.mutation(api.puzzle.guess, {
      sessionToken: me.token,
      userId: me.userId,
      dayKey: DAY,
      guess: wrong,
    });
    await t.mutation(api.puzzle.guess, {
      sessionToken: me.token,
      userId: me.userId,
      dayKey: DAY,
      guess: answer,
    });
    const r: any = await recordOf(t, me.userId, "code");
    expect(r.best).toBe(2);
    expect(r.solves).toBe(1);
  });
});

describe("the board", () => {
  test("ranks the viewer with friends, and nobody else", async () => {
    const t = convexTest(schema);
    const me = await signUp(t, "me");
    const ada = await signUp(t, "ada");
    const stranger = await signUp(t, "stranger");
    await befriend(t, me, ada, "ada");
    await solve(t, me.userId, "zip", 40_000, 1);
    await solve(t, ada.userId, "zip", 25_000, 2);
    await solve(t, stranger.userId, "zip", 5_000, 3);

    const b = await board(t, me);
    const rows = b.games.zip;
    expect(rows.map((r: any) => r.name)).toEqual(["ada", ""]);
    expect(rows.map((r: any) => r.rank)).toEqual([1, 2]);
    expect(b.games.queens).toEqual([]);
    expect(b.palette.length).toBeGreaterThan(0);
  });

  test("a friend who keeps their scores private is not on it", async () => {
    const t = convexTest(schema);
    const me = await signUp(t, "me");
    const ada = await signUp(t, "ada");
    await befriend(t, me, ada, "ada");
    await solve(t, ada.userId, "tango", 25_000, 2);
    await t.run(async (ctx: any) => {
      await ctx.db.patch(ada.userId, { visibility: { puzzle: "nobody" } });
    });
    expect((await board(t, me)).games.tango).toEqual([]);
  });
});

describe("reactions", () => {
  async function setup() {
    const t = convexTest(schema);
    const me = await signUp(t, "me");
    const ada = await signUp(t, "ada");
    await befriend(t, me, ada, "ada");
    await solve(t, ada.userId, "sudoku", 70_000, 10);
    const recordId = ((await recordOf(t, ada.userId, "sudoku")) as any)._id;
    return { t, me, ada, recordId };
  }

  test("a friend reacts, changes their mind, and takes it back", async () => {
    const { t, me, recordId } = await setup();
    await t.mutation(api.records.react, {
      sessionToken: me.token,
      userId: me.userId,
      recordId,
      emoji: "🔥",
    });
    let row = (await board(t, me)).games.sudoku[0];
    expect(row.reactions).toEqual([{ emoji: "🔥", count: 1 }]);
    expect(row.mine).toBe("🔥");
    // The reactor's id rides along, for their face on the cheer stack.
    expect(row.reactors).toEqual([
      { userId: me.userId, name: "me", emoji: "🔥" },
    ]);

    await t.mutation(api.records.react, {
      sessionToken: me.token,
      userId: me.userId,
      recordId,
      emoji: "🐐",
    });
    row = (await board(t, me)).games.sudoku[0];
    expect(row.reactions).toEqual([{ emoji: "🐐", count: 1 }]);

    await t.mutation(api.records.unreact, {
      sessionToken: me.token,
      userId: me.userId,
      recordId,
    });
    row = (await board(t, me)).games.sudoku[0];
    expect(row.reactions).toEqual([]);
    expect(row.mine).toBeNull();
  });

  test("the holder sees them on their own record", async () => {
    const { t, me, ada, recordId } = await setup();
    await t.mutation(api.records.react, {
      sessionToken: me.token,
      userId: me.userId,
      recordId,
      emoji: "👏",
    });
    const own = (await board(t, ada)).games.sudoku[0];
    expect(own.name).toBe("");
    expect(own.reactions).toEqual([{ emoji: "👏", count: 1 }]);
  });

  test("beating the record clears the cheers the old one had", async () => {
    const { t, me, ada, recordId } = await setup();
    await t.mutation(api.records.react, {
      sessionToken: me.token,
      userId: me.userId,
      recordId,
      emoji: "🔥",
    });
    await solve(t, ada.userId, "sudoku", 50_000, 20);
    const row = (await board(t, me)).games.sudoku[0];
    expect(row.best).toBe(50_000);
    expect(row.reactions).toEqual([]);
  });

  test("refuses your own record, a stranger, and an emoji off the palette", async () => {
    const { t, me, ada, recordId } = await setup();
    const stranger = await signUp(t, "stranger");
    await expect(
      t.mutation(api.records.react, {
        sessionToken: ada.token,
        userId: ada.userId,
        recordId,
        emoji: "🔥",
      }),
    ).rejects.toThrow(/OWN_RECORD/);
    await expect(
      t.mutation(api.records.react, {
        sessionToken: stranger.token,
        userId: stranger.userId,
        recordId,
        emoji: "🔥",
      }),
    ).rejects.toThrow(/NOT_FRIENDS/);
    await expect(
      t.mutation(api.records.react, {
        sessionToken: me.token,
        userId: me.userId,
        recordId,
        emoji: "🍕",
      }),
    ).rejects.toThrow(/BAD_REACTION/);
  });

  test("account teardown takes records and reactions both ways", async () => {
    const { t, me, ada, recordId } = await setup();
    await t.mutation(api.records.react, {
      sessionToken: me.token,
      userId: me.userId,
      recordId,
      emoji: "🔥",
    });
    await t.run(async (ctx: any) => purgeRecordsOf(ctx, ada.userId));
    const left = await t.run(async (ctx: any) => ({
      records: (await ctx.db.query("gameRecords").collect()).length,
      reactions: (await ctx.db.query("recordReactions").collect()).length,
    }));
    expect(left).toEqual({ records: 0, reactions: 0 });
  });
});

describe("the backfill", () => {
  test("builds records from history, and a second run changes nothing", async () => {
    const t = convexTest(schema);
    const me = await signUp(t, "me");
    await t.run(async (ctx: any) => {
      const base = {
        userId: me.userId,
        game: "queens",
        gaveUp: false,
        hintsUsed: 0,
        mistakes: 0,
      };
      await ctx.db.insert("gameResults", {
        ...base,
        dayKey: "2026-09-01",
        startedAt: 1,
        solved: true,
        finishedAt: 100,
        durationMs: 80_000,
      });
      await ctx.db.insert("gameResults", {
        ...base,
        dayKey: "2026-09-02",
        startedAt: 2,
        solved: true,
        finishedAt: 200,
        durationMs: 65_000,
      });
      // A surrender is not a solve.
      await ctx.db.insert("gameResults", {
        ...base,
        dayKey: "2026-09-03",
        startedAt: 3,
        solved: false,
        gaveUp: true,
        finishedAt: 300,
      });
      await ctx.db.insert("puzzleResults", {
        userId: me.userId,
        dayKey: "2026-09-02",
        guesses: [
          [0, 1, 2, 3],
          [1, 2, 3, 4],
          [2, 3, 4, 5],
        ],
        solved: true,
        createdAt: 1,
        updatedAt: 250,
        finishedAt: 250,
      });
    });

    const first: any = await t.mutation(internal.records.backfill, {});
    expect(first.done).toBe(true);
    const queens: any = await recordOf(t, me.userId, "queens");
    expect(queens.best).toBe(65_000);
    expect(queens.dayKey).toBe("2026-09-02");
    expect(queens.achievedAt).toBe(200);
    expect(queens.solves).toBe(2);
    // 09-01 and 09-02 in a row; the 09-03 surrender is not a third.
    expect(queens.streak).toBe(2);
    expect(queens.bestStreak).toBe(2);
    expect(queens.lastSolvedDayKey).toBe("2026-09-02");
    const code: any = await recordOf(t, me.userId, "code");
    expect(code.best).toBe(3);
    expect(code.streak).toBe(1);

    const again: any = await t.mutation(internal.records.backfill, {});
    expect(again.written).toBe(0);
  });
});

describe("sharing the code puzzle", () => {
  async function giveToken(t: ReturnType<typeof convexTest>, userId: any) {
    await t.run(async (ctx: any) => {
      await ctx.db.insert("userDevices", {
        userId,
        deviceId: DEVICE,
        platform: "android",
        fcmToken: `fcm-${userId}`,
        lastSeenAt: Date.now(),
        createdAt: Date.now(),
      });
    });
  }

  test("reaches friends once, and refuses a second send", async () => {
    const t = convexTest(schema);
    const me = await signUp(t, "me");
    const ada = await signUp(t, "ada");
    await befriend(t, me, ada, "ada");
    await giveToken(t, ada.userId);
    await t.mutation(api.puzzle.guess, {
      sessionToken: me.token,
      userId: me.userId,
      dayKey: DAY,
      guess: answerFor(DAY),
    });

    const plan: any = await t.query(internal.socialPush._puzzleAudience, {
      userId: me.userId,
      dayKey: DAY,
    });
    expect(plan.recipients.length).toBe(1);
    expect(plan.solved).toBe(true);
    expect(plan.guessCount).toBe(1);

    await t.mutation(api.puzzle.shareResult, {
      sessionToken: me.token,
      userId: me.userId,
      dayKey: DAY,
    });
    await expect(
      t.mutation(api.puzzle.shareResult, {
        sessionToken: me.token,
        userId: me.userId,
        dayKey: DAY,
      }),
    ).rejects.toThrow(/ALREADY_SHARED/);

    const feed: any = await t.query(api.feed.board, {
      sessionToken: me.token,
      userId: me.userId,
      dayKey: DAY,
    });
    expect(feed.puzzle.mine.shared).toBe(true);
  });

  test("refuses an attempt still in play, and a private player", async () => {
    const t = convexTest(schema);
    const me = await signUp(t, "me");
    await t.mutation(api.puzzle.guess, {
      sessionToken: me.token,
      userId: me.userId,
      dayKey: DAY,
      guess: [...answerFor(DAY)].reverse(),
    });
    await expect(
      t.mutation(api.puzzle.shareResult, {
        sessionToken: me.token,
        userId: me.userId,
        dayKey: DAY,
      }),
    ).rejects.toThrow(/NOT_FINISHED/);

    await t.mutation(api.puzzle.guess, {
      sessionToken: me.token,
      userId: me.userId,
      dayKey: DAY,
      guess: answerFor(DAY),
    });
    await t.run(async (ctx: any) => {
      await ctx.db.patch(me.userId, { visibility: { puzzle: "nobody" } });
    });
    await expect(
      t.mutation(api.puzzle.shareResult, {
        sessionToken: me.token,
        userId: me.userId,
        dayKey: DAY,
      }),
    ).rejects.toThrow(/RESULT_PRIVATE/);
  });
});

describe("a streak", () => {
  test("grows on consecutive days and restarts after a gap", async () => {
    const t = convexTest(schema);
    const me = await signUp(t, "me");
    await solve(t, me.userId, "zip", 50_000, 1, "2026-09-01");
    await solve(t, me.userId, "zip", 50_000, 2, "2026-09-02");
    await solve(t, me.userId, "zip", 50_000, 3, "2026-09-03");
    let r: any = await recordOf(t, me.userId, "zip");
    expect(r.streak).toBe(3);
    expect(r.bestStreak).toBe(3);

    // 09-04 skipped.
    await solve(t, me.userId, "zip", 50_000, 4, "2026-09-05");
    r = await recordOf(t, me.userId, "zip");
    expect(r.streak).toBe(1);
    expect(r.bestStreak).toBe(3);

    // Across a month boundary, which a string compare would get wrong.
    await solve(t, me.userId, "tango", 1, 5, "2026-09-30");
    await solve(t, me.userId, "tango", 1, 6, "2026-10-01");
    expect(((await recordOf(t, me.userId, "tango")) as any).streak).toBe(2);
  });

  test("each game keeps its own", async () => {
    const t = convexTest(schema);
    const me = await signUp(t, "me");
    await solve(t, me.userId, "queens", 1, 1, "2026-09-01");
    await solve(t, me.userId, "queens", 1, 2, "2026-09-02");
    await solve(t, me.userId, "sudoku", 1, 3, "2026-09-02");
    expect(((await recordOf(t, me.userId, "queens")) as any).streak).toBe(2);
    expect(((await recordOf(t, me.userId, "sudoku")) as any).streak).toBe(1);
  });

  test("standings show it while alive, and drop it once a day is missed", async () => {
    const t = convexTest(schema);
    const me = await signUp(t, "me");
    const ece = await signUp(t, "ece");
    await befriend(t, me, ece, "ece");
    await solve(t, ece.userId, "queens", 1, 1, "2026-09-01");
    await solve(t, ece.userId, "queens", 1, 2, "2026-09-02");
    await solve(t, me.userId, "zip", 1, 3, "2026-09-02");

    const standings = async (dayKey: string) =>
      (await t.query(api.games.standings, {
        sessionToken: me.token,
        userId: me.userId,
        dayKey,
      })) as any;

    // The day after: not played yet, still alive.
    const next = await standings("2026-09-03");
    expect(next.streaks[ece.userId]).toEqual({ queens: 2 });
    // Named, for the streak rankings, though she has no row that day.
    expect(next.names[ece.userId]).toBe("ece");
    expect(next.myStreaks.zip).toEqual({ current: 1, best: 1, today: false });

    // Two days on: lapsed, the best remains.
    const later = await standings("2026-09-04");
    expect(later.streaks[ece.userId]).toBeUndefined();
    expect(later.myStreaks.zip).toEqual({ current: 0, best: 1, today: false });

    const same = await standings("2026-09-02");
    expect(same.myStreaks.zip.today).toBe(true);
  });

  test("standings carry faces, and hide one its owner keeps from friends", async () => {
    const t = convexTest(schema);
    const me = await signUp(t, "me");
    const ece = await signUp(t, "ece");
    const ali = await signUp(t, "ali");
    await befriend(t, me, ece, "ece");
    await befriend(t, me, ali, "ali");
    await t.run(async (ctx: any) => {
      const pic = await ctx.storage.store(new Blob(["x"]));
      await ctx.db.patch(ece.userId, { avatarStorageId: pic });
      await ctx.db.patch(ali.userId, {
        avatarStorageId: pic,
        visibility: { avatar: "nobody" },
      });
    });
    await solve(t, ece.userId, "queens", 1, 1, DAY);
    await solve(t, ali.userId, "queens", 1, 1, DAY);
    const s: any = await t.query(api.games.standings, {
      sessionToken: me.token,
      userId: me.userId,
      dayKey: DAY,
    });
    expect(s.avatars[ece.userId]).toBeDefined();
    expect(s.avatars[ali.userId]).toBeUndefined();
  });
});
