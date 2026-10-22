import { v } from "convex/values";
import { internalMutation, internalQuery } from "./_generated/server";
import { mutation, query } from "./functions";
import { SESSION_LIVE_CAP, evictExcessLive } from "./sessionCore";

/**
 * The session table's own public surface.
 *
 * Authenticated like everything else — revoking a session is an account
 * action, so it needs one. `userId` here is injected by the wrapper, never
 * taken from the caller; see `functions.ts`.
 */
/** Revoke one device's session. The half of "remove device" that will make it
 *  a real sign-out once enforcement lands. */
export const revokeForDevice = mutation({
  args: { userId: v.id("users"), deviceId: v.string() },
  returns: v.object({ revoked: v.number() }),
  handler: async (ctx, { userId, deviceId }) => {
    const now = Date.now();
    const rows = await ctx.db
      .query("sessions")
      .withIndex("by_user_device", (q) =>
        q.eq("userId", userId).eq("deviceId", deviceId),
      )
      .collect();
    let revoked = 0;
    for (const row of rows) {
      if (row.revokedAt !== undefined) continue;
      await ctx.db.patch(row._id, { revokedAt: now });
      revoked++;
    }
    return { revoked };
  },
});

/** Revoke every session except the caller's own device. */
export const revokeOthers = mutation({
  args: { userId: v.id("users"), deviceId: v.string() },
  returns: v.object({ revoked: v.number() }),
  handler: async (ctx, { userId, deviceId }) => {
    const now = Date.now();
    const rows = await ctx.db
      .query("sessions")
      .withIndex("by_user", (q) => q.eq("userId", userId))
      .collect();
    let revoked = 0;
    for (const row of rows) {
      if (row.deviceId === deviceId || row.revokedAt !== undefined) continue;
      await ctx.db.patch(row._id, { revokedAt: now });
      revoked++;
    }
    return { revoked };
  },
});

/** Live sessions for a user, for the Devices screen to merge with its rows. */
export const listSessions = query({
  args: { userId: v.id("users") },
  returns: v.array(
    v.object({
      deviceId: v.string(),
      createdAt: v.number(),
      lastSeenAt: v.number(),
    }),
  ),
  handler: async (ctx, { userId }) => {
    const rows = await ctx.db
      .query("sessions")
      .withIndex("by_user", (q) => q.eq("userId", userId))
      .collect();
    return rows
      .filter((r) => r.revokedAt === undefined)
      .map((r) => ({
        deviceId: r.deviceId,
        createdAt: r.createdAt,
        lastSeenAt: r.lastSeenAt,
      }));
  },
});

/**
 * How many rows to touch per run of the sweeps below.
 *
 * Same bound every other sweep in this backend takes, for the same reason: a
 * mutation that walks an unbounded table is one bad day away from timing out
 * and never completing at all. Re-run until the answer is 0.
 */
const ORPHAN_PAGE = 200;

/**
 * Live sessions whose account no longer exists.
 *
 * The direct measurement of the `purgeUser` gap: before it revoked sessions,
 * every deleted account left its devices holding a token that still
 * authenticated. This counts what that left behind.
 *
 * Read-only and unbounded on purpose — it is a diagnostic run by hand, and a
 * paged count that could not see the whole table would answer the wrong
 * question. `revokeOrphaned` does the writing, and that one is bounded.
 */
export const countOrphaned = internalQuery({
  args: {},
  returns: v.object({ live: v.number(), orphaned: v.number() }),
  handler: async (ctx) => {
    const rows = await ctx.db
      .query("sessions")
      .withIndex("by_revoked_at", (q) => q.eq("revokedAt", undefined))
      .collect();
    let orphaned = 0;
    for (const row of rows) {
      if ((await ctx.db.get(row.userId)) === null) orphaned++;
    }
    return { live: rows.length, orphaned };
  },
});

/**
 * Revoke the sessions [countOrphaned] finds.
 *
 * Revoke, not delete, to match what `purgeUser` now does on the way out: the
 * device gets SESSION_REVOKED on its next call and `gcRevokedSessions` clears
 * the row a week later.
 *
 * Idempotent — a second run finds nothing, because the rows it revoked are no
 * longer in the `revokedAt === undefined` range it scans.
 */
export const revokeOrphaned = internalMutation({
  args: {},
  returns: v.object({ revoked: v.number(), done: v.boolean() }),
  handler: async (ctx) => {
    const now = Date.now();
    const rows = await ctx.db
      .query("sessions")
      .withIndex("by_revoked_at", (q) => q.eq("revokedAt", undefined))
      .collect();
    let revoked = 0;
    let remaining = 0;
    for (const row of rows) {
      if ((await ctx.db.get(row.userId)) !== null) continue;
      // The bound is on WRITES, not on the scan, and that is the whole trick.
      // Taking the first ORPHAN_PAGE *rows* instead would re-read the same
      // page of healthy sessions on every run and never reach an orphan
      // sitting behind them — a sweep that reports "not done" forever and
      // fixes nothing.
      if (revoked >= ORPHAN_PAGE) {
        remaining++;
        continue;
      }
      await ctx.db.patch(row._id, { revokedAt: now });
      revoked++;
    }
    return { revoked, done: remaining === 0 };
  },
});

