import { mutation, query } from "./functions";
import {
  internalAction,
  internalMutation,
  internalQuery,
} from "./_generated/server";
import { internal } from "./_generated/api";
import { v } from "convex/values";
import { sendCore } from "./messages";
import { assertMember, getRoomOrThrow, isGroupRoom } from "./roomAdmin";
import { rulesFor } from "./turnGames/registry";
import { partyRulesFor } from "./partyGames/registry";
import type { PartyOptions } from "./partyGames/types";
import { randomFor } from "./games/rng";
import {
  autoplayOut,
  commitParty,
  commitState,
  finishMatch,
  forfeitSeat,
  isOpen,
  loadHidden,
  OPEN_STATUSES,
} from "./matchCore";
import { matchLine, type MatchCopyKey } from "./matchCopy";

/**
 * IN-CHAT GAMES — tic-tac-toe in a DM, Connect Four in a group with the rest
 * of the room watching.
 *
 * Two ways to play, and the difference is who is at the table:
 *
 *  * **live** — everyone has the board open at once. A lobby fills, everyone
 *    taps ready, and the game starts. Leaving the screen or the app pauses it
 *    for [LIVE_GRACE_MS]; whoever is still gone then forfeits. One live game
 *    per room at a time, DM or group.
 *  * **async** — a DM game played a move at a time. Each move tells the other
 *    player with a push; they have [ASYNC_EXPIRE_MS] to answer, with a
 *    reminder at [ASYNC_REMIND_MS] and a manual nudge at most every
 *    [NUDGE_EVERY_MS]. At most [MAX_ASYNC_PER_DM] at once per DM.
 *
 * Solo games against a bot never reach this file: the bot runs on the phone,
 * and there is nothing for a server to referee.
 *
 * Nothing here touches the daily games' tables. A chat game is for fun — no
 * standings, no record, no streak — and that is the schema's doing, not a
 * promise in a comment: there is simply no path from a `matches` row to
 * `gameResults`.
 *
 * ## Invariants every mutation keeps
 *
 *  1. `state` changes only through the game's own `apply`
 *     (`turnGames/registry.ts`), and `seq` counts exactly the moves in
 *     `matchMoves`.
 *  2. A move names the `seq` it was made against. A stale one is refused
 *     (`STALE`) rather than reapplied to a board its author never saw; a resent
 *     one, recognised by its `clientMoveId`, is answered as the success it was.
 *     The native client resends mutations after a reconnect however long ago
 *     this side gave up on them, so both halves matter.
 *  3. Every caller is re-checked as a member of the room, every time.
 *  4. Every scheduled job is fenced: on `seq` for an async deadline, on
 *     `pauseEpoch` for a live grace period. A job that wakes up to a game
 *     that has moved on does nothing, so nothing ever needs cancelling.
 *  5. A finished or abandoned game is inert. Every mutation that changes
 *     a game checks its status first.
 *
 * Convex mutations are serializable transactions, so "read the room's open
 * games, then insert" cannot race into two live games: one of two concurrent
 * creates commits, and the other retries, sees it, and is refused.
 *
 * ## Party games
 *
 * Liar's Dice, Imposter and Puzzle Race (`partyGames/*`) sit at the same
 * table: the same row, lobby, ready taps, heartbeats, pause, grace, seat swap,
 * rematch and teardown. Live only. Three things differ, and each extends an
 * invariant above rather than relaxing it:
 *
 *  1. **Secrets.** The full state is in `matchHidden`, which no public query
 *     reads; `matches.state` is the rules' `publicView` (secrets revealed only
 *     once the game is over), and a player sees their own dice or card only
 *     through [mySecret]. Both are written together, by `commitParty`, and by
 *     nothing else.
 *  2. **A phase fence.** People act at the same time (a vote, a race), so a
 *     strict `seq` fence would make every simultaneous action but the first
 *     `STALE`. An action is stale instead when the PHASE has moved on since
 *     the `seq` it names: `phaseSeq` is the `seq` the current phase began at
 *     (`PartyRules.phaseKey`). A turn-based phase keys on the turn, so there
 *     the fence is exactly as strict as a turn game's. Idempotency on
 *     `clientActionId` is unchanged.
 *  3. **The server's clock.** Phase timers are absolute timestamps in the
 *     state. Every change schedules a [partyTick] at the new deadline, fenced
 *     on `seq` AND re-checked against the deadline when it fires, so a tick
 *     from before a pause (whose deadline has since moved) does nothing. A
 *     pause freezes the clock at `pausedAt` (`partyNow`); a resume shifts
 *     every timer by the time lost and arms a fresh tick. A tick that acts is
 *     a move: it is recorded in `matchMoves` and bumps `seq`, like a forfeit.
 *
 * A seat with nothing left to do (`done`: out of dice, finished the race) is
 * never marked away, so a player who closes the app after finishing does not
 * pause everybody else. Live party games send no pushes at all.
 */

// ── Limits ──────────────────────────────────────────────────────────────────

export const MAX_ASYNC_PER_DM = 3;
export const ASYNC_REMIND_MS = 20 * 60 * 60 * 1000;
export const ASYNC_EXPIRE_MS = 48 * 60 * 60 * 1000;
export const NUDGE_EVERY_MS = 12 * 60 * 60 * 1000;
export const LIVE_GRACE_MS = 2 * 60 * 1000;
/** A heartbeat older than this is a player who is not at the board. */
export const BEAT_FRESH_MS = 25_000;
/** How often the liveness job looks at a live game. */
export const LIVENESS_EVERY_MS = 15_000;
/** A lobby nobody has had open for this long closes. */
export const LOBBY_IDLE_MS = 90_000;
/** How long a seat request stands before somebody else may ask instead. */
export const SEAT_REQUEST_TTL_MS = 60_000;
/** Finished games the room's list carries, for their cards. */
const FINISHED_IN_LIST = 30;

const MAX_MOVE_LEN = 64;
/** Room for a Puzzle Race solution: 36 cell indices as JSON. */
const MAX_ACTION_LEN = 512;
const MAX_CLIENT_ID_LEN = 64;

/** The card's text — the transcript line an old client shows. */
const GAME_TITLES: Record<string, string> = {
  tictactoe: "Tic-tac-toe",
  connectfour: "Connect Four",
  reversi: "Reversi",
  checkers: "Checkers",
  dots: "Dots and Boxes",
  chess: "Chess",
  liarsdice: "Liar's Dice",
  imposter: "Imposter",
  race: "Puzzle Race",
};

/** Seat limits for a game of either kind, or null for an unknown game. */
function seatLimits(game: string): { minSeats: number; maxSeats: number } | null {
  return rulesFor(game) ?? partyRulesFor(game);
}

// ── Helpers ─────────────────────────────────────────────────────────────────

async function loadMatch(ctx: any, matchId: any) {
  const match = await ctx.db.get(matchId);
  if (!match) throw new Error("NO_MATCH");
  return match;
}

function seatOf(match: any, userId: any): number {
  return match.seats.findIndex((s: any) => s.userId === userId);
}

