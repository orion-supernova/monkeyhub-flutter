/**
 * STAR BATTLE — place two stars in every row, every column and every colour
 * region of a 10×10 board, with no two stars touching, not even at a corner.
 *
 * Queens' bigger sibling, and for the same reason it made the shortlist: a
 * grid of coloured regions contains no words, so the board is identical in all
 * twelve languages. See `queens.ts` for the full argument.
 *
 * Fixed at HARD. Two stars per unit is a genuinely different puzzle from one:
 * the easy Queens deduction ("this region is one row tall, so that row is
 * spoken for") turns into counting arguments over groups of rows and regions,
 * which is where the difficulty — and the satisfaction — comes from.
 *
 * ## The solution is guaranteed unique
 *
 * Not a nicety, for the reason given in `queens.ts`: a board with two answers
 * rewards a lucky guess on a timed, shared scoreboard. `generate` repairs the
 * board until the solver proves exactly one answer.
 *
 * ## The submission shape
 *
 * A 0/1 per cell, row-major — 100 numbers. Not a column-pair per row (which
 * would fit in 20) because that is what the client's grid naturally holds, and
 * because a strict checker over a per-cell board can say "you put a star where
 * there isn't one" without first decoding a second representation.
 */

import { neighbours } from "./grid";
import { randomFor, range, shuffle } from "./rng";

/** Board edge. Ten rows, ten columns, ten regions. */
export const SIZE = 10;

/** Stars per row, per column and per region. */
export const STARS = 2;

export type StarBattlePuzzle = {
  size: number;
  difficulty: "easy" | "medium" | "hard";
  /** Region index 0..size-1 for every cell, row-major. */
  regions: number[];
};

/** Regions that name a real region for every cell; anything else is unsolvable. */
function wellFormed(puzzle: StarBattlePuzzle): boolean {
  const n = puzzle.size;
  if (n !== SIZE) return false;
  if (!Array.isArray(puzzle.regions) || puzzle.regions.length !== n * n) return false;
  for (const r of puzzle.regions) {
    if (!Number.isInteger(r) || r < 0 || r >= n) return false;
  }
  return true;
}

/** Every legal pair of stars within one row: two columns that do not touch. */
const ROW_PAIRS: Array<[number, number]> = (() => {
  const out: Array<[number, number]> = [];
  for (let a = 0; a < SIZE; a++) {
    for (let b = a + 2; b < SIZE; b++) out.push([a, b]);
  }
  return out;
})();
const PAIR_A = Int8Array.from(ROW_PAIRS.map((p) => p[0]));
const PAIR_B = Int8Array.from(ROW_PAIRS.map((p) => p[1]));

/** Powers of three, for packing per-column and per-region counts into a key. */
const POW3 = Int32Array.from({ length: SIZE }, (_, i) => 3 ** i);

/**
 * The solver's memory of dead states: an open-addressing hash set, allocated
 * once per isolate and reused across calls.
 *
 * Not a `Set<number>`. The packed state does not fit a small integer, so a
 * `Set` would box every key on the heap, and the repair loop calls the solver
 * dozens of times per board — the allocation was a measurable share of
 * generation time. Entries carry the generation of the call that wrote them, so
 * starting a new call is one increment rather than clearing the table. Once the
 * table is two-thirds full it simply stops remembering; the search stays
 * correct, it just loses the shortcut.
 */
const DEAD_BITS = 15;
const DEAD_SIZE = 1 << DEAD_BITS;
const DEAD_CAP = Math.floor((DEAD_SIZE * 2) / 3);
// Allocated on first use, so every other function that imports `games.ts`
// does not pay for a table only Star Battle needs.
let deadA: Int32Array | null = null;
let deadB: Int32Array | null = null;
let deadGen: Int32Array | null = null;
let generation = 0;

function deadSlot(a: number, b: number): number {
  return (Math.imul(a ^ Math.imul(b, 0x27d4eb2d), 0x9e3779b1) >>> (32 - DEAD_BITS));
}

