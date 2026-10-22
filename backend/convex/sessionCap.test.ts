import { convexTest } from "convex-test";
import { afterEach, beforeEach, describe, expect, test, vi } from "vitest";
import { api, internal } from "./_generated/api";
import {
  SESSION_GRACE_FLOOR,
  SESSION_LIVE_CAP,
  mintSession,
  requireSession,
  sessionFlags,
} from "./sessionCore";
import { FIRST_TX_SESSIONS, startUserDeletion } from "./deletionCore";
import { suspendAccount } from "./moderation";
import { drainDeletions } from "./deletionTestUtils";
import schema from "./schema";

const DAY = 24 * 60 * 60 * 1000;

beforeEach(() => {
  vi.useFakeTimers();
  vi.setSystemTime(SESSION_GRACE_FLOOR + 3 * DAY);
});
afterEach(() => {
  vi.useRealTimers();
  sessionFlags.trustsRow = false;
});

async function signUp(t: ReturnType<typeof convexTest>, username = "alice") {
  return await t.mutation(api.auth.signup, {
    username,
    name: username,
    passwordHash: `hash-${username}`,
    recoveryKeyHash: `recovery-${username}`,
    deviceId: `device-${username}`,
  });
}

async function mint(t: ReturnType<typeof convexTest>, userId: any, n: number) {
  const tokens: string[] = [];
  for (let i = 0; i < n; i++) {
    vi.setSystemTime(Date.now() + 1000);
    tokens.push(await t.run((ctx) => mintSession(ctx, userId, `dev-${i}`)));
  }
  return tokens;
}

async function outcome(
  t: ReturnType<typeof convexTest>,
  token: string,
  opts?: { allowSuspended?: boolean },
) {
  try {
    await t.run((ctx) => requireSession(ctx, token, opts));
    return "ok";
  } catch (e: any) {
    return String(e.message).match(/ACCOUNT_SUSPENDED|SESSION_REVOKED|SESSION_UNKNOWN/)![0];
  }
}

async function liveCount(t: ReturnType<typeof convexTest>, userId: any) {
  const rows = await t.run((ctx) => ctx.db.query("sessions").collect());
  return rows.filter((r) => r.userId === userId && r.revokedAt === undefined).length;
}

describe("session cap", () => {
  test("cap is within the deletion first transaction window", () => {
    expect(SESSION_LIVE_CAP).toBeLessThanOrEqual(FIRST_TX_SESSIONS);
  });

  test("repeated mints evict the oldest and never exceed the cap", async () => {
    const t = convexTest(schema);
    const a = await signUp(t);
    const tokens = [a.token as string, ...(await mint(t, a.userId, SESSION_LIVE_CAP + 9))];
    expect(await liveCount(t, a.userId)).toBe(SESSION_LIVE_CAP);
    // The first ten (signup + nine) are evicted, the newest are live.
    expect(await outcome(t, tokens[0])).toBe("SESSION_REVOKED");
    expect(await outcome(t, tokens[9])).toBe("SESSION_REVOKED");
    expect(await outcome(t, tokens[10])).toBe("ok");
    expect(await outcome(t, tokens[tokens.length - 1])).toBe("ok");
    const evicted = await t.run((ctx) =>
      ctx.db.query("sessions").collect().then((r) => r.filter((x) => x.revokedReason === "evicted")),
    );
    expect(evicted).toHaveLength(10);
  });
});

