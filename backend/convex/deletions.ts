/**
 * The driver for `deletions` jobs (docs/data-integrity-phase2-design.md).
 *
 *  - `step` is the entry point every chain link runs: it calls `stepInner` in a
 *    sub-transaction, so a throwing step rolls back its own writes and the
 *    failure is recorded here (attempts, backoff). Convex rolls back a nested
 *    `ctx.runMutation` that throws even when the caller catches it, and so does
 *    convex-test.
 *  - `stepInner` runs as many plan steps as the budget allows, persists where it
 *    got to in the same transaction, and schedules the next link.
 *  - `redrive` (cron, 5 minutes) restarts jobs that went silent and gives up on
 *    ones that keep doing so; `prune` (daily) drops old finished rows.
 *  - `retry` and `summary` are for a person at the dashboard.
 *
 * A job's `restarts` is its chain generation: a link scheduled by an older
 * generation exits, so a cron re-drive never runs two chains at once.
 */
import { v } from "convex/values";
import { internal } from "./_generated/api";
import type { Id } from "./_generated/dataModel";
import { internalMutation, internalQuery } from "./_generated/server";
import { Budget, testHooks } from "./deletionCore";
import { planFor } from "./deletionPlans";
import { postOutcome } from "./moderationCore";

/** Consecutive failures before the link stops rescheduling itself (the cron takes over). */
export const MAX_ATTEMPTS = 5;
/** A running job silent this long is stalled. */
export const STALL_MS = 10 * 60 * 1000;
/** Re-drives before a job is marked failed. */
export const MAX_RESTARTS = 6;
/** Finished rows are kept this long. */
export const KEEP_DONE_MS = 30 * 24 * 60 * 60 * 1000;

const REDRIVE_BATCH = 50;
const PRUNE_BATCH = 200;

