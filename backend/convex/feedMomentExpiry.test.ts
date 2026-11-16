import { convexTest } from "convex-test";
import { expect, test } from "vitest";
import { api } from "./_generated/api";
import schema from "./schema";

/**
 * `feed.moment` is what a tapped notification opens. A friend's highlight that
 * has expired must not come back through it unless the author shares history.
 */

async function signUp(t: ReturnType<typeof convexTest>, username: string) {
  const u = await t.mutation(api.auth.signup, {
    username,
    name: username,
    passwordHash: `hash-${username}`,
    recoveryKeyHash: `recovery-${username}`,
    deviceId: `device-${username}`,
  });
  return { ...u, username };
}

const as = (who: any) => ({ sessionToken: who.token, userId: who.userId as any });

test("an expired highlight opens for its author, and for a friend only with shared history", async () => {
  const t = convexTest(schema);
  const author = await signUp(t, "author");
  const friend = await signUp(t, "friend");
  await t.mutation(api.friends.sendRequest, { ...as(author), friendUsername: "friend" });
  await t.mutation(api.friends.acceptRequest, {
    ...as(friend),
    requesterId: author.userId as any,
  });
  const momentId = await t.mutation(api.feed.post, {
    ...as(author),
    dayKey: "2026-10-08",
    caption: "sunset",
  } as any);
  const open = (who: any) => t.query(api.feed.moment, { ...as(who), momentId });

  expect(await open(friend)).not.toBeNull();

  await t.run(async (ctx: any) => {
    await ctx.db.patch(momentId, { expiresAt: Date.now() - 1000 });
  });
  expect(await open(friend)).toBeNull();
  expect(await open(author)).not.toBeNull();

  await t.run(async (ctx: any) => {
    await ctx.db.patch(author.userId, { visibility: { pointsPast: "friends" } });
  });
  expect(await open(friend)).not.toBeNull();
});
