/**
 * PATCHES — cut a 7×7 board into rectangles, each holding exactly one clue,
 * every rectangle the shape its clue shows and, where the clue carries a
 * number, exactly that many squares.
 *
 * LinkedIn's Patches, and Shikaku before it. On the shortlist for the reason
 * every daily here is (see `games.ts`): a square, a tall bar, a wide bar and a
 * digit read the same in all twelve languages, so friends everywhere cut the
 * identical board.
 *
 * ## The clues
 *
 * Each clue sits in one square of its patch and says what the patch looks
 * like: a SQUARE, TALL (more rows than columns), WIDE (more columns than
 * rows), or ANY rectangle. Most also print the patch's area. The generator
 * strips some of the numbers (and turns a couple of shapes into ANY) for as
 * long as the answer stays unique, which is where the puzzle comes from: a
 * board with every number printed is arithmetic, a board with half of them
 * gone is reasoning about what the neighbours leave.
 *
 * Fixed at MEDIUM. The stripping is capped (see [MAX_HIDDEN_AREAS],
 * [MAX_ANY]) so a day never turns into a wall of shape-only clues that can
 * only be guessed at.
 *
 * ## The solution is guaranteed unique
 *
 * As for every daily: a board with two answers rewards a lucky cut on a timed,
 * shared scoreboard. `generate` only ships a board the solver has proved has
 * exactly one.
 *
 * ## The submission shape
 *
 * The clue index whose patch covers each square, row-major — 49 numbers. The
 * autosave is the same shape with -1 for a square no patch covers yet, so a
 * half-cut board and a finished one are read by the same code.
 */

import { randomFor, shuffle } from "./rng";

/** Board edge. */
export const SIZE = 7;

/** What a clue says about its patch's proportions. */
export type PatchShape = "square" | "tall" | "wide" | "any";

export type PatchClue = {
  /** The square the clue is printed in, row-major. */
  cell: number;
  shape: PatchShape;
  /** The patch's area in squares, or 0 when the clue does not say. */
  area: number;
};

export type PatchesPuzzle = {
  size: number;
  difficulty: "easy" | "medium" | "hard";
  /** In row-major order of their cells, so clue k is also colour k. */
  clues: PatchClue[];
};

/** A rectangle by its inclusive corners. */
export type Rect = { top: number; left: number; bottom: number; right: number };

/** Fewest and most patches a board is cut into. */
const MIN_PATCHES = 8;
// Ten at most so every patch gets its own hue: the client colours clue k with
// palette entry k, and the palette has ten.
const MAX_PATCHES = 10;

/** Largest patch the generator cuts, and its longest side. */
const MAX_AREA = 8;
const MAX_SIDE = 5;

/** Clues that may lose their number, as a share of the board's clues. */
const MAX_HIDDEN_AREAS = 0.5;

/** Clues that may lose their shape (and must then keep their number). */
const MAX_ANY = 2;

const SHAPES: readonly PatchShape[] = ["square", "tall", "wide", "any"];

/** The shape [rect] actually has. */
export function shapeOf(rect: Rect): PatchShape {
  const h = rect.bottom - rect.top + 1;
  const w = rect.right - rect.left + 1;
  return h === w ? "square" : h > w ? "tall" : "wide";
}

/** Whether a [h]×[w] patch is what [clue] asks for. */
function fits(clue: PatchClue, h: number, w: number): boolean {
  if (clue.area > 0 && h * w !== clue.area) return false;
  switch (clue.shape) {
    case "square":
      return h === w;
    case "tall":
      return h > w;
    case "wide":
      return w > h;
    case "any":
      return true;
  }
}

/** Clues that name real squares, real shapes and sane areas, one per square. */
function wellFormed(puzzle: PatchesPuzzle): boolean {
  const n = puzzle.size;
  if (n !== SIZE || !Array.isArray(puzzle.clues) || puzzle.clues.length === 0) {
    return false;
  }
  const seen = new Set<number>();
  for (const clue of puzzle.clues) {
    if (!Number.isInteger(clue.cell) || clue.cell < 0 || clue.cell >= n * n) return false;
    if (seen.has(clue.cell)) return false;
    seen.add(clue.cell);
    if (!SHAPES.includes(clue.shape)) return false;
    if (!Number.isInteger(clue.area) || clue.area < 0 || clue.area > n * n) return false;
  }
  return true;
}