function nameOf(user: any): string {
  return (user?.name ?? user?.username ?? "").slice(0, 60);
}

/** The other member of a DM, or null for a group or Saved Messages. */
async function dmPartner(ctx: any, room: any, userId: any) {
  if (isGroupRoom(room) || room.name.startsWith("dm:self:")) return null;
  const members = await ctx.db
    .query("roomMembers")
    .withIndex("by_room_user", (q: any) => q.eq("roomId", room._id))
    .take(3);
  const others = members.filter((m: any) => m.userId !== userId);
  return others.length === 1 ? others[0].userId : null;
}

async function openMatches(ctx: any, roomId: any) {
  const out: any[] = [];
  for (const status of OPEN_STATUSES) {
    out.push(
      ...(await ctx.db
        .query("matches")
        .withIndex("by_room_status", (q: any) =>
          q.eq("roomId", roomId).eq("status", status),
        )
        .collect()),
    );
  }
  return out;
}

/** Arms an async turn's reminder and deadline, both fenced on [seq]. */
async function armAsyncTurn(ctx: any, matchId: any, seq: number) {
  const now = Date.now();
  await ctx.scheduler.runAfter(ASYNC_REMIND_MS, internal.matches.asyncRemind, {
    matchId,
    seq,
  });
  await ctx.scheduler.runAfter(ASYNC_EXPIRE_MS, internal.matches.asyncExpire, {
    matchId,
    seq,
  });
  await ctx.db.patch(matchId, { deadlineAt: now + ASYNC_EXPIRE_MS });
}

/** Queues one push about [matchId] to [toUserId]. Never awaited by a player. */
async function pushAbout(
  ctx: any,
  matchId: any,
  toUserId: any,
  fromUserId: any,
  key: MatchCopyKey,
) {
  if (!toUserId || toUserId === fromUserId) return;
  await ctx.scheduler.runAfter(0, internal.matches.sendMatchPush, {
    matchId,
    toUserId,
    fromUserId,
    key,
  });
}

/** What every reader gets: the row minus nothing secret (there is nothing). */
function view(match: any) {
  return {
    id: match._id,
    roomId: match.roomId,
    messageId: match.messageId,
    game: match.game,
    mode: match.mode,
    status: match.status,
    seats: match.seats,
    state: match.state,
    seq: match.seq,
    turnSeat: match.turnSeat,
    lastMove: match.lastMove,
    createdBy: match.createdBy,
    createdAt: match.createdAt,
    startedAt: match.startedAt,
    lastMoveAt: match.lastMoveAt,
    finishedAt: match.finishedAt,
    deadlineAt: match.deadlineAt,
    nudgedAt: match.nudgedAt,
    watching: match.watching ?? 0,
    seatRequest: match.seatRequest,
    drawOffer: match.drawOffer,
    winner: match.winner,
    winners: match.winners,
    draw: match.draw === true,
    reason: match.reason,
    // Party games only. `state` is then the public view's JSON.
    party: partyRulesFor(match.game) !== null,
    options: match.options ? JSON.parse(match.options) : undefined,
    phaseSeq: match.phaseSeq,
    pausedAt: match.pausedAt,
  };
}

/**
 * Starts a game in [room] with [seats] already chosen. Shared by [create] and
 * [rematch], so a rematch can never dodge an invariant a first game obeys.
 */
async function startMatch(
  ctx: any,
  args: {
    room: any;
    userId: any;
    game: string;
    mode: "live" | "async";
    seats: { userId: any; name: string }[];
    senderName?: string;
    clientId?: string;
    /** Party games: validated options, as JSON. */
    options?: string;
  },
) {
  const { room, userId, game, mode, seats, senderName, clientId, options } =
    args;
  const rules = seatLimits(game);
  if (!rules) throw new Error("UNKNOWN_GAME");
  const party = partyRulesFor(game) !== null;
  if (party && mode !== "live") throw new Error("LIVE_ONLY");

  const open = await openMatches(ctx, room._id);
  if (mode === "live") {
    if (open.some((m) => m.mode === "live")) throw new Error("ALREADY_LIVE");
  } else {
    const active = open.filter((m) => m.mode === "async").length;
    if (active >= MAX_ASYNC_PER_DM) throw new Error("TOO_MANY_GAMES");
  }
  if (mode === "async" && seats.length !== rules.minSeats) {
    throw new Error("BAD_SEATS");
  }
  if (seats.length > rules.maxSeats) throw new Error("BAD_SEATS");

  // The card first: `sendCore` is the guard (membership, a block, a child's
  // policy), the room preview, and — for the other members — the invite push.
  const messageId = await sendCore(ctx, {
    roomId: room._id,
    userId,
    content: GAME_TITLES[game] ?? game,
    type: "game",
    senderName,
    clientId,
  });
  const existing = await ctx.db
    .query("matches")
    .withIndex("by_message", (q: any) => q.eq("messageId", messageId))
    .first();
  if (existing) return existing;

  const now = Date.now();
  const base = {
    roomId: room._id,
    messageId,
    game,
    mode,
    createdBy: userId,
    createdAt: now,
    lastMoveAt: now,
    seq: 0,
  };
  if (mode === "async") {
    const turn = rulesFor(game)!;
    const state = turn.initial(seats.length);
    const turnSeat = turn.toMove(state);
    const matchId = await ctx.db.insert("matches", {
      ...base,
      status: "active",
      seats: seats.map((s) => ({ userId: s.userId, name: s.name })),
      state: turn.encode(state),
      startedAt: now,
      turnSeat,
      turnUserId: seats[turnSeat].userId,
    });
    await armAsyncTurn(ctx, matchId, 0);
    if (seats[turnSeat].userId !== userId) {
      await pushAbout(ctx, matchId, seats[turnSeat].userId, userId, "yourMove");
    }
    return await ctx.db.get(matchId);
  }
  const matchId = await ctx.db.insert("matches", {
    ...base,
    status: "lobby",
    seats: seats.map((s) => ({ userId: s.userId, name: s.name, ready: false })),
    ...(party ? { options: options ?? "{}" } : {}),
  });
  // The creator is at the board the moment they send it.
  await ctx.db.insert("matchPresence", { matchId, userId, lastBeatAt: now });
  await ctx.scheduler.runAfter(LIVENESS_EVERY_MS, internal.matches.liveness, {
    matchId,
  });
  return await ctx.db.get(matchId);
}

function cleanId(id: string | undefined): string | undefined {
  if (id === undefined) return undefined;
  if (id.length === 0 || id.length > MAX_CLIENT_ID_LEN) {
    throw new Error("BAD_ARGS");
  }
  return id;
}

// ── Creating ────────────────────────────────────────────────────────────────

/**
 * Starts a game in a room. Live: a lobby with the creator in seat one. Async
 * (DMs only): both players seated and the game already under way.
 *
 * Idempotent on [clientId]: a resend returns the game the first send made,
 * rather than tripping its own "already live" check.
 */
