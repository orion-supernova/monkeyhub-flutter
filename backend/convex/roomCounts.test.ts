import { convexTest } from "convex-test";
import { afterEach, beforeEach, describe, expect, test, vi } from "vitest";
import { api, internal } from "./_generated/api";
import { MAX_ROOMS_PER_USER } from "./roomAdmin";
import { drainDeletions } from "./deletionTestUtils";
import schema from "./schema";
import { reconcileSystemRoomMembers } from "./systemRooms";

/**
 * Phase 4E: the per-user room count behind MAX_ROOMS_PER_USER.
 * A missing `userRoomCounts` row means "not counted yet", never zero.
 */

type T = ReturnType<typeof convexTest>;
type Who = { token: string; userId: string };

beforeEach(() => {
  vi.useFakeTimers();
});
afterEach(() => {
  vi.useRealTimers();
});
const drain = (t: T) => drainDeletions(t, () => vi.advanceTimersByTime(0));

const signUp = (t: T, username: string): Promise<Who> =>
  t.mutation(api.auth.signup, {
    username,
    name: username,
    passwordHash: `hash-${username}`,
    recoveryKeyHash: `recovery-${username}`,
    deviceId: `device-${username}`,
  }) as any;
const as = (w: Who) => ({ sessionToken: w.token, userId: w.userId as any });

const counterOf = (t: T, w: Who) =>
  t.run(async (ctx: any) =>
    ctx.db
      .query("userRoomCounts")
      .withIndex("by_user", (q: any) => q.eq("userId", w.userId))
      .collect(),
  );
const countOf = async (t: T, w: Who) => {
  const rows = await counterOf(t, w);
  expect(rows.length).toBeLessThanOrEqual(1);
  return rows.length ? (rows[0] as any).count : null;
};
const realRows = (t: T, w: Who) =>
  t.run(async (ctx: any) =>
    (
      await ctx.db
        .query("roomMembers")
        .withIndex("by_user", (q: any) => q.eq("userId", w.userId))
        .collect()
    ).length,
  );
const newRoom = (t: T, w: Who, name: string) =>
  t.mutation(api.rooms.create, { ...as(w), name, isPrivate: false });

describe("userRoomCounts is kept exact", () => {
  test("create, join and leave move the count by one each", async () => {
    const t = convexTest(schema);
    const owner = await signUp(t, "owner");
    const guest = await signUp(t, "guest");
    const r1 = await newRoom(t, owner, "one");
    expect(await countOf(t, owner)).toBe(1);
    const r2 = await newRoom(t, owner, "two");
    expect(await countOf(t, owner)).toBe(2);

    await t.mutation(api.rooms.join, { ...as(guest), roomId: r1 });
    await t.mutation(api.rooms.join, { ...as(guest), roomId: r2 });
    expect(await countOf(t, guest)).toBe(2);
    // Joining twice does not count twice.
    await t.mutation(api.rooms.join, { ...as(guest), roomId: r2 });
    expect(await countOf(t, guest)).toBe(2);

    await t.mutation(api.rooms.leave, { ...as(guest), roomId: r1 });
    expect(await countOf(t, guest)).toBe(1);
    expect(await realRows(t, guest)).toBe(1);
  });

  test("an admin removing a member decrements that member", async () => {
    const t = convexTest(schema);
    const owner = await signUp(t, "owner");
    const guest = await signUp(t, "guest");
    const room = await newRoom(t, owner, "crew");
    await t.mutation(api.rooms.join, { ...as(guest), roomId: room });
    expect(await countOf(t, guest)).toBe(1);
    await t.mutation(api.roomAdmin.removeMember, {
      ...as(owner),
      roomId: room,
      targetUserId: guest.userId as any,
    });
    expect(await countOf(t, guest)).toBe(0);
  });
});

describe("the cap is a point read", () => {
  test("the counter row alone decides: 500 refuses with zero membership rows", async () => {
    const t = convexTest(schema);
    const owner = await signUp(t, "owner");
    const guest = await signUp(t, "guest");
    const room = await newRoom(t, owner, "crew");
    await t.run(async (ctx: any) => {
      await ctx.db.insert("userRoomCounts", {
        userId: guest.userId,
        count: MAX_ROOMS_PER_USER,
      });
    });
    await expect(
      t.mutation(api.rooms.join, { ...as(guest), roomId: room }),
    ).rejects.toThrow("TOO_MANY_ROOMS");
    expect(await realRows(t, guest)).toBe(0);
    // One below the cap is let through and lands exactly on it.
    await t.run(async (ctx: any) => {
      const row = await ctx.db
        .query("userRoomCounts")
        .withIndex("by_user", (q: any) => q.eq("userId", guest.userId))
        .first();
      await ctx.db.patch(row._id, { count: MAX_ROOMS_PER_USER - 1 });
    });
    await t.mutation(api.rooms.join, { ...as(guest), roomId: room });
    expect(await countOf(t, guest)).toBe(MAX_ROOMS_PER_USER);
  });

  test("the self-chat stays exempt at the cap", async () => {
    const t = convexTest(schema);
    const me = await signUp(t, "me");
    await t.run(async (ctx: any) => {
      await ctx.db.insert("userRoomCounts", {
        userId: me.userId,
        count: MAX_ROOMS_PER_USER,
      });
    });
    await t.mutation(api.rooms.ensureSavedMessagesRoom, { ...as(me) });
    expect(await realRows(t, me)).toBe(1);
    expect(await countOf(t, me)).toBe(MAX_ROOMS_PER_USER + 1);
  });
});

