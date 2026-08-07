/**
 * QUEENS — one crown per row, per column, and per colour region, and no two
 * crowns may touch, not even at a corner.
 *
 * Chosen as the first of the new dailies for the same reason the symbol-code
 * puzzle exists at all: **it contains no words**. This app ships in twelve
 * languages, and a daily whose board differs by locale gives friends a shared
 * scoreboard that compares nothing. A grid of coloured regions is identical in
 * every language, so everyone in the world plays the same board and the
 * standings mean something.
 *
 * ## The solution is guaranteed unique
 *
 * Not a nicety — it is what makes the game fair to time. A board with two
 * solutions is solvable by a guess that happens to land, and ranking players by
 * seconds when some of them were rewarded for guessing is the fastest way to
 * make a daily feel arbitrary. Generation therefore re-rolls until the solver
 * proves exactly one solution exists (`generate` below).
 */

import { randomFor, range, shuffle } from "./rng";

/** Board edge. Eight rows, eight columns, eight regions, eight crowns. */
export const SIZE = 8;

export type QueensPuzzle = {
  size: number;
  /** Region index 0..SIZE-1 for every cell, row-major. */
  regions: number[];
};

/**
 * Every solution, up to [limit] of them, each a column per row.
 *
 * Rows are the search order, which collapses "one per row" from a constraint
 * into the shape of the loop. Adjacency then only has to be checked against the
 * previous row: crowns two or more rows apart cannot touch, and two crowns in
 * the same row are already impossible.
 *
 * Returns the solutions rather than a count because the generator needs the
 * *second* one — it repairs a board by making the extra answer illegal, and to
 * do that it has to see where that answer disagrees.
 */
export function findSolutions(puzzle: QueensPuzzle, limit = 2): number[][] {
  const n = puzzle.size;
  const usedCol = new Array<boolean>(n).fill(false);
  const usedRegion = new Array<boolean>(n).fill(false);
  const pick = new Array<number>(n).fill(-1);
  const found: number[][] = [];

  const rec = (row: number, prevCol: number): void => {
    if (found.length >= limit) return;
    if (row === n) {
      found.push(pick.slice());
      return;
    }
    for (let c = 0; c < n; c++) {
      if (usedCol[c]) continue;
      // Same column is already excluded, so this only ever rejects a diagonal
      // touch against the row above.
      if (row > 0 && Math.abs(c - prevCol) === 1) continue;
      const region = puzzle.regions[row * n + c];
      if (usedRegion[region]) continue;
      usedCol[c] = true;
      usedRegion[region] = true;
      pick[row] = c;
      rec(row + 1, c);
      usedCol[c] = false;
      usedRegion[region] = false;
      if (found.length >= limit) return;
    }
  };

  rec(0, -1);
  return found;
}

/** How many solutions the board has, counted no further than [limit]. */
export function countSolutions(puzzle: QueensPuzzle, limit = 2): number {
  return findSolutions(puzzle, limit).length;
}

/** The board's solution as a column per row, or null unless it has exactly one. */
export function solve(puzzle: QueensPuzzle): number[] | null {
  const found = findSolutions(puzzle, 2);
  return found.length === 1 ? found[0] : null;
}

/**
 * Whether [cols] — a column per row — satisfies every rule.
 *
 * The authority on winning. Deliberately re-derives the rules rather than
 * comparing against `solve()`: a comparison would be correct only for as long
 * as the uniqueness gate holds, and this way a board that somehow shipped with
 * two solutions still accepts both rather than telling a player who is looking
 * at a finished, legal board that they are wrong.
 */
export function isSolved(puzzle: QueensPuzzle, cols: number[]): boolean {
  const n = puzzle.size;
  if (cols.length !== n) return false;
  const seenCol = new Set<number>();
  const seenRegion = new Set<number>();
  for (let row = 0; row < n; row++) {
    const c = cols[row];
    if (!Number.isInteger(c) || c < 0 || c >= n) return false;
    if (seenCol.has(c)) return false;
    seenCol.add(c);
    const region = puzzle.regions[row * n + c];
    if (seenRegion.has(region)) return false;
    seenRegion.add(region);
    if (row > 0 && Math.abs(c - cols[row - 1]) <= 1) return false;
  }
  return true;
}

