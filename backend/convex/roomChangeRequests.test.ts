import { convexTest } from "convex-test";
import { afterEach, beforeEach, describe, expect, test, vi } from "vitest";
import { api } from "./_generated/api";
import { drainDeletions } from "./deletionTestUtils";
import schema from "./schema";

// Deleting an account or a room finishes in the background (the lifecycle
// engine's scheduled steps), so assertions about the end state drain first.
beforeEach(() => {
  vi.useFakeTimers();
});
afterEach(() => {
  vi.useRealTimers();
});
const drain = (t: ReturnType<typeof convexTest>) => drainDeletions(t, vi.runAllTimers);

/**
 * A member suggesting a change to a group they cannot edit, actually executed.
 *
 * `tsc` covers the shapes. What it cannot cover are the four claims this
 * feature makes that are promises rather than behaviours:
 *
 *   1. **A member still cannot edit the room.** Proposing must leave `rooms`
 *      untouched until an admin says yes. If that is wrong, the admin-only
 *      rule this whole feature exists to preserve is gone and the queue is
 *      decoration.
 *   2. **Only an admin decides, and only the author withdraws.** Two
 *      different people, two different powers, and each must be refused the
 *      other's.
 *   3. **Files do not leak, and files that are in use are not deleted.** A
 *      rejected or withdrawn photo is the last pointer to its bytes and must
 *      be released; an APPROVED one is the room's live avatar and must not be,
 *      by any teardown path.
 *   4. **A suggestion cannot outlive the standing that produced it.** Leaving
 *      the room, being removed, and the room being deleted each have to take
 *      the pending row with them, or an admin is left with a queue item about
 *      somebody who is not there.
 *
 * Plus the replacement rule, which is the entire flood control and is exactly
 * the sort of thing that is quietly wrong for a month.
 */

const DEVICE = "device-a";

async function signUp(t: ReturnType<typeof convexTest>, username: string) {
  return await t.mutation(api.auth.signup, {
    username,
    name: username,
    passwordHash: `hash-${username}`,
    recoveryKeyHash: `recovery-${username}`,
    // One device per person: a deviceId is one handset, and signing in
    // on it signs out whoever was there before.
    deviceId: `device-${username}`,
  });
}

type Who = { token: string; userId: string };

/** A public group with [owner] as its owner, ready for others to join. */
async function makeRoom(
  t: ReturnType<typeof convexTest>,
  owner: Who,
  name = "the group",
) {
  return await t.mutation(api.rooms.create, {
    sessionToken: owner.token,
    userId: owner.userId as any,
    name,
    isPrivate: false,
  });
}

async function join(t: ReturnType<typeof convexTest>, who: Who, roomId: any) {
  await t.mutation(api.rooms.join, {
    sessionToken: who.token,
    userId: who.userId as any,
    roomId,
  });
}

/** A real file in `_storage`, so the blob assertions are about real bytes. */
async function upload(t: ReturnType<typeof convexTest>, body = "picture") {
  return await t.run(async (ctx: any) => await ctx.storage.store(new Blob([body])));
}

async function stored(t: ReturnType<typeof convexTest>, storageId: any) {
  return await t.run(async (ctx: any) => (await ctx.storage.get(storageId)) !== null);
}

async function roomRow(t: ReturnType<typeof convexTest>, roomId: any) {
  return await t.run(async (ctx: any) => await ctx.db.get(roomId));
}

async function propose(
  t: ReturnType<typeof convexTest>,
  who: Who,
  roomId: any,
  args: { field: string; value?: string; storageId?: any },
) {
  return await t.mutation(api.roomChangeRequests.propose, {
    sessionToken: who.token,
    userId: who.userId as any,
    roomId,
    ...args,
  });
}

async function pending(t: ReturnType<typeof convexTest>, who: Who, roomId: any) {
  return (await t.query(api.roomChangeRequests.listPending, {
    sessionToken: who.token,
    userId: who.userId as any,
    roomId,
  })) as any[];
}

