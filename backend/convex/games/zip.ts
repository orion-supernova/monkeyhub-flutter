/**
 * ZIP — draw one unbroken line from ① to the last numbered dot that passes
 * through every cell of the grid exactly once, taking the numbers in order.
 *
 * Numbers and a line, so the board is the same in all twelve languages. See
 * `queens.ts` for why that constraint decided which of LinkedIn's dailies could
 * be built here at all.
 *
 * ## Why this one is not checked for a unique solution
 *
 * Queens and Tango have an answer, and a second answer would let a lucky guess
 * beat a solved deduction on a timed board. Zip has a *rule*: cover every cell,
 * in order, without lifting the pen. Any line that does that has genuinely
 * solved it, and there is no sense in which a player who found a different
 * legal route did less work. So `isSolved` validates the route rather than
 * comparing it to a stored one, and generation only has to prove that at least
 * one route exists — which it does by construction, having drawn it first.
 */

import { randomFor, shuffle } from "./rng";

/** Board edge. */
export const SIZE = 6;

/** Numbered dots on the board, ① through this. */
export const CHECKPOINTS = 8;

export type ZipPuzzle = {
  size: number;
  /** Cell index of each numbered dot, ① first. Row-major indices. */
  checkpoints: number[];
};

/** The four orthogonal neighbours of [cell] on an [n]×[n] grid. */
function neighbours(cell: number, n: number): number[] {
  const row = Math.floor(cell / n);
  const col = cell % n;
  const out: number[] = [];
  if (row > 0) out.push(cell - n);
  if (row < n - 1) out.push(cell + n);
  if (col > 0) out.push(cell - 1);
  if (col < n - 1) out.push(cell + 1);
  return out;
}

/**
 * A random route through every cell of the grid, or null if the search gave up.
 *
 * Warnsdorff's rule — always step to the cell with the fewest onward moves —
 * with a randomised tiebreak and full backtracking behind it. A plain random
 * DFS on a 6×6 grid spends most of its time painting itself into a corner and
 * unwinding; the heuristic walks the edges and corners first, which is exactly
 * where a Hamiltonian path has no choice anyway, and finds a route almost
 * immediately.
 *
 * The step budget is the safety net that lets the caller re-roll instead of
 * hanging: this runs inside a Convex query, so "eventually" is not a runtime.
 */
function hamiltonianPath(rand: () => number, n: number): number[] | null {
  const total = n * n;
  const visited = new Array<boolean>(total).fill(false);
  const path: number[] = [];
  let steps = 0;

  const rec = (cell: number): boolean => {
    if (++steps > 120000) return false;
    visited[cell] = true;
    path.push(cell);
    if (path.length === total) return true;

    const options = shuffle(
      neighbours(cell, n).filter((c) => !visited[c]),
      rand
    );
    options.sort(
      (a, b) =>
        neighbours(a, n).filter((c) => !visited[c]).length -
        neighbours(b, n).filter((c) => !visited[c]).length
    );
    for (const next of options) {
      if (rec(next)) return true;
    }

    visited[cell] = false;
    path.pop();
    return false;
  };

  const start = Math.floor(rand() * total);
  return rec(start) ? path : null;
}

/**
 * Picks which stops along [path] get a number.
 *
 * The first and last cells are always numbered — they are what makes the route
 * a line from ① to ⑧ rather than a loop the player may enter anywhere. The rest
 * are spread with a minimum gap, because two dots three cells apart constrain
 * nothing the line was not already going to do, and a board whose numbers all
 * cluster in one corner is a board with one interesting quarter.
 */
function chooseCheckpoints(
  rand: () => number,
  path: number[],
  count: number
): number[] | null {
  const gap = Math.floor(path.length / count) - 1;
  for (let attempt = 0; attempt < 200; attempt++) {
    const picks = [0, path.length - 1];
    const interior = shuffle(
      Array.from({ length: path.length - 2 }, (_, i) => i + 1),
      rand
    );
    for (const i of interior) {
      if (picks.length >= count) break;
      if (picks.every((p) => Math.abs(p - i) >= gap)) picks.push(i);
    }
    if (picks.length === count) {
      picks.sort((a, b) => a - b);
      return picks.map((i) => path[i]);
    }
  }
  return null;
}

/**
 * Whether [path] is a legal route for [puzzle].
 *
 * The authority on winning, and the whole of the game's rules in one place:
 * every cell exactly once, orthogonal steps only, starting on ① , ending on the
 * last dot, and meeting the numbers in order.
 */
export function isSolved(puzzle: ZipPuzzle, path: number[]): boolean {
  const n = puzzle.size;
  const total = n * n;
  if (path.length !== total) return false;

  const seen = new Array<boolean>(total).fill(false);
  for (let i = 0; i < path.length; i++) {
    const cell = path[i];
    if (!Number.isInteger(cell) || cell < 0 || cell >= total) return false;
    if (seen[cell]) return false;
    seen[cell] = true;
    if (i > 0 && !neighbours(path[i - 1], n).includes(cell)) return false;
  }

  const order = puzzle.checkpoints.map((cell) => path.indexOf(cell));
  if (order[0] !== 0) return false;
  if (order[order.length - 1] !== total - 1) return false;
  for (let i = 1; i < order.length; i++) {
    if (order[i] <= order[i - 1]) return false;
  }
  return true;
}

/** Today's board, and the route it was drawn from — used to reveal a give-up. */
export function generateWithSolution(dayKey: string): {
  puzzle: ZipPuzzle;
  solution: number[];
} {
  for (let attempt = 0; attempt < 40; attempt++) {
    const rand = randomFor(dayKey, "zip", attempt);
    const path = hamiltonianPath(rand, SIZE);
    if (!path) continue;
    const checkpoints = chooseCheckpoints(rand, path, CHECKPOINTS);
    if (!checkpoints) continue;
    return { puzzle: { size: SIZE, checkpoints }, solution: path };
  }

  // Unreachable in practice — a 6×6 grid is densely Hamiltonian and the search
  // above clears on the first attempt. A serpentine fallback keeps the daily
  // playable rather than blank if it ever is not.
  const path: number[] = [];
  for (let row = 0; row < SIZE; row++) {
    for (let col = 0; col < SIZE; col++) {
      path.push(row * SIZE + (row % 2 === 0 ? col : SIZE - 1 - col));
    }
  }
  const stride = Math.floor((path.length - 1) / (CHECKPOINTS - 1));
  const checkpoints = Array.from({ length: CHECKPOINTS }, (_, i) =>
    path[Math.min(i * stride, path.length - 1)]
  );
  return { puzzle: { size: SIZE, checkpoints }, solution: path };
}

export function generate(dayKey: string): ZipPuzzle {
  return generateWithSolution(dayKey).puzzle;
}
