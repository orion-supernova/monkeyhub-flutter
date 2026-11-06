import { convexTest } from "convex-test";
import { afterEach, describe, expect, test, vi } from "vitest";
import { api, internal } from "./_generated/api";
import { hookDb } from "./dbHooks";
import schema from "./schema";
import { drainDeletions } from "./deletionTestUtils";

/**
 * C1 (docs/backend/c1-cursors-design.md): per-room sequence numbers, the
 * `roomUserState` / `roomReceipts` split, exact unread without scans, gap rows,
 * the dual-mode backfill, and the re-run isolation the split exists for.
 *
 * `shadowCompare` is the oracle for unread exactness: it reads the new
 * arithmetic and the old capped scan with the SAME cursor and names any
 * membership where they differ.
 */

type T = ReturnType<typeof convexTest>;

afterEach(() => {
  vi.useRealTimers();
});

async function signUp(t: T, username: string) {
  return await t.mutation(api.auth.signup, {
    username,
    name: username,
    passwordHash: `hash-${username}`,
    recoveryKeyHash: `recovery-${username}`,
    deviceId: `device-${username}`,
  });
}

async function befriend(t: T, a: any, b: any) {
  await t.mutation(api.friends.sendRequest, {
    sessionToken: a.token,
    userId: a.userId as any,
    friendUsername: b.username ?? "bob",
  });
  await t.mutation(api.friends.acceptRequest, {
    sessionToken: b.token,
    userId: b.userId as any,
    requesterId: a.userId as any,
  });
}

async function pair(t: T) {
  const alice = await signUp(t, "alice");
  const bob = await signUp(t, "bob");
  await befriend(t, alice, { ...bob, username: "bob" });
  const roomId = await t.mutation(api.rooms.create, {
    sessionToken: alice.token,
    userId: alice.userId as any,
    name: "room",
    isPrivate: false,
  });
  await t.mutation(api.rooms.join, {
    sessionToken: bob.token,
    userId: bob.userId as any,
    roomId,
  });
  return { alice, bob, roomId };
}

let clock = Date.now() - 10_000_000;
const tick = () => (clock += 10);

/** A message written through the write hooks (seq, sender bookkeeping), like a mutation would. */
async function put(
  t: T,
  roomId: any,
  userId: any,
  extra: Record<string, unknown> = {},
): Promise<any> {
  return await t.run(async (ctx: any) => {
    const db = hookDb(ctx.db);
    const createdAt = (extra.createdAt as number | undefined) ?? tick();
    const id = await db.insert("messages", {
      roomId,
      userId,
      content: "hi",
      type: "text",
      ...extra,
      createdAt,
    });
    const room = await ctx.db.get(roomId);
    await ctx.db.patch(roomId, {
      lastMessageTime: Math.max(room.lastMessageTime ?? 0, createdAt),
    });
    return id;
  });
}

const del = (t: T, id: any) =>
  t.run(async (ctx: any) => {
    await hookDb(ctx.db).delete(id);
  });

const room = (t: T, roomId: any) => t.run((ctx: any) => ctx.db.get(roomId)) as Promise<any>;
const doc = (t: T, id: any) => t.run((ctx: any) => ctx.db.get(id)) as Promise<any>;

async function listFor(t: T, who: any, scope?: "active" | "archived") {
  return (await t.query(api.rooms.listUserRooms, {
    sessionToken: who.token,
    userId: who.userId as any,
    ...(scope ? { scope } : {}),
  } as any)) as any[];
}

async function entry(t: T, who: any, roomId: any) {
  const rows = await listFor(t, who);
  return rows.find((r) => r._id === roomId);
}

const state = (t: T, roomId: any, userId: any) =>
  t.run((ctx: any) =>
    ctx.db
      .query("roomUserState")
      .withIndex("by_room_user", (q: any) => q.eq("roomId", roomId).eq("userId", userId))
      .first(),
  ) as Promise<any>;

const receipt = (t: T, roomId: any, userId: any) =>
  t.run((ctx: any) =>
    ctx.db
      .query("roomReceipts")
      .withIndex("by_room_user", (q: any) => q.eq("roomId", roomId).eq("userId", userId))
      .first(),
  ) as Promise<any>;

const read = (t: T, who: any, roomId: any, upTo?: number) =>
  t.mutation(api.messages.markRoomRead, {
    sessionToken: who.token,
    roomId,
    userId: who.userId as any,
    ...(upTo !== undefined ? { upTo } : {}),
  } as any);

/** Every mismatch between the new unread arithmetic and the old scan. */
async function shadow(t: T): Promise<any[]> {
  const out: any[] = [];
  let cursor: string | null = null;
  for (let i = 0; i < 50; i++) {
    const page: any = await t.query(internal.roomStateMigration.shadowCompare, {
      cursor,
      numItems: 50,
    });
    out.push(...page.mismatches);
    if (page.done) break;
    cursor = page.next;
  }
  return out;
}

/** Every document of the tables a membership touches, for write-set diffs. */
const TABLES = [
  "roomMembers",
  "roomUserState",
  "roomReceipts",
  "receiptMoves",
  "rooms",
  "messages",
  "messageGaps",
] as const;

async function snapshot(t: T) {
  return await t.run(async (ctx: any) => {
    const out: Record<string, Record<string, string>> = {};
    for (const table of TABLES) {
      const rows = await ctx.db.query(table).collect();
      out[table] = Object.fromEntries(rows.map((r: any) => [r._id, JSON.stringify(r)]));
    }
    return out;
  });
}

