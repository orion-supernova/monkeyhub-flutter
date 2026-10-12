/**
 * NONOGRAM — a 10×10 picture hidden behind its run-length clues. Each row and
 * each column lists the lengths of its filled runs, in order, and the player
 * shades cells until every line reads back the clue printed beside it.
 *
 * Numbers and squares only, so the board is identical in all twelve languages —
 * see `queens.ts` for why that decided the shortlist.
 *
 * ## "Unique" here means "line-solvable", which is stricter
 *
 * A nonogram can have exactly one solution and still be unfair: some unique
 * boards are only reachable by trial and error ("suppose this cell is filled…
 * no, contradiction three moves later"). That is a guess with extra steps, and
 * timing friends against each other on guesses is exactly what the other
 * dailies refuse to do (see `queens.ts`). So the gate is the one a human
 * actually uses: look at one line at a time, work out which cells every
 * arrangement of its clue agrees on, write those down, repeat. If that sweep
 * alone fills the whole grid, the board needs no guessing — and a board the
 * sweep completes is trivially unique, because every cell was forced.
 *
 * ## Why the picture is grown rather than drawn
 *
 * Uniform noise at ~58% fill makes clues like `1 2 1 1 1` on every line: legal,
 * solvable, and miserable — there is no shape to recognise and nothing to feel
 * clever about. A couple of passes of a majority cellular automaton clump the
 * noise into blobs, which is what makes a nonogram feel like a picture coming
 * out of the fog, and long runs are also what give a line solver (and a person)
 * its first foothold.
 */

import { randomFor } from "./rng";

/** Board edge. */
export const SIZE = 10;

/** Cell values, in the solution and in a submission. */
export const EMPTY = 0;
export const FILLED = 1;

/** A cell the player (or the solver) has not decided yet, in `progress`. */
export const UNKNOWN = -1;

export type NonogramPuzzle = {
  size: number;
  difficulty: "easy" | "medium" | "hard";
  /**
   * Run lengths per row, top to bottom, each read left to right. An empty row
   * is `[]` — the client renders that as a single `0`.
   */
  rows: number[][];
  /** Run lengths per column, left to right, each read top to bottom. */
  cols: number[][];
};

/**
 * Roughly how much of the picture is ink, measured AFTER the automaton.
 *
 * The automaton is a majority vote, so it pushes whichever colour is already
 * ahead further ahead; seeding the noise at 0.58 itself lands near two-thirds
 * filled. [NOISE_DENSITY] is the seed rate measured to land on this target.
 */
export const TARGET_DENSITY = 0.58;
const NOISE_DENSITY = 0.52;

/**
 * At most this many lines (rows and columns together) may be entirely blank.
 *
 * One blank line is a nice gift — a free row of crosses. Several read as a
 * picture that did not fit its frame, and they are dead area on a small phone.
 */
const MAX_EMPTY_LINES = 1;

/**
 * At most this many numbers per clue.
 *
 * Note that on a 10-cell line this can never trip — five runs plus four gaps is
 * already nine cells — so today it documents intent rather than filtering. It
 * is the knob to turn (to 4) if boards start feeling like barcodes.
 */
const MAX_CLUES_PER_LINE = 5;

/** Attempt budget. Bounded so one unlucky day key cannot hang the query. */
const ATTEMPTS = 20;
const FLIPS_PER_ATTEMPT = 60;

const FULL = (1 << SIZE) - 1;

/** The run lengths of a [SIZE]-bit line mask, bit 0 first. */
function clueOfMask(mask: number): number[] {
  const out: number[] = [];
  let run = 0;
  for (let i = 0; i < SIZE; i++) {
    if (mask & (1 << i)) run++;
    else if (run > 0) {
      out.push(run);
      run = 0;
    }
  }
  if (run > 0) out.push(run);
  return out;
}

/**
 * Every line arrangement, bucketed by the clue it produces.
 *
 * 1,024 masks is small enough to enumerate once at module load and cheap
 * enough to filter per line, which turns "all placements of this clue" — the
 * expensive part of a classic line solver — into a lookup. It also means the
 * solver is obviously exhaustive: there is no placement algorithm to get wrong.
 */
const MASKS_BY_CLUE: Map<string, number[]> = (() => {
  const map = new Map<string, number[]>();
  for (let m = 0; m <= FULL; m++) {
    const key = clueOfMask(m).join(",");
    const list = map.get(key);
    if (list) list.push(m);
    else map.set(key, [m]);
  }
  return map;
})();

function lineMask(grid: ArrayLike<number>, line: number): number {
  let m = 0;
  if (line < SIZE) {
    for (let c = 0; c < SIZE; c++) if (grid[line * SIZE + c] === FILLED) m |= 1 << c;
  } else {
    const col = line - SIZE;
    for (let r = 0; r < SIZE; r++) if (grid[r * SIZE + col] === FILLED) m |= 1 << r;
  }
  return m;
}

