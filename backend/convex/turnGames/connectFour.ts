/**
 * Connect Four: 7 columns by 6 rows, seat 0 (`X`) opens.
 *
 * The wire state is the 42 cells row-major with row 0 at the TOP (`X`, `O` or
 * `.`), a slash, and the seat to move. A move is the column, `"0"`..`"6"`, and
 * the disc falls to the lowest empty row. A full board with no four is a draw.
 *
 * Plain strings and arrays on purpose, not the usual 64-bit bitboards: the
 * Dart mirror also runs on Flutter web, where bitwise operators are 32-bit,
 * and the two mirrors are only worth having while they are line-for-line the
 * same algorithm.
 *
 * Mirrored in `lib/turn_games/connect_four.dart`; both replay
 * `test/fixtures/turn_games/connectfour.json`.
 */

import { illegal, type TurnOutcome, type TurnRules } from "./types";

export const COLS = 7;
export const ROWS = 6;

export type ConnectFourState = {
  /** 42 chars, row-major, row 0 at the top. */
  cells: string;
  turn: number;
};

const MARKS = ["X", "O"];

/** Every window of four cells, as start cell + step. Built once. */
export const WINDOWS: readonly (readonly number[])[] = (() => {
  const out: number[][] = [];
  const dirs = [
    [0, 1],
    [1, 0],
    [1, 1],
    [1, -1],
  ];
  for (let r = 0; r < ROWS; r++) {
    for (let c = 0; c < COLS; c++) {
      for (const [dr, dc] of dirs) {
        const er = r + 3 * dr;
        const ec = c + 3 * dc;
        if (er < 0 || er >= ROWS || ec < 0 || ec >= COLS) continue;
        out.push([0, 1, 2, 3].map((k) => (r + k * dr) * COLS + c + k * dc));
      }
    }
  }
  return out;
})();

/**
 * Every cell that is part of a four, sorted, for the UI to light up. Empty
 * while nobody has one.
 */
export function winningCells(state: ConnectFourState): number[] {
  const hit = new Set<number>();
  for (const w of WINDOWS) {
    const m = state.cells[w[0]];
    if (m !== "." && w.every((i) => state.cells[i] === m)) {
      for (const i of w) hit.add(i);
    }
  }
  return [...hit].sort((a, b) => a - b);
}

function fourOwner(cells: string): string | null {
  for (const w of WINDOWS) {
    const m = cells[w[0]];
    if (m !== "." && cells[w[1]] === m && cells[w[2]] === m && cells[w[3]] === m) {
      return m;
    }
  }
  return null;
}

function outcome(state: ConnectFourState): TurnOutcome | null {
  const owner = fourOwner(state.cells);
  if (owner) return { winner: owner === "X" ? 0 : 1, reason: "four" };
  // The top row fills last, so it alone says whether the board is full.
  if (!state.cells.slice(0, COLS).includes(".")) {
    return { winner: null, reason: "full" };
  }
  return null;
}

function legalMoves(state: ConnectFourState): string[] {
  if (outcome(state)) return [];
  const out: string[] = [];
  for (let c = 0; c < COLS; c++) if (state.cells[c] === ".") out.push(String(c));
  return out;
}

export const rules: TurnRules<ConnectFourState> = {
  id: "connectfour",
  minSeats: 2,
  maxSeats: 2,

  initial: () => ({ cells: ".".repeat(COLS * ROWS), turn: 0 }),

  toMove: (state) => state.turn,

  legalMoves,

  apply(state, move) {
    if (!legalMoves(state).includes(move)) illegal();
    const c = Number(move);
    let r = ROWS - 1;
    while (state.cells[r * COLS + c] !== ".") r--;
    const i = r * COLS + c;
    return {
      cells:
        state.cells.slice(0, i) + MARKS[state.turn] + state.cells.slice(i + 1),
      turn: 1 - state.turn,
    };
  },

  outcome,

  encode: (state) => `${state.cells}/${state.turn}`,

  decode(raw) {
    const n = COLS * ROWS;
    if (raw.length !== n + 2 || !/^[XO.]+\/[01]$/.test(raw)) {
      throw new Error("BAD_STATE");
    }
    const cells = raw.slice(0, n);
    const turn = Number(raw[n + 1]);
    let x = 0;
    let o = 0;
    for (let i = 0; i < n; i++) {
      const m = cells[i];
      if (m === "X") x++;
      else if (m === "O") o++;
      // Nothing floats: a disc's cell below must be filled too.
      if (m !== "." && i + COLS < n && cells[i + COLS] === ".") {
        throw new Error("BAD_STATE");
      }
    }
    if (x !== o + turn) throw new Error("BAD_STATE");
    // Only the side that just moved can own a four.
    const owner = fourOwner(cells);
    if (owner && owner !== MARKS[1 - turn]) throw new Error("BAD_STATE");
    if (owner) {
      const other = MARKS[turn];
      for (const w of WINDOWS) {
        if (w.every((i) => cells[i] === other)) throw new Error("BAD_STATE");
      }
    }
    return { cells, turn };
  },
};
