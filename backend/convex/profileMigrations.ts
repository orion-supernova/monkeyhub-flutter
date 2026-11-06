// Phase 6 profile migrations (stage W1 of the rollout).
//
//   backfillProfiles   W1. Calls `syncProfile` for every user, so each one has
//                      a `profiles` row (a tombstone for a deleted account).
//                      A no-op write when the row is already right, so it is
//                      idempotent and safe next to live writers.
//   countMissingProfiles   progress counter, reaches 0.
//
// `stripCopies` / `countCopies` (the W3 strip of the denormalised name and
// avatar copies on nine tables) are gone: the strip finished in production,
// the copy fields left the schema (cleanup deploy 1), and no test or caller
// can build such a row any more.
//
// Both walk one table with a single `.paginate` and chain themselves with the
// scheduler, so each page is its own small transaction.
//
// Never touched: `messages.mentions[].username`, call/push payloads, game
// names (`matches.seats[].name`, `seatRequest.name`, `gameChallenges.name`).
import { v } from "convex/values";
import { internal } from "./_generated/api";
import { internalQuery } from "./_generated/server";
import { internalMutation } from "./dbHooks";
import { syncProfile } from "./profilesCore";

/** Users per backfill page: one user get, one profile probe, <= 1 write each. */
export const BACKFILL_PAGE = 100;
/** Rows per counting page (read only). */
export const COUNT_PAGE = 200;

const cursorArg = v.optional(v.union(v.string(), v.null()));

export const backfillProfiles = internalMutation({
  args: {
    cursor: cursorArg,
    numItems: v.optional(v.number()),
    changed: v.optional(v.number()),
    unchanged: v.optional(v.number()),
    pages: v.optional(v.number()),
  },
  handler: async (ctx, args) => {
    const page = await ctx.db
      .query("users")
      .paginate({ cursor: args.cursor ?? null, numItems: args.numItems ?? BACKFILL_PAGE });

    let changed = args.changed ?? 0;
    let unchanged = args.unchanged ?? 0;
    for (const user of page.page) {
      // syncProfile builds a tombstone for a user marked `deletingAt`.
      const r = await syncProfile(ctx, user._id);
      if (r.changed) changed++;
      else unchanged++;
    }

    const pages = (args.pages ?? 0) + 1;
    if (!page.isDone) {
      await ctx.scheduler.runAfter(0, internal.profileMigrations.backfillProfiles, {
        cursor: page.continueCursor,
        numItems: args.numItems,
        changed,
        unchanged,
        pages,
      });
    } else {
      console.log(`backfillProfiles done: written=${changed} alreadyRight=${unchanged} pages=${pages}`);
    }
    return { done: page.isDone, changed, unchanged, pages };
  },
});

/** One page of "users with no profile row". Add up `missing` until `isDone`. */
export const countMissingProfiles = internalQuery({
  args: { cursor: cursorArg, numItems: v.optional(v.number()) },
  handler: async (ctx, args) => {
    const page = await ctx.db
      .query("users")
      .paginate({ cursor: args.cursor ?? null, numItems: args.numItems ?? COUNT_PAGE });
    let missing = 0;
    for (const user of page.page) {
      const row = await ctx.db
        .query("profiles")
        .withIndex("by_user", (q) => q.eq("userId", user._id))
        .first();
      if (!row) missing++;
    }
    return { missing, scanned: page.page.length, isDone: page.isDone, continueCursor: page.continueCursor };
  },
});
