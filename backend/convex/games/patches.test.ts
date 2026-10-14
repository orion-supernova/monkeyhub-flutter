import { describe, expect, test } from "vitest";
import {
  FALLBACK,
  SIZE,
  cellsOf,
  countSolutions,
  generate,
  isSolved,
  rectOfLabel,
  shapeOf,
  solvableByReasoning,
  solve,
  type PatchesPuzzle,
} from "./patches";
import { patchesHint } from "./hints";

/**
 * Patches' daily contract, over most of a year of day keys: the same board for
 * everyone, exactly one answer, an answer reachable by reasoning alone, a
 * strict checker, hints that only ever tell the truth, and a generator cheap
 * enough to share the `daily` query with nine others.
 */

const DAYS = 320;

function dayKeys(count: number, from = "2026-01-01"): string[] {
  const start = Date.parse(`${from}T00:00:00Z`);
  return Array.from({ length: count }, (_, i) =>
    new Date(start + i * 86_400_000).toISOString().slice(0, 10)
  );
}

/**
 * An independent counter sharing no code with `findSolutions`: it fills the
 * first uncovered square in reading order with every rectangle anchored there,
 * and checks each one against the plain rules — exactly one clue inside, the
 * clue's shape, the clue's area. No candidate lists, no masks, no prunes.
 */
function bruteCount(p: PatchesPuzzle, limit = 2): number {
  const n = p.size;
  const clueAt = new Map(p.clues.map((c, i) => [c.cell, i]));
  const taken = new Array<boolean>(n * n).fill(false);
  let count = 0;

  const rec = (): void => {
    if (count >= limit) return;
    const at = taken.indexOf(false);
    if (at < 0) {
      count++;
      return;
    }
    const top = Math.floor(at / n);
    const left = at % n;
    for (let bottom = top; bottom < n; bottom++) {
      for (let right = left; right < n; right++) {
        const cells: number[] = [];
        for (let r = top; r <= bottom; r++) {
          for (let c = left; c <= right; c++) cells.push(r * n + c);
        }
        if (cells.some((c) => taken[c])) continue;
        const inside = cells.filter((c) => clueAt.has(c));
        if (inside.length !== 1) continue;
        const clue = p.clues[clueAt.get(inside[0])!];
        const h = bottom - top + 1;
        const w = right - left + 1;
        if (clue.area > 0 && clue.area !== h * w) continue;
        if (clue.shape === "square" && h !== w) continue;
        if (clue.shape === "tall" && !(h > w)) continue;
        if (clue.shape === "wide" && !(w > h)) continue;
        for (const c of cells) taken[c] = true;
        rec();
        for (const c of cells) taken[c] = false;
        if (count >= limit) return;
      }
    }
  };
  rec();
  return count;
}