/**
 * A set of squares as two bitmasks, cells 0..24 in `lo` and 25..48 in `hi`,
 * so every operation the solver does on a patch stays in plain int32
 * arithmetic.
 */
type Mask = { lo: number; hi: number };

const SPLIT = 25;

function maskOf(cells: number[]): Mask {
  let lo = 0;
  let hi = 0;
  for (const c of cells) {
    if (c < SPLIT) lo |= 1 << c;
    else hi |= 1 << (c - SPLIT);
  }
  return { lo, hi };
}

/** The squares of [rect], row-major. */
export function cellsOf(rect: Rect, n = SIZE): number[] {
  const out: number[] = [];
  for (let r = rect.top; r <= rect.bottom; r++) {
    for (let c = rect.left; c <= rect.right; c++) out.push(r * n + c);
  }
  return out;
}

export type Candidate = { rect: Rect; lo: number; hi: number };

/**
 * Every rectangle clue [k] could be: it contains the clue's square, no other
 * clue's square, and matches the clue. The solver, the hints and the tests all
 * start from this list.
 */
export function candidatesFor(puzzle: PatchesPuzzle, k: number): Candidate[] {
  const n = puzzle.size;
  const clue = puzzle.clues[k];
  const row = Math.floor(clue.cell / n);
  const col = clue.cell % n;
  const isClue = new Uint8Array(n * n);
  for (const c of puzzle.clues) isClue[c.cell] = 1;

  const out: Candidate[] = [];
  for (let top = 0; top <= row; top++) {
    for (let left = 0; left <= col; left++) {
      for (let bottom = row; bottom < n; bottom++) {
        for (let right = col; right < n; right++) {
          if (!fits(clue, bottom - top + 1, right - left + 1)) continue;
          const rect = { top, left, bottom, right };
          const cells = cellsOf(rect, n);
          if (cells.some((c) => c !== clue.cell && isClue[c])) continue;
          const m = maskOf(cells);
          out.push({ rect, lo: m.lo, hi: m.hi });
        }
      }
    }
  }
  return out;
}

const FULL_LO = (1 << SPLIT) - 1;
const FULL_HI = (1 << (SIZE * SIZE - SPLIT)) - 1;

/**
 * Every solution, up to [limit] of them, each as the rectangle per clue.
 *
 * An exact cover over a handful of clues, so a plain search is plenty — with
 * two prunes that keep the uniqueness proof (the case where the whole tree has
 * to be walked) to a few hundred nodes:
 *
 *  - **fewest options first.** The next clue placed is the one with the fewest
 *    rectangles still free, so a clue with one option is placed before
 *    anything branches, the way a person would;
 *  - **no orphaned squares.** If some uncovered square lies in no free
 *    rectangle of any clue still to place, the branch is dead now rather than
 *    after every remaining clue has been tried.
 *
 * Returns the rectangles rather than a count because the hints need the answer
 * itself, clue by clue.
 */
export function findSolutions(puzzle: PatchesPuzzle, limit = 2): Rect[][] {
  if (!wellFormed(puzzle)) return [];
  const k = puzzle.clues.length;
  const options = puzzle.clues.map((_, i) => candidatesFor(puzzle, i));
  if (options.some((o) => o.length === 0)) return [];

  const placed = new Int32Array(k).fill(-1);
  const found: Rect[][] = [];
  let lo = 0;
  let hi = 0;

  const rec = (left: number): void => {
    if (found.length >= limit) return;
    if (left === 0) {
      if (lo === FULL_LO && hi === FULL_HI) {
        found.push(Array.from(placed, (p, i) => options[i][p].rect));
      }
      return;
    }
    let best = -1;
    let bestFree: number[] = [];
    let reachLo = 0;
    let reachHi = 0;
    for (let i = 0; i < k; i++) {
      if (placed[i] >= 0) continue;
      const free: number[] = [];
      const opts = options[i];
      for (let p = 0; p < opts.length; p++) {
        if ((opts[p].lo & lo) !== 0 || (opts[p].hi & hi) !== 0) continue;
        free.push(p);
        reachLo |= opts[p].lo;
        reachHi |= opts[p].hi;
      }
      if (free.length === 0) return;
      if (best < 0 || free.length < bestFree.length) {
        best = i;
        bestFree = free;
      }
    }
    if ((~lo & FULL_LO & ~reachLo) !== 0 || (~hi & FULL_HI & ~reachHi) !== 0) return;

    for (const p of bestFree) {
      const o = options[best][p];
      placed[best] = p;
      lo |= o.lo;
      hi |= o.hi;
      rec(left - 1);
      lo &= ~o.lo;
      hi &= ~o.hi;
      placed[best] = -1;
      if (found.length >= limit) return;
    }
  };

  rec(k);
  return found;
}

