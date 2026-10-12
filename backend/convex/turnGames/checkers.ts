/**
 * Checkers — English draughts / American checkers, two seats.
 *
 * Mirrored move for move in `lib/turn_games/checkers.dart`; both replay
 * `test/fixtures/turn_games/checkers.json`.
 *
 * The board is the 32 dark squares in PDN order. Square 1 is on row 0, and
 * dark (seat 0) starts on 1–12 and moves toward 32, so the PDN a player has
 * seen in a book ("11-15", "22x15x8") is exactly the wire token. A whole
 * multi-jump is ONE move: the server never has to hold a half-finished
 * capture, and a client can never leave one hanging.
 *
 * Rules, all of them the tournament ones:
 *   - men step diagonally forward; kings step one square any diagonal way
 *     (no flying kings);
 *   - a capture is mandatory and must be jumped to the end, but any capture
 *     sequence may be chosen (no majority rule);
 *   - reaching the far row crowns the man and ends the move, even mid-jump;
 *   - the side to move with no legal move loses;
 *   - draws: threefold repetition, or 40 moves each (80 plies) with no
 *     capture and no man move.
 *
 * During a jump the jumped pieces stay on the board as obstacles until the
 * move ends, so no piece is jumped twice, while the jumping piece's own start
 * square is free (a king may loop back onto it).
 */

import { illegal, TurnOutcome, TurnRules } from "./types";

/** One char per square: `.` empty, `b`/`B` dark man/king, `w`/`W` light. */
export type CheckersState = {
  /** 32 chars, index 0 is PDN square 1. */
  board: string[];
  /** Seat to move: 0 dark, 1 light. */
  turn: number;
  /** Plies since the last capture or man move. 80 is a draw. */
  quiet: number;
  /**
   * One entry per position since the last irreversible move, the current one
   * last (so always `quiet + 1` entries). Between irreversible moves the men
   * cannot move and nothing is captured, so a position differs from another in
   * the window only by where the kings stand — an entry is just the king
   * squares (dark's sorted, then light's), one base-32 char each. That keeps a
   * long king shuffle to a few hundred bytes and the repetition check exact.
   * The side to move alternates every ply, so it is implied by the index.
   */
  history: string[];
};

/** Plies with no capture and no man move before the game is drawn. */
export const QUIET_LIMIT = 80;

const SQUARE_CHARS = "0123456789abcdefghijklmnopqrstuv";

/** Diagonal steps, ordered so neighbours come out in ascending square order. */
const DIRS: ReadonlyArray<readonly [number, number]> = [
  [-1, -1],
  [-1, 1],
  [1, -1],
  [1, 1],
];

function rowOf(i: number): number {
  return i >> 2;
}

function colOf(i: number): number {
  const r = i >> 2;
  const k = i & 3;
  return r % 2 === 0 ? 2 * k + 1 : 2 * k;
}

/** The square index at (row, col), or -1 off the board or on a light square. */
function indexAt(r: number, c: number): number {
  if (r < 0 || r > 7 || c < 0 || c > 7) return -1;
  if ((r + c) % 2 === 0) return -1;
  return r * 4 + (c >> 1);
}

/** `STEP[i][d]` is the neighbour in direction d, -1 when off the board. */
const STEP: number[][] = [];
/** `JUMP[i][d]` is the landing square two steps away, or -1. */
const JUMP: number[][] = [];
for (let i = 0; i < 32; i++) {
  const r = rowOf(i);
  const c = colOf(i);
  STEP.push(DIRS.map(([dr, dc]) => indexAt(r + dr, c + dc)));
  JUMP.push(DIRS.map(([dr, dc]) => indexAt(r + 2 * dr, c + 2 * dc)));
}

function sideOf(p: string): number {
  if (p === "b" || p === "B") return 0;
  if (p === "w" || p === "W") return 1;
  return -1;
}

function isKing(p: string): boolean {
  return p === "B" || p === "W";
}

/** Direction indices a piece may move in: dark men down, light men up. */
function dirsFor(p: string): number[] {
  if (isKing(p)) return [0, 1, 2, 3];
  return sideOf(p) === 0 ? [2, 3] : [0, 1];
}

function crownRow(side: number): number {
  return side === 0 ? 7 : 0;
}

/** A move with its geometry, before it is flattened to a PDN token. */
type Path = { squares: number[]; captures: number[] };

function token(p: Path): string {
  const sep = p.captures.length > 0 ? "x" : "-";
  return p.squares.map((s) => String(s + 1)).join(sep);
}

/** Every jump sequence for the piece on [from], each run to its end. */
function jumpsFrom(board: string[], from: number): Path[] {
  const piece = board[from];
  const side = sideOf(piece);
  const dirs = dirsFor(piece);
  const out: Path[] = [];
  const squares = [from];
  const captures: number[] = [];
  const work = board.slice();
  work[from] = ".";

  const walk = (at: number) => {
    let extended = false;
    for (const d of dirs) {
      const mid = STEP[at][d];
      const land = JUMP[at][d];
      if (land < 0 || work[land] !== ".") continue;
      if (sideOf(work[mid]) !== 1 - side) continue;
      if (captures.includes(mid)) continue;
      extended = true;
      squares.push(land);
      captures.push(mid);
      // Crowning ends the move, even with another jump on offer.
      if (!isKing(piece) && rowOf(land) === crownRow(side)) {
        out.push({ squares: squares.slice(), captures: captures.slice() });
      } else {
        walk(land);
      }
      squares.pop();
      captures.pop();
    }
    if (!extended && captures.length > 0) {
      out.push({ squares: squares.slice(), captures: captures.slice() });
    }
  };
  walk(from);
  return out;
}