/**
 * Every solution, up to [limit] of them, each as a 0/1 per cell.
 *
 * ## The search
 *
 * Row by row, like Queens: each row picks one of the 36 non-touching column
 * pairs, which makes "two per row" the shape of the loop rather than a check,
 * and means touching only ever has to be tested against the row above. Then:
 *
 *  - **columns** cap at two, and a column that still needs two stars needs at
 *    least three rows left to put them in (two stars in one column cannot sit
 *    in adjacent rows);
 *  - **regions** cap at two, and a region whose last row has just been placed
 *    must have its two by then — the prune that does most of the work, since a
 *    region confined to a band of rows forces that band immediately;
 *  - **bands of rows cannot be oversubscribed**: the regions that end within
 *    the next k rows need all their missing stars there, and k rows hold only
 *    2k stars — the counting argument people actually solve this puzzle with;
 *  - **every region still short of stars has room for them** in the rows
 *    below, in columns that are not full yet — which catches a region starved
 *    by its columns filling up long before its last row arrives;
 *  - **dead states are remembered.** After any row, everything that matters
 *    for the rest of the board is the column counts, the region counts and the
 *    row just placed. Two different partial boards that agree on those have
 *    exactly the same completions, so once one is shown to have none the other
 *    is skipped without being searched. This is what makes proving uniqueness
 *    — the expensive case, where the whole tree has to be walked — cheap enough
 *    for the repair loop to call it dozens of times.
 *
 * Returns solutions rather than a count because the generator needs the rival
 * answers themselves, to see where they disagree with the intended one.
 */
