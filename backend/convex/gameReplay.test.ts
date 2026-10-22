import { convexTest } from "convex-test";
import { describe, expect, test } from "vitest";
import { api } from "./_generated/api";
import schema from "./schema";
import { answerFor } from "./puzzle";

/**
 * A move resent after a network hiccup is the same move, not another one.
 *
 * The native Convex client keeps every mutation it has sent in flight and
 * resends them when the socket comes back — long after the app has timed the
 * call out and let the player try again. These pin the server half of the
 * fix: a call that names a try (or hint) already counted writes nothing.
 */

const DEVICE = "device-a";
const DAY = "2026-10-07";

type Who = { token: string; userId: any };

async function signUp(t: ReturnType<typeof convexTest>, username: string) {
  return (await t.mutation(api.auth.signup, {
    username,
    name: username,
    passwordHash: `hash-${username}`,
    recoveryKeyHash: `recovery-${username}`,
    // One device per person: a deviceId is one handset, and signing in
    // on it signs out whoever was there before.
    deviceId: `device-${username}`,
  })) as Who;
}

describe("the code puzzle", () => {
  test("a resent guess burns no extra try", async () => {
    const t = convexTest(schema);
    const me = await signUp(t, "me");
    const wrong = [...answerFor(DAY)].reverse();
    const send = (attempt: number) =>
      t.mutation(api.puzzle.guess, {
        sessionToken: me.token,
        userId: me.userId,
        dayKey: DAY,
        guess: wrong,
        attempt,
      });

    const first: any = await send(0);
    expect(first.guesses).toHaveLength(1);
    expect(first.replay).toBe(false);

    // Five more copies of the same try, as a reconnect would replay them.
    for (let i = 0; i < 5; i++) {
      const again: any = await send(0);
      expect(again.replay).toBe(true);
      expect(again.guesses).toHaveLength(1);
      expect(again.done).toBe(false);
    }
  });

  test("a resent winning guess answers with the finished board", async () => {
    const t = convexTest(schema);
    const me = await signUp(t, "me");
    const answer = answerFor(DAY);
    const args = {
      sessionToken: me.token,
      userId: me.userId,
      dayKey: DAY,
      guess: answer,
      attempt: 0,
    };
    await t.mutation(api.puzzle.guess, args);
    const again: any = await t.mutation(api.puzzle.guess, args);
    expect(again.replay).toBe(true);
    expect(again.solved).toBe(true);
    expect(again.done).toBe(true);
  });

  test("a client without attempt still appends, as before", async () => {
    const t = convexTest(schema);
    const me = await signUp(t, "me");
    const wrong = [...answerFor(DAY)].reverse();
    const args = {
      sessionToken: me.token,
      userId: me.userId,
      dayKey: DAY,
      guess: wrong,
    };
    await t.mutation(api.puzzle.guess, args);
    const second: any = await t.mutation(api.puzzle.guess, args);
    expect(second.guesses).toHaveLength(2);
  });
});

describe("daily game hints", () => {
  test("a resent hint is not charged twice", async () => {
    const t = convexTest(schema);
    const me = await signUp(t, "me");
    const base = {
      sessionToken: me.token,
      userId: me.userId,
      dayKey: DAY,
      game: "sudoku",
    };
    await t.mutation(api.games.start, base);
    const board = new Array(36).fill(0);
    const first: any = await t.mutation(api.games.hint, {
      ...base,
      board,
      seq: 0,
    });
    const again: any = await t.mutation(api.games.hint, {
      ...base,
      board,
      seq: 0,
    });
    expect(again).toEqual(first);
    const session: any = await t.mutation(api.games.start, base);
    expect(session.hintsUsed).toBe(1);
  });
});
