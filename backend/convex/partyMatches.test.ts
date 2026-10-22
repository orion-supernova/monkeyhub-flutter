import { convexTest } from "convex-test";
import { afterEach, beforeEach, describe, expect, test, vi } from "vitest";
import { api } from "./_generated/api";
import schema from "./schema";
import * as sudoku from "./games/sudoku";
import { TURN_MS } from "./partyGames/liarsDice";
import { CLUE_MS, REVEAL_MS } from "./partyGames/imposter";

/**
 * Party games through `matches.ts`: the promises its header makes for them.
 *
 *   1. Each game runs create → ready → act → finish on the shared lobby.
 *   2. Secrets never reach `get` or `listForRoom`; `mySecret` gives each seat
 *      its own and nobody else anything.
 *   3. The phase fence: a simultaneous action is not stale because another
 *      landed first; a turn-based one is. A resend is a replay.
 *   4. Ticks are fenced: on `seq`, and on a deadline a pause moved.
 *   5. A pause freezes the clock and a resume shifts it by the time lost.
 *   6. Leaving is a forfeit the game's rules understand; a rematch keeps the
 *      options.
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

async function moves(t: T, matchId: any): Promise<any[]> {
  return await t.run(async (ctx: any) =>
    ctx.db
      .query("matchMoves")
      .withIndex("by_match_seq", (q: any) => q.eq("matchId", matchId))
      .collect(),
  );
}

beforeEach(() => {
  vi.useFakeTimers();
});
afterEach(() => {
  vi.useRealTimers();
});

describe("creating", () => {
  test("party games are live only, and their options are checked", async () => {
    const t = convexTest(schema);
    const a = await signUp(t, "ada");
    const b = await signUp(t, "bob");
    const roomId = await group(t, a, b);
    await expect(
      t.mutation(api.matches.create, { ...as(a), roomId, game: "race", mode: "async" }),
    ).rejects.toThrow("LIVE_ONLY");
    await expect(
      t.mutation(api.matches.create, {
        ...as(a),
        roomId,
        game: "race",
        mode: "live",
        options: { puzzle: "chess" },
      }),
    ).rejects.toThrow("BAD_OPTIONS");
    const { matchId } = (await t.mutation(api.matches.create, {
      ...as(a),
      roomId,
      game: "imposter",
      mode: "live",
      options: { voice: true, puzzle: "zip" },
    })) as any;
    const m = await read(t, a, matchId);
    expect(m.status).toBe("lobby");
    expect(m.party).toBe(true);
    expect(m.options).toEqual({ voice: true });
    // Nothing is dealt until it starts.
    expect(await hidden(t, matchId)).toBeNull();
    expect(await secret(t, a, matchId)).toBeNull();
    // The first test in the file pays convex-test's one-off module load
    // (about 3 s alone, more when files run in parallel); not a hang.
  }, 20_000);

  test("not enough seats does not start, a turn-game move is refused", async () => {
    const t = convexTest(schema);
    const a = await signUp(t, "ada");
    const b = await signUp(t, "bob");
    const roomId = await group(t, a, b);
    const { matchId } = (await t.mutation(api.matches.create, {
      ...as(a),
      roomId,
      game: "imposter",
      mode: "live",
    })) as any;
    await t.mutation(api.matches.join, { ...as(b), matchId });
    await t.mutation(api.matches.setReady, { ...as(a), matchId, ready: true });
    const r = await t.mutation(api.matches.setReady, { ...as(b), matchId, ready: true });
    expect(r).toEqual({ started: false });
  });
});

describe("Liar's Dice", () => {
  test("deals, keeps every hand secret, plays, and is won by the last one in", async () => {
    const t = convexTest(schema);
    const { roomId, matchId, players, watcher } = await party(t, "liarsdice", 3);
    const [a, b, c] = players;
    const m = await read(t, a, matchId);
    expect(m.status).toBe("active");
    expect(m.seq).toBe(0);
    const full = await hidden(t, matchId);
    expect(full.dice.map((d: number[]) => d.length)).toEqual([5, 5, 5]);

    // Public reads carry no dice at all.
    const state = await pub(t, watcher, matchId);
    expect(state.dice).toBeUndefined();
    expect(state.counts).toEqual([5, 5, 5]);
    const rows = (await t.query(api.matches.listForRoom, {
      sessionToken: a.token,
      roomId,
      viewerUserId: a.userId,
    })) as any[];
    expect(JSON.parse(rows[0].state).dice).toBeUndefined();
    expect(JSON.stringify(rows)).not.toContain('"seed"');

    // Each seat its own hand; the watcher and an outsider nothing.
    for (let i = 0; i < 3; i++) {
      const mine = await secret(t, players[i], matchId);
      expect(mine.seat).toBe(i);
      expect(JSON.parse(mine.secret).dice).toEqual(
        [...full.dice[i]].sort((x: number, y: number) => x - y),
      );
    }
    expect(await secret(t, watcher, matchId)).toBeNull();
    const zed = await signUp(t, "zed");
    expect(await secret(t, zed, matchId)).toBeNull();

    // A turn, with the denormalized turn seat to find it.
    const first = players[m.turnSeat];
    await expect(act(t, players[(m.turnSeat + 1) % 3], matchId, "bid:1:2")).rejects.toThrow(
      "NOT_YOUR_TURN",
    );
    await act(t, first, matchId, "bid:2:3");
    const next = players[(await read(t, a, matchId)).turnSeat];
    await act(t, next, matchId, "liar");
    const after = await pub(t, a, matchId);
    expect(after.round).toBe(2);
    expect(after.totalDice).toBe(14);
    expect(after.reveal.dice).toEqual(full.dice);

    // Two walk away; the one left wins.
    await t.mutation(api.matches.resign, { ...as(b), matchId });
    await t.mutation(api.matches.leave, { ...as(c), matchId });
    const done = await read(t, a, matchId);
    expect(done.status).toBe("finished");
    expect(done.winner).toBe(0);
    expect(done.winners).toBeUndefined();
    expect(JSON.parse(done.state).phase).toBe("over");
  });

  test("a bid against a raised bid is stale; a resend is a replay", async () => {
    const t = convexTest(schema);
    const { matchId, players } = await party(t, "liarsdice", 2);
    const m = await read(t, players[0], matchId);
    const me = players[m.turnSeat];
    const them = players[1 - m.turnSeat];
    const r1 = await act(t, me, matchId, "bid:1:4", { seq: 0, clientActionId: "x1" });
    expect(r1).toEqual({ seq: 1, replay: false, ignored: false });
    const again = await act(t, me, matchId, "bid:1:4", { seq: 0, clientActionId: "x1" });
    expect(again).toEqual({ seq: 1, replay: true, ignored: false });
    await expect(act(t, them, matchId, "bid:1:5", { seq: 0 })).rejects.toThrow("STALE");
    await expect(act(t, them, matchId, "bid:1:5", { seq: 7 })).rejects.toThrow("STALE");
    await act(t, them, matchId, "bid:1:5", { seq: 1 });
    expect((await moves(t, matchId)).length).toBe(2);
    // Only the kind of action is on the public row.
    expect((await read(t, me, matchId)).lastMove).toBe("bid");
  });

  test("the clock bids for a player who lets it run, fenced on seq", async () => {
    const t = convexTest(schema);
    const { matchId, players } = await party(t, "liarsdice", 2);
    const m = await read(t, players[0], matchId);
    // A move in time: the tick armed at the start finds a later seq.
    await advance(t, 20_000, matchId, players);
    await act(t, players[m.turnSeat], matchId, "bid:1:6");
    await advance(t, TURN_MS - 20_000 + 1000, matchId, players);
    expect((await read(t, players[0], matchId)).seq).toBe(1);
    // Then nobody calls: the clock does, for the player to move.
    await advance(t, 20_000, matchId, players);
    const after = await pub(t, players[0], matchId);
    expect(after.reveal).toMatchObject({ auto: true, caller: 1 - m.turnSeat });
    const log = await moves(t, matchId);
    expect(log.map((x) => x.move)).toEqual(["bid:1:6", "tick"]);
    expect(log[1].auto).toBe(true);
  });

  test("a pause freezes the turn clock, and the resume moves it by the time lost", async () => {
    const t = convexTest(schema);
    const { matchId, players } = await party(t, "liarsdice", 2);
    const [a, b] = players;
    const before = await pub(t, a, matchId);
    const d0 = before.deadline;
    await advance(t, 10_000, matchId, players);
    await t.mutation(api.matches.away, { ...as(b), matchId });
    const paused = await read(t, a, matchId);
    expect(paused.status).toBe("paused");
    const pausedAt = paused.pausedAt;
    expect(typeof pausedAt).toBe("number");
    await expect(act(t, a, matchId, "bid:1:2")).rejects.toThrow("PAUSED");
    // Through the original deadline while paused: nothing happens.
    await advance(t, 60_000, matchId, [a]);
    expect((await read(t, a, matchId)).seq).toBe(0);
    await t.mutation(api.matches.beat, { ...as(b), matchId });
    const resumed = await read(t, a, matchId);
    expect(resumed.status).toBe("active");
    expect(resumed.pausedAt).toBeUndefined();
    const lost = Date.now() - pausedAt;
    const d1 = JSON.parse(resumed.state).deadline;
    expect(d1).toBe(d0 + lost);
    expect(resumed.deadlineAt).toBe(d1);
    expect((await hidden(t, matchId)).deadline).toBe(d1);
    // The tick from before the pause is long gone; the new one fires at d1.
    await advance(t, d1 - Date.now() - 1000, matchId, players);
    expect((await read(t, a, matchId)).seq).toBe(0);
    await advance(t, 2000, matchId, players);
    expect((await read(t, a, matchId)).seq).toBe(1);
    expect((await moves(t, matchId)).map((x) => x.move)).toEqual(["tick"]);
  });

  test("the grace running out is a forfeit, timed at the pause", async () => {
    const t = convexTest(schema);
    const { matchId, players } = await party(t, "liarsdice", 3);
    const [a, b, c] = players;
    await t.mutation(api.matches.away, { ...as(c), matchId });
    await advance(t, 2 * 60_000 + 10_000, matchId, [a, b]);
    const m = await read(t, a, matchId);
    expect(m.status).toBe("active");
    expect(m.seats[2].out).toBe(true);
    const s = JSON.parse(m.state);
    expect(s.left).toEqual([false, false, true]);
    // A fresh round was dealt at the pause, then the clock moved with it:
    // the new turn still has (nearly) all of its time.
    expect(s.deadline - Date.now()).toBeGreaterThan(TURN_MS - 15_000);
    expect(s.deadline - Date.now()).toBeLessThanOrEqual(TURN_MS);
  });

  test("a rematch deals a new game at a new table", async () => {
    const t = convexTest(schema);
    const { matchId, players } = await party(t, "liarsdice", 2);
    await t.mutation(api.matches.resign, { ...as(players[1]), matchId });
    const again = (await t.mutation(api.matches.rematch, {
      ...as(players[1]),
      matchId,
    })) as any;
    const m = await read(t, players[0], again.matchId);
    expect(m.status).toBe("lobby");
    expect(m.game).toBe("liarsdice");
    expect(m.seats.length).toBe(2);
  });
});

describe("Imposter", () => {
  test("plays through, keeps the word and the imposter secret until the end", async () => {
    const t = convexTest(schema);
    const { roomId, matchId, players, watcher } = await party(t, "imposter", 3);
    const full = await hidden(t, matchId);
    const word = full.word;
    const imp = full.imposter;

    const leaks = async () => {
      const one = JSON.stringify(await read(t, watcher, matchId));
      const all = JSON.stringify(
        await t.query(api.matches.listForRoom, {
          sessionToken: watcher.token,
          roomId,
          viewerUserId: watcher.userId,
        }),
      );
      for (const text of [one, all]) {
        expect(text).not.toContain(word.names.en);
        expect(text).not.toContain(word.id);
      }
      expect((await pub(t, watcher, matchId)).imposter).toBeNull();
    };
    await leaks();

    // Cards: the crew gets the word, the imposter the category, the watcher nothing.
    for (let i = 0; i < 3; i++) {
      const card = JSON.parse((await secret(t, players[i], matchId)).secret);
      if (i === imp) {
        expect(card).toMatchObject({ role: "imposter", category: word.category });
        expect(card.names).toBeUndefined();
      } else {
        expect(card).toMatchObject({ role: "crew", wordId: word.id, names: word.names });
      }
    }
    expect(await secret(t, watcher, matchId)).toBeNull();

    // Everyone taps "seen" against the same seq: none of it is stale.
    for (const p of players) await act(t, p, matchId, "seen", { seq: 0 });
    let s = await pub(t, watcher, matchId);
    expect(s.phase).toBe("clues");
    for (let k = 0; k < 3; k++) {
      const turn = (await pub(t, watcher, matchId)).turn;
      await act(t, players[turn], matchId, `clue:hint ${k}`);
    }
    s = await pub(t, watcher, matchId);
    expect(s.phase).toBe("vote");
    expect(s.clues.map((c: any) => c.text)).toEqual(["hint 0", "hint 1", "hint 2"]);
    await leaks();

    // Everyone accuses the imposter (who accuses somebody else).
    const seq = (await read(t, watcher, matchId)).seq;
    for (let i = 0; i < 3; i++) {
      const target = i === imp ? (imp + 1) % 3 : imp;
      await act(t, players[i], matchId, `vote:${target}`, { seq });
    }
    s = await pub(t, watcher, matchId);
    expect(s.phase).toBe("guess");
    expect(s.accused).toBe(imp);
    await act(t, players[imp], matchId, "guess:definitely not it");

    const done = await read(t, watcher, matchId);
    expect(done.status).toBe("finished");
    expect(done.winner).toBeUndefined();
    expect(done.winners).toEqual([0, 1, 2].filter((i) => i !== imp));
    expect(done.reason).toBe("caught");
    const end = JSON.parse(done.state);
    expect(end.imposter).toBe(imp);
    expect(end.word.id).toBe(word.id);
    expect(end.guess).toBe("definitely not it");
  });

  test("the clock moves the phases; a tick the players beat does nothing", async () => {
    const t = convexTest(schema);
    const { matchId, players } = await party(t, "imposter", 3);
    for (const p of players) await act(t, p, matchId, "seen", { seq: 0 });
    expect((await read(t, players[0], matchId)).seq).toBe(3);
    // The reveal's tick (armed at seq 0) comes due and finds seq 3.
    await advance(t, REVEAL_MS + 1000, matchId, players);
    expect((await read(t, players[0], matchId)).seq).toBe(3);
    // Nobody gives a clue: it passes.
    await advance(t, CLUE_MS, matchId, players);
    const s = await pub(t, players[0], matchId);
    expect(s.clues).toEqual([{ seat: s.order[0], text: "(passed)", passed: true }]);
  });

  test("the imposter walking out hands the crew the win", async () => {
    const t = convexTest(schema);
    const { matchId, players } = await party(t, "imposter", 3);
    const imp = (await hidden(t, matchId)).imposter;
    await t.mutation(api.matches.leave, { ...as(players[imp]), matchId });
    const m = await read(t, players[(imp + 1) % 3], matchId);
    expect(m.status).toBe("finished");
    expect(m.reason).toBe("imposterLeft");
    expect(m.winners).toEqual([0, 1, 2].filter((i) => i !== imp));
  });

  test("a rematch keeps voice mode", async () => {
    const t = convexTest(schema);
    const { matchId, players } = await party(t, "imposter", 3, { voice: true });
    expect((await pub(t, players[0], matchId)).voice).toBe(true);
    const imp = (await hidden(t, matchId)).imposter;
    await t.mutation(api.matches.leave, { ...as(players[imp]), matchId });
    const again = (await t.mutation(api.matches.rematch, {
      ...as(players[(imp + 1) % 3]),
      matchId,
    })) as any;
    expect((await read(t, players[0], again.matchId)).options).toEqual({ voice: true });
  });
});

describe("Puzzle Race", () => {
  test("one board for all, progress throttled, ranked finishes, the winner first", async () => {
    const t = convexTest(schema);
    const { matchId, players } = await party(t, "race", 3, { puzzle: "sudoku" });
    const [a, b, c] = players;
    const s = await pub(t, a, matchId);
    expect(s.kind).toBe("sudoku");
    expect(s.puzzle).toEqual(sudoku.generate(`race:${matchId}`));
    expect((await secret(t, a, matchId)).secret).toBeNull();
    const answer = JSON.stringify(sudoku.solve(s.puzzle)!);

    // Simultaneous: both progress reports against seq 0 land.
    expect(await act(t, a, matchId, "progress:30", { seq: 0 })).toMatchObject({ seq: 1 });
    expect(await act(t, b, matchId, "progress:10", { seq: 0 })).toMatchObject({ seq: 2 });
    // Too soon after the last: accepted, dropped.
    expect(await act(t, a, matchId, "progress:40")).toEqual({
      seq: 2,
      replay: false,
      ignored: true,
    });
    await expect(act(t, a, matchId, "finish:[1,2,3]")).rejects.toThrow("NOT_SOLVED");

    await advance(t, 30_000, matchId, players);
    await act(t, b, matchId, `finish:${answer}`);
    await advance(t, 5_000, matchId, players);
    await act(t, a, matchId, `finish:${answer}`);
    let m = await read(t, c, matchId);
    expect(m.status).toBe("active");
    expect(m.lastMove).toBe("finish");
    expect(m.state).not.toContain(answer);
    const mid = JSON.parse(m.state).players;
    expect(mid.map((p: any) => p.rank)).toEqual([2, 1, null]);
    expect(mid[1].durationMs).toBe(30_000);
    expect(mid[0].durationMs).toBe(35_000);
    // A finished racer closing the app holds nobody up.
    expect(m.seats.map((x: any) => x.done === true)).toEqual([true, true, false]);
    await t.mutation(api.matches.away, { ...as(a), matchId });
    expect((await read(t, c, matchId)).status).toBe("active");

    await act(t, c, matchId, `finish:${answer}`);
    m = await read(t, c, matchId);
    expect(m.status).toBe("finished");
    expect(m.winner).toBe(1);
  });

  test("ten minutes is the end", async () => {
    const t = convexTest(schema);
    const { matchId, players } = await party(t, "race", 2, { puzzle: "zip" });
    await advance(t, 10 * 60_000 + 1000, matchId, players);
    const m = await read(t, players[0], matchId);
    expect(m.status).toBe("finished");
    expect(m.draw).toBe(true);
    expect(m.reason).toBe("time");
    await expect(act(t, players[0], matchId, "progress:5")).rejects.toThrow("NOT_ACTIVE");
  });
});
