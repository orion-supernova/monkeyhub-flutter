import { convexTest } from "convex-test";
import { afterEach, beforeEach, describe, expect, test } from "vitest";
import { api, internal } from "./_generated/api";
import schema from "./schema";
import { noteSolve } from "./recordBook";
import { syncProfile, tombstoneProfile } from "./profilesCore";
import { copyFlags } from "./profileCopyGate";

/**
 * Phase 6D: the moment, comment, reaction and record name copies sit behind
 * `PROFILE_COPIES`. On, nothing changes; off, no copy is written and every
 * reader (board, comments, records, pushes) shows the CURRENT name.
 */

type T = ReturnType<typeof convexTest>;
type Who = { token: string; userId: any; username: string };
const DAY = "2026-10-08";

beforeEach(() => {
  copyFlags.copies = true;
});
afterEach(() => {
  copyFlags.copies = true;
});

async function signUp(t: T, username: string): Promise<Who> {
  const u: any = await t.mutation(api.auth.signup, {
    username,
    name: username,
    passwordHash: `hash-${username}`,
    recoveryKeyHash: `recovery-${username}`,
    deviceId: `device-${username}`,
  });
  return { ...u, username };
}

async function befriend(t: T, a: Who, b: Who) {
  await t.mutation(api.friends.sendRequest, {
    sessionToken: a.token,
    userId: a.userId,
    friendUsername: b.username,
  });
  await t.mutation(api.friends.acceptRequest, {
    sessionToken: b.token,
    userId: b.userId,
    requesterId: a.userId,
  });
}

const as = (w: Who) => ({ sessionToken: w.token, userId: w.userId });

async function rename(t: T, w: Who, name: string) {
  await t.run(async (ctx: any) => {
    await ctx.db.patch(w.userId, { name });
    await syncProfile(ctx, w.userId);
  });
}

async function world() {
  const t = convexTest(schema);
  const author = await signUp(t, "author");
  const friend = await signUp(t, "friend");
  await befriend(t, author, friend);
  const momentId: any = await t.mutation(api.feed.post, {
    ...as(author),
    dayKey: DAY,
    caption: "sunset",
  } as any);
  return { t, author, friend, momentId };
}

async function giveToken(t: T, userId: any) {
  await t.run(async (ctx: any) => {
    const session = await ctx.db
      .query("sessions")
      .withIndex("by_user", (q: any) => q.eq("userId", userId))
      .first();
    await ctx.db.insert("userDevices", {
      userId,
      deviceId: session!.deviceId,
      platform: "android",
      fcmToken: `fcm-${userId}`,
      lastSeenAt: Date.now(),
      createdAt: Date.now(),
    });
  });
}

const row = (t: T, id: any): Promise<any> => t.run((ctx: any) => ctx.db.get(id));

describe("copies on: unchanged", () => {
  test("every writer still stamps its copy", async () => {
    const { t, author, friend, momentId } = await world();
    const m = await row(t, momentId);
    expect(m.authorName).toBe("author");
    expect(m.authorUsername).toBe("author");

    const rid: any = await t.mutation(api.feed.react, {
      ...as(friend), momentId, emoji: "🔥",
    } as any);
    const r = await row(t, rid);
    expect(r.userName).toBe("friend");
    expect(r.userUsername).toBe("friend");

    const root: any = await t.mutation(api.momentComments.add, {
      ...as(friend), momentId, text: "hi",
    } as any);
    const reply: any = await t.mutation(api.momentComments.add, {
      ...as(author), momentId, text: "yo", replyToId: root,
    } as any);
    const nested: any = await t.mutation(api.momentComments.add, {
      ...as(friend), momentId, text: "k", replyToId: reply,
    } as any);
    expect((await row(t, root)).userName).toBe("friend");
    expect((await row(t, nested)).replyToName).toBe("author");

    const cr: any = await t.mutation(api.momentComments.react, {
      ...as(author), commentId: root, emoji: "❤️",
    } as any);
    expect((await row(t, cr)).userName).toBe("author");
  });
});

