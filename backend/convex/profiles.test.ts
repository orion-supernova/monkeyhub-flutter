import { convexTest } from "convex-test";
import { afterEach, beforeEach, describe, expect, test, vi } from "vitest";
import { api } from "./_generated/api";
import schema from "./schema";
import { PROFILES_CAP } from "./profiles";
import {
  PROFILE_COPIES,
  nameOf,
  syncProfile,
  tombstoneProfile,
} from "./profilesCore";

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

const profileRows = (t: T, userId: string): Promise<any[]> =>
  t.run((ctx: any) =>
    ctx.db
      .query("profiles")
      .withIndex("by_user", (q: any) => q.eq("userId", userId))
      .collect(),
  );

const versions = (t: T, viewer: { token: string }, ids: string[]) =>
  t.query(api.profiles.versions, { sessionToken: viewer.token, ids: ids as any }) as Promise<
    { id: string; u: number; av: boolean }[]
  >;
const get = (t: T, viewer: { token: string }, ids: string[]) =>
  t.query(api.profiles.get, { sessionToken: viewer.token, ids: ids as any }) as Promise<any[]>;

describe("syncProfile", () => {
  test("inserts, then a no-op writes nothing", async () => {
    const t = convexTest(schema);
    const a = await signUp(t, "ann");
    await t.run((ctx) => syncProfile(ctx, a.userId as any));
    const [row] = await profileRows(t, a.userId);
    expect(row).toMatchObject({ name: "ann", username: "ann", updatedAt: T0 });
    expect(row.deleted).toBeUndefined();

    vi.setSystemTime(T0 + 5000);
    const r = await t.run((ctx) => syncProfile(ctx, a.userId as any));
    expect(r.changed).toBe(false);
    const rows = await profileRows(t, a.userId);
    expect(rows).toHaveLength(1);
    expect(rows[0]._creationTime).toBe(row._creationTime);
    expect(rows[0].updatedAt).toBe(T0);
  });

  test("updatedAt is monotonic even if the clock steps back", async () => {
    const t = convexTest(schema);
    const a = await signUp(t, "ann");
    await t.run((ctx) => syncProfile(ctx, a.userId as any));
    await t.run((ctx: any) => ctx.db.patch(a.userId, { name: "Ann 2" }));
    vi.setSystemTime(T0 - 10_000);
    await t.run((ctx) => syncProfile(ctx, a.userId as any));
    const [row] = await profileRows(t, a.userId);
    expect(row.name).toBe("Ann 2");
    expect(row.updatedAt).toBe(T0 + 1);
    await t.run((ctx: any) => ctx.db.patch(a.userId, { name: "Ann 3" }));
    await t.run((ctx) => syncProfile(ctx, a.userId as any));
    expect((await profileRows(t, a.userId))[0].updatedAt).toBe(T0 + 2);
  });

  test("copies name fallback, avatar level and the system flag", async () => {
    const t = convexTest(schema);
    const a = await signUp(t, "ann");
    await t.run(async (ctx: any) => {
      await ctx.db.patch(a.userId, {
        name: undefined,
        visibility: { avatar: "friends" },
      });
      await syncProfile(ctx, a.userId);
    });
    const [row] = await profileRows(t, a.userId);
    expect(row).toMatchObject({ name: "ann", avatarLevel: "friends" });
    expect(row.isSystem).toBeUndefined();
  });

  test("a user already deleting syncs to a tombstone; a missing user is a no-op", async () => {
    const t = convexTest(schema);
    const a = await signUp(t, "ann");
    await t.run(async (ctx: any) => {
      await syncProfile(ctx, a.userId);
      await ctx.db.patch(a.userId, { deletingAt: T0 });
      await syncProfile(ctx, a.userId);
    });
    expect((await profileRows(t, a.userId))[0]).toMatchObject({
      deleted: true,
      name: "",
      username: "",
    });
    const b = await signUp(t, "bob");
    await t.run(async (ctx: any) => {
      // Signup now writes the profile row itself; drop it to start from none.
      for (const r of await ctx.db.query("profiles").withIndex("by_user", (q: any) => q.eq("userId", b.userId)).collect()) {
        await ctx.db.delete(r._id);
      }
      await ctx.db.delete(b.userId);
      expect((await syncProfile(ctx, b.userId)).changed).toBe(false);
    });
    expect(await profileRows(t, b.userId)).toHaveLength(0);
  });
});

