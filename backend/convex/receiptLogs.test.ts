import { convexTest } from "convex-test";
import { afterEach, beforeEach, describe, expect, test, vi } from "vitest";
import { api, internal } from "./_generated/api";
import { startRoomDeletion, startUserDeletion } from "./deletionCore";
import { drainDeletions, shrinkTuning } from "./deletionTestUtils";
import schema from "./schema";

/**
 * Receipt cursors live on `roomReceipts` and their history in `receiptMoves`,
 * never on `roomMembers`: the same receipts, a membership row that stays a
 * bare roster row, a re-stamp fan-out that pages, and cleanup with the room
 * and the user.
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
      .query("roomReceipts")
      .withIndex("by_room_user", (q: any) => q.eq("roomId", roomId).eq("userId", userId))
      .first(),
  ) as Promise<any>;

const moveRows = (t: T) => t.run((ctx: any) => ctx.db.query("receiptMoves").collect()) as Promise<any[]>;

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
  test("a read writes receiptMoves and the receipt row, and leaves the roster row bare", async () => {
    vi.useFakeTimers({ toFake: ["Date"] });
    vi.setSystemTime(at("2026-10-07T10:00:00Z"));
    const t = convexTest(schema);
    const { sender, reader, roomId } = await pair(t);
    const sent = await send(t, sender, roomId, "hi");
    vi.setSystemTime(at("2026-10-07T10:00:09Z"));
    await read(t, reader, roomId, sent);

    const row = await member(t, roomId, reader.userId);
    expect(row.lastReadAt).toBe(sent);
    const roster: any = await t.run((ctx: any) =>
      ctx.db
        .query("roomMembers")
        .withIndex("by_room_user", (q: any) => q.eq("roomId", roomId).eq("userId", reader.userId))
        .first(),
    );
    expect(Object.keys(roster).sort()).toEqual(
      ["_creationTime", "_id", "joinedAt", "role", "roomId", "userId"].sort(),
    );
    const logs = await moveRows(t);
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
    expect((await moveRows(t)).map((l) => l.kind)).toEqual(["delivered"]);
  });
});

describe("getReadState on a big room", () => {
  test("1,000 members: small receipt rows, same answer", async () => {
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
        await ctx.db.insert("roomMembers", { roomId, userId: u, role: "member", joinedAt: 1 });
        await ctx.db.insert("roomReceipts", {
          roomId,
          userId: u,
          lastReadAt: sent,
          lastDeliveredAt: sent,
          vanishSeenAt: 1,
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
    const receipts: any[] = await t.run((ctx: any) =>
      ctx.db
        .query("roomReceipts")
        .withIndex("by_room_user", (q: any) => q.eq("roomId", roomId))
        .collect(),
    );
    expect(receipts.length).toBe(1000);
    for (const m of receipts) expect(JSON.stringify(m).length).toBeLessThan(700);
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
        await ctx.db.insert("roomReceipts", {
          roomId: room,
          userId: reader.userId,
          vanishSeenAt: 1,
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
        .query("roomReceipts")
        .withIndex("by_user", (q: any) => q.eq("userId", reader.userId))
        .collect(),
    );
    expect(rows.length).toBeGreaterThan(130);
    expect(rows.every((m: any) => m.seenVisibility === "nobody")).toBe(true);
  }, 20_000); // 130 rooms (just past one 100-row page): ~2 s alone, slower under suite load
});

describe("deletion cleans receiptMoves", () => {
  beforeEach(() => {
    vi.useFakeTimers();
    // Pages through hundreds of memberships: slow on a loaded machine.
  }, 30_000);
  const restore: Array<() => void> = [];
  afterEach(() => restore.splice(0).forEach((f) => f()));

  async function withLogs(t: T) {
    restore.push(shrinkTuning());
    const { sender, reader, roomId } = await pair(t);
    const sent = await send(t, sender, roomId, "hi");
    await read(t, reader, roomId, sent);
    expect((await moveRows(t)).length).toBe(2);
    return { reader, roomId };
  }

  test("room deletion", async () => {
    const t = convexTest(schema);
    const { roomId } = await withLogs(t);
    await t.run((ctx) => startRoomDeletion(ctx, roomId));
    await drainDeletions(t, vi.runAllTimers);
    expect(await moveRows(t)).toHaveLength(0);
  });

  test("user deletion", async () => {
    const t = convexTest(schema);
    const { reader } = await withLogs(t);
    await t.run((ctx) => startUserDeletion(ctx, reader.userId as any));
    await drainDeletions(t, vi.runAllTimers);
    expect(await moveRows(t)).toHaveLength(0);
  });
});
