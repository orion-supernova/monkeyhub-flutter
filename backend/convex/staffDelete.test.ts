import { convexTest } from "convex-test";
import { afterEach, beforeEach, describe, expect, test, vi } from "vitest";
import { api, internal } from "./_generated/api";
import schema from "./schema";
import { drainDeletions } from "./deletionTestUtils";
import { SUPPORT_USERNAME } from "./systemAccount";

beforeEach(() => {
  vi.useFakeTimers();
});
afterEach(() => {
  vi.useRealTimers();
});

const drain = (t: ReturnType<typeof convexTest>) => drainDeletions(t, vi.runAllTimers);

async function signUp(t: ReturnType<typeof convexTest>, username: string) {
  return await t.mutation(api.auth.signup, {
    username,
    name: username,
    passwordHash: `hash-${username}`,
    recoveryKeyHash: `recovery-${username}`,
    deviceId: `device-${username}`,
  } as any);
}

describe("moderation.staffDeleteAccount", () => {
  test("tears the account down through the engine", async () => {
    const t = convexTest(schema);
    const alice = await signUp(t, "alice");
    const bob = await signUp(t, "bob");
    const roomId = await t.mutation(api.rooms.create, {
      sessionToken: alice.token,
      userId: alice.userId,
      name: "room",
      isPrivate: false,
    } as any);
    await t.mutation(api.rooms.join, {
      sessionToken: bob.token,
      userId: bob.userId,
      roomId,
    } as any);
    await t.mutation(api.messages.send, {
      sessionToken: bob.token,
      userId: bob.userId,
      roomId,
      content: "hi",
    } as any);

    const job = await t.mutation(internal.moderation.staffDeleteAccount, { username: "bob" });
    expect(job).not.toBeNull();
    await drain(t);

    const left = await t.run(async (ctx: any) => ({
      user: await ctx.db.get(bob.userId),
      byHandle: await ctx.db
        .query("users")
        .withIndex("by_username", (q: any) => q.eq("username", "bob"))
        .first(),
      memberships: await ctx.db
        .query("roomMembers")
        .withIndex("by_user", (q: any) => q.eq("userId", bob.userId))
        .collect(),
      job: await ctx.db.get(job),
    }));
    expect(left.byHandle).toBeNull();
    expect(left.user).toBeNull();
    expect(left.memberships).toHaveLength(0);
    expect(left.job?.state ?? "done").not.toBe("failed");
    // The other member is untouched.
    expect(await t.run((ctx: any) => ctx.db.get(alice.userId))).not.toBeNull();
  });

  test("refuses unknown and system accounts", async () => {
    const t = convexTest(schema);
    const alice = await signUp(t, "alice");
    await expect(
      t.mutation(internal.moderation.staffDeleteAccount, { username: "nobody" }),
    ).rejects.toThrow("USER_NOT_FOUND");
    const roomId = await t.mutation(api.rooms.create, {
      sessionToken: alice.token,
      userId: alice.userId,
      name: "room",
      isPrivate: false,
    } as any);
    await t.mutation(internal.moderation.postNotice, { roomId, text: "hello" });
    await expect(
      t.mutation(internal.moderation.staffDeleteAccount, { username: SUPPORT_USERNAME }),
    ).rejects.toThrow("SYSTEM_ACCOUNT");
  });
});
