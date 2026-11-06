import { convexTest } from "convex-test";
import { afterEach, beforeEach, describe, expect, test, vi } from "vitest";
import { api, internal } from "./_generated/api";
import schema from "./schema";
import { startRoomDeletion } from "./deletionCore";

/**
 * Vanish mode, end to end on the backend (docs/design/swipe-up-fork.html:
 * vanish, hidden seen, cleanup, budget).
 *
 * Jobs are run by hand rather than drained: a vanishing room's 24h deadline
 * chain reschedules itself forever, so `finishAllScheduledFunctions` would
 * never return. The clock is faked, so `vi.setSystemTime` is how time passes.
 */

const T0 = Date.parse("2026-11-06T10:00:00Z");
const DAY = 24 * 60 * 60 * 1000;

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

const tok = (u: { token: string }) => ({ sessionToken: u.token }) as any;

function at(ms: number) {
  vi.setSystemTime(new Date(ms));
}

/** A room with [alice] (owner) and the rest joined. */
async function roomWith(t: T, names: string[], extra: Record<string, any> = {}) {
  const people: any[] = [];
  for (const n of names) people.push(await signUp(t, n));
  const roomId = await t.mutation(api.rooms.create, {
    ...as(people[0]),
    name: `room-${names.join("-")}`,
    isPrivate: false,
    ...extra,
  });
  for (const p of people.slice(1)) {
    await t.mutation(api.rooms.join, { ...as(p), roomId });
  }
  return { people, roomId };
}

async function send(t: T, who: any, roomId: any, content: string) {
  return await t.mutation(api.messages.send, {
    ...as(who),
    roomId,
    content,
  });
}

async function read(
  t: T,
  who: any,
  roomId: any,
  upTo: number,
  flags: { vanish?: boolean; vanishCounts?: boolean } = {},
) {
  await t.mutation(api.messages.markRoomRead, {
    ...as(who),
    roomId,
    upTo,
    ...flags,
  } as any);
}

async function msg(t: T, id: any) {
  return await t.run((ctx) => ctx.db.get(id));
}

async function stateOf(t: T, roomId: any) {
  return await t.run((ctx) =>
    ctx.db
      .query("vanishState")
      .withIndex("by_room", (q) => q.eq("roomId", roomId))
      .first(),
  );
}

/** The member's cursors as one row: roster fields plus the C1 receipts row. */
async function memberRow(t: T, roomId: any, userId: any) {
  return await t.run(async (ctx) => {
    const m = await ctx.db
      .query("roomMembers")
      .withIndex("by_room_user", (q) =>
        q.eq("roomId", roomId).eq("userId", userId),
      )
      .first();
    const r = await ctx.db
      .query("roomReceipts")
      .withIndex("by_room_user", (q) =>
        q.eq("roomId", roomId).eq("userId", userId),
      )
      .first();
    const st = await ctx.db
      .query("roomUserState")
      .withIndex("by_room_user", (q) =>
        q.eq("roomId", roomId).eq("userId", userId),
      )
      .first();
    return {
      ...m,
      ...(r ?? {}),
      ...(st ? { vanishShareReads: st.vanishShareReads } : {}),
      _id: r?._id ?? m?._id,
      joinedAt: m?.joinedAt,
    };
  });
}

/** Pending scheduled jobs whose name contains [needle]. */
async function pending(t: T, needle: string) {
  return await t.run(async (ctx) => {
    const rows = await ctx.db.system.query("_scheduled_functions").collect();
    return rows
      .filter((r) => r.name.includes(needle) && r.state.kind === "pending")
      .map((r) => ({ args: r.args[0] as any, at: r.scheduledTime, id: r._id }));
  });
}

async function runBurn(t: T, roomId: any) {
  await t.mutation(internal.vanish.burnVanished, { roomId });
}

async function turnOn(t: T, who: any, roomId: any, afterSeen?: number) {
  return await t.mutation(api.vanish.setVanishMode, {
    ...tok(who),
    roomId,
    on: true,
    ...(afterSeen !== undefined ? { afterSeen } : {}),
  });
}