/** How many solutions the board has, counted no further than [limit]. */
export function countSolutions(puzzle: PatchesPuzzle, limit = 2): number {
  return findSolutions(puzzle, limit).length;
}

/** Why [deduce] settled a clue: see there. */
export type Deduction = "only" | "cell" | "squeeze";

/**
 * What a person can work out from [fixed] without guessing: each clue's
 * rectangles still possible, and the clues that came down to one, in the order
 * they did and with the rule that did it.
 *
 * Three rules, applied until none changes anything:
 *
 *  - **only** — a clue with a single rectangle left is settled ("only one
 *    patch fits here");
 *  - **cell** — a square that only one clue's rectangles can reach belongs to
 *    that clue, which keeps only the rectangles that cover it;
 *  - **squeeze** — the squares EVERY remaining rectangle of a clue covers are
 *    that clue's whatever happens, so every other clue loses the rectangles
 *    that touch them. A settled patch is the extreme case: all its squares.
 *
 * Every rule only ever removes rectangles the answer cannot use, so a board
 * this settles completely has exactly one answer — which is why the generator
 * asks this rather than only the solver: unique is the floor, solvable by
 * reasoning is the bar. A clue settled by "cell" or "squeeze" is reported
 * with that rule even if "only" is what finally named it, since that is the
 * step that did the work.
 */
export function deduce(
  puzzle: PatchesPuzzle,
  fixed: Array<Rect | null> = []
): { options: Candidate[][]; settled: Array<{ clue: number; rule: Deduction }>; broken: boolean } {
  const k = puzzle.clues.length;
  const options = puzzle.clues.map((_, i) => {
    const all = candidatesFor(puzzle, i);
    const f = fixed[i];
    if (!f) return all;
    return all.filter(
      (o) =>
        o.rect.top === f.top &&
        o.rect.left === f.left &&
        o.rect.bottom === f.bottom &&
        o.rect.right === f.right
    );
  });
  const settled: Array<{ clue: number; rule: Deduction }> = [];
  const done = new Uint8Array(k);
  // The rule that last narrowed each clue, so a clue that comes down to one
  // after a squeeze is credited to the squeeze.
  const narrowedBy: Array<Deduction> = new Array(k).fill("only");
  for (let i = 0; i < k; i++) {
    if (fixed[i]) done[i] = 1;
  }

  const n = puzzle.size;
  let changed = true;
  while (changed) {
    changed = false;
    for (let i = 0; i < k; i++) {
      if (options[i].length === 0) return { options, settled, broken: true };
      if (!done[i] && options[i].length === 1) {
        done[i] = 1;
        settled.push({ clue: i, rule: narrowedBy[i] });
        changed = true;
      }
    }

    // Squeeze: each clue's certain squares, taken from everyone else.
    for (let i = 0; i < k; i++) {
      let coreLo = FULL_LO;
      let coreHi = FULL_HI;
      for (const o of options[i]) {
        coreLo &= o.lo;
        coreHi &= o.hi;
      }
      if (coreLo === 0 && coreHi === 0) continue;
      for (let j = 0; j < k; j++) {
        if (j === i) continue;
        const kept = options[j].filter((o) => (o.lo & coreLo) === 0 && (o.hi & coreHi) === 0);
        if (kept.length !== options[j].length) {
          options[j] = kept;
          narrowedBy[j] = "squeeze";
          changed = true;
        }
      }
    }

    // Cell: a square only one clue can still reach.
    for (let c = 0; c < n * n; c++) {
      const inLo = c < SPLIT;
      const bit = inLo ? 1 << c : 1 << (c - SPLIT);
      let owner = -1;
      let owners = 0;
      for (let i = 0; i < k && owners < 2; i++) {
        if (options[i].some((o) => ((inLo ? o.lo : o.hi) & bit) !== 0)) {
          owner = i;
          owners++;
        }
      }
      if (owners === 0) return { options, settled, broken: true };
      if (owners !== 1) continue;
      const kept = options[owner].filter((o) => ((inLo ? o.lo : o.hi) & bit) !== 0);
      if (kept.length !== options[owner].length) {
        options[owner] = kept;
        narrowedBy[owner] = "cell";
        changed = true;
      }
    }
  }
  return { options, settled, broken: false };
}

