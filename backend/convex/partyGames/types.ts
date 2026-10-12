/**
 * The contract every in-chat PARTY game implements.
 *
 * A party game sits at the same table as a turn game (`turnGames/types.ts`):
 * the same `matches` row, lobby, seats, ready taps, presence heartbeats,
 * pause, grace period and seat swap. What it adds is the two things a turn
 * game never needs:
 *
 *  * **Hidden information.** Liar's Dice hides each player's dice, Imposter
 *    hides the word and who does not know it. The full state lives in the
 *    `matchHidden` table, which no public query ever returns; `matches.state`
 *    holds [PartyRules.publicView] and a player reads their own slice through
 *    `matches.mySecret`, which is [PartyRules.privateView] for their seat.
 *  * **The server's clock.** Phases end on a timer: a 45 s turn, a 40 s vote,
 *    a 10 minute race. The timers are absolute timestamps INSIDE the state
 *    ([PartyRules.deadline]); `matches.ts` schedules a fenced tick at that
 *    instant and calls [PartyRules.onDeadline] when it fires.
 *
 * Every function here is pure and takes the time as `now` rather than reading
 * a clock, so a whole game, timeouts and all, runs in a unit test without a
 * database or fake timers. That is also what makes a pause correct: the server
 * freezes a paused game's clock at the moment it paused, and on resume calls
 * [PartyRules.shift] to move every pending deadline by exactly the time lost.
 *
 * There is no Dart mirror of the rules, unlike the turn games: nothing a party
 * client shows can be predicted without the secrets, so the client waits for
 * the round trip and draws what [publicView] and [privateView] say.
 */

/**
 * How a finished party game ended. `winner` is one seat; `winners` a team
 * (Imposter's crew), and when it is set `winner` is absent. `draw` with
 * neither set is everyone losing together (a race nobody finished).
 */
export type PartyOutcome = {
  winner?: number;
  winners?: number[];
  draw?: boolean;
  reason: string;
};

/**
 * What the creator chose at `matches.create`, already validated by
 * [PartyRules.parseOptions]. Stored on the match (as JSON) so a rematch plays
 * the same variant.
 */
export type PartyOptions = {
  /** Imposter: clues are spoken on the room's call, not typed. */
  voice?: boolean;
  /** Puzzle Race: which daily generator. Absent means a seeded random pick. */
  puzzle?: string;
};

export interface PartyRules<S> {
  /** Wire id: `matches.game`. Never collides with a turn game's id. */
  readonly id: string;
  readonly minSeats: number;
  readonly maxSeats: number;

  /**
   * Validates the creator's raw options, dropping anything this game does not
   * read. Throws `Error("BAD_OPTIONS")` on a value it does read but cannot use.
   */
  parseOptions(raw: unknown): PartyOptions;

  /**
   * The full opening state, secrets included, for [seats] players.
   *
   * [rand] is the match's seeded stream (`randomFor("party:<matchId>", …)`),
   * the ONLY randomness a game may use; anything it needs later (Liar's Dice
   * re-rolls every round) is derived from a seed drawn here and kept in the
   * state. [key] is `<game>:<matchId>`-style text for a game that seeds an
   * external generator by string (Puzzle Race passes `race:<matchId>` as the
   * daily generators' day key). [now] starts the first phase's clock.
   */
  setup(
    seats: number,
    rand: () => number,
    options: PartyOptions,
    now: number,
    key: string,
  ): S;

  /**
   * The state after [seat] performs [action]. Pure: never mutates [s].
   *
   * Throws `Error("ILLEGAL")` for anything the rules do not allow right now
   * (wrong phase, not your turn, a bid that does not raise), or a more
   * specific code the client can show (`BAD_CLUE`, `NOT_SOLVED`).
   *
   * Returns [s] ITSELF, the very object, for an action that is accepted but
   * changes nothing (Puzzle Race's throttled progress). The server then
   * records nothing and does not bump `seq`.
   */
  act(s: S, seat: number, action: string, now: number): S;

  /**
   * When the current phase ends on its own, as an absolute ms timestamp, or
   * null when nothing is timed (a finished game).
   */
  deadline(s: S): number | null;

  /** What happens when [deadline] passes: an auto-move, the next phase, the end. */
  onDeadline(s: S, now: number): S;

  /**
   * [seat] has left the table for good (left, resigned, removed from the
   * room, or still away when the pause's grace ran out). The game carries on
   * without them where it can, or ends.
   */
  forfeit(s: S, seat: number, now: number): S;

  /**
   * Every pending timer moved [ms] later: the game was paused for that long.
   * Timestamps of things that already happened stay where they were.
   */
  shift(s: S, ms: number): S;

  /**
   * The fence key of the current phase. An action made against a state whose
   * key differs from the current one is refused as `STALE`; one made against
   * an older `seq` with the SAME key is still fine.
   *
   * This is the seq fence of turn games (`matches.move`) generalised to
   * actions people take at the same time: a vote cast while another vote
   * landed is not stale (the ballot it was cast on is the same ballot), while
   * a bid against a bid that has since been raised is. A turn-based phase
   * therefore puts the turn in its key; a simultaneous one does not.
   */
  phaseKey(s: S): string;

  /** The seat expected to act right now, or null when nobody in particular is. */
  turnSeat(s: S): number | null;

  /**
   * Seats with nothing left to do in this game (out of dice, finished the
   * race). Their absence from the board pauses nothing and forfeits nothing.
   */
  doneSeats(s: S): number[];

  /**
   * What every room member sees, as JSON. Never contains a secret while the
   * game is running; once [outcome] is set, the secrets are revealed here.
   */
  publicView(s: S): string;

  /** What [seat] alone sees, as JSON, or null when that seat has no secret. */
  privateView(s: S, seat: number): string | null;

  /** Null while the game is still going. */
  outcome(s: S): PartyOutcome | null;

  encode(s: S): string;
  /** Throws `Error("BAD_STATE")` on anything [encode] could not have produced. */
  decode(raw: string): S;
}

/** Thrown by [PartyRules.act] for an action the rules refuse. */
export function illegal(code = "ILLEGAL"): never {
  throw new Error(code);
}

/** A defensive JSON decode shared by every game's [PartyRules.decode]. */
export function decodeJson<S>(raw: string, game: string): S {
  let parsed: any;
  try {
    parsed = JSON.parse(raw);
  } catch {
    throw new Error("BAD_STATE");
  }
  if (!parsed || typeof parsed !== "object" || parsed.game !== game) {
    throw new Error("BAD_STATE");
  }
  return parsed as S;
}

/** The next seat after [from] (cyclically) for which [ok] holds, or -1. */
export function nextSeat(
  from: number,
  n: number,
  ok: (seat: number) => boolean,
): number {
  for (let k = 1; k <= n; k++) {
    const seat = (from + k) % n;
    if (ok(seat)) return seat;
  }
  return -1;
}
