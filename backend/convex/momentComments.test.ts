import { convexTest } from "convex-test";
import { describe, expect, test } from "vitest";
import { api, internal } from "./_generated/api";
import schema from "./schema";
import { MAX_MOMENT_REACTIONS_PER_PERSON } from "./feed";

/**
 * Comments on a highlight, executed: who may comment, how threads file, what
 * deleting takes with it, the reaction cap on both levels, and who is told.
 */

const DEVICE = "device-a";
const DAY = "2026-10-08";

async function signUp(t: ReturnType<typeof convexTest>, username: string) {
  const u = await t.mutation(api.auth.signup, {
    username,
    name: username,
    passwordHash: `hash-${username}`,
    recoveryKeyHash: `recovery-${username}`,
    deviceId: DEVICE,
  });
  return { ...u, username };
}

async function befriend(t: ReturnType<typeof convexTest>, a: any, b: any) {
  await t.mutation(api.friends.sendRequest, {
    sessionToken: a.token,
    userId: a.userId as any,
    friendUsername: b.username,
  });
  await t.mutation(api.friends.acceptRequest, {
    sessionToken: b.token,
    userId: b.userId as any,
    requesterId: a.userId as any,
  });
}

async function giveToken(t: ReturnType<typeof convexTest>, userId: any) {
  await t.run(async (ctx: any) => {
    await ctx.db.insert("userDevices", {
      userId,
      deviceId: DEVICE,
      platform: "android",
      fcmToken: `fcm-${userId}`,
      lastSeenAt: Date.now(),
      createdAt: Date.now(),
    });
  });
}

const as = (who: any) => ({ sessionToken: who.token, userId: who.userId as any });

async function setup() {
  const t = convexTest(schema);
  const author = await signUp(t, "author");
  const friend = await signUp(t, "friend");
  const other = await signUp(t, "other");
  const stranger = await signUp(t, "stranger");
  await befriend(t, author, friend);
  await befriend(t, author, other);
  const momentId = await t.mutation(api.feed.post, {
    ...as(author),
    dayKey: DAY,
    caption: "sunset",
  } as any);
  const list = (who: any) =>
    t.query(api.momentComments.list, { ...as(who), momentId } as any);
  const add = (who: any, extra: Record<string, unknown>) =>
    t.mutation(api.momentComments.add, { ...as(who), momentId, ...extra } as any);
  const count = async () =>
    (await t.run(async (ctx: any) => ctx.db.get(momentId)))?.commentCount ?? 0;
  return { t, author, friend, other, stranger, momentId, list, add, count };
}

