import { convexTest } from "convex-test";
import { describe, expect, test } from "vitest";
import { api } from "./_generated/api";
import { MAX_CONTENT_CHARS, MAX_SENDS_PER_10S } from "./messages";
import schema from "./schema";

/**
 * Writes that reach other people are limited by the server: how often, and
 * how large. Before, a script could send without limit, at up to a megabyte
 * a message, and ring a phone on a loop.
 */

const signUp = (t: ReturnType<typeof convexTest>, username: string) =>
  t.mutation(api.auth.signup, {
    username,
    name: username,
    passwordHash: `hash-${username}`,
    recoveryKeyHash: `recovery-${username}`,
    deviceId: `device-${username}`,
  });

async function room(t: ReturnType<typeof convexTest>) {
  const me = await signUp(t, "me");
  const roomId = await t.mutation(api.rooms.create, {
    sessionToken: me.token,
    userId: me.userId as any,
    name: "spam",
    isPrivate: false,
  });
  return { me, roomId };
}

describe("sending", () => {
  test("is rate limited per account", async () => {
    const t = convexTest(schema);
    const { me, roomId } = await room(t);
    const send = (i: number) =>
      t.mutation(api.messages.send, {
        sessionToken: me.token,
        userId: me.userId as any,
        roomId,
        content: `m${i}`,
      });
    for (let i = 0; i < MAX_SENDS_PER_10S; i++) await send(i);
    await expect(send(999)).rejects.toThrow("RATE_LIMITED");
  });

  test("refuses a message over the length cap", async () => {
    const t = convexTest(schema);
    const { me, roomId } = await room(t);
    await expect(
      t.mutation(api.messages.send, {
        sessionToken: me.token,
        userId: me.userId as any,
        roomId,
        content: "x".repeat(MAX_CONTENT_CHARS + 1),
      }),
    ).rejects.toThrow("MESSAGE_TOO_LONG");
  });
});

describe("friend requests", () => {
  test("the same person can't be asked over and over", async () => {
    const t = convexTest(schema);
    const me = await signUp(t, "me");
    const them = await signUp(t, "them");
    const ask = () =>
      t.mutation(api.friends.sendRequest, {
        sessionToken: me.token,
        userId: me.userId as any,
        friendUsername: "them",
      });
    const reject = () =>
      t.mutation(api.friends.rejectRequest, {
        sessionToken: them.token,
        userId: them.userId as any,
        requesterId: me.userId as any,
      } as any);
    for (let i = 0; i < 3; i++) {
      await ask();
      await reject();
    }
    await expect(ask()).rejects.toThrow("RATE_LIMITED");
  });
});