describe("turning vanish mode on and off", () => {
  test("on: room flag, one state row, one deadline job, one system line", async () => {
    const t = convexTest(schema);
    const { people, roomId } = await roomWith(t, ["alice", "bob"]);
    const res = await turnOn(t, people[0], roomId);
    expect(res).toEqual({ changed: true });

    const room: any = await t.run((ctx) => ctx.db.get(roomId));
    expect(room.vanishMode).toBe(true);
    expect(room.vanishAfterSeen).toBe(10);

    const state: any = await stateOf(t, roomId);
    expect(state.active).toBe(true);
    expect(state.deadlineAt).toBe(T0 + DAY);
    expect(await pending(t, "vanishDeadline")).toHaveLength(1);

    const lines = await t.run((ctx) =>
      ctx.db
        .query("messages")
        .withIndex("by_room_time", (q) => q.eq("roomId", roomId))
        .collect(),
    );
    expect(lines.map((m) => m.content)).toEqual(["vanish:on:10"]);
    expect(lines[0].type).toBe("system");
    expect(lines[0].vanishUntil).toBeUndefined();
  });

  test("turning it on twice is a no-op: no second line, no second job", async () => {
    const t = convexTest(schema);
    const { people, roomId } = await roomWith(t, ["alice", "bob"]);
    await turnOn(t, people[0], roomId);
    expect(await turnOn(t, people[0], roomId)).toEqual({ changed: false });
    const lines = await t.run((ctx) =>
      ctx.db
        .query("messages")
        .withIndex("by_room_time", (q) => q.eq("roomId", roomId))
        .collect(),
    );
    expect(lines).toHaveLength(1);
    expect(await pending(t, "vanishDeadline")).toHaveLength(1);
  });

  test("a different timer while on is a change, with its own line", async () => {
    const t = convexTest(schema);
    const { people, roomId } = await roomWith(t, ["alice", "bob"]);
    await turnOn(t, people[0], roomId);
    expect(await turnOn(t, people[0], roomId, 60)).toEqual({ changed: true });
    expect(((await stateOf(t, roomId)) as any).afterSeen).toBe(60);
    await expect(turnOn(t, people[0], roomId, 7)).rejects.toThrow("BAD_VANISH_TIMER");
  });

  test("off keeps the state row until the last promised message is gone", async () => {
    const t = convexTest(schema);
    const { people, roomId } = await roomWith(t, ["alice", "bob"]);
    await turnOn(t, people[0], roomId);
    await send(t, people[0], roomId, "kept for a day");
    await t.mutation(api.vanish.setVanishMode, { ...tok(people[0]), roomId, on: false });
    expect(((await stateOf(t, roomId)) as any).active).toBe(false);
    const room: any = await t.run((ctx) => ctx.db.get(roomId));
    expect(room.vanishMode).toBe(false);
  });

  test("a group member without settings rights cannot toggle it", async () => {
    const t = convexTest(schema);
    const { people, roomId } = await roomWith(t, ["alice", "bob"]);
    await expect(turnOn(t, people[1], roomId)).rejects.toThrow();
  });

  test("a secret room refuses vanish mode", async () => {
    const t = convexTest(schema);
    const { people, roomId } = await roomWith(t, ["alice", "bob"], {
      type: "secret",
      messageLifetime: 60,
    });
    await expect(turnOn(t, people[0], roomId)).rejects.toThrow(
      "VANISH_NOT_ALLOWED_IN_SECRET_ROOM",
    );
  });
});

