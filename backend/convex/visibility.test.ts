import { convexTest } from "convex-test";
import { describe, expect, test } from "vitest";
import { api } from "./_generated/api";
import { lensFor, levelOf } from "./visibility";
import schema from "./schema";

/**
 * The defaults for a user who never opened the visibility screen — which is
 * most of them, so these ARE the product's privacy behaviour.
 *
 * "friends" for every identity field (2026-10-07). Before that a stranger saw
 * avatar/status/lastSeen ("public") and a friend never saw a read receipt
 * ("nobody"), the opposite of what a chat between people who know each other
 * wants.
 */

async function signUp(t: ReturnType<typeof convexTest>, username: string) {
  return await t.mutation(api.auth.signup, {
    username,
    name: username,
    passwordHash: `hash-${username}`,
    recoveryKeyHash: `recovery-${username}`,
    deviceId: `device-${username}`,
  });
}

async function befriend(
  t: ReturnType<typeof convexTest>,
  a: { userId: any; token: string },
  b: { userId: any; token: string },
  bUsername: string,
) {
  await t.mutation(api.friends.sendRequest, {
    sessionToken: a.token,
    userId: a.userId,
    friendUsername: bUsername,
  });
  await t.mutation(api.friends.acceptRequest, {
    sessionToken: b.token,
    userId: b.userId,
    requesterId: a.userId,
  });
}

const FIELDS = ["avatar", "status", "lastSeen", "seen"] as const;

describe("visibility defaults", () => {
  test("an unset field reads as friends", () => {
    for (const f of FIELDS) {
      expect(levelOf({}, f)).toBe("friends");
      expect(levelOf({ visibility: {} }, f)).toBe("friends");
    }
  });

  test("a stored value always wins", () => {
    expect(levelOf({ visibility: { seen: "nobody" } }, "seen")).toBe("nobody");
    expect(levelOf({ visibility: { avatar: "public" } }, "avatar")).toBe(
      "public",
    );
  });

  test("a friend sees every unset field, a stranger none", async () => {
    const t = convexTest(schema);
    const subject = await signUp(t, "subject");
    const friend = await signUp(t, "friend");
    const stranger = await signUp(t, "stranger");
    await befriend(t, subject, friend, "friend");

    await t.run(async (ctx: any) => {
      const row = await ctx.db.get(subject.userId);
      expect(row.visibility?.seen).toBeUndefined();
      const asFriend = await lensFor(ctx, friend.userId);
      const asStranger = await lensFor(ctx, stranger.userId);
      const anonymous = await lensFor(ctx, undefined);
      for (const f of FIELDS) {
        expect(asFriend.canSee(row, f)).toBe(true);
        expect(asStranger.canSee(row, f)).toBe(false);
        expect(anonymous.canSee(row, f)).toBe(false);
      }
    });
  });
});
