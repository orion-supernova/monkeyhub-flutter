import { convexTest } from "convex-test";
import { afterEach, beforeEach, describe, expect, test, vi } from "vitest";
import { api } from "./_generated/api";
import schema from "./schema";
import { REPORT_GRACE_MS } from "./partyGames/fight";

/**
 * Jungle Fist through `matches.ts` and `fightSignals.ts`: the fight runs phone
 * to phone, so the server's whole job is the lobby, the signalling, and
 * settling the reported result.
 */

type Who = { token: string; userId: any };
type T = ReturnType<typeof convexTest>;

async function signUp(t: T, username: string) {
  return (await t.mutation(api.auth.signup, {
    username,
    name: username,
    passwordHash: `hash-${username}`,
    recoveryKeyHash: `recovery-${username}`,
    // One device per person: a deviceId is one handset, and signing in
    // on it signs out whoever was there before.
    deviceId: `device-${username}`,
  })) as Who;
}

function as(who: Who) {
  return { sessionToken: who.token, userId: who.userId };
}

async function group(t: T, owner: Who, ...others: Who[]) {
  const roomId = await t.mutation(api.rooms.create, {
    ...as(owner),
    name: "party night",
    isPrivate: false,
  });
  for (const o of others) {
    await t.mutation(api.rooms.join, { ...as(o), roomId });
  }
  return roomId;
}

async function read(t: T, who: Who, matchId: any) {
  return (await t.query(api.matches.get, {
    sessionToken: who.token,
    matchId,
    viewerUserId: who.userId,
  })) as any;
}

async function pub(t: T, who: Who, matchId: any) {
  return JSON.parse((await read(t, who, matchId)).state);
}

async function secret(t: T, who: Who, matchId: any) {
  return (await t.query(api.matches.mySecret, {
    sessionToken: who.token,
    matchId,
    viewerUserId: who.userId,
  })) as any;
}

async function hidden(t: T, matchId: any): Promise<any> {
  return await t.run(async (ctx: any) => {
    const row = await ctx.db
      .query("matchHidden")
      .withIndex("by_match", (q: any) => q.eq("matchId", matchId))
      .first();
    return row ? JSON.parse(row.state) : null;
  });
}

async function act(
  t: T,
  who: Who,
  matchId: any,
  action: string,
  opts: { seq?: number; clientActionId?: string } = {},
) {
  const seq = opts.seq ?? (await read(t, who, matchId)).seq;
  return (await t.mutation(api.matches.partyAct, {
    ...as(who),
    matchId,
    expectedSeq: seq,
    action,
    clientActionId: opts.clientActionId,
  })) as { seq: number; replay: boolean; ignored: boolean };
}

/** [advance] from matches.test.ts: 10 s steps, beats, due jobs run. */
async function advance(t: T, ms: number, matchId: any, beaters: Who[] = []) {
  for (let done = 0; done < ms; done += 10_000) {
    vi.advanceTimersByTime(Math.min(10_000, ms - done));
    await t.finishInProgressScheduledFunctions();
    for (const who of beaters) {
      await t.mutation(api.matches.beat, { ...as(who), matchId });
    }
  }
}

/** A group of four (the last one only watches) and a started party game. */
async function party(
  t: T,
  game: string,
  seated: number,
  options?: { voice?: boolean; puzzle?: string },
) {
  const people = [
    await signUp(t, "ada"),
    await signUp(t, "bob"),
    await signUp(t, "cem"),
    await signUp(t, "dee"),
  ];
  const roomId = await group(t, people[0], ...people.slice(1));
  const { matchId } = (await t.mutation(api.matches.create, {
    ...as(people[0]),
    roomId,
    game,
    mode: "live",
    options,
  })) as any;
  for (const p of people.slice(1, seated)) {
    await t.mutation(api.matches.join, { ...as(p), matchId });
  }
  for (const p of people.slice(0, seated)) {
    await t.mutation(api.matches.setReady, { ...as(p), matchId, ready: true });
  }
  const players = people.slice(0, seated);
  const watcher = people[3];
  return { roomId, matchId, players, watcher, people };
}


beforeEach(() => vi.useFakeTimers());
afterEach(() => vi.useRealTimers());

async function fight(t: T) {
  const r = await party(t, "fight", 2);
  return { ...r, a: r.players[0], b: r.players[1] };
}

