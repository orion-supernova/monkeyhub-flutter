import { convexTest } from "convex-test";
import { afterEach, beforeEach, describe, expect, test, vi } from "vitest";
import { api, internal } from "./_generated/api";
import { startRoomDeletion, startUserDeletion } from "./deletionCore";
import { drainDeletions, shrinkTuning } from "./deletionTestUtils";
import schema from "./schema";

/**
 * Receipt logs live in `receiptLogs`, not on `roomMembers` (plan 4C): the same
 * receipts, a membership row that stays small, dual-read of rows from before
 * the move, a paged idempotent backfill, and cleanup with the room and user.
 */

type T = ReturnType<typeof convexTest>;

async function signUp(t: T, username: string) {
  return await t.mutation(api.auth.signup, {
    username,
    name: username,
    passwordHash: `hash-${username}`,
    recoveryKeyHash: `recovery-${username}`,
    deviceId: `device-${username}`,
  });
}

async function pair(t: T) {
  const sender = await signUp(t, "sender");
  const reader = await signUp(t, "reader");
  await t.mutation(api.friends.sendRequest, {
    sessionToken: sender.token,
    userId: sender.userId as any,
    friendUsername: "reader",
  });
  await t.mutation(api.friends.acceptRequest, {
    sessionToken: reader.token,
    userId: reader.userId as any,
    requesterId: sender.userId as any,
  });
  const roomId = await t.mutation(api.rooms.create, {
    sessionToken: sender.token,
    userId: sender.userId as any,
    name: "room",
    isPrivate: false,
  });
  await t.mutation(api.rooms.join, {
    sessionToken: reader.token,
    userId: reader.userId as any,
    roomId,
  });
  return { sender, reader, roomId };
}

async function send(t: T, who: any, roomId: any, content: string): Promise<number> {
  await t.mutation(api.messages.send, {
    sessionToken: who.token,
    userId: who.userId as any,
    roomId,
    content,
  });
  return (await t.run((ctx) => ctx.db.get(roomId)))!.lastMessageTime!;
}

const member = (t: T, roomId: any, userId: any) =>
  t.run((ctx: any) =>
    ctx.db
      .query("roomMembers")
      .withIndex("by_room_user", (q: any) => q.eq("roomId", roomId).eq("userId", userId))
      .first(),
  ) as Promise<any>;

const logRows = (t: T) => t.run((ctx: any) => ctx.db.query("receiptLogs").collect()) as Promise<any[]>;

async function times(t: T, viewer: any, roomId: any, createdAt: number, userId: any) {
  const rows: any[] = await t.query(api.messages.getReceiptTimes, {
    sessionToken: viewer.token,
    roomId,
    viewerUserId: viewer.userId as any,
    createdAt,
  } as any);
  return rows.find((r) => r.userId === userId);
}

const read = (t: T, who: any, roomId: any, upTo: number) =>
  t.mutation(api.messages.markRoomRead, {
    sessionToken: who.token,
    roomId,
    userId: who.userId as any,
    upTo,
  } as any);

const at = (iso: string) => Date.parse(iso);

afterEach(() => {
  vi.useRealTimers();
});

describe("writers", () => {
  test("a read writes receiptLogs and leaves the member row log-free", async () => {
    vi.useFakeTimers({ toFake: ["Date"] });
    vi.setSystemTime(at("2026-10-07T10:00:00Z"));
    const t = convexTest(schema);
    const { sender, reader, roomId } = await pair(t);
    const sent = await send(t, sender, roomId, "hi");
    vi.setSystemTime(at("2026-10-07T10:00:09Z"));
    await read(t, reader, roomId, sent);

    const row = await member(t, roomId, reader.userId);
    expect(row.readLog).toBeUndefined();
    expect(row.deliveredLog).toBeUndefined();
    expect(row.lastReadAt).toBe(sent);
    const logs = await logRows(t);
    expect(logs.map((l) => l.kind).sort()).toEqual(["delivered", "read"]);

    // Seen-by is unchanged.
    const r = await times(t, sender, roomId, sent, reader.userId);
    expect(r.readAt).toBe(at("2026-10-07T10:00:09Z"));
    expect(r.deliveredAt).toBe(at("2026-10-07T10:00:09Z"));
  });

  test("a delivery report writes only the delivered log", async () => {
    const t = convexTest(schema);
    const { sender, reader, roomId } = await pair(t);
    const sent = await send(t, sender, roomId, "hi");
    await t.mutation(api.messages.markRoomDelivered, {
      sessionToken: reader.token,
      roomId,
      userId: reader.userId as any,
      upTo: sent,
    } as any);
    expect((await logRows(t)).map((l) => l.kind)).toEqual(["delivered"]);
    expect((await member(t, roomId, reader.userId)).deliveredLog).toBeUndefined();
  });

  test("a stale log from an earlier stay is not spliced onto", async () => {
    vi.useFakeTimers({ toFake: ["Date"] });
    vi.setSystemTime(at("2026-10-07T10:00:00Z"));
    const t = convexTest(schema);
    const { sender, reader, roomId } = await pair(t);
    const sent = await send(t, sender, roomId, "hi");
    await t.run((ctx: any) =>
      ctx.db.insert("receiptLogs", {
        roomId,
        userId: reader.userId,
        kind: "read",
        entries: [{ upTo: sent + 9_999_999, at: 5 }],
      }),
    );
    vi.setSystemTime(at("2026-10-07T10:00:09Z"));
    await read(t, reader, roomId, sent);
    const r = await times(t, sender, roomId, sent, reader.userId);
    expect(r.readAt).toBe(at("2026-10-07T10:00:09Z"));
  });
});

