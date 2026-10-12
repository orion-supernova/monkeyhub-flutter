/**
 * MINESWEEPER, no-guess edition — a 9×9 field with twelve mines, where every
 * cell can be worked out by logic from the opening alone.
 *
 * Digits and flags only, so the board is identical in all twelve languages —
 * see `queens.ts` for why that decided the shortlist.
 *
 * ## Why "no guess" is the whole design
 *
 * Classic minesweeper ends a fair share of games on a coin flip: two cells,
 * one mine, nothing on the board to tell them apart. That is tolerable when
 * the next board is one click away. It is not tolerable in a daily that ranks
 * friends by time, where one player's run dies on a 50/50 the other happened to
 * win — the standings would be measuring luck. So the generator only ships
 * boards that a deterministic solver clears from the start cell without ever
 * guessing; and a board that can be cleared by pure deduction is necessarily
 * unique, since every cell was forced.
 *
 * ## Why the start is chosen for the player
 *
 * In the desktop game the first click is free because the mines are placed
 * after it. Here the board is fixed per day and the same for everyone, so it
 * ships a `start` cell instead: a guaranteed 0 with no mine anywhere in its
 * 3×3, so the first tap always opens a patch to reason from.
 *
 * ## Generation: Simon Tatham's perturbation approach
 *
 * Following the idea in Tatham's Mines (Portable Puzzle Collection, MIT):
 * place mines at random, run the solver from the start, and when it gets stuck,
 * don't throw the board away — move one mine from the stuck frontier to
 * somewhere the solver has not looked at yet, and solve again from scratch.
 * The frontier is where the ambiguity is, and pulling a mine out of it changes
 * the numbers exactly where the solver needed more information. This is a much
 * simpler perturbation than Tatham's (which reasons about which set to move
 * mines into), and at twelve mines on 81 cells it converges almost always —
 * see the fallback rate the tests pin.
 */

import { randomFor, range, shuffle } from "./rng";

/** Board edge. */
export const SIZE = 9;

/** Mines on the board. ~15% density: busy enough to think, never a slog. */
export const MINE_COUNT = 12;

/** `progress` values other than a revealed number 0..8. */
export const HIDDEN = -1;
export const FLAGGED = 9;

export type MinesweeperPuzzle = {
  size: number;
  difficulty: "easy" | "medium" | "hard";
  /** A cell index that is a 0 with no mines in its 3×3 — the first tap. */
  start: number;
  mineCount: number;
  /** The mine set, obfuscated. See [encodeMines] / [decodeMines]. */
  mines: string;
};

const N = SIZE * SIZE;

/** Attempt budget. Bounded so one unlucky day key cannot hang the query. */
const ATTEMPTS = 20;
const PERTURBS_PER_ATTEMPT = 50;

/** The (up to) eight cells around each cell. */
const NEIGHBORS: number[][] = range(N).map((i) => {
  const r = Math.floor(i / SIZE);
  const c = i % SIZE;
  const out: number[] = [];
  for (let dr = -1; dr <= 1; dr++) {
    for (let dc = -1; dc <= 1; dc++) {
      if (dr === 0 && dc === 0) continue;
      const rr = r + dr;
      const cc = c + dc;
      if (rr >= 0 && rr < SIZE && cc >= 0 && cc < SIZE) out.push(rr * SIZE + cc);
    }
  }
  return out;
});

/** Mines adjacent to each cell. */
function numbersOf(mines: ArrayLike<number>): Uint8Array {
  const out = new Uint8Array(N);
  for (let i = 0; i < N; i++) {
    let n = 0;
    for (const nb of NEIGHBORS[i]) n += mines[nb];
    out[i] = n;
  }
  return out;
}

// ---------------------------------------------------------------------------
// Obfuscation
// ---------------------------------------------------------------------------

/**
 * Bytes needed for one bit per cell (11 for 81 cells).
 */
const MASK_BYTES = Math.ceil(N / 8);

/**
 * The XOR keystream for a day: [MASK_BYTES] bytes, each
 * `Math.floor(rand() * 256)` from `randomFor(dayKey, "minesweeper-mask")`
 * (i.e. attempt 0, seed string `"<dayKey>:minesweeper-mask:0"`).
 */
function keystream(dayKey: string): number[] {
  const rand = randomFor(dayKey, "minesweeper-mask");
  const out: number[] = [];
  for (let k = 0; k < MASK_BYTES; k++) out.push(Math.floor(rand() * 256));
  return out;
}

