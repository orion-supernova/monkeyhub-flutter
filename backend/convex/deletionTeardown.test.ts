import { convexTest } from "convex-test";
import { afterEach, beforeEach, describe, expect, test, vi } from "vitest";
import { api, internal } from "./_generated/api";
import type { Id } from "./_generated/dataModel";
import {
  Budget,
  startRoomDeletion,
  startUserDeletion,
  testHooks,
} from "./deletionCore";
import { cursorOf, pageAfter } from "./deletionCore";
import { planFor } from "./deletionPlans";
import { drainDeletions, shrinkTuning } from "./deletionTestUtils";
import { STALL_MS } from "./deletions";
import { addMembership, getRoomOrThrow, removeMembership } from "./roomAdmin";
import schema from "./schema";

/**
 * Room and user teardown through the lifecycle engine (Phase 2, WP-C): the
 * room plan, the user plan, and the callers that now start them. Rows are
 * seeded straight into the tables, and budgets are shrunk (4 writes / 2 rows a
 * page) so a handful of rows spans many transactions.
 */

type T = ReturnType<typeof convexTest>;

let restoreTuning: () => void;
beforeEach(() => {
  vi.useFakeTimers();
  vi.spyOn(console, "warn").mockImplementation(() => {});
  vi.spyOn(console, "error").mockImplementation(() => {});
  restoreTuning = shrinkTuning();
});
afterEach(() => {
  restoreTuning();
  testHooks.beforeStep = undefined;
  testHooks.beforeRow = undefined;
  vi.restoreAllMocks();
  vi.useRealTimers();
});

const drain = (t: T) => drainDeletions(t, vi.runAllTimers);
const later = (ms: number) => vi.advanceTimersByTime(ms);

const mkUser = (t: T, username: string, extra: Record<string, any> = {}) =>
  t.run((ctx) =>
    ctx.db.insert("users", { username, passwordHash: "x", createdAt: 1, ...extra }),
  );
const mkRoom = (t: T, createdBy: Id<"users">, extra: Record<string, any> = {}) =>
  t.run((ctx) =>
    ctx.db.insert("rooms", {
      name: `room${Math.random()}`,
      createdBy,
      createdAt: 1,
      isPrivate: false,
      memberCount: 0,
      ...extra,
    }),
  );
const join = (t: T, roomId: Id<"rooms">, userId: Id<"users">, role = "member", joinedAt = 1) =>
  t.run(async (ctx) => {
    await ctx.db.insert("roomMembers", { roomId, userId, joinedAt, role });
    await ctx.db.insert("roomAccess", { roomId, userId });
    const room = await ctx.db.get(roomId);
    await ctx.db.patch(roomId, { memberCount: room!.memberCount + 1 });
  });
const say = (t: T, roomId: Id<"rooms">, userId: Id<"users">, content = "hi", extra: Record<string, any> = {}) =>
  t.run((ctx) =>
    ctx.db.insert("messages", { roomId, userId, content, createdAt: Date.now(), ...extra }),
  );
const blob = (t: T) => t.run((ctx) => ctx.storage.store(new Blob([`x${Math.random()}`])));
const get = (t: T, id: any) => t.run((ctx) => ctx.db.get(id));
const rows = (t: T, table: any): Promise<any[]> =>
  t.run((ctx) => ctx.db.query(table).collect());
const files = (t: T) => t.run(async (ctx) => (await ctx.db.system.query("_storage").collect()).length);
const jobFor = (t: T, kind: string, targetId: string): Promise<any> =>
  t.run(async (ctx) =>
    (await ctx.db.query("deletions").collect()).find((j) => j.kind === kind && j.targetId === targetId),
  );

