/**
 * FUTOSHIKI — fill a 5×5 grid with 1-5 so every row and every column holds
 * each digit once, and every `<` or `>` printed between two neighbours holds.
 *
 * Digits and two comparison signs, so the board is the same in all twelve
 * languages — see `queens.ts` for why that decided the shortlist.
 *
 * Fixed at MEDIUM. A Latin square with signs is a familiar shape (it reads as
 * "sudoku with arrows"), so the difficulty lives entirely in how much the
 * board gives away, and that is what `generate` tunes.
 *
 * ## The solution is guaranteed unique
 *
 * For the same reason as every other timed daily here: a second answer lets a
 * guess that happens to land beat a deduction on the shared clock.
 */

import { randomFor, range, shuffle } from "./rng";

/** Board edge, and the largest digit. */
export const SIZE = 5;

/** A cell with nothing in it. Filled cells hold 1..SIZE. */
export const EMPTY = 0;

/** A comparison printed on the edge between two orthogonally adjacent cells. */
export type FutoshikiSign = {
  /** Cell index, row-major. Always the smaller of the pair. */
  a: number;
  /** The cell to the right of, or below, [a]. */
  b: number;
  /** True when value(a) < value(b); false when value(a) > value(b). */
  lt: boolean;
};

export type FutoshikiPuzzle = {
  size: number;
  difficulty: "easy" | "medium" | "hard";
  /** [EMPTY] or 1..SIZE per cell, row-major. */
  givens: number[];
  signs: FutoshikiSign[];
};

/** Lowest set bit's position — the smallest digit still possible, minus one. */
function lowBit(mask: number): number {
  return 31 - Math.clz32(mask & -mask);
}

/** Highest set bit's position — the largest digit still possible, minus one. */
function highBit(mask: number): number {
  return 31 - Math.clz32(mask);
}

function popcount(mask: number): number {
  let k = 0;
  while (mask) {
    mask &= mask - 1;
    k++;
  }
  return k;
}

/** Signs that name a real adjacent pair, in the documented a-before-b form. */
function signsWellFormed(puzzle: FutoshikiPuzzle): boolean {
  const n = puzzle.size;
  if (!Array.isArray(puzzle.signs)) return false;
  for (const s of puzzle.signs) {
    if (!s || !Number.isInteger(s.a) || !Number.isInteger(s.b)) return false;
    if (s.a < 0 || s.b >= n * n || typeof s.lt !== "boolean") return false;
    const right = s.b === s.a + 1 && s.a % n !== n - 1;
    const below = s.b === s.a + n;
    if (!right && !below) return false;
  }
  return true;
}

/**
 * The board as one candidate set per cell (bit v-1 set ⇔ digit v possible), or
 * null when the givens are not even digits.
 */
function initialDomains(puzzle: FutoshikiPuzzle): Int32Array | null {
  const n = puzzle.size;
  if (!Number.isInteger(n) || n < 2 || n > 9) return null;
  if (!Array.isArray(puzzle.givens) || puzzle.givens.length !== n * n) return null;
  if (!signsWellFormed(puzzle)) return null;
  const all = (1 << n) - 1;
  const dom = new Int32Array(n * n);
  for (let i = 0; i < n * n; i++) {
    const g = puzzle.givens[i];
    if (g === EMPTY) dom[i] = all;
    else if (Number.isInteger(g) && g >= 1 && g <= n) dom[i] = 1 << (g - 1);
    else return null;
  }
  return dom;
}

/**
 * Narrows [dom] in place to a fixpoint. Returns false on a contradiction.
 *
 * Three rules, each of which a person solving the board also uses:
 *
 *  - **singles** — a cell down to one digit takes it out of its row and column;
 *  - **hidden singles** — a digit with only one possible home in a row or
 *    column goes there;
 *  - **bounds** — for `a < b`, `a` cannot be as large as the largest thing `b`
 *    might be, and `b` cannot be as small as the smallest thing `a` might be.
 *    Repeated to a fixpoint this also carries a chain like `a < b < c` the
 *    whole way along without any special case.
 *
 * `logicSolves` reuses it as the difficulty gate: a board these rules finish on
 * their own needs no guess.
 */
