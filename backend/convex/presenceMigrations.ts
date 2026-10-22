// Phase 5 presence migrations (stages W1 and W4 of the rollout).
//
//   backfillPresence    W1. Creates `presence` + `presenceBeats` rows from
//                       `users.status/lastSeen/visibility` for every user that
//                       has none. Idempotent; rows the new endpoints wrote win.
//   stripUsersPresence  W4. Clears `users.status/lastSeen`. Refuses to run until
//                       `PRESENCE_COMPAT_MIRROR=off`.
//   countMissingPresence / countUsersWithPresenceFields  progress counters.
//
// All of them walk `users` with one `.paginate` per function and chain
// themselves with the scheduler, so each page is its own small transaction.
import { v } from "convex/values";
import { internal } from "./_generated/api";
import { internalMutation, internalQuery } from "./_generated/server";
import { isTombstoned } from "./deletionCore";
import { isPresenceStatus } from "./presenceCore";
import { isSystemAccount } from "./systemAccount";

/** Users per backfill page: 2 probes + up to 2 inserts each. */
export const BACKFILL_PAGE = 100;
/** Users per strip tick. Each patch re-runs that user's friend lists. */
export const STRIP_PAGE = 50;
/** Pause between strip ticks. */
export const STRIP_TICK_MS = 5_000;
/** Users per counting page (read only). */
export const COUNT_PAGE = 200;

/** True when this user gets no presence (tombstoned, or a system account). */
function skipsPresence(user: any): boolean {
  return isTombstoned(user) || isSystemAccount(user);
}

export const backfillPresence = internalMutation({
  args: {
    cursor: v.optional(v.union(v.string(), v.null())),
    numItems: v.optional(v.number()),
    created: v.optional(v.number()),
    existing: v.optional(v.number()),
    skipped: v.optional(v.number()),
    pages: v.optional(v.number()),
  },
  handler: async (ctx, args) => {
    const now = Date.now();
    const page = await ctx.db
      .query("users")
      .paginate({ cursor: args.cursor ?? null, numItems: args.numItems ?? BACKFILL_PAGE });

    let created = args.created ?? 0;
    let existing = args.existing ?? 0;
    let skipped = args.skipped ?? 0;
    for (const user of page.page) {
      if (skipsPresence(user)) {
        skipped++;
        continue;
      }
      const has = await ctx.db
        .query("presence")
        .withIndex("by_user", (q) => q.eq("userId", user._id))
        .first();
      if (has) {
        existing++;
        continue;
      }
      // Same semantics as presenceCore.writePresence: lastSeen is absent
      // while online. No status (never signed in) reads as offline.
      const status = isPresenceStatus(user.status) ? user.status : "offline";
      const lastSeen = status === "online" ? undefined : user.lastSeen;
      await ctx.db.insert("presence", {
        userId: user._id,
        status,
        ...(lastSeen !== undefined ? { lastSeen } : {}),
        ...(user.visibility?.status !== undefined
          ? { statusLevel: user.visibility.status }
          : {}),
        ...(user.visibility?.lastSeen !== undefined
          ? { lastSeenLevel: user.visibility.lastSeen }
          : {}),
      });
      const beat = await ctx.db
        .query("presenceBeats")
        .withIndex("by_user", (q) => q.eq("userId", user._id))
        .first();
      if (!beat) {
        await ctx.db.insert("presenceBeats", {
          userId: user._id,
          beatAt: user.lastSeen ?? now,
          live: status !== "offline",
        });
      }
      created++;
    }

    const pages = (args.pages ?? 0) + 1;
    if (!page.isDone) {
      await ctx.scheduler.runAfter(0, internal.presenceMigrations.backfillPresence, {
        cursor: page.continueCursor,
        numItems: args.numItems,
        created,
        existing,
        skipped,
        pages,
      });
    } else {
      console.log(
        `backfillPresence done: created=${created} alreadyHadRow=${existing} skipped(system/tombstoned)=${skipped} pages=${pages}`,
      );
    }
    return { done: page.isDone, created, existing, skipped, pages };
  },
});

export const stripUsersPresence = internalMutation({
  args: {
    cursor: v.optional(v.union(v.string(), v.null())),
    numItems: v.optional(v.number()),
    stripped: v.optional(v.number()),
    pages: v.optional(v.number()),
  },
  handler: async (ctx, args) => {
    if (process.env.PRESENCE_COMPAT_MIRROR !== "off") {
      throw new Error(
        'stripUsersPresence refused: set PRESENCE_COMPAT_MIRROR=off first (stage W3). Old builds still read users.status/lastSeen.',
      );
    }
    const page = await ctx.db
      .query("users")
      .paginate({ cursor: args.cursor ?? null, numItems: args.numItems ?? STRIP_PAGE });

    let stripped = args.stripped ?? 0;
    const before = stripped;
    for (const user of page.page) {
      // Already clean: no write, so no re-run of anyone's friend lists.
      if (user.status === undefined && user.lastSeen === undefined) continue;
      await ctx.db.patch(user._id, { status: undefined, lastSeen: undefined });
      stripped++;
    }

    const pages = (args.pages ?? 0) + 1;
    if (!page.isDone) {
      // The pause is for the friend lists our patches re-run; a page that
      // wrote nothing re-ran nothing, so the next one goes straight away.
      const pause = stripped > before ? STRIP_TICK_MS : 0;
      await ctx.scheduler.runAfter(pause, internal.presenceMigrations.stripUsersPresence, {
        cursor: page.continueCursor,
        numItems: args.numItems,
        stripped,
        pages,
      });
    } else {
      console.log(`stripUsersPresence done: stripped=${stripped} pages=${pages}`);
    }
    return { done: page.isDone, stripped, pages };
  },
});

/**
 * One page of "users that should have a presence row and don't". Call with the
 * returned `continueCursor` until `isDone`; add up `missing`.
 */
export const countMissingPresence = internalQuery({
  args: { cursor: v.optional(v.union(v.string(), v.null())), numItems: v.optional(v.number()) },
  handler: async (ctx, args) => {
    const page = await ctx.db
      .query("users")
      .paginate({ cursor: args.cursor ?? null, numItems: args.numItems ?? COUNT_PAGE });
    let missing = 0;
    for (const user of page.page) {
      if (skipsPresence(user)) continue;
      const has = await ctx.db
        .query("presence")
        .withIndex("by_user", (q) => q.eq("userId", user._id))
        .first();
      if (!has) missing++;
    }
    return { missing, scanned: page.page.length, isDone: page.isDone, continueCursor: page.continueCursor };
  },
});

/** One page of "users still carrying users.status or users.lastSeen". */
export const countUsersWithPresenceFields = internalQuery({
  args: { cursor: v.optional(v.union(v.string(), v.null())), numItems: v.optional(v.number()) },
  handler: async (ctx, args) => {
    const page = await ctx.db
      .query("users")
      .paginate({ cursor: args.cursor ?? null, numItems: args.numItems ?? COUNT_PAGE });
    let carrying = 0;
    for (const user of page.page) {
      if (user.status !== undefined || user.lastSeen !== undefined) carrying++;
    }
    return { carrying, scanned: page.page.length, isDone: page.isDone, continueCursor: page.continueCursor };
  },
});