/**
 * The `mines` string: the 0/1 mine map packed one bit per cell, XORed with the
 * day's keystream, as lowercase hex.
 *
 * **This is cosmetic, not security.** The client has to know the whole layout
 * to answer every tap instantly (revealing a number or ending the game without
 * a server round trip on each cell), so the layout is on the device no matter
 * what — and the keystream comes from a seed anyone can recompute. All the
 * mask buys is that the answer is not sitting in plain sight in a network log
 * or a JSON dump, where a curious friend would spot it without even trying.
 *
 * ## Decoding, for the client
 *
 *  1. `seed = fnv1a("<dayKey>:minesweeper-mask:0")` and
 *     `rand = mulberry32(seed)`, exactly as in `rng.ts` (32-bit unsigned
 *     arithmetic; in Dart mask with `& 0xFFFFFFFF` after every multiply/add
 *     and emulate `Math.imul` as a 32-bit wrapping multiply).
 *  2. `key[k] = floor(rand() * 256)` for k in 0..10.
 *  3. `byte[k] = parseInt(mines.substr(2k, 2), 16) ^ key[k]`.
 *  4. Cell `i` (row-major) is a mine iff `(byte[i >> 3] >> (i & 7)) & 1`.
 *
 * Bits past cell 80 in the last byte are padding and must be ignored.
 */
export function encodeMines(mines: ArrayLike<number>, dayKey: string): string {
  const key = keystream(dayKey);
  let hex = "";
  for (let k = 0; k < MASK_BYTES; k++) {
    let byte = 0;
    for (let b = 0; b < 8; b++) {
      const i = k * 8 + b;
      if (i < N && mines[i]) byte |= 1 << b;
    }
    hex += ((byte ^ key[k]) & 0xff).toString(16).padStart(2, "0");
  }
  return hex;
}

/**
 * The mine map (0/1 per cell, row-major) of [puzzle], recovered with the day's
 * keystream. See [encodeMines] for the format. A malformed `mines` string
 * decodes to an all-zero map rather than throwing.
 */
export function decodeMines(puzzle: MinesweeperPuzzle, dayKey: string): number[] {
  const out = new Array<number>(N).fill(0);
  const hex = puzzle?.mines;
  if (typeof hex !== "string" || hex.length !== MASK_BYTES * 2 || !/^[0-9a-f]+$/.test(hex)) {
    return out;
  }
  const key = keystream(dayKey);
  for (let k = 0; k < MASK_BYTES; k++) {
    const byte = parseInt(hex.slice(2 * k, 2 * k + 2), 16) ^ key[k];
    for (let b = 0; b < 8; b++) {
      const i = k * 8 + b;
      if (i < N) out[i] = (byte >> b) & 1;
    }
  }
  return out;
}

// ---------------------------------------------------------------------------
// Solver
// ---------------------------------------------------------------------------

/** What the solver knows about the board. */
export type Knowledge = {
  /** Revealed: the player (or solver) can see this cell's number. */
  revealed: Uint8Array;
  /** Proven to be a mine. */
  mine: Uint8Array;
  /** Proven safe but not revealed (only used when the solver may not reveal). */
  safe: Uint8Array;
};

/**
 * Deduces as far as logic goes, never guessing.
 *
 * Rules, cheapest first, restarting from the top after any progress:
 *
 *  1. **Single cell.** A revealed number whose remaining unknown neighbours
 *     must all be safe (count already met) or all be mines (count equals the
 *     unknowns).
 *  2. **Pairwise subtraction.** For two overlapping constraints A and B: if
 *     A needs exactly as many more mines than B as A has cells B lacks, then
 *     every cell only in A is a mine and every cell only in B is safe. With
 *     A ⊆ B this is the classic subset rule ("B minus A has B−A mines").
 *  3. **Global count**, last, because it is the rule a person reaches for
 *     least: no mines left means every unknown is safe; as many mines left as
 *     unknown cells means they are all mines.
 *
 * [numbers] are only read for revealed cells — the information a player
 * actually has — so the same routine serves the generator (which may reveal
 * what it proves safe, flooding zeros) and the hint (which may not: the
 * player has to tap it).
 *
 * Mutates [k]. Returns nothing; read the result off [k].
 */