/**
 * Pre-flight for `SESSION_TRUSTS_ROW` (sessionCore.ts): live sessions whose
 * account is missing, tombstoned (`deletingAt`) or suspended, plus users
 * holding more than SESSION_LIVE_CAP live sessions (`overCap`, counted once per
 * user). Once the flag flips, `requireSession` stops reading the user, so every
 * such row would authenticate, and an over-cap account could not be closed in
 * one bounded transaction. Flip only when all four counts are 0.
 *
 * Paged so it can see the whole table: pass the returned `nextCursor` back
 * until `isDone`, and sum the counts. Read-only. Fixes: `revokeOrphaned`
 * (missing), re-running the suspension or deletion (suspended, tombstoned),
 * `trimOverCap` (overCap).
 *
 *   npx convex run sessions:auditLiveVsAccounts '{}'
 *   npx convex run sessions:auditLiveVsAccounts '{"cursor":"<nextCursor>"}'
 */
export const auditLiveVsAccounts = internalQuery({
  args: {
    cursor: v.optional(v.union(v.string(), v.null())),
    numItems: v.optional(v.number()),
  },
  returns: v.object({
    scanned: v.number(),
    missing: v.number(),
    tombstoned: v.number(),
    suspended: v.number(),
    overCap: v.number(),
    isDone: v.boolean(),
    nextCursor: v.union(v.string(), v.null()),
  }),
  handler: async (ctx, { cursor, numItems }) => {
    const page = await ctx.db
      .query("sessions")
      .withIndex("by_live_seen", (q) => q.eq("revokedAt", undefined))
      .paginate({ cursor: cursor ?? null, numItems: numItems ?? ORPHAN_PAGE });
    let missing = 0;
    let tombstoned = 0;
    let suspended = 0;
    let overCap = 0;
    const inPage = new Set(page.page.map((r) => r._id));
    const seen = new Set<string>();
    for (const row of page.page) {
      const user = await ctx.db.get(row.userId);
      if (user === null) missing++;
      else if (user.deletingAt !== undefined) tombstoned++;
      else if (user.suspendedAt !== undefined) suspended++;
      // A user is counted on the page holding their (CAP+1)th live session in
      // `lastSeenAt` order (the same order in both indexes), so exactly once.
      if (seen.has(row.userId)) continue;
      seen.add(row.userId);
      const live = await ctx.db
        .query("sessions")
        .withIndex("by_user_live_seen", (q) =>
          q.eq("userId", row.userId).eq("revokedAt", undefined),
        )
        .take(SESSION_LIVE_CAP + 1);
      if (live.length > SESSION_LIVE_CAP && inPage.has(live[SESSION_LIVE_CAP]._id)) {
        overCap++;
      }
    }
    return {
      scanned: page.page.length,
      missing,
      tombstoned,
      suspended,
      overCap,
      isDone: page.isDone,
      nextCursor: page.isDone ? null : page.continueCursor,
    };
  },
});

/**
 * Bring every account down to SESSION_LIVE_CAP live sessions, revoking the
 * oldest with `"evicted"`. Paged like the audit (repeat with `nextCursor` until
 * `isDone`); idempotent. Run until `auditLiveVsAccounts` reports overCap 0.
 *
 *   npx convex run sessions:trimOverCap '{}'
 */
export const trimOverCap = internalMutation({
  args: {
    cursor: v.optional(v.union(v.string(), v.null())),
    numItems: v.optional(v.number()),
  },
  returns: v.object({
    trimmed: v.number(),
    isDone: v.boolean(),
    nextCursor: v.union(v.string(), v.null()),
  }),
  handler: async (ctx, { cursor, numItems }) => {
    const page = await ctx.db
      .query("sessions")
      .withIndex("by_live_seen", (q) => q.eq("revokedAt", undefined))
      .paginate({ cursor: cursor ?? null, numItems: numItems ?? ORPHAN_PAGE });
    const now = Date.now();
    const seen = new Set<string>();
    let trimmed = 0;
    for (const row of page.page) {
      if (seen.has(row.userId)) continue;
      seen.add(row.userId);
      trimmed += await evictExcessLive(ctx, row.userId, SESSION_LIVE_CAP, now);
    }
    return {
      trimmed,
      isDone: page.isDone,
      nextCursor: page.isDone ? null : page.continueCursor,
    };
  },
});