export const create = mutation({
  args: {
    roomId: v.id("rooms"),
    userId: v.id("users"),
    game: v.string(),
    mode: v.string(),
    clientId: v.optional(v.string()),
    senderName: v.optional(v.string()),
    // Party games only, ignored by the others: Imposter's `voice`, Puzzle
    // Race's `puzzle` (queens | tango | sudoku | zip; absent is random).
    options: v.optional(
      v.object({
        voice: v.optional(v.boolean()),
        puzzle: v.optional(v.string()),
      }),
    ),
  },
  handler: async (
    ctx,
    { roomId, userId, game, mode, clientId, senderName, options },
  ) => {
    if (mode !== "live" && mode !== "async") throw new Error("BAD_MODE");
    const id = cleanId(clientId);
    if (!seatLimits(game)) throw new Error("UNKNOWN_GAME");
    const party = partyRulesFor(game);
    if (party && mode !== "live") throw new Error("LIVE_ONLY");
    const chosen: PartyOptions | undefined = party
      ? party.parseOptions(options ?? {})
      : undefined;
    const room = await getRoomOrThrow(ctx, roomId);
    await assertMember(ctx, roomId, userId);

    if (id !== undefined) {
      const sent = await ctx.db
        .query("messages")
        .withIndex("by_room_user_client", (q: any) =>
          q.eq("roomId", roomId).eq("userId", userId).eq("clientId", id),
        )
        .first();
      if (sent) {
        const match = await ctx.db
          .query("matches")
          .withIndex("by_message", (q: any) => q.eq("messageId", sent._id))
          .first();
        if (match) return { matchId: match._id, messageId: sent._id };
      }
    }

    if (room.name.startsWith("dm:self:")) throw new Error("NO_OPPONENT");
    const me = await ctx.db.get(userId);
    const seats = [{ userId, name: nameOf(me) }];
    if (mode === "async") {
      const partner = await dmPartner(ctx, room, userId);
      if (!partner) throw new Error("ASYNC_DM_ONLY");
      seats.push({ userId: partner, name: nameOf(await ctx.db.get(partner)) });
    }
    const match = await startMatch(ctx, {
      room,
      userId,
      game,
      mode,
      seats,
      senderName,
      clientId: id,
      options: chosen ? JSON.stringify(chosen) : undefined,
    });
    return { matchId: match._id, messageId: match.messageId };
  },
});

/**
 * Plays again with the same people. Live: a fresh lobby with everyone still
 * in the room already seated (nobody ready). Async: the seats swap, so the
 * player who went second goes first.
 */
export const rematch = mutation({
  args: {
    matchId: v.id("matches"),
    userId: v.id("users"),
    clientId: v.optional(v.string()),
  },
  handler: async (ctx, { matchId, userId, clientId }) => {
    const old = await loadMatch(ctx, matchId);
    if (isOpen(old.status)) throw new Error("NOT_FINISHED");
    if (seatOf(old, userId) < 0) throw new Error("NOT_SEATED");
    const room = await getRoomOrThrow(ctx, old.roomId);
    await assertMember(ctx, old.roomId, userId);
    const id = cleanId(clientId);
    const stillHere: { userId: any; name: string }[] = [];
    for (const s of old.seats) {
      const m = await ctx.db
        .query("roomMembers")
        .withIndex("by_room_user", (q: any) =>
          q.eq("roomId", old.roomId).eq("userId", s.userId),
        )
        .first();
      if (m) stillHere.push({ userId: s.userId, name: s.name });
    }
    const seats = old.mode === "async" ? [...stillHere].reverse() : stillHere;
    const match = await startMatch(ctx, {
      room,
      userId,
      game: old.game,
      mode: old.mode,
      seats,
      clientId: id,
      options: old.options,
    });
    return { matchId: match._id, messageId: match.messageId };
  },
});

// ── The lobby ───────────────────────────────────────────────────────────────

/** Takes an open seat in a live lobby. */
export const join = mutation({
  args: { matchId: v.id("matches"), userId: v.id("users") },
  handler: async (ctx, { matchId, userId }) => {
    const match = await loadMatch(ctx, matchId);
    await assertMember(ctx, match.roomId, userId);
    if (match.status !== "lobby") throw new Error("NOT_IN_LOBBY");
    if (seatOf(match, userId) >= 0) return { seat: seatOf(match, userId) };
    const rules = seatLimits(match.game)!;
    if (match.seats.length >= rules.maxSeats) throw new Error("FULL");
    const me = await ctx.db.get(userId);
    const seats = [
      ...match.seats,
      { userId, name: nameOf(me), ready: false },
    ];
    await ctx.db.patch(matchId, {
      seats,
      // A seat taken while somebody was asking for it answers the question.
      ...(match.seatRequest?.userId === userId
        ? { seatRequest: undefined }
        : {}),
    });
    await beatOnce(ctx, matchId, userId);
    return { seat: seats.length - 1 };
  },
});

/**
 * Gets up from the table. In a lobby the seat is simply vacated, and the last
 * person out closes it. In a game it is a forfeit.
 */
export const leave = mutation({
  args: { matchId: v.id("matches"), userId: v.id("users") },
  handler: async (ctx, { matchId, userId }) => {
    const match = await loadMatch(ctx, matchId);
    const seat = seatOf(match, userId);
    await dropPresence(ctx, matchId, userId);
    if (seat < 0 || !isOpen(match.status)) return null;
    if (match.status === "lobby") {
      const seats = match.seats
        .filter((_: any, i: number) => i !== seat)
        // Somebody left: the table everyone said ready to is not this one.
        .map((s: any) => ({ ...s, ready: false }));
      if (seats.length === 0) {
        await finishMatch(ctx, match, { reason: "abandoned" }, { seats });
      } else {
        await ctx.db.patch(matchId, { seats });
      }
      return null;
    }
    const after = await forfeitSeat(ctx, match, seat, "left");
    await announceEnd(ctx, after, userId);
    return null;
  },
});

/**
 * "I'm ready", or not. When every seat is ready and there are enough of them,
 * the game starts — in the same transaction, so two players tapping ready at
 * once start it exactly once.
 */
export const setReady = mutation({
  args: {
    matchId: v.id("matches"),
    userId: v.id("users"),
    ready: v.boolean(),
  },
  handler: async (ctx, { matchId, userId, ready }) => {
    const match = await loadMatch(ctx, matchId);
    await assertMember(ctx, match.roomId, userId);
    if (match.status !== "lobby") throw new Error("NOT_IN_LOBBY");
    const seat = seatOf(match, userId);
    if (seat < 0) throw new Error("NOT_SEATED");
    const seats = match.seats.map((s: any, i: number) =>
      i === seat ? { ...s, ready, away: undefined } : s,
    );
    const limits = seatLimits(match.game)!;
    const everyone =
      seats.length >= limits.minSeats && seats.every((s: any) => s.ready);
    if (!everyone) {
      await ctx.db.patch(matchId, { seats });
      await beatOnce(ctx, matchId, userId);
      return { started: false };
    }
    const party = partyRulesFor(match.game);
    if (party) {
      await startParty(ctx, match, seats);
      await beatOnce(ctx, matchId, userId);
      return { started: true };
    }
    const rules = rulesFor(match.game)!;
    const state = rules.initial(seats.length);
    const turnSeat = rules.toMove(state);
    const now = Date.now();
    await ctx.db.patch(matchId, {
      seats: seats.map((s: any) => ({
        userId: s.userId,
        name: s.name,
      })),
      status: "active",
      state: rules.encode(state),
      seq: 0,
      startedAt: now,
      lastMoveAt: now,
      turnSeat,
      turnUserId: seats[turnSeat].userId,
      // Asking for a seat in a lobby that just started is moot: the asker
      // can ask again for a seat in the game.
      seatRequest: undefined,
    });
    await beatOnce(ctx, matchId, userId);
    return { started: true };
  },
});

