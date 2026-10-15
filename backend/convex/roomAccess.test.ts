import { convexTest } from "convex-test";
import { describe, expect, test } from "vitest";
import { api, internal } from "./_generated/api";
import schema from "./schema";

/**
 * A room's contents are for its members.
 *
 * Every read below used to answer anyone holding the room id, and room ids
 * travel: Discover lists them, forwards carry them, a kicked member keeps the
 * one they had. These pin that a stranger and an ex-member get nothing back.
 */

async function signUp(t: ReturnType<typeof convexTest>, username: string) {
  return await t.mutation(api.auth.signup, {
    username,
    name: username,
    passwordHash: `hash-${username}`,
    recoveryKeyHash: `recovery-${username}`,
    deviceId: `device-${username}`,
  });
}

async function setup() {
  const t = convexTest(schema);
  const owner = await signUp(t, "owner");
  const stranger = await signUp(t, "stranger");
  const roomId = await t.mutation(api.rooms.create, {
    sessionToken: owner.token,
    userId: owner.userId as any,
    name: "locked",
    isPrivate: false,
    passwordHash: "room-secret",
  });
  await t.mutation(api.messages.send, {
    sessionToken: owner.token,
    userId: owner.userId as any,
    roomId,
    content: "members only",
  });
  return { t, owner, stranger, roomId };
}

describe("room reads are members-only", () => {
  test("a member reads; a stranger with the id reads nothing", async () => {
    const { t, owner, stranger, roomId } = await setup();

    const mine = await t.query(api.messages.list, {
      sessionToken: owner.token,
      roomId,
    });
    expect(mine.map((m: any) => m.content)).toEqual(["members only"]);

    const asStranger = { sessionToken: stranger.token, roomId };
    expect(await t.query(api.messages.list, asStranger)).toEqual([]);
    expect(
      await t.query(api.messages.listBefore, {
        ...asStranger,
        beforeTimestamp: Date.now() + 1000,
      }),
    ).toEqual([]);
    expect(await t.query(api.rooms.getRoom, asStranger)).toBeNull();
    expect(await t.query(api.rooms.getMembers, asStranger)).toEqual([]);
    expect(await t.query(api.pins.listForRoom, asStranger)).toEqual([]);
    expect(
      await t.query(api.messages.getReadState, {
        ...asStranger,
        viewerUserId: stranger.userId as any,
      }),
    ).toEqual([]);
  });

  test("leaving takes the access with it", async () => {
    const { t, owner, stranger, roomId } = await setup();
    await t.mutation(api.rooms.join, {
      sessionToken: stranger.token,
      userId: stranger.userId as any,
      roomId,
      passwordHash: "room-secret",
    });
    const asJoiner = { sessionToken: stranger.token, roomId };
    expect(await t.query(api.messages.list, asJoiner)).toHaveLength(1);

    await t.mutation(api.rooms.leave, {
      sessionToken: stranger.token,
      userId: stranger.userId as any,
      roomId,
    });
    expect(await t.query(api.messages.list, asJoiner)).toEqual([]);
    // The owner, still in, is unaffected.
    expect(
      await t.query(api.messages.list, { sessionToken: owner.token, roomId }),
    ).toHaveLength(1);
  });

  test("a member from before the access table still reads, and backfill seeds them", async () => {
    const { t, owner, roomId } = await setup();
    // Simulate a membership written before `roomAccess` existed.
    await t.run(async (ctx) => {
      for (const row of await ctx.db.query("roomAccess").collect()) {
        await ctx.db.delete(row._id);
      }
    });
    expect(
      await t.query(api.messages.list, { sessionToken: owner.token, roomId }),
    ).toHaveLength(1);

    await t.mutation(internal.roomAccess.backfill, {});
    const rows = await t.run((ctx) => ctx.db.query("roomAccess").collect());
    expect(rows).toHaveLength(1);
  });
});
