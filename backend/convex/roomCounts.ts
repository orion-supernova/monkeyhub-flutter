import { v } from "convex/values";
import { internal } from "./_generated/api";
import { internalMutation } from "./_generated/server";

/**
 * How many rooms each user is in: the number behind `MAX_ROOMS_PER_USER`.
 *
 * `addMembership` used to read up to 500 `roomMembers` rows (several MB for a
 * power user) just to compare a length against the cap. It now reads one row of
 * `userRoomCounts`. The count lives in its own table, not on `users`, so a join
 * never re-runs a subscription that reads the user.
 *
 * A MISSING row means "not counted yet", never zero. That is what makes the
 * rollout safe without a stop-the-world migration:
 *
 *  - `addMembership` for a user with no row falls back to the old bounded
 *    count, then writes the row with the correct total. Active users therefore
 *    count themselves the first time they join anything.
 *  - [incrementRoomCount] / [decrementRoomCount] are no-ops on a missing row:
 *    the later count (the fallback, or [backfill]) reads the real rows, so it
 *    already includes whatever happened in between.
 *  - [backfill] counts the users nobody has touched yet, and skips any user
 *    that already has a row, so it is idempotent and may be re-run freely.
 *
 * Every place that inserts or deletes a `roomMembers` row for a user calls one
 * of the helpers below beside it (see the list in the Phase 4E notes); the
 * integrity scan is the backstop. The counter heals itself: a decrement that
 * would go below zero clamps to zero and logs.
 *
 * Imports nothing from the room modules, so any of them can call in.
 */

/** Rooms one account may be in at once, DMs included. */
export const MAX_ROOMS_PER_USER = 500;

export async function roomCountRow(ctx: any, userId: any) {
  return await ctx.db
    .query("userRoomCounts")
    .withIndex("by_user", (q: any) => q.eq("userId", userId))
    .first();
}

/**
 * The user's room count right now, for a caller about to insert one more
 * membership: the counter row when there is one, else the bounded count over
 * `roomMembers` (never more than [MAX_ROOMS_PER_USER], which is all the cap
 * needs). `exact` is false only when that bounded count hit the ceiling, so it
 * is a floor and must not be stored.
 */
export async function currentRoomCount(
  ctx: any,
  userId: any,
): Promise<{ count: number; row: any | null; exact: boolean }> {
  const row = await roomCountRow(ctx, userId);
  if (row) return { count: row.count, row, exact: true };
  const joined = await ctx.db
    .query("roomMembers")
    .withIndex("by_user", (q: any) => q.eq("userId", userId))
    .take(MAX_ROOMS_PER_USER);
  return {
    count: joined.length,
    row: null,
    exact: joined.length < MAX_ROOMS_PER_USER,
  };
}

/**
 * Records one membership the caller just inserted, given what
 * [currentRoomCount] returned beforehand. Writes the row when it was missing
 * and the count was exact; a floor is left unrecorded until [backfill].
 */
export async function recordJoin(
  ctx: any,
  userId: any,
  before: { count: number; row: any | null; exact: boolean },
): Promise<void> {
  if (before.row) {
    await ctx.db.patch(before.row._id, { count: before.count + 1 });
  } else if (before.exact) {
    await ctx.db.insert("userRoomCounts", { userId, count: before.count + 1 });
  }
}

/** For inserts that bypass `addMembership`: counts one more if the user is counted. */
export async function incrementRoomCount(ctx: any, userId: any): Promise<void> {
  const row = await roomCountRow(ctx, userId);
  if (row) await ctx.db.patch(row._id, { count: row.count + 1 });
}

/** Counts one fewer if the user is counted; never below zero. */
export async function decrementRoomCount(ctx: any, userId: any): Promise<void> {
  const row = await roomCountRow(ctx, userId);
  if (!row) return;
  if (row.count <= 0) {
    console.warn(
      `userRoomCounts: decrement below zero for ${userId}, clamped (counter had drifted)`,
    );
    if (row.count !== 0) await ctx.db.patch(row._id, { count: 0 });
    return;
  }
  await ctx.db.patch(row._id, { count: row.count - 1 });
}

/** Users looked at per backfill transaction. */
const BACKFILL_USERS = 25;
/** Membership rows one backfill transaction may read (each row is large). */
const BACKFILL_ROW_BUDGET = 300;

/**
 * One-time, paged backfill: counts each user's memberships through
 * `roomMembers.by_user` and writes their `userRoomCounts` row. Users that
 * already have a row (joined since the deploy, or counted by an earlier run)
 * are skipped, so it is idempotent and safe to run while the app is live: the
 * count and the insert are one transaction, and a concurrent join conflicts and
 * retries rather than being lost.
 *
 * Run: `npx convex run roomCounts:backfill` (reschedules itself until done,
 * then logs `done`). Re-running is harmless.
 */
export const backfill = internalMutation({
  args: { after: v.optional(v.number()) },
  returns: v.object({ counted: v.number(), done: v.boolean() }),
  handler: async (ctx, { after }) => {
    // `gte` + skip-if-counted rather than `gt`: two users can share a
    // creation time, and a counted user costs one point read to pass over.
    const users = await ctx.db
      .query("users")
      .withIndex("by_creation_time", (q) => q.gte("_creationTime", after ?? 0))
      .take(BACKFILL_USERS);
    let counted = 0;
    let rowsRead = 0;
    let resumeAt: number | null = null;
    for (const user of users) {
      if (rowsRead >= BACKFILL_ROW_BUDGET) {
        resumeAt = user._creationTime;
        break;
      }
      if (await roomCountRow(ctx, user._id)) continue;
      // A little over the cap, so a system reader past it is still counted.
      const rows = await ctx.db
        .query("roomMembers")
        .withIndex("by_user", (q) => q.eq("userId", user._id))
        .take(MAX_ROOMS_PER_USER + 100);
      rowsRead += rows.length;
      await ctx.db.insert("userRoomCounts", {
        userId: user._id,
        count: rows.length,
      });
      counted++;
    }
    let next: number | null = resumeAt;
    if (next === null && users.length === BACKFILL_USERS) {
      next = users[users.length - 1]._creationTime;
    }
    // No progress possible only if a whole page shares one timestamp and is
    // already counted; step past it rather than spin.
    if (next !== null && next === (after ?? 0) && counted === 0) next += 1;
    if (next !== null) {
      await ctx.scheduler.runAfter(0, internal.roomCounts.backfill, { after: next });
    } else {
      console.log("roomCounts.backfill: done");
    }
    return { counted, done: next === null };
  },
});
