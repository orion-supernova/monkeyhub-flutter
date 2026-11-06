import { convexTest } from "convex-test";
import { afterEach, beforeEach, describe, expect, test, vi } from "vitest";
import { api, internal } from "./_generated/api";
import { buildApnsBody, buildFcmMessage } from "./push";
import schema from "./schema";

/**
 * Huddles: a group call that rings no one. See docs/design/swipe-up-fork.html
 * (huddle notifications, backend budget).
 */

const T0 = Date.parse("2026-11-06T10:00:00Z");
const HOUR = 60 * 60 * 1000;

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

async function roomWith(t: T, names: string[]) {
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
  return { people, roomId };
}

async function startHuddle(t: T, who: any, roomId: any, extra: Record<string, any> = {}) {
  const res: any = await t.mutation(api.groupCalls.start, {
    ...as(who),
    roomId,
    type: "audio",
    deviceId: `device-${who.userId}`,
    kind: "huddle",
    ...extra,
  });
  return res.groupCallId;
}

async function pending(t: T, needle: string) {
  return await t.run(async (ctx) => {
    const rows = await ctx.db.system.query("_scheduled_functions").collect();
    return rows
      .filter((r) => r.name.includes(needle) && r.state.kind === "pending")
      .map((r) => ({ args: r.args[0] as any, at: r.scheduledTime }));
  });
}

async function rowsOf(t: T, table: "groupCallParticipants" | "callSignals" | "groupCallSignals" | "messages") {
  return await t.run((ctx) => ctx.db.query(table as any).collect());
}

describe("a huddle rings no one", () => {
  test("no invitee rows, no signals, no VoIP and no ring-expiry job, even if invitees are named", async () => {
    const t = convexTest(schema);
    const { people, roomId } = await roomWith(t, ["alice", "bob", "carol"]);
    const [alice, bob, carol] = people;
    const id = await startHuddle(t, alice, roomId, {
      inviteeIds: [bob.userId, carol.userId],
    });

    const parts: any[] = await rowsOf(t, "groupCallParticipants");
    expect(parts).toHaveLength(1);
    expect(parts[0].userId).toBe(alice.userId);
    expect(parts[0].status).toBe("joined");
    expect(await rowsOf(t, "callSignals")).toHaveLength(0);
    expect(await rowsOf(t, "groupCallSignals")).toHaveLength(0);
    expect(await pending(t, "sendGroupVoip")).toHaveLength(0);
    expect(await pending(t, "sendGroupInvitePush")).toHaveLength(0);
    expect(await pending(t, "_expireRingers")).toHaveLength(0);

    const call: any = await t.run((ctx) => ctx.db.get(id));
    expect(call.kind).toBe("huddle");
  });

  test("with inviteeIds: [] too", async () => {
    const t = convexTest(schema);
    const { people, roomId } = await roomWith(t, ["alice", "bob"]);
    await startHuddle(t, people[0], roomId, { inviteeIds: [] });
    expect(await rowsOf(t, "groupCallParticipants")).toHaveLength(1);
    expect(await pending(t, "sendGroupVoip")).toHaveLength(0);
  });

  test("a ringing call is unchanged: it still rings", async () => {
    const t = convexTest(schema);
    const { people, roomId } = await roomWith(t, ["alice", "bob"]);
    await t.mutation(api.groupCalls.start, {
      ...as(people[0]),
      roomId,
      type: "audio",
    });
    expect(await pending(t, "sendGroupVoip")).toHaveLength(1);
    expect(await pending(t, "sendHuddlePush")).toHaveLength(0);
  });

  test("activeForRoom and liveInMyRooms expose the kind", async () => {
    const t = convexTest(schema);
    const { people, roomId } = await roomWith(t, ["alice", "bob"]);
    await startHuddle(t, people[0], roomId);
    const active: any = await t.query(api.groupCalls.activeForRoom, {
      ...as(people[1]),
      roomId,
    });
    expect(active.kind).toBe("huddle");
    const live: any[] = await t.query(api.groupCalls.liveInMyRooms, {
      ...as(people[1]),
      roomIds: [roomId],
    });
    expect(live[0].kind).toBe("huddle");
  });
});

