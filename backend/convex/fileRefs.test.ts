import { convexTest } from "convex-test";
import { afterEach, beforeEach, describe, expect, test, vi } from "vitest";
import { api, internal } from "./_generated/api";
import {
  attachFile,
  claimUpload,
  discardUpload,
  fileInUse,
  releaseFile,
  releaseMessageBlobs,
  transferFile,
  type FileHolder,
} from "./files";
import schema from "./schema";

/**
 * Phase 3 P1: files are freed by their last reference, not by scanning for
 * one. Holders here are made-up ids unless a test needs the row to exist.
 */

type T = ReturnType<typeof convexTest>;

afterEach(() => {
  vi.useRealTimers();
  vi.restoreAllMocks();
  delete process.env.FILE_REFS_ENFORCE;
});

const DAY = 24 * 60 * 60 * 1000;

async function signUp(t: T, username: string) {
  return await t.mutation(api.auth.signup, {
    username,
    name: username,
    passwordHash: `hash-${username}`,
    recoveryKeyHash: `recovery-${username}`,
    deviceId: `device-${username}`,
  });
}

const holder = (id: string, field = "mediaStorageId", table = "messages"): FileHolder => ({
  table,
  id,
  field,
});

/** A stored blob claimed by [userId] (tracked, zero refs). */
async function claimed(t: T, userId: any, opts: { permanent?: boolean } = {}) {
  return await t.run(async (ctx: any) => {
    const id = await ctx.storage.store(new Blob(["jpeg"], { type: "image/jpeg" }));
    await claimUpload(ctx, id, userId, "media", opts);
    return id;
  });
}

const exists = (t: T, id: any) => t.run(async (ctx: any) => (await ctx.db.system.get(id)) !== null);
const ledger = (t: T, id: any) =>
  t.run(async (ctx: any) =>
    ctx.db.query("uploads").withIndex("by_storage", (q: any) => q.eq("storageId", id)).first(),
  );
const refCount = (t: T, id: any) =>
  t.run(async (ctx: any) =>
    (await ctx.db.query("fileRefs").withIndex("by_file_holder", (q: any) => q.eq("storageId", id)).collect()).length,
  );

