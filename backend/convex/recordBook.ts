import type { Doc, Id } from "./_generated/dataModel";

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
  },
): Promise<void> {
  const { userId, game, score, dayKey, achievedAt } = args;
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
      best: score,
      dayKey,
      achievedAt,
      solves: 1,
    });
    return;
  }
  const beaten = score < row.best;
  await ctx.db.patch(row._id, {
    solves: row.solves + 1,
    ...(beaten ? { best: score, dayKey, achievedAt } : {}),
  });
  if (beaten) {
    for (const r of await reactionsOn(ctx, row._id)) await ctx.db.delete(r._id);
  }
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