describe("the passive push", () => {
  test("one push, soft copy, to everyone but the starter", async () => {
    const t = convexTest(schema);
    const { people, roomId } = await roomWith(t, ["alice", "bob", "carol"]);
    const id = await startHuddle(t, people[0], roomId);
    const [job] = await pending(t, "sendHuddlePush");
    expect(job.args.groupCallId).toBe(id);
    expect(job.args.userIds.sort()).toEqual([people[1].userId, people[2].userId].sort());
    expect(job.args.starterName).toBe("alice");
    expect(job.args.roomName).toBe("room-alice-bob-carol");
    const call: any = await t.run((ctx) => ctx.db.get(id));
    expect(call.pushedAt).toBe(T0);
    expect(call.pushedTo).toHaveLength(2);
  });

  test("muted members are skipped", async () => {
    const t = convexTest(schema);
    const { people, roomId } = await roomWith(t, ["alice", "bob", "carol"]);
    await t.run(async (ctx) => {
      const row = await ctx.db
        .query("roomMembers")
        .withIndex("by_room_user", (q) =>
          q.eq("roomId", roomId).eq("userId", people[1].userId),
        )
        .first();
      await ctx.db.patch(row!._id, { muteNotifications: true, mutedUntil: Number.MAX_SAFE_INTEGER });
    });
    await startHuddle(t, people[0], roomId);
    const [job] = await pending(t, "sendHuddlePush");
    expect(job.args.userIds).toEqual([people[2].userId]);
  });

  test("a per-room cooldown of two hours, from the previous huddle's pushedAt", async () => {
    const t = convexTest(schema);
    const { people, roomId } = await roomWith(t, ["alice", "bob"]);
    const [alice, bob] = people;
    const first = await startHuddle(t, alice, roomId);
    await t.mutation(api.groupCalls.leave, { ...as(alice), groupCallId: first });
    expect(await pending(t, "sendHuddlePush")).toHaveLength(1);

    // Another huddle an hour later, started by someone else: no second push.
    vi.setSystemTime(new Date(T0 + HOUR));
    await startHuddle(t, bob, roomId);
    expect(await pending(t, "sendHuddlePush")).toHaveLength(1);
    const second: any = (await rowsOf(t, "groupCallParticipants")).length;
    expect(second).toBeGreaterThan(0);

    // Past the cooldown it speaks again.
    const active: any = await t.query(api.groupCalls.activeForRoom, { ...as(bob), roomId });
    await t.mutation(api.groupCalls.leave, { ...as(bob), groupCallId: active.groupCallId });
    vi.setSystemTime(new Date(T0 + 2 * HOUR + 1000));
    await startHuddle(t, alice, roomId);
    expect(await pending(t, "sendHuddlePush")).toHaveLength(2);
  });

  test("a room of more than 20 gets no push, only the Join pill", async () => {
    const t = convexTest(schema);
    const { people, roomId } = await roomWith(t, ["alice", "bob"]);
    await t.run(async (ctx) => {
      for (let i = 0; i < 20; i++) {
        const u = await ctx.db.insert("users", {
          username: `filler${i}`,
          name: `filler${i}`,
          passwordHash: "x",
          createdAt: Date.now(),
        } as any);
        await ctx.db.insert("roomMembers", {
          roomId,
          userId: u,
          joinedAt: Date.now(),
          role: "member",
        });
      }
    });
    await startHuddle(t, people[0], roomId);
    expect(await pending(t, "sendHuddlePush")).toHaveLength(0);
  });

  test("a member who blocked the starter is not told", async () => {
    const t = convexTest(schema);
    const { people, roomId } = await roomWith(t, ["alice", "bob", "carol"]);
    await t.run((ctx) =>
      ctx.db.insert("blocks", {
        userId: people[1].userId,
        blockedUserId: people[0].userId,
        createdAt: Date.now(),
      } as any),
    );
    await startHuddle(t, people[0], roomId);
    const [job] = await pending(t, "sendHuddlePush");
    expect(job.args.userIds).toEqual([people[2].userId]);
  });

  test("iOS passive and no sound; Android on its own low-importance channel", () => {
    const spec: any = {
      kind: "huddle",
      title: "design crew",
      body: "alice is hanging out in design crew · Drop in",
      data: { kind: "huddle" },
      badge: 3,
      threadId: "room1",
      channelId: "huddles",
    };
    const aps: any = (buildApnsBody(spec) as any).aps;
    expect(aps["interruption-level"]).toBe("passive");
    expect(aps.sound).toBeUndefined();
    expect(aps.badge).toBeUndefined();
    const fcm: any = buildFcmMessage(spec, "tok");
    expect(fcm.data.channelId).toBe("huddles");
    expect(fcm.android.priority).toBe("normal");
    expect(fcm.data.badge).toBeUndefined();
  });
});