export function findSolutions(puzzle: StarBattlePuzzle, limit = 2): number[][] {
  if (!wellFormed(puzzle)) return [];
  const n = SIZE;
  const regions = puzzle.regions;

  const lastRow = new Int8Array(n).fill(-1);
  for (let i = 0; i < n * n; i++) lastRow[regions[i]] = Math.floor(i / n);
  // Every region must exist, or the board cannot have two stars in each.
  for (let g = 0; g < n; g++) if (lastRow[g] < 0) return [];
  // Regions whose last row is [row], as a bitmask over regions.
  const closing = new Int32Array(n);
  for (let g = 0; g < n; g++) closing[lastRow[g]] |= 1 << g;
  // Columns each region occupies in each row, as a bitmask: [g * n + row].
  const shape = new Int32Array(n * n);
  for (let i = 0; i < n * n; i++) shape[regions[i] * n + Math.floor(i / n)] |= 1 << (i % n);

  const colCount = new Int8Array(n);
  const regCount = new Int8Array(n);
  const band = new Int8Array(n);
  const picks = new Int32Array(n * 2);
  const found: number[][] = [];
  let colKey = 0;
  let regKey = 0;
  let deadCount = 0;
  if (!deadA || !deadB || !deadGen) {
    deadA = new Int32Array(DEAD_SIZE);
    deadB = new Int32Array(DEAD_SIZE);
    deadGen = new Int32Array(DEAD_SIZE);
  }
  const keysA = deadA;
  const keysB = deadB;
  const stamps = deadGen;
  generation = (generation + 1) | 0;
  if (generation === 0) {
    stamps.fill(0);
    generation = 1;
  }
  const gen = generation;

  /** Whether the board after placing [mask] in [row] can still be finished. */
  const viable = (row: number, mask: number): boolean => {
    for (let g = 0; g < n; g++) {
      if ((closing[row] >> g) & 1 && regCount[g] !== STARS) return false;
    }
    const left = n - 1 - row;
    let full = 0;
    for (let c = 0; c < n; c++) {
      const need = STARS - colCount[c];
      if (need === 0) {
        full |= 1 << c;
        continue;
      }
      // Rows still free for this column: all remaining ones, minus the next
      // if this row just put a star here.
      const rows = (mask >> c) & 1 ? left - 1 : left;
      if (need === 2 ? rows < 3 : rows < 1) return false;
    }

    band.fill(0);
    const touching = mask | (mask << 1) | (mask >> 1);
    for (let g = 0; g < n; g++) {
      const need = STARS - regCount[g];
      if (need === 0) continue;
      band[lastRow[g]] += need;
      // A row can give a region two stars only if it has two free cells that
      // do not touch; the next row also loses whatever touches this one.
      let room = 0;
      for (let r = row + 1; r <= lastRow[g] && room < need; r++) {
        let m = shape[g * n + r] & ~full;
        if (r === row + 1) m &= ~touching;
        if (m === 0) continue;
        const low = m & -m;
        room += m & ~(low | (low << 1)) ? 2 : 1;
      }
      if (room < need) return false;
    }
    let owed = 0;
    for (let r = row + 1; r < n; r++) {
      owed += band[r];
      if (owed > STARS * (r - row)) return false;
    }
    return true;
  };

  const rec = (row: number, prevMask: number): void => {
    if (row === n) {
      const cells = new Array<number>(n * n).fill(0);
      for (let r = 0; r < n; r++) {
        cells[r * n + picks[r * 2]] = 1;
        cells[r * n + picks[r * 2 + 1]] = 1;
      }
      found.push(cells);
      return;
    }
    // Columns touching a star in the row above.
    const blocked = prevMask | (prevMask << 1) | (prevMask >> 1);
    const base = row * n;

    for (let p = 0; p < PAIR_A.length; p++) {
      const a = PAIR_A[p];
      const b = PAIR_B[p];
      if ((blocked >> a) & 1 || (blocked >> b) & 1) continue;
      if (colCount[a] >= STARS || colCount[b] >= STARS) continue;
      const ga = regions[base + a];
      const gb = regions[base + b];
      if (ga === gb ? regCount[ga] > 0 : regCount[ga] >= STARS || regCount[gb] >= STARS) {
        continue;
      }

      colCount[a]++;
      colCount[b]++;
      regCount[ga]++;
      regCount[gb]++;
      colKey += POW3[a] + POW3[b];
      regKey += POW3[ga] + POW3[gb];
      const mask = (1 << a) | (1 << b);

      if (viable(row, mask)) {
        // colKey < 3^10 and mask < 2^10, so the first half fits an int32;
        // regKey < 3^10 and row < 16 likewise.
        const ka = colKey * 1024 + mask;
        const kb = regKey * 16 + row;
        let slot = deadSlot(ka, kb);
        let known = false;
        while (stamps[slot] === gen) {
          if (keysA[slot] === ka && keysB[slot] === kb) {
            known = true;
            break;
          }
          slot = (slot + 1) & (DEAD_SIZE - 1);
        }
        if (!known) {
          const before = found.length;
          picks[row * 2] = a;
          picks[row * 2 + 1] = b;
          rec(row + 1, mask);
          if (found.length === before && deadCount < DEAD_CAP) {
            // Probed again rather than reusing [slot]: the search below may
            // have filled it with a deeper row's key in the meantime.
            let at = deadSlot(ka, kb);
            while (stamps[at] === gen) at = (at + 1) & (DEAD_SIZE - 1);
            stamps[at] = gen;
            keysA[at] = ka;
            keysB[at] = kb;
            deadCount++;
          }
        }
      }

      colCount[a]--;
      colCount[b]--;
      regCount[ga]--;
      regCount[gb]--;
      colKey -= POW3[a] + POW3[b];
      regKey -= POW3[ga] + POW3[gb];
      if (found.length >= limit) return;
    }
  };

  rec(0, 0);
  return found;
}

/** How many solutions the board has, counted no further than [limit]. */
export function countSolutions(puzzle: StarBattlePuzzle, limit = 2): number {
  return findSolutions(puzzle, limit).length;
}

/** The answer as a 0/1 per cell — or an empty list for a board with none. */
export function solve(puzzle: StarBattlePuzzle): number[] {
  const found = findSolutions(puzzle, 1);
  return found.length > 0 ? found[0] : [];
}

/**
 * Whether [cells] — a 0/1 per cell — satisfies every rule.
 *
 * The authority on winning. Re-derives the rules rather than comparing against
 * `solve()`, for the reason given in `queens.ts`.
 */
