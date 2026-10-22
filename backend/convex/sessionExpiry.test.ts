import { convexTest } from "convex-test";
import { afterEach, beforeEach, describe, expect, test, vi } from "vitest";
import { api, internal } from "./_generated/api";
import {
  SESSION_GRACE_FLOOR,
  SESSION_IDLE_MS,
  SESSION_TOUCH_MS,
} from "./sessionCore";
import schema from "./schema";

/**
 * Sessions expire after 90 days without use, and use refreshes them.
 *
 * Time is fully faked and starts a few days after the grace floor, the state a
 * deployment is in right after this ships.
 */

const DAY = 24 * 60 * 60 * 1000;

beforeEach(() => {
  vi.useFakeTimers();
  vi.setSystemTime(SESSION_GRACE_FLOOR + 3 * DAY);
});
afterEach(() => {
  vi.useRealTimers();
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

async function beat(t: ReturnType<typeof convexTest>, who: any) {
  await t.mutation(api.users.heartbeat, {
    sessionToken: who.token,
    userId: who.userId as any,
  });
}

async function lastSeen(t: ReturnType<typeof convexTest>) {
  const rows = await t.run((ctx) => ctx.db.query("sessions").collect());
  return rows.map((r) => r.lastSeenAt);
}

/** Whether the token still authenticates. */
async function alive(t: ReturnType<typeof convexTest>, who: any) {
  try {
    await beat(t, who);
    return true;
  } catch (e: any) {
    expect(String(e.message)).toContain("SESSION_REVOKED");
    return false;
  }
}

describe("idle expiry", () => {
  test("a session idle for 90 days is refused as revoked", async () => {
    const t = convexTest(schema);
    const a = await signUp(t);
    expect(await alive(t, a)).toBe(true);
    vi.setSystemTime(Date.now() + SESSION_IDLE_MS - DAY);
    // Not touched yet: the heartbeat above is 89 days old but within bounds.
    expect(await lastSeen(t)).toHaveLength(1);
    vi.setSystemTime(Date.now() + 2 * DAY);
    expect(await alive(t, a)).toBe(false);
  });

  test("use refreshes it: it outlives 90 days from sign-in", async () => {
    const t = convexTest(schema);
    const a = await signUp(t);
    vi.setSystemTime(Date.now() + 60 * DAY);
    expect(await alive(t, a)).toBe(true); // refreshes lastSeenAt
    vi.setSystemTime(Date.now() + 60 * DAY); // 120 days since sign-in
    expect(await alive(t, a)).toBe(true);
  });

  test("the heartbeat writes at most once a day", async () => {
    const t = convexTest(schema);
    const a = await signUp(t);
    const signedIn = (await lastSeen(t))[0];
    vi.setSystemTime(Date.now() + SESSION_TOUCH_MS - 60_000);
    await beat(t, a);
    expect(await lastSeen(t)).toEqual([signedIn]);
    vi.setSystemTime(Date.now() + 2 * 60_000);
    await beat(t, a);
    const touched = (await lastSeen(t))[0];
    expect(touched).toBeGreaterThan(signedIn);
    vi.setSystemTime(Date.now() + 3_600_000);
    await beat(t, a);
    expect(await lastSeen(t)).toEqual([touched]);
  });

  test("a session minted before expiry existed gets the grace", async () => {
    const t = convexTest(schema);
    const a = await signUp(t);
    // Signed in 200 days before the floor and never updated, as old rows are.
    await t.run(async (ctx) => {
      const [row] = await ctx.db.query("sessions").collect();
      await ctx.db.patch(row._id, { lastSeenAt: SESSION_GRACE_FLOOR - 200 * DAY });
    });
    expect(await alive(t, a)).toBe(true);
    // The cron does not revoke it inside the grace window either.
    await t.mutation(internal.sessionCore.expireIdleSessions, {});
    const [row] = await t.run((ctx) => ctx.db.query("sessions").collect());
    expect(row.revokedAt).toBeUndefined();
  });

  test("an old session nobody uses is refused once the grace has run out", async () => {
    const t = convexTest(schema);
    const a = await signUp(t);
    await t.run(async (ctx) => {
      const [row] = await ctx.db.query("sessions").collect();
      await ctx.db.patch(row._id, { lastSeenAt: SESSION_GRACE_FLOOR - 200 * DAY });
    });
    vi.setSystemTime(SESSION_GRACE_FLOOR + SESSION_IDLE_MS + DAY);
    expect(await alive(t, a)).toBe(false);
  });
});

describe("expireIdleSessions", () => {
  test("revokes idle sessions in pages, keeps live ones, then they are swept", async () => {
    const t = convexTest(schema);
    const a = await signUp(t);
    vi.setSystemTime(SESSION_GRACE_FLOOR + 200 * DAY);
    const now = Date.now();
    await t.run(async (ctx) => {
      for (let i = 0; i < 450; i++) {
        await ctx.db.insert("sessions", {
          userId: a.userId as any, tokenHash: `idle${i}`, deviceId: `d${i}`,
          createdAt: now - 150 * DAY, lastSeenAt: now - 120 * DAY,
        });
      }
    });
    await t.mutation(internal.sessionCore.expireIdleSessions, {});
    await t.finishAllScheduledFunctions(vi.runAllTimers);
    const rows = await t.run((ctx) => ctx.db.query("sessions").collect());
    const live = rows.filter((r) => r.revokedAt === undefined);
    // alice's own session was minted at the start of the test: 197 days idle.
    expect(live.length).toBe(0);
    expect(rows.length).toBe(451);
    // A week on, the revoked rows are deleted too.
    vi.setSystemTime(now + 8 * DAY);
    await t.mutation(internal.sessionCore.gcRevokedSessions, {});
    await t.finishAllScheduledFunctions(vi.runAllTimers);
    expect(await t.run((ctx) => ctx.db.query("sessions").collect())).toHaveLength(0);
  });
});
