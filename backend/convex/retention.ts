import { v } from "convex/values";
import { internal } from "./_generated/api";
import type { Doc } from "./_generated/dataModel";
import { internalMutation } from "./_generated/server";
import { eraseMatch } from "./matchCore";
import { removeMessageBounded } from "./messages";
import { releaseRowFiles } from "./files";
import { CODE_GAME, foldSolveIntoYear, yearOfDayKey } from "./recordBook";
import { SYSTEM_ROOM_LOGS, LOG_USERNAME, LOG_FORMER_USERNAMES } from "./systemAccount";
import { continueSweep, sweepArgs } from "./sweep";

/**
 * Retention: how long rows live once nobody needs them (plan section 7).
 *
 * Every sweep here is one paged internal mutation, ranges on an index with BOTH
 * ends bound (an unset optional field sorts below every number, so a bare
 * `lt(field, cutoff)` would match rows that never had the field), and
 * reschedules itself through `sweep.ts` while its page comes back full. The
 * crons in `crons.ts` fire each one once a day; a backlog drains in one firing.
 *
 * Rows with children never take a raw delete: a game goes through `eraseMatch`,
 * a message through `removeMessageBounded`, and rows holding a file release it
 * through `releaseRowFiles`.
 *
 * A cutoff is `now - period`, and a row is removed only when its timestamp is
 * strictly BELOW it, so a row exactly one period old is still kept.
 */

const DAY = 24 * 60 * 60 * 1000;

/** Rows per page for sweeps whose rows have no children. */
const PAGE = 200;
/** Rows per page when each row costs a handful of writes. */
const PAGE_HEAVY = 25;
/** Result rows folded per page: a read, a year-row write and a delete each. */
const PAGE_RESULTS = 100;

export const RETENTION = {
  typingIdleMs: 1 * DAY,
  /** Views are kept this long after their moment expired. */
  momentViewsMs: 7 * DAY,
  finishedGameMs: 90 * DAY,
  /** Daily results older than this are folded into `gameResultYears`. */
  resultDays: 365,
  failedScheduledMs: 30 * DAY,
  decidedRequestMs: 90 * DAY,
  deadInviteMs: 90 * DAY,
  consumedCodeMs: 1 * DAY,
  logRoomMessageMs: 90 * DAY,
  integrityRunMs: 8 * 7 * DAY,
} as const;

/**
 * How long a moment is visible after posting (`feed.ts` `VISIBLE_MS`). Only used
 * to bound the view sweep by `viewedAt`: a view happened while its moment was
 * up, so it is at most this much older than the moment's expiry.
 */
const MOMENT_VISIBLE_MS = 1 * DAY;

/** A `YYYY-MM-DD` key (UTC) for [ms]. */
function isoDay(ms: number): string {
  return new Date(ms).toISOString().slice(0, 10);
}

// ── Room bans ───────────────────────────────────────────────────────────────

/** Bans whose `until` has passed: `assertNotRemoved` already ignores them. */
export const gcExpiredRoomBans = internalMutation({
  args: sweepArgs,
  returns: v.null(),
  handler: async (ctx, { chain }) => {
    const now = Date.now();
    const rows = await ctx.db
      .query("roomBans")
      .withIndex("by_until", (q) => q.gte("until", 0).lt("until", now))
      .take(PAGE);
    for (const row of rows) await ctx.db.delete(row._id);
    await continueSweep(ctx, internal.retention.gcExpiredRoomBans, rows.length === PAGE, chain);
    return null;
  },
});

// ── Typing indicators ───────────────────────────────────────────────────────

/** Rows idle for a day: a client that died mid-sentence, or an old zeroed row. */
export const gcIdleTyping = internalMutation({
  args: sweepArgs,
  returns: v.null(),
  handler: async (ctx, { chain }) => {
    const cutoff = Date.now() - RETENTION.typingIdleMs;
    const rows = await ctx.db
      .query("typingIndicators")
      .withIndex("by_updated", (q) => q.gte("updatedAt", 0).lt("updatedAt", cutoff))
      .take(PAGE);
    for (const row of rows) await ctx.db.delete(row._id);
    await continueSweep(ctx, internal.retention.gcIdleTyping, rows.length === PAGE, chain);
    return null;
  },
});

// ── Moment views ────────────────────────────────────────────────────────────

/**
 * Views of moments that expired more than 7 days ago. Ranged by `viewedAt`
 * (a view cannot be older than 24 h before its moment's expiry, so anything
 * viewed before `now - 7d - 24h` belongs to a moment expired for at least 7
 * days); each view still checks its moment, so a longer-lived moment would keep
 * its views rather than lose them.
 */