describe("revocation reasons", () => {
  test("deletion first transaction leaves 0 live even with 40 old revoked rows in range", async () => {
    const t = convexTest(schema);
    const a = await signUp(t);
    await t.run(async (ctx) => {
      for (let i = 0; i < 40; i++) {
        await ctx.db.insert("sessions", {
          userId: a.userId as any,
          tokenHash: `old-${i}`,
          deviceId: `old-${i}`,
          createdAt: 1,
          lastSeenAt: 1,
          revokedAt: 2,
        });
      }
    });
    const tokens = await mint(t, a.userId, 45);
    await t.run((ctx) => startUserDeletion(ctx, a.userId as any));
    expect(await liveCount(t, a.userId)).toBe(0);
    expect(await outcome(t, tokens[0])).toBe("SESSION_REVOKED");
    const reasons = await t.run((ctx) =>
      ctx.db.query("sessions").collect().then((r) => r.filter((x) => x.revokedAt !== 2)),
    );
    expect(reasons.every((r) => r.revokedReason === "deleted")).toBe(true);
  });

  test("suspension answers ACCOUNT_SUSPENDED; allowSuspended works by reason", async () => {
    const t = convexTest(schema);
    const a = await signUp(t);
    const b = await signUp(t, "bob");
    await t.run((ctx) => suspendAccount(ctx, a.userId, b.userId));
    expect(await outcome(t, a.token)).toBe("ACCOUNT_SUSPENDED");
    expect(await outcome(t, a.token, { allowSuspended: true })).toBe("ok");
    const row = await t.run((ctx) => ctx.db.query("sessions").first());
    expect(row?.revokedReason).toBe("suspended");
  });

  test("a token signed out before the ban stays dead for allowSuspended", async () => {
    const t = convexTest(schema);
    const a = await signUp(t);
    const b = await signUp(t, "bob");
    await t.run(async (ctx) => {
      const row = await ctx.db.query("sessions").first();
      await ctx.db.patch(row!._id, { revokedAt: Date.now() - 1000 });
    });
    vi.setSystemTime(Date.now() + 5000);
    await t.run((ctx) => suspendAccount(ctx, a.userId, b.userId));
    expect(await outcome(t, a.token, { allowSuspended: true })).toBe("ACCOUNT_SUSPENDED");
  });

  test("legacy reasonless rows behave as today", async () => {
    const t = convexTest(schema);
    const a = await signUp(t);
    const b = await signUp(t, "bob");
    // Plain sign-out: REVOKED.
    await t.run(async (ctx) => {
      const row = await ctx.db.query("sessions").first();
      await ctx.db.patch(row!._id, { revokedAt: Date.now() });
    });
    expect(await outcome(t, a.token)).toBe("SESSION_REVOKED");
    // Legacy ban-revoked row (no reason, revokedAt >= suspendedAt).
    vi.setSystemTime(Date.now() + 5000);
    await t.run(async (ctx) => {
      const now = Date.now();
      await ctx.db.patch(b.userId as any, { suspendedAt: now });
      const rows = await ctx.db.query("sessions").collect();
      const row = rows.find((r) => r.userId === b.userId)!;
      await ctx.db.patch(row._id, { revokedAt: now });
    });
    expect(await outcome(t, b.token)).toBe("ACCOUNT_SUSPENDED");
    expect(await outcome(t, b.token, { allowSuspended: true })).toBe("ok");
  });
});

describe("SESSION_TRUSTS_ROW", () => {
  test("no users read on the live path, yet banned and deleted accounts are refused", async () => {
    const t = convexTest(schema);
    const a = await signUp(t);
    const b = await signUp(t, "bob");
    const c = await signUp(t, "carol");
    sessionFlags.trustsRow = true;
    // Prove no users read: make the user row vanish; trusting mode still passes.
    await t.run(async (ctx) => {
      const get = ctx.db.get.bind(ctx.db);
      let usersReads = 0;
      (ctx.db as any).get = async (id: any) => {
        usersReads++;
        return get(id);
      };
      await requireSession(ctx, a.token);
      expect(usersReads).toBe(0);
    });
    await t.run((ctx) => suspendAccount(ctx, b.userId, a.userId));
    expect(await outcome(t, b.token)).toBe("ACCOUNT_SUSPENDED");
    await t.run((ctx) => startUserDeletion(ctx, c.userId as any));
    expect(await outcome(t, c.token)).toBe("SESSION_REVOKED");
    expect(await outcome(t, a.token)).toBe("ok");
  });
});

describe("auditLiveVsAccounts", () => {
  test("counts missing, tombstoned and suspended; clean table is 0", async () => {
    const t = convexTest(schema);
    const a = await signUp(t);
    const b = await signUp(t, "bob");
    const c = await signUp(t, "carol");
    const d = await signUp(t, "dave");
    const run = () => t.query(internal.sessions.auditLiveVsAccounts, {});
    expect(await run()).toMatchObject({ scanned: 4, missing: 0, tombstoned: 0, suspended: 0, isDone: true });
    await t.run(async (ctx) => {
      // Simulate pre-reason states: flags set without revoking sessions.
      await ctx.db.patch(b.userId as any, { suspendedAt: 1 });
      await ctx.db.patch(c.userId as any, { deletingAt: 1 });
      await ctx.db.delete(d.userId as any);
    });
    expect(await run()).toMatchObject({ scanned: 4, missing: 1, tombstoned: 1, suspended: 1 });
    // Paging.
    const p1 = await t.query(internal.sessions.auditLiveVsAccounts, { numItems: 2 });
    expect(p1.isDone).toBe(false);
    const p2 = await t.query(internal.sessions.auditLiveVsAccounts, { numItems: 2, cursor: p1.nextCursor });
    expect(p1.scanned + p2.scanned).toBe(4);
    expect(p1.missing + p2.missing).toBe(1);
    void a;
  });
});

