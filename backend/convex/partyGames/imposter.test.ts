import { describe, expect, test } from "vitest";
import { randomFor } from "../games/rng";
import {
  cleanClue,
  CLUE_MS,
  GUESS_MS,
  guessMatches,
  normalizeGuess,
  PASSED,
  REVEAL_MS,
  rules,
  tally,
  VOTE_MS,
  type ImposterState,
} from "./imposter";
import type { ImposterWord } from "./imposterWords";

/**
 * Imposter: the phase flow, the clue order, how ballots are counted (ties
 * and skips accuse nobody), a guess matched in any language with accents
 * ignored, and an imposter who walks out.
 */

const T0 = 5_000_000;

const ELEPHANT: ImposterWord = {
  id: "elephant",
  category: "animals",
  names: {
    en: "Elephant",
    tr: "Fil",
    ar: "فيل",
    es: "Elefante",
    fr: "Éléphant",
    hi: "हाथी",
    ja: "ゾウ",
    ko: "코끼리",
    "pt-br": "Elefante",
    pt: "Elefante",
    sv: "Elefant",
    zh: "大象",
  },
};

/** Four players, seat 2 the imposter, clues in order 1, 2, 3, 0. */
function game(opts: { voice?: boolean } = {}): ImposterState {
  const s = rules.setup(4, randomFor("party:x", "imposter"), opts, T0, "imposter:x");
  return { ...s, word: ELEPHANT, imposter: 2, order: [1, 2, 3, 0] };
}

/** [game] moved on to the vote, every clue given. */
function atVote(): ImposterState {
  let s = rules.onDeadline(game(), T0 + REVEAL_MS);
  for (const seat of [1, 2, 3, 0]) s = rules.act(s, seat, `clue:hint${seat}`, T0);
  expect(s.phase).toBe("vote");
  return s;
}

describe("dealing", () => {
  test("one imposter, one word, a seeded first clue-giver; nothing secret in public", () => {
    const s = rules.setup(5, randomFor("party:y", "imposter"), {}, T0, "imposter:y");
    expect(s.imposter).toBeGreaterThanOrEqual(0);
    expect(s.imposter).toBeLessThan(5);
    expect([...s.order].sort()).toEqual([0, 1, 2, 3, 4]);
    for (let i = 1; i < 5; i++) expect(s.order[i]).toBe((s.order[0] + i) % 5);
    expect(s.phase).toBe("reveal");
    expect(s.deadline).toBe(T0 + REVEAL_MS);

    const pub = rules.publicView(s);
    for (const name of Object.values(s.word.names)) expect(pub).not.toContain(name);
    expect(pub).not.toContain(s.word.id);
    expect(JSON.parse(pub).imposter).toBeNull();
  });

  test("the crew sees the word in every language; the imposter only the category", () => {
    const s = game();
    expect(JSON.parse(rules.privateView(s, 0)!)).toMatchObject({
      role: "crew",
      wordId: "elephant",
      names: ELEPHANT.names,
    });
    const me = JSON.parse(rules.privateView(s, 2)!);
    expect(me).toMatchObject({ role: "imposter", category: "animals", myVote: null });
    expect(me.categoryNames.en).toBe("Animals");
    expect(me.names).toBeUndefined();
    expect(me.wordId).toBeUndefined();
    expect(JSON.stringify(me)).not.toContain("lephant");
    expect(rules.privateView(s, -1)).toBeNull();
  });
});