describe("sending", () => {
  test("stamps vanishUntil = sentAt + 24h, no expiresAt, and schedules nothing of its own", async () => {
    const t = convexTest(schema);
    const { people, roomId } = await roomWith(t, ["alice", "bob"]);
    await turnOn(t, people[0], roomId);
    const jobsBefore = (await pending(t, "vanish")).length;
    const expireBefore = (await pending(t, "expireMessage")).length;

    at(T0 + 5000);
    const id = await send(t, people[0], roomId, "psst");
    const m: any = await msg(t, id);
    expect(m.vanishUntil).toBe(m.createdAt + DAY);
    expect(m.expiresAt).toBeUndefined();

    expect((await pending(t, "vanish")).length).toBe(jobsBefore);
    expect((await pending(t, "expireMessage")).length).toBe(expireBefore);
  });

  test("a normal room's messages are untouched", async () => {
    const t = convexTest(schema);
    const { people, roomId } = await roomWith(t, ["alice", "bob"]);
    const id = await send(t, people[0], roomId, "hello");
    const m: any = await msg(t, id);
    expect(m.vanishUntil).toBeUndefined();
    expect(await stateOf(t, roomId)).toBeNull();
  });

  test("the push says only 'Vanishing message' and drops the seed", async () => {
    const t = convexTest(schema);
    const { people, roomId } = await roomWith(t, ["alice", "bob"]);
    await turnOn(t, people[0], roomId);
    await send(t, people[0], roomId, "top secret words");
    const [job] = await pending(t, "sendMessagePush");
    expect(job.args.vanishing).toBe(true);
    expect(job.args.content).toBe("Vanishing message");
    const room: any = await t.run((ctx) => ctx.db.get(roomId));
    expect(room.lastMessage).toBe("Vanishing message");
  });

  test("forwarding out of a vanishing room is refused", async () => {
    const t = convexTest(schema);
    const { people, roomId } = await roomWith(t, ["alice", "bob"]);
    const other = await t.mutation(api.rooms.create, {
      ...as(people[0]),
      name: "elsewhere",
      isPrivate: false,
    });
    const id = await send(t, people[0], roomId, "before vanish");
    await turnOn(t, people[0], roomId);
    await expect(
      t.mutation(api.messages.forwardToRoom, {
        ...as(people[0]),
        sourceRoomId: roomId,
        targetRoomId: other,
        messageIds: [id],
      }),
    ).rejects.toThrow("SOURCE_IS_EPHEMERAL");
  });
});

