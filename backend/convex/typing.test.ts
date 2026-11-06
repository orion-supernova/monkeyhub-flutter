import { convexTest } from "convex-test";
import { afterEach, beforeEach, describe, expect, test, vi } from "vitest";
import { api } from "./_generated/api";
import schema from "./schema";

const NOW = 1_800_000_000_000;

async function signUp(t: ReturnType<typeof convexTest>, username: string) {
  return (await t.mutation(api.auth.signup, {
    username,
    name: username,
    passwordHash: `hash-${username}`,
    recoveryKeyHash: `recovery-${username}`,
    deviceId: `device-${username}`,
  })) as { token: string; userId: string };
}

async function room(t: ReturnType<typeof convexTest>, owner: string, members: string[]) {
  return await t.run(async (ctx) => {
    const roomId = await ctx.db.insert("rooms", {
      name: "g",
      type: "group",
      createdBy: owner as any,
      createdAt: NOW,
      isPrivate: true,
      memberCount: members.length,
    } as any);
    for (const u of members) {
      await ctx.db.insert("roomMembers", {
        roomId,
        userId: u as any,
        joinedAt: NOW,
        role: "member",
      } as any);
      // The whole-session typing read goes through the access rows.
      await ctx.db.insert("roomAccess", { roomId, userId: u as any });
    }
    return roomId;
  });
}

const row = (t: ReturnType<typeof convexTest>, roomId: any, userId: string, updatedAt: number) =>
  t.run((ctx) =>
    ctx.db.insert("typingIndicators", { roomId, userId: userId as any, updatedAt } as any),
  );

describe("typing reads only live rows", () => {
  beforeEach(() => vi.useFakeTimers({ now: NOW }));
  afterEach(() => vi.useRealTimers());

  test("expired and cleared rows are not returned; live ones are", async () => {
    const t = convexTest(schema);
    const me = await signUp(t, "murat");
    const a = await signUp(t, "ayse");
    const b = await signUp(t, "bora");
    const c = await signUp(t, "cem");
    const roomId = await room(t, me.userId, [me.userId, a.userId, b.userId, c.userId]);
    await row(t, roomId, a.userId, NOW - 1000); // live
    await row(t, roomId, b.userId, NOW - 60_000); // long expired
    await row(t, roomId, c.userId, 0); // cleared
    const typists = await t.query(api.typing.getTypingUsers, {
      sessionToken: me.token,
      roomId,
      currentUserId: me.userId,
    } as any);
    expect(typists).toHaveLength(1);
    expect(typists[0]._id).toBe(a.userId);
  });

  test("roomIds: only listed rooms the viewer belongs to", async () => {
    const t = convexTest(schema);
    const me = await signUp(t, "murat");
    const a = await signUp(t, "ayse");
    const mine = await room(t, me.userId, [me.userId, a.userId]);
    const other = await room(t, me.userId, [me.userId, a.userId]);
    const foreign = await room(t, a.userId, [a.userId]);
    for (const r of [mine, other, foreign]) await row(t, r, a.userId, NOW - 1000);

    const got = (await t.query(api.typing.getTypingForUser, {
      sessionToken: me.token,
      userId: me.userId,
      roomIds: [mine, foreign],
    } as any)) as Record<string, string[]>;
    expect(Object.keys(got)).toEqual([mine.toString()]);

    // Old builds: no roomIds, every room.
    const all = (await t.query(api.typing.getTypingForUser, {
      sessionToken: me.token,
      userId: me.userId,
    } as any)) as Record<string, string[]>;
    expect(Object.keys(all).sort()).toEqual([mine.toString(), other.toString()].sort());
  });
});