async function myPending(t: ReturnType<typeof convexTest>, who: Who, roomId: any) {
  return (await t.query(api.roomChangeRequests.mine, {
    sessionToken: who.token,
    userId: who.userId as any,
    roomId,
  })) as any[];
}

describe("a suggestion is not an edit", () => {
  test("a member's proposal leaves the room exactly as it was", async () => {
    const t = convexTest(schema);
    const owner = await signUp(t, "owner");
    const member = await signUp(t, "member");
    const roomId = await makeRoom(t, owner);
    await join(t, member, roomId);

    const res = await propose(t, member, roomId, {
      field: "name",
      value: "Trip 2026",
    });
    expect(res.status).toBe("pending");

    const room = await roomRow(t, roomId);
    expect(room.name).toBe("the group");
    expect(await pending(t, owner, roomId)).toHaveLength(1);
  });

  test("a member cannot reach the room through the ordinary edit either", async () => {
    const t = convexTest(schema);
    const owner = await signUp(t, "owner");
    const member = await signUp(t, "member");
    const roomId = await makeRoom(t, owner);
    await join(t, member, roomId);

    // The rule this feature is built around. If this ever passes, everything
    // below is ceremony around a door that is already open.
    await expect(
      t.mutation(api.rooms.updateRoom, {
        sessionToken: member.token,
        userId: member.userId as any,
        roomId,
        name: "mine now",
      }),
    ).rejects.toThrow(/NOT_ADMIN/);
  });

  test("an approval is what writes, and it writes the proposed value", async () => {
    const t = convexTest(schema);
    const owner = await signUp(t, "owner");
    const member = await signUp(t, "member");
    const roomId = await makeRoom(t, owner);
    await join(t, member, roomId);

    await propose(t, member, roomId, { field: "name", value: "Trip 2026" });
    const [row] = await pending(t, owner, roomId);
    // The admin gets the room's CURRENT value alongside the proposal, so the
    // sheet can show "the group → Trip 2026" without a second read.
    expect(row.currentValue).toBe("the group");

    await t.mutation(api.roomChangeRequests.decide, {
      sessionToken: owner.token,
      userId: owner.userId as any,
      requestId: row.requestId,
      approve: true,
    });

    expect((await roomRow(t, roomId)).name).toBe("Trip 2026");
    expect(await pending(t, owner, roomId)).toHaveLength(0);
  });

  test("a rejection changes nothing and clears the queue", async () => {
    const t = convexTest(schema);
    const owner = await signUp(t, "owner");
    const member = await signUp(t, "member");
    const roomId = await makeRoom(t, owner);
    await join(t, member, roomId);

    await propose(t, member, roomId, {
      field: "description",
      value: "for the trip",
    });
    const [row] = await pending(t, owner, roomId);
    await t.mutation(api.roomChangeRequests.decide, {
      sessionToken: owner.token,
      userId: owner.userId as any,
      requestId: row.requestId,
      approve: false,
    });

    expect((await roomRow(t, roomId)).description).toBeUndefined();
    expect(await pending(t, owner, roomId)).toHaveLength(0);
    expect(await myPending(t, member, roomId)).toHaveLength(0);
  });

  test("an admin's own proposal applies immediately", async () => {
    const t = convexTest(schema);
    const owner = await signUp(t, "owner");
    const roomId = await makeRoom(t, owner);

    // The promoted-mid-edit race, and the only way a caller sees "applied".
    const res = await propose(t, owner, roomId, {
      field: "description",
      value: "straight through",
    });
    expect(res.status).toBe("applied");
    expect((await roomRow(t, roomId)).description).toBe("straight through");
    expect(await pending(t, owner, roomId)).toHaveLength(0);
  });
});