describe("user teardown", () => {
  /** A user with a few rows in many tables, plus a bystander `o`. */
  async function seedUser(t: T) {
    const u = await mkUser(t, "leaver", { avatarStorageId: await blob(t) });
    const o = await mkUser(t, "other");
    const friends: Id<"users">[] = [];
    for (let i = 0; i < 4; i++) friends.push(await mkUser(t, `f${i}`));

    // r1: u owns it, o is in it. r2: u alone. r3: o owns it but u created it.
    const r1 = await mkRoom(t, u);
    const r2 = await mkRoom(t, u);
    const r3 = await mkRoom(t, u);
    await join(t, r1, u, "owner", 1);
    await join(t, r1, o, "member", 2);
    await join(t, r2, u, "owner", 1);
    await join(t, r3, o, "owner", 1);
    await join(t, r3, u, "member", 2);

    const theirs = await say(t, r1, o, "from o");
    const mine: Id<"messages">[] = [];
    for (let i = 0; i < 5; i++) mine.push(await say(t, r1, u, `mine ${i}`));
    await say(t, r2, u, "alone");

    await t.run(async (ctx) => {
      for (let i = 0; i < 5; i++) {
        const m = await ctx.db.insert("messages", {
          roomId: r1, userId: o, content: `o${i}`, createdAt: 1,
        });
        await ctx.db.insert("reactions", { messageId: m, userId: u, emoji: "x", createdAt: 1 });
      }
      await ctx.db.insert("reactions", { messageId: mine[0], userId: o, emoji: "y", createdAt: 1 });
      for (let i = 0; i < 5; i++) {
        await ctx.db.insert("sessions", {
          userId: u, tokenHash: `h${i}`, deviceId: `d${i}`, createdAt: 1, lastSeenAt: 1,
        });
      }
      for (const f of [o, ...friends]) {
        await ctx.db.insert("friendships", { userId: u, friendId: f, status: "accepted", createdAt: 1 });
        await ctx.db.insert("friendships", { userId: f, friendId: u, status: "pending", createdAt: 1 });
        await ctx.db.insert("blocks", { userId: u, blockedUserId: f, createdAt: 1 });
        await ctx.db.insert("blocks", { userId: f, blockedUserId: u, createdAt: 1 });
        await ctx.db.insert("speakerColors", { viewerId: u, roomId: r1, subjectId: f, slot: 1 });
        await ctx.db.insert("speakerColors", { viewerId: f, roomId: r1, subjectId: u, slot: 1 });
      }
      for (let i = 0; i < 3; i++) {
        await ctx.db.insert("scheduledMessages", {
          roomId: r1, userId: u, content: "later", sendAt: Date.now() + 1e9,
          createdAt: 1, clientId: `c${i}`, pending: true,
        } as any);
      }
      for (let i = 0; i < 3; i++) {
        await ctx.db.insert("moments", {
          userId: u, dayKey: "2026-10-22", createdAt: 1, expiresAt: 9e15,
          authorName: "x", authorUsername: "leaver",
        });
      }
      await ctx.db.insert("userExpressions", { userId: u, recents: [], favorites: [], updatedAt: 1 });
    });
    const controlRows = {
      theirs,
      friendsBlocks: friends.length,
    };
    return { u, o, friends, r1, r2, r3, mine, controlRows };
  }

  test("more than a page of rows in many tables goes, in pages, with the user row last", async () => {
    const t = convexTest(schema);
    const { u, o, r1, r2, r3, controlRows } = await seedUser(t);
    const avatarFiles = await files(t);
    expect(avatarFiles).toBe(1);

    const jobId = (await t.run((ctx) => startUserDeletion(ctx, u, { reason: "self" })))!;
    // First transaction only: scrubbed and tombstoned, nothing else deleted yet.
    const ghost: any = await get(t, u);
    expect(ghost.deletingAt).toBeTypeOf("number");
    expect(ghost.username).toBe(`deleted:${u}`);
    expect(await rows(t, "messages")).toHaveLength(1 + 5 + 5 + 1);

    const seen: [string, boolean][] = [];
    testHooks.beforeStep = async (ctx, _j, s) => {
      seen.push([s.id, (await ctx.db.get(u)) !== null]);
    };
    await drain(t);

    const job: any = await get(t, jobId);
    expect(job.state).toBe("done");
    expect(job.pages).toBeGreaterThan(5);
    expect(await get(t, u)).toBeNull();
    // Parent last: the row exists at every step but the final one.
    expect(seen[seen.length - 1][0]).toBe("parent");
    expect(seen.every(([, exists]) => exists)).toBe(true);

    // Everything of theirs is gone ...
    const left = async (table: string, field: string) =>
      (await rows(t, table)).filter((r) => r[field] === u);
    expect(await left("messages", "userId")).toHaveLength(0);
    expect(await left("reactions", "userId")).toHaveLength(0);
    expect(await left("roomMembers", "userId")).toHaveLength(0);
    expect(await left("roomAccess", "userId")).toHaveLength(0);
    expect(await left("friendships", "userId")).toHaveLength(0);
    expect(await left("friendships", "friendId")).toHaveLength(0);
    expect(await left("blocks", "userId")).toHaveLength(0);
    expect(await left("blocks", "blockedUserId")).toHaveLength(0);
    expect(await left("speakerColors", "viewerId")).toHaveLength(0);
    expect(await left("speakerColors", "subjectId")).toHaveLength(0);
    expect(await left("scheduledMessages", "userId")).toHaveLength(0);
    expect(await left("moments", "userId")).toHaveLength(0);
    expect(await left("userExpressions", "userId")).toHaveLength(0);
    // Sessions are revoked (the cron deletes them), never left live.
    const sessions = await left("sessions", "userId");
    expect(sessions).toHaveLength(5);
    expect(sessions.every((x) => x.revokedAt !== undefined)).toBe(true);
    expect(await files(t)).toBe(0); // the avatar file

    // ... and what is not theirs is intact: the bystander's messages (and
    // their reply count), the room they shared, which re-seated its owner.
    expect((await rows(t, "messages")).filter((m) => m.userId === o)).toHaveLength(1 + 5);
    expect(controlRows.theirs).toBeTruthy();
    expect(await get(t, r1)).not.toBeNull();
    const r1Members: any[] = (await rows(t, "roomMembers")).filter((m) => m.roomId === r1);
    expect(r1Members.map((m) => [m.userId, m.role])).toEqual([[o, "owner"]]);
    expect(((await get(t, r1)) as any).memberCount).toBe(1);
    expect(((await get(t, r1)) as any).createdBy).toBe(o);
    // r3: created by u, owned by o: kept, and createdBy follows the owner.
    expect(((await get(t, r3)) as any).createdBy).toBe(o);
    expect(((await get(t, r3)) as any).memberCount).toBe(1);
    // r2: u was the last one out, so its own teardown ran and finished.
    expect(await get(t, r2)).toBeNull();
    expect((await rows(t, "messages")).filter((m) => m.roomId === r2)).toHaveLength(0);
    const roomJob = await jobFor(t, "room", r2);
    expect(roomJob.state).toBe("done");
    expect(roomJob.reason).toBe("lastMember");
  });

  test("a session is revoked, not deleted, so a device gets SESSION_REVOKED", async () => {
    const t = convexTest(schema);
    const me = await t.mutation(api.auth.signup, {
      username: "ada", name: "ada", passwordHash: "h", recoveryKeyHash: "r", deviceId: "d1",
    });
    await t.mutation(api.auth.deleteAccount, { sessionToken: me.token, userId: me.userId });
    // Not drained yet: the first transaction already closed the gate.
    await expect(
      t.query(api.voipTokens.listDevices, { sessionToken: me.token, userId: me.userId, deviceId: "d1" }),
    ).rejects.toThrow(/SESSION_REVOKED/);
    await drain(t);
    await expect(
      t.query(api.voipTokens.listDevices, { sessionToken: me.token, userId: me.userId, deviceId: "d1" }),
    ).rejects.toThrow(/SESSION_(REVOKED|UNKNOWN)/);
  });

  test("the only guardian is refused before any write", async () => {
    const t = convexTest(schema);
    const parent = await t.mutation(api.auth.signup, {
      username: "mum", name: "mum", passwordHash: "h", recoveryKeyHash: "r", deviceId: "d1",
    });
    const child = await mkUser(t, "kid", { accountType: "child" });
    await t.run((ctx) =>
      ctx.db.insert("guardianships", {
        guardianId: parent.userId as any, childId: child, role: "primary", createdAt: 1,
      }),
    );
    await expect(
      t.mutation(api.auth.deleteAccount, { sessionToken: parent.token, userId: parent.userId }),
    ).rejects.toThrow(/LAST_GUARDIAN/);
    await drain(t);
    const row: any = await get(t, parent.userId);
    expect(row.deletingAt).toBeUndefined();
    expect(row.username).toBe("mum");
    expect(await rows(t, "deletions")).toHaveLength(0);
    expect((await rows(t, "sessions")).every((s) => s.revokedAt === undefined)).toBe(true);
    expect(await rows(t, "guardianships")).toHaveLength(1);
  });

  test("a co-guardian deleting keeps the child's approvals, decider cleared", async () => {
    const t = convexTest(schema);
    const g1 = await t.mutation(api.auth.signup, {
      username: "g1", name: "g1", passwordHash: "h", recoveryKeyHash: "r", deviceId: "d1",
    });
    const g2 = await mkUser(t, "g2");
    const child = await mkUser(t, "kid", { accountType: "child" });
    const decided = await t.run(async (ctx) => {
      for (const g of [g1.userId as any, g2])
        await ctx.db.insert("guardianships", { guardianId: g, childId: child, role: "guardian", createdAt: 1 });
      const approved = await ctx.db.insert("approvalRequests", {
        childId: child, kind: "contact", status: "approved", createdAt: 1,
        decidedByGuardianId: g1.userId as any, targetUserId: g2,
      } as any);
      const pending = await ctx.db.insert("approvalRequests", {
        childId: child, kind: "contact", status: "pending", createdAt: 2,
      } as any);
      return { approved, pending };
    });
    await t.mutation(api.auth.deleteAccount, { sessionToken: g1.token, userId: g1.userId });
    await drain(t);
    expect(await get(t, g1.userId)).toBeNull();
    expect(await get(t, child)).not.toBeNull();
    const approved: any = await get(t, decided.approved);
    expect(approved.status).toBe("approved");
    expect(approved.decidedByGuardianId).toBeUndefined();
    expect(await get(t, decided.pending)).not.toBeNull();
    const links: any[] = await rows(t, "guardianships");
    expect(links.map((l) => l.guardianId)).toEqual([g2]);
  });

  test("a throwing step rolls back and the cron re-drive finishes the job; a finished job re-runs as a no-op", async () => {
    const t = convexTest(schema);
    const { u, r1 } = await seedUser(t);
    const jobId = (await t.run((ctx) => startUserDeletion(ctx, u)))!;
    testHooks.beforeStep = (_ctx, _j, s) => {
      if (s.id === "moments") throw new Error("boom at moments");
    };
    await drain(t);
    let job: any = await get(t, jobId);
    expect(job.state).toBe("running");
    expect(job.attempts).toBe(5);
    expect(job.lastError).toContain("boom at moments");
    expect(await get(t, u)).not.toBeNull();
    expect((await rows(t, "messages")).filter((m) => m.userId === u)).toHaveLength(0);

    testHooks.beforeStep = undefined;
    later(STALL_MS + 1000);
    await t.mutation(internal.deletions.redrive, {});
    await drain(t);
    job = await get(t, jobId);
    expect(job.state).toBe("done");
    expect(job.restarts).toBe(1);
    expect(await get(t, u)).toBeNull();
    expect(await get(t, r1)).not.toBeNull();

    // A finished job: another link does nothing, and no step writes anything.
    const before = JSON.stringify(await get(t, jobId));
    await t.mutation(internal.deletions.step, { jobId, gen: 1 });
    expect(JSON.stringify(await get(t, jobId))).toBe(before);
    await t.run(async (ctx) => {
      for (const s of planFor("user")) {
        const b = new Budget(1000, 1000);
        const r = await s.run(ctx, job, b);
        expect(r.done, s.id).toBe(true);
        expect(b.writes, s.id).toBe(0);
      }
    });
  });

  test("the old purgeMessagesLater shim finishes a removed account's messages through the engine", async () => {
    const t = convexTest(schema);
    const u = await mkUser(t, "gone");
    const r = await mkRoom(t, u);
    await join(t, r, u, "owner");
    const o = await mkUser(t, "o");
    await join(t, r, o);
    for (let i = 0; i < 5; i++) await say(t, r, u, `m${i}`);
    await t.run((ctx) => ctx.db.delete(u));
    await t.mutation(internal.auth.purgeMessagesLater, { userId: u });
    await drain(t);
    expect((await rows(t, "messages")).filter((m) => m.userId === u)).toHaveLength(0);
    expect(((await jobFor(t, "user", u)) as any).state).toBe("done");
  });
});

