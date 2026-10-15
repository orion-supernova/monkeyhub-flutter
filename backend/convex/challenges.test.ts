import { convexTest } from "convex-test";
import { describe, expect, test } from "vitest";
import { api, internal } from "./_generated/api";
import { CHALLENGE_PUSH_TABLE, challengePushBody } from "./challengeCopy";
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

async function solved(
  t: ReturnType<typeof convexTest>,
  who: Who,
  durationMs: number,
  opts: { gaveUp?: boolean; finished?: boolean } = {},
) {
  await t.run(async (ctx) => {
    await ctx.db.insert("gameResults", {
      userId: who.userId,
      dayKey: DAY,
      game: "queens",
      startedAt: 1,
      finishedAt: opts.finished === false ? undefined : 2,
      solved: !opts.gaveUp && opts.finished !== false,
      gaveUp: !!opts.gaveUp,
      durationMs: opts.gaveUp || opts.finished === false ? undefined : durationMs,
      hintsUsed: 0,
      mistakes: 0,
    } as any);
  });
}

/** An accepted friendship: two directed rows, as `friends.ts` writes it. */
async function befriend(t: ReturnType<typeof convexTest>, x: Who, ...ys: Who[]) {
  await t.run(async (ctx) => {
    for (const y of ys) {
      for (const [u, f] of [[x, y], [y, x]]) {
        await ctx.db.insert("friendships", {
          userId: u.userId,
          friendId: f.userId,
          status: "accepted",
          createdAt: 1,
        } as any);
      }
    }
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
    // A question: "Beat my time: Queens 2:41" was announced as a claim.
    expect(msg.content).toBe("Can you beat my 2:41 on Queens?");
    expect(rows[0]).toMatchObject({ roomId, isGroup: true, roomName: "friends" });
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

describe("who played", () => {
  const results = (t: ReturnType<typeof convexTest>, who: Who, roomId: any) =>
    t.query(api.challenges.roomResults, {
      sessionToken: who.token,
      roomId,
      game: "queens",
      dayKey: DAY,
      viewerUserId: who.userId,
    }) as Promise<any>;

  test("is for members only", async () => {
    const t = convexTest(schema);
    const a = await signUp(t, "ada");
    const z = await signUp(t, "zed");
    const roomId = await room(t, a);
    await solved(t, a, 90_000);
    expect(await results(t, z, roomId)).toBeNull();
    const mine = await results(t, a, roomId);
    expect(mine).toMatchObject({ played: 1, isGroup: true });
  });

  test("ranks like the standings and hides who asked to be hidden", async () => {
    const t = convexTest(schema);
    const a = await signUp(t, "ada");
    const b = await signUp(t, "bob");
    const c = await signUp(t, "cat");
    const d = await signUp(t, "dan");
    const e = await signUp(t, "eve");
    const f = await signUp(t, "fay");
    const roomId = await room(t, a, b, c, d, e, f);
    await befriend(t, a, b, c, d, e, f);
    await befriend(t, f, b, c, d);
    await solved(t, a, 41_900); // 0:41
    await solved(t, b, 41_100); // 0:41, a tie on what is shown
    await solved(t, c, 30_000, { gaveUp: true });
    await solved(t, d, 20_000);
    await solved(t, e, 5_000, { finished: false }); // still playing: absent
    await solved(t, f, 10_000);
    // Fay keeps her dailies to herself.
    await t.run(async (ctx) => {
      await ctx.db.patch(f.userId, { visibility: { puzzle: "nobody" } } as any);
    });

    const r = await results(t, a, roomId);
    expect(r.played).toBe(4);
    expect(r.rows.map((x: any) => [x.name, x.place, x.solved])).toEqual([
      ["dan", 1, true],
      ["", 2, true], // the viewer, nameless, tied with bob on 0:41
      ["bob", 2, true],
      ["cat", 4, false],
    ]);
    expect(r.rows[3].durationMs).toBeUndefined();

    // Hidden from everyone else, never from herself.
    const own = await results(t, f, roomId);
    expect(own.rows[0]).toMatchObject({ userId: f.userId, name: "", place: 1 });
    expect(own.played).toBe(5);
  });

  test("shows friends only, never strangers who share the room", async () => {
    const t = convexTest(schema);
    const a = await signUp(t, "ada");
    const b = await signUp(t, "bob");
    const c = await signUp(t, "cat");
    const roomId = await room(t, a, b, c);
    await befriend(t, a, b);
    await solved(t, b, 20_000);
    await solved(t, c, 10_000); // in the room, not ada's friend
    const r = await results(t, a, roomId);
    expect(r.rows.map((x: any) => x.name)).toEqual(["bob"]);
    // Cat sees neither of them: she is nobody's friend here.
    const hers = await results(t, c, roomId);
    expect(hers.rows.map((x: any) => x.userId)).toEqual([c.userId]);
  });

  test("a DM says so", async () => {
    const t = convexTest(schema);
    const a = await signUp(t, "ada");
    const b = await signUp(t, "bob");
    const roomId = await t.run(async (ctx) => {
      const id = await ctx.db.insert("rooms", {
        name: `dm:${a.userId}:${b.userId}`,
        createdBy: a.userId,
        isPrivate: true,
        createdAt: 1,
        memberCount: 2,
      } as any);
      for (const who of [a, b]) {
        await ctx.db.insert("roomMembers", {
          roomId: id,
          userId: who.userId,
          joinedAt: 1,
          role: "member",
        } as any);
      }
      return id;
    });
    await befriend(t, a, b);
    await solved(t, b, 17_000);
    const r = await results(t, a, roomId);
    expect(r).toMatchObject({ isGroup: false, played: 1 });
  });
});

describe("the challenge push", () => {
  test("is a question in every language, with the time inside it", () => {
    expect(Object.keys(CHALLENGE_PUSH_TABLE)).toHaveLength(12);
    for (const [lang, line] of Object.entries(CHALLENGE_PUSH_TABLE)) {
      expect(line, lang).toContain("{game}");
      expect(line, lang).toContain("{time}");
      expect(line, lang).not.toContain("—");
      expect(/[?？؟]$/.test(line), lang).toBe(true);
    }
    expect(challengePushBody(undefined, "zip", 17_400)).toBe(
      "Can you beat my 0:17 on Zip?",
    );
    expect(challengePushBody("tr-TR", "queens", 161_000)).toBe(
      "Kraliçeler oyununda 2:41 yaptım. Geçebilir misin?",
    );
    expect(challengePushBody("en", "sudoku", 61_000)).toBe(
      "Can you beat my 1:01 on Mini Sudoku?",
    );
    expect(challengePushBody("pt_BR", "zip", 9_000)).toBe(
      "Você consegue bater meu 0:09 em Zip?",
    );
    expect(challengePushBody("xx", "zip", 9_000)).toBe("Can you beat my 0:09 on Zip?");
  });

  test("plans each recipient's language off their newest handset", async () => {
    const t = convexTest(schema);
    const a = await signUp(t, "ada");
    const b = await signUp(t, "bob");
    const roomId = await room(t, a, b);
    await solved(t, a, 161_000);
    const [messageId] = (await t.mutation(api.challenges.send, {
      sessionToken: a.token,
      userId: a.userId,
      roomIds: [roomId],
      game: "queens",
      dayKey: DAY,
    })) as any[];
    await t.run(async (ctx) => {
      for (const [deviceId, locale, lastSeenAt] of [
        ["old", "en_US", 5],
        ["new", "tr_TR", 10],
      ] as const) {
        await ctx.db.insert("userDevices", {
          userId: b.userId,
          deviceId,
          platform: "android",
          locale,
          lastSeenAt,
          createdAt: 1,
        } as any);
      }
    });
    const plan: any = await t.query(internal.challenges._pushPlan, {
      messageId,
      userIds: [b.userId],
    });
    expect(plan).toMatchObject({ game: "queens", durationMs: 161_000 });
    expect(plan.locales[b.userId]).toBe("tr_TR");
  });
});
