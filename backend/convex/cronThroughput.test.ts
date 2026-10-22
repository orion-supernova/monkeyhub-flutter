import { convexTest } from "convex-test";
import { afterEach, beforeEach, describe, expect, test, vi } from "vitest";
import { api, internal } from "./_generated/api";
import schema from "./schema";

/**
 * Cleanups that keep up.
 *
 * Each sweep used to delete a fixed page per cron firing, so a backlog bigger
 * than the page only grew. Every test here builds a backlog of more than two
 * pages, fires the sweep ONCE (as the cron would) and lets the scheduler run:
 * the backlog must be gone, while rows the sweep must keep are still there.
 */

beforeEach(() => {
  vi.useFakeTimers();
});
afterEach(() => {
  vi.useRealTimers();
});

async function drain(t: ReturnType<typeof convexTest>) {
  await t.finishAllScheduledFunctions(vi.runAllTimers);
}

const DAY = 24 * 60 * 60 * 1000;

async function signUp(t: ReturnType<typeof convexTest>, username: string) {
  return await t.mutation(api.auth.signup, {
    username,
    name: username,
    passwordHash: `hash-${username}`,
    recoveryKeyHash: `recovery-${username}`,
    deviceId: `device-${username}`,
  });
}

async function roomFor(t: ReturnType<typeof convexTest>, who: any, name: string) {
  return await t.mutation(api.rooms.create, {
    sessionToken: who.token,
    userId: who.userId as any,
    name,
    isPrivate: false,
  });
}

describe("rate limit sweeps", () => {
  test("gcRateBuckets drains a backlog of more than one page", async () => {
    const t = convexTest(schema);
    await t.run(async (ctx) => {
      for (let i = 0; i < 1100; i++) {
        await ctx.db.insert("rateBuckets", { key: `k${i}`, windowStart: 1, count: 1 });
      }
      await ctx.db.insert("rateBuckets", { key: "fresh", windowStart: Date.now(), count: 1 });
    });
    await t.mutation(internal.rateLimit.gcRateBuckets, {});
    await drain(t);
    const left = await t.run((ctx) => ctx.db.query("rateBuckets").collect());
    expect(left.map((r) => r.key)).toEqual(["fresh"]);
  });

  test("gcAuthAttempts drains a backlog of more than one page", async () => {
    const t = convexTest(schema);
    await t.run(async (ctx) => {
      for (let i = 0; i < 450; i++) {
        await ctx.db.insert("authAttempts", {
          key: `login:${i}`, failures: 1, windowStartedAt: 1, updatedAt: 1,
        });
      }
      await ctx.db.insert("authAttempts", {
        key: "fresh", failures: 1, windowStartedAt: Date.now(), updatedAt: Date.now(),
      });
    });
    await t.mutation(internal.rateLimit.gcAuthAttempts, {});
    await drain(t);
    const left = await t.run((ctx) => ctx.db.query("authAttempts").collect());
    expect(left.map((r) => r.key)).toEqual(["fresh"]);
  });

  test("a chained run stops at the cap instead of looping forever", async () => {
    const t = convexTest(schema);
    await t.run(async (ctx) => {
      for (let i = 0; i < 300; i++) {
        await ctx.db.insert("authAttempts", {
          key: `login:${i}`, failures: 1, windowStartedAt: 1, updatedAt: 1,
        });
      }
    });
    // Already at the last permitted link: one page is taken, nothing follows.
    await t.mutation(internal.rateLimit.gcAuthAttempts, { chain: 49 });
    await drain(t);
    const left = await t.run((ctx) => ctx.db.query("authAttempts").collect());
    expect(left.length).toBe(100);
  });
});

describe("report retention sweeps", () => {
  test("users.gcExpiredReports and problemReports.gcExpiredReports drain", async () => {
    const t = convexTest(schema);
    const old = Date.now() - 800 * DAY;
    await t.run(async (ctx) => {
      for (let i = 0; i < 450; i++) {
        await ctx.db.insert("reports", {
          targetType: "user", targetId: `x${i}`, reason: "spam", createdAt: old,
        });
        await ctx.db.insert("problemReports", { deviceId: `d${i}`, createdAt: old });
      }
      await ctx.db.insert("reports", {
        targetType: "user", targetId: "fresh", reason: "spam", createdAt: Date.now(),
      });
      await ctx.db.insert("problemReports", { deviceId: "fresh", createdAt: Date.now() });
    });
    await t.mutation(internal.users.gcExpiredReports, {});
    await t.mutation(internal.problemReports.gcExpiredReports, {});
    await drain(t);
    const reports = await t.run((ctx) => ctx.db.query("reports").collect());
    const problems = await t.run((ctx) => ctx.db.query("problemReports").collect());
    expect(reports.map((r) => r.targetId)).toEqual(["fresh"]);
    expect(problems.map((r) => r.deviceId)).toEqual(["fresh"]);
  });
});

