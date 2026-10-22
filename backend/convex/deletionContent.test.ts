import { convexTest } from "convex-test";
import { afterEach, beforeEach, describe, expect, test, vi } from "vitest";
import { api, internal } from "./_generated/api";
import type { Id } from "./_generated/dataModel";
import { Budget, testHooks, tuning } from "./deletionCore";
import { drainDeletions, shrinkTuning } from "./deletionTestUtils";
import { planFor } from "./deletionPlans";
import { STALL_MS } from "./deletions";
import { eraseMatch } from "./matchCore";
import { removeMessageAndFanout } from "./messages";
import schema from "./schema";

/**
 * Phase 2, work package B: the message, moment, comment, match and avatar
 * teardowns, against the real tables. Budgets are shrunk (4 writes, 2 rows a
 * page, 2 rows inline) so a handful of rows spans several pages.
 */

type T = ReturnType<typeof convexTest>;

let restoreTuning: () => void;
beforeEach(() => {
  vi.useFakeTimers();
  vi.spyOn(console, "warn").mockImplementation(() => {});
  vi.spyOn(console, "error").mockImplementation(() => {});
  restoreTuning = shrinkTuning();
});
afterEach(() => {
  restoreTuning();
  testHooks.beforeStep = undefined;
  vi.restoreAllMocks();
  vi.useRealTimers();
});

const drain = (t: T) => drainDeletions(t, vi.runAllTimers);
const count = (t: T, table: string) =>
  t.run(async (ctx) => (await ctx.db.query(table as any).collect()).length);
const get = (t: T, id: any) => t.run((ctx) => ctx.db.get(id));
const jobs = (t: T, kind?: string) =>
  t.run(async (ctx) =>
    (await ctx.db.query("deletions").collect()).filter((j) => !kind || j.kind === kind),
  );
const store = (t: T, bytes = 100) =>
  t.run((ctx) => ctx.storage.store(new Blob([new Uint8Array(bytes)], { type: "image/jpeg" })));
const exists = (t: T, storageId: any) =>
  t.run(async (ctx) => (await ctx.db.system.get(storageId)) !== null);

const mkUser = (t: T, username: string) =>
  t.run((ctx) => ctx.db.insert("users", { username, passwordHash: "x", createdAt: 1 }));
const mkRoom = (t: T, owner: Id<"users">) =>
  t.run((ctx) =>
    ctx.db.insert("rooms", {
      name: `room${Math.random()}`,
      createdBy: owner,
      createdAt: 1,
      isPrivate: false,
      memberCount: 1,
    }),
  );
const mkMsg = (t: T, roomId: Id<"rooms">, userId: Id<"users">, extra: Record<string, any> = {}) =>
  t.run((ctx) =>
    ctx.db.insert("messages", {
      roomId,
      userId,
      content: "hello",
      createdAt: Date.now(),
      ...extra,
    } as any),
  );
const remove = (t: T, id: Id<"messages">) =>
  t.run(async (ctx) => {
    const msg = await ctx.db.get(id);
    await removeMessageAndFanout(ctx, msg, id);
  });

async function world(t: T) {
  const u1 = await mkUser(t, "u1");
  const u2 = await mkUser(t, "u2");
  const roomId = await mkRoom(t, u1);
  return { u1, u2, roomId };
}

/** `n` rows in each table that hangs off a message. */
function seedMessageTails(t: T, p: { messageId: Id<"messages">; roomId: Id<"rooms">; userId: Id<"users"> }, n: number) {
  return t.run(async (ctx) => {
    for (let i = 0; i < n; i++) {
      await ctx.db.insert("reactions", { messageId: p.messageId, userId: p.userId, emoji: `e${i}`, createdAt: 1 });
      await ctx.db.insert("pinnedMessages", { roomId: p.roomId, messageId: p.messageId, userId: p.userId, pinnedAt: 1 });
      await ctx.db.insert("messageBookmarks", { roomId: p.roomId, messageId: p.messageId, userId: p.userId, savedAt: 1 });
      await ctx.db.insert("viewOnceViews", { messageId: p.messageId, roomId: p.roomId, userId: p.userId, viewedAt: 1, countsToward: true });
      await ctx.db.insert("interactionResponses", {
        messageId: p.messageId, roomId: p.roomId, userId: p.userId, choiceId: `c${i}`, userName: "u", createdAt: 1,
      });
    }
  });
}