describe("alone timeout", () => {
  test("a starter left alone ends the huddle after three minutes", async () => {
    const t = convexTest(schema);
    const { people, roomId } = await roomWith(t, ["alice", "bob"]);
    const id = await startHuddle(t, people[0], roomId);
    const [job] = await pending(t, "_huddleAloneTimeout");
    expect(job.at - T0).toBe(3 * 60 * 1000);
    expect(await pending(t, "_huddleAloneTimeout")).toHaveLength(1);

    vi.setSystemTime(new Date(job.at));
    await t.mutation(internal.groupCalls._huddleAloneTimeout, job.args);
    const call: any = await t.run((ctx) => ctx.db.get(id));
    expect(call.status).toBe("ended");
  });

  test("someone joining cancels it: the stale job does nothing", async () => {
    const t = convexTest(schema);
    const { people, roomId } = await roomWith(t, ["alice", "bob"]);
    const id = await startHuddle(t, people[0], roomId);
    const [job] = await pending(t, "_huddleAloneTimeout");
    await t.mutation(api.groupCalls.join, { ...as(people[1]), groupCallId: id });
    const afterJoin: any = await t.run((ctx) => ctx.db.get(id));
    expect(afterJoin.aloneAt).toBeUndefined();

    vi.setSystemTime(new Date(job.at));
    await t.mutation(internal.groupCalls._huddleAloneTimeout, job.args);
    expect(((await t.run((ctx) => ctx.db.get(id))) as any).status).toBe("active");
  });

  test("when everyone else leaves, the clock starts again", async () => {
    const t = convexTest(schema);
    const { people, roomId } = await roomWith(t, ["alice", "bob"]);
    const id = await startHuddle(t, people[0], roomId);
    await t.mutation(api.groupCalls.join, { ...as(people[1]), groupCallId: id });
    vi.setSystemTime(new Date(T0 + 60_000));
    await t.mutation(api.groupCalls.leave, { ...as(people[1]), groupCallId: id });
    const call: any = await t.run((ctx) => ctx.db.get(id));
    expect(call.aloneAt).toBe(T0 + 60_000);
  });
});

