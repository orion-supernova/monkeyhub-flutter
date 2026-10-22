import { convexTest } from "convex-test";
import { afterEach, beforeEach, describe, expect, test, vi } from "vitest";
import { api } from "./_generated/api";
import { startRoomDeletion, startUserDeletion } from "./deletionCore";
import { assertRoomAllows } from "./roomPolicy";
import schema from "./schema";

/**
 * The read side of a delete (docs/data-integrity-phase2-design.md, section 2):
 * what every reader and gate answers DURING the window, after the first
 * transaction has run and before any step has drained. Fake timers are on and
 * never advanced, so the scheduled `deletions.step` never runs; every assertion
 * here is about the tombstone alone.
 */

type T = ReturnType<typeof convexTest>;

beforeEach(() => {
  vi.useFakeTimers();
  vi.spyOn(console, "warn").mockImplementation(() => {});
  vi.spyOn(console, "error").mockImplementation(() => {});
});
afterEach(() => {
  vi.restoreAllMocks();
  vi.useRealTimers();
});

async function signUp(t: T, username: string) {
  return await t.mutation(api.auth.signup, {
    username,
    name: username,
    passwordHash: `hash-${username}`,
    recoveryKeyHash: `recovery-${username}`,
    deviceId: `device-${username}`,
  });
}
type Who = Awaited<ReturnType<typeof signUp>>;

const as = (who: Who) => ({
  sessionToken: who.token,
  userId: who.userId as any,
});

async function befriend(t: T, a: Who, b: Who, bName: string) {
  await t.mutation(api.friends.sendRequest, {
    ...as(a),
    friendUsername: bName,
  } as any);
  await t.mutation(api.friends.acceptRequest, {
    ...as(b),
    requesterId: a.userId as any,
  } as any);
}

const dm = (t: T, a: Who, b: Who) =>
  t.mutation(api.rooms.getOrCreateDM, {
    ...as(a),
    friendId: b.userId as any,
  } as any) as Promise<any>;

describe("a user being deleted", () => {
  test("is a ghost at once: old token, login, search, friends, requests and calls", async () => {
    const t = convexTest(schema);
    const alice = await signUp(t, "alice");
    const bob = await signUp(t, "bob");
    const carol = await signUp(t, "carol");
    await befriend(t, alice, bob, "bob");
    const roomId = await dm(t, alice, bob);
    expect(
      await t.query(api.friends.listFriends, as(alice) as any),
    ).toHaveLength(1);

    await t.run((ctx) => startUserDeletion(ctx, bob.userId as any));

    // The old token is signed out, not "unknown" and not suspended.
    await expect(
      t.query(api.friends.listFriends, as(bob) as any),
    ).rejects.toThrow(/SESSION_REVOKED/);

    // Signing in as the ghost: the handle is scrubbed, and minting a session
    // for the row (any sign-in path ends there) is refused outright.
    await expect(
      t.mutation(api.auth.login, {
        username: "bob",
        passwordHash: "hash-bob",
        deviceId: "device-new",
      }),
    ).rejects.toThrow(/USER_NOT_FOUND/);
    const { mintSession } = await import("./sessionCore");
    await expect(
      t.run((ctx) => mintSession(ctx, bob.userId as any, "device-new")),
    ).rejects.toThrow(/SESSION_REVOKED/);

    // Search finds neither the old handle nor the scrubbed one.
    for (const q of ["bob", "deleted"]) {
      const found: any[] = await t.query(api.friends.searchUsers, {
        sessionToken: carol.token,
        currentUserId: carol.userId as any,
        query: q,
      } as any);
      expect(found.map((u) => u._id)).not.toContain(bob.userId);
    }

    // The friend's list drops the ghost although the friendship row is still there.
    expect(
      await t.query(api.friends.listFriends, as(alice) as any),
    ).toHaveLength(0);

    // Nobody can ask, accept, DM or ring a ghost.
    await expect(
      t.mutation(api.friends.sendRequest, {
        ...as(carol),
        friendUsername: "bob",
      } as any),
    ).rejects.toThrow(/USER_NOT_FOUND/);
    await expect(dm(t, alice, bob)).rejects.toThrow(/USER_NOT_FOUND/);
    await expect(
      t.mutation(api.calls.initiate, {
        sessionToken: alice.token,
        callerId: alice.userId as any,
        calleeId: bob.userId as any,
        roomId,
        type: "audio",
      } as any),
    ).rejects.toThrow(/USER_NOT_FOUND/);
  });

  test("a suspended user's second delete request is SESSION_REVOKED, not ACCOUNT_SUSPENDED", async () => {
    const t = convexTest(schema);
    const dave = await signUp(t, "dave");
    // Ban (revokes the session), then the allowSuspended delete path, as
    // `auth.deleteAccount` runs it.
    await t.run(async (ctx) => {
      const now = Date.now();
      await ctx.db.patch(dave.userId as any, { suspendedAt: now });
      const rows = await ctx.db.query("sessions").collect();
      for (const r of rows) await ctx.db.patch(r._id, { revokedAt: now });
    });
    const { requireSession } = await import("./sessionCore");
    await expect(
      t.run((ctx) => requireSession(ctx, dave.token, { allowSuspended: true })),
    ).resolves.toBe(dave.userId);
    await t.run((ctx) => startUserDeletion(ctx, dave.userId as any));
    await expect(
      t.run((ctx) => requireSession(ctx, dave.token, { allowSuspended: true })),
    ).rejects.toThrow(/SESSION_REVOKED/);
  });
});

