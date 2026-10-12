import { Chess } from "chess.js";
import { describe, expect, test } from "vitest";
import {
  FIFTY_MOVE_PLIES,
  inCheck,
  positionHash,
  repetitions,
  rules,
  type ChessState,
} from "./chess";

function play(line: string, from: ChessState = rules.initial(2)) {
  let s = from;
  for (const m of line.split(" ").filter(Boolean)) s = rules.apply(s, m);
  return s;
}

/** A state from a bare FEN, with a history of the right length that never matches. */
function at(fen: string): ChessState {
  const clock = Number(fen.split(" ")[4]);
  return rules.decode(`${fen}|${"AAAAA".repeat(clock)}`);
}

describe("chess", () => {
  test("opens with white's twenty moves, sorted as strings", () => {
    const s = rules.initial(2);
    expect(rules.toMove(s)).toBe(0);
    const legal = rules.legalMoves(s);
    expect(legal).toHaveLength(20);
    expect(legal).toEqual([...legal].sort());
    expect(legal.slice(0, 3)).toEqual(["a2a3", "a2a4", "b1a3"]);
    expect(rules.encode(s)).toBe(
      "rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1|",
    );
  });

  test("castles on both wings, and the rights go with the king", () => {
    const short = play("e2e4 e7e5 g1f3 b8c6 f1c4 g8f6");
    expect(rules.legalMoves(short)).toContain("e1g1");
    const castled = play("e1g1", short);
    expect(castled.fen.split(" ")[0]).toContain("RK1");
    expect(castled.fen.split(" ")[2]).toBe("kq");
    const long = play("d2d4 d7d5 b1c3 g8f6 c1f4 e7e6 d1d2 f8e7 e1c1 e8g8");
    expect(long.fen.split(" ")[0].endsWith("2KR1BNR")).toBe(true);
    expect(long.fen.split(" ")[2]).toBe("-");
    // Through check is not allowed: the f1 square is covered by the c4 bishop.
    const covered = at("4k3/8/8/8/2b5/8/8/4K2R w K - 0 1");
    expect(rules.legalMoves(covered)).not.toContain("e1g1");
  });

  test("en passant: taken when legal, and only then written into the FEN", () => {
    const pushed = play("e2e4 a7a6 e4e5 d7d5");
    expect(pushed.fen.split(" ")[3]).toBe("d6");
    expect(rules.legalMoves(pushed)).toContain("e5d6");
    const taken = play("e5d6", pushed);
    expect(taken.fen.startsWith("rnbqkbnr/1pp1pppp/p2P4/8/")).toBe(true);
    // No pawn beside the pushed one: the field stays empty.
    expect(play("e2e4").fen.split(" ")[3]).toBe("-");
    // A pinned capturer: b5xc6 would open the fifth rank to the rook on h5.
    const pin = at("7k/2p5/8/KP5r/8/8/8/8 b - - 0 1");
    const pushedPast = play("c7c5", pin);
    expect(pushedPast.fen.split(" ")[3]).toBe("-");
    expect(rules.legalMoves(pushedPast)).not.toContain("b5c6");
  });

  test("promotion needs its piece letter, and under-promotion works", () => {
    const s = at("8/4P3/8/8/8/8/k7/4K3 w - - 0 1");
    const legal = rules.legalMoves(s);
    expect(legal.filter((m) => m.startsWith("e7e8"))).toEqual([
      "e7e8b",
      "e7e8n",
      "e7e8q",
      "e7e8r",
    ]);
    expect(() => rules.apply(s, "e7e8")).toThrow("ILLEGAL");
    expect(rules.apply(s, "e7e8n").fen.startsWith("4N3/")).toBe(true);
  });

  test("checkmate names the winner", () => {
    const fool = play("f2f3 e7e5 g2g4 d8h4");
    expect(rules.outcome(fool)).toEqual({ winner: 1, reason: "checkmate" });
    expect(rules.legalMoves(fool)).toEqual([]);
    expect(inCheck(fool)).toBe(true);
    const scholar = play("e2e4 e7e5 d1h5 b8c6 f1c4 g8f6 h5f7");
    expect(rules.outcome(scholar)).toEqual({ winner: 0, reason: "checkmate" });
  });

  test("stalemate, insufficient material and the fifty-move rule draw", () => {
    const loyd = play(
      "e2e3 a7a5 d1h5 a8a6 h5a5 h7h5 h2h4 a6h6 a5c7 f7f6 c7d7 e8f7 d7b7 " +
        "d8d3 b7b8 d3h7 b8c8 f7g6 c8e6",
    );
    expect(rules.outcome(loyd)).toEqual({ winner: null, reason: "stalemate" });

    for (const fen of [
      "8/8/4k3/8/8/3K4/8/8 w - - 0 1", // bare kings
      "8/8/4k3/8/8/3KN3/8/8 w - - 0 1", // a lone knight
      "8/8/4k3/2b5/8/3KB3/8/8 w - - 0 1", // bishops on one colour
    ]) {
      expect(rules.outcome(at(fen))?.reason, fen).toBe("insufficient-material");
    }
    // Bishops on both colours can still mate.
    expect(rules.outcome(at("8/8/4k3/3b4/8/3KB3/8/8 w - - 0 1"))).toBeNull();

    const late = at(`8/8/4k3/8/8/3K4/7R/8 w - - ${FIFTY_MOVE_PLIES - 1} 80`);
    expect(rules.outcome(late)).toBeNull();
    const over = play("h2h3", late);
    expect(rules.outcome(over)).toEqual({
      winner: null,
      reason: "fifty-moves",
    });
  });

  test("threefold repetition draws, counting the opening position", () => {
    const twice = play("g1f3 g8f6 f3g1 f6g8");
    expect(repetitions(twice)).toBe(2);
    expect(rules.outcome(twice)).toBeNull();
    const thrice = play("g1f3 g8f6 f3g1 f6g8", twice);
    expect(repetitions(thrice)).toBe(3);
    expect(rules.outcome(thrice)).toEqual({
      winner: null,
      reason: "repetition",
    });
    expect(rules.legalMoves(thrice)).toEqual([]);
  });

  test("the history resets on a capture or pawn move and stays one hash per ply", () => {
    const s = play("g1f3 g8f6 b1c3");
    expect(s.history).toHaveLength(3);
    expect(s.history[0]).toBe(positionHash(rules.initial(2).fen));
    expect(play("e7e5", s).history).toEqual([]);
    expect(rules.encode(s).split("|")[1]).toHaveLength(15);
  });

  test("illegal moves throw", () => {
    const s = rules.initial(2);
    for (const m of ["", "e2e5", "e7e5", "e2e4q", "E2E4", "e2-e4", "e1g1", "z9z9"]) {
      expect(() => rules.apply(s, m), m).toThrow("ILLEGAL");
    }
    const mated = play("f2f3 e7e5 g2g4 d8h4");
    expect(() => rules.apply(mated, "a2a3")).toThrow("ILLEGAL");
  });

  test("encode and decode round-trip", () => {
    const s = play("e2e4 e7e5 g1f3 b8c6 f1b5 a7a6");
    expect(rules.encode(rules.decode(rules.encode(s)))).toBe(rules.encode(s));
    expect(rules.decode(rules.encode(s))).toEqual(s);
  });

  test("decode refuses what encode could not produce", () => {
    const start = "rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR";
    for (const raw of [
      "",
      `${start} w KQkq - 0 1`, // no history separator
      `${start} w KQkq - 0 1|AAAAA`, // history longer than the clock
      `${start} w KQkq - 1 1|`, // and shorter
      `${start} w KQkq - 0 01|`, // not canonical
      `${start} x KQkq - 0 1|`,
      `${start} w KQkq e6 0 1|`, // no pawn pushed past e6
      "4k3/8/8/8/8/8/8/4K3 w K - 0 1|", // a right with no rook
      "4k3/8/8/8/8/8/8/R3K3 w Q - 0 1|AAAAA|", // two separators
      "3Qk3/8/8/8/8/8/8/4K3 w - - 0 1|", // black in check, white to move
      "8/8/8/8/8/8/8/4K3 w - - 0 1|", // no black king
      `4k3/8/8/8/8/8/8/4K3 w - - 101 60|${"AAAAA".repeat(101)}`,
      "4k3/8/8/8/8/8/8/4K3 w - - 1 1|AAAA!",
    ]) {
      expect(() => rules.decode(raw), raw).toThrow("BAD_STATE");
    }
  });

  test("legal moves match chess.js on a busy middlegame, sorted", () => {
    // Kiwipete: castling both ways, en passant-ready pawns, pins.
    const fen = "r3k2r/p1ppqpb1/bn2pnp1/3PN3/1p2P3/2N2Q1p/PPPBBPPP/R3K2R w KQkq - 0 1";
    const s = at(fen);
    const legal = rules.legalMoves(s);
    expect(legal).toHaveLength(48);
    expect(legal).toEqual(
      new Chess(fen).moves({ verbose: true }).map((m) => m.lan).sort(),
    );
  });
});
