import { describe, expect, test } from "vitest";
import {
  FALLBACK,
  SIZE,
  STARS,
  countSolutions,
  generate,
  hint,
  isSolved,
  solve,
  type StarBattlePuzzle,
} from "./starbattle";

/**
 * Star Battle's daily contract, measured over most of a year of day keys: the
 * same board for everyone, exactly one answer, a strict checker, hints that
 * only ever tell the truth, and — the hard one for this game — a generator
 * cheap enough to share one query with every other daily on a 1 GB box.
 */

const DAYS = 320;

function dayKeys(count: number, from = "2026-01-01"): string[] {
  const start = Date.parse(`${from}T00:00:00Z`);
  return Array.from({ length: count }, (_, i) =>
    new Date(start + i * 86_400_000).toISOString().slice(0, 10)
  );
}

/**
 * An independent counter sharing no code with `findSolutions`: it walks
 * COLUMNS rather than rows, picks cells one at a time rather than as pairs, and
 * keeps no memory between branches. The only prunes are the plain rules plus
 * "a region whose last column has passed must be full" and "a row still owed
 * two stars needs three columns left" — both direct consequences of the rules.
 */
function bruteCount(p: StarBattlePuzzle, limit = 2): number {
  const n = p.size;
  const at = (row: number, col: number) => row * n + col;
  const lastCol = new Array<number>(n).fill(-1);
  for (let i = 0; i < n * n; i++) lastCol[p.regions[i]] = Math.max(lastCol[p.regions[i]], i % n);
  const rowCount = new Array<number>(n).fill(0);
  const regCount = new Array<number>(n).fill(0);
  const star = new Array<boolean>(n * n).fill(false);
  let count = 0;

  const touches = (row: number, col: number): boolean => {
    for (let dr = -1; dr <= 1; dr++) {
      for (let dc = -1; dc <= 0; dc++) {
        if (dr === 0 && dc === 0) continue;
        const r = row + dr;
        const c = col + dc;
        if (r >= 0 && r < n && c >= 0 && star[at(r, c)]) return true;
      }
    }
    return false;
  };

  // Places the [k]th star (0 or 1) of column [col], at a row after [from].
  const rec = (col: number, k: number, from: number): void => {
    if (count >= limit) return;
    if (col === n) {
      if (rowCount.every((c) => c === STARS) && regCount.every((c) => c === STARS)) count++;
      return;
    }
    if (k === STARS) {
      for (let g = 0; g < n; g++) if (lastCol[g] === col && regCount[g] !== STARS) return;
      const left = n - 1 - col;
      for (let r = 0; r < n; r++) {
        const need = STARS - rowCount[r];
        if (need === 2 && left < 3) return;
        if (need === 1 && left < 1) return;
      }
      rec(col + 1, 0, -1);
      return;
    }
    for (let row = from + 1; row < n; row++) {
      const i = at(row, col);
      const g = p.regions[i];
      if (rowCount[row] >= STARS || regCount[g] >= STARS || touches(row, col)) continue;
      star[i] = true;
      rowCount[row]++;
      regCount[g]++;
      rec(col, k + 1, row);
      star[i] = false;
      rowCount[row]--;
      regCount[g]--;
      if (count >= limit) return;
    }
  };
  rec(0, 0, -1);
  return count;
}

/** Sizes of each region, and whether each is one connected piece. */
function regionShapes(p: StarBattlePuzzle): { sizes: number[]; connected: boolean } {
  const n = p.size;
  const sizes = new Array<number>(n).fill(0);
  for (const r of p.regions) sizes[r]++;
  let connected = true;
  for (let g = 0; g < n; g++) {
    const first = p.regions.indexOf(g);
    if (first < 0) {
      connected = false;
      continue;
    }
    const seen = new Set([first]);
    const stack = [first];
    while (stack.length) {
      const c = stack.pop()!;
      const row = Math.floor(c / n);
      const col = c % n;
      const around = [
        row > 0 ? c - n : -1,
        row < n - 1 ? c + n : -1,
        col > 0 ? c - 1 : -1,
        col < n - 1 ? c + 1 : -1,
      ];
      for (const x of around) {
        if (x >= 0 && p.regions[x] === g && !seen.has(x)) {
          seen.add(x);
          stack.push(x);
        }
      }
    }
    if (seen.size !== sizes[g]) connected = false;
  }
  return { sizes, connected };
}

