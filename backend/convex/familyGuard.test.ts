import { convexTest } from "convex-test";
import { describe, expect, test } from "vitest";
import { api } from "./_generated/api";
import schema from "./schema";

/**
 * The parent side of child accounts: who is allowed to decide, what a parent
 * is actually told is waiting, and the two ways a conversation could go
 * missing.
 *
 * Every test here was written against a real reported symptom rather than
 * against the code, which is why several of them assert about numbers a parent
 * SEES (`pendingCount`) rather than about rows in a table: the rows were
 * mostly right all along, and the bug was that nothing ever showed them.
 */

async function signUp(t: ReturnType<typeof convexTest>, username: string) {
  return await t.mutation(api.auth.signup, {
    username,
    name: username,
    passwordHash: `hash-${username}`,
    recoveryKeyHash: `recovery-${username}`,
    // One device per person: a deviceId is one physical handset, and signing
    // in on it ends whoever was signed in there before.
    deviceId: `device-${username}`,
  });
}

/** A guardian with one child, and a session for each. */
async function family(t: ReturnType<typeof convexTest>, kid = "lena") {
  const parent = await signUp(t, "parent");
  const child = await t.mutation(api.family.createChildAccount, {
    sessionToken: parent.token,
    guardianId: parent.userId,
    username: kid,
    name: kid,
  });
  // The child's own session, minted the way pairing actually mints it.
  const codeHash = `pair-${kid}`;
  await t.mutation(api.family.createPairingCode, {
    sessionToken: parent.token,
    guardianId: parent.userId,
    childId: child.userId,
    codeHash,
  });
  const redeemed = await t.mutation(api.family.redeemPairingCode as any, {
    codeHash,
    deviceId: "child-device",
    platform: "ios",
  });
  return { parent, child, childToken: redeemed.token };
}

async function makeRoom(
  t: ReturnType<typeof convexTest>,
  owner: { token: string; userId: string },
  name: string,
) {
  return await t.mutation(api.rooms.create, {
    sessionToken: owner.token,
    userId: owner.userId,
    name,
    isPrivate: false,
  });
}

describe("a request aimed at a child reaches the parent", () => {
  test("a room invite stops at the guardian even when the inviter is a whitelisted contact", async () => {
    const t = convexTest(schema);
    const { parent, child, childToken } = await family(t);
    const outsider = await signUp(t, "zeynepoz");

    // The parent has already vouched for this person AS A CONTACT.
    await t.mutation(api.family.allowContactByUsername, {
      sessionToken: parent.token,
      guardianId: parent.userId,
      childId: child.userId,
      username: "zeynepoz",
      sendRequestNow: false,
    });

    const room = await makeRoom(t, outsider, "minecraft");
    await t.mutation(api.roomInvitations.invite, {
      sessionToken: outsider.token,
      userId: outsider.userId,
      roomId: room,
      inviteeId: child.userId,
    });

    // The contact whitelist must NOT have waived this. "I trust them to talk
    // to my kid" is not "they may put my kid in a room full of strangers".
    const queue = await t.query(api.family.listGuardianQueue, {
      sessionToken: parent.token,
      guardianId: parent.userId,
    });
    expect(queue.map((q: any) => q.type)).toContain("roomInviteIncoming");

    // And the child cannot see it yet — asked as the child, for the reason in
    // the room-grant test below.
    const inbox = await t.query(api.roomInvitations.listIncoming, {
      sessionToken: childToken,
      userId: child.userId,
    });
    expect(inbox).toHaveLength(0);
  });

  test("that invite is counted in the number the parent's badge and banner read", async () => {
    const t = convexTest(schema);
    const { parent, child } = await family(t);
    const outsider = await signUp(t, "zeynepoz");
    const room = await makeRoom(t, outsider, "minecraft");

    const before = await t.query(api.family.getFamilyContext, {
      sessionToken: parent.token,
      userId: parent.userId,
    });
    expect(before.pendingCount).toBe(0);

    await t.mutation(api.roomInvitations.invite, {
      sessionToken: outsider.token,
      userId: outsider.userId,
      roomId: room,
      inviteeId: child.userId,
    });

    // This is the regression: the queue had the item all along, but the count
    // driving the badge, the banner and the only door into the queue ignored
    // both room-invitation hops — so the parent was never told.
    const after = await t.query(api.family.getFamilyContext, {
      sessionToken: parent.token,
      userId: parent.userId,
    });
    expect(after.pendingCount).toBe(1);
    expect(after.children[0].pendingCount).toBe(1);
  });

  test("approving it lets the child in, and the count goes back down", async () => {
    const t = convexTest(schema);
    const { parent, child, childToken } = await family(t);
    const outsider = await signUp(t, "zeynepoz");
    const room = await makeRoom(t, outsider, "minecraft");
    const invitationId = await t.mutation(api.roomInvitations.invite, {
      sessionToken: outsider.token,
      userId: outsider.userId,
      roomId: room,
      inviteeId: child.userId,
    });

    await t.mutation(api.roomInvitations.advance, {
      sessionToken: parent.token,
      invitationId,
      guardianId: parent.userId,
      approve: true,
    });

    const after = await t.query(api.family.getFamilyContext, {
      sessionToken: parent.token,
      userId: parent.userId,
    });
    expect(after.pendingCount).toBe(0);

    // Released to the child, who can now answer it themselves.
    const inbox = await t.query(api.roomInvitations.listIncoming, {
      sessionToken: childToken,
      userId: child.userId,
    });
    expect(inbox).toHaveLength(1);
  });

  test("a room whose members are all family needs no second approval", async () => {
    const t = convexTest(schema);
    const { parent, child } = await family(t);
    const room = await makeRoom(t, parent, "kitchen");

    await t.mutation(api.roomInvitations.invite, {
      sessionToken: parent.token,
      userId: parent.userId,
      roomId: room,
      inviteeId: child.userId,
    });

    // The guardian is the only other member, so the question has already been
    // answered by the act of asking it.
    const queue = await t.query(api.family.listGuardianQueue, {
      sessionToken: parent.token,
      guardianId: parent.userId,
    });
    expect(queue).toHaveLength(0);
  });
});

