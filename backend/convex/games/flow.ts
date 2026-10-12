/**
 * FLOW — connect each pair of same-coloured dots with a pipe, so that pipes
 * never cross and every cell of the grid ends up holding one.
 *
 * Coloured dots and lines, so the board is identical in all twelve languages —
 * the same reason Queens and Zip were chosen. See `queens.ts` for the argument.
 *
 * Fixed at EASY: a 7×7 board with six or seven pairs. It is the gentle one on
 * the shelf, the daily somebody plays first to warm up, and a 7×7 with fewer,
 * longer pipes is still a puzzle you have to look at rather than a colouring
 * exercise.
 *
 * ## The solution is guaranteed unique
 *
 * Like Queens and Tango, and unlike Zip. Zip's rule ("cover every cell in
 * order") is something any route that satisfies it has genuinely solved. Flow
 * is different: a board with two fillings lets a player connect the pairs the
 * lazy way and be told they are done while a friend did the actual deduction,
 * and both are ranked on the same clock. `generate` re-rolls until the counting
 * solver below proves exactly one filling exists.
 *
 * ## The submission shape
 *
 * One flat list, because that is what `games.ts` stores for every game: for each
 * colour in order, that colour's pipe from `endpoints[k][0]` to
 * `endpoints[k][1]`, concatenated. Every cell is in exactly one pipe, so the
 * whole thing is `size * size` long, and the boundaries between pipes are
 * recoverable without a separator: pipe k ends the moment it reaches its second
 * dot.
 */

import { hamiltonianPath, isAdjacent, neighbours } from "./grid";
import { randomFor, shuffle } from "./rng";

/** Board edge. */
export const SIZE = 7;

/** How many pairs a board may have. Both ends inclusive. */
export const MIN_PAIRS = 6;
export const MAX_PAIRS = 7;

/**
 * Shortest pipe the generator will cut.
 *
 * A two-cell pipe is two dots touching, which is not a pipe; it is a domino
 * the player taps once. Three is the shortest length that asks for a decision.
 */
export const MIN_PIPE = 3;

/**
 * Longest pipe the generator will cut. Above this one colour snakes across most
 * of the board and the rest are stubs, which reads as one puzzle and five
 * afterthoughts.
 */
export const MAX_PIPE = 14;

export type FlowPuzzle = {
  size: number;
  difficulty: "easy" | "medium" | "hard";
  /** Both dots of each colour, as row-major cell indices. Colour k is index k. */
  endpoints: [number, number][];
};

/** Endpoints that name real, distinct cells — anything else has no solution. */
function wellFormed(puzzle: FlowPuzzle): boolean {
  const n = puzzle.size;
  if (!Number.isInteger(n) || n < 2 || n > 16) return false;
  if (!Array.isArray(puzzle.endpoints) || puzzle.endpoints.length === 0) return false;
  const seen = new Set<number>();
  for (const pair of puzzle.endpoints) {
    if (!Array.isArray(pair) || pair.length !== 2) return false;
    for (const c of pair) {
      if (!Number.isInteger(c) || c < 0 || c >= n * n || seen.has(c)) return false;
      seen.add(c);
    }
  }
  return true;
}

/**
 * Every filling, up to [limit] of them, each as one pipe per colour (from the
 * first dot to the second).
 *
 * ## The search
 *
 * Pipes are drawn outward from their first dot, one cell at a time, always
 * extending the colour with the FEWEST legal next steps. That ordering is what
 * makes the search cheap: on a half-drawn board most colours have exactly one
 * way forward, so the "search" is mostly a chain of forced moves, and the
 * genuine branch points are rare.
 *
 * After every move the board is checked for four things that make it hopeless,
 * each of which is a *proof* of no completion rather than a heuristic:
 *
 *  - **a dead cell** — an empty cell with fewer than two ways for a pipe to
 *    pass through it (a pipe needs an in and an out);
 *  - **a stranded colour** — an unfinished pipe whose head can no longer reach
 *    its own second dot through empty cells;
 *  - **an orphaned region** — a pocket of empty cells that no unfinished colour
 *    can both enter and leave, so nothing could ever fill it;
 *  - **a finished board with holes**, which the rules forbid.
 *
 * ## What the search deliberately does NOT prune
 *
 * Many Flow solvers also refuse a pipe that brushes against itself, or one that
 * fills a 2×2 block on its own, on the grounds that "a well-made puzzle never
 * needs one". That is true of the *intended* answer — the generator below makes
 * sure its own pipes never touch themselves — but it is not a rule of the game,
 * and `isSolved` accepts such a pipe. Pruning it here would let a board through
 * the uniqueness gate that a player can still finish two ways, which is the
 * exact thing the gate exists to stop. So this counts every legal filling and
 * leans on the four proofs above, which on a 7×7 are more than fast enough.
 */
