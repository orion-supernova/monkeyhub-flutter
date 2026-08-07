/**
 * MINI SUDOKU — a 6×6 grid of the digits 1-6, each appearing once per row, once
 * per column, and once in each 2-tall, 3-wide box.
 *
 * Digits, so it reads identically in all twelve languages — see `queens.ts` for
 * why that decided the shortlist. Six is also the point of the "mini": a 9×9
 * grid is a fifteen-minute sit-down, and a daily that friends compare has to be
 * something you can finish while the kettle boils.
 */

import { randomFor, range, shuffle } from "./rng";

/** Board edge. */
export const SIZE = 6;

/** Box shape: two rows tall, three columns wide, so six boxes tile the grid. */
export const BOX_ROWS = 2;
export const BOX_COLS = 3;

/** A cell with nothing in it. Filled cells hold 1..SIZE. */
export const EMPTY = 0;

export type SudokuPuzzle = {
  size: number;
  /** [EMPTY] or 1..SIZE per cell, row-major. */
  givens: number[];
};

/** The top-left cell of the box containing [index]. */
function boxOrigin(index: number): number {
  const row = Math.floor(index / SIZE);
  const col = index % SIZE;
  return (row - (row % BOX_ROWS)) * SIZE + (col - (col % BOX_COLS));
}

/** Whether [value] may go at [index] given what is already placed. */
function allows(cells: number[], index: number, value: number): boolean {
  const row = Math.floor(index / SIZE);
  const col = index % SIZE;
  for (let k = 0; k < SIZE; k++) {
    if (k !== col && cells[row * SIZE + k] === value) return false;
    if (k !== row && cells[k * SIZE + col] === value) return false;
  }
  const origin = boxOrigin(index);
  for (let r = 0; r < BOX_ROWS; r++) {
    for (let c = 0; c < BOX_COLS; c++) {
      const i = origin + r * SIZE + c;
      if (i !== index && cells[i] === value) return false;
    }
  }
  return true;
}

/**
 * Counts solutions, stopping at [limit]. Writes the first one into [out].
 *
 * Most-constrained-cell-first, unlike Tango's row-major walk. Here it earns its
 * keep: a 6×6 sudoku mid-dig usually has a cell with exactly one candidate, and
 * taking that cell next turns what would be a search into a chain of forced
 * moves. It is also what makes the dig loop below affordable, since that runs
 * the solver once per cell removed.
 */
export function countSolutions(
  puzzle: SudokuPuzzle,
  limit = 2,
  out?: number[]
): number {
  const cells = puzzle.givens.slice();
  let count = 0;

  // A given that conflicts with another given has no solutions — checked up
  // front so the search never "solves" around an impossible board.
  for (let i = 0; i < cells.length; i++) {
    if (cells[i] !== EMPTY && !allows(cells, i, cells[i])) return 0;
  }

  const rec = (): void => {
    if (count >= limit) return;

    let target = -1;
    let candidates: number[] = [];
    for (let i = 0; i < cells.length; i++) {
      if (cells[i] !== EMPTY) continue;
      const options: number[] = [];
      for (let v = 1; v <= SIZE; v++) if (allows(cells, i, v)) options.push(v);
      if (options.length === 0) return;
      if (target < 0 || options.length < candidates.length) {
        target = i;
        candidates = options;
        if (options.length === 1) break;
      }
    }

    if (target < 0) {
      if (out && count === 0) for (let i = 0; i < cells.length; i++) out[i] = cells[i];
      count++;
      return;
    }

    for (const value of candidates) {
      cells[target] = value;
      rec();
      cells[target] = EMPTY;
      if (count >= limit) return;
    }
  };

  rec();
  return count;
}

/** The board's solution, or null if it has none. */
export function solve(puzzle: SudokuPuzzle): number[] | null {
  const out = new Array<number>(SIZE * SIZE).fill(EMPTY);
  return countSolutions(puzzle, 1, out) === 1 ? out : null;
}

/** Whether [cells] is a complete, legal grid that respects [puzzle]'s givens. */
export function isSolved(puzzle: SudokuPuzzle, cells: number[]): boolean {
  if (cells.length !== SIZE * SIZE) return false;
  for (let i = 0; i < cells.length; i++) {
    const v = cells[i];
    if (!Number.isInteger(v) || v < 1 || v > SIZE) return false;
    if (puzzle.givens[i] !== EMPTY && puzzle.givens[i] !== v) return false;
  }
  for (let i = 0; i < cells.length; i++) {
    if (!allows(cells, i, cells[i])) return false;
  }
  return true;
}

/** A complete legal grid — the answer the puzzle hides. */
function fullGrid(rand: () => number): number[] | null {
  const cells = new Array<number>(SIZE * SIZE).fill(EMPTY);

  const rec = (index: number): boolean => {
    if (index === cells.length) return true;
    for (const value of shuffle(range(SIZE).map((v) => v + 1), rand)) {
      if (!allows(cells, index, value)) continue;
      cells[index] = value;
      if (rec(index + 1)) return true;
      cells[index] = EMPTY;
    }
    return false;
  };

  return rec(0) ? cells : null;
}

/**
 * How many digits stay on the board.
 *
 * The dig stops here rather than at "minimal". A 6×6 grid minimised all the way
 * lands around eight givens and needs the kind of chained hypothesis a 9×9
 * expert enjoys and nobody wants before coffee — and this one is timed against
 * friends, which punishes exactly that kind of stall. Twelve leaves a puzzle
 * that yields to plain scanning and still cannot be filled in without thinking.
 */
const MIN_GIVENS = 12;

/** Today's board. */
export function generate(dayKey: string): SudokuPuzzle {
  let fallback: SudokuPuzzle | null = null;

  for (let attempt = 0; attempt < 24; attempt++) {
    const rand = randomFor(dayKey, "sudoku", attempt);
    const solution = fullGrid(rand);
    if (!solution) continue;

    const puzzle: SudokuPuzzle = { size: SIZE, givens: solution.slice() };
    fallback ??= puzzle;
    // A little day-to-day wobble in the floor. Pinning it exactly gives every
    // board in the year the same twelve digits' worth of head start, which
    // reads as the same puzzle in a different arrangement.
    const floor = MIN_GIVENS + Math.floor(rand() * 3);
    let given = puzzle.givens.length;
    for (const i of shuffle(range(SIZE * SIZE), rand)) {
      if (given <= floor) break;
      const value = puzzle.givens[i];
      puzzle.givens[i] = EMPTY;
      if (countSolutions(puzzle, 2) === 1) given--;
      else puzzle.givens[i] = value;
    }
    if (given <= floor + 4) return puzzle;
  }

  return fallback ?? { size: SIZE, givens: new Array(SIZE * SIZE).fill(EMPTY) };
}
