// Presence endpoints (Phase 5). The write logic lives in presenceCore.ts; this
// file is the authed surface, the rate limit, and the sweep.
//
//   beat         the 90 s keepalive. Usually a pure read (see noteBeat).
//   setStatus    foreground / background / sign-out transitions.
//   forUsers     the one subscription the app holds for "who is online".
//   sweepStale   cron: demote clients whose beat went quiet.
//
// `forUsers` never reads `users`: the privacy levels it needs are copied on the
// presence row, and each id costs at most three point reads (`canSeeAs`), so a
// subscription is bounded however many friends the viewer has.
import { v } from "convex/values";
import { internal } from "./_generated/api";
import { internalMutation } from "./_generated/server";
import { mutation, query } from "./functions";
import { PRESENCE_OFFLINE_MS } from "./presence";
import {
  demoteStale,
  noteBeat,
  setStatus as setPresenceStatus,
} from "./presenceCore";
import { consume } from "./rateLimit";
import { touchSessions } from "./sessionCore";
import { continueSweep, sweepArgs } from "./sweep";
import { canSeeAs } from "./visibilityPoint";

/** Most ids one `forUsers` subscription may watch. */
export const FOR_USERS_CAP = 100;
/** Beats demoted per sweep page. */
export const SWEEP_PAGE = 200;

const fgStatus = v.union(v.literal("online"), v.literal("away"));
const anyStatus = v.union(v.literal("online"), v.literal("away"), v.literal("offline"));

/**
 * The keepalive. [status] is what the client is doing right now, so a beat
 * after the sweep demoted a sleeping phone brings the user back as it was.
 */
export const beat = mutation({
  args: { status: fgStatus },
  handler: async (ctx, { userId, status }) => {
    // Session idle expiry's "refreshed on use"; an index probe most of the time.
    await touchSessions(ctx, userId);
    await noteBeat(ctx, userId, { now: Date.now(), resurrect: status });
    return null;
  },
});

/** A status transition. Repeats are free; flip-flopping is rate limited. */
export const setStatus = mutation({
  args: { status: anyStatus },
  handler: async (ctx, { userId, status }) => {
    const now = Date.now();
    const current = await ctx.db
      .query("presence")
      .withIndex("by_user", (q) => q.eq("userId", userId))
      .first();
    // Only a real change counts against the limit: a repeat writes nothing
    // (setStatus drops it), so charging for it would starve honest clients.
    if (!current || current.status !== status) {
      try {
        await consume(ctx, `presence:${userId}`, 20, 60 * 1000);
      } catch {
        return null; // over the limit: dropped, not refused
      }
    }
    await setPresenceStatus(ctx, userId, status, { now });
    return null;
  },
});

/**
 * Presence for up to [FOR_USERS_CAP] users, as the caller may see it.
 * `s` only if the status is visible; `ls` only if lastSeen is visible and set.
 * A user with no presence row (never seen, system account, deleted) is `{id}`.
 */
export const forUsers = query({
  args: { ids: v.array(v.id("users")) },
  handler: async (ctx, { userId: viewerId, ids }) => {
    if (ids.length > FOR_USERS_CAP) throw new Error("TOO_MANY_IDS");
    const seen = new Set<string>();
    const out: { id: string; s?: string; ls?: number }[] = [];
    for (const id of ids) {
      if (seen.has(id)) continue;
      seen.add(id);
      const row = await ctx.db
        .query("presence")
        .withIndex("by_user", (q) => q.eq("userId", id))
        .first();
      const item: { id: string; s?: string; ls?: number } = { id };
      if (row) {
        if (await canSeeAs(ctx, viewerId, id, row.statusLevel, "status")) {
          item.s = row.status;
        }
        if (
          row.lastSeen != null &&
          (await canSeeAs(ctx, viewerId, id, row.lastSeenLevel, "lastSeen"))
        ) {
          item.ls = row.lastSeen;
        }
      }
      out.push(item);
    }
    return out;
  },
});

/**
 * Cron: a query does not re-run because time passed, so a vanished client
 * only reads offline once this lands. One page per run, chained while full.
 */
export const sweepStale = internalMutation({
  args: sweepArgs,
  handler: async (ctx, { chain }) => {
    const now = Date.now();
    const cutoff = now - PRESENCE_OFFLINE_MS;
    const stale = await ctx.db
      .query("presenceBeats")
      .withIndex("by_live_beat", (q) => q.eq("live", true).lt("beatAt", cutoff))
      .take(SWEEP_PAGE);
    for (const b of stale) {
      await demoteStale(ctx, b.userId, b.beatAt, { now });
    }
    await continueSweep(
      ctx,
      internal.presenceApi.sweepStale,
      stale.length === SWEEP_PAGE,
      chain,
    );
  },
});
