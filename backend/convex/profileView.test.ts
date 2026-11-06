import { convexTest } from "convex-test";
import { afterEach, beforeEach, describe, expect, test, vi } from "vitest";
import { api } from "./_generated/api";
import schema from "./schema";

// B6: friends:listFriends, rooms:getMembers, family:getFamilyContext and
// feed:board read `profiles` / `presence`, not `users`. Each test writes
// DIFFERENT (poisoned) values to the users row without going through
// syncProfile or the presence writers; a result that did not change proves the
// query no longer reads that row (so a users write cannot re-run it).

type T = ReturnType<typeof convexTest>;
const T0 = 1_800_000_000_000;
beforeEach(() => {
  vi.useFakeTimers();
  vi.setSystemTime(T0);
});
afterEach(() => vi.useRealTimers());

async function signUp(t: T, username: string) {
  return await t.mutation(api.auth.signup, {
    username,
    name: username,
    passwordHash: `hash-${username}`,
    recoveryKeyHash: `recovery-${username}`,
    deviceId: `device-${username}`,
  });
}

const befriend = (t: T, a: string, b: string) =>
  t.run(async (ctx: any) => {
    for (const [x, y] of [[a, b], [b, a]]) {
      await ctx.db.insert("friendships", {
        userId: x,
        friendId: y,
        status: "accepted",
        createdAt: T0,
      });
    }
  });

const setPresence = (t: T, userId: string, row: Record<string, unknown>) =>
  t.run(async (ctx: any) => {
    const cur = await ctx.db
      .query("presence")
      .withIndex("by_user", (q: any) => q.eq("userId", userId))
      .first();
    if (cur) await ctx.db.replace(cur._id, { userId, ...row });
    else await ctx.db.insert("presence", { userId, ...row });
  });

/** A users write that no profile / presence writer made. */
const poison = (t: T, userId: string) =>
  t.run(async (ctx: any) => {
    await ctx.db.patch(userId, {
      name: "POISONED",
      status: "online",
      lastSeen: T0 + 5,
      email: "x@example.com",
    });
  });

describe("listFriends", () => {
  test("shape comes from profiles + presence and ignores users-row writes", async () => {
    const t = convexTest(schema);
    const me = await signUp(t, "meee");
    const pal = await signUp(t, "pall");
    await befriend(t, me.userId, pal.userId);
    await setPresence(t, pal.userId, { status: "away", lastSeen: T0 - 1000 });

    const call = () =>
      t.query(api.friends.listFriends, { sessionToken: me.token, userId: me.userId });
    const before: any[] = await call();
    expect(before).toEqual([
      {
        _id: pal.userId,
        username: "pall",
        name: "pall",
        status: "away",
        lastSeen: T0 - 1000,
      },
    ]);
    await poison(t, pal.userId);
    expect(await call()).toEqual(before);
  });

  test("status and lastSeen follow the presence levels; a deleted friend drops out", async () => {
    const t = convexTest(schema);
    const me = await signUp(t, "meee");
    const pal = await signUp(t, "pall");
    const gone = await signUp(t, "gone");
    await befriend(t, me.userId, pal.userId);
    await befriend(t, me.userId, gone.userId);
    await setPresence(t, pal.userId, {
      status: "online",
      statusLevel: "nobody",
      lastSeenLevel: "nobody",
    });
    await t.run(async (ctx: any) => {
      const p = await ctx.db
        .query("profiles")
        .withIndex("by_user", (q: any) => q.eq("userId", gone.userId))
        .first();
      await ctx.db.patch(p._id, { deleted: true, name: "", username: "" });
    });
    const out: any[] = await t.query(api.friends.listFriends, {
      sessionToken: me.token,
      userId: me.userId,
    });
    expect(out.map((f) => f.username)).toEqual(["pall"]);
    expect(out[0].status).toBeUndefined();
    expect(out[0].lastSeen).toBeUndefined();
  });
});

