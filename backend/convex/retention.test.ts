import { convexTest } from "convex-test";
import { afterEach, beforeEach, describe, expect, test, vi } from "vitest";
import { api, internal } from "./_generated/api";
import schema from "./schema";
import { resultCutoffDayKey } from "./retention";
import { LOG_USERNAME, SYSTEM_ROOM_LOGS } from "./systemAccount";

/**
 * Retention sweeps (retention.ts).
 *
 * Time is frozen at NOW. Every sweep gets a backlog of more than two pages,
 * fires ONCE (as its cron would) and the scheduler runs to completion; rows
 * that must survive sit beside the backlog, and the boundary row is exactly one
 * period old (kept) next to one a millisecond older (removed).
 */

const DAY = 24 * 60 * 60 * 1000;
const NOW = Date.UTC(2026, 9, 23, 12, 0, 0);

beforeEach(() => {
  vi.useFakeTimers();
  vi.setSystemTime(NOW);
});
afterEach(() => {
  vi.useRealTimers();
});

async function drain(t: ReturnType<typeof convexTest>) {
  await t.finishAllScheduledFunctions(vi.runAllTimers);
}

async function signUp(t: ReturnType<typeof convexTest>, username: string) {
  return await t.mutation(api.auth.signup, {
    username,
    name: username,
    passwordHash: `hash-${username}`,
    recoveryKeyHash: `recovery-${username}`,
    deviceId: `device-${username}`,
  });
}

async function world(t: ReturnType<typeof convexTest>) {
  const a = await signUp(t, "alice");
  const b = await signUp(t, "bob");
  const room = await t.mutation(api.rooms.create, {
    sessionToken: a.token,
    userId: a.userId as any,
    name: "lounge",
    isPrivate: false,
  });
  return { a, b, userId: a.userId as any, otherId: b.userId as any, room: room as any };
}

const all = (t: ReturnType<typeof convexTest>, table: any): Promise<any[]> =>
  t.run((ctx) => (ctx.db.query(table) as any).collect()) as Promise<any[]>;

describe("room bans", () => {
  test("drains expired bans, keeps live ones, boundary is exact", async () => {
    const t = convexTest(schema);
    const { userId, room } = await world(t);
    await t.run(async (ctx) => {
      for (let i = 0; i < 450; i++) {
        await ctx.db.insert("roomBans", { roomId: room, userId, until: NOW - 1 - i });
      }
      await ctx.db.insert("roomBans", { roomId: room, userId, until: NOW }); // not below now
      await ctx.db.insert("roomBans", { roomId: room, userId, until: NOW + DAY });
    });
    await t.mutation(internal.retention.gcExpiredRoomBans, {});
    await drain(t);
    const left = await all(t, "roomBans");
    expect(left.map((r: any) => r.until).sort()).toEqual([NOW, NOW + DAY]);
  });
});

