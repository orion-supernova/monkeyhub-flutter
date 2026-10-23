import { convexTest } from "convex-test";
import { afterEach, beforeEach, describe, expect, test, vi } from "vitest";
import { api, internal } from "./_generated/api";
import type { Id } from "./_generated/dataModel";
import { startRoomDeletion } from "./deletionCore";
import { drainDeletions } from "./deletionTestUtils";
import schema from "./schema";
import { REPORT_INBOX_USERNAME, SYSTEM_PASSWORD_PREFIX } from "./systemAccount";

/**
 * Phase 3 P2: every call site that keeps a file holds a ref on it, and lets go
 * of it when the use ends. The file itself lives exactly as long as its last
 * ref. Each describe below is one of the paths that used to count rows with an
 * index (or not count at all).
 */

type T = ReturnType<typeof convexTest>;

beforeEach(() => {
  vi.useFakeTimers();
});
afterEach(() => {
  vi.useRealTimers();
  delete process.env.FILE_REFS_REAP;
});
const drain = (t: T) => drainDeletions(t, vi.runAllTimers);

async function signUp(t: T, username: string) {
  const u = await t.mutation(api.auth.signup, {
    username,
    name: username,
    passwordHash: `hash-${username}`,
    recoveryKeyHash: `recovery-${username}`,
    deviceId: `device-${username}`,
  });
  return { ...u, username };
}
type Who = Awaited<ReturnType<typeof signUp>>;
const as = (who: Who) => ({ sessionToken: who.token, userId: who.userId as any });

const store = (t: T, type = "image/jpeg", bytes = 64) =>
  t.run((ctx: any) => ctx.storage.store(new Blob([new Uint8Array(bytes)], { type })));
const alive = (t: T, id: any) => t.run(async (ctx: any) => (await ctx.db.system.get(id)) !== null);
const refsOf = (t: T, id: any) =>
  t.run((ctx: any) =>
    ctx.db.query("fileRefs").withIndex("by_file_holder", (q: any) => q.eq("storageId", id)).collect(),
  ) as Promise<any[]>;
const ledgerOf = (t: T, id: any) =>
  t.run((ctx: any) =>
    ctx.db.query("uploads").withIndex("by_storage", (q: any) => q.eq("storageId", id)).first(),
  ) as Promise<any>;

async function makeRoom(t: T, owner: Who, name = "room") {
  return (await t.mutation(api.rooms.create, { ...as(owner), name, isPrivate: false } as any)) as Id<"rooms">;
}
async function join(t: T, who: Who, roomId: any) {
  await t.mutation(api.rooms.join, { ...as(who), roomId } as any);
}
async function befriend(t: T, a: Who, b: Who) {
  await t.mutation(api.friends.sendRequest, { ...as(a), friendUsername: b.username } as any);
  await t.mutation(api.friends.acceptRequest, { ...as(b), requesterId: a.userId as any } as any);
}
const sendImage = (t: T, who: Who, roomId: any, file: any, extra: Record<string, unknown> = {}) =>
  t.mutation(api.messages.send, {
    ...as(who),
    roomId,
    content: "",
    type: "image",
    mediaStorageId: file,
    ...extra,
  } as any) as Promise<Id<"messages">>;
const roomMessages = (t: T, roomId: any) =>
  t.run((ctx: any) =>
    ctx.db.query("messages").withIndex("by_room_time", (q: any) => q.eq("roomId", roomId)).collect(),
  ) as Promise<any[]>;