/**
 * Deals a party game: the rules' setup on the match's own seeded stream,
 * written through `commitParty` like every later change, which also arms the
 * first phase's tick.
 */
async function startParty(ctx: any, match: any, seats: any[]) {
  const rules = partyRulesFor(match.game)!;
  const now = Date.now();
  const options: PartyOptions = match.options ? JSON.parse(match.options) : {};
  const state = rules.setup(
    seats.length,
    randomFor(`party:${match._id}`, match.game, 0),
    options,
    now,
    `${match.game}:${match._id}`,
  );
  const started = {
    ...match,
    status: "active",
    seats: seats.map((s: any) => ({ userId: s.userId, name: s.name })),
    phaseSeq: 0,
  };
  await commitParty(ctx, started, rules, state, state, 0, {
    status: "active",
    seats: started.seats,
    startedAt: now,
    seatRequest: undefined,
  });
}

// ── Playing ─────────────────────────────────────────────────────────────────

/**
 * One move. See the header for what [expectedSeq] and [clientMoveId] buy.
 *
 * Returns the `seq` the game now stands at, and `replay` when this was a
 * resend of a move that had already landed.
 */
export const move = mutation({
  args: {
    matchId: v.id("matches"),
    userId: v.id("users"),
    expectedSeq: v.number(),
    move: v.string(),
    clientMoveId: v.optional(v.string()),
  },
  handler: async (ctx, { matchId, userId, expectedSeq, move, clientMoveId }) => {
    if (move.length === 0 || move.length > MAX_MOVE_LEN) {
      throw new Error("BAD_ARGS");
    }
    const id = cleanId(clientMoveId);
    const match = await loadMatch(ctx, matchId);
    if (id !== undefined) {
      const seen = await ctx.db
        .query("matchMoves")
        .withIndex("by_match_client", (q: any) =>
          q.eq("matchId", matchId).eq("clientMoveId", id),
        )
        .first();
      if (seen && seen.userId === userId) {
        return { seq: match.seq, replay: true };
      }
    }
    await assertMember(ctx, match.roomId, userId);
    if (match.status === "paused") throw new Error("PAUSED");
    if (match.status !== "active") throw new Error("NOT_ACTIVE");
    const seat = seatOf(match, userId);
    if (seat < 0 || match.seats[seat].out) throw new Error("NOT_SEATED");
    if (expectedSeq !== match.seq) throw new Error("STALE");

    if (partyRulesFor(match.game)) throw new Error("PARTY_GAME");
    const rules = rulesFor(match.game);
    if (!rules || match.state === undefined) throw new Error("UNKNOWN_GAME");
    const state = rules.decode(match.state);
    if (rules.toMove(state) !== seat) throw new Error("NOT_YOUR_TURN");
    let next;
    try {
      next = rules.apply(state, move);
    } catch {
      throw new Error("ILLEGAL");
    }

    await ctx.db.insert("matchMoves", {
      matchId,
      seq: match.seq,
      seat,
      userId,
      move,
      clientMoveId: id,
      at: Date.now(),
    });
    let after = await commitState(ctx, match, rules, next, match.seq + 1, {
      lastMove: move,
    });
    after = await autoplayOut(ctx, after);

    if (after.status === "finished") {
      await announceEnd(ctx, after, userId);
    } else if (after.mode === "async") {
      await armAsyncTurn(ctx, matchId, after.seq);
      await pushAbout(ctx, matchId, after.turnUserId, userId, "yourMove");
    }
    return { seq: after.seq, replay: false };
  },
});

/**
 * One action in a party game: a bid, a clue, a vote, a finished board (the
 * tokens are documented in each `partyGames/<game>.ts`).
 *
 * [expectedSeq] is the `seq` the client last saw. It is `STALE` when the
 * phase has moved on since (see the header: a vote is not stale because
 * somebody else's vote landed first, a bid against a raised bid is). A resend
 * with the same [clientActionId] is answered as the success it was.
 *
 * Returns the `seq` the game now stands at; `replay` for a resend, and
 * `ignored` for an action the rules accepted but that changed nothing (Puzzle
 * Race's throttled progress), which records nothing and bumps nothing.
 */
export const partyAct = mutation({
  args: {
    matchId: v.id("matches"),
    userId: v.id("users"),
    expectedSeq: v.number(),
    action: v.string(),
    clientActionId: v.optional(v.string()),
  },
  handler: async (
    ctx,
    { matchId, userId, expectedSeq, action, clientActionId },
  ) => {
    if (action.length === 0 || action.length > MAX_ACTION_LEN) {
      throw new Error("BAD_ARGS");
    }
    const id = cleanId(clientActionId);
    const match = await loadMatch(ctx, matchId);
    if (id !== undefined) {
      const seen = await ctx.db
        .query("matchMoves")
        .withIndex("by_match_client", (q: any) =>
          q.eq("matchId", matchId).eq("clientMoveId", id),
        )
        .first();
      if (seen && seen.userId === userId) {
        return { seq: match.seq, replay: true, ignored: false };
      }
    }
    await assertMember(ctx, match.roomId, userId);
    const rules = partyRulesFor(match.game);
    if (!rules) throw new Error("UNKNOWN_GAME");
    if (match.status === "paused") throw new Error("PAUSED");
    if (match.status !== "active") throw new Error("NOT_ACTIVE");
    const seat = seatOf(match, userId);
    if (seat < 0 || match.seats[seat].out) throw new Error("NOT_SEATED");
    if (expectedSeq > match.seq || expectedSeq < (match.phaseSeq ?? 0)) {
      throw new Error("STALE");
    }
    const raw = await loadHidden(ctx, matchId);
    if (raw === null) throw new Error("NOT_ACTIVE");
    const state = rules.decode(raw);
    const now = Date.now();
    // The phase is over even if its tick has not run yet: a bid at 45.2 s or
    // a finish after the race's last second is not taken.
    const deadline = rules.deadline(state);
    if (deadline !== null && now >= deadline) throw new Error("TOO_LATE");
    let next;
    try {
      next = rules.act(state, seat, action, now);
    } catch (e: any) {
      const code = typeof e?.message === "string" ? e.message : "";
      throw new Error(/^[A-Z_]{3,32}$/.test(code) ? code : "ILLEGAL");
    }
    if (next === state) return { seq: match.seq, replay: false, ignored: true };

    await ctx.db.insert("matchMoves", {
      matchId,
      seq: match.seq,
      seat,
      userId,
      move: action,
      clientMoveId: id,
      at: now,
    });
    const after = await commitParty(ctx, match, rules, state, next, match.seq + 1, {
      // Only the KIND of action is public here: a `vote:3` would publish a
      // secret ballot and a `finish:[…]` the race's answer. Whatever the
      // action showed the table is in the public view already.
      lastMove: action.split(":")[0],
    });
    await announceEnd(ctx, after, userId);
    return { seq: after.seq, replay: false, ignored: false };
  },
});

