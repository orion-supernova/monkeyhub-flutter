import { convexTest } from "convex-test";
import { afterEach, beforeEach, describe, expect, test, vi } from "vitest";
import { api, internal } from "./_generated/api";
import schema from "./schema";
import { DEFAULT_LEVEL, GUARDIAN_BYPASS, type VisField } from "./visibility";
import { DEFAULT_POINT_LEVEL } from "./visibilityPoint";
import { FOR_USERS_CAP, SWEEP_PAGE } from "./presenceApi";
import { PRESENCE_OFFLINE_MS } from "./presence";

type T = ReturnType<typeof convexTest>;

const T0 = 1_800_000_000_000;

beforeEach(() => {
  vi.useFakeTimers();
  vi.setSystemTime(T0);
});
afterEach(() => {
  vi.useRealTimers();
});

async function signUp(t: T, username: string) {
  return await t.mutation(api.auth.signup, {
    username,
    name: username,
    passwordHash: `hash-${username}`,
    recoveryKeyHash: `recovery-${username}`,
    deviceId: `device-${username}`,
  });
}

const rowsOf = (t: T, userId: string) =>
  t.run(async (ctx: any) => ({
    presence: await ctx.db
      .query("presence")
      .withIndex("by_user", (q: any) => q.eq("userId", userId as any))
      .collect(),
    beats: await ctx.db
      .query("presenceBeats")
      .withIndex("by_user", (q: any) => q.eq("userId", userId as any))
      .collect(),
    user: (await ctx.db.get(userId as any)) as any,
  }));

const forUsers = (t: T, viewer: { token: string }, ids: string[]) =>
  t.query(api.presenceApi.forUsers, { sessionToken: viewer.token, ids: ids as any });

describe("the visibility copies agree with visibility.ts", () => {
  test("default levels and the guardian bypass", async () => {
    expect(DEFAULT_POINT_LEVEL).toEqual(DEFAULT_LEVEL);
    // The bypass set is private to visibilityPoint, so prove it by behaviour:
    // a guardian sees exactly the bypassed fields on a "nobody" child.
    const t = convexTest(schema);
    const guardian = await signUp(t, "gina");
    const child = await signUp(t, "cody");
    await t.run(async (ctx) => {
      await ctx.db.insert("guardianships", {
        guardianId: guardian.userId as any,
        childId: child.userId as any,
        role: "primary",
        createdAt: 1,
      });
    });
    const { canSeeAs } = await import("./visibilityPoint");
    for (const field of ["avatar", "status", "lastSeen", "seen"] as VisField[]) {
      const sees = await t.run((ctx) =>
        canSeeAs(ctx, guardian.userId, child.userId, "nobody", field),
      );
      expect(sees).toBe(GUARDIAN_BYPASS.has(field));
    }
  });
});