const TAIL_TABLES = ["reactions", "pinnedMessages", "messageBookmarks", "viewOnceViews", "interactionResponses"];

describe("message", () => {
  test("a popular message: a bounded first transaction, the rest in a job, replies marked", async () => {
    const t = convexTest(schema);
    const { u1, roomId } = await world(t);
    const target = await mkMsg(t, roomId, u1);
    const control = await mkMsg(t, roomId, u1);
    await seedMessageTails(t, { messageId: target, roomId, userId: u1 }, 7);
    await t.run((ctx) =>
      ctx.db.insert("reactions", { messageId: control, userId: u1, emoji: "x", createdAt: 1 }),
    );
    const replies: Id<"messages">[] = [];
    for (let i = 0; i < 7; i++) {
      replies.push(
        await mkMsg(t, roomId, u1, {
          replyToId: target,
          replyToPreview: { senderId: u1, senderName: "u1", contentPreview: "hello", type: "text" },
        }),
      );
    }

    await remove(t, target);
    // Immediately: the row is gone (so nothing can read the rest, which is
    // only ever reached through it), the first slice of each table with it.
    expect(await get(t, target)).toBeNull();
    for (const table of TAIL_TABLES) expect(await count(t, table)).toBe(table === "reactions" ? 5 + 1 : 5);
    const marked = async () =>
      (await Promise.all(replies.map((r) => get(t, r)))).filter(
        (m: any) => m.replyToPreview.contentPreview === "__DELETED__",
      ).length;
    expect(await marked()).toBe(2);
    const [job] = await jobs(t, "message");
    expect(job.state).toBe("running");
    expect(job.targetId).toBe(target);

    await drain(t);
    for (const table of TAIL_TABLES) expect(await count(t, table)).toBe(table === "reactions" ? 1 : 0);
    expect(await marked()).toBe(7);
    expect(await get(t, control)).not.toBeNull();
    expect((await jobs(t, "message"))[0].state).toBe("done");
  });

  test("a message nobody touched needs no job", async () => {
    const t = convexTest(schema);
    const { u1, roomId } = await world(t);
    const id = await mkMsg(t, roomId, u1);
    await remove(t, id);
    await drain(t);
    expect(await jobs(t, "message")).toHaveLength(0);
  });

  test("self-destruct on a message with 60 reactions cannot fail and finishes in the job", async () => {
    restoreTuning(); // real budgets: 25 rows inline
    const t = convexTest(schema);
    const { u1, roomId } = await world(t);
    const id = await mkMsg(t, roomId, u1, { expiresAt: 1 });
    await t.run(async (ctx) => {
      for (let i = 0; i < 60; i++) {
        await ctx.db.insert("reactions", { messageId: id, userId: u1, emoji: `e${i}`, createdAt: 1 });
      }
    });
    await t.mutation(internal.messages.expireMessage, { messageId: id });
    expect(await get(t, id)).toBeNull();
    expect(await count(t, "reactions")).toBe(60 - tuning.inlineCap);
    await drain(t);
    expect(await count(t, "reactions")).toBe(0);
  });

  test("a room preview is repaired when the newest message goes", async () => {
    const t = convexTest(schema);
    const { u1, roomId } = await world(t);
    const older = await mkMsg(t, roomId, u1, { content: "older", createdAt: 100 });
    const newest = await mkMsg(t, roomId, u1, { content: "newest", createdAt: 200 });
    await t.run((ctx) =>
      ctx.db.patch(roomId, { lastMessage: "newest", lastMessageTime: 200, lastMessageSenderId: u1 }),
    );
    await remove(t, newest);
    const room: any = await get(t, roomId);
    expect(room.lastMessageTime).toBe(100);
    expect(await get(t, older)).not.toBeNull();
  });

  test("forwarded media: a shared file is kept, and so is the quote's picture, until the last copy goes", async () => {
    const t = convexTest(schema);
    const { u1, roomId } = await world(t);
    const room2 = await mkRoom(t, u1);
    const blob = await store(t);
    const m1 = await mkMsg(t, roomId, u1, { mediaStorageId: blob, type: "image" });
    const m2 = await mkMsg(t, room2, u1, { mediaStorageId: blob, type: "image" });
    const quoting = async (parent: Id<"messages">, inRoom: Id<"rooms">) => {
      const ids: Id<"messages">[] = [];
      for (let i = 0; i < 5; i++) {
        ids.push(
          await mkMsg(t, inRoom, u1, {
            replyToId: parent,
            replyToPreview: { senderId: u1, senderName: "u1", contentPreview: "pic", type: "image", mediaStorageId: blob },
          }),
        );
      }
      return ids;
    };
    const r1 = await quoting(m1, roomId);
    const r2 = await quoting(m2, room2);
    const previews = async (ids: Id<"messages">[]) =>
      (await Promise.all(ids.map((r) => get(t, r)))).map((m: any) => m.replyToPreview);

    await remove(t, m1);
    await drain(t);
    expect(await exists(t, blob)).toBe(true); // m2 still uses it
    for (const p of await previews(r1)) {
      expect(p.contentPreview).toBe("__DELETED__");
      expect(p.mediaStorageId).toBe(blob); // the file is alive: the quote keeps it
    }

    await remove(t, m2);
    await drain(t);
    expect(await exists(t, blob)).toBe(false);
    for (const p of await previews(r2)) {
      expect(p.contentPreview).toBe("__DELETED__");
      expect(p.mediaStorageId).toBeUndefined(); // really deleted: stripped, job path included
    }
  });
});

