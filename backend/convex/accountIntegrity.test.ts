import { convexTest } from "convex-test";
import { describe, expect, test } from "vitest";
import { api, internal } from "./_generated/api";
import type { Id } from "./_generated/dataModel";
import * as auth from "./auth";
import { MAX_ROOM_MEMBERS, addMembership } from "./roomAdmin";
import { STAGE_RECIPIENT_GUARDIAN } from "./childGuard";
import { suspendAccount } from "./moderation";
import schema from "./schema";

/**
 * Phase 0 of the data-integrity plan, the account half: what deleting,
 * suspending, signing in and unlinking an account leaves behind.
 *
 * Every test sets its rows up directly with `t.run` where the setup is not the
 * thing under test, so the suite stays fast.
 */

type T = ReturnType<typeof convexTest>;

async function signUp(
  t: T,
  username: string,
  deviceId = `device-${username}`,
  deviceSecret?: string,
) {
  return await t.mutation(api.auth.signup, {
    username,
    name: username,
    passwordHash: `hash-${username}`,
    recoveryKeyHash: `recovery-${username}`,
    deviceId,
    ...(deviceSecret !== undefined ? { deviceSecret } : {}),
  });
}

/** A per-install secret as the client makes them: 64 hex characters. */
const SECRET_A = "a".repeat(64);
const SECRET_B = "b".repeat(64);

/** A guardian with one child, and the child's own session on "child-device". */
async function family(t: T) {
  const parent = await signUp(t, "parent");
  const child = await t.mutation(api.family.createChildAccount, {
    sessionToken: parent.token,
    guardianId: parent.userId,
    username: "lena",
    name: "lena",
  });
  const codeHash = "pair-lena";
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
  return { parent, child, childToken: redeemed.token as string };
}

/** Makes `other` a second guardian of the child. */
const coGuardian = (t: T, other: { userId: any }, childId: any) =>
  t.run((ctx) =>
    ctx.db.insert("guardianships", {
      guardianId: other.userId,
      childId,
      role: "guardian",
      createdAt: Date.now(),
    }),
  );

const makeRoom = (t: T, owner: { token: string; userId: any }, name: string) =>
  t.mutation(api.rooms.create, {
    sessionToken: owner.token,
    userId: owner.userId,
    name,
    isPrivate: false,
  });

/** Any authed call that only asks the session layer who you are. */
const probe = (t: T, who: { token: string; userId: any }, deviceId: string) =>
  t.query(api.voipTokens.listDevices, {
    sessionToken: who.token,
    userId: who.userId,
    deviceId,
  });

describe("item 1: the only guardian cannot delete their account", () => {
  test("refused while a child depends on them, allowed once there is a second", async () => {
    const t = convexTest(schema);
    const { parent, child } = await family(t);

    await expect(
      t.mutation(api.auth.deleteAccount, {
        sessionToken: parent.token,
        userId: parent.userId,
      }),
    ).rejects.toThrow("LAST_GUARDIAN");
    // Nothing was touched: still a guardian, still signed in.
    expect(
      await t.run((ctx) =>
        ctx.db
          .query("guardianships")
          .withIndex("by_child", (q) => q.eq("childId", child.userId))
          .collect(),
      ),
    ).toHaveLength(1);

    const other = await signUp(t, "other");
    await coGuardian(t, other, child.userId);
    await t.mutation(api.auth.deleteAccount, {
      sessionToken: parent.token,
      userId: parent.userId,
    });
    expect(await t.run((ctx) => ctx.db.get(parent.userId))).toBeNull();
    // The child is still supervised, by the other guardian.
    const links = await t.run((ctx) =>
      ctx.db
        .query("guardianships")
        .withIndex("by_child", (q) => q.eq("childId", child.userId))
        .collect(),
    );
    expect(links.map((l) => l.guardianId)).toEqual([other.userId]);
  });
});

