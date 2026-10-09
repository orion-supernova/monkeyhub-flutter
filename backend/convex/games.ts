import { mutation, query } from "./functions";
import { internal } from "./_generated/api";
import { v } from "convex/values";

import * as queens from "./games/queens";
import * as sudoku from "./games/sudoku";
import * as tango from "./games/tango";
import * as zip from "./games/zip";
import { liveStreak, noteSolve } from "./recordBook";
import { lensFor } from "./visibility";

/**
 * THE DAILY GAMES — Queens, Tango, Zip and Mini Sudoku.
 *
 * Four fresh boards every day, the same four boards for everyone, ranked by how
 * fast you finished them. They sit alongside the symbol-code puzzle in
 * `puzzle.ts`, which keeps its own table and its own guesses-based ranking.
 *
 * ## Why these four, and not Crossclimb or Pinpoint
 *
 * Because they contain no words. This app ships in twelve languages, and
 * `puzzle.ts` already spells out what that costs a word game: a curated answer
 * list per locale, friends on different app languages solving *different*
 * boards, and a shared scoreboard that therefore compares nothing. A crown, a
 * sun, a line and the digits 1-6 are the same in every language, so every
 * friend in the world plays the identical board and the standings mean
 * something. That constraint picked the shortlist; it was not a shortcut.
 *
 * ## Where the boards live
 *
 * Nowhere. Each is a pure function of the day key (`games/*.ts`), so there is
 * no table to seed, no cron to run before midnight in the earliest timezone,
 * and no race between the day's first two players. Adding a fifth game is a new
 * file and one line of `GAMES` — no migration over live rows.
 *
 * ## Query budget
 *
 * This feature adds **no live subscriptions**. `daily` reads nothing from the
 * database, so it is invalidated by nothing. `standings` is a one-shot read the
 * client asks for when the hub opens and again when someone finishes — a daily
 * leaderboard does not need to be live, and this app runs ~15 subscriptions
 * app-wide and has turned down new ones for far more than this.
 */

/** The games that exist. Mirrored by `DailyGame` in lib/models/daily_game.dart. */
export const GAMES = ["queens", "tango", "zip", "sudoku"] as const;
export type GameId = (typeof GAMES)[number];

function isGameId(value: string): value is GameId {
  return (GAMES as readonly string[]).includes(value);
}

/** Every board for one day, in the shape the client renders from. */
type DailyBoards = {
  dayKey: string;
  queens: queens.QueensPuzzle;
  tango: tango.TangoPuzzle;
  zip: zip.ZipPuzzle;
  sudoku: sudoku.SudokuPuzzle;
};

/**
 * Generated boards, remembered per day key.
 *
 * Generation is a search — Queens repairs its board until the solver proves one
 * answer, and that runs tens of milliseconds on an unlucky seed. It is also a
 * pure function of the day key, so the result can be cached without any way for
 * it to go stale, and every player after the first on a given Convex instance
 * gets it for free.
 *
 * Bounded, and cleared rather than evicted one by one: the working set is
 * "today, and yesterday for anyone west of the dateline", so anything beyond a
 * handful of keys is a sign of clock skew, not of a cache that needs an LRU.
 */
const boardCache = new Map<string, DailyBoards>();

function boardsFor(dayKey: string): DailyBoards {
  const hit = boardCache.get(dayKey);
  if (hit) return hit;
  const built: DailyBoards = {
    dayKey,
    queens: queens.generate(dayKey),
    tango: tango.generate(dayKey),
    zip: zip.generate(dayKey),
    sudoku: sudoku.generate(dayKey),
  };
  if (boardCache.size >= 8) boardCache.clear();
  boardCache.set(dayKey, built);
  return built;
}

/** Whether [solution] finishes [game]'s board for [dayKey]. */
function isSolved(dayKey: string, game: GameId, solution: number[]): boolean {
  const boards = boardsFor(dayKey);
  switch (game) {
    case "queens":
      return queens.isSolved(boards.queens, solution);
    case "tango":
      return tango.isSolved(boards.tango, solution);
    case "zip":
      return zip.isSolved(boards.zip, solution);
    case "sudoku":
      return sudoku.isSolved(boards.sudoku, solution);
  }
}