describe("match", () => {
  async function game(t: T, moves: number) {
    const { u1, u2, roomId } = await world(t);
    const card = await mkMsg(t, roomId, u1, { type: "game" });
    const matchId = await t.run((ctx) =>
      ctx.db.insert("matches", {
        roomId, messageId: card, game: "checkers", mode: "async", status: "active",
        seats: [{ userId: u1, name: "u1" }, { userId: u2, name: "u2" }],
        seq: moves, createdBy: u1, createdAt: 1, lastMoveAt: 1,
      } as any),
    );
    const bubbles: Id<"messages">[] = [];
    await t.run(async (ctx) => {
      for (let i = 0; i < moves; i++) {
        const bubble = await ctx.db.insert("messages", {
          roomId, userId: u1, content: "", createdAt: 10 + i, type: "gameMove",
          gameMove: { matchId, game: "checkers", seq: i + 1, seat: i % 2, move: "m", state: "s" },
        } as any);
        bubbles.push(bubble);
        await ctx.db.insert("matchMoves", { matchId, seq: i + 1, seat: i % 2, userId: u1, move: "m", messageId: bubble, at: 1 });
      }
      for (let i = 0; i < 3; i++) {
        await ctx.db.insert("matchHidden", { matchId, state: `h${i}` });
        await ctx.db.insert("matchPresence", { matchId, userId: u1, lastBeatAt: i });
      }
    });
    return { u1, roomId, card, matchId, bubbles };
  }

  test("a game card with more than a page of moves: game, history and every bubble go", async () => {
    const t = convexTest(schema);
    const { card, matchId, bubbles } = await game(t, 7);
    await remove(t, card);
    expect(await get(t, card)).toBeNull();
    expect(await get(t, matchId)).toBeNull();
    // Only the first slice of moves went inline.
    expect(await count(t, "matchMoves")).toBe(7 - tuning.inlineCap);
    expect((await jobs(t, "match"))[0].state).toBe("running");

    await drain(t);
    for (const table of ["matches", "matchMoves", "matchHidden", "matchPresence"]) {
      expect(await count(t, table)).toBe(0);
    }
    for (const b of bubbles) expect(await get(t, b)).toBeNull();
    expect(await count(t, "messages")).toBe(0);
    expect((await jobs(t, "match"))[0].state).toBe("done");
  });

  test("skipBubbles leaves the move bubbles for whoever sweeps the messages", async () => {
    const t = convexTest(schema);
    const { matchId, bubbles } = await game(t, 5);
    await t.run((ctx) => eraseMatch(ctx, matchId, { skipBubbles: true }));
    await drain(t);
    expect(await count(t, "matchMoves")).toBe(0);
    for (const b of bubbles) expect(await get(t, b)).not.toBeNull();
    expect((await jobs(t, "match"))[0].args).toEqual({ skipBubbles: true });
  });

  test("deleting a move bubble clears the move's pointer and the game plays on", async () => {
    const t = convexTest(schema);
    const { matchId, bubbles } = await game(t, 3);
    await remove(t, bubbles[1]);
    expect(await get(t, matchId)).not.toBeNull();
    const moves: any[] = await t.run((ctx) => ctx.db.query("matchMoves").collect());
    expect(moves.filter((m) => m.messageId === undefined)).toHaveLength(1);
    expect(moves.filter((m) => m.messageId === bubbles[1])).toHaveLength(0);
  });
});

