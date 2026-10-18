import { internal } from "./_generated/api";
import { rulesFor } from "./turnGames/registry";
import { partyRulesFor, type AnyPartyRules } from "./partyGames/registry";

/**
 * The parts of in-chat games that other modules have to reach.
 *
 * Leaving a room, being removed from one, deleting an account, wiping a room
 * and deleting a message all have to end or erase the games that hang off
 * them — and every one of those paths lives in a module `matches.ts` itself
 * imports (it sends its card through `messages.sendCore`). Keeping the
 * teardown here, importing nothing but the two rules registries (and the
 * generated function references, which import nothing at runtime), is what
 * stops that becoming an import cycle; `interactionCore.ts` exists for the
 * same reason.
 *
 * It is also where a party game's state is written ([commitParty]), because a
 * forfeit, which teardown triggers, is one of the things that writes it.
 *
 * Nothing here sends a push or a message. Teardown is quiet.
 */

/** A game still being played or waiting to be: the ones teardown must end. */
export const OPEN_STATUSES = ["lobby", "active", "paused"] as const;

export function isOpen(status: string): boolean {
  return (OPEN_STATUSES as readonly string[]).includes(status);
}

/**
 * Finishes [match] from its current `state`'s outcome, or with the explicit
 * [ending] — a resignation, a timeout, a forfeit. Clears every piece of
 * in-flight state (turn, deadline, offers, requests) so a finished row is
 * inert: nothing scheduled against it, and nothing a late call can act on.
 */
export async function finishMatch(
  ctx: any,
  match: any,
  ending: { winner?: number; winners?: number[]; draw?: boolean; reason: string },
  extra: Record<string, unknown> = {},
) {
  const now = Date.now();
  await ctx.db.patch(match._id, {
    ...extra,
    status: ending.reason === "abandoned" ? "abandoned" : "finished",
    finishedAt: now,
    winner: ending.winner,
    winners:
      ending.winners && ending.winners.length > 0 ? ending.winners : undefined,
    pausedAt: undefined,
    draw: ending.draw === true ? true : undefined,
    reason: ending.reason,
    turnSeat: undefined,
    turnUserId: undefined,
    deadlineAt: undefined,
    drawOffer: undefined,
    takebackOffer: undefined,
    seatRequest: undefined,
  });
}

/**
 * Seats still playing: seated, and not forfeited.
 */
export function liveSeats(match: any): number[] {
  const out: number[] = [];
  for (let i = 0; i < match.seats.length; i++) {
    if (!match.seats[i].out) out.push(i);
  }
  return out;
}

/**
 * Takes [seat] out of an active game.
 *
 * Two players: the other one wins, with [reason]. More than two (Dots and
 * Boxes): the seat is marked out, the others play on, and its turns are
 * played for it by [autoplayOut]; the game ends when one player is left.
 * A party game asks its own rules instead ([forfeitPartySeat]).
 * Returns the row as it now stands so a caller can keep going with it.
 */
export async function forfeitSeat(
  ctx: any,
  match: any,
  seat: number,
  reason: "resign" | "timeout" | "left",
) {
  if (match.status !== "active" && match.status !== "paused") return match;
  const party = partyRulesFor(match.game);
  if (party) return await forfeitPartySeat(ctx, match, seat, reason, party);
  const seats = match.seats.map((s: any, i: number) =>
    i === seat ? { ...s, out: true, away: undefined } : s,
  );
  const remaining = seats
    .map((s: any, i: number) => (s.out ? -1 : i))
    .filter((i: number) => i >= 0);
  if (remaining.length <= 1) {
    await finishMatch(
      ctx,
      match,
      remaining.length === 1
        ? { winner: remaining[0], reason }
        : { reason: "abandoned" },
      { seats },
    );
    return await ctx.db.get(match._id);
  }
  await ctx.db.patch(match._id, { seats });
  const next = { ...match, seats };
  return await autoplayOut(ctx, next);
}

/**
 * While the seat to move has forfeited, plays its first legal move for it.
 *
 * Deliberately the dullest possible move: the point is that the people still
 * at the table can finish their game, not that a departed player keeps
 * scoring. Bounded by the board — every move is irreversible in the games
 * that have more than two seats — and by an explicit cap regardless.
 */