describe("forUsers", () => {
  test("cap: 100 pass, 101 throw TOO_MANY_IDS", async () => {
    const t = convexTest(schema);
    const me = await signUp(t, "me");
    const ids = await t.run(async (ctx) => {
      const out: string[] = [];
      for (let i = 0; i < FOR_USERS_CAP + 1; i++) {
        out.push(
          await ctx.db.insert("users", {
            username: `u${i}`,
            name: `u${i}`,
            passwordHash: "x",
            recoveryKeyHash: "x",
            createdAt: 1,
          } as any),
        );
      }
      return out;
    });
    expect(await forUsers(t, me, ids.slice(0, FOR_USERS_CAP))).toHaveLength(FOR_USERS_CAP);
    await expect(forUsers(t, me, ids)).rejects.toThrow("TOO_MANY_IDS");
  });

  test("the privacy matrix", async () => {
    const t = convexTest(schema);
    const me = await signUp(t, "me");
    const names = [
      "selfie", // = me
      "pub",
      "frnd",
      "nobd",
      "kid",
      "strg",
      "dflt",
      "ghost",
    ];
    const u: Record<string, string> = { selfie: me.userId };
    for (const n of names.slice(1, 7)) u[n] = (await signUp(t, n)).userId;
    // Make everyone away so lastSeen is set; set levels directly on presence.
    vi.setSystemTime(T0 + 1000);
    await t.run(async (ctx) => {
      const setLevels = async (id: string, level: string | undefined) => {
        const row = await ctx.db
          .query("presence")
          .withIndex("by_user", (q) => q.eq("userId", id as any))
          .first();
        await ctx.db.patch(row!._id, {
          status: "away",
          lastSeen: T0 + 500,
          statusLevel: level,
          lastSeenLevel: level,
        });
      };
      await setLevels(u.selfie, "nobody");
      await setLevels(u.pub, "public");
      await setLevels(u.frnd, "friends");
      await setLevels(u.nobd, "nobody");
      await setLevels(u.kid, "nobody");
      await setLevels(u.strg, "friends");
      await setLevels(u.dflt, undefined);
      // friends: me <-> frnd (one direction row is enough), dflt as well
      for (const id of [u.frnd, u.dflt]) {
        await ctx.db.insert("friendships", {
          userId: id as any,
          friendId: me.userId as any,
          status: "accepted",
          createdAt: 1,
        });
      }
      // a pending request is not a friend
      await ctx.db.insert("friendships", {
        userId: me.userId as any,
        friendId: u.nobd as any,
        status: "pending",
        createdAt: 1,
      });
      await ctx.db.insert("guardianships", {
        guardianId: me.userId as any,
        childId: u.kid as any,
        role: "primary",
        createdAt: 1,
      });
    });
    // a user with no presence row at all
    const missing = await t.run((ctx) =>
      ctx.db.insert("users", {
        username: "nopresence",
        name: "n",
        passwordHash: "x",
        recoveryKeyHash: "x",
        createdAt: 1,
      } as any),
    );

    const res = await forUsers(t, me, [...Object.values(u), missing]);
    const by = Object.fromEntries(res.map((r: any) => [r.id, r]));
    const shown = { s: "away", ls: T0 + 500 };
    expect(by[u.selfie]).toEqual({ id: u.selfie, ...shown }); // self always
    expect(by[u.pub]).toEqual({ id: u.pub, ...shown });
    expect(by[u.frnd]).toEqual({ id: u.frnd, ...shown });
    expect(by[u.nobd]).toEqual({ id: u.nobd }); // pending is not accepted
    expect(by[u.kid]).toEqual({ id: u.kid, ...shown }); // guardian bypass
    expect(by[u.strg]).toEqual({ id: u.strg }); // friends-only, not a friend
    expect(by[u.dflt]).toEqual({ id: u.dflt, ...shown }); // default is friends
    expect(by[missing]).toEqual({ id: missing });
  });

  test("s without ls while online; ls only when set", async () => {
    const t = convexTest(schema);
    const me = await signUp(t, "me");
    const other = await signUp(t, "other");
    await t.run(async (ctx) => {
      const row = await ctx.db
        .query("presence")
        .withIndex("by_user", (q) => q.eq("userId", other.userId as any))
        .first();
      await ctx.db.patch(row!._id, { statusLevel: "public", lastSeenLevel: "public" });
    });
    expect(await forUsers(t, me, [other.userId])).toEqual([
      { id: other.userId, s: "online" },
    ]);
  });

  test("never reads users", async () => {
    const t = convexTest(schema);
    const me = await signUp(t, "me");
    const other = await signUp(t, "other");
    // Corrupt the users row: if forUsers read it the answer would change.
    await t.run(async (ctx) => {
      await ctx.db.patch(other.userId as any, {
        visibility: { status: "nobody", lastSeen: "nobody" },
      });
      const row = await ctx.db
        .query("presence")
        .withIndex("by_user", (q) => q.eq("userId", other.userId as any))
        .first();
      await ctx.db.patch(row!._id, { statusLevel: "public" });
    });
    expect(await forUsers(t, me, [other.userId])).toEqual([
      { id: other.userId, s: "online" },
    ]);
  });
});

