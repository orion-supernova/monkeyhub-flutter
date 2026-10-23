import { convexTest } from "convex-test";
import { afterEach, beforeEach, describe, expect, test, vi } from "vitest";
import { api, internal } from "./_generated/api";
import type { Id } from "./_generated/dataModel";
import { startUserDeletion } from "./deletionCore";
import { drainDeletions, shrinkTuning } from "./deletionTestUtils";
import schema from "./schema";

/**
 * Follow-ups to the data-integrity phases for rooms and games:
 *   1. `roomInvitations.respond` on a dead room returns "gone" and the stale
 *      invitation really is deleted (a throw used to roll the delete back).
 *   2. Leaving a room removes the leaver's game heartbeats there.
 *   3. A finished game carries no live watchers.
 *   4. Account deletion re-points `rooms.createdBy` of rooms the user left.
 *   5. Reads that were "unverified" in referenceRules: scheduled mentions and
 *      reply tethers, and the sticker picker.
 */

type T = ReturnType<typeof convexTest>;
type Who = { token: string; userId: any };

let restoreTuning: () => void;
beforeEach(() => {
  vi.useFakeTimers();
  restoreTuning = shrinkTuning();
});
afterEach(() => {
  restoreTuning();
  vi.useRealTimers();
});

const as = (w: Who) => ({ sessionToken: w.token, userId: w.userId });
const get = (t: T, id: any) => t.run((ctx) => ctx.db.get(id));
const rows = (t: T, table: any): Promise<any[]> =>
  t.run((ctx) => ctx.db.query(table).collect());

async function signUp(t: T, username: string) {
  return (await t.mutation(api.auth.signup, {
    username,
    name: username,
    passwordHash: `hash-${username}`,
    recoveryKeyHash: `recovery-${username}`,
    deviceId: `device-${username}`,
  })) as Who;
}

let roomSeq = 0;
async function group(t: T, owner: Who, ...others: Who[]) {
  const roomId = await t.mutation(api.rooms.create, {
    ...as(owner),
    name: `games night ${++roomSeq}`,
    isPrivate: false,
  });
  for (const o of others) await t.mutation(api.rooms.join, { ...as(o), roomId });
  return roomId;
}

describe("roomInvitations.respond on a dead room", () => {
  test("returns gone and the stale invitation is deleted", async () => {
    const t = convexTest(schema);
    const owner = await signUp(t, "owner");
    const guest = await signUp(t, "guest");
    const roomId = await group(t, owner);
    await t.mutation(api.roomInvitations.invite, {
      ...as(owner),
      roomId,
      inviteeId: guest.userId,
    });
    const [inv] = await rows(t, "roomInvitations");
    expect(inv.status).toBe("pending");
    await t.run((ctx) => ctx.db.patch(roomId, { deletingAt: Date.now() }));

    const out = await t.mutation(api.roomInvitations.respond, {
      ...as(guest),
      invitationId: inv._id,
      accept: true,
    });
    expect(out).toEqual({ status: "gone", roomId });
    expect(await rows(t, "roomInvitations")).toHaveLength(0);
  });

  test("a room row that is simply missing behaves the same", async () => {
    const t = convexTest(schema);
    const owner = await signUp(t, "owner");
    const guest = await signUp(t, "guest");
    const roomId = await group(t, owner);
    await t.mutation(api.roomInvitations.invite, {
      ...as(owner),
      roomId,
      inviteeId: guest.userId,
    });
    const [inv] = await rows(t, "roomInvitations");
    await t.run((ctx) => ctx.db.delete(roomId));
    const out: any = await t.mutation(api.roomInvitations.respond, {
      ...as(guest),
      invitationId: inv._id,
      accept: true,
    });
    expect(out.status).toBe("gone");
    expect(await rows(t, "roomInvitations")).toHaveLength(0);
  });
});