export async function autoplayOut(ctx: any, match: any) {
  const rules = rulesFor(match.game);
  if (!rules || match.state === undefined) return match;
  let state = rules.decode(match.state);
  let seq: number = match.seq;
  let played = 0;
  let last: string | undefined;
  while (played < 400) {
    if (rules.outcome(state)) break;
    const seat = rules.toMove(state);
    if (!match.seats[seat]?.out) break;
    const moves = rules.legalMoves(state);
    if (moves.length === 0) break;
    state = rules.apply(state, moves[0]);
    last = moves[0];
    await ctx.db.insert("matchMoves", {
      matchId: match._id,
      seq,
      seat,
      userId: match.seats[seat].userId,
      move: moves[0],
      auto: true,
      at: Date.now(),
    });
    seq++;
    played++;
  }
  if (played === 0) return match;
  return await commitState(ctx, match, rules, state, seq, { lastMove: last });
}

/**
 * Writes a new position: the state, the move count, whose turn it is — and,
 * if the rules say the game is over, the result. Shared by a player's move
 * and by [autoplayOut] so the two can never disagree about what "over" means.
 */
export async function commitState(
  ctx: any,
  match: any,
  rules: any,
  state: any,
  seq: number,
  extra: Record<string, unknown> = {},
) {
  const now = Date.now();
  const outcome = rules.outcome(state);
  const encoded = rules.encode(state);
  if (outcome) {
    await finishMatch(
      ctx,
      match,
      outcome.winner === null
        ? { draw: true, reason: "draw" }
        : { winner: outcome.winner, reason: "win" },
      { ...extra, state: encoded, seq, lastMoveAt: now },
    );
  } else {
    const turnSeat = rules.toMove(state);
    await ctx.db.patch(match._id, {
      ...extra,
      state: encoded,
      seq,
      lastMoveAt: now,
      turnSeat,
      turnUserId: match.seats[turnSeat]?.userId,
      drawOffer: undefined,
      takebackOffer: undefined,
    });
  }
  return await ctx.db.get(match._id);
}

/**
 * Called when [userId] stops being a member of [roomId] — they left, were
 * removed, or the account is going. Every open game of theirs there ends the
 * way walking away from the table ends it: a lobby seat is simply vacated, a
 * seat in play is forfeited, and a lobby nobody is left in closes.
 */
export async function leaveMatchesInRoom(ctx: any, roomId: any, userId: any) {
  for (const status of OPEN_STATUSES) {
    const rows = await ctx.db
      .query("matches")
      .withIndex("by_room_status", (q: any) =>
        q.eq("roomId", roomId).eq("status", status),
      )
      .collect();
    for (const match of rows) {
      const seat = match.seats.findIndex(
        (s: any) => s.userId === userId,
      );
      if (match.seatRequest?.userId === userId) {
        await ctx.db.patch(match._id, { seatRequest: undefined });
      }
      if (seat < 0) continue;
      if (match.status === "lobby") {
        const seats = match.seats.filter((_: any, i: number) => i !== seat);
        if (seats.length === 0) {
          await finishMatch(ctx, match, { reason: "abandoned" }, { seats });
        } else {
          await ctx.db.patch(match._id, {
            seats: seats.map((s: any) => ({ ...s, ready: undefined })),
          });
        }
      } else {
        await forfeitSeat(ctx, match, seat, "left");
      }
    }
  }
}

// ── Party games ─────────────────────────────────────────────────────────────

/**
 * The clock a party game's rules run on. While paused it is frozen at the
 * moment the pause began, so anything the rules do during a pause (a forfeit
 * when the grace runs out) is timed as if it happened then, and the shift on
 * resume ([PartyRules.shift] by `now - pausedAt`) moves it with everything
 * else. Without this, a turn handed on during a two-minute pause would come
 * back with two minutes too many.
 */
export function partyNow(match: any): number {
  return match.status === "paused" && typeof match.pausedAt === "number"
    ? match.pausedAt
    : Date.now();
}

/** A party game's full state, or null before it starts. Server-side only. */
export async function loadHidden(ctx: any, matchId: any): Promise<string | null> {
  const row = await ctx.db
    .query("matchHidden")
    .withIndex("by_match", (q: any) => q.eq("matchId", matchId))
    .first();
  return row ? row.state : null;
}