describe("moment", () => {
  async function signUp(t: T, username: string) {
    return await t.mutation(api.auth.signup, {
      username, name: username, passwordHash: `hash-${username}`,
      recoveryKeyHash: `recovery-${username}`, deviceId: `device-${username}`,
    });
  }

  test("a moment with more than a page of children and shared files", async () => {
    const t = convexTest(schema);
    const me = await signUp(t, "me");
    const other = await signUp(t, "other");
    const mine = me.userId as Id<"users">;
    const media = await store(t);
    const poster = await store(t); // also another moment's PICTURE
    const poster2 = await store(t); // also another moment's POSTER
    const base = { dayKey: "2026-10-22", createdAt: 1, expiresAt: 2, authorName: "x", authorUsername: "x" };
    const ids = await t.run(async (ctx) => {
      const momentId = await ctx.db.insert("moments", {
        ...base, userId: mine, mediaStorageId: media, posterStorageId: poster,
      } as any);
      const second = await ctx.db.insert("moments", {
        ...base, userId: mine, mediaStorageId: poster2, posterStorageId: poster,
      } as any);
      await ctx.db.insert("moments", {
        ...base, userId: other.userId as any, mediaStorageId: poster, posterStorageId: poster2,
      } as any);
      for (let i = 0; i < 5; i++) {
        await ctx.db.insert("momentReactions", { momentId, userId: mine, emoji: `e${i}`, createdAt: 1 });
        await ctx.db.insert("momentViews", { momentId, viewerId: other.userId as any, viewedAt: i });
        const c = await ctx.db.insert("momentComments", { momentId, userId: mine, userName: "me", text: "hi", createdAt: i });
        await ctx.db.insert("momentCommentReactions", { commentId: c, momentId, userId: mine, emoji: "x", createdAt: 1 });
      }
      return { momentId, second };
    });

    await t.mutation(api.feed.remove, { sessionToken: me.token, userId: mine, momentId: ids.momentId } as any);
    expect(await get(t, ids.momentId)).toBeNull();
    expect(await exists(t, media)).toBe(false); // nobody else uses it
    expect(await exists(t, poster)).toBe(true); // another moment's picture
    expect(await count(t, "momentReactions")).toBe(5 - tuning.inlineCap);
    expect((await jobs(t, "moment"))[0].state).toBe("running");

    await drain(t);
    for (const table of ["momentReactions", "momentViews", "momentComments", "momentCommentReactions"]) {
      expect(await count(t, table)).toBe(0);
    }
    expect(await exists(t, poster)).toBe(true);
    expect(await exists(t, poster2)).toBe(true); // `second` and the other moment still use it
    expect(await get(t, ids.second)).not.toBeNull();
    expect((await jobs(t, "moment"))[0].state).toBe("done");
  });

  test("comments: a thread with more replies than fit inline goes in a job and the counter follows", async () => {
    const t = convexTest(schema);
    const me = await signUp(t, "me");
    const mine = me.userId as Id<"users">;
    const seeded = await t.run(async (ctx) => {
      const momentId = await ctx.db.insert("moments", {
        dayKey: "d", createdAt: 1, expiresAt: 2, authorName: "x", authorUsername: "x",
        userId: mine, commentCount: 7,
      } as any);
      const root = await ctx.db.insert("momentComments", { momentId, userId: mine, userName: "me", text: "r", createdAt: 1 });
      const other = await ctx.db.insert("momentComments", { momentId, userId: mine, userName: "me", text: "o", createdAt: 2 });
      await ctx.db.insert("momentCommentReactions", { commentId: other, momentId, userId: mine, emoji: "x", createdAt: 1 });
      for (let i = 0; i < 5; i++) {
        const reply = await ctx.db.insert("momentComments", {
          momentId, userId: mine, userName: "me", text: "y", parentId: root, createdAt: 3 + i,
        });
        for (let k = 0; k < 3; k++) {
          await ctx.db.insert("momentCommentReactions", { commentId: reply, momentId, userId: mine, emoji: `e${k}`, createdAt: 1 });
        }
      }
      for (let k = 0; k < 4; k++) {
        await ctx.db.insert("momentCommentReactions", { commentId: root, momentId, userId: mine, emoji: `r${k}`, createdAt: 1 });
      }
      return { momentId, root, other };
    });

    await t.mutation(api.momentComments.remove, { sessionToken: me.token, userId: mine, commentId: seeded.root } as any);
    expect(await get(t, seeded.root)).toBeNull();
    expect(((await get(t, seeded.momentId)) as any).commentCount).toBe(7 - 3); // root + 2 inline replies
    expect((await jobs(t, "comment")).length).toBeGreaterThan(0);

    await drain(t);
    expect(await count(t, "momentComments")).toBe(1); // the unrelated comment
    expect(await count(t, "momentCommentReactions")).toBe(1); // its reaction
    expect(((await get(t, seeded.momentId)) as any).commentCount).toBe(1);
    expect((await jobs(t, "comment")).every((j) => j.state === "done")).toBe(true);
  });
});

