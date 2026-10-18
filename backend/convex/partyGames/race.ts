import * as queens from "../games/queens";
import * as sudoku from "../games/sudoku";
import * as tango from "../games/tango";
import * as zip from "../games/zip";
import {
  decodeJson,
  illegal,
  type PartyOptions,
  type PartyRules,
} from "./types";

/**
 * PUZZLE RACE, for 2 to 8: everyone gets the same board and races to solve
 * it on their own phone.
 *
 * The board comes from one of the daily generators, seeded with the match's
 * own key (`race:<matchId>`) in place of a day key, so it is a fresh board
 * nobody has seen, reproducible from the key, and judged by exactly the
 * `isSolved` the daily game uses. Nothing about the board is secret: the
 * puzzle is in the public view and there is no private view.
 *
 * The server is the only clock. A finish is ranked in the order the server
 * accepts it, and its time is the server's `now` minus [startedAt], so a phone
 * whose clock is off, or that lies, changes nothing.
 *
 * ## Action tokens
 *
 *  * `progress:<0-100>`: how far along this player is, for the others' bars.
 *    Throttled to one per [PROGRESS_EVERY_MS] per seat; one sooner is
 *    accepted and dropped, never refused, so a chatty client cannot error
 *    itself into a retry loop.
 *  * `finish:<json>`: the solution, in the daily game's own encoding (Queens:
 *    a column per row; Tango: 0 sun / 1 moon per cell; Sudoku: 1..6 per cell;
 *    Zip: the path as cell indices, start to end). A board that is not solved
 *    is refused with `NOT_SOLVED`.
 *
 * ## The end
 *
 * When every player still in has finished, or [RACE_MS] after the start,
 * whichever is first; the first finish also cuts the clock to at most
 * [FINISH_GRACE_MS] for everyone else. Rank 1 wins; a race nobody finished
 * ends level (`draw`).
 *
 * A pause stops the race clock: [shift] moves [startedAt] along with the
 * deadline, so the time a player is shown and the time they are ranked by
 * both leave out the minutes everyone spent waiting for somebody to come back.
 */

export const RACE_MS = 10 * 60 * 1000;
export const PROGRESS_EVERY_MS = 2_000;
/**
 * Once somebody has won, how long the rest have left to finish for a place.
 * Without it, one slow player held the whole table (winner included) on the
 * results for up to the full [RACE_MS].
 */
export const FINISH_GRACE_MS = 2 * 60 * 1000;
export const PUZZLES = ["queens", "tango", "sudoku", "zip"] as const;
export type RaceKind = (typeof PUZZLES)[number];

export type RaceState = {
  game: "race";
  n: number;
  kind: RaceKind;
  /** The generator's seed key, `race:<matchId>`. */
  key: string;
  /** The generator's puzzle, as the daily game would serve it. */
  puzzle: unknown;
  startedAt: number;
  deadline: number;
  progress: number[];
  lastProgressAt: (number | null)[];
  /** 1-based finishing place per seat, or null. */
  rank: (number | null)[];
  /** Time from [startedAt] to the accepted finish. */
  durationMs: (number | null)[];
  left: boolean[];
  over: boolean;
  /**
   * "finished" (everyone still in is done), "time", or "left" (everyone else
   * left before anybody finished; the one who stayed wins).
   */
  endReason: string | null;
};

export function generatePuzzle(kind: RaceKind, key: string): unknown {
  switch (kind) {
    case "queens":
      return queens.generate(key);
    case "tango":
      return tango.generate(key);
    case "sudoku":
      return sudoku.generate(key);
    case "zip":
      return zip.generate(key);
  }
}

export function checkSolution(kind: RaceKind, puzzle: unknown, solution: unknown): boolean {
  if (!Array.isArray(solution) || solution.length > 256) return false;
  if (!solution.every((x) => typeof x === "number" && Number.isInteger(x))) {
    return false;
  }
  const cells = solution as number[];
  switch (kind) {
    case "queens":
      return queens.isSolved(puzzle as queens.QueensPuzzle, cells);
    case "tango":
      return tango.isSolved(puzzle as tango.TangoPuzzle, cells);
    case "sudoku":
      return sudoku.isSolved(puzzle as sudoku.SudokuPuzzle, cells);
    case "zip":
      return zip.isSolved(puzzle as zip.ZipPuzzle, cells);
  }
}

function racing(s: RaceState): number[] {
  const out: number[] = [];
  for (let i = 0; i < s.n; i++) if (!s.left[i] && s.rank[i] === null) out.push(i);
  return out;
}

function maybeEnd(s: RaceState): RaceState {
  if (s.over || racing(s).length > 0) return s;
  return { ...s, over: true, endReason: "finished" };
}