describe("every claim path leaves a ref", () => {
  test("send media and its poster", async () => {
    const t = convexTest(schema);
    const me = await signUp(t, "me");
    const roomId = await makeRoom(t, me);
    const media = await store(t, "video/mp4");
    const poster = await store(t);
    const id = await sendImage(t, me, roomId, media, { type: "video", posterStorageId: poster });
    expect(await refsOf(t, media)).toMatchObject([
      { holderTable: "messages", holderId: id.toString(), field: "mediaStorageId" },
    ]);
    expect(await refsOf(t, poster)).toMatchObject([
      { holderTable: "messages", holderId: id.toString(), field: "posterStorageId" },
    ]);
  });

  test("a moment's media and poster", async () => {
    const t = convexTest(schema);
    const me = await signUp(t, "me");
    const media = await store(t, "video/mp4");
    const poster = await store(t);
    const id = await t.mutation(api.feed.post, {
      ...as(me),
      dayKey: "2026-10-22",
      mediaStorageId: media,
      posterStorageId: poster,
      mediaKind: "video",
    } as any);
    expect(await refsOf(t, media)).toMatchObject([{ holderTable: "moments", holderId: id.toString() }]);
    expect(await refsOf(t, poster)).toMatchObject([{ holderTable: "moments", holderId: id.toString() }]);
    // Removing the moment frees both.
    await t.mutation(api.feed.remove, { ...as(me), momentId: id } as any);
    expect(await alive(t, media)).toBe(false);
    expect(await alive(t, poster)).toBe(false);
  });

  test("a personal sticker's art", async () => {
    const t = convexTest(schema);
    const me = await signUp(t, "me");
    const file = await store(t, "image/png");
    const id = await t.mutation(api.expressions.createPersonalSticker, {
      ...tok(me),
      storageId: file,
      emoji: "🐶",
      width: 400,
      height: 380,
    } as any);
    expect(await refsOf(t, file)).toMatchObject([
      { holderTable: "stickers", holderId: id.toString(), field: "storageId" },
    ]);
  });

  test("an avatar", async () => {
    const t = convexTest(schema);
    const me = await signUp(t, "me");
    const file = await store(t);
    await t.mutation(api.users.updateAvatar, { ...as(me), storageId: file } as any);
    expect(await refsOf(t, file)).toMatchObject([
      { holderTable: "users", holderId: me.userId.toString(), field: "avatarStorageId" },
    ]);
  });

  test("a room photo proposal, and an admin's direct change", async () => {
    const t = convexTest(schema);
    const owner = await signUp(t, "owner");
    const member = await signUp(t, "member");
    const roomId = await makeRoom(t, owner);
    await join(t, member, roomId);

    const proposed = await store(t);
    const { requestId } = (await t.mutation(api.roomChangeRequests.propose, {
      ...as(member),
      roomId,
      field: "avatar",
      storageId: proposed,
    } as any)) as any;
    expect(await refsOf(t, proposed)).toMatchObject([
      { holderTable: "roomChangeRequests", holderId: requestId.toString(), field: "storageId" },
    ]);

    const direct = await store(t);
    await t.mutation(api.roomChangeRequests.propose, {
      ...as(owner),
      roomId,
      field: "avatar",
      storageId: direct,
    } as any);
    expect(await refsOf(t, direct)).toMatchObject([
      { holderTable: "rooms", holderId: roomId.toString(), field: "avatarStorageId" },
    ]);
  });

  test("a scheduled photo", async () => {
    const t = convexTest(schema);
    const me = await signUp(t, "me");
    const roomId = await makeRoom(t, me);
    const file = await store(t);
    const id = await t.mutation(api.scheduledMessages.schedule, {
      ...as(me),
      roomId,
      content: "",
      delayMs: 60 * 60 * 1000,
      type: "image",
      mediaStorageId: file,
      clientId: "sch_1",
    } as any);
    expect(await refsOf(t, file)).toMatchObject([
      { holderTable: "scheduledMessages", holderId: id.toString(), field: "mediaStorageId" },
    ]);
  });

  test("a problem report's log and screenshots", async () => {
    const t = convexTest(schema);
    await signUp(t, REPORT_INBOX_USERNAME);
    const me = await signUp(t, "me");
    const log = await store(t, "text/plain");
    const shot = await store(t);
    await t.mutation(api.problemReports.submit, {
      ...tok(me),
      deviceId: "dev-1",
      body: "it broke",
      logStorageId: log,
      logFileName: "log.txt",
      logFileSize: 64,
      screenshots: [shot],
    } as any);
    expect(await refsOf(t, log)).toHaveLength(1);
    expect(await refsOf(t, shot)).toHaveLength(1);
    for (const f of [log, shot]) {
      const [ref] = await refsOf(t, f);
      const msg: any = await t.run((ctx: any) => ctx.db.get(ref.holderId));
      expect(msg?.mediaStorageId).toBe(f);
    }
  });
});

