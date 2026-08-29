import { v } from "convex/values";
import { internalMutation, internalQuery } from "./_generated/server";
import { mutation, query } from "./functions";

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