/** [game]'s answer for [dayKey], for a player who has given up. */
function answerOf(dayKey: string, game: GameId): number[] | null {
  const boards = boardsFor(dayKey);
  switch (game) {
    case "queens":
      return queens.solve(boards.queens);
    case "tango":
      return tango.solve(boards.tango);
    case "zip":
      // Zip validates a route rather than comparing one, so it has no single
      // stored answer — the route it was drawn from is a legal one, which is
      // all a surrender needs to be shown.
      return zip.generateWithSolution(dayKey).solution;
    case "sudoku":
      return sudoku.solve(boards.sudoku);
  }
}

/** One player's row, as anyone may see it. */
function resultView(row: any) {
  return {
    game: row.game,
    startedAt: row.startedAt,
    durationMs: row.durationMs,
    solved: row.solved,
    gaveUp: row.gaveUp,
    finishedAt: row.finishedAt,
    hintsUsed: row.hintsUsed,
    mistakes: row.mistakes,
  };
}

/** [userId]'s rows for [dayKey], keyed by game. One indexed read. */
async function rowsFor(ctx: any, userId: any, dayKey: string) {
  const rows = await ctx.db
    .query("gameResults")
    .withIndex("by_user_day_game", (q: any) =>
      q.eq("userId", userId).eq("dayKey", dayKey)
    )
    .collect();
  const byGame = new Map<string, any>();
  for (const row of rows) byGame.set(row.game, row);
  return byGame;
}

/** [userId]'s all-time rows, one per game they have solved. One indexed read. */
async function recordsOf(ctx: any, userId: any): Promise<any[]> {
  return await ctx.db
    .query("gameRecords")
    .withIndex("by_user_game", (q: any) => q.eq("userId", userId))
    .collect();
}

/**
 * Today's four boards.
 *
 * Takes no `userId` and reads no table on purpose: with no database read there
 * is nothing to invalidate it, so even though Convex will happily keep it live
 * it costs the same as a constant. The player's own progress rides on
 * `standings` instead, which is where the reads are.
 */
export const daily = query({
  args: { dayKey: v.string() },
  handler: async (_ctx, { dayKey }) => {
    const boards = boardsFor(dayKey);
    return {
      dayKey,
      games: GAMES.map((id) => ({ id })),
      queens: boards.queens,
      tango: boards.tango,
      zip: boards.zip,
      sudoku: boards.sudoku,
    };
  },
});

/**
 * The viewer's own rows plus a leaderboard per game, over accepted friends.
 *
 * One-shot. See the file header: a daily leaderboard refreshed when you open
 * the hub and when you finish a board is indistinguishable from a live one, and
 * a subscription here would re-fire on every friend's presence heartbeat
 * because of the visibility read below.
 *
 * An UNFINISHED board never leaves its owner's device, exactly as in
 * `feed.board`'s puzzle section: knowing a friend is nine minutes into Queens
 * and still going tells you how hard today is, and a live progress counter
 * turns a quiet daily into a race.
 */