describe("room teardown", () => {
  test("pages of messages, reactions, a game and a pending photo go with no file leaked", async () => {
    const t = convexTest(schema);
    const owner = await mkUser(t, "owner");
    const a = await mkUser(t, "a");
    const b = await mkUser(t, "b");
    const avatar = await blob(t);
    const room = await mkRoom(t, owner, { avatarStorageId: avatar });
    const control = await mkRoom(t, owner);
    for (const [u, role] of [[owner, "owner"], [a, "member"], [b, "member"]] as const) {
      await join(t, room, u, role);
      await join(t, control, u, role);
    }
    const controlBlob = await blob(t);
    const proposal = await blob(t);
    const queued = await blob(t);
    const msgFiles: any[] = [];
    await t.run(async (ctx) => {
      await ctx.db.insert("messages", {
        roomId: control, userId: a, content: "keep", createdAt: 1, type: "image", mediaStorageId: controlBlob,
      } as any);
      for (let i = 0; i < 7; i++) {
        const f = await ctx.storage.store(new Blob([`m${i}`]));
        msgFiles.push(f);
        const m = await ctx.db.insert("messages", {
          roomId: room, userId: i % 2 ? a : b, content: `m${i}`, createdAt: i,
          type: "image", mediaStorageId: f,
        } as any);
        for (const [n, u] of [owner, a, b].entries()) {
          await ctx.db.insert("reactions", { messageId: m, userId: u, emoji: `e${n}`, createdAt: 1 });
        }
        await ctx.db.insert("pinnedMessages", { roomId: room, messageId: m, userId: a, pinnedAt: 1 });
      }
      const match = await ctx.db.insert("matches", {
        roomId: room, game: "connectfour", mode: "live", status: "active",
        seats: [], seq: 3, createdBy: a, createdAt: 1, lastMoveAt: 1,
      } as any);
      for (let i = 0; i < 3; i++) {
        await ctx.db.insert("matchMoves", { matchId: match, seq: i, seat: 0, move: "1", at: 1 });
      }
      await ctx.db.insert("roomChangeRequests", {
        roomId: room, userId: a, field: "avatar", status: "pending", createdAt: 1, storageId: proposal,
      } as any);
      await ctx.db.insert("scheduledMessages", {
        roomId: room, userId: a, content: "later", sendAt: Date.now() + 1e9, createdAt: 1,
        clientId: "c", pending: true, type: "image", mediaStorageId: queued,
      } as any);
      await ctx.db.insert("roomInvites", { roomId: room, code: "abc", createdBy: owner, createdAt: 1, useCount: 0 });
      await ctx.db.insert("typingIndicators", { roomId: room, userId: a, updatedAt: 1 });
    });
    const filesBefore = await files(t);
    expect(filesBefore).toBe(1 + 1 + 1 + 1 + 7); // avatar, control, proposal, queued, 7 messages

    const jobId = (await t.run((ctx) => startRoomDeletion(ctx, room, { reason: "owner" })))!;
    const seen: [string, boolean][] = [];
    testHooks.beforeStep = async (ctx, _j, s) => {
      seen.push([s.id, (await ctx.db.get(room)) !== null]);
    };
    await drain(t);

    expect(((await get(t, jobId)) as any).state).toBe("done");
    expect(((await get(t, jobId)) as any).pages).toBeGreaterThan(8);
    expect(await get(t, room)).toBeNull();
    expect(seen[seen.length - 1][0]).toBe("parent");
    expect(seen.every(([, exists]) => exists)).toBe(true);
    for (const table of ["messages", "reactions", "pinnedMessages", "roomMembers", "roomAccess",
      "matches", "roomChangeRequests", "scheduledMessages", "roomInvites", "typingIndicators"]) {
      const left = (await rows(t, table)).filter((r) => r.roomId === room);
      expect(left, table).toHaveLength(0);
    }
    // Only the control room's file is left: nothing leaked.
    expect(await files(t)).toBe(1);
    expect((await rows(t, "reactions"))).toHaveLength(0);
    expect(await get(t, control)).not.toBeNull();
    expect((await rows(t, "roomMembers")).filter((m) => m.roomId === control)).toHaveLength(3);
    expect((await rows(t, "messages")).filter((m) => m.roomId === control)).toHaveLength(1);
    // The match's move history went with a `match` job (B's plan).
    expect(await rows(t, "matchMoves")).toHaveLength(0);
  });

  test("a system room keeps its picture", async () => {
    const t = convexTest(schema);
    const owner = await mkUser(t, "owner");
    const avatar = await blob(t);
    const room = await mkRoom(t, owner, { avatarStorageId: avatar, system: "log" });
    await t.run((ctx) => startRoomDeletion(ctx, room));
    await drain(t);
    expect(await get(t, room)).toBeNull();
    expect(await files(t)).toBe(1);
  });

  test("a message sent between the tombstone and the messages step is swept", async () => {
    const t = convexTest(schema);
    const owner = await mkUser(t, "owner");
    const room = await mkRoom(t, owner);
    await join(t, room, owner, "owner");
    for (let i = 0; i < 5; i++) await say(t, room, owner, `m${i}`);
    await t.run((ctx) => startRoomDeletion(ctx, room));
    // Racing sends, one before the first step and one after the members step.
    await say(t, room, owner, "raced early");
    let late = false;
    testHooks.beforeStep = async (ctx, _j, s) => {
      if (s.id === "messages" && !late) {
        late = true;
        await ctx.db.insert("messages", { roomId: room, userId: owner, content: "raced late", createdAt: 9 });
      }
    };
    await drain(t);
    expect(late).toBe(true);
    expect(await get(t, room)).toBeNull();
    expect((await rows(t, "messages")).filter((m) => m.roomId === room)).toHaveLength(0);
  });

  test("throw and re-drive: the room survives a failing step and finishes after the cron", async () => {
    const t = convexTest(schema);
    const owner = await mkUser(t, "owner");
    const room = await mkRoom(t, owner);
    await join(t, room, owner, "owner");
    for (let i = 0; i < 5; i++) await say(t, room, owner, `m${i}`);
    const jobId = (await t.run((ctx) => startRoomDeletion(ctx, room)))!;
    testHooks.beforeStep = (_ctx, _j, s) => {
      if (s.id === "parent") throw new Error("boom at parent");
    };
    await drain(t);
    let job: any = await get(t, jobId);
    expect(job.state).toBe("running");
    expect(job.lastError).toContain("boom at parent");
    expect(await get(t, room)).not.toBeNull();
    // The data steps committed in earlier transactions (the last transaction,
    // which reached the parent, rolled back whole).
    expect(job.pages).toBeGreaterThan(0);

    testHooks.beforeStep = undefined;
    later(STALL_MS + 1000);
    await t.mutation(internal.deletions.redrive, {});
    await drain(t);
    job = await get(t, jobId);
    expect(job.state).toBe("done");
    expect(await get(t, room)).toBeNull();

    // Re-running a finished job does nothing.
    const before = JSON.stringify(job);
    await t.mutation(internal.deletions.step, { jobId, gen: job.restarts });
    expect(JSON.stringify(await get(t, jobId))).toBe(before);
    await t.run(async (ctx) => {
      for (const s of planFor("room")) {
        const b = new Budget(1000, 1000);
        const r = await s.run(ctx, job, b);
        expect(r.done, s.id).toBe(true);
        expect(b.writes, s.id).toBe(0);
      }
    });
  });

  test("the old wipeMessagesLater shim finishes a removed room's messages through the engine", async () => {
    const t = convexTest(schema);
    const owner = await mkUser(t, "owner");
    const room = await mkRoom(t, owner);
    for (let i = 0; i < 5; i++) await say(t, room, owner, `m${i}`);
    await t.run((ctx) => ctx.db.delete(room));
    await t.mutation(internal.roomCleanup.wipeMessagesLater, { roomId: room });
    await drain(t);
    expect(await rows(t, "messages")).toHaveLength(0);
    expect(((await jobFor(t, "room", room)) as any).state).toBe("done");
  });

  test("a room being deleted is not found, takes no member and no scheduled message", async () => {
    const t = convexTest(schema);
    const me = await t.mutation(api.auth.signup, {
      username: "ada", name: "ada", passwordHash: "h", recoveryKeyHash: "r", deviceId: "d1",
    });
    const other = await mkUser(t, "other");
    const room = await mkRoom(t, me.userId as any);
    await join(t, room, me.userId as any, "owner");
    await t.run((ctx) => startRoomDeletion(ctx, room));

    await t.run(async (ctx) => {
      await expect(getRoomOrThrow(ctx, room)).rejects.toThrow("ROOM_NOT_FOUND");
      await expect(addMembership(ctx, room, other)).rejects.toThrow("ROOM_NOT_FOUND");
    });
    await expect(
      t.mutation(api.scheduledMessages.schedule, {
        sessionToken: me.token, roomId: room, userId: me.userId as any, content: "later",
        delayMs: 3_600_000, clientId: "c1",
      } as any),
    ).rejects.toThrow("ROOM_NOT_FOUND");
    expect(await rows(t, "scheduledMessages")).toHaveLength(0);
  });
});