function propagate(n: number, dom: Int32Array, signs: FutoshikiSign[]): boolean {
  const total = n * n;
  // Bounded by construction (every pass that changes anything removes at least
  // one candidate, and there are total * n of them), but cheap to make explicit.
  for (let pass = 0; pass <= total * n; pass++) {
    let changed = false;

    for (let i = 0; i < total; i++) {
      const d = dom[i];
      if (d === 0) return false;
      if (d & (d - 1)) continue;
      const row = Math.floor(i / n);
      const col = i % n;
      for (let k = 0; k < n; k++) {
        const r = row * n + k;
        if (r !== i && dom[r] & d) {
          dom[r] &= ~d;
          if (dom[r] === 0) return false;
          changed = true;
        }
        const c = k * n + col;
        if (c !== i && dom[c] & d) {
          dom[c] &= ~d;
          if (dom[c] === 0) return false;
          changed = true;
        }
      }
    }

    for (let line = 0; line < n; line++) {
      for (let v = 0; v < n; v++) {
        const bit = 1 << v;
        let rowCount = 0;
        let rowAt = -1;
        let colCount = 0;
        let colAt = -1;
        for (let k = 0; k < n; k++) {
          if (dom[line * n + k] & bit) {
            rowCount++;
            rowAt = line * n + k;
          }
          if (dom[k * n + line] & bit) {
            colCount++;
            colAt = k * n + line;
          }
        }
        if (rowCount === 0 || colCount === 0) return false;
        if (rowCount === 1 && dom[rowAt] !== bit) {
          dom[rowAt] = bit;
          changed = true;
        }
        if (colCount === 1 && dom[colAt] !== bit) {
          dom[colAt] = bit;
          changed = true;
        }
      }
    }

    for (const s of signs) {
      const small = s.lt ? s.a : s.b;
      const big = s.lt ? s.b : s.a;
      // Strictly below the largest the big side can be.
      const capped = dom[small] & ((1 << highBit(dom[big])) - 1);
      if (capped !== dom[small]) {
        if (capped === 0) return false;
        dom[small] = capped;
        changed = true;
      }
      // Strictly above the smallest the small side can be.
      const floored = dom[big] & ~((1 << (lowBit(dom[small]) + 1)) - 1);
      if (floored !== dom[big]) {
        if (floored === 0) return false;
        dom[big] = floored;
        changed = true;
      }
    }

    if (!changed) return true;
  }
  return true;
}

/**
 * Counts solutions, stopping at [limit]. Writes the first one into [out].
 *
 * Propagates to a fixpoint, then branches on the cell with the fewest digits
 * left. On a 5×5 the propagation does nearly all the work — most boards the
 * generator considers never branch at all — which is what makes the clue-by-
 * clue minimisation in `generate` affordable: it runs this once per clue.
 */
export function countSolutions(
  puzzle: FutoshikiPuzzle,
  limit = 2,
  out?: number[]
): number {
  const start = initialDomains(puzzle);
  if (!start) return 0;
  const n = puzzle.size;
  let count = 0;

  const rec = (dom: Int32Array, depth: number): void => {
    if (count >= limit || depth > n * n) return;
    if (!propagate(n, dom, puzzle.signs)) return;

    let target = -1;
    let best = n + 1;
    for (let i = 0; i < dom.length; i++) {
      const k = popcount(dom[i]);
      if (k > 1 && k < best) {
        best = k;
        target = i;
        if (k === 2) break;
      }
    }
    if (target < 0) {
      if (out && count === 0) for (let i = 0; i < dom.length; i++) out[i] = lowBit(dom[i]) + 1;
      count++;
      return;
    }
    let options = dom[target];
    while (options && count < limit) {
      const bit = options & -options;
      options &= ~bit;
      const next = dom.slice();
      next[target] = bit;
      rec(next, depth + 1);
    }
  };

  rec(start, 0);
  return count;
}

/**
 * Whether the three rules in `propagate` finish the board with no guessing.
 *
 * This is what MEDIUM means here. A board these rules solve outright is one a
 * player can always make progress on by looking harder; a board that needs a
 * branch is one where, at some point, the only way forward is to try a digit
 * and see — fine for a puzzle book's back pages, wrong for a timed daily that
 * sits in the middle of the shelf.
 */
function logicSolves(puzzle: FutoshikiPuzzle): boolean {
  const dom = initialDomains(puzzle);
  if (!dom || !propagate(puzzle.size, dom, puzzle.signs)) return false;
  for (let i = 0; i < dom.length; i++) if (dom[i] & (dom[i] - 1)) return false;
  return true;
}

