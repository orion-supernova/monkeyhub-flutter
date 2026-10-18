import { fnv1a, mulberry32 } from "../games/rng";
import {
  decodeJson,
  illegal,
  nextSeat,
  type PartyOptions,
  type PartyRules,
} from "./types";

/**
 * LIAR'S DICE, for 2 to 6 at a table.
 *
 * Everyone holds [START_DICE] dice nobody else can see. In turn order a player
 * either raises the bid ("there are at least four 5s on the table") or calls
 * the last bidder a liar. A call shows every die: when the bid holds, the
 * caller loses a die; when it does not, the bidder does. 1s are wild, counting
 * as any face, except in a bid ON 1s. The round's loser starts the next round
 * (or the next player still in, if that die was their last). Out of dice is
 * out of the game; the last player holding any wins.
 *
 * Dice are re-rolled every round from a seed drawn once at setup, so a round
 * is reproducible from the state alone and nothing ever calls `Math.random`.
 *
 * ## Action tokens
 *
 *  * `bid:<quantity>:<face>`, face 1..6, quantity 1..(dice still in play).
 *    Strictly higher than the standing bid ([raises]: a bigger quantity, or
 *    the same quantity on a higher face, with Perudo's conversion for 1s).
 *  * `liar`, only against a standing bid.
 *
 * ## The clock
 *
 * Every turn has [TURN_MS]. A player who lets it run out has it played for
 * them: a call if there is a bid to call, otherwise the most modest opening
 * there is, one of their own most common face. Both are marked `auto` so the
 * board can say "time ran out" rather than pretend the player chose it.
 */

export const START_DICE = 5;
export const TURN_MS = 45_000;

export type Bid = { seat: number; qty: number; face: number; auto?: boolean };

/** The last call and what the dice said, kept for the board to show. */
export type Reveal = {
  round: number;
  /** Every seat's dice that round, [] for a seat that had none. */
  dice: number[][];
  bid: Bid;
  caller: number;
  /** How many dice matched the bid's face, wild 1s included. */
  count: number;
  holds: boolean;
  loser: number;
  /** The call was the timer's, not the caller's. */
  auto: boolean;
};

export type LiarsDiceState = {
  game: "liarsdice";
  n: number;
  /** Drawn from the match's stream at setup; every round's roll derives from it. */
  seed: number;
  round: number;
  /** Dice each seat still holds. 0 is out. */
  counts: number[];
  /** This round's dice, per seat. SECRET while the game runs. */
  dice: number[][];
  left: boolean[];
  turn: number;
  /** This round's bids, oldest first. The standing bid is the last. */
  bids: Bid[];
  deadline: number | null;
  reveal: Reveal | null;
  winner: number | null;
  /** "win" (outlasted everyone) or "left" (everyone else left). */
  endReason: string | null;
};

/** Seat [seat]'s dice for [round], a pure function of the seed. */
function rollRound(seed: number, round: number, counts: number[]): number[][] {
  const rand = mulberry32(fnv1a(`${seed}:${round}`));
  return counts.map((c) =>
    Array.from({ length: c }, () => 1 + Math.floor(rand() * 6)),
  );
}

function alive(s: LiarsDiceState): number[] {
  const out: number[] = [];
  for (let i = 0; i < s.n; i++) if (s.counts[i] > 0) out.push(i);
  return out;
}

function totalDice(s: LiarsDiceState): number {
  return s.counts.reduce((a, b) => a + b, 0);
}

/** The dice matching [face] across the table, 1s wild unless the face is 1. */
export function countFace(dice: number[][], face: number): number {
  let n = 0;
  for (const hand of dice) {
    for (const d of hand) if (d === face || (face !== 1 && d === 1)) n++;
  }
  return n;
}

