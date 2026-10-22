import { convexTest } from "convex-test";
import { afterEach, beforeEach, describe, expect, test, vi } from "vitest";
import { api } from "./_generated/api";
import { MAX_ROOMS_PER_USER } from "./roomAdmin";
import { drainDeletions } from "./deletionTestUtils";
import schema from "./schema";

/**
 * Phase 0 of the data-integrity plan, rooms and membership.
 *
 *   5. leaving or being removed takes you out of the room's live group call;
 *      deleting the room ends live calls;
 *   6. the per-user room cap holds on every path that inserts a membership;
 *   8. leaving or being removed cancels your queued messages for that room;
 *  11. a decided room-photo request does not keep pointing at a released file.
 */

type T = ReturnType<typeof convexTest>;

// Deleting an account or a room finishes in the background (the lifecycle
// engine's scheduled steps), so assertions about the end state drain first.
beforeEach(() => {
  vi.useFakeTimers();
});
afterEach(() => {
  vi.useRealTimers();
});
// Only the zero-delay links fire: `runAllTimers` would also fire the 30 s ring
// timeouts of the calls under test, racing the teardown that is supposed to end
// them (a real call's timeout is 30 s away, the teardown's first step is not).
const drain = (t: ReturnType<typeof convexTest>) =>
  drainDeletions(t, () => vi.advanceTimersByTime(0));
type Who = { token: string; userId: string };

const signUp = (t: T, username: string): Promise<Who> =>
  t.mutation(api.auth.signup, {
    username,
    name: username,
    passwordHash: `hash-${username}`,
    recoveryKeyHash: `recovery-${username}`,
    deviceId: `device-${username}`,
  }) as any;

const as = (w: Who) => ({ sessionToken: w.token, userId: w.userId as any });

async function groupOfThree(t: T) {
  const owner = await signUp(t, "owner");
  const alice = await signUp(t, "alice");
  const bob = await signUp(t, "bob");
  const roomId = await t.mutation(api.rooms.create, {
    ...as(owner),
    name: "crew",
    isPrivate: false,
  });
  for (const w of [alice, bob]) {
    await t.mutation(api.rooms.join, { ...as(w), roomId });
  }
  return { owner, alice, bob, roomId };
}

const upload = (t: T) =>
  t.run(async (ctx: any) => await ctx.storage.store(new Blob(["x"], { type: "image/jpeg" })));
/**
 * A file from before references: it has a ledger row but is not `tracked`, so
 * "is it in use" is still answered by the old index checks. Both tests below
 * put a room on a file by writing the column directly, which is exactly what
 * such a room looks like.
 */
const legacyUpload = async (t: T, owner: Who) => {
  const id = await upload(t);
  await t.run(async (ctx: any) =>
    ctx.db.insert("uploads", {
      storageId: id,
      userId: owner.userId as any,
      size: 1,
      createdAt: Date.now(),
      tracked: false,
    }),
  );
  return id;
};
const stored = (t: T, id: any) =>
  t.run(async (ctx: any) => (await ctx.storage.get(id)) !== null);
const get = (t: T, id: any) => t.run(async (ctx: any) => await ctx.db.get(id));

async function startGroupCall(t: T, starter: Who, roomId: any) {
  const res: any = await t.mutation(api.groupCalls.start, {
    ...as(starter),
    roomId,
    type: "audio",
    deviceId: "d-start",
  });
  return res.groupCallId;
}

async function participant(t: T, groupCallId: any, who: Who) {
  return await t.run(async (ctx: any) =>
    ctx.db
      .query("groupCallParticipants")
      .withIndex("by_call_user", (q: any) =>
        q.eq("groupCallId", groupCallId).eq("userId", who.userId),
      )
      .first(),
  );
}

// ───────────────────────────── item 5 ─────────────────────────────

