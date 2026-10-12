import {
  IMPOSTER_CATEGORY_NAMES,
  IMPOSTER_WORDS,
  type ImposterWord,
} from "./imposterWords";
import {
  decodeJson,
  illegal,
  type PartyOptions,
  type PartyRules,
} from "./types";

/**
 * IMPOSTER, for 3 to 8: a Spyfall-lite that fits in a chat.
 *
 * Everyone but one player is dealt the same secret word. The odd one out,
 * the imposter, is told only its category. Each player gives one clue in turn;
 * the crew wants to prove they know the word without handing it to the
 * imposter, and the imposter wants to blend in. Then everyone votes.
 *
 * ## Phases
 *
 *  1. `reveal` ([REVEAL_MS]): everyone looks at their card. Ends early once
 *     every player still in has tapped `seen`.
 *  2. `clues`: in [order], one clue each, [CLUE_MS] apiece. Clues are public
 *     the moment they land. A player whose time runs out has passed. With
 *     `voice` set at create time the clues are spoken on the room's call and
 *     the action is just `done`.
 *  3. `vote` ([VOTE_MS]): each player votes for somebody else, or skips. Ends
 *     early once everyone has voted. One seat with strictly more votes than
 *     any other seat AND than the skips is accused; a tie, a skip majority, or
 *     no votes at all accuses nobody, and the imposter slips away.
 *  4. `guess` ([GUESS_MS]), only when the accused IS the imposter: one last
 *     chance. Naming the word (in any app language, accents and case ignored)
 *     steals the win; anything else, or silence, and the crew wins.
 *  5. `over`. The word and the imposter are revealed in the public view.
 *
 * Accusing a crew member ends the game at once with the imposter winning.
 *
 * ## What is secret
 *
 * The word and the imposter's seat live only in the hidden state until
 * `over`. One thing leaks by construction: the `guess` phase only happens when
 * the accused is the imposter, so reaching it tells the table who it was. That
 * is the game's own reveal moment, not a leak in the code.
 *
 * Ballots are secret while the vote is open (the board shows WHO has voted,
 * not for whom) and published with the result.
 *
 * ## Action tokens
 *
 *  * `seen`: in `reveal`.
 *  * `clue:<text>`: in `clues`, on your turn; 1 to [MAX_CLUE] characters
 *    once trimmed, at most [MAX_CLUE_WORDS] words, no links. `done` (or an
 *    empty `clue:`) in voice mode.
 *  * `vote:<seat>` | `vote:skip`: in `vote`. A vote may be changed until the
 *    vote closes.
 *  * `guess:<text>`: in `guess`, the imposter only.
 */

export const REVEAL_MS = 12_000;
export const CLUE_MS = 40_000;
export const VOTE_MS = 40_000;
export const GUESS_MS = 30_000;
export const MAX_CLUE = 24;
export const MAX_CLUE_WORDS = 4;
export const MAX_GUESS = 48;
/** The clue recorded for a player whose time ran out. */
export const PASSED = "(passed)";
/** A ballot for nobody. */
export const SKIP = -1;

export type Clue = { seat: number; text: string; passed?: boolean };

export type ImposterPhase = "reveal" | "clues" | "vote" | "guess" | "over";

export type ImposterState = {
  game: "imposter";
  n: number;
  voice: boolean;
  /** The whole entry, copied in so a later word-list edit cannot orphan it. SECRET. */
  word: ImposterWord;
  /** SECRET until `over`. */
  imposter: number;
  phase: ImposterPhase;
  deadline: number | null;
  seen: boolean[];
  /** Clue order: every seat, rotated to start at a seeded random seat. */
  order: number[];
  /** Index into [order] of the seat giving its clue. */
  clueIdx: number;
  clues: Clue[];
  /** Per seat: the seat voted for, [SKIP], or null. SECRET until counted. */
  votes: (number | null)[];
  left: boolean[];
  accused: number | null;
  guess: string | null;
  guessCorrect: boolean | null;
  result: "imposter" | "crew" | null;
  /**
   * "escaped" (nobody accused), "wrongAccused" (a crew member was), "guessed"
   * (caught, then named the word), "caught" (caught, and did not),
   * "imposterLeft", "left" (the crew all left).
   */
  endReason: string | null;
};