describe("tombstoneProfile and nameOf", () => {
  test("tombstone clears name, username and avatar, is idempotent, and nameOf gives empty", async () => {
    const t = convexTest(schema);
    const a = await signUp(t, "ann");
    await t.run(async (ctx: any) => {
      const sid = await ctx.storage.store(new Blob(["x"]));
      await ctx.db.patch(a.userId, { avatarStorageId: sid });
      await syncProfile(ctx, a.userId);
      expect(await nameOf(ctx, a.userId)).toBe("ann");
    });
    expect((await profileRows(t, a.userId))[0].avatarStorageId).toBeDefined();

    vi.setSystemTime(T0 + 1000);
    await t.run((ctx) => tombstoneProfile(ctx, a.userId as any));
    const [row] = await profileRows(t, a.userId);
    expect(row).toMatchObject({ deleted: true, name: "", username: "" });
    expect(row.avatarStorageId).toBeUndefined();
    expect(row.updatedAt).toBe(T0 + 1000);

    vi.setSystemTime(T0 + 2000);
    const again = await t.run((ctx) => tombstoneProfile(ctx, a.userId as any));
    expect(again.changed).toBe(false);
    expect((await profileRows(t, a.userId))[0].updatedAt).toBe(T0 + 1000);
    expect(await t.run((ctx) => nameOf(ctx, a.userId as any))).toBe("");
  });

  test("nameOf falls back to users before the backfill", async () => {
    const t = convexTest(schema);
    const a = await signUp(t, "ann");
    expect(await t.run((ctx) => nameOf(ctx, a.userId as any))).toBe("ann");
  });

  test("tombstone inserts when no row existed", async () => {
    const t = convexTest(schema);
    const a = await signUp(t, "ann");
    await t.run((ctx) => tombstoneProfile(ctx, a.userId as any));
    expect((await profileRows(t, a.userId))[0].deleted).toBe(true);
  });

  test("PROFILE_COPIES is on until the strip", () => {
    expect(PROFILE_COPIES).toBe(true);
  });
});

describe("versions and get", () => {
  test("cap: 100 pass, 101 throw TOO_MANY_IDS on both", async () => {
    const t = convexTest(schema);
    const me = await signUp(t, "me");
    const ids = await t.run(async (ctx) => {
      const out: string[] = [];
      for (let i = 0; i < PROFILES_CAP + 1; i++) {
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
    expect(await versions(t, me, ids.slice(0, PROFILES_CAP))).toHaveLength(PROFILES_CAP);
    await expect(versions(t, me, ids)).rejects.toThrow("TOO_MANY_IDS");
    expect(await get(t, me, ids.slice(0, PROFILES_CAP))).toHaveLength(PROFILES_CAP);
    await expect(get(t, me, ids)).rejects.toThrow("TOO_MANY_IDS");
  });

  test("avatar privacy matrix, and get hides the file when av is false", async () => {
    const t = convexTest(schema);
    const me = await signUp(t, "me");
    const names = ["pub", "frnd", "nobd", "kid", "strg", "dflt"];
    const u: Record<string, string> = { selfie: me.userId };
    for (const n of names) u[n] = (await signUp(t, n)).userId;
    const levels: Record<string, string | undefined> = {
      selfie: "nobody",
      pub: "public",
      frnd: "friends",
      nobd: "nobody",
      kid: "nobody",
      strg: "friends",
      dflt: undefined,
    };
    await t.run(async (ctx: any) => {
      for (const [n, id] of Object.entries(u)) {
        const sid = await ctx.storage.store(new Blob([n]));
        await ctx.db.patch(id, {
          avatarStorageId: sid,
          visibility: levels[n] ? { avatar: levels[n] } : undefined,
        });
        await syncProfile(ctx, id);
      }
      await ctx.db.insert("friendships", {
        userId: u.frnd as any,
        friendId: me.userId as any,
        status: "accepted",
        createdAt: 1,
      });
      await ctx.db.insert("guardianships", {
        guardianId: me.userId as any,
        childId: u.kid as any,
        role: "primary",
        createdAt: 1,
      });
    });
    const expected: Record<string, boolean> = {
      selfie: true, // self
      pub: true, // public
      frnd: true, // friends and friends
      nobd: false, // nobody
      kid: true, // nobody, but guardian bypass
      strg: false, // friends, stranger
      dflt: true, // default avatar level is public
    };
    const ids = Object.values(u);
    const vs = await versions(t, me, ids);
    const gs = await get(t, me, ids);
    for (const [n, id] of Object.entries(u)) {
      expect(vs.find((x) => x.id === id)!.av, n).toBe(expected[n]);
      const g = gs.find((x) => x && x.id === id)!;
      expect("avatarStorageId" in g, n).toBe(expected[n]);
    }
  });

  test("shapes: missing row, no avatar, tombstone, system flag, dedupe", async () => {
    const t = convexTest(schema);
    const me = await signUp(t, "me");
    const a = await signUp(t, "ann");
    const b = await signUp(t, "bob");
    const c = await signUp(t, "cat");
    await t.run(async (ctx: any) => {
      // Signup writes profile rows; remove cat's so the "no row" case exists.
      for (const r of await ctx.db.query("profiles").withIndex("by_user", (q: any) => q.eq("userId", c.userId)).collect()) {
        await ctx.db.delete(r._id);
      }
      await syncProfile(ctx, a.userId);
      await syncProfile(ctx, b.userId);
      await tombstoneProfile(ctx, b.userId);
    });
    const vs = await versions(t, me, [a.userId, a.userId, b.userId, c.userId]);
    expect(vs).toEqual([
      { id: a.userId, u: T0, av: false }, // no avatar
      { id: b.userId, u: T0 + 1, av: false },
      { id: c.userId, u: 0, av: false }, // no row
    ]);
    const gs = await get(t, me, [a.userId, b.userId, c.userId]);
    expect(gs[0]).toEqual({
      id: a.userId,
      name: "ann",
      username: "ann",
      updatedAt: T0,
    });
    expect(gs[1]).toMatchObject({ deleted: true, name: "", username: "" });
    expect(gs[2]).toBeNull();
  });
});