export function isSolved(puzzle: StarBattlePuzzle, cells: number[]): boolean {
  if (!wellFormed(puzzle) || !Array.isArray(cells)) return false;
  const n = puzzle.size;
  if (cells.length !== n * n) return false;
  const rows = new Array<number>(n).fill(0);
  const cols = new Array<number>(n).fill(0);
  const regs = new Array<number>(n).fill(0);
  for (let i = 0; i < cells.length; i++) {
    const v = cells[i];
    if (v !== 0 && v !== 1) return false;
    if (v === 0) continue;
    const row = Math.floor(i / n);
    const col = i % n;
    rows[row]++;
    cols[col]++;
    regs[puzzle.regions[i]]++;
    // Only right, below and the two lower diagonals: every touching pair is
    // seen once from its upper-left member.
    if (col < n - 1 && cells[i + 1] === 1) return false;
    if (row < n - 1) {
      if (cells[i + n] === 1) return false;
      if (col > 0 && cells[i + n - 1] === 1) return false;
      if (col < n - 1 && cells[i + n + 1] === 1) return false;
    }
  }
  for (let k = 0; k < n; k++) {
    if (rows[k] !== STARS || cols[k] !== STARS || regs[k] !== STARS) return false;
  }
  return true;
}

/**
 * One cell put right: a star that should not be there (value 0) if the board
 * has any, otherwise a star that is missing (value 1).
 *
 * A wrong star first because it is the thing actually blocking the player —
 * every deduction they make around it is built on sand. [progress] is read as
 * "1 is a star, anything else is not", so a client that marks dots or crosses
 * with other values still gets sensible help. Rotates with [seq] among
 * candidates, so a second hint is a different cell.
 */
export function hint(
  puzzle: StarBattlePuzzle,
  progress: number[],
  seq: number
): { index: number; value: number; cells?: number[] } | null {
  const answer = solve(puzzle);
  if (answer.length === 0) return null;
  const board = Array.isArray(progress) ? progress : [];

  const wrong: number[] = [];
  const missing: number[] = [];
  for (let i = 0; i < answer.length; i++) {
    const star = board[i] === 1;
    if (star && answer[i] === 0) wrong.push(i);
    else if (!star && answer[i] === 1) missing.push(i);
  }
  const turn = Number.isInteger(seq) && seq > 0 ? seq : 0;
  if (wrong.length > 0) return { index: wrong[turn % wrong.length], value: 0 };
  if (missing.length > 0) return { index: missing[turn % missing.length], value: 1 };
  return null;
}

/**
 * A legal star placement — two per row, two per column, none touching — as
 * star cells, or null if the bounded search gave up.
 *
 * Backtracks row by row over shuffled column pairs, with the same column
 * look-ahead the solver uses. Unlike Queens' single-crown rows, a random draw
 * per row almost never survives ten rows of "≤ 2 per column, no touching",
 * so this has to be a real search; the look-ahead keeps it to a few dozen
 * steps.
 */
function placeStars(rand: () => number): number[] | null {
  const n = SIZE;
  const colCount = new Int8Array(n);
  const picks: number[] = [];
  let steps = 0;

  const rec = (row: number, prevMask: number): boolean => {
    if (++steps > 5000) return false;
    if (row === n) return true;
    const blocked = prevMask | (prevMask << 1) | (prevMask >> 1);
    const left = n - 1 - row;
    for (const [a, b] of shuffle(ROW_PAIRS.slice(), rand)) {
      if ((blocked >> a) & 1 || (blocked >> b) & 1) continue;
      if (colCount[a] >= STARS || colCount[b] >= STARS) continue;
      colCount[a]++;
      colCount[b]++;
      const mask = (1 << a) | (1 << b);
      let ok = true;
      for (let c = 0; c < n && ok; c++) {
        const need = STARS - colCount[c];
        const rows = (mask >> c) & 1 ? left - 1 : left;
        if (need === 2 ? rows < 3 : need === 1 && rows < 1) ok = false;
      }
      if (ok) {
        picks.push(row * n + a, row * n + b);
        if (rec(row + 1, mask)) return true;
        picks.length -= 2;
      }
      colCount[a]--;
      colCount[b]--;
      if (steps > 5000) return false;
    }
    return false;
  };

  return rec(0, 0) ? picks : null;
}

