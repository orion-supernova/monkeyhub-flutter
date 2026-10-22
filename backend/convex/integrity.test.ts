import { convexTest } from "convex-test";
import { afterEach, beforeEach, describe, expect, test, vi } from "vitest";
import { internal } from "./_generated/api";
import type { Id } from "./_generated/dataModel";
import { EPHEMERAL_GRACE_MS, STALL_MS, valuesAt } from "./integrity";
import schema from "./schema";

/**
 * The paged integrity scan. Pages are forced down to 2 rows so a handful of
 * rows crosses several reschedules of `step`, which is the cursor path that
 * matters at millions of rows.
 */

type T = ReturnType<typeof convexTest>;

beforeEach(() => {
  vi.useFakeTimers();
});
afterEach(() => {
  vi.useRealTimers();
  vi.restoreAllMocks();
});

const drain = (t: T) => t.finishAllScheduledFunctions(vi.runAllTimers);

async function seed(t: T) {
  return await t.run(async (ctx) => {
    const user = (username: string) =>
      ctx.db.insert("users", { username, passwordHash: "x", createdAt: 1 });
    const u1 = await user("u1");
    const u2 = await user("u2");
    const ghost = await user("ghost");
    await ctx.db.delete(ghost);

    const liveBlob = await ctx.storage.store(new Blob(["live"]));
    const deadBlob = await ctx.storage.store(new Blob(["dead"]));
    await ctx.storage.delete(deadBlob);
    await ctx.db.patch(u1, { avatarStorageId: deadBlob });
    await ctx.db.patch(u2, { avatarStorageId: liveBlob });

    // blocks: 7 clean rows and 2 dangling (one per column), cascade rules.
    for (let i = 0; i < 7; i++) {
      await ctx.db.insert("blocks", { userId: u1, blockedUserId: u2, createdAt: i });
    }
    await ctx.db.insert("blocks", { userId: u1, blockedUserId: ghost, createdAt: 8 });
    await ctx.db.insert("blocks", { userId: ghost, blockedUserId: u2, createdAt: 9 });

    // reports: setNull (reporterId) and history (reportedUserId) both dangle.
    await ctx.db.insert("reports", {
      targetType: "user", targetId: "x", reason: "r", createdAt: 1,
      reporterId: ghost, reportedUserId: ghost,
    });
    await ctx.db.insert("reports", {
      targetType: "user", targetId: "x", reason: "r", createdAt: 2,
      reporterId: u1, reportedUserId: u2,
    });

    // calls.roomId is ephemeral: a dead room on a fresh call row.
    const room = await ctx.db.insert("rooms", {
      name: "r", createdBy: u1, createdAt: 1, isPrivate: false, memberCount: 0,
    });
    await ctx.db.insert("calls", {
      callerId: u1, calleeId: u2, roomId: room, type: "audio", status: "ended", startedAt: 1,
    });
    await ctx.db.delete(room);
    return { u1, u2, ghost };
  });
}

const row = (list: { key: string }[], key: string) =>
  list.find((p) => p.key === key) as any;

