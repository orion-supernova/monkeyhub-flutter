import { convexTest } from "convex-test";
import { describe, expect, test } from "vitest";
import { api, internal } from "./_generated/api";
import schema from "./schema";
import { formatDuration } from "./socialPush";

/**
 * Who gets told when a friend posts, and who deliberately does not.
 *
 * The fan-out itself is three `Promise.allSettled` calls over transports that
 * cannot run in a test, so what is checked here is the part that decides
 * WHETHER anybody is reached: `_momentAudience` and `_gameAudience`. Those two
 * queries are the whole privacy surface of this feature, and every gate in them
 * is one line that fails silently in the direction of sending more.
 *
 * Four claims, each of which is a promise to a user rather than a behaviour:
 *
 *   1. **A stranger is never told.** The audience is accepted friendships and
 *      nothing else — no pending request, no one-directional row.
 *   2. **"Nobody" means nobody.** An author whose highlights are private has no
 *      audience for a highlight, and still has one for a point (they are
 *      separate settings, and collapsing them is the obvious wrong fix).
 *   3. **A device that opted out is not in the list.** Both switches, checked
 *      separately, because `friendActivityEnabled` exists precisely so that
 *      turning this off does not turn messages off.
 *   4. **A result can only be shared once.** `sharedAt` is the gate, and it is
 *      on the row rather than in the client, so the second attempt is refused
 *      by the server rather than by a button.
 */

const DEVICE = "device-a";

async function signUp(t: ReturnType<typeof convexTest>, username: string) {
  return await t.mutation(api.auth.signup, {
    username,
    name: username,
    passwordHash: `hash-${username}`,
    recoveryKeyHash: `recovery-${username}`,
    deviceId: DEVICE,
  });
}

/** Accepted both ways, which is what the audience query reads. */
async function befriend(
  t: ReturnType<typeof convexTest>,
  a: { userId: any; token: string },
  b: { userId: any; token: string; username: string },
) {
  await t.mutation(api.friends.sendRequest, {
    sessionToken: a.token,
    userId: a.userId as any,
    friendUsername: b.username,
  });
  await t.mutation(api.friends.acceptRequest, {
    sessionToken: b.token,
    userId: b.userId as any,
    requesterId: a.userId as any,
  });
}

/**
 * Register a push-capable device for [userId].
 *
 * Signing up creates a SESSION carrying the device id, but no `userDevices`
 * row — that is written when the client registers with APNs/FCM and uploads a
 * token, which a test has no way to do. Inserted directly for that reason, on
 * the same `deviceId` the session holds so `liveSessionDeviceIds` matches it.
 *
 * That match is the point of doing it this way rather than stubbing the query:
 * "signed out on this handset" is one of the gates, and a fixture that
 * sidestepped the session would test the audience with that gate permanently
 * open.
 */
async function giveToken(
  t: ReturnType<typeof convexTest>,
  userId: any,
  patch: Record<string, unknown> = {},
) {
  await t.run(async (ctx: any) => {
    await ctx.db.insert("userDevices", {
      userId,
      deviceId: DEVICE,
      platform: "android",
      fcmToken: `fcm-${userId}`,
      lastSeenAt: Date.now(),
      createdAt: Date.now(),
      ...patch,
    });
  });
}

const DAY = "2026-09-06";

/** The number of PEOPLE an audience reaches, or 0 when there is none. */
function reach(plan: any): number {
  return plan === null ? 0 : plan.recipients.length;
}