describe("leaving a big room", () => {
  /** Document reads a block of `ctx.db` calls does, counted from query results. */
  function counted(ctx: any) {
    let docs = 0;
    const wrap = (obj: any): any =>
      new Proxy(obj, {
        get(target, prop) {
          const v = target[prop];
          if (typeof v !== "function") return v;
          return (...args: any[]) => {
            const out = v.apply(target, args);
            if (out && typeof out.then === "function") {
              return out.then((r: any) => {
                if (Array.isArray(r)) docs += r.length;
                else if (r && typeof r === "object" && "_id" in r) docs += 1;
                return r;
              });
            }
            if (out && typeof out === "object" && typeof out.withIndex === "function") return wrap(out);
            if (out && typeof out === "object" && ("take" in out || "collect" in out || "first" in out)) return wrap(out);
            return out;
          };
        },
      });
    return { ctx: { ...ctx, db: wrap(ctx.db) }, docs: () => docs };
  }

  async function bigRoom(t: T, n: number) {
    const owner = await mkUser(t, "owner");
    const room = await mkRoom(t, owner);
    const ids: Id<"users">[] = [];
    await t.run(async (ctx) => {
      await ctx.db.insert("roomMembers", { roomId: room, userId: owner, joinedAt: 1, role: "owner" });
      for (let i = 0; i < n; i++) {
        const u = await ctx.db.insert("users", { username: `u${i}`, passwordHash: "x", createdAt: 1 });
        ids.push(u);
        await ctx.db.insert("roomMembers", { roomId: room, userId: u, joinedAt: 2 + i, role: i === 5 ? "admin" : "member" });
      }
      await ctx.db.patch(room, { memberCount: n + 1 });
    });
    return { owner, room, ids };
  }

  test("a member leaving does not read the member list, and an owner leaving seats the heir by index", async () => {
    restoreTuning(); // real budgets: this is about the cost of one call
    const t = convexTest(schema);
    const { owner, room, ids } = await bigRoom(t, 320);

    const plain = await t.run(async (ctx) => {
      const c = counted(ctx);
      const res = await removeMembership(c.ctx, room, ids[100]);
      return { res, docs: c.docs() };
    });
    expect(plain.res).toBe("removed");
    expect(plain.docs).toBeLessThan(40);

    const heir = await t.run(async (ctx) => {
      const c = counted(ctx);
      const res = await removeMembership(c.ctx, room, owner);
      return { res, docs: c.docs() };
    });
    expect(heir.res).toBe("removed");
    expect(heir.docs).toBeLessThan(40);
    const members: any[] = (await rows(t, "roomMembers")).filter((m) => m.roomId === room);
    expect(members.filter((m) => m.role === "owner").map((m) => m.userId)).toEqual([ids[5]]); // the admin
    expect(((await get(t, room)) as any).createdBy).toBe(ids[5]);
    expect(((await get(t, room)) as any).memberCount).toBe(319);
  });

  test("the last member leaving hands the room to the engine and drops their typing row", async () => {
    const t = convexTest(schema);
    const owner = await mkUser(t, "owner");
    const room = await mkRoom(t, owner);
    await join(t, room, owner, "owner");
    await say(t, room, owner);
    await t.run((ctx) => ctx.db.insert("typingIndicators", { roomId: room, userId: owner, updatedAt: 1 }));
    const res = await t.run((ctx) => removeMembership(ctx, room, owner));
    expect(res).toBe("wiped");
    expect(await rows(t, "typingIndicators")).toHaveLength(0);
    expect(((await get(t, room)) as any).deletingAt).toBeTypeOf("number");
    await drain(t);
    expect(await get(t, room)).toBeNull();
    expect(await rows(t, "messages")).toHaveLength(0);
  });
});

