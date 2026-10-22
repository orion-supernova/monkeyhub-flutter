import { v } from "convex/values";
import type { MutationCtx } from "./_generated/server";

/**
 * Self-rescheduling cleanups.
 *
 * A sweep that takes "the first N rows of its range" per cron firing can only
 * ever delete N rows per firing, so once the table grows faster than that the
 * backlog grows forever (plan section 5, "Cleanups that can't keep up").
 * Every sweep that deletes the rows it ranges over uses this instead: take one
 * page, and if the page came back full, schedule the same function again with
 * `runAfter(0)` so the next page is its own small transaction.
 *
 * `chain` counts the runs since the cron fired. It is capped so that a table
 * that refills as fast as it drains (or a bug that stops a page from shrinking
 * its range) ends after [MAX_SWEEP_CHAIN] pages and waits for the next firing
 * rather than looping the scheduler forever.
 */
export const MAX_SWEEP_CHAIN = 50;

/** The one optional argument every chained sweep accepts; the cron passes none. */
export const sweepArgs = { chain: v.optional(v.number()) };

/**
 * Schedule the next page of [fn] when this one was [full] and the cap allows.
 * Returns whether it did. [fn] is the sweep's own internal function reference.
 */
export async function continueSweep(
  ctx: MutationCtx,
  fn: any,
  full: boolean,
  chain: number | undefined,
): Promise<boolean> {
  const n = chain ?? 0;
  if (!full || n + 1 >= MAX_SWEEP_CHAIN) return false;
  await ctx.scheduler.runAfter(0, fn, { chain: n + 1 });
  return true;
}