describe("item 2: a co-guardian deleting their account keeps the child's permissions", () => {
  test("approvals and request history they decided survive, with the decider cleared", async () => {
    const t = convexTest(schema);
    const { parent, child } = await family(t);
    const other = await signUp(t, "other");
    await coGuardian(t, other, child.userId);
    const friend = await signUp(t, "grandma");

    // The other guardian whitelists a contact and approves a room.
    await t.mutation(api.family.allowContactByUsername, {
      sessionToken: other.token,
      guardianId: other.userId,
      childId: child.userId,
      username: "grandma",
      sendRequestNow: false,
    });
    const room = await makeRoom(t, friend, "minecraft");
    const rows = await t.run(async (ctx) => {
      const approval = await ctx.db.insert("approvalRequests", {
        childId: child.userId,
        kind: "joinRoom",
        status: "approved",
        targetRoomId: room,
        createdAt: 1,
        decidedAt: 2,
        decidedByGuardianId: other.userId,
      });
      const join = await ctx.db.insert("roomJoinRequests", {
        roomId: room,
        userId: parent.userId,
        status: "approved",
        createdAt: 1,
        decidedAt: 2,
        decidedBy: other.userId,
      });
      const change = await ctx.db.insert("roomChangeRequests", {
        roomId: room,
        userId: friend.userId,
        field: "name",
        value: "x",
        status: "approved",
        createdAt: 1,
        decidedAt: 2,
        decidedBy: other.userId,
      });
      return { approval, join, change };
    });

    await t.mutation(api.auth.deleteAccount, {
      sessionToken: other.token,
      userId: other.userId,
    });

    const after = await t.run(async (ctx) => ({
      approvals: await ctx.db
        .query("approvalRequests")
        .withIndex("by_child_status", (q) =>
          q.eq("childId", child.userId).eq("status", "approved"),
        )
        .collect(),
      join: await ctx.db.get(rows.join),
      change: await ctx.db.get(rows.change),
    }));
    // The contact and the room are still approved for the child.
    expect(after.approvals).toHaveLength(2);
    expect(after.approvals.map((a) => a.kind).sort()).toEqual([
      "contact",
      "joinRoom",
    ]);
    for (const a of after.approvals) expect(a.decidedByGuardianId).toBeUndefined();
    expect(after.join).not.toBeNull();
    expect(after.join!.decidedBy).toBeUndefined();
    expect(after.change).not.toBeNull();
    expect(after.change!.decidedBy).toBeUndefined();
  });
});

describe("item 3: handing a child's phone back signs it out", () => {
  test("releasing the device revokes its session", async () => {
    const t = convexTest(schema);
    const { parent, child, childToken } = await family(t);
    const childWho = { token: childToken, userId: child.userId };
    await expect(probe(t, childWho, "child-device")).resolves.toBeDefined();

    await t.mutation(api.family.createReleaseCode, {
      sessionToken: parent.token,
      guardianId: parent.userId,
      childId: child.userId,
      codeHash: "release-1",
    });
    await t.mutation(api.family.releaseDeviceByCode, {
      sessionToken: childToken,
      codeHash: "release-1",
      deviceId: "child-device",
    });

    await expect(probe(t, childWho, "child-device")).rejects.toThrow(
      /SESSION_REVOKED/,
    );
  });

  test("a pairing code from a guardian who has since been unlinked is dead", async () => {
    const t = convexTest(schema);
    const { parent, child } = await family(t);
    const other = await signUp(t, "other");
    await coGuardian(t, other, child.userId);

    await t.mutation(api.family.createPairingCode, {
      sessionToken: parent.token,
      guardianId: parent.userId,
      childId: child.userId,
      codeHash: "stale-code",
    });
    await t.mutation(api.family.unlinkChild, {
      sessionToken: other.token,
      guardianId: parent.userId,
      childId: child.userId,
    });

    const result = await t.mutation(api.family.redeemPairingCode as any, {
      codeHash: "stale-code",
      deviceId: "thief-device",
      platform: "ios",
    });
    expect(result.__refused).toBe("PAIRING_CODE_INVALID");
    expect(result.token).toBeUndefined();
    const sessions = await t.run((ctx) =>
      ctx.db
        .query("sessions")
        .withIndex("by_user_device", (q) =>
          q.eq("userId", child.userId).eq("deviceId", "thief-device"),
        )
        .collect(),
    );
    expect(sessions).toHaveLength(0);
  });
});