export function findSolutions(puzzle: FlowPuzzle, limit = 2): number[][][] {
  if (!wellFormed(puzzle)) return [];
  const n = puzzle.size;
  const total = n * n;
  const colours = puzzle.endpoints.length;

  const around: number[][] = [];
  for (let c = 0; c < total; c++) around.push(neighbours(c, n));

  const owner = new Int16Array(total).fill(-1);
  const heads = new Int32Array(colours);
  const targets = new Int32Array(colours);
  const done = new Uint8Array(colours);
  const pipes: number[][] = [];
  for (let k = 0; k < colours; k++) {
    const [a, b] = puzzle.endpoints[k];
    owner[a] = k;
    owner[b] = k;
    heads[k] = a;
    targets[k] = b;
    pipes.push([a]);
  }
  let filled = colours * 2;
  let unfinished = colours;

  // Scratch for the region check, reused across every node.
  const label = new Int32Array(total);
  const stack = new Int32Array(total);
  const regionOk = new Uint8Array(total);
  const stampHead = new Int32Array(total);
  let stamp = 0;

  const found: number[][][] = [];

  /** Whether the board can still be completed, as far as the proofs can tell. */
  const feasible = (): boolean => {
    // Dead cells. A neighbour is a usable connection when it is empty, or it
    // is the live end of an unfinished pipe — its head or its second dot.
    for (let c = 0; c < total; c++) {
      if (owner[c] >= 0) continue;
      let ways = 0;
      for (const x of around[c]) {
        const o = owner[x];
        if (o < 0) ways++;
        else if (!done[o] && (heads[o] === x || targets[o] === x)) ways++;
      }
      if (ways < 2) return false;
    }

    // Label the empty regions.
    label.fill(-1);
    let regions = 0;
    for (let c = 0; c < total; c++) {
      if (owner[c] >= 0 || label[c] >= 0) continue;
      let top = 0;
      stack[top++] = c;
      label[c] = regions;
      while (top > 0) {
        const at = stack[--top];
        for (const x of around[at]) {
          if (owner[x] < 0 && label[x] < 0) {
            label[x] = regions;
            stack[top++] = x;
          }
        }
      }
      regionOk[regions] = 0;
      regions++;
    }

    // Stranded colours, and which regions some colour can pass through.
    for (let k = 0; k < colours; k++) {
      if (done[k]) continue;
      stamp++;
      let touching = false;
      for (const x of around[heads[k]]) {
        if (x === targets[k]) touching = true;
        else if (owner[x] < 0) stampHead[label[x]] = stamp;
      }
      let reachable = touching;
      for (const x of around[targets[k]]) {
        if (owner[x] < 0 && stampHead[label[x]] === stamp) {
          reachable = true;
          regionOk[label[x]] = 1;
        }
      }
      if (!reachable) return false;
    }
    for (let r = 0; r < regions; r++) if (!regionOk[r]) return false;
    return true;
  };

  const rec = (): void => {
    if (found.length >= limit) return;
    if (unfinished === 0) {
      if (filled === total) found.push(pipes.map((p) => p.slice()));
      return;
    }
    if (!feasible()) return;

    // The colour with the fewest ways forward.
    let pick = -1;
    let best = 5;
    for (let k = 0; k < colours; k++) {
      if (done[k]) continue;
      let moves = 0;
      for (const x of around[heads[k]]) {
        if (owner[x] < 0 || x === targets[k]) moves++;
      }
      if (moves < best) {
        best = moves;
        pick = k;
        if (moves <= 1) break;
      }
    }
    if (best === 0) return;

    const k = pick;
    const from = heads[k];
    for (const x of around[from]) {
      if (x === targets[k]) {
        done[k] = 1;
        unfinished--;
        pipes[k].push(x);
        rec();
        pipes[k].pop();
        unfinished++;
        done[k] = 0;
      } else if (owner[x] < 0) {
        owner[x] = k;
        heads[k] = x;
        filled++;
        pipes[k].push(x);
        rec();
        pipes[k].pop();
        filled--;
        heads[k] = from;
        owner[x] = -1;
      }
      if (found.length >= limit) return;
    }
  };

  rec();
  return found;
}

/** How many fillings the board has, counted no further than [limit]. */
export function countSolutions(puzzle: FlowPuzzle, limit = 2): number {
  return findSolutions(puzzle, limit).length;
}

