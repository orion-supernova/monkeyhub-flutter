import { convexTest } from "convex-test";
import { afterEach, beforeEach, describe, expect, test, vi } from "vitest";
import { internal } from "./_generated/api";
import { MAX_RESTARTS, STALL_MS } from "./fileBackfill";
import schema from "./schema";

/**
 * Phase 3 P3: the file-refs backfill (scan), its verification gate and the mark
 * step, plus the reaper's safety gate. Legacy files here are blobs with no
 * ledger row, as everything from before refs is.
 */

type T = ReturnType<typeof convexTest>;

beforeEach(() => {
  vi.useFakeTimers();
});
afterEach(() => {
  vi.useRealTimers();
  vi.restoreAllMocks();
  delete process.env.FILE_REFS_REAP;
});

const DAY = 24 * 60 * 60 * 1000;
const drain = (t: T) => t.finishAllScheduledFunctions(vi.runAllTimers);

const latest = (t: T) => t.query(internal.fileBackfill.latest, {});
const refsOf = (t: T): Promise<any[]> => t.run((ctx: any) => ctx.db.query("fileRefs").collect());
const ledgerOf = (t: T, id: any): Promise<any> =>
  t.run((ctx: any) =>
    ctx.db.query("uploads").withIndex("by_storage", (q: any) => q.eq("storageId", id)).first(),
  );
const stored = (t: T, id: any) => t.run(async (ctx: any) => (await ctx.db.system.get(id)) !== null);

async function runScan(t: T) {
  await t.mutation(internal.fileBackfill.start, {});
  await drain(t);
}

/** A verified, finished integrity run that started after the scan. */
async function verify(t: T) {
  vi.advanceTimersByTime(1000);
  await t.mutation(internal.integrity.start, {});
  await drain(t);
}

async function world(t: T, opts: { messages?: number } = {}) {
  return await t.run(async (ctx: any) => {
    const blob = () => ctx.storage.store(new Blob(["x"]));
    const u = await ctx.db.insert("users", { username: "u", passwordHash: "x", createdAt: 1 });
    const avatar = await blob();
    await ctx.db.patch(u, { avatarStorageId: avatar });
    const room = await ctx.db.insert("rooms", {
      name: "r", createdBy: u, createdAt: 1, isPrivate: false, memberCount: 0,
    });
    const messageFiles: any[] = [];
    for (let i = 0; i < (opts.messages ?? 2); i++) {
      const media = await blob();
      messageFiles.push(media);
      await ctx.db.insert("messages", {
        roomId: room, userId: u, content: "", createdAt: i, type: "image", mediaStorageId: media,
      });
    }
    return { u, room, avatar, messageFiles };
  });
}

