import { convexTest } from "convex-test";
import { afterEach, beforeEach, describe, expect, test, vi } from "vitest";
import { api } from "./_generated/api";
import schema from "./schema";

/**
 * The in-room `@` stack (mentions.ts): filled by a send, emptied by sight,
 * and never fooled by a message that stopped naming the reader.
 */

type T = ReturnType<typeof convexTest>;
type Who = { token: string; userId: any };

beforeEach(() => {
  vi.useFakeTimers();
});
afterEach(() => {
  vi.useRealTimers();
});

const as = (w: Who) => ({ sessionToken: w.token, userId: w.userId });

async function signUp(t: T, username: string) {
  return (await t.mutation(api.auth.signup, {
    username,
    name: username,
    passwordHash: `hash-${username}`,
    recoveryKeyHash: `recovery-${username}`,
    deviceId: `device-${username}`,
  })) as Who;
}

let roomSeq = 0;
async function group(t: T, owner: Who, ...others: Who[]) {
  const roomId = await t.mutation(api.rooms.create, {
    ...as(owner),
    name: `mentions ${++roomSeq}`,
    isPrivate: false,
  });
  for (const o of others) await t.mutation(api.rooms.join, { ...as(o), roomId });
  return roomId;
}

const pending = (t: T, who: Who, roomId: any) =>
  t.query(api.mentions.pendingForRoom, { sessionToken: who.token, roomId });

describe("mention stack", () => {
  test("a mention waits, oldest first, until it is seen", async () => {
    const t = convexTest(schema);
    const a = await signUp(t, "ada");
    const b = await signUp(t, "bob");
    const roomId = await group(t, a, b);
    const first = await t.mutation(api.messages.send, {
      ...as(a),
      roomId,
      content: "hey @bob",
      mentionedUserIds: [b.userId],
    });
    vi.advanceTimersByTime(10);
    await t.mutation(api.messages.send, { ...as(a), roomId, content: "plain" });
    vi.advanceTimersByTime(10);
    const second = await t.mutation(api.messages.send, {
      ...as(a),
      roomId,
      content: "again @bob",
      mentionedUserIds: [b.userId],
    });

    expect((await pending(t, b, roomId)).items.map((i: any) => i.messageId)).toEqual([
      first,
      second,
    ]);
    // The sender's own stack is untouched.
    expect((await pending(t, a, roomId)).items).toHaveLength(0);

    await t.mutation(api.mentions.markSeen, {
      sessionToken: b.token,
      roomId,
      messageIds: [first as any],
    });
    expect((await pending(t, b, roomId)).items.map((i: any) => i.messageId)).toEqual([
      second,
    ]);

    await t.mutation(api.mentions.markAllSeen, { sessionToken: b.token, roomId });
    expect((await pending(t, b, roomId)).items).toHaveLength(0);
  });

  test("an edit that drops the mention drops it from the stack", async () => {
    const t = convexTest(schema);
    const a = await signUp(t, "ada");
    const b = await signUp(t, "bob");
    const roomId = await group(t, a, b);
    const id = await t.mutation(api.messages.send, {
      ...as(a),
      roomId,
      content: "hey @bob",
      mentionedUserIds: [b.userId],
    });
    expect((await pending(t, b, roomId)).items).toHaveLength(1);
    await t.mutation(api.messages.editMessage, {
      ...as(a),
      messageId: id as any,
      content: "hey all",
    });
    expect((await pending(t, b, roomId)).items).toHaveLength(0);
  });

  test("an edit that adds a mention stacks it", async () => {
    const t = convexTest(schema);
    const a = await signUp(t, "ada");
    const b = await signUp(t, "bob");
    const roomId = await group(t, a, b);
    const id = await t.mutation(api.messages.send, { ...as(a), roomId, content: "hey" });
    await t.mutation(api.messages.editMessage, {
      ...as(a),
      messageId: id as any,
      content: "hey @bob",
      mentionedUserIds: [b.userId],
    });
    expect((await pending(t, b, roomId)).items.map((i: any) => i.messageId)).toEqual([id]);
  });

  test("@everyone reaches every member but the sender", async () => {
    const t = convexTest(schema);
    const a = await signUp(t, "ada");
    const b = await signUp(t, "bob");
    const c = await signUp(t, "cem");
    const roomId = await group(t, a, b, c);
    await t.mutation(api.messages.send, {
      ...as(a),
      roomId,
      content: "@everyone dinner",
      mentionsEveryone: true,
    });
    await t.finishAllScheduledFunctions(vi.runAllTimers);
    expect((await pending(t, b, roomId)).items).toHaveLength(1);
    expect((await pending(t, c, roomId)).items).toHaveLength(1);
    expect((await pending(t, a, roomId)).items).toHaveLength(0);
  });

  test("leaving the room clears the stack", async () => {
    const t = convexTest(schema);
    const a = await signUp(t, "ada");
    const b = await signUp(t, "bob");
    const roomId = await group(t, a, b);
    await t.mutation(api.messages.send, {
      ...as(a),
      roomId,
      content: "hey @bob",
      mentionedUserIds: [b.userId],
    });
    await t.mutation(api.rooms.leave, { ...as(b), roomId });
    const left = await t.run((ctx) => ctx.db.query("mentionInbox").collect());
    expect(left).toHaveLength(0);
  });
});
