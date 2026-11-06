import { convexTest } from "convex-test";
import { afterEach, beforeEach, describe, expect, test, vi } from "vitest";
import { internal } from "./_generated/api";
import { LEGACY_MEMBER_FIELDS } from "./cleanupMigration";
import schema from "./schema";

type T = ReturnType<typeof convexTest>;

beforeEach(() => {
  vi.useFakeTimers();
});
afterEach(() => {
  vi.useRealTimers();
});

const drain = (t: T) => t.finishAllScheduledFunctions(vi.runAllTimers);

/** Every legacy field set to a plausible value. */
const LEGACY_VALUES: Record<string, unknown> = {
  lastReadAt: 10,
  lastDeliveredAt: 11,
  lastReadClock: 12,
  lastDeliveredClock: 13,
  readLog: [{ upTo: 1, at: 2 }],
  deliveredLog: [{ upTo: 1, at: 2 }],
  isPinned: true,
  pinnedAt: 14,
  isArchived: true,
  archivedAt: 15,
  muteNotifications: true,
  muteBadges: true,
  mutedUntil: 16,
  seenVisibility: "friends",
  vanishSeenAt: 17,
  vanishShareReads: true,
};

async function seed(t: T, members: number) {
  return await t.run(async (ctx: any) => {
    const user = await ctx.db.insert("users", {
      username: "u",
      name: "u",
      passwordHash: "x",
      recoveryKeyHash: "x",
      createdAt: 1,
    });
    const room = await ctx.db.insert("rooms", {
      name: "r",
      createdBy: user,
      createdAt: 1,
      isPrivate: false,
      memberCount: 0,
      lastSeq: 0,
    });
    const dirty: any[] = [];
    for (let i = 0; i < members; i++) {
      const u = await ctx.db.insert("users", {
        username: `m${i}`,
        name: "m",
        passwordHash: "x",
        recoveryKeyHash: "x",
        createdAt: 1,
      });
      dirty.push(
        await ctx.db.insert("roomMembers", {
          roomId: room,
          userId: u,
          joinedAt: 5,
          role: "member",
          ...LEGACY_VALUES,
        }),
      );
    }
    return { user, room, dirty };
  });
}

const allMembers = (t: T): Promise<any[]> => t.run((ctx: any) => ctx.db.query("roomMembers").collect());

async function countAll(t: T, phase: "members" | "receiptLogs" | "avatarJobs") {
  let carrying = 0;
  const byField: Record<string, number> = {};
  let cursor: string | null = null;
  for (;;) {
    const r: any = await t.query(internal.cleanupMigration.countLegacy, { phase, cursor, numItems: 2 });
    carrying += r.carrying;
    for (const [k, v] of Object.entries(r.byField as Record<string, number>)) {
      byField[k] = (byField[k] ?? 0) + v;
    }
    if (r.isDone) return { carrying, byField };
    cursor = r.continueCursor;
  }
}

