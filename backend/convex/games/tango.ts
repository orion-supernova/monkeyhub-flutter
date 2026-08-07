/**
 * TANGO — fill a 6×6 grid with two symbols so that
 *
 *  1. no three of the same symbol sit next to each other in a row or column,
 *  2. every row and every column holds exactly three of each, and
 *  3. every `=` pair matches and every `×` pair differs.
 *
 * Two symbols and a handful of operators, so the board is identical in all
 * twelve languages — the same reason Queens and the symbol-code puzzle were
 * chosen over LinkedIn's word games. See `queens.ts` for the full argument.
 *
 * ## Why the puzzle is minimised rather than merely generated
 *
 * A solved grid with a random third of its cells blanked is almost always
 * solvable by inspection: the givens carry the answer and the rules are
 * decoration. `generate` instead strips every given and every operator whose
 * removal leaves the solution still unique, so what survives is exactly the
 * information the rules cannot supply. That is the difference between a grid
 * you fill in and a puzzle you solve.
 */

import { randomFor, range, shuffle } from "./rng";

/** Board edge. */
export const SIZE = 6;

/** Both symbols. Rendered as a sun and a moon; the engine only sees 0 and 1. */
export const SUN = 0;
export const MOON = 1;

/** A cell with nothing in it yet, in both a puzzle's givens and a solver. */
export const EMPTY = -1;

/** An operator printed on the edge between two orthogonally adjacent cells. */
export type TangoSign = {
  /** Cell index, row-major. Always the smaller of the pair. */
  a: number;
  /** The cell to the right of, or below, [a]. */
  b: number;
  /** `=` when true, `×` when false. */
  eq: boolean;
};

export type TangoPuzzle = {
  size: number;
  /** [SUN], [MOON] or [EMPTY] per cell, row-major. */
  givens: number[];
  signs: TangoSign[];
};

/** Half a row, half a column — three of each symbol. */
const PER_LINE = SIZE / 2;

/**
 * Whether placing [value] at [index] keeps a partially-filled grid legal.
 *
 * Checks only what that one cell can have broken, which is what makes the
 * solver's inner loop cheap: the run-of-three windows that contain it, the
 * counts of its own row and column, and the operators touching it.
 */
function allows(
  cells: number[],
  signs: TangoSign[],
  signsByCell: number[][],
  index: number,
  value: number
): boolean {
  const n = SIZE;
  const row = Math.floor(index / n);
  const col = index % n;

  // Rule 1 — no three in a row. The new cell can only complete a run that it
  // sits at the start, middle or end of, so three windows per axis.
  for (let start = col - 2; start <= col; start++) {
    if (start < 0 || start + 2 >= n) continue;
    let run = 0;
    for (let c = start; c <= start + 2; c++) {
      const v = c === col ? value : cells[row * n + c];
      if (v !== value) break;
      run++;
    }
    if (run === 3) return false;
  }
  for (let start = row - 2; start <= row; start++) {
    if (start < 0 || start + 2 >= n) continue;
    let run = 0;
    for (let r = start; r <= start + 2; r++) {
      const v = r === row ? value : cells[r * n + col];
      if (v !== value) break;
      run++;
    }
    if (run === 3) return false;
  }

  // Rule 2 — three of each per line. Counting the *other* symbol too is what
  // turns this from a check into a prune: a row already holding three suns
  // cannot take a fourth, and a row with three moons and two suns forces the
  // last cell before the solver ever reaches it.
  let rowSame = 1;
  let rowOther = 0;
  for (let c = 0; c < n; c++) {
    if (c === col) continue;
    const v = cells[row * n + c];
    if (v === value) rowSame++;
    else if (v !== EMPTY) rowOther++;
  }
  if (rowSame > PER_LINE || rowOther > PER_LINE) return false;

  let colSame = 1;
  let colOther = 0;
  for (let r = 0; r < n; r++) {
    if (r === row) continue;
    const v = cells[r * n + col];
    if (v === value) colSame++;
    else if (v !== EMPTY) colOther++;
  }
  if (colSame > PER_LINE || colOther > PER_LINE) return false;

  // Rule 3 — operators, but only against an endpoint that is already filled.
  for (const s of signsByCell[index]) {
    const sign = signs[s];
    const other = sign.a === index ? sign.b : sign.a;
    const v = cells[other];
    if (v === EMPTY) continue;
    if (sign.eq ? v !== value : v === value) return false;
  }

  return true;
}