describe("the phases", () => {
  test("reveal ends when everyone has seen their card, or on the clock", () => {
    let s = game();
    for (const seat of [0, 1, 2]) s = rules.act(s, seat, "seen", T0 + 1);
    expect(s.phase).toBe("reveal");
    expect(rules.phaseKey(s)).toBe("reveal");
    s = rules.act(s, 3, "seen", T0 + 2);
    expect(s.phase).toBe("clues");
    expect(s.deadline).toBe(T0 + 2 + CLUE_MS);

    const timed = rules.onDeadline(game(), T0 + REVEAL_MS);
    expect(timed.phase).toBe("clues");
  });

  test("clues go in order, one each, and a silent player passes", () => {
    let s = rules.onDeadline(game(), T0 + REVEAL_MS);
    expect(rules.turnSeat(s)).toBe(1);
    expect(() => rules.act(s, 2, "clue:big", T0)).toThrow("NOT_YOUR_TURN");
    s = rules.act(s, 1, "clue:  big   ears ", T0 + 100);
    expect(s.clues).toEqual([{ seat: 1, text: "big ears" }]);
    expect(rules.turnSeat(s)).toBe(2);
    s = rules.onDeadline(s, T0 + 100 + CLUE_MS);
    expect(s.clues[1]).toEqual({ seat: 2, text: PASSED, passed: true });
    expect(rules.turnSeat(s)).toBe(3);
    // Clues are public the moment they land.
    expect(JSON.parse(rules.publicView(s)).clues).toHaveLength(2);
    s = rules.act(s, 3, "clue:grey", T0);
    s = rules.act(s, 0, "clue:trunk", T0 + 7);
    expect(s.phase).toBe("vote");
    expect(s.deadline).toBe(T0 + 7 + VOTE_MS);
    expect(rules.turnSeat(s)).toBeNull();
  });

  test("a clue is short, a word or a phrase, and never a link", () => {
    expect(cleanClue("  safari  ")).toBe("safari");
    expect(() => cleanClue("   ")).toThrow("BAD_CLUE");
    expect(() => cleanClue("x".repeat(25))).toThrow("BAD_CLUE");
    expect(cleanClue("x".repeat(24))).toBe("x".repeat(24));
    expect(() => cleanClue("a b c d e")).toThrow("BAD_CLUE");
    expect(() => cleanClue("see example.com")).toThrow("BAD_CLUE");
    expect(() => cleanClue("https://x")).toThrow("BAD_CLUE");
    expect(() => cleanClue("www.zoo")).toThrow("BAD_CLUE");
    expect(cleanClue("Dr. Dolittle")).toBe("Dr. Dolittle");
  });

  test("voice mode: a clue is just done", () => {
    let s = rules.onDeadline(game({ voice: true }), T0 + REVEAL_MS);
    expect(s.voice).toBe(true);
    expect(() => rules.act(s, 1, "clue:trunk", T0)).toThrow("ILLEGAL");
    s = rules.act(s, 1, "done", T0);
    expect(s.clues).toEqual([{ seat: 1, text: "" }]);
  });

  test("everyone voting closes the vote early, and the imposter caught gets a guess", () => {
    let s = atVote();
    s = rules.act(s, 0, "vote:2", T0);
    s = rules.act(s, 1, "vote:2", T0);
    // A ballot can be changed until the vote closes.
    s = rules.act(s, 1, "vote:3", T0);
    s = rules.act(s, 1, "vote:2", T0);
    s = rules.act(s, 2, "vote:0", T0);
    // Ballots are secret while the vote is open: who voted, not for whom.
    const open = JSON.parse(rules.publicView(s));
    expect(open.votes).toBeNull();
    expect(open.voted).toEqual([true, true, true, false]);
    expect(rules.phaseKey(s)).toBe("vote");
    s = rules.act(s, 3, "vote:skip", T0 + 9);
    expect(s.phase).toBe("guess");
    expect(s.accused).toBe(2);
    expect(s.deadline).toBe(T0 + 9 + GUESS_MS);
    expect(rules.turnSeat(s)).toBe(2);
    expect(JSON.parse(rules.publicView(s)).votes).toEqual([2, 2, 0, "skip"]);
    // Still no word in public until it is over.
    expect(rules.publicView(s)).not.toContain("lephant");
    expect(() => rules.act(s, 0, "guess:elephant", T0)).toThrow("NOT_YOUR_TURN");
  });

  test("a vote may not be for yourself or for nobody in particular", () => {
    const s = atVote();
    expect(() => rules.act(s, 0, "vote:0", T0)).toThrow("ILLEGAL");
    expect(() => rules.act(s, 0, "vote:9", T0)).toThrow("ILLEGAL");
    expect(() => rules.act(s, 0, "vote:", T0)).toThrow("ILLEGAL");
  });
});

describe("counting the ballots", () => {
  function voted(votes: (number | null)[]): ImposterState {
    return { ...atVote(), votes };
  }

  test("a tie accuses nobody, and the imposter escapes", () => {
    expect(tally(voted([1, 0, 1, 0])).accused).toBeNull();
    const s = rules.onDeadline(voted([1, 0, 1, 0]), T0);
    expect(rules.outcome(s)).toEqual({ winner: 2, reason: "escaped" });
  });

  test("skips at least matching the leader accuse nobody", () => {
    expect(tally(voted([-1, -1, 0, 0])).accused).toBeNull();
    expect(tally(voted([-1, -1, -1, 2])).accused).toBeNull();
    expect(tally(voted([2, -1, null, 2])).accused).toBe(2);
    expect(tally(voted([null, null, null, null])).accused).toBeNull();
  });

  test("accusing a crew member hands the imposter the win", () => {
    const s = rules.onDeadline(voted([3, 3, 3, null]), T0);
    expect(s.accused).toBe(3);
    expect(rules.outcome(s)).toEqual({ winner: 2, reason: "wrongAccused" });
    const pub = JSON.parse(rules.publicView(s));
    expect(pub.imposter).toBe(2);
    expect(pub.word.id).toBe("elephant");
  });
});