describe("getMembers", () => {
  test("same shape, from profiles + presence", async () => {
    const t = convexTest(schema);
    const me = await signUp(t, "meee");
    const pal = await signUp(t, "pall");
    await befriend(t, me.userId, pal.userId);
    await setPresence(t, pal.userId, { status: "online" });
    const roomId = await t.mutation(api.rooms.create, {
      sessionToken: me.token,
      userId: me.userId as any,
      name: "r",
      isPrivate: false,
    });
    await t.run(async (ctx: any) => {
      await ctx.db.insert("roomMembers", {
        roomId,
        userId: pal.userId,
        role: "member",
        joinedAt: T0,
      });
    });
    const call = () =>
      t.query(api.rooms.getMembers, {
        sessionToken: me.token,
        roomId,
        viewerUserId: me.userId,
      } as any);
    const before: any[] = await call();
    const p = before.find((m) => m.username === "pall");
    expect(p).toMatchObject({
      _id: pal.userId,
      name: "pall",
      status: "online",
      role: "member",
      joinedAt: T0,
    });
    expect(Object.keys(p).sort()).toEqual(
      ["_id", "joinedAt", "name", "role", "status", "username"].sort(),
    );
    await poison(t, pal.userId);
    await poison(t, me.userId);
    expect(await call()).toEqual(before);
  });
});

describe("getFamilyContext", () => {
  test("a child's status comes from presence", async () => {
    const t = convexTest(schema);
    const parent = await signUp(t, "parent");
    const kid = await signUp(t, "kiddo");
    await t.run(async (ctx: any) => {
      await ctx.db.patch(kid.userId, { accountType: "child" });
      await ctx.db.insert("guardianships", {
        guardianId: parent.userId,
        childId: kid.userId,
        role: "primary",
        createdAt: T0,
      });
    });
    await setPresence(t, kid.userId, { status: "away", lastSeen: T0 - 5 });
    await t.run((ctx: any) =>
      ctx.db.patch(kid.userId, { status: "online", lastSeen: T0 }),
    );
    const out: any = await t.query(api.family.getFamilyContext, {
      sessionToken: parent.token,
      userId: parent.userId,
    });
    expect(out.children).toHaveLength(1);
    expect(out.children[0]).toMatchObject({
      username: "kiddo",
      status: "away",
      lastSeen: T0 - 5,
    });
  });
});

describe("feed:board", () => {
  async function setup() {
    const t = convexTest(schema);
    const me = await signUp(t, "meee");
    const pal = await signUp(t, "pall");
    await befriend(t, me.userId, pal.userId);
    const momentId = await t.run(async (ctx: any) => {
      const id = await ctx.db.insert("moments", {
        userId: pal.userId,
        dayKey: "2026-11-06",
        createdAt: T0 - 1000,
        expiresAt: T0 + 3_600_000,
      });
      await ctx.db.insert("momentReactions", {
        momentId: id,
        userId: me.userId,
        emoji: "x",
        createdAt: T0,
      });
      return id;
    });
    const call = () =>
      t.query(api.feed.board, {
        sessionToken: me.token,
        userId: me.userId,
        dayKey: "2026-11-06",
      });
    return { t, me, pal, momentId, call };
  }

  test("a friend's moment renders from the profile and ignores users writes", async () => {
    const { t, pal, call } = await setup();
    const before: any = await call();
    expect(before.moments).toHaveLength(1);
    expect(before.moments[0]).toMatchObject({
      authorName: "pall",
      authorUsername: "pall",
      reactionCounts: [{ emoji: "x", count: 1 }],
    });
    await poison(t, pal.userId);
    expect(await call()).toEqual(before);
  });

  test("the feed levels live on the profile and are honoured", async () => {
    const { t, me, pal, call } = await setup();
    await t.mutation(api.users.updateVisibility, {
      sessionToken: pal.token,
      userId: pal.userId,
      feed: "nobody",
    } as any);
    const prof: any = await t.run((ctx: any) =>
      ctx.db
        .query("profiles")
        .withIndex("by_user", (q: any) => q.eq("userId", pal.userId))
        .first(),
    );
    expect(prof.feedLevels).toEqual({ feed: "nobody" });
    expect((await call() as any).moments).toHaveLength(0);
    void me;
  });

  test("an unsynced profile falls back to the users row", async () => {
    const { t, pal, call } = await setup();
    await t.run(async (ctx: any) => {
      const p = await ctx.db
        .query("profiles")
        .withIndex("by_user", (q: any) => q.eq("userId", pal.userId))
        .first();
      await ctx.db.patch(p._id, { feedLevels: undefined });
      await ctx.db.patch(pal.userId, { visibility: { feed: "nobody" } });
    });
    expect(((await call()) as any).moments).toHaveLength(0);
  });
});