// ── Matching ────────────────────────────────────────────────────────────────

/**
 * A guess or a word reduced to what a person means by it: no accents, no
 * case, no spaces or punctuation. "Éléphant", "elephant" and "ele-phant" are
 * one word; so are Turkish "Fıl" and "fil".
 */
export function normalizeGuess(text: string): string {
  return text
    .normalize("NFKD")
    .replace(/\p{M}+/gu, "")
    .toLowerCase()
    .replace(/ı/g, "i")
    .replace(/ß/g, "ss")
    .replace(/[^\p{L}\p{N}]+/gu, "");
}

/** Whether [guess] names [word] in any of its locales. */
export function guessMatches(word: ImposterWord, guess: string): boolean {
  const g = normalizeGuess(guess);
  if (!g) return false;
  const names = Object.values(word.names);
  return names.some((name) => normalizeGuess(name) === g);
}

const URLISH =
  /(https?:\/\/|www\.)|[\p{L}\p{N}-]+\.(com|net|org|io|app|co|me|ly|gg|xyz|tv|dev|info|biz|link)\b/iu;

/** The clue as stored, or a thrown `BAD_CLUE`. */
export function cleanClue(raw: string): string {
  const text = raw.replace(/\s+/g, " ").trim();
  const len = [...text].length;
  if (len < 1 || len > MAX_CLUE) illegal("BAD_CLUE");
  if (text.split(" ").length > MAX_CLUE_WORDS) illegal("BAD_CLUE");
  if (URLISH.test(text)) illegal("BAD_CLUE");
  return text;
}

// ── Flow ────────────────────────────────────────────────────────────────────

/** The category's label in every locale, for the client to pick its own. */
function categoryNames(category: string): Record<string, string> | null {
  return IMPOSTER_CATEGORY_NAMES[category] ?? null;
}

function living(s: ImposterState): number[] {
  const out: number[] = [];
  for (let i = 0; i < s.n; i++) if (!s.left[i]) out.push(i);
  return out;
}

function end(
  s: ImposterState,
  result: "imposter" | "crew",
  reason: string,
): ImposterState {
  return { ...s, phase: "over", deadline: null, result, endReason: reason };
}

/** The first index in [order] at or after [from] whose seat still owes a clue. */
function nextClueIdx(s: ImposterState, from: number): number {
  for (let i = from; i < s.order.length; i++) {
    const seat = s.order[i];
    if (!s.left[seat] && !s.clues.some((c) => c.seat === seat)) return i;
  }
  return -1;
}

/** Moves to the clue at or after [from], or on to the vote. */
function toClue(s: ImposterState, from: number, now: number): ImposterState {
  const idx = nextClueIdx(s, from);
  if (idx < 0) {
    return {
      ...s,
      phase: "vote",
      clueIdx: s.order.length,
      votes: Array(s.n).fill(null),
      deadline: now + VOTE_MS,
    };
  }
  return { ...s, phase: "clues", clueIdx: idx, deadline: now + CLUE_MS };
}

function giveClue(s: ImposterState, text: string, passed: boolean, now: number) {
  const seat = s.order[s.clueIdx];
  const clue: Clue = passed ? { seat, text: PASSED, passed: true } : { seat, text };
  return toClue({ ...s, clues: [...s.clues, clue] }, s.clueIdx + 1, now);
}

/** Counts the ballots. Exported for tests. */
export function tally(s: ImposterState): {
  counts: number[];
  skips: number;
  accused: number | null;
} {
  const counts: number[] = Array(s.n).fill(0);
  let skips = 0;
  for (let i = 0; i < s.n; i++) {
    const v = s.votes[i];
    if (s.left[i] || v === null || v === undefined) continue;
    if (v === SKIP) skips++;
    else if (!s.left[v]) counts[v]++;
  }
  const top = Math.max(0, ...counts);
  const leaders = counts.filter((c) => c === top).length;
  const accused =
    top > 0 && leaders === 1 && top > skips ? counts.indexOf(top) : null;
  return { counts, skips, accused };
}

