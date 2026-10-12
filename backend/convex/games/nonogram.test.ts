import { describe, expect, test } from "vitest";
import {
  fallback,
  generate,
  generateWithSolution,
  hint,
  isSolved,
  lineSolve,
  NonogramPuzzle,
  SIZE,
  solve,
} from "./nonogram";

/**
 * The nonogram generator, across a year of real day keys.
 *
 * These pin the promises the daily makes to players — every board is the same
 * for everyone, needs no guessing, accepts its own answer and rejects garbage —
 * and the one it makes to the server: all of today's boards are generated in
 * one query with a 1 s limit on a small VPS, so this one gets a hard budget.
 */

const DAYS = 300;

/** `YYYY-MM-DD` for 2026-01-01 plus [n] days. */
function dayKeyAt(n: number): string {
  return new Date(Date.UTC(2026, 0, 1) + n * 86_400_000).toISOString().slice(0, 10);
}

const KEYS = Array.from({ length: DAYS }, (_, i) => dayKeyAt(i));
const BOARDS = KEYS.map((k) => ({ dayKey: k, ...generateWithSolution(k) }));

describe("nonogram", () => {
  test("is a pure function of the day key", () => {
    for (const k of KEYS) expect(generate(k)).toEqual(generate(k));
    // And different days are different boards.
    const distinct = new Set(BOARDS.map((b) => JSON.stringify(b.puzzle)));
    expect(distinct.size).toBeGreaterThan(DAYS - 3);
  });

  test("every board is line-solvable to its own picture", () => {
    for (const b of BOARDS) {
      expect(b.puzzle.size).toBe(SIZE);
      expect(b.puzzle.difficulty).toBe("medium");
      const solved = lineSolve(b.puzzle.rows, b.puzzle.cols);
      expect(solved.contradiction).toBe(false);
      expect(solved.complete).toBe(true);
      expect(Array.from(solved.grid)).toEqual(b.solution);
    }
  });

  test("ships only clues, and passes the look-and-feel gates", () => {
    let ink = 0;
    for (const b of BOARDS) {
      expect(Object.keys(b.puzzle).sort()).toEqual(["cols", "difficulty", "rows", "size"]);
      const lines = [...b.puzzle.rows, ...b.puzzle.cols];
      expect(lines.filter((l) => l.length === 0).length).toBeLessThanOrEqual(1);
      for (const l of lines) expect(l.length).toBeLessThanOrEqual(5);
      ink += b.solution.reduce((a, v) => a + v, 0);
    }
    const density = ink / (DAYS * SIZE * SIZE);
    expect(density).toBeGreaterThan(0.53);
    expect(density).toBeLessThan(0.63);
  });

  test("accepts its own answer and rejects garbage", () => {
    for (const b of BOARDS) {
      const answer = solve(b.puzzle);
      expect(answer).toEqual(b.solution);
      expect(isSolved(b.puzzle, answer)).toBe(true);

      expect(isSolved(b.puzzle, [])).toBe(false);
      expect(isSolved(b.puzzle, answer.slice(0, 99))).toBe(false);
      expect(isSolved(b.puzzle, [...answer, 0])).toBe(false);
      expect(isSolved(b.puzzle, answer.map((v) => (v ? 2 : 0)))).toBe(false);
      expect(isSolved(b.puzzle, answer.map(() => -1))).toBe(false);
      expect(isSolved(b.puzzle, answer.map((v) => 1 - v))).toBe(false);
      const flipped = answer.slice();
      flipped[37] ^= 1;
      expect(isSolved(b.puzzle, flipped)).toBe(false);
    }
    const p = BOARDS[0].puzzle;
    const a = BOARDS[0].solution;
    expect(isSolved(p, null as unknown as number[])).toBe(false);
    expect(isSolved(p, "x" as unknown as number[])).toBe(false);
    expect(isSolved(p, a.map((v) => (v ? "1" : "0")) as unknown as number[])).toBe(false);
    expect(isSolved(p, a.map((v) => (v ? 1 : NaN)))).toBe(false);
    expect(isSolved({ ...p, rows: null } as unknown as NonogramPuzzle, a)).toBe(false);
    expect(isSolved(null as unknown as NonogramPuzzle, a)).toBe(false);
    expect(() => solve({ ...p, cols: [[99]] })).not.toThrow();
    expect(() => hint(null as unknown as NonogramPuzzle, [], 0)).not.toThrow();
  });

  test("hints are always right and finish the board", () => {
    for (const b of BOARDS) {
      const progress = new Array<number>(SIZE * SIZE).fill(-1);
      let seq = 0;
      for (; seq <= SIZE * SIZE; seq++) {
        const h = hint(b.puzzle, progress, seq);
        if (!h) break;
        expect(progress[h.index]).not.toBe(b.solution[h.index]);
        expect(h.value).toBe(b.solution[h.index]);
        progress[h.index] = h.value;
      }
      expect(seq).toBe(SIZE * SIZE);
      expect(progress).toEqual(b.solution);
      expect(isSolved(b.puzzle, progress)).toBe(true);
    }
  });

  test("hints correct a wrong board and survive garbage progress", () => {
    const b = BOARDS[1];
    const progress = b.solution.map((v, i) => (i % 7 === 0 ? 1 - v : v));
    for (let seq = 0; seq < 20; seq++) {
      const h = hint(b.puzzle, progress, seq);
      if (!h) break;
      expect(h.value).toBe(b.solution[h.index]);
      progress[h.index] = h.value;
    }
    expect(progress).toEqual(b.solution);
    expect(hint(b.puzzle, progress, 0)).toBeNull();
    expect(hint(b.puzzle, [], 3)?.value).toBe(b.solution[3]);
    expect(hint(b.puzzle, null as unknown as number[], -5)).not.toBeNull();
  });

  test("the fallback is a real, line-solvable puzzle", () => {
    const { puzzle, solution } = fallback();
    const solved = lineSolve(puzzle.rows, puzzle.cols);
    expect(solved.complete).toBe(true);
    expect(Array.from(solved.grid)).toEqual(solution);
    const lines = [...puzzle.rows, ...puzzle.cols];
    expect(lines.filter((l) => l.length === 0).length).toBeLessThanOrEqual(1);
    expect(isSolved(puzzle, solution)).toBe(true);
  });

  test("falls back on fewer than 2% of days", () => {
    const fallbacks = BOARDS.filter((b) => b.fallback).length;
    expect(fallbacks / DAYS).toBeLessThan(0.02);
  });

  test("generates fast enough for the shared daily query", () => {
    // Warm the JIT on keys outside the measured window, as a long-lived Convex
    // isolate would be.
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