describe("the seen floor and the burn", () => {
  test("a normal room: markRoomRead with no hint writes nothing vanish-shaped", async () => {
    const t = convexTest(schema);
    const { people, roomId } = await roomWith(t, ["alice", "bob"]);
    const id = await send(t, people[0], roomId, "hello");
    const m: any = await msg(t, id);
    await read(t, people[1], roomId, m.createdAt);
    expect(((await memberRow(t, roomId, people[1].userId)) as any).vanishSeenAt).toBe(((await memberRow(t, roomId, people[1].userId)) as any).joinedAt);
    expect(await stateOf(t, roomId)).toBeNull();
    expect(await pending(t, "burnVanished")).toHaveLength(0);
  });

  test("in a vanishing room, without the hint nothing vanish-shaped is written either", async () => {
    const t = convexTest(schema);
    const { people, roomId } = await roomWith(t, ["alice", "bob"]);
    await turnOn(t, people[0], roomId);
    at(T0 + 1000);
    const id = await send(t, people[0], roomId, "psst");
    const m: any = await msg(t, id);
    at(T0 + 2000);
    await read(t, people[1], roomId, m.createdAt);
    expect(((await memberRow(t, roomId, people[1].userId)) as any).vanishSeenAt).toBe(((await memberRow(t, roomId, people[1].userId)) as any).joinedAt);
    expect(await pending(t, "burnVanished")).toHaveLength(0);
  });

  test("a recipient who does not share holds the message to 24 hours", async () => {
    const t = convexTest(schema);
    const { people, roomId } = await roomWith(t, ["alice", "bob"]);
    const [alice, bob] = people;
    await turnOn(t, alice, roomId);
    at(T0 + 1000);
    const id = await send(t, alice, roomId, "psst");
    const m: any = await msg(t, id);

    at(T0 + 2000);
    await read(t, bob, roomId, m.createdAt, { vanish: true, vanishCounts: false });
    // The normal cursor moved, the vanish one did not, nothing was queued.
    const row: any = await memberRow(t, roomId, bob.userId);
    expect(row.lastReadAt).toBe(m.createdAt);
    expect(row.vanishSeenAt).toBe(row.joinedAt);
    expect(await pending(t, "burnVanished")).toHaveLength(0);

    // Hours later it is still there...
    at(T0 + 23 * 60 * 60 * 1000);
    await runBurn(t, roomId);
    expect(await msg(t, id)).not.toBeNull();

    // ...and the 24h deadline takes it.
    const state: any = await stateOf(t, roomId);
    at(m.vanishUntil + 1);
    await t.mutation(internal.vanish.vanishDeadline, {
      roomId,
      at: state.deadlineAt,
    });
    expect(await msg(t, id)).toBeNull();
  });

  test("a sharing recipient burns it vanishAfterSeen seconds after they read it", async () => {
    const t = convexTest(schema);
    const { people, roomId } = await roomWith(t, ["alice", "bob"]);
    const [alice, bob] = people;
    await turnOn(t, alice, roomId);
    at(T0 + 1000);
    const id = await send(t, alice, roomId, "psst");
    const m: any = await msg(t, id);

    at(T0 + 2000);
    await read(t, bob, roomId, m.createdAt, { vanish: true, vanishCounts: true });
    expect(((await memberRow(t, roomId, bob.userId)) as any).vanishSeenAt).toBe(m.createdAt);

    const [burn] = await pending(t, "burnVanished");
    expect(burn.at).toBe(T0 + 2000 + 10_000);
    const state: any = await stateOf(t, roomId);
    expect(state.burnAt).toBe(T0 + 12_000);

    // Early duplicate fires do nothing; the real one deletes.
    at(T0 + 5000);
    await runBurn(t, roomId);
    expect(await msg(t, id)).not.toBeNull();
    at(T0 + 12_000);
    await runBurn(t, roomId);
    expect(await msg(t, id)).toBeNull();
    // The burn did not patch the room preview.
    const room: any = await t.run((ctx) => ctx.db.get(roomId));
    expect(room.lastMessage).toBe("Vanishing message");
    expect(((await stateOf(t, roomId)) as any).burnUpTo).toBeUndefined();
  });

  test("my own read never holds my own message, and my message never waits for me", async () => {
    const t = convexTest(schema);
    const { people, roomId } = await roomWith(t, ["alice", "bob"]);
    const [alice, bob] = people;
    await turnOn(t, alice, roomId);
    at(T0 + 1000);
    const mine = await send(t, alice, roomId, "from alice");
    at(T0 + 1500);
    const theirs = await send(t, bob, roomId, "from bob");
    const m1: any = await msg(t, mine);
    const m2: any = await msg(t, theirs);

    // Alice never reads and never shares. Bob reads both and shares.
    at(T0 + 2000);
    await read(t, bob, roomId, m2.createdAt, { vanish: true, vanishCounts: true });
    at(T0 + 20_000);
    await runBurn(t, roomId);
    // Alice's message was seen by everyone it was sent to (Bob): gone.
    expect(await msg(t, mine)).toBeNull();
    // Bob's message was sent to Alice, who has not shared a read: held.
    expect(await msg(t, theirs)).not.toBeNull();
    expect(m1.vanishUntil).toBeLessThan(m2.vanishUntil);
  });

  test("sharing later burns what was already read, after the grace", async () => {
    const t = convexTest(schema);
    const { people, roomId } = await roomWith(t, ["alice", "bob"]);
    const [alice, bob] = people;
    await turnOn(t, alice, roomId);
    at(T0 + 1000);
    const id = await send(t, alice, roomId, "psst");
    const m: any = await msg(t, id);
    at(T0 + 2000);
    await read(t, bob, roomId, m.createdAt, { vanish: true, vanishCounts: false });
    expect(await pending(t, "burnVanished")).toHaveLength(0);

    at(T0 + 3 * 60 * 60 * 1000);
    await t.mutation(api.vanish.setVanishShareReads, {
      ...tok(bob),
      roomId,
      share: true,
    });
    const row: any = await memberRow(t, roomId, bob.userId);
    expect(row.vanishShareReads).toBe(true);
    expect(row.vanishSeenAt).toBe(m.createdAt);

    const [burn] = await pending(t, "burnVanished");
    expect(burn.at).toBe(T0 + 3 * 60 * 60 * 1000 + 10_000);
    expect(await msg(t, id)).not.toBeNull();
    at(burn.at);
    await runBurn(t, roomId);
    expect(await msg(t, id)).toBeNull();
  });

  test("the global switch catches up on the next counted read of an already-read room", async () => {
    const t = convexTest(schema);
    const { people, roomId } = await roomWith(t, ["alice", "bob"]);
    const [alice, bob] = people;
    await turnOn(t, alice, roomId);
    at(T0 + 1000);
    const id = await send(t, alice, roomId, "psst");
    const m: any = await msg(t, id);
    at(T0 + 2000);
    await read(t, bob, roomId, m.createdAt, { vanish: true, vanishCounts: false });
    at(T0 + 4000);
    // Same cursor, but they now agree to share: the early-return path catches up.
    await read(t, bob, roomId, m.createdAt, { vanish: true, vanishCounts: true });
    expect(((await memberRow(t, roomId, bob.userId)) as any).vanishSeenAt).toBe(m.createdAt);
    expect(await pending(t, "burnVanished")).toHaveLength(1);
  });

  test("at most one burn job per room; a later reach waits its own full grace", async () => {
    const t = convexTest(schema);
    const { people, roomId } = await roomWith(t, ["alice", "bob"]);
    const [alice, bob] = people;
    await turnOn(t, alice, roomId);
    at(T0 + 1000);
    const a = await send(t, alice, roomId, "one");
    const ma: any = await msg(t, a);
    at(T0 + 1500);
    const b = await send(t, alice, roomId, "two");
    const mb: any = await msg(t, b);

    at(T0 + 2000);
    await read(t, bob, roomId, ma.createdAt, { vanish: true, vanishCounts: true });
    at(T0 + 6000);
    await read(t, bob, roomId, mb.createdAt, { vanish: true, vanishCounts: true });
    // The second read only recorded where it got to.
    expect(await pending(t, "burnVanished")).toHaveLength(1);
    const state: any = await stateOf(t, roomId);
    expect(state.nextReachedAt).toBe(T0 + 6000);

    // The first job fires at +12s: it takes "one" and not "two", then
    // reschedules itself for the second reach + 10s = +16s.
    at(T0 + 12_000);
    await runBurn(t, roomId);
    expect(await msg(t, a)).toBeNull();
    expect(await msg(t, b)).not.toBeNull();
    // (The first job was run by hand here, so the scheduler still lists it as
    // pending; the live one is the job the state names.)
    const live: any = await stateOf(t, roomId);
    expect(live.burnAt).toBe(T0 + 16_000);
    const jobsAfter = await pending(t, "burnVanished");
    expect(jobsAfter.filter((j) => j.at === T0 + 16_000)).toHaveLength(1);

    at(T0 + 16_000);
    await runBurn(t, roomId);
    expect(await msg(t, b)).toBeNull();
    expect(((await stateOf(t, roomId)) as any).burnAt).toBeUndefined();
  });

  test("a group: the slowest reader holds everyone else's messages, and a leaver is dropped from the floor", async () => {
    const t = convexTest(schema);
    const { people, roomId } = await roomWith(t, ["alice", "bob", "carol"]);
    const [alice, bob, carol] = people;
    await turnOn(t, alice, roomId);
    at(T0 + 1000);
    const id = await send(t, alice, roomId, "to both");
    const m: any = await msg(t, id);

    at(T0 + 2000);
    await read(t, bob, roomId, m.createdAt, { vanish: true, vanishCounts: true });
    at(T0 + 3000);
    // Carol has not read: Alice's message is held for her.
    await runBurn(t, roomId);
    expect(await msg(t, id)).not.toBeNull();
    expect(await pending(t, "burnVanished")).toHaveLength(0);

    // Carol leaves: she stops counting, the floor is recomputed in the same
    // mutation and the burn is queued.
    at(T0 + 4000);
    await t.mutation(api.rooms.leave, { ...as(carol), roomId });
    const [burn] = await pending(t, "burnVanished");
    expect(burn.at).toBe(T0 + 4000 + 10_000);
    at(burn.at);
    await runBurn(t, roomId);
    expect(await msg(t, id)).toBeNull();
  });
});