describe("references", () => {
  test("a forwarded copy keeps the file until the last holder lets go", async () => {
    const t = convexTest(schema);
    const me = await signUp(t, "me");
    const file = await claimed(t, me.userId);
    const out = await t.run(async (ctx: any) => {
      await attachFile(ctx, file, holder("m1"));
      await attachFile(ctx, file, holder("m2"), { share: true });
      const first = await releaseFile(ctx, file, holder("m1"));
      return first;
    });
    expect(out).toEqual({ released: true, deleted: false });
    expect(await exists(t, file)).toBe(true);

    const last = await t.run((ctx: any) => releaseFile(ctx, file, holder("m2")));
    expect(last).toEqual({ released: true, deleted: true });
    expect(await exists(t, file)).toBe(false);
    expect(await ledger(t, file)).toBeNull();
  });

  test("releasing twice is a no-op, so it cannot take a shared file", async () => {
    const t = convexTest(schema);
    const me = await signUp(t, "me");
    const file = await claimed(t, me.userId);
    await t.run(async (ctx: any) => {
      await attachFile(ctx, file, holder("m1"));
      await attachFile(ctx, file, holder("m2"), { share: true });
      await releaseFile(ctx, file, holder("m1"));
    });
    const again = await t.run((ctx: any) => releaseFile(ctx, file, holder("m1")));
    expect(again).toEqual({ released: false, deleted: false });
    expect(await exists(t, file)).toBe(true);
  });

  test("a poster equal to its media is freed with the second field", async () => {
    const t = convexTest(schema);
    const me = await signUp(t, "me");
    const file = await claimed(t, me.userId);
    await t.run(async (ctx: any) => {
      await attachFile(ctx, file, holder("m1"));
      await attachFile(ctx, file, holder("m1", "posterStorageId"));
    });
    expect(await refCount(t, file)).toBe(2);
    const a = await t.run((ctx: any) => releaseFile(ctx, file, holder("m1")));
    expect(a.deleted).toBe(false);
    const b = await t.run((ctx: any) => releaseFile(ctx, file, holder("m1", "posterStorageId")));
    expect(b.deleted).toBe(true);
  });

  test("500 share-attaches leave the ledger document untouched", async () => {
    const t = convexTest(schema);
    const me = await signUp(t, "me");
    const file = await claimed(t, me.userId);
    await t.run((ctx: any) => attachFile(ctx, file, holder("first")));
    const before = await ledger(t, file);
    expect(before.zeroSince).toBeUndefined();
    await t.run(async (ctx: any) => {
      for (let i = 0; i < 500; i++) {
        await attachFile(ctx, file, holder(`copy${i}`), { share: true });
      }
    });
    expect(await ledger(t, file)).toEqual(before);
    expect(await refCount(t, file)).toBe(501);
  });

  test("attaching twice is idempotent, and an unclaimed file is refused", async () => {
    const t = convexTest(schema);
    const me = await signUp(t, "me");
    const file = await claimed(t, me.userId);
    await t.run(async (ctx: any) => {
      await attachFile(ctx, file, holder("m1"));
      await attachFile(ctx, file, holder("m1"));
    });
    expect(await refCount(t, file)).toBe(1);

    const loose = await t.run((ctx: any) => ctx.storage.store(new Blob(["x"])));
    await expect(
      t.run((ctx: any) => attachFile(ctx, loose, holder("m1"))),
    ).rejects.toThrow("FILE_NOT_CLAIMED");
  });

  test("a second exclusive holder throws under enforcement and only warns without", async () => {
    const t = convexTest(schema);
    const me = await signUp(t, "me");
    const file = await claimed(t, me.userId);
    await t.run((ctx: any) => attachFile(ctx, file, holder("m1")));

    const warn = vi.spyOn(console, "warn").mockImplementation(() => {});
    await t.run((ctx: any) => attachFile(ctx, file, holder("m2")));
    expect(warn).toHaveBeenCalledWith("file_in_use", expect.anything(), "messages", "mediaStorageId");
    expect(await refCount(t, file)).toBe(2);

    process.env.FILE_REFS_ENFORCE = "1";
    await expect(
      t.run((ctx: any) => attachFile(ctx, file, holder("m3"))),
    ).rejects.toThrow("FILE_IN_USE");
    // Sharing is still allowed under enforcement.
    await t.run((ctx: any) => attachFile(ctx, file, holder("m3"), { share: true }));
    expect(await refCount(t, file)).toBe(3);
  });

  test("transferFile moves the use without ever reaching zero", async () => {
    const t = convexTest(schema);
    const me = await signUp(t, "me");
    const file = await claimed(t, me.userId);
    await t.run(async (ctx: any) => {
      await attachFile(ctx, file, holder("req", "storageId", "roomChangeRequests"));
      await transferFile(
        ctx,
        file,
        holder("req", "storageId", "roomChangeRequests"),
        holder("room", "avatarStorageId", "rooms"),
      );
    });
    expect(await exists(t, file)).toBe(true);
    expect(await refCount(t, file)).toBe(1);
  });

  test("permanent files are never ref'd or freed", async () => {
    const t = convexTest(schema);
    const file = await claimed(t, undefined, { permanent: true });
    const out = await t.run(async (ctx: any) => {
      await attachFile(ctx, file, holder("s1", "stickerStorageId"), { share: true });
      return await releaseFile(ctx, file, holder("s1", "stickerStorageId"));
    });
    expect(out.deleted).toBe(false);
    expect(await refCount(t, file)).toBe(0);
    expect(await exists(t, file)).toBe(true);
    expect(await t.run((ctx: any) => fileInUse(ctx, file))).toBe(true);
  });

  test("freeing a file gives its bytes back, unless it was never charged", async () => {
    const t = convexTest(schema);
    const me = await signUp(t, "me");
    const file = await claimed(t, me.userId);
    const usage = () =>
      t.run(async (ctx: any) =>
        ctx.db.query("uploadUsage").withIndex("by_user", (q: any) => q.eq("userId", me.userId)).first(),
      );
    expect((await usage()).totalBytes).toBeGreaterThan(0);
    await t.run(async (ctx: any) => {
      await attachFile(ctx, file, holder("m1"));
      await releaseFile(ctx, file, holder("m1"));
    });
    expect((await usage()).totalBytes).toBe(0);
  });

  test("discardUpload frees an unattached file and spares an attached one", async () => {
    const t = convexTest(schema);
    const me = await signUp(t, "me");
    const kept = await claimed(t, me.userId);
    const dropped = await claimed(t, me.userId);
    await t.run(async (ctx: any) => {
      await attachFile(ctx, kept, holder("m1"));
      await discardUpload(ctx, kept, me.userId);
      await discardUpload(ctx, dropped, me.userId);
    });
    expect(await exists(t, kept)).toBe(true);
    expect(await exists(t, dropped)).toBe(false);
  });
});