// ── Review round: ghosts, guardians, poison rows, shims, alerts ─────────────

describe("a user being deleted is admitted nowhere", () => {
  const signUp = (username: string, t: T) =>
    t.mutation(api.auth.signup, {
      username, name: username, passwordHash: "h", recoveryKeyHash: "r", deviceId: `d-${username}`,
    });

  test("addMembership and blockUser refuse a tombstoned user", async () => {
    const t = convexTest(schema);
    const me = await signUp("ada", t);
    const ghost = await mkUser(t, "ghost");
    const room = await mkRoom(t, me.userId as any);
    await join(t, room, me.userId as any, "owner");
    await t.run((ctx) => startUserDeletion(ctx, ghost));
    await t.run(async (ctx) => {
      await expect(addMembership(ctx, room, ghost)).rejects.toThrow("USER_NOT_FOUND");
    });
    await expect(
      t.mutation(api.users.blockUser, { sessionToken: me.token, userId: me.userId as any, targetUserId: ghost } as any),
    ).rejects.toThrow("USER_NOT_FOUND");
    expect(await rows(t, "blocks")).toHaveLength(0);
    expect((await rows(t, "roomMembers")).filter((m) => m.userId === ghost)).toHaveLength(0);
  });

  test("a guardian cannot grant, approve or advance anything for a child being deleted", async () => {
    const t = convexTest(schema);
    const g = await signUp("mum", t);
    const child = await mkUser(t, "kid", { accountType: "child" });
    const room = await mkRoom(t, g.userId as any);
    await join(t, room, g.userId as any, "owner");
    const { approval, invitation } = await t.run(async (ctx) => {
      await ctx.db.insert("guardianships", { guardianId: g.userId as any, childId: child, role: "primary", createdAt: 1 });
      const approval = await ctx.db.insert("approvalRequests", {
        childId: child, kind: "joinRoom", status: "pending", targetRoomId: room, createdAt: 1,
      } as any);
      const invitation = await ctx.db.insert("roomInvitations", {
        roomId: room, inviterId: g.userId as any, inviteeId: child, status: "pending",
        stage: "awaitingRecipientGuardian", createdAt: 1,
      } as any);
      return { approval, invitation };
    });
    await t.run((ctx) => startUserDeletion(ctx, child));
    await expect(
      t.mutation(api.family.grantRoomToChild, { sessionToken: g.token, guardianId: g.userId as any, childId: child, roomId: room } as any),
    ).rejects.toThrow("USER_NOT_FOUND");
    await expect(
      t.mutation(api.family.decideApproval, { sessionToken: g.token, guardianId: g.userId as any, approvalId: approval, approve: true } as any),
    ).rejects.toThrow("REQUEST_NOT_FOUND");
    await expect(
      t.mutation(api.roomInvitations.advance, { sessionToken: g.token, guardianId: g.userId as any, invitationId: invitation, approve: true } as any),
    ).rejects.toThrow("USER_NOT_FOUND");
    expect((await rows(t, "roomMembers")).filter((m) => m.userId === child)).toHaveLength(0);
    expect((await rows(t, "approvalRequests")).filter((r) => r.status === "approved")).toHaveLength(0);
  });
});

