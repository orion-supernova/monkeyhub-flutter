import { describe, expect, test } from "vitest";
import {
  EMPTY,
  FALLBACK,
  SIZE,
  countSolutions,
  generate,
  hint,
  isSolved,
  solve,
  type FutoshikiPuzzle,
} from "./futoshiki";

/**
 * Futoshiki's daily contract, measured over most of a year of day keys: the
 * same board for everyone, exactly one answer, a strict checker, hints that
 * only ever tell the truth, and a generator cheap enough to share one query
 * with every other daily.
 */

const DAYS = 320;

function dayKeys(count: number, from = "2026-01-01"): string[] {
  const start = Date.parse(`${from}T00:00:00Z`);
  return Array.from({ length: count }, (_, i) =>
    new Date(start + i * 86_400_000).toISOString().slice(0, 10)
  );
}

/**
 * An independent counter sharing no code with the module's solver: plain
 * row-major backtracking with a direct rule check per placement, no domains, no
 * propagation. Slow by comparison, and on a 5×5 that does not matter.
 */
function bruteCount(p: FutoshikiPuzzle, limit = 2): number {
  const n = p.size;
  const cells = p.givens.slice();
  const signsAt: FutoshikiPuzzle["signs"][] = Array.from({ length: n * n }, () => []);
  for (const s of p.signs) {
    signsAt[s.a].push(s);
    signsAt[s.b].push(s);
  }
  const ok = (i: number, v: number): boolean => {
    const row = Math.floor(i / n);
    const col = i % n;
    for (let k = 0; k < n; k++) {
      if (k !== col && cells[row * n + k] === v) return false;
      if (k !== row && cells[k * n + col] === v) return false;
    }
    for (const s of signsAt[i]) {
      const va = s.a === i ? v : cells[s.a];
      const vb = s.b === i ? v : cells[s.b];
      if (va === EMPTY || vb === EMPTY) continue;
      if (s.lt ? va >= vb : va <= vb) return false;
    }
    return true;
  };
  for (let i = 0; i < cells.length; i++) {
    if (cells[i] !== EMPTY && !ok(i, cells[i])) return 0;
  }
  let count = 0;
  const rec = (i: number): void => {
    if (count >= limit) return;
    if (i === cells.length) {
      count++;
      return;
    }
    if (p.givens[i] !== EMPTY) return rec(i + 1);
    for (let v = 1; v <= n; v++) {
      if (!ok(i, v)) continue;
      cells[i] = v;
      rec(i + 1);
      cells[i] = EMPTY;
      if (count >= limit) return;
    }
  };
  rec(0);
  return count;
}