const tok = (who: Who) => ({ sessionToken: who.token });

describe("messages", () => {
  test("a forwarded copy keeps the file; the last delete frees it", async () => {
    const t = convexTest(schema);
    const me = await signUp(t, "me");
    const a = await makeRoom(t, me, "a");
    const b = await makeRoom(t, me, "b");
    const file = await store(t);
    const original = await sendImage(t, me, a, file);

    await t.mutation(api.messages.forwardToRoom, {
      ...as(me),
      sourceRoomId: a,
      targetRoomId: b,
      messageIds: [original],
    } as any);
    const [copy] = await roomMessages(t, b);
    expect(await refsOf(t, file)).toHaveLength(2);

    await t.mutation(api.messages.deleteMessage, { ...as(me), messageId: original } as any);
    await drain(t);
    expect(await alive(t, file)).toBe(true);
    expect(await refsOf(t, file)).toMatchObject([{ holderId: copy._id.toString() }]);

    await t.mutation(api.messages.deleteMessage, { ...as(me), messageId: copy._id } as any);
    await drain(t);
    expect(await alive(t, file)).toBe(false);
    expect(await refsOf(t, file)).toHaveLength(0);
    expect(await ledgerOf(t, file)).toBeNull();
  });

  test("report evidence shares the blob, so it outlives the reported message", async () => {
    const t = convexTest(schema);
    await signUp(t, REPORT_INBOX_USERNAME);
    const ada = await signUp(t, "ada");
    const bob = await signUp(t, "bob");
    const roomId = await makeRoom(t, ada);
    await join(t, bob, roomId);
    const file = await store(t);
    const photo = await sendImage(t, bob, roomId, file);

    await t.mutation(api.users.report, {
      ...tok(ada),
      reporterId: ada.userId,
      targetType: "message",
      targetId: photo,
      reason: "HARASSMENT",
    } as any);
    // The message, the card's evidence bubble and the report itself.
    expect(await refsOf(t, file)).toHaveLength(3);

    await t.mutation(api.messages.deleteMessage, { ...as(bob), messageId: photo } as any);
    await drain(t);
    expect(await alive(t, file)).toBe(true);
    expect(await refsOf(t, file)).toHaveLength(2);
  });

  test("a view-once burn frees the file at once", async () => {
    const t = convexTest(schema);
    const me = await signUp(t, "me");
    const peer = await signUp(t, "peer");
    const roomId = await makeRoom(t, me);
    await join(t, peer, roomId);
    const file = await store(t);
    const id = await sendImage(t, me, roomId, file, { viewOnce: true });
    expect(await refsOf(t, file)).toHaveLength(1);

    await t.mutation(internal.messages.burnViewOnce, { messageId: id });
    expect(await alive(t, file)).toBe(false);
    expect(await refsOf(t, file)).toHaveLength(0);
    expect(((await t.run((ctx: any) => ctx.db.get(id))) as any)?.mediaStorageId).toBeUndefined();
  });
});