/**
 * Whether [qty]×[face] is strictly higher than [last], by Perudo's rule for
 * aces. 1s are wild, so a bid ON 1s is roughly twice as hard to make as the
 * same quantity of any other face, and the ladder prices it that way:
 *
 *  * plain face to plain face: more dice, or the same number on a higher face;
 *  * onto 1s: at least half the quantity, rounded up (5×4 → 3×1);
 *  * 1s to 1s: more of them;
 *  * off 1s: at least double plus one (3×1 → 7×anything).
 *
 * Without the conversion a bid on 1s was simply the LOWEST face, so "4×1"
 * outbid "3×6" while being far less likely, and nobody had a reason to bid
 * 1s at all. Any opening bid stands, 1s included.
 */
export function raises(last: Bid | null, qty: number, face: number): boolean {
  if (!last) return true;
  if (last.face === 1 && face === 1) return qty > last.qty;
  if (face === 1) return qty >= Math.ceil(last.qty / 2);
  if (last.face === 1) return qty >= last.qty * 2 + 1;
  return qty > last.qty || (qty === last.qty && face > last.face);
}

/** The face [hand] holds most of; ties go to the higher face. */
export function mostCommonFace(hand: number[]): number {
  let best = 6;
  let bestN = -1;
  for (let face = 6; face >= 1; face--) {
    const n = hand.filter((d) => d === face).length;
    if (n > bestN) {
      best = face;
      bestN = n;
    }
  }
  return best;
}

/** Starts round [s.round + 1] with [starter] to bid. */
function newRound(s: LiarsDiceState, starter: number, now: number): LiarsDiceState {
  const round = s.round + 1;
  return {
    ...s,
    round,
    dice: rollRound(s.seed, round, s.counts),
    turn: starter,
    bids: [],
    deadline: now + TURN_MS,
  };
}

function bid(
  s: LiarsDiceState,
  seat: number,
  qty: number,
  face: number,
  now: number,
  auto = false,
): LiarsDiceState {
  if (!Number.isInteger(qty) || !Number.isInteger(face)) illegal();
  if (face < 1 || face > 6 || qty < 1 || qty > totalDice(s)) illegal();
  const last = s.bids.length ? s.bids[s.bids.length - 1] : null;
  if (!raises(last, qty, face)) illegal();
  const next = nextSeat(seat, s.n, (i) => s.counts[i] > 0);
  return {
    ...s,
    bids: [...s.bids, { seat, qty, face, ...(auto ? { auto: true } : {}) }],
    turn: next,
    deadline: now + TURN_MS,
  };
}

function call(
  s: LiarsDiceState,
  caller: number,
  now: number,
  auto = false,
): LiarsDiceState {
  const standing = s.bids.length ? s.bids[s.bids.length - 1] : null;
  if (!standing) illegal();
  const count = countFace(s.dice, standing.face);
  const holds = count >= standing.qty;
  const loser = holds ? caller : standing.seat;
  const counts = s.counts.map((c, i) => (i === loser ? c - 1 : c));
  const reveal: Reveal = {
    round: s.round,
    dice: s.dice,
    bid: standing,
    caller,
    count,
    holds,
    loser,
    auto,
  };
  const after: LiarsDiceState = { ...s, counts, reveal };
  const left = alive(after);
  if (left.length <= 1) {
    return {
      ...after,
      winner: left.length === 1 ? left[0] : null,
      endReason: "win",
      deadline: null,
      bids: [],
    };
  }
  const starter =
    counts[loser] > 0 ? loser : nextSeat(loser, s.n, (i) => counts[i] > 0);
  return newRound(after, starter, now);
}

function parseAction(action: string): { kind: "liar" } | { kind: "bid"; qty: number; face: number } {
  if (action === "liar") return { kind: "liar" };
  const m = /^bid:(\d{1,3}):(\d)$/.exec(action);
  if (!m) illegal();
  return { kind: "bid", qty: Number(m[1]), face: Number(m[2]) };
}