/**
 * A party game's phase timer, scheduled by `commitParty` and on resume.
 *
 * Fenced twice: on [seq] (anything happened since, and this tick is moot;
 * the change armed its own) and on the deadline itself, re-read from the
 * state (a pause moved it later, and the tick armed on resume will come).
 * A paused or finished game is left alone.
 */
export const partyTick = internalMutation({
  args: { matchId: v.id("matches"), seq: v.number() },
  handler: async (ctx, { matchId, seq }) => {
    const match = await ctx.db.get(matchId);
    if (!match || match.status !== "active" || match.seq !== seq) return null;
    const rules = partyRulesFor(match.game);
    if (!rules) return null;
    const raw = await loadHidden(ctx, matchId);
    if (raw === null) return null;
    const state = rules.decode(raw);
    const deadline = rules.deadline(state);
    const now = Date.now();
    if (deadline === null || now < deadline) return null;
    const next = rules.onDeadline(state, now);
    const turn = rules.turnSeat(state);
    await ctx.db.insert("matchMoves", {
      matchId,
      seq,
      seat: turn ?? -1,
      userId: turn === null ? undefined : match.seats[turn]?.userId,
      move: "tick",
      auto: true,
      at: now,
    });
    const after = await commitParty(ctx, match, rules, state, next, seq + 1, {
      lastMove: "tick",
    });
    await announceEnd(ctx, after, undefined);
    return null;
  },
});

/** Concedes. Two players: the other one wins. More: the rest play on. */
export const resign = mutation({
  args: { matchId: v.id("matches"), userId: v.id("users") },
  handler: async (ctx, { matchId, userId }) => {
    const match = await loadMatch(ctx, matchId);
    await assertMember(ctx, match.roomId, userId);
    if (match.status !== "active" && match.status !== "paused") {
      throw new Error("NOT_ACTIVE");
    }
    const seat = seatOf(match, userId);
    if (seat < 0 || match.seats[seat].out) throw new Error("NOT_SEATED");
    const after = await forfeitSeat(ctx, match, seat, "resign");
    await announceEnd(ctx, after, userId);
    return null;
  },
});

/**
 * Offers a draw (two-player games). Bound to the current `seq`, so it dies
 * with the next move. Offering when the other side already offered at this
 * very position is accepting.
 */
export const offerDraw = mutation({
  args: { matchId: v.id("matches"), userId: v.id("users") },
  handler: async (ctx, { matchId, userId }) => {
    const match = await loadMatch(ctx, matchId);
    await assertMember(ctx, match.roomId, userId);
    if (match.status !== "active") throw new Error("NOT_ACTIVE");
    if (match.seats.length !== 2 || partyRulesFor(match.game)) {
      throw new Error("NO_DRAWS");
    }
    const seat = seatOf(match, userId);
    if (seat < 0) throw new Error("NOT_SEATED");
    const offer = match.drawOffer;
    if (offer && offer.seq === match.seq && offer.seat !== seat) {
      await finishMatch(ctx, match, { draw: true, reason: "draw" });
      await announceEnd(ctx, await ctx.db.get(matchId), userId);
      return { drawn: true };
    }
    await ctx.db.patch(matchId, { drawOffer: { seat, seq: match.seq } });
    if (match.mode === "async") {
      await pushAbout(ctx, matchId, match.seats[1 - seat].userId, userId, "nudge");
    }
    return { drawn: false };
  },
});

/** Accepts or declines the standing draw offer. */
export const answerDraw = mutation({
  args: {
    matchId: v.id("matches"),
    userId: v.id("users"),
    accept: v.boolean(),
  },
  handler: async (ctx, { matchId, userId, accept }) => {
    const match = await loadMatch(ctx, matchId);
    await assertMember(ctx, match.roomId, userId);
    if (match.status !== "active") throw new Error("NOT_ACTIVE");
    const seat = seatOf(match, userId);
    const offer = match.drawOffer;
    if (!offer || offer.seq !== match.seq) throw new Error("NO_OFFER");
    if (seat < 0 || offer.seat === seat) throw new Error("NOT_SEATED");
    if (!accept) {
      await ctx.db.patch(matchId, { drawOffer: undefined });
      return { drawn: false };
    }
    await finishMatch(ctx, match, { draw: true, reason: "draw" });
    await announceEnd(ctx, await ctx.db.get(matchId), userId);
    return { drawn: true };
  },
});

// ── Swapping seats ──────────────────────────────────────────────────────────

/**
 * A room member who is watching asks the holder of [seat] to swap places.
 * No admin, no host: the person giving up the seat is the one who decides.
 */
export const requestSeat = mutation({
  args: {
    matchId: v.id("matches"),
    userId: v.id("users"),
    seat: v.number(),
  },
  handler: async (ctx, { matchId, userId, seat }) => {
    const match = await loadMatch(ctx, matchId);
    await assertMember(ctx, match.roomId, userId);
    if (match.mode !== "live" || !isOpen(match.status)) {
      throw new Error("NOT_ACTIVE");
    }
    if (seatOf(match, userId) >= 0) throw new Error("ALREADY_SEATED");
    if (!Number.isInteger(seat) || seat < 0 || seat >= match.seats.length) {
      throw new Error("BAD_ARGS");
    }
    if (match.seats[seat].out) throw new Error("BAD_ARGS");
    const pending = match.seatRequest;
    const now = Date.now();
    if (
      pending &&
      pending.userId !== userId &&
      now - pending.at < SEAT_REQUEST_TTL_MS
    ) {
      throw new Error("REQUEST_PENDING");
    }
    const me = await ctx.db.get(userId);
    await ctx.db.patch(matchId, {
      seatRequest: { userId, name: nameOf(me), seat, at: now },
    });
    await beatOnce(ctx, matchId, userId);
    return null;
  },
});

/** The asker changes their mind. */
export const cancelSeatRequest = mutation({
  args: { matchId: v.id("matches"), userId: v.id("users") },
  handler: async (ctx, { matchId, userId }) => {
    const match = await loadMatch(ctx, matchId);
    if (match.seatRequest?.userId === userId) {
      await ctx.db.patch(matchId, { seatRequest: undefined });
    }
    return null;
  },
});

/**
 * The seat's holder answers. Yes: the asker sits down in that exact seat —
 * mid-game, the position carries on with them — and the holder becomes a
 * spectator.
 */