/** Tables whose documents were inserted, changed or deleted between two snapshots. */
function touched(a: Record<string, Record<string, string>>, b: Record<string, Record<string, string>>) {
  const names: string[] = [];
  for (const table of TABLES) {
    const x = a[table];
    const y = b[table];
    let changed = Object.keys(x).length !== Object.keys(y).length;
    for (const [id, json] of Object.entries(y)) if (x[id] !== json) changed = true;
    if (changed) names.push(table);
  }
  return names;
}

describe("sequence numbers", () => {
  test("a new room is born with lastSeq 0 and each member gets both rows", async () => {
    const t = convexTest(schema);
    const { alice, bob, roomId } = await pair(t);
    expect((await room(t, roomId)).lastSeq).toBe(0);
    for (const who of [alice, bob]) {
      const s = await state(t, roomId, who.userId);
      expect(s).toMatchObject({ readSeq: 0, archived: false });
      const r = await receipt(t, roomId, who.userId);
      expect(r).not.toBeNull();
      expect(typeof r.vanishSeenAt).toBe("number");
    }
  });

  test("send, forward and a vanish line each take the next seq", async () => {
    const t = convexTest(schema);
    const { alice, roomId } = await pair(t);
    const other = await t.mutation(api.rooms.create, {
      sessionToken: alice.token,
      userId: alice.userId as any,
      name: "other",
      isPrivate: false,
    });
    await t.mutation(api.messages.send, {
      sessionToken: alice.token,
      userId: alice.userId as any,
      roomId,
      content: "one",
    });
    await t.mutation(api.messages.send, {
      sessionToken: alice.token,
      userId: alice.userId as any,
      roomId,
      content: "two",
    });
    const msgs = (await t.run((ctx: any) =>
      ctx.db.query("messages").withIndex("by_room_time", (q: any) => q.eq("roomId", roomId)).collect(),
    )) as any[];
    await t.mutation(api.messages.forwardToRoom, {
      sessionToken: alice.token,
      userId: alice.userId as any,
      sourceRoomId: roomId,
      targetRoomId: other,
      messageIds: [msgs[0]._id],
    } as any);
    await t.mutation(api.vanish.setVanishMode, {
      sessionToken: alice.token,
      roomId: other,
      on: true,
    } as any);

    const a = (await t.run((ctx: any) =>
      ctx.db.query("messages").withIndex("by_room_time", (q: any) => q.eq("roomId", roomId)).collect(),
    )) as any[];
    expect(a.map((m) => m.seq)).toEqual([1, 2]);
    const b = (await t.run((ctx: any) =>
      ctx.db.query("messages").withIndex("by_room_time", (q: any) => q.eq("roomId", other)).collect(),
    )) as any[];
    expect(b.map((m) => m.seq)).toEqual([1, 2]);
    expect((await room(t, roomId)).lastSeq).toBe(2);
    expect((await room(t, other)).lastSeq).toBe(2);
  });

  test("seq order follows createdAt order on every sequential insert", async () => {
    const t = convexTest(schema);
    const { alice, roomId } = await pair(t);
    for (let i = 0; i < 6; i++) await put(t, roomId, alice.userId);
    const rows = (await t.run((ctx: any) =>
      ctx.db.query("messages").withIndex("by_room_time", (q: any) => q.eq("roomId", roomId)).collect(),
    )) as any[];
    expect(rows.map((m) => m.seq)).toEqual([1, 2, 3, 4, 5, 6]);
    for (let i = 1; i < rows.length; i++) {
      expect(rows[i].createdAt).toBeGreaterThan(rows[i - 1].createdAt);
    }
  });

  test("markRoomRead tolerates an earlier-stamped message that got the later seq", async () => {
    const t = convexTest(schema);
    const { alice, bob, roomId } = await pair(t);
    const base = tick();
    await put(t, roomId, alice.userId, { createdAt: base + 100 }); // seq 1
    await put(t, roomId, alice.userId, { createdAt: base + 90 }); // seq 2, stamped earlier
    await read(t, bob, roomId, base + 100);
    // Both messages are at or before the cursor: the read position is seq 2.
    expect((await state(t, roomId, bob.userId)).readSeq).toBe(2);
    expect((await entry(t, bob, roomId)).unreadCount).toBe(0);
  });

  test("a room with no lastSeq is left alone by the hook", async () => {
    const t = convexTest(schema);
    const { alice } = await pair(t);
    const legacyRoom = await t.run((ctx: any) =>
      ctx.db.insert("rooms", {
        name: "legacy",
        createdBy: alice.userId,
        createdAt: 1,
        isPrivate: false,
        memberCount: 0,
      }),
    );
    const id = await put(t, legacyRoom, alice.userId);
    expect((await doc(t, id)).seq).toBeUndefined();
    expect((await room(t, legacyRoom)).lastSeq).toBeUndefined();
  });
});

