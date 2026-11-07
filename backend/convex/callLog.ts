/**
 * The Calls tab's reads and the owner's few writes (docs/design/calls.md).
 * Rows are written once, at the end of a call, by `callHistory.ts`; here a
 * person can page their history, total it, delete rows and report how a call
 * sounded. Every function runs as the session user (`functions.ts` injects
 * `userId`), so nobody can read or touch another person's rows.
 */
import { v } from "convex/values";
import { paginationOptsValidator } from "convex/server";
import { mutation, query } from "./functions";
import { consume } from "./rateLimit";
import { worsenCallMessageQuality } from "./callHistory";

const SUMMARY_ROWS = 1000;
const SUMMARY_TOP = 8;
const CLEAR_BATCH = 500;
const MAX_SAMPLES = 360;
const QUALITY = ["good", "fair", "poor"] as const;

/** Newest first. "missed" reads its own index range, so it stays one page. */
export const list = query({
  args: {
    paginationOpts: paginationOptsValidator,
    filter: v.union(v.literal("all"), v.literal("missed")),
  },
  handler: async (ctx, { userId, paginationOpts, filter }) => {
    if (filter === "missed") {
      return await ctx.db
        .query("callLog")
        .withIndex("by_user_outcome_started", (q) =>
          q.eq("userId", userId).eq("outcome", "missed"),
        )
        .order("desc")
        .paginate(paginationOpts);
    }
    return await ctx.db
      .query("callLog")
      .withIndex("by_user_started", (q) => q.eq("userId", userId))
      .order("desc")
      .paginate(paginationOpts);
  },
});

/**
 * The stats behind the Calls tab's talk-time sheet, over [since]..now. One
 * bounded read (newest 1000 rows in range, the same read the plain totals
 * always did); every figure below is folded out of those rows in the same
 * pass, so a richer sheet costs CPU for a loop, not another read. `top`
 * counts direct calls only (a group has no single peer).
 *
 * [tzOffsetMin] is the viewer's UTC offset in minutes (local = UTC + offset),
 * so hour-of-day, weekday and streak buckets fall on THEIR clock. Absent: UTC.
 * Streaks count days with an ANSWERED call, in range; `currentStreak` is the
 * run ending today or yesterday.
 */
export const summary = query({
  args: { since: v.number(), tzOffsetMin: v.optional(v.number()) },
  returns: v.object({
    totalMs: v.number(),
    calls: v.number(),
    top: v.array(
      v.object({ peerId: v.id("users"), ms: v.number(), calls: v.number() }),
    ),
    answered: v.number(),
    missed: v.number(),
    outgoing: v.number(),
    incoming: v.number(),
    audioCalls: v.number(),
    videoCalls: v.number(),
    audioMs: v.number(),
    videoMs: v.number(),
    longestMs: v.number(),
    byHour: v.array(v.number()),
    byWeekday: v.array(v.number()),
    activeDays: v.number(),
    bestStreak: v.number(),
    currentStreak: v.number(),
  }),
  handler: async (ctx, { userId, since, tzOffsetMin }) => {
    const rows = await ctx.db
      .query("callLog")
      .withIndex("by_user_started", (q) =>
        q.eq("userId", userId).gte("startedAt", since),
      )
      .order("desc")
      .take(SUMMARY_ROWS);
    const off = Math.max(-14 * 60, Math.min(14 * 60, Math.round(tzOffsetMin ?? 0))) * 60000;
    const DAY = 86400000;
    let totalMs = 0;
    let answered = 0;
    let missed = 0;
    let outgoing = 0;
    let incoming = 0;
    let audioCalls = 0;
    let videoCalls = 0;
    let audioMs = 0;
    let videoMs = 0;
    let longestMs = 0;
    const byHour = new Array<number>(24).fill(0);
    const byWeekday = new Array<number>(7).fill(0); // 0 = Sunday
    const days = new Set<number>();
    const peers = new Map<string, { peerId: any; ms: number; calls: number }>();
    for (const r of rows) {
      totalMs += r.durationMs;
      if (r.outcome === "answered") answered += 1;
      else if (r.outcome === "missed") missed += 1;
      if (r.direction === "out") outgoing += 1;
      else incoming += 1;
      if (r.type === "video") {
        videoCalls += 1;
        videoMs += r.durationMs;
      } else {
        audioCalls += 1;
        audioMs += r.durationMs;
      }
      if (r.durationMs > longestMs) longestMs = r.durationMs;
      const local = r.startedAt + off;
      byHour[Math.floor((((local % DAY) + DAY) % DAY) / 3600000)] += 1;
      const day = Math.floor(local / DAY);
      byWeekday[(((day + 4) % 7) + 7) % 7] += 1; // day 0 (1970-01-01) was a Thursday
      if (r.outcome === "answered") days.add(day);
      if (r.kind !== "direct" || !r.peerId) continue;
      const key = r.peerId.toString();
      const p = peers.get(key) ?? { peerId: r.peerId, ms: 0, calls: 0 };
      p.ms += r.durationMs;
      p.calls += 1;
      peers.set(key, p);
    }
    const top = [...peers.values()]
      .sort((a, b) => b.ms - a.ms || b.calls - a.calls)
      .slice(0, SUMMARY_TOP);
    const sorted = [...days].sort((a, b) => a - b);
    let best = 0;
    let run = 0;
    for (let i = 0; i < sorted.length; i++) {
      run = i > 0 && sorted[i] === sorted[i - 1] + 1 ? run + 1 : 1;
      if (run > best) best = run;
    }
    const today = Math.floor((Date.now() + off) / DAY);
    let current = 0;
    let d = days.has(today) ? today : today - 1;
    while (days.has(d)) {
      current += 1;
      d -= 1;
    }
    return {
      totalMs,
      calls: rows.length,
      top,
      answered,
      missed,
      outgoing,
      incoming,
      audioCalls,
      videoCalls,
      audioMs,
      videoMs,
      longestMs,
      byHour,
      byWeekday,
      activeDays: days.size,
      bestStreak: best,
      currentStreak: current,
    };
  },
});