describe("only the child's own guardian may decide", () => {
  test("a stranger naming the parent's id cannot approve a request to their child", async () => {
    const t = convexTest(schema);
    const { parent, child } = await family(t);
    const outsider = await signUp(t, "zeynepoz");
    const room = await makeRoom(t, outsider, "minecraft");
    const invitationId = await t.mutation(api.roomInvitations.invite, {
      sessionToken: outsider.token,
      userId: outsider.userId,
      roomId: room,
      inviteeId: child.userId,
    });

    // The payload claims to be the parent. The SESSION is the outsider's, and
    // that is what has to win — otherwise anyone signed in could wave their
    // own request past somebody else's child.
    await expect(
      t.mutation(api.roomInvitations.advance, {
        sessionToken: outsider.token,
        invitationId,
        guardianId: parent.userId,
        approve: true,
      }),
    ).rejects.toThrow();

    const queue = await t.query(api.family.listGuardianQueue, {
      sessionToken: parent.token,
      guardianId: parent.userId,
    });
    expect(queue).toHaveLength(1);
  });

  test("a stranger cannot read another family's queue, loosen a policy, or delete a child", async () => {
    const t = convexTest(schema);
    const { parent, child } = await family(t);
    const outsider = await signUp(t, "zeynepoz");

    // Every one of these used to succeed: the handlers checked that the
    // CLAIMED guardian supervises the child, never that the caller is them.
    const queue = await t.query(api.family.listGuardianQueue, {
      sessionToken: outsider.token,
      guardianId: parent.userId,
    });
    expect(queue).toHaveLength(0);

    await expect(
      t.mutation(api.family.setChildPolicy, {
        sessionToken: outsider.token,
        guardianId: parent.userId,
        childId: child.userId,
        canCreateRooms: true,
      }),
    ).rejects.toThrow();

    await expect(
      t.mutation(api.family.deleteChildAccount, {
        sessionToken: outsider.token,
        guardianId: parent.userId,
        childId: child.userId,
      }),
    ).rejects.toThrow();

    await expect(
      t.mutation(api.family.allowContactByUsername, {
        sessionToken: outsider.token,
        guardianId: parent.userId,
        childId: child.userId,
        username: "zeynepoz",
        sendRequestNow: true,
      }),
    ).rejects.toThrow();
  });

  test("a co-parent can still be removed, but only by another grown-up", async () => {
    const t = convexTest(schema);
    const { parent, child } = await family(t);
    const other = await signUp(t, "otherparent");
    const outsider = await signUp(t, "zeynepoz");

    await t.mutation(api.family.addGuardian, {
      sessionToken: parent.token,
      guardianId: parent.userId,
      childId: child.userId,
      newGuardianUsername: "otherparent",
    });

    // Not yours to sever.
    await expect(
      t.mutation(api.family.unlinkChild, {
        sessionToken: outsider.token,
        guardianId: other.userId,
        childId: child.userId,
      }),
    ).rejects.toThrow();

    // But a real guardian may remove a co-parent — the one case where the
    // named guardian is deliberately somebody other than the caller.
    await t.mutation(api.family.unlinkChild, {
      sessionToken: parent.token,
      guardianId: other.userId,
      childId: child.userId,
    });
    const ctx = await t.query(api.family.getFamilyContext, {
      sessionToken: parent.token,
      userId: parent.userId,
    });
    expect(ctx.children[0].guardianCount).toBe(1);
  });
});

