import { convexTest } from "convex-test";
import { afterEach, beforeEach, describe, expect, test, vi } from "vitest";
import { api } from "./_generated/api";
import schema from "./schema";
import { ASYNC_EXPIRE_MS, MAX_TAKEBACKS } from "./matches";
import { matchLine, MATCH_COPY_TABLE } from "./matchCopy";
import { rulesFor, turnGames } from "./turnGames/registry";

/**
 * Takebacks, draw-offer pacing and the move list (`matches.history`):
 *
 *   1. Only the player who made the last move may ask, the opponent decides,
 *      and nothing changes until they say yes.
 *   2. A granted takeback restores EXACTLY the position before that move, in
 *      every game, and `seq` keeps climbing.
 *   3. A declined request is not repeated at the same position; each seat
 *      gets [MAX_TAKEBACKS] per game.
 *   4. A declined draw offer is not repeated until two more moves land.
 *   5. The move list is the effective line, for members, for turn games only.
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

async function dm(t: T, a: Who, b: Who) {
  await t.mutation(api.friends.sendRequest, {
    ...as(a),
    friendUsername: ((await t.run((ctx) => ctx.db.get(b.userId))) as any)
      .username,
  });
  await t.mutation(api.friends.acceptRequest, {
    ...as(b),
    requesterId: a.userId,
  });
  return await t.mutation(api.rooms.getOrCreateDM, {
    sessionToken: a.token,
    userId: a.userId,
    friendId: b.userId,
  });
}

async function read(t: T, who: Who, matchId: any) {
  return (await t.query(api.matches.get, {
    sessionToken: who.token,
    matchId,
    viewerUserId: who.userId,
  })) as any;
}

async function history(t: T, who: Who, matchId: any) {
  return (await t.query(api.matches.history, {
    sessionToken: who.token,
    matchId,
    viewerUserId: who.userId,
  })) as any;
}

async function play(t: T, who: Who, matchId: any, move: string) {
  const m = await read(t, who, matchId);
  return await t.mutation(api.matches.move, {
    ...as(who),
    matchId,
    expectedSeq: m.seq,
    move,
    clientMoveId: `mv-${m.seq}-${move}`,
  });
}

/** An async DM game of [game] between ada (seat 0) and bob (seat 1). */
async function asyncGame(t: T, game: string) {
  const a = await signUp(t, "ada");
  const b = await signUp(t, "bob");
  const roomId = await dm(t, a, b);
  const { matchId } = (await t.mutation(api.matches.create, {
    ...as(a),
    roomId,
    game,
    mode: "async",
  })) as any;
  const seat = [a, b];
  return { a, b, roomId, matchId, seat };
}

async function liveGame(t: T, game: string) {
  const a = await signUp(t, "ada");
  const b = await signUp(t, "bob");
  const c = await signUp(t, "cem");
  const roomId = await t.mutation(api.rooms.create, {
    sessionToken: a.token,
    userId: a.userId,
    name: "games night",
    isPrivate: false,
  });
  for (const o of [b, c]) {
    await t.mutation(api.rooms.join, { ...as(o), roomId });
  }
  const { matchId } = (await t.mutation(api.matches.create, {
    ...as(a),
    roomId,
    game,
    mode: "live",
  })) as any;
  await t.mutation(api.matches.join, { ...as(b), matchId });
  await t.mutation(api.matches.setReady, { ...as(a), matchId, ready: true });
  await t.mutation(api.matches.setReady, { ...as(b), matchId, ready: true });
  return { a, b, c, roomId, matchId };
}

const ask = (t: T, who: Who, matchId: any) =>
  t.mutation(api.matches.requestTakeback, { ...as(who), matchId });
const answer = (t: T, who: Who, matchId: any, accept: boolean) =>
  t.mutation(api.matches.answerTakeback, { ...as(who), matchId, accept });

/** A small seeded generator, so a failing line can be replayed. */
function rng(seed: number) {
  let x = seed >>> 0 || 1;
  return () => {
    x ^= x << 13;
    x ^= x >>> 17;
    x ^= x << 5;
    return (x >>> 0) / 4294967296;
  };
}

/**
 * A random line of [game] whose LAST move satisfies [want] (and leaves the
 * game going), from seeded playouts.
 */
