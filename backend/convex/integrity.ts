/**
 * Paged reference-integrity check (Phase 1, item 4 of
 * docs/data-integrity-and-scale-plan-2026-10-22.md).
 *
 * Convex has no foreign keys, so every `v.id(...)` in the schema can dangle.
 * This walks every table that holds one, a page at a time, and counts the
 * references whose target no longer exists, per reference path.
 *
 * Shape (built to run on millions of rows without a long transaction):
 *  - `start` creates an `integrityRuns` row and schedules `step`.
 *  - `step` reads ONE page of ONE table (`.paginate`, small pages), checks
 *    every reference in those rows with one `db.get` per distinct id (cached
 *    within the page), folds the counts into that table's `integrityCounts` row (the run row
 *    only gets its cursor and progress), and reschedules
 *    itself with `runAfter(PAGE_DELAY_MS)`. The cursor and table position live
 *    on the run row, so nothing is held in memory between pages.
 *  - A page reads at most `pageSize` docs plus one get per distinct referenced
 *    id: 200 rows for tables with no array references, 50 for tables with
 *    array references, so even 50 rows x 50 ids stays far under Convex's
 *    16k-reads-per-transaction limit.
 *  - One run at a time: `start` while a run is making progress is a no-op. A
 *    run silent for 30 minutes is stalled; `start` resumes it from its cursor
 *    (up to 3 times, then marks it failed and begins a fresh run), and the
 *    hourly `resumeStalled` cron does the same without ever starting one.
 *
 * File refs (Phase 3): beyond dangling ids the scan also checks the `fileRefs`
 * table against its holders, as two more counters per run:
 *  - `<table>.<field>#missingRef`: a strong file field (`FILE_FIELDS`) whose
 *    file exists but has no ref row for that holder (not for official art,
 *    deleted stickers or answered change requests, which hold none).
 *  - `fileRefs#staleRef`: a ref whose holder row is gone or whose field no
 *    longer points at the file.
 * Both are violations; `fileBackfill.markTracked` refuses while either is non-zero.
 *
 * Ephemeral rules get a grace period: a dangling id on a short-lived row
 * younger than EPHEMERAL_GRACE_MS is counted as `inGrace`, not `dangling`,
 * because its TTL sweep has not had its turn yet.
 *
 * Read the result with `internal.integrity.latest` (dashboard or one-off run).
 * Everything here is internal; nothing is reachable by a client.
 */
import { v } from "convex/values";
import { internal } from "./_generated/api";
import type { Doc, Id } from "./_generated/dataModel";
import {
  internalMutation,
  internalQuery,
  type MutationCtx,
} from "./_generated/server";
import { FILE_FIELDS, REFERENCE_RULES } from "./referenceRules";
import schema from "./schema";
import { refKey, schemaRefs, type SchemaRef } from "./schemaRefs";

export const PAGE_SIZE = 200;
/** Tables with array references read fewer rows per page. */
export const PAGE_SIZE_ARRAYS = 50;
export const PAGE_DELAY_MS = 50;
export const STALL_MS = 30 * 60 * 1000;
export const MAX_RESTARTS = 3;
export const MAX_EXAMPLES = 5;
/** A dangling id on an `ephemeral` row younger than this is not yet a violation. */
export const EPHEMERAL_GRACE_MS = 2 * 24 * 60 * 60 * 1000;

const EXPECTED_RULES = new Set(["history", "softRef"]);

const ALL_REFS: SchemaRef[] = schemaRefs(schema as any);
/** Tables that hold at least one reference, sorted, with their paths. */
const SCAN_TABLES: { table: string; refs: SchemaRef[] }[] = (() => {
  const by = new Map<string, SchemaRef[]>();
  for (const r of ALL_REFS) {
    const list = by.get(r.table) ?? [];
    list.push(r);
    by.set(r.table, list);
  }
  return [...by.entries()]
    .sort(([a], [b]) => a.localeCompare(b))
    .map(([table, refs]) => ({ table, refs }));
})();

/** Every string at `path` in `doc` ("a.b", "a[].b", "a{}"). Absent/null skipped. */
export function valuesAt(doc: any, path: string): string[] {
  const tokens = path.match(/\[\]|\{\}|[^.[\]{}]+/g) ?? [];
  let level: any[] = [doc];
  for (const tok of tokens) {
    const next: any[] = [];
    for (const node of level) {
      if (node === null || node === undefined) continue;
      if (tok === "[]") {
        if (Array.isArray(node)) next.push(...node);
      } else if (tok === "{}") {
        if (typeof node === "object") next.push(...Object.values(node));
      } else if (typeof node === "object") {
        next.push(node[tok]);
      }
    }
    level = next;
  }
  return level.filter((x) => typeof x === "string");
}

