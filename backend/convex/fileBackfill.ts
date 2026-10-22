/**
 * The one-off backfill that gives every pre-refs file its `fileRefs` rows, and
 * the mark step that flips files to ref-authoritative (Phase 3 of
 * docs/data-integrity-and-scale-plan-2026-10-22.md, section 6 of
 * docs/data-integrity-phase3-design.md). The runbook is in the plan doc.
 *
 * Two phases, both MANUAL to start and both safe to re-run:
 *
 *  1. SCAN (`start`, `step`): walks every table that holds a strong file field
 *     (`FILE_FIELDS`, derived from `fileHold: "ref"` in `referenceRules.ts`),
 *     one `.paginate()` page per step (100 rows for messages, 200 otherwise),
 *     and for each (row, field) calls `files.backfillRef`: make sure the file
 *     has a ledger row (adopted ones are untracked and `uncounted: true`),
 *     insert the ref if absent. A file that no longer exists is tallied as
 *     `missingFile`, never thrown. Re-running inserts nothing new. Progress
 *     lives on a `fileBackfill` row on the `integrity.ts` pattern: a
 *     `runAfter(50)` chain, a run silent for 30 minutes is stalled, `start` or
 *     the hourly `resumeStalled` resume it from its cursor up to 3 times.
 *
 *  2. MARK (`markTracked`): the irreversible step. Flips every untracked file to
 *     tracked. A file with no refs (and not permanent) also gets `zeroSince`, so
 *     the reaper frees it after 24 hours (when `files.reapUnreferenced` is
 *     enabled). Refuses unless the scan is done and the latest FINISHED
 *     integrity run started after it and shows zero `missingRef`/`staleRef`.
 *     Read `files:zeroRefReport` first.
 *
 * Everything here is internal; nothing is reachable by a client.
 */
import { v } from "convex/values";
import { internal } from "./_generated/api";
import type { Doc, Id } from "./_generated/dataModel";
import { internalMutation, internalQuery, type MutationCtx } from "./_generated/server";
import { backfillRef } from "./files";
import { fileRefViolations, holdsRef } from "./integrity";
import { FILE_FIELDS } from "./referenceRules";

export const PAGE_SIZE = 200;
/** Messages hold three file fields and the widest rows, so they page smaller. */
export const PAGE_SIZE_MESSAGES = 100;
export const PAGE_DELAY_MS = 50;
export const STALL_MS = 30 * 60 * 1000;
export const MAX_RESTARTS = 3;
/** Untracked files marked per `markTracked` call. */
export const MARK_BATCH = 100;

/** Tables holding strong file fields, in scan order. */
const SCAN_TABLES: string[] = Object.keys(FILE_FIELDS).sort();

const pageSizeFor = (table: string) => (table === "messages" ? PAGE_SIZE_MESSAGES : PAGE_SIZE);

async function resumeOrFail(ctx: MutationCtx, run: Doc<"fileBackfill">): Promise<"resumed" | "failed"> {
  const now = Date.now();
  if (run.restarts < MAX_RESTARTS) {
    await ctx.db.patch(run._id, { lastProgressAt: now, restarts: run.restarts + 1 });
    await ctx.scheduler.runAfter(0, internal.fileBackfill.step, { runId: run._id });
    return "resumed";
  }
  await ctx.db.patch(run._id, { status: "failed", finishedAt: now });
  // Ids and positions only, never user data.
  console.warn(
    `[fileBackfill] run ${run._id} failed after ${run.restarts} resumes, stuck on table ` +
      `${SCAN_TABLES[run.tableIdx] ?? "(finish)"} at cursor ${run.cursor ?? "(start)"}`,
  );
  return "failed";
}

/** Hourly cron: resume a stalled scan, or fail it after 3 resumes. Never starts one. */
export const resumeStalled = internalMutation({
  args: {},
  handler: async (ctx) => {
    const running = await ctx.db
      .query("fileBackfill")
      .withIndex("by_status", (q) => q.eq("status", "running"))
      .order("desc")
      .first();
    if (!running || Date.now() - running.lastProgressAt < STALL_MS) return null;
    return await resumeOrFail(ctx, running);
  },
});

/** Start the scan. No-op while one is making progress; resumes a stalled one. */
export const start = internalMutation({
  args: {},
  handler: async (ctx) => {
    const now = Date.now();
    const running = await ctx.db
      .query("fileBackfill")
      .withIndex("by_status", (q) => q.eq("status", "running"))
      .order("desc")
      .first();
    if (running) {
      if (now - running.lastProgressAt < STALL_MS) {
        return { started: false, runId: running._id, reason: "running" };
      }
      const outcome = await resumeOrFail(ctx, running);
      if (outcome === "resumed") return { started: true, runId: running._id, reason: "resumed" };
    }
    const runId = await ctx.db.insert("fileBackfill", {
      startedAt: now,
      lastProgressAt: now,
      status: "running",
      tableIdx: 0,
      cursor: null,
      restarts: 0,
      pages: 0,
      rowsScanned: 0,
      inserted: 0,
      existed: 0,
      missingFile: 0,
    });
    await ctx.scheduler.runAfter(0, internal.fileBackfill.step, { runId });
    return { started: true, runId, reason: "new" };
  },
});