describe("a guardian can hand a room to a child directly", () => {
  test("the child joins, and the grant is revocable like any other", async () => {
    const t = convexTest(schema);
    const { parent, child, childToken } = await family(t);
    const room = await makeRoom(t, parent, "board-games");

    const offered = await t.query(api.family.grantableRooms, {
      sessionToken: parent.token,
      guardianId: parent.userId,
      childId: child.userId,
    });
    expect(offered.map((r: any) => r._id)).toContain(room);

    await t.mutation(api.family.grantRoomToChild, {
      sessionToken: parent.token,
      guardianId: parent.userId,
      childId: child.userId,
      roomId: room,
    });

    // Asked as the CHILD. `listUserRooms` binds `userId` to the session, so a
    // parent's token here would answer about the parent — which is exactly how
    // this assertion passed for the wrong reason on the first draft.
    const rooms = await t.query(api.rooms.listUserRooms, {
      sessionToken: childToken,
      userId: child.userId,
    });
    expect(rooms.map((r: any) => r._id)).toContain(room);

    // Offered once, not twice.
    const again = await t.query(api.family.grantableRooms, {
      sessionToken: parent.token,
      guardianId: parent.userId,
      childId: child.userId,
    });
    expect(again.map((r: any) => r._id)).not.toContain(room);

    // And it shows up where a parent takes things back.
    const grants = await t.query(api.family.listChildGrants, {
      sessionToken: parent.token,
      guardianId: parent.userId,
      childId: child.userId,
    });
    const granted = grants.rooms.find((r: any) => r._id === room);
    expect(granted).toBeTruthy();

    await t.mutation(api.family.revokeApproval, {
      sessionToken: parent.token,
      guardianId: parent.userId,
      approvalId: granted.approvalId,
    });
    const afterRevoke = await t.query(api.rooms.listUserRooms, {
      sessionToken: childToken,
      userId: child.userId,
    });
    expect(afterRevoke.map((r: any) => r._id)).not.toContain(room);
  });

  test("a room the guardian is not in cannot be handed over", async () => {
    const t = convexTest(schema);
    const { parent, child } = await family(t);
    const outsider = await signUp(t, "zeynepoz");
    const theirRoom = await makeRoom(t, outsider, "not-yours");

    await expect(
      t.mutation(api.family.grantRoomToChild, {
        sessionToken: parent.token,
        guardianId: parent.userId,
        childId: child.userId,
        roomId: theirRoom,
      }),
    ).rejects.toThrow();
  });
});

describe("a DM never goes missing for one side only", () => {
  test("reopening a DM one person walked out of puts them back in it", async () => {
    const t = convexTest(schema);
    const a = await signUp(t, "ada");
    const b = await signUp(t, "bela");

    // Friends, then a DM.
    await t.mutation(api.friends.createDirectRequest, {
      sessionToken: a.token,
      userId: a.userId,
      friendId: b.userId,
      roomType: "Regular Room",
    });
    await t.mutation(api.friends.approveDirectRequest, {
      sessionToken: b.token,
      userId: b.userId,
      requesterId: a.userId,
    });
    const roomId = await t.mutation(api.rooms.getOrCreateDM, {
      sessionToken: a.token,
      userId: a.userId,
      friendId: b.userId,
    });

    // One of them leaves. The room survives — a two-person room is only wiped
    // when the LAST member goes — so it is still findable by name.
    await t.mutation(api.rooms.leave, {
      sessionToken: a.token,
      roomId,
      userId: a.userId,
    });
    const gone = await t.query(api.rooms.listUserRooms, {
      sessionToken: a.token,
      userId: a.userId,
    });
    expect(gone.map((r: any) => r._id)).not.toContain(roomId);

    // Reopening it used to hand back the same room without restoring the
    // missing membership, which is how a conversation ended up visible to one
    // person and invisible to the other, permanently.
    const reopened = await t.mutation(api.rooms.getOrCreateDM, {
      sessionToken: a.token,
      userId: a.userId,
      friendId: b.userId,
    });
    expect(reopened).toBe(roomId);

    for (const who of [a, b]) {
      const rooms = await t.query(api.rooms.listUserRooms, {
        sessionToken: who.token,
        userId: who.userId,
      });
      expect(rooms.map((r: any) => r._id)).toContain(roomId);
    }
  });
});