/** Counter key for a strong file field with no ref row. */
export const missingRefKey = (table: string, field: string) => `${table}.${field}#missingRef`;
/** Counter key for a ref whose holder or field is gone. */
export const STALE_REF_KEY = "fileRefs#staleRef";

/** Whether [key] is one of the file-ref counters above. */
export const isFileRefKey = (key: string) => key.endsWith("#missingRef") || key === STALE_REF_KEY;

/** The counters a table's `integrityCounts` row carries beyond its reference paths. */
function fileRefKeys(table: string): string[] {
  const keys = (FILE_FIELDS[table] ?? []).map((f) => missingRefKey(table, f));
  if (table === "fileRefs") keys.push(STALE_REF_KEY);
  return keys;
}

const pageSizeFor = (refs: SchemaRef[], override?: number) =>
  override ?? (refs.some((r) => r.array) ? PAGE_SIZE_ARRAYS : PAGE_SIZE);

async function exists(ctx: MutationCtx, target: string, id: string): Promise<boolean> {
  try {
    const doc = target.startsWith("_")
      ? await ctx.db.system.get(id as any)
      : await ctx.db.get(id as Id<any>);
    return doc !== null;
  } catch {
    // A malformed id cannot resolve to anything.
    return false;
  }
}

interface Count {
  key: string;
  checked: number;
  dangling: number;
  inGrace: number;
  examples: string[];
}

export interface PathReport extends Count {
  target: string;
  rule: string;
  expected: boolean;
}

/** Splits a run's counts into expected (history/softRef) and violations. */
export function summarize(run: { counts: Count[] }) {
  const targetOf = new Map(ALL_REFS.map((r) => [refKey(r), r.target]));
  const paths: PathReport[] = run.counts.map((c) => {
    const fileRef = isFileRefKey(c.key);
    const rule = fileRef ? "fileRef" : (REFERENCE_RULES[c.key]?.rule ?? "unruled");
    return {
      ...c,
      target: fileRef ? "fileRefs" : (targetOf.get(c.key) ?? "?"),
      rule,
      expected: EXPECTED_RULES.has(rule),
    };
  });
  const sum = (xs: PathReport[]) => xs.reduce((n, p) => n + p.dangling, 0);
  const expected = paths.filter((p) => p.expected && p.dangling > 0);
  const violations = paths.filter((p) => !p.expected && p.dangling > 0);
  return {
    expectedDangling: sum(expected),
    violationDangling: sum(violations),
    fileRefViolations: sum(paths.filter((p) => isFileRefKey(p.key))),
    expected,
    violations,
    cleanPaths: paths.filter((p) => p.dangling === 0).length,
    paths,
  };
}

/**
 * Rows of a strong-file table that legitimately hold no ref for their field:
 * a deleted personal sticker released it, a decided change request handed the
 * file to the room, and a sent official-pack sticker is never ref'd (hot,
 * permanent art). Shared with `fileBackfill`, which skips the same rows.
 */
export function holdsRef(table: string, doc: any, field: string): boolean {
  if (field === "stickerStorageId" && doc.mediaSource === "pack") return false;
  if (table === "stickers") return doc.deletedAt === undefined;
  if (table === "roomChangeRequests") return doc.status === "pending";
  return true;
}

/** Whether [holderId]'s [field] has a ref on the file, or the file is permanent art. */
async function hasRef(ctx: MutationCtx, storageId: string, holderId: string, field: string) {
  const ref = await ctx.db
    .query("fileRefs")
    .withIndex("by_file_holder", (q) =>
      q.eq("storageId", storageId as Id<"_storage">).eq("holderId", holderId).eq("field", field),
    )
    .first();
  if (ref) return true;
  const ledger = await ctx.db
    .query("uploads")
    .withIndex("by_storage", (q) => q.eq("storageId", storageId as Id<"_storage">))
    .first();
  return ledger?.permanent === true;
}

/** Counts [ref] when its holder row is gone or its field no longer holds the file. */
async function checkStale(ctx: MutationCtx, ref: Doc<"fileRefs">, c: Count) {
  c.checked++;
  let holder: any = null;
  try {
    const id = ctx.db.normalizeId(ref.holderTable as any, ref.holderId);
    holder = id ? await ctx.db.get(id as Id<any>) : null;
  } catch {
    // An unknown table cannot hold anything.
  }
  if (holder && holder[ref.field]?.toString() === ref.storageId.toString()) return;
  c.dangling++;
  if (c.examples.length < MAX_EXAMPLES) {
    c.examples.push(`${ref.holderTable}:${ref.holderId}.${ref.field}->${ref.storageId}`);
  }
}