describe("scan", () => {
  test("pages across tables, adopts ledger rows, and a re-run inserts nothing", async () => {
    const t = convexTest(schema);
    const w = await world(t, { messages: 105 }); // messages page at 100
    await runScan(t);

    const s = (await latest(t))!;
    expect(s.status).toBe("done");
    expect(s.inserted).toBe(106); // 105 photos + the avatar
    expect(s.existed).toBe(0);
    expect(s.missingFile).toBe(0);
    expect(s.progress.pages).toBeGreaterThan(s.progress.tablesTotal); // messages took two pages
    expect(await refsOf(t)).toHaveLength(106);

    const led = await ledgerOf(t, w.messageFiles[0]);
    expect(led.tracked).toBeUndefined();
    expect(led).toMatchObject({ userId: w.u, uncounted: true, size: expect.any(Number) });
    expect((await ledgerOf(t, w.avatar)).userId).toBe(w.u);

    await runScan(t);
    const again = (await latest(t))!;
    expect(again.inserted).toBe(0);
    expect(again.existed).toBe(106);
    expect(await refsOf(t)).toHaveLength(106);
  });

  test("a missing file is tallied, not thrown, and the rest still lands", async () => {
    const t = convexTest(schema);
    const w = await world(t);
    await t.run((ctx: any) => ctx.storage.delete(w.messageFiles[0]));
    await runScan(t);
    const s = (await latest(t))!;
    expect(s.status).toBe("done");
    expect(s.missingFile).toBe(1);
    expect(s.inserted).toBe(2); // the other photo and the avatar
  });

  test("skips what legitimately holds no ref, and owns personal stickers by their pack owner", async () => {
    const t = convexTest(schema);
    const w = await world(t, { messages: 0 });
    const out = await t.run(async (ctx: any) => {
      const blob = () => ctx.storage.store(new Blob(["x"]));
      const mk = (kind: string, ownerId?: any) =>
        ctx.db.insert("stickerPacks", { slug: kind, title: kind, kind, ownerId, order: 0, createdAt: 1 });
      const personal = await mk("personal", w.u);
      const official = await mk("official");
      const sticker = (packId: any, storageId: any, extra: object = {}) =>
        ctx.db.insert("stickers", {
          packId, storageId, format: "image", emoji: "x", width: 1, height: 1, order: 0, createdAt: 1, ...extra,
        });
      const mine = await blob();
      const art = await blob();
      const dead = await blob();
      const packed = await blob();
      const retired = await blob();
      await sticker(personal, mine);
      await sticker(official, art);
      // Official art retired before the scan, still shown by an old message.
      await sticker(official, retired, { deletedAt: 5 });
      await ctx.db.insert("messages", {
        roomId: w.room, userId: w.u, content: "", createdAt: 2, type: "sticker",
        stickerStorageId: retired, mediaSource: "pack",
      });
      await sticker(personal, dead, { deletedAt: 5 });
      // A sent official sticker and a decided change request hold no ref.
      await ctx.db.insert("messages", {
        roomId: w.room, userId: w.u, content: "", createdAt: 1, type: "sticker",
        stickerStorageId: art, mediaSource: "pack",
      });
      await ctx.db.insert("roomChangeRequests", {
        roomId: w.room, userId: w.u, field: "avatar", storageId: packed, status: "approved", createdAt: 1,
      });
      return { mine, art, dead, packed, retired };
    });
    await runScan(t);

    expect((await ledgerOf(t, out.mine)).userId).toBe(w.u);
    // Official art, live or retired, is pinned permanent and never ref'd.
    expect(await ledgerOf(t, out.art)).toMatchObject({ permanent: true, uncounted: true });
    expect(await ledgerOf(t, out.retired)).toMatchObject({ permanent: true });
    expect(await ledgerOf(t, out.dead)).toBeNull();
    expect(await ledgerOf(t, out.packed)).toBeNull();
    const refs = await refsOf(t);
    expect(refs.filter((r: any) => r.storageId === out.art || r.storageId === out.retired)).toHaveLength(0);
  });
});

describe("stalls", () => {
  test("a stalled scan is resumed from its cursor, and failed after 3 resumes", async () => {
    const t = convexTest(schema);
    await world(t, { messages: 3 });
    const warn = vi.spyOn(console, "warn").mockImplementation(() => {});

    const first = await t.mutation(internal.fileBackfill.start, {});
    expect(first.started).toBe(true);
    // No cron work yet: a second start while it is fresh is a no-op.
    expect((await t.mutation(internal.fileBackfill.start, {})).reason).toBe("running");
    expect(await t.mutation(internal.fileBackfill.resumeStalled, {})).toBeNull();

    // Pretend the chain died: drop the scheduled step, then go silent.
    await t.run(async (ctx: any) => {
      for (const f of await ctx.db.system.query("_scheduled_functions").collect()) {
        await ctx.scheduler.cancel(f._id);
      }
    });
    vi.advanceTimersByTime(STALL_MS + 1000);
    expect(await t.mutation(internal.fileBackfill.resumeStalled, {})).toBe("resumed");
    await drain(t);
    expect((await latest(t))!.status).toBe("done");
    expect((await latest(t))!.progress.restarts).toBe(1);

    // A run that keeps stalling is failed, and start then begins a fresh one.
    await t.run(async (ctx: any) => {
      const run = await ctx.db.query("fileBackfill").order("desc").first();
      await ctx.db.patch(run._id, { status: "running", restarts: MAX_RESTARTS, lastProgressAt: 0 });
    });
    expect(await t.mutation(internal.fileBackfill.resumeStalled, {})).toBe("failed");
    expect((await latest(t))!.status).toBe("failed");
    expect(warn).toHaveBeenCalled();
    const fresh = await t.mutation(internal.fileBackfill.start, {});
    expect(fresh).toMatchObject({ started: true, reason: "new" });
  });
});

