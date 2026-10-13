import { convexTest } from "convex-test";
import { afterEach, beforeEach, describe, expect, test, vi } from "vitest";
import { api, internal } from "./_generated/api";
import schema from "./schema";
import {
  ASYNC_EXPIRE_MS,
  LIVE_GRACE_MS,
  MAX_ASYNC_PER_DM,
  NUDGE_EVERY_MS,
} from "./matches";
import { matchLine, MATCH_COPY_TABLE } from "./matchCopy";

/**
 * In-chat games: the promises `matches.ts` makes in its header, each pinned.
 *
 *   1. The rules module is the only way a board changes; an illegal, early,
 *      stale or out-of-turn move is refused and changes nothing.
 *   2. A resent move is answered as the success it was, never applied twice.
 *   3. One live game per room; at most three async games per DM; async only
 *      in a DM.
 *   4. Only members play, watch, or ask for a seat.
 *   5. Leaving the board pauses a live game; the grace period ends it for
 *      whoever stayed away. An async turn left unanswered times out.
 *   6. Leaving the room, or deleting the card, takes the games with it.
 *   7. None of it ever writes a daily game's tables.
 */

type Who = { token: string; userId: any };
const DEVICE = "device-a";

async function signUp(t: ReturnType<typeof convexTest>, username: string) {
  return (await t.mutation(api.auth.signup, {
    username,
    name: username,
    passwordHash: `hash-${username}`,
    recoveryKeyHash: `recovery-${username}`,
    deviceId: DEVICE,
  })) as Who;
}