describe("calls follow membership", () => {
  test("a removed member is taken out of the live group call", async () => {
    const t = convexTest(schema);
    const { owner, alice, bob, roomId } = await groupOfThree(t);
    const callId = await startGroupCall(t, owner, roomId);
    await t.mutation(api.groupCalls.join, { ...as(alice), groupCallId: callId });
    await t.mutation(api.groupCalls.join, { ...as(bob), groupCallId: callId });

    await t.mutation(api.roomAdmin.removeMember, {
      ...as(owner),
      roomId,
      targetUserId: alice.userId as any,
    } as any);

    expect((await participant(t, callId, alice)).status).toBe("left");
    expect((await participant(t, callId, bob)).status).toBe("joined");
    const call: any = await get(t, callId);
    expect(call.status).toBe("active");
    expect(call.joinedUserIds.map(String).sort()).toEqual(
      [owner.userId, bob.userId].sort(),
    );
    // Their client's heartbeat learns it is out and lets go of its media.
    expect(
      await t.mutation(api.groupCalls.heartbeat, { ...as(alice), groupCallId: callId }),
    ).toBe("not-in-call");
  });

  test("leaving as the last one in the call ends it; an unanswered invite is declined", async () => {
    const t = convexTest(schema);
    const { owner, alice, roomId } = await groupOfThree(t);
    const callId = await startGroupCall(t, owner, roomId);
    // alice is still `invited`; the owner is the only one joined.
    expect((await participant(t, callId, alice)).status).toBe("invited");
    await t.mutation(api.rooms.leave, { ...as(alice), roomId });
    expect((await participant(t, callId, alice)).status).toBe("declined");

    await t.mutation(api.rooms.leave, { ...as(owner), roomId });
    expect(((await get(t, callId)) as any).status).toBe("ended");
  });

  test("deleting a room ends its live group call and its live 1:1 call", async () => {
    const t = convexTest(schema);
    const { owner, alice, bob, roomId } = await groupOfThree(t);
    const groupCallId = await startGroupCall(t, owner, roomId);
    await t.mutation(api.groupCalls.join, { ...as(alice), groupCallId });
    const callId = await t.mutation(api.calls.initiate, {
      sessionToken: bob.token,
      callerId: bob.userId as any,
      calleeId: alice.userId as any,
      roomId,
      type: "audio",
    });

    await t.mutation(api.rooms.deleteRoom, { ...as(owner), roomId } as any);
    await drain(t);

    expect(((await get(t, groupCallId)) as any).status).toBe("ended");
    expect((await participant(t, groupCallId, alice)).status).toBe("left");
    expect(((await get(t, callId)) as any).status).toBe("ended");
  });
});

// ───────────────────────────── item 6 ─────────────────────────────

describe("the room cap holds everywhere", () => {
  /** [who] already holds the maximum number of memberships. */
  async function fillToCap(t: T, who: Who, roomId: any) {
    await t.run(async (ctx: any) => {
      for (let i = 0; i < MAX_ROOMS_PER_USER; i++) {
        await ctx.db.insert("roomMembers", {
          roomId,
          userId: who.userId,
          joinedAt: i,
          role: "member",
        });
      }
      // Rows inserted by hand bypass `addMembership`, so keep the counter (the
      // thing the cap actually reads) in step with them.
      const counter = await ctx.db
        .query("userRoomCounts")
        .withIndex("by_user", (q: any) => q.eq("userId", who.userId))
        .first();
      if (counter) await ctx.db.patch(counter._id, { count: counter.count + MAX_ROOMS_PER_USER });
    });
  }

  test("creating a room at the cap is refused and leaves no room behind", async () => {
    const t = convexTest(schema);
    const { owner, alice, roomId } = await groupOfThree(t);
    await fillToCap(t, alice, roomId);

    await expect(
      t.mutation(api.rooms.create, { ...as(alice), name: "one more", isPrivate: true }),
    ).rejects.toThrow("TOO_MANY_ROOMS");
    const rooms = await t.run(async (ctx: any) =>
      ctx.db.query("rooms").withIndex("by_name", (q: any) => q.eq("name", "one more")).collect(),
    );
    expect(rooms).toHaveLength(0);
    // Sanity: the owner (not at the cap) still can.
    await t.mutation(api.rooms.create, { ...as(owner), name: "fine", isPrivate: true });
  });

  const befriend = (t: T, a: Who, b: Who) =>
    t.run(async (ctx: any) => {
      await ctx.db.insert("friendships", {
        userId: a.userId,
        friendId: b.userId,
        status: "accepted",
        createdAt: Date.now(),
      });
    });

  test("opening a DM with someone at the cap is refused", async () => {
    const t = convexTest(schema);
    const { owner, alice, roomId } = await groupOfThree(t);
    await befriend(t, owner, alice);
    await fillToCap(t, alice, roomId);
    await expect(
      t.mutation(api.rooms.getOrCreateDM, { ...as(owner), friendId: alice.userId as any }),
    ).rejects.toThrow("TOO_MANY_ROOMS");
  });

  test("the self-chat is exempt from the cap", async () => {
    const t = convexTest(schema);
    const { owner, roomId } = await groupOfThree(t);
    await fillToCap(t, owner, roomId);
    const self = await t.mutation(api.rooms.ensureSavedMessagesRoom, as(owner));
    expect(((await get(t, self)) as any).memberCount).toBe(1);
  });

  test("creating a room and a DM still count the members honestly", async () => {
    const t = convexTest(schema);
    const { owner, alice, roomId } = await groupOfThree(t);
    await befriend(t, owner, alice);
    expect(((await get(t, roomId)) as any).memberCount).toBe(3);
    const dm = await t.mutation(api.rooms.getOrCreateDM, {
      ...as(owner),
      friendId: alice.userId as any,
    });
    expect(((await get(t, dm)) as any).memberCount).toBe(2);
    const self = await t.mutation(api.rooms.ensureSavedMessagesRoom, as(owner));
    const row: any = await t.run(async (ctx: any) =>
      ctx.db
        .query("roomMembers")
        .withIndex("by_room_user", (q: any) => q.eq("roomId", self))
        .first(),
    );
    expect(row.role).toBe("owner");
    expect(row.isPinned).toBe(true);
    expect(((await get(t, self)) as any).memberCount).toBe(1);
  });
});

