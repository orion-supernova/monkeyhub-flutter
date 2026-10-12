/**
 * Every turn game the server can host, by wire id.
 *
 * `matches:*` looks a game up here and nowhere else, so a game that is not in
 * this map cannot be started, moved in or replayed. `tools/turn-fixtures.ts`
 * walks the same map to write the fixtures the Dart mirrors replay.
 */

import type { TurnRules } from "./types";
import { rules as checkers } from "./checkers";
import { rules as chess } from "./chess";
import { rules as connectFour } from "./connectFour";
import { rules as dots } from "./dots";
import { rules as reversi } from "./reversi";
import { rules as ticTacToe } from "./ticTacToe";

// `any` because each game's state type is its own; callers only ever pass a
// state back to the same game's functions, as the decoded output of `decode`.
// eslint-disable-next-line @typescript-eslint/no-explicit-any
export type AnyTurnRules = TurnRules<any>;

export const turnGames: Readonly<Record<string, AnyTurnRules>> = {
  [ticTacToe.id]: ticTacToe,
  [connectFour.id]: connectFour,
  [reversi.id]: reversi,
  [checkers.id]: checkers,
  [dots.id]: dots,
  [chess.id]: chess,
};

/** The rules for [id], or null for a game this build does not know. */
export function rulesFor(id: string): AnyTurnRules | null {
  return Object.prototype.hasOwnProperty.call(turnGames, id)
    ? turnGames[id]
    : null;
}
