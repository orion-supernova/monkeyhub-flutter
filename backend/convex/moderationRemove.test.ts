import { convexTest } from "convex-test";
import { describe, expect, test } from "vitest";
import { api } from "./_generated/api";
import schema from "./schema";
import { REPORT_INBOX_USERNAME } from "./systemAccount";

/**
 * Phase 4G: a moderator removes a reported moment or comment from its card.
 * Goes through the same delete cores as the author's own delete, so children
 * and files go with it; staff only; idempotent; the card flips to done.
 */

type T = ReturnType<typeof convexTest>;

async function signUp(t: T, username: string) {
  const u = await t.mutation(api.auth.signup, {
    username,
    name: username,
    passwordHash: `hash-${username}`,
    recoveryKeyHash: `recovery-${username}`,
    deviceId: `device-${username}`,
  } as any);
  return { ...u, username };
}
const as = (who: any) => ({ sessionToken: who.token, userId: who.userId as any });
const store = (t: T) =>
  t.run((ctx) => ctx.storage.store(new Blob([new Uint8Array(10)], { type: "image/jpeg" })));
const exists = (t: T, id: any) => t.run(async (ctx) => (await ctx.db.system.get(id)) !== null);
const get = (t: T, id: any): Promise<any> => t.run((ctx) => ctx.db.get(id));
const count = (t: T, table: string) =>
  t.run(async (ctx) => (await ctx.db.query(table as any).collect()).length);

async function scene() {
  const t = convexTest(schema);
  const staff = await signUp(t, REPORT_INBOX_USERNAME);
  const author = await signUp(t, "author");
  const reporter = await signUp(t, "reporter");
  const media = await store(t);
  const { momentId, rootId, replyId } = await t.run(async (ctx: any) => {
    const momentId = await ctx.db.insert("moments", {
      userId: author.userId, dayKey: "2026-10-22", createdAt: 1, expiresAt: 2,
      authorName: "author", authorUsername: "author", caption: "bad", mediaStorageId: media,
      commentCount: 2,
    });
    await ctx.db.insert("momentReactions", { momentId, userId: author.userId, emoji: "x", createdAt: 1 });
    const rootId = await ctx.db.insert("momentComments", {
      momentId, userId: author.userId, userName: "author", text: "rude", createdAt: 1,
    });
    const replyId = await ctx.db.insert("momentComments", {
      momentId, userId: reporter.userId, userName: "reporter", text: "hey", createdAt: 2, parentId: rootId,
    });
    await ctx.db.insert("momentCommentReactions", {
      commentId: replyId, momentId, userId: author.userId, emoji: "x", createdAt: 1,
    });
    return { momentId, rootId, replyId };
  });
  const file = async (targetType: string, targetId: any) => {
    await t.mutation(api.users.report, {
      sessionToken: reporter.token, reporterId: reporter.userId, targetType, targetId, reason: "SPAM",
    } as any);
    const reports = await t.run((ctx) => ctx.db.query("reports").collect());
    return reports.find((r: any) => r.targetType === targetType && r.targetId === targetId)! as any;
  };
  const act = (who: any, reportId: any, action = "removeContent") =>
    t.mutation(api.moderation.act, { ...as(who), reportId, action } as any);
  return { t, staff, author, reporter, media, momentId, rootId, replyId, file, act };
}

describe("moderator removes reported moments and comments", () => {
  test("the card says there is something to remove", async () => {
    const { t, momentId, file } = await scene();
    const report = await file("moment", momentId);
    expect((await get(t, report.cardMessageId)).moderationCard.hasContent).toBe(true);
  });

  test("a moment goes with its children and files; the card flips and keeps its excerpt", async () => {
    const { t, staff, momentId, media, file, act } = await scene();
    const report = await file("moment", momentId);
    const before = (await get(t, report.cardMessageId)).content;
    expect(before).toContain("» bad");
    await act(staff, report._id);

    expect(await get(t, momentId)).toBeNull();
    expect(await exists(t, media)).toBe(false);
    for (const table of ["momentReactions", "momentComments", "momentCommentReactions"]) {
      expect(await count(t, table)).toBe(0);
    }
    const after = await get(t, report._id);
    expect(after.status).toBe("actioned");
    expect(after.action).toBe("removeContent");
    const card = await get(t, report.cardMessageId);
    expect(card.moderationCard.hasContent).toBe(false);
    expect(card.content).toBe(before);
  });

  test("a comment takes its replies; the moment survives with a true count", async () => {
    const { t, staff, momentId, rootId, replyId, file, act } = await scene();
    const report = await file("comment", rootId);
    await act(staff, report._id);
    expect(await get(t, rootId)).toBeNull();
    expect(await get(t, replyId)).toBeNull();
    expect(await count(t, "momentCommentReactions")).toBe(0);
    expect((await get(t, momentId)).commentCount).toBe(0);
    expect((await get(t, report.cardMessageId)).moderationCard.hasContent).toBe(false);
  });

  test("a non-staff caller is refused and nothing is removed", async () => {
    const { t, author, reporter, momentId, file, act } = await scene();
    const report = await file("moment", momentId);
    await expect(act(reporter, report._id)).rejects.toThrow("NOT_AUTHORIZED");
    await expect(act(author, report._id)).rejects.toThrow("NOT_AUTHORIZED");
    expect(await get(t, momentId)).not.toBeNull();
  });

  test("a second removal is a no-op that still marks the report", async () => {
    const { t, staff, momentId, file, act } = await scene();
    const report = await file("moment", momentId);
    await act(staff, report._id);
    const again: any = await act(staff, report._id);
    expect(again.ok).toBe(true);
    expect(again.outcome).toContain("already gone");
    expect((await get(t, report._id)).status).toBe("actioned");
  });

  test("a report about an already-deleted moment can still be marked", async () => {
    const { t, staff, author, momentId, file, act } = await scene();
    const report = await file("moment", momentId);
    await t.mutation(api.feed.remove, { ...as(author), momentId } as any);
    const res: any = await act(staff, report._id);
    expect(res.outcome).toContain("already gone");
    expect((await get(t, report._id)).status).toBe("actioned");
  });

  test("works when the author's account is already gone", async () => {
    const { t, staff, author, momentId, media, file, act } = await scene();
    const report = await file("moment", momentId);
    await t.run((ctx: any) => ctx.db.delete(author.userId));
    await act(staff, report._id);
    expect(await get(t, momentId)).toBeNull();
    expect(await exists(t, media)).toBe(false);
  });

  test("refuses removeContent on a message or user report", async () => {
    const { t, staff, author, file, act } = await scene();
    const report = await file("user", author.userId.toString());
    await expect(act(staff, report._id)).rejects.toThrow("NOT_REMOVABLE");
    expect((await get(t, report._id)).status).toBe("open");
  });
});
