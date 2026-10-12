import { describe, expect, test } from "vitest";
import { randomFor } from "../games/rng";
import {
  countFace,
  mostCommonFace,
  raises,
  rules,
  START_DICE,
  TURN_MS,
  type LiarsDiceState,
} from "./liarsDice";

/**
 * Liar's Dice: the bid ladder, the wild 1s, who a call costs a die, who is
 * out, and what the clock does for a player who lets it run.
 */

const T0 = 1_000_000;

function fresh(seats = 3): LiarsDiceState {
  return rules.setup(seats, randomFor("party:test", "liarsdice"), {}, T0, "liarsdice:test");
}

/** [s] with the dice set by hand and seat [turn] to act, for exact sums. */
function rigged(dice: number[][], turn = 0): LiarsDiceState {
  const s = fresh(dice.length);
  return { ...s, dice, counts: dice.map((d) => d.length), turn };
}

describe("setup", () => {
  test("deals five hidden dice each, reproducibly, with a running clock", () => {
    const a = fresh(4);
    const b = fresh(4);
    expect(a).toEqual(b);
    expect(a.counts).toEqual([5, 5, 5, 5]);
    expect(a.dice.every((d) => d.length === START_DICE)).toBe(true);
    expect(a.dice.flat().every((d) => d >= 1 && d <= 6)).toBe(true);
    expect(a.round).toBe(1);
    expect(a.deadline).toBe(T0 + TURN_MS);
    expect(rules.turnSeat(a)).toBe(a.turn);
  });

  test("the public view carries no dice; each seat sees only its own", () => {
    const s = fresh(3);
    const pub = JSON.parse(rules.publicView(s));
    expect(pub.dice).toBeUndefined();
    expect(JSON.stringify(pub)).not.toContain(JSON.stringify(s.dice));
    for (let seat = 0; seat < 3; seat++) {
      const mine = JSON.parse(rules.privateView(s, seat)!);
      expect(mine.dice).toEqual([...s.dice[seat]].sort((a, b) => a - b));
    }
    expect(rules.privateView(s, 7)).toBeNull();
  });
});

describe("bidding", () => {
  test("a bid must be strictly higher", () => {
    expect(raises(null, 1, 1)).toBe(true);
    expect(raises({ seat: 0, qty: 3, face: 4 }, 4, 2)).toBe(true);
    expect(raises({ seat: 0, qty: 3, face: 4 }, 3, 5)).toBe(true);
    expect(raises({ seat: 0, qty: 3, face: 4 }, 3, 4)).toBe(false);
    expect(raises({ seat: 0, qty: 3, face: 4 }, 2, 6)).toBe(false);

    let s = rigged([[1, 2, 3, 4, 5], [6, 6, 6, 6, 6], [2, 2, 2, 2, 2]]);
    s = rules.act(s, 0, "bid:3:4", T0 + 1);
    expect(s.turn).toBe(1);
    expect(s.deadline).toBe(T0 + 1 + TURN_MS);
    expect(() => rules.act(s, 1, "bid:3:4", T0)).toThrow("ILLEGAL");
    expect(() => rules.act(s, 1, "bid:2:6", T0)).toThrow("ILLEGAL");
    expect(() => rules.act(s, 1, "bid:3:7", T0)).toThrow("ILLEGAL");
    expect(() => rules.act(s, 1, "bid:16:6", T0)).toThrow("ILLEGAL");
    expect(() => rules.act(s, 1, "bid:x:6", T0)).toThrow("ILLEGAL");
    expect(() => rules.act(s, 2, "bid:5:5", T0)).toThrow("NOT_YOUR_TURN");
    s = rules.act(s, 1, "bid:3:5", T0);
    expect(s.bids.map((b) => [b.seat, b.qty, b.face])).toEqual([
      [0, 3, 4],
      [1, 3, 5],
    ]);
  });

  test("liar needs a bid to call", () => {
    const s = rigged([[1], [2]]);
    expect(() => rules.act(s, 0, "liar", T0)).toThrow("ILLEGAL");
  });

  test("the phase key moves with every bid, so a late bid is stale", () => {
    const s = rigged([[1], [2]]);
    const after = rules.act(s, 0, "bid:1:3", T0);
    expect(rules.phaseKey(after)).not.toBe(rules.phaseKey(s));
  });
});

describe("the wild 1s", () => {
  test("count as any face except in a bid on 1s", () => {
    const dice = [[1, 1, 4], [4, 5, 6], [1, 2, 3]];
    expect(countFace(dice, 4)).toBe(5);
    expect(countFace(dice, 1)).toBe(3);
    expect(countFace(dice, 6)).toBe(4);
  });
});