export const gcMomentViews = internalMutation({
  args: sweepArgs,
  returns: v.null(),
  handler: async (ctx, { chain }) => {
    const now = Date.now();
    const expiredBefore = now - RETENTION.momentViewsMs;
    const rows = await ctx.db
      .query("momentViews")
      .withIndex("by_viewed_at", (q) =>
        q.gte("viewedAt", 0).lt("viewedAt", expiredBefore - MOMENT_VISIBLE_MS),
      )
      .take(PAGE);
    let deleted = 0;
    for (const row of rows) {
      const moment = await ctx.db.get(row.momentId);
      if (moment && moment.expiresAt >= expiredBefore) continue;
      await ctx.db.delete(row._id);
      deleted++;
    }
    // Chain on progress only: skipped rows stay at the head of the range.
    await continueSweep(
      ctx,
      internal.retention.gcMomentViews,
      rows.length === PAGE && deleted > 0,
      chain,
    );
    return null;
  },
});

// ── Finished games ──────────────────────────────────────────────────────────

/**
 * Finished and abandoned games older than 90 days: the match, its moves, hidden
 * state and heartbeats. The chat result card (and any move bubble) is a message
 * and stays, hence `skipBubbles`.
 */
export const gcFinishedMatches = internalMutation({
  args: sweepArgs,
  returns: v.null(),
  handler: async (ctx, { chain }) => {
    const cutoff = Date.now() - RETENTION.finishedGameMs;
    let full = false;
    for (const status of ["finished", "abandoned"]) {
      const rows = await ctx.db
        .query("matches")
        .withIndex("by_status_finished", (q) =>
          q.eq("status", status).gt("finishedAt", 0).lt("finishedAt", cutoff),
        )
        .take(PAGE_HEAVY);
      for (const row of rows) await eraseMatch(ctx, row._id, { skipBubbles: true });
      if (rows.length === PAGE_HEAVY) full = true;
    }
    await continueSweep(ctx, internal.retention.gcFinishedMatches, full, chain);
    return null;
  },
});

// ── Daily game and puzzle results ───────────────────────────────────────────

/**
 * The first day key (UTC) that is still kept in full: results on earlier days
 * are folded. A result exactly [RETENTION.resultDays] days old stays.
 */
export function resultCutoffDayKey(now: number): string {
  return isoDay(now - RETENTION.resultDays * DAY);
}

/**
 * Folds one solve into its player's row for that game and year.
 * Rows arrive oldest day first (the `by_day` index), which the streak fold needs.
 */
async function foldSolve(
  ctx: any,
  userId: any,
  game: string,
  solve: { best?: number; dayKey: string; achievedAt: number },
  year: string,
) {
  const row: Doc<"gameResultYears"> | null = await ctx.db
    .query("gameResultYears")
    .withIndex("by_user_game_year", (q: any) =>
      q.eq("userId", userId).eq("game", game).eq("year", year),
    )
    .first();
  const next = foldSolveIntoYear(row, solve);
  if (row) await ctx.db.patch(row._id, next);
  else await ctx.db.insert("gameResultYears", { userId, game, year, ...next } as any);
}

/**
 * Results more than a year old: solved ones are folded into `gameResultYears`
 * (the only thing that still needs them is `records:backfill`), then every row,
 * solved or not, is deleted. A row whose day key is not a date cannot take part
 * in any streak and is just dropped.
 *
 * Fold and delete happen in the same transaction per row, so a failure leaves
 * both undone and a re-run cannot count a solve twice.
 */
export const foldOldResults = internalMutation({
  args: sweepArgs,
  returns: v.null(),
  handler: async (ctx, { chain }) => {
    const cutoff = resultCutoffDayKey(Date.now());
    let full = false;

    const games = await ctx.db
      .query("gameResults")
      .withIndex("by_day", (q) => q.gte("dayKey", "0").lt("dayKey", cutoff))
      .take(PAGE_RESULTS);
    for (const row of games) {
      const year = yearOfDayKey(row.dayKey);
      if (year && row.solved && row.durationMs !== undefined) {
        await foldSolve(
          ctx,
          row.userId,
          row.game,
          {
            ...((row.hintsUsed ?? 0) === 0 ? { best: row.durationMs } : {}),
            dayKey: row.dayKey,
            achievedAt: row.finishedAt ?? row.startedAt,
          },
          year,
        );
      }
      await ctx.db.delete(row._id);
    }
    if (games.length === PAGE_RESULTS) full = true;

    const puzzles = await ctx.db
      .query("puzzleResults")
      .withIndex("by_day", (q) => q.gte("dayKey", "0").lt("dayKey", cutoff))
      .take(PAGE_RESULTS);
    for (const row of puzzles) {
      const year = yearOfDayKey(row.dayKey);
      if (year && row.solved) {
        await foldSolve(
          ctx,
          row.userId,
          CODE_GAME,
          {
            best: row.guesses.length,
            dayKey: row.dayKey,
            achievedAt: row.finishedAt ?? row.updatedAt,
          },
          year,
        );
      }
      await ctx.db.delete(row._id);
    }
    if (puzzles.length === PAGE_RESULTS) full = true;

    await continueSweep(ctx, internal.retention.foldOldResults, full, chain);
    return null;
  },
});

