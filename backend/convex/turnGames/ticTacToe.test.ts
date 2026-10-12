import { describe, expect, test } from "vitest";
import { rules, winningLine } from "./ticTacToe";

/** Plays [moves] from the opening, returning the encoded state after each. */
function play(...moves: string[]) {
  let s = rules.initial(2);
  for (const m of moves) s = rules.apply(s, m);
  return s;
}

describe("tic-tac-toe", () => {
  test("opens empty with X to move and every cell legal", () => {
    const s = rules.initial(2);
    expect(rules.encode(s)).toBe("........./0");
    expect(rules.toMove(s)).toBe(0);
    expect(rules.legalMoves(s)).toEqual(
      ["0", "1", "2", "3", "4", "5", "6", "7", "8"],
    );
    expect(rules.outcome(s)).toBeNull();
  });

  test("marks alternate and occupied cells drop out of the legal list", () => {
    const s = play("4", "0");
    expect(rules.encode(s)).toBe("O...X..../0");
    expect(rules.legalMoves(s)).not.toContain("4");
    expect(rules.legalMoves(s)).not.toContain("0");
  });

  test("a row wins for the side that closed it", () => {
    const s = play("0", "3", "1", "4", "2");
    expect(rules.outcome(s)).toEqual({ winner: 0, reason: "line" });
    expect(winningLine(s)).toEqual([0, 1, 2]);
    expect(rules.legalMoves(s)).toEqual([]);
  });

  test("O can win too", () => {
    const s = play("0", "4", "1", "2", "8", "6");
    expect(rules.outcome(s)).toEqual({ winner: 1, reason: "line" });
  });

  test("a full board with no line is a draw", () => {
    // X O X / X O O / O X X
    const s = play("0", "1", "2", "4", "3", "5", "7", "6", "8");
    expect(rules.outcome(s)).toEqual({ winner: null, reason: "full" });
  });

  test("illegal moves throw: taken cell, off board, junk, finished game", () => {
    const s = play("4");
    expect(() => rules.apply(s, "4")).toThrow("ILLEGAL");
    expect(() => rules.apply(s, "9")).toThrow("ILLEGAL");
    expect(() => rules.apply(s, "-1")).toThrow("ILLEGAL");
    expect(() => rules.apply(s, "04")).toThrow("ILLEGAL");
    expect(() => rules.apply(s, "")).toThrow("ILLEGAL");
    const won = play("0", "3", "1", "4", "2");
    expect(() => rules.apply(won, "8")).toThrow("ILLEGAL");
  });

  test("apply never mutates its input", () => {
    const s = play("4");
    const before = rules.encode(s);
    rules.apply(s, "0");
    expect(rules.encode(s)).toBe(before);
  });

  test("encode and decode round-trip", () => {
    for (const s of [play(), play("4"), play("4", "0", "8")]) {
      expect(rules.encode(rules.decode(rules.encode(s)))).toBe(rules.encode(s));
    }
  });

  test("decode refuses what encode could not have produced", () => {
    for (const raw of [
      "",
      "........./",
      "........./2",
      "........../0",
      "X......../0", // X ahead but X to move
      "O......../1", // O ahead
      "XX......./1", // two X, no O
      "XXXOO..../0", // X has a line but it is X's turn
      "XXXOOO.../1", // both have lines
      "XX.OOOX../1", // O line, but O to move again
      "x......../1",
    ]) {
      expect(() => rules.decode(raw), raw).toThrow("BAD_STATE");
    }
  });
});