function findLine(
  game: string,
  want: (before: any, move: string, after: () => any) => boolean,
  maxPlies = 120,
): string[] {
  const rules = rulesFor(game)!;
  for (let seed = 1; seed < 4000; seed++) {
    const rand = rng(seed);
    let s = rules.initial(2);
    const line: string[] = [];
    for (let ply = 0; ply < maxPlies; ply++) {
      const legal = rules.legalMoves(s);
      if (legal.length === 0) break;
      const hits = legal.filter((m) => {
        const after = () => rules.apply(s, m);
        return want(s, m, after) && rules.outcome(after()) === null;
      });
      if (hits.length > 0 && ply >= 2) {
        return [...line, hits[Math.floor(rand() * hits.length)]];
      }
      const m = legal[Math.floor(rand() * legal.length)];
      const next = rules.apply(s, m);
      if (rules.outcome(next) !== null) break;
      line.push(m);
      s = next;
    }
  }
  throw new Error(`no line found for ${game}`);
}

/** Plays [line] through the server, each move by whoever is to move. */
async function playLine(t: T, g: Awaited<ReturnType<typeof asyncGame>>, game: string, line: string[]) {
  const rules = rulesFor(game)!;
  let s = rules.initial(2);
  const states = [rules.encode(s)];
  for (const m of line) {
    const mover = g.seat[rules.toMove(s)];
    await play(t, mover, g.matchId, m);
    s = rules.apply(s, m);
    states.push(rules.encode(s));
  }
  return { states, lastMover: g.seat[rules.toMove(rules.decode(states[states.length - 2]))] };
}

beforeEach(() => {
  vi.useFakeTimers();
});
afterEach(() => {
  vi.useRealTimers();
});