/** Legal moves for [side] on [board], ignoring whose turn it really is. */
function pathsFor(board: string[], side: number): Path[] {
  const jumps: Path[] = [];
  for (let i = 0; i < 32; i++) {
    if (sideOf(board[i]) === side) jumps.push(...jumpsFrom(board, i));
  }
  if (jumps.length > 0) return jumps;
  const steps: Path[] = [];
  for (let i = 0; i < 32; i++) {
    if (sideOf(board[i]) !== side) continue;
    for (const d of dirsFor(board[i])) {
      const to = STEP[i][d];
      if (to >= 0 && board[to] === ".") {
        steps.push({ squares: [i, to], captures: [] });
      }
    }
  }
  return steps;
}

/** The kings-only key for the repetition history. */
function kingKey(board: string[]): string {
  let dark = "";
  let light = "";
  for (let i = 0; i < 32; i++) {
    if (board[i] === "B") dark += SQUARE_CHARS[i];
    else if (board[i] === "W") light += SQUARE_CHARS[i];
  }
  return dark + light;
}

function repetitions(state: CheckersState): number {
  const h = state.history;
  const last = h.length - 1;
  let n = 0;
  // Same side to move means same parity of index.
  for (let i = last; i >= 0; i -= 2) {
    if (h[i] === h[last]) n++;
  }
  return n;
}

function initialBoard(): string[] {
  const board: string[] = [];
  for (let i = 0; i < 32; i++) board.push(i < 12 ? "b" : i >= 20 ? "w" : ".");
  return board;
}

function outcomeOf(state: CheckersState): TurnOutcome | null {
  if (pathsFor(state.board, state.turn).length === 0) {
    return { winner: 1 - state.turn, reason: "no-moves" };
  }
  if (repetitions(state) >= 3) return { winner: null, reason: "repetition" };
  if (state.quiet >= QUIET_LIMIT) {
    return { winner: null, reason: "move-limit" };
  }
  return null;
}

function bad(): never {
  throw new Error("BAD_STATE");
}

export const rules: TurnRules<CheckersState> = {
  id: "checkers",
  minSeats: 2,
  maxSeats: 2,

  initial(seats) {
    if (seats !== 2) illegal();
    const board = initialBoard();
    return { board, turn: 0, quiet: 0, history: [kingKey(board)] };
  },

  toMove(state) {
    return state.turn;
  },

  legalMoves(state) {
    if (outcomeOf(state) !== null) return [];
    return pathsFor(state.board, state.turn).map(token);
  },

  apply(state, move) {
    if (outcomeOf(state) !== null) illegal();
    const path = pathsFor(state.board, state.turn).find(
      (p) => token(p) === move,
    );
    if (!path) illegal();
    const board = state.board.slice();
    const from = path.squares[0];
    const to = path.squares[path.squares.length - 1];
    let piece = board[from];
    board[from] = ".";
    for (const c of path.captures) board[c] = ".";
    const wasMan = !isKing(piece);
    if (wasMan && rowOf(to) === crownRow(state.turn)) {
      piece = piece.toUpperCase();
    }
    board[to] = piece;
    const key = kingKey(board);
    const irreversible = wasMan || path.captures.length > 0;
    return {
      board,
      turn: 1 - state.turn,
      quiet: irreversible ? 0 : state.quiet + 1,
      history: irreversible ? [key] : [...state.history, key],
    };
  },

  outcome: outcomeOf,

  encode(state) {
    return [
      state.board.join(""),
      String(state.turn),
      String(state.quiet),
      state.history.join(""),
    ].join("|");
  },

  decode(raw) {
    const parts = raw.split("|");
    if (parts.length !== 4) bad();
    const [b, t, q, h] = parts;
    if (!/^[.bBwW]{32}$/.test(b)) bad();
    if (t !== "0" && t !== "1") bad();
    if (!/^(0|[1-9][0-9]?)$/.test(q)) bad();
    const quiet = Number(q);
    if (quiet > QUIET_LIMIT) bad();
    const board = b.split("");
    for (let i = 0; i < 4; i++) if (board[i] === "w") bad();
    for (let i = 28; i < 32; i++) if (board[i] === "b") bad();
    const key = kingKey(board);
    const k = key.length;
    if (k === 0 ? quiet !== 0 || h !== "" : h.length !== (quiet + 1) * k) bad();
    const history: string[] = [];
    if (k === 0) {
      history.push("");
    } else {
      const darkKings = board.filter((p) => p === "B").length;
      for (let i = 0; i < h.length; i += k) {
        const entry = h.slice(i, i + k);
        // Each half must be strictly ascending squares, as kingKey writes them.
        for (let j = 0; j < k; j++) {
          const v = SQUARE_CHARS.indexOf(entry[j]);
          if (v < 0) bad();
          if (j !== 0 && j !== darkKings) {
            if (SQUARE_CHARS.indexOf(entry[j - 1]) >= v) bad();
          }
        }
        history.push(entry);
      }
      if (history[history.length - 1] !== key) bad();
    }
    return { board, turn: Number(t), quiet, history };
  },
};