describe("typing indicators", () => {
  test("drains rows idle for a day, keeps newer ones, boundary is exact", async () => {
    const t = convexTest(schema);
    const { userId, otherId, room } = await world(t);
    await t.run(async (ctx) => {
      for (let i = 0; i < 450; i++) {
        await ctx.db.insert("typingIndicators", {
          roomId: room, userId, updatedAt: i === 0 ? 0 : NOW - DAY - 1 - i,
        });
      }
      await ctx.db.insert("typingIndicators", { roomId: room, userId: otherId, updatedAt: NOW - DAY });
      await ctx.db.insert("typingIndicators", { roomId: room, userId: otherId, updatedAt: NOW });
    });
    await t.mutation(internal.retention.gcIdleTyping, {});
    await drain(t);
    const left = await all(t, "typingIndicators");
    expect(left.map((r: any) => r.updatedAt).sort()).toEqual([NOW - DAY, NOW]);
  });

  test("clearTyping hides the row (keeping the throttle), and the idle sweep removes it", async () => {
    const t = convexTest(schema);
    const { a, userId, room } = await world(t);
    const args = { sessionToken: a.token, roomId: room, userId };
    await t.mutation(api.typing.setTyping, args);
    await t.mutation(api.typing.clearTyping, args);
    const rows = await all(t, "typingIndicators");
    expect(rows).toHaveLength(1);
    expect(rows[0].updatedAt).toBe(0);
    await t.mutation(api.typing.clearTyping, args); // already hidden is fine
    await t.mutation(internal.retention.gcIdleTyping, {});
    expect(await all(t, "typingIndicators")).toHaveLength(0);
  });

  test("getTypingForUser reads one room when given roomId, all rooms otherwise", async () => {
    const t = convexTest(schema);
    const { a, b, userId, otherId, room } = await world(t);
    const second = (await t.mutation(api.rooms.create, {
      sessionToken: a.token,
      userId,
      name: "den",
      isPrivate: false,
    })) as any;
    await t.run(async (ctx) => {
      await ctx.db.insert("roomMembers", { roomId: second, userId: otherId, role: "member", joinedAt: NOW } as any);
      await ctx.db.insert("roomMembers", { roomId: room, userId: otherId, role: "member", joinedAt: NOW } as any);
      for (const r of [room, second]) {
        await ctx.db.insert("typingIndicators", {
          roomId: r, userId: otherId, updatedAt: NOW, userName: "bob",
        });
      }
    });
    const base = { sessionToken: a.token, userId };
    const everything = await t.query(api.typing.getTypingForUser, base);
    expect(Object.keys(everything).sort()).toEqual([room.toString(), second.toString()].sort());
    const one = await t.query(api.typing.getTypingForUser, { ...base, roomId: room });
    expect(one).toEqual({ [room.toString()]: ["bob"] });
    // A room the asker is not in yields nothing.
    const stranger = await t.query(api.typing.getTypingForUser, {
      sessionToken: b.token,
      userId: otherId,
      roomId: (await t.mutation(api.rooms.create, {
        sessionToken: a.token, userId, name: "vault", isPrivate: true,
      })) as any,
    });
    expect(stranger).toEqual({});
  });
});

describe("moment views", () => {
  test("drains views of long-expired moments, keeps the rest, boundary is exact", async () => {
    const t = convexTest(schema);
    const { userId, otherId } = await world(t);
    const oldViewed = NOW - 8 * DAY - 1; // below the range bound
    const ids = await t.run(async (ctx) => {
      const mk = (expiresAt: number) =>
        ctx.db.insert("moments", {
          userId, dayKey: "2026-01-01", createdAt: expiresAt - DAY, expiresAt,
          authorName: "a", authorUsername: "a",
        });
      const expired = await mk(NOW - 30 * DAY);
      const lived = await mk(NOW - DAY); // expired a day ago only
      for (let i = 0; i < 450; i++) {
        await ctx.db.insert("momentViews", { momentId: expired, viewerId: otherId, viewedAt: oldViewed - i });
      }
      // Not below the bound: kept even though its moment is long expired.
      await ctx.db.insert("momentViews", { momentId: expired, viewerId: otherId, viewedAt: NOW - 8 * DAY });
      // Old enough, but the moment is recent (a longer-lived moment): kept.
      await ctx.db.insert("momentViews", { momentId: lived, viewerId: otherId, viewedAt: oldViewed });
      await ctx.db.insert("momentViews", { momentId: lived, viewerId: otherId, viewedAt: NOW });
      return { expired, lived };
    });
    await t.mutation(internal.retention.gcMomentViews, {});
    await drain(t);
    const left = await all(t, "momentViews");
    expect(left).toHaveLength(3);
    expect(left.filter((r: any) => r.momentId === ids.expired)).toHaveLength(1);
  });
});