// ───────────────────────────── item 8 ─────────────────────────────

describe("queued messages do not outlive membership", () => {
  const schedule = (t: T, who: Who, roomId: any, clientId: string, storageId?: any) =>
    t.mutation(api.scheduledMessages.schedule, {
      ...as(who),
      roomId,
      content: "later",
      delayMs: 60 * 60 * 1000,
      clientId,
      ...(storageId
        ? { type: "image", mediaStorageId: storageId, mediaWidth: 10, mediaHeight: 10 }
        : {}),
    } as any);

  test("leaving cancels my queued messages and frees my queued photo, and only mine", async () => {
    const t = convexTest(schema);
    const { owner, alice, roomId } = await groupOfThree(t);
    const photo = await upload(t);
    const mine = await schedule(t, alice, roomId, "a1");
    const minePhoto = await schedule(t, alice, roomId, "a2", photo);
    const theirs = await schedule(t, owner, roomId, "o1");

    await t.mutation(api.rooms.leave, { ...as(alice), roomId });

    expect(await get(t, mine)).toBeNull();
    expect(await get(t, minePhoto)).toBeNull();
    expect(await stored(t, photo)).toBe(false);
    expect(await get(t, theirs)).not.toBeNull();
  });

  test("being removed does the same", async () => {
    const t = convexTest(schema);
    const { owner, alice, roomId } = await groupOfThree(t);
    const queued = await schedule(t, alice, roomId, "a1");
    await t.mutation(api.roomAdmin.removeMember, {
      ...as(owner),
      roomId,
      targetUserId: alice.userId as any,
    } as any);
    expect(await get(t, queued)).toBeNull();
  });

  test("queued messages for a different room are kept", async () => {
    const t = convexTest(schema);
    const { alice, roomId } = await groupOfThree(t);
    const other = await t.mutation(api.rooms.create, {
      ...as(alice),
      name: "elsewhere",
      isPrivate: true,
    });
    const keep = await schedule(t, alice, other, "k1");
    await t.mutation(api.rooms.leave, { ...as(alice), roomId });
    expect(await get(t, keep)).not.toBeNull();
  });
});

// ───────────────────────────── item 11 ─────────────────────────────