describe("LAST_GUARDIAN counts live guardians", () => {
  test("co-guardians cannot both delete; a stuck deletion of one does not block the other while a third remains", async () => {
    const t = convexTest(schema);
    const mk = (name: string) =>
      t.mutation(api.auth.signup, {
        username: name, name, passwordHash: "h", recoveryKeyHash: "r", deviceId: `d-${name}`,
      });
    const a = await mk("ga");
    const b = await mk("gb");
    const child = await mkUser(t, "kid", { accountType: "child" });
    await t.run(async (ctx) => {
      for (const g of [a, b]) {
        await ctx.db.insert("guardianships", { guardianId: g.userId as any, childId: child, role: "guardian", createdAt: 1 });
      }
    });
    // A's deletion starts and its guardianship row is still there (the job has not run).
    await t.mutation(api.auth.deleteAccount, { sessionToken: a.token, userId: a.userId });
    expect((await rows(t, "guardianships")).filter((g) => g.guardianId === a.userId)).toHaveLength(1);
    // B is now the only live guardian: refused, before any write.
    await expect(
      t.mutation(api.auth.deleteAccount, { sessionToken: b.token, userId: b.userId }),
    ).rejects.toThrow(/LAST_GUARDIAN/);
    expect(((await get(t, b.userId)) as any).deletingAt).toBeUndefined();
    await drain(t);
    await expect(
      t.mutation(api.auth.deleteAccount, { sessionToken: b.token, userId: b.userId }),
    ).rejects.toThrow(/LAST_GUARDIAN/);

    // With a third guardian, B may go even while A's job is stuck.
    const c = await mkUser(t, "gc");
    await t.run((ctx) => ctx.db.insert("guardianships", { guardianId: c, childId: child, role: "guardian", createdAt: 1 }));
    await t.mutation(api.auth.deleteAccount, { sessionToken: b.token, userId: b.userId });
    expect(((await get(t, b.userId)) as any).deletingAt).toBeTypeOf("number");
  });
});

