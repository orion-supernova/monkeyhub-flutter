import { convexTest } from "convex-test";
import { afterEach, describe, expect, test, vi } from "vitest";
import { api, internal } from "./_generated/api";
import { RECEIPT_LOG_CAP } from "./receiptLog";
import schema from "./schema";

/**
 * B1/B2/B4/B7 of the backend handbook: receipt history as one row per move,
 * the debounced read-dismissal, receipts that do not read the room, and the
 * merged send bucket.
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

const send = async (t: T, who: any, roomId: any, content: string) => {
  await t.mutation(api.messages.send, {
    sessionToken: who.token,
    userId: who.userId as any,
    roomId,
    content,
  });
  return (await t.run((ctx) => ctx.db.get(roomId)))!.lastMessageTime!;
};

const read = (t: T, who: any, roomId: any, upTo: number) =>
  t.mutation(api.messages.markRoomRead, {
    sessionToken: who.token,
    roomId,
    userId: who.userId as any,
    upTo,
  } as any);

const moves = (t: T, kind?: string) =>
  t.run(async (ctx: any) => {
    const all = await ctx.db.query("receiptMoves").collect();
    return kind ? all.filter((m: any) => m.kind === kind) : all;
  }) as Promise<any[]>;

async function times(t: T, viewer: any, roomId: any, createdAt: number, userId: any) {
  const rows: any[] = await t.query(api.messages.getReceiptTimes, {
    sessionToken: viewer.token,
    roomId,
    viewerUserId: viewer.userId as any,
    createdAt,
  } as any);
  return rows.find((r) => r.userId === userId);
}

async function setPushState(ctx: any, userId: any, devices: any[]) {
  const row = await ctx.db
    .query("userPushState")
    .withIndex("by_user", (q: any) => q.eq("userId", userId))
    .first();
  if (row) await ctx.db.replace(row._id, { userId, devices });
  else await ctx.db.insert("userPushState", { userId, devices });
}

afterEach(() => {
  vi.useRealTimers();
});

describe("receiptMoves", () => {
  test("keeps the newest RECEIPT_LOG_CAP moves and marks the cut as unknown", async () => {
    const t = convexTest(schema);
    const { sender, reader, roomId } = await pair(t);
    const sent = await send(t, sender, roomId, "hi");
    // Drive the writer directly: 250 cursor moves of the same member.
    await t.run(async (ctx: any) => {
      const { appendReceiptMove } = await import("./receipts");
      const m = await ctx.db
        .query("roomMembers")
        .withIndex("by_room_user", (q: any) =>
          q.eq("roomId", roomId).eq("userId", reader.userId),
        )
        .first();
      let before = 0;
      for (let i = 1; i <= 250; i++) {
        await appendReceiptMove(ctx, m, "read", {
          before,
          upTo: i * 10,
          at: 1000 + i,
        });
        before = i * 10;
      }
    });
    const rows = await moves(t, "read");
    expect(rows.length).toBe(RECEIPT_LOG_CAP);
    const sorted = rows.sort((a, b) => a.at - b.at);
    expect(sorted[0].clock).toBe(0); // the cut is unknown, not borrowed
    expect(sorted[sorted.length - 1].at).toBe(2500);
    expect(sorted[sorted.length - 1].clock).toBe(1250);
    void sent;
  });

  test("backfillMoves copies old logs, is idempotent, and sets the marker", async () => {
    vi.useFakeTimers();
    const t = convexTest(schema);
    const { sender, reader, roomId } = await pair(t);
    const sent = await send(t, sender, roomId, "hi");
    const row: any = await t.run((ctx: any) =>
      ctx.db
        .query("roomMembers")
        .withIndex("by_room_user", (q: any) =>
          q.eq("roomId", roomId).eq("userId", reader.userId),
        )
        .first(),
    );
    await t.run(async (ctx: any) => {
      await ctx.db.patch(row._id, { lastReadAt: sent, lastDeliveredAt: sent });
      await ctx.db.insert("receiptLogs", {
        roomId,
        userId: reader.userId,
        kind: "read",
        entries: [{ upTo: sent, at: 4242 }],
      });
    });
    // Before the backfill, readers fall back to the old log.
    expect((await times(t, sender, roomId, sent, reader.userId)).readAt).toBe(4242);

    const first = await t.mutation(internal.receipts.backfillMoves, {});
    await t.finishAllScheduledFunctions(vi.runAllTimers);
    expect(first.done).toBe(true);
    expect(await moves(t)).toHaveLength(1);
    const again = await t.mutation(internal.receipts.backfillMoves, {});
    expect(again.copied).toBe(0);
    expect(await moves(t)).toHaveLength(1);
    const markers = await t.run((ctx: any) => ctx.db.query("migrationMarkers").collect());
    expect(markers).toHaveLength(1);
    expect((await times(t, sender, roomId, sent, reader.userId)).readAt).toBe(4242);
  });

  test("a first move after deploy carries the old history over", async () => {
    vi.useFakeTimers({ toFake: ["Date"] });
    vi.setSystemTime(Date.parse("2026-10-07T10:00:00Z"));
    const t = convexTest(schema);
    const { sender, reader, roomId } = await pair(t);
    const first = await send(t, sender, roomId, "one");
    const row: any = await t.run((ctx: any) =>
      ctx.db
        .query("roomMembers")
        .withIndex("by_room_user", (q: any) =>
          q.eq("roomId", roomId).eq("userId", reader.userId),
        )
        .first(),
    );
    await t.run(async (ctx: any) => {
      await ctx.db.patch(row._id, { lastReadAt: first, lastDeliveredAt: first });
      await ctx.db.insert("receiptLogs", {
        roomId,
        userId: reader.userId,
        kind: "read",
        entries: [{ upTo: first, at: 4242 }],
      });
    });
    vi.setSystemTime(Date.parse("2026-10-07T10:05:00Z"));
    const second = await send(t, sender, roomId, "two");
    await read(t, reader, roomId, second);
    expect((await times(t, sender, roomId, first, reader.userId)).readAt).toBe(4242);
    expect((await times(t, sender, roomId, second, reader.userId)).readAt).toBe(
      Date.parse("2026-10-07T10:05:00Z"),
    );
    expect(await t.run((ctx: any) => ctx.db.query("receiptLogs").collect())).toHaveLength(0);
  });
});

describe("delivery receipts", () => {
  test("a report that does not move the cursor writes nothing", async () => {
    const t = convexTest(schema);
    const { sender, reader, roomId } = await pair(t);
    const sent = await send(t, sender, roomId, "hi");
    const report = () =>
      t.mutation(api.messages.markRoomDelivered, {
        sessionToken: reader.token,
        roomId,
        userId: reader.userId as any,
        upTo: sent,
      } as any);
    await report();
    const before = await moves(t);
    await report();
    expect(await moves(t)).toEqual(before);
  });
});

describe("send bucket", () => {
  test("one row per user, limits unchanged", async () => {
    const t = convexTest(schema);
    const { sender, roomId } = await pair(t);
    for (let i = 0; i < 30; i++) await send(t, sender, roomId, `m${i}`);
    const rows: any[] = await t.run((ctx: any) => ctx.db.query("sendBuckets").collect());
    expect(rows).toHaveLength(1);
    expect(rows[0].shortCount).toBe(30);
    expect(rows[0].hourCount).toBe(30);
    await expect(send(t, sender, roomId, "one too many")).rejects.toThrow(/RATE_LIMITED/);
  });
});

describe("read dismissal", () => {
  async function setup(t: T) {
    const p = await pair(t);
    // A second push-reachable device for the reader.
    await t.run(async (ctx: any) => {
      await setPushState(ctx, p.reader.userId, [
          { deviceRowId: "a", deviceId: "device-reader", platform: "ios", apnsToken: "x" },
          { deviceRowId: "b", deviceId: "other", platform: "macos", apnsToken: "y" },
      ]);
    });
    return p;
  }
  const pending = (t: T): Promise<any[]> => t.run((ctx: any) => ctx.db.query("dismissPending").collect());

  test("a burst of reads opens one window and one trailing flag", async () => {
    const t = convexTest(schema);
    const { sender, reader, roomId } = await setup(t);
    for (let i = 0; i < 3; i++) {
      const sent = await send(t, sender, roomId, `m${i}`);
      await read(t, reader, roomId, sent);
    }
    const rows: any[] = await pending(t);
    expect(rows).toHaveLength(1);
    expect(rows[0].trailing).toBe(true);
  });

  test("no other device: nothing is scheduled", async () => {
    const t = convexTest(schema);
    const { sender, reader, roomId } = await pair(t);
    await t.run(async (ctx: any) => {
      await setPushState(ctx, reader.userId, [
        { deviceRowId: "a", deviceId: "device-reader", platform: "ios", apnsToken: "x" },
      ]);
    });
    const sent = await send(t, sender, roomId, "hi");
    await read(t, reader, roomId, sent);
    expect(await pending(t)).toHaveLength(0);
  });
});