describe("item 6: guardian approve and revoke use the shared membership helpers", () => {
  const askToJoin = async (t: T, childToken: string, childId: any, room: any) =>
    t.mutation(api.family.requestApproval, {
      sessionToken: childToken,
      childId,
      kind: "joinRoom",
      targetRoomId: room,
    });

  test("approving into a full room is refused, so the cap holds", async () => {
    const t = convexTest(schema);
    const { parent, child, childToken } = await family(t);
    const host = await signUp(t, "host");
    const room = await makeRoom(t, host, "packed");
    const approvalId = await askToJoin(t, childToken, child.userId, room);
    await t.run((ctx) =>
      ctx.db.patch(room as Id<"rooms">, { memberCount: MAX_ROOM_MEMBERS }),
    );

    await expect(
      t.mutation(api.family.decideApproval, {
        sessionToken: parent.token,
        guardianId: parent.userId,
        approvalId,
        approve: true,
      }),
    ).rejects.toThrow("ROOM_FULL");
  });

  test("approve joins, revoke leaves, and the count follows", async () => {
    const t = convexTest(schema);
    const { parent, child, childToken } = await family(t);
    const host = await signUp(t, "host");
    const room = await makeRoom(t, host, "club");
    const approvalId = await askToJoin(t, childToken, child.userId, room);
    const count = async () => (await t.run((ctx) => ctx.db.get(room as Id<"rooms">)))!.memberCount;
    const before = await count();

    await t.mutation(api.family.decideApproval, {
      sessionToken: parent.token,
      guardianId: parent.userId,
      approvalId,
      approve: true,
    });
    expect(await count()).toBe(before + 1);

    await t.mutation(api.family.revokeApproval, {
      sessionToken: parent.token,
      guardianId: parent.userId,
      approvalId,
    });
    expect(await count()).toBe(before);
    const member = await t.run((ctx) =>
      ctx.db
        .query("roomMembers")
        .withIndex("by_room_user", (q) =>
          q.eq("roomId", room).eq("userId", child.userId),
        )
        .first(),
    );
    expect(member).toBeNull();
  });

  test("accepting a message request builds the DM through addMembership", async () => {
    const t = convexTest(schema);
    const a = await signUp(t, "alice");
    const b = await signUp(t, "bob");
    await t.mutation(api.friends.createDirectRequest, {
      sessionToken: a.token,
      userId: a.userId,
      friendId: b.userId,
      roomType: "Regular Room",
      initialMessage: "hi",
    });
    const roomId = await t.mutation(api.friends.approveDirectRequest, {
      sessionToken: b.token,
      userId: b.userId,
      requesterId: a.userId,
    });
    const dm = roomId as Id<"rooms">;
    const { room, members } = await t.run(async (ctx) => ({
      room: await ctx.db.get(dm),
      members: await ctx.db
        .query("roomMembers")
        .withIndex("by_room_user", (q) => q.eq("roomId", dm))
        .collect(),
    }));
    expect(room!.memberCount).toBe(2);
    expect(members.map((m) => m.role).sort()).toEqual(["member", "owner"]);
  });
});

