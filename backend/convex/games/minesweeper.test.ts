import { describe, expect, test } from "vitest";
import {
  decodeMines,
  encodeMines,
  fallback,
  FLAGGED,
  generate,
  generateWithSolution,
  HIDDEN,
  hint,
  isSolved,
  MINE_COUNT,
  MinesweeperPuzzle,
  playFrom,
  SIZE,
  solve,
} from "./minesweeper";

/**
 * The no-guess minesweeper generator, across a year of real day keys.
 *
 * These pin the promises the daily makes to players — the same board for
 * everyone, an opening tap that is always a 0, a board that never needs a
 * guess, hints that never lie — and the one it makes to the server: all of
 * today's boards are generated in one query with a 1 s limit on a small VPS.
 */

const DAYS = 300;
const N = SIZE * SIZE;

function dayKeyAt(n: number): string {
  return new Date(Date.UTC(2026, 0, 1) + n * 86_400_000).toISOString().slice(0, 10);
}

function neighbours(i: number): number[] {
  const r = Math.floor(i / SIZE);
  const c = i % SIZE;
  const out: number[] = [];
  for (let dr = -1; dr <= 1; dr++) {
    for (let dc = -1; dc <= 1; dc++) {
      const rr = r + dr;
      const cc = c + dc;
      if ((dr || dc) && rr >= 0 && rr < SIZE && cc >= 0 && cc < SIZE) out.push(rr * SIZE + cc);
    }
  }
  return out;
}

function numberAt(mines: number[], i: number): number {
  return neighbours(i).reduce((a, n) => a + mines[n], 0);
}

/** What the client does on a tap: show the number, flood out from zeros. */
function reveal(progress: number[], mines: number[], cell: number): void {
  const stack = [cell];
  while (stack.length > 0) {
    const at = stack.pop()!;
    if (progress[at] >= 0 && progress[at] <= 8) continue;
    progress[at] = numberAt(mines, at);
    if (progress[at] === 0) for (const n of neighbours(at)) if (!mines[n]) stack.push(n);
  }
}

const KEYS = Array.from({ length: DAYS }, (_, i) => dayKeyAt(i));
const BOARDS = KEYS.map((k) => ({ dayKey: k, ...generateWithSolution(k) }));

