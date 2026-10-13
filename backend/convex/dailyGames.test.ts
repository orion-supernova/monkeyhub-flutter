import { convexTest } from "convex-test";
import { describe, expect, test } from "vitest";
import { api } from "./_generated/api";
import schema from "./schema";
import { MINE_PENALTY_MS } from "./games";
import * as flow from "./games/flow";
import * as futoshiki from "./games/futoshiki";
import * as minesweeper from "./games/minesweeper";
import * as nonogram from "./games/nonogram";
import * as starbattle from "./games/starbattle";

/**
 * The five newer dailies, end to end through the mutations.
 *
 * The engines have their own tests (`games/*.test.ts`); what is pinned here is
 * the wiring in `games.ts` that those cannot see: each game is routed to its
 * own checker and its own hint, the per-game cell caps are the board's real
 * size rather than the 64 the first four fit under, the hint replay guard
 * still holds when the engine (not the generic diff) picks the cell, and
 * Minesweeper's clock penalty survives the server's clamp.
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
    deviceId: DEVICE,
  })) as Who;
}

/** Each new game's board and server answer for [DAY], as the engines see it. */
const ANSWERS: Record<string, number[]> = {
  flow: flow.solve(flow.generate(DAY)),
  futoshiki: futoshiki.solve(futoshiki.generate(DAY)),
  nonogram: nonogram.solve(nonogram.generate(DAY)),
  minesweeper: minesweeper.solve(minesweeper.generate(DAY), DAY),
  starbattle: starbattle.solve(starbattle.generate(DAY)),
};

async function session(t: ReturnType<typeof convexTest>, game: string) {
  const me = await signUp(t, `p${game}`);
  const base = {
    sessionToken: me.token,
    userId: me.userId,
    dayKey: DAY,
    game,
  };
  await t.mutation(api.games.start, base);
  return base;
}

async function hintsUsed(t: ReturnType<typeof convexTest>, base: any) {
  const s: any = await t.mutation(api.games.start, base);
  return s.hintsUsed;
}

describe("the daily payload", () => {
  test("serves all nine boards", async () => {
    const t = convexTest(schema);
    const me = await signUp(t, "reader");
    const day: any = await t.query(api.games.daily, {
      sessionToken: me.token,
      dayKey: DAY,
    } as any);
    expect(day.games.map((g: any) => g.id)).toEqual([
      "queens",
      "tango",
      "zip",
      "sudoku",
      "flow",
      "futoshiki",
      "nonogram",
      "minesweeper",
      "starbattle",
    ]);
    expect(day.flow).toEqual(flow.generate(DAY));
    expect(day.futoshiki.size).toBe(5);
    expect(day.nonogram.rows).toHaveLength(10);
    expect(typeof day.minesweeper.mines).toBe("string");
    expect(day.starbattle.regions).toHaveLength(100);
  });
});

describe("submitting a new game", () => {
  for (const game of Object.keys(ANSWERS)) {
    test(`${game}: the server answer is a solve`, async () => {
      const t = convexTest(schema);
      const base = await session(t, game);
      const out: any = await t.mutation(api.games.submit, {
        ...base,
        solution: ANSWERS[game],
        elapsedMs: 0,
        hintsUsed: 0,
        mistakes: 0,
      });
      expect(out.solved).toBe(true);
      expect(out.replay).toBe(false);
    });

    test(`${game}: a board one cell off is refused`, async () => {
      const t = convexTest(schema);
      const base = await session(t, game);
      const wrong = [...ANSWERS[game]];
      // Flow's answer is a route of cell indices, so swapping two of them
      // breaks adjacency; for the per-cell games flip the first cell.
      if (game === "flow") {
        [wrong[1], wrong[2]] = [wrong[2], wrong[1]];
      } else if (game === "futoshiki") {
        wrong[0] = wrong[0] === 1 ? 2 : 1;
      } else {
        wrong[0] = wrong[0] === 1 ? 0 : 1;
      }
      await expect(
        t.mutation(api.games.submit, {
          ...base,
          solution: wrong,
          elapsedMs: 0,
          hintsUsed: 0,
          mistakes: 0,
        })
      ).rejects.toThrow(/NOT_SOLVED/);
    });
  }
});