export const standings = query({
  args: { userId: v.id("users"), dayKey: v.string() },
  handler: async (ctx, { userId, dayKey }) => {
    const friendships = await ctx.db
      .query("friendships")
      .withIndex("by_user", (q: any) => q.eq("userId", userId))
      .collect();
    // An accepted friendship is always two directed rows, so scanning by_user
    // alone is complete. Capped for the same reason `feed.board` caps its
    // fan-out — a query whose cost grows without limit is how a small box falls
    // over.
    const friendIds = friendships
      .filter((f: any) => f.status === "accepted")
      .slice(0, 200)
      .map((f: any) => f.friendId);

    const mineRows = await rowsFor(ctx, userId, dayKey);
    const mine: Record<string, any> = {};
    const progress: Record<string, number[]> = {};
    for (const [game, row] of mineRows) {
      // `shared` rides on the viewer's OWN rows only, and is deliberately not
      // in `resultView`: that shape is what friends see too, and whether
      // somebody pressed "tell friends" is a fact about their notification
      // habits rather than about the board. The client needs it to stop
      // offering a button that would now be refused.
      mine[game] = { ...resultView(row), shared: row.sharedAt !== undefined };
      if (row.progress) progress[game] = row.progress;
    }

    const boards: Record<string, any[]> = {};
    for (const id of GAMES) boards[id] = [];

    // Live streaks by person, then game ("code" included), for the flame on
    // each row: only runs still alive on [dayKey], so a run that lapsed last
    // week does not ride on somebody's time. The viewer's under their own id.
    const streaks: Record<string, Record<string, number>> = {};
    const noteStreaks = (id: string, records: any[]) => {
      const live: Record<string, number> = {};
      for (const rec of records) {
        const n = liveStreak(rec, dayKey);
        if (n > 0) live[rec.game] = n;
      }
      if (Object.keys(live).length > 0) streaks[id] = live;
    };

    // Faces for the rows and the podium, by person, through the same lens
    // the Feed draws authors with: a friend who keeps their picture from
    // friends stays a monogram here too.
    const lens = await lensFor(ctx, userId);
    const avatars: Record<string, string> = {};
    const names: Record<string, string> = {};
    const me: any = await ctx.db.get(userId);
    if (me?.avatarStorageId) avatars[userId] = me.avatarStorageId;

    const myRecords = await recordsOf(ctx, userId);
    noteStreaks(userId, myRecords);
    // The viewer's own streak area: every game they have ever solved, the run
    // they are on (0 when it lapsed), their longest, and whether today's
    // board is already in it.
    const myStreaks: Record<string, any> = {};
    for (const rec of myRecords) {
      myStreaks[rec.game] = {
        current: liveStreak(rec, dayKey),
        best: rec.bestStreak ?? 0,
        today: rec.lastSolvedDayKey === dayKey,
      };
    }

    for (const friendId of friendIds) {
      const rows = await rowsFor(ctx, friendId, dayKey);
      // One more indexed read per friend: the code puzzle's scores live on
      // the Feed's board rather than here, so its scorers' streaks have no
      // other way onto the leaderboard.
      const records = await recordsOf(ctx, friendId);
      if (rows.size === 0 && records.length === 0) continue;
      // One `users` read per friend who actually played, not per friend.
      // Someone who has not touched today's games costs nothing here.
      const friend: any = await ctx.db.get(friendId);
      if (!friend) continue;
      // The same `visibility.puzzle` switch the symbol-code scoreboard obeys.
      // Deliberately not a new thirteenth setting: a user who said "my daily
      // score is not comparable" said it about dailies, and splitting that into
      // two switches means the one they already set silently stops covering
      // half the feature.
      if ((friend.visibility?.puzzle ?? "friends") === "nobody") continue;
      noteStreaks(friendId, records);
      // A name for everyone on a streak, for the streak rankings: a friend
      // alive since yesterday has no row today to carry it.
      if (streaks[friendId]) {
        names[friendId] = friend.name ?? friend.username ?? "";
      }
      if (friend.avatarStorageId && lens.canSee(friend, "avatar")) {
        avatars[friendId] = friend.avatarStorageId;
      }
      const name = friend.name ?? friend.username ?? "";
      for (const [game, row] of rows) {
        if (!row.finishedAt) continue;
        boards[game]?.push({ ...resultView(row), userId: friendId, name });
      }
    }

    for (const [game, row] of mineRows) {
      if (!row.finishedAt) continue;
      boards[game]?.push({ ...resultView(row), userId, name: "" });
    }

    // Solved first, then fastest, then earliest finish, then id — a stable
    // order, because the client animates these rows by identity and a tie that
    // reshuffles on every refresh reads as the list glitching.
    for (const id of GAMES) {
      boards[id].sort((a, b) => {
        if (a.solved !== b.solved) return a.solved ? -1 : 1;
        const at = a.durationMs ?? Number.MAX_SAFE_INTEGER;
        const bt = b.durationMs ?? Number.MAX_SAFE_INTEGER;
        if (at !== bt) return at - bt;
        if (a.finishedAt !== b.finishedAt) return a.finishedAt - b.finishedAt;
        return a.userId < b.userId ? -1 : 1;
      });
    }

    return {
      dayKey,
      mine,
      progress,
      boards,
      streaks,
      myStreaks,
      avatars,
      names,
    };
  },
});