describe("item 7 (reversed): deleting an account deletes its stickers' files", () => {
  test("files are deleted, rows stay tombstoned so references read as unavailable", async () => {
    const t = convexTest(schema);
    const me = await signUp(t, "maker");
    const { stickerId, storageId } = await t.run(async (ctx) => {
      const storageId = await ctx.storage.store(new Blob(["png"]));
      const packId = await ctx.db.insert("stickerPacks", {
        slug: `personal:${me.userId}`,
        title: "My stickers",
        kind: "personal",
        ownerId: me.userId,
        order: 0,
        createdAt: 1,
      });
      const stickerId = await ctx.db.insert("stickers", {
        packId,
        storageId,
        format: "image",
        emoji: "x",
        width: 1,
        height: 1,
        order: 0,
        createdAt: 1,
      });
      return { stickerId, storageId };
    });

    await t.mutation(api.auth.deleteAccount, {
      sessionToken: me.token,
      userId: me.userId,
    });

    const after = await t.run(async (ctx) => ({
      sticker: await ctx.db.get(stickerId),
      blob: await ctx.db.system.get(storageId),
      url: await ctx.storage.getUrl(storageId),
    }));
    expect(after.blob).toBeNull();
    expect(after.url).toBeNull();
    expect(after.sticker).not.toBeNull();
    expect(after.sticker!.deletedAt).toBeDefined();

    // Readers cope: nobody can send it, and the catalog neither lists it nor
    // throws on it.
    const other = await signUp(t, "reader");
    const room = await makeRoom(t, other, "chat");
    const sentId = await t.mutation(api.messages.send, {
      sessionToken: other.token,
      userId: other.userId,
      roomId: room,
      content: "x",
      type: "sticker",
      stickerId,
    } as any);
    // Refused as a sticker: whatever was stored carries no reference to it.
    const sent: any = await t.run((ctx) => ctx.db.get(sentId as any));
    expect(sent.stickerId).toBeUndefined();
    const catalog: any[] = await t.query(api.expressions.packs, {
      sessionToken: other.token,
    } as any);
    expect(catalog.flatMap((p) => p.stickers ?? []).map((s: any) => s._id)).not.toContain(
      stickerId,
    );
  });
});

describe("item 13: the dead auth.updateStatus is gone", () => {
  test("auth exports no updateStatus", () => {
    expect((auth as any).updateStatus).toBeUndefined();
  });
});

describe("item 15: a suspended user can still delete their account", () => {
  test("only deleteAccount is open to them", async () => {
    const t = convexTest(schema);
    const me = await signUp(t, "banned");
    const other = await signUp(t, "mod");
    await t.run((ctx) => suspendAccount(ctx, me.userId, other.userId));

    await expect(probe(t, me, "device-banned")).rejects.toThrow(
      /ACCOUNT_SUSPENDED/,
    );
    await t.mutation(api.auth.deleteAccount, {
      sessionToken: me.token,
      userId: me.userId,
    });
    expect(await t.run((ctx) => ctx.db.get(me.userId))).toBeNull();
  });

  test("a token revoked before the ban cannot delete the account", async () => {
    const t = convexTest(schema);
    const me = await signUp(t, "banned");
    const other = await signUp(t, "mod");
    const old = await t.mutation(api.auth.login as any, {
      username: "banned",
      passwordHash: "hash-banned",
      deviceId: "old-phone",
    });
    // Signed out long ago, then banned.
    await t.run(async (ctx) => {
      const row = await ctx.db
        .query("sessions")
        .withIndex("by_user_device", (q) =>
          q.eq("userId", me.userId).eq("deviceId", "old-phone"),
        )
        .first();
      await ctx.db.patch(row!._id, { revokedAt: 1 });
    });
    await t.run((ctx) => suspendAccount(ctx, me.userId, other.userId));

    await expect(
      t.mutation(api.auth.deleteAccount, {
        sessionToken: old.token,
        userId: me.userId,
      }),
    ).rejects.toThrow(/ACCOUNT_SUSPENDED/);
    expect(await t.run((ctx) => ctx.db.get(me.userId))).not.toBeNull();
  });
});

