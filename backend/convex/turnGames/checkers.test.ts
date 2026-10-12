import { describe, expect, test } from "vitest";
import { CheckersState, rules } from "./checkers";

/**
 * Positions are built from PDN square numbers, the way a checkers book prints
 * them, so a failing test reads like the diagram it came from.
 */
function position(
  pieces: Record<number, string>,
  turn = 0,
): CheckersState {
  const board = new Array(32).fill(".");
  for (const [sq, p] of Object.entries(pieces)) board[Number(sq) - 1] = p;
  // Round-trip through the wire so every test position is one decode accepts.
  const kings = board
    .map((p, i) => (p === "B" ? i : -1))
    .filter((i) => i >= 0)
    .concat(board.map((p, i) => (p === "W" ? i : -1)).filter((i) => i >= 0));
  const key = kings.map((i) => "0123456789abcdefghijklmnopqrstuv"[i]).join("");
  return rules.decode(`${board.join("")}|${turn}|0|${key}`);
}

function play(state: CheckersState, moves: string[]): CheckersState {
  return moves.reduce((s, m) => rules.apply(s, m), state);
}

describe("checkers", () => {
  test("the opening has the seven book moves, dark first", () => {
    const s = rules.initial(2);
    expect(rules.toMove(s)).toBe(0);
    expect(rules.legalMoves(s)).toEqual([
      "9-13", "9-14", "10-14", "10-15", "11-15", "11-16", "12-16",
    ]);
    const after = rules.apply(s, "11-15");
    expect(rules.toMove(after)).toBe(1);
    expect(rules.legalMoves(after)).toEqual([
      "21-17", "22-17", "22-18", "23-18", "23-19", "24-19", "24-20",
    ]);
  });

  test("a capture is forced over any quiet move", () => {
    const s = position({ 1: "b", 15: "b", 18: "w" });
    expect(rules.legalMoves(s)).toEqual(["15x22"]);
    expect(() => rules.apply(s, "1-5")).toThrow("ILLEGAL");
    const after = rules.apply(s, "15x22");
    expect(after.board[17]).toBe(".");
    expect(after.board[21]).toBe("b");
  });

  test("a multi-jump runs to the end, but either branch may be chosen", () => {
    const s = position({ 6: "b", 10: "w", 18: "w", 19: "w" });
    expect(rules.legalMoves(s)).toEqual(["6x15x22", "6x15x24"]);
    expect(() => rules.apply(s, "6x15")).toThrow("ILLEGAL");
    const after = rules.apply(s, "6x15x24");
    expect(after.board[9]).toBe(".");
    expect(after.board[18]).toBe(".");
    expect(after.board[17]).toBe("w");
    expect(after.board[23]).toBe("b");
  });

  test("crowning ends the move, even with a king's jump on offer", () => {
    const s = position({ 22: "b", 26: "w", 27: "w", 1: "W" });
    expect(rules.legalMoves(s)).toEqual(["22x31"]);
    const after = rules.apply(s, "22x31");
    expect(after.board[30]).toBe("B");
    expect(after.board[26]).toBe("w");
    expect(rules.toMove(after)).toBe(1);
  });

  test("kings step backwards, men never do", () => {
    const s = position({ 14: "B", 18: "b" });
    expect(rules.legalMoves(s)).toEqual([
      "14-9", "14-10", "14-17", "18-22", "18-23",
    ]);
  });

  test("the side with no move loses", () => {
    expect(rules.outcome(position({ 5: "b", 9: "w", 14: "w" }))).toEqual({
      winner: 1,
      reason: "no-moves",
    });
    expect(rules.outcome(position({ 20: "w" }, 0))).toEqual({
      winner: 1,
      reason: "no-moves",
    });
    expect(rules.legalMoves(position({ 20: "w" }, 0))).toEqual([]);
  });

  test("threefold repetition is a draw", () => {
    const start = position({ 1: "B", 32: "W" });
    const shuffle = ["1-5", "32-28", "5-1", "28-32"];
    const twice = play(start, shuffle);
    expect(rules.outcome(twice)).toBeNull();
    const thrice = play(twice, shuffle);
    expect(rules.outcome(thrice)).toEqual({
      winner: null,
      reason: "repetition",
    });
    expect(rules.legalMoves(thrice)).toEqual([]);
    expect(() => rules.apply(thrice, "1-5")).toThrow("ILLEGAL");
  });

  test("80 plies with no capture and no man move is a draw", () => {
    // 78 quiet plies already behind it, all of them different positions.
    const board = "B..............................W";
    const past: string[] = [];
    for (let i = 0; past.length < 78; i++) {
      past.push("abcdefghijklmnopqrstu"[i % 21] + "123456789"[Math.floor(i / 21)]);
    }
    const s = rules.decode(`${board}|0|78|${past.join("")}0v`);
    expect(rules.outcome(s)).toBeNull();
    const at79 = rules.apply(s, "1-5");
    expect(at79.quiet).toBe(79);
    expect(rules.outcome(at79)).toBeNull();
    const at80 = rules.apply(at79, "32-28");
    expect(at80.quiet).toBe(80);
    expect(rules.outcome(at80)).toEqual({
      winner: null,
      reason: "move-limit",
    });
    expect(rules.legalMoves(at80)).toEqual([]);
    expect(rules.decode(rules.encode(at80))).toEqual(at80);
  });

  test("a man move resets the quiet count and the history", () => {
    let s = position({ 1: "B", 32: "W", 12: "b", 21: "w" });
    s = play(s, ["1-5", "32-28"]);
    expect(s.quiet).toBe(2);
    expect(s.history.length).toBe(3);
    s = rules.apply(s, "12-16");
    expect(s.quiet).toBe(0);
    expect(s.history.length).toBe(1);
  });

  test("encode and decode round-trip", () => {
    let s = rules.initial(2);
    expect(rules.encode(s)).toBe(
      "bbbbbbbbbbbb........wwwwwwwwwwww|0|0|",
    );
    for (const m of ["11-15", "22-18", "15x22", "25x18", "8-11"]) {
      s = rules.apply(s, m);
      expect(rules.decode(rules.encode(s))).toEqual(s);
    }
    const kings = play(position({ 1: "B", 32: "W" }), ["1-5", "32-28"]);
    expect(rules.encode(kings)).toBe(
      "....B......................W....|0|2|0v4v4r",
    );
    expect(rules.decode(rules.encode(kings))).toEqual(kings);
  });

  test("decode rejects what encode could not produce", () => {
    const good = rules.encode(rules.initial(2));
    for (const raw of [
      "",
      good + "|",
      good.replace("|0|0|", "|2|0|"),
      good.replace("|0|0|", "|0|1|"),
      good.replace("b", "x"),
      "w" + good.slice(1),
      "...............................b|0|0|",
      "B..............................W|0|0|0",
      "B..............................W|0|0|v0",
      "B..............................W|0|81|" + "0v".repeat(82),
    ]) {
      expect(() => rules.decode(raw), raw).toThrow("BAD_STATE");
    }
  });

  test("illegal moves throw", () => {
    const s = rules.initial(2);
    for (const m of ["11-14", "22-18", "", "11x18", "11-15-19", "nope"]) {
      expect(() => rules.apply(s, m), m).toThrow("ILLEGAL");
    }
    expect(() => rules.initial(3)).toThrow();
  });
});