/** Whether [deduce] alone settles every clue of [puzzle]. */
export function solvableByReasoning(puzzle: PatchesPuzzle): boolean {
  if (!wellFormed(puzzle)) return false;
  const { options, broken } = deduce(puzzle);
  return !broken && options.every((o) => o.length === 1);
}

/** The clue index covering each square, row-major. */
export function labelsOf(rects: Rect[], n = SIZE): number[] {
  const out = new Array<number>(n * n).fill(-1);
  rects.forEach((rect, k) => {
    for (const c of cellsOf(rect, n)) out[c] = k;
  });
  return out;
}

/** The answer as a clue index per square — or an empty list for a board with none. */
export function solve(puzzle: PatchesPuzzle): number[] {
  const found = findSolutions(puzzle, 1);
  return found.length > 0 ? labelsOf(found[0], puzzle.size) : [];
}

/**
 * The rectangle clue [k]'s squares form in [labels], or null if they are not
 * one solid rectangle.
 */
export function rectOfLabel(labels: number[], k: number, n = SIZE): Rect | null {
  let top = n;
  let left = n;
  let bottom = -1;
  let right = -1;
  let count = 0;
  for (let i = 0; i < labels.length; i++) {
    if (labels[i] !== k) continue;
    count++;
    const r = Math.floor(i / n);
    const c = i % n;
    if (r < top) top = r;
    if (r > bottom) bottom = r;
    if (c < left) left = c;
    if (c > right) right = c;
  }
  if (count === 0) return null;
  const rect = { top, left, bottom, right };
  return count === (bottom - top + 1) * (right - left + 1) ? rect : null;
}

/**
 * Whether [labels] — a clue index per square — cuts the board legally.
 *
 * The authority on winning, and it re-derives the rules rather than comparing
 * against `solve()`, for the reason given in `queens.ts`: a checker that only
 * compares would turn any generator bug into a board nobody can win.
 */
export function isSolved(puzzle: PatchesPuzzle, labels: number[]): boolean {
  if (!wellFormed(puzzle) || !Array.isArray(labels)) return false;
  const n = puzzle.size;
  const k = puzzle.clues.length;
  if (labels.length !== n * n) return false;
  for (const v of labels) {
    if (!Number.isInteger(v) || v < 0 || v >= k) return false;
  }
  for (let i = 0; i < k; i++) {
    const clue = puzzle.clues[i];
    // A clue's own square belongs to its own patch, which is also what stops
    // one patch from holding two clues: the other clue's square carries the
    // other index.
    if (labels[clue.cell] !== i) return false;
    const rect = rectOfLabel(labels, i, n);
    if (!rect) return false;
    if (!fits(clue, rect.bottom - rect.top + 1, rect.right - rect.left + 1)) return false;
  }
  return true;
}

/**
 * Cuts the board into random rectangles, or null if this draw left a square
 * no rectangle can take.
 *
 * Always fills the first uncovered square in reading order, and that square
 * is always the top-left corner of whatever rectangle covers it — true of
 * every cut of a grid into rectangles — so trying only rectangles anchored
 * there reaches every possible cut. Areas lean towards 3–6: a board of pairs
 * is fiddly, a board of eights is a handful of big moves.
 */
function cut(rand: () => number): Rect[] | null {
  const n = SIZE;
  const taken = new Uint8Array(n * n);
  const rects: Rect[] = [];
  for (let at = 0; at < n * n; at++) {
    if (taken[at]) continue;
    const top = Math.floor(at / n);
    const left = at % n;
    const choices: Array<{ rect: Rect; weight: number }> = [];
    // Widest the row allows from here, before running into a taken square.
    let maxRight = left;
    while (maxRight + 1 < n && !taken[top * n + maxRight + 1]) maxRight++;
    for (let right = left; right <= Math.min(maxRight, left + MAX_SIDE - 1); right++) {
      for (let bottom = top; bottom < Math.min(n, top + MAX_SIDE); bottom++) {
        let free = true;
        for (let c = left; c <= right && free; c++) if (taken[bottom * n + c]) free = false;
        if (!free) break;
        const area = (bottom - top + 1) * (right - left + 1);
        if (area < 2 || area > MAX_AREA) continue;
        choices.push({ rect: { top, left, bottom, right }, weight: area >= 3 && area <= 6 ? 3 : 1 });
      }
    }
    if (choices.length === 0) return null;
    let roll = rand() * choices.reduce((s, c) => s + c.weight, 0);
    let pick = choices[choices.length - 1].rect;
    for (const c of choices) {
      roll -= c.weight;
      if (roll < 0) {
        pick = c.rect;
        break;
      }
    }
    for (const c of cellsOf(pick, n)) taken[c] = 1;
    rects.push(pick);
    if (rects.length > MAX_PATCHES) return null;
  }
  return rects.length >= MIN_PATCHES ? rects : null;
}

