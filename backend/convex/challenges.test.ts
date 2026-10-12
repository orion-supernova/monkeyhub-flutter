import { convexTest } from "convex-test";
import { describe, expect, test } from "vitest";
import { api } from "./_generated/api";
import schema from "./schema";

/**
 * "Beat my time": a challenge is only as honest as the result it came from,
 * only members read it, and deleting the card takes its body.
 */

type Who = { token: string; userId: any };
const DAY = "2026-10-12";

async function signUp(t: ReturnType<typeof convexTest>, username: string) {
  return (await t.mutation(api.auth.signup, {
    username,
    name: username,
    passwordHash: `hash-${username}`,
    recoveryKeyHash: `recovery-${username}`,
    deviceId: "d",
  })) as Who;
}

async function room(t: ReturnType<typeof convexTest>, owner: Who, ...others: Who[]) {
  const roomId = await t.mutation(api.rooms.create, {
    sessionToken: owner.token,
    userId: owner.userId,
    name: "friends",
    isPrivate: false,
  });
  for (const o of others) {
    await t.mutation(api.rooms.join, {
      sessionToken: o.token,
      userId: o.userId,
      roomId,
    });
  }
  return roomId;
}

async function solved(t: ReturnType<typeof convexTest>, who: Who, durationMs: number) {
  await t.run(async (ctx) => {
    await ctx.db.insert("gameResults", {
      userId: who.userId,
      dayKey: DAY,
      game: "queens",
      startedAt: 1,
      finishedAt: 2,
      solved: true,
      gaveUp: false,
      durationMs,
      hintsUsed: 0,
      mistakes: 0,
    } as any);
  });
}

describe("a challenge", () => {
  test("needs a solved board, and carries the server's time", async () => {
    const t = convexTest(schema);
    const a = await signUp(t, "ada");
    const b = await signUp(t, "bob");
    const roomId = await room(t, a, b);
    const send = () =>
      t.mutation(api.challenges.send, {
        sessionToken: a.token,
        userId: a.userId,
        roomIds: [roomId],
        game: "queens",
        dayKey: DAY,
      });
    await expect(send()).rejects.toThrow("NOT_SOLVED");
    await solved(t, a, 161_000);
    const [messageId] = (await send()) as any[];
    const rows = (await t.query(api.challenges.forMessages, {
      sessionToken: b.token,
      messageIds: [messageId],
      viewerUserId: b.userId,
    })) as any[];
    expect(rows).toHaveLength(1);
    expect(rows[0]).toMatchObject({ game: "queens", durationMs: 161_000, name: "ada" });
    const msg: any = await t.run((ctx) => ctx.db.get(messageId));
    expect(msg.type).toBe("challenge");
    expect(msg.content).toBe("Beat my time: Queens 2:41");
  });

  test("is invisible to outsiders and goes with its card", async () => {
    const t = convexTest(schema);
    const a = await signUp(t, "ada");
    const z = await signUp(t, "zed");
    const roomId = await room(t, a);
    await solved(t, a, 90_000);
    const [messageId] = (await t.mutation(api.challenges.send, {
      sessionToken: a.token,
      userId: a.userId,
      roomIds: [roomId],
      game: "queens",
      dayKey: DAY,
    })) as any[];
    expect(
      await t.query(api.challenges.forMessages, {
        sessionToken: z.token,
        messageIds: [messageId],
        viewerUserId: z.userId,
      }),
    ).toEqual([]);
    await t.mutation(api.messages.deleteMessage, {
      sessionToken: a.token,
      userId: a.userId,
      messageId,
    });
    await t.run(async (ctx) => {
      expect(await ctx.db.query("gameChallenges").collect()).toHaveLength(0);
    });
  });
});