async function dm(t: ReturnType<typeof convexTest>, a: Who, b: Who) {
  await t.mutation(api.friends.sendRequest, {
    ...as(a),
    friendUsername: (await t.run((ctx) => ctx.db.get(b.userId)) as any).username,
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

async function group(t: ReturnType<typeof convexTest>, owner: Who, ...others: Who[]) {
  const roomId = await t.mutation(api.rooms.create, {
    sessionToken: owner.token,
    userId: owner.userId,
    name: "games night",
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

function as(who: Who) {
  return { sessionToken: who.token, userId: who.userId };
}

async function create(
  t: ReturnType<typeof convexTest>,
  who: Who,
  roomId: any,
  game: string,
  mode: "live" | "async",
  clientId?: string,
) {
  return (await t.mutation(api.matches.create, {
    ...as(who),
    roomId,
    game,
    mode,
    clientId,
  })) as { matchId: any; messageId: any };
}

async function read(t: ReturnType<typeof convexTest>, who: Who, matchId: any) {
  return (await t.query(api.matches.get, {
    sessionToken: who.token,
    matchId,
    viewerUserId: who.userId,
  })) as any;
}

async function play(
  t: ReturnType<typeof convexTest>,
  who: Who,
  matchId: any,
  move: string,
  clientMoveId?: string,
) {
  const m = await read(t, who, matchId);
  return await t.mutation(api.matches.move, {
    ...as(who),
    matchId,
    expectedSeq: m.seq,
    move,
    clientMoveId,
  });
}

/**
 * Moves the clock [ms] forward the way a real one passes: in 10 s steps, each
 * with a heartbeat from everyone in [beaters] still at the board (the game
 * screen beats every 10 s), letting every job that came due run.
 */
async function advance(
  t: ReturnType<typeof convexTest>,
  ms: number,
  matchId: any,
  beaters: Who[] = [],
) {
  for (let done = 0; done < ms; done += 10_000) {
    vi.advanceTimersByTime(Math.min(10_000, ms - done));
    await t.finishInProgressScheduledFunctions();
    for (const who of beaters) {
      await t.mutation(api.matches.beat, { ...as(who), matchId });
    }
  }
}

/** A live tic-tac-toe in a fresh group, both players seated and ready. */
async function liveGame(t: ReturnType<typeof convexTest>) {
  const a = await signUp(t, "ada");
  const b = await signUp(t, "bob");
  const c = await signUp(t, "cem");
  const roomId = await group(t, a, b, c);
  const { matchId } = await create(t, a, roomId, "tictactoe", "live");
  await t.mutation(api.matches.join, { ...as(b), matchId });
  await t.mutation(api.matches.setReady, { ...as(a), matchId, ready: true });
  await t.mutation(api.matches.setReady, { ...as(b), matchId, ready: true });
  return { a, b, c, roomId, matchId };
}

beforeEach(() => {
  vi.useFakeTimers();
});
afterEach(() => {
  vi.useRealTimers();
});

describe("a live game", () => {
  test("fills, starts when everyone is ready, and is won by the rules", async () => {
    const t = convexTest(schema);
    const { a, b, matchId } = await liveGame(t);
    const started = await read(t, a, matchId);
    expect(started.status).toBe("active");
    expect(started.seats.map((s: any) => s.name)).toEqual(["ada", "bob"]);
    expect(started.turnSeat).toBe(0);

    // X takes the top row.
    for (const [who, cell] of [
      [a, "0"],
      [b, "3"],
      [a, "1"],
      [b, "4"],
      [a, "2"],
    ] as const) {
      await play(t, who, matchId, cell);
    }
    const done = await read(t, b, matchId);
    expect(done.status).toBe("finished");
    expect(done.winner).toBe(0);
    expect(done.reason).toBe("win");
    expect(done.turnSeat).toBeUndefined();
    await expect(play(t, b, matchId, "5")).rejects.toThrow("NOT_ACTIVE");
  });

  test("refuses an illegal, out-of-turn or stale move, changing nothing", async () => {
    const t = convexTest(schema);
    const { a, b, matchId } = await liveGame(t);
    await expect(play(t, b, matchId, "0")).rejects.toThrow("NOT_YOUR_TURN");
    await expect(play(t, a, matchId, "9")).rejects.toThrow("ILLEGAL");
    await play(t, a, matchId, "4");
    await expect(play(t, b, matchId, "4")).rejects.toThrow("ILLEGAL");
    await expect(
      t.mutation(api.matches.move, {
        ...as(b),
        matchId,
        expectedSeq: 0,
        move: "0",
      }),
    ).rejects.toThrow("STALE");
    const m = await read(t, a, matchId);
    expect(m.seq).toBe(1);
    expect(m.state).toBe("....X..../1");
  });

  test("a resent move is a success, not a second move", async () => {
    const t = convexTest(schema);
    const { a, matchId } = await liveGame(t);
    await t.mutation(api.matches.move, {
      ...as(a),
      matchId,
      expectedSeq: 0,
      move: "4",
      clientMoveId: "m1",
    });
    const again = await t.mutation(api.matches.move, {
      ...as(a),
      matchId,
      expectedSeq: 0,
      move: "4",
      clientMoveId: "m1",
    });
    expect(again).toEqual({ seq: 1, replay: true });
    expect((await read(t, a, matchId)).seq).toBe(1);
  });

  test("one live game per room, and a resent create is not a second one", async () => {
    const t = convexTest(schema);
    const a = await signUp(t, "ada");
    const b = await signUp(t, "bob");
    const roomId = await group(t, a, b);
    const first = await create(t, a, roomId, "connectfour", "live", "c1");
    const resent = await create(t, a, roomId, "connectfour", "live", "c1");
    expect(resent.matchId).toEqual(first.matchId);
    await expect(create(t, b, roomId, "tictactoe", "live")).rejects.toThrow(
      "ALREADY_LIVE",
    );
  });

  test("leaving the board pauses it; coming back resumes it", async () => {
    const t = convexTest(schema);
    const { a, b, matchId } = await liveGame(t);
    await t.mutation(api.matches.away, { ...as(b), matchId });
    const paused = await read(t, a, matchId);
    expect(paused.status).toBe("paused");
    expect(paused.seats[1].away).toBe(true);
    await expect(play(t, a, matchId, "4")).rejects.toThrow("PAUSED");

    await t.mutation(api.matches.beat, { ...as(b), matchId });
    const back = await read(t, a, matchId);
    expect(back.status).toBe("active");
    expect(back.seats[1].away).toBeUndefined();
  });

  test("whoever is still gone when the grace runs out forfeits", async () => {
    const t = convexTest(schema);
    const { a, b, matchId } = await liveGame(t);
    await t.mutation(api.matches.away, { ...as(b), matchId });
    await advance(t, LIVE_GRACE_MS + 1000, matchId, [a]);
    const done = await read(t, a, matchId);
    expect(done.status).toBe("finished");
    expect(done.winner).toBe(0);
    expect(done.reason).toBe("left");
  });

  test("a pause that ended does not let its old timer end a new one", async () => {
    const t = convexTest(schema);
    const { a, b, matchId } = await liveGame(t);
    await t.mutation(api.matches.away, { ...as(b), matchId });
    await t.mutation(api.matches.beat, { ...as(b), matchId });
    await advance(t, LIVE_GRACE_MS - 30_000, matchId, [a, b]);
    await t.mutation(api.matches.away, { ...as(b), matchId });
    // The FIRST pause's timer comes due inside this window, and must do
    // nothing: this pause is only 40 s old.
    await advance(t, 40_000, matchId, [a]);
    expect((await read(t, a, matchId)).status).toBe("paused");
  });

  test("a spectator asks, the holder agrees, and they swap mid-game", async () => {
    const t = convexTest(schema);
    const { a, b, c, matchId } = await liveGame(t);
    await play(t, a, matchId, "4");
    await t.mutation(api.matches.requestSeat, { ...as(c), matchId, seat: 1 });
    await expect(
      t.mutation(api.matches.answerSeatRequest, { ...as(a), matchId, accept: true }),
    ).rejects.toThrow("NOT_YOURS");
    await t.mutation(api.matches.answerSeatRequest, {
      ...as(b),
      matchId,
      accept: true,
    });
    const m = await read(t, a, matchId);
    expect(m.seats[1].name).toBe("cem");
    expect(m.seatRequest).toBeUndefined();
    // The position carries on, with cem to move.
    await expect(play(t, b, matchId, "0")).rejects.toThrow("NOT_SEATED");
    await play(t, c, matchId, "0");
    expect((await read(t, a, matchId)).seq).toBe(2);
  });

  test("the last one out of a lobby closes it", async () => {
    const t = convexTest(schema);
    const a = await signUp(t, "ada");
    const b = await signUp(t, "bob");
    const roomId = await group(t, a, b);
    const { matchId } = await create(t, a, roomId, "dots", "live");
    await t.mutation(api.matches.join, { ...as(b), matchId });
    await t.mutation(api.matches.leave, { ...as(a), matchId });
    expect((await read(t, b, matchId)).status).toBe("lobby");
    await t.mutation(api.matches.leave, { ...as(b), matchId });
    expect((await read(t, b, matchId)).status).toBe("abandoned");
    // And the room is free for another.
    await create(t, b, roomId, "tictactoe", "live");
  });
});

describe("an async DM game", () => {
  test("starts at once, tells the other player, and times out unanswered", async () => {
    const t = convexTest(schema);
    const a = await signUp(t, "ada");
    const b = await signUp(t, "bob");
    const roomId = await dm(t, a, b);
    const { matchId } = await create(t, a, roomId, "connectfour", "async");
    const m = await read(t, b, matchId);
    expect(m.status).toBe("active");
    expect(m.seats.map((s: any) => s.name)).toEqual(["ada", "bob"]);
    await play(t, a, matchId, "3");
    expect((await read(t, b, matchId)).turnSeat).toBe(1);

    vi.advanceTimersByTime(ASYNC_EXPIRE_MS + 1000);
    await t.finishInProgressScheduledFunctions();
    const done = await read(t, a, matchId);
    expect(done.status).toBe("finished");
    expect(done.winner).toBe(0);
    expect(done.reason).toBe("timeout");
  });

  test("a move answered in time keeps the old deadline from firing", async () => {
    const t = convexTest(schema);
    const a = await signUp(t, "ada");
    const b = await signUp(t, "bob");
    const roomId = await dm(t, a, b);
    const { matchId } = await create(t, a, roomId, "tictactoe", "async");
    vi.advanceTimersByTime(ASYNC_EXPIRE_MS - 60_000);
    await play(t, a, matchId, "4");
    vi.advanceTimersByTime(120_000);
    await t.finishInProgressScheduledFunctions();
    expect((await read(t, a, matchId)).status).toBe("active");
  });

  test("is DM-only, and capped at three at once", async () => {
    const t = convexTest(schema);
    const a = await signUp(t, "ada");
    const b = await signUp(t, "bob");
    const g = await group(t, a, b);
    await expect(create(t, a, g, "tictactoe", "async")).rejects.toThrow(
      "ASYNC_DM_ONLY",
    );
    const roomId = await dm(t, a, b);
    for (let i = 0; i < MAX_ASYNC_PER_DM; i++) {
      await create(t, i % 2 ? a : b, roomId, "tictactoe", "async");
    }
    await expect(create(t, a, roomId, "reversi", "async")).rejects.toThrow(
      "TOO_MANY_GAMES",
    );
    // A live one alongside is still fine.
    await create(t, a, roomId, "reversi", "live");
  });

  test("a nudge waits its turn", async () => {
    const t = convexTest(schema);
    const a = await signUp(t, "ada");
    const b = await signUp(t, "bob");
    const roomId = await dm(t, a, b);
    const { matchId } = await create(t, a, roomId, "tictactoe", "async");
    await play(t, a, matchId, "4");
    await expect(
      t.mutation(api.matches.nudge, { ...as(a), matchId }),
    ).rejects.toThrow("TOO_SOON");
    await expect(
      t.mutation(api.matches.nudge, { ...as(b), matchId }),
    ).rejects.toThrow("YOUR_MOVE");
    vi.advanceTimersByTime(NUDGE_EVERY_MS + 1000);
    await t.mutation(api.matches.nudge, { ...as(a), matchId });
    await expect(
      t.mutation(api.matches.nudge, { ...as(a), matchId }),
    ).rejects.toThrow("TOO_SOON");
  });

  test("a draw offered and accepted ends it level", async () => {
    const t = convexTest(schema);
    const a = await signUp(t, "ada");
    const b = await signUp(t, "bob");
    const roomId = await dm(t, a, b);
    const { matchId } = await create(t, a, roomId, "checkers", "async");
    await t.mutation(api.matches.offerDraw, { ...as(a), matchId });
    await t.mutation(api.matches.answerDraw, { ...as(b), matchId, accept: true });
    const m = await read(t, a, matchId);
    expect(m.status).toBe("finished");
    expect(m.draw).toBe(true);
  });

  test("every move posts one bubble with the position it made, live games none", async () => {
    const t = convexTest(schema);
    const a = await signUp(t, "ada");
    const b = await signUp(t, "bob");
    const roomId = await dm(t, a, b);
    const { matchId } = await create(t, a, roomId, "tictactoe", "async");
    await play(t, a, matchId, "4", "mv-1");
    // A resend is the success it was: still one bubble.
    await t.mutation(api.matches.move, {
      ...as(a),
      matchId,
      expectedSeq: 0,
      move: "4",
      clientMoveId: "mv-1",
    });
    await play(t, b, matchId, "0");
    const moves = await t.run(async (ctx) =>
      (await ctx.db.query("messages").collect()).filter(
        (m: any) => m.type === "gameMove",
      ),
    );
    expect(moves.map((m: any) => m.userId)).toEqual([a.userId, b.userId]);
    expect(moves[0].gameMove).toMatchObject({
      matchId,
      game: "tictactoe",
      seq: 1,
      seat: 0,
      move: "4",
    });
    expect(moves[1]!.gameMove!.seq).toBe(2);
    expect(moves[1]!.gameMove!.state).toBe((await read(t, a, matchId)).state);
    expect(moves[1]!.content).toBe("Tic-tac-toe · move 2");
    const room = (await t.run((ctx) => ctx.db.get(roomId))) as any;
    expect(room.lastMessage).toBe("[game] Tic-tac-toe · move 2");

    // A live game's board is open on every screen: no bubbles there.
    const t2 = convexTest(schema);
    const g = await liveGame(t2);
    await play(t2, g.a, g.matchId, "4");
    const liveMoves = await t2.run(async (ctx) =>
      (await ctx.db.query("messages").collect()).filter(
        (m: any) => m.type === "gameMove",
      ),
    );
    expect(liveMoves).toHaveLength(0);
  });

  test("a move's bubble sends no push of its own, only the your-move one", async () => {
    const t = convexTest(schema);
    const a = await signUp(t, "ada");
    const b = await signUp(t, "bob");
    const roomId = await dm(t, a, b);
    const { matchId } = await create(t, a, roomId, "tictactoe", "async");
    const before = await t.run(async (ctx) =>
      (await ctx.db.system.query("_scheduled_functions").collect()).length,
    );
    await play(t, a, matchId, "4");
    const jobs = await t.run(async (ctx) =>
      (await ctx.db.system.query("_scheduled_functions").collect()).slice(before),
    );
    const names = jobs.map((j: any) => j.name);
    expect(names.filter((n: string) => n.includes("sendMessagePush"))).toHaveLength(0);
    expect(names.filter((n: string) => n.includes("sendMatchPush"))).toHaveLength(1);
  });

  test("a rematch swaps who goes first", async () => {
    const t = convexTest(schema);
    const a = await signUp(t, "ada");
    const b = await signUp(t, "bob");
    const roomId = await dm(t, a, b);
    const { matchId } = await create(t, a, roomId, "tictactoe", "async");
    await t.mutation(api.matches.resign, { ...as(b), matchId });
    const again = (await t.mutation(api.matches.rematch, {
      ...as(b),
      matchId,
    })) as any;
    const m = await read(t, a, again.matchId);
    expect(m.seats.map((s: any) => s.name)).toEqual(["bob", "ada"]);
  });
});

/** A turn by turn game started the current way: no card, first move sent. */
async function startTurns(
  t: ReturnType<typeof convexTest>,
  who: Who,
  roomId: any,
  game: string,
  move: string,
  clientMoveId: string,
  rematchOf?: any,
) {
  return (await t.mutation(api.matches.startTurns, {
    ...as(who),
    roomId,
    game,
    move,
    clientMoveId,
    rematchOf,
  })) as { matchId: any; messageId: any; seq: number; replay: boolean };
}

async function rowsOf(t: ReturnType<typeof convexTest>) {
  return await t.run(async (ctx) => ({
    matches: await ctx.db.query("matches").collect(),
    moves: await ctx.db.query("matchMoves").collect(),
    messages: await ctx.db.query("messages").collect(),
  }));
}

describe("a turn by turn game with no card", () => {
  test("the first move creates the game, posts its bubble and nothing else", async () => {
    const t = convexTest(schema);
    const a = await signUp(t, "ada");
    const b = await signUp(t, "bob");
    const roomId = await dm(t, a, b);
    const before = await t.run(async (ctx) =>
      (await ctx.db.system.query("_scheduled_functions").collect()).length,
    );
    const res = await startTurns(t, a, roomId, "tictactoe", "4", "mv-first");
    expect(res.seq).toBe(1);
    expect(res.replay).toBe(false);

    const { matches, moves, messages } = await rowsOf(t);
    expect(matches).toHaveLength(1);
    expect(matches[0].messageId).toBeUndefined();
    // No card: the move bubble is the only message.
    expect(messages.map((m: any) => m.type)).toEqual(["gameMove"]);
    expect(messages[0]._id).toBe(res.messageId);
    expect(messages[0].gameMove).toMatchObject({
      matchId: res.matchId,
      game: "tictactoe",
      seq: 1,
      seat: 0,
      move: "4",
    });
    expect(moves).toHaveLength(1);
    expect(moves[0].messageId).toBe(res.messageId);

    const m = await read(t, b, res.matchId);
    expect(m.status).toBe("active");
    expect(m.seats.map((s: any) => s.name)).toEqual(["ada", "bob"]);
    expect(m.turnSeat).toBe(1);
    expect(m.state).toBe(messages[0].gameMove!.state);
    expect(m.deadlineAt).toBeGreaterThan(Date.now());

    // The banner and the chat list's dot both find it, with no card.
    const list = (await t.query(api.matches.listForRoom, {
      sessionToken: b.token,
      roomId,
      viewerUserId: b.userId,
    })) as any[];
    expect(list.map((x) => x.id)).toEqual([res.matchId]);
    const turns = (await t.query(api.matches.myTurns, {
      sessionToken: b.token,
      viewerUserId: b.userId,
    })) as any[];
    expect(turns.map((x) => x.roomId)).toEqual([roomId]);
    const room = (await t.run((ctx) => ctx.db.get(roomId))) as any;
    expect(room.lastMessage).toBe("[game] Tic-tac-toe · move 1");

    // One push, the game's own; the bubble is quiet.
    const jobs = await t.run(async (ctx) =>
      (await ctx.db.system.query("_scheduled_functions").collect()).slice(before),
    );
    const pushes = jobs.filter((j: any) => j.name.includes("sendMatchPush"));
    expect(pushes).toHaveLength(1);
    expect(pushes[0].args[0]).toMatchObject({ toUserId: b.userId, key: "started" });
    expect(
      jobs.filter((j: any) => j.name.includes("sendMessagePush")),
    ).toHaveLength(0);
    expect(matchLine("en", "started", "tictactoe", "Ada")).toBe(
      "Ada started Tic-tac-toe and played. Your move.",
    );

    // And it plays on like any async game.
    await play(t, b, res.matchId, "0");
    expect((await read(t, a, res.matchId)).turnSeat).toBe(0);
  });

  test("a resend is the success it was, not a second game", async () => {
    const t = convexTest(schema);
    const a = await signUp(t, "ada");
    const b = await signUp(t, "bob");
    const roomId = await dm(t, a, b);
    const first = await startTurns(t, a, roomId, "connectfour", "3", "mv-x");
    const again = await startTurns(t, a, roomId, "connectfour", "3", "mv-x");
    expect(again.replay).toBe(true);
    expect(again.matchId).toBe(first.matchId);
    expect(again.messageId).toBe(first.messageId);
    const { matches, messages } = await rowsOf(t);
    expect(matches).toHaveLength(1);
    expect(messages).toHaveLength(1);
  });

  test("the per-DM cap is enforced at the create, and a refusal writes nothing", async () => {
    const t = convexTest(schema);
    const a = await signUp(t, "ada");
    const b = await signUp(t, "bob");
    const roomId = await dm(t, a, b);
    // An older build's carded game counts against the same cap.
    await create(t, b, roomId, "tictactoe", "async");
    for (let i = 1; i < MAX_ASYNC_PER_DM; i++) {
      await startTurns(t, i % 2 ? a : b, roomId, "tictactoe", "4", `mv-${i}`);
    }
    const before = await rowsOf(t);
    await expect(
      startTurns(t, a, roomId, "reversi", "19", "mv-over"),
    ).rejects.toThrow("TOO_MANY_GAMES");
    const after = await rowsOf(t);
    expect(after.matches).toHaveLength(MAX_ASYNC_PER_DM);
    expect(after.messages).toHaveLength(before.messages.length);
    expect(after.moves).toHaveLength(before.moves.length);
  });

  test("an illegal first move is refused, creating nothing", async () => {
    const t = convexTest(schema);
    const a = await signUp(t, "ada");
    const b = await signUp(t, "bob");
    const roomId = await dm(t, a, b);
    await expect(
      startTurns(t, a, roomId, "tictactoe", "9", "mv-bad"),
    ).rejects.toThrow("ILLEGAL");
    await expect(
      startTurns(t, a, roomId, "liarsdice", "x", "mv-party"),
    ).rejects.toThrow("LIVE_ONLY");
    const g = await group(t, a, b);
    await expect(
      startTurns(t, a, g, "tictactoe", "4", "mv-group"),
    ).rejects.toThrow("ASYNC_DM_ONLY");
    const { matches, moves, messages } = await rowsOf(t);
    expect(matches).toHaveLength(0);
    expect(moves).toHaveLength(0);
    expect(messages.filter((m: any) => m.type === "gameMove")).toHaveLength(0);
    const room = (await t.run((ctx) => ctx.db.get(roomId))) as any;
    expect(room.lastMessage ?? "").not.toContain("[game]");
  });

  test("deleting the first move's bubble leaves a playable game", async () => {
    const t = convexTest(schema);
    const a = await signUp(t, "ada");
    const b = await signUp(t, "bob");
    const roomId = await dm(t, a, b);
    const { matchId, messageId } = await startTurns(
      t, a, roomId, "tictactoe", "4", "mv-1",
    );
    await t.mutation(api.messages.deleteMessage, { ...as(a), messageId });
    await t.run(async (ctx) => {
      expect(await ctx.db.get(messageId)).toBeNull();
      expect(await ctx.db.get(matchId)).not.toBeNull();
      expect(await ctx.db.query("matchMoves").collect()).toHaveLength(1);
    });
    const list = (await t.query(api.matches.listForRoom, {
      sessionToken: b.token,
      roomId,
      viewerUserId: b.userId,
    })) as any[];
    expect(list.map((x) => x.id)).toEqual([matchId]);
    await play(t, b, matchId, "0");
    const m = await read(t, a, matchId);
    expect(m.status).toBe("active");
    expect(m.seq).toBe(2);
    // The orphan sweep leaves it alone too: its room is its anchor.
    const swept: any = await t.mutation(internal.matches._purgeOrphanMatches, {
      table: "matches",
      paginationOpts: { numItems: 50, cursor: null },
    });
    expect(swept.removed).toBe(0);
    expect(await read(t, a, matchId)).not.toBeNull();
  });

  test("an unanswered first move times out like any other", async () => {
    const t = convexTest(schema);
    const a = await signUp(t, "ada");
    const b = await signUp(t, "bob");
    const roomId = await dm(t, a, b);
    const { matchId } = await startTurns(t, a, roomId, "chess", "e2e4", "mv-1");
    vi.advanceTimersByTime(ASYNC_EXPIRE_MS + 1000);
    await t.finishInProgressScheduledFunctions();
    const done = await read(t, a, matchId);
    expect(done.status).toBe("finished");
    expect(done.winner).toBe(0);
    expect(done.reason).toBe("timeout");
  });

  test("a rematch is card-less too, and whoever asks moves first", async () => {
    const t = convexTest(schema);
    const a = await signUp(t, "ada");
    const b = await signUp(t, "bob");
    const roomId = await dm(t, a, b);
    const { matchId } = await startTurns(t, a, roomId, "tictactoe", "4", "mv-1");
    await expect(
      startTurns(t, b, roomId, "tictactoe", "0", "mv-early", matchId),
    ).rejects.toThrow("NOT_FINISHED");
    await t.mutation(api.matches.resign, { ...as(b), matchId });
    const again = await startTurns(t, b, roomId, "tictactoe", "0", "mv-r", matchId);
    const m = await read(t, a, again.matchId);
    expect(m.seats.map((s: any) => s.name)).toEqual(["bob", "ada"]);
    expect(m.turnSeat).toBe(1);
    const { messages } = await rowsOf(t);
    expect(messages.filter((x: any) => x.type === "game")).toHaveLength(0);
  });

  test("wiping the room erases it", async () => {
    const t = convexTest(schema);
    const a = await signUp(t, "ada");
    const b = await signUp(t, "bob");
    const roomId = await dm(t, a, b);
    const { matchId } = await startTurns(t, a, roomId, "tictactoe", "4", "mv-1");
    await t.run(async (ctx) => {
      const { purgeMatchesForRoom } = await import("./matchCore");
      await purgeMatchesForRoom(ctx, roomId);
      expect(await ctx.db.get(matchId)).toBeNull();
      expect(await ctx.db.query("matchMoves").collect()).toHaveLength(0);
    });
  });
});

describe("the room around it", () => {
  test("outsiders cannot read, move or ask for a seat", async () => {
    const t = convexTest(schema);
    const { matchId } = await liveGame(t);
    const z = await signUp(t, "zed");
    expect(await read(t, z, matchId)).toBeNull();
    await expect(play(t, z, matchId, "0")).rejects.toThrow();
    await expect(
      t.mutation(api.matches.requestSeat, { ...as(z), matchId, seat: 0 }),
    ).rejects.toThrow();
  });

  test("leaving the room forfeits your seat", async () => {
    const t = convexTest(schema);
    const { a, b, roomId, matchId } = await liveGame(t);
    await t.mutation(api.rooms.leave, { ...as(b), roomId });
    const m = await read(t, a, matchId);
    expect(m.status).toBe("finished");
    expect(m.winner).toBe(0);
    expect(m.reason).toBe("left");
  });

  test("deleting the card takes the game and its history", async () => {
    const t = convexTest(schema);
    const a = await signUp(t, "ada");
    const b = await signUp(t, "bob");
    const roomId = await dm(t, a, b);
    const { matchId, messageId } = await create(t, a, roomId, "tictactoe", "async");
    await play(t, a, matchId, "4");
    await play(t, b, matchId, "0");
    await t.mutation(api.messages.send, {
      ...as(b),
      roomId,
      content: "good game so far",
    });
    await t.mutation(api.messages.deleteMessage, { ...as(a), messageId });
    await t.run(async (ctx) => {
      expect(await ctx.db.get(matchId)).toBeNull();
      expect(await ctx.db.query("matchMoves").collect()).toHaveLength(0);
      // Both players' move bubbles go with the card; the chat stays.
      const left = await ctx.db.query("messages").collect();
      expect(left.map((m: any) => m.type)).toEqual(["text"]);
      const room = (await ctx.db.get(roomId)) as any;
      expect(room.lastMessage).toBe("good game so far");
    });
  });

  test("deleting a live card in a group leaves no game, child row or banner entry", async () => {
    const t = convexTest(schema);
    const a = await signUp(t, "ada");
    const b = await signUp(t, "bob");
    const c = await signUp(t, "cem");
    const roomId = await group(t, a, b, c);
    // A party game, so the hidden-state table has a row to lose too.
    const { matchId, messageId } = await create(t, a, roomId, "liarsdice", "live");
    await t.mutation(api.matches.join, { ...as(b), matchId });
    await t.mutation(api.matches.setReady, { ...as(a), matchId, ready: true });
    await t.mutation(api.matches.setReady, { ...as(b), matchId, ready: true });
    await t.mutation(api.matches.beat, { ...as(c), matchId });
    await t.run(async (ctx) => {
      expect(await ctx.db.query("matchHidden").collect()).toHaveLength(1);
      expect(
        (await ctx.db.query("matchPresence").collect()).length,
      ).toBeGreaterThan(0);
    });

    await t.mutation(api.messages.deleteMessage, { ...as(a), messageId });

    const gone = async () =>
      await t.run(async (ctx) => {
        expect(await ctx.db.get(matchId)).toBeNull();
        expect(await ctx.db.query("matches").collect()).toHaveLength(0);
        expect(await ctx.db.query("matchMoves").collect()).toHaveLength(0);
        expect(await ctx.db.query("matchPresence").collect()).toHaveLength(0);
        expect(await ctx.db.query("matchHidden").collect()).toHaveLength(0);
      });
    await gone();
    for (const who of [a, b, c]) {
      expect(
        await t.query(api.matches.listForRoom, {
          sessionToken: who.token,
          roomId,
          viewerUserId: who.userId,
        }),
      ).toEqual([]);
      expect(await read(t, who, matchId)).toBeNull();
    }
    // A stale screen's heartbeat cannot bring a presence row back, and every
    // timer the game had armed wakes to nothing and re-arms nothing.
    await expect(
      t.mutation(api.matches.beat, { ...as(b), matchId }),
    ).rejects.toThrow(/NO_MATCH/);
    await advance(t, LIVE_GRACE_MS * 3, matchId);
    await gone();
    // The room is free for a new live game.
    await create(t, b, roomId, "tictactoe", "live");
  });

  test("a card that expires takes its game the same way", async () => {
    const t = convexTest(schema);
    const { matchId, a, roomId } = await liveGame(t);
    const m = await read(t, a, matchId);
    await t.mutation(internal.messages.expireMessage, {
      messageId: m.messageId,
    });
    await t.run(async (ctx) => {
      expect(await ctx.db.get(matchId)).toBeNull();
      expect(await ctx.db.query("matchPresence").collect()).toHaveLength(0);
    });
    expect(
      await t.query(api.matches.listForRoom, {
        sessionToken: a.token,
        roomId,
        viewerUserId: a.userId,
      }),
    ).toEqual([]);
  });

  test("deleting the account that sent the card takes the game", async () => {
    const t = convexTest(schema);
    const a = await signUp(t, "ada");
    const b = await signUp(t, "bob");
    const c = await signUp(t, "cem");
    const roomId = await group(t, a, b, c);
    const { matchId } = await create(t, a, roomId, "connectfour", "live");
    await t.mutation(api.matches.join, { ...as(b), matchId });
    await t.mutation(api.matches.join, { ...as(c), matchId }).catch(() => {});
    await t.mutation(api.auth.deleteAccount, {
      sessionToken: a.token,
      userId: a.userId,
    });
    // Before: the creator's seat was vacated, the lobby stayed open for the
    // others, and its card was gone — a banner entry that could not open.
    await t.run(async (ctx) => {
      expect(await ctx.db.get(matchId)).toBeNull();
      expect(await ctx.db.query("matchPresence").collect()).toHaveLength(0);
    });
    expect(
      await t.query(api.matches.listForRoom, {
        sessionToken: b.token,
        roomId,
        viewerUserId: b.userId,
      }),
    ).toEqual([]);
  });

  test("no game starts in a room whose messages self-destruct", async () => {
    const t = convexTest(schema);
    const a = await signUp(t, "ada");
    const b = await signUp(t, "bob");
    const roomId = await t.mutation(api.rooms.create, {
      sessionToken: a.token,
      userId: a.userId,
      name: "the chamber",
      isPrivate: false,
      messageLifetime: 10,
    });
    await t.mutation(api.rooms.join, { ...as(b), roomId });
    await expect(
      create(t, a, roomId, "tictactoe", "live"),
    ).rejects.toThrow(/EPHEMERAL_ROOM/);
    await t.run(async (ctx) => {
      expect(await ctx.db.query("matches").collect()).toHaveLength(0);
      // Refused before the card is sent, not after.
      const msgs = await ctx.db.query("messages").collect();
      expect(msgs.filter((m: any) => m.type === "game")).toHaveLength(0);
    });
  });

  test("the orphan sweep erases a card-less game and nothing live", async () => {
    const t = convexTest(schema);
    const { matchId: live } = await liveGame(t);
    const orphan = await t.run(async (ctx) => {
      const m = (await ctx.db.get(live)) as any;
      const card = await ctx.db.insert("messages", {
        ...(await ctx.db.get(m.messageId) as any),
        _id: undefined,
        _creationTime: undefined,
      } as any);
      const id = await ctx.db.insert("matches", {
        ...m,
        _id: undefined,
        _creationTime: undefined,
        messageId: card,
        status: "finished",
      } as any);
      await ctx.db.insert("matchPresence", {
        matchId: id,
        userId: m.createdBy,
        lastBeatAt: 0,
      });
      await ctx.db.delete(card);
      return id;
    });
    // Paged: one row a call.
    const sweep = async (table: any, dryRun?: boolean) => {
      let removed = 0;
      let cursor: string | null = null;
      for (;;) {
        const r: any = await t.mutation(internal.matches._purgeOrphanMatches, {
          table,
          paginationOpts: { numItems: 1, cursor },
          dryRun,
        });
        removed += r.removed;
        if (r.isDone) return removed;
        cursor = r.continueCursor;
      }
    };
    expect(await sweep("matches", true)).toBe(1);
    expect(await sweep("matches")).toBe(1);
    expect(await sweep("matchPresence")).toBe(0);
    await t.run(async (ctx) => {
      expect(await ctx.db.get(orphan)).toBeNull();
      expect(await ctx.db.get(live)).not.toBeNull();
    });
  });

  test("never writes a daily game's tables", async () => {
    const t = convexTest(schema);
    const { a, b, matchId } = await liveGame(t);
    for (const [who, cell] of [
      [a, "0"],
      [b, "3"],
      [a, "1"],
      [b, "4"],
      [a, "2"],
    ] as const) {
      await play(t, who, matchId, cell);
    }
    await t.run(async (ctx) => {
      expect(await ctx.db.query("gameResults").collect()).toHaveLength(0);
      expect(await ctx.db.query("gameRecords").collect()).toHaveLength(0);
    });
  });

  test("the card shows in the room's list, for members only", async () => {
    const t = convexTest(schema);
    const { a, roomId, matchId } = await liveGame(t);
    const rows = (await t.query(api.matches.listForRoom, {
      sessionToken: a.token,
      roomId,
      viewerUserId: a.userId,
    })) as any[];
    expect(rows.map((r) => r.id)).toEqual([matchId]);
    const z = await signUp(t, "zed");
    expect(
      await t.query(api.matches.listForRoom, {
        sessionToken: z.token,
        roomId,
        viewerUserId: z.userId,
      }),
    ).toEqual([]);
  });
});

describe("push copy", () => {
  test("every locale has every line, with no em dash", () => {
    const keys = Object.keys(MATCH_COPY_TABLE.en);
    for (const [locale, copy] of Object.entries(MATCH_COPY_TABLE)) {
      expect(Object.keys(copy).sort(), locale).toEqual([...keys].sort());
      expect(Object.keys(copy.names).sort(), locale).toEqual(
        Object.keys(MATCH_COPY_TABLE.en.names).sort(),
      );
      expect(JSON.stringify(copy), locale).not.toContain("—");
    }
    expect(matchLine("tr-TR", "yourMove", "connectfour", "Ada")).toBe(
      "Ada hamlesini yaptı. Dörtlü oyununda sıra sende.",
    );
  });
});