describe("unread is exact", () => {
  test("others' messages count, mine do not, reading clears", async () => {
    const t = convexTest(schema);
    const { alice, bob, roomId } = await pair(t);
    for (let i = 0; i < 3; i++) await put(t, roomId, alice.userId);
    expect((await entry(t, bob, roomId)).unreadCount).toBe(3);
    expect((await entry(t, alice, roomId)).unreadCount).toBe(0);
    const last = (await room(t, roomId)).lastMessageTime;
    await read(t, bob, roomId, last);
    expect((await entry(t, bob, roomId)).unreadCount).toBe(0);
    await put(t, roomId, alice.userId);
    await put(t, roomId, alice.userId);
    expect((await entry(t, bob, roomId)).unreadCount).toBe(2);
    expect(await shadow(t)).toEqual([]);
  });

  test("deleting an unread message lowers the count; deleting a read one does not", async () => {
    const t = convexTest(schema);
    const { alice, bob, roomId } = await pair(t);
    const m1 = await put(t, roomId, alice.userId);
    const m2 = await put(t, roomId, alice.userId);
    await read(t, bob, roomId, (await doc(t, m2)).createdAt);
    const m3 = await put(t, roomId, alice.userId);
    const m4 = await put(t, roomId, alice.userId);
    expect((await entry(t, bob, roomId)).unreadCount).toBe(2);
    await del(t, m1); // already read
    expect((await entry(t, bob, roomId)).unreadCount).toBe(2);
    await del(t, m3); // unread
    expect((await entry(t, bob, roomId)).unreadCount).toBe(1);
    const gaps = (await t.run((ctx: any) => ctx.db.query("messageGaps").collect())) as any[];
    expect(gaps.map((g) => g.seq).sort()).toEqual([1, 3]);
    await del(t, m4);
    expect((await entry(t, bob, roomId)).unreadCount).toBe(0);
    expect(await shadow(t)).toEqual([]);
  });

  test("my own messages interleaved with unread ones never count, deleted or not", async () => {
    const t = convexTest(schema);
    const { alice, bob, roomId } = await pair(t);
    await put(t, roomId, alice.userId); // 1 unread for bob
    const mine1 = await put(t, roomId, bob.userId); // 2 (own run)
    await put(t, roomId, alice.userId); // 3 unread
    await put(t, roomId, bob.userId); // 4 (second run)
    await put(t, roomId, bob.userId); // 5 (extends it)
    expect((await entry(t, bob, roomId)).unreadCount).toBe(2);
    const s = await state(t, roomId, bob.userId);
    expect(s.ownRuns).toEqual([
      { from: 2, to: 2 },
      { from: 4, to: 5 },
    ]);
    await del(t, mine1); // an own message that is also a gap: counted once
    expect((await entry(t, bob, roomId)).unreadCount).toBe(2);
    expect(await shadow(t)).toEqual([]);
  });

  test("a sender who is caught up moves readSeq with each send and keeps no runs", async () => {
    const t = convexTest(schema);
    const { alice, roomId } = await pair(t);
    await put(t, roomId, alice.userId);
    await put(t, roomId, alice.userId);
    const s = await state(t, roomId, alice.userId);
    expect(s.readSeq).toBe(2);
    expect(s.ownRuns).toBeUndefined();
    // seen-by stays honest: the sender's receipts are untouched.
    expect((await receipt(t, roomId, alice.userId)).lastReadAt).toBeUndefined();
    expect(s.readAt).toBeUndefined();
  });

  test("a 9th own run raises ownOverflow instead of moving readSeq; the count stays exact", async () => {
    const t = convexTest(schema);
    const { alice, bob, roomId } = await pair(t);
    for (let i = 0; i < 9; i++) {
      await put(t, roomId, alice.userId);
      await put(t, roomId, bob.userId);
    }
    const s = await state(t, roomId, bob.userId);
    expect(s.ownOverflow).toBe(true);
    expect(s.readSeq).toBe(0);
    expect(s.ownRuns).toBeUndefined();
    expect((await entry(t, bob, roomId)).unreadCount).toBe(9);
    expect(await shadow(t)).toEqual([]);
    // Reading to the newest message proves nothing is left above: cleared.
    await read(t, bob, roomId, (await room(t, roomId)).lastMessageTime);
    const after = await state(t, roomId, bob.userId);
    expect(after.ownOverflow).toBeUndefined();
    expect((await entry(t, bob, roomId)).unreadCount).toBe(0);
  });

  test("99+ is capped and flagged; below it the count is exact", async () => {
    const t = convexTest(schema);
    const { alice, bob, roomId } = await pair(t);
    for (let i = 0; i < 105; i++) await put(t, roomId, alice.userId);
    const e = await entry(t, bob, roomId);
    expect(e.unreadCount).toBe(99);
    expect(e.unreadCapped).toBe(true);
    expect(await shadow(t)).toEqual([]);
  });

  test("100 or more gaps above the cursor fall back to the scan", async () => {
    const t = convexTest(schema);
    const { alice, bob, roomId } = await pair(t);
    const ids: any[] = [];
    for (let i = 0; i < 120; i++) ids.push(await put(t, roomId, alice.userId));
    for (let i = 0; i < 110; i++) await del(t, ids[i]);
    const e = await entry(t, bob, roomId);
    expect(e.unreadCount).toBe(10);
    expect(e.unreadCapped).toBe(false);
    expect(await shadow(t)).toEqual([]);
  });

  test("a cursor older than the gap horizon uses the scan, so an ungapped old delete is not missed", async () => {
    const t = convexTest(schema);
    const { alice, bob, roomId } = await pair(t);
    const day = 24 * 60 * 60 * 1000;
    const longAgo = Date.now() - 400 * day;
    // Bob read the room a year ago; two old messages arrived after, one was deleted.
    const s = await state(t, roomId, bob.userId);
    await t.run((ctx: any) => ctx.db.patch(s._id, { readAt: longAgo - day, readSeq: 0 }));
    const old1 = await put(t, roomId, alice.userId, { createdAt: longAgo });
    await put(t, roomId, alice.userId, { createdAt: longAgo + 1000 });
    await del(t, old1); // older than the horizon: no gap row is written
    const gaps = (await t.run((ctx: any) => ctx.db.query("messageGaps").collect())) as any[];
    expect(gaps).toEqual([]);
    // The arithmetic alone would say 2 - 0 = 2; the scan sees only the survivor.
    expect((await entry(t, bob, roomId)).unreadCount).toBe(1);
    expect(await shadow(t)).toEqual([]);
  });

  test("expiry deletes leave gaps; a view-once burn keeps the row and the count", async () => {
    const t = convexTest(schema);
    const { alice, bob, roomId } = await pair(t);
    const m1 = await put(t, roomId, alice.userId);
    const m2 = await put(t, roomId, alice.userId);
    await t.mutation(internal.messages.expireMessage, { messageId: m1 });
    expect((await entry(t, bob, roomId)).unreadCount).toBe(1);
    await t.mutation(internal.messages.burnViewOnce, { messageId: m2 });
    expect((await doc(t, m2))?._id).toBe(m2);
    expect((await entry(t, bob, roomId)).unreadCount).toBe(1);
    expect(await shadow(t)).toEqual([]);
  });

  test("a mention shows in hasMention until the read position passes it", async () => {
    const t = convexTest(schema);
    const { alice, bob, roomId } = await pair(t);
    const m = await put(t, roomId, alice.userId);
    expect((await entry(t, bob, roomId)).hasMention).toBe(false);
    const at = (await doc(t, m)).createdAt;
    await t.run((ctx: any) =>
      ctx.db.insert("mentionInbox", {
        userId: bob.userId,
        roomId,
        messageId: m,
        createdAt: at,
      }),
    );
    expect((await entry(t, bob, roomId)).hasMention).toBe(true);
    await read(t, bob, roomId, at);
    const after = await entry(t, bob, roomId);
    expect(after.unreadCount).toBe(0);
    expect(after.hasMention).toBe(false);
  });

  test("an @everyone send marks the room instantly for others, never the sender, and clears after read", async () => {
    const t = convexTest(schema);
    const { alice, bob, roomId } = await pair(t);
    await put(t, roomId, alice.userId);
    expect((await entry(t, bob, roomId)).hasMention).toBe(false);
    const m = await put(t, roomId, alice.userId, { mentionsEveryone: true });
    const r = await room(t, roomId);
    expect(r.lastEveryoneSeq).toBe((await doc(t, m)).seq);
    expect(r.lastEveryoneBy).toBe(alice.userId);
    const b = await entry(t, bob, roomId);
    expect(b.unreadCount).toBe(2);
    expect(b.hasMention).toBe(true);
    expect((await entry(t, alice, roomId)).hasMention).toBe(false);
    await read(t, bob, roomId, (await doc(t, m)).createdAt);
    const after = await entry(t, bob, roomId);
    expect(after.unreadCount).toBe(0);
    expect(after.hasMention).toBe(false);
    // A plain message afterwards does not resurrect the old marker.
    await put(t, roomId, alice.userId);
    expect((await entry(t, bob, roomId)).hasMention).toBe(false);
  });

  test("a deleted @everyone message stops marking the room", async () => {
    const t = convexTest(schema);
    const { alice, bob, roomId } = await pair(t);
    await put(t, roomId, alice.userId);
    const m = await put(t, roomId, alice.userId, { mentionsEveryone: true });
    expect((await entry(t, bob, roomId)).hasMention).toBe(true);
    await del(t, m);
    const b = await entry(t, bob, roomId);
    expect(b.unreadCount).toBe(1);
    expect(b.hasMention).toBe(false);
  });

  test("the badge total uses the same arithmetic and skips badge-muted rooms", async () => {
    const t = convexTest(schema);
    const { alice, bob, roomId } = await pair(t);
    await put(t, roomId, alice.userId);
    await put(t, roomId, alice.userId);
    const total = (u: any) =>
      t.run(async (ctx: any) => (await (await import("./badges")).badgeTotalFor(ctx, u)).total);
    expect(await total(bob.userId)).toBe(2);
    await t.mutation(api.rooms.muteRoom, {
      sessionToken: bob.token,
      roomId,
      userId: bob.userId as any,
      notifications: false,
      badges: true,
    } as any);
    expect(await total(bob.userId)).toBe(0);
  });
});