export const answerSeatRequest = mutation({
  args: {
    matchId: v.id("matches"),
    userId: v.id("users"),
    accept: v.boolean(),
  },
  handler: async (ctx, { matchId, userId, accept }) => {
    const match = await loadMatch(ctx, matchId);
    await assertMember(ctx, match.roomId, userId);
    const req = match.seatRequest;
    if (!req) throw new Error("NO_REQUEST");
    if (match.seats[req.seat]?.userId !== userId) throw new Error("NOT_YOURS");
    if (!accept || !isOpen(match.status)) {
      await ctx.db.patch(matchId, { seatRequest: undefined });
      return { swapped: false };
    }
    // The asker may have left the room, or sat down elsewhere at this table,
    // since asking.
    const stillMember = await ctx.db
      .query("roomMembers")
      .withIndex("by_room_user", (q: any) =>
        q.eq("roomId", match.roomId).eq("userId", req.userId),
      )
      .first();
    if (!stillMember || seatOf(match, req.userId) >= 0) {
      await ctx.db.patch(matchId, { seatRequest: undefined });
      return { swapped: false };
    }
    const seats = match.seats.map((s: any, i: number) =>
      i === req.seat
        ? {
            userId: req.userId,
            name: req.name,
            ...(match.status === "lobby" ? { ready: false } : {}),
          }
        : s,
    );
    await ctx.db.patch(matchId, {
      seats,
      seatRequest: undefined,
      ...(match.turnSeat === req.seat ? { turnUserId: req.userId } : {}),
      // An offer was between the two people who were seated.
      drawOffer: undefined,
    });
    await beatOnce(ctx, matchId, req.userId);
    return { swapped: true };
  },
});

// ── Presence (live games) ───────────────────────────────────────────────────

async function beatOnce(ctx: any, matchId: any, userId: any) {
  const now = Date.now();
  const row = await ctx.db
    .query("matchPresence")
    .withIndex("by_match_user", (q: any) =>
      q.eq("matchId", matchId).eq("userId", userId),
    )
    .first();
  if (row) await ctx.db.patch(row._id, { lastBeatAt: now });
  else await ctx.db.insert("matchPresence", { matchId, userId, lastBeatAt: now });
}

async function dropPresence(ctx: any, matchId: any, userId: any) {
  const row = await ctx.db
    .query("matchPresence")
    .withIndex("by_match_user", (q: any) =>
      q.eq("matchId", matchId).eq("userId", userId),
    )
    .first();
  if (row) await ctx.db.delete(row._id);
}

/**
 * Resumes a paused game if nobody is away any more. A party game's timers
 * move by exactly the time the pause took, and its next tick is armed
 * afresh: the one armed before the pause will wake to a later deadline and
 * do nothing.
 */
async function maybeResume(ctx: any, match: any, seats: any[]) {
  const anyAway = seats.some((s: any) => s.away && !s.out);
  const resuming = match.status === "paused" && !anyAway;
  await ctx.db.patch(match._id, {
    seats,
    ...(resuming ? { status: "active", deadlineAt: undefined } : {}),
  });
  if (resuming) await resumeParty(ctx, { ...match, seats });
}

async function resumeParty(ctx: any, match: any) {
  const rules = partyRulesFor(match.game);
  if (!rules) return;
  const raw = await loadHidden(ctx, match._id);
  const lost = Date.now() - (match.pausedAt ?? Date.now());
  if (raw === null) {
    await ctx.db.patch(match._id, { pausedAt: undefined });
    return;
  }
  const state = rules.shift(rules.decode(raw), Math.max(0, lost));
  await commitParty(ctx, { ...match, status: "active" }, rules, state, state, match.seq, {
    pausedAt: undefined,
  });
}

/** Pauses [match] with [seats] (some now away), arming a fresh grace timer. */
async function pause(ctx: any, match: any, seats: any[]) {
  const epoch = (match.pauseEpoch ?? 0) + 1;
  await ctx.db.patch(match._id, {
    seats,
    status: "paused",
    pauseEpoch: epoch,
    deadlineAt: Date.now() + LIVE_GRACE_MS,
    drawOffer: undefined,
    // A party game's clock stops here (`partyNow`) until the resume.
    ...(partyRulesFor(match.game) ? { pausedAt: Date.now() } : {}),
  });
  await ctx.scheduler.runAfter(LIVE_GRACE_MS, internal.matches.graceExpire, {
    matchId: match._id,
    epoch,
  });
}

/**
 * The board is open on this screen. Sent every few seconds by the game
 * screen and the lobby; writes only `matchPresence`, and the game row only
 * when this beat brings back a player who had been marked away.
 */
export const beat = mutation({
  args: { matchId: v.id("matches"), userId: v.id("users") },
  handler: async (ctx, { matchId, userId }) => {
    const match = await loadMatch(ctx, matchId);
    if (match.mode !== "live" || !isOpen(match.status)) return null;
    await assertMember(ctx, match.roomId, userId);
    await beatOnce(ctx, matchId, userId);
    const seat = seatOf(match, userId);
    if (seat >= 0 && match.seats[seat].away) {
      const seats = match.seats.map((s: any, i: number) =>
        i === seat ? { ...s, away: undefined } : s,
      );
      await maybeResume(ctx, match, seats);
    }
    return null;
  },
});

/**
 * The fast path for "I left": the screen closed or the app went to the
 * background. A player's seat goes away at once rather than when the next
 * liveness pass notices the heartbeat stopped.
 */
export const away = mutation({
  args: { matchId: v.id("matches"), userId: v.id("users") },
  handler: async (ctx, { matchId, userId }) => {
    const match = await loadMatch(ctx, matchId);
    await dropPresence(ctx, matchId, userId);
    if (match.mode !== "live" || !isOpen(match.status)) return null;
    const seat = seatOf(match, userId);
    if (seat < 0) return null;
    if (match.status === "lobby") {
      // Not at the table means not ready to start.
      if (match.seats[seat].ready) {
        const seats = match.seats.map((s: any, i: number) =>
          i === seat ? { ...s, ready: false } : s,
        );
        await ctx.db.patch(matchId, { seats });
      }
      return null;
    }
    const mine = match.seats[seat];
    // A seat with nothing left to do is not holding anybody up.
    if (mine.away || mine.out || mine.done) return null;
    const seats = match.seats.map((s: any, i: number) =>
      i === seat ? { ...s, away: true } : s,
    );
    if (match.status === "paused") await ctx.db.patch(matchId, { seats });
    else await pause(ctx, match, seats);
    return null;
  },
});

/**
 * Every [LIVENESS_EVERY_MS] while a live game is open: marks seated players
 * whose heartbeat stopped as away (pausing the game), recounts who is
 * watching, and closes a lobby nobody has had open for [LOBBY_IDLE_MS].
 * Writes the game row only when something changed.
 */
