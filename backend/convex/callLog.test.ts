import { convexTest } from "convex-test";
import { afterEach, beforeEach, describe, expect, test, vi } from "vitest";
import { api } from "./_generated/api";
import { decodeCall } from "./callHistory";
import schema from "./schema";

/**
 * Call history (docs/design/calls.md): the `call:` bubble's lifecycle, the
 * `callLog` rows every terminal path writes exactly once, and the Calls tab's
 * reads. Scheduled work is never drained here: only the mutations under test
 * run.
 */

const T0 = Date.parse("2026-11-06T10:00:00Z");

beforeEach(() => {
  vi.useFakeTimers();
  vi.setSystemTime(new Date(T0));
});
afterEach(() => {
  vi.useRealTimers();
});

const makeT = () => convexTest(schema);
type T = ReturnType<typeof makeT>;

async function signUp(t: T, username: string) {
  return await t.mutation(api.auth.signup, {
    username,
    name: username,
    passwordHash: `hash-${username}`,
    recoveryKeyHash: `recovery-${username}`,
    deviceId: `device-${username}`,
  });
}
const as = (u: { token: string; userId: string }) =>
  ({ sessionToken: u.token, userId: u.userId as any }) as any;

async function roomWith(t: T, names: string[], extra: Record<string, any> = {}) {
  const people: any[] = [];
  for (const n of names) people.push(await signUp(t, n));
  const roomId = await t.mutation(api.rooms.create, {
    ...as(people[0]),
    name: `room-${names.join("-")}`,
    isPrivate: false,
  });
  for (const p of people.slice(1)) {
    await t.mutation(api.rooms.join, { ...as(p), roomId });
  }
  if (Object.keys(extra).length > 0) {
    await t.run((ctx) => ctx.db.patch(roomId, extra));
  }
  return { people, roomId };
}

async function call(t: T, a: any, b: any, roomId: any, type = "audio") {
  return await t.mutation(api.calls.initiate, {
    sessionToken: a.token,
    callerId: a.userId as any,
    calleeId: b.userId as any,
    roomId,
    type,
  });
}

const accept = (t: T, callId: any, who: any, deviceId?: string) =>
  t.mutation(api.calls.accept, {
    sessionToken: who.token,
    callId,
    userId: who.userId as any,
    acceptingDeviceId: deviceId,
  });

const bubble = async (t: T, callId: any) => {
  const c: any = await t.run((ctx) => ctx.db.get(callId));
  const m: any = c.messageId ? await t.run((ctx) => ctx.db.get(c.messageId)) : null;
  return { call: c, message: m, fields: m ? decodeCall(m.content) : null };
};

const logOf = (t: T, userId: any) =>
  t.run((ctx) =>
    ctx.db
      .query("callLog")
      .withIndex("by_user_started", (q) => q.eq("userId", userId))
      .collect(),
  );

const at = (ms: number) => vi.setSystemTime(new Date(T0 + ms));