/** Delete one of my rows. Someone else's (or a missing one) is a no-op. */
export const remove = mutation({
  args: { id: v.id("callLog") },
  returns: v.null(),
  handler: async (ctx, { userId, id }) => {
    const row = await ctx.db.get(id);
    if (row && row.userId.toString() === userId.toString()) {
      await ctx.db.delete(id);
    }
    return null;
  },
});

/** Delete up to 500 of my rows; `more` says call again. */
export const clear = mutation({
  args: {},
  returns: v.object({ more: v.boolean() }),
  handler: async (ctx, { userId }) => {
    const rows = await ctx.db
      .query("callLog")
      .withIndex("by_user_started", (q) => q.eq("userId", userId))
      .take(CLEAR_BATCH);
    for (const r of rows) await ctx.db.delete(r._id);
    return { more: rows.length === CLEAR_BATCH };
  },
});

/**
 * My own report after a call: one 0/1/2 bucket per 10 s connected. Patches my
 * row, and the bubble's `q` only when this is worse than what it already says
 * (the worst of both sides wins). Rate-limited: it is one write per call.
 */
export const reportQuality = mutation({
  args: {
    callId: v.optional(v.id("calls")),
    groupCallId: v.optional(v.id("groupCalls")),
    samples: v.array(v.number()),
  },
  returns: v.null(),
  handler: async (ctx, { userId, callId, groupCallId, samples }) => {
    await consume(ctx, `callq:${userId}`, 20, 60 * 1000);
    if (!callId && !groupCallId) return null;
    const clean = samples
      .slice(0, MAX_SAMPLES)
      .map((n) => (Number.isFinite(n) ? Math.min(2, Math.max(0, Math.round(n))) : 0));
    if (clean.length === 0) return null;
    const worst = QUALITY[Math.max(...clean)];

    const row = callId
      ? await ctx.db
          .query("callLog")
          .withIndex("by_call_user", (q) =>
            q.eq("callId", callId).eq("userId", userId),
          )
          .first()
      : await ctx.db
          .query("callLog")
          .withIndex("by_group_call_user", (q) =>
            q.eq("groupCallId", groupCallId).eq("userId", userId),
          )
          .first();
    if (!row) return null; // not mine, or never recorded
    await ctx.db.patch(row._id, { quality: { worst, samples: clean } });

    // Huddles have no bubble; the call row may be long swept. Both are fine.
    const call = callId
      ? await ctx.db.get(callId)
      : groupCallId
        ? await ctx.db.get(groupCallId)
        : null;
    await worsenCallMessageQuality(ctx, call?.messageId, worst);
    return null;
  },
});
