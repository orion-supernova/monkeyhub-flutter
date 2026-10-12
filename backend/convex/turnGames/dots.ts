/**
 * Dots and Boxes, two to four seats.
 *
 * Mirrored in `lib/turn_games/dots.dart`; both replay
 * `test/fixtures/turn_games/dots.json`.
 *
 * The grid is [rows] x [cols] boxes, so (rows + 1) x (cols + 1) dots. Lines are
 * numbered horizontals first, row by row — (rows + 1) * cols of them — then
 * verticals row by row, rows * (cols + 1). A move is just that index as a
 * decimal string.
 *
 * Drawing a line that closes one box or two scores them for the mover, who
 * then moves again; any other line passes the turn on. The game ends when the
 * last line is drawn. The highest score wins, and a tie for first place is a
 * draw — with three or four players, too, so nobody "wins" a shared first.
 *
 * The size lives in the state rather than in a constant so a smaller board
 * (3 x 3) can ship later without a new game id; `initial` is always 4 x 4.
 */

import { illegal, TurnOutcome, TurnRules } from "./types";

export type DotsState = {
  rows: number;
  cols: number;
  /** One flag per line, in line-index order. */
  lines: boolean[];
  /** One per box, row-major: the owning seat, or -1 while open. */
  owners: number[];
  toMove: number;
  /** One per seat, which also fixes the seat count. */
  scores: number[];
};

export const DEFAULT_SIZE = 4;
/** The largest size `decode` accepts; keeps a hostile state from being huge. */
const MAX_SIZE = 8;

export function lineCount(rows: number, cols: number): number {
  return (rows + 1) * cols + rows * (cols + 1);
}

/** The four line indices around box (r, c): top, bottom, left, right. */
export function boxSides(
  rows: number,
  cols: number,
  r: number,
  c: number,
): [number, number, number, number] {
  const h = (rows + 1) * cols;
  return [
    r * cols + c,
    (r + 1) * cols + c,
    h + r * (cols + 1) + c,
    h + r * (cols + 1) + c + 1,
  ];
}

/** The one or two boxes a line borders, as row-major box indices. */
export function lineBoxes(rows: number, cols: number, line: number): number[] {
  const h = (rows + 1) * cols;
  const out: number[] = [];
  if (line < h) {
    const r = Math.floor(line / cols);
    const c = line % cols;
    if (r > 0) out.push((r - 1) * cols + c);
    if (r < rows) out.push(r * cols + c);
  } else {
    const v = line - h;
    const r = Math.floor(v / (cols + 1));
    const c = v % (cols + 1);
    if (c > 0) out.push(r * cols + c - 1);
    if (c < cols) out.push(r * cols + c);
  }
  return out;
}

function sidesDrawn(s: DotsState, box: number): number {
  const sides = boxSides(s.rows, s.cols, Math.floor(box / s.cols), box % s.cols);
  let n = 0;
  for (const l of sides) if (s.lines[l]) n++;
  return n;
}

/** An empty [rows] x [cols] board for [seats] players. Exposed for tests. */
export function initialSized(
  seats: number,
  rows: number,
  cols: number,
): DotsState {
  if (seats < 2 || seats > 4) illegal();
  if (rows < 1 || cols < 1 || rows > MAX_SIZE || cols > MAX_SIZE) illegal();
  return {
    rows,
    cols,
    lines: new Array(lineCount(rows, cols)).fill(false),
    owners: new Array(rows * cols).fill(-1),
    toMove: 0,
    scores: new Array(seats).fill(0),
  };
}

function isOver(s: DotsState): boolean {
  return s.lines.every((l) => l);
}

function outcomeOf(s: DotsState): TurnOutcome | null {
  if (!isOver(s)) return null;
  const best = Math.max(...s.scores);
  const leaders = s.scores.filter((x) => x === best).length;
  if (leaders > 1) return { winner: null, reason: "tie" };
  return { winner: s.scores.indexOf(best), reason: "most-boxes" };
}

function bad(): never {
  throw new Error("BAD_STATE");
}

export const rules: TurnRules<DotsState> = {
  id: "dots",
  minSeats: 2,
  maxSeats: 4,

  initial(seats) {
    return initialSized(seats, DEFAULT_SIZE, DEFAULT_SIZE);
  },

  toMove(state) {
    return state.toMove;
  },

  legalMoves(state) {
    const out: string[] = [];
    for (let i = 0; i < state.lines.length; i++) {
      if (!state.lines[i]) out.push(String(i));
    }
    return out;
  },

  apply(state, move) {
    if (!/^(0|[1-9][0-9]*)$/.test(move)) illegal();
    const line = Number(move);
    if (line >= state.lines.length || state.lines[line]) illegal();
    const next: DotsState = {
      rows: state.rows,
      cols: state.cols,
      lines: state.lines.slice(),
      owners: state.owners.slice(),
      toMove: state.toMove,
      scores: state.scores.slice(),
    };
    next.lines[line] = true;
    let closed = 0;
    for (const box of lineBoxes(state.rows, state.cols, line)) {
      if (sidesDrawn(next, box) === 4) {
        next.owners[box] = state.toMove;
        closed++;
      }
    }
    next.scores[state.toMove] += closed;
    if (closed === 0) next.toMove = (state.toMove + 1) % state.scores.length;
    return next;
  },

  outcome: outcomeOf,

  encode(state) {
    return [
      `${state.rows}x${state.cols}`,
      state.lines.map((l) => (l ? "1" : "0")).join(""),
      state.owners.map((o) => (o < 0 ? "." : String(o))).join(""),
      String(state.toMove),
      state.scores.join(","),
    ].join("|");
  },

  decode(raw) {
    const parts = raw.split("|");
    if (parts.length !== 5) bad();
    const [size, l, o, t, sc] = parts;
    const m = /^([1-9])x([1-9])$/.exec(size);
    if (!m) bad();
    const rows = Number(m[1]);
    const cols = Number(m[2]);
    if (rows > MAX_SIZE || cols > MAX_SIZE) bad();
    if (!/^[01]*$/.test(l) || l.length !== lineCount(rows, cols)) bad();
    const scoreParts = sc.split(",");
    const seats = scoreParts.length;
    if (seats < 2 || seats > 4) bad();
    if (!/^[.0-3]*$/.test(o) || o.length !== rows * cols) bad();
    if (!/^[0-3]$/.test(t) || Number(t) >= seats) bad();
    const scores = scoreParts.map((x) => {
      if (!/^(0|[1-9][0-9]*)$/.test(x)) bad();
      return Number(x);
    });
    const state: DotsState = {
      rows,
      cols,
      lines: l.split("").map((c) => c === "1"),
      owners: o.split("").map((c) => (c === "." ? -1 : Number(c))),
      toMove: Number(t),
      scores,
    };
    // A box is owned exactly when it is closed, and scores are owner counts.
    const counted = new Array(seats).fill(0);
    for (let b = 0; b < rows * cols; b++) {
      const owner = state.owners[b];
      if (owner >= seats) bad();
      if ((owner >= 0) !== (sidesDrawn(state, b) === 4)) bad();
      if (owner >= 0) counted[owner]++;
    }
    for (let i = 0; i < seats; i++) if (counted[i] !== scores[i]) bad();
    return state;
  },
};