describe("direct call bubble", () => {
  test("ringing, active, ended with duration and answering platform", async () => {
    const t = makeT();
    const { people: [a, b], roomId } = await roomWith(t, ["alice", "bob"]);
    await t.run(async (ctx) => {
      await ctx.db.insert("userDevices", {
        userId: b.userId,
        deviceId: "bob-mac",
        platform: "macos",
        lastSeenAt: 0, createdAt: 0,
      } as any);
    });
    const callId = await call(t, a, b, roomId, "video");

    let s = await bubble(t, callId);
    expect(s.message.type).toBe("system");
    expect(s.message.userId).toBe(a.userId);
    expect(s.message.createdAt).toBe(T0);
    expect(s.message.content).toBe(
      `call:{"v":1,"k":"d","id":"${callId}","t":"video","s":"ringing"}`,
    );

    at(5000);
    await accept(t, callId, b, "bob-mac");
    s = await bubble(t, callId);
    expect(s.fields).toMatchObject({ s: "active", a: T0 + 5000, o: "macos" });

    at(65_000);
    await t.mutation(api.calls.end, { ...as(a), callId });
    s = await bubble(t, callId);
    expect(s.fields).toMatchObject({
      s: "ended",
      a: T0 + 5000,
      e: T0 + 65_000,
      d: 60_000,
      o: "macos",
    });
    const room: any = await t.run((ctx) => ctx.db.get(roomId));
    expect(room.lastMessage).toBe(s.message.content);
    expect(room.lastMessageTime).toBe(T0 + 65_000);
    expect(room.lastMessageSenderId).toBe(a.userId);
  });

  test("end during ringing is cancelled; the callee sees a miss", async () => {
    const t = makeT();
    const { people: [a, b], roomId } = await roomWith(t, ["alice", "bob"]);
    const callId = await call(t, a, b, roomId);
    at(3000);
    await t.mutation(api.calls.end, { ...as(a), callId });
    expect((await bubble(t, callId)).fields).toMatchObject({ s: "cancelled", e: T0 + 3000 });
    const [out] = await logOf(t, a.userId);
    const [inn] = await logOf(t, b.userId);
    expect(out).toMatchObject({ direction: "out", outcome: "cancelled", peerId: b.userId, durationMs: 0 });
    expect(inn).toMatchObject({ direction: "in", outcome: "missed", peerId: a.userId });
  });

  test("cancel, decline and ring timeout each settle once", async () => {
    const t = makeT();
    const { people: [a, b], roomId } = await roomWith(t, ["alice", "bob"]);

    const c1 = await call(t, a, b, roomId);
    await t.mutation(api.calls.cancel, { ...as(a), callId: c1 });
    expect((await bubble(t, c1)).fields?.s).toBe("cancelled");

    const c2 = await call(t, a, b, roomId);
    await t.mutation(api.calls.reject, { ...as(b), callId: c2 });
    expect((await bubble(t, c2)).fields?.s).toBe("declined");

    const c3 = await call(t, a, b, roomId);
    at(31_000);
    await t.run(async (ctx) => {
      // The scheduled expiry, run by hand.
    });
    const { internal } = await import("./_generated/api");
    await t.mutation(internal.calls.expireRingingCall, { callId: c3 });
    expect((await bubble(t, c3)).fields?.s).toBe("missed");

    const rows = await logOf(t, a.userId);
    expect(rows.map((r: any) => r.outcome).sort()).toEqual(["cancelled", "declined", "unanswered"]);
    const theirs = await logOf(t, b.userId);
    expect(theirs.map((r: any) => r.outcome).sort()).toEqual(["declined", "missed", "missed"]);
    expect(rows).toHaveLength(3);
    expect(theirs).toHaveLength(3);
  });

  test("a second terminal transition does not double-write", async () => {
    const t = makeT();
    const { people: [a, b], roomId } = await roomWith(t, ["alice", "bob"]);
    const callId = await call(t, a, b, roomId);
    await accept(t, callId, b, "d");
    await t.mutation(api.calls.end, { ...as(a), callId });
    await t.mutation(api.calls.end, { ...as(b), callId });
    expect(await logOf(t, a.userId)).toHaveLength(1);
    expect(await logOf(t, b.userId)).toHaveLength(1);
    // Even the reaper's helper, forced on an already recorded call.
    const { recordDirectCallEnd } = await import("./callHistory");
    await t.run(async (ctx) => {
      const c: any = await ctx.db.get(callId);
      await recordDirectCallEnd(ctx, c, "ended", Date.now());
    });
    expect(await logOf(t, a.userId)).toHaveLength(1);
  });

  test("answered rows carry duration, answeredAt and handoffs", async () => {
    const t = makeT();
    const { people: [a, b], roomId } = await roomWith(t, ["alice", "bob"]);
    await t.run(async (ctx) => {
      await ctx.db.insert("userDevices", { userId: b.userId, deviceId: "bob-phone", platform: "ios", lastSeenAt: 0, createdAt: 0 } as any);
      await ctx.db.insert("userDevices", { userId: b.userId, deviceId: "bob-mac", platform: "macos", lastSeenAt: 0, createdAt: 0 } as any);
    });
    const callId = await call(t, a, b, roomId);
    at(2000);
    await accept(t, callId, b, "bob-phone");
    at(12_000);
    await t.mutation(api.calls.handoffCall, { ...as(b), callId, newDeviceId: "bob-mac" });
    at(22_000);
    await t.mutation(api.calls.end, { ...as(b), callId });

    for (const u of [a, b]) {
      const [r]: any[] = await logOf(t, u.userId);
      expect(r).toMatchObject({
        outcome: "answered",
        answeredAt: T0 + 2000,
        endedAt: T0 + 22_000,
        durationMs: 20_000,
        answeredOn: "ios",
        handoffs: [{ at: T0 + 12_000, platform: "macos" }],
      });
    }
  });

  test("room teardown ends the call without writing history", async () => {
    const t = makeT();
    const { people: [a, b], roomId } = await roomWith(t, ["alice", "bob"]);
    const callId = await call(t, a, b, roomId);
    const { endLiveCallsInRoom } = await import("./calls");
    await t.run((ctx) => endLiveCallsInRoom(ctx, roomId));
    expect(((await bubble(t, callId)).call as any).status).toBe("ended");
    expect((await bubble(t, callId)).fields?.s).toBe("ringing");
    expect(await logOf(t, a.userId)).toHaveLength(0);
  });

  test("a deleted bubble is skipped, history still lands", async () => {
    const t = makeT();
    const { people: [a, b], roomId } = await roomWith(t, ["alice", "bob"]);
    const callId = await call(t, a, b, roomId);
    const { call: c } = await bubble(t, callId);
    await t.run((ctx) => ctx.db.delete(c.messageId));
    await t.mutation(api.calls.cancel, { ...as(a), callId });
    expect(await logOf(t, a.userId)).toHaveLength(1);
    const room: any = await t.run((ctx) => ctx.db.get(roomId));
    expect(room.lastMessage ?? "").not.toContain("call:");
  });

  test("a vanishing room expires the bubble and shows the vanish preview", async () => {
    const t = makeT();
    const { people: [a, b], roomId } = await roomWith(t, ["alice", "bob"], { vanishMode: true });
    const callId = await call(t, a, b, roomId);
    const { message } = await bubble(t, callId);
    expect(message.vanishUntil).toBeGreaterThan(T0);
    await t.mutation(api.calls.cancel, { ...as(a), callId });
    const room: any = await t.run((ctx) => ctx.db.get(roomId));
    expect(room.lastMessage).toBe("Vanishing message");
  });

  test("a message lifetime schedules expiry", async () => {
    const t = makeT();
    const { people: [a, b], roomId } = await roomWith(t, ["alice", "bob"], { messageLifetime: 3600 });
    const callId = await call(t, a, b, roomId);
    const { message } = await bubble(t, callId);
    expect(message.expiresAt).toBe(T0 + 3600 * 1000);
  });
});