/** Row clues then column clues of a full 0/1 grid. */
function cluesOf(grid: ArrayLike<number>): { rows: number[][]; cols: number[][] } {
  const rows: number[][] = [];
  const cols: number[][] = [];
  for (let l = 0; l < SIZE; l++) rows.push(clueOfMask(lineMask(grid, l)));
  for (let l = 0; l < SIZE; l++) cols.push(clueOfMask(lineMask(grid, SIZE + l)));
  return { rows, cols };
}

/** Cell index of position [k] along line [line] (rows 0..9, then columns 10..19). */
function cellAt(line: number, k: number): number {
  return line < SIZE ? line * SIZE + k : k * SIZE + (line - SIZE);
}

/**
 * Line-solves the clues as far as they go, without guessing.
 *
 * Each line keeps the masks that still fit what is known; the cells all
 * survivors fill are filled, the cells none fill are empty. Only lines that
 * gained a cell since their last pass are revisited, so a sweep to the fixpoint
 * costs a few dozen filters rather than a fixed number of full passes.
 *
 * Returns the grid in -1/0/1 and whether it was finished. `contradiction` means
 * the clues cannot be satisfied at all (a malformed puzzle, never a generated
 * one); the grid is then whatever was known when that surfaced.
 */
export function lineSolve(rows: number[][], cols: number[][]): {
  grid: Int8Array;
  complete: boolean;
  contradiction: boolean;
} {
  const grid = new Int8Array(SIZE * SIZE).fill(UNKNOWN);
  const cands: number[][] = [];
  for (let l = 0; l < 2 * SIZE; l++) {
    const clue = l < SIZE ? rows[l] : cols[l - SIZE];
    const list = Array.isArray(clue) ? MASKS_BY_CLUE.get(clue.join(",")) : undefined;
    if (!list) return { grid, complete: false, contradiction: true };
    cands.push(list);
  }

  const dirty = new Array<boolean>(2 * SIZE).fill(true);
  let queued = 2 * SIZE;
  let known = 0;
  // Each productive pass decides at least one of 100 cells, so this bound is
  // never the reason the loop stops; it is there so a bug cannot spin.
  for (let guard = 0; queued > 0 && guard < 4000; guard++) {
    for (let l = 0; l < 2 * SIZE; l++) {
      if (!dirty[l]) continue;
      dirty[l] = false;
      queued--;

      let filled = 0;
      let empty = 0;
      for (let k = 0; k < SIZE; k++) {
        const v = grid[cellAt(l, k)];
        if (v === FILLED) filled |= 1 << k;
        else if (v === EMPTY) empty |= 1 << k;
      }
      const kept: number[] = [];
      let and = FULL;
      let or = 0;
      for (const m of cands[l]) {
        if ((m & filled) !== filled || (m & empty) !== 0) continue;
        kept.push(m);
        and &= m;
        or |= m;
      }
      if (kept.length === 0) return { grid, complete: false, contradiction: true };
      cands[l] = kept;

      const newFilled = and & ~filled;
      const newEmpty = ~or & FULL & ~empty;
      if ((newFilled | newEmpty) === 0) continue;
      for (let k = 0; k < SIZE; k++) {
        const bit = 1 << k;
        if (!((newFilled | newEmpty) & bit)) continue;
        grid[cellAt(l, k)] = newFilled & bit ? FILLED : EMPTY;
        known++;
        // The crossing line just learned a cell.
        const cross = l < SIZE ? SIZE + k : k;
        if (!dirty[cross]) {
          dirty[cross] = true;
          queued++;
        }
      }
    }
  }

  return { grid, complete: known === SIZE * SIZE, contradiction: false };
}

/** Whether a picture passes the look-and-feel gates (not the solvability one). */
function passesGates(grid: ArrayLike<number>): boolean {
  let emptyLines = 0;
  for (let l = 0; l < 2 * SIZE; l++) {
    const m = lineMask(grid, l);
    if (m === 0) emptyLines++;
    if (clueOfMask(m).length > MAX_CLUES_PER_LINE) return false;
  }
  return emptyLines <= MAX_EMPTY_LINES;
}

