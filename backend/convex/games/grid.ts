/**
 * Square-grid helpers shared by the dailies that live on one.
 *
 * Flow and Star Battle both need "the cells next to this one", and Flow needs a
 * random route through every cell as well. Each of the older games carries a
 * private copy of whichever helper it needed; this module exists so the newer
 * ones do not grow more. `zip.ts` and `queens.ts` keep their own copies on
 * purpose: their boards are already shipped, and pointing them at a shared
 * helper would mean that any later change here silently redraws every past
 * day's Zip or Queens board.
 */

import { shuffle } from "./rng";

/** The four orthogonal neighbours of [cell] on an [n]×[n] grid. */
export function neighbours(cell: number, n: number): number[] {
  const row = Math.floor(cell / n);
  const col = cell % n;
  const out: number[] = [];
  if (row > 0) out.push(cell - n);
  if (row < n - 1) out.push(cell + n);
  if (col > 0) out.push(cell - 1);
  if (col < n - 1) out.push(cell + 1);
  return out;
}

/** Whether two cells share an edge. */
export function isAdjacent(a: number, b: number, n: number): boolean {
  const ra = Math.floor(a / n);
  const rb = Math.floor(b / n);
  const ca = a % n;
  const cb = b % n;
  return Math.abs(ra - rb) + Math.abs(ca - cb) === 1;
}

/**
 * A random route through every cell of an [n]×[n] grid, or null if the search
 * gave up after [budget] steps.
 *
 * The same search as Zip's (`zip.ts`): Warnsdorff's rule — always step to the
 * cell with the fewest onward moves — with a randomised tiebreak and full
 * backtracking behind it. A plain random DFS spends most of its time painting
 * itself into a corner and unwinding; the heuristic walks the edges and corners
 * first, which is exactly where a Hamiltonian path has no choice anyway.
 *
 * One addition Zip's 6×6 never needed: **on an odd board the start is drawn
 * from the majority colour of the checkerboard.** A 7×7 grid has 25 cells of
 * one colour and 24 of the other, and a route alternates colours, so it must
 * begin and end on the 25. Starting on the 24 is not "unlucky", it is
 * impossible, and the search would only find that out by exhausting its whole
 * budget — the single most expensive thing this function can do.
 *
 * The step budget is the safety net that lets the caller re-roll instead of
 * hanging: every caller runs inside a Convex query, so "eventually" is not a
 * runtime.
 */
export function hamiltonianPath(
  rand: () => number,
  n: number,
  budget = 120000
): number[] | null {
  const total = n * n;
  const visited = new Array<boolean>(total).fill(false);
  const path: number[] = [];
  let steps = 0;

  const onward = (c: number): number => {
    let k = 0;
    for (const x of neighbours(c, n)) if (!visited[x]) k++;
    return k;
  };

  const rec = (cell: number): boolean => {
    if (++steps > budget) return false;
    visited[cell] = true;
    path.push(cell);
    if (path.length === total) return true;

    const options = shuffle(
      neighbours(cell, n).filter((c) => !visited[c]),
      rand
    );
    options.sort((a, b) => onward(a) - onward(b));
    for (const next of options) {
      if (rec(next)) return true;
    }

    visited[cell] = false;
    path.pop();
    return false;
  };

  let start = Math.floor(rand() * total);
  if (n % 2 === 1) {
    // Majority colour on an odd board is (row + col) even — the corners.
    const row = Math.floor(start / n);
    const col = start % n;
    if ((row + col) % 2 === 1) start = start + 1 < total ? start + 1 : start - 1;
  }
  return rec(start) ? path : null;
}