describe("scheduled messages", () => {
  async function scheduled(t: T, me: Who, roomId: any, file: any) {
    const id = await t.mutation(api.scheduledMessages.schedule, {
      ...as(me),
      roomId,
      content: "later",
      delayMs: 60 * 60 * 1000,
      type: "image",
      mediaStorageId: file,
      clientId: "sch_1",
    } as any);
    const row: any = await t.run((ctx: any) => ctx.db.get(id));
    return { id, sendAt: row.sendAt as number };
  }

  test("release leaves one ref, the message's", async () => {
    const t = convexTest(schema);
    const me = await signUp(t, "me");
    const roomId = await makeRoom(t, me);
    const file = await store(t);
    const { id, sendAt } = await scheduled(t, me, roomId, file);

    await t.mutation(internal.scheduledMessages.release, { id, expectSendAt: sendAt });
    const [msg] = await roomMessages(t, roomId);
    expect(msg.mediaStorageId).toBe(file);
    expect(await refsOf(t, file)).toMatchObject([
      { holderTable: "messages", holderId: msg._id.toString(), field: "mediaStorageId" },
    ]);
    expect(await alive(t, file)).toBe(true);
  });

  test("sending now does the same, and cancelling frees the file", async () => {
    const t = convexTest(schema);
    const me = await signUp(t, "me");
    const roomId = await makeRoom(t, me);
    const file = await store(t);
    const { id } = await scheduled(t, me, roomId, file);
    await t.mutation(api.scheduledMessages.sendNow, { ...as(me), id } as any);
    expect(await refsOf(t, file)).toMatchObject([{ holderTable: "messages" }]);

    const other = await store(t);
    const second = await t.mutation(api.scheduledMessages.schedule, {
      ...as(me),
      roomId,
      content: "never",
      delayMs: 60 * 60 * 1000,
      type: "image",
      mediaStorageId: other,
      clientId: "sch_2",
    } as any);
    await t.mutation(api.scheduledMessages.cancel, { ...as(me), id: second } as any);
    expect(await alive(t, other)).toBe(false);
    expect(await refsOf(t, other)).toHaveLength(0);
  });
});

describe("room photos", () => {
  async function scene() {
    const t = convexTest(schema);
    const owner = await signUp(t, "owner");
    const member = await signUp(t, "member");
    const roomId = await makeRoom(t, owner);
    await join(t, member, roomId);
    const propose = (storageId: any) =>
      t.mutation(api.roomChangeRequests.propose, {
        ...as(member),
        roomId,
        field: "avatar",
        storageId,
      } as any) as Promise<any>;
    const decide = (requestId: any, approve: boolean) =>
      t.mutation(api.roomChangeRequests.decide, { ...as(owner), requestId, approve } as any);
    return { t, owner, member, roomId, propose, decide };
  }

  test("approval hands the file to the room and frees the one it replaces", async () => {
    const { t, owner, roomId, propose, decide } = await scene();
    const first = await store(t);
    await t.mutation(api.rooms.updateRoomAvatar, { ...as(owner), roomId, storageId: first } as any);
    expect(await refsOf(t, first)).toMatchObject([{ holderTable: "rooms" }]);

    const next = await store(t);
    const { requestId } = await propose(next);
    expect(await refsOf(t, next)).toMatchObject([{ holderTable: "roomChangeRequests" }]);

    await decide(requestId, true);
    expect(await refsOf(t, next)).toMatchObject([
      { holderTable: "rooms", holderId: roomId.toString(), field: "avatarStorageId" },
    ]);
    expect(await alive(t, next)).toBe(true);
    expect(await alive(t, first)).toBe(false);
  });

  test("rejection and withdrawal free the proposed file; the same file cannot be proposed twice", async () => {
    const { t, member, roomId, propose, decide } = await scene();
    const rejected = await store(t);
    const { requestId } = await propose(rejected);
    await expect(propose(rejected)).rejects.toThrow("PHOTO_IN_USE");
    await decide(requestId, false);
    expect(await alive(t, rejected)).toBe(false);
    expect(await refsOf(t, rejected)).toHaveLength(0);

    const withdrawn = await store(t);
    const second = await propose(withdrawn);
    await t.mutation(api.roomChangeRequests.withdraw, {
      ...as(member),
      requestId: second.requestId,
    } as any);
    expect(await alive(t, withdrawn)).toBe(false);
    expect(roomId).toBeTruthy();
  });

  test("replacing a room photo directly frees the old one", async () => {
    const { t, owner, roomId } = await scene();
    const first = await store(t);
    const second = await store(t);
    for (const storageId of [first, second]) {
      await t.mutation(api.rooms.updateRoomAvatar, { ...as(owner), roomId, storageId } as any);
    }
    expect(await alive(t, first)).toBe(false);
    expect(await alive(t, second)).toBe(true);
    expect(await refsOf(t, second)).toHaveLength(1);
  });
});

