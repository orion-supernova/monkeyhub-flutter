import { convexTest } from "convex-test";
import { afterEach, beforeEach, describe, expect, test, vi } from "vitest";
import { internal } from "./_generated/api";
import type { Id } from "./_generated/dataModel";
import {
  Budget,
  deleteCapped,
  enqueueDeletion,
  getLiveRoom,
  getLiveUser,
  isTombstoned,
  startRoomDeletion,
  startUserDeletion,
  testHooks,
  tuning,
} from "./deletionCore";
import { drainDeletions, shrinkTuning } from "./deletionTestUtils";
import { genericStep } from "./deletionPlans";
import { MAX_RESTARTS, STALL_MS } from "./deletions";
import schema from "./schema";

/**
 * The delete engine against the real tables. The multi-page test uses the
 * `room` kind with rows only in tables whose rules are all generic
 * (roomAccess, roomBans: cascade; friendships.roomId: setNull), so the plan has
 * no custom steps yet. Budgets are shrunk to 4 writes / 2 rows a page.
 */

type T = ReturnType<typeof convexTest>;

let restoreTuning: () => void;
beforeEach(() => {
  vi.useFakeTimers();
  vi.spyOn(console, "warn").mockImplementation(() => {});
  vi.spyOn(console, "error").mockImplementation(() => {});
  restoreTuning = shrinkTuning();
});
afterEach(() => {
  restoreTuning();
  testHooks.beforeStep = undefined;
  vi.restoreAllMocks();
  vi.useRealTimers();
});

const drain = (t: T) => drainDeletions(t, vi.runAllTimers);

const mkUser = (t: T, username: string, extra: Record<string, any> = {}) =>
  t.run((ctx) =>
    ctx.db.insert("users", { username, passwordHash: "x", createdAt: 1, ...extra }),
  );
const mkRoom = (t: T, extra: Record<string, any> = {}) =>
  t.run(async (ctx) => {
    const owner = await ctx.db.insert("users", { username: `o${Math.random()}`, passwordHash: "x", createdAt: 1 });
    return await ctx.db.insert("rooms", {
      name: "crew",
      createdBy: owner,
      createdAt: 1,
      isPrivate: false,
      memberCount: 1,
      ...extra,
    });
  });
const get = (t: T, id: any) => t.run((ctx) => ctx.db.get(id));
const job = (t: T, id: Id<"deletions">) => t.run((ctx) => ctx.db.get(id));

/** A room with `n` roomAccess rows, bans and DM friendships, plus a control room. */
async function seedRoom(t: T, n: number) {
  const roomId = await mkRoom(t, { passwordHash: "pw" });
  const otherRoom = await mkRoom(t);
  const who = await mkUser(t, "member");
  await t.run(async (ctx) => {
    for (let i = 0; i < n; i++) {
      const u = await ctx.db.insert("users", { username: `m${i}`, passwordHash: "x", createdAt: 1 });
      await ctx.db.insert("roomAccess", { roomId, userId: u });
      await ctx.db.insert("roomBans", { roomId, userId: u, until: 99 });
      await ctx.db.insert("friendships", {
        userId: who, friendId: u, status: "accepted", createdAt: 1, roomId,
      });
    }
    await ctx.db.insert("roomAccess", { roomId: otherRoom, userId: who });
    await ctx.db.insert("friendships", {
      userId: who, friendId: who, status: "accepted", createdAt: 1, roomId: otherRoom,
    });
  });
  return { roomId, otherRoom };
}

const count = (t: T, table: any) => t.run(async (ctx) => (await ctx.db.query(table).collect()).length);