describe("beat", () => {
  test("a fresh beat performs zero writes", async () => {
    const t = convexTest(schema);
    const me = await signUp(t, "me");
    const before = await rowsOf(t, me.userId);
    vi.setSystemTime(T0 + 30_000);
    await t.mutation(api.presenceApi.beat, { sessionToken: me.token, status: "online" });
    const after = await rowsOf(t, me.userId);
    expect(after.beats).toEqual(before.beats);
    expect(after.presence).toEqual(before.presence);
    expect(after.user).toEqual(before.user);
  });

  test("a stale beat only stamps presenceBeats", async () => {
    const t = convexTest(schema);
    const me = await signUp(t, "me");
    vi.setSystemTime(T0 + 100_000);
    await t.mutation(api.presenceApi.beat, { sessionToken: me.token, status: "online" });
    const s = await rowsOf(t, me.userId);
    expect(s.beats[0]).toMatchObject({ beatAt: T0 + 100_000, live: true });
    expect(s.presence[0].status).toBe("online");
  });

  test("resurrects a swept user as the beat's status", async () => {
    const t = convexTest(schema);
    const me = await signUp(t, "me");
    vi.setSystemTime(T0 + PRESENCE_OFFLINE_MS + 60_000);
    await t.mutation(internal.presenceApi.sweepStale, {});
    expect((await rowsOf(t, me.userId)).presence[0].status).toBe("offline");
    await t.mutation(api.presenceApi.beat, { sessionToken: me.token, status: "away" });
    const s = await rowsOf(t, me.userId);
    expect(s.presence[0].status).toBe("away");
    expect(s.beats[0].live).toBe(true);
  });
});

describe("setStatus", () => {
  test("transitions land in presence; lastSeen set on leaving", async () => {
    const t = convexTest(schema);
    const me = await signUp(t, "me");
    vi.setSystemTime(T0 + 5_000);
    await t.mutation(api.presenceApi.setStatus, { sessionToken: me.token, status: "away" });
    const s = await rowsOf(t, me.userId);
    expect(s.presence[0]).toMatchObject({ status: "away", lastSeen: T0 + 5_000 });
    // new endpoint mirrors to users for old viewers
    expect(s.user).toMatchObject({ status: "away", lastSeen: T0 + 5_000 });
  });

  test("a repeat writes nothing and is not charged to the limit", async () => {
    const t = convexTest(schema);
    const me = await signUp(t, "me");
    const before = await rowsOf(t, me.userId);
    for (let i = 0; i < 50; i++) {
      await t.mutation(api.presenceApi.setStatus, { sessionToken: me.token, status: "online" });
    }
    const after = await rowsOf(t, me.userId);
    expect(after.presence).toEqual(before.presence);
    const buckets = await t.run((ctx) => ctx.db.query("rateBuckets").collect());
    expect(buckets.filter((b: any) => b.key.startsWith("presence:"))).toEqual([]);
  });

  test("flip-flopping is rate limited to 20 changes per minute, then dropped", async () => {
    const t = convexTest(schema);
    const me = await signUp(t, "me");
    for (let i = 0; i < 30; i++) {
      await t.mutation(api.presenceApi.setStatus, {
        sessionToken: me.token,
        status: i % 2 === 0 ? "away" : "online",
      });
    }
    // 20 flips applied (i = 0..19, ending on "online"), the rest dropped.
    expect((await rowsOf(t, me.userId)).presence[0].status).toBe("online");
    vi.setSystemTime(T0 + 61_000);
    await t.mutation(api.presenceApi.setStatus, { sessionToken: me.token, status: "away" });
    expect((await rowsOf(t, me.userId)).presence[0].status).toBe("away");
  });
});

