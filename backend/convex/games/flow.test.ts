import { describe, expect, test } from "vitest";
import {
  FALLBACK,
  MAX_PAIRS,
  MIN_PAIRS,
  MIN_PIPE,
  SIZE,
  countSolutions,
  generate,
  hint,
  isSolved,
  solve,
  type FlowPuzzle,
} from "./flow";

/**
 * Flow's daily contract, measured over most of a year of day keys.
 *
 * The numbers that matter are the ones a player never sees: that a day's board
 * is the same for everyone, that it has exactly one filling, that the server
 * accepts that filling and nothing else, and that generating it is cheap enough
 * to share one query with every other daily on a 1 GB box.
 */

const DAYS = 320;

function dayKeys(count: number, from = "2026-01-01"): string[] {
  const start = Date.parse(`${from}T00:00:00Z`);
  return Array.from({ length: count }, (_, i) =>
    new Date(start + i * 86_400_000).toISOString().slice(0, 10)
  );
}

/**
 * An independent filling counter that shares no code with `findSolutions`, so
 * a pruning bug in that one cannot also hide here.
 *
 * Decides EDGES rather than drawing pipes: walking the cells row-major, it
 * chooses whether each cell's right and down edges are part of a pipe. A cell's
 * degree is final once both are decided, and must then be exactly 1 for a dot
 * and 2 for anything else. A union-find over the chosen edges rejects a cycle
 * the moment it closes and rejects joining two different colours. With those
 * three rules every surviving edge set is exactly a legal filling — each piece
 * is a simple path whose two degree-1 ends are dots of one colour — so this
 * counts what the rules allow, self-touching pipes included.
 */
function bruteCount(puzzle: FlowPuzzle, limit = 2): number {
  const n = puzzle.size;
  const total = n * n;
  const want = new Array<number>(total).fill(2);
  const dotColour = new Array<number>(total).fill(-1);
  puzzle.endpoints.forEach(([a, b], k) => {
    want[a] = 1;
    want[b] = 1;
    dotColour[a] = k;
    dotColour[b] = k;
  });
  const deg = new Array<number>(total).fill(0);
  const parent = Array.from({ length: total }, (_, i) => i);
  const colour = dotColour.slice();
  const find = (x: number): number => {
    while (parent[x] !== x) x = parent[x];
    return x;
  };
  let count = 0;

  // Joins a and b; returns an undo record, or null if the join is illegal.
  const join = (a: number, b: number): [number, number, number] | null => {
    const ra = find(a);
    const rb = find(b);
    if (ra === rb) return null;
    if (colour[ra] >= 0 && colour[rb] >= 0 && colour[ra] !== colour[rb]) return null;
    const oldColour = colour[ra];
    parent[rb] = ra;
    if (colour[ra] < 0) colour[ra] = colour[rb];
    return [ra, rb, oldColour];
  };
  const unjoin = ([ra, rb, oldColour]: [number, number, number]) => {
    parent[rb] = rb;
    colour[ra] = oldColour;
  };

  const rec = (c: number): void => {
    if (count >= limit) return;
    if (c === total) {
      count++;
      return;
    }
    const row = Math.floor(c / n);
    const col = c % n;
    const canRight = col < n - 1;
    const canDown = row < n - 1;
    for (let mask = 0; mask < 4; mask++) {
      const right = mask & 1;
      const down = (mask >> 1) & 1;
      if ((right && !canRight) || (down && !canDown)) continue;
      if (deg[c] + right + down !== want[c]) continue;
      if (right && deg[c + 1] + 1 > want[c + 1]) continue;
      if (down && deg[c + n] + 1 > want[c + n]) continue;
      const undo: Array<[number, number, number]> = [];
      let ok = true;
      if (right) {
        const u = join(c, c + 1);
        if (u) undo.push(u);
        else ok = false;
      }
      if (ok && down) {
        const u = join(c, c + n);
        if (u) undo.push(u);
        else ok = false;
      }
      if (ok) {
        deg[c] += right + down;
        if (right) deg[c + 1]++;
        if (down) deg[c + n]++;
        rec(c + 1);
        deg[c] -= right + down;
        if (right) deg[c + 1]--;
        if (down) deg[c + n]--;
      }
      for (let i = undo.length - 1; i >= 0; i--) unjoin(undo[i]);
      if (count >= limit) return;
    }
  };
  rec(0);
  return count;
}

/** The answer cut back into one pipe per colour. */
function pipesOf(puzzle: FlowPuzzle, flat: number[]): number[][] {
  const out: number[][] = [];
  let at = 0;
  for (const [, b] of puzzle.endpoints) {
    const pipe: number[] = [];
    for (;;) {
      pipe.push(flat[at++]);
      if (pipe[pipe.length - 1] === b) break;
    }
    out.push(pipe);
  }
  return out;
}