describe("the deadline chain", () => {
  test("exactly one deadline job; an early burn leaves it nothing to do, and with vanish off it ends the chain", async () => {
    const t = convexTest(schema);
    const { people, roomId } = await roomWith(t, ["alice", "bob"]);
    const [alice, bob] = people;
    await turnOn(t, alice, roomId);
    at(T0 + 1000);
    const id = await send(t, alice, roomId, "psst");
    expect(await pending(t, "vanishDeadline")).toHaveLength(1);
    const m: any = await msg(t, id);
    at(T0 + 2000);
    await read(t, bob, roomId, m.createdAt, { vanish: true, vanishCounts: true });
    at(T0 + 12_000);
    await runBurn(t, roomId);
    expect(await msg(t, id)).toBeNull();

    // Vanish off, nothing left: the deadline job finds nothing and ends it all.
    await t.mutation(api.vanish.setVanishMode, { ...tok(alice), roomId, on: false });
    const state: any = await stateOf(t, roomId);
    at(state.deadlineAt);
    await t.mutation(internal.vanish.vanishDeadline, { roomId, at: state.deadlineAt });
    expect(await stateOf(t, roomId)).toBeNull();
  });

  test("with vanish still on and nothing left it reschedules for a day later: one job a day", async () => {
    const t = convexTest(schema);
    const { people, roomId } = await roomWith(t, ["alice", "bob"]);
    await turnOn(t, people[0], roomId);
    const state: any = await stateOf(t, roomId);
    at(state.deadlineAt);
    await t.mutation(internal.vanish.vanishDeadline, { roomId, at: state.deadlineAt });
    const after: any = await stateOf(t, roomId);
    expect(after.deadlineAt).toBe(state.deadlineAt + DAY);
    // Exactly one job is aimed at the new instant (the first was run by hand).
    const live = (await pending(t, "vanishDeadline")).filter((j) => j.args.at === after.deadlineAt);
    expect(live).toHaveLength(1);
  });

  test("it points itself at the oldest survivor", async () => {
    const t = convexTest(schema);
    const { people, roomId } = await roomWith(t, ["alice", "bob"]);
    await turnOn(t, people[0], roomId);
    at(T0 + 3 * 60 * 60 * 1000);
    const id = await send(t, people[0], roomId, "later");
    const m: any = await msg(t, id);
    const state: any = await stateOf(t, roomId);
    at(state.deadlineAt);
    await t.mutation(internal.vanish.vanishDeadline, { roomId, at: state.deadlineAt });
    expect(((await stateOf(t, roomId)) as any).deadlineAt).toBe(m.vanishUntil);
    expect(await msg(t, id)).not.toBeNull();
  });

  test("a superseded job (token mismatch) does nothing", async () => {
    const t = convexTest(schema);
    const { people, roomId } = await roomWith(t, ["alice", "bob"]);
    await turnOn(t, people[0], roomId);
    const state: any = await stateOf(t, roomId);
    at(state.deadlineAt + 1);
    await t.mutation(internal.vanish.vanishDeadline, { roomId, at: 12345 });
    expect(((await stateOf(t, roomId)) as any).deadlineAt).toBe(state.deadlineAt);
  });

  test("the daily backstop cleans up after a lost job and re-arms the chain", async () => {
    const t = convexTest(schema);
    const { people, roomId } = await roomWith(t, ["alice", "bob"]);
    await turnOn(t, people[0], roomId);
    at(T0 + 1000);
    const id = await send(t, people[0], roomId, "stuck");
    const m: any = await msg(t, id);
    // The deadline job "died": time passes far beyond it with no run.
    at(m.vanishUntil + 3 * 60 * 60 * 1000);
    await t.mutation(internal.retention.gcVanishBackstop, {});
    expect(await msg(t, id)).toBeNull();
    const after: any = await stateOf(t, roomId);
    expect(after.deadlineAt).toBeGreaterThan(Date.now());
  });

  test("the backstop ignores a healthy chain", async () => {
    const t = convexTest(schema);
    const { people, roomId } = await roomWith(t, ["alice", "bob"]);
    await turnOn(t, people[0], roomId);
    const before: any = await stateOf(t, roomId);
    await t.mutation(internal.retention.gcVanishBackstop, {});
    expect(((await stateOf(t, roomId)) as any).deadlineJobId).toBe(before.deadlineJobId);
  });
});

