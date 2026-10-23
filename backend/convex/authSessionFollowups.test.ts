import { convexTest } from "convex-test";
import { afterEach, beforeEach, describe, expect, test, vi } from "vitest";
import { api, internal } from "./_generated/api";
import { SESSION_GRACE_FLOOR, SESSION_TOUCH_MS } from "./sessionCore";
import { suspendAccount, unsuspendAccount } from "./moderation";
import schema from "./schema";

type T = ReturnType<typeof convexTest>;
const DAY = 24 * 60 * 60 * 1000;
const SECRET_A = "a".repeat(64);
const SECRET_B = "b".repeat(64);

beforeEach(() => {
  vi.useFakeTimers();
  vi.setSystemTime(SESSION_GRACE_FLOOR + 3 * DAY);
});
afterEach(() => vi.useRealTimers());

async function signUp(t: T, username: string, extra: Record<string, any> = {}) {
  return await t.mutation(api.auth.signup, {
    username,
    name: username,
    passwordHash: `hash-${username}`,
    recoveryKeyHash: `recovery-${username}`,
    deviceId: `device-${username}`,
    ...extra,
  });
}

const login = async (t: T, username: string, deviceId: string) =>
  (await t.mutation(api.auth.login, {
    username,
    passwordHash: `hash-${username}`,
    deviceId,
  })) as { userId: any; token: string };

const sessions = (t: T, userId: any): Promise<any[]> =>
  t.run((ctx: any) =>
    ctx.db
      .query("sessions")
      .withIndex("by_user", (q: any) => q.eq("userId", userId))
      .collect(),
  );

describe("heartbeat refreshes only the calling session", () => {
  test("the phone in the drawer keeps its old lastSeenAt", async () => {
    const t = convexTest(schema);
    const laptop = await signUp(t, "alice");
    const phone = await login(t, "alice", "phone");
    vi.setSystemTime(Date.now() + SESSION_TOUCH_MS + 1000);
    const later = Date.now();

    await t.mutation(api.presenceApi.beat, {
      sessionToken: laptop.token,
      status: "online",
    });

    const rows = await sessions(t, laptop.userId);
    const byDevice = new Map(rows.map((r) => [r.deviceId, r]));
    expect(byDevice.get("device-alice")!.lastSeenAt).toBe(later);
    expect(byDevice.get("phone")!.lastSeenAt).toBeLessThan(later);
    expect(phone.token).toBeTruthy();
  });

  test("the legacy users.heartbeat is per-session too, and throttled", async () => {
    const t = convexTest(schema);
    const laptop = await signUp(t, "bob");
    await login(t, "bob", "phone");
    const first = Date.now();
    // Fresh session: no write.
    vi.setSystemTime(first + 1000);
    await t.mutation(api.users.heartbeat, { sessionToken: laptop.token, userId: laptop.userId } as any);
    let rows = await sessions(t, laptop.userId);
    expect(rows.every((r) => r.lastSeenAt === first)).toBe(true);

    vi.setSystemTime(first + SESSION_TOUCH_MS + 1000);
    await t.mutation(api.users.heartbeat, { sessionToken: laptop.token, userId: laptop.userId } as any);
    rows = await sessions(t, laptop.userId);
    const touched = rows.filter((r) => r.lastSeenAt > first);
    expect(touched.map((r) => r.deviceId)).toEqual(["device-bob"]);
  });

  test("a forgotten session still idles out while another stays active", async () => {
    const t = convexTest(schema);
    const laptop = await signUp(t, "cara");
    const phone = await login(t, "cara", "phone");
    let token = laptop.token;
    // The laptop beats every 60 days for 120 days; the phone is never used.
    for (let i = 0; i < 2; i++) {
      vi.setSystemTime(Date.now() + 60 * DAY);
      await t.mutation(api.presenceApi.beat, { sessionToken: token, status: "online" });
    }
    await expect(
      t.mutation(api.presenceApi.beat, { sessionToken: phone.token, status: "online" }),
    ).rejects.toThrow(/SESSION_REVOKED/);
    await t.mutation(api.presenceApi.beat, { sessionToken: token, status: "online" });
  });
});