/**
 * Starts the clock for one game, or returns the clock already running.
 *
 * Idempotent by existence rather than by a flag: reopening a board you walked
 * away from must not reset its start, or a player could farm a good time by
 * backing out and coming straight back in.
 */
export const start = mutation({
  args: {
    userId: v.id("users"),
    dayKey: v.string(),
    game: v.string(),
  },
  handler: async (ctx, { userId, dayKey, game }) => {
    if (!isGameId(game)) throw new Error("UNKNOWN_GAME");
    const existing = await ctx.db
      .query("gameResults")
      .withIndex("by_user_day_game", (q: any) =>
        q.eq("userId", userId).eq("dayKey", dayKey).eq("game", game)
      )
      .first();
    if (existing) {
      return {
        startedAt: existing.startedAt,
        progress: existing.progress ?? null,
        elapsedMs: existing.elapsedMs ?? 0,
        hintsUsed: existing.hintsUsed,
        mistakes: existing.mistakes,
        finished: existing.finishedAt !== undefined,
      };
    }
    const now = Date.now();
    await ctx.db.insert("gameResults", {
      userId,
      dayKey,
      game,
      startedAt: now,
      solved: false,
      gaveUp: false,
      hintsUsed: 0,
      mistakes: 0,
    });
    return {
      startedAt: now,
      progress: null,
      elapsedMs: 0,
      hintsUsed: 0,
      mistakes: 0,
      finished: false,
    };
  },
});

/**
 * Stores a half-finished board so closing the app does not throw it away.
 *
 * Called when the player leaves the screen, never per move — a mutation per tap
 * on a grid you tap sixty times would be the single chattiest thing in the app.
 * A finished row ignores it: a late save racing in behind a submit must not be
 * able to un-finish a result.
 */
export const saveProgress = mutation({
  args: {
    userId: v.id("users"),
    dayKey: v.string(),
    game: v.string(),
    progress: v.array(v.number()),
    elapsedMs: v.number(),
    mistakes: v.number(),
  },
  handler: async (
    ctx,
    { userId, dayKey, game, progress, elapsedMs, mistakes }
  ) => {
    if (!isGameId(game)) throw new Error("UNKNOWN_GAME");
    if (progress.length > 64) throw new Error("BAD_PROGRESS");
    const row = await ctx.db
      .query("gameResults")
      .withIndex("by_user_day_game", (q: any) =>
        q.eq("userId", userId).eq("dayKey", dayKey).eq("game", game)
      )
      .first();
    if (!row || row.finishedAt !== undefined) return null;
    await ctx.db.patch(row._id, {
      progress,
      // Monotonic. A save carrying a *smaller* clock than the one already
      // stored is either a stale write landing late or a second device with a
      // shorter session, and in both cases the longer reading is the honest
      // one.
      elapsedMs: Math.max(row.elapsedMs ?? 0, Math.max(0, Math.round(elapsedMs))),
      mistakes: Math.max(row.mistakes, Math.max(0, Math.round(mistakes))),
    });
    return null;
  },
});

/**
 * Reveals one correct cell, and counts it.
 *
 * Takes the player's current board because the server does not track it move by
 * move — `saveProgress` runs when they leave the screen, not per tap — so the
 * grid in the argument is the only current picture of what they have filled in.
 * Nothing is trusted from it beyond "which squares still need help": the cell
 * handed back is read off the generator's own solution.
 *
 * `board` is in the same shape `submit` takes, which differs by game: a column
 * per row for Queens (so `index` is a ROW and `value` its column), and a value
 * per cell for Tango and Sudoku. Anything the player has not decided yet is
 * whatever that game's blank is, which simply reads as a disagreement with the
 * answer and therefore as a candidate.
 *
 * Which cell is chosen rotates with the number of hints already taken, so a
 * second hint is a different square rather than the same one again.
 *
 * **Zip has no hint, on purpose.** Its board accepts any route that covers
 * every cell in order, so there is no single next-correct-move to point at —
 * only "the route I generated", and steering a player onto that would mean
 * discarding whichever perfectly legal line they had already drawn.
 */
