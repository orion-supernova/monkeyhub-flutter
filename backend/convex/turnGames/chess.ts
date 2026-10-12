/**
 * Chess: standard rules, seat 0 is white and opens.
 *
 * The move generator is chess.js (BSD-2-Clause, pinned to 1.4.0 in
 * package.json). It is pure JavaScript with no Node APIs, so it bundles for
 * Convex's default V8 runtime. Everything chess.js cannot know from a single
 * FEN, which is the repetition history, lives in the state beside it.
 *
 * The wire state is `<FEN>|<history>`:
 *  * FEN exactly as chess.js 1.4.0 writes it. Its en passant field is only
 *    set when a legal en passant capture exists (a pinned pawn does not
 *    count), which is also the FIDE test for "the same position", so the
 *    first four fields are a repetition key as they stand.
 *  * history is one 5-char hash per earlier position since the last capture
 *    or pawn move, oldest first. A capture or a pawn move can never be
 *    undone, so no position from before one can recur, and the FEN's
 *    halfmove clock is exactly how many entries there are. The 50-move rule
 *    ends the game at 100, so the history never passes 500 chars, and in a
 *    normal game it is a few dozen.
 *
 * A move is UCI: `e2e4`, `e1g1` for castling, `e7e8q` for a promotion.
 * Legal moves are sorted as strings, an order the Dart mirror reproduces
 * without chess.js.
 *
 * Mirrored in `lib/turn_games/chess.dart`; both replay
 * `test/fixtures/turn_games/chess.json`.
 */

import { Chess, DEFAULT_POSITION, validateFen } from "chess.js";

import { illegal, type TurnOutcome, type TurnRules } from "./types";

export type ChessState = {
  fen: string;
  /** One [positionHash] per earlier position since the clock last reset. */
  history: string[];
};

/** Halfmove clock at which the game is drawn: 50 moves each, no capture or pawn move. */
export const FIFTY_MOVE_PLIES = 100;

/** Chars per history entry. */
export const HASH_LEN = 5;

const HASH_CHARS =
  "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-_";

/** A prime under 2^30, so a hash fits [HASH_LEN] base-64 chars. */
const HASH_MOD = 1_000_000_007;

const UCI = /^[a-h][1-8][a-h][1-8][qrbn]?$/;

/** The FEN's first four fields: placement, side, castling, en passant. */
export function positionKey(fen: string): string {
  return fen.split(" ").slice(0, 4).join(" ");
}

/**
 * A polynomial string hash of [positionKey], mod a prime, as 5 base-64 chars.
 *
 * Not FNV or anything else that wants 32-bit multiplication: every step here
 * stays under 2^38, so it is exact in a JS double and in Dart on the web,
 * where integers are doubles too. 30 bits is plenty for this: a false draw
 * needs the current position to collide with two of at most 50 same-side
 * entries.
 */
export function positionHash(fen: string): string {
  const key = positionKey(fen);
  let h = 0;
  for (let i = 0; i < key.length; i++) {
    h = (h * 131 + key.charCodeAt(i)) % HASH_MOD;
  }
  let out = "";
  for (let k = 0; k < HASH_LEN; k++) {
    out = HASH_CHARS[h % 64] + out;
    h = Math.floor(h / 64);
  }
  return out;
}

function halfmoves(fen: string): number {
  return Number(fen.split(" ")[4]);
}

/** How many times the current position has stood on the board, this one included. */
export function repetitions(state: ChessState): number {
  const now = positionHash(state.fen);
  let n = 1;
  for (const h of state.history) if (h === now) n++;
  return n;
}

/** Whether the side to move is in check, for the UI's king glow. */
export function inCheck(state: ChessState): boolean {
  return new Chess(state.fen).inCheck();
}

/**
 * Checked in a fixed order, which matters only when two hold at once (a
 * mate on the 100th ply is still a mate), and which the Dart side copies.
 */
function outcomeOf(chess: Chess, state: ChessState): TurnOutcome | null {
  if (chess.moves().length === 0) {
    if (chess.inCheck()) {
      return { winner: chess.turn() === "w" ? 1 : 0, reason: "checkmate" };
    }
    return { winner: null, reason: "stalemate" };
  }
  if (chess.isInsufficientMaterial()) {
    return { winner: null, reason: "insufficient-material" };
  }
  if (halfmoves(state.fen) >= FIFTY_MOVE_PLIES) {
    return { winner: null, reason: "fifty-moves" };
  }
  if (repetitions(state) >= 3) return { winner: null, reason: "repetition" };
  return null;
}

