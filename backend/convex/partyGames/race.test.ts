import { describe, expect, test } from "vitest";
import { randomFor } from "../games/rng";
import * as queens from "../games/queens";
import * as sudoku from "../games/sudoku";
import * as tango from "../games/tango";
import * as zip from "../games/zip";
import {
  checkSolution,
  FINISH_GRACE_MS,
  PROGRESS_EVERY_MS,
  PUZZLES,
  RACE_MS,
  rules,
  type RaceKind,
  type RaceState,
} from "./race";

/**
 * Puzzle Race: the daily generators' own `isSolved` is the referee, places go
 * in the order the server accepts finishes, progress is throttled without
 * ever erroring, and the race ends when everyone is done or time is up.
 */

const T0 = 9_000_000;
const KEY = "race:test-match";

function race(kind: RaceKind, seats = 3): RaceState {
  return rules.setup(seats, randomFor("party:t", "race"), { puzzle: kind }, T0, KEY);
}

/** The answer to [s]'s board, from the generator's own solver. */
function answer(s: RaceState): number[] {
  switch (s.kind) {
    case "queens":
      return queens.solve(s.puzzle as queens.QueensPuzzle)!;
    case "tango":
      return tango.solve(s.puzzle as tango.TangoPuzzle)!;
    case "sudoku":
      return sudoku.solve(s.puzzle as sudoku.SudokuPuzzle)!;
    case "zip":
      return zip.generateWithSolution(s.key).solution;
  }
}

describe("the board", () => {
  test.each(PUZZLES)("%s: the generator's board under the match key, judged by isSolved", (kind) => {
    const s = race(kind);
    expect(s.key).toBe(KEY);
    expect(JSON.stringify(s.puzzle)).toBe(JSON.stringify(
      kind === "queens"
        ? queens.generate(KEY)
        : kind === "tango"
          ? tango.generate(KEY)
          : kind === "sudoku"
            ? sudoku.generate(KEY)
            : zip.generate(KEY),
    ));
    const solution = answer(s);
    expect(checkSolution(kind, s.puzzle, solution)).toBe(true);
    const broken = [...solution];
    [broken[0], broken[1]] = [broken[1], broken[0]];
    expect(checkSolution(kind, s.puzzle, broken)).toBe(false);
    expect(checkSolution(kind, s.puzzle, "nope")).toBe(false);
    expect(checkSolution(kind, s.puzzle, [1.5])).toBe(false);
    // The board is public; there is no secret.
    expect(JSON.parse(rules.publicView(s)).puzzle).toEqual(s.puzzle);
    expect(rules.privateView(s, 0)).toBeNull();
  });

  test("no puzzle chosen: a seeded pick, the same every time for the same match", () => {
    const a = rules.setup(2, randomFor("party:m1", "race"), {}, T0, "race:m1");
    const b = rules.setup(2, randomFor("party:m1", "race"), {}, T0, "race:m1");
    expect(PUZZLES).toContain(a.kind);
    expect(a.kind).toBe(b.kind);
  });

  test("options: one of the four, or random", () => {
    expect(rules.parseOptions({ puzzle: "zip" })).toEqual({ puzzle: "zip" });
    expect(rules.parseOptions({ puzzle: "random" })).toEqual({});
    expect(rules.parseOptions({})).toEqual({});
    expect(() => rules.parseOptions({ puzzle: "chess" })).toThrow("BAD_OPTIONS");
  });
});