describe("engine behaviour for these kinds", () => {
  test("a throwing step rolls back, then the cron re-drives it to completion", async () => {
    const t = convexTest(schema);
    const { u1, roomId } = await world(t);
    const target = await mkMsg(t, roomId, u1);
    await seedMessageTails(t, { messageId: target, roomId, userId: u1 }, 7);
    await remove(t, target);
    const [job] = await jobs(t, "message");
    testHooks.beforeStep = (_c, _j, s) => {
      if (s.id === "generic:reactions.messageId") throw new Error("boom");
    };
    await drain(t);
    let j: any = await t.run((ctx) => ctx.db.get(job._id));
    expect(j.state).toBe("running");
    expect(j.lastError).toContain("boom");
    expect(await count(t, "reactions")).toBe(5); // nothing from the failed slice stuck

    testHooks.beforeStep = undefined;
    vi.advanceTimersByTime(STALL_MS + 1000);
    await t.mutation(internal.deletions.redrive, {});
    await drain(t);
    j = await t.run((ctx) => ctx.db.get(job._id));
    expect(j.state).toBe("done");
    for (const table of TAIL_TABLES) expect(await count(t, table)).toBe(0);
  });

  test("re-running every step of a finished job is a no-op", async () => {
    const t = convexTest(schema);
    const { u1, roomId } = await world(t);
    const target = await mkMsg(t, roomId, u1);
    const reply = await mkMsg(t, roomId, u1, {
      replyToId: target,
      replyToPreview: { senderId: u1, senderName: "u1", contentPreview: "hello", type: "text" },
    });
    await seedMessageTails(t, { messageId: target, roomId, userId: u1 }, 5);
    await remove(t, target);
    await drain(t);
    const before = await t.run(async (ctx) => ({
      reply: await ctx.db.get(reply),
      rows: await Promise.all(TAIL_TABLES.map(async (x) => (await ctx.db.query(x as any).collect()).length)),
    }));
    const [job] = await jobs(t, "message");
    await t.run(async (ctx) => {
      for (const step of planFor("message")) {
        const r = await step.run(ctx, { ...job, stepId: step.id, cursor: null }, new Budget());
        expect(r.done).toBe(true);
      }
    });
    const after = await t.run(async (ctx) => ({
      reply: await ctx.db.get(reply),
      rows: await Promise.all(TAIL_TABLES.map(async (x) => (await ctx.db.query(x as any).collect()).length)),
    }));
    expect(after).toEqual(before);
  });

  test("a second deletion of the same message while its job runs makes one job", async () => {
    const t = convexTest(schema);
    const { u1, roomId } = await world(t);
    const target = await mkMsg(t, roomId, u1);
    await seedMessageTails(t, { messageId: target, roomId, userId: u1 }, 6);
    await remove(t, target);
    await t.run(async (ctx) => {
      const { enqueueDeletion } = await import("./deletionCore");
      await enqueueDeletion(ctx, { kind: "message", targetId: target });
    });
    expect(await jobs(t, "message")).toHaveLength(1);
  });
});