describe("fight result", () => {
  test("both phones agree: that result stands", async () => {
    const t = convexTest(schema);
    const { matchId, a, b } = await fight(t);
    expect((await read(t, a, matchId)).status).toBe("active");
    await act(t, a, matchId, "result:1:4242");
    expect((await read(t, a, matchId)).status).toBe("active");
    await act(t, b, matchId, "result:1:4242");
    const m = await read(t, a, matchId);
    expect(m.status).toBe("finished");
    expect(m.winner).toBe(1);
    expect(m.reason).toBe("win");
  });

  test("a draw both agree on", async () => {
    const t = convexTest(schema);
    const { matchId, a, b } = await fight(t);
    await act(t, a, matchId, "result:-1:7");
    await act(t, b, matchId, "result:-1:7");
    const m = await read(t, a, matchId);
    expect(m.draw).toBe(true);
    expect(m.reason).toBe("draw");
  });

  test("they disagree: a disputed draw", async () => {
    const t = convexTest(schema);
    const { matchId, a, b } = await fight(t);
    await act(t, a, matchId, "result:0:111");
    await act(t, b, matchId, "result:1:111");
    const m = await read(t, a, matchId);
    expect(m.draw).toBe(true);
    expect(m.reason).toBe("disputed");
  });

  test("same winner, different checksum: disputed too", async () => {
    const t = convexTest(schema);
    const { matchId, a, b } = await fight(t);
    await act(t, a, matchId, "result:0:111");
    await act(t, b, matchId, "result:0:112");
    expect((await read(t, a, matchId)).reason).toBe("disputed");
  });

  test("only one phone reports: it stands after the grace", async () => {
    const t = convexTest(schema);
    const { matchId, a, b } = await fight(t);
    await act(t, a, matchId, "result:0:99");
    await advance(t, REPORT_GRACE_MS + 10_000, matchId, [a, b]);
    const m = await read(t, a, matchId);
    expect(m.status).toBe("finished");
    expect(m.winner).toBe(0);
    expect(m.reason).toBe("unconfirmed");
  });

  test("leaving before any report forfeits", async () => {
    const t = convexTest(schema);
    const { matchId, a, b } = await fight(t);
    await t.mutation(api.matches.leave, { ...as(b), matchId });
    const m = await read(t, a, matchId);
    expect(m.winner).toBe(0);
    expect(m.reason).toBe("left");
  });

  test("bad tokens and double reports are refused", async () => {
    const t = convexTest(schema);
    const { matchId, a } = await fight(t);
    await expect(act(t, a, matchId, "result:2:1")).rejects.toThrow();
    await expect(act(t, a, matchId, "result:0:abc")).rejects.toThrow();
    await act(t, a, matchId, "result:0:1");
    await expect(act(t, a, matchId, "result:0:1")).rejects.toThrow(/ALREADY_REPORTED/);
  });

  test("only two seats", async () => {
    const t = convexTest(schema);
    const { matchId, people } = await party(t, "fight", 1);
    await t.mutation(api.matches.join, { ...as(people[1]), matchId });
    await expect(t.mutation(api.matches.join, { ...as(people[2]), matchId })).rejects.toThrow(/FULL/);
  });
});

describe("fight signals", () => {
  async function send(t: T, from: Who, matchId: any, to: Who, kind = "offer", payload = "{}") {
    return await t.mutation(api.fightSignals.send, {
      ...as(from),
      matchId,
      toUserId: to.userId,
      kind,
      payload,
      fromDeviceId: "dev-x",
    });
  }
  async function inbox(t: T, who: Who, matchId: any) {
    return (await t.query(api.fightSignals.forMe, {
      sessionToken: who.token,
      matchId,
      viewerUserId: who.userId,
    })) as any[];
  }

  test("seated players signal each other; consume deletes", async () => {
    const t = convexTest(schema);
    const { matchId, a, b } = await fight(t);
    await send(t, a, matchId, b, "offer", JSON.stringify({ sdp: "x" }));
    await send(t, a, matchId, b, "ice", "[]");
    expect(await inbox(t, a, matchId)).toHaveLength(0);
    const got = await inbox(t, b, matchId);
    expect(got.map((r) => r.kind)).toEqual(["offer", "ice"]);
    expect(got[0].fromDeviceId).toBe("dev-x");
    // Somebody else cannot consume b's rows.
    await t.mutation(api.fightSignals.consume, { ...as(a), signalIds: got.map((r) => r._id) });
    expect(await inbox(t, b, matchId)).toHaveLength(2);
    await t.mutation(api.fightSignals.consume, { ...as(b), signalIds: got.map((r) => r._id) });
    expect(await inbox(t, b, matchId)).toHaveLength(0);
  });

  test("outsiders, self-signals and unknown kinds are refused", async () => {
    const t = convexTest(schema);
    const { matchId, a, b, watcher } = await fight(t);
    await expect(send(t, watcher, matchId, a)).rejects.toThrow(/NOT_SEATED/);
    await expect(send(t, a, matchId, a)).rejects.toThrow(/WRONG_PEER/);
    await expect(send(t, a, matchId, watcher)).rejects.toThrow(/WRONG_PEER/);
    await expect(send(t, a, matchId, b, "media")).rejects.toThrow(/BAD_ARGS/);
    expect(await inbox(t, watcher, matchId)).toHaveLength(0);
  });

  test("a finished fight takes no new signals", async () => {
    const t = convexTest(schema);
    const { matchId, a, b } = await fight(t);
    await t.mutation(api.matches.leave, { ...as(b), matchId });
    expect(await send(t, a, matchId, b)).toBeNull();
    expect(await inbox(t, b, matchId)).toHaveLength(0);
  });
});