describe("who may answer, and who may take it back", () => {
  test("a plain member cannot decide, not even their own", async () => {
    const t = convexTest(schema);
    const owner = await signUp(t, "owner");
    const member = await signUp(t, "member");
    const roomId = await makeRoom(t, owner);
    await join(t, member, roomId);

    await propose(t, member, roomId, { field: "name", value: "Trip 2026" });
    const [row] = await pending(t, owner, roomId);

    await expect(
      t.mutation(api.roomChangeRequests.decide, {
        sessionToken: member.token,
        userId: member.userId as any,
        requestId: row.requestId,
        approve: true,
      }),
    ).rejects.toThrow(/NOT_ADMIN/);
    expect((await roomRow(t, roomId)).name).toBe("the group");
  });

  test("the queue is invisible to everybody but an admin", async () => {
    const t = convexTest(schema);
    const owner = await signUp(t, "owner");
    const member = await signUp(t, "member");
    const other = await signUp(t, "other");
    const roomId = await makeRoom(t, owner);
    await join(t, member, roomId);
    await join(t, other, roomId);

    await propose(t, member, roomId, { field: "name", value: "Trip 2026" });

    // Empty rather than an error: a demoted admin's open screen should empty,
    // not break.
    expect(await pending(t, other, roomId)).toHaveLength(0);
    // But the author can always see their own.
    expect(await myPending(t, member, roomId)).toHaveLength(1);
    expect(await myPending(t, other, roomId)).toHaveLength(0);
  });

  test("only the author withdraws", async () => {
    const t = convexTest(schema);
    const owner = await signUp(t, "owner");
    const member = await signUp(t, "member");
    const other = await signUp(t, "other");
    const roomId = await makeRoom(t, owner);
    await join(t, member, roomId);
    await join(t, other, roomId);

    await propose(t, member, roomId, { field: "name", value: "Trip 2026" });
    const [row] = await pending(t, owner, roomId);

    // Not another member, and not even an admin — an admin who wants it gone
    // rejects it, which tells the author what happened.
    await expect(
      t.mutation(api.roomChangeRequests.withdraw, {
        sessionToken: other.token,
        userId: other.userId as any,
        requestId: row.requestId,
      }),
    ).rejects.toThrow(/CHANGE_REQUEST_NOT_YOURS/);
    await expect(
      t.mutation(api.roomChangeRequests.withdraw, {
        sessionToken: owner.token,
        userId: owner.userId as any,
        requestId: row.requestId,
      }),
    ).rejects.toThrow(/CHANGE_REQUEST_NOT_YOURS/);

    await t.mutation(api.roomChangeRequests.withdraw, {
      sessionToken: member.token,
      userId: member.userId as any,
      requestId: row.requestId,
    });
    expect(await pending(t, owner, roomId)).toHaveLength(0);
  });

  test("an admin demoted since the notification is refused", async () => {
    const t = convexTest(schema);
    const owner = await signUp(t, "owner");
    const deputy = await signUp(t, "deputy");
    const member = await signUp(t, "member");
    const roomId = await makeRoom(t, owner);
    await join(t, deputy, roomId);
    await join(t, member, roomId);
    await t.mutation(api.roomAdmin.setAdmin, {
      sessionToken: owner.token,
      userId: owner.userId as any,
      roomId,
      targetUserId: deputy.userId as any,
      makeAdmin: true,
    });

    await propose(t, member, roomId, { field: "name", value: "Trip 2026" });
    const [row] = await pending(t, deputy, roomId);

    await t.mutation(api.roomAdmin.setAdmin, {
      sessionToken: owner.token,
      userId: owner.userId as any,
      roomId,
      targetUserId: deputy.userId as any,
      makeAdmin: false,
    });

    // Rank is read at the decision, not at the notification.
    await expect(
      t.mutation(api.roomChangeRequests.decide, {
        sessionToken: deputy.token,
        userId: deputy.userId as any,
        requestId: row.requestId,
        approve: true,
      }),
    ).rejects.toThrow(/NOT_ADMIN/);
  });
});