describe("games and a departing member", () => {
  async function liveGame(t: T) {
    const a = await signUp(t, "ada");
    const b = await signUp(t, "bob");
    const c = await signUp(t, "cem");
    const roomId = await group(t, a, b, c);
    const { matchId } = (await t.mutation(api.matches.create, {
      ...as(a),
      roomId,
      game: "tictactoe",
      mode: "live",
    })) as any;
    await t.mutation(api.matches.join, { ...as(b), matchId });
    await t.mutation(api.matches.setReady, { ...as(a), matchId, ready: true });
    await t.mutation(api.matches.setReady, { ...as(b), matchId, ready: true });
    return { a, b, c, roomId, matchId };
  }

  test("leaving the room removes the leaver's heartbeat there, and only there", async () => {
    const t = convexTest(schema);
    const { a, c, roomId, matchId } = await liveGame(t);
    const other = await group(t, a, c);
    const { matchId: otherMatch } = (await t.mutation(api.matches.create, {
      ...as(a),
      roomId: other,
      game: "tictactoe",
      mode: "live",
    })) as any;
    await t.mutation(api.matches.beat, { ...as(c), matchId });
    await t.mutation(api.matches.beat, { ...as(c), matchId: otherMatch });
    const beatsOf = async (who: Who) =>
      (await rows(t, "matchPresence")).filter((r) => r.userId === who.userId);
    expect(await beatsOf(c)).toHaveLength(2);

    await t.mutation(api.rooms.leave, { ...as(c), roomId });
    const left = await beatsOf(c);
    expect(left).toHaveLength(1);
    expect(left[0].matchId).toBe(otherMatch);
  });

  test("a heartbeat on an already finished game is left to match retention", async () => {
    const t = convexTest(schema);
    const { a, b, c, roomId, matchId } = await liveGame(t);
    await t.mutation(api.matches.beat, { ...as(c), matchId });
    // b leaves: the game finishes with c still holding a heartbeat row.
    await t.mutation(api.rooms.leave, { ...as(b), roomId });
    expect(((await get(t, matchId)) as any).status).toBe("finished");
    const beatsOfC = async () =>
      (await rows(t, "matchPresence")).filter((r) => r.userId === c.userId);
    expect(await beatsOfC()).toHaveLength(1);
    // Leaving sweeps only OPEN games (bounded); the finished game's row goes
    // with the match (retention) or the account (deletion cascade).
    await t.mutation(api.rooms.leave, { ...as(c), roomId });
    expect(await beatsOfC()).toHaveLength(1);
    void a;
  });

  test("finishing a game clears its watchers", async () => {
    const t = convexTest(schema);
    const { b, c, roomId, matchId } = await liveGame(t);
    await t.run((ctx) => ctx.db.patch(matchId, { watchers: [c.userId] }));
    await t.mutation(api.rooms.leave, { ...as(b), roomId });
    const m: any = await get(t, matchId);
    expect(m.status).toBe("finished");
    expect(m.watchers).toBeUndefined();
  });
});

describe("account deletion and rooms.createdBy", () => {
  const mkUser = (t: T, username: string) =>
    t.run((ctx) =>
      ctx.db.insert("users", { username, passwordHash: "x", createdAt: 1 }),
    );
  const mkRoom = (t: T, createdBy: Id<"users">) =>
    t.run((ctx) =>
      ctx.db.insert("rooms", {
        name: `room${Math.random()}`,
        createdBy,
        createdAt: 1,
        isPrivate: false,
        memberCount: 0,
      }),
    );
  const join = (t: T, roomId: Id<"rooms">, userId: Id<"users">, role: string) =>
    t.run(async (ctx) => {
      await ctx.db.insert("roomMembers", { roomId, userId, joinedAt: 1, role });
      await ctx.db.insert("roomAccess", { roomId, userId });
      const room = await ctx.db.get(roomId);
      await ctx.db.patch(roomId, { memberCount: room!.memberCount + 1 });
    });

  test("a creator who already left is replaced by the owner seat; ownerless rooms keep the id", async () => {
    const t = convexTest(schema);
    const creator = await mkUser(t, "creator");
    const owner = await mkUser(t, "owner");
    const member = await mkUser(t, "member");
    // Left earlier; the owner seat is someone else.
    const left = await mkRoom(t, creator);
    await join(t, left, owner, "owner");
    // Several, so the step pages (page size is 2 under shrinkTuning).
    const more = [await mkRoom(t, creator), await mkRoom(t, creator), await mkRoom(t, creator)];
    for (const r of more) await join(t, r, owner, "owner");
    // No owner seat at all: nothing to name.
    const ownerless = await mkRoom(t, creator);
    await join(t, ownerless, member, "member");
    // Someone else's room is untouched.
    const theirs = await mkRoom(t, owner);
    await join(t, theirs, owner, "owner");

    await t.run((ctx) => startUserDeletion(ctx, creator, { reason: "self" }));
    await drainDeletions(t, vi.runAllTimers);

    expect(await get(t, creator)).toBeNull();
    for (const r of [left, ...more]) expect(((await get(t, r)) as any).createdBy).toBe(owner);
    expect(((await get(t, ownerless)) as any).createdBy).toBe(creator);
    expect(((await get(t, theirs)) as any).createdBy).toBe(owner);
  });
});