/** The answer, a digit per cell — or an empty list for a board with none. */
export function solve(puzzle: FutoshikiPuzzle): number[] {
  const out = new Array<number>(puzzle.size * puzzle.size).fill(EMPTY);
  return countSolutions(puzzle, 1, out) === 1 ? out : [];
}

/**
 * Whether [cells] is a complete, legal grid for [puzzle].
 *
 * Re-derives the rules rather than comparing against `solve()`, for the same
 * reason as Queens: a finished, legal board must never be rejected, even if a
 * future generator change let a second solution through the gate.
 */
export function isSolved(puzzle: FutoshikiPuzzle, cells: number[]): boolean {
  if (!initialDomains(puzzle) || !Array.isArray(cells)) return false;
  const n = puzzle.size;
  if (cells.length !== n * n) return false;
  for (let i = 0; i < cells.length; i++) {
    const v = cells[i];
    if (!Number.isInteger(v) || v < 1 || v > n) return false;
    if (puzzle.givens[i] !== EMPTY && puzzle.givens[i] !== v) return false;
  }
  for (let line = 0; line < n; line++) {
    let rowSeen = 0;
    let colSeen = 0;
    for (let k = 0; k < n; k++) {
      rowSeen |= 1 << (cells[line * n + k] - 1);
      colSeen |= 1 << (cells[k * n + line] - 1);
    }
    if (rowSeen !== (1 << n) - 1 || colSeen !== (1 << n) - 1) return false;
  }
  for (const s of puzzle.signs) {
    if (s.lt ? !(cells[s.a] < cells[s.b]) : !(cells[s.a] > cells[s.b])) return false;
  }
  return true;
}

/**
 * One cell set to its answer: a wrong digit if the board has any, otherwise an
 * empty cell.
 *
 * Wrong cells come first because a mistake is the thing actually stopping the
 * player — revealing a blank while a wrong digit sits elsewhere only moves the
 * contradiction somewhere they will hit it later. Among candidates the pick
 * rotates with [seq], so a second hint is a different square.
 */
export function hint(
  puzzle: FutoshikiPuzzle,
  progress: number[],
  seq: number
): { index: number; value: number; cells?: number[] } | null {
  const answer = solve(puzzle);
  if (answer.length === 0) return null;
  const board = Array.isArray(progress) ? progress : [];
  const n = puzzle.size;

  const wrong: number[] = [];
  const empty: number[] = [];
  for (let i = 0; i < answer.length; i++) {
    const v = board[i];
    if (v === answer[i]) continue;
    // A printed digit is not a blank the player failed to fill — a client
    // that leaves givens out of its board must not be "helped" to one.
    if (puzzle.givens[i] !== EMPTY) continue;
    if (Number.isInteger(v) && v >= 1 && v <= n) wrong.push(i);
    else empty.push(i);
  }
  const pool = wrong.length > 0 ? wrong : empty;
  if (pool.length === 0) return null;
  const turn = Number.isInteger(seq) && seq > 0 ? seq : 0;
  const index = pool[turn % pool.length];
  return { index, value: answer[index] };
}

/** A random Latin square — the answer the puzzle hides. */
function latinSquare(rand: () => number, n: number): number[] | null {
  const cells = new Array<number>(n * n).fill(EMPTY);
  let steps = 0;
  const allows = (i: number, v: number): boolean => {
    const row = Math.floor(i / n);
    const col = i % n;
    for (let k = 0; k < n; k++) {
      if (k !== col && cells[row * n + k] === v) return false;
      if (k !== row && cells[k * n + col] === v) return false;
    }
    return true;
  };
  const rec = (i: number): boolean => {
    if (++steps > 20000) return false;
    if (i === cells.length) return true;
    for (const v of shuffle(range(n).map((x) => x + 1), rand)) {
      if (!allows(i, v)) continue;
      cells[i] = v;
      if (rec(i + 1)) return true;
      cells[i] = EMPTY;
    }
    return false;
  };
  return rec(0) ? cells : null;
}

/** Every orthogonally adjacent pair, as the sign the solution implies. */
function allSigns(solution: number[], n: number): FutoshikiSign[] {
  const signs: FutoshikiSign[] = [];
  for (let i = 0; i < n * n; i++) {
    if (i % n < n - 1) signs.push({ a: i, b: i + 1, lt: solution[i] < solution[i + 1] });
    if (i + n < n * n) signs.push({ a: i, b: i + n, lt: solution[i] < solution[i + n] });
  }
  return signs;
}