async function saveHidden(ctx: any, matchId: any, state: string) {
  const row = await ctx.db
    .query("matchHidden")
    .withIndex("by_match", (q: any) => q.eq("matchId", matchId))
    .first();
  if (row) await ctx.db.patch(row._id, { state });
  else await ctx.db.insert("matchHidden", { matchId, state });
}

/**
 * Schedules the tick that ends the current phase of a party game, fenced on
 * [seq]. Scheduled afresh after every change and on every resume, never
 * cancelled: a tick that wakes to a later `seq`, a pause, or a deadline that
 * moved (`partyTick` re-reads it) does nothing.
 */
export async function armPartyTick(
  ctx: any,
  matchId: any,
  seq: number,
  deadline: number | null,
) {
  if (deadline === null) return;
  await ctx.scheduler.runAt(deadline, internal.matches.partyTick, {
    matchId,
    seq,
  });
}

/**
 * Writes a party game's new state [next] (reached from [prev]) at [seq]: the
 * full state to `matchHidden`, the public view to `matches.state`, the
 * denormalized turn and `done` seats, the phase fence, and either the result
 * or the next tick. The party twin of [commitState], shared by an action, a
 * tick, a forfeit and the start, so none of them can disagree about "over".
 */
export async function commitParty(
  ctx: any,
  match: any,
  rules: AnyPartyRules,
  prev: any,
  next: any,
  seq: number,
  extra: Record<string, unknown> = {},
) {
  const now = Date.now();
  await saveHidden(ctx, match._id, rules.encode(next));
  const done = new Set(rules.doneSeats(next));
  const seats = ((extra.seats as any[]) ?? match.seats).map(
    (s: any, i: number) => ({ ...s, done: done.has(i) ? true : undefined }),
  );
  const phaseSeq =
    rules.phaseKey(next) !== rules.phaseKey(prev) ? seq : (match.phaseSeq ?? 0);
  const fields = {
    ...extra,
    seats,
    state: rules.publicView(next),
    seq,
    phaseSeq,
    lastMoveAt: now,
  };
  const outcome = rules.outcome(next);
  if (outcome) {
    await finishMatch(ctx, match, outcome, fields);
    return await ctx.db.get(match._id);
  }
  const turn = rules.turnSeat(next);
  const deadline = rules.deadline(next);
  const paused = match.status === "paused";
  await ctx.db.patch(match._id, {
    ...fields,
    turnSeat: turn ?? undefined,
    turnUserId: turn === null ? undefined : seats[turn]?.userId,
    // While paused, `deadlineAt` is the grace period's; resume restores ours.
    ...(paused ? {} : { deadlineAt: deadline ?? undefined }),
  });
  if (!paused) await armPartyTick(ctx, match._id, seq, deadline);
  return await ctx.db.get(match._id);
}

/**
 * [forfeitSeat] for a party game: the seat is out at the table, the rules
 * decide what that means for the game (Liar's Dice re-deals without them,
 * Imposter ends if they were the imposter), and the forfeit is recorded as a
 * move so `seq` still counts exactly the rows in `matchMoves`.
 */
async function forfeitPartySeat(
  ctx: any,
  match: any,
  seat: number,
  reason: "resign" | "timeout" | "left",
  rules: AnyPartyRules,
) {
  const seats = match.seats.map((s: any, i: number) =>
    i === seat ? { ...s, out: true, away: undefined } : s,
  );
  const raw = await loadHidden(ctx, match._id);
  let after: any;
  if (raw === null) {
    await ctx.db.patch(match._id, { seats });
    after = await ctx.db.get(match._id);
  } else {
    const prev = rules.decode(raw);
    const next = rules.forfeit(prev, seat, partyNow(match));
    await ctx.db.insert("matchMoves", {
      matchId: match._id,
      seq: match.seq,
      seat,
      userId: match.seats[seat].userId,
      move: `forfeit:${reason}`,
      auto: true,
      at: Date.now(),
    });
    after = await commitParty(ctx, match, rules, prev, next, match.seq + 1, {
      seats,
    });
  }
  // The rules always end a game nobody is left to play; this is the net
  // under them, the same one the turn games have.
  if (after && isOpen(after.status)) {
    const remaining = liveSeats(after);
    if (remaining.length <= 1) {
      await finishMatch(
        ctx,
        after,
        remaining.length === 1
          ? { winner: remaining[0], reason }
          : { reason: "abandoned" },
      );
      after = await ctx.db.get(match._id);
    }
  }
  return after;
}