describe("old and new endpoints both land in presence", () => {
  test("users.updateStatus and users.heartbeat", async () => {
    const t = convexTest(schema);
    const me = await signUp(t, "me");
    vi.setSystemTime(T0 + 5_000);
    await t.mutation(api.users.updateStatus, {
      sessionToken: me.token,
      userId: me.userId,
      status: "away",
    } as any);
    let s = await rowsOf(t, me.userId);
    expect(s.presence[0]).toMatchObject({ status: "away", lastSeen: T0 + 5_000 });
    expect(s.user).toMatchObject({ status: "away", lastSeen: T0 + 5_000 });

    await t.mutation(api.users.updateStatus, {
      sessionToken: me.token,
      userId: me.userId,
      status: "online",
    } as any);
    vi.setSystemTime(T0 + 200_000);
    await t.mutation(api.users.heartbeat, {
      sessionToken: me.token,
      userId: me.userId,
    } as any);
    s = await rowsOf(t, me.userId);
    expect(s.presence[0].status).toBe("online");
    expect(s.beats[0]).toMatchObject({ beatAt: T0 + 200_000, live: true });
  });

  test("a stray heartbeat does not resurrect an offline user", async () => {
    const t = convexTest(schema);
    const me = await signUp(t, "me");
    await t.run(async (ctx) => {
      const p = await ctx.db
        .query("presence")
        .withIndex("by_user", (q) => q.eq("userId", me.userId as any))
        .first();
      await ctx.db.patch(p!._id, { status: "offline", lastSeen: T0 });
    });
    vi.setSystemTime(T0 + 200_000);
    await t.mutation(api.users.heartbeat, {
      sessionToken: me.token,
      userId: me.userId,
    } as any);
    expect((await rowsOf(t, me.userId)).presence[0].status).toBe("offline");
  });

  test("updateVisibility copies the levels onto presence", async () => {
    const t = convexTest(schema);
    const me = await signUp(t, "me");
    await t.mutation(api.users.updateVisibility, {
      sessionToken: me.token,
      userId: me.userId,
      status: "nobody",
      lastSeen: "public",
    } as any);
    expect((await rowsOf(t, me.userId)).presence[0]).toMatchObject({
      statusLevel: "nobody",
      lastSeenLevel: "public",
    });
  });

  test("sign-up and login mark online", async () => {
    const t = convexTest(schema);
    const me = await signUp(t, "me");
    expect((await rowsOf(t, me.userId)).presence[0].status).toBe("online");
    await t.mutation(api.auth.logout, { sessionToken: me.token, deviceId: "device-me" });
    await t.mutation(api.auth.login as any, {
      username: "me",
      passwordHash: "hash-me",
      deviceId: "device-me2",
    });
    expect((await rowsOf(t, me.userId)).presence[0].status).toBe("online");
  });
});

describe("sweepStale", () => {
  async function seed(t: T, n: number, beatAt: number, live = true) {
    return await t.run(async (ctx) => {
      const out: string[] = [];
      for (let i = 0; i < n; i++) {
        const id = await ctx.db.insert("users", {
          username: `s${beatAt}${live}${i}`,
          name: "s",
          passwordHash: "x",
          recoveryKeyHash: "x",
          createdAt: 1,
          status: "online",
        } as any);
        await ctx.db.insert("presence", { userId: id, status: "online" });
        await ctx.db.insert("presenceBeats", { userId: id, beatAt, live });
        out.push(id);
      }
      return out;
    });
  }

  test("demotes only stale live beats; lastSeen = the last beat", async () => {
    const t = convexTest(schema);
    const stale = (await seed(t, 1, T0 - PRESENCE_OFFLINE_MS - 5_000))[0];
    const fresh = (await seed(t, 1, T0 - 10_000))[0];
    const dead = (await seed(t, 1, T0 - PRESENCE_OFFLINE_MS - 5_000, false))[0];
    await t.mutation(internal.presenceApi.sweepStale, {});
    const s = await rowsOf(t, stale);
    expect(s.presence[0]).toMatchObject({
      status: "offline",
      lastSeen: T0 - PRESENCE_OFFLINE_MS - 5_000,
    });
    expect(s.beats[0].live).toBe(false);
    expect(s.user).toMatchObject({ status: "offline" }); // mirrored for old viewers
    const f = await rowsOf(t, fresh);
    expect(f.presence[0].status).toBe("online");
    expect(f.beats[0].live).toBe(true);
    // a non-live beat is never touched
    expect((await rowsOf(t, dead)).presence[0].status).toBe("online");
  });

  test("pages: a full page chains the next run", async () => {
    const t = convexTest(schema);
    const ids = await seed(t, SWEEP_PAGE + 50, T0 - PRESENCE_OFFLINE_MS - 1_000);
    await t.mutation(internal.presenceApi.sweepStale, {});
    const live = () =>
      t.run(async (ctx) =>
        (
          await ctx.db
            .query("presenceBeats")
            .withIndex("by_live_beat", (q) => q.eq("live", true))
            .collect()
        ).length,
      );
    expect(await live()).toBe(50);
    await t.finishAllScheduledFunctions(vi.runAllTimers);
    expect(await live()).toBe(0);
    expect(ids).toHaveLength(SWEEP_PAGE + 50);
  });
});

