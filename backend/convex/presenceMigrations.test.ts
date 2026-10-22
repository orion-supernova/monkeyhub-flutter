import { convexTest } from "convex-test";
import { afterEach, beforeEach, describe, expect, test, vi } from "vitest";
import { internal } from "./_generated/api";
import schema from "./schema";
import { STRIP_TICK_MS } from "./presenceMigrations";
import { SYSTEM_PASSWORD_PREFIX } from "./systemAccount";

const base = { name: "u", passwordHash: "x", recoveryKeyHash: "x", createdAt: 1 };

beforeEach(() => {
  vi.useFakeTimers();
});
afterEach(() => {
  vi.useRealTimers();
  delete process.env.PRESENCE_COMPAT_MIRROR;
});

async function mk(t: ReturnType<typeof convexTest>, username: string, extra: any = {}) {
  return await t.run((ctx) => ctx.db.insert("users", { username, ...base, ...extra } as any));
}
const drain = (t: ReturnType<typeof convexTest>) => t.finishAllScheduledFunctions(vi.runAllTimers);
const dump = (t: ReturnType<typeof convexTest>) =>
  t.run(async (ctx) => ({
    presence: await ctx.db.query("presence").collect(),
    beats: await ctx.db.query("presenceBeats").collect(),
    users: await ctx.db.query("users").collect(),
  }));

describe("backfillPresence", () => {
  test("pages across several pages and maps status/lastSeen/levels", async () => {
    const t = convexTest(schema);
    await mk(t, "on", { status: "online", lastSeen: 500, visibility: { status: "public", lastSeen: "nobody" } });
    await mk(t, "away", { status: "away", lastSeen: 400 });
    await mk(t, "off", { status: "offline", lastSeen: 300 });
    await mk(t, "none");
    await mk(t, "off2", { status: "offline", lastSeen: 200 });
    const r = await t.mutation(internal.presenceMigrations.backfillPresence, { numItems: 2 });
    expect(r.done).toBe(false);
    await drain(t);
    const s = await dump(t);
    expect(s.presence).toHaveLength(5);
    expect(s.beats).toHaveLength(5);
    const byName = (n: string) => {
      const u = s.users.find((x: any) => x.username === n)!;
      return {
        p: s.presence.find((p: any) => p.userId === u._id)!,
        b: s.beats.find((b: any) => b.userId === u._id)!,
      };
    };
    const on = byName("on");
    expect(on.p.status).toBe("online");
    expect(on.p.lastSeen).toBeUndefined();
    expect(on.p.statusLevel).toBe("public");
    expect(on.p.lastSeenLevel).toBe("nobody");
    expect(on.b).toMatchObject({ live: true, beatAt: 500 });
    expect(byName("away").p).toMatchObject({ status: "away", lastSeen: 400 });
    expect(byName("away").b.live).toBe(true);
    expect(byName("off").p).toMatchObject({ status: "offline", lastSeen: 300 });
    expect(byName("off").b).toMatchObject({ live: false, beatAt: 300 });
    const none = byName("none");
    expect(none.p.status).toBe("offline");
    expect(none.p.lastSeen).toBeUndefined();
    expect(none.b.live).toBe(false);
  });

  test("online with no lastSeen beats at now", async () => {
    const t = convexTest(schema);
    vi.setSystemTime(7_000);
    await mk(t, "a", { status: "online" });
    await t.mutation(internal.presenceMigrations.backfillPresence, {});
    const s = await dump(t);
    expect(s.beats[0]).toMatchObject({ live: true, beatAt: 7_000 });
  });

  test("is idempotent", async () => {
    const t = convexTest(schema);
    await mk(t, "a", { status: "online", lastSeen: 5 });
    await mk(t, "b", { status: "offline", lastSeen: 6 });
    await t.mutation(internal.presenceMigrations.backfillPresence, {});
    const first = await dump(t);
    const r = await t.mutation(internal.presenceMigrations.backfillPresence, {});
    expect(r).toMatchObject({ created: 0, existing: 2 });
    const second = await dump(t);
    expect(second.presence).toEqual(first.presence);
    expect(second.beats).toEqual(first.beats);
  });

  test("does not overwrite an existing presence row", async () => {
    const t = convexTest(schema);
    const id = await mk(t, "a", { status: "offline", lastSeen: 5 });
    await t.run((ctx) => ctx.db.insert("presence", { userId: id, status: "online" }));
    await t.mutation(internal.presenceMigrations.backfillPresence, {});
    const s = await dump(t);
    expect(s.presence).toHaveLength(1);
    expect(s.presence[0].status).toBe("online");
    expect(s.beats).toHaveLength(0);
  });

  test("skips system and tombstoned accounts", async () => {
    const t = convexTest(schema);
    await mk(t, "sys", { status: "online", passwordHash: SYSTEM_PASSWORD_PREFIX + "x" });
    await mk(t, "dead", { status: "online", deletingAt: 1 });
    await mk(t, "ok", { status: "online" });
    const r = await t.mutation(internal.presenceMigrations.backfillPresence, {});
    expect(r).toMatchObject({ created: 1, skipped: 2 });
    const s = await dump(t);
    expect(s.presence).toHaveLength(1);
  });
});