describe("room teardown (generic steps)", () => {
  test("hides the room at once, then sweeps cascade/setNull in pages and deletes the parent last", async () => {
    const t = convexTest(schema);
    const { roomId, otherRoom } = await seedRoom(t, 7);

    const jobId = (await t.run((ctx) => startRoomDeletion(ctx, roomId, { reason: "owner" })))!;
    // The first transaction only: tombstone, rename, private, no password.
    const hidden: any = await get(t, roomId);
    expect(hidden.deletingAt).toBeTypeOf("number");
    expect(hidden.name).toBe(`deleted:${roomId}`);
    expect(hidden.isPrivate).toBe(true);
    expect(hidden.passwordHash).toBeUndefined();
    expect(await count(t, "roomAccess")).toBe(8);

    // Parent last: the room row exists at every step but the final one.
    const seen: [string, boolean][] = [];
    testHooks.beforeStep = async (ctx, j, s) => {
      seen.push([s.id, (await ctx.db.get(roomId as any)) !== null]);
    };
    await drain(t);

    const done: any = await job(t, jobId);
    expect(done.state).toBe("done");
    expect(done.reason).toBe("owner");
    expect(done.pages).toBeGreaterThan(3); // several transactions, not one
    expect(done.writes).toBeGreaterThanOrEqual(21);
    expect(await get(t, roomId)).toBeNull();
    expect(seen.length).toBeGreaterThan(3);
    expect(seen[seen.length - 1][0]).toBe("parent");
    expect(seen.every(([, exists]) => exists)).toBe(true);

    // cascade rows are gone, setNull rows kept without the pointer, control untouched.
    const access: any[] = await t.run((ctx) => ctx.db.query("roomAccess").collect());
    expect(access.map((r) => r.roomId)).toEqual([otherRoom]);
    expect(await count(t, "roomBans")).toBe(0);
    const fr: any[] = await t.run((ctx) => ctx.db.query("friendships").collect());
    expect(fr).toHaveLength(8);
    expect(fr.filter((f) => f.roomId === roomId)).toHaveLength(0);
    expect(fr.filter((f) => f.roomId === undefined)).toHaveLength(7);
    expect(fr.filter((f) => f.roomId === otherRoom)).toHaveLength(1);
  });

  test("a step run twice is a no-op the second time", async () => {
    const t = convexTest(schema);
    const { roomId } = await seedRoom(t, 5);
    const writes = await t.run(async (ctx) => {
      const step = genericStep("roomAccess.roomId");
      const j: any = { kind: "room", targetId: roomId };
      const first = new Budget(1000, 1000);
      expect(await step.run(ctx, j, first)).toEqual({ done: true });
      const second = new Budget(1000, 1000);
      expect(await step.run(ctx, j, second)).toEqual({ done: true });
      return [first.writes, second.writes];
    });
    expect(writes).toEqual([5, 0]);
  });

  test("an empty targetId never runs a step (eq(undefined) would match unset rows)", async () => {
    const t = convexTest(schema);
    const { otherRoom } = await seedRoom(t, 2);
    await t.run(async (ctx) => {
      // friendships.roomId is unset on no row here; add one to be sure it survives.
      const who = await ctx.db.insert("users", { username: "w", passwordHash: "x", createdAt: 1 });
      await ctx.db.insert("friendships", { userId: who, friendId: who, status: "accepted", createdAt: 1 });
      const b = new Budget(1000, 1000);
      const j: any = { kind: "room", targetId: "" };
      expect(await genericStep("friendships.roomId").run(ctx, j, b)).toEqual({ done: true });
      expect(b.writes).toBe(0);
    });
    expect(await count(t, "friendships")).toBe(4);
    expect(otherRoom).toBeTruthy();
  });
});

