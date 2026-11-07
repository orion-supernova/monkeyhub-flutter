import { convexTest } from "convex-test";
import { afterEach, beforeEach, describe, expect, test, vi } from "vitest";
import { api } from "./_generated/api";
import schema from "./schema";
import { LIVE_GRACE_MS, LIVE_REQUEST_TTL_MS } from "./matches";

/**
 * Going live from a turn by turn duel: one player asks, the other says yes,
 * and the SAME game row becomes a live game. Pinned here:
 *
 *   1. Both must be online (the partner's presence row) to ask; an offline
 *      or hidden partner answers a bare NOT_AVAILABLE.
 *   2. A request is dead after its TTL with no job; a decline is quiet and
 *      rate-limited for the asker.
 *   3. Yes flips the mode, drops the async deadline, and its stale async
 *      jobs do nothing.
 *   4. A pause in a session-by-consent goes back to async, never forfeits.
 *   5. A game that ends live ends as an async game, with no "you lost" push.
 */

type Who = { token: string; userId: any };
const as = (w: Who) => ({ sessionToken: w.token, userId: w.userId });

async function signUp(t: ReturnType<typeof convexTest>, username: string) {
  return (await t.mutation(api.auth.signup, {
    username,
    name: username,
    passwordHash: `hash-${username}`,
    recoveryKeyHash: `recovery-${username}`,
    deviceId: `device-${username}`,
  })) as Who;
}

async function setup(online = true) {
  const t = convexTest(schema);
  const a = await signUp(t, "ada");
  const b = await signUp(t, "bob");
  await t.mutation(api.friends.sendRequest, {
    ...as(a),
    friendUsername: "bob",
  });
  await t.mutation(api.friends.acceptRequest, { ...as(b), requesterId: a.userId });
  const roomId = await t.mutation(api.rooms.getOrCreateDM, {
    sessionToken: a.token,
    userId: a.userId,
    friendId: b.userId,
  });
  const res = (await t.mutation(api.matches.startTurns, {
    ...as(a),
    roomId,
    game: "tictactoe",
    move: "4",
    clientMoveId: "mv-1",
  })) as { matchId: any };
  await t.run(async (ctx) => {
    for (const r of await ctx.db
      .query("presence")
      .withIndex("by_user", (q: any) => q.eq("userId", b.userId))
      .collect()) {
      await ctx.db.delete(r._id);
    }
    await ctx.db.insert("presence", {
      userId: b.userId,
      status: online ? "online" : "offline",
    });
  });
  return { t, a, b, roomId, matchId: res.matchId };
}

const get = async (t: any, w: Who, matchId: any) =>
  (await t.query(api.matches.get, {
    sessionToken: w.token,
    matchId,
    viewerUserId: w.userId,
  })) as any;

beforeEach(() => vi.useFakeTimers());
afterEach(() => vi.useRealTimers());

describe("going live from a turn by turn duel", () => {
  test("an offline partner cannot be asked", async () => {
    const { t, a, matchId } = await setup(false);
    await expect(
      t.mutation(api.matches.requestLive, { ...as(a), matchId }),
    ).rejects.toThrow("NOT_AVAILABLE");
  });

  test("yes makes the same game live, with no async deadline", async () => {
    const { t, a, b, matchId } = await setup();
    await t.mutation(api.matches.requestLive, { ...as(a), matchId });
    expect((await get(t, b, matchId)).liveRequest.seat).toBe(0);
    await t.mutation(api.matches.answerLive, { ...as(b), matchId, accept: true });
    const m = await get(t, b, matchId);
    expect(m.mode).toBe("live");
    expect(m.status).toBe("active");
    expect(m.liveRequest).toBeUndefined();
    expect(m.deadlineAt).toBeUndefined();
    expect(m.seq).toBe(1);
    // The old async deadline job wakes up to a live game and does nothing.
    vi.advanceTimersByTime(49 * 3600 * 1000);
    await t.finishInProgressScheduledFunctions();
    expect((await get(t, b, matchId)).status).not.toBe("finished");
  });

  test("a decline is quiet and cannot be repeated at once", async () => {
    const { t, a, b, matchId } = await setup();
    await t.mutation(api.matches.requestLive, { ...as(a), matchId });
    await t.mutation(api.matches.answerLive, { ...as(b), matchId, accept: false });
    const m = await get(t, a, matchId);
    expect(m.mode).toBe("async");
    expect(m.liveRequest).toBeUndefined();
    await expect(
      t.mutation(api.matches.requestLive, { ...as(a), matchId }),
    ).rejects.toThrow("TOO_SOON");
  });

  test("a request lapses on its own", async () => {
    const { t, a, b, matchId } = await setup();
    await t.mutation(api.matches.requestLive, { ...as(a), matchId });
    vi.advanceTimersByTime(LIVE_REQUEST_TTL_MS + 1000);
    await expect(
      t.mutation(api.matches.answerLive, { ...as(b), matchId, accept: true }),
    ).rejects.toThrow("NO_REQUEST");
  });

  test("an asker who stopped beating cannot be accepted", async () => {
    const { t, a, b, matchId } = await setup();
    await t.mutation(api.matches.requestLive, { ...as(a), matchId });
    vi.advanceTimersByTime(30_000);
    await expect(
      t.mutation(api.matches.answerLive, { ...as(b), matchId, accept: true }),
    ).rejects.toThrow("NO_REQUEST");
    expect((await get(t, a, matchId)).mode).toBe("async");
  });

  test("cancel withdraws; only the asker can", async () => {
    const { t, a, b, matchId } = await setup();
    await t.mutation(api.matches.requestLive, { ...as(a), matchId });
    await t.mutation(api.matches.cancelLive, { ...as(b), matchId });
    expect((await get(t, a, matchId)).liveRequest).toBeDefined();
    await t.mutation(api.matches.cancelLive, { ...as(a), matchId });
    expect((await get(t, a, matchId)).liveRequest).toBeUndefined();
  });

  test("a live session nobody keeps goes back to async, not to a forfeit", async () => {
    const { t, a, b, matchId } = await setup();
    await t.mutation(api.matches.requestLive, { ...as(a), matchId });
    await t.mutation(api.matches.answerLive, { ...as(b), matchId, accept: true });
    // Nobody beats: the liveness pass pauses it, the grace ends it.
    for (let done = 0; done < 60_000 + LIVE_GRACE_MS; done += 10_000) {
      vi.advanceTimersByTime(10_000);
      await t.finishInProgressScheduledFunctions();
    }
    const m = await get(t, a, matchId);
    expect(m.mode).toBe("async");
    expect(m.status).toBe("active");
    expect(m.deadlineAt).toBeGreaterThan(Date.now());
  });

  test("a live move lands in the transcript, and a finish ends it as async", async () => {
    const { t, a, b, matchId } = await setup();
    await t.mutation(api.matches.requestLive, { ...as(a), matchId });
    await t.mutation(api.matches.answerLive, { ...as(b), matchId, accept: true });
    await t.mutation(api.matches.move, {
      ...as(b), matchId, expectedSeq: 1, move: "0",
    });
    await t.mutation(api.matches.resign, { ...as(a), matchId });
    const m = await get(t, a, matchId);
    expect(m.status).toBe("finished");
    expect(m.mode).toBe("async");
    const bubbles = await t.run(async (ctx) =>
      (await ctx.db.query("messages").collect()).filter(
        (x: any) => x.type === "gameMove",
      ),
    );
    expect(bubbles).toHaveLength(2);
  });
});