describe("markTracked", () => {
  test("refuses before a scan, before a verification, and on a dirty verification", async () => {
    const t = convexTest(schema);
    const w = await world(t);
    vi.spyOn(console, "warn").mockImplementation(() => {});

    const noScan = await t.mutation(internal.fileBackfill.markTracked, {});
    expect(noScan.ok).toBe(false);
    expect(noScan.refused).toContain("scan has not finished");

    await runScan(t);
    const noVerify = await t.mutation(internal.fileBackfill.markTracked, {});
    expect(noVerify.refused).toContain("integrity run that started after the scan");

    // An integrity run from BEFORE the scan does not count either.
    await t.mutation(internal.integrity.start, {});
    await drain(t);
    const old = await t.mutation(internal.fileBackfill.markTracked, {});
    expect(old.refused).toContain("integrity run that started after the scan");

    // A use with no ref, written after the scan: the verification catches it.
    await t.run((ctx: any) =>
      ctx.db.insert("messages", {
        roomId: w.room, userId: w.u, content: "", createdAt: 9, type: "image",
        mediaStorageId: w.messageFiles[0],
      }),
    );
    await t.run(async (ctx: any) => {
      const refs = await ctx.db.query("fileRefs").collect();
      for (const r of refs) if (r.field === "mediaStorageId") await ctx.db.delete(r._id);
    });
    await runScan(t); // re-seeds refs...
    await t.run(async (ctx: any) => {
      const refs = await ctx.db.query("fileRefs").collect();
      for (const r of refs) if (r.field === "mediaStorageId") await ctx.db.delete(r._id);
    });
    await verify(t); // ...which we then take away again, so the run is dirty
    const dirty = await t.mutation(internal.fileBackfill.markTracked, {});
    expect(dirty.ok).toBe(false);
    expect(dirty.refused).toContain("file-ref violations");
    expect((await ledgerOf(t, w.avatar)).tracked).toBeUndefined();
  });

  test("dryRun reports without writing", async () => {
    const t = convexTest(schema);
    const w = await world(t);
    await runScan(t);
    await verify(t);
    const out = await t.mutation(internal.fileBackfill.markTracked, { dryRun: true });
    expect(out).toMatchObject({ ok: true, marked: 0 });
    expect((await ledgerOf(t, w.avatar)).tracked).toBeUndefined();
    expect((await latest(t))!.markedAt).toBeNull();
  });

  test("flips untracked files to tracked in batches, queues the unused ones, keeps permanent art", async () => {
    const t = convexTest(schema);
    const w = await world(t, { messages: 120 });
    const extra = await t.run(async (ctx: any) => {
      const blob = () => ctx.storage.store(new Blob(["x"]));
      // Legacy ledger rows: one nobody uses, one permanent art with no ref.
      const unused = await blob();
      await ctx.db.insert("uploads", { storageId: unused, userId: w.u, size: 1, createdAt: 1 });
      const art = await blob();
      await ctx.db.insert("uploads", { storageId: art, size: 1, createdAt: 1, permanent: true });
      return { unused, art };
    });
    await runScan(t);
    await verify(t);

    const first = await t.mutation(internal.fileBackfill.markTracked, {});
    expect(first).toMatchObject({ ok: true, marked: 100, done: false });
    await drain(t); // the chain finishes the rest
    const s = (await latest(t))!;
    expect(s.markedAt).not.toBeNull();
    expect(s.marked).toBe(123); // 120 photos + avatar + unused + art
    expect(s.queuedForReap).toBe(1);

    const untracked = await t.run((ctx: any) =>
      ctx.db.query("uploads").withIndex("by_tracked", (q: any) => q.eq("tracked", undefined)).collect(),
    );
    expect(untracked).toEqual([]);
    expect((await ledgerOf(t, w.messageFiles[0])).zeroSince).toBeUndefined();
    expect((await ledgerOf(t, extra.unused)).zeroSince).toBeGreaterThan(0);
    expect((await ledgerOf(t, extra.art)).zeroSince).toBeUndefined();

    // Marking again is harmless.
    expect(await t.mutation(internal.fileBackfill.markTracked, {})).toMatchObject({ ok: true, marked: 0, done: true });
  });
});

