import { convexTest } from "convex-test";
import { expect, test } from "vitest";
import { api } from "./_generated/api";
import schema from "./schema";

/**
 * `matches.setPick`: lobby choices shown live to the other seat. Seated
 * players only, lobby only, the stage is the host's, and an unchanged choice
 * writes nothing.
 */

type Who = { userId: any; token: string; username: string };

async function signUp(t: ReturnType<typeof convexTest>, username: string): Promise<Who> {
  const u = await t.mutation(api.auth.signup, {
    username,
    name: username,
    passwordHash: `hash-${username}`,
    recoveryKeyHash: `recovery-${username}`,
    deviceId: `device-${username}`,
  });
  return { ...u, username } as any;
}

const as = (who: Who) => ({ sessionToken: who.token, userId: who.userId });

async function lobby(t: ReturnType<typeof convexTest>) {
  const a = await signUp(t, "ada");
  const b = await signUp(t, "bob");
  const c = await signUp(t, "cem");
  const roomId = await t.mutation(api.rooms.create, {
    ...as(a),
    name: "games night",
    isPrivate: false,
  });
  for (const o of [b, c]) {
    await t.mutation(api.rooms.join, { ...as(o), roomId });
  }
  const { matchId } = (await t.mutation(api.matches.create, {
    ...as(a),
    roomId,
    game: "tictactoe",
    mode: "live",
  } as any)) as any;
  await t.mutation(api.matches.join, { ...as(b), matchId });
  const seats = async () =>
    ((await t.query(api.matches.get, {
      sessionToken: a.token,
      matchId,
      viewerUserId: a.userId,
    })) as any).seats;
  return { a, b, c, matchId, seats };
}

test("each seat's choice is visible to the other, and the stage is the host's", async () => {
  const t = convexTest(schema);
  const { a, b, matchId, seats } = await lobby(t);

  await t.mutation(api.matches.setPick, { ...as(a), matchId, pick: 3, stage: 2 });
  await t.mutation(api.matches.setPick, { ...as(b), matchId, pick: 7, stage: 5 });
  let s = await seats();
  expect(s[0]).toMatchObject({ pick: 3, stage: 2 });
  expect(s[1].pick).toBe(7);
  expect(s[1].stage).toBeUndefined();

  // A later fighter change keeps the stage, and readiness keeps both.
  await t.mutation(api.matches.setPick, { ...as(a), matchId, pick: 4 });
  await t.mutation(api.matches.setReady, { ...as(a), matchId, ready: true });
  s = await seats();
  expect(s[0]).toMatchObject({ pick: 4, stage: 2, ready: true });
});

test("only a seated player in a lobby may choose, and junk is refused", async () => {
  const t = convexTest(schema);
  const { a, b, c, matchId, seats } = await lobby(t);

  await expect(
    t.mutation(api.matches.setPick, { ...as(c), matchId, pick: 1 }),
  ).rejects.toThrow("NOT_SEATED");
  await expect(
    t.mutation(api.matches.setPick, { ...as(a), matchId, pick: 1.5 }),
  ).rejects.toThrow("BAD_PICK");
  await expect(
    t.mutation(api.matches.setPick, { ...as(a), matchId, pick: 9000 }),
  ).rejects.toThrow("BAD_PICK");

  await t.mutation(api.matches.setReady, { ...as(a), matchId, ready: true });
  await t.mutation(api.matches.setReady, { ...as(b), matchId, ready: true });
  await expect(
    t.mutation(api.matches.setPick, { ...as(a), matchId, pick: 1 }),
  ).rejects.toThrow("NOT_IN_LOBBY");
  // Starting drops the previews: the game's own exchange is the authority.
  expect((await seats())[0].pick).toBeUndefined();
});