describe("the guess", () => {
  function caught(): ImposterState {
    return rules.onDeadline({ ...atVote(), votes: [2, 2, 0, 2] }, T0);
  }

  test("matches any locale's name, accents and case ignored", () => {
    expect(normalizeGuess("Éléphant!")).toBe("elephant");
    expect(normalizeGuess("FIL")).toBe("fil");
    expect(normalizeGuess("Fıl")).toBe("fil");
    for (const g of ["elephant", "ELEPHANT", "éléphant", "Elefánte", "fil", "大象", " ゾウ "]) {
      expect(guessMatches(ELEPHANT, g), g).toBe(true);
    }
    expect(guessMatches(ELEPHANT, "giraffe")).toBe(false);
    expect(guessMatches(ELEPHANT, "!!!")).toBe(false);
  });

  test("a right guess steals the win; a wrong one or silence loses it", () => {
    const right = rules.act(caught(), 2, "guess:Elefánte", T0);
    expect(rules.outcome(right)).toEqual({ winner: 2, reason: "guessed" });
    const pub = JSON.parse(rules.publicView(right));
    expect(pub).toMatchObject({ phase: "over", result: "imposter", guessCorrect: true });

    const wrong = rules.act(caught(), 2, "guess:giraffe", T0);
    expect(rules.outcome(wrong)).toEqual({ winners: [0, 1, 3], reason: "caught" });

    const silent = rules.onDeadline(caught(), T0 + GUESS_MS);
    expect(rules.outcome(silent)).toEqual({ winners: [0, 1, 3], reason: "caught" });
    expect(() => rules.act(caught(), 2, "guess:   ", T0)).toThrow("BAD_GUESS");
  });

  test("during the guess only the imposter is holding anybody up", () => {
    expect(rules.doneSeats(caught())).toEqual([0, 1, 3]);
  });
});

describe("leaving", () => {
  test("the imposter leaving hands the crew the win", () => {
    const s = rules.forfeit(atVote(), 2, T0);
    expect(rules.outcome(s)).toEqual({ winners: [0, 1, 3], reason: "imposterLeft" });
  });

  test("a crew member leaving on their clue turn passes it on", () => {
    let s = rules.onDeadline(game(), T0 + REVEAL_MS);
    s = rules.forfeit(s, 1, T0 + 50);
    expect(rules.turnSeat(s)).toBe(2);
    expect(s.deadline).toBe(T0 + 50 + CLUE_MS);
    // And a later turn of theirs is skipped, not waited for.
    s = rules.forfeit(s, 0, T0 + 60);
    s = rules.act(s, 2, "clue:a", T0);
    s = rules.act(s, 3, "clue:b", T0);
    expect(s.phase).toBe("vote");
    expect(s.clues.map((c) => c.seat)).toEqual([2, 3]);
  });

  test("in the vote, their ballot and every ballot for them are void", () => {
    let s = atVote();
    s = rules.act(s, 0, "vote:1", T0);
    s = rules.act(s, 2, "vote:3", T0);
    s = rules.forfeit(s, 1, T0);
    expect(s.phase).toBe("vote");
    expect(s.votes).toEqual([null, null, 3, null]);
    s = rules.act(s, 0, "vote:2", T0);
    s = rules.act(s, 3, "vote:2", T0);
    expect(s.phase).toBe("guess");
    expect(() => rules.act(s, 1, "vote:2", T0)).toThrow();
  });

  test("the whole crew leaving leaves the imposter the winner", () => {
    let s = atVote();
    for (const seat of [0, 1, 3]) s = rules.forfeit(s, seat, T0);
    expect(rules.outcome(s)).toEqual({ winner: 2, reason: "left" });
  });
});

test("options: voice is a boolean or nothing", () => {
  expect(rules.parseOptions({ voice: true })).toEqual({ voice: true });
  expect(rules.parseOptions({ puzzle: "zip" })).toEqual({});
  expect(() => rules.parseOptions({ voice: "yes" })).toThrow("BAD_OPTIONS");
});

test("a pause moves the deadline", () => {
  const s = game();
  expect(rules.shift(s, 1234).deadline).toBe(s.deadline! + 1234);
});
