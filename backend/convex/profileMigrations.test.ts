import { convexTest } from "convex-test";
import { afterEach, beforeEach, describe, expect, test, vi } from "vitest";
import { internal } from "./_generated/api";
import schema from "./schema";

type T = ReturnType<typeof convexTest>;
const base = { name: "u", passwordHash: "x", recoveryKeyHash: "x", createdAt: 1 };

beforeEach(() => {
  vi.useFakeTimers();
});
afterEach(() => {
  vi.useRealTimers();
});

const mk = (t: T, username: string, extra: any = {}) =>
  t.run((ctx) => ctx.db.insert("users", { username, ...base, ...extra } as any));
const drain = (t: T) => t.finishAllScheduledFunctions(vi.runAllTimers);
const profiles = (t: T) => t.run((ctx) => ctx.db.query("profiles").collect());

async function countAll(t: T, fn: any, key: string, args: any = {}) {
  let total = 0;
  let cursor: string | null = null;
  for (;;) {
    const r: any = await t.query(fn, { ...args, cursor, numItems: 2 });
    total += r[key];
    if (r.isDone) return total;
    cursor = r.continueCursor;
  }
}

describe("backfillProfiles", () => {
  test("pages across several pages, fills every user, and is idempotent", async () => {
    const t = convexTest(schema);
    await mk(t, "a", { name: "Ann" });
    await mk(t, "b", { name: undefined });
    await mk(t, "c");
    await mk(t, "d");
    await mk(t, "e");
    expect(await countAll(t, internal.profileMigrations.countMissingProfiles, "missing")).toBe(5);

    const r = await t.mutation(internal.profileMigrations.backfillProfiles, { numItems: 2 });
    expect(r.done).toBe(false);
    await drain(t);
    const rows = await profiles(t);
    expect(rows).toHaveLength(5);
    expect(rows.find((p: any) => p.username === "a")).toMatchObject({ name: "Ann" });
    expect(rows.find((p: any) => p.username === "b")).toMatchObject({ name: "b" });
    expect(await countAll(t, internal.profileMigrations.countMissingProfiles, "missing")).toBe(0);

    // Second run: nothing changes, updatedAt does not move.
    const again = await t.mutation(internal.profileMigrations.backfillProfiles, { numItems: 100 });
    expect(again).toMatchObject({ done: true, changed: 0, unchanged: 5 });
    expect(await profiles(t)).toEqual(rows);
  });

  test("a rename after the first run is picked up, the rest stay put", async () => {
    const t = convexTest(schema);
    const a = await mk(t, "a", { name: "Ann" });
    await mk(t, "b");
    await t.mutation(internal.profileMigrations.backfillProfiles, {});
    await t.run((ctx) => ctx.db.patch(a, { name: "Anna" }));
    const r = await t.mutation(internal.profileMigrations.backfillProfiles, {});
    expect(r).toMatchObject({ changed: 1, unchanged: 1 });
  });

  test("a deleted account gets a tombstone", async () => {
    const t = convexTest(schema);
    const gone = await mk(t, "gone", { name: "Gone", deletingAt: 5 });
    await mk(t, "live");
    await t.mutation(internal.profileMigrations.backfillProfiles, {});
    const row = (await profiles(t)).find((p: any) => p.userId === gone)!;
    expect(row).toMatchObject({ deleted: true, name: "", username: "" });
    expect(row.avatarStorageId).toBeUndefined();
    expect(await countAll(t, internal.profileMigrations.countMissingProfiles, "missing")).toBe(0);
  });
});