describe("re-run isolation (what each path writes)", () => {
  test("a delivery report writes roomReceipts (and its move) only", async () => {
    const t = convexTest(schema);
    const { alice, bob, roomId } = await pair(t);
    const m = await put(t, roomId, alice.userId);
    const upTo = (await doc(t, m)).createdAt;
    const before = await snapshot(t);
    await t.mutation(api.messages.markRoomDelivered, {
      sessionToken: bob.token,
      roomId,
      userId: bob.userId as any,
      upTo,
    } as any);
    const names = touched(before, await snapshot(t));
    expect(names.sort()).toEqual(["receiptMoves", "roomReceipts"]);
    expect((await receipt(t, roomId, bob.userId)).lastDeliveredAt).toBe(upTo);
    // And the same report again writes nothing.
    const again = await snapshot(t);
    await t.mutation(api.messages.markRoomDelivered, {
      sessionToken: bob.token,
      roomId,
      userId: bob.userId as any,
      upTo,
    } as any);
    expect(touched(again, await snapshot(t))).toEqual([]);
  });

  test("a push-side delivery report writes roomReceipts only", async () => {
    const t = convexTest(schema);
    const { alice, bob, roomId } = await pair(t);
    const m = await put(t, roomId, alice.userId);
    const upTo = (await doc(t, m)).createdAt;
    const before = await snapshot(t);
    await t.mutation(internal.messages.markDeliveredByPush, {
      roomId,
      userId: bob.userId as any,
      upTo,
    });
    expect(touched(before, await snapshot(t)).sort()).toEqual(["receiptMoves", "roomReceipts"]);
  });

  test("pin, archive and mute write the viewer's state row only", async () => {
    const t = convexTest(schema);
    const { bob, roomId } = await pair(t);
    for (const run of [
      () => t.mutation(api.rooms.pinRoom, { sessionToken: bob.token, roomId, userId: bob.userId as any }),
      () => t.mutation(api.rooms.archiveRoom, { sessionToken: bob.token, roomId, userId: bob.userId as any }),
      () =>
        t.mutation(api.rooms.muteRoom, {
          sessionToken: bob.token,
          roomId,
          userId: bob.userId as any,
          notifications: true,
          badges: false,
        } as any),
      () => t.mutation(api.rooms.unarchiveRoom, { sessionToken: bob.token, roomId, userId: bob.userId as any }),
      () => t.mutation(api.rooms.unpinRoom, { sessionToken: bob.token, roomId, userId: bob.userId as any }),
    ]) {
      const before = await snapshot(t);
      await run();
      expect(touched(before, await snapshot(t))).toEqual(["roomUserState"]);
    }
  });

  test("markRoomRead writes state, receipts and moves; never roomMembers or the room", async () => {
    const t = convexTest(schema);
    const { alice, bob, roomId } = await pair(t);
    const m = await put(t, roomId, alice.userId);
    const upTo = (await doc(t, m)).createdAt;
    const before = await snapshot(t);
    await read(t, bob, roomId, upTo);
    const names = touched(before, await snapshot(t));
    expect(names).not.toContain("roomMembers");
    expect(names).not.toContain("rooms");
    expect(names).not.toContain("messages");
    expect(names).toEqual(expect.arrayContaining(["roomUserState", "roomReceipts", "receiptMoves"]));
    const s = await state(t, roomId, bob.userId);
    expect(s).toMatchObject({ readSeq: 1, readAt: upTo });
    const r = await receipt(t, roomId, bob.userId);
    expect(r).toMatchObject({ lastReadAt: upTo, lastDeliveredAt: upTo });
    // Already read: nothing at all.
    const again = await snapshot(t);
    await read(t, bob, roomId, upTo);
    expect(touched(again, await snapshot(t))).toEqual([]);
  });

  test("a send touches no roomMembers row", async () => {
    const t = convexTest(schema);
    const { alice, roomId } = await pair(t);
    const before = await snapshot(t);
    await t.mutation(api.messages.send, {
      sessionToken: alice.token,
      userId: alice.userId as any,
      roomId,
      content: "hello",
    });
    const names = touched(before, await snapshot(t));
    expect(names).not.toContain("roomMembers");
    expect(names).not.toContain("roomReceipts");
  });

  test("read state comes from roomReceipts and keeps its shape", async () => {
    const t = convexTest(schema);
    const { alice, bob, roomId } = await pair(t);
    const m = await put(t, roomId, alice.userId);
    const upTo = (await doc(t, m)).createdAt;
    await read(t, bob, roomId, upTo);
    const rows: any[] = await t.query(api.messages.getReadState, {
      sessionToken: alice.token,
      roomId,
      viewerUserId: alice.userId as any,
    } as any);
    const b = rows.find((r) => r.userId === bob.userId);
    expect(b).toMatchObject({ lastReadAt: upTo, lastDeliveredAt: upTo });
    expect(Object.keys(b).sort()).toEqual(
      ["deliveredClock", "lastDeliveredAt", "lastReadAt", "readClock", "userId"].sort(),
    );
    const times: any[] = await t.query(api.messages.getReceiptTimes, {
      sessionToken: alice.token,
      roomId,
      viewerUserId: alice.userId as any,
      createdAt: upTo,
    } as any);
    expect(times.find((r) => r.userId === bob.userId).readAt).not.toBeNull();
  });
});