describe("futoshiki", () => {
  const keys = dayKeys(DAYS);
  const boards = keys.map((k) => generate(k));

  test("is a pure function of the day key", () => {
    for (let i = 0; i < keys.length; i++) {
      expect(JSON.stringify(generate(keys[i]))).toBe(JSON.stringify(boards[i]));
    }
  });

  test("every board is well shaped, medium, and the fallback is almost never needed", () => {
    let fallbacks = 0;
    let givens = 0;
    let signs = 0;
    for (const p of boards) {
      expect(p.size).toBe(SIZE);
      expect(p.difficulty).toBe("medium");
      expect(p.givens.length).toBe(SIZE * SIZE);
      for (const s of p.signs) {
        expect(s.a).toBeLessThan(s.b);
        expect(s.b === s.a + 1 || s.b === s.a + SIZE).toBe(true);
        if (s.b === s.a + 1) expect(s.a % SIZE).not.toBe(SIZE - 1);
      }
      const g = p.givens.filter((v) => v !== EMPTY).length;
      expect(g).toBeLessThanOrEqual(4);
      givens += g;
      signs += p.signs.length;
      if (JSON.stringify(p) === JSON.stringify(FALLBACK)) fallbacks++;
    }
    console.log(
      `futoshiki fallback: ${fallbacks}/${boards.length}; mean givens ` +
        `${(givens / boards.length).toFixed(2)}, mean signs ${(signs / boards.length).toFixed(2)}`
    );
    expect(fallbacks / boards.length).toBeLessThan(0.02);
  });

  test("every board has exactly one answer, by an independent count", () => {
    for (const p of boards) {
      expect(countSolutions(p, 2)).toBe(1);
      expect(bruteCount(p, 2)).toBe(1);
    }
  });

  test("the fallback board is itself unique", () => {
    expect(FALLBACK.signs.length).toBeGreaterThan(0);
    expect(bruteCount(FALLBACK, 2)).toBe(1);
    expect(isSolved(FALLBACK, solve(FALLBACK))).toBe(true);
  });

  test("solve() is accepted and broken answers are not", () => {
    for (const p of boards) {
      const answer = solve(p);
      expect(answer.length).toBe(SIZE * SIZE);
      expect(isSolved(p, answer)).toBe(true);
      for (let i = 0; i < answer.length; i++) {
        if (p.givens[i] !== EMPTY) expect(answer[i]).toBe(p.givens[i]);
      }
      // Every single-cell change breaks it — a Latin square cannot absorb one.
      for (let i = 0; i < answer.length; i += 3) {
        const bad = answer.slice();
        bad[i] = (bad[i] % SIZE) + 1;
        expect(isSolved(p, bad)).toBe(false);
      }
      // Swapping two columns keeps it a Latin square, so only the signs or a
      // given can reject it — which is the point of checking the signs.
      const swapped = answer.slice();
      for (let r = 0; r < SIZE; r++) {
        [swapped[r * SIZE], swapped[r * SIZE + 1]] = [swapped[r * SIZE + 1], swapped[r * SIZE]];
      }
      expect(isSolved(p, swapped)).toBe(false);
    }
  });

  test("garbage never passes and never throws", () => {
    const p = boards[0];
    const answer = solve(p);
    const junk: unknown[] = [
      [],
      answer.slice(0, -1),
      [...answer, 1],
      new Array(25).fill(0),
      new Array(25).fill(6),
      answer.map((v) => v + 0.5),
      answer.map(() => NaN),
      answer.map((v) => -v),
      null,
      "12345",
    ];
    for (const j of junk) {
      expect(() => isSolved(p, j as number[])).not.toThrow();
      expect(isSolved(p, j as number[])).toBe(false);
    }
    const broken = { ...p, signs: [{ a: 4, b: 5, lt: true }] };
    expect(() => isSolved(broken, answer)).not.toThrow();
    expect(isSolved(broken, answer)).toBe(false);
  });

  test("hints only ever reveal the answer, fix mistakes first, and finish the board", () => {
    for (const p of boards) {
      const answer = solve(p);
      const board = p.givens.slice();
      // Two deliberate mistakes on blanks.
      const blanks = board.map((v, i) => (v === EMPTY ? i : -1)).filter((i) => i >= 0);
      board[blanks[0]] = (answer[blanks[0]] % SIZE) + 1;
      board[blanks[1]] = (answer[blanks[1]] % SIZE) + 1;

      let seq = 0;
      for (;;) {
        const h = hint(p, board, seq);
        if (!h) break;
        expect(h.value).toBe(answer[h.index]);
        if (seq < 2) expect(blanks.slice(0, 2)).toContain(h.index);
        board[h.index] = h.value;
        seq++;
        expect(seq).toBeLessThanOrEqual(SIZE * SIZE);
      }
      expect(isSolved(p, board)).toBe(true);
      expect(hint(p, answer, 5)).toBeNull();
    }
    const h = hint(boards[0], [NaN, 99, -1] as number[], 7);
    expect(h).not.toBeNull();
    expect(h!.value).toBe(solve(boards[0])[h!.index]);
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
      `futoshiki generate: p50 ${p50.toFixed(2)} ms, p99 ${p99.toFixed(2)} ms, max ${max.toFixed(2)} ms`
    );
    expect(p99).toBeLessThan(60);
    expect(max).toBeLessThan(150);
  });
});