describe("avatars", () => {
  test("the old file is freed by the avatar job, not before", async () => {
    const t = convexTest(schema);
    const me = await signUp(t, "me");
    const first = await store(t);
    const second = await store(t);
    await t.mutation(api.users.updateAvatar, { ...as(me), storageId: first } as any);
    await t.mutation(api.users.updateAvatar, { ...as(me), storageId: second } as any);
    // The job has not run: copies still point at the old file.
    expect(await alive(t, first)).toBe(true);
    expect(await refsOf(t, first)).toHaveLength(1);

    await drain(t);
    expect(await alive(t, first)).toBe(false);
    expect(await refsOf(t, first)).toHaveLength(0);
    expect(await refsOf(t, second)).toHaveLength(1);
  });

  test("deleting the account frees the current avatar", async () => {
    const t = convexTest(schema);
    const me = await signUp(t, "me");
    const file = await store(t);
    await t.mutation(api.users.updateAvatar, { ...as(me), storageId: file } as any);
    await t.mutation(api.auth.deleteAccount, { sessionToken: me.token, userId: me.userId } as any);
    await drain(t);
    expect(await alive(t, file)).toBe(false);
    expect(await refsOf(t, file)).toHaveLength(0);
  });
});

describe("personal stickers", () => {
  async function scene() {
    const t = convexTest(schema);
    const me = await signUp(t, "me");
    const peer = await signUp(t, "peer");
    const roomId = await makeRoom(t, me);
    await join(t, peer, roomId);
    const file = await store(t, "image/png");
    const stickerId = (await t.mutation(api.expressions.createPersonalSticker, {
      ...tok(me),
      storageId: file,
      emoji: "🐶",
      width: 400,
      height: 380,
    } as any)) as Id<"stickers">;
    const sendSticker = (who: Who) =>
      t.mutation(api.messages.send, {
        ...as(who),
        roomId,
        content: "🐶",
        type: "sticker",
        stickerId,
      } as any) as Promise<Id<"messages">>;
    return { t, me, peer, roomId, file, stickerId, sendSticker };
  }

  test("soft delete keeps the file while a message holds it, and the last copy frees it", async () => {
    const { t, me, peer, file, stickerId, sendSticker } = await scene();
    // Anyone may keep forwarding a personal sticker: no owner check.
    const sent = await sendSticker(peer);
    expect(await refsOf(t, file)).toHaveLength(2);

    await t.mutation(api.expressions.deletePersonalSticker, { ...tok(me), stickerId } as any);
    expect(await alive(t, file)).toBe(true);
    expect(await refsOf(t, file)).toMatchObject([{ holderTable: "messages", holderId: sent.toString() }]);

    await t.mutation(api.messages.deleteMessage, { ...as(peer), messageId: sent } as any);
    await drain(t);
    expect(await alive(t, file)).toBe(false);
  });

  test("with no copies, a soft delete frees the file at once", async () => {
    const { t, me, file, stickerId } = await scene();
    await t.mutation(api.expressions.deletePersonalSticker, { ...tok(me), stickerId } as any);
    expect(await alive(t, file)).toBe(false);
  });

  test("account deletion deletes the art and readers degrade to the emoji", async () => {
    const { t, me, peer, file, sendSticker } = await scene();
    const sent = await sendSticker(peer);
    await t.mutation(api.auth.deleteAccount, { sessionToken: me.token, userId: me.userId } as any);
    await drain(t);

    expect(await alive(t, file)).toBe(false);
    const msg: any = await t.run((ctx: any) => ctx.db.get(sent));
    // The row still names the file; the file is gone, so the URL resolves to
    // null and the app draws the sticker's emoji.
    expect(msg?.stickerStorageId).toBe(file);
    expect(await t.run((ctx: any) => ctx.storage.getUrl(file))).toBeNull();
  });

  test("a sticker comment holds a ref, and deleting the comment lets go of it", async () => {
    const { t, me, peer, file, stickerId } = await scene();
    await befriend(t, me, peer);
    const momentId = await t.mutation(api.feed.post, {
      ...as(me),
      dayKey: "2026-10-22",
      caption: "hi",
    } as any);
    const commentId = await t.mutation(api.momentComments.add, {
      ...as(peer),
      momentId,
      type: "sticker",
      stickerId,
    } as any);
    expect(await refsOf(t, file)).toHaveLength(2);

    await t.mutation(api.momentComments.remove, { ...as(peer), commentId } as any);
    expect(await refsOf(t, file)).toMatchObject([{ holderTable: "stickers" }]);
    expect(await alive(t, file)).toBe(true);
  });

  test("the strip drops personal entries whose sticker is gone", async () => {
    const { t, me, stickerId } = await scene();
    await t.run(async (ctx: any) => {
      const entry = { kind: "sticker", source: "personal", stickerId };
      const official = { kind: "gif", source: "klipy", url: "https://static.klipy.com/x.webp" };
      await ctx.db.insert("userExpressions", {
        userId: me.userId,
        recents: [entry, official],
        favorites: [entry],
        updatedAt: 0,
      });
    });
    const before: any = await t.query(api.expressions.state, tok(me) as any);
    expect(before.recents).toHaveLength(2);
    expect(before.favorites).toHaveLength(1);

    await t.mutation(api.expressions.deletePersonalSticker, { ...tok(me), stickerId } as any);
    // The delete scrubs the owner's own lists already; put the entry back to
    // prove the read side filters on its own.
    await t.run(async (ctx: any) => {
      const row = await ctx.db.query("userExpressions").first();
      await ctx.db.patch(row._id, {
        recents: [{ kind: "sticker", source: "personal", stickerId }, row.recents[0]],
        favorites: [{ kind: "sticker", source: "personal", stickerId }],
      });
    });
    const after: any = await t.query(api.expressions.state, tok(me) as any);
    expect(after.recents.map((r: any) => r.source)).toEqual(["klipy"]);
    expect(after.favorites).toEqual([]);
  });
});