describe("stripLegacy", () => {
  test("unsets every legacy membership field and keeps the roster fields", async () => {
    const t = convexTest(schema);
    await seed(t, 7);
    const before = await countAll(t, "members");
    expect(before.carrying).toBe(7);
    expect(Object.keys(before.byField).sort()).toEqual([...LEGACY_MEMBER_FIELDS].sort());

    await t.mutation(internal.cleanupMigration.stripLegacy, {});
    await drain(t);

    const rows = await allMembers(t);
    expect(rows).toHaveLength(7);
    for (const m of rows) {
      for (const f of LEGACY_MEMBER_FIELDS) expect(f in m).toBe(false);
      expect(m.joinedAt).toBe(5);
      expect(m.role).toBe("member");
    }
    expect((await countAll(t, "members")).carrying).toBe(0);
  });

  test("the fixture covers exactly LEGACY_MEMBER_FIELDS, and the schema accepts every one", async () => {
    // A listed field the schema does not hold would fail validation in seed().
    const t = convexTest(schema);
    await seed(t, 1);
    expect(Object.keys(LEGACY_VALUES).sort()).toEqual([...LEGACY_MEMBER_FIELDS].sort());
  });

  test("deletes every receiptLogs row, across more than one page", async () => {
    const t = convexTest(schema);
    const { user, room } = await seed(t, 0);
    await t.run(async (ctx: any) => {
      for (let i = 0; i < 230; i++) {
        await ctx.db.insert("receiptLogs", {
          roomId: room,
          userId: user,
          kind: i % 2 === 0 ? "read" : "delivered",
          entries: [{ upTo: i, at: i }],
        });
      }
    });
    expect((await countAll(t, "receiptLogs")).carrying).toBe(230);
    const r = await t.mutation(internal.cleanupMigration.stripLegacy, {});
    expect(r.done).toBe(false);
    await drain(t);
    expect(await t.run((ctx: any) => ctx.db.query("receiptLogs").collect())).toHaveLength(0);
    expect((await countAll(t, "receiptLogs")).carrying).toBe(0);
  });

  test("deletes leftover retired avatar deletion jobs and nothing else", async () => {
    const t = convexTest(schema);
    const base = { targetId: "x", cursor: null, stepId: "", createdAt: 1, lastProgressAt: 1, restarts: 0, attempts: 0, pages: 0, writes: 0 };
    await t.run(async (ctx: any) => {
      await ctx.db.insert("deletions", { ...base, kind: "avatar", state: "done", finishedAt: 2 });
      await ctx.db.insert("deletions", { ...base, kind: "avatar", targetId: "y", state: "running" });
      await ctx.db.insert("deletions", { ...base, kind: "message", state: "done", finishedAt: 2 });
    });
    expect((await countAll(t, "avatarJobs")).carrying).toBe(2);
    await t.mutation(internal.cleanupMigration.stripLegacy, {});
    await drain(t);
    const left: any[] = await t.run((ctx: any) => ctx.db.query("deletions").collect());
    expect(left.map((j) => j.kind)).toEqual(["message"]);
    expect((await countAll(t, "avatarJobs")).carrying).toBe(0);
  });

  test("is idempotent: a second run writes nothing", async () => {
    const t = convexTest(schema);
    await seed(t, 3);
    await t.mutation(internal.cleanupMigration.stripLegacy, {});
    await drain(t);
    const snapshot = await allMembers(t);

    const again = await t.mutation(internal.cleanupMigration.stripLegacy, {});
    await drain(t);
    expect(again).toMatchObject({ stripped: 0 });
    expect(await allMembers(t)).toEqual(snapshot);
  });

  test("a row with only some legacy fields is stripped; a clean row is untouched", async () => {
    const t = convexTest(schema);
    const { room } = await seed(t, 0);
    const [partial, clean] = await t.run(async (ctx: any) => {
      const a = await ctx.db.insert("users", { username: "a", name: "a", passwordHash: "x", recoveryKeyHash: "x", createdAt: 1 });
      const b = await ctx.db.insert("users", { username: "b", name: "b", passwordHash: "x", recoveryKeyHash: "x", createdAt: 1 });
      return [
        await ctx.db.insert("roomMembers", { roomId: room, userId: a, joinedAt: 1, role: "member", isPinned: false, mutedUntil: 9 }),
        await ctx.db.insert("roomMembers", { roomId: room, userId: b, joinedAt: 1, role: "owner" }),
      ];
    });
    const cleanBefore: any = await t.run((ctx: any) => ctx.db.get(clean));
    await t.mutation(internal.cleanupMigration.stripLegacy, {});
    await drain(t);
    const p: any = await t.run((ctx: any) => ctx.db.get(partial));
    expect("isPinned" in p).toBe(false);
    expect("mutedUntil" in p).toBe(false);
    expect(await t.run((ctx: any) => ctx.db.get(clean))).toEqual(cleanBefore);
  });
});

describe("countLegacy", () => {
  test("reports nothing on a clean database and names the fields on a dirty one", async () => {
    const t = convexTest(schema);
    expect(await countAll(t, "members")).toEqual({ carrying: 0, byField: {} });
    expect((await countAll(t, "receiptLogs")).carrying).toBe(0);
    expect((await countAll(t, "avatarJobs")).carrying).toBe(0);

    await seed(t, 3);
    const dirty = await countAll(t, "members");
    expect(dirty.carrying).toBe(3);
    expect(dirty.byField.isPinned).toBe(3);
    expect(dirty.byField.readLog).toBe(3);
    expect(dirty.byField.vanishSeenAt).toBe(3);
  });

  test("defaults to the members phase and pages", async () => {
    const t = convexTest(schema);
    await seed(t, 5);
    const first: any = await t.query(internal.cleanupMigration.countLegacy, { numItems: 2 });
    expect(first.phase).toBe("members");
    expect(first.scanned).toBe(2);
    expect(first.isDone).toBe(false);
  });
});