describe("copies off", () => {
  test("no copy is written anywhere", async () => {
    copyFlags.copies = false;
    const { t, author, friend, momentId } = await world();
    const m = await row(t, momentId);
    expect(m.authorName).toBeUndefined();
    expect(m.authorUsername).toBeUndefined();
    expect(m.authorAvatarStorageId).toBeUndefined();

    const rid: any = await t.mutation(api.feed.react, {
      ...as(friend), momentId, emoji: "🔥",
    } as any);
    const r = await row(t, rid);
    for (const f of ["userName", "userUsername", "userAvatarStorageId", "userAvatarLevel"]) {
      expect(f in r).toBe(false);
    }

    const root: any = await t.mutation(api.momentComments.add, {
      ...as(friend), momentId, text: "hi",
    } as any);
    const reply: any = await t.mutation(api.momentComments.add, {
      ...as(author), momentId, text: "yo", replyToId: root,
    } as any);
    const nested: any = await t.mutation(api.momentComments.add, {
      ...as(friend), momentId, text: "k", replyToId: reply,
    } as any);
    for (const id of [root, reply, nested]) {
      const c = await row(t, id);
      expect("userName" in c).toBe(false);
      expect("replyToName" in c).toBe(false);
    }
    const cr: any = await t.mutation(api.momentComments.react, {
      ...as(author), commentId: root, emoji: "❤️",
    } as any);
    expect("userName" in (await row(t, cr))).toBe(false);
  });

  test("the board, comments and viewer show current names", async () => {
    copyFlags.copies = false;
    const { t, author, friend, momentId } = await world();
    await t.mutation(api.feed.react, { ...as(friend), momentId, emoji: "🔥" } as any);
    const root: any = await t.mutation(api.momentComments.add, {
      ...as(friend), momentId, text: "hi",
    } as any);
    const reply: any = await t.mutation(api.momentComments.add, {
      ...as(author), momentId, text: "yo", replyToId: root,
    } as any);
    await t.mutation(api.momentComments.add, {
      ...as(friend), momentId, text: "k", replyToId: reply,
    } as any);
    await t.mutation(api.momentComments.react, {
      ...as(author), commentId: root, emoji: "❤️",
    } as any);
    await rename(t, author, "Author Renamed");
    await rename(t, friend, "Friend Renamed");

    const boardRows: any[] = (await t.query(api.feed.board, {
      ...as(friend), dayKey: DAY,
    } as any)) as any;
    const items: any[] = Array.isArray(boardRows) ? boardRows : (boardRows as any).moments ?? [];
    const mine = items.find((x) => x._id === momentId);
    expect(mine.authorName).toBe("Author Renamed");
    expect(mine.reactors[0].name).toBe("Friend Renamed");

    // The author's own view of their own moment.
    const own: any = await t.query(api.feed.board, { ...as(author), dayKey: DAY } as any);
    const ownItems: any[] = Array.isArray(own) ? own : own.moments ?? [];
    expect(ownItems.find((x) => x._id === momentId).authorName).toBe("Author Renamed");

    const list: any = await t.query(api.momentComments.list, { ...as(friend), momentId } as any);
    const byText = new Map(list.comments.map((c: any) => [c.text, c]));
    expect((byText.get("hi") as any).userName).toBe("Friend Renamed");
    expect((byText.get("hi") as any).reactors[0].name).toBe("Author Renamed");
    expect((byText.get("k") as any).replyToName).toBe("Author Renamed");
  });

  test("a record reaction shows the current name", async () => {
    copyFlags.copies = false;
    const { t, author, friend } = await world();
    await t.run(async (ctx: any) => {
      await noteSolve(ctx, {
        userId: author.userId, game: "queens", score: 30000, dayKey: DAY, achievedAt: 1000,
      });
    });
    const rec: any = await t.run((ctx: any) => ctx.db.query("gameRecords").first());
    const id = await t.mutation(api.records.react, {
      ...as(friend), recordId: rec._id, emoji: "🔥",
    } as any);
    expect(id).toBeNull();
    const rr: any = await t.run((ctx: any) => ctx.db.query("recordReactions").first());
    expect("userName" in rr).toBe(false);
    await rename(t, friend, "Friend Renamed");
    const b: any = await t.query(api.records.board, as(author) as any);
    const reactors = Object.values(b.games).flat().flatMap((x: any) => x.reactors);
    expect(reactors.map((x: any) => x.name)).toEqual(["Friend Renamed"]);
  });

  test("pushes are built with the current name, after a rename", async () => {
    copyFlags.copies = false;
    const { t, author, friend, momentId } = await world();
    const rid: any = await t.mutation(api.feed.react, { ...as(friend), momentId, emoji: "🔥" } as any);
    const root: any = await t.mutation(api.momentComments.add, {
      ...as(friend), momentId, text: "hi",
    } as any);
    await giveToken(t, author.userId);
    await giveToken(t, friend.userId);
    await rename(t, author, "Author Renamed");
    await rename(t, friend, "Friend Renamed");

    const moment: any = await t.query(internal.socialPush._momentAudience, { momentId });
    expect(moment.authorName).toBe("Author Renamed");
    const comment: any = await t.query(internal.socialPush._commentAudience, { commentId: root });
    expect(comment.commenterName).toBe("Friend Renamed");
    const reaction: any = await t.query(internal.socialPush._reactionAudience, { momentReactionId: rid });
    expect(reaction.reactorName).toBe("Friend Renamed");
  });
});