/**
 * Who the ledger row of an adopted file should name. Rooms and official stickers
 * have no owner: their files are never charged to anyone.
 */
async function ownerOf(
  ctx: MutationCtx,
  table: string,
  doc: any,
  packOwners: Map<string, Id<"users"> | undefined>,
): Promise<Id<"users"> | undefined> {
  if (table === "users") return doc._id;
  if (table === "rooms") return undefined;
  if (table === "stickers") {
    const key = doc.packId.toString();
    if (!packOwners.has(key)) {
      const pack = await ctx.db.get(doc.packId as Id<"stickerPacks">);
      packOwners.set(key, pack?.kind === "personal" ? pack.ownerId : undefined);
    }
    return packOwners.get(key);
  }
  return doc.userId;
}

/**
 * Official sticker art is never ref'd (hot, shared by every send), so it must
 * be `permanent` or the reaper and the epoch lift would take it. New art is
 * claimed permanent; art from before the ledger, including art of a pack
 * retired before this scan whose old messages still show it, is marked here.
 * Returns false when the file is already gone.
 */
async function ensurePermanent(ctx: MutationCtx, storageId: Id<"_storage">): Promise<boolean> {
  const meta = await ctx.db.system.get(storageId);
  if (!meta) return false;
  const ledger = await ctx.db
    .query("uploads")
    .withIndex("by_storage", (q) => q.eq("storageId", storageId))
    .first();
  if (!ledger) {
    await ctx.db.insert("uploads", {
      storageId,
      size: meta.size ?? 0,
      createdAt: Date.now(),
      uncounted: true,
      permanent: true,
    } as any);
  } else if (!ledger.permanent) {
    await ctx.db.patch(ledger._id, { permanent: true, zeroSince: undefined });
  }
  return true;
}

/** Whether [doc]'s [field] is official sticker art (see [ensurePermanent]). */
async function isOfficialArt(
  ctx: MutationCtx,
  table: string,
  doc: any,
  field: string,
  packKinds: Map<string, string | undefined>,
): Promise<boolean> {
  if (field === "stickerStorageId" && doc.mediaSource === "pack") return true;
  if (table !== "stickers") return false;
  const key = doc.packId.toString();
  if (!packKinds.has(key)) {
    const pack = await ctx.db.get(doc.packId as Id<"stickerPacks">);
    packKinds.set(key, pack?.kind);
  }
  // A missing pack is treated as personal: never pin art we can't vouch for.
  const kind = packKinds.get(key);
  return kind !== undefined && kind !== "personal";
}

/** One page of one table, then reschedule. Dies quietly if the run is not running. */
export const step = internalMutation({
  args: { runId: v.id("fileBackfill") },
  handler: async (ctx, { runId }) => {
    const run = await ctx.db.get(runId);
    if (!run || run.status !== "running") return;
    const table = SCAN_TABLES[run.tableIdx];
    if (!table) {
      await ctx.db.patch(runId, { status: "done", finishedAt: Date.now(), lastProgressAt: Date.now() });
      return;
    }

    const page = await ctx.db
      .query(table as any)
      .paginate({ numItems: pageSizeFor(table), cursor: run.cursor });

    const packOwners = new Map<string, Id<"users"> | undefined>();
    const packKinds = new Map<string, string | undefined>();
    let inserted = 0;
    let existed = 0;
    let missingFile = 0;
    for (const doc of page.page as any[]) {
      for (const field of FILE_FIELDS[table]) {
        const value = doc[field];
        if (typeof value !== "string") continue;
        if (await isOfficialArt(ctx, table, doc, field, packKinds)) {
          if (await ensurePermanent(ctx, value as Id<"_storage">)) existed++;
          else missingFile++;
          continue;
        }
        if (!holdsRef(table, doc, field)) continue;
        const owner = await ownerOf(ctx, table, doc, packOwners);
        const out = await backfillRef(
          ctx,
          value as Id<"_storage">,
          { table, id: doc._id, field },
          owner,
        );
        if (out === "inserted") inserted++;
        else if (out === "exists") existed++;
        else missingFile++;
      }
    }

    const now = Date.now();
    await ctx.db.patch(runId, {
      lastProgressAt: now,
      pages: run.pages + 1,
      rowsScanned: run.rowsScanned + page.page.length,
      inserted: run.inserted + inserted,
      existed: run.existed + existed,
      missingFile: run.missingFile + missingFile,
      tableIdx: page.isDone ? run.tableIdx + 1 : run.tableIdx,
      cursor: page.isDone ? null : page.continueCursor,
    });
    await ctx.scheduler.runAfter(PAGE_DELAY_MS, internal.fileBackfill.step, { runId });
  },
});