/**
 * Pairs the twenty stars into ten regions' worth, closest pairs first.
 *
 * Greedy over all pairs sorted by distance (ties broken by the seeded shuffle
 * before the sort). Two stars that start a region together have to be joined
 * by a corridor of that region's cells, and a long corridor across the board
 * walls off everything on either side of it — near pairs keep each region's
 * seed compact and leave the rest of the board for growth to shape.
 */
function pairStars(rand: () => number, stars: number[]): Array<[number, number]> | null {
  const n = SIZE;
  const dist = (x: number, y: number) =>
    Math.abs(Math.floor(x / n) - Math.floor(y / n)) + Math.abs((x % n) - (y % n));
  const all: Array<[number, number, number]> = [];
  for (let i = 0; i < stars.length; i++) {
    for (let j = i + 1; j < stars.length; j++) all.push([i, j, dist(stars[i], stars[j])]);
  }
  shuffle(all, rand);
  all.sort((p, q) => p[2] - q[2]);
  const used = new Array<boolean>(stars.length).fill(false);
  const out: Array<[number, number]> = [];
  for (const [i, j] of all) {
    if (used[i] || used[j]) continue;
    used[i] = true;
    used[j] = true;
    out.push([stars[i], stars[j]]);
  }
  return out.length === SIZE ? out : null;
}

/**
 * Claims, for each pair in order, a shortest corridor of free cells between its
 * two stars that steps on no other star. Returns false if some pair is walled
 * off by the corridors already drawn.
 *
 * This is what makes "two stars per region" satisfiable by construction: each
 * region starts as one connected piece holding exactly its own two stars, so
 * the intended answer is legal before the solver ever runs, and the uniqueness
 * work is only ever about removing *extra* answers.
 */
function carveSeeds(
  rand: () => number,
  pairs: Array<[number, number]>,
  regions: number[]
): boolean {
  const n = SIZE;
  const isStar = new Uint8Array(n * n);
  for (const [a, b] of pairs) {
    isStar[a] = 1;
    isStar[b] = 1;
  }
  const from = new Int32Array(n * n);
  for (let g = 0; g < pairs.length; g++) {
    const [a, b] = pairs[g];
    from.fill(-2);
    from[a] = -1;
    const queue = [a];
    for (let q = 0; q < queue.length && from[b] === -2; q++) {
      for (const x of shuffle(neighbours(queue[q], n), rand)) {
        if (from[x] !== -2) continue;
        if (x !== b && (isStar[x] || regions[x] >= 0)) continue;
        from[x] = queue[q];
        queue.push(x);
      }
    }
    if (from[b] === -2) return false;
    for (let at = b; at !== -1; at = from[at]) regions[at] = g;
  }
  return true;
}

/**
 * Grows the seeded regions outward until the board is covered, the same way
 * `queens.ts` does it — smallest region most of the time, a random one
 * otherwise — for the same reason: pure smallest-first tiles the board into
 * near-identical blocks, pure random leaves one blob and a handful of slivers.
 * Growth only ever adds a cell next to its region, so every region stays one
 * connected piece.
 */
function growRegions(rand: () => number, regions: number[]): void {
  const n = SIZE;
  const sizes = new Array<number>(n).fill(0);
  let remaining = 0;
  for (const r of regions) {
    if (r >= 0) sizes[r]++;
    else remaining++;
  }
  while (remaining > 0) {
    const options: Array<{ region: number; cells: number[] }> = [];
    const byRegion: number[][] = Array.from({ length: n }, () => []);
    for (let i = 0; i < n * n; i++) {
      if (regions[i] >= 0) continue;
      const seen = new Set<number>();
      for (const x of neighbours(i, n)) {
        const r = regions[x];
        if (r >= 0 && !seen.has(r)) {
          seen.add(r);
          byRegion[r].push(i);
        }
      }
    }
    for (let r = 0; r < n; r++) if (byRegion[r].length > 0) options.push({ region: r, cells: byRegion[r] });
    // The grid is connected and something is still unclaimed, so some region
    // always borders it — a guard for a future change, not a reachable state.
    if (options.length === 0) return;

    let choice = options[Math.floor(rand() * options.length)];
    if (rand() < 0.72) {
      let best = options[0];
      for (const o of options) if (sizes[o.region] < sizes[best.region]) best = o;
      choice = best;
    }
    const cell = choice.cells[Math.floor(rand() * choice.cells.length)];
    regions[cell] = choice.region;
    sizes[choice.region]++;
    remaining--;
  }
}

