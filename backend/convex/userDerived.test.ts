import { convexTest } from "convex-test";
import { describe, expect, test, vi } from "vitest";
import { api, internal } from "./_generated/api";
import schema from "./schema";
import { hookDb } from "./dbHooks";
import { badgeTotalFor } from "./badges";

async function signUp(t: ReturnType<typeof convexTest>, username: string) {
  return await t.mutation(api.auth.signup, {
    username,
    name: username,
    passwordHash: `hash-${username}`,
    recoveryKeyHash: `recovery-${username}`,
    deviceId: `device-${username}`,
  });
}

const pushRow = (t: any, userId: any) =>
  t.run((ctx: any) =>
    ctx.db.query("userPushState").withIndex("by_user", (q: any) => q.eq("userId", userId)).first(),
  );
const countsRow = (t: any, userId: any) =>
  t.run((ctx: any) =>
    ctx.db.query("userBadgeCounts").withIndex("by_user", (q: any) => q.eq("userId", userId)).first(),
  );
const targets = (t: any, userIds: any[]) =>
  t.query(internal.push._loadAlertTargets, { userIds }) as Promise<any[]>;

async function setApns(t: any, me: any, deviceId = `device-${me.username ?? ""}`, token = "tok") {
  await t.mutation(api.voipTokens.setApnsToken, {
    sessionToken: me.token,
    userId: me.userId,
    deviceId,
    platform: "ios",
    token,
  } as any);
}

describe("userPushState", () => {
  test("device add, disable and remove move the row", async () => {
    const t = convexTest(schema);
    const me = await signUp(t, "ann");
    await setApns(t, me, "device-ann", "tok1");
    let row = await pushRow(t, me.userId);
    expect(row.devices.map((d: any) => d.apnsToken)).toEqual(["tok1"]);
    expect((await targets(t, [me.userId]))[0].devices).toHaveLength(1);

    await t.mutation(api.voipTokens.setPushEnabled, {
      sessionToken: me.token, userId: me.userId, deviceId: "device-ann", enabled: false,
    } as any);
    expect((await pushRow(t, me.userId)).devices).toEqual([]);

    await t.mutation(api.voipTokens.setPushEnabled, {
      sessionToken: me.token, userId: me.userId, deviceId: "device-ann", enabled: true,
    } as any);
    expect((await pushRow(t, me.userId)).devices).toHaveLength(1);

    await t.mutation(api.voipTokens.clearDeviceToken, {
      sessionToken: me.token, userId: me.userId, deviceId: "device-ann",
    } as any).catch(() => {});
    row = await pushRow(t, me.userId);
    expect(row.devices).toEqual([]);
  });

  test("a revoked session drops its device", async () => {
    const t = convexTest(schema);
    const me = await signUp(t, "bob");
    await setApns(t, me, "device-bob", "tokb");
    expect((await pushRow(t, me.userId)).devices).toHaveLength(1);
    await t.run(async (ctx) => {
      const s = await ctx.db.query("sessions").withIndex("by_user", (q) => q.eq("userId", me.userId)).first();
      return s;
    });
    await t.run(async (ctx) => {
      const rows = await ctx.db.query("sessions").withIndex("by_user", (q) => q.eq("userId", me.userId)).collect();
      for (const r of rows) await hookDb(ctx.db).patch(r._id, { revokedAt: Date.now() });
    });
    expect((await pushRow(t, me.userId)).devices).toEqual([]);
    expect((await targets(t, [me.userId]))[0].devices).toEqual([]);
  });

  test("an idle-expired session is swept out of the row", async () => {
    const t = convexTest(schema);
    const me = await signUp(t, "cat");
    await setApns(t, me, "device-cat", "tokc");
    await t.run(async (ctx) => {
      const s = await ctx.db.query("sessions").withIndex("by_user", (q) => q.eq("userId", me.userId)).first();
      await ctx.db.patch(s!._id, { lastSeenAt: 1 });
    });
    // Past the grace floor plus the idle window.
    vi.useFakeTimers({ toFake: ["Date"] });
    vi.setSystemTime(new Date("2027-06-01"));
    try {
      await t.mutation(internal.sessionCore.expireIdleSessions, {} as any);
    } finally {
      vi.useRealTimers();
    }
    expect((await pushRow(t, me.userId)).devices).toEqual([]);
  });

  test("a missing row falls back to the full computation, then the backfill fills it", async () => {
    const t = convexTest(schema);
    const me = await signUp(t, "dan");
    await setApns(t, me, "device-dan", "tokd");
    await t.run(async (ctx) => {
      const r = await ctx.db.query("userPushState").first();
      await ctx.db.delete(r!._id);
    });
    expect(await pushRow(t, me.userId)).toBeNull();
    const out = await targets(t, [me.userId]);
    expect(out[0].devices.map((d: any) => d.apnsToken)).toEqual(["tokd"]);
    await t.mutation(internal.userDerived.backfill, {});
    await t.finishAllScheduledFunctions(() => {});
    expect((await pushRow(t, me.userId)).devices).toHaveLength(1);
    expect(await countsRow(t, me.userId)).not.toBeNull();
    // Idempotent.
    await t.mutation(internal.userDerived.backfill, {});
    const rows = await t.run((ctx) => ctx.db.query("userPushState").collect());
    expect(rows).toHaveLength(1);
  });
});