async function resumeOrFail(
  ctx: MutationCtx,
  run: Doc<"integrityRuns">,
): Promise<"resumed" | "failed"> {
  const now = Date.now();
  if (run.restarts < MAX_RESTARTS) {
    await ctx.db.patch(run._id, { lastProgressAt: now, restarts: run.restarts + 1 });
    await ctx.scheduler.runAfter(0, internal.integrity.step, { runId: run._id });
    return "resumed";
  }
  await ctx.db.patch(run._id, { status: "failed", finishedAt: now });
  // Ids and positions only, never user data.
  console.warn(
    `[integrity] run ${run._id} failed after ${run.restarts} resumes, stuck on table ` +
      `${SCAN_TABLES[run.tableIdx]?.table ?? "(finish)"} at cursor ${run.cursor ?? "(start)"}`,
  );
  return "failed";
}

/**
 * What `fileBackfill.markTracked` asks of a finished run: whether it carried the
 * file-ref counters at all (an older run did not) and how many violations they
 * hold (`missingRef` plus `staleRef`).
 */
export async function fileRefViolations(
  ctx: { db: any },
  runId: Id<"integrityRuns">,
): Promise<{ counted: boolean; violations: number }> {
  const fileCounts = (await countsOf(ctx, runId)).filter((c) => isFileRefKey(c.key));
  return {
    counted: fileCounts.some((c) => c.key === STALE_REF_KEY),
    violations: fileCounts.reduce((n, c) => n + c.dangling, 0),
  };
}

async function countsOf(ctx: { db: any }, runId: Id<"integrityRuns">): Promise<Count[]> {
  const rows = await ctx.db
    .query("integrityCounts")
    .withIndex("by_run_table", (q: any) => q.eq("runId", runId))
    .collect(); // bounded: one row per table that holds references
  return rows.flatMap((r: any) => r.counts as Count[]);
}

/** Hourly cron: resume a stalled run, or fail it after 3 resumes. Never starts one. */
export const resumeStalled = internalMutation({
  args: {},
  handler: async (ctx) => {
    const running = await ctx.db
      .query("integrityRuns")
      .withIndex("by_status", (q) => q.eq("status", "running"))
      .order("desc")
      .first();
    if (!running || Date.now() - running.lastProgressAt < STALL_MS) return null;
    return await resumeOrFail(ctx, running);
  },
});

/** Start a run. No-op while one is making progress; resumes a stalled one. */
export const start = internalMutation({
  args: { pageSize: v.optional(v.number()) },
  handler: async (ctx, args) => {
    const now = Date.now();
    const running = await ctx.db
      .query("integrityRuns")
      .withIndex("by_status", (q) => q.eq("status", "running"))
      .order("desc")
      .first();
    if (running) {
      if (now - running.lastProgressAt < STALL_MS) {
        return { started: false, runId: running._id, reason: "running" };
      }
      const outcome = await resumeOrFail(ctx, running);
      if (outcome === "resumed") {
        return { started: true, runId: running._id, reason: "resumed" };
      }
    }
    const runId = await ctx.db.insert("integrityRuns", {
      startedAt: now,
      lastProgressAt: now,
      status: "running",
      tableIdx: 0,
      cursor: null,
      pageSize: args.pageSize,
      restarts: 0,
      pages: 0,
      rowsScanned: 0,
    });
    for (const { table, refs } of SCAN_TABLES) {
      await ctx.db.insert("integrityCounts", {
        runId,
        table,
        counts: [...refs.map((r) => refKey(r)), ...fileRefKeys(table)].map((key) => ({
          key,
          checked: 0,
          dangling: 0,
          inGrace: 0,
          examples: [],
        })),
      });
    }
    await ctx.scheduler.runAfter(0, internal.integrity.step, { runId });
    return { started: true, runId, reason: "new" };
  },
});