export const rules: PartyRules<LiarsDiceState> = {
  id: "liarsdice",
  minSeats: 2,
  maxSeats: 6,

  parseOptions(): PartyOptions {
    return {};
  },

  setup(seats, rand, _options, now) {
    const seed = Math.floor(rand() * 4294967296) >>> 0;
    const starter = Math.floor(rand() * seats);
    const base: LiarsDiceState = {
      game: "liarsdice",
      n: seats,
      seed,
      round: 0,
      counts: Array(seats).fill(START_DICE),
      dice: [],
      left: Array(seats).fill(false),
      turn: starter,
      bids: [],
      deadline: null,
      reveal: null,
      winner: null,
      endReason: null,
    };
    return newRound(base, starter, now);
  },

  act(s, seat, action, now) {
    if (s.winner !== null || s.endReason !== null) illegal();
    if (seat !== s.turn || s.counts[seat] <= 0) illegal("NOT_YOUR_TURN");
    const a = parseAction(action);
    if (a.kind === "liar") return call(s, seat, now);
    return bid(s, seat, a.qty, a.face, now);
  },

  deadline(s) {
    return s.endReason !== null ? null : s.deadline;
  },

  onDeadline(s, now) {
    if (s.endReason !== null) return s;
    if (s.bids.length > 0) return call(s, s.turn, now, true);
    return bid(s, s.turn, 1, mostCommonFace(s.dice[s.turn] ?? []), now, true);
  },

  forfeit(s, seat, now) {
    if (s.endReason !== null || s.left[seat]) return s;
    const hadDice = s.counts[seat] > 0;
    const after: LiarsDiceState = {
      ...s,
      left: s.left.map((l, i) => l || i === seat),
      counts: s.counts.map((c, i) => (i === seat ? 0 : c)),
    };
    if (!hadDice) return after;
    const left = alive(after);
    if (left.length <= 1) {
      return {
        ...after,
        winner: left.length === 1 ? left[0] : null,
        endReason: "left",
        deadline: null,
        bids: [],
      };
    }
    // Their dice were part of every bid on the table; the round those bids
    // were about no longer exists. Re-deal it, with the same player to act
    // (or the next one in, if it was the leaver's turn).
    const starter =
      after.counts[s.turn] > 0
        ? s.turn
        : nextSeat(s.turn, s.n, (i) => after.counts[i] > 0);
    return newRound(after, starter, now);
  },

  shift(s, ms) {
    return s.deadline === null ? s : { ...s, deadline: s.deadline + ms };
  },

  phaseKey(s) {
    return `${s.round}:${s.bids.length}`;
  },

  turnSeat(s) {
    return s.endReason !== null ? null : s.turn;
  },

  doneSeats(s) {
    const out: number[] = [];
    for (let i = 0; i < s.n; i++) if (s.counts[i] <= 0) out.push(i);
    return out;
  },

  publicView(s) {
    const over = s.endReason !== null;
    return JSON.stringify({
      game: "liarsdice",
      phase: over ? "over" : "bidding",
      round: s.round,
      turn: over ? null : s.turn,
      deadline: rules.deadline(s),
      bid: s.bids.length ? s.bids[s.bids.length - 1] : null,
      bids: s.bids,
      counts: s.counts,
      out: s.counts.map((c) => c <= 0),
      left: s.left,
      totalDice: totalDice(s),
      reveal: s.reveal,
      winner: s.winner,
      ...(over ? { dice: s.dice } : {}),
    });
  },

  privateView(s, seat) {
    if (seat < 0 || seat >= s.n) return null;
    return JSON.stringify({
      round: s.round,
      dice: [...(s.dice[seat] ?? [])].sort((a, b) => a - b),
    });
  },

  outcome(s) {
    if (s.endReason === null) return null;
    if (s.winner === null) return { draw: true, reason: s.endReason };
    return { winner: s.winner, reason: s.endReason };
  },

  encode(s) {
    return JSON.stringify(s);
  },

  decode(raw) {
    return decodeJson<LiarsDiceState>(raw, "liarsdice");
  },
};