async function groupCall(t: T, starter: any, roomId: any, extra: Record<string, any> = {}) {
  const res: any = await t.mutation(api.groupCalls.start, {
    ...as(starter),
    roomId,
    type: "video",
    deviceId: `device-${starter.userId}`,
    ...extra,
  });
  return res.groupCallId;
}

const joinGroup = (t: T, who: any, groupCallId: any) =>
  t.mutation(api.groupCalls.join, { ...as(who), groupCallId, deviceId: `device-${who.userId}` });
const leaveGroup = (t: T, who: any, groupCallId: any) =>
  t.mutation(api.groupCalls.leave, { ...as(who), groupCallId });

describe("group call history", () => {
  test("bubble goes live on the first other join, then settles with n and d", async () => {
    const t = makeT();
    const { people: [a, b, c, d], roomId } = await roomWith(t, ["alice", "bob", "carol", "dave"]);
    const id = await groupCall(t, a, roomId);
    const gc0: any = await t.run((ctx) => ctx.db.get(id));
    expect(decodeCall((await t.run((ctx) => ctx.db.get(gc0.messageId)) as any).content)).toEqual({
      v: 1, k: "g", id: id.toString(), t: "video", s: "ringing",
    });

    at(10_000);
    await joinGroup(t, b, id);
    at(20_000);
    await joinGroup(t, c, id);
    const gc1: any = await t.run((ctx) => ctx.db.get(id));
    expect(gc1.firstJoinAt).toBe(T0 + 10_000);
    const live = decodeCall(((await t.run((ctx) => ctx.db.get(gc1.messageId))) as any).content);
    expect(live).toMatchObject({ s: "active", a: T0 + 10_000 });

    at(70_000);
    await leaveGroup(t, c, id);
    at(100_000);
    await leaveGroup(t, b, id);
    await leaveGroup(t, a, id);

    const end = decodeCall(((await t.run((ctx) => ctx.db.get(gc1.messageId))) as any).content);
    expect(end).toMatchObject({ s: "ended", a: T0 + 10_000, e: T0 + 100_000, d: 90_000, n: 3 });

    const ra: any = (await logOf(t, a.userId))[0];
    const rb: any = (await logOf(t, b.userId))[0];
    const rc: any = (await logOf(t, c.userId))[0];
    const rd: any = (await logOf(t, d.userId))[0];
    expect(ra).toMatchObject({ kind: "group", direction: "out", outcome: "answered", people: 3, durationMs: 90_000 });
    expect(ra.peerId).toBeUndefined();
    expect(rb).toMatchObject({ direction: "in", outcome: "answered", peerId: a.userId, durationMs: 90_000 });
    expect(rc).toMatchObject({ direction: "in", outcome: "answered", durationMs: 50_000 });
    expect(rd).toMatchObject({ direction: "in", outcome: "missed", peerId: a.userId, durationMs: 0 });
    const room: any = await t.run((ctx) => ctx.db.get(roomId));
    expect(room.lastMessage).toContain('"s":"ended"');
  });

  test("nobody joined: missed bubble, unanswered for the starter, declined recorded", async () => {
    const t = makeT();
    const { people: [a, b, c], roomId } = await roomWith(t, ["alice", "bob", "carol"]);
    const id = await groupCall(t, a, roomId);
    await t.mutation(api.groupCalls.decline, { ...as(b), groupCallId: id });
    at(15_000);
    await leaveGroup(t, a, id);
    const gc: any = await t.run((ctx) => ctx.db.get(id));
    expect(decodeCall(((await t.run((ctx) => ctx.db.get(gc.messageId))) as any).content)).toMatchObject({
      s: "missed", n: 1,
    });
    expect(gc.firstJoinAt).toBeUndefined();
    expect(((await logOf(t, a.userId))[0] as any).outcome).toBe("unanswered");
    expect(((await logOf(t, b.userId))[0] as any).outcome).toBe("declined");
    expect(((await logOf(t, c.userId))[0] as any).outcome).toBe("missed");
  });

  test("a huddle keeps its history line and logs only the people who joined", async () => {
    const t = makeT();
    const { people: [a, b, c], roomId } = await roomWith(t, ["alice", "bob", "carol"]);
    const id = await groupCall(t, a, roomId, { kind: "huddle" });
    const gc: any = await t.run((ctx) => ctx.db.get(id));
    expect(gc.messageId).toBeUndefined();
    at(5000);
    await joinGroup(t, b, id);
    at(65_000);
    await leaveGroup(t, b, id);
    await leaveGroup(t, a, id);
    const msgs: any[] = await t.run((ctx) => ctx.db.query("messages").collect());
    expect(msgs.map((m) => m.content)).toEqual([`huddle:ended:65000:2`]);
    expect(((await logOf(t, a.userId)) as any[])[0]).toMatchObject({ kind: "huddle", direction: "out", outcome: "answered", people: 2 });
    expect(((await logOf(t, b.userId)) as any[])[0]).toMatchObject({ kind: "huddle", direction: "in", outcome: "answered", durationMs: 60_000 });
    expect(await logOf(t, c.userId)).toHaveLength(0);
  });

  test("an empty huddle logs nothing", async () => {
    const t = makeT();
    const { people: [a], roomId } = await roomWith(t, ["alice", "bob"]);
    const id = await groupCall(t, a, roomId, { kind: "huddle" });
    await leaveGroup(t, a, id);
    expect(await logOf(t, a.userId)).toHaveLength(0);
  });
});

