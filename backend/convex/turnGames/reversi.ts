/**
 * Reversi (Othello rules): 8×8, seat 0 is black and opens from the standard
 * crossed centre.
 *
 * The wire state is the 64 cells row-major (`B`, `W` or `.`), a slash, the
 * seat to move, and a trailing `p` when the OTHER seat just had to pass:
 * `"…/0"`, or `"…/0p"` for "white had no move, black again". A move is the
 * cell index, `"0"`..`"63"`, and must flip at least one disc.
 *
 * Passes are never sent. When the side that would move next has nothing
 * legal but the side that just moved does, [apply] hands the turn straight
 * back and sets the flag so the UI can say who was skipped. When neither side
 * can move the game is over, and most discs wins.
 *
 * Mirrored in `lib/turn_games/reversi.dart`; both replay
 * `test/fixtures/turn_games/reversi.json`.
 */

import { illegal, type TurnOutcome, type TurnRules } from "./types";

export const SIZE = 8;

export type ReversiState = {
  /** 64 chars, row-major: `B` (seat 0), `W` (seat 1) or `.`. */
  cells: string;
  toMove: number;
  /** The seat that is not [toMove] had no legal move and was skipped. */
  passed: boolean;
};

const DISCS = ["B", "W"];

const DIRS: readonly (readonly [number, number])[] = [
  [-1, -1],
  [-1, 0],
  [-1, 1],
  [0, -1],
  [0, 1],
  [1, -1],
  [1, 0],
  [1, 1],
];

/** The cells [seat] would flip by playing [cell]; empty when it is illegal. */
export function flipsFor(cells: string, seat: number, cell: number): number[] {
  if (cells[cell] !== ".") return [];
  const mine = DISCS[seat];
  const theirs = DISCS[1 - seat];
  const r0 = Math.floor(cell / SIZE);
  const c0 = cell % SIZE;
  const out: number[] = [];
  for (const [dr, dc] of DIRS) {
    let r = r0 + dr;
    let c = c0 + dc;
    const run: number[] = [];
    while (r >= 0 && r < SIZE && c >= 0 && c < SIZE) {
      const v = cells[r * SIZE + c];
      if (v !== theirs) {
        if (v === mine && run.length > 0) out.push(...run);
        break;
      }
      run.push(r * SIZE + c);
      r += dr;
      c += dc;
    }
  }
  return out;
}

/** Every cell [seat] could play, ascending. */
export function movesFor(cells: string, seat: number): number[] {
  const out: number[] = [];
  for (let i = 0; i < SIZE * SIZE; i++) {
    if (flipsFor(cells, seat, i).length > 0) out.push(i);
  }
  return out;
}

/** `[black, white]` disc counts. */
export function discCounts(state: ReversiState): [number, number] {
  let b = 0;
  let w = 0;
  for (const v of state.cells) {
    if (v === "B") b++;
    else if (v === "W") w++;
  }
  return [b, w];
}

/** The seat that was skipped to reach this position, if one was. */
export function passedSeat(state: ReversiState): number | null {
  return state.passed ? 1 - state.toMove : null;
}

function outcome(state: ReversiState): TurnOutcome | null {
  if (movesFor(state.cells, state.toMove).length > 0) return null;
  // [apply] never leaves the mover stuck while the other side can play, so a
  // mover with nothing means nobody has anything.
  const [b, w] = discCounts(state);
  return { winner: b === w ? null : b > w ? 0 : 1, reason: "discs" };
}

export const rules: TurnRules<ReversiState> = {
  id: "reversi",
  minSeats: 2,
  maxSeats: 2,

  initial() {
    const cells = ".".repeat(64).split("");
    cells[27] = "W";
    cells[28] = "B";
    cells[35] = "B";
    cells[36] = "W";
    return { cells: cells.join(""), toMove: 0, passed: false };
  },

  toMove: (state) => state.toMove,

  legalMoves: (state) => movesFor(state.cells, state.toMove).map(String),

  apply(state, move) {
    if (!/^\d{1,2}$/.test(move)) illegal();
    const cell = Number(move);
    if (cell >= 64 || String(cell) !== move) illegal();
    const flips = flipsFor(state.cells, state.toMove, cell);
    if (flips.length === 0) illegal();
    const next = state.cells.split("");
    const mine = DISCS[state.toMove];
    next[cell] = mine;
    for (const i of flips) next[i] = mine;
    const cells = next.join("");
    const other = 1 - state.toMove;
    if (movesFor(cells, other).length > 0) {
      return { cells, toMove: other, passed: false };
    }
    if (movesFor(cells, state.toMove).length > 0) {
      return { cells, toMove: state.toMove, passed: true };
    }
    // Neither side can move: over. The turn passes as usual so the final
    // position reads the same as any other.
    return { cells, toMove: other, passed: false };
  },

  outcome,

  encode: (state) =>
    `${state.cells}/${state.toMove}${state.passed ? "p" : ""}`,

  decode(raw) {
    if (!/^[BW.]{64}\/[01]p?$/.test(raw)) throw new Error("BAD_STATE");
    const cells = raw.slice(0, 64);
    const toMove = Number(raw[65]);
    const passed = raw.length === 67;
    // The four centre squares start filled and discs are never removed.
    for (const i of [27, 28, 35, 36]) {
      if (cells[i] === ".") throw new Error("BAD_STATE");
    }
    const mover = movesFor(cells, toMove).length > 0;
    const other = movesFor(cells, 1 - toMove).length > 0;
    // [apply] would have passed for a stuck mover, and only flags a pass
    // that really happened (and never on a finished game).
    if (!mover && other) throw new Error("BAD_STATE");
    if (passed && (other || !mover)) throw new Error("BAD_STATE");
    return { cells, toMove, passed };
  },
};