/**
 * Erases one game and everything hanging off it: its hidden state, its move
 * history and its heartbeats. The ONE teardown every path that removes a game
 * goes through (a deleted or expired card, a wiped room).
 *
 * Seats, the turn, offers and requests live on the row itself, so they go with
 * it. Scheduled jobs (`liveness`, `graceExpire`, `asyncRemind`, `asyncExpire`,
 * `partyTick`, `sendMatchPush`) are not cancelled: every one of them re-reads
 * the row first and does nothing when it is gone, and `liveness`, the only one
 * that re-arms itself, stops re-arming. Cancelling would mean scanning
 * `_scheduled_functions`, which has no index on a job's arguments.
 */
export async function eraseMatch(ctx: any, matchId: any) {
  for (const h of await ctx.db
    .query("matchHidden")
    .withIndex("by_match", (q: any) => q.eq("matchId", matchId))
    .collect()) {
    await ctx.db.delete(h._id);
  }
  for (const m of await ctx.db
    .query("matchMoves")
    .withIndex("by_match_seq", (q: any) => q.eq("matchId", matchId))
    .collect()) {
    await ctx.db.delete(m._id);
  }
  for (const p of await ctx.db
    .query("matchPresence")
    .withIndex("by_match_user", (q: any) => q.eq("matchId", matchId))
    .collect()) {
    await ctx.db.delete(p._id);
  }
  await ctx.db.delete(matchId);
}

/**
 * The game behind a card that is being deleted. Returns its move bubbles'
 * message ids, for the caller (`messages.ts`, which owns message teardown)
 * to remove: a move left behind would open a game that no longer exists.
 *
 * A move bubble is never a card, so deleting one finds nothing here and the
 * game plays on. That matters for a card-less turn by turn game
 * (`matches.startTurns`): its moves are all it has in the transcript, and
 * deleting one must not end it.
 */
export async function purgeMatchForMessage(
  ctx: any,
  messageId: any,
): Promise<any[]> {
  // `eq(undefined)` would match every row whose `messageId` is unset.
  if (!messageId) return [];
  // One game per card by construction; every one found goes regardless, so a
  // second row could never outlive the card it hangs off.
  const rows = await ctx.db
    .query("matches")
    .withIndex("by_message", (q: any) => q.eq("messageId", messageId))
    .take(10);
  const bubbles: any[] = [];
  for (const match of rows) {
    for (const m of await ctx.db
      .query("matchMoves")
      .withIndex("by_match_seq", (q: any) => q.eq("matchId", match._id))
      .collect()) {
      if (m.messageId) bubbles.push(m.messageId);
    }
    await eraseMatch(ctx, match._id);
  }
  return bubbles;
}

/** Every game a room ever held, when the room itself is going. */
export async function purgeMatchesForRoom(ctx: any, roomId: any) {
  const rows = await ctx.db
    .query("matches")
    .withIndex("by_room_status", (q: any) => q.eq("roomId", roomId))
    .collect();
  for (const match of rows) await eraseMatch(ctx, match._id);
}

// ── Challenge cards ("Beat my time", `challenges.ts`) ───────────────────────
//
// Here beside the games' teardown for the same import-cycle reason: the paths
// that delete a message, wipe a room or purge an account all reach this file
// already.

/** The body behind a challenge card that is being deleted. */
export async function purgeChallengeForMessage(ctx: any, messageId: any) {
  const row = await ctx.db
    .query("gameChallenges")
    .withIndex("by_message", (q: any) => q.eq("messageId", messageId))
    .first();
  if (row) await ctx.db.delete(row._id);
}

export async function purgeChallengesForRoom(ctx: any, roomId: any) {
  for (const row of await ctx.db
    .query("gameChallenges")
    .withIndex("by_room", (q: any) => q.eq("roomId", roomId))
    .collect()) {
    await ctx.db.delete(row._id);
  }
}

export async function purgeChallengesOfUser(ctx: any, userId: any) {
  for (const row of await ctx.db
    .query("gameChallenges")
    .withIndex("by_user", (q: any) => q.eq("userId", userId))
    .collect()) {
    await ctx.db.delete(row._id);
  }
}