describe("compat window for old-path readers", () => {
  test("a 30 s beater never reads offline over 20 minutes", async () => {
    const { effectiveStatus } = await import("./presence");
    const { COMPAT_OFFLINE_MS } = await import("./presenceCore");
    const t = convexTest(schema);
    const me = await signUp(t, "me");
    for (let s = 30; s <= 20 * 60; s += 30) {
      vi.setSystemTime(T0 + s * 1000);
      await t.mutation(api.presenceApi.beat, { sessionToken: me.token, status: "online" });
      if (s % 60 === 0) {
        await t.mutation(internal.presenceApi.sweepStale, {});
        await t.mutation(internal.users.sweepStalePresence, {});
      }
      const u = (await rowsOf(t, me.userId)).user;
      expect(effectiveStatus(u.status, u.lastSeen, Date.now(), COMPAT_OFFLINE_MS)).toBe("online");
    }
  });

  test("mirrorLive restores a users.status the old sweep flipped", async () => {
    const t = convexTest(schema);
    const me = await signUp(t, "me");
    await t.run((ctx) => ctx.db.patch(me.userId as any, { status: "offline" }));
    vi.setSystemTime(T0 + 100_000);
    await t.mutation(api.presenceApi.beat, { sessionToken: me.token, status: "online" });
    expect((await rowsOf(t, me.userId)).user).toMatchObject({
      status: "online",
      lastSeen: T0 + 100_000,
    });
  });
});

describe("ghost presence", () => {
  test.each([["deletingAt"], ["suspendedAt"]])("%s users get no presence", async (field) => {
    const { setStatus, noteBeat } = await import("./presenceCore");
    const t = convexTest(schema);
    const me = await signUp(t, "me");
    await t.run((ctx) => ctx.db.patch(me.userId as any, { [field]: T0 } as any));
    const before = await rowsOf(t, me.userId);
    vi.setSystemTime(T0 + 200_000);
    await t.run((ctx) => setStatus(ctx, me.userId, "away", { now: Date.now() }));
    await t.run((ctx) => noteBeat(ctx, me.userId, { now: Date.now(), resurrect: "online" }));
    const after = await rowsOf(t, me.userId);
    expect(after.presence).toEqual(before.presence);
    expect(after.beats).toEqual(before.beats);
    // going offline stays possible
    await t.run((ctx) => setStatus(ctx, me.userId, "offline", { now: Date.now() }));
    expect((await rowsOf(t, me.userId)).presence[0].status).toBe("offline");
  });
});

describe("a late beat after an explicit offline", () => {
  test("within 60 s it does not resurrect", async () => {
    const t = convexTest(schema);
    const me = await signUp(t, "me");
    vi.setSystemTime(T0 + 10_000);
    await t.mutation(api.presenceApi.setStatus, { sessionToken: me.token, status: "offline" });
    vi.setSystemTime(T0 + 40_000);
    await t.mutation(api.presenceApi.beat, { sessionToken: me.token, status: "online" });
    const s = await rowsOf(t, me.userId);
    expect(s.presence[0].status).toBe("offline");
    expect(s.beats[0].live).toBe(false);
  });

  test("a sweep-demoted user still resurrects after a gap", async () => {
    const t = convexTest(schema);
    const me = await signUp(t, "me");
    vi.setSystemTime(T0 + PRESENCE_OFFLINE_MS + 60_000);
    await t.mutation(internal.presenceApi.sweepStale, {});
    // beat arrives right after the sweep: lastSeen (= old beatAt) is old
    await t.mutation(api.presenceApi.beat, { sessionToken: me.token, status: "online" });
    expect((await rowsOf(t, me.userId)).presence[0].status).toBe("online");
  });

  test("after 60 s an explicit offline can be undone by a beat", async () => {
    const t = convexTest(schema);
    const me = await signUp(t, "me");
    await t.mutation(api.presenceApi.setStatus, { sessionToken: me.token, status: "offline" });
    vi.setSystemTime(T0 + 61_000);
    await t.mutation(api.presenceApi.beat, { sessionToken: me.token, status: "online" });
    expect((await rowsOf(t, me.userId)).presence[0].status).toBe("online");
  });
});