describe("untracked (pre-refs) files", () => {
  async function sentPhoto(t: T) {
    const me = await signUp(t, "me");
    const roomId = await t.mutation(api.rooms.create, {
      sessionToken: me.token,
      userId: me.userId as any,
      name: "room",
      isPrivate: false,
    });
    const file = await t.run((ctx: any) =>
      ctx.storage.store(new Blob(["jpeg"], { type: "image/jpeg" })),
    );
    const messageId = await t.mutation(api.messages.send, {
      sessionToken: me.token,
      userId: me.userId as any,
      roomId,
      content: "",
      type: "image",
      mediaStorageId: file,
      clientId: "c1",
    } as any);
    return { me, roomId, file, messageId };
  }

  test("a legacy file is not deleted while another message still points at it", async () => {
    const t = convexTest(schema);
    const { me, roomId, file, messageId } = await sentPhoto(t);
    // Make it a pre-refs file: untracked, no refs.
    await t.run(async (ctx: any) => {
      const row = await ctx.db.query("uploads").withIndex("by_storage", (q: any) => q.eq("storageId", file)).first();
      await ctx.db.patch(row._id, { tracked: undefined, zeroSince: undefined });
      for (const r of await ctx.db.query("fileRefs").collect()) await ctx.db.delete(r._id);
    });
    const twin = await t.mutation(api.messages.send, {
      sessionToken: me.token,
      userId: me.userId as any,
      roomId,
      content: "",
      type: "image",
      mediaStorageId: file,
      clientId: "c2",
    } as any);

    const gone1 = await t.run(async (ctx: any) =>
      releaseMessageBlobs(ctx, await ctx.db.get(messageId)),
    );
    expect(gone1).toEqual([]);
    expect(await exists(t, file)).toBe(true);

    const gone2 = await t.run(async (ctx: any) => {
      await ctx.db.delete(messageId);
      return releaseMessageBlobs(ctx, await ctx.db.get(twin));
    });
    expect(gone2).toEqual([String(file)]);
    expect(await exists(t, file)).toBe(false);
  });

  test("a ledger-less old file is swept only after liftEpoch", async () => {
    vi.useFakeTimers();
    vi.setSystemTime(Date.UTC(2026, 9, 1));
    const t = convexTest(schema);
    const old = await t.run((ctx: any) => ctx.storage.store(new Blob(["old"])));
    vi.setSystemTime(Date.UTC(2026, 9, 25));

    await t.mutation(internal.files.sweepUnclaimed, {});
    expect(await exists(t, old)).toBe(true);

    // Refused while the backfill has not run.
    expect((await t.mutation(internal.files.liftEpoch, {})).lifted).toBe(false);
    await t.run((ctx: any) =>
      ctx.db.insert("fileBackfill", {
        startedAt: 1, lastProgressAt: 1, finishedAt: 2, status: "done", tableIdx: 0,
        cursor: null, restarts: 0, pages: 1, rowsScanned: 0, inserted: 0, existed: 0, missingFile: 0,
      }),
    );
    expect((await t.mutation(internal.files.liftEpoch, {})).lifted).toBe(true);
    await t.mutation(internal.files.sweepUnclaimed, {});
    expect(await exists(t, old)).toBe(false);
  });

  test("liftEpoch refuses while files are still untracked", async () => {
    const t = convexTest(schema);
    const me = await signUp(t, "me");
    const file = await claimed(t, me.userId);
    await t.run(async (ctx: any) => {
      const row = await ctx.db.query("uploads").withIndex("by_storage", (q: any) => q.eq("storageId", file)).first();
      await ctx.db.patch(row._id, { tracked: undefined });
      await ctx.db.insert("fileBackfill", {
        startedAt: 1, lastProgressAt: 1, finishedAt: 2, status: "done", tableIdx: 0,
        cursor: null, restarts: 0, pages: 1, rowsScanned: 0, inserted: 0, existed: 0, missingFile: 0,
      });
    });
    const out = await t.mutation(internal.files.liftEpoch, {});
    expect(out.lifted).toBe(false);
    expect(out.reason).toContain("untracked");
  });
});