export const liveness = internalMutation({
  args: { matchId: v.id("matches") },
  handler: async (ctx, { matchId }) => {
    const match = await ctx.db.get(matchId);
    if (!match || match.mode !== "live" || !isOpen(match.status)) return null;
    const now = Date.now();
    const beats = await ctx.db
      .query("matchPresence")
      .withIndex("by_match_user", (q: any) => q.eq("matchId", matchId))
      .collect();
    const fresh = new Set(
      beats
        .filter((b: any) => now - b.lastBeatAt < BEAT_FRESH_MS)
        .map((b: any) => b.userId),
    );
    const seated = new Set(match.seats.map((s: any) => s.userId));
    const watching = [...fresh].filter((u) => !seated.has(u)).length;
    const patch: Record<string, unknown> = {};
    if ((match.watching ?? 0) !== watching) patch.watching = watching;

    if (match.status === "lobby") {
      const lastSeen = Math.max(
        match.createdAt,
        ...beats
          .filter((b: any) => seated.has(b.userId))
          .map((b: any) => b.lastBeatAt),
      );
      if (now - lastSeen > LOBBY_IDLE_MS) {
        await finishMatch(ctx, match, { reason: "abandoned" });
        return null;
      }
      // A seat whose screen is gone is not ready.
      const seats = match.seats.map((s: any) =>
        s.ready && !fresh.has(s.userId) ? { ...s, ready: false } : s,
      );
      if (seats.some((s: any, i: number) => s.ready !== match.seats[i].ready)) {
        patch.seats = seats;
      }
      if (Object.keys(patch).length > 0) await ctx.db.patch(matchId, patch);
    } else {
      const seats = match.seats.map((s: any) =>
        !s.out && !s.away && !s.done && !fresh.has(s.userId)
          ? { ...s, away: true }
          : s,
      );
      const newlyAway = seats.some(
        (s: any, i: number) => s.away && !match.seats[i].away,
      );
      if (newlyAway) {
        if (Object.keys(patch).length > 0) await ctx.db.patch(matchId, patch);
        if (match.status === "paused") await ctx.db.patch(matchId, { seats });
        else await pause(ctx, match, seats);
      } else if (Object.keys(patch).length > 0) {
        await ctx.db.patch(matchId, patch);
      }
    }
    await ctx.scheduler.runAfter(LIVENESS_EVERY_MS, internal.matches.liveness, {
      matchId,
    });
    return null;
  },
});

/**
 * A pause ran out. Everyone still away forfeits; if that was everyone, the
 * game simply ends with no winner.
 */
export const graceExpire = internalMutation({
  args: { matchId: v.id("matches"), epoch: v.number() },
  handler: async (ctx, { matchId, epoch }) => {
    let match = await ctx.db.get(matchId);
    if (!match || match.status !== "paused") return null;
    if ((match.pauseEpoch ?? 0) !== epoch) return null;
    const away = match.seats
      .map((s: any, i: number) => (s.away && !s.out ? i : -1))
      .filter((i: number) => i >= 0);
    if (away.length === match.seats.filter((s: any) => !s.out).length) {
      await finishMatch(ctx, match, { reason: "abandoned" });
      return null;
    }
    for (const seat of away) {
      if (!match || !isOpen(match.status)) break;
      match = await forfeitSeat(ctx, match, seat, "left");
    }
    if (match && isOpen(match.status)) {
      const seats = match.seats.map((s: any) => ({ ...s, away: undefined }));
      await maybeResume(ctx, { ...match, status: "paused" }, seats);
    }
    return null;
  },
});

// ── Async turns ─────────────────────────────────────────────────────────────

/** The waiting player pokes the one whose move it is. */
export const nudge = mutation({
  args: { matchId: v.id("matches"), userId: v.id("users") },
  handler: async (ctx, { matchId, userId }) => {
    const match = await loadMatch(ctx, matchId);
    await assertMember(ctx, match.roomId, userId);
    if (match.mode !== "async" || match.status !== "active") {
      throw new Error("NOT_ACTIVE");
    }
    if (seatOf(match, userId) < 0) throw new Error("NOT_SEATED");
    if (match.turnUserId === userId) throw new Error("YOUR_MOVE");
    const now = Date.now();
    if (
      now - match.lastMoveAt < NUDGE_EVERY_MS ||
      (match.nudgedAt !== undefined && now - match.nudgedAt < NUDGE_EVERY_MS)
    ) {
      throw new Error("TOO_SOON");
    }
    await ctx.db.patch(matchId, { nudgedAt: now });
    await pushAbout(ctx, matchId, match.turnUserId, userId, "nudge");
    return null;
  },
});

export const asyncRemind = internalMutation({
  args: { matchId: v.id("matches"), seq: v.number() },
  handler: async (ctx, { matchId, seq }) => {
    const match = await ctx.db.get(matchId);
    if (!match || match.status !== "active" || match.seq !== seq) return null;
    const other = match.seats.find((s: any) => s.userId !== match.turnUserId);
    await pushAbout(ctx, matchId, match.turnUserId, other?.userId, "reminder");
    return null;
  },
});

export const asyncExpire = internalMutation({
  args: { matchId: v.id("matches"), seq: v.number() },
  handler: async (ctx, { matchId, seq }) => {
    const match = await ctx.db.get(matchId);
    if (!match || match.status !== "active" || match.seq !== seq) return null;
    if (match.turnSeat === undefined) return null;
    const loser = match.seats[match.turnSeat]?.userId;
    const after = await forfeitSeat(ctx, match, match.turnSeat, "timeout");
    await announceEnd(ctx, after, loser);
    return null;
  },
});

// ── Endings and pushes ──────────────────────────────────────────────────────

/**
 * Tells everyone at an async table, except [actorId], how it ended. Live
 * games say nothing: everyone who cares is looking at the board.
 */
async function announceEnd(ctx: any, match: any, actorId: any) {
  if (!match || match.mode !== "async" || isOpen(match.status)) return;
  for (let i = 0; i < match.seats.length; i++) {
    const to = match.seats[i].userId;
    if (to === actorId) continue;
    const key: MatchCopyKey =
      match.draw === true
        ? "draw"
        : match.winner === i
          ? "youWon"
          : "theyWon";
    // The other person: the winner when you lost, the loser when you won.
    const other =
      match.seats.find((s: any) => s.userId !== to)?.userId ?? actorId;
    await pushAbout(ctx, match._id, to, other, key);
  }
}

export const _pushPlan = internalQuery({
  args: {
    matchId: v.id("matches"),
    toUserId: v.id("users"),
    fromUserId: v.optional(v.id("users")),
  },
  returns: v.any(),
  handler: async (ctx, { matchId, toUserId, fromUserId }) => {
    const match = await ctx.db.get(matchId);
    if (!match) return null;
    const member = await ctx.db
      .query("roomMembers")
      .withIndex("by_room_user", (q: any) =>
        q.eq("roomId", match.roomId).eq("userId", toUserId),
      )
      .first();
    if (!member) return null;
    const from = fromUserId
      ? match.seats.find((s: any) => s.userId === fromUserId)?.name ??
        nameOf(await ctx.db.get(fromUserId))
      : "";
    const room = await ctx.db.get(match.roomId);
    const devices = await ctx.db
      .query("userDevices")
      .withIndex("by_user", (q: any) => q.eq("userId", toUserId))
      .take(50);
    const locale = devices
      .filter((d: any) => typeof d.locale === "string" && d.locale)
      .sort((a: any, b: any) => b.lastSeenAt - a.lastSeenAt)[0]?.locale;
    return {
      roomId: match.roomId,
      messageId: match.messageId,
      game: match.game,
      fromName: from,
      isGroup: isGroupRoom(room),
      roomName: isGroupRoom(room) ? room?.name : undefined,
      locale,
    };
  },
});