describe("session sweep", () => {
  test("gcRevokedSessions drains, and never touches a live session", async () => {
    const t = convexTest(schema);
    const a = await signUp(t, "alice");
    await t.run(async (ctx) => {
      for (let i = 0; i < 450; i++) {
        await ctx.db.insert("sessions", {
          userId: a.userId as any, tokenHash: `h${i}`, deviceId: `d${i}`,
          createdAt: 1, lastSeenAt: 1, revokedAt: 1000,
        });
      }
    });
    await t.mutation(internal.sessionCore.gcRevokedSessions, {});
    await drain(t);
    const left = await t.run((ctx) => ctx.db.query("sessions").collect());
    expect(left.length).toBe(1);
    expect(left[0].revokedAt).toBeUndefined();
  });
});

describe("call sweeps", () => {
  async function callFixture(t: ReturnType<typeof convexTest>) {
    const a = await signUp(t, "alice");
    const b = await signUp(t, "bob");
    const roomId = await roomFor(t, a, "r");
    return { a, b, roomId };
  }

  test("gcTerminalCalls drains and takes the signals with the calls", async () => {
    const t = convexTest(schema);
    const { a, b, roomId } = await callFixture(t);
    const old = Date.now() - 3 * DAY;
    await t.run(async (ctx) => {
      for (let i = 0; i < 120; i++) {
        const callId = await ctx.db.insert("calls", {
          callerId: a.userId as any, calleeId: b.userId as any, roomId,
          type: "audio", status: "ended", startedAt: old,
        });
        await ctx.db.insert("callSignals", {
          callId, fromUserId: a.userId as any, toUserId: b.userId as any,
          kind: "bye", payload: "{}", createdAt: old, consumed: false,
        });
      }
      await ctx.db.insert("calls", {
        callerId: a.userId as any, calleeId: b.userId as any, roomId,
        type: "audio", status: "ended", startedAt: Date.now(),
      });
    });
    await t.mutation(internal.calls.gcTerminalCalls, {});
    await drain(t);
    const calls = await t.run((ctx) => ctx.db.query("calls").collect());
    const sigs = await t.run((ctx) => ctx.db.query("callSignals").collect());
    expect(calls.length).toBe(1);
    expect(sigs.length).toBe(0);
  });

  test("gcConsumedSignals drains, and reaps unconsumed signals of ended calls only", async () => {
    const t = convexTest(schema);
    const { a, b, roomId } = await callFixture(t);
    const now = Date.now();
    const live = await t.run(async (ctx) => {
      const sig = (callId: any, consumed: boolean, createdAt: number) =>
        ctx.db.insert("callSignals", {
          callId, fromUserId: a.userId as any, toUserId: b.userId as any,
          kind: "ice", payload: "{}", createdAt, consumed,
        });
      const ended = await ctx.db.insert("calls", {
        callerId: a.userId as any, calleeId: b.userId as any, roomId,
        type: "audio", status: "ended", startedAt: now - 2 * DAY,
      });
      const active = await ctx.db.insert("calls", {
        callerId: a.userId as any, calleeId: b.userId as any, roomId,
        type: "audio", status: "active", startedAt: now - 2 * DAY,
      });
      for (let i = 0; i < 450; i++) await sig(ended, true, now - 10 * 60_000);
      for (let i = 0; i < 450; i++) await sig(ended, false, now - 2 * DAY);
      await sig(active, false, now - 2 * DAY);
      await sig(active, true, now - 1000); // consumed but too fresh
      return active;
    });
    await t.mutation(internal.calls.gcConsumedSignals, {});
    await drain(t);
    const sigs = await t.run((ctx) => ctx.db.query("callSignals").collect());
    expect(sigs.length).toBe(2);
    expect(sigs.every((s) => s.callId === live)).toBe(true);
  });
});

