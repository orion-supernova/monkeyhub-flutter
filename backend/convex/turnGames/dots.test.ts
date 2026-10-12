import { describe, expect, test } from "vitest";
import { mulberry32 } from "../games/rng";
import { boxSides, DotsState, initialSized, lineBoxes, rules } from "./dots";

/**
 * Small boards keep these readable. On 2 x 2: horizontals 0–5 (rows of two),
 * verticals 6–11 (rows of three); box 0 is {0, 2, 6, 7}, box 1 {1, 3, 7, 8}.
 */

function play(state: DotsState, moves: number[]): DotsState {
  return moves.reduce((s, m) => rules.apply(s, String(m)), state);
}

describe("dots", () => {
  test("line numbering: horizontals first, then verticals", () => {
    expect(boxSides(2, 2, 0, 0)).toEqual([0, 2, 6, 7]);
    expect(boxSides(2, 2, 1, 1)).toEqual([3, 5, 10, 11]);
    expect(lineBoxes(2, 2, 7)).toEqual([0, 1]);
    expect(lineBoxes(2, 2, 0)).toEqual([0]);
    expect(lineBoxes(2, 2, 4)).toEqual([2]);
    const s = rules.initial(2);
    expect(s.rows).toBe(4);
    expect(s.cols).toBe(4);
    expect(rules.legalMoves(s)).toEqual(
      Array.from({ length: 40 }, (_, i) => String(i)),
    );
  });

  test("closing a box scores it and moves again", () => {
    let s = play(initialSized(2, 2, 2), [0, 2, 6]);
    expect(rules.toMove(s)).toBe(1);
    s = rules.apply(s, "7");
    expect(s.owners[0]).toBe(1);
    expect(s.scores).toEqual([0, 1]);
    expect(rules.toMove(s)).toBe(1);
    s = rules.apply(s, "11");
    expect(rules.toMove(s)).toBe(0);
  });

  test("one line can close two boxes", () => {
    let s = play(initialSized(2, 2, 2), [0, 2, 6, 1, 3, 8]);
    expect(rules.toMove(s)).toBe(0);
    s = rules.apply(s, "7");
    expect(s.owners.slice(0, 2)).toEqual([0, 0]);
    expect(s.scores).toEqual([2, 0]);
    expect(rules.toMove(s)).toBe(0);
  });

  test("the game ends on the last line, most boxes wins", () => {
    const s = play(initialSized(2, 1, 1), [0, 1, 2, 3]);
    expect(rules.outcome(s)).toEqual({ winner: 1, reason: "most-boxes" });
    expect(rules.legalMoves(s)).toEqual([]);
    expect(() => rules.apply(s, "0")).toThrow("ILLEGAL");
  });

  test("a tie for first is a draw, with any number of seats", () => {
    // 1 x 2: box 0 taken by seat 0, box 1 one line (6) from closed.
    const two = rules.decode("1x2|1111110|0.|1|1,0");
    expect(rules.outcome(two)).toBeNull();
    expect(rules.outcome(rules.apply(two, "6"))).toEqual({
      winner: null,
      reason: "tie",
    });
    const three = rules.decode("1x2|1111110|0.|2|1,0,0");
    const done = rules.apply(three, "6");
    expect(done.scores).toEqual([1, 0, 1]);
    expect(rules.outcome(done)).toEqual({ winner: null, reason: "tie" });
    const solo = rules.apply(rules.decode("1x2|1111110|0.|0|1,0,0,0"), "6");
    expect(rules.outcome(solo)).toEqual({ winner: 0, reason: "most-boxes" });
  });

  test("three and four seats rotate in order", () => {
    for (const seats of [3, 4]) {
      let s = rules.initial(seats);
      const order: number[] = [];
      // Lines 0..7 are the top two rows of horizontals: no box closes.
      for (let i = 0; i < 8; i++) {
        order.push(rules.toMove(s));
        s = rules.apply(s, String(i));
      }
      expect(order).toEqual([0, 1, 2, 3, 4, 5, 6, 7].map((i) => i % seats));
    }
    expect(() => rules.initial(1)).toThrow();
    expect(() => rules.initial(5)).toThrow();
  });

  test("random playouts score every box exactly once", () => {
    const rand = mulberry32(7);
    for (const seats of [2, 3, 4]) {
      let s = rules.initial(seats);
      while (rules.outcome(s) === null) {
        const legal = rules.legalMoves(s);
        s = rules.apply(s, legal[Math.floor(rand() * legal.length)]);
        expect(rules.decode(rules.encode(s))).toEqual(s);
      }
      expect(s.scores.reduce((a, b) => a + b, 0)).toBe(16);
      expect(s.owners.every((o) => o >= 0 && o < seats)).toBe(true);
    }
  });

  test("encode and decode round-trip", () => {
    const s = play(initialSized(3, 2, 2), [0, 2, 6, 7]);
    expect(rules.encode(s)).toBe("2x2|101000110000|0...|0|1,0,0");
    expect(rules.decode(rules.encode(s))).toEqual(s);
    expect(rules.encode(rules.initial(2))).toBe(
      `4x4|${"0".repeat(40)}|${".".repeat(16)}|0|0,0`,
    );
  });

  test("decode rejects what encode could not produce", () => {
    for (const raw of [
      "",
      "2x2|101000110000|2...|2|0,0,1|",
      "2x2|10100011000|2...|2|0,0,1",
      "2x2|101000110000|....|2|0,0,1",
      "2x2|101000110000|2...|2|0,0,0",
      "2x2|101000110000|1...|2|1,0,0",
      "2x2|101000110000|2...|3|0,0,1",
      "2x2|101000110000|2...|2|1",
      "2x2|000000000000|....|0|0,0,0,0,0",
      "0x2|0000000|..|0|0,0",
      "9x9|0|.|0|0,0",
      "2x2|101000110000|3...|2|0,0,1",
    ]) {
      expect(() => rules.decode(raw), raw).toThrow("BAD_STATE");
    }
  });

  test("illegal moves throw", () => {
    const s = play(rules.initial(2), [5]);
    for (const m of ["5", "40", "-1", "", "01", "1.0", "x"]) {
      expect(() => rules.apply(s, m), m).toThrow("ILLEGAL");
    }
  });
});