describe("membership lifecycle", () => {
  test("a DM's two members carry dmPeerId and the list needs no roster scan", async () => {
    const t = convexTest(schema);
    const alice = await signUp(t, "alice");
    const bob = await signUp(t, "bob");
    await befriend(t, alice, { ...bob, username: "bob" });
    const dm = await t.mutation(api.rooms.getOrCreateDM, {
      sessionToken: alice.token,
      userId: alice.userId as any,
      friendId: bob.userId as any,
    } as any);
    expect((await state(t, dm, alice.userId)).dmPeerId).toBe(bob.userId);
    expect((await state(t, dm, bob.userId)).dmPeerId).toBe(alice.userId);
    const e = await entry(t, alice, dm);
    expect(e.participantIds).toEqual([alice.userId, bob.userId]);
  });

  test("the self chat is born pinned from the state row", async () => {
    const t = convexTest(schema);
    const alice = await signUp(t, "alice");
    const id = await t.mutation(api.rooms.ensureSavedMessagesRoom, {
      sessionToken: alice.token,
      userId: alice.userId as any,
    });
    const s = await state(t, id, alice.userId);
    expect(s.isPinned).toBe(true);
    expect(s.dmPeerId).toBeUndefined();
    const e = await entry(t, alice, id);
    expect(e.isPinned).toBe(true);
    expect(e.participantIds).toEqual([alice.userId]);
  });

  test("leave deletes the state, receipts and moves; a rejoin starts clean", async () => {
    const t = convexTest(schema);
    const { alice, bob, roomId } = await pair(t);
    const m = await put(t, roomId, alice.userId);
    await read(t, bob, roomId, (await doc(t, m)).createdAt);
    expect(await state(t, roomId, bob.userId)).not.toBeNull();
    await t.mutation(api.rooms.leave, {
      sessionToken: bob.token,
      roomId,
      userId: bob.userId as any,
    });
    expect(await state(t, roomId, bob.userId)).toBeNull();
    expect(await receipt(t, roomId, bob.userId)).toBeNull();
    const moves = (await t.run((ctx: any) =>
      ctx.db
        .query("receiptMoves")
        .withIndex("by_user", (q: any) => q.eq("userId", bob.userId))
        .collect(),
    )) as any[];
    expect(moves).toEqual([]);
    await t.mutation(api.rooms.join, {
      sessionToken: bob.token,
      userId: bob.userId as any,
      roomId,
    });
    const fresh = await state(t, roomId, bob.userId);
    expect(fresh.readSeq).toBe(0);
    expect(fresh.readAt).toBeUndefined();
  });

  test("a rejoin does not count the member's own old messages as unread", async () => {
    const t = convexTest(schema);
    const { alice, bob, roomId } = await pair(t);
    await put(t, roomId, bob.userId);
    await put(t, roomId, bob.userId);
    await put(t, roomId, alice.userId);
    await t.mutation(api.rooms.leave, {
      sessionToken: bob.token,
      roomId,
      userId: bob.userId as any,
    });
    await t.mutation(api.rooms.join, {
      sessionToken: bob.token,
      userId: bob.userId as any,
      roomId,
    });
    // Only alice's message counts: bob's two are his own.
    const e = await entry(t, bob, roomId);
    expect(e.unreadCount).toBe(1);
    expect((await state(t, roomId, bob.userId)).ownOverflow).toBe(true);
  });

  test("a kick deletes the target's rows", async () => {
    const t = convexTest(schema);
    const { alice, bob, roomId } = await pair(t);
    await t.mutation(api.roomAdmin.removeMember, {
      sessionToken: alice.token,
      roomId,
      userId: alice.userId as any,
      targetUserId: bob.userId as any,
    } as any);
    expect(await state(t, roomId, bob.userId)).toBeNull();
    expect(await receipt(t, roomId, bob.userId)).toBeNull();
    expect(await state(t, roomId, alice.userId)).not.toBeNull();
  });

  test("account deletion removes the user's rows, and room teardown removes the rest", async () => {
    vi.useFakeTimers();
    const t = convexTest(schema);
    const { alice, bob, roomId } = await pair(t);
    await put(t, roomId, alice.userId);
    const gone = await put(t, roomId, alice.userId);
    await del(t, gone);
    const { startUserDeletion, startRoomDeletion } = await import("./deletionCore");
    await t.run((ctx: any) => startUserDeletion(ctx, bob.userId, { reason: "self" }));
    await drainDeletions(t, vi.runAllTimers);
    expect(await state(t, roomId, bob.userId)).toBeNull();
    expect(await receipt(t, roomId, bob.userId)).toBeNull();
    expect(await state(t, roomId, alice.userId)).not.toBeNull();
    await t.run((ctx: any) => startRoomDeletion(ctx, roomId, { reason: "owner" } as any));
    await drainDeletions(t, vi.runAllTimers);
    for (const table of ["roomUserState", "roomReceipts", "messageGaps", "messages"] as const) {
      const rows = (await t.run((ctx: any) => ctx.db.query(table).collect())) as any[];
      expect(rows.filter((r) => r.roomId === roomId), table).toEqual([]);
    }
  });

  test("tearing a room down writes no gap rows", async () => {
    vi.useFakeTimers();
    const t = convexTest(schema);
    const { alice, roomId } = await pair(t);
    for (let i = 0; i < 3; i++) await put(t, roomId, alice.userId);
    const { startRoomDeletion } = await import("./deletionCore");
    await t.run((ctx: any) => startRoomDeletion(ctx, roomId, { reason: "owner" } as any));
    await drainDeletions(t, vi.runAllTimers);
    const gaps = (await t.run((ctx: any) => ctx.db.query("messageGaps").collect())) as any[];
    expect(gaps).toEqual([]);
  });
});