describe("item 16: signing in on a device signs out its earlier account, with proof", () => {
  test("the same device secret revokes A's session there, and only there", async () => {
    const t = convexTest(schema);
    const a = await signUp(t, "alice", "shared-phone", SECRET_A);
    const aLaptop = await t.mutation(api.auth.login as any, {
      username: "alice",
      passwordHash: "hash-alice",
      deviceId: "laptop",
      deviceSecret: SECRET_B,
    });
    await probe(t, a, "shared-phone");

    await signUp(t, "bob", "shared-phone", SECRET_A);

    await expect(probe(t, a, "shared-phone")).rejects.toThrow(/SESSION_REVOKED/);
    // Multi-device is intact: Alice's laptop is still signed in.
    await expect(
      probe(t, { token: aLaptop.token, userId: a.userId }, "laptop"),
    ).resolves.toBeDefined();
  });

  test("no userDevices row needed", async () => {
    const t = convexTest(schema);
    const a = await signUp(t, "alice", "shared-phone", SECRET_A);
    await probe(t, a, "shared-phone");
    await signUp(t, "bob", "shared-phone", SECRET_A);
    await expect(probe(t, a, "shared-phone")).rejects.toThrow(/SESSION_REVOKED/);
  });

  test("a stranger who only knows the deviceId evicts nothing", async () => {
    const t = convexTest(schema);
    const alice = await signUp(t, "alice", "alice-phone", SECRET_A);
    // Mallory read Alice's deviceId off a call roster. No secret, then a wrong one.
    await signUp(t, "mallory", "alice-phone");
    await expect(probe(t, alice, "alice-phone")).resolves.toBeDefined();
    await t.mutation(api.auth.login as any, {
      username: "mallory",
      passwordHash: "hash-mallory",
      deviceId: "alice-phone",
      deviceSecret: SECRET_B,
    });
    await expect(probe(t, alice, "alice-phone")).resolves.toBeDefined();
  });

  test("an old client with no secret on either side evicts nothing", async () => {
    const t = convexTest(schema);
    const a = await signUp(t, "alice", "shared-phone");
    await signUp(t, "bob", "shared-phone");
    await expect(probe(t, a, "shared-phone")).resolves.toBeDefined();
    // And a new client signing in over an old client's session evicts nothing.
    await signUp(t, "carol", "shared-phone", SECRET_A);
    await expect(probe(t, a, "shared-phone")).resolves.toBeDefined();
  });

  test("a malformed secret counts as none", async () => {
    const t = convexTest(schema);
    const a = await signUp(t, "alice", "shared-phone", "not-hex");
    await signUp(t, "bob", "shared-phone", "not-hex");
    await expect(probe(t, a, "shared-phone")).resolves.toBeDefined();
  });
});

describe("item 16: push rows are not stealable by claiming a deviceId", () => {
  const register = (t: T, who: any, deviceId: string) =>
    t.mutation(api.voipTokens.registerDevice, {
      sessionToken: who.token,
      userId: who.userId,
      deviceId,
      platform: "ios",
    });
  const rowsFor = (t: T, deviceId: string) =>
    t.run((ctx) =>
      (ctx.db as any)
        .query("userDevices")
        .withIndex("by_device", (q: any) => q.eq("deviceId", deviceId))
        .collect(),
    ) as Promise<any[]>;

  test("Mallory registering Alice's deviceId leaves Alice's row alone", async () => {
    const t = convexTest(schema);
    const alice = await signUp(t, "alice", "alice-phone", SECRET_A);
    await register(t, alice, "alice-phone");
    const mallory = await signUp(t, "mallory", "mallory-phone", SECRET_B);
    await register(t, mallory, "alice-phone");
    const rows = await rowsFor(t, "alice-phone");
    expect(rows.map((r) => r.userId)).toContain(alice.userId);
  });

  test("the same install signing in as someone else does take the row", async () => {
    const t = convexTest(schema);
    const alice = await signUp(t, "alice", "shared-phone", SECRET_A);
    await register(t, alice, "shared-phone");
    const bob = await signUp(t, "bob", "shared-phone", SECRET_A);
    await register(t, bob, "shared-phone");
    expect((await rowsFor(t, "shared-phone")).map((r) => r.userId)).toEqual([
      bob.userId,
    ]);
  });
});