/**
 * A hand-checked board for the day the generator cannot produce one. Generated
 * once from the key `2020-02-29` and frozen; the test suite proves it unique.
 */
export const FALLBACK: StarBattlePuzzle = {
  size: SIZE,
  difficulty: "hard",
  regions: [
    7, 7, 7, 7, 7, 7, 7, 7, 7, 0,
    7, 7, 3, 7, 7, 0, 0, 0, 0, 0,
    7, 6, 3, 3, 3, 3, 0, 0, 0, 0,
    6, 6, 3, 9, 3, 8, 8, 0, 0, 0,
    9, 6, 6, 9, 9, 8, 8, 8, 4, 4,
    9, 1, 1, 9, 9, 9, 9, 8, 4, 4,
    9, 1, 1, 9, 9, 9, 9, 2, 4, 4,
    9, 1, 1, 9, 2, 2, 2, 2, 4, 4,
    9, 1, 9, 9, 9, 5, 2, 5, 5, 4,
    9, 9, 9, 9, 9, 5, 5, 5, 5, 4,
  ],
};

/** Rival answers asked for per solver call in the repair loop. */
const RIVALS_PER_CALL = 4;

/** Longest corridor `evict` will hand over in one move. */
const MAX_EVICT = 4;

/**
 * Moves [cell] out of its region and into a neighbouring one. Returns false,
 * changing nothing, if that cannot be done without breaking the intended
 * answer.
 *
 * The single-cell move in `queens.ts` is the common case here too, but two
 * situations that are rare on Queens' 8×8 are routine on a 10×10 with two
 * stars per region, and without handling them about half of all seeds were
 * abandoned as stuck:
 *
 *  - **the cell is in the middle of its region**, with no foreign neighbour to
 *    hand it to. Then the shortest corridor of the region's cells from it to
 *    the border moves with it.
 *  - **the cell is a bridge**, and taking it splits the region. Then the
 *    pieces that would be cut off go with it, and the region keeps the one
 *    piece that holds both of its intended stars. (If its two stars would end
 *    up in different pieces, the move is refused.)
 *
 * Safe for the same reasons as a single cell. Nothing that moves is a star of
 * the intended answer, so no region's intended star count changes. The region
 * left behind is one piece by construction. The receiving region stays one
 * piece because the corridor ends against it and every cut-off piece borders
 * the corridor. And the rival this was called for dies: it already had two
 * stars in the receiving region, and [cell] gives it a third.
 */
function evict(
  rand: () => number,
  regions: number[],
  intended: Uint8Array,
  cell: number
): boolean {
  const n = SIZE;
  const home = regions[cell];

  // Shortest corridor from [cell] to a cell with a foreign neighbour, through
  // the home region, avoiding its intended stars.
  const from = new Map<number, number>([[cell, -1]]);
  const depth = new Map<number, number>([[cell, 1]]);
  const queue = [cell];
  let end = -1;
  let target = -1;
  for (let q = 0; q < queue.length && end < 0; q++) {
    const at = queue[q];
    const around = shuffle(neighbours(at, n), rand);
    for (const x of around) {
      if (regions[x] !== home) {
        end = at;
        target = regions[x];
        break;
      }
    }
    if (end >= 0 || depth.get(at)! >= MAX_EVICT) continue;
    for (const x of around) {
      if (regions[x] !== home || intended[x] || from.has(x)) continue;
      from.set(x, at);
      depth.set(x, depth.get(at)! + 1);
      queue.push(x);
    }
  }
  if (end < 0) return false;

  const moving = new Uint8Array(regions.length);
  for (let at = end; at >= 0; at = from.get(at)!) moving[at] = 1;

  // What stays: the piece of the rest of the home region that holds its
  // intended stars. Both must be in it.
  let anchor = -1;
  let stars = 0;
  for (let i = 0; i < regions.length; i++) {
    if (regions[i] === home && intended[i]) {
      stars++;
      if (anchor < 0) anchor = i;
    }
  }
  if (anchor < 0) return false;
  const keep = new Uint8Array(regions.length);
  keep[anchor] = 1;
  const stack = [anchor];
  let kept = 0;
  while (stack.length > 0) {
    const at = stack.pop()!;
    if (intended[at]) kept++;
    for (const x of neighbours(at, n)) {
      if (regions[x] !== home || moving[x] || keep[x]) continue;
      keep[x] = 1;
      stack.push(x);
    }
  }
  if (kept !== stars) return false;

  for (let i = 0; i < regions.length; i++) {
    if (regions[i] === home && !keep[i]) regions[i] = target;
  }
  return true;
}

