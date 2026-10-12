import { expect, test } from "vitest";
import { partyGames, partyRulesFor } from "./registry";
import { turnGames } from "../turnGames/registry";

/**
 * `matches.ts` picks a game's machinery by which registry it is in, so an id
 * in both would be a game that is two things at once.
 */
test("party and turn games never share an id", () => {
  for (const id of Object.keys(partyGames)) {
    expect(Object.keys(turnGames)).not.toContain(id);
    expect(partyRulesFor(id)?.id).toBe(id);
  }
  expect(partyRulesFor("toString")).toBeNull();
  expect(Object.keys(partyGames).sort()).toEqual(["imposter", "liarsdice", "race"]);
});