describe("avatar", () => {
  async function signUp(t: T, username: string) {
    return await t.mutation(api.auth.signup, {
      username, name: username, passwordHash: `hash-${username}`,
      recoveryKeyHash: `recovery-${username}`, deviceId: `device-${username}`,
    });
  }
  const setup = async () => {
    const t = convexTest(schema);
    const me = await signUp(t, "me");
    const set = (storageId: any) =>
      t.mutation(api.users.updateAvatar, { sessionToken: me.token, userId: me.userId as any, storageId } as any);
    return { t, me, set };
  };
  const stamp = (t: T, me: any, avatar: any, n = 5) =>
    t.run(async (ctx) => {
      const ids: Id<"moments">[] = [];
      for (let i = 0; i < n; i++) {
        ids.push(
          await ctx.db.insert("moments", {
            userId: me.userId, dayKey: "d", createdAt: i, expiresAt: 9, authorName: "x", authorUsername: "x",
            authorAvatarStorageId: avatar,
          } as any),
        );
      }
      return ids;
    });

  test("the patch is immediate; copies move and the old file goes in the job, last", async () => {
    const { t, set, me } = await setup();
    const a = await store(t);
    const b = await store(t);
    await set(a);
    const moments = await stamp(t, me, a);
    await set(b);
    // Nothing deleted inline: the old file is still there for the copies.
    expect(await exists(t, a)).toBe(true);
    expect(((await get(t, me.userId)) as any).avatarStorageId).toBe(b);
    await drain(t);
    expect(await exists(t, a)).toBe(false);
    for (const m of moments) expect(((await get(t, m)) as any).authorAvatarStorageId).toBe(b);
    expect((await jobs(t, "avatar")).every((j) => j.state === "done")).toBe(true);
  });

  test("changing back before the job runs keeps the file; A to B to C converges on C", async () => {
    const { t, set, me } = await setup();
    const a = await store(t);
    const b = await store(t);
    const c = await store(t);
    await set(a);
    const moments = await stamp(t, me, a, 3);

    await set(b);
    await set(a); // back again before anything ran
    await drain(t);
    expect(await exists(t, a)).toBe(true);
    expect(await exists(t, b)).toBe(false);
    for (const m of moments) expect(((await get(t, m)) as any).authorAvatarStorageId).toBe(a);

    const d = await store(t);
    await set(d);
    await set(c);
    await drain(t);
    expect(await exists(t, a)).toBe(false);
    expect(await exists(t, d)).toBe(false);
    expect(await exists(t, c)).toBe(true);
    for (const m of moments) expect(((await get(t, m)) as any).authorAvatarStorageId).toBe(c);
  });

  test("re-submitting the current avatar queues nothing and deletes nothing", async () => {
    const { t, set } = await setup();
    const a = await store(t);
    await set(a);
    await set(a);
    await drain(t);
    expect(await exists(t, a)).toBe(true);
    expect(await jobs(t, "avatar")).toHaveLength(0);
  });
});