/** Seeded noise clumped by [steps] majority votes over each 3×3 neighbourhood. */
function drawPicture(rand: () => number): Uint8Array {
  let grid = new Uint8Array(SIZE * SIZE);
  for (let i = 0; i < grid.length; i++) grid[i] = rand() < NOISE_DENSITY ? 1 : 0;

  const steps = 1 + Math.floor(rand() * 2);
  for (let s = 0; s < steps; s++) {
    const next = new Uint8Array(SIZE * SIZE);
    for (let r = 0; r < SIZE; r++) {
      for (let c = 0; c < SIZE; c++) {
        let on = 0;
        let total = 0;
        for (let dr = -1; dr <= 1; dr++) {
          for (let dc = -1; dc <= 1; dc++) {
            const rr = r + dr;
            const cc = c + dc;
            if (rr < 0 || rr >= SIZE || cc < 0 || cc >= SIZE) continue;
            total++;
            on += grid[rr * SIZE + cc];
          }
        }
        // A tie (possible on edges, where the window is 6 or 4 cells) keeps
        // the cell as it was — otherwise every border would drift one way.
        const i = r * SIZE + c;
        next[i] = 2 * on > total ? 1 : 2 * on < total ? 0 : grid[i];
      }
    }
    grid = next;
  }
  return grid;
}

/**
 * The undetermined cells grouped into 4-connected blocks, largest first.
 *
 * The repair flips a cell in the biggest block because that is where the
 * ambiguity lives: a large undecided patch is usually one "swap two runs"
 * degree of freedom, and changing any cell inside it changes the clues of the
 * exact lines that were failing to pin it down. Small blocks are tried after,
 * in case every cell of the big one would break a look-and-feel gate.
 */
function undeterminedBlocks(solved: Int8Array): number[][] {
  const seen = new Uint8Array(SIZE * SIZE);
  const blocks: number[][] = [];
  for (let i = 0; i < solved.length; i++) {
    if (solved[i] !== UNKNOWN || seen[i]) continue;
    const block: number[] = [];
    const stack = [i];
    seen[i] = 1;
    while (stack.length > 0) {
      const at = stack.pop()!;
      block.push(at);
      const r = Math.floor(at / SIZE);
      const c = at % SIZE;
      const around = [
        r > 0 ? at - SIZE : -1,
        r < SIZE - 1 ? at + SIZE : -1,
        c > 0 ? at - 1 : -1,
        c < SIZE - 1 ? at + 1 : -1,
      ];
      for (const n of around) {
        if (n < 0 || seen[n] || solved[n] !== UNKNOWN) continue;
        seen[n] = 1;
        stack.push(n);
      }
    }
    block.sort((a, b) => a - b);
    blocks.push(block);
  }
  // Stable on ties (the sort above and the scan order are both deterministic),
  // which keeps the whole generator a pure function of the day key.
  blocks.sort((a, b) => b.length - a.length || a[0] - b[0]);
  return blocks;
}

/**
 * A hand-drawn board shipped if every attempt fails, so the daily never goes
 * dark. A little house; `nonogram.test.ts` pins that it is line-solvable and
 * passes the gates, so the fallback is a real puzzle and not a placeholder.
 */
const FALLBACK_PICTURE = [
  "....##....",
  "...####...",
  "..######..",
  ".########.",
  "##########",
  ".#......#.",
  ".#.##.#.#.",
  ".#.##...#.",
  ".#.##..##.",
  ".########.",
];

/** The fallback board and its picture. Exported for the test that pins it. */
export function fallback(): { puzzle: NonogramPuzzle; solution: number[] } {
  const grid = new Uint8Array(SIZE * SIZE);
  for (let r = 0; r < SIZE; r++) {
    for (let c = 0; c < SIZE; c++) grid[r * SIZE + c] = FALLBACK_PICTURE[r][c] === "#" ? 1 : 0;
  }
  return { puzzle: puzzleOf(grid), solution: Array.from(grid) };
}

function puzzleOf(grid: ArrayLike<number>): NonogramPuzzle {
  const { rows, cols } = cluesOf(grid);
  return { size: SIZE, difficulty: "medium", rows, cols };
}

/**
 * Today's board with its picture and how it was reached. `generate` is the
 * public face; this exists for the tests, which pin the fallback rate.
 */
export function generateWithSolution(dayKey: string): {
  puzzle: NonogramPuzzle;
  solution: number[];
  attempt: number;
  fallback: boolean;
} {
  for (let attempt = 0; attempt < ATTEMPTS; attempt++) {
    const rand = randomFor(dayKey, "nonogram", attempt);
    const grid = drawPicture(rand);
    if (!passesGates(grid)) continue;

    for (let flip = 0; flip <= FLIPS_PER_ATTEMPT; flip++) {
      const { rows, cols } = cluesOf(grid);
      const solved = lineSolve(rows, cols);
      if (solved.complete) {
        return {
          puzzle: { size: SIZE, difficulty: "medium", rows, cols },
          solution: Array.from(grid),
          attempt,
          fallback: false,
        };
      }
      if (flip === FLIPS_PER_ATTEMPT) break;

      // Repair: flip one undecided cell, preferring the largest undecided
      // block, skipping any flip that would break a look-and-feel gate. The
      // candidate order inside a block is seeded, so which cell moves is still
      // a function of the day key.
      let flipped = false;
      for (const block of undeterminedBlocks(solved.grid)) {
        const start = Math.floor(rand() * block.length);
        for (let k = 0; k < block.length; k++) {
          const cell = block[(start + k) % block.length];
          grid[cell] ^= 1;
          if (passesGates(grid)) {
            flipped = true;
            break;
          }
          grid[cell] ^= 1;
        }
        if (flipped) break;
      }
      if (!flipped) break;
    }
  }

  return { ...fallback(), attempt: ATTEMPTS, fallback: true };
}