describe("takebacks", () => {
  test("asked by the last mover, granted by the opponent, restores the position", async () => {
    const t = convexTest(schema);
    const g = await asyncGame(t, "tictactoe");
    await play(t, g.a, g.matchId, "4");
    const before = await read(t, g.a, g.matchId);
    await play(t, g.b, g.matchId, "0");

    // Not the last mover; the opponent of a request cannot grant their own.
    await expect(ask(t, g.a, g.matchId)).rejects.toThrow("NOTHING_TO_TAKE_BACK");
    await ask(t, g.b, g.matchId);
    let m = await read(t, g.a, g.matchId);
    expect(m.takebackOffer).toEqual({ seat: 1, seq: 2 });
    await expect(answer(t, g.b, g.matchId, true)).rejects.toThrow("NOT_SEATED");
    // Nothing changes until the answer.
    expect(m.state).not.toBe(before.state);

    await answer(t, g.a, g.matchId, true);
    m = await read(t, g.a, g.matchId);
    expect(m.state).toBe(before.state);
    expect(m.seq).toBe(3); // monotonic: the takeback is a row of its own
    expect(m.turnSeat).toBe(1);
    expect(m.lastMove).toBe("4");
    expect(m.takebackOffer).toBeUndefined();
    expect(m.takebacks).toEqual([0, 1]);
    // The undone move can be played again, or another one.
    await play(t, g.b, g.matchId, "8");
    expect((await history(t, g.a, g.matchId)).moves).toEqual([
      { seat: 0, move: "4" },
      { seat: 1, move: "8" },
    ]);
  });

  test("an old move resent after a takeback is not replayed", async () => {
    const t = convexTest(schema);
    const g = await asyncGame(t, "tictactoe");
    await play(t, g.a, g.matchId, "4");
    await play(t, g.b, g.matchId, "0");
    await ask(t, g.b, g.matchId);
    await answer(t, g.a, g.matchId, true);
    // bob's original send, resent by a reconnecting client.
    const res = await t.mutation(api.matches.move, {
      ...as(g.b),
      matchId: g.matchId,
      expectedSeq: 1,
      move: "0",
      clientMoveId: "mv-1-0",
    });
    expect(res).toMatchObject({ replay: true });
    // A new move against the pre-takeback seq is stale.
    await expect(
      t.mutation(api.matches.move, {
        ...as(g.b),
        matchId: g.matchId,
        expectedSeq: 2,
        move: "1",
      }),
    ).rejects.toThrow("STALE");
    expect((await history(t, g.a, g.matchId)).moves).toHaveLength(1);
  });

  test("a request dies with the next move, and a decline is not repeated there", async () => {
    const t = convexTest(schema);
    const g = await asyncGame(t, "connectfour");
    await play(t, g.a, g.matchId, "3");
    await ask(t, g.a, g.matchId);
    await answer(t, g.b, g.matchId, false);
    let m = await read(t, g.a, g.matchId);
    expect(m.takebackOffer).toBeUndefined();
    expect(m.takebackDeclined).toEqual({ seat: 0, seq: 1 });
    await expect(ask(t, g.a, g.matchId)).rejects.toThrow("TOO_SOON");

    await play(t, g.b, g.matchId, "3");
    await ask(t, g.b, g.matchId);
    await play(t, g.a, g.matchId, "4"); // answering by playing on
    m = await read(t, g.a, g.matchId);
    expect(m.takebackOffer).toBeUndefined();
    await expect(answer(t, g.a, g.matchId, true)).rejects.toThrow("NO_OFFER");
  });

  test("each seat gets three per game", async () => {
    const t = convexTest(schema);
    const g = await asyncGame(t, "connectfour");
    for (let i = 0; i < MAX_TAKEBACKS; i++) {
      await play(t, g.a, g.matchId, "0");
      await ask(t, g.a, g.matchId);
      await answer(t, g.b, g.matchId, true);
    }
    await play(t, g.a, g.matchId, "0");
    await expect(ask(t, g.a, g.matchId)).rejects.toThrow("NO_TAKEBACKS_LEFT");
    expect((await read(t, g.b, g.matchId)).takebacks).toEqual([3, 0]);
  });

  test("turn by turn: the bubble goes, the clock restarts, the asker is told", async () => {
    const t = convexTest(schema);
    const g = await asyncGame(t, "tictactoe");
    await play(t, g.a, g.matchId, "4");
    vi.advanceTimersByTime(ASYNC_EXPIRE_MS - 60_000);
    await play(t, g.b, g.matchId, "0");
    const bubbles = async () =>
      t.run(async (ctx) =>
        (await ctx.db.query("messages").collect()).filter(
          (x: any) => x.type === "gameMove",
        ),
      );
    expect(await bubbles()).toHaveLength(2);
    const jobsBefore = await t.run(async (ctx) =>
      (await ctx.db.system.query("_scheduled_functions").collect()).length,
    );
    await ask(t, g.b, g.matchId);
    await answer(t, g.a, g.matchId, true);
    const left = await bubbles();
    expect(left.map((x: any) => x.gameMove.move)).toEqual(["4"]);
    const jobs = await t.run(async (ctx) =>
      (await ctx.db.system.query("_scheduled_functions").collect()).slice(
        jobsBefore,
      ),
    );
    const pushes = jobs
      .filter((j: any) => j.name.includes("sendMatchPush"))
      .map((j: any) => j.args[0]);
    expect(pushes).toEqual([
      expect.objectContaining({ toUserId: g.a.userId, key: "takebackAsked" }),
      expect.objectContaining({ toUserId: g.b.userId, key: "takebackGiven" }),
    ]);
    const m = await read(t, g.a, g.matchId);
    expect(m.deadlineAt).toBeGreaterThan(Date.now() + ASYNC_EXPIRE_MS - 1000);
    // ada's turn would have timed out a minute after her move; it did not.
    vi.advanceTimersByTime(120_000);
    await t.finishInProgressScheduledFunctions();
    expect((await read(t, g.a, g.matchId)).status).toBe("active");
  });

  test("live, between the two players only; never in a finished or paused game", async () => {
    const t = convexTest(schema);
    const g = await liveGame(t, "tictactoe");
    await play(t, g.a, g.matchId, "4");
    await expect(ask(t, g.c, g.matchId)).rejects.toThrow("NOT_SEATED");
    await ask(t, g.a, g.matchId);
    await expect(answer(t, g.c, g.matchId, true)).rejects.toThrow("NOT_SEATED");
    // Leaving the board pauses the game, and the request goes with the pause.
    await t.mutation(api.matches.away, { ...as(g.b), matchId: g.matchId });
    const paused = await read(t, g.a, g.matchId);
    expect(paused.status).toBe("paused");
    expect(paused.takebackOffer).toBeUndefined();
    await expect(answer(t, g.b, g.matchId, true)).rejects.toThrow("NOT_ACTIVE");
    await expect(ask(t, g.a, g.matchId)).rejects.toThrow("NOT_ACTIVE");
  });

  test("not in a party game", async () => {
    const t = convexTest(schema);
    const g = await liveGame(t, "liarsdice");
    await expect(ask(t, g.a, g.matchId)).rejects.toThrow("NO_TAKEBACKS");
    expect(await history(t, g.a, g.matchId)).toBeNull();
  });

  // Replay equality, per game, at the moves that are easiest to get wrong.
  const cases: [string, (b: any, m: string, a: () => any) => boolean][] = [
    ["tictactoe", () => true],
    ["connectfour", () => true],
    ["reversi", () => true],
    ["chess", (_b, m) => m.length === 5], // a promotion
    ["chess", (_b, m) => m === "e1g1" || m === "e8g8"], // castling
    ["checkers", (_b, m) => m.split("x").length > 2], // a multi-jump
    ["dots", (b, _m, a) => rulesFor("dots")!.toMove(b) === rulesFor("dots")!.toMove(a())], // extra turn
  ];
  for (const [game, want] of cases) {
    test(`${game}: the position before the move, exactly`, async () => {
      const t = convexTest(schema);
      const g = await asyncGame(t, game);
      const line = findLine(game, want, game === "chess" ? 200 : 120);
      const { states, lastMover } = await playLine(t, g, game, line);
      const other = lastMover === g.a ? g.b : g.a;
      await ask(t, lastMover, g.matchId);
      await answer(t, other, g.matchId, true);
      const m = await read(t, g.a, g.matchId);
      expect(m.state).toBe(states[states.length - 2]);
      expect(m.lastMove).toBe(line[line.length - 2]);
      expect((await history(t, g.b, g.matchId)).moves.map((x: any) => x.move)).toEqual(
        line.slice(0, -1),
      );
    }, 60_000);
  }

  test("every two-seat game is covered above", () => {
    const covered = new Set(cases.map(([g]) => g));
    for (const id of Object.keys(turnGames)) expect(covered.has(id), id).toBe(true);
  });
});

