import { convexTest } from "convex-test";
import { describe, expect, test } from "vitest";
import { api } from "./_generated/api";
import schema from "./schema";

/**
 * `dm:` names are the system's own keys (Saved Messages is found by the name
 * `dm:self:<userId>`), so a user-chosen room can never take one: created
 * under `dm:self:<someoneElse>`, it would be found as that person's Saved
 * Messages the first time they opened it.
 */

const signUp = (t: ReturnType<typeof convexTest>, username: string) =>
  t.mutation(api.auth.signup, {
    username,
    name: username,
    passwordHash: `hash-${username}`,
    recoveryKeyHash: `recovery-${username}`,
    deviceId: `device-${username}`,
  });

describe("reserved room names", () => {
  test("a room cannot be created under someone's Saved Messages name", async () => {
    const t = convexTest(schema);
    const mallory = await signUp(t, "mallory");
    const victim = await signUp(t, "victim");
    for (const name of [`dm:self:${victim.userId}`, "dm:regular:a:b", "  DM:anything"]) {
      await expect(
        t.mutation(api.rooms.create, {
          sessionToken: mallory.token,
          userId: mallory.userId as any,
          name,
          isPrivate: true,
        }),
      ).rejects.toThrow("ROOM_NAME_RESERVED");
    }
  });

  test("an ordinary name is still fine, and cannot be renamed into dm:", async () => {
    const t = convexTest(schema);
    const owner = await signUp(t, "owner");
    const roomId = await t.mutation(api.rooms.create, {
      sessionToken: owner.token,
      userId: owner.userId as any,
      name: "dmv fans",
      isPrivate: true,
    });
    await expect(
      t.mutation(api.rooms.updateRoom, {
        sessionToken: owner.token,
        roomId,
        userId: owner.userId as any,
        name: `dm:self:${owner.userId}`,
      } as any),
    ).rejects.toThrow("ROOM_NAME_RESERVED");
  });
});