describe("job lifecycle", () => {
  test("double enqueue makes one job; a finished one does not block a new one", async () => {
    const t = convexTest(schema);
    const roomId = await mkRoom(t);
    const a = await t.run((ctx) => startRoomDeletion(ctx, roomId));
    const b = await t.run((ctx) => startRoomDeletion(ctx, roomId));
    expect(b).toBe(a);
    const c = await t.run((ctx) => enqueueDeletion(ctx, { kind: "avatar", targetId: "u1" }));
    const d = await t.run((ctx) => enqueueDeletion(ctx, { kind: "avatar", targetId: "u1" }));
    expect(d).toBe(c);
    expect(await count(t, "deletions")).toBe(2);
    await drain(t);
    expect(((await job(t, c)) as any).state).toBe("done"); // avatar: empty plan
    const e = await t.run((ctx) => enqueueDeletion(ctx, { kind: "avatar", targetId: "u1" }));
    expect(e).not.toBe(c);
  });

  test("a stale generation exits without touching the job", async () => {
    const t = convexTest(schema);
    const roomId = await mkRoom(t);
    const jobId = (await t.run((ctx) => startRoomDeletion(ctx, roomId)))!;
    await t.run((ctx) => ctx.db.patch(jobId, { restarts: 2 }));
    await t.mutation(internal.deletions.step, { jobId, gen: 1 });
    await t.mutation(internal.deletions.stepInner, { jobId, gen: 1 });
    const j: any = await job(t, jobId);
    expect(j.pages).toBe(0);
    expect(j.stepId).toBe("");
    expect(await get(t, roomId)).not.toBeNull();
    // The current generation does run.
    await t.mutation(internal.deletions.stepInner, { jobId, gen: 2 });
    expect(((await job(t, jobId)) as any).pages).toBe(1);
  });

  test("re-running a finished job is a no-op", async () => {
    const t = convexTest(schema);
    const { roomId } = await seedRoom(t, 3);
    const jobId = (await t.run((ctx) => startRoomDeletion(ctx, roomId)))!;
    await drain(t);
    const before: any = await job(t, jobId);
    expect(before.state).toBe("done");
    await t.mutation(internal.deletions.step, { jobId, gen: 0 });
    await t.mutation(internal.deletions.stepInner, { jobId, gen: 0 });
    expect(await job(t, jobId)).toEqual(before);
  });

  test("an unknown step id (the plan changed in a deploy) restarts from the top", async () => {
    const t = convexTest(schema);
    const { roomId } = await seedRoom(t, 3);
    const jobId = (await t.run((ctx) => startRoomDeletion(ctx, roomId)))!;
    await t.run((ctx) => ctx.db.patch(jobId, { stepId: "removed-in-deploy", cursor: "stale" }));
    await drain(t);
    expect(((await job(t, jobId)) as any).state).toBe("done");
    expect(await get(t, roomId)).toBeNull();
    expect(await count(t, "roomAccess")).toBe(1);
  });
});