describe("finished games", () => {
  test("erases old finished and abandoned games with children; the chat card stays", async () => {
    const t = convexTest(schema);
    const { userId, room } = await world(t);
    const cutoff = NOW - 90 * DAY;
    const card = await t.run(async (ctx) => {
      const mk = async (status: string, finishedAt: number | undefined, withCard = false) => {
        const messageId = withCard
          ? await ctx.db.insert("messages", { roomId: room, userId, content: "result", createdAt: NOW - 100 * DAY, type: "text" } as any)
          : undefined;
        const id = await ctx.db.insert("matches", {
          roomId: room, game: "tictactoe", mode: "turns", status, seats: [], seq: 2,
          createdBy: userId, createdAt: NOW - 200 * DAY, lastMoveAt: NOW - 200 * DAY,
          ...(finishedAt !== undefined ? { finishedAt } : {}),
          ...(messageId ? { messageId } : {}),
        } as any);
        await ctx.db.insert("matchMoves", { matchId: id, seq: 1, seat: 0, move: "a", at: 1 });
        await ctx.db.insert("matchHidden", { matchId: id, state: "{}" });
        await ctx.db.insert("matchPresence", { matchId: id, userId, lastBeatAt: 1 });
        return { id, messageId };
      };
      for (let i = 0; i < 60; i++) await mk(i % 2 ? "finished" : "abandoned", cutoff - 1 - i);
      const withCard = await mk("finished", cutoff - 5, true);
      await mk("finished", cutoff); // exactly 90 days: kept
      await mk("finished", NOW - DAY); // recent: kept
      await mk("active", undefined); // never finished: kept
      return withCard.messageId;
    });
    await t.mutation(internal.retention.gcFinishedMatches, {});
    await drain(t);
    const matches = await all(t, "matches");
    expect(matches.map((m: any) => m.status).sort()).toEqual(["active", "finished", "finished"]);
    expect(await all(t, "matchMoves")).toHaveLength(3);
    expect(await all(t, "matchHidden")).toHaveLength(3);
    expect(await all(t, "matchPresence")).toHaveLength(3);
    const msg = await t.run((ctx) => ctx.db.get(card as any));
    expect(msg).not.toBeNull();
  });
});

describe("failed scheduled messages", () => {
  test("drains old failed rows and releases their photo; pending and recent rows stay", async () => {
    const t = convexTest(schema);
    const { userId, room } = await world(t);
    const cutoff = NOW - 30 * DAY;
    const base = { roomId: room, userId, content: "hi", sendAt: NOW + DAY, createdAt: NOW - 40 * DAY };
    const photo = await t.run(async (ctx) => {
      const storageId = await ctx.storage.store(new Blob(["x"]));
      for (let i = 0; i < 450; i++) {
        await ctx.db.insert("scheduledMessages", {
          ...base, clientId: `c${i}`, failedReason: "x", failedAt: cutoff - 1 - i,
        });
      }
      await ctx.db.insert("scheduledMessages", {
        ...base, clientId: "photo", failedReason: "x", failedAt: cutoff - 1, type: "image", mediaStorageId: storageId,
      } as any);
      await ctx.db.insert("scheduledMessages", { ...base, clientId: "edge", failedReason: "x", failedAt: cutoff });
      await ctx.db.insert("scheduledMessages", { ...base, clientId: "pending", pending: true });
      return storageId;
    });
    await t.mutation(internal.retention.gcFailedScheduled, {});
    await drain(t);
    const left = await all(t, "scheduledMessages");
    expect(left.map((r: any) => r.clientId).sort()).toEqual(["edge", "pending"]);
    expect(await t.run((ctx) => ctx.storage.get(photo))).toBeNull();
  });
});