describe("scheduled sends with dead references", () => {
  async function schedule(t: T, who: Who, roomId: any, extra: Record<string, any>) {
    const id = await t.mutation(api.scheduledMessages.schedule, {
      ...as(who),
      roomId,
      content: "hello @cem",
      delayMs: 60 * 60 * 1000,
      clientId: "sch_x",
      ...extra,
    } as any);
    const row: any = await get(t, id);
    await t.mutation(internal.scheduledMessages.release, { id, expectSendAt: row.sendAt });
  }

  test("a mentioned person who left or was deleted is dropped; the rest stay", async () => {
    const t = convexTest(schema);
    const a = await signUp(t, "ada");
    const b = await signUp(t, "bob");
    const c = await signUp(t, "cem");
    const roomId = await group(t, a, b, c);
    await t.mutation(api.rooms.leave, { ...as(c), roomId });
    await schedule(t, a, roomId, {
      content: "hi @bob and @cem",
      mentionedUserIds: [b.userId, c.userId],
    });
    const [m] = (await rows(t, "messages")).filter((x) => x.content?.startsWith("hi @bob"));
    expect(m.mentions.map((x: any) => x.username)).toEqual(["bob"]);
  });

  test("a reply to a deleted parent goes out as a plain message", async () => {
    const t = convexTest(schema);
    const a = await signUp(t, "ada");
    const roomId = await group(t, a);
    const parent = await t.mutation(api.messages.send, { ...as(a), roomId, content: "first" });
    const id = await t.mutation(api.scheduledMessages.schedule, {
      ...as(a),
      roomId,
      content: "answer",
      delayMs: 60 * 60 * 1000,
      clientId: "sch_reply",
      replyToId: parent,
    } as any);
    await t.run((ctx) => ctx.db.delete(parent as any));
    const row: any = await get(t, id);
    await t.mutation(internal.scheduledMessages.release, { id, expectSendAt: row.sendAt });
    const [m] = (await rows(t, "messages")).filter((x) => x.content === "answer");
    expect(m).toBeDefined();
    expect(m.replyToId).toBeUndefined();
    expect(m.replyToPreview).toBeUndefined();
  });
});

describe("the sticker picker", () => {
  test("drops personal stickers that are gone or deleted, keeps official and GIF entries", async () => {
    const t = convexTest(schema);
    const a = await signUp(t, "ada");
    const { gone, soft, live, official } = await t.run(async (ctx) => {
      const file = await ctx.storage.store(new Blob(["x"]));
      const pack = await ctx.db.insert("stickerPacks", {
        kind: "personal",
        ownerId: a.userId,
        title: "mine",
        slug: "personal:test",
        order: 0,
        createdAt: 1,
      } as any);
      const mk = (deletedAt?: number) =>
        ctx.db.insert("stickers", {
          packId: pack,
          storageId: file,
          format: "image",
          emoji: "x",
          width: 1,
          height: 1,
          order: 0,
          createdAt: 1,
          deletedAt,
        } as any);
      const gone = await mk();
      await ctx.db.delete(gone);
      return { gone, soft: await mk(5), live: await mk(), official: await mk() };
    });
    await t.run(async (ctx) => {
      const file = (await ctx.db.get(live as any)) as any;
      const r = (id: any, source: string) => ({
        kind: "sticker", source, stickerId: id, storageId: file.storageId,
      });
      await ctx.db.insert("userExpressions", {
        userId: a.userId,
        recents: [r(gone, "personal"), r(soft, "personal"), r(live, "personal"), r(official, "pack")],
        favorites: [r(gone, "personal")],
        updatedAt: 1,
      } as any);
    });
    const s: any = await t.query(api.expressions.state, { sessionToken: a.token } as any);
    expect(s.recents.map((x: any) => x.stickerId)).toEqual([live, official]);
    expect(s.favorites).toEqual([]);
  });
});