describe("draw offers", () => {
  test("a declined offer waits two moves before it can be made again", async () => {
    const t = convexTest(schema);
    const g = await asyncGame(t, "connectfour");
    await t.mutation(api.matches.offerDraw, { ...as(g.a), matchId: g.matchId });
    await t.mutation(api.matches.answerDraw, {
      ...as(g.b),
      matchId: g.matchId,
      accept: false,
    });
    expect((await read(t, g.a, g.matchId)).drawDeclined).toEqual({ seat: 0, seq: 0 });
    await expect(
      t.mutation(api.matches.offerDraw, { ...as(g.a), matchId: g.matchId }),
    ).rejects.toThrow("TOO_SOON");
    await play(t, g.a, g.matchId, "3");
    await expect(
      t.mutation(api.matches.offerDraw, { ...as(g.a), matchId: g.matchId }),
    ).rejects.toThrow("TOO_SOON");
    // The other side is not held back by somebody else's refusal.
    await t.mutation(api.matches.offerDraw, { ...as(g.b), matchId: g.matchId });
    await t.mutation(api.matches.answerDraw, {
      ...as(g.a),
      matchId: g.matchId,
      accept: false,
    });
    await play(t, g.b, g.matchId, "3");
    await t.mutation(api.matches.offerDraw, { ...as(g.a), matchId: g.matchId });
    expect((await read(t, g.b, g.matchId)).drawOffer).toEqual({ seat: 0, seq: 2 });
  });

  test("a spectator can neither offer nor answer", async () => {
    const t = convexTest(schema);
    const g = await liveGame(t, "tictactoe");
    await expect(
      t.mutation(api.matches.offerDraw, { ...as(g.c), matchId: g.matchId }),
    ).rejects.toThrow("NOT_SEATED");
    await t.mutation(api.matches.offerDraw, { ...as(g.a), matchId: g.matchId });
    await expect(
      t.mutation(api.matches.answerDraw, {
        ...as(g.c),
        matchId: g.matchId,
        accept: true,
      }),
    ).rejects.toThrow("NOT_SEATED");
  });

  test("a seat swap clears every offer between the old pair", async () => {
    const t = convexTest(schema);
    const g = await liveGame(t, "tictactoe");
    await play(t, g.a, g.matchId, "4");
    await ask(t, g.a, g.matchId);
    await t.mutation(api.matches.requestSeat, {
      ...as(g.c),
      matchId: g.matchId,
      seat: 1,
    });
    await t.mutation(api.matches.answerSeatRequest, {
      ...as(g.b),
      matchId: g.matchId,
      accept: true,
    });
    const m = await read(t, g.a, g.matchId);
    expect(m.seats[1].userId).toBe(g.c.userId);
    expect(m.takebackOffer).toBeUndefined();
    expect(m.drawOffer).toBeUndefined();
  });
});

describe("the move list", () => {
  test("members only", async () => {
    const t = convexTest(schema);
    const g = await asyncGame(t, "tictactoe");
    await play(t, g.a, g.matchId, "4");
    const z = await signUp(t, "zed");
    expect(await history(t, z, g.matchId)).toBeNull();
    expect(await history(t, g.b, g.matchId)).toEqual({
      seq: 1,
      moves: [{ seat: 0, move: "4" }],
    });
  });

  test("takeback push copy is in every locale, without em dashes", () => {
    for (const [locale, copy] of Object.entries(MATCH_COPY_TABLE)) {
      for (const key of ["takebackAsked", "takebackGiven"] as const) {
        expect((copy as any)[key], `${locale}.${key}`).toMatch(/\{name\}/);
        expect((copy as any)[key]).toMatch(/\{game\}/);
        expect((copy as any)[key]).not.toContain("—");
      }
    }
    expect(matchLine("en", "takebackGiven", "chess", "Bob")).toBe(
      "Bob let you take back your move. Your move in Chess.",
    );
  });
});