describe("item 16: every sign-in mutation accepts the device secret", () => {
  // Validators reject unknown args, so a missing declaration surfaces as a
  // validation error. Anything else (a refusal, an unknown code) means the
  // argument was accepted.
  const notAValidationError = async (call: () => Promise<unknown>) => {
    let message = "";
    try {
      await call();
    } catch (e: any) {
      message = String(e?.message ?? e);
    }
    expect(message).not.toMatch(/extra field|ArgumentValidation|Validator error/i);
  };
  const base = { deviceId: "d", deviceSecret: SECRET_A };

  test("auth.signup, login, resetPasswordWithRecoveryKey", async () => {
    const t = convexTest(schema);
    await notAValidationError(() =>
      t.mutation(api.auth.signup, {
        username: "newbie",
        name: "newbie",
        passwordHash: "h",
        recoveryKeyHash: "r",
        ...base,
      }),
    );
    await notAValidationError(() =>
      t.mutation(api.auth.login as any, { username: "nobody", passwordHash: "h", ...base }),
    );
    await notAValidationError(() =>
      t.mutation(api.auth.resetPasswordWithRecoveryKey as any, {
        username: "nobody",
        recoveryKeyHash: "r",
        newPasswordHash: "n",
        ...base,
      }),
    );
  });

  test("family.redeemPairingCode and deviceLogin.exchangeDeviceLoginRequest", async () => {
    const t = convexTest(schema);
    await notAValidationError(() =>
      t.mutation(api.family.redeemPairingCode as any, {
        codeHash: "x",
        platform: "ios",
        ...base,
      }),
    );
    await notAValidationError(() =>
      t.mutation(api.deviceLogin.exchangeDeviceLoginRequest as any, {
        requestId: "nope",
        ...base,
      }),
    );
  });

  test("socialAuth.signIn, completeSignUp, linkExistingAccount", async () => {
    const t = convexTest(schema);
    const tok = { provider: "apple", idToken: "bad" };
    await notAValidationError(() =>
      t.action(api.socialAuth.signIn as any, { ...tok, ...base }),
    );
    await notAValidationError(() =>
      t.action(api.socialAuth.completeSignUp as any, {
        ...tok,
        username: "u",
        ...base,
      }),
    );
    await notAValidationError(() =>
      t.action(api.socialAuth.linkExistingAccount as any, {
        ...tok,
        username: "u",
        passwordHash: "h",
        ...base,
      }),
    );
  });
});

describe("item 15b: a suspended account cannot shed its ban by deleting itself", () => {
  const identityOf = (t: T, userId: any, subject: string) =>
    t.run((ctx) =>
      ctx.db.insert("socialIdentities", {
        provider: "apple",
        subject,
        userId,
        createdAt: 1,
        lastUsedAt: 1,
      }),
    );

  test("its Apple identity is refused afterwards, others are not", async () => {
    const t = convexTest(schema);
    const me = await signUp(t, "banned");
    const mod = await signUp(t, "mod");
    await identityOf(t, me.userId, "sub-banned");
    await t.run((ctx) => suspendAccount(ctx, me.userId, mod.userId));
    await t.mutation(api.auth.deleteAccount, {
      sessionToken: me.token,
      userId: me.userId,
    });

    await expect(
      t.query(internal.socialAuth.findIdentity, {
        provider: "apple",
        subject: "sub-banned",
      }),
    ).rejects.toThrow(/ACCOUNT_SUSPENDED/);
    await expect(
      t.mutation(internal.socialAuth.createWithIdentity, {
        deviceId: "d",
        provider: "apple",
        subject: "sub-banned",
        username: "comeback",
      }),
    ).rejects.toThrow(/ACCOUNT_SUSPENDED/);
    await expect(
      t.query(internal.socialAuth.findIdentity, {
        provider: "apple",
        subject: "sub-someone-else",
      }),
    ).resolves.toBeNull();
    // Only a hash is kept.
    const rows = await t.run((ctx) => ctx.db.query("bannedIdentities").collect());
    expect(rows).toHaveLength(1);
    expect(JSON.stringify(rows[0])).not.toContain("sub-banned");
  });

  test("an ordinary deletion records no ban", async () => {
    const t = convexTest(schema);
    const me = await signUp(t, "leaver");
    await identityOf(t, me.userId, "sub-leaver");
    await t.mutation(api.auth.deleteAccount, {
      sessionToken: me.token,
      userId: me.userId,
    });
    expect(await t.run((ctx) => ctx.db.query("bannedIdentities").collect())).toHaveLength(0);
    await expect(
      t.query(internal.socialAuth.findIdentity, {
        provider: "apple",
        subject: "sub-leaver",
      }),
    ).resolves.toBeNull();
  });
});