describe("chat list payload and scope", () => {
  const FROM_JSON = [
    "_id",
    "name",
    "createdBy",
    "createdAt",
    "isPrivate",
    "memberCount",
    "hasPassword",
    "unreadCount",
    "unreadCapped",
    "hasMention",
    "isPinned",
    "isArchived",
    "muteNotifications",
    "muteBadges",
    "participantIds",
    "lastReadAt",
    "lastDeliveredAt",
    "pinnedAt",
    "archivedAt",
    "mutedUntil",
  ];

  test("carries every field ChatRoom.fromJson reads, no password hash, null delivery", async () => {
    const t = convexTest(schema);
    const { alice, bob, roomId } = await pair(t);
    await put(t, roomId, alice.userId);
    const e = await entry(t, bob, roomId);
    for (const k of FROM_JSON) expect(e, k).toHaveProperty(k);
    expect(e).not.toHaveProperty("passwordHash");
    expect(e).not.toHaveProperty("lastSeq");
    expect(e.lastDeliveredAt).toBeNull();
    expect(e.lastReadAt).toBeNull();
    expect(e.hasPassword).toBe(false);
    expect(e.lastMessageTime).toBeGreaterThan(0);
    expect(e.participantIds).toEqual([]);
  });

  test("scope splits active and archived; absent means all; archivedCount counts", async () => {
    const t = convexTest(schema);
    const { bob, roomId } = await pair(t);
    const second = await t.mutation(api.rooms.create, {
      sessionToken: bob.token,
      userId: bob.userId as any,
      name: "second",
      isPrivate: false,
    });
    await t.mutation(api.rooms.archiveRoom, {
      sessionToken: bob.token,
      roomId: second,
      userId: bob.userId as any,
    });
    const ids = (rows: any[]) => rows.map((r) => r._id).sort();
    expect(ids(await listFor(t, bob))).toEqual([roomId, second].sort());
    expect(ids(await listFor(t, bob, "active"))).toEqual([roomId]);
    expect(ids(await listFor(t, bob, "archived"))).toEqual([second]);
    const n = await t.query(api.rooms.archivedCount, {
      sessionToken: bob.token,
      userId: bob.userId as any,
    } as any);
    expect(n).toBe(1);
    expect((await listFor(t, bob)).find((r) => r._id === second).isArchived).toBe(true);
  });
});