/** Which operators touch each cell, so `allows` never scans the whole list. */
function indexSigns(signs: TangoSign[]): number[][] {
  const byCell: number[][] = Array.from({ length: SIZE * SIZE }, () => []);
  for (let i = 0; i < signs.length; i++) {
    byCell[signs[i].a].push(i);
    byCell[signs[i].b].push(i);
  }
  return byCell;
}

/**
 * Counts solutions, stopping at [limit]. Writes the first one into [out].
 *
 * Row-major order rather than most-constrained-first: on a 6×6 binary grid the
 * line-count prune above already collapses the search, and scanning for the
 * best cell every step costs more than it saves.
 */
export function countSolutions(
  puzzle: TangoPuzzle,
  limit = 2,
  out?: number[]
): number {
  const cells = puzzle.givens.slice();
  const signsByCell = indexSigns(puzzle.signs);
  let count = 0;

  // A given that already breaks a rule has no solutions at all — without this
  // the solver would happily "solve" around it.
  for (let i = 0; i < cells.length; i++) {
    if (cells[i] === EMPTY) continue;
    const v = cells[i];
    cells[i] = EMPTY;
    const ok = allows(cells, puzzle.signs, signsByCell, i, v);
    cells[i] = v;
    if (!ok) return 0;
  }

  const rec = (index: number): void => {
    if (count >= limit) return;
    if (index === cells.length) {
      if (out && count === 0) for (let i = 0; i < cells.length; i++) out[i] = cells[i];
      count++;
      return;
    }
    if (cells[index] !== EMPTY) {
      rec(index + 1);
      return;
    }
    for (const value of [SUN, MOON]) {
      if (!allows(cells, puzzle.signs, signsByCell, index, value)) continue;
      cells[index] = value;
      rec(index + 1);
      cells[index] = EMPTY;
      if (count >= limit) return;
    }
  };

  rec(0);
  return count;
}

/** The board's solution, or null if it has none. */
export function solve(puzzle: TangoPuzzle): number[] | null {
  const out = new Array<number>(SIZE * SIZE).fill(EMPTY);
  return countSolutions(puzzle, 1, out) === 1 ? out : null;
}

/**
 * Whether [cells] is a complete, legal grid for [puzzle].
 *
 * Re-derives all three rules instead of comparing against `solve()`, for the
 * same reason as Queens: a legal finished board should never be rejected, even
 * if a future change to the generator lets a second solution through.
 */
export function isSolved(puzzle: TangoPuzzle, cells: number[]): boolean {
  const n = puzzle.size;
  if (cells.length !== n * n) return false;
  for (let i = 0; i < cells.length; i++) {
    if (cells[i] !== SUN && cells[i] !== MOON) return false;
    if (puzzle.givens[i] !== EMPTY && puzzle.givens[i] !== cells[i]) return false;
  }
  for (let line = 0; line < n; line++) {
    let rowSuns = 0;
    let colSuns = 0;
    for (let k = 0; k < n; k++) {
      if (cells[line * n + k] === SUN) rowSuns++;
      if (cells[k * n + line] === SUN) colSuns++;
      if (k >= 2) {
        const a = cells[line * n + k - 2];
        if (a === cells[line * n + k - 1] && a === cells[line * n + k]) return false;
        const b = cells[(k - 2) * n + line];
        if (b === cells[(k - 1) * n + line] && b === cells[k * n + line]) return false;
      }
    }
    if (rowSuns !== PER_LINE || colSuns !== PER_LINE) return false;
  }
  for (const s of puzzle.signs) {
    const same = cells[s.a] === cells[s.b];
    if (s.eq !== same) return false;
  }
  return true;
}