/**
 * A hand-checked board for the day the generator cannot produce one. Generated
 * once from the key `2020-02-29` and frozen; the test suite proves it unique.
 */
export const FALLBACK: PatchesPuzzle = {
  size: SIZE,
  difficulty: "medium",
  clues: [
    { cell: 5, shape: "any", area: 8 },
    { cell: 9, shape: "square", area: 0 },
    { cell: 18, shape: "tall", area: 0 },
    { cell: 21, shape: "tall", area: 0 },
    { cell: 23, shape: "tall", area: 0 },
    { cell: 25, shape: "tall", area: 0 },
    { cell: 35, shape: "tall", area: 3 },
    { cell: 36, shape: "tall", area: 3 },
    { cell: 40, shape: "any", area: 6 },
    { cell: 45, shape: "square", area: 4 },
  ],
};

/** Cuts one day may try before shipping the fallback. */
const MAX_CUTS = 400;

/**
 * Fewest numbers a shipped board hides. A cut that stays fair only with
 * nearly every number printed is a sum, not a puzzle; the next cut will do
 * better.
 */
const MIN_HIDDEN_AREAS = 3;

/**
 * The bar every board, and every removal from it, has to clear: one answer,
 * reachable by [deduce]'s reasoning alone. The second implies the first; the
 * solver's count is kept as a belt to the braces, and costs well under a
 * millisecond on a 7×7.
 */
function fair(puzzle: PatchesPuzzle): boolean {
  return solvableByReasoning(puzzle) && countSolutions(puzzle) === 1;
}

/**
 * Today's board.
 *
 * Cuts the board, prints the full truth on every clue (shape and area), and
 * keeps the first cut whose fully printed board has one answer. Then strips
 * clues in a seeded order — a number first, then, on at most [MAX_ANY] clues
 * that kept their number, the shape — keeping each removal only if the answer
 * is still unique. Every removal is checked, so the board that ships is
 * always one the solver has proved.
 *
 * Bounded like every generator here: this runs inside the `daily` query, and
 * one unlucky day key must not be able to take every daily offline with it.
 */
export function generate(dayKey: string): PatchesPuzzle {
  const n = SIZE;
  const rand = randomFor(dayKey, "patches");
  for (let attempt = 0; attempt < MAX_CUTS; attempt++) {
    const rects = cut(rand);
    if (!rects) continue;

    // Each clue at a random square of its patch, then sorted into reading
    // order so the clue (and colour) numbering runs top-left to bottom-right.
    const clues: PatchClue[] = rects
      .map((rect) => {
        const cells = cellsOf(rect, n);
        return {
          cell: cells[Math.floor(rand() * cells.length)],
          shape: shapeOf(rect),
          area: cells.length,
        };
      })
      .sort((a, b) => a.cell - b.cell);
    const puzzle: PatchesPuzzle = { size: n, difficulty: "medium", clues };
    if (!fair(puzzle)) continue;

    const order = shuffle(clues.map((_, i) => i), rand);
    const maxHidden = Math.floor(clues.length * MAX_HIDDEN_AREAS);
    let hidden = 0;
    for (const i of order) {
      if (hidden >= maxHidden) break;
      const area = clues[i].area;
      clues[i].area = 0;
      if (fair(puzzle)) hidden++;
      else clues[i].area = area;
    }
    let anys = 0;
    for (const i of order) {
      if (anys >= MAX_ANY) break;
      if (clues[i].area === 0) continue;
      const shape = clues[i].shape;
      clues[i].shape = "any";
      if (fair(puzzle)) anys++;
      else clues[i].shape = shape;
    }
    if (hidden < MIN_HIDDEN_AREAS) continue;
    return puzzle;
  }
  return { ...FALLBACK, clues: FALLBACK.clues.map((c) => ({ ...c })) };
}
