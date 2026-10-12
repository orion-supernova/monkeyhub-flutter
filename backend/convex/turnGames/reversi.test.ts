import { describe, expect, test } from "vitest";
import { discCounts, movesFor, passedSeat, rules } from "./reversi";

function board(rows: string[]): string {
  expect(rows.length).toBe(8);
  return rows.join("");
}

describe("reversi", () => {
  test("standard opening: black to move with four choices", () => {
    const s = rules.initial(2);
    expect(rules.encode(s)).toBe(
      `${".".repeat(27)}WB......BW${".".repeat(27)}/0`,
    );
    expect(rules.legalMoves(s)).toEqual(["19", "26", "37", "44"]);
    expect(discCounts(s)).toEqual([2, 2]);
  });

  test("a move flips the line it closes and hands over the turn", () => {
    const s = rules.apply(rules.initial(2), "19");
    expect(s.cells[19]).toBe("B");
    expect(s.cells[27]).toBe("B");
    expect(discCounts(s)).toEqual([4, 1]);
    expect(rules.toMove(s)).toBe(1);
    expect(passedSeat(s)).toBeNull();
  });

  test("flips in several directions at once", () => {
    const cells = board([
      "........",
      "........",
      "..B.B...",
      "...WW...",
      "..BW....",
      "....W...",
      "........",
      "........",
    ]);
    const s = rules.apply({ cells, toMove: 0, passed: false }, "36");
    // West (35, closed by 34), north (28, by 20), north-west (27, by 18).
    expect(s.cells[35]).toBe("B");
    expect(s.cells[28]).toBe("B");
    expect(s.cells[27]).toBe("B");
    // South runs off into an empty cell, so 44 stays white.
    expect(s.cells[44]).toBe("W");
    expect(discCounts(s)).toEqual([7, 1]);
  });

  test("a move that flips nothing is illegal, as is junk", () => {
    const s = rules.initial(2);
    for (const m of ["0", "27", "64", "-1", "019", "", "x"]) {
      expect(() => rules.apply(s, m), m).toThrow("ILLEGAL");
    }
  });

  test("a side with no move is skipped automatically and flagged", () => {
    // Black's only move is 2 (flipping 1). Afterwards white's lone disc at 3
    // brackets nothing, while black can still take it from 4.
    const before = {
      cells: board([
        "BW.W....",
        "BB......",
        "........",
        "........",
        "........",
        "........",
        "........",
        "........",
      ]),
      toMove: 0,
      passed: false,
    };
    expect(movesFor(before.cells, 0)).toEqual([2]);
    const after = rules.apply(before, "2");
    expect(after.cells.slice(0, 4)).toBe("BBBW");
    expect(movesFor(after.cells, 1)).toEqual([]);
    expect(rules.legalMoves(after)).toEqual(["4"]);
    expect(rules.toMove(after)).toBe(0);
    expect(after.passed).toBe(true);
    expect(passedSeat(after)).toBe(1);
    expect(rules.encode(after).endsWith("/0p")).toBe(true);
    expect(rules.outcome(after)).toBeNull();
    // The flag only describes the move that set it.
    const next = rules.apply(after, "4");
    expect(next.passed).toBe(false);
    expect(rules.outcome(next)).toEqual({ winner: 0, reason: "discs" });
  });

  test("the game ends when neither side can move; most discs wins", () => {
    const before = {
      cells: "BW" + ".".repeat(62),
      toMove: 0,
      passed: false,
    };
    // Black has no bracket for W at 1 from anywhere but 2 → flips it.
    const after = rules.apply(before, "2");
    expect(after.cells.slice(0, 3)).toBe("BBB");
    expect(rules.legalMoves(after)).toEqual([]);
    expect(rules.outcome(after)).toEqual({ winner: 0, reason: "discs" });
    expect(after.passed).toBe(false);
    expect(() => rules.apply(after, "3")).toThrow("ILLEGAL");
  });

  test("equal discs is a draw", () => {
    const full = "BW".repeat(32);
    const s = { cells: full, toMove: 0, passed: false };
    expect(rules.outcome(s)).toEqual({ winner: null, reason: "discs" });
  });

  test("encode and decode round-trip, pass flag included", () => {
    const s = rules.apply(rules.initial(2), "19");
    expect(rules.encode(rules.decode(rules.encode(s)))).toBe(rules.encode(s));
    // A real pass position, with the centre filled so decode accepts it.
    const raw =
      board([
        "WWWWWWWW",
        "WWWWWWWW",
        "WWWWWWWW",
        "WWWWWWWW",
        "WWWWWWWW",
        "WWWWWWWW",
        "WWWWWWWW",
        "WWWWW.WB",
      ]) + "/0p";
    // Black takes 62 from 61; white has nothing to bracket a corner with.
    const p = rules.decode(raw);
    expect(rules.encode(p)).toBe(raw);
    expect(passedSeat(p)).toBe(1);
    expect(rules.legalMoves(p)).toEqual(["61"]);
  });

  test("decode refuses impossible states", () => {
    const open = rules.encode(rules.initial(2));
    const cells = open.slice(0, 64);
    for (const raw of [
      "",
      `${cells}/2`,
      `${cells}/0x`,
      `${cells.slice(1)}/0`,
      `${".".repeat(64)}/0`, // empty centre
      `${cells}/0p`, // flags a pass white never had to make
      // White to move but stuck while black can play: apply would have passed.
      board([
        "WWWWWWWW",
        "WWWWWWWW",
        "WWWWWWWW",
        "WWWWWWWW",
        "WWWWWWWW",
        "WWWWWWWW",
        "WWWWWWWW",
        "WWWWW.WB",
      ]) + "/1",
    ]) {
      expect(() => rules.decode(raw), raw).toThrow("BAD_STATE");
    }
  });
});