describe("starbattle", () => {
  const keys = dayKeys(DAYS);
  const boards = keys.map((k) => generate(k));

  test("is a pure function of the day key", () => {
    for (let i = 0; i < keys.length; i++) {
      expect(JSON.stringify(generate(keys[i]))).toBe(JSON.stringify(boards[i]));
    }
  });

  test("every board is ten connected regions, and the fallback is almost never needed", () => {
    let fallbacks = 0;
    let smallest = Infinity;
    let largest = 0;
    for (const p of boards) {
      expect(p.size).toBe(SIZE);
      expect(p.difficulty).toBe("hard");
      expect(p.regions.length).toBe(SIZE * SIZE);
      const { sizes, connected } = regionShapes(p);
      expect(connected).toBe(true);
      expect(sizes.every((s) => s >= 3)).toBe(true);
      smallest = Math.min(smallest, ...sizes);
      largest = Math.max(largest, ...sizes);
      if (JSON.stringify(p) === JSON.stringify(FALLBACK)) fallbacks++;
    }
    console.log(
      `starbattle fallback: ${fallbacks}/${boards.length}; region sizes ${smallest}..${largest}`
    );
    expect(fallbacks / boards.length).toBeLessThan(0.02);
  });

  test("every board has exactly one answer, by an independent count", () => {
    for (const p of boards) {
      expect(countSolutions(p, 2)).toBe(1);
      expect(bruteCount(p, 2)).toBe(1);
    }
  });

  test("the fallback board is itself unique and well shaped", () => {
    expect(regionShapes(FALLBACK).connected).toBe(true);
    expect(bruteCount(FALLBACK, 2)).toBe(1);
    expect(isSolved(FALLBACK, solve(FALLBACK))).toBe(true);
  });

  test("solve() is accepted and broken answers are not", () => {
    for (const p of boards) {
      const answer = solve(p);
      expect(answer.length).toBe(SIZE * SIZE);
      expect(isSolved(p, answer)).toBe(true);

      // Any one star removed, any one star added.
      for (let i = 0; i < answer.length; i += 7) {
        const bad = answer.slice();
        bad[i] = 1 - bad[i];
        expect(isSolved(p, bad)).toBe(false);
      }
      // A star slid one cell sideways keeps every row count, so only the
      // column, region or touching rule can reject it.
      for (let i = 0; i < answer.length; i++) {
        if (answer[i] !== 1 || i % SIZE === SIZE - 1 || answer[i + 1] === 1) continue;
        const bad = answer.slice();
        bad[i] = 0;
        bad[i + 1] = 1;
        expect(isSolved(p, bad)).toBe(false);
      }
      // Rows swapped wholesale: every count intact, regions and touching not.
      const swapped = [...answer.slice(SIZE), ...answer.slice(0, SIZE)];
      expect(isSolved(p, swapped)).toBe(false);
    }
  });

  test("garbage never passes and never throws", () => {
    const p = boards[0];
    const answer = solve(p);
    const junk: unknown[] = [
      [],
      answer.slice(0, -1),
      [...answer, 0],
      new Array(100).fill(0),
      new Array(100).fill(1),
      answer.map((v) => v * 2),
      answer.map((v) => (v ? true : false)),
      answer.map((v) => String(v)),
      answer.map(() => NaN),
      null,
      "1010",
    ];
    for (const j of junk) {
      expect(() => isSolved(p, j as number[])).not.toThrow();
      expect(isSolved(p, j as number[])).toBe(false);
    }
    const broken = { ...p, regions: p.regions.map(() => 0) };
    expect(() => isSolved(broken, answer)).not.toThrow();
    expect(isSolved(broken, answer)).toBe(false);
    expect(solve(broken)).toEqual([]);
    expect(hint(broken, answer, 0)).toBeNull();
  });

  test("hints only ever reveal the answer, clear wrong stars first, and finish the board", () => {
    for (const p of boards.slice(0, 80)) {
      const answer = solve(p);
      // Start with three wrong stars.
      const board = new Array<number>(answer.length).fill(0);
      const wrongs = answer.map((v, i) => (v === 0 ? i : -1)).filter((i) => i >= 0).slice(0, 3);
      for (const i of wrongs) board[i] = 1;

      let seq = 0;
      for (;;) {
        const h = hint(p, board, seq);
        if (!h) break;
        expect(h.value).toBe(answer[h.index]);
        if (seq < 3) {
          expect(h.value).toBe(0);
          expect(wrongs).toContain(h.index);
        } else {
          expect(h.value).toBe(1);
        }
        board[h.index] = h.value;
        seq++;
        expect(seq).toBeLessThanOrEqual(3 + SIZE * STARS);
      }
      expect(seq).toBe(3 + SIZE * STARS);
      expect(isSolved(p, board)).toBe(true);
      expect(hint(p, answer, 9)).toBeNull();
    }
    // Marks other than 1 read as "not a star", and junk does not throw.
    const p = boards[0];
    const answer = solve(p);
    const marked = answer.map((v) => (v === 1 ? 1 : 2));
    expect(hint(p, marked, 0)).toBeNull();
    const h = hint(p, [NaN, -1, 5] as number[], 4);
    expect(h).not.toBeNull();
    expect(h!.value).toBe(answer[h!.index]);
  });

  test("generation is fast", () => {
    const times: number[] = [];
    for (const k of dayKeys(DAYS, "2027-01-01")) {
      const t = performance.now();
      generate(k);
      times.push(performance.now() - t);
    }
    times.sort((a, b) => a - b);
    const p50 = times[Math.floor(times.length * 0.5)];
    const p99 = times[Math.floor(times.length * 0.99)];
    const max = times[times.length - 1];
    console.log(
      `starbattle generate: p50 ${p50.toFixed(2)} ms, p99 ${p99.toFixed(2)} ms, max ${max.toFixed(2)} ms`
    );
    expect(p99).toBeLessThan(60);
    expect(max).toBeLessThan(150);
  });
});