// ── Failed scheduled messages ───────────────────────────────────────────────

/** Scheduled messages that failed to send more than 30 days ago, photo released. */
export const gcFailedScheduled = internalMutation({
  args: sweepArgs,
  returns: v.null(),
  handler: async (ctx, { chain }) => {
    const cutoff = Date.now() - RETENTION.failedScheduledMs;
    const rows = await ctx.db
      .query("scheduledMessages")
      .withIndex("by_failed_at", (q) => q.gt("failedAt", 0).lt("failedAt", cutoff))
      .take(PAGE);
    for (const row of rows) {
      // A failed row is not `pending`, so a retry cannot be racing us; its job
      // has already run.
      if (row.pending === true) continue;
      await ctx.db.delete(row._id);
      await releaseRowFiles(ctx, "scheduledMessages", row);
    }
    await continueSweep(ctx, internal.retention.gcFailedScheduled, rows.length === PAGE, chain);
    return null;
  },
});

// ── Decided requests ────────────────────────────────────────────────────────

/**
 * Decided invitations, join requests, change requests and denied or revoked
 * approvals, 90 days after the decision. Each index leads with `status`, and
 * only the decided statuses are ranged, so a pending row (or an approved
 * guardian permission) is outside every range by construction.
 */
export const gcDecidedRequests = internalMutation({
  args: sweepArgs,
  returns: v.null(),
  handler: async (ctx, { chain }) => {
    const cutoff = Date.now() - RETENTION.decidedRequestMs;
    let full = false;
    const done = (rows: any[]) => {
      if (rows.length === PAGE) full = true;
    };

    for (const status of ["accepted", "rejected", "cancelled"]) {
      const rows = await ctx.db
        .query("roomInvitations")
        .withIndex("by_status_responded", (q) =>
          q.eq("status", status).gt("respondedAt", 0).lt("respondedAt", cutoff),
        )
        .take(PAGE);
      for (const row of rows) await ctx.db.delete(row._id);
      done(rows);
    }
    for (const status of ["approved", "rejected"]) {
      const rows = await ctx.db
        .query("roomJoinRequests")
        .withIndex("by_status_decided", (q) =>
          q.eq("status", status).gt("decidedAt", 0).lt("decidedAt", cutoff),
        )
        .take(PAGE);
      for (const row of rows) await ctx.db.delete(row._id);
      done(rows);

      const changes = await ctx.db
        .query("roomChangeRequests")
        .withIndex("by_status_decided", (q) =>
          q.eq("status", status).gt("decidedAt", 0).lt("decidedAt", cutoff),
        )
        .take(PAGE);
      for (const row of changes) {
        await ctx.db.delete(row._id);
        // Decided rows already let go of their file; this is the net.
        await releaseRowFiles(ctx, "roomChangeRequests", row);
      }
      done(changes);
    }
    // "approved" approvals are live permissions and are never ranged over.
    for (const status of ["denied", "revoked"]) {
      const rows = await ctx.db
        .query("approvalRequests")
        .withIndex("by_status_decided", (q) =>
          q.eq("status", status).gt("decidedAt", 0).lt("decidedAt", cutoff),
        )
        .take(PAGE);
      for (const row of rows) await ctx.db.delete(row._id);
      done(rows);
    }

    await continueSweep(ctx, internal.retention.gcDecidedRequests, full, chain);
    return null;
  },
});

// ── Dead invite links ───────────────────────────────────────────────────────

/** Join requests an invite still names are pointed at nothing first (`setNull`). */
const INVITE_REQUESTS_PER_PASS = 100;

/**
 * Invite links revoked or expired more than 90 days ago. The join requests that
 * came through a link keep their row and lose the pointer. A link with more
 * requests than one pass clears is left for the next firing.
 */
export const gcDeadInvites = internalMutation({
  args: sweepArgs,
  returns: v.null(),
  handler: async (ctx, { chain }) => {
    const cutoff = Date.now() - RETENTION.deadInviteMs;
    let full = false;
    const sweep = async (rows: Doc<"roomInvites">[]) => {
      for (const invite of rows) {
        const requests = await ctx.db
          .query("roomJoinRequests")
          .withIndex("by_invite", (q) => q.eq("inviteId", invite._id))
          .take(INVITE_REQUESTS_PER_PASS + 1);
        for (const r of requests.slice(0, INVITE_REQUESTS_PER_PASS)) {
          await ctx.db.patch(r._id, { inviteId: undefined });
        }
        if (requests.length > INVITE_REQUESTS_PER_PASS) continue;
        await ctx.db.delete(invite._id);
      }
      if (rows.length === PAGE_HEAVY) full = true;
    };
    await sweep(
      await ctx.db
        .query("roomInvites")
        .withIndex("by_revoked", (q) => q.gt("revokedAt", 0).lt("revokedAt", cutoff))
        .take(PAGE_HEAVY),
    );
    await sweep(
      await ctx.db
        .query("roomInvites")
        .withIndex("by_expires", (q) => q.gt("expiresAt", 0).lt("expiresAt", cutoff))
        .take(PAGE_HEAVY),
    );
    await continueSweep(ctx, internal.retention.gcDeadInvites, full, chain);
    return null;
  },
});