/**
 * Sends one game push. Through the ordinary message channel with the room
 * attached, so a muted room stays muted and a tap opens the room focused on
 * the game (`focus: game:<id>`) without any new native routing.
 */
export const sendMatchPush = internalAction({
  args: {
    matchId: v.id("matches"),
    toUserId: v.id("users"),
    fromUserId: v.optional(v.id("users")),
    key: v.string(),
  },
  returns: v.null(),
  handler: async (ctx, { matchId, toUserId, fromUserId, key }) => {
    const plan: any = await ctx.runQuery(internal.matches._pushPlan, {
      matchId,
      toUserId,
      fromUserId,
    });
    if (!plan) return null;
    const body = matchLine(plan.locale, key as MatchCopyKey, plan.game, plan.fromName);
    await ctx.runAction(internal.push.sendAlert, {
      userIds: [toUserId],
      kind: "message",
      title: plan.fromName || undefined,
      subtitle: plan.isGroup ? plan.roomName : undefined,
      body,
      data: {
        kind: "message",
        roomId: plan.roomId.toString(),
        ...(plan.messageId ? { messageId: plan.messageId.toString() } : {}),
        ...(fromUserId ? { senderId: fromUserId.toString() } : {}),
        senderName: plan.fromName,
        content: body,
        type: "game",
        mention: "false",
        isGroup: plan.isGroup ? "true" : "false",
        focus: `game:${matchId}`,
        ...(plan.isGroup && plan.roomName ? { roomName: plan.roomName } : {}),
      },
      roomId: plan.roomId,
      // One banner per game: the latest "your move" replaces the last.
      collapseId: `game:${matchId}`,
    });
    return null;
  },
});

// ── Reading ─────────────────────────────────────────────────────────────────

/** One game, for its screen. */
export const get = query({
  identityArg: "viewerUserId" as const,
  args: {
    matchId: v.id("matches"),
    viewerUserId: v.optional(v.id("users")),
  },
  handler: async (ctx, { matchId, viewerUserId }) => {
    const match = await ctx.db.get(matchId);
    if (!match || !viewerUserId) return null;
    const member = await ctx.db
      .query("roomMembers")
      .withIndex("by_room_user", (q: any) =>
        q.eq("roomId", match.roomId).eq("userId", viewerUserId),
      )
      .first();
    if (!member) return null;
    return view(match);
  },
});

/**
 * The caller's own secret in a party game: their dice, their card. The ONLY
 * way anything in `matchHidden` reaches a client, and only ever as the rules'
 * `privateView` for the seat the caller holds.
 *
 * Null for a non-member, a spectator, a turn game, a lobby, or a game whose
 * rules give that seat nothing private (Puzzle Race). `seq` says which state
 * the secret belongs to, so a client can tell a fresh card from a stale one
 * while the public row and this query land in either order. `secret` is JSON.
 *
 * A seat swap hands the seat's secret to its new holder along with the seat,
 * the way it hands over a turn game's position.
 */
export const mySecret = query({
  identityArg: "viewerUserId" as const,
  args: {
    matchId: v.id("matches"),
    viewerUserId: v.optional(v.id("users")),
  },
  handler: async (ctx, { matchId, viewerUserId }) => {
    const match = await ctx.db.get(matchId);
    if (!match || !viewerUserId) return null;
    const rules = partyRulesFor(match.game);
    if (!rules) return null;
    const member = await ctx.db
      .query("roomMembers")
      .withIndex("by_room_user", (q: any) =>
        q.eq("roomId", match.roomId).eq("userId", viewerUserId),
      )
      .first();
    if (!member) return null;
    const seat = seatOf(match, viewerUserId);
    if (seat < 0) return null;
    const raw = await loadHidden(ctx, matchId);
    if (raw === null) return null;
    return {
      seat,
      seq: match.seq,
      secret: rules.privateView(rules.decode(raw), seat),
    };
  },
});

/**
 * A room's games: every open one, and the last [FINISHED_IN_LIST] that ended,
 * for their cards. One subscription per open room, refiring on a move in that
 * room's games and on nothing else.
 */
export const listForRoom = query({
  identityArg: "viewerUserId" as const,
  args: {
    roomId: v.id("rooms"),
    viewerUserId: v.optional(v.id("users")),
  },
  handler: async (ctx, { roomId, viewerUserId }) => {
    if (!viewerUserId) return [];
    const member = await ctx.db
      .query("roomMembers")
      .withIndex("by_room_user", (q: any) =>
        q.eq("roomId", roomId).eq("userId", viewerUserId),
      )
      .first();
    if (!member) return [];
    const rows = await openMatches(ctx, roomId);
    for (const status of ["finished", "abandoned"]) {
      rows.push(
        ...(await ctx.db
          .query("matches")
          .withIndex("by_room_status", (q: any) =>
            q.eq("roomId", roomId).eq("status", status),
          )
          .order("desc")
          .take(FINISHED_IN_LIST)),
      );
    }
    return rows.map(view);
  },
});

/**
 * The rooms where it is the viewer's move in an async game, for the chat
 * list's dot. Indexed on the denormalized `turnUserId`, so it reads only the
 * viewer's own turns.
 */
export const myTurns = query({
  identityArg: "viewerUserId" as const,
  args: { viewerUserId: v.optional(v.id("users")) },
  handler: async (ctx, { viewerUserId }) => {
    if (!viewerUserId) return [];
    const rows = await ctx.db
      .query("matches")
      .withIndex("by_turn_user_status", (q: any) =>
        q.eq("turnUserId", viewerUserId).eq("status", "active"),
      )
      .take(50);
    return rows
      .filter((m: any) => m.mode === "async")
      .map((m: any) => ({ matchId: m._id, roomId: m.roomId, game: m.game }));
  },
});

/**
 * The game behind one card, for a card scrolled back past [listForRoom]'s
 * window. One-shot, like `interactions:stateForMessages`.
 */
export const forMessages = query({
  identityArg: "viewerUserId" as const,
  args: {
    messageIds: v.array(v.id("messages")),
    viewerUserId: v.optional(v.id("users")),
  },
  handler: async (ctx, { messageIds, viewerUserId }) => {
    if (!viewerUserId || messageIds.length > 100) return [];
    const out: any[] = [];
    const allowed = new Map<string, boolean>();
    for (const messageId of messageIds) {
      const match = await ctx.db
        .query("matches")
        .withIndex("by_message", (q: any) => q.eq("messageId", messageId))
        .first();
      if (!match) continue;
      const key = match.roomId as string;
      if (!allowed.has(key)) {
        const m = await ctx.db
          .query("roomMembers")
          .withIndex("by_room_user", (q: any) =>
            q.eq("roomId", match.roomId).eq("userId", viewerUserId),
          )
          .first();
        allowed.set(key, !!m);
      }
      if (allowed.get(key)) out.push(view(match));
    }
    return out;
  },
});