describe("callLog API", () => {
  async function twoCalls(t: T) {
    const { people: [a, b], roomId } = await roomWith(t, ["alice", "bob"]);
    const c1 = await call(t, a, b, roomId);
    await accept(t, c1, b, "d");
    at(30_000);
    await t.mutation(api.calls.end, { ...as(a), callId: c1 });
    const c2 = await call(t, a, b, roomId);
    at(60_000);
    await t.mutation(api.calls.cancel, { ...as(a), callId: c2 });
    return { a, b, roomId, c1, c2 };
  }

  test("list is newest first, scoped to me, and filters missed", async () => {
    const t = makeT();
    const { a, b, c1, c2 } = await twoCalls(t);
    const all: any = await t.query(api.callLog.list, {
      sessionToken: b.token, filter: "all", paginationOpts: { numItems: 10, cursor: null },
    });
    expect(all.page.map((r: any) => r.callId)).toEqual([c2, c1]);
    expect(all.page.every((r: any) => r.userId === b.userId)).toBe(true);
    const missed: any = await t.query(api.callLog.list, {
      sessionToken: b.token, filter: "missed", paginationOpts: { numItems: 10, cursor: null },
    });
    expect(missed.page.map((r: any) => r.callId)).toEqual([c2]);
    const mine: any = await t.query(api.callLog.list, {
      sessionToken: a.token, filter: "missed", paginationOpts: { numItems: 10, cursor: null },
    });
    expect(mine.page).toHaveLength(0);
  });

  test("summary totals talk time and ranks peers", async () => {
    const t = makeT();
    const { a, b } = await twoCalls(t);
    const s = await t.query(api.callLog.summary, { sessionToken: a.token, since: 0 });
    expect(s.totalMs).toBe(30_000);
    expect(s.calls).toBe(2);
    expect(s.top).toEqual([{ peerId: b.userId, ms: 30_000, calls: 2 }]);
  });

  test("remove only deletes my own row; clear empties mine", async () => {
    const t = makeT();
    const { a, b } = await twoCalls(t);
    const [mineRow, ...rest]: any[] = await logOf(t, a.userId);
    const [theirRow]: any[] = await logOf(t, b.userId);
    await t.mutation(api.callLog.remove, { sessionToken: a.token, id: theirRow._id });
    expect(await logOf(t, b.userId)).toHaveLength(2);
    await t.mutation(api.callLog.remove, { sessionToken: a.token, id: mineRow._id });
    expect(await logOf(t, a.userId)).toHaveLength(rest.length);
    expect(await t.mutation(api.callLog.clear, { sessionToken: a.token })).toEqual({ more: false });
    expect(await logOf(t, a.userId)).toHaveLength(0);
    expect(await logOf(t, b.userId)).toHaveLength(2);
  });

  test("reportQuality stores my samples and only ever worsens the bubble", async () => {
    const t = makeT();
    const { a, b, c1 } = await twoCalls(t);
    await t.mutation(api.callLog.reportQuality, { sessionToken: a.token, callId: c1, samples: [0, 1, 0, 9, -3] });
    let { fields } = await bubble(t, c1);
    expect(fields?.q).toBe("poor");
    const [ra]: any[] = (await logOf(t, a.userId)).filter((r: any) => r.callId === c1);
    expect(ra.quality).toEqual({ worst: "poor", samples: [0, 1, 0, 2, 0] });

    await t.mutation(api.callLog.reportQuality, { sessionToken: b.token, callId: c1, samples: [0, 0] });
    fields = (await bubble(t, c1)).fields;
    expect(fields?.q).toBe("poor"); // b's good report did not improve it
    const rb: any = (await logOf(t, b.userId)).find((r: any) => r.callId === c1);
    expect(rb.quality.worst).toBe("good");
  });

  test("reportQuality caps samples and ignores a call that is not mine", async () => {
    const t = makeT();
    const { a, c1 } = await twoCalls(t);
    const stranger = await signUp(t, "mallory");
    await t.mutation(api.callLog.reportQuality, { sessionToken: stranger.token, callId: c1, samples: [2] });
    expect((await bubble(t, c1)).fields?.q).toBeUndefined();
    await t.mutation(api.callLog.reportQuality, {
      sessionToken: a.token, callId: c1, samples: Array.from({ length: 500 }, () => 1),
    });
    const ra: any = (await logOf(t, a.userId)).find((r: any) => r.callId === c1);
    expect(ra.quality.samples).toHaveLength(360);
    expect((await bubble(t, c1)).fields?.q).toBe("fair");
  });
});

describe("account deletion", () => {
  test("the user plan has a step that clears callLog", async () => {
    const { planFor } = await import("./deletionPlans");
    expect(planFor("user").map((s) => s.id)).toContain("generic:callLog.userId");
  });
});