describe("copies on, rename", () => {
  test("readers show the live name over the stored copy", async () => {
    const { t, author, friend, momentId } = await world();
    await t.mutation(api.feed.react, { ...as(friend), momentId, emoji: "🔥" } as any);
    await rename(t, author, "Author Renamed");
    const items: any = await t.query(api.feed.board, { ...as(friend), dayKey: DAY } as any);
    const list = Array.isArray(items) ? items : items.moments ?? [];
    expect(list.find((x: any) => x._id === momentId).authorName).toBe("Author Renamed");
  });
});

describe("review fixes", () => {
  test("the viewer's own moments are named from the profile, not the users row", async () => {
    copyFlags.copies = false;
    const { t, author, momentId } = await world();
    // Profile says one thing, the users row another: only the profile counts.
    await t.run(async (ctx: any) => {
      await ctx.db.patch(author.userId, { name: "Row Name" });
    });
    const own: any = await t.query(api.feed.board, { ...as(author), dayKey: DAY } as any);
    const items: any[] = Array.isArray(own) ? own : own.moments ?? [];
    expect(items.find((x) => x._id === momentId).authorName).toBe("author");
  });

  test("a deleting account is an empty name, never its internal handle", async () => {
    copyFlags.copies = false;
    const { t, author, friend, momentId } = await world();
    const root: any = await t.mutation(api.momentComments.add, {
      ...as(author), momentId, text: "hi",
    } as any);
    await t.mutation(api.momentComments.react, { ...as(friend), commentId: root, emoji: "❤️" } as any);
    await t.mutation(api.feed.react, { ...as(friend), momentId, emoji: "🔥" } as any);
    await t.run(async (ctx: any) => {
      await ctx.db.patch(friend.userId, { deletingAt: Date.now(), name: "deleted:abc", username: "deleted:abc" });
      await tombstoneProfile(ctx, friend.userId);
    });
    const list: any = await t.query(api.momentComments.list, { ...as(author), momentId } as any);
    expect(list.comments[0].reactors.map((r: any) => r.name)).toEqual([]);
    const board: any = await t.query(api.feed.board, { ...as(author), dayKey: DAY } as any);
    const items: any[] = Array.isArray(board) ? board : board.moments ?? [];
    for (const r of items.find((x) => x._id === momentId).reactors) {
      expect(r.name).toBe("");
      expect(r.username).toBe("");
    }
  });
});