function closeVote(s: ImposterState, now: number): ImposterState {
  const { accused } = tally(s);
  const after = { ...s, accused };
  if (accused === null) return end(after, "imposter", "escaped");
  if (accused !== s.imposter) return end(after, "imposter", "wrongAccused");
  return { ...after, phase: "guess", deadline: now + GUESS_MS };
}

function allVoted(s: ImposterState): boolean {
  return living(s).every((i) => s.votes[i] !== null && s.votes[i] !== undefined);
}

function allSeen(s: ImposterState): boolean {
  return living(s).every((i) => s.seen[i]);
}

export const rules: PartyRules<ImposterState> = {
  id: "imposter",
  minSeats: 3,
  maxSeats: 8,

  parseOptions(raw) {
    const o = (raw ?? {}) as Record<string, unknown>;
    if (o.voice !== undefined && typeof o.voice !== "boolean") {
      illegal("BAD_OPTIONS");
    }
    return o.voice === true ? { voice: true } : {};
  },

  setup(seats, rand, options: PartyOptions, now) {
    if (IMPOSTER_WORDS.length === 0) throw new Error("NO_WORDS");
    const word = IMPOSTER_WORDS[Math.floor(rand() * IMPOSTER_WORDS.length)];
    const imposter = Math.floor(rand() * seats);
    const start = Math.floor(rand() * seats);
    return {
      game: "imposter",
      n: seats,
      voice: options.voice === true,
      word,
      imposter,
      phase: "reveal",
      deadline: now + REVEAL_MS,
      seen: Array(seats).fill(false),
      order: Array.from({ length: seats }, (_, i) => (start + i) % seats),
      clueIdx: 0,
      clues: [],
      votes: Array(seats).fill(null),
      left: Array(seats).fill(false),
      accused: null,
      guess: null,
      guessCorrect: null,
      result: null,
      endReason: null,
    };
  },

  act(s, seat, action, now) {
    if (s.phase === "over" || s.left[seat]) illegal();
    switch (s.phase) {
      case "reveal": {
        if (action !== "seen") illegal();
        if (s.seen[seat]) return s;
        const after = { ...s, seen: s.seen.map((v, i) => v || i === seat) };
        return allSeen(after) ? toClue(after, 0, now) : after;
      }
      case "clues": {
        if (s.order[s.clueIdx] !== seat) illegal("NOT_YOUR_TURN");
        if (s.voice) {
          if (action !== "done" && action !== "clue:") illegal();
          return giveClue(s, "", false, now);
        }
        if (!action.startsWith("clue:")) illegal();
        return giveClue(s, cleanClue(action.slice(5)), false, now);
      }
      case "vote": {
        const m = /^vote:(skip|\d{1,2})$/.exec(action);
        if (!m) illegal();
        const target = m[1] === "skip" ? SKIP : Number(m[1]);
        if (target !== SKIP) {
          if (target >= s.n || target === seat || s.left[target]) illegal();
        }
        const after = {
          ...s,
          votes: s.votes.map((v, i) => (i === seat ? target : v)),
        };
        return allVoted(after) ? closeVote(after, now) : after;
      }
      case "guess": {
        if (seat !== s.imposter) illegal("NOT_YOUR_TURN");
        if (!action.startsWith("guess:")) illegal();
        const text = action.slice(6).replace(/\s+/g, " ").trim();
        const len = [...text].length;
        if (len < 1 || len > MAX_GUESS) illegal("BAD_GUESS");
        const correct = guessMatches(s.word, text);
        return end(
          { ...s, guess: text, guessCorrect: correct },
          correct ? "imposter" : "crew",
          correct ? "guessed" : "caught",
        );
      }
    }
    return illegal();
  },

  deadline(s) {
    return s.phase === "over" ? null : s.deadline;
  },

  onDeadline(s, now) {
    switch (s.phase) {
      case "reveal":
        return toClue(s, 0, now);
      case "clues":
        return giveClue(s, PASSED, true, now);
      case "vote":
        return closeVote(s, now);
      case "guess":
        return end({ ...s, guessCorrect: false }, "crew", "caught");
      default:
        return s;
    }
  },

  forfeit(s, seat, now) {
    if (s.phase === "over" || s.left[seat]) return s;
    let after: ImposterState = {
      ...s,
      left: s.left.map((l, i) => l || i === seat),
    };
    if (seat === s.imposter) return end(after, "crew", "imposterLeft");
    if (living(after).every((i) => i === s.imposter)) {
      return end(after, "imposter", "left");
    }
    switch (s.phase) {
      case "reveal":
        return allSeen(after) ? toClue(after, 0, now) : after;
      case "clues":
        // Their turn: on to the next. Otherwise [nextClueIdx] skips them.
        return s.order[s.clueIdx] === seat ? toClue(after, s.clueIdx, now) : after;
      case "vote": {
        // Their ballot goes with them, and so does every ballot cast FOR
        // them: those voters get to vote again before the clock runs out.
        after = {
          ...after,
          votes: after.votes.map((v, i) => (i === seat || v === seat ? null : v)),
        };
        return allVoted(after) ? closeVote(after, now) : after;
      }
      default:
        return after;
    }
  },

  shift(s, ms) {
    return s.deadline === null ? s : { ...s, deadline: s.deadline + ms };
  },

  phaseKey(s) {
    return s.phase === "clues" ? `clues:${s.clueIdx}` : s.phase;
  },

  turnSeat(s) {
    if (s.phase === "clues") return s.order[s.clueIdx] ?? null;
    if (s.phase === "guess") return s.imposter;
    return null;
  },

  doneSeats(s) {
    const out: number[] = [];
    for (let i = 0; i < s.n; i++) {
      // Only the imposter has anything left to do during the guess.
      if (s.left[i] || (s.phase === "guess" && i !== s.imposter)) out.push(i);
    }
    return out;
  },

  publicView(s) {
    const counted = s.phase === "guess" || s.phase === "over";
    const over = s.phase === "over";
    const t = counted ? tally(s) : null;
    return JSON.stringify({
      game: "imposter",
      phase: s.phase,
      deadline: rules.deadline(s),
      voice: s.voice,
      order: s.order,
      turn: s.phase === "clues" ? s.order[s.clueIdx] : null,
      clues: s.clues,
      seen: s.seen,
      voted: s.votes.map((v) => v !== null && v !== undefined),
      left: s.left,
      votes: counted ? s.votes.map((v) => (v === SKIP ? "skip" : v)) : null,
      voteCounts: t ? t.counts : null,
      skips: t ? t.skips : null,
      accused: counted ? s.accused : null,
      result: s.result,
      reason: s.endReason,
      imposter: over ? s.imposter : null,
      word: over
        ? {
            id: s.word.id,
            category: s.word.category,
            categoryNames: categoryNames(s.word.category),
            names: s.word.names,
          }
        : null,
      guess: over ? s.guess : null,
      guessCorrect: over ? s.guessCorrect : null,
    });
  },

  privateView(s, seat) {
    if (seat < 0 || seat >= s.n) return null;
    const v = s.votes[seat];
    const myVote = v === null || v === undefined ? null : v === SKIP ? "skip" : v;
    if (seat === s.imposter) {
      return JSON.stringify({
        role: "imposter",
        category: s.word.category,
        categoryNames: categoryNames(s.word.category),
        myVote,
      });
    }
    return JSON.stringify({
      role: "crew",
      wordId: s.word.id,
      names: s.word.names,
      category: s.word.category,
      categoryNames: categoryNames(s.word.category),
      myVote,
    });
  },

  outcome(s) {
    if (s.phase !== "over" || s.result === null) return null;
    const reason = s.endReason ?? "win";
    if (s.result === "imposter") return { winner: s.imposter, reason };
    const winners = living(s).filter((i) => i !== s.imposter);
    return { winners, reason };
  },

  encode(s) {
    return JSON.stringify(s);
  },

  decode(raw) {
    return decodeJson<ImposterState>(raw, "imposter");
  },
};