describe("backfill", () => {
  /** A pre-C1 world: rooms without lastSeq, messages without seq, cursors on roomMembers. */
  async function legacyWorld(t: T) {
    const alice = await signUp(t, "alice");
    const bob = await signUp(t, "bob");
    const day = 24 * 60 * 60 * 1000;
    const base = Date.now() - 5 * day;
    return await t.run(async (ctx: any) => {
      const roomId = await ctx.db.insert("rooms", {
        name: "old",
        createdBy: alice.userId,
        createdAt: base,
        isPrivate: false,
        memberCount: 2,
        lastMessageTime: base + 60,
      });
      for (const [u, role] of [
        [alice.userId, "owner"],
        [bob.userId, "member"],
      ] as const) {
        await ctx.db.insert("roomMembers", { roomId, userId: u, joinedAt: base, role });
      }
      // Messages: A A B A A A (seq 1..6), bob read through the second.
      const who = [alice, alice, bob, alice, alice, alice];
      const ids: any[] = [];
      for (let i = 0; i < who.length; i++) {
        ids.push(
          await ctx.db.insert("messages", {
            roomId,
            userId: who[i].userId,
            content: `m${i}`,
            createdAt: base + 10 * (i + 1),
            type: "text",
          }),
        );
      }
      const bobRow = await ctx.db
        .query("roomMembers")
        .withIndex("by_room_user", (q: any) => q.eq("roomId", roomId).eq("userId", bob.userId))
        .first();
      await ctx.db.patch(bobRow._id, {
        lastReadAt: base + 20,
        lastDeliveredAt: base + 30,
        isPinned: true,
        pinnedAt: base,
        muteBadges: true,
        mutedUntil: 9_999_999_999_999,
      });
      return { alice, bob, roomId, ids, base };
    });
  }

  const runSeq = async (t: T) => {
    await t.mutation(internal.roomStateMigration.assignSeq, {});
    await t.finishAllScheduledFunctions(vi.runAllTimers);
  };
  const runStates = async (t: T) => {
    const r: any = await t.mutation(internal.roomStateMigration.createStates, {});
    await t.finishAllScheduledFunctions(vi.runAllTimers);
    return r;
  };

  test("assigns seq oldest first, sets lastSeq, and is idempotent", async () => {
    vi.useFakeTimers();
    const t = convexTest(schema);
    const w = await legacyWorld(t);
    await runSeq(t);
    const seqs = await Promise.all(w.ids.map(async (id: any) => (await doc(t, id)).seq));
    expect(seqs).toEqual([1, 2, 3, 4, 5, 6]);
    expect((await room(t, w.roomId)).lastSeq).toBe(6);
    await runSeq(t);
    expect(await Promise.all(w.ids.map(async (id: any) => (await doc(t, id)).seq))).toEqual(seqs);
    expect((await room(t, w.roomId)).lastSeq).toBe(6);
  });

  test("a room bigger than a page continues in its own chain and is numbered completely", async () => {
    vi.useFakeTimers();
    const t = convexTest(schema);
    const alice = await signUp(t, "alice");
    const roomId = await t.run(async (ctx: any) => {
      const id = await ctx.db.insert("rooms", {
        name: "big",
        createdBy: alice.userId,
        createdAt: 1,
        isPrivate: false,
        memberCount: 0,
      });
      for (let i = 0; i < 650; i++) {
        await ctx.db.insert("messages", {
          roomId: id,
          userId: alice.userId,
          content: "x",
          createdAt: 1000 + i,
          type: "text",
        });
      }
      return id;
    });
    await runSeq(t);
    const rows = (await t.run((ctx: any) =>
      ctx.db.query("messages").withIndex("by_room_time", (q: any) => q.eq("roomId", roomId)).collect(),
    )) as any[];
    expect(rows.map((m) => m.seq)).toEqual(Array.from({ length: 650 }, (_, i) => i + 1));
    expect((await room(t, roomId)).lastSeq).toBe(650);
  });

  test("a send that lands before the room is closed is numbered by the final page; after, by the hook", async () => {
    vi.useFakeTimers();
    const t = convexTest(schema);
    const w = await legacyWorld(t);
    // Sent mid-migration: the room has no lastSeq yet, so the hook leaves it unnumbered.
    const late = await put(t, w.roomId, w.alice.userId);
    expect((await doc(t, late)).seq).toBeUndefined();
    await runSeq(t);
    expect((await doc(t, late)).seq).toBe(7);
    expect((await room(t, w.roomId)).lastSeq).toBe(7);
    // After: the hook takes over.
    const after = await put(t, w.roomId, w.alice.userId);
    expect((await doc(t, after)).seq).toBe(8);
    expect((await room(t, w.roomId)).lastSeq).toBe(8);
  });

  test("createStates builds readSeq, own runs and the moved fields; skips unsequenced rooms; is idempotent", async () => {
    vi.useFakeTimers();
    const t = convexTest(schema);
    const w = await legacyWorld(t);
    const waiting: any = await runStates(t);
    expect(waiting.pending).toBe(2); // nothing is sequenced yet
    expect(await state(t, w.roomId, w.bob.userId)).toBeNull();

    await runSeq(t);
    const done: any = await runStates(t);
    expect(done.created).toBe(2);
    const s = await state(t, w.roomId, w.bob.userId);
    expect(s.readSeq).toBe(2);
    expect(s.readAt).toBe(w.base + 20);
    expect(s.ownRuns).toEqual([{ from: 3, to: 3 }]);
    expect(s).toMatchObject({
      isPinned: true,
      pinnedAt: w.base,
      muteBadges: true,
      archived: false,
    });
    const r = await receipt(t, w.roomId, w.bob.userId);
    expect(r).toMatchObject({ lastReadAt: w.base + 20, lastDeliveredAt: w.base + 30 });
    expect(r.vanishSeenAt).toBe(w.base);
    // Alice never read: everything of bob's counts, nothing of hers.
    const a = await state(t, w.roomId, w.alice.userId);
    expect(a.readSeq).toBe(0);
    // 6 messages, 1 is bob's: bob's unread = 3 (m3, m4, m5 are alice's after seq 3...) -> seq 4,5,6
    expect((await entry(t, w.bob, w.roomId)).unreadCount).toBe(3);
    expect((await entry(t, w.alice, w.roomId)).unreadCount).toBe(1);
    expect(await shadow(t)).toEqual([]);

    const before = await snapshot(t);
    const again: any = await runStates(t);
    expect(again.created).toBe(0);
    expect(touched(before, await snapshot(t))).toEqual([]);
  });

  test("a stale legacy cursor that cannot be told falls back, never over-counts own messages", async () => {
    vi.useFakeTimers();
    const t = convexTest(schema);
    const alice = await signUp(t, "alice");
    const bob = await signUp(t, "bob");
    const roomId = await t.run(async (ctx: any) => {
      const id = await ctx.db.insert("rooms", {
        name: "chatty",
        createdBy: alice.userId,
        createdAt: Date.now() - 1000 * 1000,
        isPrivate: false,
        memberCount: 2,
      });
      for (const u of [alice, bob]) {
        await ctx.db.insert("roomMembers", { roomId: id, userId: u.userId, joinedAt: 1, role: "member" });
      }
      // Bob never read; he wrote 9 separate runs between alice's messages.
      for (let i = 0; i < 18; i++) {
        await ctx.db.insert("messages", {
          roomId: id,
          userId: (i % 2 === 0 ? alice : bob).userId,
          content: "x",
          createdAt: Date.now() - 900 * 1000 + i,
          type: "text",
        });
      }
      return id;
    });
    await runSeq(t);
    await runStates(t);
    const s = await state(t, roomId, bob.userId);
    expect(s.ownOverflow).toBe(true);
    expect((await entry(t, bob, roomId)).unreadCount).toBe(9);
    expect(await shadow(t)).toEqual([]);
  });

  test("finish refuses while a membership has no state, then sets the marker", async () => {
    vi.useFakeTimers();
    const t = convexTest(schema);
    const w = await legacyWorld(t);
    await runSeq(t);
    // Rooms are done, memberships are not.
    await t.mutation(internal.roomStateMigration.finish, {});
    await t.finishAllScheduledFunctions(vi.runAllTimers);
    const noMarker = (await t.run((ctx: any) =>
      ctx.db.query("migrationMarkers").collect(),
    )) as any[];
    expect(noMarker.filter((m) => m.name === "roomUserState")).toEqual([]);

    await runStates(t);
    await t.mutation(internal.roomStateMigration.finish, {});
    await t.finishAllScheduledFunctions(vi.runAllTimers);
    const marker = (await t.run((ctx: any) =>
      ctx.db.query("migrationMarkers").collect(),
    )) as any[];
    expect(marker.filter((m) => m.name === "roomUserState")).toHaveLength(1);
    // The list reads state rows only, and still answers.
    expect((await entry(t, w.bob, w.roomId)).unreadCount).toBe(3);
  });
});
