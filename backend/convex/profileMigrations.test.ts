import { convexTest } from "convex-test";
import { afterEach, beforeEach, describe, expect, test, vi } from "vitest";
import { internal } from "./_generated/api";
import schema from "./schema";
import { STRIP_TICK_MS, copyPatch } from "./profileMigrations";

import { copyFlags } from "./profileCopyGate";

// The shared, flippable gate (`profileCopyGate.copyFlags`).
const gate = copyFlags;

type T = ReturnType<typeof convexTest>;
const base = { name: "u", passwordHash: "x", recoveryKeyHash: "x", createdAt: 1 };

beforeEach(() => {
  vi.useFakeTimers();
  gate.copies = true;
});
afterEach(() => {
  vi.useRealTimers();
  gate.copies = true;
});

const mk = (t: T, username: string, extra: any = {}) =>
  t.run((ctx) => ctx.db.insert("users", { username, ...base, ...extra } as any));
const drain = (t: T) => t.finishAllScheduledFunctions(vi.runAllTimers);
const mkRoom = (t: T, createdBy: any) =>
  t.run((ctx) =>
    ctx.db.insert("rooms", { name: "r", createdBy, createdAt: 1, isPrivate: false, memberCount: 0 } as any),
  );
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

describe("stripCopies", () => {
  test("refuses while PROFILE_COPIES is true and touches nothing", async () => {
    const t = convexTest(schema);
    const u = await mk(t, "a");
    const room = await mkRoom(t, u);
    const m = await t.run((ctx) =>
      ctx.db.insert("messages", { roomId: room, userId: u, content: "hi", createdAt: 1, senderName: "A" } as any),
    );
    await expect(
      t.mutation(internal.profileMigrations.stripCopies, { table: "messages" }),
    ).rejects.toThrow(/refused/);
    expect((await t.run((ctx) => ctx.db.get(m)))!.senderName).toBe("A");
  });

  test("clears only copy fields, pages, and throttles after pages that wrote", async () => {
    gate.copies = false;
    const t = convexTest(schema);
    const u = await mk(t, "a");
    const room = await mkRoom(t, u);
    const ids: any[] = [];
    await t.run(async (ctx) => {
      for (let i = 0; i < 4; i++) {
        ids.push(
          await ctx.db.insert("messages", {
            roomId: room,
            userId: u,
            content: `m${i}`,
            createdAt: 1,
            senderName: "A",
            mentions: [{ userId: u, username: "keep" }],
            replyToId: i === 0 ? undefined : ids[0],
            ...(i === 1
              ? { replyToPreview: { senderId: u, senderName: "A", contentPreview: "x", type: "text" } }
              : {}),
          } as any),
        );
      }
      // Already clean: must not be written.
      ids.push(await ctx.db.insert("messages", { roomId: room, userId: u, content: "clean", createdAt: 1 } as any));
    });

    const r = await t.mutation(internal.profileMigrations.stripCopies, { table: "messages", numItems: 2 });
    expect(r).toMatchObject({ done: false, stripped: 2 });
    // The page wrote, so the next tick is delayed by STRIP_TICK_MS.
    const [next]: any[] = await t.run((ctx) => ctx.db.system.query("_scheduled_functions").collect());
    expect(next.scheduledTime - Date.now()).toBeGreaterThanOrEqual(STRIP_TICK_MS);
    expect(
      (await t.run((ctx) => ctx.db.query("messages").collect())).filter((m: any) => m.senderName).length,
    ).toBe(2);
    await drain(t);

    const msgs = await t.run((ctx) => ctx.db.query("messages").collect());
    for (const m of msgs) {
      expect(m.senderName).toBeUndefined();
      expect(m.replyToPreview && "senderName" in m.replyToPreview).toBeFalsy();
    }
    const withMention = msgs.filter((m: any) => m.mentions);
    expect(withMention).toHaveLength(4);
    expect(withMention[0].mentions![0].username).toBe("keep");
    expect(msgs.find((m: any) => m._id === ids[1])!.replyToPreview).toMatchObject({
      senderId: u,
      contentPreview: "x",
      type: "text",
    });
    expect(msgs.find((m: any) => m._id === ids[0])!.content).toBe("m0");
  });

  test("a page with nothing to strip does not pause", async () => {
    gate.copies = false;
    const t = convexTest(schema);
    const u = await mk(t, "a");
    const room = await mkRoom(t, u);
    await t.run(async (ctx) => {
      for (let i = 0; i < 3; i++)
        await ctx.db.insert("messages", { roomId: room, userId: u, content: "c", createdAt: 1 } as any);
    });
    const r = await t.mutation(internal.profileMigrations.stripCopies, { table: "messages", numItems: 1 });
    expect(r).toMatchObject({ done: false, stripped: 0 });
    const [next]: any[] = await t.run((ctx) => ctx.db.system.query("_scheduled_functions").collect());
    expect(next.scheduledTime - Date.now()).toBeLessThan(STRIP_TICK_MS);
    await drain(t);
  });

  test("typing indicators lose name and avatar, keep their keys", async () => {
    gate.copies = false;
    const t = convexTest(schema);
    const u = await mk(t, "a");
    const room = await mkRoom(t, u);
    const id = await t.run((ctx) =>
      ctx.db.insert("typingIndicators", {
        roomId: room,
        userId: u,
        updatedAt: 7,
        userName: "A",
        avatarVisibility: "public",
      } as any),
    );
    await t.mutation(internal.profileMigrations.stripCopies, { table: "typingIndicators" });
    const row: any = await t.run((ctx) => ctx.db.get(id));
    expect(row.userName).toBeUndefined();
    expect(row.avatarVisibility).toBeUndefined();
    expect(row).toMatchObject({ roomId: room, userId: u, updatedAt: 7 });
  });

  test("counts reach 0", async () => {
    gate.copies = false;
    const t = convexTest(schema);
    const u = await mk(t, "a");
    const room = await mkRoom(t, u);
    await t.run(async (ctx) => {
      for (let i = 0; i < 5; i++)
        await ctx.db.insert("messages", { roomId: room, userId: u, content: "c", createdAt: 1, senderName: "A" } as any);
    });
    const fn = internal.profileMigrations.countCopies;
    expect(await countAll(t, fn, "carrying", { table: "messages" })).toBe(5);
    await t.mutation(internal.profileMigrations.stripCopies, { table: "messages", numItems: 2 });
    await drain(t);
    expect(await countAll(t, fn, "carrying", { table: "messages" })).toBe(0);
  });
});