describe("decided requests", () => {
  test("drains decided rows past 90 days; pending and approved permissions stay", async () => {
    const t = convexTest(schema);
    const { userId, otherId, room } = await world(t);
    const cutoff = NOW - 90 * DAY;
    await t.run(async (ctx) => {
      for (let i = 0; i < 450; i++) {
        await ctx.db.insert("roomInvitations", {
          roomId: room, inviterId: userId, inviteeId: otherId, createdAt: 1,
          status: ["accepted", "rejected", "cancelled"][i % 3], respondedAt: cutoff - 1 - i,
        });
      }
      for (let i = 0; i < 450; i++) {
        await ctx.db.insert("roomJoinRequests", {
          roomId: room, userId: otherId, createdAt: 1,
          status: i % 2 ? "approved" : "rejected", decidedAt: cutoff - 1 - i,
        });
        await ctx.db.insert("roomChangeRequests", {
          roomId: room, userId: otherId, field: "name", createdAt: 1,
          status: i % 2 ? "approved" : "rejected", decidedAt: cutoff - 1 - i,
        });
      }
      for (let i = 0; i < 450; i++) {
        await ctx.db.insert("approvalRequests", {
          childId: otherId, kind: "contact", createdAt: 1,
          status: i % 2 ? "denied" : "revoked", decidedAt: cutoff - 1 - i,
        });
      }
      // Kept: the boundary, pending rows, and approved guardian permissions.
      await ctx.db.insert("roomInvitations", { roomId: room, inviterId: userId, inviteeId: otherId, createdAt: 1, status: "accepted", respondedAt: cutoff });
      await ctx.db.insert("roomInvitations", { roomId: room, inviterId: userId, inviteeId: otherId, createdAt: 1, status: "pending" });
      await ctx.db.insert("roomJoinRequests", { roomId: room, userId: otherId, createdAt: 1, status: "approved", decidedAt: cutoff });
      await ctx.db.insert("roomJoinRequests", { roomId: room, userId: otherId, createdAt: 1, status: "pending" });
      await ctx.db.insert("roomChangeRequests", { roomId: room, userId: otherId, field: "name", createdAt: 1, status: "rejected", decidedAt: cutoff });
      await ctx.db.insert("roomChangeRequests", { roomId: room, userId: otherId, field: "name", createdAt: 1, status: "pending" });
      await ctx.db.insert("approvalRequests", { childId: otherId, kind: "contact", createdAt: 1, status: "approved", decidedAt: 5 });
      await ctx.db.insert("approvalRequests", { childId: otherId, kind: "contact", createdAt: 1, status: "pending" });
      await ctx.db.insert("approvalRequests", { childId: otherId, kind: "contact", createdAt: 1, status: "denied", decidedAt: cutoff });
    });
    await t.mutation(internal.retention.gcDecidedRequests, {});
    await drain(t);
    expect(await all(t, "roomInvitations")).toHaveLength(2);
    expect(await all(t, "roomJoinRequests")).toHaveLength(2);
    expect(await all(t, "roomChangeRequests")).toHaveLength(2);
    const approvals = await all(t, "approvalRequests");
    expect(approvals.map((r: any) => r.status).sort()).toEqual(["approved", "denied", "pending"]);
  });
});

describe("dead invite links", () => {
  test("drains revoked and expired links; live ones stay; requests lose the pointer", async () => {
    const t = convexTest(schema);
    const { userId, otherId, room } = await world(t);
    const cutoff = NOW - 90 * DAY;
    const probe = await t.run(async (ctx) => {
      const mk = (code: string, extra: object) =>
        ctx.db.insert("roomInvites", { roomId: room, code, createdBy: userId, createdAt: 1, useCount: 0, ...extra });
      for (let i = 0; i < 60; i++) await mk(`r${i}`, { revokedAt: cutoff - 1 - i });
      for (let i = 0; i < 60; i++) await mk(`e${i}`, { expiresAt: cutoff - 1 - i });
      const dead = await mk("dead", { revokedAt: cutoff - 1 });
      await mk("edge-revoked", { revokedAt: cutoff });
      await mk("edge-expired", { expiresAt: cutoff });
      await mk("fresh", { expiresAt: NOW + DAY });
      await mk("forever", {});
      const request = await ctx.db.insert("roomJoinRequests", {
        roomId: room, userId: otherId, createdAt: 1, status: "pending", inviteId: dead,
      });
      return { request };
    });
    await t.mutation(internal.retention.gcDeadInvites, {});
    await drain(t);
    const left = await all(t, "roomInvites");
    expect(left.map((r: any) => r.code).sort()).toEqual(["edge-expired", "edge-revoked", "forever", "fresh"].sort());
    const request: any = await t.run((ctx) => ctx.db.get(probe.request));
    expect(request.status).toBe("pending");
    expect(request.inviteId).toBeUndefined();
  });
});

describe("guardian codes", () => {
  test("drains codes a day past expiry; fresher ones stay", async () => {
    const t = convexTest(schema);
    const { userId, otherId } = await world(t);
    const cutoff = NOW - DAY;
    await t.run(async (ctx) => {
      for (let i = 0; i < 450; i++) {
        for (const table of ["pairingCodes", "releaseCodes"] as const) {
          await ctx.db.insert(table, {
            childId: otherId, createdByGuardianId: userId, codeHash: `${table}${i}`,
            expiresAt: cutoff - 1 - i, ...(i % 2 ? { consumedAt: cutoff - 5000 } : {}),
          });
        }
      }
      for (const table of ["pairingCodes", "releaseCodes"] as const) {
        await ctx.db.insert(table, { childId: otherId, createdByGuardianId: userId, codeHash: "edge", expiresAt: cutoff });
        await ctx.db.insert(table, { childId: otherId, createdByGuardianId: userId, codeHash: "live", expiresAt: NOW + 1000 });
      }
    });
    await t.mutation(internal.retention.gcFamilyCodes, {});
    await drain(t);
    for (const table of ["pairingCodes", "releaseCodes"]) {
      expect((await all(t, table)).map((r: any) => r.codeHash).sort()).toEqual(["edge", "live"]);
    }
  });
});

