/**
 * The contract every in-chat turn game implements.
 *
 * One pure module per game (`ticTacToe.ts`, `connectFour.ts`, …), mirrored in
 * Dart under `lib/turn_games/`. The server is the only authority on whether a
 * move is legal: `matches:move` decodes the stored state, calls [apply], and
 * stores what comes back. The Dart mirror exists so a tap can draw before the
 * round trip lands, and so the bot can search without a network.
 *
 * Everything crosses the wire as strings — the state as [encode]'s output and a
 * move as a short token — so the match row stays small and a new game needs no
 * schema change. Both mirrors replay the same fixture files
 * (`test/fixtures/turn_games/<id>.json`), which is what keeps them honest.
 */

/** How a finished game ended. `winner` is a seat index, or null for a draw. */
export type TurnOutcome = { winner: number | null; reason: string };

export interface TurnRules<S> {
  /** Wire id, also the fixture file name. */
  readonly id: string;
  readonly minSeats: number;
  readonly maxSeats: number;

  /** The opening position for [seats] players. */
  initial(seats: number): S;

  /** Whose turn it is. A game with extra turns or forced passes says so here. */
  toMove(state: S): number;

  /** Every legal move token, in a stable order. Empty once [outcome] is set. */
  legalMoves(state: S): string[];

  /**
   * The position after [move]. Pure: never mutates [state]. Throws
   * `Error("ILLEGAL")` for any move [legalMoves] would not list, including on
   * a finished game. Forced passes are applied inside, never sent by a client.
   */
  apply(state: S, move: string): S;

  /** Null while the game is still going. */
  outcome(state: S): TurnOutcome | null;

  /** A compact string, at most a few hundred bytes. Round-trips through [decode]. */
  encode(state: S): string;

  /** Throws `Error("BAD_STATE")` on anything [encode] could not have produced. */
  decode(raw: string): S;
}

/** Thrown by [TurnRules.apply]. */
export function illegal(): never {
  throw new Error("ILLEGAL");
}