/**
 * Today's board.
 *
 * Draw a clumpy picture, line-solve its clues, and when the sweep stalls,
 * nudge the picture rather than throw it away — a stalled board is usually one
 * flip from solvable, and a re-roll would discard all the shape it already has.
 * Bounded at [FLIPS_PER_ATTEMPT] flips per picture and [ATTEMPTS] pictures,
 * then a hand-drawn fallback, because this runs inside a subscribed query.
 *
 * Only the clues are shipped. The picture never leaves the server.
 */
export function generate(dayKey: string): NonogramPuzzle {
  return generateWithSolution(dayKey).puzzle;
}

/** A well-formed clue list for this board size, or null. */
function cleanClues(lines: unknown, size: number): number[][] | null {
  if (!Array.isArray(lines) || lines.length !== size) return null;
  const out: number[][] = [];
  for (const line of lines) {
    if (!Array.isArray(line)) return null;
    for (const n of line) if (!Number.isInteger(n) || n < 1 || n > size) return null;
    out.push(line as number[]);
  }
  return out;
}

/**
 * The answer as 0/1 per cell, row-major — the shape `submit` takes.
 *
 * Re-derived from the clues by the same line solver the generator gated on, so
 * it is the unique picture for any generated board. For a malformed or not
 * line-solvable puzzle (never a generated one) undecided cells read as empty
 * rather than throwing; such a puzzle has no single answer to give.
 */
export function solve(puzzle: NonogramPuzzle): number[] {
  const out = new Array<number>(SIZE * SIZE).fill(EMPTY);
  if (!puzzle || puzzle.size !== SIZE) return out;
  const rows = cleanClues(puzzle.rows, SIZE);
  const cols = cleanClues(puzzle.cols, SIZE);
  if (!rows || !cols) return out;
  const { grid } = lineSolve(rows, cols);
  for (let i = 0; i < out.length; i++) out[i] = grid[i] === FILLED ? FILLED : EMPTY;
  return out;
}

function sameClues(a: number[][], b: number[][]): boolean {
  if (a.length !== b.length) return false;
  for (let i = 0; i < a.length; i++) {
    if (a[i].length !== b[i].length) return false;
    for (let k = 0; k < a[i].length; k++) if (a[i][k] !== b[i][k]) return false;
  }
  return true;
}

/**
 * Whether [cells] — 0/1 per cell, row-major — reads back every clue.
 *
 * Compares CLUES, not cells, for the reason Queens re-derives its rules: the
 * rules of a nonogram are the clues, and a grid that satisfies them is a win
 * even if a future generator change ever lets a second such grid through.
 * Strict about shape: anything but exactly 100 zeros and ones is false.
 */
export function isSolved(puzzle: NonogramPuzzle, cells: number[]): boolean {
  if (!puzzle || puzzle.size !== SIZE) return false;
  if (!Array.isArray(cells) || cells.length !== SIZE * SIZE) return false;
  for (const v of cells) if (v !== EMPTY && v !== FILLED) return false;
  const rows = cleanClues(puzzle.rows, SIZE);
  const cols = cleanClues(puzzle.cols, SIZE);
  if (!rows || !cols) return false;
  const got = cluesOf(cells);
  return sameClues(got.rows, rows) && sameClues(got.cols, cols);
}

/**
 * One cell that is wrong or still unknown in [progress], with its answer.
 *
 * [progress] is 1 filled, 0 crossed/empty, -1 unknown per cell; anything else
 * (or a missing cell) simply disagrees with the answer and is a candidate.
 * Rotates by [seq] — the hints already taken — so a second hint is a different
 * square, matching `games.ts`'s generic hint. Null when the board is already
 * right everywhere.
 */
export function hint(
  puzzle: NonogramPuzzle,
  progress: number[],
  seq: number
): { index: number; value: number } | null {
  const answer = solve(puzzle);
  const board = Array.isArray(progress) ? progress : [];
  const wrong: number[] = [];
  for (let i = 0; i < answer.length; i++) if (board[i] !== answer[i]) wrong.push(i);
  if (wrong.length === 0) return null;
  const s = Number.isInteger(seq) && seq >= 0 ? seq : 0;
  const index = wrong[s % wrong.length];
  return { index, value: answer[index] };
}
