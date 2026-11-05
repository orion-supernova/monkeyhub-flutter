import {
  decodeJson,
  illegal,
  type PartyRules,
} from "./types";

/**
 * JUNGLE FIST, 1v1: a real-time fighting game played phone to phone.
 *
 * The fight itself never touches Convex. Both phones run the same
 * deterministic simulation (lib/fight/core) and swap only their button
 * presses over a WebRTC data channel (signalled through `fightSignals`), with
 * rollback netcode hiding the latency. This table is everything around that:
 * the chat card, the lobby and ready taps, presence (beat/away, pause, the
 * forfeit after the live grace), and the result.
 *
 * The server cannot judge the fight (it never sees the inputs), so the result
 * is what the players report:
 *
 * ## Action tokens
 *
 *  * `result:<winner>:<checksum>`: this phone's final result. `winner` is the
 *    winning seat (0 or 1) or `-1` for a draw; `checksum` is the 32-bit state
 *    checksum of the final frame, which two honest phones share exactly
 *    because the simulation is deterministic. A seat reports once.
 *
 * ## The end
 *
 *  * Both report the same winner and checksum: that result stands.
 *  * They disagree: neither phone can be believed over the other, so the
 *    fight is a draw, reason `disputed`.
 *  * One reports and the other does not within [REPORT_GRACE_MS] (a loser who
 *    closes the app on the result screen): the one report stands.
 *  * A seat leaves before any report: the other wins, reason `left`.
 *  * Nobody reports within [FIGHT_MS] of the start: draw, `abandoned`.
 *
 * Unranked, like every chat game: nothing here feeds a rating, so a false
 * report wins nothing beyond the card.
 */

/** Longest a fight can run: 3 rounds of 60 s plus intros, KOs and slack. */
export const FIGHT_MS = 8 * 60 * 1000;
/** After the first report, how long the other phone has to send its own. */
export const REPORT_GRACE_MS = 20 * 1000;

export type FightReport = { winner: number; cs: number };

export type FightState = {
  game: "fight";
  startedAt: number;
  deadline: number;
  reports: (FightReport | null)[];
  left: boolean[];
  over: boolean;
  /** "win", "draw", "disputed", "left", "abandoned", "unconfirmed". */
  endReason: string | null;
  winner: number | null;
};

function settle(s: FightState): FightState {
  const [a, b] = s.reports;
  if (!a || !b) return s;
  if (a.winner === b.winner && a.cs === b.cs) {
    return {
      ...s,
      over: true,
      endReason: a.winner < 0 ? "draw" : "win",
      winner: a.winner < 0 ? null : a.winner,
    };
  }
  return { ...s, over: true, endReason: "disputed", winner: null };
}

export const rules: PartyRules<FightState> = {
  id: "fight",
  minSeats: 2,
  maxSeats: 2,

  parseOptions() {
    return {};
  },

  setup(_seats, _rand, _options, now) {
    return {
      game: "fight",
      startedAt: now,
      deadline: now + FIGHT_MS,
      reports: [null, null],
      left: [false, false],
      over: false,
      endReason: null,
      winner: null,
    };
  },

  act(s, seat, action, now) {
    if (s.over || s.left[seat]) illegal();
    if (s.reports[seat]) illegal("ALREADY_REPORTED");
    const m = /^result:(-1|0|1):(\d{1,10})$/.exec(action);
    if (!m) illegal();
    const cs = Number(m[2]);
    if (cs > 0xffffffff) illegal();
    const reports = s.reports.map((r, i) =>
      i === seat ? { winner: Number(m[1]), cs } : r,
    );
    const first = s.reports.every((r) => r === null);
    return settle({
      ...s,
      reports,
      deadline: first ? Math.min(s.deadline, now + REPORT_GRACE_MS) : s.deadline,
    });
  },

  deadline(s) {
    return s.over ? null : s.deadline;
  },

  onDeadline(s) {
    if (s.over) return s;
    const only = s.reports.find((r) => r !== null);
    if (only) {
      return {
        ...s,
        over: true,
        endReason: only.winner < 0 ? "draw" : "unconfirmed",
        winner: only.winner < 0 ? null : only.winner,
      };
    }
    return { ...s, over: true, endReason: "abandoned", winner: null };
  },

  forfeit(s, seat) {
    if (s.over || s.left[seat]) return s;
    const left = s.left.map((l, i) => l || i === seat);
    // A seat that already reported has said how it ended; leaving afterwards
    // (closing the result screen) is not a forfeit. Let the other report or
    // the grace settle it.
    if (s.reports[seat]) return { ...s, left };
    const other = 1 - seat;
    return { ...s, left, over: true, endReason: "left", winner: other };
  },

  shift(s, ms) {
    if (s.over) return s;
    return { ...s, startedAt: s.startedAt + ms, deadline: s.deadline + ms };
  },

  phaseKey() {
    return "fight";
  },

  turnSeat() {
    return null;
  },

  doneSeats(s) {
    const out: number[] = [];
    for (let i = 0; i < 2; i++) if (s.reports[i] || s.left[i]) out.push(i);
    return out;
  },

  publicView(s) {
    return JSON.stringify({
      game: "fight",
      phase: s.over ? "over" : "fighting",
      startedAt: s.startedAt,
      deadline: rules.deadline(s),
      reported: s.reports.map((r) => r !== null),
      left: s.left,
      winner: s.winner,
      reason: s.endReason,
    });
  },

  privateView() {
    return null;
  },

  outcome(s) {
    if (!s.over) return null;
    const reason = s.endReason ?? "abandoned";
    if (s.winner === null) return { draw: true, reason };
    return { winner: s.winner, reason };
  },

  encode(s) {
    return JSON.stringify(s);
  },

  decode(raw) {
    return decodeJson<FightState>(raw, "fight");
  },
};