describe("problem-report log room", () => {
  test("removes log messages past 90 days; other rooms and newer messages stay", async () => {
    const t = convexTest(schema);
    const { userId, room } = await world(t);
    const cutoff = NOW - 90 * DAY;
    await t.run(async (ctx) => {
      const logger = await ctx.db.insert("users", { username: LOG_USERNAME, name: "Logger", passwordHash: "x", recoveryKeyHash: "y", createdAt: 1 } as any);
      const logRoom = await ctx.db.insert("rooms", {
        name: "Logs", createdBy: logger, createdAt: 1, isPrivate: true, memberCount: 1,
        type: "Regular Room", system: SYSTEM_ROOM_LOGS,
      } as any);
      await ctx.db.insert("roomMembers", { roomId: logRoom, userId: logger, role: "owner", joinedAt: 1 } as any);
      const msg = (roomId: any, createdAt: number, content: string) =>
        ctx.db.insert("messages", { roomId, userId: logger, content, createdAt, type: "text" } as any);
      for (let i = 0; i < 60; i++) await msg(logRoom, cutoff - 1 - i, "old");
      await msg(logRoom, cutoff, "edge");
      await msg(logRoom, NOW - DAY, "new");
      // An ordinary room's old messages are not this sweep's business.
      await msg(room, cutoff - 5, "ordinary");
    });
    await t.mutation(internal.retention.gcLogRoomMessages, {});
    await drain(t);
    const left = await all(t, "messages");
    expect(left.map((m: any) => m.content).sort()).toEqual(["edge", "new", "ordinary"]);
  });
});

describe("integrity history", () => {
  test("drains runs older than 8 weeks with their counters; recent runs stay", async () => {
    const t = convexTest(schema);
    const cutoff = NOW - 56 * DAY;
    await t.run(async (ctx) => {
      const run = (startedAt: number) =>
        ctx.db.insert("integrityRuns", {
          startedAt, lastProgressAt: startedAt, status: "done", tableIdx: 0, cursor: null,
          restarts: 0, pages: 0, rowsScanned: 0,
        });
      for (let i = 0; i < 60; i++) {
        const id = await run(cutoff - 1 - i);
        await ctx.db.insert("integrityCounts", { runId: id, table: "a", counts: [] });
        await ctx.db.insert("integrityCounts", { runId: id, table: "b", counts: [] });
      }
      for (const at of [cutoff, NOW - DAY]) {
        const id = await run(at);
        await ctx.db.insert("integrityCounts", { runId: id, table: "a", counts: [] });
      }
    });
    await t.mutation(internal.retention.gcIntegrityRuns, {});
    await drain(t);
    expect((await all(t, "integrityRuns")).map((r: any) => r.startedAt).sort()).toEqual([cutoff, NOW - DAY].sort());
    expect(await all(t, "integrityCounts")).toHaveLength(2);
  });
});

// ── Daily results: fold, then delete ────────────────────────────────────────

const recordsOf = async (t: ReturnType<typeof convexTest>) =>
  (await all(t, "gameRecords"))
    .map(({ _id, _creationTime, ...rest }: any) => rest)
    .sort((x: any, y: any) => x.game.localeCompare(y.game));

const dayKeyAt = (ms: number) => new Date(ms).toISOString().slice(0, 10);

/** A small deterministic generator so each seed is a different history. */
function lcg(seed: number) {
  let s = seed >>> 0;
  return () => (s = (Math.imul(s, 1664525) + 1013904223) >>> 0) / 2 ** 32;
}

async function runBackfill(t: ReturnType<typeof convexTest>) {
  await t.mutation(internal.records.backfill, {});
  await drain(t);
}