/** First line only, quoted text redacted unless it is an id: the row says ids, never content. */
function safeError(e: unknown): string {
  const raw = e instanceof Error ? e.message : String(e);
  const line = raw.split("\n")[0];
  return line
    .replace(/(["'])([^"']*)\1/g, (m, _q, inner) =>
      /^[a-z0-9]{20,40}$/.test(inner) ? m : '"?"',
    )
    .slice(0, 200);
}

export const step = internalMutation({
  args: { jobId: v.id("deletions"), gen: v.number() },
  handler: async (ctx, { jobId, gen }) => {
    const job = await ctx.db.get(jobId);
    if (!job || job.state !== "running" || job.restarts !== gen) return;
    try {
      await ctx.runMutation(internal.deletions.stepInner, { jobId, gen });
    } catch (e) {
      // The sub-transaction rolled back; note the failure and back off.
      const attempts = job.attempts + 1;
      const lastError = safeError(e);
      await ctx.db.patch(jobId, { attempts, lastError });
      console.warn(
        `deletion step failed kind=${job.kind} id=${job.targetId} step=${job.stepId} attempt=${attempts}: ${lastError}`,
      );
      if (attempts < MAX_ATTEMPTS) {
        await ctx.scheduler.runAfter(2 ** attempts * 1000, internal.deletions.step, {
          jobId,
          gen,
        });
      }
      // Else: left for `redrive`, which restarts it once it has been silent.
    }
  },
});

export const stepInner = internalMutation({
  args: { jobId: v.id("deletions"), gen: v.number() },
  handler: async (ctx, { jobId, gen }) => {
    const job = await ctx.db.get(jobId);
    if (!job || job.state !== "running" || job.restarts !== gen) return;

    const plan = planFor(job.kind);
    let idx = job.stepId === "" ? 0 : plan.findIndex((s) => s.id === job.stepId);
    let cursor = job.cursor;
    // The plan changed under a deploy: start over. Every step is idempotent.
    if (idx < 0) {
      idx = 0;
      cursor = null;
    }

    const b = new Budget();
    let finished = plan.length === 0;
    while (!finished) {
      const s = plan[idx];
      await testHooks.beforeStep?.(ctx, job, s);
      const r = await s.run(ctx, { ...job, stepId: s.id, cursor }, b);
      if (!r.done) {
        cursor = r.cursor ?? null;
        break;
      }
      idx++;
      cursor = null;
      if (idx >= plan.length) finished = true;
      else if (b.spent()) break;
    }

    const now = Date.now();
    const patch = {
      stepId: finished ? (plan[plan.length - 1]?.id ?? "") : plan[idx].id,
      cursor,
      lastProgressAt: now,
      pages: job.pages + 1,
      writes: job.writes + b.writes,
      attempts: 0,
      lastError: undefined,
    };
    if (finished) {
      await ctx.db.patch(jobId, { ...patch, state: "done" as const, finishedAt: now });
    } else {
      await ctx.db.patch(jobId, patch);
      await ctx.scheduler.runAfter(0, internal.deletions.step, { jobId, gen });
    }
  },
});

/** Restart jobs that went silent; give up on ones that keep doing so. */
export const redrive = internalMutation({
  args: {},
  handler: async (ctx) => {
    const now = Date.now();
    const stalled = await ctx.db
      .query("deletions")
      .withIndex("by_state_progress", (q) =>
        q.eq("state", "running").lt("lastProgressAt", now - STALL_MS),
      )
      .take(REDRIVE_BATCH);
    for (const job of stalled) {
      if (job.restarts >= MAX_RESTARTS) {
        await ctx.db.patch(job._id, {
          state: "failed",
          finishedAt: now,
          lastError: job.lastError ?? "gave up after repeated re-drives",
        });
        console.error(
          `deletion FAILED kind=${job.kind} id=${job.targetId} step=${job.stepId} job=${job._id}`,
        );
        await ctx.scheduler.runAfter(0, internal.deletions.alertFailed, {
          jobId: job._id,
        });
        continue;
      }
      const gen = job.restarts + 1;
      await ctx.db.patch(job._id, {
        restarts: gen,
        attempts: 0,
        lastProgressAt: now,
      });
      await ctx.scheduler.runAfter(0, internal.deletions.step, {
        jobId: job._id,
        gen,
      });
    }
  },
});

/**
 * Tell staff a job gave up. Ids only: the job, what it was deleting and where
 * it stopped. It goes where staff already get alerts (the moderation inbox,
 * posted as Monkey Reporter, with the same push a report card sends). A
 * separate mutation so a failure here cannot undo marking the job failed.
 */
export const alertFailed = internalMutation({
  args: { jobId: v.id("deletions") },
  handler: async (ctx, { jobId }) => {
    const job = await ctx.db.get(jobId);
    if (!job || job.state !== "failed") return;
    const text = [
      "Deletion job gave up",
      `Kind: ${job.kind}`,
      `Target: ${job.targetId}`,
      `Step: ${job.stepId || "(not started)"}`,
      `Re-drives: ${job.restarts}`,
      `Job: ${job._id}`,
      "Retry: internal.deletions.retry with this job id.",
    ].join("\n");
    const messageId = (await postOutcome(ctx, {}, text)) as
      | Id<"messages">
      | undefined;
    if (!messageId) return;
    const msg = await ctx.db.get(messageId);
    if (!msg) return;
    await ctx.scheduler.runAfter(0, internal.notifications.sendMessagePush, {
      roomId: msg.roomId,
      messageId,
      senderId: msg.userId,
      senderName: msg.senderName ?? "Monkey Reporter",
      content: "Deletion job gave up",
      type: "text",
    });
  },
});

/** Drop finished jobs older than 30 days. */
export const prune = internalMutation({
  args: {},
  handler: async (ctx) => {
    const cutoff = Date.now() - KEEP_DONE_MS;
    // `finishedAt` is set on every done row; the lower bound keeps an unset
    // one (which sorts lowest) from matching.
    const old = await ctx.db
      .query("deletions")
      .withIndex("by_state_finished", (q) =>
        q.eq("state", "done").gt("finishedAt", 0).lt("finishedAt", cutoff),
      )
      .take(PRUNE_BATCH);
    for (const job of old) await ctx.db.delete(job._id);
    if (old.length === PRUNE_BATCH) {
      await ctx.scheduler.runAfter(0, internal.deletions.prune, {});
    }
  },
});

/** Put a failed job back to work (dashboard: `deletions:retry`). */
export const retry = internalMutation({
  args: { jobId: v.id("deletions") },
  handler: async (ctx, { jobId }) => {
    const job = await ctx.db.get(jobId);
    if (!job || job.state !== "failed") return null;
    await ctx.db.patch(jobId, {
      state: "running",
      finishedAt: undefined,
      restarts: 0,
      attempts: 0,
      lastProgressAt: Date.now(),
    });
    await ctx.scheduler.runAfter(0, internal.deletions.step, { jobId, gen: 0 });
    return jobId;
  },
});

/** Counts by state (capped) and the failed rows. For the dashboard. */
export const summary = internalQuery({
  args: {},
  handler: async (ctx) => {
    const CAP = 1000;
    const counts: Record<string, string> = {};
    for (const state of ["running", "done", "failed"] as const) {
      const rows = await ctx.db
        .query("deletions")
        .withIndex("by_state_progress", (q) => q.eq("state", state))
        .take(CAP + 1);
      counts[state] = rows.length > CAP ? `${CAP}+` : String(rows.length);
    }
    const failed = await ctx.db
      .query("deletions")
      .withIndex("by_state_progress", (q) => q.eq("state", "failed"))
      .take(50);
    return {
      counts,
      failed: failed.map((j) => ({
        jobId: j._id,
        kind: j.kind,
        targetId: j.targetId,
        stepId: j.stepId,
        restarts: j.restarts,
        lastError: j.lastError,
      })),
    };
  },
});
