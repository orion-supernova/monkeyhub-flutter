import { mutation } from "./_generated/server";
import { v } from "convex/values";

/**
 * The daily puzzle.
 *
 * A Mastermind, not a Wordle. Guess a hidden five-symbol code in six tries;
 * each guess comes back with how many symbols are in the right place and how
 * many are right but misplaced. Mechanically it is Wordle — same tension, same
 * shareable grid — with one decisive difference: **there are no words**.
 *
 * That is the entire reason for the choice. This app ships in twelve languages.
 * A real Wordle needs a hand-curated answer list per locale, and friends on
 * different app languages would then be solving *different puzzles*, which
 * quietly makes the shared scoreboard compare nothing. Symbols are identical
 * everywhere, so every friend in the world plays the same puzzle and the
 * standings mean something.
 *
 * ## Where the answer lives
 *
 * Nowhere. It is derived from the day key by a pure function, so there is no
 * table, no row to create, and no race between the first two players of the
 * day. The client never receives it — guesses are scored server-side and only
 * the feedback comes back — so the code is not on the device before it has been
 * earned.
 */

/** Symbols in the alphabet. Mirrored by `kPuzzleSymbolCount` in Dart. */
export const SYMBOLS = 6;

/** Slots in the code. */
export const SLOTS = 5;

/** Guesses allowed. */
export const MAX_GUESSES = 6;

/**
 * Deterministic PRNG (mulberry32).
 *
 * Chosen over `Math.random` for the obvious reason — the answer has to be the
 * same for every player and on every call — and over a hash-slice because a
 * proper generator gives an even distribution across all 7,776 codes. A biased
 * one would make certain openings reliably good, which is exactly the kind of
 * thing a group of friends works out by week three.
 */
function mulberry32(seed: number): () => number {
  let a = seed >>> 0;
  return () => {
    a = (a + 0x6d2b79f5) >>> 0;
    let t = Math.imul(a ^ (a >>> 15), 1 | a);
    t = (t + Math.imul(t ^ (t >>> 7), 61 | t)) ^ t;
    return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
  };
}

/** FNV-1a over the day key, so consecutive days look unrelated. */
function seedFor(dayKey: string): number {
  let h = 2166136261;
  for (let i = 0; i < dayKey.length; i++) {
    h ^= dayKey.charCodeAt(i);
    h = Math.imul(h, 16777619);
  }
  return h >>> 0;
}

/**
 * The code for [dayKey]. Repeats are allowed — 6^5 = 7,776 possibilities,
 * which is Wordle-equivalent difficulty at six guesses.
 */
export function answerFor(dayKey: string): number[] {
  const rand = mulberry32(seedFor(dayKey));
  const out: number[] = [];
  for (let i = 0; i < SLOTS; i++) out.push(Math.floor(rand() * SYMBOLS));
  return out;
}

/**
 * Scores one guess: how many are exactly right, and how many are the right
 * symbol in the wrong slot.
 *
 * The two-pass structure is not incidental. Counting "present" naively
 * double-counts a symbol that is both exact somewhere and repeated elsewhere —
 * guess `AABBB` against answer `ABBBB` would report more matches than there are
 * symbols. Exact positions are consumed first, then the remainder is matched by
 * multiset, which is the standard Mastermind rule and the only one that is
 * self-consistent when repeats are allowed.
 */
export function score(
  guess: number[],
  answer: number[]
): { exact: number; present: number } {
  let exact = 0;
  const guessLeft: number[] = [];
  const answerLeft: number[] = [];
  for (let i = 0; i < answer.length; i++) {
    if (guess[i] === answer[i]) {
      exact++;
    } else {
      guessLeft.push(guess[i]);
      answerLeft.push(answer[i]);
    }
  }
  let present = 0;
  const pool = new Map<number, number>();
  for (const s of answerLeft) pool.set(s, (pool.get(s) ?? 0) + 1);
  for (const s of guessLeft) {
    const n = pool.get(s) ?? 0;
    if (n > 0) {
      present++;
      pool.set(s, n - 1);
    }
  }
  return { exact, present };
}

/**
 * Submits a guess and returns the feedback for it.
 *
 * Idempotency is by GUESS COUNT rather than a flag: replaying the same call
 * after a flaky socket appends a duplicate row's worth of guesses otherwise,
 * and burning a try on a network hiccup is the sort of thing that makes a
 * daily game feel unfair exactly once and then get abandoned.
 *
 * Returns the whole board state rather than only the new row, so a client that
 * missed a response can resync from any single call.
 */
export const guess = mutation({
  args: {
    userId: v.id("users"),
    // The player's local day, for the same timezone reason as the feed board.
    dayKey: v.string(),
    guess: v.array(v.number()),
  },
  handler: async (ctx, { userId, dayKey, guess: g }) => {
    if (g.length !== SLOTS) throw new Error("BAD_GUESS");
    for (const s of g) {
      if (!Number.isInteger(s) || s < 0 || s >= SYMBOLS) {
        throw new Error("BAD_GUESS");
      }
    }

    const existing = await ctx.db
      .query("puzzleResults")
      .withIndex("by_user_day", (q: any) =>
        q.eq("userId", userId).eq("dayKey", dayKey)
      )
      .first();

    const prior: number[][] = existing?.guesses ?? [];
    if (existing?.solved) throw new Error("ALREADY_SOLVED");
    if (prior.length >= MAX_GUESSES) throw new Error("OUT_OF_GUESSES");

    const answer = answerFor(dayKey);
    const guesses = [...prior, g];
    const solved = score(g, answer).exact === SLOTS;
    const done = solved || guesses.length >= MAX_GUESSES;
    const now = Date.now();

    if (existing) {
      await ctx.db.patch(existing._id, {
        guesses,
        solved,
        updatedAt: now,
        ...(done ? { finishedAt: now } : {}),
      });
    } else {
      await ctx.db.insert("puzzleResults", {
        userId,
        dayKey,
        guesses,
        solved,
        createdAt: now,
        updatedAt: now,
        ...(done ? { finishedAt: now } : {}),
      });
    }

    return {
      // Feedback for every guess so far, not just this one — a client that
      // dropped a response can rebuild the whole grid from this.
      feedback: guesses.map((row) => score(row, answer)),
      guesses,
      solved,
      done,
      // The answer is revealed ONLY once the player can no longer act on it.
      // Returning it a moment early would put it in the response of the guess
      // that used their last try, which is exactly when it matters.
      answer: done && !solved ? answer : undefined,
    };
  },
});