describe("failure, re-drive, give-up", () => {
  const failAt = (stepId: string) => {
    testHooks.beforeStep = (_ctx, _j, s) => {
      if (s.id === stepId) throw new Error(`boom at ${s.id}`);
    };
  };
  const later = (ms: number) => vi.advanceTimersByTime(ms);

  test("a throwing step rolls back, backs off, then the cron re-drives it to completion", async () => {
    const t = convexTest(schema);
    // Roomy budgets: the whole plan runs in ONE transaction, which throws at
    // the last step, so everything the earlier steps did must roll back.
    shrinkTuning({ maxWrites: 1500, maxReads: 6000, pageRows: 100 });
    const { roomId } = await seedRoom(t, 5);
    const jobId = (await t.run((ctx) => startRoomDeletion(ctx, roomId)))!;
    failAt("parent");
    await drain(t);

    let j: any = await job(t, jobId);
    expect(j.state).toBe("running");
    expect(j.attempts).toBe(5); // backoff stopped rescheduling
    expect(j.lastError).toContain("boom at parent");
    expect(await get(t, roomId)).not.toBeNull();
    // The sub-transaction rolled back: the steps before the throw left nothing.
    expect(j.pages).toBe(0);
    expect(await count(t, "roomAccess")).toBe(6);
    expect(await count(t, "roomBans")).toBe(5);

    // Not stalled yet: redrive leaves it alone.
    await t.mutation(internal.deletions.redrive, {});
    expect(((await job(t, jobId)) as any).restarts).toBe(0);

    testHooks.beforeStep = undefined;
    later(STALL_MS + 1000);
    await t.mutation(internal.deletions.redrive, {});
    j = await job(t, jobId);
    expect(j.restarts).toBe(1);
    expect(j.attempts).toBe(0);
    await drain(t);
    j = await job(t, jobId);
    expect(j.state).toBe("done");
    expect(j.attempts).toBe(0);
    expect(j.lastError).toBeUndefined();
    expect(await get(t, roomId)).toBeNull();
  });

  test("after 6 re-drives it is marked failed and staff are told, ids only; retry revives it", async () => {
    const t = convexTest(schema);
    const staff = await mkUser(t, "muratcankoc");
    const { roomId } = await seedRoom(t, 3);
    const jobId = (await t.run((ctx) => startRoomDeletion(ctx, roomId)))!;
    failAt("access"); // WP-C: roomAccess.roomId is a custom step now
    await drain(t);
    for (let i = 0; i < MAX_RESTARTS; i++) {
      later(STALL_MS + 1000);
      await t.mutation(internal.deletions.redrive, {});
      await drain(t);
      const j: any = await job(t, jobId);
      expect(j.state).toBe("running");
      expect(j.restarts).toBe(i + 1);
    }
    later(STALL_MS + 1000);
    await t.mutation(internal.deletions.redrive, {});
    await drain(t);

    const failed: any = await job(t, jobId);
    expect(failed.state).toBe("failed");
    expect(failed.finishedAt).toBeTypeOf("number");
    expect(await get(t, roomId)).not.toBeNull(); // nothing half-deleted

    // The notice: posted in the moderation inbox, naming the job and the room by id.
    const notice: any = await t.run(async (ctx) =>
      (await ctx.db.query("messages").collect()).find((m: any) => m.content.startsWith("Deletion job gave up")),
    );
    expect(notice).toBeDefined();
    expect(notice.content).toContain(`Target: ${roomId}`);
    expect(notice.content).toContain(`Job: ${jobId}`);
    expect(notice.content).not.toContain("—");
    expect(staff).toBeTruthy();

    const summary: any = await t.query(internal.deletions.summary, {});
    expect(summary.counts.failed).toBe("1");
    expect(summary.failed[0].jobId).toBe(jobId);

    testHooks.beforeStep = undefined;
    await t.mutation(internal.deletions.retry, { jobId });
    await drain(t);
    expect(((await job(t, jobId)) as any).state).toBe("done");
    expect(await get(t, roomId)).toBeNull();
  });

  test("prune drops done rows older than 30 days and nothing else", async () => {
    const t = convexTest(schema);
    const base = { kind: "avatar" as const, targetId: "x", cursor: null, stepId: "", createdAt: 1, lastProgressAt: 1, restarts: 0, attempts: 0, pages: 0, writes: 0 };
    const now = Date.now();
    await t.run(async (ctx) => {
      await ctx.db.insert("deletions", { ...base, state: "done", finishedAt: now - 31 * 86400_000 });
      await ctx.db.insert("deletions", { ...base, state: "done", finishedAt: now - 1000 });
      await ctx.db.insert("deletions", { ...base, state: "running" });
      await ctx.db.insert("deletions", { ...base, state: "failed", finishedAt: now - 99 * 86400_000 });
    });
    await t.mutation(internal.deletions.prune, {});
    expect(await count(t, "deletions")).toBe(3);
  });
});