describe("daily results fold", () => {
  test("the cutoff day is the first one kept in full", () => {
    expect(resultCutoffDayKey(NOW)).toBe("2025-10-23");
  });

  test("a streak crossing New Year and the cutoff is identical after the fold", async () => {
    const t = convexTest(schema);
    const { userId } = await world(t);
    // Solved days for "queens": Dec 28 - Jan 3 (across New Year), a gap, a run
    // from Oct 15 to Oct 30 2025 (across the cutoff), a gap, a short recent run.
    const span = (from: string, n: number) =>
      Array.from({ length: n }, (_, i) => dayKeyAt(Date.parse(`${from}T00:00:00Z`) + i * DAY));
    const days = [
      ...span("2024-12-28", 7),
      ...span("2025-10-15", 16),
      ...span("2026-03-01", 5),
    ];
    await t.run(async (ctx) => {
      let i = 0;
      for (const dayKey of days) {
        i++;
        await ctx.db.insert("gameResults", {
          userId, dayKey, game: "queens", startedAt: Date.parse(dayKey), finishedAt: Date.parse(dayKey) + 1000 + i,
          durationMs: 60_000 - (i % 7) * 1000, solved: true, gaveUp: false, hintsUsed: i % 5 === 0 ? 1 : 0, mistakes: 0,
        });
      }
      // Unsolved and gave-up rows add nothing to records but are also deleted.
      await ctx.db.insert("gameResults", {
        userId, dayKey: "2024-06-01", game: "zip", startedAt: 1, solved: false, gaveUp: true, finishedAt: 2, hintsUsed: 0, mistakes: 0,
      });
    });
    await runBackfill(t);
    const before = await recordsOf(t);
    expect(before).toHaveLength(1);
    expect(before[0].bestStreak).toBe(16);

    await t.mutation(internal.retention.foldOldResults, {});
    await drain(t);
    const left = await all(t, "gameResults");
    // Only days on or after the cutoff (2025-10-23) remain.
    expect(left.every((r: any) => r.dayKey >= "2025-10-23")).toBe(true);
    expect(left.some((r: any) => r.dayKey === "2025-10-23")).toBe(true);
    const years = await all(t, "gameResultYears");
    expect(years.map((y: any) => y.year).sort()).toEqual(["2024", "2025"]);

    // Rebuild from scratch: the folded history must give the same records.
    await t.run(async (ctx) => {
      for (const r of await ctx.db.query("gameRecords").collect()) await ctx.db.delete(r._id);
    });
    await runBackfill(t);
    expect(await recordsOf(t)).toEqual(before);
  });

  test("a run that spans whole folded years still counts as one streak", async () => {
    const t = convexTest(schema);
    const { userId } = await world(t);
    // Every day from 2023-11-01 to 2025-12-31: 2023 and 2025 are partial years
    // and 2024 is a full one in the middle, so the run is stitched from three
    // rollups plus live days. Then a gap and a short run.
    const start = Date.parse("2023-11-01T00:00:00Z");
    const end = Date.parse("2025-12-31T00:00:00Z");
    const days: string[] = [];
    for (let ms = start; ms <= end; ms += DAY) days.push(dayKeyAt(ms));
    days.push("2026-02-01", "2026-02-02");
    await t.run(async (ctx) => {
      for (const dayKey of days) {
        await ctx.db.insert("gameResults", {
          userId, dayKey, game: "sudoku", startedAt: 1, finishedAt: 2, durationMs: 1000,
          solved: true, gaveUp: false, hintsUsed: 0, mistakes: 0,
        });
      }
    });
    await runBackfill(t);
    const before = await recordsOf(t);
    expect(before[0].bestStreak).toBe(days.length - 2);
    await t.mutation(internal.retention.foldOldResults, {});
    await drain(t);
    expect((await all(t, "gameResultYears")).map((y: any) => y.year).sort()).toEqual(["2023", "2024", "2025"]);
    await t.run(async (ctx) => {
      for (const r of await ctx.db.query("gameRecords").collect()) await ctx.db.delete(r._id);
    });
    await runBackfill(t);
    expect(await recordsOf(t)).toEqual(before);
  });

  test("records rebuild identically across seeds, games, the puzzle, and two folds", async () => {
    for (const seed of [1, 2, 3]) {
      vi.setSystemTime(NOW);
      const t = convexTest(schema);
      const { userId, otherId } = await world(t);
      const rand = lcg(seed);
      await t.run(async (ctx) => {
        for (const owner of [userId, otherId]) {
          // ~3 years of history ending today; each game skips random days.
          for (let back = 0; back < 800; back++) {
            const dayKey = dayKeyAt(NOW - back * DAY);
            for (const game of ["queens", "zip"]) {
              if (rand() < 0.15) continue;
              const solved = rand() < 0.9;
              const durationMs = 20_000 + Math.floor(rand() * 40) * 1000; // many ties
              await ctx.db.insert("gameResults", {
                userId: owner, dayKey, game, startedAt: Date.parse(dayKey), finishedAt: Date.parse(dayKey) + 5000 + Math.floor(rand() * 9),
                durationMs: solved ? durationMs : undefined, solved, gaveUp: !solved,
                hintsUsed: rand() < 0.3 ? 1 : 0, mistakes: 0,
              });
            }
            if (rand() < 0.2) continue;
            await ctx.db.insert("puzzleResults", {
              userId: owner, dayKey, guesses: Array.from({ length: 1 + Math.floor(rand() * 6) }, () => [0, 1, 2, 3]),
              solved: rand() < 0.8, createdAt: Date.parse(dayKey), updatedAt: Date.parse(dayKey) + 7, finishedAt: Date.parse(dayKey) + 9,
            });
          }
        }
      });
      await runBackfill(t);
      const before = await recordsOf(t);
      expect(before.length).toBeGreaterThan(4);

      // First fold now; a second one 40 days later folds a further slice into
      // the year rows already written.
      await t.mutation(internal.retention.foldOldResults, {});
      await drain(t);
      const afterFirst = await all(t, "gameResults");
      expect(afterFirst.length).toBeLessThan(2 * 2 * 380); // ~one year of two games, two players
      vi.setSystemTime(NOW + 40 * DAY);
      await t.mutation(internal.retention.foldOldResults, {});
      await drain(t);
      expect((await all(t, "gameResults")).length).toBeLessThan(afterFirst.length);
      expect((await all(t, "puzzleResults")).every((r: any) => r.dayKey >= resultCutoffDayKey(NOW + 40 * DAY))).toBe(true);

      await t.run(async (ctx) => {
        for (const r of await ctx.db.query("gameRecords").collect()) await ctx.db.delete(r._id);
      });
      await runBackfill(t);
      expect(await recordsOf(t)).toEqual(before);
    }
  }, 120_000);

  test("a backlog bigger than a page drains in one firing; boundary day is kept", async () => {
    const t = convexTest(schema);
    const { userId } = await world(t);
    await t.run(async (ctx) => {
      for (let i = 0; i < 450; i++) {
        const dayKey = dayKeyAt(NOW - (366 + i) * DAY);
        await ctx.db.insert("gameResults", {
          userId, dayKey, game: "tango", startedAt: 1, solved: false, gaveUp: false, hintsUsed: 0, mistakes: 0,
        });
        await ctx.db.insert("puzzleResults", {
          userId, dayKey, guesses: [], solved: false, createdAt: 1, updatedAt: 1,
        });
      }
      await ctx.db.insert("gameResults", { userId, dayKey: "2025-10-23", game: "tango", startedAt: 1, solved: false, gaveUp: false, hintsUsed: 0, mistakes: 0 });
      await ctx.db.insert("gameResults", { userId, dayKey: "not-a-date", game: "tango", startedAt: 1, solved: true, durationMs: 5, gaveUp: false, hintsUsed: 0, mistakes: 0 });
      await ctx.db.insert("gameResults", { userId, dayKey: "2025-10-22", game: "tango", startedAt: 1, solved: true, durationMs: 5, gaveUp: false, hintsUsed: 0, mistakes: 0 });
    });
    await t.mutation(internal.retention.foldOldResults, {});
    await drain(t);
    expect((await all(t, "gameResults")).map((r: any) => r.dayKey).sort()).toEqual(["2025-10-23", "not-a-date"]);
    expect(await all(t, "puzzleResults")).toHaveLength(0);
    // Only the solved 2025-10-22 row produced a rollup.
    const years = await all(t, "gameResultYears");
    expect(years).toHaveLength(1);
    expect(years[0]).toMatchObject({ game: "tango", year: "2025", solves: 1, best: 5 });
  });
});