// ── Guardian pairing and release codes ──────────────────────────────────────

/**
 * Pairing and release codes a day past their expiry. A code is consumed within
 * its few minutes of life, so "expired or consumed a day ago" is one range.
 */
export const gcFamilyCodes = internalMutation({
  args: sweepArgs,
  returns: v.null(),
  handler: async (ctx, { chain }) => {
    const cutoff = Date.now() - RETENTION.consumedCodeMs;
    const pairing = await ctx.db
      .query("pairingCodes")
      .withIndex("by_expires", (q) => q.gte("expiresAt", 0).lt("expiresAt", cutoff))
      .take(PAGE);
    for (const row of pairing) await ctx.db.delete(row._id);
    const release = await ctx.db
      .query("releaseCodes")
      .withIndex("by_expires", (q) => q.gte("expiresAt", 0).lt("expiresAt", cutoff))
      .take(PAGE);
    for (const row of release) await ctx.db.delete(row._id);
    await continueSweep(
      ctx,
      internal.retention.gcFamilyCodes,
      pairing.length === PAGE || release.length === PAGE,
      chain,
    );
    return null;
  },
});

// ── Problem-report log room ─────────────────────────────────────────────────

/**
 * The delivered bug reports (messages in the staff log room) 90 days after they
 * were filed, matching the receipts in `problemReports`. The room is found
 * through the log account's memberships, as `systemRooms` does.
 */
export const gcLogRoomMessages = internalMutation({
  args: sweepArgs,
  returns: v.null(),
  handler: async (ctx, { chain }) => {
    const cutoff = Date.now() - RETENTION.logRoomMessageMs;
    let full = false;
    for (const username of [LOG_USERNAME, ...LOG_FORMER_USERNAMES]) {
      const account = await ctx.db
        .query("users")
        .withIndex("by_username", (q) => q.eq("username", username))
        .first();
      if (!account) continue;
      const memberships = await ctx.db
        .query("roomMembers")
        .withIndex("by_user", (q) => q.eq("userId", account._id))
        .take(20);
      for (const m of memberships) {
        const room = await ctx.db.get(m.roomId);
        if (!room || room.system !== SYSTEM_ROOM_LOGS) continue;
        const messages = await ctx.db
          .query("messages")
          .withIndex("by_room_time", (q) =>
            q.eq("roomId", room._id).gt("createdAt", 0).lt("createdAt", cutoff),
          )
          .take(PAGE_HEAVY);
        for (const msg of messages) await removeMessageBounded(ctx, msg, msg._id);
        if (messages.length === PAGE_HEAVY) full = true;
      }
    }
    await continueSweep(ctx, internal.retention.gcLogRoomMessages, full, chain);
    return null;
  },
});

// ── Integrity scan history ──────────────────────────────────────────────────

/** Counters per run are one row per table of the schema; bounded, cleared in one go. */
const COUNTS_PER_RUN = 500;

/** Scan runs older than 8 weeks, their counter rows first. */
export const gcIntegrityRuns = internalMutation({
  args: sweepArgs,
  returns: v.null(),
  handler: async (ctx, { chain }) => {
    const cutoff = Date.now() - RETENTION.integrityRunMs;
    const runs = await ctx.db
      .query("integrityRuns")
      .withIndex("by_started", (q) => q.gt("startedAt", 0).lt("startedAt", cutoff))
      .take(PAGE_HEAVY);
    let deleted = 0;
    for (const run of runs) {
      const counts = await ctx.db
        .query("integrityCounts")
        .withIndex("by_run_table", (q) => q.eq("runId", run._id))
        .take(COUNTS_PER_RUN + 1);
      for (const c of counts.slice(0, COUNTS_PER_RUN)) await ctx.db.delete(c._id);
      // The run row goes only once nothing points at it.
      if (counts.length > COUNTS_PER_RUN) continue;
      await ctx.db.delete(run._id);
      deleted++;
    }
    await continueSweep(
      ctx,
      internal.retention.gcIntegrityRuns,
      runs.length === PAGE_HEAVY && deleted > 0,
      chain,
    );
    return null;
  },
});