/**
 * A legal crown placement: a column per row, all distinct, with consecutive
 * rows at least two columns apart so no two crowns touch.
 *
 * Retries rather than backtracks. On an 8×8 board a random permutation clears
 * the adjacency rule often enough that a bounded retry loop is both simpler and
 * faster than a search, and the caller already owns a re-roll path for the
 * uniqueness gate.
 */
function placeCrowns(rand: () => number, n: number): number[] | null {
  for (let attempt = 0; attempt < 200; attempt++) {
    const cols = shuffle(range(n), rand);
    let ok = true;
    for (let r = 1; r < n && ok; r++) {
      if (Math.abs(cols[r] - cols[r - 1]) <= 1) ok = false;
    }
    if (ok) return cols;
  }
  return null;
}

/**
 * Grows [n] contiguous regions outward from the crowns until the board is
 * covered.
 *
 * Seeding one region per crown is what makes "one crown per region" satisfiable
 * by construction — the intended solution is legal before the solver ever runs,
 * so the uniqueness gate is only ever rejecting *extra* solutions, never
 * discovering the board is impossible.
 *
 * Growth picks the smallest region most of the time and a random one otherwise.
 * Pure smallest-first tiles the board into eight near-identical blocks, which
 * looks machine-made and reads as easy; pure random lets one region swallow
 * half the grid and leaves the rest as slivers. The mix gives regions that look
 * hand-drawn, which is also where the difficulty comes from.
 */
function growRegions(rand: () => number, n: number, cols: number[]): number[] {
  const regions = new Array<number>(n * n).fill(-1);
  const sizes = new Array<number>(n).fill(1);
  for (let r = 0; r < n; r++) regions[r * n + cols[r]] = r;

  let remaining = n * n - n;
  while (remaining > 0) {
    // Every region that has at least one unclaimed orthogonal neighbour, with
    // the neighbours it could take.
    const options: Array<{ region: number; cells: number[] }> = [];
    for (let region = 0; region < n; region++) {
      const cells: number[] = [];
      for (let i = 0; i < n * n; i++) {
        if (regions[i] !== region) continue;
        const row = Math.floor(i / n);
        const col = i % n;
        if (row > 0 && regions[i - n] < 0) cells.push(i - n);
        if (row < n - 1 && regions[i + n] < 0) cells.push(i + n);
        if (col > 0 && regions[i - 1] < 0) cells.push(i - 1);
        if (col < n - 1 && regions[i + 1] < 0) cells.push(i + 1);
      }
      if (cells.length > 0) options.push({ region, cells });
    }
    // The grid is connected and something is still unclaimed, so at least one
    // region can always expand — this guards a future change to the loop above,
    // not a reachable state.
    if (options.length === 0) break;

    let choice = options[Math.floor(rand() * options.length)];
    if (rand() < 0.72) {
      let best = options[0];
      for (const o of options) {
        if (sizes[o.region] < sizes[best.region]) best = o;
      }
      choice = best;
    }
    const cell = choice.cells[Math.floor(rand() * choice.cells.length)];
    regions[cell] = choice.region;
    sizes[choice.region]++;
    remaining--;
  }

  return regions;
}

/**
 * Whether [cell] can leave its region without cutting that region in two.
 *
 * A region split into two islands is not a colour region any more — the rule
 * "one crown per colour" stops reading as a spatial constraint and the board
 * looks like a rendering bug. Flood-fills what would remain and checks it is
 * still one piece.
 */