describe("flow", () => {
  const keys = dayKeys(DAYS);
  const boards = keys.map((k) => generate(k));

  test("is a pure function of the day key", () => {
    for (let i = 0; i < keys.length; i++) {
      expect(JSON.stringify(generate(keys[i]))).toBe(JSON.stringify(boards[i]));
    }
  });

  test("every board is well shaped, and the fallback is almost never needed", () => {
    let fallbacks = 0;
    for (const p of boards) {
      expect(p.size).toBe(SIZE);
      expect(p.difficulty).toBe("easy");
      expect(p.endpoints.length).toBeGreaterThanOrEqual(MIN_PAIRS);
      expect(p.endpoints.length).toBeLessThanOrEqual(MAX_PAIRS);
      if (JSON.stringify(p) === JSON.stringify(FALLBACK)) fallbacks++;
    }
    console.log(`flow fallback: ${fallbacks}/${boards.length}`);
    expect(fallbacks / boards.length).toBeLessThan(0.02);
  });

  test("every board has exactly one filling, by an independent count", () => {
    for (const p of boards) {
      expect(countSolutions(p, 2)).toBe(1);
      expect(bruteCount(p, 2)).toBe(1);
    }
  });

  test("the fallback board is itself unique", () => {
    expect(FALLBACK.endpoints.length).toBeGreaterThanOrEqual(MIN_PAIRS);
    expect(bruteCount(FALLBACK, 2)).toBe(1);
    expect(isSolved(FALLBACK, solve(FALLBACK))).toBe(true);
  });

  test("solve() is accepted, every pipe is long enough, and broken answers are not", () => {
    for (const p of boards) {
      const answer = solve(p);
      expect(answer.length).toBe(SIZE * SIZE);
      expect(isSolved(p, answer)).toBe(true);
      for (const pipe of pipesOf(p, answer)) {
        expect(pipe.length).toBeGreaterThanOrEqual(MIN_PIPE);
      }

      // Two adjacent entries swapped: either a jump or a dot out of place.
      for (let i = 0; i + 1 < answer.length; i += 7) {
        const bad = answer.slice();
        [bad[i], bad[i + 1]] = [bad[i + 1], bad[i]];
        expect(isSolved(p, bad)).toBe(false);
      }
      // Pipes in the wrong colour order.
      const pipes = pipesOf(p, answer);
      expect(isSolved(p, [...pipes[1], ...pipes[0], ...pipes.slice(2).flat()])).toBe(false);
      // A pipe drawn backwards.
      expect(isSolved(p, [...pipes[0].slice().reverse(), ...pipes.slice(1).flat()])).toBe(false);
      // A cell used twice, a cell missing, too short, too long.
      const dup = answer.slice();
      dup[dup.length - 2] = dup[0];
      expect(isSolved(p, dup)).toBe(false);
      expect(isSolved(p, answer.slice(0, -1))).toBe(false);
      expect(isSolved(p, [...answer, answer[0]])).toBe(false);
    }
  });

  test("garbage never passes and never throws", () => {
    const p = boards[0];
    const junk: unknown[] = [
      [],
      new Array(49).fill(0),
      new Array(49).fill(-1),
      Array.from({ length: 49 }, (_, i) => i),
      Array.from({ length: 49 }, (_, i) => i + 0.5),
      Array.from({ length: 49 }, () => NaN),
      Array.from({ length: 49 }, (_, i) => i * 100),
      null,
      "nope",
    ];
    for (const j of junk) {
      expect(() => isSolved(p, j as number[])).not.toThrow();
      expect(isSolved(p, j as number[])).toBe(false);
    }
  });

  test("hints only ever reveal answer pipes and finish the board", () => {
    for (const p of boards.slice(0, 60)) {
      const answer = solve(p);
      const pipes = pipesOf(p, answer);
      const offsets: number[] = [];
      let o = 0;
      for (const pipe of pipes) {
        offsets.push(o);
        o += pipe.length;
      }

      // Start from an empty board.
      const board = new Array<number>(answer.length).fill(-1);
      let seq = 0;
      for (;;) {
        const h = hint(p, board, seq);
        if (!h) break;
        expect(h.index).toBe(h.value);
        expect(h.cells).toEqual(pipes[h.index]);
        h.cells!.forEach((c, i) => (board[offsets[h.index] + i] = c));
        seq++;
        expect(seq).toBeLessThanOrEqual(pipes.length);
      }
      expect(seq).toBe(pipes.length);
      expect(isSolved(p, board)).toBe(true);

      // A board that is already right gets nothing.
      expect(hint(p, answer, 0)).toBeNull();
      // A wrong pipe is a candidate even though a dot is in place.
      const wrong = answer.slice();
      [wrong[1], wrong[2]] = [wrong[2], wrong[1]];
      expect(hint(p, wrong, 0)?.index).toBe(0);
      // Junk progress still gets a correct pipe.
      const h = hint(p, [1e9, -5, NaN] as number[], 3);
      expect(h && h.cells).toEqual(pipes[h!.index]);
    }
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
      `flow generate: p50 ${p50.toFixed(2)} ms, p99 ${p99.toFixed(2)} ms, max ${max.toFixed(2)} ms`
    );
    expect(p99).toBeLessThan(60);
    expect(max).toBeLessThan(150);
  });
});