describe("moment comments", () => {
  test("friends comment and reply; threads stay one level deep", async () => {
    const { friend, other, author, list, add, count } = await setup();
    const root = await add(friend, { text: "  gorgeous  " });
    const reply = await add(author, { text: "thanks!", replyToId: root });
    // Answering a reply files under the same root and names who it answers.
    const nested = await add(other, { text: "agreed", replyToId: reply });

    const res: any = await list(friend);
    const byId = new Map(res.comments.map((c: any) => [c._id, c]));
    expect((byId.get(root) as any).text).toBe("gorgeous");
    expect((byId.get(reply) as any).parentId).toBe(root);
    expect((byId.get(reply) as any).isAuthor).toBe(true);
    expect((byId.get(nested) as any).parentId).toBe(root);
    expect((byId.get(nested) as any).replyToName).toBe("author");
    expect(await count()).toBe(3);
  });

  test("a stranger can neither read nor comment", async () => {
    const { stranger, list, add } = await setup();
    expect(await list(stranger)).toBeNull();
    await expect(add(stranger, { text: "hi" })).rejects.toThrow("NOT_A_FRIEND");
  });

  test("empty and over-long comments are refused; a photo cannot be smuggled", async () => {
    const { friend, add } = await setup();
    await expect(add(friend, { text: "   " })).rejects.toThrow("EMPTY_COMMENT");
    await expect(add(friend, { text: "x".repeat(501) })).rejects.toThrow(
      "COMMENT_TOO_LONG",
    );
    // A "GIF" that is not a KLIPY URL resolves to nothing, so with no words
    // there is nothing to post.
    await expect(
      add(friend, {
        type: "gif",
        mediaSource: "klipy",
        mediaUrl: "https://evil.example/pixel.gif",
      }),
    ).rejects.toThrow("EMPTY_COMMENT");
    const gif = await add(friend, {
      type: "gif",
      mediaSource: "klipy",
      mediaUrl: "https://static.klipy.com/a.gif",
      mediaWidth: 200,
      mediaHeight: 150,
    });
    expect(gif).toBeTruthy();
  });

  test("deleting a root takes its replies; the author may delete anyone's", async () => {
    const { t, friend, other, author, list, add, count } = await setup();
    const root = await add(friend, { text: "one" });
    await add(other, { text: "two", replyToId: root });
    const keep = await add(other, { text: "three" });
    await expect(
      t.mutation(api.momentComments.remove, { ...as(other), commentId: root } as any),
    ).rejects.toThrow("NOT_YOUR_COMMENT");
    await t.mutation(api.momentComments.remove, {
      ...as(author),
      commentId: root,
    } as any);
    const res: any = await list(friend);
    expect(res.comments.map((c: any) => c._id)).toEqual([keep]);
    expect(await count()).toBe(1);
  });

  test("comment reactions cap at the highlight's per-person limit", async () => {
    const { t, friend, other, add } = await setup();
    const c = await add(friend, { text: "hey" });
    const react = (who: any, emoji: string) =>
      t.mutation(api.momentComments.react, { ...as(who), commentId: c, emoji } as any);
    const emoji = ["❤️", "😂", "😮", "🔥", "👏", "🎉"];
    for (const e of emoji.slice(0, MAX_MOMENT_REACTIONS_PER_PERSON)) {
      await react(other, e);
    }
    await expect(react(other, emoji[MAX_MOMENT_REACTIONS_PER_PERSON])).rejects.toThrow(
      "REACTION_LIMIT",
    );
    await react(other, emoji[0]); // idempotent at the cap
    await react(friend, emoji[MAX_MOMENT_REACTIONS_PER_PERSON]); // per person
  });

  test("the highlight itself caps reactions per person", async () => {
    const { t, friend, momentId } = await setup();
    const react = (emoji: string) =>
      t.mutation(api.feed.react, { ...as(friend), momentId, emoji } as any);
    const emoji = ["❤️", "😂", "😮", "🔥", "👏", "🎉"];
    for (const e of emoji.slice(0, MAX_MOMENT_REACTIONS_PER_PERSON)) await react(e);
    await expect(react(emoji[MAX_MOMENT_REACTIONS_PER_PERSON])).rejects.toThrow(
      "REACTION_LIMIT",
    );
  });

  test("deleting the moment takes the whole conversation", async () => {
    const { t, friend, author, momentId, add } = await setup();
    const c = await add(friend, { text: "hey" });
    await t.mutation(api.momentComments.react, {
      ...as(author),
      commentId: c,
      emoji: "❤️",
    } as any);
    await t.mutation(api.feed.remove, { ...as(author), momentId } as any);
    const left = await t.run(async (ctx: any) => ({
      comments: await ctx.db.query("momentComments").collect(),
      reactions: await ctx.db.query("momentCommentReactions").collect(),
    }));
    expect(left.comments).toHaveLength(0);
    expect(left.reactions).toHaveLength(0);
  });

  test("the comment push reaches the author and the person answered, never the commenter", async () => {
    const { t, friend, other, author, add } = await setup();
    for (const u of [author, friend, other]) await giveToken(t, u.userId);
    const root = await add(friend, { text: "nice" });
    const plan1: any = await t.query(internal.socialPush._commentAudience, {
      commentId: root,
    } as any);
    expect(plan1.recipients.map((r: any) => [r.userId, r.line])).toEqual([
      [author.userId, "commented"],
    ]);

    const reply = await add(other, { text: "+1", replyToId: root });
    const plan2: any = await t.query(internal.socialPush._commentAudience, {
      commentId: reply,
    } as any);
    const lines = new Map(plan2.recipients.map((r: any) => [r.userId, r.line]));
    expect(lines.get(friend.userId)).toBe("replied");
    expect(lines.get(author.userId)).toBe("commented");
    expect(lines.has(other.userId)).toBe(false);
  });
});