export const hint = mutation({
  args: {
    userId: v.id("users"),
    dayKey: v.string(),
    game: v.string(),
    board: v.array(v.number()),
    // How many hints the client has already seen land. Optional only for
    // clients from before it existed. See the replay check below.
    seq: v.optional(v.number()),
  },
  handler: async (ctx, { userId, dayKey, game, board, seq }) => {
    if (!isGameId(game)) throw new Error("UNKNOWN_GAME");
    if (game === "zip") throw new Error("NO_HINT");
    if (board.length > 64) throw new Error("BAD_PROGRESS");

    const row = await ctx.db
      .query("gameResults")
      .withIndex("by_user_day_game", (q: any) =>
        q.eq("userId", userId).eq("dayKey", dayKey).eq("game", game)
      )
      .first();
    if (!row) throw new Error("NOT_STARTED");
    if (row.finishedAt !== undefined) throw new Error("ALREADY_FINISHED");

    const answer = answerOf(dayKey, game);
    if (!answer) throw new Error("NO_HINT");

    // Where the player's grid disagrees with the answer, including everything
    // they have not filled in yet.
    const wrong: number[] = [];
    for (let i = 0; i < answer.length; i++) {
      if (board[i] !== answer[i]) wrong.push(i);
    }
    if (wrong.length === 0) return { index: -1, value: 0 };

    // A replay: this hint was already counted, and the native client is
    // resending a call the player saw time out. It keeps every sent mutation
    // in flight across a reconnect, so without this a hint asked for in a dead
    // tunnel was charged once per resend. Answered from the same rotation slot
    // it would have had, and charged nothing.
    if (seq !== undefined && row.hintsUsed > seq) {
      const pick = wrong[seq % wrong.length];
      return { index: pick, value: answer[pick] };
    }

    const pick = wrong[row.hintsUsed % wrong.length];
    await ctx.db.patch(row._id, { hintsUsed: row.hintsUsed + 1 });
    return { index: pick, value: answer[pick] };
  },
});

/**
 * Submits a finished board.
 *
 * ## On the reported time
 *
 * The client says how long the board was in front of it and the server clamps
 * that to the window since `start`, so a time can never be longer than the
 * player has actually had the puzzle. It can be *shorter*, and that is
 * deliberate: the clock is meant to stop when you put the phone down, and a
 * purely server-measured duration would punish answering the door rather than
 * measuring the solve. The upper bound is what the server can honestly prove;
 * beyond it, this is a private app between friends whose points board is
 * already openly self-reported.
 *
 * Whether you SOLVED it is not client-reported. The grid is re-validated here
 * against the same generator the board came from.
 */
export const submit = mutation({
  args: {
    userId: v.id("users"),
    dayKey: v.string(),
    game: v.string(),
    solution: v.array(v.number()),
    elapsedMs: v.number(),
    hintsUsed: v.number(),
    mistakes: v.number(),
  },
  handler: async (
    ctx,
    { userId, dayKey, game, solution, elapsedMs, hintsUsed, mistakes }
  ) => {
    if (!isGameId(game)) throw new Error("UNKNOWN_GAME");
    if (solution.length > 64) throw new Error("BAD_SOLUTION");

    const row = await ctx.db
      .query("gameResults")
      .withIndex("by_user_day_game", (q: any) =>
        q.eq("userId", userId).eq("dayKey", dayKey).eq("game", game)
      )
      .first();
    // Replaying a submit after a flaky socket must not overwrite a finished
    // result with a slower one, and a board that was never started cannot be
    // finished — both would be ways to hand yourself a better time.
    if (!row) throw new Error("NOT_STARTED");
    if (row.finishedAt !== undefined) {
      return { solved: row.solved, durationMs: row.durationMs, replay: true };
    }
    if (!isSolved(dayKey, game, solution)) throw new Error("NOT_SOLVED");

    const now = Date.now();
    const durationMs = Math.max(
      0,
      Math.min(Math.round(elapsedMs), now - row.startedAt)
    );
    await ctx.db.patch(row._id, {
      solved: true,
      finishedAt: now,
      durationMs,
      hintsUsed: Math.max(0, Math.round(hintsUsed)),
      mistakes: Math.max(0, Math.round(mistakes)),
      // The finished grid replaces the autosave, so reopening a board you
      // already solved shows the solved board rather than the state you were in
      // when you last happened to leave the screen.
      progress: solution,
    });
    // In the same transaction as the result, so the all-time board and the
    // day's standings can never disagree about a time. A replay returned above
    // and never reaches here, so a flaky socket cannot count a solve twice.
    await noteSolve(ctx, {
      userId,
      game,
      score: durationMs,
      dayKey,
      achievedAt: now,
    });
    return { solved: true, durationMs, replay: false };
  },
});

