import type { Doc, Id } from "./_generated/dataModel";
import { dayOrdinal } from "./dayKeys";

/**
 * The write side of the all-time records (`records.ts`), in a module of its own.
 *
 * `games.submit` and `puzzle.guess` record every solve through [noteSolve], and
 * `records.ts` needs `games.GAMES` for its list of games. Keeping these here —
 * importing neither — is what stops that pair becoming an import cycle, whose
 * top-level `[...GAMES]` would read an uninitialised binding on whichever
 * module happened to load second.
 */

/** The code puzzle's id on the records board, beside the four dailies. */
export const CODE_GAME = "code";

export async function reactionsOn(ctx: any, recordId: Id<"gameRecords">) {
  return await ctx.db
    .query("recordReactions")
    .withIndex("by_record_user", (q: any) => q.eq("recordId", recordId))
    .collect();
}

/**
 * Counts one solve of [game] by [userId], scored [score] (lower is better), and
 * makes it the record if it is one.
 *
 * A solve that used a hint ([clean] false) counts — `solves` and the streak
 * move — but never sets or beats `best`: the record is the fastest board the
 * player solved on their own.
 *
 * Called from inside the mutation that finished the board, so the record and
 * the result can never disagree. [achievedAt] is that mutation's own
 * `finishedAt`, which is what [backfill] reads back for the same result — the
 * two agree on what "this achievement" means.
 *
 * A tie does not replace the standing record: the earlier holder set it first.
 */
export async function noteSolve(
  ctx: any,
  args: {
    userId: Id<"users">;
    game: string;
    score: number;
    dayKey: string;
    achievedAt: number;
    clean?: boolean;
  },
): Promise<void> {
  const { userId, game, score, dayKey, achievedAt } = args;
  const clean = args.clean ?? true;
  const row: Doc<"gameRecords"> | null = await ctx.db
    .query("gameRecords")
    .withIndex("by_user_game", (q: any) =>
      q.eq("userId", userId).eq("game", game),
    )
    .first();
  if (!row) {
    await ctx.db.insert("gameRecords", {
      userId,
      game,
      ...(clean ? { best: score } : {}),
      dayKey,
      achievedAt,
      solves: 1,
      streak: 1,
      bestStreak: 1,
      lastSolvedDayKey: dayKey,
    });
    return;
  }
  const beaten = clean && (row.best === undefined || score < row.best);
  await ctx.db.patch(row._id, {
    solves: row.solves + 1,
    ...(beaten ? { best: score, dayKey, achievedAt } : {}),
    ...extendStreak(row, dayKey),
  });
  if (beaten) {
    for (const r of await reactionsOn(ctx, row._id)) await ctx.db.delete(r._id);
  }
}

/**
 * The streak fields after a solve on [dayKey]: one longer when the last solve
 * was the day before, a fresh run of one after a gap.
 *
 * A [dayKey] at or before the last solve leaves the run alone. One board a
 * day makes a second solve of the same day impossible, and an EARLIER day is
 * a client whose clock disagrees with the last one it used (a timezone hop
 * west); counting it would break a run the player never broke.
 */
export function extendStreak(
  row: Pick<Doc<"gameRecords">, "streak" | "bestStreak" | "lastSolvedDayKey">,
  dayKey: string,
): { streak: number; bestStreak: number; lastSolvedDayKey: string } | {} {
  const last = row.lastSolvedDayKey;
  const gap = last === undefined ? Infinity : dayOrdinal(dayKey) - dayOrdinal(last);
  if (gap <= 0) return {};
  const streak = gap === 1 ? (row.streak ?? 0) + 1 : 1;
  return {
    streak,
    bestStreak: Math.max(row.bestStreak ?? 0, streak),
    lastSolvedDayKey: dayKey,
  };
}

/**
 * The streak [row] is on as of [dayKey], or 0 when it has lapsed.
 *
 * Still alive the day after the last solve: today's board is not missed until
 * today is over, and a ring that went out at midnight would tell somebody who
 * has not played YET that they had already lost it.
 */
export function liveStreak(
  row: Pick<Doc<"gameRecords">, "streak" | "lastSolvedDayKey">,
  dayKey: string,
): number {
  const last = row.lastSolvedDayKey;
  if (last === undefined || !row.streak) return 0;
  const gap = dayOrdinal(dayKey) - dayOrdinal(last);
  // A negative gap is a solve on a day the asker has not reached yet (they
  // are west of the player): the run is current, and counts that day too.
  return gap <= 1 ? row.streak : 0;
}

/**
 * Deletes [userId]'s records, the reactions on them, and the reactions they
 * left on other people's. For account teardown (`auth.purgeUser`).
 */
export async function purgeRecordsOf(ctx: any, userId: Id<"users">) {
  for (const r of await ctx.db
    .query("recordReactions")
    .withIndex("by_user", (q: any) => q.eq("userId", userId))
    .collect()) {
    await ctx.db.delete(r._id);
  }
  for (const record of await ctx.db
    .query("gameRecords")
    .withIndex("by_user_game", (q: any) => q.eq("userId", userId))
    .collect()) {
    for (const r of await reactionsOn(ctx, record._id)) await ctx.db.delete(r._id);
    await ctx.db.delete(record._id);
  }
}