describe("dual read of rows from before the move", () => {
  test("getReceiptTimes falls back to the member row's log", async () => {
    const t = convexTest(schema);
    const { sender, reader, roomId } = await pair(t);
    const sent = await send(t, sender, roomId, "hi");
    const row = await member(t, roomId, reader.userId);
    await t.run((ctx: any) =>
      ctx.db.patch(row._id, {
        lastReadAt: sent,
        lastDeliveredAt: sent,
        readLog: [{ upTo: sent, at: 7777 }],
        deliveredLog: [{ upTo: sent, at: 5555 }],
      }),
    );
    const r = await times(t, sender, roomId, sent, reader.userId);
    expect(r.readAt).toBe(7777);
    expect(r.deliveredAt).toBe(5555);
  });

  test("the first write moves the legacy log out and keeps its history", async () => {
    vi.useFakeTimers({ toFake: ["Date"] });
    vi.setSystemTime(at("2026-10-07T10:00:00Z"));
    const t = convexTest(schema);
    const { sender, reader, roomId } = await pair(t);
    const first = await send(t, sender, roomId, "one");
    const row = await member(t, roomId, reader.userId);
    await t.run((ctx: any) =>
      ctx.db.patch(row._id, {
        lastReadAt: first,
        lastDeliveredAt: first,
        readLog: [{ upTo: first, at: 7777 }],
        deliveredLog: [{ upTo: first, at: 5555 }],
      }),
    );
    vi.setSystemTime(at("2026-10-07T10:05:00Z"));
    const second = await send(t, sender, roomId, "two");
    vi.setSystemTime(at("2026-10-07T10:05:09Z"));
    await read(t, reader, roomId, second);

    const after = await member(t, roomId, reader.userId);
    expect(after.readLog).toBeUndefined();
    expect(after.deliveredLog).toBeUndefined();
    // Old message keeps its legacy time, new one gets the new time.
    expect((await times(t, sender, roomId, first, reader.userId)).readAt).toBe(7777);
    expect((await times(t, sender, roomId, second, reader.userId)).readAt).toBe(
      at("2026-10-07T10:05:09Z"),
    );
  });
});

describe("receipts:moveLogs", () => {
  async function seedLegacy(t: T, n: number) {
    const { sender, reader, roomId } = await pair(t);
    const sent = await send(t, sender, roomId, "hi");
    const rows: any[] = await t.run((ctx: any) => ctx.db.query("roomMembers").collect());
    for (const m of rows.slice(0, n)) {
      await t.run((ctx: any) =>
        ctx.db.patch(m._id, {
          lastReadAt: sent,
          lastDeliveredAt: sent,
          readLog: [{ upTo: sent, at: 11 }],
          deliveredLog: [{ upTo: sent, at: 22 }],
        }),
      );
    }
    return { sender, reader, roomId, sent, count: Math.min(n, rows.length) };
  }

  test("pages, moves everything, and is idempotent", async () => {
    vi.useFakeTimers();
    const t = convexTest(schema);
    const { sender, reader, roomId, sent, count } = await seedLegacy(t, 2);
    expect(count).toBe(2);
    const first = await t.mutation(internal.receipts.moveLogs, { batchSize: 1 });
    expect(first.done).toBe(false);
    await t.finishAllScheduledFunctions(vi.runAllTimers);

    const members: any[] = await t.run((ctx: any) => ctx.db.query("roomMembers").collect());
    for (const m of members) {
      expect(m.readLog).toBeUndefined();
      expect(m.deliveredLog).toBeUndefined();
    }
    expect(await logRows(t)).toHaveLength(4);
    expect((await times(t, sender, roomId, sent, reader.userId)).readAt).toBe(11);

    const again = await t.mutation(internal.receipts.moveLogs, {});
    await t.finishAllScheduledFunctions(vi.runAllTimers);
    expect(again.moved).toBe(0);
    expect(await logRows(t)).toHaveLength(4);
  });

  test("an existing receiptLogs row wins over the legacy field", async () => {
    const t = convexTest(schema);
    const { reader, roomId, sent } = await seedLegacy(t, 2);
    await t.run((ctx: any) =>
      ctx.db.insert("receiptLogs", {
        roomId,
        userId: reader.userId,
        kind: "read",
        entries: [{ upTo: sent, at: 99 }],
      }),
    );
    await t.mutation(internal.receipts.moveLogs, { batchSize: 100 });
    const reads = (await logRows(t)).filter(
      (l) => l.kind === "read" && l.userId === reader.userId,
    );
    expect(reads).toHaveLength(1);
    expect(reads[0].entries[0].at).toBe(99);
  });
});

