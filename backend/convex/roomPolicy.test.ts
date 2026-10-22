import { convexTest } from "convex-test";
import { describe, expect, test } from "vitest";
import { api } from "./_generated/api";
import schema from "./schema";
import { sendCore } from "./messages";
import {
  ERR_ROOM_POSTING_RESTRICTED,
  POSTING_PRESETS,
  policyAllows,
  postKindOf,
  postingPresetOf,
} from "./roomPolicy";
import { SYSTEM_PASSWORD_PREFIX, SYSTEM_ROOM_LOGS } from "./systemAccount";

/**
 * The room posting policy, executed end to end: one guard, every write path.
 * See `roomPolicy.ts` for the design.
 */

const DEVICE = "device-a";

async function signUp(t: ReturnType<typeof convexTest>, username: string) {
  return await t.mutation(api.auth.signup, {
    username,
    name: username,
    passwordHash: `hash-${username}`,
    recoveryKeyHash: `recovery-${username}`,
    // One device per person: a deviceId is one handset, and signing in
    // on it signs out whoever was there before.
    deviceId: `device-${username}`,
  });
}

type Who = Awaited<ReturnType<typeof signUp>>;

const as = (who: Who) => ({
  sessionToken: who.token,
  userId: who.userId as any,
});

let roomSeq = 0;

/** A public room [owner] made and [others] joined, optionally stamped. */
async function makeRoom(
  t: ReturnType<typeof convexTest>,
  owner: Who,
  others: Who[],
  stamp: Record<string, any> = {},
) {
  const roomId = await t.mutation(api.rooms.create, {
    ...as(owner),
    name: `room-${++roomSeq}`,
    isPrivate: false,
  });
  for (const o of others) {
    await t.mutation(api.rooms.join, { ...as(o), roomId } as any);
  }
  if (Object.keys(stamp).length > 0) {
    await t.run(async (ctx) => ctx.db.patch(roomId, stamp as any));
  }
  return roomId;
}

const send = (
  t: ReturnType<typeof convexTest>,
  who: Who,
  roomId: any,
  extra: Record<string, any> = {},
) =>
  t.mutation(api.messages.send, {
    ...as(who),
    roomId,
    content: "hi",
    ...extra,
  } as any) as Promise<any>;

describe("resolution", () => {
  test("absent is open, a system room is readOnly, a stamp wins, junk is readOnly", () => {
    expect(postingPresetOf({})).toBe("open");
    expect(postingPresetOf(null)).toBe("open");
    expect(postingPresetOf({ system: SYSTEM_ROOM_LOGS })).toBe("readOnly");
    expect(postingPresetOf({ system: "someFutureBot" })).toBe("readOnly");
    expect(
      postingPresetOf({ system: "agentBot", postingPolicy: "agent" }),
    ).toBe("agent");
    expect(postingPresetOf({ postingPolicy: "readOnly" })).toBe("readOnly");
    // A preset this build predates fails closed.
    expect(postingPresetOf({ postingPolicy: "somethingNew" })).toBe("readOnly");
    // A prototype key is not a preset.
    expect(postingPresetOf({ postingPolicy: "toString" })).toBe("readOnly");
  });

  test("types map to kinds", () => {
    expect(postKindOf(undefined)).toBe("text");
    expect(postKindOf("url")).toBe("text");
    expect(postKindOf("videoNote")).toBe("video");
    expect(postKindOf("audio")).toBe("voice");
    expect(postKindOf("gif")).toBe("sticker");
    expect(postKindOf("liveLocation")).toBe("location");
    expect(postKindOf("gameMove")).toBe("game");
    expect(postKindOf("challenge")).toBe("game");
    expect(postKindOf("hologram")).toBe("other");
  });

  test("open grants everything, readOnly nothing, agent text and images only", () => {
    const everything = {
      kinds: ["text", "image", "video", "game", "other", "system"] as const,
      actions: ["reply", "react", "forwardIn", "call", "interact", "pin"] as const,
    };
    expect(policyAllows(POSTING_PRESETS.open, everything)).toBe(true);
    expect(policyAllows(POSTING_PRESETS.readOnly, { kinds: ["text"] })).toBe(false);
    expect(policyAllows(POSTING_PRESETS.readOnly, { actions: ["react"] })).toBe(false);
    // An empty write asks for nothing, so even readOnly grants it.
    expect(policyAllows(POSTING_PRESETS.readOnly, {})).toBe(true);
    const agent = POSTING_PRESETS.agent;
    expect(policyAllows(agent, { kinds: ["text", "image"] })).toBe(true);
    for (const kind of ["video", "voice", "file", "location", "game", "poll"] as const) {
      expect(policyAllows(agent, { kinds: [kind] })).toBe(false);
    }
    expect(policyAllows(agent, { actions: ["reply", "react", "pin"] })).toBe(true);
    expect(policyAllows(agent, { actions: ["call"] })).toBe(false);
  });
});

describe("a normal room is unaffected", () => {
  test("text, a poll-shaped type, a reply, a reaction and a pin all go through", async () => {
    const t = convexTest(schema);
    const a = await signUp(t, "alice");
    const b = await signUp(t, "bob");
    const roomId = await makeRoom(t, a, [b]);
    const first = await send(t, a, roomId);
    await send(t, b, roomId, { replyToId: first });
    await send(t, b, roomId, { type: "image" });
    await t.mutation(api.reactions.addReaction, {
      ...as(b),
      messageId: first,
      emoji: "👍",
    } as any);
    await t.mutation(api.pins.pin, { ...as(b), messageId: first } as any);
    const rows = await t.run((ctx) => ctx.db.query("messages").collect());
    expect(rows).toHaveLength(3);
  });
});

