import { convexTest } from "convex-test";
import { afterEach, describe, expect, test } from "vitest";
import schema from "./schema";
import {
  BEAT_THROTTLE_MS,
  COMPAT_MIRROR_MS,
  clearPresence,
  demoteStale,
  markOffline,
  markOnline,
  noteBeat,
  setStatus,
  syncLevels,
} from "./presenceCore";

const T0 = 1_000_000_000_000;

async function setup(extra: Record<string, any> = {}) {
  const t = convexTest(schema);
  const userId = await t.run((ctx) =>
    ctx.db.insert("users", {
      username: "u",
      name: "u",
      passwordHash: "x",
      recoveryKeyHash: "x",
      createdAt: 1,
      ...extra,
    } as any),
  );
  const rows = () =>
    t.run(async (ctx) => ({
      presence: await ctx.db.query("presence").collect(),
      beat: await ctx.db.query("presenceBeats").collect(),
      user: (await ctx.db.get(userId)) as any,
    }));
  return { t, userId, rows };
}

afterEach(() => {
  delete process.env.PRESENCE_COMPAT_MIRROR;
});

describe("setStatus", () => {
  test("online: row without lastSeen, live beat, mirrored to users", async () => {
    const { t, userId, rows } = await setup();
    const r = await t.run((ctx) => setStatus(ctx, userId, "online", { now: T0 }));
    expect(r.changed).toBe(true);
    const s = await rows();
    expect(s.presence).toHaveLength(1);
    expect(s.presence[0].status).toBe("online");
    expect(s.presence[0].lastSeen).toBeUndefined();
    expect(s.beat[0]).toMatchObject({ beatAt: T0, live: true });
    expect(s.user).toMatchObject({ status: "online", lastSeen: T0 });
  });

  test("leaving the foreground sets lastSeen; coming back clears it", async () => {
    const { t, userId, rows } = await setup();
    await t.run((ctx) => setStatus(ctx, userId, "online", { now: T0 }));
    await t.run((ctx) => setStatus(ctx, userId, "away", { now: T0 + 1000 }));
    expect((await rows()).presence[0]).toMatchObject({ status: "away", lastSeen: T0 + 1000 });
    await t.run((ctx) => setStatus(ctx, userId, "online", { now: T0 + 2000 }));
    const s = await rows();
    expect(s.presence[0].status).toBe("online");
    expect("lastSeen" in s.presence[0]).toBe(false);
  });

  test("a repeat writes no presence row and a fresh beat is not rewritten", async () => {
    const { t, userId, rows } = await setup();
    await t.run((ctx) => setStatus(ctx, userId, "online", { now: T0 }));
    const before = await rows();
    const r = await t.run((ctx) => setStatus(ctx, userId, "online", { now: T0 + 10_000 }));
    expect(r.changed).toBe(false);
    const after = await rows();
    expect(after.presence[0]._creationTime).toBe(before.presence[0]._creationTime);
    expect(after.beat[0].beatAt).toBe(T0);
    // A stale beat is refreshed even on a repeat.
    await t.run((ctx) => setStatus(ctx, userId, "online", { now: T0 + BEAT_THROTTLE_MS }));
    expect((await rows()).beat[0].beatAt).toBe(T0 + BEAT_THROTTLE_MS);
  });

  test("offline retires the beat; levels are copied from users on insert", async () => {
    const { t, userId, rows } = await setup({ visibility: { status: "public", lastSeen: "nobody" } });
    await t.run((ctx) => markOnline(ctx, userId, { now: T0 }));
    await t.run((ctx) => markOffline(ctx, userId, { now: T0 + 5 }));
    const s = await rows();
    expect(s.presence[0]).toMatchObject({
      status: "offline",
      lastSeen: T0 + 5,
      statusLevel: "public",
      lastSeenLevel: "nobody",
    });
    expect(s.beat[0].live).toBe(false);
  });

  test("system accounts and missing users get no row", async () => {
    const { t, rows } = await setup();
    const sys = await t.run((ctx) =>
      ctx.db.insert("users", {
        username: "sys",
        passwordHash: "__SYSTEM_NO_LOGIN__x",
        createdAt: 1,
      } as any),
    );
    await t.run((ctx) => setStatus(ctx, sys, "online", { now: T0 }));
    expect((await rows()).presence).toHaveLength(0);
  });

  test("mirror: false and the env switch leave users alone", async () => {
    const a = await setup();
    await a.t.run((ctx) => setStatus(ctx, a.userId, "online", { now: T0, mirror: false }));
    expect((await a.rows()).user.status).toBeUndefined();
    process.env.PRESENCE_COMPAT_MIRROR = "off";
    const b = await setup();
    await b.t.run((ctx) => setStatus(ctx, b.userId, "online", { now: T0 }));
    expect((await b.rows()).user.status).toBeUndefined();
  });
});