/**
 * How many digits stay printed.
 *
 * Around three, by design. Zero is often uniquely solvable off signs alone, but
 * a board with nothing printed has no foothold — the first move is a cold
 * start, which reads as hard rather than medium. Many more and the digits
 * carry the board and the signs are decoration.
 */
const TARGET_GIVENS = 3;

/**
 * The fewest signs the minimiser leaves, before a day-to-day wobble of one.
 *
 * Measured, not guessed: stripping signs until logic alone stops finishing the
 * board lands on about seven, and those boards are a long single chain of
 * forced moves with no slack — one missed deduction and the player is stuck.
 * Eight or nine leaves a second way into most regions of the grid, which is
 * the texture of a medium board rather than a hard one.
 */
const MIN_SIGNS = 8;

/**
 * A hand-checked board for the day the generator cannot produce one. Generated
 * once from the key `2020-02-29` and frozen; the test suite proves it unique.
 */
export const FALLBACK: FutoshikiPuzzle = {
  size: SIZE,
  difficulty: "medium",
  givens: [
    0, 0, 0, 0, 0,
    0, 0, 0, 0, 0,
    0, 0, 5, 0, 0,
    0, 0, 0, 0, 0,
    1, 0, 0, 5, 0,
  ],
  signs: [
    { a: 0, b: 5, lt: true },
    { a: 1, b: 2, lt: false },
    { a: 2, b: 3, lt: true },
    { a: 6, b: 11, lt: false },
    { a: 9, b: 14, lt: false },
    { a: 14, b: 19, lt: true },
    { a: 15, b: 16, lt: true },
    { a: 16, b: 21, lt: false },
    { a: 21, b: 22, lt: false },
  ],
};

/**
 * Today's board.
 *
 * Builds the answer, offers every given and every sign, then takes away what
 * the board can do without — **givens first, signs second**, for the reason
 * spelled out in `tango.ts`: while all twenty-five digits are printed no sign
 * is ever load-bearing, so a mixed or signs-first order strips every sign and
 * ships a fill-in-the-blanks grid.
 *
 * The sign pass stops short of minimal on purpose. A sign comes off only if the
 * board stays unique **and** stays solvable by the plain rules in `propagate`
 * (see `logicSolves`). A fully minimised 5×5 Futoshiki is an expert board that
 * needs trial and error; holding the line at "logic alone finishes it" keeps a
 * few redundant signs on the board, and those are exactly the footholds that
 * make it medium.
 */
export function generate(dayKey: string): FutoshikiPuzzle {
  for (let attempt = 0; attempt < 24; attempt++) {
    const rand = randomFor(dayKey, "futoshiki", attempt);
    const solution = latinSquare(rand, SIZE);
    if (!solution) continue;

    const puzzle: FutoshikiPuzzle = {
      size: SIZE,
      difficulty: "medium",
      givens: solution.slice(),
      signs: shuffle(allSigns(solution, SIZE), rand),
    };

    let given = puzzle.givens.length;
    for (const i of shuffle(range(SIZE * SIZE), rand)) {
      if (given <= TARGET_GIVENS) break;
      const value = puzzle.givens[i];
      puzzle.givens[i] = EMPTY;
      if (logicSolves(puzzle)) given--;
      else puzzle.givens[i] = value;
    }
    if (given > TARGET_GIVENS + 1) continue;

    const floor = MIN_SIGNS + Math.floor(rand() * 2);
    for (let s = puzzle.signs.length - 1; s >= 0; s--) {
      if (puzzle.signs.length <= floor) break;
      const removed = puzzle.signs.splice(s, 1)[0];
      if (!logicSolves(puzzle)) puzzle.signs.splice(s, 0, removed);
    }

    // Logic finishing the board already implies a unique answer — every step
    // was forced — but the counting solver is the authority, and it is cheap.
    if (countSolutions(puzzle, 2) !== 1) continue;
    // Printed in reading order, which is how the client draws them anyway, and
    // so the JSON does not leak the shuffle.
    puzzle.signs.sort((x, y) => x.a - y.a || x.b - y.b);
    return puzzle;
  }
  return {
    ...FALLBACK,
    givens: FALLBACK.givens.slice(),
    signs: FALLBACK.signs.map((s) => ({ ...s })),
  };
}