/**
 * Repairs one board may take before it is abandoned for a fresh seed.
 *
 * Lower than the 150 first planned, and measured to be: over 640 day keys the
 * boards that converge almost all do so well inside forty repairs, while a
 * board still fighting rivals past that point is usually on a trajectory that
 * would burn the whole budget. Abandoning it early took the slowest day from
 * ~260 ms to ~55 ms without a single extra fallback — a fresh seed is cheaper
 * than a stubborn one.
 */
const MAX_REPAIRS = 40;

/** Fresh seeds one day may try before shipping the fallback. */
const MAX_ATTEMPTS = 15;

/**
 * Today's board.
 *
 * Places the stars first, gives each pair of them a region, grows the regions,
 * and then **repairs rather than re-rolls**, exactly as Queens does and for the
 * same reason: a board grown from seeds essentially never has a unique answer
 * by luck.
 *
 * Each repair asks the solver for a few rival answers, finds a cell where a
 * rival puts a star and the intended answer does not, and hands that cell to a
 * neighbouring region. The intended answer survives (no region it uses changes
 * its star count — the cell carries none of its stars), and that rival dies
 * (it already had two stars in the receiving region, and now has three). Each
 * pass therefore removes at least one answer and never the one the board was
 * built around. Every region stays in one piece (see `evict` for how, when
 * the cell is buried inside its region or is its only bridge).
 *
 * Both loops are bounded — this runs inside a subscribed query alongside every
 * other daily, and a generator that can spin is one that can take them all
 * offline on one unlucky day key.
 */
export function generate(dayKey: string): StarBattlePuzzle {
  const n = SIZE;
  for (let attempt = 0; attempt < MAX_ATTEMPTS; attempt++) {
    const rand = randomFor(dayKey, "starbattle", attempt);
    const stars = placeStars(rand);
    if (!stars) continue;
    const pairs = pairStars(rand, stars);
    if (!pairs) continue;
    const regions = new Array<number>(n * n).fill(-1);
    if (!carveSeeds(rand, pairs, regions)) continue;
    growRegions(rand, regions);
    if (regions.some((r) => r < 0)) continue;

    const intended = new Uint8Array(n * n);
    for (const s of stars) intended[s] = 1;
    const puzzle: StarBattlePuzzle = { size: n, difficulty: "hard", regions };

    for (let repair = 0; repair < MAX_REPAIRS; repair++) {
      // Several rivals per solver call, and every one of them still alive gets
      // repaired before asking again. The solver is the expensive part of this
      // loop, so a call that turns up four rivals should cost four of them, not
      // one.
      const found = findSolutions(puzzle, RIVALS_PER_CALL + 1);
      if (found.length === 1) return puzzle;
      const rivals = shuffle(
        found.filter((s) => s.some((v, i) => v !== intended[i])),
        rand
      );
      if (rivals.length === 0) break;

      let moved = false;
      for (const other of rivals) {
        // An earlier move this round may already have broken it.
        if (moved && !isSolved(puzzle, other)) continue;
        const cells = shuffle(
          range(n * n).filter((i) => other[i] === 1 && intended[i] === 0),
          rand
        );
        for (const cell of cells) {
          if (evict(rand, regions, intended, cell)) {
            moved = true;
            break;
          }
        }
      }
      // Every rival is stuck. Rare, and a fresh seed is cheaper than trying to
      // reason a way out of it.
      if (!moved) break;
    }
  }
  return { ...FALLBACK, regions: FALLBACK.regions.slice() };
}