function deduce(
  numbers: Uint8Array,
  isMine: ArrayLike<number>,
  mineCount: number,
  k: Knowledge,
  canReveal: boolean
): void {
  const { revealed, mine, safe } = k;

  const reveal = (cell: number): void => {
    // Never reveals a real mine: the solver only calls this on proven-safe
    // cells, and a proof from true numbers cannot be wrong. The check is for a
    // future bug, not a reachable state.
    if (revealed[cell] || isMine[cell]) return;
    const stack = [cell];
    revealed[cell] = 1;
    while (stack.length > 0) {
      const at = stack.pop()!;
      safe[at] = 0;
      if (numbers[at] !== 0) continue;
      for (const nb of NEIGHBORS[at]) {
        if (revealed[nb] || isMine[nb]) continue;
        revealed[nb] = 1;
        stack.push(nb);
      }
    }
  };

  const markSafe = (cell: number): void => {
    if (canReveal) reveal(cell);
    else safe[cell] = 1;
  };

  const isUnknown = (cell: number): boolean =>
    !revealed[cell] && !mine[cell] && !safe[cell];

  // Stamp array for set intersection in the pairwise rule.
  const stamp = new Int32Array(N);
  let stampId = 0;

  // Each productive pass proves at least one of 81 cells, so the bound only
  // matters if a bug stops a pass from making progress.
  for (let guard = 0; guard < 400; guard++) {
    // Rule 1, collecting the constraints rule 2 will need as it goes.
    let progressed = false;
    const sets: number[][] = [];
    const need: number[] = [];
    const center: number[] = [];
    for (let c = 0; c < N; c++) {
      if (!revealed[c]) continue;
      let m = numbers[c];
      const unknown: number[] = [];
      for (const nb of NEIGHBORS[c]) {
        if (mine[nb]) m--;
        else if (isUnknown(nb)) unknown.push(nb);
      }
      if (unknown.length === 0) continue;
      if (m === 0) {
        for (const u of unknown) markSafe(u);
        progressed = true;
      } else if (m === unknown.length) {
        for (const u of unknown) mine[u] = 1;
        progressed = true;
      } else if (!progressed) {
        sets.push(unknown);
        need.push(m);
        center.push(c);
      }
    }
    if (progressed) continue;

    // Rule 2. Only constraints whose centres are within two cells can share a
    // cell, which keeps this from being a full quadratic in practice.
    for (let a = 0; a < sets.length && !progressed; a++) {
      const ra = Math.floor(center[a] / SIZE);
      const ca = center[a] % SIZE;
      for (let b = 0; b < sets.length && !progressed; b++) {
        if (a === b) continue;
        const rb = Math.floor(center[b] / SIZE);
        const cb = center[b] % SIZE;
        if (Math.abs(ra - rb) > 2 || Math.abs(ca - cb) > 2) continue;

        stampId++;
        for (const x of sets[b]) stamp[x] = stampId;
        const onlyA: number[] = [];
        let shared = 0;
        for (const x of sets[a]) {
          if (stamp[x] === stampId) shared++;
          else onlyA.push(x);
        }
        if (shared === 0) continue;
        if (need[a] - need[b] !== onlyA.length) continue;

        stampId++;
        for (const x of sets[a]) stamp[x] = stampId;
        const onlyB = sets[b].filter((x) => stamp[x] !== stampId);
        if (onlyA.length === 0 && onlyB.length === 0) continue;
        for (const x of onlyA) mine[x] = 1;
        for (const x of onlyB) markSafe(x);
        progressed = true;
      }
    }
    if (progressed) continue;

    // Rule 3.
    let minesLeft = mineCount;
    const unknown: number[] = [];
    for (let c = 0; c < N; c++) {
      if (mine[c]) minesLeft--;
      else if (isUnknown(c)) unknown.push(c);
    }
    if (unknown.length > 0 && minesLeft === 0) {
      for (const u of unknown) markSafe(u);
      continue;
    }
    if (unknown.length > 0 && minesLeft === unknown.length) {
      for (const u of unknown) mine[u] = 1;
      continue;
    }
    return;
  }
}

/** A blank slate of [Knowledge]. */
function blank(): Knowledge {
  return { revealed: new Uint8Array(N), mine: new Uint8Array(N), safe: new Uint8Array(N) };
}

/**
 * Plays [mines] from [start] by deduction alone. `cleared` is true when every
 * safe cell ended up revealed — the board needs no guess.
 */
export function playFrom(
  mines: ArrayLike<number>,
  start: number,
  mineCount = MINE_COUNT
): { cleared: boolean; knowledge: Knowledge } {
  const numbers = numbersOf(mines);
  const k = blank();
  if (mines[start] || numbers[start] !== 0) return { cleared: false, knowledge: k };
  // The first tap: the start is safe by promise, not by proof, so it is
  // opened here (flooding its zeros, as the client does) and the rules take
  // over from what it reveals.
  k.revealed[start] = 1;
  const stack = [start];
  while (stack.length > 0) {
    const at = stack.pop()!;
    if (numbers[at] !== 0) continue;
    for (const nb of NEIGHBORS[at]) {
      if (k.revealed[nb] || mines[nb]) continue;
      k.revealed[nb] = 1;
      stack.push(nb);
    }
  }
  deduce(numbers, mines, mineCount, k, true);
  let cleared = true;
  for (let i = 0; i < N; i++) if (!mines[i] && !k.revealed[i]) cleared = false;
  return { cleared, knowledge: k };
}