describe("history", () => {
  test("an empty huddle writes nothing", async () => {
    const t = convexTest(schema);
    const { people, roomId } = await roomWith(t, ["alice", "bob"]);
    const id = await startHuddle(t, people[0], roomId);
    await t.mutation(api.groupCalls.leave, { ...as(people[0]), groupCallId: id });
    expect(((await t.run((ctx) => ctx.db.get(id))) as any).status).toBe("ended");
    expect(await rowsOf(t, "messages")).toHaveLength(0);
  });

  test("a huddle someone joined leaves exactly one history message, and withdraws the push", async () => {
    const t = convexTest(schema);
    const { people, roomId } = await roomWith(t, ["alice", "bob"]);
    const id = await startHuddle(t, people[0], roomId);
    await t.mutation(api.groupCalls.join, { ...as(people[1]), groupCallId: id });
    vi.setSystemTime(new Date(T0 + 4 * 60 * 1000));
    await t.mutation(api.groupCalls.leave, { ...as(people[1]), groupCallId: id });
    await t.mutation(api.groupCalls.leave, { ...as(people[0]), groupCallId: id });

    const msgs: any[] = await rowsOf(t, "messages");
    expect(msgs).toHaveLength(1);
    expect(msgs[0].type).toBe("system");
    expect(msgs[0].content).toBe(`huddle:ended:${4 * 60 * 1000}:2`);

    const [dismiss] = await pending(t, "dismissAndSync");
    expect(dismiss.args.dismissIds).toEqual([`huddle:${id}`]);
    expect(dismiss.args.userIds).toEqual([people[1].userId]);
  });
});

describe("ring someone into a huddle", () => {
  const invitedOf = async (t: T, who: any) =>
    (await rowsOf(t, "groupCallParticipants")).filter(
      (r: any) => r.userId === who.userId && r.status === "invited",
    );

  test("rings a member: invited row, one VoIP send, a ring-expiry job", async () => {
    const t = convexTest(schema);
    const { people, roomId } = await roomWith(t, ["alice", "bob", "carol"]);
    const id = await startHuddle(t, people[0], roomId);
    const res: any = await t.mutation(api.groupCalls.ringInto, {
      ...as(people[0]),
      groupCallId: id,
      inviteeIds: [people[1].userId],
    });
    expect(res.rung).toBe(1);
    expect(await invitedOf(t, people[1])).toHaveLength(1);
    expect(await pending(t, "sendGroupVoip")).toHaveLength(1);
    expect((await pending(t, "_expireRingers")).length).toBeGreaterThanOrEqual(1);
  });

  test("skips non-members, people already in, people already ringing, and yourself", async () => {
    const t = convexTest(schema);
    const { people, roomId } = await roomWith(t, ["alice", "bob", "carol"]);
    const stranger = await signUp(t, "mallory");
    const id = await startHuddle(t, people[0], roomId);
    await t.mutation(api.groupCalls.join, { ...as(people[1]), groupCallId: id });
    await t.mutation(api.groupCalls.ringInto, {
      ...as(people[0]),
      groupCallId: id,
      inviteeIds: [people[2].userId],
    });
    const again: any = await t.mutation(api.groupCalls.ringInto, {
      ...as(people[0]),
      groupCallId: id,
      inviteeIds: [people[0].userId, people[1].userId, people[2].userId, stranger.userId],
    });
    expect(again.rung).toBe(0);
    expect(await invitedOf(t, stranger)).toHaveLength(0);
    // Only ring sends carry inviteeIds; joining also schedules a cancel to the
    // joiner's other devices through the same action.
    const rings = (await pending(t, "sendGroupVoip")).filter((p) => p.args.inviteeIds);
    expect(rings).toHaveLength(1);
  });

  test("only someone in the call can ring, and only while it's live", async () => {
    const t = convexTest(schema);
    const { people, roomId } = await roomWith(t, ["alice", "bob", "carol"]);
    const id = await startHuddle(t, people[0], roomId);
    await expect(
      t.mutation(api.groupCalls.ringInto, {
        ...as(people[1]),
        groupCallId: id,
        inviteeIds: [people[2].userId],
      }),
    ).rejects.toThrow("NOT_IN_CALL");
    await t.mutation(api.groupCalls.leave, { ...as(people[0]), groupCallId: id } as any);
    await expect(
      t.mutation(api.groupCalls.ringInto, {
        ...as(people[0]),
        groupCallId: id,
        inviteeIds: [people[2].userId],
      }),
    ).rejects.toThrow(/CALL_ENDED|NOT_IN_CALL/);
  });
});
