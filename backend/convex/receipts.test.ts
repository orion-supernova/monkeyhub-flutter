import { convexTest } from "convex-test";
import { afterEach, describe, expect, test, vi } from "vitest";
import { api } from "./_generated/api";
import type { Id } from "./_generated/dataModel";
import {
  RECEIPT_LOG_CAP,
  appendReceiptLog,
  receiptTimeFor,
} from "./receiptLog";
import { receiptEndpoint, receiptFields } from "./receiptToken";
import schema from "./schema";

/**
 * Per-message receipt times, and delivery reported by the push itself.
 *
 * The bug these pin (2026-10-07, muratcankoc → zeynepoz): "aaa" was sent at
 * 23:17 and delivered at 23:17, "df" followed at 23:18, and when both were
 * read at 23:18 the info screen for "aaa" said delivered 23:18. The one
 * wall-clock stamp per cursor had been overwritten by the later move.
 */

async function signUp(t: ReturnType<typeof convexTest>, username: string) {
  return await t.mutation(api.auth.signup, {
    username,
    name: username,
    passwordHash: `hash-${username}`,
    recoveryKeyHash: `recovery-${username}`,
    deviceId: `device-${username}`,
  });
}

/** Sender and recipient, friends (receipts default to friends), one room. */
async function pair(t: ReturnType<typeof convexTest>) {
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

async function send(
  t: ReturnType<typeof convexTest>,
  who: { token: string; userId: string },
  roomId: any,
  content: string,
): Promise<number> {
  await t.mutation(api.messages.send, {
    sessionToken: who.token,
    userId: who.userId as any,
    roomId,
    content,
  });
  return (await t.run((ctx) => ctx.db.get(roomId as Id<"rooms">)))!
    .lastMessageTime!;
}

async function timesFor(
  t: ReturnType<typeof convexTest>,
  viewer: { token: string; userId: string },
  roomId: any,
  createdAt: number,
) {
  const rows: any[] = await t.query(api.messages.getReceiptTimes, {
    sessionToken: viewer.token,
    roomId,
    viewerUserId: viewer.userId as any,
    createdAt,
  } as any);
  return rows;
}

async function readerRow(t: ReturnType<typeof convexTest>, roomId: any, userId: any) {
  return await t.run((ctx: any) =>
    ctx.db
      .query("roomMembers")
      .withIndex("by_room_user", (q: any) =>
        q.eq("roomId", roomId).eq("userId", userId)
      )
      .first()
  ) as any;
}

const at = (iso: string) => Date.parse(iso);

afterEach(() => {
  vi.useRealTimers();
  vi.unstubAllEnvs();
});

describe("receipt log", () => {
  test("a message takes the time of the first move that covered it", () => {
    let log = appendReceiptLog(undefined, 0, 100, 1000);
    log = appendReceiptLog(log, 100, 200, 2000);
    expect(receiptTimeFor(log, 50)).toBe(1000);
    expect(receiptTimeFor(log, 100)).toBe(1000);
    expect(receiptTimeFor(log, 150)).toBe(2000);
    expect(receiptTimeFor(log, 201)).toBeNull();
  });

  test("where the cursor stood before the log began has no time", () => {
    const log = appendReceiptLog(undefined, 100, 200, 2000);
    expect(receiptTimeFor(log, 90)).toBeNull();
    expect(receiptTimeFor(log, 150)).toBe(2000);
  });

  test("a full log trims from the front and leaves the trimmed run unknown", () => {
    let log: any[] | undefined;
    for (let i = 1; i <= RECEIPT_LOG_CAP + 10; i++) {
      log = appendReceiptLog(log, (i - 1) * 10, i * 10, i * 1000);
    }
    expect(log!.length).toBe(RECEIPT_LOG_CAP);
    expect(receiptTimeFor(log, 10)).toBeNull();
    const last = RECEIPT_LOG_CAP + 10;
    expect(receiptTimeFor(log, last * 10)).toBe(last * 1000);
    // The oldest entry still known keeps its own time, not the gap's.
    const oldestKnown = log![1];
    expect(receiptTimeFor(log, oldestKnown.upTo)).toBe(oldestKnown.at);
  });
});

describe("each message keeps its own delivered and read time", () => {
  test("a later read does not rewrite an earlier delivery", async () => {
    vi.useFakeTimers({ toFake: ["Date"] });
    vi.setSystemTime(at("2026-10-07T23:17:00Z"));
    const t = convexTest(schema);
    const { sender, reader, roomId } = await pair(t);

    const aaa = await send(t, sender, roomId, "aaa");
    vi.setSystemTime(at("2026-10-07T23:17:20Z"));
    await t.mutation(api.messages.markRoomDelivered, {
      sessionToken: reader.token,
      roomId,
      userId: reader.userId as any,
      upTo: aaa,
    } as any);

    vi.setSystemTime(at("2026-10-07T23:18:07Z"));
    const df = await send(t, sender, roomId, "df");
    vi.setSystemTime(at("2026-10-07T23:18:32Z"));
    await t.mutation(api.messages.markRoomRead, {
      sessionToken: reader.token,
      roomId,
      userId: reader.userId as any,
      upTo: df,
    } as any);

    const forAaa = (await timesFor(t, sender, roomId, aaa)).find(
      (r) => r.userId === reader.userId,
    );
    expect(forAaa.deliveredAt).toBe(at("2026-10-07T23:17:20Z"));
    expect(forAaa.readAt).toBe(at("2026-10-07T23:18:32Z"));

    const forDf = (await timesFor(t, sender, roomId, df)).find(
      (r) => r.userId === reader.userId,
    );
    expect(forDf.deliveredAt).toBe(at("2026-10-07T23:18:32Z"));
    expect(forDf.readAt).toBe(at("2026-10-07T23:18:32Z"));
  });

  test("a message not reached yet has no times", async () => {
    const t = convexTest(schema);
    const { sender, reader, roomId } = await pair(t);
    const sent = await send(t, sender, roomId, "hi");
    const row = (await timesFor(t, sender, roomId, sent)).find(
      (r) => r.userId === reader.userId,
    );
    expect(row.deliveredAt).toBeNull();
    expect(row.readAt).toBeNull();
  });

  test("a stranger's receipt times are not served", async () => {
    const t = convexTest(schema);
    const owner = await signUp(t, "owner");
    const stranger = await signUp(t, "stranger");
    const roomId = await t.mutation(api.rooms.create, {
      sessionToken: owner.token,
      userId: owner.userId as any,
      name: "room",
      isPrivate: false,
    });
    await t.mutation(api.rooms.join, {
      sessionToken: stranger.token,
      userId: stranger.userId as any,
      roomId,
    });
    const sent = await send(t, owner, roomId, "hi");
    expect(await timesFor(t, owner, roomId, sent)).toEqual([]);
  });
});

describe("delivery claims only what the device has", () => {
  test("the cursor stops at the reported message, not at now", async () => {
    vi.useFakeTimers({ toFake: ["Date"] });
    vi.setSystemTime(at("2026-10-07T10:00:00Z"));
    const t = convexTest(schema);
    const { sender, reader, roomId } = await pair(t);
    const first = await send(t, sender, roomId, "one");
    vi.setSystemTime(at("2026-10-07T10:00:05Z"));
    const second = await send(t, sender, roomId, "two");

    // The device only had "one" when it reported.
    await t.mutation(api.messages.markRoomDelivered, {
      sessionToken: reader.token,
      roomId,
      userId: reader.userId as any,
      upTo: first,
    } as any);
    const row = await readerRow(t, roomId, reader.userId);
    expect(row!.lastDeliveredAt).toBe(first);
    expect(row!.lastDeliveredAt!).toBeLessThan(second);
  });

  test("a report past the newest message is clamped to it", async () => {
    const t = convexTest(schema);
    const { sender, reader, roomId } = await pair(t);
    const sent = await send(t, sender, roomId, "hi");
    await t.mutation(api.messages.markRoomDelivered, {
      sessionToken: reader.token,
      roomId,
      userId: reader.userId as any,
      upTo: sent + 60_000,
    } as any);
    expect((await readerRow(t, roomId, reader.userId))!.lastDeliveredAt).toBe(sent);
  });
});

describe("delivery reported by the push", () => {
  test("the endpoint follows the self-hosted /http layout", () => {
    vi.stubEnv("RECEIPT_URL", "");
    vi.stubEnv("CONVEX_CLOUD_URL", "https://api.example.com");
    expect(receiptEndpoint()).toBe("https://api.example.com/http/receipts/delivered");
    vi.stubEnv("CONVEX_CLOUD_URL", "https://happy-fox-1.convex.cloud");
    expect(receiptEndpoint()).toBe("https://happy-fox-1.convex.site/receipts/delivered");
  });

  test("off until a secret is set", async () => {
    vi.stubEnv("RECEIPT_SECRET", "");
    vi.stubEnv("CONVEX_CLOUD_URL", "https://api.example.com");
    expect(await receiptFields("r", "u", "1")).toBeNull();
  });

  test("a signed echo moves the cursor; a forged one does not", async () => {
    vi.stubEnv("RECEIPT_SECRET", "test-secret");
    vi.stubEnv("CONVEX_CLOUD_URL", "https://api.example.com");
    const t = convexTest(schema);
    const { sender, reader, roomId } = await pair(t);
    const sent = await send(t, sender, roomId, "hi");
    const fields = (await receiptFields(roomId, reader.userId, String(sent)))!;
    expect(fields.rcptUser).toBe(reader.userId);

    const post = (body: Record<string, string>) =>
      t.fetch("/receipts/delivered", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify(body),
      });

    // Signed for the reader, presented as the sender: refused.
    const forged = await post({
      roomId,
      userId: sender.userId,
      createdAt: String(sent),
      sig: fields.rcptSig,
    });
    expect(forged.status).toBe(403);
    // A later message time under the same signature: refused.
    const stretched = await post({
      roomId,
      userId: reader.userId,
      createdAt: String(sent + 1),
      sig: fields.rcptSig,
    });
    expect(stretched.status).toBe(403);
    expect((await readerRow(t, roomId, reader.userId))!.lastDeliveredAt ?? 0)
      .toBeLessThan(sent);

    const ok = await post({
      roomId,
      userId: reader.userId,
      createdAt: String(sent),
      sig: fields.rcptSig,
    });
    expect(ok.status).toBe(204);
    expect((await readerRow(t, roomId, reader.userId))!.lastDeliveredAt).toBe(sent);

    // Replaying it is harmless.
    const again = await post({
      roomId,
      userId: reader.userId,
      createdAt: String(sent),
      sig: fields.rcptSig,
    });
    expect(again.status).toBe(204);
    const logs: any[] = await t.run((ctx: any) =>
      ctx.db
        .query("receiptLogs")
        .withIndex("by_room_user_kind", (q: any) =>
          q.eq("roomId", roomId).eq("userId", reader.userId).eq("kind", "delivered"),
        )
        .collect(),
    );
    expect(logs.length).toBe(1);
    expect(logs[0].entries.length).toBe(1);
  });
});