describe("a suspended user deletes their account without an old session", () => {
  async function suspended(t: T, username: string) {
    const u = await signUp(t, username);
    await t.run((ctx) => suspendAccount(ctx, u.userId, u.userId));
    // The revoked row is gone a week later.
    vi.setSystemTime(Date.now() + 8 * DAY);
    await t.mutation(internal.sessionCore.gcRevokedSessions, {});
    expect(await sessions(t, u.userId)).toHaveLength(0);
    return u;
  }

  test("password proof deletes it, and the ban outlives the account", async () => {
    const t = convexTest(schema);
    const u = await suspended(t, "dan");
    await expect(login(t, "dan", "d2")).rejects.toThrow(/ACCOUNT_SUSPENDED/);
    await t.mutation(api.auth.deleteSuspendedAccount, {
      username: "dan",
      passwordHash: "hash-dan",
    });
    const user = await t.run((ctx) => ctx.db.get(u.userId));
    expect(user?.deletingAt).toBeDefined();
    expect(user?.suspendedAt).toBeDefined();
  });

  test("deleting after the sessions were GC'd keeps the install ban, and an unban cannot lift it", async () => {
    const t = convexTest(schema);
    const u = await signUp(t, "hal", { deviceSecret: SECRET_A });
    await t.run((ctx) => suspendAccount(ctx, u.userId, u.userId));
    vi.setSystemTime(Date.now() + 8 * DAY);
    await t.mutation(internal.sessionCore.gcRevokedSessions, {});
    expect(await sessions(t, u.userId)).toHaveLength(0);
    await t.mutation(api.auth.deleteSuspendedAccount, {
      username: "hal",
      passwordHash: "hash-hal",
    });
    expect((await t.run((ctx) => ctx.db.get(u.userId)))?.deletingAt).toBeDefined();
    await expect(
      signUp(t, "hal2", { deviceId: "d-new", deviceSecret: SECRET_A }),
    ).rejects.toThrow(/ACCOUNT_SUSPENDED/);
    await expect(t.run((ctx) => unsuspendAccount(ctx, u.userId))).rejects.toThrow(
      /USER_NOT_FOUND/,
    );
    await expect(
      signUp(t, "hal3", { deviceId: "d-new3", deviceSecret: SECRET_A }),
    ).rejects.toThrow(/ACCOUNT_SUSPENDED/);
  });

  test("recordAccountBans reads the newest sessions first", async () => {
    const t = convexTest(schema);
    const u = await signUp(t, "ivy", { deviceSecret: SECRET_A });
    await t.run(async (ctx: any) => {
      const base = await ctx.db
        .query("sessions")
        .withIndex("by_user", (q: any) => q.eq("userId", u.userId))
        .first();
      const { _id, _creationTime, ...rest } = base;
      for (let i = 0; i < 205; i++) {
        await ctx.db.insert("sessions", {
          ...rest,
          tokenHash: `th-${i}`,
          deviceId: `old-${i}`,
          deviceSecretHash: `old-secret-${i}`,
        });
      }
      await ctx.db.insert("sessions", {
        ...rest,
        tokenHash: "th-new",
        deviceId: "newest",
        deviceSecretHash: "newest-secret",
      });
    });
    await t.run((ctx) => suspendAccount(ctx, u.userId, u.userId));
    const { identityBanHash, BAN_DEVICE } = await import("./sessionCore");
    const want = await identityBanHash(BAN_DEVICE, "newest-secret");
    const rows = await t.run((ctx: any) =>
      ctx.db.query("bannedIdentities").withIndex("by_hash", (q: any) => q.eq("hash", want)).collect(),
    );
    expect(rows).toHaveLength(1);
  });

  test("a wrong password deletes nothing and counts toward the lockout", async () => {
    const t = convexTest(schema);
    const u = await suspended(t, "eve");
    const res = await t.mutation(api.auth.deleteSuspendedAccount, {
      username: "eve",
      passwordHash: "nope",
    });
    expect(res).toEqual({ __refused: "WRONG_PASSWORD" });
    expect((await t.run((ctx) => ctx.db.get(u.userId)))?.deletingAt).toBeUndefined();
    for (let i = 0; i < 9; i++) {
      await t.mutation(api.auth.deleteSuspendedAccount, {
        username: "eve",
        passwordHash: "nope",
      });
    }
    await expect(
      t.mutation(api.auth.deleteSuspendedAccount, {
        username: "eve",
        passwordHash: "hash-eve",
      }),
    ).rejects.toThrow(/TOO_MANY_ATTEMPTS/);
  });

  test("it is refused for an account that is not suspended", async () => {
    const t = convexTest(schema);
    const u = await signUp(t, "fay");
    await expect(
      t.mutation(api.auth.deleteSuspendedAccount, {
        username: "fay",
        passwordHash: "hash-fay",
      }),
    ).rejects.toThrow(/CHILD_NOT_ALLOWED/);
    expect((await t.run((ctx) => ctx.db.get(u.userId)))?.deletingAt).toBeUndefined();
  });

  test("a social-only suspended account is deleted by its identity, once proven", async () => {
    const t = convexTest(schema);
    const u = await signUp(t, "gus");
    await t.run(async (ctx) => {
      await ctx.db.insert("socialIdentities", {
        provider: "google",
        subject: "g-1",
        userId: u.userId,
        createdAt: Date.now(),
        lastUsedAt: Date.now(),
      });
    });
    // Not suspended: refused.
    await expect(
      t.mutation(internal.socialAuth.deleteSuspendedByIdentity, { userId: u.userId }),
    ).rejects.toThrow(/CHILD_NOT_ALLOWED/);
    await t.run((ctx) => suspendAccount(ctx, u.userId, u.userId));
    await t.mutation(internal.socialAuth.deleteSuspendedByIdentity, { userId: u.userId });
    expect((await t.run((ctx) => ctx.db.get(u.userId)))?.deletingAt).toBeDefined();
    // The ban on the Google identity survives the deletion.
    const banned = await t.run((ctx) => ctx.db.query("bannedIdentities").collect());
    expect(banned.length).toBeGreaterThanOrEqual(1);
  });
});