describe("getReadState on a big room", () => {
  test("1,000 members: small rows, no logs, same answer", async () => {
    const t = convexTest(schema);
    const { sender, reader, roomId } = await pair(t);
    const sent = await send(t, sender, roomId, "hi");
    // 998 more members, seeded straight in.
    await t.run(async (ctx: any) => {
      for (let i = 0; i < 998; i++) {
        const u = await ctx.db.insert("users", {
          username: `u${i}`,
          passwordHash: "x",
          createdAt: 1,
        });
        await ctx.db.insert("roomMembers", {
          roomId,
          userId: u,
          role: "member",
          joinedAt: 1,
          lastReadAt: sent,
          lastDeliveredAt: sent,
        });
      }
    });
    await read(t, reader, roomId, sent);
    const state: any[] = await t.query(api.messages.getReadState, {
      sessionToken: sender.token,
      roomId,
      viewerUserId: sender.userId as any,
    } as any);
    expect(state.length).toBeGreaterThan(0);
    const members: any[] = await t.run((ctx: any) =>
      ctx.db
        .query("roomMembers")
        .withIndex("by_room_user", (q: any) => q.eq("roomId", roomId))
        .collect(),
    );
    expect(members.length).toBe(1000);
    for (const m of members) {
      expect(m.readLog).toBeUndefined();
      expect(m.deliveredLog).toBeUndefined();
      expect(JSON.stringify(m).length).toBeLessThan(700);
    }
  });
});

describe("seenVisibility fan-out", () => {
  test("is stamped on every membership, paged past the first page", async () => {
    vi.useFakeTimers();
    const t = convexTest(schema);
    const { reader } = await pair(t);
    await t.run(async (ctx: any) => {
      for (let i = 0; i < 130; i++) {
        const room = await ctx.db.insert("rooms", {
          name: `r${i}`,
          createdBy: reader.userId,
          isPrivate: false,
          memberCount: 1,
          createdAt: 1,
        } as any);
        await ctx.db.insert("roomMembers", {
          roomId: room,
          userId: reader.userId,
          role: "member",
          joinedAt: 1,
        });
      }
    });
    await t.mutation(api.users.updateVisibility, {
      sessionToken: reader.token,
      userId: reader.userId as any,
      seen: "nobody",
    } as any);
    await t.finishAllScheduledFunctions(vi.runAllTimers);
    const rows: any[] = await t.run((ctx: any) =>
      ctx.db
        .query("roomMembers")
        .withIndex("by_user", (q: any) => q.eq("userId", reader.userId))
        .collect(),
    );
    expect(rows.length).toBeGreaterThan(130);
    expect(rows.every((m: any) => m.seenVisibility === "nobody")).toBe(true);
  }, 20_000); // 130 rooms (just past one 100-row page): ~2 s alone, slower under suite load
});

describe("deletion cleans receiptLogs", () => {
  beforeEach(() => {
    vi.useFakeTimers();
  });
  const restore: Array<() => void> = [];
  afterEach(() => restore.splice(0).forEach((f) => f()));

  async function withLogs(t: T) {
    restore.push(shrinkTuning());
    const { sender, reader, roomId } = await pair(t);
    const sent = await send(t, sender, roomId, "hi");
    await read(t, reader, roomId, sent);
    expect((await logRows(t)).length).toBe(2);
    return { reader, roomId };
  }

  test("room deletion", async () => {
    const t = convexTest(schema);
    const { roomId } = await withLogs(t);
    await t.run((ctx) => startRoomDeletion(ctx, roomId));
    await drainDeletions(t, vi.runAllTimers);
    expect(await logRows(t)).toHaveLength(0);
  });

  test("user deletion", async () => {
    const t = convexTest(schema);
    const { reader } = await withLogs(t);
    await t.run((ctx) => startUserDeletion(ctx, reader.userId as any));
    await drainDeletions(t, vi.runAllTimers);
    expect(await logRows(t)).toHaveLength(0);
  });
});