describe("queries never show a message past its promise", () => {
  test("list drops a vanishing message whose time has passed, even if its job is late", async () => {
    const t = convexTest(schema);
    const { people, roomId } = await roomWith(t, ["alice", "bob"]);
    await turnOn(t, people[0], roomId);
    at(T0 + 1000);
    const id = await send(t, people[0], roomId, "expiring");
    const keep = await send(t, people[0], roomId, "fresh");
    const m: any = await msg(t, id);
    const call = () =>
      t.query(api.messages.list, { ...tok(people[1]), roomId } as any);
    const before: any[] = await call();
    expect(before.map((x) => x._id)).toContain(id);

    at(m.vanishUntil + 1);
    // `keep` has the same deadline moment minus a millisecond or so; push it out.
    await t.run((ctx) => ctx.db.patch(keep, { vanishUntil: Date.now() + DAY }));
    const after: any[] = await call();
    expect(after.map((x) => x._id)).not.toContain(id);
    expect(after.map((x) => x._id)).toContain(keep);
  });
});

describe("secret rooms on the seen clock", () => {
  test("no expiresAt, no per-message job, a vanishUntil and a state row from creation", async () => {
    const t = convexTest(schema);
    const { people, roomId } = await roomWith(t, ["alice", "bob"], {
      type: "secret",
      messageLifetime: 60,
      messageClock: "seen",
    });
    const state: any = await stateOf(t, roomId);
    expect(state.afterSeen).toBe(60);
    expect(await pending(t, "vanishDeadline")).toHaveLength(1);

    const id = await send(t, people[0], roomId, "secret");
    const m: any = await msg(t, id);
    expect(m.expiresAt).toBeUndefined();
    expect(m.vanishUntil).toBe(m.createdAt + DAY);
    expect(await pending(t, "expireMessage")).toHaveLength(0);
  });

  test("the sent clock is exactly as before", async () => {
    const t = convexTest(schema);
    const { people, roomId } = await roomWith(t, ["alice", "bob"], {
      type: "secret",
      messageLifetime: 60,
    });
    expect(await stateOf(t, roomId)).toBeNull();
    const id = await send(t, people[0], roomId, "secret");
    const m: any = await msg(t, id);
    expect(m.expiresAt).toBe(m.createdAt + 60_000);
    expect(m.vanishUntil).toBeUndefined();
    expect(await pending(t, "expireMessage")).toHaveLength(1);
  });

  test("a seen-clock timer must be 10s, 1m or 1h", async () => {
    const t = convexTest(schema);
    const a = await signUp(t, "alice");
    await expect(
      t.mutation(api.rooms.create, {
        ...as(a),
        name: "bad",
        isPrivate: false,
        type: "secret",
        messageLifetime: 45,
        messageClock: "seen",
      }),
    ).rejects.toThrow("BAD_VANISH_TIMER");
  });
});