describe("item 17: accepting a request does not duplicate the friendship", () => {
  test("a crossed request reuses the reverse row", async () => {
    const t = convexTest(schema);
    const a = await signUp(t, "alice");
    const b = await signUp(t, "bob");
    // Both asked each other at once: a row each way, both pending.
    await t.run(async (ctx) => {
      await ctx.db.insert("friendships", {
        userId: a.userId,
        friendId: b.userId,
        status: "pending",
        createdAt: 1,
      });
      await ctx.db.insert("friendships", {
        userId: b.userId,
        friendId: a.userId,
        status: "pending",
        createdAt: 2,
      });
    });

    await t.mutation(api.friends.acceptRequest, {
      sessionToken: b.token,
      userId: b.userId,
      requesterId: a.userId,
    });

    const rows = await t.run((ctx) => ctx.db.query("friendships").collect());
    expect(rows).toHaveLength(2);
    expect(rows.every((r) => r.status === "accepted")).toBe(true);
  });
});

describe("item 18: friend-request messages go with their request", () => {
  const pending = async (t: T, a: any, b: any) =>
    await t.run(async (ctx) => {
      const requestId = await ctx.db.insert("friendships", {
        userId: a.userId,
        friendId: b.userId,
        status: "pending",
        createdAt: 1,
      });
      for (const [userId, content] of [
        [a.userId, "hi"],
        [b.userId, "hello"],
      ] as const) {
        await ctx.db.insert("friendRequestMessages", {
          requestId,
          userId,
          content,
          createdAt: 1,
        });
      }
      return requestId;
    });
  const leftover = (t: T, requestId: any) =>
    t.run((ctx) =>
      (ctx.db as any)
        .query("friendRequestMessages")
        .withIndex("by_request", (q: any) => q.eq("requestId", requestId))
        .collect(),
    );

  test("unfriend", async () => {
    const t = convexTest(schema);
    const a = await signUp(t, "alice");
    const b = await signUp(t, "bob");
    const id = await pending(t, a, b);
    await t.mutation(api.friends.removeFriend, {
      sessionToken: a.token,
      userId: a.userId,
      friendId: b.userId,
    });
    expect(await leftover(t, id)).toHaveLength(0);
  });

  test("reject (the older endpoint)", async () => {
    const t = convexTest(schema);
    const a = await signUp(t, "alice");
    const b = await signUp(t, "bob");
    const id = await pending(t, a, b);
    await t.mutation(api.friends.rejectRequest, {
      sessionToken: b.token,
      userId: b.userId,
      requesterId: a.userId,
    });
    expect(await leftover(t, id)).toHaveLength(0);
  });

  test("block", async () => {
    const t = convexTest(schema);
    const a = await signUp(t, "alice");
    const b = await signUp(t, "bob");
    const id = await pending(t, a, b);
    await t.mutation(api.users.blockUser, {
      sessionToken: b.token,
      userId: b.userId,
      targetUserId: a.userId,
    });
    expect(await leftover(t, id)).toHaveLength(0);
  });

  test("account deletion, including the other person's messages", async () => {
    const t = convexTest(schema);
    const a = await signUp(t, "alice");
    const b = await signUp(t, "bob");
    const id = await pending(t, a, b);
    // Bob deletes: the request Alice SENT him, with Alice's message on it.
    await t.mutation(api.auth.deleteAccount, {
      sessionToken: b.token,
      userId: b.userId,
    });
    expect(await leftover(t, id)).toHaveLength(0);
  });
});