export const rules: PartyRules<RaceState> = {
  id: "race",
  minSeats: 2,
  maxSeats: 8,

  parseOptions(raw) {
    const o = (raw ?? {}) as Record<string, unknown>;
    if (o.puzzle === undefined || o.puzzle === null || o.puzzle === "random") {
      return {};
    }
    if (typeof o.puzzle !== "string" || !(PUZZLES as readonly string[]).includes(o.puzzle)) {
      illegal("BAD_OPTIONS");
    }
    return { puzzle: o.puzzle };
  },

  setup(seats, rand, options: PartyOptions, now, key) {
    const kind = (options.puzzle as RaceKind | undefined) ??
      PUZZLES[Math.floor(rand() * PUZZLES.length)];
    return {
      game: "race",
      n: seats,
      kind,
      key,
      puzzle: generatePuzzle(kind, key),
      startedAt: now,
      deadline: now + RACE_MS,
      progress: Array(seats).fill(0),
      lastProgressAt: Array(seats).fill(null),
      rank: Array(seats).fill(null),
      durationMs: Array(seats).fill(null),
      left: Array(seats).fill(false),
      over: false,
      endReason: null,
    };
  },

  act(s, seat, action, now) {
    if (s.over || s.left[seat]) illegal();
    if (s.rank[seat] !== null) illegal("ALREADY_FINISHED");
    if (action.startsWith("progress:")) {
      const m = /^progress:(\d{1,3})$/.exec(action);
      if (!m) illegal();
      const pct = Number(m[1]);
      if (pct > 100) illegal();
      const last = s.lastProgressAt[seat];
      if (last !== null && now - last < PROGRESS_EVERY_MS) return s;
      return {
        ...s,
        // Finishing is what says 100; a bar can sit at 99 until then.
        progress: s.progress.map((p, i) => (i === seat ? Math.min(pct, 99) : p)),
        lastProgressAt: s.lastProgressAt.map((t, i) => (i === seat ? now : t)),
      };
    }
    if (action.startsWith("finish:")) {
      let solution: unknown;
      try {
        solution = JSON.parse(action.slice(7));
      } catch {
        illegal("NOT_SOLVED");
      }
      if (!checkSolution(s.kind, s.puzzle, solution)) illegal("NOT_SOLVED");
      const place = s.rank.filter((r) => r !== null).length + 1;
      return maybeEnd({
        ...s,
        deadline: place === 1 ? Math.min(s.deadline, now + FINISH_GRACE_MS) : s.deadline,
        progress: s.progress.map((p, i) => (i === seat ? 100 : p)),
        rank: s.rank.map((r, i) => (i === seat ? place : r)),
        durationMs: s.durationMs.map((d, i) =>
          i === seat ? Math.max(0, now - s.startedAt) : d,
        ),
      });
    }
    return illegal();
  },

  deadline(s) {
    return s.over ? null : s.deadline;
  },

  onDeadline(s) {
    if (s.over) return s;
    return { ...s, over: true, endReason: "time" };
  },

  forfeit(s, seat) {
    if (s.over || s.left[seat]) return s;
    const after = { ...s, left: s.left.map((l, i) => l || i === seat) };
    // A finisher who walks away keeps their place; anyone else is out.
    const ended = maybeEnd(after);
    if (ended.over) return ended;
    // Nobody left to race against, and nobody has finished: the one still
    // at the table wins by default rather than racing a clock alone.
    const staying = after.left.filter((l) => !l).length;
    if (staying <= 1 && !after.rank.includes(1)) {
      return { ...after, over: true, endReason: "left" };
    }
    return ended;
  },

  shift(s, ms) {
    if (s.over) return s;
    return { ...s, startedAt: s.startedAt + ms, deadline: s.deadline + ms };
  },

  phaseKey() {
    // Everyone races at once: no action is ever stale because of another's.
    return "race";
  },

  turnSeat() {
    return null;
  },

  doneSeats(s) {
    const out: number[] = [];
    for (let i = 0; i < s.n; i++) if (s.rank[i] !== null || s.left[i]) out.push(i);
    return out;
  },

  publicView(s) {
    return JSON.stringify({
      game: "race",
      phase: s.over ? "over" : "racing",
      kind: s.kind,
      puzzle: s.puzzle,
      startedAt: s.startedAt,
      deadline: rules.deadline(s),
      players: Array.from({ length: s.n }, (_, i) => ({
        progress: s.progress[i],
        rank: s.rank[i],
        durationMs: s.durationMs[i],
        left: s.left[i],
      })),
      reason: s.endReason,
    });
  },

  privateView() {
    return null;
  },

  outcome(s) {
    if (!s.over) return null;
    const first = s.rank.indexOf(1);
    const reason = s.endReason ?? "finished";
    if (first < 0 && reason === "left") {
      const staying = s.left.indexOf(false);
      if (staying >= 0) return { winner: staying, reason };
    }
    if (first < 0) return { draw: true, reason };
    return { winner: first, reason };
  },

  encode(s) {
    return JSON.stringify(s);
  },

  decode(raw) {
    return decodeJson<RaceState>(raw, "race");
  },
};