describe("racing", () => {
  test("a wrong board is refused; right ones are ranked in order, timed by the server", () => {
    let s = race("sudoku");
    const sol = JSON.stringify(answer(s));
    const wrong = JSON.stringify(answer(s).map((v, i) => (i === 0 ? (v % 6) + 1 : v)));
    expect(() => rules.act(s, 0, `finish:${wrong}`, T0)).toThrow("NOT_SOLVED");
    expect(() => rules.act(s, 0, "finish:{oops", T0)).toThrow("NOT_SOLVED");

    s = rules.act(s, 1, `finish:${sol}`, T0 + 61_000);
    s = rules.act(s, 0, `finish:${sol}`, T0 + 75_500);
    expect(s.rank).toEqual([2, 1, null]);
    expect(s.durationMs).toEqual([75_500, 61_000, null]);
    expect(s.progress[1]).toBe(100);
    expect(rules.outcome(s)).toBeNull();
    expect(rules.doneSeats(s)).toEqual([0, 1]);
    expect(() => rules.act(s, 1, `finish:${sol}`, T0)).toThrow("ALREADY_FINISHED");

    s = rules.act(s, 2, `finish:${sol}`, T0 + 90_000);
    expect(rules.outcome(s)).toEqual({ winner: 1, reason: "finished" });
    const pub = JSON.parse(rules.publicView(s));
    expect(pub.phase).toBe("over");
    expect(pub.players[2]).toEqual({ progress: 100, rank: 3, durationMs: 90_000, left: false });
  });

  test("progress is throttled, never refused, and only finishing says 100", () => {
    let s = race("queens");
    s = rules.act(s, 0, "progress:40", T0);
    expect(s.progress[0]).toBe(40);
    const same = rules.act(s, 0, "progress:50", T0 + PROGRESS_EVERY_MS - 1);
    expect(same).toBe(s);
    s = rules.act(s, 0, "progress:100", T0 + PROGRESS_EVERY_MS);
    expect(s.progress[0]).toBe(99);
    // Throttled per seat: another player is not held back by this one.
    s = rules.act(s, 1, "progress:10", T0 + PROGRESS_EVERY_MS);
    expect(s.progress[1]).toBe(10);
    expect(() => rules.act(s, 0, "progress:101", T0 + 10_000)).toThrow("ILLEGAL");
    expect(() => rules.act(s, 0, "progress:-1", T0 + 10_000)).toThrow("ILLEGAL");
  });

  test("everyone races at once: no action is ever stale because of another's", () => {
    const s = race("zip");
    const after = rules.act(s, 0, "progress:20", T0);
    expect(rules.phaseKey(after)).toBe(rules.phaseKey(s));
    expect(rules.turnSeat(s)).toBeNull();
  });
});

describe("the end", () => {
  test("ten minutes in, it is over; nobody finishing is a level end", () => {
    let s = race("tango", 2);
    expect(rules.deadline(s)).toBe(T0 + RACE_MS);
    s = rules.onDeadline(s, T0 + RACE_MS);
    expect(rules.outcome(s)).toEqual({ draw: true, reason: "time" });
    expect(rules.deadline(s)).toBeNull();
  });

  test("time up after someone finished: rank one wins", () => {
    let s = race("sudoku", 3);
    s = rules.act(s, 2, `finish:${JSON.stringify(answer(s))}`, T0 + 1000);
    s = rules.onDeadline(s, T0 + RACE_MS);
    expect(rules.outcome(s)).toEqual({ winner: 2, reason: "time" });
  });

  test("the first finish leaves the rest a short grace, never a longer one", () => {
    let s = race("sudoku", 3);
    const sol = `finish:${JSON.stringify(answer(s))}`;
    s = rules.act(s, 0, sol, T0 + 60_000);
    expect(rules.deadline(s)).toBe(T0 + 60_000 + FINISH_GRACE_MS);
    // A later finish does not move it again.
    s = rules.act(s, 1, sol, T0 + 90_000);
    expect(rules.deadline(s)).toBe(T0 + 60_000 + FINISH_GRACE_MS);
    s = rules.onDeadline(s, T0 + 60_000 + FINISH_GRACE_MS);
    expect(rules.outcome(s)).toEqual({ winner: 0, reason: "time" });
    // A win with less than the grace left keeps the original clock.
    let late = race("sudoku", 2);
    late = rules.act(late, 1, sol, T0 + RACE_MS - 30_000);
    expect(rules.deadline(late)).toBe(T0 + RACE_MS);
  });

  test("a leaver is out; the race ends when everyone still in has finished", () => {
    let s = race("queens", 3);
    s = rules.act(s, 0, `finish:${JSON.stringify(answer(s))}`, T0 + 1000);
    s = rules.forfeit(s, 1, T0 + 2000);
    expect(rules.outcome(s)).toBeNull();
    s = rules.forfeit(s, 2, T0 + 3000);
    expect(rules.outcome(s)).toEqual({ winner: 0, reason: "finished" });
  });

  test("everyone else leaving before anybody finished: the one who stayed wins", () => {
    const s = rules.forfeit(race("zip", 2), 0, T0);
    expect(rules.outcome(s)).toEqual({ winner: 1, reason: "left" });
  });

  test("a pause moves the clock's start with the deadline", () => {
    let s = race("sudoku", 2);
    s = rules.shift(s, 60_000);
    expect(s.startedAt).toBe(T0 + 60_000);
    expect(s.deadline).toBe(T0 + RACE_MS + 60_000);
    s = rules.act(s, 0, `finish:${JSON.stringify(answer(s))}`, T0 + 100_000);
    expect(s.durationMs[0]).toBe(40_000);
  });
});