describe("patches", () => {
  const keys = dayKeys(DAYS);
  const boards = keys.map((k) => generate(k));

  test("is a pure function of the day key", () => {
    expect(generate("2026-10-14")).toEqual(generate("2026-10-14"));
    expect(generate("2026-10-14")).not.toEqual(generate("2026-10-15"));
  });

  test("every board is 8 to 10 clues in reading order, and the fallback is never needed", () => {
    let fallbacks = 0;
    for (const p of boards) {
      expect(p.size).toBe(SIZE);
      expect(p.clues.length).toBeGreaterThanOrEqual(8);
      // Ten at most: one palette hue per patch.
      expect(p.clues.length).toBeLessThanOrEqual(10);
      for (let i = 1; i < p.clues.length; i++) {
        expect(p.clues[i].cell).toBeGreaterThan(p.clues[i - 1].cell);
      }
      if (JSON.stringify(p.clues) === JSON.stringify(FALLBACK.clues)) fallbacks++;
    }
    expect(fallbacks).toBe(0);
  });

  test("every board has exactly one answer, by an independent count", () => {
    for (const p of boards) expect(bruteCount(p)).toBe(1);
  });

  test("every board solves by reasoning alone, and is a puzzle rather than a sum", () => {
    for (const p of boards) {
      expect(solvableByReasoning(p)).toBe(true);
      const hidden = p.clues.filter((c) => c.area === 0).length;
      expect(hidden).toBeGreaterThanOrEqual(3);
      expect(hidden).toBeLessThanOrEqual(Math.floor(p.clues.length / 2));
      expect(p.clues.filter((c) => c.shape === "any").length).toBeLessThanOrEqual(2);
      // An ANY clue always keeps its number: a clue that says nothing at all
      // is not a clue.
      for (const c of p.clues) if (c.shape === "any") expect(c.area).toBeGreaterThan(0);
    }
  });

  test("every clue tells the truth about its patch", () => {
    for (const p of boards) {
      const labels = solve(p);
      p.clues.forEach((clue, k) => {
        const rect = rectOfLabel(labels, k)!;
        expect(rect).not.toBeNull();
        expect(cellsOf(rect)).toContain(clue.cell);
        if (clue.area > 0) expect(cellsOf(rect)).toHaveLength(clue.area);
        if (clue.shape !== "any") expect(shapeOf(rect)).toBe(clue.shape);
      });
    }
  });

  test("the fallback board is itself unique and fair", () => {
    expect(bruteCount(FALLBACK)).toBe(1);
    expect(countSolutions(FALLBACK)).toBe(1);
    expect(solvableByReasoning(FALLBACK)).toBe(true);
    expect(isSolved(FALLBACK, solve(FALLBACK))).toBe(true);
  });

  test("solve() is accepted and broken answers are not", () => {
    for (const p of boards.slice(0, 40)) {
      const answer = solve(p);
      expect(isSolved(p, answer)).toBe(true);

      // A clue's square handed to a neighbouring patch.
      const n = p.size;
      const cell = p.clues[0].cell;
      const next = [cell + 1, cell - 1, cell + n, cell - n].find(
        (c) => c >= 0 && c < n * n && answer[c] !== answer[cell]
      );
      if (next !== undefined) {
        const stolen = [...answer];
        stolen[cell] = answer[next];
        expect(isSolved(p, stolen)).toBe(false);
      }

      // Two patches merged into one label: one patch, two clues.
      const merged = answer.map((v) => (v === 1 ? 0 : v));
      expect(isSolved(p, merged)).toBe(false);

      // A square left uncovered.
      const holed = [...answer];
      holed[n * n - 1] = -1;
      expect(isSolved(p, holed)).toBe(false);
    }
  });

  test("a legal cut that breaks a clue's shape or number is refused", () => {
    // One clue, one patch: the whole board, every square labelled 0.
    const whole = new Array(SIZE * SIZE).fill(0);
    const base = { size: SIZE, difficulty: "medium" as const };
    expect(isSolved({ ...base, clues: [{ cell: 24, shape: "square", area: 49 }] }, whole)).toBe(
      true
    );
    expect(isSolved({ ...base, clues: [{ cell: 24, shape: "square", area: 0 }] }, whole)).toBe(
      true
    );
    expect(isSolved({ ...base, clues: [{ cell: 24, shape: "any", area: 48 }] }, whole)).toBe(
      false
    );
    expect(isSolved({ ...base, clues: [{ cell: 24, shape: "tall", area: 0 }] }, whole)).toBe(
      false
    );
    expect(isSolved({ ...base, clues: [{ cell: 24, shape: "wide", area: 49 }] }, whole)).toBe(
      false
    );
  });

  test("garbage never passes and never throws", () => {
    const p = boards[0];
    const k = p.clues.length;
    const bad: unknown[] = [
      [],
      new Array(48).fill(0),
      new Array(50).fill(0),
      new Array(49).fill(k),
      new Array(49).fill(0.5),
      new Array(49).fill(NaN),
      null,
      "nope",
    ];
    for (const b of bad) expect(isSolved(p, b as number[])).toBe(false);
    const broken = [
      { ...p, size: 6 },
      { ...p, clues: [] },
      { ...p, clues: [...p.clues, { ...p.clues[0] }] },
      { ...p, clues: [{ ...p.clues[0], shape: "round" as never }, ...p.clues.slice(1)] },
      { ...p, clues: [{ ...p.clues[0], cell: 49 }, ...p.clues.slice(1)] },
    ];
    for (const q of broken) {
      expect(isSolved(q, solve(p))).toBe(false);
      expect(countSolutions(q)).toBe(0);
    }
  });

  test("hints clear wrong patches first, only ever place the answer, and finish the board", () => {
    for (const p of boards.slice(0, 60)) {
      const answer = solve(p);
      const n = p.size;
      const board = new Array<number>(n * n).fill(-1);

      // A wrong patch down first: clue 0 as just its own square.
      board[p.clues[0].cell] = 0;
      const firstIsRight = answer.filter((v) => v === 0).length === 1;
      if (!firstIsRight) {
        const w = patchesHint(p, board)!;
        expect(w.kind).toBe("wrong");
        expect(w.value).toBe(0);
        expect(w.cells).toEqual([p.clues[0].cell]);
        board[p.clues[0].cell] = -1;
      }

      let steps = 0;
      for (let turn = 0; turn <= p.clues.length; turn++) {
        const h = patchesHint(p, board);
        if (!h) break;
        expect(h.kind).not.toBe("wrong");
        // Reasoning settles every shipped board, so it never has to reveal.
        expect(h.kind).toBe("step");
        expect(["patches.only", "patches.cell", "patches.squeeze"]).toContain(h.reason);
        expect(h.cell).toBe(p.clues[h.value].cell);
        for (const c of h.cells!) {
          expect(answer[c]).toBe(h.value);
          expect(board[c]).toBe(-1);
          board[c] = h.value;
        }
        steps++;
      }
      expect(steps).toBe(p.clues.length - (firstIsRight ? 1 : 0));
      expect(isSolved(p, board)).toBe(true);
      expect(patchesHint(p, board)).toBeNull();
    }
  });

  test("generation is fast", () => {
    const times: number[] = [];
    for (const key of dayKeys(200, "2027-01-01")) {
      const t = performance.now();
      generate(key);
      times.push(performance.now() - t);
    }
    times.sort((a, b) => a - b);
    const p99 = times[Math.floor(times.length * 0.99)];
    const max = times[times.length - 1];
    expect(p99).toBeLessThan(40);
    expect(max).toBeLessThan(120);
  });
});
