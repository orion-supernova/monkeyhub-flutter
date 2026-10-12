import { describe, expect, test } from "vitest";
import { COLS, ROWS, WINDOWS, rules, winningCells } from "./connectFour";

function play(...moves: (string | number)[]) {
  let s = rules.initial(2);
  for (const m of moves) s = rules.apply(s, String(m));
  return s;
}

describe("connect four", () => {
  test("opens empty, X to move, every column legal", () => {
    const s = rules.initial(2);
    expect(rules.encode(s)).toBe(`${".".repeat(42)}/0`);
    expect(rules.legalMoves(s)).toEqual(["0", "1", "2", "3", "4", "5", "6"]);
  });

  test("there are 69 windows of four", () => {
    expect(WINDOWS.length).toBe(69);
  });

  test("discs fall to the lowest empty row of their column", () => {
    const s = play(3, 3);
    expect(s.cells[(ROWS - 1) * COLS + 3]).toBe("X");
    expect(s.cells[(ROWS - 2) * COLS + 3]).toBe("O");
    expect(rules.toMove(s)).toBe(0);
  });

  test("a full column drops out of the legal list", () => {
    const s = play(0, 0, 0, 0, 0, 0);
    expect(rules.legalMoves(s)).toEqual(["1", "2", "3", "4", "5", "6"]);
    expect(() => rules.apply(s, "0")).toThrow("ILLEGAL");
  });

  test("horizontal, vertical and both diagonals win", () => {
    expect(rules.outcome(play(0, 0, 1, 1, 2, 2, 3))).toEqual({
      winner: 0,
      reason: "four",
    });
    expect(rules.outcome(play(0, 1, 0, 1, 0, 1, 0))?.winner).toBe(0);
    // Rising diagonal for X: (5,0) (4,1) (3,2) (2,3).
    const rising = play(0, 1, 1, 2, 2, 3, 2, 3, 3, 6, 3);
    expect(rules.outcome(rising)?.winner).toBe(0);
    expect(winningCells(rising)).toEqual([17, 23, 29, 35]);
    // The mirror image: a falling diagonal (2,3) (3,4) (4,5) (5,6).
    const falling = play(6, 5, 5, 4, 4, 3, 4, 3, 3, 0, 3);
    expect(rules.outcome(falling)?.winner).toBe(0);
    expect(winningCells(falling)).toEqual([17, 25, 33, 41]);
    // And O wins too: a column, while X's three below it stays three.
    expect(rules.outcome(play(0, 1, 0, 1, 0, 1, 2, 1))).toEqual({
      winner: 1,
      reason: "four",
    });
  });

  test("a full board with no four is a draw", () => {
    // Columns filled in pairs, shifted every two columns, never line up.
    const order = [0, 1, 0, 1, 0, 1, 1, 0, 1, 0, 1, 0, 2, 3, 2, 3, 2, 3, 3, 2,
      3, 2, 3, 2, 4, 5, 4, 5, 4, 5, 5, 4, 5, 4, 5, 4, 6, 6, 6, 6, 6, 6];
    const s = play(...order);
    expect(rules.outcome(s)).toEqual({ winner: null, reason: "full" });
    expect(rules.legalMoves(s)).toEqual([]);
  });

  test("illegal moves throw", () => {
    const s = play(3);
    for (const m of ["7", "-1", "03", "", "x", "3.0"]) {
      expect(() => rules.apply(s, m), m).toThrow("ILLEGAL");
    }
    const won = play(0, 0, 1, 1, 2, 2, 3);
    expect(() => rules.apply(won, "4")).toThrow("ILLEGAL");
  });

  test("encode and decode round-trip", () => {
    const s = play(3, 3, 2, 4, 4);
    expect(rules.encode(rules.decode(rules.encode(s)))).toBe(rules.encode(s));
  });

  test("decode refuses impossible boards", () => {
    const empty = ".".repeat(42);
    const floating = "X" + empty.slice(1);
    const bottom = (row: string) => empty.slice(0, 35) + row;
    for (const raw of [
      "",
      `${empty}/2`,
      `${empty}0`,
      `${floating}/1`,
      `${bottom("X......")}/0`,
      `${bottom("XXXXOOO")}/0`, // X four, but X to move
      `${empty.slice(0, 28)}OOOO...${"XXXX.XX"}/0`, // both have fours
    ]) {
      expect(() => rules.decode(raw), raw).toThrow("BAD_STATE");
    }
  });
});