describe("group call sweeps", () => {
  async function fixture(t: ReturnType<typeof convexTest>) {
    const a = await signUp(t, "alice");
    const roomId = await roomFor(t, a, "r");
    return { a, roomId };
  }

  test("gcTerminalGroupCalls drains with participants and signals", async () => {
    const t = convexTest(schema);
    const { a, roomId } = await fixture(t);
    const old = Date.now() - 3 * DAY;
    await t.run(async (ctx) => {
      for (let i = 0; i < 120; i++) {
        const groupCallId = await ctx.db.insert("groupCalls", {
          roomId, startedBy: a.userId as any, type: "audio", status: "ended", startedAt: old,
        });
        await ctx.db.insert("groupCallParticipants", {
          groupCallId, userId: a.userId as any, status: "left", invitedAt: old,
        });
        await ctx.db.insert("groupCallSignals", {
          groupCallId, fromUserId: a.userId as any, toUserId: a.userId as any,
          kind: "offer", payload: "{}", createdAt: old, consumed: false,
        });
      }
    });
    await t.mutation(internal.groupCalls.gcTerminalGroupCalls, {});
    await drain(t);
    for (const table of ["groupCalls", "groupCallParticipants", "groupCallSignals"] as const) {
      expect((await t.run((ctx) => ctx.db.query(table).collect())).length).toBe(0);
    }
  });

  test("gcConsumedGroupSignals is not blocked by fresh rows at the head", async () => {
    const t = convexTest(schema);
    const { a, roomId } = await fixture(t);
    const now = Date.now();
    await t.run(async (ctx) => {
      const groupCallId = await ctx.db.insert("groupCalls", {
        roomId, startedBy: a.userId as any, type: "audio", status: "active", startedAt: now,
      });
      const sig = (createdAt: number) =>
        ctx.db.insert("groupCallSignals", {
          groupCallId, fromUserId: a.userId as any, toUserId: a.userId as any,
          kind: "ice-batch", payload: "{}", createdAt, consumed: true,
        });
      for (let i = 0; i < 250; i++) await sig(now); // fresh, inserted first
      for (let i = 0; i < 450; i++) await sig(now - 10 * 60_000);
    });
    await t.mutation(internal.groupCalls.gcConsumedGroupSignals, {});
    await drain(t);
    const left = await t.run((ctx) => ctx.db.query("groupCallSignals").collect());
    expect(left.length).toBe(250);
  });

  test("the participant reaper works past 50 live calls", async () => {
    const t = convexTest(schema);
    const { a, roomId } = await fixture(t);
    const now = Date.now();
    const healthy = await t.run(async (ctx) => {
      // 120 calls whose only participant went silent...
      for (let i = 0; i < 120; i++) {
        const groupCallId = await ctx.db.insert("groupCalls", {
          roomId, startedBy: a.userId as any, type: "audio", status: "active",
          startedAt: now - 60_000, joinedUserIds: [a.userId as any],
        });
        await ctx.db.insert("groupCallParticipants", {
          groupCallId, userId: a.userId as any, status: "joined",
          invitedAt: now - 60_000, joinedAt: now - 60_000, lastSeenAt: now - 5 * 60_000,
        });
      }
      // ...and one still heartbeating, created last so it sorts behind them all.
      const groupCallId = await ctx.db.insert("groupCalls", {
        roomId, startedBy: a.userId as any, type: "audio", status: "active",
        startedAt: now, joinedUserIds: [a.userId as any],
      });
      await ctx.db.insert("groupCallParticipants", {
        groupCallId, userId: a.userId as any, status: "joined",
        invitedAt: now, joinedAt: now, lastSeenAt: now,
      });
      return groupCallId;
    });
    await t.mutation(internal.groupCalls.gcStaleGroupParticipants, {});
    await drain(t);
    const calls = await t.run((ctx) => ctx.db.query("groupCalls").collect());
    expect(calls.filter((c) => c.status === "active").map((c) => c._id)).toEqual([healthy]);
    expect(calls.filter((c) => c.status === "ended").length).toBe(120);
  });
});

describe("groupCalls.liveInMyRooms", () => {
  test("shows my room's call with 150+ other live calls present", async () => {
    const t = convexTest(schema);
    const a = await signUp(t, "alice");
    const other = await signUp(t, "other");
    const theirRoom = await roomFor(t, other, "theirs");
    const myRoom = await roomFor(t, a, "mine");
    const now = Date.now();
    // 160 live calls in rooms alice is not in, all older than hers.
    const mine = await t.run(async (ctx) => {
      for (let i = 0; i < 160; i++) {
        await ctx.db.insert("groupCalls", {
          roomId: theirRoom, startedBy: other.userId as any, type: "audio",
          status: "active", startedAt: now - 10_000 + i, joinedUserIds: [other.userId as any],
        });
      }
      return await ctx.db.insert("groupCalls", {
        roomId: myRoom, startedBy: a.userId as any, type: "video",
        status: "active", startedAt: now, joinedUserIds: [other.userId as any],
      });
    });
    const viaMembership: any[] = await t.query(api.groupCalls.liveInMyRooms, {
      sessionToken: a.token, userId: a.userId as any,
    });
    expect(viaMembership.map((r) => r.groupCallId)).toEqual([mine]);
    const viaRoomIds: any[] = await t.query(api.groupCalls.liveInMyRooms, {
      sessionToken: a.token, userId: a.userId as any, roomIds: [myRoom, theirRoom],
    });
    // theirRoom is only a candidate: alice is not a member, so it shows nothing.
    expect(viaRoomIds.map((r) => r.groupCallId)).toEqual([mine]);
  });
});
