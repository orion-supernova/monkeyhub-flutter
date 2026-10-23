import { convexTest } from "convex-test";
import { afterEach, beforeEach, describe, expect, test, vi } from "vitest";
import { api, internal } from "./_generated/api";
import { startUserDeletion, testHooks } from "./deletionCore";
import { drainDeletions, shrinkTuning } from "./deletionTestUtils";
import { REPORT_INBOX_USERNAME, SYSTEM_ROOM_MODERATION } from "./systemAccount";
import { REPORT_RETENTION_MS } from "./users";
import schema from "./schema";

/**
 * Reported content must outlive its author's account: the report snapshots the
 * words and holds its own ref on the media, until the report expires.
 */

type T = ReturnType<typeof convexTest>;

let restoreTuning: () => void;
beforeEach(() => {
  vi.useFakeTimers();
  vi.spyOn(console, "warn").mockImplementation(() => {});
  restoreTuning = shrinkTuning();
});
afterEach(() => {
  restoreTuning();
  testHooks.beforeStep = undefined;
  vi.restoreAllMocks();
  vi.useRealTimers();
});

async function signUp(t: T, username: string) {
  return (await t.mutation(api.auth.signup, {
    username,
    name: username,
    passwordHash: `hash-${username}`,
    recoveryKeyHash: `recovery-${username}`,
    deviceId: `dev-${username}`,
  } as any)) as any;
}
const as = (w: any) => ({ sessionToken: w.token, userId: w.userId as any });
const exists = async (t: T, id: any) =>
  (await t.run((ctx) => ctx.db.system.get(id))) !== null;

/** A stored file with a tracked ledger row, as an upload would leave it. */
const upload = (t: T, owner: any) =>
  t.run(async (ctx) => {
    const id = await ctx.storage.store(new Blob([new Uint8Array(64)], { type: "image/jpeg" }));
    await ctx.db.insert("uploads", {
      storageId: id, userId: owner, size: 64, createdAt: Date.now(), tracked: true,
    });
    return id;
  });

async function scene(t: T) {
  const staff = await signUp(t, REPORT_INBOX_USERNAME);
  const ada = await signUp(t, "ada");
  const bob = await signUp(t, "bob");
  const roomId = await t.mutation(api.rooms.create, {
    ...as(ada), name: "grp", isPrivate: false,
  } as any);
  await t.mutation(api.rooms.join, { ...as(bob), roomId } as any);
  return { staff, ada, bob, roomId };
}

const file = (t: T, id: any) =>
  t.run(async (ctx: any) => ({
    stored: (await ctx.db.system.get(id)) !== null,
    ledger: await ctx.db.query("uploads").withIndex("by_storage", (q: any) => q.eq("storageId", id)).first(),
    refs: (await ctx.db.query("fileRefs").withIndex("by_file_holder", (q: any) => q.eq("storageId", id)).collect()) as any[],
  }));