describe("a call", () => {
  test("a bid that holds costs the caller a die, and the caller starts next", () => {
    // Five 4s on the table counting the wild 1s.
    let s = rigged([[1, 1, 4], [4, 5, 6], [1, 2, 3]]);
    s = rules.act(s, 0, "bid:5:4", T0);
    s = rules.act(s, 1, "liar", T0 + 5);
    expect(s.reveal).toMatchObject({ count: 5, holds: true, loser: 1, caller: 1 });
    expect(s.counts).toEqual([3, 2, 3]);
    expect(s.round).toBe(2);
    expect(s.turn).toBe(1);
    expect(s.bids).toEqual([]);
    expect(s.dice.map((d) => d.length)).toEqual([3, 2, 3]);
    expect(s.deadline).toBe(T0 + 5 + TURN_MS);
    // The reveal is public: it is the round that just ended.
    expect(JSON.parse(rules.publicView(s)).reveal.dice).toEqual([
      [1, 1, 4],
      [4, 5, 6],
      [1, 2, 3],
    ]);
  });

  test("a bid that fails costs the bidder a die", () => {
    let s = rigged([[2, 2], [3, 3], [5, 5]]);
    s = rules.act(s, 0, "bid:3:6", T0);
    s = rules.act(s, 1, "liar", T0);
    expect(s.reveal).toMatchObject({ count: 0, holds: false, loser: 0 });
    expect(s.counts).toEqual([1, 2, 2]);
    expect(s.turn).toBe(0);
  });

  test("a last die lost is out; the next one in starts; the last one standing wins", () => {
    let s = rigged([[6], [2, 2], [3]]);
    s = rules.act(s, 0, "bid:2:5", T0);
    s = rules.act(s, 1, "liar", T0); // no 5s: seat 0 loses its only die.
    expect(s.counts).toEqual([0, 2, 1]);
    expect(s.dice[0]).toEqual([]);
    expect(s.turn).toBe(1);
    expect(rules.doneSeats(s)).toEqual([0]);
    expect(() => rules.act(s, 0, "bid:1:2", T0)).toThrow("NOT_YOUR_TURN");

    s = { ...s, dice: [[], [4, 4], [3]] };
    s = rules.act(s, 1, "bid:1:6", T0);
    s = rules.act(s, 2, "liar", T0); // no 6s: seat 1 loses one.
    expect(s.counts).toEqual([0, 1, 1]);
    s = { ...s, dice: [[], [5], [2]], turn: 1 };
    s = rules.act(s, 1, "bid:2:2", T0);
    s = rules.act(s, 2, "liar", T0); // one 2: seat 1 is out.
    expect(rules.outcome(s)).toEqual({ winner: 2, reason: "win" });
    expect(rules.deadline(s)).toBeNull();
    const pub = JSON.parse(rules.publicView(s));
    expect(pub.phase).toBe("over");
    expect(pub.winner).toBe(2);
  });
});

describe("the clock", () => {
  test("with no bid on the table, it bids one of the player's most common face", () => {
    expect(mostCommonFace([2, 5, 5, 3, 2])).toBe(5);
    expect(mostCommonFace([])).toBe(6);
    const s = rigged([[3, 3, 1, 6, 6], [2]], 0);
    const after = rules.onDeadline(s, T0 + TURN_MS);
    expect(after.bids).toEqual([{ seat: 0, qty: 1, face: 6, auto: true }]);
    expect(after.turn).toBe(1);
    expect(after.deadline).toBe(T0 + 2 * TURN_MS);
  });

  test("with a bid on the table, it calls liar", () => {
    let s = rigged([[2], [3]]);
    s = rules.act(s, 0, "bid:2:5", T0);
    const after = rules.onDeadline(s, T0 + TURN_MS);
    expect(after.reveal).toMatchObject({ caller: 1, loser: 0, auto: true });
  });

  test("a pause moves the deadline and nothing else", () => {
    const s = fresh();
    const moved = rules.shift(s, 30_000);
    expect(moved.deadline).toBe(s.deadline! + 30_000);
    expect({ ...moved, deadline: s.deadline }).toEqual(s);
  });
});

describe("leaving", () => {
  test("a player who leaves is out, and the round is re-dealt", () => {
    let s = rigged([[1, 2], [3, 4], [5, 6]]);
    s = rules.act(s, 0, "bid:2:3", T0);
    s = rules.forfeit(s, 1, T0 + 10);
    expect(s.counts).toEqual([2, 0, 2]);
    expect(s.left).toEqual([false, true, false]);
    expect(s.bids).toEqual([]);
    expect(s.round).toBe(2);
    // It was the leaver's turn; the next one in takes it.
    expect(s.turn).toBe(2);
    expect(s.deadline).toBe(T0 + 10 + TURN_MS);
  });

  test("the last one at the table wins", () => {
    const s = rules.forfeit(rigged([[1], [2]]), 0, T0);
    expect(rules.outcome(s)).toEqual({ winner: 1, reason: "left" });
  });

  test("someone already out of dice leaving changes nothing in play", () => {
    const s = rigged([[], [2, 3], [4]], 1);
    const after = rules.forfeit(s, 0, T0);
    expect(after.dice).toEqual(s.dice);
    expect(after.round).toBe(s.round);
  });
});

test("encode and decode round-trip; garbage is refused", () => {
  const s = fresh();
  expect(rules.decode(rules.encode(s))).toEqual(s);
  expect(() => rules.decode("nope")).toThrow("BAD_STATE");
  expect(() => rules.decode('{"game":"race"}')).toThrow("BAD_STATE");
});