describe("friends.acceptRequest honours the guardian relay", () => {
  test("a request still held at a guardian cannot be accepted", async () => {
    const t = convexTest(schema);
    const a = await signUp(t, "alice");
    const b = await signUp(t, "bob");
    await t.run((ctx) =>
      ctx.db.insert("friendships", {
        userId: a.userId,
        friendId: b.userId,
        status: "pending",
        stage: STAGE_RECIPIENT_GUARDIAN,
        createdAt: 1,
      }),
    );
    await expect(
      t.mutation(api.friends.acceptRequest, {
        sessionToken: b.token,
        userId: b.userId,
        requesterId: a.userId,
      }),
    ).rejects.toThrow("REQUEST_NOT_FOUND");
  });

  test("a guardian-denied reverse row is not overridden", async () => {
    const t = convexTest(schema);
    const a = await signUp(t, "alice");
    const b = await signUp(t, "bob");
    const reverse = await t.run(async (ctx) => {
      await ctx.db.insert("friendships", {
        userId: a.userId,
        friendId: b.userId,
        status: "pending",
        createdAt: 1,
      });
      return await ctx.db.insert("friendships", {
        userId: b.userId,
        friendId: a.userId,
        status: "denied",
        createdAt: 2,
      });
    });
    await expect(
      t.mutation(api.friends.acceptRequest, {
        sessionToken: b.token,
        userId: b.userId,
        requesterId: a.userId,
      }),
    ).rejects.toThrow("REQUEST_NOT_FOUND");
    expect(((await t.run((ctx) => ctx.db.get(reverse))) as any).status).toBe("denied");
  });

  test("an accepted request leaves no messages behind", async () => {
    const t = convexTest(schema);
    const a = await signUp(t, "alice");
    const b = await signUp(t, "bob");
    const id = await t.run(async (ctx) => {
      const id = await ctx.db.insert("friendships", {
        userId: a.userId,
        friendId: b.userId,
        status: "pending",
        createdAt: 1,
      });
      await ctx.db.insert("friendRequestMessages", {
        requestId: id,
        userId: a.userId,
        content: "hi",
        createdAt: 1,
      });
      return id;
    });
    await t.mutation(api.friends.acceptRequest, {
      sessionToken: b.token,
      userId: b.userId,
      requesterId: a.userId,
    });
    const left = await t.run((ctx) =>
      (ctx.db as any)
        .query("friendRequestMessages")
        .withIndex("by_request", (q: any) => q.eq("requestId", id))
        .collect(),
    );
    expect(left).toHaveLength(0);
  });
});

describe("family.revokeApproval only undoes an approved approval", () => {
  test("a pending joinRoom request does not remove the child from the room", async () => {
    const t = convexTest(schema);
    const { parent, child, childToken } = await family(t);
    const host = await signUp(t, "host");
    const room = await makeRoom(t, host, "club");
    const roomId = room as Id<"rooms">;
    // The child is already in the room some other way, then asks again.
    await t.run((ctx) => addMembership(ctx, roomId, child.userId));
    const approvalId = await t.mutation(api.family.requestApproval, {
      sessionToken: childToken,
      childId: child.userId,
      kind: "joinRoom",
      targetRoomId: roomId,
    });

    await t.mutation(api.family.revokeApproval, {
      sessionToken: parent.token,
      guardianId: parent.userId,
      approvalId,
    });

    const after = await t.run(async (ctx) => ({
      member: await ctx.db
        .query("roomMembers")
        .withIndex("by_room_user", (q) =>
          q.eq("roomId", roomId).eq("userId", child.userId),
        )
        .first(),
      approval: await ctx.db.get(approvalId),
    }));
    expect(after.member).not.toBeNull();
    expect((after.approval as any).status).toBe("pending");
  });
});

describe("deleting an account leaves the room's live group call", () => {
  test("the only joined participant going ends the call", async () => {
    const t = convexTest(schema);
    const starter = await signUp(t, "starter");
    const alice = await signUp(t, "alice");
    const roomId = await makeRoom(t, starter, "crew");
    await t.mutation(api.rooms.join, {
      sessionToken: alice.token,
      userId: alice.userId,
      roomId,
    } as any);
    const res: any = await t.mutation(api.groupCalls.start, {
      sessionToken: starter.token,
      userId: starter.userId,
      roomId,
      type: "audio",
      deviceId: "device-starter",
    } as any);

    await t.mutation(api.auth.deleteAccount, {
      sessionToken: starter.token,
      userId: starter.userId,
    });

    const call = await t.run((ctx) => ctx.db.get(res.groupCallId as any));
    expect((call as any).status).toBe("ended");
  });
});