describe("a user with no counter row yet", () => {
  test("the bounded count decides, then the row is written correctly", async () => {
    const t = convexTest(schema);
    const owner = await signUp(t, "owner");
    const guest = await signUp(t, "guest");
    const room = await newRoom(t, owner, "crew");
    const other = await newRoom(t, owner, "other");
    // Simulate a pre-deploy account: three memberships, no counter row.
    await t.run(async (ctx: any) => {
      for (let i = 0; i < 3; i++) {
        await ctx.db.insert("roomMembers", {
          roomId: other,
          userId: guest.userId,
          joinedAt: i,
          role: "member",
        });
      }
    });
    expect(await countOf(t, guest)).toBeNull();
    await t.mutation(api.rooms.join, { ...as(guest), roomId: room });
    expect(await countOf(t, guest)).toBe(4);
  });

  test("at the cap the fallback refuses and writes no row", async () => {
    const t = convexTest(schema);
    const owner = await signUp(t, "owner");
    const guest = await signUp(t, "guest");
    const room = await newRoom(t, owner, "crew");
    const other = await newRoom(t, owner, "other");
    await t.run(async (ctx: any) => {
      for (let i = 0; i < MAX_ROOMS_PER_USER; i++) {
        await ctx.db.insert("roomMembers", {
          roomId: other,
          userId: guest.userId,
          joinedAt: i,
          role: "member",
        });
      }
    });
    await expect(
      t.mutation(api.rooms.join, { ...as(guest), roomId: room }),
    ).rejects.toThrow("TOO_MANY_ROOMS");
    expect(await countOf(t, guest)).toBeNull();
  });

  test("leaving with no counter row stays uncounted (and does not throw)", async () => {
    const t = convexTest(schema);
    const owner = await signUp(t, "owner");
    const guest = await signUp(t, "guest");
    const room = await newRoom(t, owner, "crew");
    await t.mutation(api.rooms.join, { ...as(guest), roomId: room });
    await t.run(async (ctx: any) => {
      for (const r of await ctx.db
        .query("userRoomCounts")
        .withIndex("by_user", (q: any) => q.eq("userId", guest.userId))
        .collect())
        await ctx.db.delete(r._id);
    });
    await t.mutation(api.rooms.leave, { ...as(guest), roomId: room });
    expect(await countOf(t, guest)).toBeNull();
  });
});

describe("self-healing", () => {
  test("a decrement below zero clamps to zero and logs", async () => {
    const t = convexTest(schema);
    const owner = await signUp(t, "owner");
    const guest = await signUp(t, "guest");
    const room = await newRoom(t, owner, "crew");
    await t.mutation(api.rooms.join, { ...as(guest), roomId: room });
    await t.run(async (ctx: any) => {
      const row = await ctx.db
        .query("userRoomCounts")
        .withIndex("by_user", (q: any) => q.eq("userId", guest.userId))
        .first();
      await ctx.db.patch(row._id, { count: -3 });
    });
    const warn = vi.spyOn(console, "warn").mockImplementation(() => {});
    await t.mutation(api.rooms.leave, { ...as(guest), roomId: room });
    expect(await countOf(t, guest)).toBe(0);
    expect(warn).toHaveBeenCalled();
    warn.mockRestore();
  });
});

describe("system rooms", () => {
  test("a counted reader's count rises with the direct insert; an uncounted one stays uncounted", async () => {
    const t = convexTest(schema);
    const counted = await signUp(t, "counted");
    const uncounted = await signUp(t, "uncounted");
    const room = await t.run(async (ctx: any) =>
      ctx.db.insert("rooms", {
        name: "sys",
        createdBy: counted.userId,
        createdAt: 1,
        isPrivate: true,
        memberCount: 0,
        type: "Regular Room",
      }),
    );
    await t.run(async (ctx: any) => {
      await ctx.db.insert("userRoomCounts", { userId: counted.userId, count: 0 });
      await reconcileSystemRoomMembers(ctx, room, counted.userId, [uncounted.userId]);
    });
    expect(await countOf(t, counted)).toBe(1);
    expect(await countOf(t, uncounted)).toBeNull();
  });
});