function legalOf(chess: Chess): string[] {
  return chess
    .moves({ verbose: true })
    .map((m) => m.lan)
    .sort();
}

function legalMoves(state: ChessState): string[] {
  const chess = new Chess(state.fen);
  if (outcomeOf(chess, state)) return [];
  return legalOf(chess);
}

/**
 * Whether castling rights and the en passant square agree with the board.
 * chess.js's `load` takes both on trust, and `fen()` echoes them back, so the
 * round trip in [decode] would not catch a king that has a right to castle
 * from the wrong square.
 */
function consistent(chess: Chess, fields: string[]): boolean {
  const at = (sq: string, piece: string) => {
    const p = chess.get(sq as Parameters<Chess["get"]>[0]);
    if (!p) return false;
    return (p.color === "w" ? p.type.toUpperCase() : p.type) === piece;
  };
  const rights: [string, string, string][] = [
    ["K", "e1", "h1"],
    ["Q", "e1", "a1"],
    ["k", "e8", "h8"],
    ["q", "e8", "a8"],
  ];
  for (const [flag, king, rook] of rights) {
    if (!fields[2].includes(flag)) continue;
    const white = flag === flag.toUpperCase();
    if (!at(king, white ? "K" : "k") || !at(rook, white ? "R" : "r")) {
      return false;
    }
  }
  const ep = fields[3];
  if (ep !== "-") {
    // White to move: black just pushed from rank 7 to rank 5 over rank 6.
    const white = fields[1] === "w";
    const file = ep[0];
    const pawn = `${file}${white ? 5 : 4}`;
    const start = `${file}${white ? 7 : 2}`;
    if (!at(pawn, white ? "p" : "P")) return false;
    if (chess.get(ep as Parameters<Chess["get"]>[0])) return false;
    if (chess.get(start as Parameters<Chess["get"]>[0])) return false;
  }
  return true;
}

export const rules: TurnRules<ChessState> = {
  id: "chess",
  minSeats: 2,
  maxSeats: 2,

  initial: () => ({ fen: DEFAULT_POSITION, history: [] }),

  toMove: (state) => (state.fen.split(" ")[1] === "w" ? 0 : 1),

  legalMoves,

  apply(state, move) {
    if (!UCI.test(move)) illegal();
    const chess = new Chess(state.fen);
    if (outcomeOf(chess, state) || !legalOf(chess).includes(move)) illegal();
    chess.move({
      from: move.slice(0, 2),
      to: move.slice(2, 4),
      promotion: move.length === 5 ? move[4] : undefined,
    });
    const fen = chess.fen();
    return {
      fen,
      history:
        halfmoves(fen) === 0 ? [] : [...state.history, positionHash(state.fen)],
    };
  },

  outcome: (state) => outcomeOf(new Chess(state.fen), state),

  encode: (state) => `${state.fen}|${state.history.join("")}`,

  decode(raw) {
    const bad = (): never => {
      throw new Error("BAD_STATE");
    };
    const parts = raw.split("|");
    if (parts.length !== 2) bad();
    const [fen, h] = parts;
    if (!validateFen(fen).ok) bad();
    let chess: Chess;
    try {
      chess = new Chess(fen);
    } catch {
      return bad();
    }
    // Canonical only: what chess.js would write itself, so "01" for a move
    // number, a dead en passant square or a doubled space never decode.
    if (chess.fen() !== fen) bad();
    const fields = fen.split(" ");
    if (!consistent(chess, fields)) bad();
    // The side that just moved cannot have left its own king in check.
    const flipped = [fields[0], fields[1] === "w" ? "b" : "w", fields[2], "-",
      fields[4], fields[5]].join(" ");
    if (new Chess(flipped).inCheck()) bad();
    const clock = Number(fields[4]);
    if (clock > FIFTY_MOVE_PLIES || h.length !== clock * HASH_LEN) bad();
    const history: string[] = [];
    for (let i = 0; i < h.length; i += HASH_LEN) {
      const entry = h.slice(i, i + HASH_LEN);
      for (const c of entry) if (!HASH_CHARS.includes(c)) bad();
      history.push(entry);
    }
    return { fen, history };
  },
};