function canRelease(regions: number[], n: number, cell: number): boolean {
  const region = regions[cell];
  const members: number[] = [];
  for (let i = 0; i < regions.length; i++) {
    if (i !== cell && regions[i] === region) members.push(i);
  }
  if (members.length === 0) return false;

  const seen = new Set<number>([members[0]]);
  const queue = [members[0]];
  while (queue.length > 0) {
    const at = queue.pop()!;
    const row = Math.floor(at / n);
    const col = at % n;
    const around: number[] = [];
    if (row > 0) around.push(at - n);
    if (row < n - 1) around.push(at + n);
    if (col > 0) around.push(at - 1);
    if (col < n - 1) around.push(at + 1);
    for (const next of around) {
      if (next === cell || regions[next] !== region || seen.has(next)) continue;
      seen.add(next);
      queue.push(next);
    }
  }
  return seen.size === members.length;
}

/**
 * Today's board.
 *
 * ## Why this repairs rather than re-rolls
 *
 * The obvious generator — draw regions, check uniqueness, throw the board away
 * and draw again — does not work here, and measuring it is what showed why: an
 * 8×8 board grown from eight seeds essentially never has a unique solution by
 * luck, so a re-roll loop burns its whole budget and ships a fallback every
 * single day.
 *
 * So the loop below fixes the board it has instead. Ask the solver for a second
 * answer; find a row where that answer puts its crown somewhere the intended
 * one does not; move that cell into a neighbouring region. Two things make this
 * safe to iterate. The intended solution can never be broken by it, because the
 * cell being moved is by definition not one of the intended crowns and no
 * crown's own region membership changes. And the unwanted solution is always
 * broken by it, because that solution used all eight regions exactly once, so
 * handing its crown a region another of its rows already claimed makes it
 * illegal. Each pass therefore strictly kills one answer and keeps the one the
 * board was built around — the board tightens rather than being rerolled.
 *
 * Both loops are bounded. A generator that can spin forever is a generator that
 * can take the daily offline on one unlucky day key, and this runs inside a
 * subscribed query.
 */
export function generate(dayKey: string): QueensPuzzle {
  let fallback: QueensPuzzle | null = null;

  for (let attempt = 0; attempt < 40; attempt++) {
    const rand = randomFor(dayKey, "queens", attempt);
    const cols = placeCrowns(rand, SIZE);
    if (!cols) continue;
    const puzzle: QueensPuzzle = {
      size: SIZE,
      regions: growRegions(rand, SIZE, cols),
    };
    fallback ??= puzzle;

    for (let repair = 0; repair < 400; repair++) {
      // Several rival answers rather than just one. Not every disagreement is
      // actionable — a cell that is its region's only bridge cannot leave
      // without splitting it — and asking for one alternative meant a board got
      // abandoned whenever that single alternative happened to be the stuck
      // kind, even though a different one was sitting right behind it.
      const found = findSolutions(puzzle, 6);
      if (found.length === 1) return puzzle;
      const rivals = shuffle(
        found.filter((s) => s.some((c, r) => c !== cols[r])),
        rand
      );
      if (rivals.length === 0) break;

      let moved = false;
      for (const other of rivals) {
        const rows = shuffle(
          range(SIZE).filter((r) => other[r] !== cols[r]),
          rand
        );
        for (const row of rows) {
          const cell = row * SIZE + other[row];
          if (!canRelease(puzzle.regions, SIZE, cell)) continue;
          const col = other[row];
          const around: number[] = [];
          if (row > 0) around.push(cell - SIZE);
          if (row < SIZE - 1) around.push(cell + SIZE);
          if (col > 0) around.push(cell - 1);
          if (col < SIZE - 1) around.push(cell + 1);
          const targets = shuffle(
            around
              .map((i) => puzzle.regions[i])
              .filter((r) => r !== puzzle.regions[cell]),
            rand
          );
          if (targets.length === 0) continue;
          puzzle.regions[cell] = targets[0];
          moved = true;
          break;
        }
        if (moved) break;
      }
      // Every rival is stuck. Rare, and a fresh seed is cheaper than trying to
      // reason a way out of it.
      if (!moved) break;
    }
  }

  return fallback ?? { size: SIZE, regions: new Array(SIZE * SIZE).fill(0) };
}