/** Insert [n] live legacy sessions (no reason), oldest first. */
async function seedLive(t: ReturnType<typeof convexTest>, userId: any, n: number) {
  await t.run(async (ctx) => {
    for (let i = 0; i < n; i++) {
      await ctx.db.insert("sessions", {
        userId,
        tokenHash: `seed-${userId}-${i}`,
        deviceId: `seed-${i}`,
        createdAt: 10 + i,
        lastSeenAt: 10 + i,
      });
    }
  });
}

describe("review fixes", () => {
  test("one mint trims an account over the cap down to the cap", async () => {
    const t = convexTest(schema);
    const a = await signUp(t);
    await seedLive(t, a.userId, 149);
    expect(await liveCount(t, a.userId)).toBe(150);
    await t.run((ctx) => mintSession(ctx, a.userId as any, "fresh"));
    expect(await liveCount(t, a.userId)).toBe(SESSION_LIVE_CAP);
    // Oldest by lastSeenAt went first: the seeded rows (tiny lastSeenAt), not the new one.
    const rows = await t.run((ctx) => ctx.db.query("sessions").collect());
    const live = rows.filter((r) => r.revokedAt === undefined);
    expect(live.some((r) => r.deviceId === "fresh")).toBe(true);
  });

  test("suspending an account with 150 live sessions revokes all of them", async () => {
    const t = convexTest(schema);
    const a = await signUp(t);
    const b = await signUp(t, "bob");
    await seedLive(t, a.userId, 149);
    await t.run((ctx) => suspendAccount(ctx, a.userId, b.userId));
    // First page only (the continuation is scheduled).
    expect(await liveCount(t, a.userId)).toBeGreaterThan(0);
    await drainDeletions(t, vi.runAllTimers);
    expect(await liveCount(t, a.userId)).toBe(0);
    const rows = await t.run((ctx) => ctx.db.query("sessions").collect());
    expect(
      rows.filter((r) => r.userId === a.userId).every((r) => r.revokedReason === "suspended"),
    ).toBe(true);
  });

  test("deleting an account with 150 live sessions ends with none live, all 'deleted'", async () => {
    const t = convexTest(schema);
    const a = await signUp(t);
    await seedLive(t, a.userId, 149);
    await t.run((ctx) => startUserDeletion(ctx, a.userId as any));
    await drainDeletions(t, vi.runAllTimers);
    expect(await liveCount(t, a.userId)).toBe(0);
    const rows = await t.run((ctx) => ctx.db.query("sessions").collect());
    expect(
      rows.filter((r) => r.userId === a.userId).every((r) => r.revokedReason === "deleted"),
    ).toBe(true);
  });

  test("audit counts overCap once per user across pages; trimOverCap brings it to 0", async () => {
    const t = convexTest(schema);
    const a = await signUp(t);
    const b = await signUp(t, "bob");
    await seedLive(t, a.userId, 80); // 81 live
    await seedLive(t, b.userId, 10); // 11 live
    const sum = async (numItems: number) => {
      let cursor: string | null = null;
      let over = 0;
      for (;;) {
        const r: any = await t.query(internal.sessions.auditLiveVsAccounts, { numItems, cursor });
        over += r.overCap;
        if (r.isDone) return over;
        cursor = r.nextCursor;
      }
    };
    expect(await sum(7)).toBe(1);
    expect(await sum(1000)).toBe(1);
    let cursor: string | null = null;
    for (;;) {
      const r: any = await t.mutation(internal.sessions.trimOverCap, { numItems: 7, cursor });
      if (r.isDone) break;
      cursor = r.nextCursor;
    }
    expect(await liveCount(t, a.userId)).toBe(SESSION_LIVE_CAP);
    expect(await liveCount(t, b.userId)).toBe(11);
    expect(await sum(7)).toBe(0);
  });

  test("a session from an earlier ban does not pass allowSuspended after a second ban", async () => {
    const t = convexTest(schema);
    const a = await signUp(t);
    const b = await signUp(t, "bob");
    await t.run((ctx) => suspendAccount(ctx, a.userId, b.userId));
    expect(await outcome(t, a.token, { allowSuspended: true })).toBe("ok");
    vi.setSystemTime(Date.now() + 5000);
    await t.run(async (ctx) => {
      await ctx.db.patch(a.userId as any, { suspendedAt: undefined, suspendedBy: undefined });
    });
    vi.setSystemTime(Date.now() + 5000);
    await t.run((ctx) => suspendAccount(ctx, a.userId, b.userId));
    expect(await outcome(t, a.token, { allowSuspended: true })).toBe("ACCOUNT_SUSPENDED");
  });
});