describe("integrity scan", () => {
  test("counts dangling refs per path across pages and splits expected from violations", async () => {
    const t = convexTest(schema);
    await seed(t);
    const warn = vi.spyOn(console, "warn").mockImplementation(() => {});

    const r = await t.mutation(internal.integrity.start, { pageSize: 2 });
    expect(r.started).toBe(true);
    await drain(t);

    const s = (await t.query(internal.integrity.latest, {}))!;
    expect(s.status).toBe("done");
    // 9 blocks at 2 per page alone is 5 pages, so the cursor was exercised.
    expect(s.progress.pages).toBeGreaterThan(8);
    expect(s.progress.tablesDone).toBe(s.progress.tablesTotal);

    const v = s.violations;
    expect(row(v, "blocks.blockedUserId")).toMatchObject({ rule: "cascade", checked: 9, dangling: 1 });
    expect(row(v, "blocks.userId")).toMatchObject({ rule: "cascade", checked: 9, dangling: 1 });
    expect(row(v, "reports.reporterId")).toMatchObject({ rule: "setNull", checked: 2, dangling: 1 });
    expect(row(v, "users.avatarStorageId")).toMatchObject({ rule: "file", checked: 2, dangling: 1 });
    expect(row(v, "blocks.blockedUserId").examples).toHaveLength(1);
    expect(v.map((p) => p.key).sort()).toEqual([
      "blocks.blockedUserId",
      "blocks.userId",
      "reports.reporterId",
      "users.avatarStorageId",
    ]);
    expect(s.violationDangling).toBe(4);

    // history dangles on purpose and is reported apart, not as a violation.
    expect(s.expected.map((p) => p.key)).toEqual(["reports.reportedUserId"]);
    expect(s.expectedDangling).toBe(1);

    // The ephemeral row is inside its grace period: not a violation.
    expect(row(v, "calls.roomId")).toBeUndefined();
    expect(s.graceTotal).toBe(1);

    expect(warn).toHaveBeenCalledTimes(1);
    expect(warn.mock.calls[0][0]).toContain("blocks.userId[cascade]=1");
    expect(warn.mock.calls[0][0]).not.toContain("u1");
  });

  test("an ephemeral ref past its grace period becomes a violation", async () => {
    const t = convexTest(schema);
    await seed(t);
    vi.spyOn(console, "warn").mockImplementation(() => {});
    vi.setSystemTime(Date.now() + EPHEMERAL_GRACE_MS + 60_000);
    await t.mutation(internal.integrity.start, { pageSize: 3 });
    await drain(t);
    const s = (await t.query(internal.integrity.latest, {}))!;
    expect(row(s.violations, "calls.roomId")).toMatchObject({ rule: "ephemeral", dangling: 1 });
    expect(s.graceTotal).toBe(0);
  });

  test("a clean database reports no violations and does not warn", async () => {
    const t = convexTest(schema);
    await t.run(async (ctx) => {
      const a = await ctx.db.insert("users", { username: "a", passwordHash: "x", createdAt: 1 });
      await ctx.db.insert("blocks", { userId: a, blockedUserId: a, createdAt: 1 });
    });
    const warn = vi.spyOn(console, "warn").mockImplementation(() => {});
    await t.mutation(internal.integrity.start, { pageSize: 5 });
    await drain(t);
    const s = (await t.query(internal.integrity.latest, {}))!;
    expect(s.status).toBe("done");
    expect(s.violations).toEqual([]);
    expect(warn).not.toHaveBeenCalled();
  });

  test("only one run at a time; a stalled run is resumed from its cursor", async () => {
    const t = convexTest(schema);
    await seed(t);
    const first = await t.mutation(internal.integrity.start, { pageSize: 2 });
    const second = await t.mutation(internal.integrity.start, { pageSize: 2 });
    expect(second).toMatchObject({ started: false, runId: first.runId, reason: "running" });
    expect(await t.run((ctx) => ctx.db.query("integrityRuns").collect())).toHaveLength(1);

    // Simulate a dead chain: no progress for longer than the stall window.
    await t.run((ctx) =>
      ctx.db.patch(first.runId as Id<"integrityRuns">, {
        lastProgressAt: Date.now() - STALL_MS - 1,
      }),
    );
    const resumed = await t.mutation(internal.integrity.start, { pageSize: 2 });
    expect(resumed).toMatchObject({ started: true, runId: first.runId, reason: "resumed" });
    vi.spyOn(console, "warn").mockImplementation(() => {});
    await drain(t);
    const s = (await t.query(internal.integrity.latest, {}))!;
    expect(s.status).toBe("done");
    expect(s.progress.restarts).toBe(1);

    // A finished run does not block the next one.
    const next = await t.mutation(internal.integrity.start, {});
    expect(next).toMatchObject({ started: true, reason: "new" });
    expect(next.runId).not.toBe(first.runId);
    await drain(t);
  });

  test("resumeStalled never starts a run, resumes a stalled one, and fails it after 3 resumes", async () => {
    const t = convexTest(schema);
    await seed(t);
    expect(await t.mutation(internal.integrity.resumeStalled, {})).toBeNull();
    expect(await t.run((ctx) => ctx.db.query("integrityRuns").collect())).toHaveLength(0);

    const { runId } = await t.mutation(internal.integrity.start, { pageSize: 2 });
    const id = runId as Id<"integrityRuns">;
    const stall = () =>
      t.run((ctx) => ctx.db.patch(id, { lastProgressAt: Date.now() - STALL_MS - 1 }));
    // Fresh progress: nothing to do.
    expect(await t.mutation(internal.integrity.resumeStalled, {})).toBeNull();
    const warn = vi.spyOn(console, "warn").mockImplementation(() => {});
    for (let i = 0; i < 3; i++) {
      await stall();
      expect(await t.mutation(internal.integrity.resumeStalled, {})).toBe("resumed");
    }
    await stall();
    expect(await t.mutation(internal.integrity.resumeStalled, {})).toBe("failed");
    const run = await t.run((ctx) => ctx.db.get(id));
    expect(run).toMatchObject({ status: "failed", restarts: 3 });
    expect(warn).toHaveBeenCalledTimes(1);
    expect(warn.mock.calls[0][0]).toMatch(/stuck on table \w+ at cursor/);
    // Failed runs are not resumed again, and a dead chain's step is a no-op.
    expect(await t.mutation(internal.integrity.resumeStalled, {})).toBeNull();
    await t.mutation(internal.integrity.step, { runId });
  });

  test("a page rewrites only its table's counter row", async () => {
    const t = convexTest(schema);
    await seed(t);
    const { runId } = await t.mutation(internal.integrity.start, { pageSize: 2 });
    const before = await t.run((ctx) => ctx.db.query("integrityCounts").collect());
    await t.mutation(internal.integrity.step, { runId });
    const after = await t.run((ctx) => ctx.db.query("integrityCounts").collect());
    const changed = after.filter(
      (a) => JSON.stringify(a.counts) !== JSON.stringify(before.find((b) => b._id === a._id)!.counts),
    );
    expect(changed.length).toBeLessThanOrEqual(1);
    vi.spyOn(console, "warn").mockImplementation(() => {});
  });

  test("valuesAt walks dotted, array and record paths", () => {
    const doc = { a: { b: "1" }, m: [{ u: "2" }, { u: "3" }, {}], r: { x: "4", y: "5" }, n: null };
    expect(valuesAt(doc, "a.b")).toEqual(["1"]);
    expect(valuesAt(doc, "m[].u")).toEqual(["2", "3"]);
    expect(valuesAt(doc, "r{}")).toEqual(["4", "5"]);
    expect(valuesAt(doc, "n")).toEqual([]);
    expect(valuesAt(doc, "missing.deep")).toEqual([]);
  });
});