/**
 * Pushes a finished result to the player's friends, because they asked.
 *
 * The counterpart to `feed.post`'s automatic fan-out, and deliberately not
 * automatic itself. A moment is something you published; a game result is
 * something you happened to do, and a notification about it is a boast — which
 * is fine when you press the button and obnoxious when the app presses it for
 * you. So this exists as a mutation with no caller but a tap on the result
 * card.
 *
 * Four refusals, each closing a different way to notify people twice:
 *
 *   * `NOT_STARTED` / `NOT_FINISHED` — there is no result to share. A board
 *     still in progress is private (see `standings`), and sharing one would
 *     leak a time that has not stopped.
 *   * `ALREADY_SHARED` — `sharedAt` is the whole gate, and it is stored on the
 *     row rather than remembered by the client for the obvious reason: the
 *     client that would remember is a reinstall away from notifying fifty
 *     people again.
 *   * `RESULT_PRIVATE` — the player's own `visibility.puzzle` is "nobody", so
 *     their friends cannot see this result in the standings the push would
 *     open. Refused loudly here, where the player is standing, rather than
 *     silently dropped in the fan-out — the audience query checks it too, but
 *     that check cannot tell anybody why nothing happened.
 */
export const shareResult = mutation({
  args: { userId: v.id("users"), dayKey: v.string(), game: v.string() },
  handler: async (ctx, { userId, dayKey, game }) => {
    if (!isGameId(game)) throw new Error("UNKNOWN_GAME");
    const row = await ctx.db
      .query("gameResults")
      .withIndex("by_user_day_game", (q: any) =>
        q.eq("userId", userId).eq("dayKey", dayKey).eq("game", game)
      )
      .first();
    if (!row) throw new Error("NOT_STARTED");
    if (row.finishedAt === undefined) throw new Error("NOT_FINISHED");
    if (row.sharedAt !== undefined) throw new Error("ALREADY_SHARED");

    const player = await ctx.db.get(userId);
    if (!player) throw new Error("USER_NOT_FOUND");
    if ((player.visibility?.puzzle ?? "friends") === "nobody") {
      throw new Error("RESULT_PRIVATE");
    }

    // Stamped BEFORE the schedule, inside the same transaction. The other
    // order would let two taps that arrive together both read an unshared row
    // and both schedule a fan-out.
    await ctx.db.patch(row._id, { sharedAt: Date.now() });
    await ctx.scheduler.runAfter(0, internal.socialPush.sendGameResultPush, {
      userId,
      dayKey,
      game,
    });
    return { shared: true };
  },
});

/**
 * Gives up, and returns the answer.
 *
 * Recorded rather than left blank. A surrender is a result — the standings show
 * it below the solvers the way an unsolved daily puzzle shows as X/6 — and a
 * player who has seen the answer must not then be able to submit it as a solve,
 * which is what `finishedAt` being set here prevents.
 */
export const reveal = mutation({
  args: { userId: v.id("users"), dayKey: v.string(), game: v.string() },
  handler: async (ctx, { userId, dayKey, game }) => {
    if (!isGameId(game)) throw new Error("UNKNOWN_GAME");
    const row = await ctx.db
      .query("gameResults")
      .withIndex("by_user_day_game", (q: any) =>
        q.eq("userId", userId).eq("dayKey", dayKey).eq("game", game)
      )
      .first();
    if (!row) throw new Error("NOT_STARTED");
    const answer = answerOf(dayKey, game);
    if (row.finishedAt === undefined) {
      await ctx.db.patch(row._id, {
        gaveUp: true,
        solved: false,
        finishedAt: Date.now(),
      });
    }
    return { answer };
  },
});