describe("one pending suggestion per person per field", () => {
  test("proposing again replaces rather than queues", async () => {
    const t = convexTest(schema);
    const owner = await signUp(t, "owner");
    const member = await signUp(t, "member");
    const roomId = await makeRoom(t, owner);
    await join(t, member, roomId);

    await propose(t, member, roomId, { field: "name", value: "first" });
    await propose(t, member, roomId, { field: "name", value: "second" });

    const rows = await pending(t, owner, roomId);
    expect(rows).toHaveLength(1);
    expect(rows[0].value).toBe("second");
  });

  test("the three fields queue independently", async () => {
    const t = convexTest(schema);
    const owner = await signUp(t, "owner");
    const member = await signUp(t, "member");
    const roomId = await makeRoom(t, owner);
    await join(t, member, roomId);

    await propose(t, member, roomId, { field: "name", value: "renamed" });
    await propose(t, member, roomId, { field: "description", value: "about" });
    await propose(t, member, roomId, {
      field: "avatar",
      storageId: await upload(t),
    });
    expect(await pending(t, owner, roomId)).toHaveLength(3);
  });

  test("suggesting what the room already says is refused", async () => {
    const t = convexTest(schema);
    const owner = await signUp(t, "owner");
    const member = await signUp(t, "member");
    const roomId = await makeRoom(t, owner);
    await join(t, member, roomId);

    await expect(
      propose(t, member, roomId, { field: "name", value: "  the group  " }),
    ).rejects.toThrow(/CHANGE_REQUEST_NO_CHANGE/);
  });

  test("an empty name and an unknown field are both refused", async () => {
    const t = convexTest(schema);
    const owner = await signUp(t, "owner");
    const member = await signUp(t, "member");
    const roomId = await makeRoom(t, owner);
    await join(t, member, roomId);

    await expect(
      propose(t, member, roomId, { field: "name", value: "   " }),
    ).rejects.toThrow(/CHANGE_REQUEST_MISSING_VALUE/);
    await expect(
      propose(t, member, roomId, { field: "passwordHash", value: "x" }),
    ).rejects.toThrow(/CHANGE_REQUEST_INVALID_FIELD/);
    await expect(
      propose(t, member, roomId, { field: "avatar" }),
    ).rejects.toThrow(/CHANGE_REQUEST_MISSING_VALUE/);
  });
});