/** The board's pipes, one per colour, or null if it has no filling. */
function solvedPipes(puzzle: FlowPuzzle): number[][] | null {
  const found = findSolutions(puzzle, 1);
  return found.length > 0 ? found[0] : null;
}

/**
 * The answer in submission shape — every pipe in colour order, concatenated —
 * or an empty list for a board with no filling at all.
 */
export function solve(puzzle: FlowPuzzle): number[] {
  const pipes = solvedPipes(puzzle);
  return pipes ? pipes.flat() : [];
}

/**
 * Whether [solution] is a complete, legal filling of [puzzle].
 *
 * The authority on winning. Re-derives the rules rather than comparing against
 * `solve()`, for the same reason as Queens: a finished, legal board must never
 * be rejected, even if a future generator change ever let a second filling
 * through the gate.
 *
 * Walks the flat list pipe by pipe: pipe k must start on its first dot, move
 * one orthogonal step at a time through cells nobody has used and that are not
 * some other colour's dot, and stop on its second dot. Then the next pipe
 * starts on the very next entry. The list must end exactly when the last pipe
 * does, and by then every cell has been used once.
 */
export function isSolved(puzzle: FlowPuzzle, solution: number[]): boolean {
  if (!wellFormed(puzzle) || !Array.isArray(solution)) return false;
  const n = puzzle.size;
  const total = n * n;
  if (solution.length !== total) return false;

  const dotOf = new Int16Array(total).fill(-1);
  puzzle.endpoints.forEach(([a, b], k) => {
    dotOf[a] = k;
    dotOf[b] = k;
  });
  const used = new Uint8Array(total);

  let at = 0;
  for (let k = 0; k < puzzle.endpoints.length; k++) {
    const [a, b] = puzzle.endpoints[k];
    if (solution[at] !== a) return false;
    used[a] = 1;
    let prev = a;
    at++;
    for (;;) {
      if (at >= total) return false;
      const cell = solution[at];
      if (!Number.isInteger(cell) || cell < 0 || cell >= total) return false;
      if (used[cell]) return false;
      if (!isAdjacent(prev, cell, n)) return false;
      if (dotOf[cell] >= 0 && dotOf[cell] !== k) return false;
      used[cell] = 1;
      prev = cell;
      at++;
      if (cell === b) break;
    }
  }
  return at === total;
}

/**
 * One whole pipe the player does not already have right.
 *
 * Flow's natural unit of help is a pipe, not a cell: "this square is red" on
 * its own still leaves the player to find the route through it, whereas a
 * drawn pipe is something they can build around. The hint is therefore
 * `{ index: colour, value: colour, cells: that pipe from dot to dot }`.
 *
 * [progress] is read for "which pipes are already correct" and nothing else,
 * so it does not have to be laid out exactly like a submission: a pipe counts
 * as right if the answer's pipe appears in it as a contiguous run, starting on
 * that colour's first dot. Anything else — missing, partial, a detour — is a
 * candidate, and which one is shown rotates with [seq] so a second hint is a
 * different pipe.
 */
export function hint(
  puzzle: FlowPuzzle,
  progress: number[],
  seq: number
): { index: number; value: number; cells?: number[] } | null {
  const pipes = solvedPipes(puzzle);
  if (!pipes) return null;
  const board = Array.isArray(progress) ? progress : [];

  const pending: number[] = [];
  for (let k = 0; k < pipes.length; k++) {
    const pipe = pipes[k];
    const start = board.indexOf(pipe[0]);
    let right = start >= 0 && start + pipe.length <= board.length;
    for (let i = 0; right && i < pipe.length; i++) {
      if (board[start + i] !== pipe[i]) right = false;
    }
    if (!right) pending.push(k);
  }
  if (pending.length === 0) return null;

  const turn = Number.isInteger(seq) && seq > 0 ? seq : 0;
  const k = pending[turn % pending.length];
  return { index: k, value: k, cells: pipes[k].slice() };
}

/**
 * Every way of cutting [path] into [pieces] pipes, sampled uniformly.
 *
 * A cut is legal when every pipe is MIN_PIPE..MAX_PIPE cells long and **no pipe
 * touches itself** — no two of its cells sit side by side unless they are
 * consecutive along it. A self-touching pipe is a pipe with a shortcut: the
 * player can take the short way, and the cells it skipped are then either
 * fillable by a neighbour (a second solution) or a dead end the player only
 * discovers late. Neither is a puzzle anyone enjoys.
 *
 * Counted by a small dynamic program (cuts from position i onward into k
 * pieces) rather than by trial cuts, so a path that *can* be cut is never
 * thrown away because a random cut happened to land badly, and one that cannot
 * is known immediately.
 */
