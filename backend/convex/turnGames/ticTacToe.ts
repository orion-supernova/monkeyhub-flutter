/**
 * Tic-tac-toe, the smallest game on the [TurnRules] contract.
 *
 * Seat 0 is X and always opens. The wire state is the nine cells row-major
 * (`X`, `O` or `.`), a slash, and the seat to move: `"X.O....../1"`. The turn
 * is derivable from the counts, and is carried anyway so every game's state
 * reads the same way and so [decode] can refuse a string whose two halves
 * disagree. A move is the cell index, `"0"`..`"8"`.
 *
 * Mirrored in `lib/turn_games/tic_tac_toe.dart`; both replay
 * `test/fixtures/turn_games/tictactoe.json`.
 */

import { illegal, type TurnOutcome, type TurnRules } from "./types";

export type TicTacToeState = {
  /** Nine chars, row-major: `X`, `O` or `.`. */
  cells: string;
  /** 0 for X, 1 for O. */
  turn: number;
};

/** Every three-in-a-row, rows then columns then diagonals. */
export const LINES: readonly (readonly [number, number, number])[] = [
  [0, 1, 2],
  [3, 4, 5],
  [6, 7, 8],
  [0, 3, 6],
  [1, 4, 7],
  [2, 5, 8],
  [0, 4, 8],
  [2, 4, 6],
];

const MARKS = ["X", "O"];

/** The first completed line, for the UI to strike through. */
export function winningLine(state: TicTacToeState): number[] | null {
  for (const [a, b, c] of LINES) {
    const m = state.cells[a];
    if (m !== "." && m === state.cells[b] && m === state.cells[c]) {
      return [a, b, c];
    }
  }
  return null;
}

function outcome(state: TicTacToeState): TurnOutcome | null {
  const line = winningLine(state);
  if (line) {
    return { winner: state.cells[line[0]] === "X" ? 0 : 1, reason: "line" };
  }
  if (!state.cells.includes(".")) return { winner: null, reason: "full" };
  return null;
}

function legalMoves(state: TicTacToeState): string[] {
  if (outcome(state)) return [];
  const out: string[] = [];
  for (let i = 0; i < 9; i++) if (state.cells[i] === ".") out.push(String(i));
  return out;
}

function count(cells: string, mark: string): number {
  let n = 0;
  for (const c of cells) if (c === mark) n++;
  return n;
}

export const rules: TurnRules<TicTacToeState> = {
  id: "tictactoe",
  minSeats: 2,
  maxSeats: 2,

  initial: () => ({ cells: ".........", turn: 0 }),

  toMove: (state) => state.turn,

  legalMoves,

  apply(state, move) {
    if (!legalMoves(state).includes(move)) illegal();
    const i = Number(move);
    return {
      cells:
        state.cells.slice(0, i) + MARKS[state.turn] + state.cells.slice(i + 1),
      turn: 1 - state.turn,
    };
  },

  outcome,

  encode: (state) => `${state.cells}/${state.turn}`,

  decode(raw) {
    if (!/^[XO.]{9}\/[01]$/.test(raw)) throw new Error("BAD_STATE");
    const state = { cells: raw.slice(0, 9), turn: Number(raw[10]) };
    const x = count(state.cells, "X");
    const o = count(state.cells, "O");
    // X opens, so X is level with O (X to move) or one ahead (O to move).
    if (x !== o + state.turn) throw new Error("BAD_STATE");
    // Play stops at the first line, so only the side that just moved can own
    // one (possibly two, closed by the same mark).
    let xLine = false;
    let oLine = false;
    for (const [a, b, c] of LINES) {
      const m = state.cells[a];
      if (m !== "." && m === state.cells[b] && m === state.cells[c]) {
        if (m === "X") xLine = true;
        else oLine = true;
      }
    }
    if (xLine && (oLine || state.turn !== 1)) throw new Error("BAD_STATE");
    if (oLine && state.turn !== 0) throw new Error("BAD_STATE");
    return state;
  },
};
