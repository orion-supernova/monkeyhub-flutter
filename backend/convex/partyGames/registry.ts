/**
 * Every party game the server can host, by wire id.
 *
 * The party counterpart of `turnGames/registry.ts`, and like it the only door:
 * `matches:*` looks a party game up here, so one that is not in this map can
 * be neither created nor acted in. The two maps never share an id; the test
 * next to this file pins that, because `matches.ts` decides which machinery a
 * game gets by which map it is in.
 */

import type { PartyRules } from "./types";
import { rules as imposter } from "./imposter";
import { rules as liarsDice } from "./liarsDice";
import { rules as race } from "./race";

// `any` for the same reason as the turn registry: a state only ever goes back
// to the game that decoded it.
// eslint-disable-next-line @typescript-eslint/no-explicit-any
export type AnyPartyRules = PartyRules<any>;

export const partyGames: Readonly<Record<string, AnyPartyRules>> = {
  [liarsDice.id]: liarsDice,
  [imposter.id]: imposter,
  [race.id]: race,
};

/** The rules for [id], or null when [id] is not a party game. */
export function partyRulesFor(id: string): AnyPartyRules | null {
  return Object.prototype.hasOwnProperty.call(partyGames, id)
    ? partyGames[id]
    : null;
}

export function isPartyGame(id: string): boolean {
  return partyRulesFor(id) !== null;
}