describe("noteBeat", () => {
  test("a fresh beat on an online user is read-only", async () => {
    const { t, userId, rows } = await setup();
    await t.run((ctx) => markOnline(ctx, userId, { now: T0 }));
    const r = await t.run((ctx) => noteBeat(ctx, userId, { now: T0 + 30_000 }));
    expect(r.wrote).toBe(false);
    expect((await rows()).beat[0].beatAt).toBe(T0);
  });

  test("a stale beat writes the beat only, not presence", async () => {
    const { t, userId, rows } = await setup();
    await t.run((ctx) => markOnline(ctx, userId, { now: T0 }));
    const before = (await rows()).presence[0];
    const now = T0 + BEAT_THROTTLE_MS;
    const r = await t.run((ctx) => noteBeat(ctx, userId, { now }));
    expect(r.wrote).toBe(true);
    const s = await rows();
    expect(s.beat[0].beatAt).toBe(now);
    expect(s.presence[0]).toEqual(before);
    // users.lastSeen only refreshes every COMPAT_MIRROR_MS.
    expect(s.user.lastSeen).toBe(T0);
    await t.run((ctx) => noteBeat(ctx, userId, { now: T0 + COMPAT_MIRROR_MS }));
    expect((await rows()).user.lastSeen).toBe(T0 + COMPAT_MIRROR_MS);
  });

  test("an offline or absent user is not resurrected unless asked", async () => {
    const { t, userId, rows } = await setup();
    expect((await t.run((ctx) => noteBeat(ctx, userId, { now: T0 }))).wrote).toBe(false);
    await t.run((ctx) => markOnline(ctx, userId, { now: T0 }));
    await t.run((ctx) => markOffline(ctx, userId, { now: T0 + 1 }));
    await t.run((ctx) => noteBeat(ctx, userId, { now: T0 + 200_000 }));
    expect((await rows()).presence[0].status).toBe("offline");
    await t.run((ctx) => noteBeat(ctx, userId, { now: T0 + 300_000, resurrect: "away" }));
    const s = await rows();
    expect(s.presence[0]).toMatchObject({ status: "away", lastSeen: T0 + 300_000 });
    expect(s.beat[0]).toMatchObject({ live: true, beatAt: T0 + 300_000 });
  });

  test("resurrect creates the row for a user who has none", async () => {
    const { t, userId, rows } = await setup();
    await t.run((ctx) => noteBeat(ctx, userId, { now: T0, resurrect: "online" }));
    expect((await rows()).presence[0].status).toBe("online");
  });
});

describe("demoteStale / clearPresence / syncLevels", () => {
  test("demoteStale goes offline at the last beat and retires it", async () => {
    const { t, userId, rows } = await setup();
    await t.run((ctx) => markOnline(ctx, userId, { now: T0 }));
    const r = await t.run((ctx) => demoteStale(ctx, userId, T0, { now: T0 + 200_000 }));
    expect(r.changed).toBe(true);
    const s = await rows();
    expect(s.presence[0]).toMatchObject({ status: "offline", lastSeen: T0 });
    expect(s.beat[0].live).toBe(false);
    expect(s.user).toMatchObject({ status: "offline", lastSeen: T0 });
    expect((await t.run((ctx) => demoteStale(ctx, userId, T0, { now: T0 + 1 }))).changed).toBe(false);
  });

  test("clearPresence deletes both rows", async () => {
    const { t, userId, rows } = await setup();
    await t.run((ctx) => markOnline(ctx, userId, { now: T0 }));
    expect(await t.run((ctx) => clearPresence(ctx, userId))).toBe(2);
    const s = await rows();
    expect(s.presence).toHaveLength(0);
    expect(s.beat).toHaveLength(0);
  });

  test("syncLevels patches only on a real difference", async () => {
    const { t, userId, rows } = await setup();
    expect((await t.run((ctx) => syncLevels(ctx, userId, { status: "nobody" }))).changed).toBe(false);
    await t.run((ctx) => markOnline(ctx, userId, { now: T0 }));
    expect((await t.run((ctx) => syncLevels(ctx, userId, undefined))).changed).toBe(false);
    expect((await t.run((ctx) => syncLevels(ctx, userId, { status: "nobody", lastSeen: "public" }))).changed).toBe(true);
    expect((await rows()).presence[0]).toMatchObject({ statusLevel: "nobody", lastSeenLevel: "public" });
    expect((await t.run((ctx) => syncLevels(ctx, userId, { status: "nobody", lastSeen: "public" }))).changed).toBe(false);
    await t.run((ctx) => syncLevels(ctx, userId, {}));
    expect((await rows()).presence[0].statusLevel).toBeUndefined();
  });
});