describe("a posted moment", () => {
  test("reaches an accepted friend who holds a push credential", async () => {
    const t = convexTest(schema);
    const author = await signUp(t, "author");
    const friend = await signUp(t, "friend");
    await befriend(t, author, { ...friend, username: "friend" });
    await giveToken(t, friend.userId);

    const momentId = await t.mutation(api.feed.post, {
      sessionToken: author.token,
      userId: author.userId as any,
      dayKey: DAY,
      caption: "a photo",
    });
    const plan: any = await t.query(internal.socialPush._momentAudience, {
      momentId,
    });
    expect(reach(plan)).toBe(1);
    expect(plan.authorName).toBe("author");
    expect(plan.countToday).toBe(1);
  });

  test("does not reach a stranger, or a pending request", async () => {
    const t = convexTest(schema);
    const author = await signUp(t, "author");
    const stranger = await signUp(t, "stranger");
    await giveToken(t, stranger.userId);
    // Sent but never accepted — one directed row, status "pending". The
    // audience must not read that as a friendship, or every request anybody
    // ever sent becomes a subscription to their board.
    await t.mutation(api.friends.sendRequest, {
      sessionToken: author.token,
      userId: author.userId as any,
      friendUsername: "stranger",
    });

    const momentId = await t.mutation(api.feed.post, {
      sessionToken: author.token,
      userId: author.userId as any,
      dayKey: DAY,
      caption: "a photo",
    });
    expect(
      reach(await t.query(internal.socialPush._momentAudience, { momentId })),
    ).toBe(0);
  });

  test("obeys the author's own highlight/point settings separately", async () => {
    const t = convexTest(schema);
    const author = await signUp(t, "author");
    const friend = await signUp(t, "friend");
    await befriend(t, author, { ...friend, username: "friend" });
    await giveToken(t, friend.userId);

    // Highlights private, points still shared. Two settings because sharing
    // your running joke but not your camera roll is a reasonable position —
    // and a single check would make it unrepresentable.
    await t.run(async (ctx: any) => {
      await ctx.db.patch(author.userId, { visibility: { feed: "nobody" } });
    });

    const highlight = await t.mutation(api.feed.post, {
      sessionToken: author.token,
      userId: author.userId as any,
      dayKey: DAY,
      caption: "a photo",
    });
    const point = await t.mutation(api.feed.post, {
      sessionToken: author.token,
      userId: author.userId as any,
      dayKey: DAY,
      tag: "jinx",
      caption: "the car thing",
    });

    expect(
      reach(
        await t.query(internal.socialPush._momentAudience, {
          momentId: highlight,
        }),
      ),
    ).toBe(0);
    expect(
      reach(
        await t.query(internal.socialPush._momentAudience, {
          momentId: point,
        }),
      ),
    ).toBe(1);
  });

  test("skips a device that switched friend activity off", async () => {
    const t = convexTest(schema);
    const author = await signUp(t, "author");
    const friend = await signUp(t, "friend");
    await befriend(t, author, { ...friend, username: "friend" });
    await giveToken(t, friend.userId, { friendActivityEnabled: false });

    const momentId = await t.mutation(api.feed.post, {
      sessionToken: author.token,
      userId: author.userId as any,
      dayKey: DAY,
      caption: "a photo",
    });
    expect(
      reach(await t.query(internal.socialPush._momentAudience, { momentId })),
    ).toBe(0);
  });

  test("the games switch does NOT silence friend activity", async () => {
    // The two switches are separate on purpose. Somebody who turned off the
    // lunchtime nudge did not ask to stop hearing from their friends, and a
    // single flag would make that impossible to say.
    const t = convexTest(schema);
    const author = await signUp(t, "author");
    const friend = await signUp(t, "friend");
    await befriend(t, author, { ...friend, username: "friend" });
    await giveToken(t, friend.userId, { gameRemindersEnabled: false });

    const momentId = await t.mutation(api.feed.post, {
      sessionToken: author.token,
      userId: author.userId as any,
      dayKey: DAY,
      caption: "a photo",
    });
    expect(
      reach(await t.query(internal.socialPush._momentAudience, { momentId })),
    ).toBe(1);
  });

  test("counts the day's other moments, for the collapsed row", async () => {
    // The banner replaces itself and counts up rather than stacking. The count
    // is read fresh per send, so a dropped delivery does not leave it short.
    const t = convexTest(schema);
    const author = await signUp(t, "author");
    const friend = await signUp(t, "friend");
    await befriend(t, author, { ...friend, username: "friend" });
    await giveToken(t, friend.userId);

    for (const caption of ["one", "two"]) {
      await t.mutation(api.feed.post, {
        sessionToken: author.token,
        userId: author.userId as any,
        dayKey: DAY,
        caption,
      });
    }
    const third = await t.mutation(api.feed.post, {
      sessionToken: author.token,
      userId: author.userId as any,
      dayKey: DAY,
      caption: "three",
    });
    const plan: any = await t.query(internal.socialPush._momentAudience, {
      momentId: third,
    });
    expect(plan.countToday).toBe(3);
    // A different day is a different row in the shade, so it must not be
    // counted into this one.
    const tomorrow = await t.mutation(api.feed.post, {
      sessionToken: author.token,
      userId: author.userId as any,
      dayKey: "2026-09-07",
      caption: "later",
    });
    const next: any = await t.query(internal.socialPush._momentAudience, {
      momentId: tomorrow,
    });
    expect(next.countToday).toBe(1);
  });

  test("a deleted moment reaches nobody rather than throwing", async () => {
    // `feed.post` schedules the action with runAfter(0), so a post-then-delete
    // can genuinely land in between. The action must treat it as "nothing to
    // send", not as an error to retry.
    const t = convexTest(schema);
    const author = await signUp(t, "author");
    const friend = await signUp(t, "friend");
    await befriend(t, author, { ...friend, username: "friend" });
    await giveToken(t, friend.userId);

    const momentId = await t.mutation(api.feed.post, {
      sessionToken: author.token,
      userId: author.userId as any,
      dayKey: DAY,
      caption: "a photo",
    });
    await t.mutation(api.feed.remove, {
      sessionToken: author.token,
      userId: author.userId as any,
      momentId,
    });
    expect(
      await t.query(internal.socialPush._momentAudience, { momentId }),
    ).toBeNull();
  });
});

