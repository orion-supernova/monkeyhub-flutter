import { v } from "convex/values";
import { internal } from "./_generated/api";
import { internalMutation } from "./dbHooks";
import { refreshPendingCounts, refreshPushState } from "./userDerivedCore";

/**
 * One-off backfill of the two derived per-user rows (`userPushState`,
 * `userBadgeCounts`; see `userDerivedCore.ts`):
 *
 *     npx convex run userDerived:backfill '{}'
 *
 * Self-scheduling, a few users per transaction, idempotent: each row is
 * recomputed from the source tables and overwritten, so it can be re-run any
 * time. Until a user is reached, readers fall back to the old computation.
 */
const PAGE = 10;

export const backfill = internalMutation({
  args: { cursor: v.optional(v.union(v.string(), v.null())) },
  returns: v.null(),
  handler: async (ctx, { cursor }) => {
    const page = await ctx.db
      .query("users")
      .paginate({ cursor: cursor ?? null, numItems: PAGE });
    for (const user of page.page) {
      await refreshPushState(ctx.db, user._id);
      await refreshPendingCounts(ctx.db, user._id);
    }
    if (!page.isDone) {
      await ctx.scheduler.runAfter(0, internal.userDerived.backfill, {
        cursor: page.continueCursor,
      });
    } else {
      console.log("userDerived.backfill: done");
    }
    return null;
  },
});