/** Why `markTracked` would refuse right now, or null when it may go ahead. */
async function markRefusal(ctx: MutationCtx): Promise<string | null> {
  const scan = await ctx.db.query("fileBackfill").order("desc").first();
  if (!scan || scan.status !== "done" || scan.finishedAt === undefined) {
    return "the file backfill scan has not finished: run fileBackfill:start and wait for status done";
  }
  const verify = await ctx.db.query("integrityRuns").order("desc").first();
  if (!verify || verify.status !== "done" || verify.startedAt <= scan.finishedAt) {
    return "no finished integrity run that started after the scan: run integrity:start, wait for status done, then retry";
  }
  const check = await fileRefViolations(ctx, verify._id);
  if (!check.counted) return "the latest integrity run has no file-ref counters: run integrity:start again";
  if (check.violations > 0) {
    return (
      `the latest integrity run found ${check.violations} file-ref violations (missingRef/staleRef): ` +
      "see integrity:latest, run files:repairRefs for stale ones, rerun the scan and integrity:start"
    );
  }
  return null;
}

/**
 * IRREVERSIBLE. Marks every untracked file tracked, so refs become
 * authoritative for it. A file with no refs (and not permanent art) is also
 * stamped `zeroSince` and freed by `files.reapUnreferenced` 24 hours later, once
 * that is enabled (`FILE_REFS_REAP=1`). Read `files:zeroRefReport` first.
 *
 * Refuses (see [markRefusal]) unless the scan is done and the latest finished
 * integrity run started after it with zero `missingRef`/`staleRef`. Works in
 * batches of [MARK_BATCH] and chains itself until nothing is untracked, then
 * stamps `markedAt` on the scan row (which opens the reaper's gate). Safe to
 * re-run. `dryRun` only reports whether it would refuse.
 *
 *   npx convex run fileBackfill:markTracked '{"dryRun":true}'
 *   npx convex run fileBackfill:markTracked '{}'
 */
export const markTracked = internalMutation({
  args: { dryRun: v.optional(v.boolean()) },
  handler: async (ctx, { dryRun }) => {
    const refusal = await markRefusal(ctx);
    if (refusal) return { ok: false, refused: refusal, marked: 0, queuedForReap: 0, done: false };
    if (dryRun) return { ok: true, refused: null, marked: 0, queuedForReap: 0, done: false };

    const scan = (await ctx.db.query("fileBackfill").order("desc").first())!;
    const now = Date.now();
    const rows = await ctx.db
      .query("uploads")
      .withIndex("by_tracked", (q) => q.eq("tracked", undefined))
      .take(MARK_BATCH);
    let queued = 0;
    for (const row of rows) {
      const hasRef = await ctx.db
        .query("fileRefs")
        .withIndex("by_file_holder", (q) => q.eq("storageId", row.storageId))
        .first();
      if (hasRef || row.permanent) {
        await ctx.db.patch(row._id, { tracked: true, zeroSince: undefined });
      } else {
        await ctx.db.patch(row._id, { tracked: true, zeroSince: now });
        queued++;
      }
    }
    const done = rows.length < MARK_BATCH;
    await ctx.db.patch(scan._id, {
      marked: (scan.marked ?? 0) + rows.length,
      queuedForReap: (scan.queuedForReap ?? 0) + queued,
      ...(done ? { markedAt: now } : {}),
    });
    if (!done) await ctx.scheduler.runAfter(PAGE_DELAY_MS, internal.fileBackfill.markTracked, {});
    return { ok: true, refused: null, marked: rows.length, queuedForReap: queued, done };
  },
});

/** Progress of the latest scan and mark, for the dashboard or a one-off run. */
export const latest = internalQuery({
  args: {},
  handler: async (ctx) => {
    const run = await ctx.db.query("fileBackfill").order("desc").first();
    if (!run) return null;
    return {
      runId: run._id,
      status: run.status,
      startedAt: run.startedAt,
      finishedAt: run.finishedAt ?? null,
      lastProgressAt: run.lastProgressAt,
      progress: {
        table: SCAN_TABLES[run.tableIdx] ?? null,
        tablesDone: Math.min(run.tableIdx, SCAN_TABLES.length),
        tablesTotal: SCAN_TABLES.length,
        pages: run.pages,
        rowsScanned: run.rowsScanned,
        restarts: run.restarts,
      },
      inserted: run.inserted,
      existed: run.existed,
      missingFile: run.missingFile,
      markedAt: run.markedAt ?? null,
      marked: run.marked ?? 0,
      queuedForReap: run.queuedForReap ?? 0,
    };
  },
});