describe("userBadgeCounts", () => {
  const total = (t: any, userId: any) =>
    t.run((ctx: any) => badgeTotalFor(ctx, userId)).then((r: any) => r.total as number);

  test("request, accept, reject and cancel keep the pending count exact", async () => {
    const t = convexTest(schema);
    const a = await signUp(t, "eve");
    const b = await signUp(t, "fay");
    const c = await signUp(t, "gus");
    const send = (from: any, to: string) =>
      t.mutation(api.friends.sendRequest, { sessionToken: from.token, userId: from.userId, friendUsername: to } as any);

    await send(a, "fay");
    await send(c, "fay");
    expect((await countsRow(t, b.userId)).requests).toBe(2);
    expect(await total(t, b.userId)).toBe(2);
    // The sender has nothing pending.
    expect((await countsRow(t, a.userId))?.requests ?? 0).toBe(0);

    await t.mutation(api.friends.acceptRequest, {
      sessionToken: b.token, userId: b.userId, requesterId: a.userId,
    } as any);
    expect((await countsRow(t, b.userId)).requests).toBe(1);

    await t.mutation(api.friends.rejectRequest, {
      sessionToken: b.token, userId: b.userId, requesterId: c.userId,
    } as any);
    expect((await countsRow(t, b.userId)).requests).toBe(0);
    expect(await total(t, b.userId)).toBe(0);

    await send(c, "fay");
    expect((await countsRow(t, b.userId)).requests).toBe(1);
    await t.mutation(api.friends.cancelDirectRequest, {
      sessionToken: c.token, userId: c.userId, friendId: b.userId,
    } as any);
    expect((await countsRow(t, b.userId)).requests).toBe(0);
  });

  test("a missing row falls back to the scan and a later write rebuilds it", async () => {
    const t = convexTest(schema);
    const a = await signUp(t, "hal");
    const b = await signUp(t, "ivy");
    const c = await signUp(t, "jon");
    await t.mutation(api.friends.sendRequest, { sessionToken: a.token, userId: a.userId, friendUsername: "ivy" } as any);
    await t.run(async (ctx) => {
      const r = await ctx.db.query("userBadgeCounts").withIndex("by_user", (q) => q.eq("userId", b.userId)).first();
      await ctx.db.delete(r!._id);
    });
    expect(await total(t, b.userId)).toBe(1);
    // The next write recounts absolutely (the other request included).
    await t.mutation(api.friends.sendRequest, { sessionToken: c.token, userId: c.userId, friendUsername: "ivy" } as any);
    expect((await countsRow(t, b.userId)).requests).toBe(2);
  });
});