describe("a room being deleted", () => {
  test("leaves lists, refuses sends and joins, and frees the DM name", async () => {
    const t = convexTest(schema);
    const alice = await signUp(t, "alice");
    const bob = await signUp(t, "bob");
    const carol = await signUp(t, "carol");

    const roomId = await t.mutation(api.rooms.create, {
      ...as(alice),
      name: "crew",
      isPrivate: false,
    } as any);
    await t.mutation(api.rooms.join, { ...as(bob), roomId } as any);
    expect(
      (await t.query(api.rooms.listUserRooms, as(alice) as any)).map(
        (r: any) => r._id,
      ),
    ).toContain(roomId);

    await befriend(t, alice, bob, "bob");
    const firstDm = await dm(t, alice, bob);
    const dmName = ((await t.run((ctx) => ctx.db.get(firstDm))) as any).name;

    await t.run((ctx) => startRoomDeletion(ctx, roomId));
    await t.run((ctx) => startRoomDeletion(ctx, firstDm));

    // Gone from the member's list, before any membership row is touched.
    const listed = (await t.query(api.rooms.listUserRooms, as(alice) as any)).map(
      (r: any) => r._id,
    );
    expect(listed).not.toContain(roomId);
    expect(listed).not.toContain(firstDm);
    expect(
      await t.query(api.rooms.getRoom, {
        sessionToken: alice.token,
        roomId,
      } as any),
    ).toBeNull();

    // A send is refused, both through the real mutation and the shared gate.
    await expect(
      t.mutation(api.messages.send, {
        ...as(alice),
        roomId,
        content: "hi",
      } as any),
    ).rejects.toThrow(/ROOM_NOT_FOUND/);
    const room = await t.run((ctx) => ctx.db.get(roomId));
    await expect(
      assertRoomAllows(null, room as any, alice.userId, { kinds: ["text"] }),
    ).rejects.toThrow(/ROOM_NOT_FOUND/);

    // Nobody joins, edits, or deletes it a second time.
    await expect(
      t.mutation(api.rooms.join, { ...as(carol), roomId } as any),
    ).rejects.toThrow(/ROOM_NOT_FOUND/);
    await expect(
      t.mutation(api.rooms.updateRoom, {
        ...as(alice),
        roomId,
        name: "renamed",
      } as any),
    ).rejects.toThrow(/ROOM_NOT_FOUND/);
    await expect(
      t.mutation(api.rooms.deleteRoom, { ...as(alice), roomId } as any),
    ).resolves.toBeNull();

    // The same pair can start over, under the original key, in a new room.
    const secondDm = await dm(t, alice, bob);
    expect(secondDm).not.toBe(firstDm);
    const fresh: any = await t.run((ctx) => ctx.db.get(secondDm));
    expect(fresh.name).toBe(dmName);
    expect((fresh as any).deletingAt).toBeUndefined();
  });
});