describe("reapUnreferenced", () => {
  // Open the safety gate (see fileBackfill.test.ts for the gate itself).
  beforeEach(async () => {
    process.env.FILE_REFS_REAP = "1";
  });
  afterEach(() => {
    delete process.env.FILE_REFS_REAP;
  });
  const openGate = (t: T) =>
    t.run((ctx: any) =>
      ctx.db.insert("fileBackfill", {
        startedAt: 1, lastProgressAt: 1, finishedAt: 2, status: "done", tableIdx: 0, cursor: null,
        restarts: 0, pages: 1, rowsScanned: 0, inserted: 0, existed: 0, missingFile: 0, markedAt: 3,
      }),
    );

  test("waits out the grace period, then frees the file", async () => {
    vi.useFakeTimers();
    const t = convexTest(schema);
    await openGate(t);
    const me = await signUp(t, "me");
    const file = await claimed(t, me.userId);

    await t.mutation(internal.files.reapUnreferenced, {});
    expect(await exists(t, file)).toBe(true);

    vi.advanceTimersByTime(DAY + 60_000);
    const out = await t.mutation(internal.files.reapUnreferenced, {});
    expect(out.reaped).toBe(1);
    expect(await exists(t, file)).toBe(false);
    expect(await ledger(t, file)).toBeNull();
  });

  test("a ref that arrived clears the mark instead of freeing the file", async () => {
    vi.useFakeTimers();
    const t = convexTest(schema);
    await openGate(t);
    const me = await signUp(t, "me");
    const file = await claimed(t, me.userId);
    // A ref written without going through attachFile: the mark is still set.
    await t.run((ctx: any) =>
      ctx.db.insert("fileRefs", {
        storageId: file, holderTable: "messages", holderId: "m1", field: "mediaStorageId", createdAt: 1,
      }),
    );
    vi.advanceTimersByTime(DAY + 60_000);
    const out = await t.mutation(internal.files.reapUnreferenced, {});
    expect(out.reaped).toBe(0);
    expect(await exists(t, file)).toBe(true);
    expect((await ledger(t, file)).zeroSince).toBeUndefined();
  });

  test("attaching clears the mark", async () => {
    vi.useFakeTimers();
    const t = convexTest(schema);
    await openGate(t);
    const me = await signUp(t, "me");
    const file = await claimed(t, me.userId);
    expect((await ledger(t, file)).zeroSince).toBeDefined();
    await t.run((ctx: any) => attachFile(ctx, file, holder("m1")));
    vi.advanceTimersByTime(2 * DAY);
    await t.mutation(internal.files.reapUnreferenced, {});
    expect(await exists(t, file)).toBe(true);
  });

  test("pages through a backlog and skips permanent files", async () => {
    vi.useFakeTimers();
    const t = convexTest(schema);
    await openGate(t);
    const me = await signUp(t, "me");
    const ids: any[] = [];
    for (let i = 0; i < 130; i++) ids.push(await claimed(t, me.userId));
    const art = await claimed(t, undefined, { permanent: true });
    vi.advanceTimersByTime(DAY + 60_000);

    const first = await t.mutation(internal.files.reapUnreferenced, {});
    expect(first).toEqual({ reaped: 100, scanned: 100 });
    const second = await t.mutation(internal.files.reapUnreferenced, {});
    expect(second.reaped).toBe(30);
    const third = await t.mutation(internal.files.reapUnreferenced, {});
    expect(third).toEqual({ reaped: 0, scanned: 0 });
    expect(await exists(t, art)).toBe(true);
    expect(await exists(t, ids[0])).toBe(false);
  });
});