describe("poison rows and shrinking budgets", () => {
  const staffAlerts = async (t: T) =>
    (await rows(t, "messages")).filter((m) => typeof m.content === "string" && m.content.startsWith("Deletion job"));

  test("a user message that always throws is skipped, the job finishes, staff are told", async () => {
    const t = convexTest(schema);
    await mkUser(t, "muratcankoc");
    const u = await mkUser(t, "leaver");
    const room = await mkRoom(t, u);
    const o = await mkUser(t, "o");
    await join(t, room, u, "owner");
    await join(t, room, o);
    const m1 = await say(t, room, u, "one");
    const bad = await say(t, room, u, "poison");
    const m3 = await say(t, room, u, "three");
    testHooks.beforeRow = (_ctx, _j, step, rowId) => {
      if (step === "messages" && rowId === bad) throw new Error("poison");
    };
    const jobId = (await t.run((ctx) => startUserDeletion(ctx, u)))!;
    await drain(t);

    const job: any = await get(t, jobId);
    expect(job.state).toBe("done");
    expect(job.skipped).toEqual([bad]);
    expect(await get(t, bad)).not.toBeNull();
    expect(await get(t, m1)).toBeNull();
    expect(await get(t, m3)).toBeNull();
    expect(await get(t, u)).toBeNull();
    const alerts = await staffAlerts(t);
    expect(alerts).toHaveLength(1);
    expect(alerts[0].content).toContain("finished with skipped rows");
    expect(alerts[0].content).toContain(`Skipped rows: ${bad}`);
    expect(alerts[0].content).not.toContain("poison"); // ids only
    expect(console.error).toHaveBeenCalledWith(expect.stringContaining(`row=${bad}`));
  });

  test("a room message that always throws is skipped too, and the room still goes", async () => {
    const t = convexTest(schema);
    await mkUser(t, "muratcankoc");
    const owner = await mkUser(t, "owner");
    const room = await mkRoom(t, owner);
    await join(t, room, owner, "owner");
    const bad = await say(t, room, owner, "poison");
    for (let i = 0; i < 3; i++) await say(t, room, owner, `m${i}`);
    testHooks.beforeRow = (_c, _j, step, rowId) => {
      if (step === "messages" && rowId === bad) throw new Error("poison");
    };
    const jobId = (await t.run((ctx) => startRoomDeletion(ctx, room)))!;
    await drain(t);
    const job: any = await get(t, jobId);
    expect(job.state).toBe("done");
    expect(job.skipped).toEqual([bad]);
    expect(await get(t, room)).toBeNull();
    expect((await rows(t, "messages")).filter((m) => m.roomId === room).map((m) => m._id)).toEqual([bad]);
    expect(await staffAlerts(t)).toHaveLength(1);
  });

  test("a row that fails once and then works is retried, not skipped", async () => {
    const t = convexTest(schema);
    const owner = await mkUser(t, "owner");
    const room = await mkRoom(t, owner);
    const flaky = await say(t, room, owner, "flaky");
    let failed = false;
    testHooks.beforeRow = (_c, _j, step, rowId) => {
      if (step === "messages" && rowId === flaky && !failed) {
        failed = true;
        throw new Error("once");
      }
    };
    const jobId = (await t.run((ctx) => startRoomDeletion(ctx, room)))!;
    await drain(t);
    const job: any = await get(t, jobId);
    expect(job.state).toBe("done");
    expect(job.skipped ?? []).toEqual([]);
    expect(await get(t, flaky)).toBeNull();
  });

  test("each failed attempt halves the budget, down to one row", async () => {
    const t = convexTest(schema);
    const owner = await mkUser(t, "owner");
    const room = await mkRoom(t, owner);
    const seen: number[] = [];
    testHooks.beforeStep = (_c, j, s, b) => {
      if (s.id !== "gates") return;
      seen.push(b.maxWrites);
      if (j.attempts < 4) throw new Error("too big");
    };
    shrinkTuning({ maxWrites: 64 });
    await t.run((ctx) => startRoomDeletion(ctx, room));
    await drain(t);
    expect(seen.slice(0, 5)).toEqual([64, 32, 16, 8, 4]);
    expect(await get(t, room)).toBeNull();
  });
});

