import { convexTest } from "convex-test";
import { describe, expect, test } from "vitest";
import { api } from "./_generated/api";
import { MAX_ROOM_MEMBERS } from "./roomAdmin";
import schema from "./schema";

/**
 * Rooms have a ceiling, and an admin's removal sticks.
 */

const signUp = (t: ReturnType<typeof convexTest>, username: string) =>
  t.mutation(api.auth.signup, {
    username,
    name: username,
    passwordHash: `hash-${username}`,
    recoveryKeyHash: `recovery-${username}`,
    deviceId: `device-${username}`,
  });

async function publicRoom(t: ReturnType<typeof convexTest>) {
  const owner = await signUp(t, "owner");
  const guest = await signUp(t, "guest");
  const roomId = await t.mutation(api.rooms.create, {
    sessionToken: owner.token,
    userId: owner.userId as any,
    name: "open",
    isPrivate: false,
  });
  const join = () =>
    t.mutation(api.rooms.join, {
      sessionToken: guest.token,
      userId: guest.userId as any,
      roomId,
    });
  return { owner, guest, roomId, join };
}

describe("rooms", () => {
  test("a removed member can't walk back in through Discover", async () => {
    const t = convexTest(schema);
    const { owner, guest, roomId, join } = await publicRoom(t);
    await join();
    await t.mutation(api.roomAdmin.removeMember, {
      sessionToken: owner.token,
      userId: owner.userId as any,
      roomId,
      targetUserId: guest.userId as any,
    } as any);
    await expect(join()).rejects.toThrow("REMOVED_FROM_ROOM");
  });

  test("a full room refuses the next member", async () => {
    const t = convexTest(schema);
    const { roomId, join } = await publicRoom(t);
    await t.run((ctx) => ctx.db.patch(roomId, { memberCount: MAX_ROOM_MEMBERS }));
    await expect(join()).rejects.toThrow("ROOM_FULL");
  });
});