describe("a read-only room", () => {
  test("refuses every member write path with one code", async () => {
    const t = convexTest(schema);
    const a = await signUp(t, "alice");
    const b = await signUp(t, "bob");
    const elsewhere = await makeRoom(t, b, []);
    const roomId = await makeRoom(t, a, [b]);
    // Written while the room was still open, so there is something to react
    // to, pin, edit and reply to once it is not.
    const existing = await send(t, a, roomId);
    const outside = await send(t, b, elsewhere);
    await t.run(async (ctx) =>
      ctx.db.patch(roomId, { postingPolicy: "readOnly" }),
    );

    const refused = (p: Promise<unknown>) =>
      expect(p).rejects.toThrow(ERR_ROOM_POSTING_RESTRICTED);

    await refused(send(t, b, roomId));
    await refused(send(t, b, roomId, { type: "image" }));
    await refused(send(t, b, roomId, { type: "sticker" }));
    await refused(
      send(t, b, roomId, { type: "location", latitude: 1, longitude: 2 }),
    );
    // A malformed location is downgraded to text, and text is refused too.
    await refused(send(t, b, roomId, { type: "location" }));
    await refused(
      t.mutation(api.messages.editMessage, {
        ...as(a),
        messageId: existing,
        content: "rewritten",
      } as any),
    );
    await refused(
      t.mutation(api.messages.forwardToRoom, {
        ...as(b),
        sourceRoomId: elsewhere,
        targetRoomId: roomId,
        messageIds: [outside],
      } as any),
    );
    await refused(
      t.mutation(api.reactions.addReaction, {
        ...as(b),
        messageId: existing,
        emoji: "👍",
      } as any),
    );
    await refused(
      t.mutation(api.pins.pin, { ...as(b), messageId: existing } as any),
    );
    await refused(
      t.mutation(api.scheduledMessages.schedule, {
        ...as(b),
        roomId,
        content: "later",
        delayMs: 60_000,
        clientId: "c1",
      } as any),
    );
    await refused(
      t.mutation(api.groupCalls.start, {
        ...as(b),
        roomId,
        type: "audio",
      } as any),
    );

    const inRoom = await t.run((ctx) =>
      ctx.db
        .query("messages")
        .withIndex("by_room_time", (q: any) => q.eq("roomId", roomId))
        .collect(),
    );
    expect(inRoom).toHaveLength(1);
    expect(inRoom[0].content).toBe("hi");
  });

  test("an unstamped system room is read-only by default", async () => {
    const t = convexTest(schema);
    const a = await signUp(t, "alice");
    const roomId = await makeRoom(t, a, [], { system: SYSTEM_ROOM_LOGS });
    await expect(send(t, a, roomId)).rejects.toThrow(
      ERR_ROOM_POSTING_RESTRICTED,
    );
  });

  test("a system account posts through the same path, bypassing the policy", async () => {
    const t = convexTest(schema);
    const reader = await signUp(t, "alice");
    const roomId = await makeRoom(t, reader, [], {
      system: SYSTEM_ROOM_LOGS,
      postingPolicy: "readOnly",
    });
    const botId = await t.run(async (ctx) => {
      const id = await ctx.db.insert("users", {
        username: "bot",
        name: "Bot",
        passwordHash: `${SYSTEM_PASSWORD_PREFIX}abc`,
        createdAt: Date.now(),
        status: "offline",
      } as any);
      await ctx.db.insert("roomMembers", {
        roomId,
        userId: id,
        joinedAt: Date.now(),
        role: "member",
      } as any);
      return id;
    });
    const messageId = await t.run(async (ctx) =>
      sendCore(ctx, { roomId, userId: botId, content: "report", type: "text" }),
    );
    expect(messageId).toBeTruthy();
    // ...and the reader still cannot answer it.
    await expect(send(t, reader, roomId)).rejects.toThrow(
      ERR_ROOM_POSTING_RESTRICTED,
    );
  });
});

describe("the agent preset", () => {
  test("takes text, images and replies; refuses games, files and calls", async () => {
    const t = convexTest(schema);
    const a = await signUp(t, "alice");
    const b = await signUp(t, "bob");
    const roomId = await makeRoom(t, a, [b], { postingPolicy: "agent" });

    const first = await send(t, a, roomId);
    await send(t, b, roomId, { type: "image" });
    await send(t, b, roomId, { replyToId: first });
    await t.mutation(api.reactions.addReaction, {
      ...as(b),
      messageId: first,
      emoji: "👍",
    } as any);

    const refused = (p: Promise<unknown>) =>
      expect(p).rejects.toThrow(ERR_ROOM_POSTING_RESTRICTED);
    await refused(send(t, b, roomId, { type: "game" }));
    await refused(send(t, b, roomId, { type: "file" }));
    await refused(send(t, b, roomId, { type: "audio" }));
    await refused(
      t.mutation(api.groupCalls.start, {
        ...as(b),
        roomId,
        type: "video",
      } as any),
    );
  });
});