describe("shims, alerts, scrub, cursors, orphan sweep", () => {
  test("the shims leave a live account and a live room alone", async () => {
    const t = convexTest(schema);
    const u = await mkUser(t, "alive");
    const room = await mkRoom(t, u);
    await t.mutation(internal.auth.purgeMessagesLater, { userId: u });
    await t.mutation(internal.roomCleanup.wipeMessagesLater, { roomId: room });
    expect(await rows(t, "deletions")).toHaveLength(0);
  });

  test("an alert with nobody to hear it retries hourly, three times, then logs", async () => {
    const t = convexTest(schema);
    const owner = await mkUser(t, "owner"); // not staff: no inbox
    const jobId = await t.run((ctx) =>
      ctx.db.insert("deletions", {
        kind: "room", targetId: "x", state: "failed", stepId: "gates", cursor: null,
        createdAt: 1, lastProgressAt: 1, restarts: 6, attempts: 0, pages: 0, writes: 0,
      }),
    );
    expect(owner).toBeTruthy();
    await t.mutation(internal.deletions.alertFailed, { jobId });
    await drain(t);
    expect(console.error).toHaveBeenCalledWith(expect.stringContaining("undeliverable"));
    expect((console.error as any).mock.calls.filter((c: any[]) => String(c[0]).includes("undeliverable"))).toHaveLength(1);
    expect(await rows(t, "messages")).toHaveLength(0);

    // Staff turn up in time for the second try: it is posted and stops retrying.
    const t2 = convexTest(schema);
    await mkUser(t2, "muratcankoc");
    const job2 = await t2.run((ctx) =>
      ctx.db.insert("deletions", {
        kind: "room", targetId: "y", state: "failed", stepId: "gates", cursor: null,
        createdAt: 1, lastProgressAt: 1, restarts: 6, attempts: 0, pages: 0, writes: 0,
      }),
    );
    await t2.mutation(internal.deletions.alertFailed, { jobId: job2 });
    expect((await rows(t2, "messages")).filter((m) => m.content.startsWith("Deletion job gave up"))).toHaveLength(1);
  });

  test("the ghost keeps accountType and the ban, and nothing that describes the person", async () => {
    const t = convexTest(schema);
    const u = await mkUser(t, "pii", {
      name: "Pat", email: "p@x.com", birthYear: 2012, accountType: "child", suspendedAt: 5,
      visibility: { avatar: "nobody" }, childPolicy: {
        publicRoomsEnabled: false, callsEnabled: false, mediaEnabled: false,
        canRequestContacts: false, canCreateRooms: false,
      }, usernameChangedAt: 3, lastNudgedDayKey: "2026-10-01", termsAcceptedAt: 2, termsVersion: 1,
    });
    await t.run((ctx) => startUserDeletion(ctx, u));
    const g: any = await get(t, u);
    for (const f of ["name", "email", "birthYear", "visibility", "childPolicy", "usernameChangedAt", "lastNudgedDayKey", "termsAcceptedAt", "termsVersion"]) {
      expect(g[f], f).toBeUndefined();
    }
    expect(g.accountType).toBe("child");
    expect(g.suspendedAt).toBe(5);
    expect(g.deletingAt).toBeTypeOf("number");
  });

  test("pageAfter walks rows that share a creation time exactly once", async () => {
    const all = [
      { _id: "a", _creationTime: 1 }, { _id: "b", _creationTime: 2 }, { _id: "c", _creationTime: 2 },
      { _id: "d", _creationTime: 2 }, { _id: "e", _creationTime: 2 }, { _id: "f", _creationTime: 3 },
    ];
    const fetch = async (t: number, k: number) => all.filter((r) => r._creationTime >= t).slice(0, k);
    const got: string[] = [];
    let cursor: string | null = null;
    for (;;) {
      const page = await pageAfter(fetch, cursor, 2);
      if (page.length === 0) break;
      for (const r of page) got.push(r._id);
      cursor = cursorOf(page[page.length - 1]);
    }
    expect(got).toEqual(["a", "b", "c", "d", "e", "f"]);
    // A cursor row that vanished: the rows at its time are seen again, none are lost.
    const again = await pageAfter(fetch, JSON.stringify({ t: 2, id: "gone" }), 10);
    expect(again.map((r) => r._id)).toEqual(["f"]);
  });

  test("the orphan sweep pages itself and hands every orphan room to the engine", async () => {
    const t = convexTest(schema);
    const u = await mkUser(t, "u");
    const orphans: Id<"rooms">[] = [];
    for (let i = 0; i < 3; i++) {
      const r = await mkRoom(t, u);
      await join(t, r, u);
      await say(t, r, u);
      orphans.push(r);
    }
    const live = await mkRoom(t, u);
    await join(t, live, u);
    for (const r of orphans) await t.run((ctx) => ctx.db.delete(r));
    await t.mutation(internal.roomCleanup.gcOrphanedRoomMemberships, {});
    await drain(t);
    expect((await rows(t, "roomMembers")).map((m) => m.roomId)).toEqual([live]);
    expect(await rows(t, "messages")).toHaveLength(0);
    expect((await rows(t, "deletions")).filter((j) => j.reason === "orphan")).toHaveLength(3);
  });
});
