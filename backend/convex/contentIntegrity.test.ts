import { convexTest } from "convex-test";
import { describe, expect, test } from "vitest";
import { api, internal } from "./_generated/api";
import { releaseMessageBlobs } from "./files";
import type { Id } from "./_generated/dataModel";
import schema from "./schema";

/**
 * Phase 0 content-integrity fixes: board reactors follow LIVE privacy and
 * blocks, poll respondents are named, a burned view-once message keeps no
 * caption, and a shared poster survives the other owner's delete.
 */

const DAY = "2026-10-22";

async function signUp(t: ReturnType<typeof convexTest>, username: string, name = username) {
  const u = await t.mutation(api.auth.signup, {
    username,
    name,
    passwordHash: `hash-${username}`,
    recoveryKeyHash: `recovery-${username}`,
    deviceId: `device-${username}`,
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

const as = (who: any) => ({ sessionToken: who.token, userId: who.userId as any });

const store = (t: ReturnType<typeof convexTest>, type = "image/jpeg", bytes = 512) =>
  t.run((ctx) => ctx.storage.store(new Blob([new Uint8Array(bytes)], { type })));

const exists = async (t: ReturnType<typeof convexTest>, id: any) =>
  (await t.run((ctx) => ctx.db.system.get(id))) !== null;

/** author is friends with viewer AND reactor; viewer and reactor are strangers. */
async function boardSetup() {
  const t = convexTest(schema);
  const author = await signUp(t, "author");
  const viewer = await signUp(t, "viewer");
  const reactor = await signUp(t, "reactor");
  await befriend(t, author, viewer);
  await befriend(t, author, reactor);
  const face = await store(t);
  await t.run((ctx) => ctx.db.patch(reactor.userId as any, { avatarStorageId: face }));
  const momentId = await t.mutation(api.feed.post, {
    ...as(author),
    dayKey: DAY,
    caption: "hi",
  } as any);
  const reactorsSeenBy = async (who: any) => {
    const rows: any[] = await t.query(api.feed.board, { ...as(who), dayKey: DAY } as any);
    const board: any = rows;
    const list: any[] = (board.moments ?? board.items ?? board) as any[];
    const m = list.find((x: any) => x._id === momentId);
    return m ? m.reactors : null;
  };
  return { t, author, viewer, reactor, face, momentId, reactorsSeenBy };
}

describe("board reactors follow live privacy", () => {
  test("a reactor who later hides their photo stops showing it", async () => {
    const { t, reactor, face, momentId, reactorsSeenBy, viewer } = await boardSetup();
    await t.mutation(api.users.updateVisibility, { ...as(reactor), avatar: "public" } as any);
    await t.mutation(api.feed.react, { ...as(reactor), momentId, emoji: "❤️" } as any);
    // Public at reaction time: the face shows.
    expect((await reactorsSeenBy(viewer))[0].avatarStorageId).toBe(face);

    // Friends-only now; the viewer is a stranger to the reactor.
    await t.mutation(api.users.updateVisibility, { ...as(reactor), avatar: "friends" } as any);
    const after = await reactorsSeenBy(viewer);
    expect(after).toHaveLength(1);
    expect(after[0].avatarStorageId).toBeUndefined();
    expect(after[0].name).toBe("reactor");
  });

  test("a reactor the viewer blocked, or who blocked the viewer, is dropped", async () => {
    const { t, author, reactor, momentId, reactorsSeenBy, viewer } = await boardSetup();
    await t.mutation(api.feed.react, { ...as(reactor), momentId, emoji: "🔥" } as any);
    await t.mutation(api.feed.react, { ...as(author), momentId, emoji: "👍" } as any);
    expect(await reactorsSeenBy(viewer)).toHaveLength(2);

    await t.mutation(api.users.blockUser, { ...as(viewer), targetUserId: reactor.userId } as any);
    const afterBlock = await reactorsSeenBy(viewer);
    expect(afterBlock.map((r: any) => r.username)).toEqual(["author"]);
    // Counts agree with the faces: the blocked person's 🔥 is not tallied.
    const board: any = await t.query(api.feed.board, { ...as(viewer), dayKey: DAY } as any);
    const list: any[] = (board.moments ?? board.items ?? board) as any[];
    const counts = list.find((x: any) => x._id === momentId).reactionCounts;
    expect(counts).toEqual([{ emoji: "👍", count: 1 }]);

    // The other direction, on a fresh pair.
    const s = await boardSetup();
    await s.t.mutation(api.feed.react, { ...as(s.reactor), momentId: s.momentId, emoji: "🔥" } as any);
    await s.t.mutation(api.users.blockUser, { ...as(s.reactor), targetUserId: s.viewer.userId } as any);
    expect(await s.reactorsSeenBy(s.viewer)).toEqual([]);
  });
});

describe("poll respondent names", () => {
  test("a voter is named by their display name, not their handle", async () => {
    const t = convexTest(schema);
    const author = await signUp(t, "author");
    const voter = await signUp(t, "voter99", "Vera Voter");
    const roomId = await t.mutation(api.rooms.create, {
      ...as(author),
      name: "room",
      isPrivate: false,
    } as any);
    await t.mutation(api.rooms.join, { ...as(voter), roomId } as any);
    const messageId = await t.mutation(api.interactions.create, {
      ...as(author),
      roomId,
      kind: "poll",
      prompt: "q",
      labels: ["a", "b"],
    } as any);
    await t.mutation(api.interactions.respond, { ...as(voter), messageId, choiceId: "0" } as any);
    const detail: any[] = await t.query(api.interactions.respondents, {
      sessionToken: author.token,
      messageId,
      viewerUserId: author.userId as any,
    } as any);
    expect(detail[0].name).toBe("Vera Voter");
  });
});

describe("a burned view-once message keeps no caption", () => {
  test("content and its sidecars are cleared with the blob", async () => {
    const t = convexTest(schema);
    const me = await signUp(t, "sender");
    const peer = await signUp(t, "peer");
    const roomId = await t.mutation(api.rooms.create, {
      ...as(me),
      name: "room",
      isPrivate: false,
    } as any);
    await t.mutation(api.rooms.join, { ...as(peer), roomId } as any);
    const media = await store(t);
    const messageId = (await t.mutation(api.messages.send, {
      ...as(me),
      roomId,
      content: "the secret caption",
      type: "image",
      mediaStorageId: media,
      viewOnce: true,
      clientId: "burn-1",
    } as any)) as Id<"messages">;
    expect((await t.run((ctx) => ctx.db.get(messageId)))?.content).toBe("the secret caption");

    await t.mutation(internal.messages.burnViewOnce, { messageId });
    const ghost: any = await t.run((ctx) => ctx.db.get(messageId));
    expect(ghost.content).toBe("");
    expect(ghost.viewOnceBurnedAt).toBeDefined();
    expect(await exists(t, media)).toBe(false);
  });
});

describe("shared posters survive a delete", () => {
  test("moments: removing one moment keeps a poster another moment still uses", async () => {
    const t = convexTest(schema);
    const me = await signUp(t, "poster");
    const poster = await store(t);
    const a = await store(t, "video/mp4");
    const b = await store(t, "video/mp4");
    const post = (mediaStorageId: any) =>
      t.mutation(api.feed.post, {
        ...as(me),
        dayKey: DAY,
        mediaStorageId,
        posterStorageId: poster,
        mediaKind: "video",
      } as any);
    const first = await post(a);
    const second = await post(b);

    await t.mutation(api.feed.remove, { ...as(me), momentId: first } as any);
    expect(await exists(t, a)).toBe(false);
    expect(await exists(t, poster)).toBe(true);

    await t.mutation(api.feed.remove, { ...as(me), momentId: second } as any);
    expect(await exists(t, poster)).toBe(false);
  });

  test("messages: a poster another message uses as its picture is not deleted", async () => {
    const t = convexTest(schema);
    const me = await signUp(t, "sender");
    const roomId = await t.mutation(api.rooms.create, {
      ...as(me),
      name: "room",
      isPrivate: false,
    } as any);
    const video = await store(t, "video/mp4");
    const poster = await store(t);
    const row = (extra: Record<string, unknown>) =>
      t.run((ctx) =>
        ctx.db.insert("messages", {
          roomId,
          userId: me.userId as any,
          content: "",
          createdAt: Date.now(),
          type: "image",
          ...extra,
        } as any),
      );
    const withVideo = await row({ type: "video", mediaStorageId: video, posterStorageId: poster });
    await row({ mediaStorageId: poster });

    await t.run(async (ctx) => {
      await releaseMessageBlobs(ctx, await ctx.db.get(withVideo));
    });
    expect(await exists(t, video)).toBe(false);
    expect(await exists(t, poster)).toBe(true);
  });
});