describe("system-room avatars", () => {
  async function scene(t: T) {
    return await t.run(async (ctx: any) => {
      const accountId = await ctx.db.insert("users", {
        username: "bot",
        name: "Bot",
        passwordHash: SYSTEM_PASSWORD_PREFIX + "x",
        createdAt: 0,
      });
      const rooms: any[] = [];
      for (const slug of ["one", "two"]) {
        const roomId = await ctx.db.insert("rooms", {
          name: `Room ${slug}`,
          createdBy: accountId,
          createdAt: 0,
          isPrivate: true,
          memberCount: 1,
          type: "Regular Room",
          system: slug,
        });
        await ctx.db.insert("roomMembers", { roomId, userId: accountId, role: "owner", joinedAt: 0 });
        rooms.push(roomId);
      }
      return { accountId, rooms };
    });
  }
  const setAvatar = (t: T, target?: "account" | "room") =>
    t.action(internal.systemAvatars.set, {
      username: "bot",
      imageBase64: btoa("pixels"),
      contentType: "image/png",
      ...(target ? { target } : {}),
    });
  const wearing = (t: T, id: any) => t.run(async (ctx: any) => (await ctx.db.get(id))?.avatarStorageId);

  test("two rooms and the account each own a file, set twice, and a wipe spares the account", async () => {
    const t = convexTest(schema);
    const { accountId, rooms } = await scene(t);

    await setAvatar(t);
    const first = [await wearing(t, accountId), await wearing(t, rooms[0]), await wearing(t, rooms[1])];
    expect(new Set(first.map(String)).size).toBe(3);
    for (const f of first) expect(await refsOf(t, f)).toHaveLength(1);

    // A second `set` replaces every face's file and frees each old one.
    await setAvatar(t);
    const second = [await wearing(t, accountId), await wearing(t, rooms[0]), await wearing(t, rooms[1])];
    expect(new Set(second.map(String)).size).toBe(3);
    for (const f of first) expect(await alive(t, f)).toBe(false);
    for (const f of second) expect(await refsOf(t, f)).toHaveLength(1);

    // Wiping one room frees its own file and leaves the account's picture.
    await t.run((ctx: any) => startRoomDeletion(ctx, rooms[0]));
    await drain(t);
    expect(await alive(t, second[1])).toBe(false);
    expect(await alive(t, second[0])).toBe(true);
    expect(await alive(t, second[2])).toBe(true);
  });

  test("a room with its own picture is left alone by an account-only change", async () => {
    const t = convexTest(schema);
    const { accountId, rooms } = await scene(t);
    await setAvatar(t, "room");
    const roomFaces = [await wearing(t, rooms[0]), await wearing(t, rooms[1])];
    expect(await wearing(t, accountId)).toBeFalsy();

    await setAvatar(t, "account");
    expect(await wearing(t, rooms[0])).toBe(roomFaces[0]);
    expect(await wearing(t, rooms[1])).toBe(roomFaces[1]);
    expect(await wearing(t, accountId)).toBeDefined();
  });

  test("a legacy room still on the account's untracked file is not freed by its wipe", async () => {
    const t = convexTest(schema);
    const { accountId, rooms } = await scene(t);
    // Before refs: the account and a room share one file with no ledger row.
    const legacy = await store(t);
    await t.run(async (ctx: any) => {
      await ctx.db.patch(accountId, { avatarStorageId: legacy });
      await ctx.db.patch(rooms[0], { avatarStorageId: legacy });
    });
    await t.run((ctx: any) => startRoomDeletion(ctx, rooms[0]));
    await drain(t);
    expect(await alive(t, legacy)).toBe(true);
  });
});