describe("the bytes", () => {
  test("an approved photo becomes the room's avatar and survives", async () => {
    const t = convexTest(schema);
    const owner = await signUp(t, "owner");
    const member = await signUp(t, "member");
    const roomId = await makeRoom(t, owner);
    await join(t, member, roomId);

    const storageId = await upload(t, "the new photo");
    await propose(t, member, roomId, { field: "avatar", storageId });
    const [row] = await pending(t, owner, roomId);
    await t.mutation(api.roomChangeRequests.decide, {
      sessionToken: owner.token,
      userId: owner.userId as any,
      requestId: row.requestId,
      approve: true,
    });

    const room = await roomRow(t, roomId);
    expect(room.avatarStorageId).toBe(storageId);
    expect(await stored(t, storageId)).toBe(true);
  });

  test("approving releases the picture it replaced", async () => {
    const t = convexTest(schema);
    const owner = await signUp(t, "owner");
    const member = await signUp(t, "member");
    const roomId = await makeRoom(t, owner);
    await join(t, member, roomId);

    const old = await upload(t, "the old photo");
    await t.mutation(api.rooms.updateRoomAvatar, {
      sessionToken: owner.token,
      userId: owner.userId as any,
      roomId,
      storageId: old,
    });

    const fresh = await upload(t, "the new photo");
    await propose(t, member, roomId, { field: "avatar", storageId: fresh });
    const [row] = await pending(t, owner, roomId);
    await t.mutation(api.roomChangeRequests.decide, {
      sessionToken: owner.token,
      userId: owner.userId as any,
      requestId: row.requestId,
      approve: true,
    });

    // The same sweep `rooms.updateRoomAvatar` does on its own side. Without it
    // every accepted suggestion leaks one picture, forever.
    expect(await stored(t, old)).toBe(false);
    expect(await stored(t, fresh)).toBe(true);
  });

  test("a rejected photo is released", async () => {
    const t = convexTest(schema);
    const owner = await signUp(t, "owner");
    const member = await signUp(t, "member");
    const roomId = await makeRoom(t, owner);
    await join(t, member, roomId);

    const storageId = await upload(t);
    await propose(t, member, roomId, { field: "avatar", storageId });
    const [row] = await pending(t, owner, roomId);
    await t.mutation(api.roomChangeRequests.decide, {
      sessionToken: owner.token,
      userId: owner.userId as any,
      requestId: row.requestId,
      approve: false,
    });
    expect(await stored(t, storageId)).toBe(false);
    expect((await roomRow(t, roomId)).avatarStorageId).toBeUndefined();
  });

  test("a withdrawn photo is released, and so is a replaced one", async () => {
    const t = convexTest(schema);
    const owner = await signUp(t, "owner");
    const member = await signUp(t, "member");
    const roomId = await makeRoom(t, owner);
    await join(t, member, roomId);

    const first = await upload(t, "first pick");
    await propose(t, member, roomId, { field: "avatar", storageId: first });
    const second = await upload(t, "second pick");
    await propose(t, member, roomId, { field: "avatar", storageId: second });
    // Changing your mind must not leave the first upload paid for forever.
    expect(await stored(t, first)).toBe(false);

    const [row] = await myPending(t, member, roomId);
    await t.mutation(api.roomChangeRequests.withdraw, {
      sessionToken: member.token,
      userId: member.userId as any,
      requestId: row.requestId,
    });
    expect(await stored(t, second)).toBe(false);
  });
});

describe("a suggestion cannot outlive the standing that produced it", () => {
  test("leaving the room takes the pending row and its file", async () => {
    const t = convexTest(schema);
    const owner = await signUp(t, "owner");
    const member = await signUp(t, "member");
    const roomId = await makeRoom(t, owner);
    await join(t, member, roomId);

    const storageId = await upload(t);
    await propose(t, member, roomId, { field: "avatar", storageId });
    await t.mutation(api.rooms.leave, {
      sessionToken: member.token,
      userId: member.userId as any,
      roomId,
    });

    expect(await pending(t, owner, roomId)).toHaveLength(0);
    expect(await stored(t, storageId)).toBe(false);
  });

  test("being removed does the same", async () => {
    const t = convexTest(schema);
    const owner = await signUp(t, "owner");
    const member = await signUp(t, "member");
    const roomId = await makeRoom(t, owner);
    await join(t, member, roomId);

    await propose(t, member, roomId, { field: "name", value: "Trip 2026" });
    await t.mutation(api.roomAdmin.removeMember, {
      sessionToken: owner.token,
      userId: owner.userId as any,
      roomId,
      targetUserId: member.userId as any,
    });
    expect(await pending(t, owner, roomId)).toHaveLength(0);
  });

  test("deleting the room releases a pending photo", async () => {
    const t = convexTest(schema);
    const owner = await signUp(t, "owner");
    const member = await signUp(t, "member");
    const roomId = await makeRoom(t, owner);
    await join(t, member, roomId);

    const storageId = await upload(t);
    await propose(t, member, roomId, { field: "avatar", storageId });
    await t.mutation(api.rooms.deleteRoom, {
      sessionToken: owner.token,
      userId: owner.userId as any,
      roomId,
    });
    await drain(t);

    expect(await stored(t, storageId)).toBe(false);
    const rows = await t.run(
      async (ctx: any) => await ctx.db.query("roomChangeRequests").collect(),
    );
    expect(rows).toHaveLength(0);
  });

  test("deleting the author's account does not break a room they decorated", async () => {
    const t = convexTest(schema);
    const owner = await signUp(t, "owner");
    const member = await signUp(t, "member");
    const roomId = await makeRoom(t, owner);
    await join(t, member, roomId);

    const live = await upload(t, "the accepted photo");
    await propose(t, member, roomId, { field: "avatar", storageId: live });
    const [row] = await pending(t, owner, roomId);
    await t.mutation(api.roomChangeRequests.decide, {
      sessionToken: owner.token,
      userId: owner.userId as any,
      requestId: row.requestId,
      approve: true,
    });

    await t.mutation(api.auth.deleteAccount, {
      sessionToken: member.token,
      userId: member.userId as any,
    });
    await drain(t);

    // The approved row goes; the file it handed the room does NOT. Freeing it
    // here would leave a group everybody is still in with a broken picture.
    expect((await roomRow(t, roomId)).avatarStorageId).toBe(live);
    expect(await stored(t, live)).toBe(true);
  });
});

