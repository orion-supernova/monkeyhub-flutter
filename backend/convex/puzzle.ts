import { mutation } from "./_generated/server";
import { v } from "convex/values";

/**
 * The daily puzzle.
 *
 * Wordle's tension — a hidden code, six tries, each guess comes back tile by
 * tile as exactly right / right symbol wrong place / absent — with one
 * decisive difference: **there are no words**.
 *
 * That is the entire reason for the choice. This app ships in twelve
 * languages. A real Wordle needs a hand-curated answer list per locale, and
 * friends on different app languages would then be solving *different
 * puzzles*, which quietly makes the shared scoreboard compare nothing.
 * Symbols are identical everywhere, so every friend in the world plays the
 * same puzzle and the standings mean something.
 *
 * A friend's FINISHED row, and the shareable grid, both stay positionless —
 * aggregate exact/present counts only, via `score()`. The ordered per-slot
 * read (`pegsForSlots()`) is only ever handed back for the player's OWN
 * attempt: pasting an ordered grid into a group chat would tell every friend
 * who hasn't played yet which slots of the (identical, shared) answer are
 * right, before they've earned that.
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

/**
 * Slots in the code.
 *
 * No symbol repeats within a code (see `answerFor`), so four slots over six
 * symbols is 6×5×4×3 = 360 possible codes. Combined with per-slot feedback —
 * which tile is exactly right, which is right-symbol-wrong-place — that is
 * comfortably solvable by a careful human in six, the same shape of difficulty
 * a daily is supposed to have: beatable most days, lost occasionally.
 */
export const SLOTS = 4;

/** Guesses allowed. */
export const MAX_GUESSES = 6;

/**
 * Deterministic PRNG (mulberry32).
 *
 * Chosen over `Math.random` for the obvious reason — the answer has to be the
 * same for every player and on every call — and over a hash-slice because a
 * proper generator gives an even distribution across all 360 codes (and,
 * downstream, a fair shuffle in `answerFor`). A biased one would make certain
 * openings reliably good, which is exactly the kind of thing a group of
 * friends works out by week three.
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
 * The code for [dayKey].
 *
 * No repeats: a Fisher-Yates shuffle of all SYMBOLS, truncated to SLOTS, so
 * every symbol in the code is distinct. That is what makes per-slot feedback
 * safe to hand back at all — see `pegsForSlots` below — and it is also just
 * more legible: a code the player can reason about symbol-by-symbol rather
 * than tracking how many of a repeated one are left.
 */
export function answerFor(dayKey: string): number[] {
  const rand = mulberry32(seedFor(dayKey));
  const pool = Array.from({ length: SYMBOLS }, (_, i) => i);
  for (let i = pool.length - 1; i > 0; i--) {
    const j = Math.floor(rand() * (i + 1));
    [pool[i], pool[j]] = [pool[j], pool[i]];
  }
  return pool.slice(0, SLOTS);
}

/**
 * Per-slot feedback for one guess against [answer]: which slots are the exact
 * symbol in the exact place, which are the right symbol in the wrong place,
 * and which are absent.
 *
 * Two-pass, same as classic Mastermind/Wordle scoring: exact matches are
 * consumed first, then the remaining answer symbols are pooled and matched by
 * multiset against the remaining guess symbols. That still matters even though
 * the ANSWER no longer repeats a symbol — the GUESS can, and without the pool
 * step a guess like `AABC` against answer `ABCD` would mark both `A`s as
 * "present" when only one `A` exists to be present at all.
 *
 * Safe to hand back ordered, unlike the old aggregate-only feedback: this is
 * only ever returned for the player's OWN attempt (see `guess` below and
 * `board` in feed.ts), never for a friend's row. A friend's finished attempt
 * still gets the aggregate `score()` counts only — ordered pegs would tell
 * someone who hasn't played yet which slots of the shared answer are right.
 */
export function pegsForSlots(
  guess: number[],
  answer: number[]
): Array<"exact" | "present" | "absent"> {
  const status: Array<"exact" | "present" | "absent"> = new Array(
    answer.length
  ).fill("absent");
  const pool = new Map<number, number>();
  for (let i = 0; i < answer.length; i++) {
    if (guess[i] === answer[i]) {
      status[i] = "exact";
    } else {
      pool.set(answer[i], (pool.get(answer[i]) ?? 0) + 1);
    }
  }
  for (let i = 0; i < guess.length; i++) {
    if (status[i] === "exact") continue;
    const n = pool.get(guess[i]) ?? 0;
    if (n > 0) {
      status[i] = "present";
      pool.set(guess[i], n - 1);
    }
  }
  return status;
}

/**
 * Scores one guess: how many are exactly right, and how many are the right
 * symbol in the wrong slot. The aggregate view of `pegsForSlots` — this is
 * what a friend's row gets, since a count alone reveals nothing about which
 * slots of the shared answer are right.
 */
export function score(
  guess: number[],
  answer: number[]
): { exact: number; present: number } {
  const slots = pegsForSlots(guess, answer);
  let exact = 0;
  let present = 0;
  for (const s of slots) {
    if (s === "exact") exact++;
    else if (s === "present") present++;
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
      // dropped a response can rebuild the whole grid from this. Ordered
      // per-slot status is safe here: this response only ever reaches the
      // player who made these exact guesses.
      feedback: guesses.map((row) => ({
        ...score(row, answer),
        slots: pegsForSlots(row, answer),
      })),
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