describe("a banned password user cannot sign up again from the same install", () => {
  test("same deviceSecret is refused, another install is not", async () => {
    const t = convexTest(schema);
    const bad = await signUp(t, "mal", { deviceSecret: SECRET_A });
    await t.run((ctx) => suspendAccount(ctx, bad.userId, bad.userId));

    await expect(
      signUp(t, "mal2", { deviceId: "d-new", deviceSecret: SECRET_A }),
    ).rejects.toThrow(/ACCOUNT_SUSPENDED/);
    await signUp(t, "nina", { deviceId: "d-other", deviceSecret: SECRET_B });
    // No secret at all (an old client): nothing to match, allowed.
    await signUp(t, "olga", { deviceId: "d-old" });
  });

  test("a kept email is matched case-insensitively", async () => {
    const t = convexTest(schema);
    const bad = await signUp(t, "pat", { email: "Pat@Example.com" });
    await t.run((ctx) => suspendAccount(ctx, bad.userId, bad.userId));
    await expect(
      signUp(t, "pat2", { deviceId: "x", email: "pat@example.com " }),
    ).rejects.toThrow(/ACCOUNT_SUSPENDED/);
  });

  test("lifting the ban lifts the install ban; the ban survives deleting the account", async () => {
    const t = convexTest(schema);
    const bad = await signUp(t, "quin", { deviceSecret: SECRET_A });
    await t.run((ctx) => suspendAccount(ctx, bad.userId, bad.userId));
    await t.run((ctx) => unsuspendAccount(ctx, bad.userId));
    await signUp(t, "quin2", { deviceId: "d2", deviceSecret: SECRET_A });

    const worse = await signUp(t, "rex", { deviceId: "d3", deviceSecret: SECRET_B });
    await t.run((ctx) => suspendAccount(ctx, worse.userId, worse.userId));
    await t.mutation(api.auth.deleteSuspendedAccount, {
      username: "rex",
      passwordHash: "hash-rex",
    });
    await expect(
      signUp(t, "rex2", { deviceId: "d4", deviceSecret: SECRET_B }),
    ).rejects.toThrow(/ACCOUNT_SUSPENDED/);
  });
});