describe("deletion keeps counts correct", () => {
  test("deleting a room decrements every member and keeps other rooms counted", async () => {
    const t = convexTest(schema);
    const owner = await signUp(t, "owner");
    const a = await signUp(t, "alice");
    const b = await signUp(t, "bob");
    const doomed = await newRoom(t, owner, "doomed");
    const kept = await newRoom(t, owner, "kept");
    for (const w of [a, b]) {
      await t.mutation(api.rooms.join, { ...as(w), roomId: doomed });
    }
    await t.mutation(api.rooms.join, { ...as(a), roomId: kept });
    await t.mutation(api.rooms.deleteRoom, { ...as(owner), roomId: doomed });
    await drain(t);
    expect(await countOf(t, owner)).toBe(1);
    expect(await countOf(t, a)).toBe(1);
    expect(await countOf(t, b)).toBe(0);
    for (const w of [owner, a, b]) {
      expect(await countOf(t, w)).toBe(await realRows(t, w));
    }
  });

  test("deleting an account decrements what it leaves behind and removes its row", async () => {
    const t = convexTest(schema);
    const owner = await signUp(t, "owner");
    const leaver = await signUp(t, "leaver");
    const room = await newRoom(t, owner, "crew");
    await t.mutation(api.rooms.join, { ...as(leaver), roomId: room });
    const mineToo = await newRoom(t, leaver, "mine");
    await t.mutation(api.rooms.join, { ...as(owner), roomId: mineToo });
    expect(await countOf(t, owner)).toBe(2);
    await t.mutation(api.auth.deleteAccount, {
      sessionToken: leaver.token,
      userId: leaver.userId as any,
    });
    await drain(t);
    expect(await counterOf(t, leaver)).toHaveLength(0);
    expect(await countOf(t, owner)).toBe(await realRows(t, owner));
    expect(await countOf(t, owner)).toBe(2);
  });
});

describe("backfill", () => {
  async function uncountedWorld(t: T) {
    const a = await signUp(t, "alice");
    const b = await signUp(t, "bob");
    const c = await signUp(t, "carol");
    const r1 = await newRoom(t, a, "one");
    const r2 = await newRoom(t, a, "two");
    await t.mutation(api.rooms.join, { ...as(b), roomId: r1 });
    // Back to the pre-deploy state: no counter rows at all.
    await t.run(async (ctx: any) => {
      for (const r of await ctx.db.query("userRoomCounts").collect())
        await ctx.db.delete(r._id);
    });
    return { a, b, c, r1, r2 };
  }

  test("counts every user (zero included), pages, and is idempotent", async () => {
    const t = convexTest(schema);
    const { a, b, c } = await uncountedWorld(t);
    const first = await t.mutation(internal.roomCounts.backfill, {});
    expect(first.counted).toBe(3);
    await vi.advanceTimersByTimeAsync(0);
    expect(await countOf(t, a)).toBe(2);
    expect(await countOf(t, b)).toBe(1);
    expect(await countOf(t, c)).toBe(0);

    const again = await t.mutation(internal.roomCounts.backfill, {});
    expect(again.counted).toBe(0);
    expect(await countOf(t, a)).toBe(2);
    const all = await t.run(async (ctx: any) => ctx.db.query("userRoomCounts").collect());
    expect(all).toHaveLength(3);
  });

  test("walks more users than one page by rescheduling itself", async () => {
    const t = convexTest(schema);
    const seed = await signUp(t, "seed");
    await t.run(async (ctx: any) => {
      const { _id, _creationTime, ...fields } = (await ctx.db.get(seed.userId)) as any;
      for (let i = 0; i < 39; i++)
        await ctx.db.insert("users", { ...fields, username: `u${i}` });
      for (const r of await ctx.db.query("userRoomCounts").collect())
        await ctx.db.delete(r._id);
    });
    const first = await t.mutation(internal.roomCounts.backfill, {});
    expect(first.done).toBe(false);
    for (let i = 0; i < 10; i++) await vi.advanceTimersByTimeAsync(0);
    await t.finishAllScheduledFunctions(() => vi.advanceTimersByTime(0));
    const all = await t.run(async (ctx: any) => ctx.db.query("userRoomCounts").collect());
    expect(all).toHaveLength(40);
  });

  test("never overwrites a user who joined something since the deploy", async () => {
    const t = convexTest(schema);
    const { a, b, r2 } = await uncountedWorld(t);
    await t.mutation(api.rooms.join, { ...as(b), roomId: r2 });
    expect(await countOf(t, b)).toBe(2); // fallback counted 1, +1
    await t.mutation(internal.roomCounts.backfill, {});
    expect(await countOf(t, b)).toBe(2);
    expect(await countOf(t, a)).toBe(2);
  });
});