describe("a decided photo request holds no file", () => {
  async function proposal(t: T, member: Who, roomId: any) {
    const storageId = await upload(t);
    const res: any = await t.mutation(api.roomChangeRequests.propose, {
      ...as(member),
      roomId,
      field: "avatar",
      storageId,
    });
    return { storageId, requestId: res.requestId };
  }
  const decide = (t: T, admin: Who, requestId: any, approve: boolean) =>
    t.mutation(api.roomChangeRequests.decide, { ...as(admin), requestId, approve });

  test("rejecting releases the file and clears the row's pointer", async () => {
    const t = convexTest(schema);
    const { owner, alice, roomId } = await groupOfThree(t);
    const { storageId, requestId } = await proposal(t, alice, roomId);
    await decide(t, owner, requestId, false);
    expect(await stored(t, storageId)).toBe(false);
    const row: any = await get(t, requestId);
    expect(row.status).toBe("rejected");
    expect(row.storageId).toBeUndefined();
  });

  test("approving keeps the file (it is the room's) but the row lets go; replacing it later leaves nothing dangling", async () => {
    const t = convexTest(schema);
    const { owner, alice, roomId } = await groupOfThree(t);
    const { storageId, requestId } = await proposal(t, alice, roomId);
    await decide(t, owner, requestId, true);
    expect(await stored(t, storageId)).toBe(true);
    expect(((await get(t, roomId)) as any).avatarStorageId).toBe(storageId);
    expect(((await get(t, requestId)) as any).storageId).toBeUndefined();

    const next = await upload(t);
    await t.mutation(api.rooms.updateRoomAvatar, { ...as(owner), roomId, storageId: next });
    expect(await stored(t, storageId)).toBe(false);
    expect(((await get(t, requestId)) as any).storageId).toBeUndefined();
  });

  test("a row approved before this fix (still pointing at the photo) is cleared when the photo is replaced", async () => {
    const t = convexTest(schema);
    const { owner, alice, roomId } = await groupOfThree(t);
    const { storageId, requestId } = await proposal(t, alice, roomId);
    await decide(t, owner, requestId, true);
    // Recreate the legacy shape.
    await t.run(async (ctx: any) => ctx.db.patch(requestId, { storageId }));

    const next = await upload(t);
    await t.mutation(api.rooms.updateRoomAvatar, { ...as(owner), roomId, storageId: next });
    expect(((await get(t, requestId)) as any).storageId).toBeUndefined();
  });
});

describe("one file, one pointer", () => {
  const propose = (t: T, who: Who, roomId: any, storageId: any) =>
    t.mutation(api.roomChangeRequests.propose, {
      ...as(who),
      roomId,
      field: "avatar",
      storageId,
    });

  test("a member cannot propose the file the room already shows", async () => {
    const t = convexTest(schema);
    const { alice, roomId } = await groupOfThree(t);
    const photo = await legacyUpload(t, alice);
    await t.run(async (ctx: any) => ctx.db.patch(roomId, { avatarStorageId: photo }));
    await expect(propose(t, alice, roomId, photo)).rejects.toThrow(
      "CHANGE_REQUEST_PHOTO_IN_USE",
    );
    // And leaving does not delete the room's photo.
    await t.mutation(api.rooms.leave, { ...as(alice), roomId });
    expect(await stored(t, photo)).toBe(true);
  });

  test("a file held by a pending request cannot be proposed again, and release keeps a live photo", async () => {
    const t = convexTest(schema);
    const { owner, alice, bob, roomId } = await groupOfThree(t);
    const photo = await legacyUpload(t, alice);
    const res: any = await propose(t, alice, roomId, photo);
    // Same owner, second room: refused.
    const other = await t.mutation(api.rooms.create, {
      ...as(alice),
      name: "second",
      isPrivate: false,
    });
    await t.mutation(api.rooms.join, { ...as(bob), roomId: other });
    await expect(propose(t, alice, roomId, photo)).rejects.toThrow("CHANGE_REQUEST_PHOTO_IN_USE");
    await expect(propose(t, alice, other, photo)).rejects.toThrow("CHANGE_REQUEST_PHOTO_IN_USE");

    // Release-side guard: even if a legacy duplicate pointer exists, a
    // rejection must not delete a file a room still shows.
    await t.run(async (ctx: any) => ctx.db.patch(roomId, { avatarStorageId: photo }));
    await t.mutation(api.roomChangeRequests.decide, {
      ...as(owner),
      requestId: res.requestId,
      approve: false,
    });
    expect(await stored(t, photo)).toBe(true);
  });
});