describe("stripUsersPresence", () => {
  test("refuses without PRESENCE_COMPAT_MIRROR=off", async () => {
    const t = convexTest(schema);
    await mk(t, "a", { status: "online", lastSeen: 1 });
    await expect(t.mutation(internal.presenceMigrations.stripUsersPresence, {})).rejects.toThrow(/refused/);
    process.env.PRESENCE_COMPAT_MIRROR = "on";
    await expect(t.mutation(internal.presenceMigrations.stripUsersPresence, {})).rejects.toThrow(/refused/);
    const s = await dump(t);
    expect(s.users[0].status).toBe("online");
  });

  test("pages and throttles: one page per tick, 5 s apart", async () => {
    process.env.PRESENCE_COMPAT_MIRROR = "off";
    const t = convexTest(schema);
    for (let i = 0; i < 5; i++) await mk(t, `u${i}`, { status: "away", lastSeen: i + 1 });
    await mk(t, "clean");
    vi.setSystemTime(100_000);
    const r = await t.mutation(internal.presenceMigrations.stripUsersPresence, { numItems: 2 });
    expect(r).toMatchObject({ done: false, stripped: 2 });
    // Only the first page is done; the next is scheduled STRIP_TICK_MS out.
    let s = await dump(t);
    expect(s.users.filter((u: any) => u.status !== undefined)).toHaveLength(3);
    const sched = await t.run((ctx) => ctx.db.system.query("_scheduled_functions").collect());
    expect(sched).toHaveLength(1);
    expect(sched[0].scheduledTime - 100_000).toBe(STRIP_TICK_MS);
    await drain(t);
    s = await dump(t);
    expect(s.users.every((u: any) => u.status === undefined && u.lastSeen === undefined)).toBe(true);
  });

  test("is a no-op when fields are already absent", async () => {
    process.env.PRESENCE_COMPAT_MIRROR = "off";
    const t = convexTest(schema);
    await mk(t, "a");
    await mk(t, "b");
    const r = await t.mutation(internal.presenceMigrations.stripUsersPresence, {});
    expect(r).toMatchObject({ done: true, stripped: 0 });
  });
});

describe("counts", () => {
  test("reach 0 after the backfill and the strip", async () => {
    const t = convexTest(schema);
    await mk(t, "a", { status: "online", lastSeen: 1 });
    await mk(t, "b", { status: "offline", lastSeen: 2 });
    await mk(t, "sys", { passwordHash: SYSTEM_PASSWORD_PREFIX + "x", status: "online" });
    const sum = async (fn: any, key: string) => {
      let cursor: string | null = null;
      let total = 0;
      for (;;) {
        const r: any = await t.query(fn, { cursor, numItems: 2 });
        total += r[key];
        if (r.isDone) return total;
        cursor = r.continueCursor;
      }
    };
    expect(await sum(internal.presenceMigrations.countMissingPresence, "missing")).toBe(2);
    expect(await sum(internal.presenceMigrations.countUsersWithPresenceFields, "carrying")).toBe(3);
    await t.mutation(internal.presenceMigrations.backfillPresence, {});
    expect(await sum(internal.presenceMigrations.countMissingPresence, "missing")).toBe(0);
    process.env.PRESENCE_COMPAT_MIRROR = "off";
    await t.mutation(internal.presenceMigrations.stripUsersPresence, {});
    expect(await sum(internal.presenceMigrations.countUsersWithPresenceFields, "carrying")).toBe(0);
  });
});