describe("prefs and state queries", () => {
  test("stateForRoom is members-only and null with no activity", async () => {
    const t = convexTest(schema);
    const { people, roomId } = await roomWith(t, ["alice", "bob"]);
    const stranger = await signUp(t, "mallory");
    expect(await t.query(api.vanish.stateForRoom, { ...tok(people[0]), roomId })).toBeNull();
    await turnOn(t, people[0], roomId);
    expect(await t.query(api.vanish.stateForRoom, { ...tok(stranger), roomId })).toBeNull();
    const s: any = await t.query(api.vanish.stateForRoom, { ...tok(people[1]), roomId });
    expect(s.active).toBe(true);
    expect(s.afterSeen).toBe(10);
  });

  test("stateForRoom never names the slowest reader to anyone else", async () => {
    const t = convexTest(schema);
    const { people, roomId } = await roomWith(t, ["alice", "bob", "carol"]);
    await turnOn(t, people[0], roomId);
    // Force a side-burn target onto the cached state, whoever computes it.
    await t.run(async (ctx) => {
      const s = await ctx.db
        .query("vanishState")
        .withIndex("by_room", (q) => q.eq("roomId", roomId))
        .first();
      await ctx.db.patch(s!._id, { burnWho: people[2].userId, burnUpTo2: 12345 });
    });
    for (const who of [people[0], people[1]]) {
      const s: any = await t.query(api.vanish.stateForRoom, { ...tok(who), roomId });
      expect(s.mineUpTo).toBeNull();
      expect(JSON.stringify(s)).not.toContain(String(people[2].userId));
    }
    const mine: any = await t.query(api.vanish.stateForRoom, { ...tok(people[2]), roomId });
    expect(mine.mineUpTo).toBe(12345);
  });

  test("updateVisibility stores the global switch; myVanishPrefs reflects it", async () => {
    const t = convexTest(schema);
    const { people, roomId } = await roomWith(t, ["alice", "bob"]);
    const bob = people[1];
    await t.mutation(api.users.updateVisibility, { ...as(bob), seen: "nobody" } as any);
    let prefs: any = await t.query(api.vanish.myVanishPrefs, { ...tok(bob), roomId });
    expect(prefs).toEqual({ perChat: null, global: false, seen: "nobody", counts: false });
    await t.mutation(api.users.updateVisibility, { ...as(bob), vanishShareReads: true } as any);
    prefs = await t.query(api.vanish.myVanishPrefs, { ...tok(bob), roomId });
    expect(prefs.global).toBe(true);
    expect(prefs.counts).toBe(true);
  });
});

describe("teardown", () => {
  test("room deletion cancels both jobs and removes the state row and its messages", async () => {
    const t = convexTest(schema);
    const { people, roomId } = await roomWith(t, ["alice", "bob"]);
    const [alice, bob] = people;
    await turnOn(t, alice, roomId);
    at(T0 + 1000);
    const id = await send(t, alice, roomId, "psst");
    const m: any = await msg(t, id);
    at(T0 + 2000);
    await read(t, bob, roomId, m.createdAt, { vanish: true, vanishCounts: true });
    const state: any = await stateOf(t, roomId);
    expect(state.burnJobId).toBeDefined();
    expect(state.deadlineJobId).toBeDefined();

    await t.run((ctx) => startRoomDeletion(ctx, roomId, { reason: "test" } as any));
    // Drive only the deletion links; the room's own jobs must already be gone.
    await t.finishAllScheduledFunctions(vi.runAllTimers);
    expect(await stateOf(t, roomId)).toBeNull();
    expect(await msg(t, id)).toBeNull();
    expect(await pending(t, "vanishDeadline")).toHaveLength(0);
    expect(await pending(t, "burnVanished")).toHaveLength(0);
  });
});