// ---------------------------------------------------------------------------
// Generation
// ---------------------------------------------------------------------------

/** The start cell's 3×3, which must stay mine-free. */
function startZone(start: number): Set<number> {
  return new Set([start, ...NEIGHBORS[start]]);
}

/**
 * A board shipped if every attempt fails, so the daily never goes dark.
 * `minesweeper.test.ts` pins that it clears from its start without a guess.
 */
const FALLBACK_START = 40;
const FALLBACK_MINES = [17, 21, 24, 35, 43, 44, 51, 54, 60, 69, 72, 76];

/**
 * Today's board with its mine map and how it was reached. `generate` is the
 * public face; this exists for the tests, which pin the fallback rate.
 */
export function generateWithSolution(dayKey: string): {
  puzzle: MinesweeperPuzzle;
  solution: number[];
  attempt: number;
  perturbs: number;
  fallback: boolean;
} {
  for (let attempt = 0; attempt < ATTEMPTS; attempt++) {
    const rand = randomFor(dayKey, "minesweeper", attempt);
    // An interior start, so its 3×3 is a full nine cells and the opening is a
    // proper patch rather than a corner sliver.
    const start = (1 + Math.floor(rand() * (SIZE - 2))) * SIZE + 1 + Math.floor(rand() * (SIZE - 2));
    const zone = startZone(start);
    const mines = new Uint8Array(N);
    for (const i of shuffle(range(N).filter((i) => !zone.has(i)), rand).slice(0, MINE_COUNT)) {
      mines[i] = 1;
    }

    for (let perturb = 0; perturb <= PERTURBS_PER_ATTEMPT; perturb++) {
      const { cleared, knowledge } = playFrom(mines, start);
      if (cleared) {
        const solution = Array.from(mines);
        return {
          puzzle: {
            size: SIZE,
            difficulty: "medium",
            start,
            mineCount: MINE_COUNT,
            mines: encodeMines(solution, dayKey),
          },
          solution,
          attempt,
          perturbs: perturb,
          fallback: false,
        };
      }
      if (perturb === PERTURBS_PER_ATTEMPT) break;

      // The stuck frontier: hidden, unproven cells touching a revealed number.
      const frontier = new Uint8Array(N);
      for (let c = 0; c < N; c++) {
        if (!knowledge.revealed[c]) continue;
        for (const nb of NEIGHBORS[c]) {
          if (!knowledge.revealed[nb] && !knowledge.mine[nb]) frontier[nb] = 1;
        }
      }
      const from: number[] = [];
      const to: number[] = [];
      for (let c = 0; c < N; c++) {
        if (frontier[c] && mines[c]) from.push(c);
        else if (
          !frontier[c] &&
          !mines[c] &&
          !knowledge.revealed[c] &&
          !zone.has(c)
        ) {
          to.push(c);
        }
      }
      // A stuck solver always has an unproven mine on its frontier (if every
      // frontier cell were safe, rule 1 would have fired), so `from` is empty
      // only for a future bug. `to` running dry is common, though: it is the
      // classic end-game 50/50, where the last few hidden cells are all on the
      // frontier and there is nowhere off it to move a mine. Measured at about
      // one first layout in eight; a fresh layout is cheaper than reasoning a
      // way out, and the attempt budget absorbs it (fallback rate stays 0).
      if (from.length === 0 || to.length === 0) break;
      mines[from[Math.floor(rand() * from.length)]] = 0;
      mines[to[Math.floor(rand() * to.length)]] = 1;
    }
  }

  return { ...fallback(dayKey), attempt: ATTEMPTS, perturbs: 0, fallback: true };
}

/** The fallback board and its mine map. Exported for the test that pins it. */
export function fallback(dayKey: string): { puzzle: MinesweeperPuzzle; solution: number[] } {
  const solution = new Array<number>(N).fill(0);
  for (const i of FALLBACK_MINES) solution[i] = 1;
  return {
    puzzle: {
      size: SIZE,
      difficulty: "medium",
      start: FALLBACK_START,
      mineCount: MINE_COUNT,
      mines: encodeMines(solution, dayKey),
    },
    solution,
  };
}