describe("the notifications actually dispatch", () => {
  /**
   * A scheduled action's arguments are validated when it FIRES, which is after
   * the mutation that queued it has already returned successfully. So a wrong
   * shape here is invisible in every other test in this file and shows up in
   * production as a notification that silently never arrives.
   *
   * `finishInProgressScheduledFunctions` is the only thing that catches it.
   * The push itself reaches no device — these accounts have no tokens — so
   * what is under test is strictly that the handlers accept what they are
   * given, for all three fields and both decisions.
   */
  async function drain(t: ReturnType<typeof convexTest>) {
    await t.finishInProgressScheduledFunctions();
  }

  test("every field's proposal notifies the admins without throwing", async () => {
    const t = convexTest(schema);
    const owner = await signUp(t, "owner");
    const member = await signUp(t, "member");
    const roomId = await makeRoom(t, owner);
    await join(t, member, roomId);

    // The avatar and description branches carry NO `value`; the name branch
    // does. That asymmetry is the shape most likely to be wrong.
    await propose(t, member, roomId, {
      field: "avatar",
      storageId: await upload(t),
    });
    await propose(t, member, roomId, { field: "name", value: "Trip 2026" });
    await propose(t, member, roomId, { field: "description", value: "about" });
    await drain(t);
  });

  test("both decisions notify the author without throwing", async () => {
    const t = convexTest(schema);
    const owner = await signUp(t, "owner");
    const member = await signUp(t, "member");
    const roomId = await makeRoom(t, owner);
    await join(t, member, roomId);

    await propose(t, member, roomId, { field: "name", value: "Trip 2026" });
    await propose(t, member, roomId, { field: "description", value: "about" });
    const rows = await pending(t, owner, roomId);
    await t.mutation(api.roomChangeRequests.decide, {
      sessionToken: owner.token,
      userId: owner.userId as any,
      requestId: rows[0].requestId,
      approve: true,
    });
    await t.mutation(api.roomChangeRequests.decide, {
      sessionToken: owner.token,
      userId: owner.userId as any,
      requestId: rows[1].requestId,
      approve: false,
    });
    await drain(t);
  });
});

describe("permissions say which controls to draw", () => {
  test("review and suggest are complements, never both", async () => {
    const t = convexTest(schema);
    const owner = await signUp(t, "owner");
    const member = await signUp(t, "member");
    const roomId = await makeRoom(t, owner);
    await join(t, member, roomId);

    const asOwner = (await t.query(api.roomAdmin.myPermissions, {
      sessionToken: owner.token,
      userId: owner.userId as any,
      roomId,
    })) as any;
    const asMember = (await t.query(api.roomAdmin.myPermissions, {
      sessionToken: member.token,
      userId: member.userId as any,
      roomId,
    })) as any;

    expect(asOwner.canReviewChangeRequests).toBe(true);
    expect(asOwner.canSuggestChanges).toBe(false);
    expect(asMember.canReviewChangeRequests).toBe(false);
    expect(asMember.canSuggestChanges).toBe(true);
  });
});
