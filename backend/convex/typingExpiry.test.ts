import { convexTest } from "convex-test";
import { afterEach, beforeEach, describe, expect, test, vi } from "vitest";
import { api } from "./_generated/api";
import schema from "./schema";

/**
 * A typing indicator says when it stops being true.
 *
 * Both typing queries compare against `Date.now()`, and Convex caches a
 * query's answer until the TABLE changes, not until time passes. So a typist
 * whose phone died mid-word stayed "typing" in every subscription, and a room
 * opened minutes later flashed it from the cache. The fix hands the client the
 * deadline; these pin that it is there, in both shapes.
 */

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

async function sharedRoom(t: ReturnType<typeof convexTest>, a: string, b: string) {
  return await t.run(async (ctx) => {
    const roomId = await ctx.db.insert("rooms", {
      name: "group",
      type: "group",
      createdBy: a as any,
      createdAt: NOW,
      isPrivate: true,
      memberCount: 2,
    } as any);
    for (const u of [a, b]) {
      await ctx.db.insert("roomMembers", {
        roomId,
        userId: u as any,
        joinedAt: NOW,
        role: "member",
      } as any);
      await ctx.db.insert("roomAccess", { roomId, userId: u as any });
    }
    await ctx.db.insert("typingIndicators", {
      roomId,
      userId: b as any,
      updatedAt: NOW - 2000,
    } as any);
    return roomId;
  });
}

describe("typing indicators carry their deadline", () => {
  beforeEach(() => vi.useFakeTimers({ now: NOW }));
  afterEach(() => vi.useRealTimers());

  test("the open room's typists, each with typingUntil", async () => {
    const t = convexTest(schema);
    const me = await signUp(t, "murat");
    const them = await signUp(t, "zeynep");
    const roomId = await sharedRoom(t, me.userId, them.userId);
    const typists = await t.query(api.typing.getTypingUsers, {
      sessionToken: me.token,
      roomId,
      currentUserId: me.userId,
    } as any);
    expect(typists).toHaveLength(1);
    expect(typists[0].typingUntil).toBe(NOW - 2000 + 8000);
  });

  test("the room list answers rooms and deadlines", async () => {
    const t = convexTest(schema);
    const me = await signUp(t, "murat");
    const them = await signUp(t, "zeynep");
    const roomId = await sharedRoom(t, me.userId, them.userId);

    const rich = await t.query(api.typing.getTypingForUser, {
      sessionToken: me.token,
      userId: me.userId,
      roomIds: [roomId],
    } as any);
    expect(rich).toEqual({
      rooms: { [roomId]: ["zeynep"] },
      until: { [roomId]: NOW - 2000 + 8000 },
    });
  });
});