describe("the orphan reaper never sees a kept file as unused", () => {
  test("a scheduled photo waits out the grace period with its ref", async () => {
    const t = convexTest(schema);
    const me = await signUp(t, "me");
    const roomId = await makeRoom(t, me);
    const file = await store(t);
    await t.mutation(api.scheduledMessages.schedule, {
      ...as(me),
      roomId,
      content: "",
      delayMs: 60 * 60 * 1000,
      type: "image",
      mediaStorageId: file,
      clientId: "sch_1",
    } as any);

    // Open the reaper's gate and run it well past the 24 hour grace.
    process.env.FILE_REFS_REAP = "1";
    await t.run((ctx: any) =>
      ctx.db.insert("fileBackfill", {
        startedAt: 0,
        lastProgressAt: 0,
        status: "done",
        tableIdx: 0,
        cursor: null,
        restarts: 0,
        pages: 0,
        rowsScanned: 0,
        inserted: 0,
        existed: 0,
        missingFile: 0,
        markedAt: 1,
      }),
    );
    vi.setSystemTime(Date.now() + 2 * 24 * 60 * 60 * 1000);
    const out: any = await t.mutation(internal.files.reapUnreferenced, {});
    expect(out.reaped).toBe(0);
    expect(await alive(t, file)).toBe(true);
    expect((await ledgerOf(t, file)).zeroSince).toBeUndefined();
  });
});