/**
 * Today's board.
 *
 * Place mines away from the start, play the board by deduction, and when the
 * solver stalls, move one frontier mine out of the way and replay from
 * scratch. Bounded at [PERTURBS_PER_ATTEMPT] moves per layout and [ATTEMPTS]
 * layouts, then a hand-checked fallback, because this runs inside a
 * subscribed query.
 */
export function generate(dayKey: string): MinesweeperPuzzle {
  return generateWithSolution(dayKey).puzzle;
}

/** Whether [puzzle] has the shape this module generates. */
function wellFormed(puzzle: MinesweeperPuzzle): boolean {
  return (
    !!puzzle &&
    puzzle.size === SIZE &&
    Number.isInteger(puzzle.start) &&
    puzzle.start >= 0 &&
    puzzle.start < N &&
    Number.isInteger(puzzle.mineCount)
  );
}

/**
 * The answer as a 0/1 mine map per cell, row-major — the shape `submit` takes.
 *
 * **Takes the day key**, unlike the other games' `solve`: the mine set is
 * shipped masked with a keystream seeded by the day, so the day is needed to
 * unmask it. The caller (`games.ts`) always has it.
 */
export function solve(puzzle: MinesweeperPuzzle, dayKey: string): number[] {
  return decodeMines(puzzle, dayKey);
}

/**
 * Whether [cells] is exactly the mine map: 81 entries, each 0 or 1, with the
 * ones precisely on the mines. Strict about shape, never throws.
 *
 * Comparing against the mine set is sound here (unlike Queens' re-derivation)
 * because the board is fixed: there is no "other legal answer" to accept.
 * Takes the day key for the same reason as [solve].
 */
export function isSolved(puzzle: MinesweeperPuzzle, cells: number[], dayKey: string): boolean {
  if (!wellFormed(puzzle)) return false;
  if (!Array.isArray(cells) || cells.length !== N) return false;
  const answer = decodeMines(puzzle, dayKey);
  let mines = 0;
  for (let i = 0; i < N; i++) {
    if (cells[i] !== 0 && cells[i] !== 1) return false;
    if (cells[i] !== answer[i]) return false;
    mines += answer[i];
  }
  // A garbage `mines` string decodes to all zeros; never call an empty
  // submission a win against that.
  return mines === puzzle.mineCount;
}

/**
 * The next thing the player can PROVE from what they can see, with what to do.
 *
 * [progress] is -1 hidden, 0..8 a revealed number, 9 flagged. Only which cells
 * are revealed is trusted — their numbers are re-read off the real layout, and
 * a "revealed" cell that is actually a mine is ignored — and flags are not
 * trusted at all, since a wrong flag is exactly what a stuck player might have.
 *
 * Returns `{ index, value: 0 }` for a provably safe cell to reveal (including
 * one the player wrongly flagged) or `{ index, value: 1 }` for a provable mine
 * not yet flagged. Safe cells come first, because revealing is what moves the
 * board forward; mines only when nothing is left to open. Rotates among the
 * candidates by [seq] so a second hint is a different cell. With nothing
 * revealed, the hint is the start. Null when nothing is provable (a board
 * that is finished, or a malformed request) — never a guess.
 *
 * Takes the day key for the same reason as [solve].
 */
export function hint(
  puzzle: MinesweeperPuzzle,
  progress: number[],
  seq: number,
  dayKey: string
): { index: number; value: number } | null {
  if (!wellFormed(puzzle)) return null;
  const mines = decodeMines(puzzle, dayKey);
  const board = Array.isArray(progress) ? progress : [];
  const numbers = numbersOf(mines);
  const k = blank();
  let anyRevealed = false;
  for (let i = 0; i < N; i++) {
    const v = board[i];
    if (Number.isInteger(v) && v >= 0 && v <= 8 && !mines[i]) {
      k.revealed[i] = 1;
      anyRevealed = true;
    }
  }
  const s = Number.isInteger(seq) && seq >= 0 ? seq : 0;
  if (!anyRevealed) return { index: puzzle.start, value: 0 };

  deduce(numbers, mines, puzzle.mineCount, k, false);

  const safes: number[] = [];
  const flags: number[] = [];
  for (let i = 0; i < N; i++) {
    if (k.revealed[i]) continue;
    if (k.safe[i]) safes.push(i);
    else if (k.mine[i] && board[i] !== FLAGGED) flags.push(i);
  }
  // The start is always provably safe — it was promised.
  if (!k.revealed[puzzle.start] && !safes.includes(puzzle.start) && !mines[puzzle.start]) {
    safes.unshift(puzzle.start);
  }
  if (safes.length > 0) return { index: safes[s % safes.length], value: 0 };
  if (flags.length > 0) return { index: flags[s % flags.length], value: 1 };
  return null;
}