/** One page of one table, then reschedule. Dies quietly if the run is not running. */
export const step = internalMutation({
  args: { runId: v.id("integrityRuns") },
  handler: async (ctx, { runId }) => {
    const run = await ctx.db.get(runId);
    if (!run || run.status !== "running") return;
    const now = Date.now();
    const entry = SCAN_TABLES[run.tableIdx];
    if (!entry) {
      await finish(ctx, run);
      return;
    }

    const page = await ctx.db
      .query(entry.table as any)
      .paginate({
        numItems: pageSizeFor(entry.refs, run.pageSize),
        cursor: run.cursor,
      });

    const countRow = (await ctx.db
      .query("integrityCounts")
      .withIndex("by_run_table", (q) => q.eq("runId", runId).eq("table", entry.table))
      .unique())!;
    const counts = new Map<string, Count>(
      countRow.counts.map((c) => [c.key, { ...c, examples: [...c.examples] }]),
    );
    const seen = new Map<string, boolean>();
    const strong = new Set(FILE_FIELDS[entry.table] ?? []);
    const stale = entry.table === "fileRefs" ? counts.get(STALE_REF_KEY) : undefined;
    for (const doc of page.page as any[]) {
      if (stale) await checkStale(ctx, doc, stale);
      for (const ref of entry.refs) {
        const key = refKey(ref);
        const c = counts.get(key)!;
        const ephemeral = REFERENCE_RULES[key]?.rule === "ephemeral";
        for (const id of valuesAt(doc, ref.path)) {
          c.checked++;
          const cacheKey = `${ref.target}:${id}`;
          let ok = seen.get(cacheKey);
          if (ok === undefined) {
            ok = await exists(ctx, ref.target, id);
            seen.set(cacheKey, ok);
          }
          if (ok) {
            if (strong.has(ref.path) && holdsRef(entry.table, doc, ref.path)) {
              const m = counts.get(missingRefKey(entry.table, ref.path));
              if (m) {
                m.checked++;
                if (!(await hasRef(ctx, id, doc._id, ref.path))) {
                  m.dangling++;
                  if (m.examples.length < MAX_EXAMPLES) m.examples.push(`${doc._id}->${id}`);
                }
              }
            }
            continue;
          }
          if (ephemeral && now - doc._creationTime < EPHEMERAL_GRACE_MS) {
            c.inGrace++;
            continue;
          }
          c.dangling++;
          if (c.examples.length < MAX_EXAMPLES) c.examples.push(`${doc._id}->${id}`);
        }
      }
    }

    await ctx.db.patch(countRow._id, {
      counts: countRow.counts.map((c) => counts.get(c.key)!),
    });
    await ctx.db.patch(runId, {
      lastProgressAt: now,
      pages: run.pages + 1,
      rowsScanned: run.rowsScanned + page.page.length,
      tableIdx: page.isDone ? run.tableIdx + 1 : run.tableIdx,
      cursor: page.isDone ? null : page.continueCursor,
    });
    await ctx.scheduler.runAfter(PAGE_DELAY_MS, internal.integrity.step, { runId });
  },
});

async function finish(
  ctx: MutationCtx,
  run: { _id: Id<"integrityRuns"> },
) {
  await ctx.db.patch(run._id, { status: "done", finishedAt: Date.now() });
  const s = summarize({ counts: await countsOf(ctx, run._id) });
  if (s.violations.length > 0) {
    // Ids and counts only, never user data.
    console.warn(
      `[integrity] run ${run._id}: ${s.violationDangling} violating dangling refs on ${s.violations.length} paths: ` +
        s.violations
          .slice(0, 20)
          .map((p) => `${p.key}[${p.rule}]=${p.dangling}`)
          .join(", "),
    );
  }
}

/** Summary of the latest run (finished or in flight), for the dashboard. */
export const latest = internalQuery({
  args: {},
  handler: async (ctx) => {
    const run = await ctx.db.query("integrityRuns").order("desc").first();
    if (!run) return null;
    const counts = await countsOf(ctx, run._id);
    const s = summarize({ counts });
    return {
      runId: run._id,
      status: run.status,
      startedAt: run.startedAt,
      finishedAt: run.finishedAt ?? null,
      lastProgressAt: run.lastProgressAt,
      progress: {
        table: SCAN_TABLES[run.tableIdx]?.table ?? null,
        tablesDone: Math.min(run.tableIdx, SCAN_TABLES.length),
        tablesTotal: SCAN_TABLES.length,
        pages: run.pages,
        rowsScanned: run.rowsScanned,
        restarts: run.restarts,
      },
      expectedDangling: s.expectedDangling,
      violationDangling: s.violationDangling,
      fileRefViolations: s.fileRefViolations,
      violations: s.violations,
      expected: s.expected,
      cleanPaths: s.cleanPaths,
      graceTotal: counts.reduce((n, c) => n + c.inGrace, 0),
    };
  },
});