describe("reads while a deletion is in flight", () => {
  async function signUp(t: T, username: string) {
    return await t.mutation(api.auth.signup, {
      username, name: username, passwordHash: `hash-${username}`,
      recoveryKeyHash: `recovery-${username}`, deviceId: `device-${username}`,
    });
  }
  const as = (who: any) => ({ sessionToken: who.token, userId: who.userId as any });
  async function befriend(t: T, a: any, b: any, bName: string) {
    await t.mutation(api.friends.sendRequest, { ...as(a), friendUsername: bName } as any);
    await t.mutation(api.friends.acceptRequest, { ...as(b), requesterId: a.userId as any } as any);
  }
  const tombstone = (t: T, userId: any) =>
    t.run((ctx) => ctx.db.patch(userId, { deletingAt: Date.now() }));

  test("a tombstoned user has no profile, no search hit, no board entry and no comments", async () => {
    const t = convexTest(schema);
    const me = await signUp(t, "me");
    const ghost = await signUp(t, "ghost");
    await befriend(t, me, ghost, "ghost");
    const momentId = await t.mutation(api.feed.post, { ...as(ghost), dayKey: "2026-10-22", caption: "hi" } as any);
    // A comment under a moment of mine, by the ghost.
    const mine = await t.mutation(api.feed.post, { ...as(me), dayKey: "2026-10-22", caption: "mine" } as any);
    await t.mutation(api.momentComments.add, { ...as(ghost), momentId: mine, text: "boo" } as any);

    const comments = async () =>
      ((await t.query(api.momentComments.list, { ...as(me), momentId: mine } as any)) as any).comments;
    const board = async () =>
      ((await t.query(api.feed.board, { ...as(me), dayKey: "2026-10-22" } as any)) as any);
    expect(await comments()).toHaveLength(1);
    expect(JSON.stringify(await board())).toContain(momentId);
    expect(await t.query(api.users.getProfile, { ...as(me), userId: ghost.userId as any } as any)).not.toBeNull();

    await tombstone(t, ghost.userId);

    expect(await comments()).toHaveLength(0);
    expect(JSON.stringify(await board())).not.toContain(momentId);
    expect(await t.query(api.users.getProfile, { ...as(me), userId: ghost.userId as any } as any)).toBeNull();
    const found: any[] = await t.query(api.users.searchUsers, {
      sessionToken: me.token, currentUserId: me.userId as any, query: "ghost",
    } as any);
    expect(found).toHaveLength(0);
  });

  test("a room being deleted refuses edits and forwards out of it", async () => {
    const t = convexTest(schema);
    const me = await signUp(t, "me");
    const mine = me.userId as Id<"users">;
    const roomId = await mkRoom(t, mine);
    const room2 = await mkRoom(t, mine);
    await t.run(async (ctx) => {
      await ctx.db.insert("roomMembers", { roomId, userId: mine, role: "owner", joinedAt: 1 } as any);
    });
    const msg = await mkMsg(t, roomId, mine);
    await t.run((ctx) => ctx.db.patch(roomId, { deletingAt: Date.now() }));
    await expect(
      t.mutation(api.messages.editMessage, { ...as(me), messageId: msg, content: "x" } as any),
    ).rejects.toThrow("ROOM_NOT_FOUND");
    await expect(
      t.mutation(api.messages.forwardToRoom, {
        ...as(me), sourceRoomId: roomId, targetRoomId: room2, messageIds: [msg],
      } as any),
    ).rejects.toThrow("ROOM_NOT_FOUND");
  });

  test("a message mid-deletion is already gone to readers; its leftovers are unreachable", async () => {
    const t = convexTest(schema);
    const { u1, roomId } = await world(t);
    const target = await mkMsg(t, roomId, u1);
    await seedMessageTails(t, { messageId: target, roomId, userId: u1 }, 6);
    await remove(t, target);
    const listed = await t.run(async (ctx) =>
      ctx.db.query("messages").withIndex("by_room_time", (q) => q.eq("roomId", roomId)).collect(),
    );
    expect(listed).toHaveLength(0);
    expect(await jobs(t, "message")).toHaveLength(1);
    expect(await count(t, "reactions")).toBeGreaterThan(0);
  });
});
