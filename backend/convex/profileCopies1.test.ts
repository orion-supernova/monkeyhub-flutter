import { convexTest } from "convex-test";
import { afterEach, beforeEach, describe, expect, test } from "vitest";
import { api, internal } from "./_generated/api";
import schema from "./schema";
import { copyFlags } from "./profileCopyGate";
import { syncProfile, tombstoneProfile } from "./profilesCore";

// Phase 6C: the copy writers of messages, interactions and typing, and the
// server readers that build a name (reaction push, deletion alert, typing).
type T = ReturnType<typeof convexTest>;

beforeEach(() => {
  copyFlags.copies = true;
});
afterEach(() => {
  copyFlags.copies = true;
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

async function world(t: T) {
  const a = await signUp(t, "alice");
  const b = await signUp(t, "bobby");
  const roomId = await t.mutation(api.rooms.create, {
    sessionToken: a.token,
    userId: a.userId as any,
    name: "room",
    isPrivate: false,
  });
  await t.mutation(api.rooms.join, {
    sessionToken: b.token,
    userId: b.userId as any,
    roomId,
  } as any);
  return { a, b, roomId };
}

const rename = (t: T, userId: string, name: string) =>
  t.run(async (ctx: any) => {
    await ctx.db.patch(userId, { name });
    await syncProfile(ctx, userId);
  });

const rows = (t: T, table: string): Promise<any[]> =>
  t.run((ctx: any) => ctx.db.query(table).collect());

async function send(t: T, w: any, who: any, content = "hi", extra: any = {}) {
  return (await t.mutation(api.messages.send, {
    sessionToken: who.token,
    userId: who.userId as any,
    roomId: w.roomId,
    content,
    ...extra,
  })) as any;
}

async function poll(t: T, w: any) {
  return (await t.mutation(api.interactions.create, {
    sessionToken: w.a.token,
    userId: w.a.userId as any,
    roomId: w.roomId,
    kind: "poll",
    prompt: "pizza or curry?",
    labels: ["pizza", "curry"],
  })) as any;
}

const vote = (t: T, w: any, who: any, messageId: any) =>
  t.mutation(api.interactions.respond, {
    sessionToken: who.token,
    userId: who.userId as any,
    messageId,
    choiceId: "0",
  });

const typers = (t: T, w: any) =>
  t.query(api.typing.getTypingUsers, {
    sessionToken: w.a.token,
    roomId: w.roomId,
    currentUserId: w.a.userId as any,
  } as any) as Promise<any[]>;

describe("copies on (today's behaviour)", () => {
  test("messages, replies, votes and typing still carry the copies", async () => {
    const t = convexTest(schema);
    const w = await world(t);
    const m1 = await send(t, w, w.a, "first");
    await send(t, w, w.b, "second", { replyToId: m1 });
    const msgs = await rows(t, "messages");
    expect(msgs.every((m) => m.senderName)).toBe(true);
    expect(msgs.find((m) => m.replyToPreview)!.replyToPreview.senderName).toBe("alice");

    const p = await poll(t, w);
    await vote(t, w, w.b, p);
    expect((await rows(t, "interactionResponses"))[0].userName).toBe("bobby");
    const tally = (await rows(t, "messageInteractions"))[0];
    expect(tally.choices[0].respondents[0].name).toBe("bobby");

    await t.mutation(api.typing.setTyping, {
      sessionToken: w.b.token, roomId: w.roomId, userId: w.b.userId as any,
    } as any);
    const ti = (await rows(t, "typingIndicators"))[0];
    expect(ti.userName).toBe("bobby");
    expect((await typers(t, w))[0].name).toBe("bobby");
  });
});

describe("copies off", () => {
  test("no copy is written and every reader still shows the current name", async () => {
    copyFlags.copies = false;
    const t = convexTest(schema);
    const w = await world(t);
    const m1 = await send(t, w, w.a, "first");
    await send(t, w, w.b, "second", { replyToId: m1 });
    const msgs = await rows(t, "messages");
    for (const m of msgs) expect(m.senderName).toBeUndefined();
    expect(msgs.find((m) => m.replyToPreview)!.replyToPreview.senderName).toBeUndefined();

    const p = await poll(t, w);
    await vote(t, w, w.b, p);
    expect((await rows(t, "interactionResponses"))[0].userName).toBeUndefined();
    const tally = (await rows(t, "messageInteractions"))[0];
    expect(tally.choices[0].count).toBe(1);
    expect(tally.choices[0].respondents[0].name).toBeUndefined();

    await t.mutation(api.typing.setTyping, {
      sessionToken: w.b.token, roomId: w.roomId, userId: w.b.userId as any,
    } as any);
    const ti = (await rows(t, "typingIndicators"))[0];
    expect(ti.userName).toBeUndefined();
    expect(ti.avatarVisibility).toBeUndefined();
    expect((await typers(t, w))[0].name).toBe("bobby");

    // A rename shows everywhere, with nothing to refresh.
    await rename(t, w.b.userId, "Robert");
    expect((await typers(t, w))[0].name).toBe("Robert");
    const list = (await t.query(api.interactions.respondents, {
      sessionToken: w.a.token, messageId: p, viewerUserId: w.a.userId as any,
    } as any)) as any[];
    expect(list[0].name).toBe("Robert");
  });
});

describe("readers", () => {
  test("respondents shows the renamed voter even from the stored copy", async () => {
    const t = convexTest(schema);
    const w = await world(t);
    const p = await poll(t, w);
    await vote(t, w, w.b, p);
    await rename(t, w.b.userId, "Robert");
    const list = (await t.query(api.interactions.respondents, {
      sessionToken: w.a.token, messageId: p, viewerUserId: w.a.userId as any,
    } as any)) as any[];
    expect(list[0].name).toBe("Robert");
  });

  test("a deleted voter has an empty name, not the stale copy", async () => {
    const t = convexTest(schema);
    const w = await world(t);
    const p = await poll(t, w);
    await vote(t, w, w.b, p);
    await t.run((ctx: any) => tombstoneProfile(ctx, w.b.userId));
    const list = (await t.query(api.interactions.respondents, {
      sessionToken: w.a.token, messageId: p, viewerUserId: w.a.userId as any,
    } as any)) as any[];
    expect(list[0].name).toBe("");
  });

  test("a reaction push built after a rename uses the new name; a deleted reactor sends none", async () => {
    for (const copies of [true, false]) {
      copyFlags.copies = copies;
      const t = convexTest(schema);
      const w = await world(t);
      const msg = await send(t, w, w.a, "see you at 8");
      const id = typeof msg === "string" ? msg : msg._id ?? msg.id;
      const react = (await t.mutation(api.reactions.addReaction, {
        sessionToken: w.b.token, userId: w.b.userId as any, messageId: id, emoji: "❤️",
      } as any)) as any;
      await rename(t, w.b.userId, "Robert");
      const plan: any = await t.query(internal.notifications._reactionPushPlan, {
        reactionId: react,
      });
      expect(plan.reactorName).toBe("Robert");
      await t.run((ctx: any) => tombstoneProfile(ctx, w.b.userId));
      const gone = await t.query(internal.notifications._reactionPushPlan, {
        reactionId: react,
      });
      expect(gone).toBeNull();
    }
  });

  test("a deleted typist is not shown", async () => {
    const t = convexTest(schema);
    const w = await world(t);
    await t.mutation(api.typing.setTyping, {
      sessionToken: w.b.token, roomId: w.roomId, userId: w.b.userId as any,
    } as any);
    await t.run((ctx: any) => tombstoneProfile(ctx, w.b.userId));
    expect(await typers(t, w)).toEqual([]);
  });
});