describe("user tombstone", () => {
  test("scrubs the row, revokes sessions, drops identities, keeps a ban, then deletes the user last", async () => {
    const t = convexTest(schema);
    const userId = await mkUser(t, "alice", {
      name: "Alice", email: "a@x.com", recoveryKeyHash: "r", lastSeen: 5, status: "online",
      suspendedAt: 7,
    });
    await t.run(async (ctx) => {
      for (let i = 0; i < 3; i++) {
        await ctx.db.insert("sessions", { userId, tokenHash: `h${i}`, deviceId: `d${i}`, createdAt: 1, lastSeenAt: 1 });
      }
      await ctx.db.insert("socialIdentities", { provider: "apple", subject: "s1", userId, createdAt: 1, lastUsedAt: 1, appleRefreshToken: "rt" });
      await ctx.db.insert("socialIdentities", { provider: "google", subject: "s2", userId, createdAt: 1, lastUsedAt: 1 });
      await ctx.db.insert("blocks", { userId, blockedUserId: userId, createdAt: 1 });
    });

    const jobId = (await t.run((ctx) => startUserDeletion(ctx, userId, { reason: "self" })))!;
    const row: any = await get(t, userId);
    expect(row.deletingAt).toBeTypeOf("number");
    expect(row.username).toBe(`deleted:${userId}`);
    expect(row.passwordHash).toBe("");
    expect(row.status).toBe("offline");
    for (const f of ["name", "email", "recoveryKeyHash", "lastSeen"]) expect(row[f]).toBeUndefined();
    expect(row.suspendedAt).toBe(7); // the ban survives the scrub
    const sessions: any[] = await t.run((ctx) => ctx.db.query("sessions").collect());
    expect(sessions.every((s) => s.revokedAt !== undefined)).toBe(true);
    expect(await count(t, "socialIdentities")).toBe(0);
    expect(await count(t, "bannedIdentities")).toBe(3); // suspended: 2 identities + the email, remembered
    const j: any = await job(t, jobId);
    expect(j).toMatchObject({ kind: "user", targetId: userId, reason: "self", args: { suspended: true } });

    // Double tap: same job, no second scrub.
    expect(await t.run((ctx) => startUserDeletion(ctx, userId))).toBe(jobId);
    expect(await count(t, "bannedIdentities")).toBe(3);

    await drain(t);
    expect(((await job(t, jobId)) as any).state).toBe("done");
    expect(await get(t, userId)).toBeNull();
    expect(await count(t, "blocks")).toBe(0); // generic cascade by blocks.userId
  });

  test("a staff handle is retired, an unsuspended account leaves no ban, a missing user is null", async () => {
    const t = convexTest(schema);
    const staff = await mkUser(t, "muratcankoc");
    await t.run(async (ctx) => {
      await ctx.db.insert("socialIdentities", { provider: "google", subject: "s", userId: staff, createdAt: 1, lastUsedAt: 1 });
    });
    await t.run((ctx) => startUserDeletion(ctx, staff));
    const retired: any[] = await t.run((ctx) => ctx.db.query("retiredHandles").collect());
    expect(retired.map((r) => r.username)).toEqual(["muratcankoc"]);
    expect(await count(t, "bannedIdentities")).toBe(0);

    await drain(t);
    expect(await t.run((ctx) => startUserDeletion(ctx, staff))).toBeNull();
  });
});

describe("tombstone helpers", () => {
  test("getLive* hide a tombstoned row while get still resolves it", async () => {
    const t = convexTest(schema);
    const roomId = await mkRoom(t);
    const userId = await mkUser(t, "bob");
    await t.run(async (ctx) => {
      expect(isTombstoned(await ctx.db.get(roomId))).toBe(false);
      expect(await getLiveRoom(ctx, roomId)).not.toBeNull();
      expect(await getLiveUser(ctx, userId)).not.toBeNull();
    });
    await t.run(async (ctx) => {
      await startRoomDeletion(ctx, roomId);
      await startUserDeletion(ctx, userId);
    });
    await t.run(async (ctx) => {
      expect(isTombstoned(await ctx.db.get(roomId))).toBe(true);
      expect(isTombstoned(await ctx.db.get(userId))).toBe(true);
      expect(await getLiveRoom(ctx, roomId)).toBeNull();
      expect(await getLiveUser(ctx, userId)).toBeNull();
    });
    expect(isTombstoned(null)).toBe(false);
  });

  test("deleteCapped deletes at most the cap and reports overflow", async () => {
    const t = convexTest(schema);
    const roomId = await mkRoom(t);
    const res = await t.run(async (ctx) => {
      for (let i = 0; i < 5; i++) {
        const u = await ctx.db.insert("users", { username: `c${i}`, passwordHash: "x", createdAt: 1 });
        await ctx.db.insert("roomBans", { roomId, userId: u, until: 1 });
      }
      const q = () => ctx.db.query("roomBans").withIndex("by_room_user", (x) => x.eq("roomId", roomId));
      const a = await deleteCapped(ctx, q(), 2);
      const b = await deleteCapped(ctx, q(), 3);
      return [a, b];
    });
    expect(res[0]).toEqual({ deleted: 2, overflow: true });
    expect(res[1]).toEqual({ deleted: 3, overflow: false });
    expect(tuning.inlineCap).toBe(2);
  });
});