function sampleCut(
  rand: () => number,
  path: number[],
  n: number,
  pieces: number
): Array<[number, number]> | null {
  const len = path.length;
  // latest[q] — the furthest-right p ≤ q - 2 whose cell touches path[q]. A
  // segment starting at i contains a self-touch at q iff latest[q] >= i.
  const latest = new Int32Array(len).fill(-1);
  for (let q = 0; q < len; q++) {
    for (let p = q - 2; p >= 0; p--) {
      if (isAdjacent(path[p], path[q], n)) {
        latest[q] = p;
        break;
      }
    }
  }
  // ends[i] — every j such that path[i..j] is a legal pipe.
  const ends: number[][] = [];
  for (let i = 0; i < len; i++) {
    const out: number[] = [];
    for (let j = i + 1; j < len && j - i + 1 <= MAX_PIPE; j++) {
      if (latest[j] >= i) break;
      if (j - i + 1 >= MIN_PIPE) out.push(j);
    }
    ends.push(out);
  }

  // ways[k][i] — ways to cut path[i..] into exactly k legal pipes.
  const ways: number[][] = [];
  for (let k = 0; k <= pieces; k++) ways.push(new Array<number>(len + 1).fill(0));
  ways[0][len] = 1;
  for (let k = 1; k <= pieces; k++) {
    for (let i = len - 1; i >= 0; i--) {
      let sum = 0;
      for (const j of ends[i]) sum += ways[k - 1][j + 1];
      ways[k][i] = sum;
    }
  }
  if (ways[pieces][0] === 0) return null;

  const out: Array<[number, number]> = [];
  let i = 0;
  for (let k = pieces; k > 0; k--) {
    let roll = rand() * ways[k][i];
    let pick = ends[i][ends[i].length - 1];
    for (const j of ends[i]) {
      roll -= ways[k - 1][j + 1];
      if (roll < 0) {
        pick = j;
        break;
      }
    }
    out.push([i, pick]);
    i = pick + 1;
  }
  return out;
}

/**
 * A hand-checked board for the day the generator cannot produce one.
 *
 * Generated once from the key `2020-02-29` and frozen. Unreachable in the
 * measured range (see `flow.test.ts`), but a generator that
 * can come back empty-handed is a daily that can be blank, and this runs inside
 * a subscribed query. The test suite proves this board's filling is unique, so
 * the fallback is never a worse puzzle, only a repeated one.
 */
export const FALLBACK: FlowPuzzle = {
  size: SIZE,
  difficulty: "easy",
  endpoints: [
    [42, 23], [39, 30], [24, 37], [1, 4], [0, 6], [35, 13], [40, 32],
  ],
};

/**
 * Today's board.
 *
 * Draws one route through every cell (the same Warnsdorff search as Zip), cuts
 * it into six or seven pipes, and asks the counting solver whether the dots
 * alone pin that cutting down. Most cuttings of a route are ambiguous — two
 * neighbouring pipes can often trade a corner — so each route is given several
 * different cuttings before a fresh route is drawn. Both loops are bounded:
 * this runs inside a subscribed query, and a generator that can spin forever is
 * one that can take the daily offline on one unlucky day key.
 *
 * Colours are shuffled and each pipe randomly reversed before the check, so
 * colour 0 is not always the pipe that starts top-left and the first dot is
 * not always the end the route happened to visit first.
 */
export function generate(dayKey: string): FlowPuzzle {
  for (let attempt = 0; attempt < 30; attempt++) {
    const rand = randomFor(dayKey, "flow", attempt);
    const path = hamiltonianPath(rand, SIZE, 20000);
    if (!path) continue;

    for (let cut = 0; cut < 8; cut++) {
      let pieces = MIN_PAIRS + Math.floor(rand() * (MAX_PAIRS - MIN_PAIRS + 1));
      let segments = sampleCut(rand, path, SIZE, pieces);
      if (!segments) {
        pieces = pieces === MIN_PAIRS ? MAX_PAIRS : MIN_PAIRS;
        segments = sampleCut(rand, path, SIZE, pieces);
      }
      if (!segments) break;

      const endpoints = shuffle(
        segments.map(([i, j]): [number, number] =>
          rand() < 0.5 ? [path[i], path[j]] : [path[j], path[i]]
        ),
        rand
      );
      const puzzle: FlowPuzzle = { size: SIZE, difficulty: "easy", endpoints };
      if (countSolutions(puzzle, 2) === 1) return puzzle;
    }
  }
  return { ...FALLBACK, endpoints: FALLBACK.endpoints.map((p) => [p[0], p[1]]) };
}