describe("report evidence survives deletion", () => {
  test("message: report, delete the account, staff still read it, expiry frees the file", async () => {
    const t = convexTest(schema);
    const { staff, ada, bob, roomId } = await scene(t);
    const blob = await upload(t, bob.userId);
    const longText = "x".repeat(2000) + " the end";
    const msgId = await t.run(async (ctx) => {
      const id = await ctx.db.insert("messages", {
        roomId, userId: bob.userId, content: longText, createdAt: Date.now(),
        type: "image", mediaStorageId: blob,
      } as any);
      await ctx.db.insert("fileRefs", {
        storageId: blob, holderTable: "messages", holderId: id.toString(),
        field: "mediaStorageId", createdAt: 1,
      });
      return id;
    });
    await t.mutation(api.users.report, {
      sessionToken: ada.token, reporterId: ada.userId, targetType: "message", targetId: msgId, reason: "HARASSMENT",
    } as any);
    const report: any = await t.run(async (ctx) => (await ctx.db.query("reports").collect())[0]);
    expect(report.evidence).toMatchObject({
      kind: "message", authorUsername: "bob", contentType: "image",
    });
    expect(report.evidence.text).toBe(longText);
    expect(report.evidenceMediaStorageId).toBe(blob);
    const refs = (await file(t, blob)).refs;
    expect(refs.some((r) => r.holderTable === "reports" && r.holderId === report._id)).toBe(true);

    // Bob's account goes, through the engine, and takes his message.
    await t.run((ctx) => startUserDeletion(ctx, bob.userId, { reason: "self" }));
    await drainDeletions(t, vi.runAllTimers);
    expect(await t.run((ctx) => ctx.db.get(bob.userId))).toBeNull();
    expect(await t.run((ctx) => ctx.db.get(msgId))).toBeNull();

    // The file and the words are still there, for staff only.
    expect((await file(t, blob)).stored).toBe(true);
    const ev: any = await t.query(api.moderation.reportEvidence, {
      ...as(staff), reportId: report._id,
    } as any);
    expect(ev.evidence.text).toBe(longText);
    expect(ev.evidence.authorUsername).toBe("bob");
    expect(ev.mediaUrl).toBeTruthy();
    await expect(
      t.query(api.moderation.reportEvidence, { ...as(ada), reportId: report._id } as any),
    ).rejects.toThrow("NOT_AUTHORIZED");

    // The card bubbles age out first; the report's own ref still holds the file.
    const room: any = await t.run(async (ctx) =>
      (await ctx.db.query("rooms").collect()).find((r) => r.system === SYSTEM_ROOM_MODERATION),
    );
    await t.run(async (ctx) => {
      for (const m of await ctx.db.query("messages").withIndex("by_room_time", (q) => q.eq("roomId", room._id)).collect()) {
        await ctx.db.patch(m._id, { createdAt: 1 });
      }
    });
    await t.mutation(internal.moderation.gcExpiredEvidence, {});
    expect((await file(t, blob)).stored).toBe(true);

    // The report expires: the ref goes and the file with it.
    await t.run((ctx) => ctx.db.patch(report._id, { createdAt: Date.now() - REPORT_RETENTION_MS - 1000 }));
    await t.mutation(internal.users.gcExpiredReports, {});
    expect(await t.run((ctx) => ctx.db.get(report._id))).toBeNull();
    const after = await file(t, blob);
    expect(after.stored).toBe(false);
    expect(after.refs).toHaveLength(0);
    expect(after.ledger).toBeNull();
  });

  test("moment: caption and photo are kept after the author deletes their account", async () => {
    const t = convexTest(schema);
    const { staff, ada, bob } = await scene(t);
    const blob = await upload(t, bob.userId);
    const momentId = await t.run(async (ctx) => {
      const id = await ctx.db.insert("moments", {
        userId: bob.userId, dayKey: "2026-10-23", caption: "my moment", mediaStorageId: blob,
        mediaKind: "image", createdAt: Date.now(), expiresAt: Date.now() + 1e9,
      } as any);
      await ctx.db.insert("fileRefs", {
        storageId: blob, holderTable: "moments", holderId: id.toString(),
        field: "mediaStorageId", createdAt: 1,
      });
      return id;
    });
    await t.mutation(api.users.report, {
      sessionToken: ada.token, reporterId: ada.userId, targetType: "moment", targetId: momentId, reason: "INAPPROPRIATE",
    } as any);
    const report: any = await t.run(async (ctx) => (await ctx.db.query("reports").collect())[0]);
    expect(report.evidence).toMatchObject({ kind: "moment", text: "my moment", authorUsername: "bob" });

    await t.run((ctx) => startUserDeletion(ctx, bob.userId, { reason: "self" }));
    await drainDeletions(t, vi.runAllTimers);
    expect(await t.run((ctx) => ctx.db.get(momentId))).toBeNull();
    expect((await file(t, blob)).stored).toBe(true);
    const ev: any = await t.query(api.moderation.reportEvidence, { ...as(staff), reportId: report._id } as any);
    expect(ev.evidence.text).toBe("my moment");
    expect(ev.mediaUrl).toBeTruthy();
  });

  test("a view-once message keeps its words but never its media", async () => {
    const t = convexTest(schema);
    const { ada, bob, roomId } = await scene(t);
    const blob = await upload(t, bob.userId);
    const msgId = await t.run((ctx) =>
      ctx.db.insert("messages", {
        roomId, userId: bob.userId, content: "look", createdAt: Date.now(),
        type: "image", mediaStorageId: blob, viewOnce: true,
      } as any),
    );
    await t.mutation(api.users.report, {
      sessionToken: ada.token, reporterId: ada.userId, targetType: "message", targetId: msgId, reason: "SPAM",
    } as any);
    const report: any = await t.run(async (ctx) => (await ctx.db.query("reports").collect())[0]);
    expect(report.evidence.text).toBe("look");
    expect(report.evidenceMediaStorageId).toBeUndefined();
  });
});