describe("a shared game result", () => {
  /** Start and solve one game, returning nothing — the row is what matters. */
  async function finish(
    t: ReturnType<typeof convexTest>,
    userId: any,
    token: string,
  ) {
    await t.mutation(api.games.start, {
      sessionToken: token,
      userId: userId as any,
      dayKey: DAY,
      game: "queens",
    });
    // Solving for real would mean reproducing the generator here. The row is
    // patched straight to finished instead: what is under test is the sharing
    // gate, not the solver, which `games.submit` already owns.
    await t.run(async (ctx: any) => {
      const row = await ctx.db
        .query("gameResults")
        .withIndex("by_user_day_game", (q: any) =>
          q.eq("userId", userId).eq("dayKey", DAY).eq("game", "queens"),
        )
        .first();
      await ctx.db.patch(row._id, {
        solved: true,
        finishedAt: Date.now(),
        durationMs: 134_000,
      });
    });
  }

  test("reaches friends, once, and refuses a second send", async () => {
    const t = convexTest(schema);
    const player = await signUp(t, "player");
    const friend = await signUp(t, "friend");
    await befriend(t, player, { ...friend, username: "friend" });
    await giveToken(t, friend.userId);
    await finish(t, player.userId, player.token);

    const plan: any = await t.query(internal.socialPush._gameAudience, {
      userId: player.userId,
      dayKey: DAY,
      game: "queens",
    });
    expect(reach(plan)).toBe(1);
    expect(plan.solved).toBe(true);
    expect(plan.durationMs).toBe(134_000);

    await t.mutation(api.games.shareResult, {
      sessionToken: player.token,
      userId: player.userId as any,
      dayKey: DAY,
      game: "queens",
    });
    // The second attempt is refused by the SERVER. A client-side latch would
    // be one reinstall away from notifying everybody again.
    await expect(
      t.mutation(api.games.shareResult, {
        sessionToken: player.token,
        userId: player.userId as any,
        dayKey: DAY,
        game: "queens",
      }),
    ).rejects.toThrow(/ALREADY_SHARED/);
  });

  test("refuses an unfinished board", async () => {
    const t = convexTest(schema);
    const player = await signUp(t, "player");
    await t.mutation(api.games.start, {
      sessionToken: player.token,
      userId: player.userId as any,
      dayKey: DAY,
      game: "queens",
    });
    await expect(
      t.mutation(api.games.shareResult, {
        sessionToken: player.token,
        userId: player.userId as any,
        dayKey: DAY,
        game: "queens",
      }),
    ).rejects.toThrow(/NOT_FINISHED/);
  });

  test("refuses when the player's own daily scores are private", async () => {
    // `visibility.puzzle` is the switch the standings already obey, so a push
    // that ignored it would open a leaderboard the recipient cannot see the
    // sender on. Refused loudly, where the player is standing.
    const t = convexTest(schema);
    const player = await signUp(t, "player");
    await finish(t, player.userId, player.token);
    await t.run(async (ctx: any) => {
      await ctx.db.patch(player.userId, { visibility: { puzzle: "nobody" } });
    });
    await expect(
      t.mutation(api.games.shareResult, {
        sessionToken: player.token,
        userId: player.userId as any,
        dayKey: DAY,
        game: "queens",
      }),
    ).rejects.toThrow(/RESULT_PRIVATE/);
    // …and the audience query refuses independently, so a future caller that
    // forgets the check above still cannot reach anybody.
    expect(
      await t.query(internal.socialPush._gameAudience, {
        userId: player.userId,
        dayKey: DAY,
        game: "queens",
      }),
    ).toBeNull();
  });

  test("standings report the viewer's own share state, and only theirs", async () => {
    const t = convexTest(schema);
    const player = await signUp(t, "player");
    const friend = await signUp(t, "friend");
    await befriend(t, player, { ...friend, username: "friend" });
    await finish(t, player.userId, player.token);
    await finish(t, friend.userId, friend.token);

    await t.mutation(api.games.shareResult, {
      sessionToken: player.token,
      userId: player.userId as any,
      dayKey: DAY,
      game: "queens",
    });

    const mine: any = await t.query(api.games.standings, {
      sessionToken: player.token,
      userId: player.userId as any,
      dayKey: DAY,
    });
    expect(mine.mine.queens.shared).toBe(true);
    // Whether somebody pressed "tell friends" is a fact about their
    // notification habits, not about the board — so it must not ride on the
    // rows other people read.
    for (const row of mine.boards.queens) {
      expect(row).not.toHaveProperty("shared");
    }
    const theirs: any = await t.query(api.games.standings, {
      sessionToken: friend.token,
      userId: friend.userId as any,
      dayKey: DAY,
    });
    expect(theirs.mine.queens.shared).toBe(false);
  });
});

describe("the time in the body", () => {
  /**
   * The push and the result card have to read the same, and the app's
   * `formatGameTime` truncates. Rounding here once made an 11.7s Zip solve
   * arrive as 0:12 next to the 0:11 the player had just watched the stopwatch
   * stop on, which reads as the wrong time rather than as a rounded one.
   */
  test("truncates like formatGameTime, never rounds up", () => {
    expect(formatDuration(11_700)).toBe("0:11");
    expect(formatDuration(11_000)).toBe("0:11");
    expect(formatDuration(59_999)).toBe("0:59");
    expect(formatDuration(134_000)).toBe("2:14");
    expect(formatDuration(3_787_400)).toBe("63:07");
    expect(formatDuration(undefined)).toBe("0:00");
    expect(formatDuration(-5)).toBe("0:00");
  });
});
