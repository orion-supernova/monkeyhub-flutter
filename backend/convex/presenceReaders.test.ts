// The readers that used to take status / lastSeen off the `users` row now take
// them from `presence`, with the same visibility rules and the same output
// shape: `status` when the level allows it ("offline" with no row), `lastSeen`
// only when the level allows it AND one is set.
import { convexTest } from "convex-test";
import { describe, expect, test } from "vitest";
import { api } from "./_generated/api";
import schema from "./schema";

type T = ReturnType<typeof convexTest>;

async function signUp(t: T, username: string) {
  return await t.mutation(api.auth.signup, {
    username,
    name: username,
    passwordHash: `hash-${username}`,
    recoveryKeyHash: `recovery-${username}`,
    deviceId: `device-${username}`,
  });
}

async function setPresence(t: T, userId: string, patch: Record<string, unknown>) {
  await t.run(async (ctx: any) => {
    const row = await ctx.db
      .query("presence")
      .withIndex("by_user", (q: any) => q.eq("userId", userId))
      .first();
    await ctx.db.patch(row._id, patch);
  });
}

const profile = (t: T, viewer: { token: string }, userId: string) =>
  t.query(api.users.getProfile, { sessionToken: viewer.token, userId: userId as any } as any);

describe("getProfile reads presence", () => {
  test("a visible status and lastSeen come from the presence row, not users", async () => {
    const t = convexTest(schema);
    const me = await signUp(t, "me");
    const them = await signUp(t, "them");
    await t.run((ctx) =>
      ctx.db.patch(them.userId as any, { visibility: { status: "public", lastSeen: "public" } }),
    );
    await setPresence(t, them.userId, { status: "away", lastSeen: 12345 });
    const p: any = await profile(t, me, them.userId);
    expect(p.status).toBe("away");
    expect(p.lastSeen).toBe(12345);
    // And the users row carries neither field any more.
    const row: any = await t.run((ctx) => ctx.db.get(them.userId as any));
    expect(row.status).toBeUndefined();
    expect(row.lastSeen).toBeUndefined();
  });

  test("online has no lastSeen; a hidden level hides both", async () => {
    const t = convexTest(schema);
    const me = await signUp(t, "me");
    const them = await signUp(t, "them");
    await t.run((ctx) =>
      ctx.db.patch(them.userId as any, { visibility: { status: "public", lastSeen: "public" } }),
    );
    const online: any = await profile(t, me, them.userId);
    expect(online.status).toBe("online");
    expect(online.lastSeen).toBeUndefined();

    await t.run((ctx) =>
      ctx.db.patch(them.userId as any, { visibility: { status: "nobody", lastSeen: "nobody" } }),
    );
    const hidden: any = await profile(t, me, them.userId);
    expect(hidden.status).toBeUndefined();
    expect(hidden.lastSeen).toBeUndefined();
    expect(hidden.isRedacted).toBe(true);
  });

  test("no presence row reads offline when the level allows it", async () => {
    const t = convexTest(schema);
    const me = await signUp(t, "me");
    const them = await signUp(t, "them");
    await t.run(async (ctx: any) => {
      await ctx.db.patch(them.userId, { visibility: { status: "public", lastSeen: "public" } });
      const row = await ctx.db
        .query("presence")
        .withIndex("by_user", (q: any) => q.eq("userId", them.userId))
        .first();
      await ctx.db.delete(row._id);
    });
    const p: any = await profile(t, me, them.userId);
    expect(p.status).toBe("offline");
    expect(p.lastSeen).toBeUndefined();
  });
});

describe("request lists keep the person shape", () => {
  test("listIncomingDirectRequests carries status from presence", async () => {
    const t = convexTest(schema);
    const me = await signUp(t, "me");
    const asker = await signUp(t, "asker");
    await t.run((ctx) =>
      ctx.db.patch(asker.userId as any, { visibility: { status: "public", lastSeen: "public" } }),
    );
    await setPresence(t, asker.userId, { status: "away", lastSeen: 777 });
    await t.mutation(api.friends.sendRequest, {
      sessionToken: asker.token,
      userId: asker.userId,
      friendUsername: "me",
    } as any);
    const list: any[] = await t.query(api.friends.listIncomingDirectRequests, {
      sessionToken: me.token,
      userId: me.userId,
    } as any);
    expect(list).toHaveLength(1);
    expect(list[0].user).toMatchObject({
      _id: asker.userId,
      username: "asker",
      name: "asker",
      status: "away",
      lastSeen: 777,
    });
    expect(Object.keys(list[0].user).sort()).toEqual(
      ["_id", "lastSeen", "name", "status", "username"].sort(),
    );
  });
});