/** A complete legal grid, ignoring operators — the answer the puzzle hides. */
function fullGrid(rand: () => number): number[] | null {
  const cells = new Array<number>(SIZE * SIZE).fill(EMPTY);
  const noSigns: TangoSign[] = [];
  const byCell = indexSigns(noSigns);
  let steps = 0;

  const rec = (index: number): boolean => {
    if (++steps > 200000) return false;
    if (index === cells.length) return true;
    // Shuffled so the day's grid is not the same lexicographic-first board
    // every time — with a fixed order every day's answer starts `010101`.
    for (const value of shuffle([SUN, MOON], rand)) {
      if (!allows(cells, noSigns, byCell, index, value)) continue;
      cells[index] = value;
      if (rec(index + 1)) return true;
      cells[index] = EMPTY;
    }
    return false;
  };

  return rec(0) ? cells : null;
}

/** Every orthogonally adjacent pair, as the operator the solution implies. */
function allSigns(solution: number[]): TangoSign[] {
  const signs: TangoSign[] = [];
  for (let row = 0; row < SIZE; row++) {
    for (let col = 0; col < SIZE; col++) {
      const i = row * SIZE + col;
      if (col < SIZE - 1) {
        signs.push({ a: i, b: i + 1, eq: solution[i] === solution[i + 1] });
      }
      if (row < SIZE - 1) {
        signs.push({ a: i, b: i + SIZE, eq: solution[i] === solution[i + SIZE] });
      }
    }
  }
  return signs;
}

/**
 * How few givens the minimiser is allowed to leave.
 *
 * Zero would often still be uniquely solvable off operators alone, and a board
 * with nothing printed in it reads as broken rather than hard — there is no
 * foothold to make a first move from, only a cold start.
 */
const MIN_GIVENS = 3;

/**
 * Today's board.
 *
 * Builds the answer, offers the solver far more information than it needs, then
 * takes away everything it can still do without.
 *
 * **Givens go first, operators second, and the order is not a detail.** Doing it
 * the other way round produces a board with no operators at all on every single
 * day — while all thirty-six cells are still printed, no operator is ever load-
 * bearing, so the minimiser correctly removes every one of them, and what ships
 * is a fill-in-the-blanks grid with Tango's entire distinguishing mechanic
 * stripped out. Removing the givens first forces the operators to carry the
 * board, and only the ones that genuinely do survive the second pass.
 */
export function generate(dayKey: string): TangoPuzzle {
  let fallback: TangoPuzzle | null = null;

  for (let attempt = 0; attempt < 24; attempt++) {
    const rand = randomFor(dayKey, "tango", attempt);
    const solution = fullGrid(rand);
    if (!solution) continue;

    // Start from a generous, random slice of the operator set. Offering all 60
    // and minimising down works too, but costs 60 solver runs to reach the same
    // place, and every day's board would then carry whichever operators happen
    // to survive a fixed order rather than a different handful each day.
    const pool = shuffle(allSigns(solution), rand);
    const signs = pool.slice(0, 10 + Math.floor(rand() * 5));
    const puzzle: TangoPuzzle = { size: SIZE, givens: solution.slice(), signs };
    fallback ??= puzzle;

    let given = puzzle.givens.length;
    for (const i of shuffle(range(SIZE * SIZE), rand)) {
      if (given <= MIN_GIVENS) break;
      const value = puzzle.givens[i];
      puzzle.givens[i] = EMPTY;
      if (countSolutions(puzzle, 2) === 1) given--;
      else puzzle.givens[i] = value;
    }

    for (let s = puzzle.signs.length - 1; s >= 0; s--) {
      const removed = puzzle.signs.splice(s, 1)[0];
      if (countSolutions(puzzle, 2) !== 1) puzzle.signs.splice(s, 0, removed);
    }

    if (puzzle.signs.length >= 3 && countSolutions(puzzle, 2) === 1) return puzzle;
  }

  return (
    fallback ?? {
      size: SIZE,
      givens: new Array(SIZE * SIZE).fill(EMPTY),
      signs: [],
    }
  );
}