describe("repairRefs", () => {
  test("drops refs whose holder, field or ledger row is gone", async () => {
    const t = convexTest(schema);
    const me = await signUp(t, "me");
    const other = await signUp(t, "other");
    const live = await claimed(t, me.userId);
    const moved = await claimed(t, me.userId);
    const orphanFile = await t.run((ctx: any) => ctx.storage.store(new Blob(["x"])));
    const gone = await claimed(t, me.userId);

    await t.run(async (ctx: any) => {
      // A real holder whose field points at `live`.
      await ctx.db.patch(me.userId, { avatarStorageId: live });
      await attachFile(ctx, live, holder(me.userId, "avatarStorageId", "users"));
      // A real holder whose field no longer equals the file.
      await attachFile(ctx, moved, holder(other.userId, "avatarStorageId", "users"));
      // A holder that was deleted.
      await attachFile(ctx, gone, holder("k17aaaaaaaaaaaaaaaaaaaaaaaaaaaaa", "avatarStorageId", "users"));
      // A ref with no ledger row.
      await ctx.db.insert("fileRefs", {
        storageId: orphanFile, holderTable: "users", holderId: me.userId, field: "avatarStorageId", createdAt: 1,
      });
    });

    const out = await t.mutation(internal.files.repairRefs, {});
    expect(out.dropped).toBe(3);
    expect(await refCount(t, live)).toBe(1);
    expect(await refCount(t, moved)).toBe(0);
    expect(await refCount(t, gone)).toBe(0);
    // Emptied tracked files are marked, not freed on the spot.
    expect(await exists(t, moved)).toBe(true);
    expect((await ledger(t, moved)).zeroSince).toBeDefined();
  });
});

describe("zeroRefReport", () => {
  test("lists untracked files that nothing holds", async () => {
    const t = convexTest(schema);
    const me = await signUp(t, "me");
    const held = await claimed(t, me.userId);
    const loose = await claimed(t, me.userId);
    await t.run(async (ctx: any) => {
      for (const id of [held, loose]) {
        const row = await ctx.db.query("uploads").withIndex("by_storage", (q: any) => q.eq("storageId", id)).first();
        await ctx.db.patch(row._id, { tracked: undefined });
      }
      await ctx.db.insert("fileRefs", {
        storageId: held, holderTable: "messages", holderId: "m1", field: "mediaStorageId", createdAt: 1,
      });
    });
    const rep = await t.query(internal.files.zeroRefReport, {});
    expect(rep.zeroRef.map((r: any) => r.storageId)).toEqual([loose]);
    expect(rep.next).toBeNull();
  });
});