describe("end to end", () => {
  test("after marking, the unused legacy file is reaped a day later and the used ones stay", async () => {
    const t = convexTest(schema);
    const w = await world(t);
    const unused = await t.run(async (ctx: any) => {
      const id = await ctx.storage.store(new Blob(["x"]));
      await ctx.db.insert("uploads", { storageId: id, userId: w.u, size: 1, createdAt: 1 });
      return id;
    });
    await runScan(t);
    await verify(t);
    await t.mutation(internal.fileBackfill.markTracked, {});
    await drain(t);
    process.env.FILE_REFS_REAP = "1";

    // Inside the grace period nothing goes.
    expect((await t.mutation(internal.files.reapUnreferenced, {})).reaped).toBe(0);
    vi.advanceTimersByTime(DAY + 60_000);
    const out = await t.mutation(internal.files.reapUnreferenced, {});
    expect(out).toMatchObject({ reaped: 1, scanned: 1 });
    expect(await stored(t, unused)).toBe(false);
    expect(await stored(t, w.avatar)).toBe(true);
    expect(await stored(t, w.messageFiles[0])).toBe(true);
  });
});

describe("reaper gate", () => {
  const unusedTracked = async (t: T) => {
    const id = await t.run(async (ctx: any) => {
      const id = await ctx.storage.store(new Blob(["x"]));
      await ctx.db.insert("uploads", {
        storageId: id, size: 1, createdAt: 1, tracked: true, zeroSince: Date.now(),
      });
      return id;
    });
    vi.advanceTimersByTime(DAY + 60_000);
    return id;
  };
  const markRun = (t: T, markedAt?: number) =>
    t.run((ctx: any) =>
      ctx.db.insert("fileBackfill", {
        startedAt: 1, lastProgressAt: 1, finishedAt: 2, status: "done", tableIdx: 0, cursor: null,
        restarts: 0, pages: 1, rowsScanned: 0, inserted: 0, existed: 0, missingFile: 0, markedAt,
      }),
    );

  test("deletes nothing without a marked backfill, nor without FILE_REFS_REAP, and says what it would do", async () => {
    const t = convexTest(schema);
    const warn = vi.spyOn(console, "warn").mockImplementation(() => {});
    const file = await unusedTracked(t);

    // Neither condition.
    const none = await t.mutation(internal.files.reapUnreferenced, {});
    expect(none).toMatchObject({ reaped: 0, gated: true, wouldReap: 1 });
    expect(await stored(t, file)).toBe(true);
    expect(warn).toHaveBeenCalledWith(expect.stringContaining("would have reaped 1"));

    // The env alone is not enough: no backfill row, then an unmarked one.
    process.env.FILE_REFS_REAP = "1";
    expect((await t.mutation(internal.files.reapUnreferenced, {})).gated).toBe(true);
    await markRun(t);
    expect((await t.mutation(internal.files.reapUnreferenced, {})).gated).toBe(true);
    expect(await stored(t, file)).toBe(true);
    delete process.env.FILE_REFS_REAP;

    // A marked backfill alone is not enough either.
    await markRun(t, 5);
    expect((await t.mutation(internal.files.reapUnreferenced, {})).gated).toBe(true);
    expect(await stored(t, file)).toBe(true);
    expect((await ledgerOf(t, file)).zeroSince).toBeGreaterThan(0); // the mark is kept for later
  });

  test("with both, the reaper frees the file", async () => {
    const t = convexTest(schema);
    const file = await unusedTracked(t);
    await markRun(t, 5);
    process.env.FILE_REFS_REAP = "1";
    const out = await t.mutation(internal.files.reapUnreferenced, {});
    expect(out).toMatchObject({ reaped: 1 });
    expect(await stored(t, file)).toBe(false);
  });

  test("a new scan after marking closes the gate again", async () => {
    const t = convexTest(schema);
    const file = await unusedTracked(t);
    await markRun(t, 5);
    process.env.FILE_REFS_REAP = "1";
    await t.mutation(internal.fileBackfill.start, {});
    expect((await t.mutation(internal.files.reapUnreferenced, {})).gated).toBe(true);
    expect(await stored(t, file)).toBe(true);
  });
});