describe("minesweeper", () => {
  test("is a pure function of the day key", () => {
    for (const k of KEYS) expect(generate(k)).toEqual(generate(k));
    const distinct = new Set(BOARDS.map((b) => b.puzzle.mines));
    expect(distinct.size).toBe(DAYS);
  });

  test("ships a masked layout that decodes to the real one", () => {
    for (const b of BOARDS) {
      expect(Object.keys(b.puzzle).sort()).toEqual([
        "difficulty",
        "mineCount",
        "mines",
        "size",
        "start",
      ]);
      expect(b.puzzle.size).toBe(SIZE);
      expect(b.puzzle.difficulty).toBe("medium");
      expect(b.puzzle.mineCount).toBe(MINE_COUNT);
      expect(b.puzzle.mines).toMatch(/^[0-9a-f]{22}$/);
      const mines = decodeMines(b.puzzle, b.dayKey);
      expect(mines).toEqual(b.solution);
      expect(mines.reduce((a, v) => a + v, 0)).toBe(MINE_COUNT);
      expect(encodeMines(mines, b.dayKey)).toBe(b.puzzle.mines);
    }
    // The mask is not the identity: the raw bitstring is not what ships.
    const b = BOARDS[0];
    expect(decodeMines(b.puzzle, "1999-01-01")).not.toEqual(b.solution);
    expect(decodeMines({ ...b.puzzle, mines: "zz" }, b.dayKey)).toEqual(new Array(N).fill(0));
  });

  test("the start is a 0 with no mine in its 3x3", () => {
    for (const b of BOARDS) {
      const mines = b.solution;
      expect(mines[b.puzzle.start]).toBe(0);
      for (const n of neighbours(b.puzzle.start)) expect(mines[n]).toBe(0);
      expect(numberAt(mines, b.puzzle.start)).toBe(0);
    }
  });

  test("every board clears from its start without a guess", () => {
    for (const b of BOARDS) {
      expect(playFrom(b.solution, b.puzzle.start).cleared).toBe(true);
    }
  });

  test("accepts its own answer and rejects garbage", () => {
    for (const b of BOARDS) {
      const answer = solve(b.puzzle, b.dayKey);
      expect(answer).toEqual(b.solution);
      expect(isSolved(b.puzzle, answer, b.dayKey)).toBe(true);

      expect(isSolved(b.puzzle, [], b.dayKey)).toBe(false);
      expect(isSolved(b.puzzle, answer.slice(0, N - 1), b.dayKey)).toBe(false);
      expect(isSolved(b.puzzle, [...answer, 0], b.dayKey)).toBe(false);
      expect(isSolved(b.puzzle, new Array(N).fill(0), b.dayKey)).toBe(false);
      expect(isSolved(b.puzzle, new Array(N).fill(1), b.dayKey)).toBe(false);
      expect(isSolved(b.puzzle, answer.map((v) => v * 2), b.dayKey)).toBe(false);
      const moved = answer.slice();
      const m = moved.indexOf(1);
      moved[m] = 0;
      moved[answer.findIndex((v, i) => v === 0 && i !== b.puzzle.start)] = 1;
      expect(isSolved(b.puzzle, moved, b.dayKey)).toBe(false);
    }
    const b = BOARDS[0];
    expect(isSolved(b.puzzle, null as unknown as number[], b.dayKey)).toBe(false);
    expect(isSolved(b.puzzle, b.solution.map(String) as unknown as number[], b.dayKey)).toBe(false);
    expect(isSolved(null as unknown as MinesweeperPuzzle, b.solution, b.dayKey)).toBe(false);
    // A garbage mask decodes to "no mines"; an empty map must not win against it.
    expect(isSolved({ ...b.puzzle, mines: "" }, new Array(N).fill(0), b.dayKey)).toBe(false);
    expect(() => hint(null as unknown as MinesweeperPuzzle, [], 0, b.dayKey)).not.toThrow();
    expect(hint({ ...b.puzzle, size: 4 }, [], 0, b.dayKey)).toBeNull();
  });

  test("hints are always right, never a guess, and finish the board", () => {
    for (const b of BOARDS) {
      const mines = b.solution;
      const progress = new Array<number>(N).fill(HIDDEN);
      let seq = 0;
      for (; seq < 2 * N; seq++) {
        const h = hint(b.puzzle, progress, seq, b.dayKey);
        if (!h) break;
        expect(h.value).toBe(mines[h.index]);
        if (h.value === 0) {
          expect(progress[h.index] === HIDDEN || progress[h.index] === FLAGGED).toBe(true);
          reveal(progress, mines, h.index);
        } else {
          expect(progress[h.index]).toBe(HIDDEN);
          progress[h.index] = FLAGGED;
        }
      }
      expect(seq).toBeLessThan(2 * N);
      for (let i = 0; i < N; i++) {
        expect(progress[i]).toBe(mines[i] ? FLAGGED : numberAt(mines, i));
      }
      const submission = progress.map((v) => (v === FLAGGED ? 1 : 0));
      expect(isSolved(b.puzzle, submission, b.dayKey)).toBe(true);
    }
  });

  test("the first hint on a blank board is the start", () => {
    for (const b of BOARDS.slice(0, 20)) {
      const blank = new Array<number>(N).fill(HIDDEN);
      expect(hint(b.puzzle, blank, 0, b.dayKey)).toEqual({ index: b.puzzle.start, value: 0 });
    }
  });

  test("hints ignore wrong flags and lying progress", () => {
    for (const b of BOARDS.slice(0, 60)) {
      const mines = b.solution;
      const progress = new Array<number>(N).fill(HIDDEN);
      reveal(progress, mines, b.puzzle.start);
      // Flag every hidden SAFE cell (all wrong) and claim a mine is revealed.
      for (let i = 0; i < N; i++) if (progress[i] === HIDDEN && !mines[i]) progress[i] = FLAGGED;
      progress[mines.indexOf(1)] = 3;
      for (let seq = 0; seq < 10; seq++) {
        const h = hint(b.puzzle, progress, seq, b.dayKey);
        if (!h) break;
        expect(h.value).toBe(mines[h.index]);
      }
    }
  });

  test("the fallback clears from its start without a guess", () => {
    const { puzzle, solution } = fallback("2026-01-01");
    expect(solution.reduce((a, v) => a + v, 0)).toBe(MINE_COUNT);
    expect(numberAt(solution, puzzle.start)).toBe(0);
    expect(solution[puzzle.start]).toBe(0);
    expect(playFrom(solution, puzzle.start).cleared).toBe(true);
    expect(isSolved(puzzle, solution, "2026-01-01")).toBe(true);
  });

  test("falls back on fewer than 2% of days", () => {
    const fallbacks = BOARDS.filter((b) => b.fallback).length;
    expect(fallbacks / DAYS).toBeLessThan(0.02);
  });

  test("generates fast enough for the shared daily query", () => {
    for (let i = 0; i < 20; i++) generate(`2025-06-${String(i + 1).padStart(2, "0")}`);
    const times: number[] = [];
    for (const k of KEYS) {
      const t = performance.now();
      generate(k);
      times.push(performance.now() - t);
    }
    times.sort((a, b) => a - b);
    const p99 = times[Math.floor(times.length * 0.99)];
    const max = times[times.length - 1];
    expect(p99).toBeLessThan(60);
    expect(max).toBeLessThan(150);
  });
});