describe("hints for a new game", () => {
  /** An untouched board in the shape each game's hint reads. */
  const blank: Record<string, () => number[]> = {
    flow: () => [],
    futoshiki: () => new Array(25).fill(0),
    nonogram: () => new Array(100).fill(-1),
    minesweeper: () => new Array(81).fill(-1),
    starbattle: () => new Array(100).fill(0),
  };

  for (const game of Object.keys(ANSWERS)) {
    test(`${game}: a hint is a real cell and costs one`, async () => {
      const t = convexTest(schema);
      const base = await session(t, game);
      const h: any = await t.mutation(api.games.hint, {
        ...base,
        board: blank[game](),
        seq: 0,
      });
      expect(h.index).toBeGreaterThanOrEqual(0);
      if (game === "minesweeper") {
        // Nothing revealed yet: the only provable move is the promised start.
        const start = minesweeper.generate(DAY).start;
        expect(h).toMatchObject({ index: start, value: 0, kind: "step", cell: start });
      } else if (game === "flow") {
        // A colour, and that colour's whole pipe dot to dot.
        const ends = flow.generate(DAY).endpoints[h.index];
        expect(h.value).toBe(h.index);
        expect(h.cells[0]).toBe(ends[0]);
        expect(h.cells[h.cells.length - 1]).toBe(ends[1]);
      } else {
        expect(h.value).toBe(ANSWERS[game][h.index]);
        expect(h.cells).toBeUndefined();
        // The explained half: a forced step (or, on Star Battle's hard empty
        // board, a labelled reveal), with the squares it is about.
        expect(["step", "reveal"]).toContain(h.kind);
        expect(typeof h.reason).toBe("string");
        expect(h.area).toContain(h.cell);
      }
      expect(await hintsUsed(t, base)).toBe(1);
    });
  }

  test("a resent hint is not charged twice", async () => {
    const t = convexTest(schema);
    const base = await session(t, "nonogram");
    const board = new Array(100).fill(-1);
    const first: any = await t.mutation(api.games.hint, { ...base, board, seq: 0 });
    const again: any = await t.mutation(api.games.hint, { ...base, board, seq: 0 });
    expect(again).toEqual(first);
    expect(await hintsUsed(t, base)).toBe(1);
    // A new hint on the board the first one changed is the next step.
    const after = [...board];
    after[first.cell] = first.answer;
    const next: any = await t.mutation(api.games.hint, { ...base, board: after, seq: 1 });
    expect(next.cell).not.toBe(first.cell);
    expect(await hintsUsed(t, base)).toBe(2);
  });

  test("a board already right everywhere gets nothing, free", async () => {
    const t = convexTest(schema);
    const base = await session(t, "starbattle");
    const h: any = await t.mutation(api.games.hint, {
      ...base,
      board: ANSWERS.starbattle,
      seq: 0,
    });
    expect(h).toEqual({ index: -1, value: 0 });
    expect(await hintsUsed(t, base)).toBe(0);
  });

  test("zip still has no hint", async () => {
    const t = convexTest(schema);
    const base = await session(t, "zip");
    await expect(
      t.mutation(api.games.hint, { ...base, board: [], seq: 0 })
    ).rejects.toThrow(/NO_HINT/);
  });
});

describe("per-game cell caps", () => {
  test("a nonogram autosave of 100 cells fits, 101 does not", async () => {
    const t = convexTest(schema);
    const base = await session(t, "nonogram");
    await t.mutation(api.games.saveProgress, {
      ...base,
      progress: new Array(100).fill(-1),
      elapsedMs: 1000,
      mistakes: 0,
    });
    await expect(
      t.mutation(api.games.saveProgress, {
        ...base,
        progress: new Array(101).fill(-1),
        elapsedMs: 1000,
        mistakes: 0,
      })
    ).rejects.toThrow(/BAD_PROGRESS/);
  });

  test("the old games keep their own size, not the biggest one", async () => {
    const t = convexTest(schema);
    const base = await session(t, "sudoku");
    await expect(
      t.mutation(api.games.saveProgress, {
        ...base,
        progress: new Array(37).fill(0),
        elapsedMs: 0,
        mistakes: 0,
      })
    ).rejects.toThrow(/BAD_PROGRESS/);
  });
});

describe("minesweeper's clock penalty", () => {
  test("two mine hits keep their minute past the wall clock", async () => {
    const t = convexTest(schema);
    const base = await session(t, "minesweeper");
    const out: any = await t.mutation(api.games.submit, {
      ...base,
      solution: ANSWERS.minesweeper,
      // Played in (almost) no time, but two mines were stepped on.
      elapsedMs: 2 * MINE_PENALTY_MS,
      hintsUsed: 0,
      mistakes: 2,
    });
    expect(out.solved).toBe(true);
    expect(out.durationMs).toBeGreaterThanOrEqual(2 * MINE_PENALTY_MS);
  });

  test("but no further than the penalties it reported", async () => {
    const t = convexTest(schema);
    const base = await session(t, "minesweeper");
    const out: any = await t.mutation(api.games.submit, {
      ...base,
      solution: ANSWERS.minesweeper,
      elapsedMs: 10 * MINE_PENALTY_MS,
      hintsUsed: 0,
      mistakes: 2,
    });
    expect(out.durationMs).toBeLessThan(3 * MINE_PENALTY_MS);
  });

  test("other games get no allowance for mistakes", async () => {
    const t = convexTest(schema);
    const base = await session(t, "nonogram");
    const out: any = await t.mutation(api.games.submit, {
      ...base,
      solution: ANSWERS.nonogram,
      elapsedMs: 2 * MINE_PENALTY_MS,
      hintsUsed: 0,
      mistakes: 2,
    });
    expect(out.durationMs).toBeLessThan(MINE_PENALTY_MS);
  });
});