describe("copyPatch", () => {
  test("covers every copy field and nothing else", () => {
    expect(copyPatch("moments", { authorName: "a", authorUsername: "a", authorAvatarStorageId: "s", userId: "u" })).toEqual({
      authorName: undefined,
      authorUsername: undefined,
      authorAvatarStorageId: undefined,
    });
    expect(copyPatch("momentReactions", { userName: "a", userUsername: "a", userAvatarStorageId: "s", userAvatarLevel: "x" })).toEqual({
      userName: undefined,
      userUsername: undefined,
      userAvatarStorageId: undefined,
      userAvatarLevel: undefined,
    });
    expect(copyPatch("momentComments", { userName: "a", replyToName: "b" })).toEqual({
      userName: undefined,
      replyToName: undefined,
    });
    for (const tb of ["momentCommentReactions", "recordReactions", "interactionResponses"] as const) {
      expect(copyPatch(tb, { userName: "a" })).toEqual({ userName: undefined });
    }
    expect(copyPatch("typingIndicators", { userName: "a", avatarStorageId: "s", avatarVisibility: "p" })).toEqual({
      userName: undefined,
      avatarStorageId: undefined,
      avatarVisibility: undefined,
    });
  });

  test("clean rows give null", () => {
    for (const tb of [
      "messages", "messageInteractions", "interactionResponses", "moments", "momentReactions",
      "momentComments", "momentCommentReactions", "recordReactions", "typingIndicators",
    ] as const) {
      expect(copyPatch(tb, { choices: [{ id: "a", count: 1, respondents: [{ userId: "u", at: 1 }] }] })).toBeNull();
    }
  });

  test("respondent names go, ids and timestamps stay; messages keep mentions", () => {
    const p: any = copyPatch("messageInteractions", {
      choices: [
        { id: "a", label: "A", count: 1, respondents: [{ userId: "u", name: "Ann", at: 5 }] },
        { id: "b", label: "B", count: 0 },
      ],
    });
    expect(p.choices[0].respondents).toEqual([{ userId: "u", at: 5 }]);
    expect(p.choices[1]).toEqual({ id: "b", label: "B", count: 0 });
    const m: any = copyPatch("messages", { senderName: "A", mentions: [{ username: "x" }] });
    expect(m).toEqual({ senderName: undefined });
  });
});
