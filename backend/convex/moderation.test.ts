import { convexTest } from "convex-test";
import { describe, expect, test } from "vitest";
import { api, internal } from "./_generated/api";
import schema from "./schema";
import { ERR_FILTER_BLOCKED } from "./contentFilter";
import {
  REPORTER_USERNAME,
  REPORT_INBOX_USERNAME,
  SYSTEM_ROOM_MODERATION,
  isSystemAccount,
} from "./systemAccount";
import { MAX_REPORTS_PER_WINDOW } from "./moderationCore";
import { TERMS_VERSION } from "./terms";

/**
 * The Guideline 1.2 moderation pack, end to end: a report lands as a card in
 * the moderation room with its evidence, staff (and only staff) can act on
 * it, a ban locks the account out, and the text filter masks, blocks and
 * files on its own.
 */

const DEVICE = "device-a";

async function signUp(
  t: ReturnType<typeof convexTest>,
  username: string,
  extra: Record<string, any> = {},
) {
  return await t.mutation(api.auth.signup, {
    username,
    name: username,
    passwordHash: `hash-${username}`,
    recoveryKeyHash: `recovery-${username}`,
    deviceId: DEVICE,
    ...extra,
  } as any);
}

type Who = Awaited<ReturnType<typeof signUp>>;

const as = (who: Who) => ({ sessionToken: who.token, userId: who.userId as any });
/** For a function whose identity argument is not `userId`. */
const tok = (who: Who) => ({ sessionToken: who.token });

let roomSeq = 0;

async function groupWith(t: ReturnType<typeof convexTest>, owner: Who, others: Who[]) {
  const roomId = await t.mutation(api.rooms.create, {
    ...as(owner),
    name: `room-${++roomSeq}`,
    isPrivate: false,
  } as any);
  for (const o of others) {
    await t.mutation(api.rooms.join, { ...as(o), roomId } as any);
  }
  return roomId;
}

const send = (t: ReturnType<typeof convexTest>, who: Who, roomId: any, content: string) =>
  t.mutation(api.messages.send, { ...as(who), roomId, content } as any) as Promise<any>;

async function moderationRoom(t: ReturnType<typeof convexTest>) {
  return await t.run(async (ctx) => {
    const rooms = await ctx.db.query("rooms").collect();
    return rooms.find((r) => r.system === SYSTEM_ROOM_MODERATION) ?? null;
  });
}

async function roomMessages(t: ReturnType<typeof convexTest>, roomId: any) {
  return await t.run((ctx: any) =>
    ctx.db
      .query("messages")
      .withIndex("by_room_time", (q: any) => q.eq("roomId", roomId))
      .collect(),
  ) as any[];
}

/** Staff, a reporter and a reported person, in one public group. */
async function scene(t: ReturnType<typeof convexTest>) {
  const staff = await signUp(t, REPORT_INBOX_USERNAME);
  const ada = await signUp(t, "ada");
  const bob = await signUp(t, "bob");
  const roomId = await groupWith(t, ada, [bob]);
  return { staff, ada, bob, roomId };
}

describe("filing a report", () => {
  test("posts a card with the reported message and its context", async () => {
    const t = convexTest(schema);
    const { staff, ada, bob, roomId } = await scene(t);
    await send(t, ada, roomId, "hello bob");
    await send(t, bob, roomId, "first");
    const bad = await send(t, bob, roomId, "you are awful");

    const res = await t.mutation(api.users.report, {
      ...tok(ada),
      reporterId: ada.userId,
      targetType: "message",
      targetId: bad,
      reason: "HARASSMENT",
    } as any);
    expect(res).toEqual({ ok: true, blocked: false });

    const report = await t.run(async (ctx) => (await ctx.db.query("reports").collect())[0]);
    expect(report.status).toBe("open");
    expect(report.reportedUserId).toBe(bob.userId);
    expect(report.messageId).toBe(bad);
    expect(report.cardMessageId).toBeTruthy();

    const room = await moderationRoom(t);
    expect(room).not.toBeNull();
    expect(room!.isPrivate).toBe(true);
    const cards = await roomMessages(t, room!._id);
    expect(cards).toHaveLength(1);
    const card = cards[0];
    expect(card.moderationCard).toEqual({
      reportId: report._id,
      hasMessage: true,
      hasUser: true,
      userBanned: false,
    });
    expect(card.content).toContain("Harassment");
    expect(card.content).toContain("@bob");
    expect(card.content).toContain("▶");
    expect(card.content).toContain("you are awful");
    expect(card.content).toContain("hello bob");
    expect(card.content).not.toContain("—");

    // The staff member is in the room; the reported person is not.
    const members = await t.run((ctx) =>
      ctx.db
        .query("roomMembers")
        .withIndex("by_room_user", (q) => q.eq("roomId", room!._id))
        .collect(),
    );
    const ids = members.map((m) => m.userId);
    expect(ids).toContain(staff.userId);
    expect(ids).not.toContain(bob.userId);
    expect(ids).not.toContain(ada.userId);
  });

  test("Monkey Reporter is a system account nobody can find", async () => {
    const t = convexTest(schema);
    const { ada, bob } = await scene(t);
    await t.mutation(api.users.report, {
      ...tok(ada),
      reporterId: ada.userId,
      targetType: "user",
      targetId: bob.userId,
      reason: "SPAM",
    } as any);
    const bot = await t.run((ctx) =>
      ctx.db
        .query("users")
        .withIndex("by_username", (q) => q.eq("username", REPORTER_USERNAME))
        .first(),
    );
    expect(isSystemAccount(bot)).toBe(true);
    const found = await t.query(api.users.searchUsers, {
      ...tok(ada),
      query: "reporter",
      currentUserId: ada.userId,
    } as any);
    expect(found).toHaveLength(0);
  });

  test("also-block writes the block in the same call", async () => {
    const t = convexTest(schema);
    const { ada, bob } = await scene(t);
    const res = await t.mutation(api.users.report, {
      ...tok(ada),
      reporterId: ada.userId,
      targetType: "user",
      targetId: bob.userId,
      reason: "SPAM",
      alsoBlock: true,
    } as any);
    expect(res.blocked).toBe(true);
    const blocked = await t.query(api.users.isBlocked, {
      ...as(ada),
      otherUserId: bob.userId,
    } as any);
    expect(blocked).toBe(true);
  });

  test("a repeat report posts no second card", async () => {
    const t = convexTest(schema);
    const { ada, bob } = await scene(t);
    for (let i = 0; i < 3; i++) {
      await t.mutation(api.users.report, {
        ...tok(ada),
        reporterId: ada.userId,
        targetType: "user",
        targetId: bob.userId,
        reason: "SPAM",
      } as any);
    }
    const room = await moderationRoom(t);
    expect(await roomMessages(t, room!._id)).toHaveLength(1);
  });

  test("is rate-limited per reporter", async () => {
    const t = convexTest(schema);
    const { ada } = await scene(t);
    const targets: Who[] = [];
    for (let i = 0; i <= MAX_REPORTS_PER_WINDOW; i++) {
      targets.push(await signUp(t, `target${i}`));
    }
    for (let i = 0; i < MAX_REPORTS_PER_WINDOW; i++) {
      await t.mutation(api.users.report, {
        ...tok(ada),
        reporterId: ada.userId,
        targetType: "user",
        targetId: targets[i].userId,
        reason: "SPAM",
      } as any);
    }
    await expect(
      t.mutation(api.users.report, {
        ...tok(ada),
        reporterId: ada.userId,
        targetType: "user",
        targetId: targets[MAX_REPORTS_PER_WINDOW].userId,
        reason: "SPAM",
      } as any),
    ).rejects.toThrow("TOO_MANY_REPORTS");
  });

  test("still records the report on a deployment with no staff", async () => {
    const t = convexTest(schema);
    const ada = await signUp(t, "ada");
    const bob = await signUp(t, "bob");
    await t.mutation(api.users.report, {
      ...tok(ada),
      reporterId: ada.userId,
      targetType: "user",
      targetId: bob.userId,
      reason: "SPAM",
    } as any);
    const reports = await t.run((ctx) => ctx.db.query("reports").collect());
    expect(reports).toHaveLength(1);
    expect(await moderationRoom(t)).toBeNull();
  });
});

describe("moderator actions", () => {
  async function filed(t: ReturnType<typeof convexTest>) {
    const s = await scene(t);
    const bad = await send(t, s.bob, s.roomId, "awful thing");
    await t.mutation(api.users.report, {
      ...tok(s.ada),
      reporterId: s.ada.userId,
      targetType: "message",
      targetId: bad,
      reason: "HARASSMENT",
    } as any);
    const report = await t.run(async (ctx) => (await ctx.db.query("reports").collect())[0]);
    return { ...s, bad, report };
  }

  test("are refused to anyone who is not staff", async () => {
    const t = convexTest(schema);
    const { ada, report } = await filed(t);
    await expect(
      t.mutation(api.moderation.act, {
        ...as(ada),
        reportId: report._id,
        action: "dismiss",
      } as any),
    ).rejects.toThrow("NOT_AUTHORIZED");
  });

  test("remove message deletes it for everyone and posts the outcome", async () => {
    const t = convexTest(schema);
    const { staff, bad, report } = await filed(t);
    await t.mutation(api.moderation.act, {
      ...as(staff),
      reportId: report._id,
      action: "removeMessage",
    } as any);
    expect(await t.run((ctx) => ctx.db.get(bad))).toBeNull();
    const after: any = await t.run((ctx) => ctx.db.get(report._id));
    expect(after!.status).toBe("actioned");
    expect(after!.action).toBe("removeMessage");
    const room = await moderationRoom(t);
    const msgs = await roomMessages(t, room!._id);
    expect(msgs.at(-1)!.content).toContain("Message removed");
    expect(msgs.at(-1)!.replyToId).toBe(report.cardMessageId);
  });

  test("ban locks the account out, unban lets it back in", async () => {
    const t = convexTest(schema);
    const { staff, bob, roomId, report } = await filed(t);
    await t.mutation(api.moderation.act, {
      ...as(staff),
      reportId: report._id,
      action: "ban",
    } as any);

    // The live session is gone, and says why.
    await expect(send(t, bob, roomId, "still here?")).rejects.toThrow(
      "ACCOUNT_SUSPENDED",
    );
    // A fresh sign-in is refused.
    await expect(
      t.mutation(api.auth.login, {
        username: "bob",
        passwordHash: "hash-bob",
        deviceId: "device-b",
      }),
    ).rejects.toThrow("ACCOUNT_SUSPENDED");
    // Out of the public room, and out of search.
    const membership = await t.run((ctx) =>
      ctx.db
        .query("roomMembers")
        .withIndex("by_room_user", (q) => q.eq("roomId", roomId).eq("userId", bob.userId))
        .first(),
    );
    expect(membership).toBeNull();
    const found = await t.query(api.users.searchUsers, {
      ...tok(staff),
      query: "bob",
      currentUserId: staff.userId,
    } as any);
    expect(found).toHaveLength(0);
    // The card now offers Unban instead of Ban.
    const card = (): Promise<any> => t.run((ctx) => ctx.db.get(report.cardMessageId!));
    expect((await card())!.moderationCard!.userBanned).toBe(true);

    await t.mutation(api.moderation.act, {
      ...as(staff),
      reportId: report._id,
      action: "unban",
    } as any);
    expect((await card())!.moderationCard!.userBanned).toBe(false);
    const back = await t.mutation(api.auth.login, {
      username: "bob",
      passwordHash: "hash-bob",
      deviceId: "device-b",
    });
    expect(back.token).toBeTruthy();
  });

  test("a moderator cannot be banned", async () => {
    const t = convexTest(schema);
    const { staff, ada, roomId } = await scene(t);
    await t.mutation(api.rooms.join, { ...as(staff), roomId } as any);
    const msg = await send(t, staff, roomId, "hi");
    await t.mutation(api.users.report, {
      ...tok(ada),
      reporterId: ada.userId,
      targetType: "message",
      targetId: msg,
      reason: "SPAM",
    } as any);
    const report = await t.run(async (ctx) => (await ctx.db.query("reports").collect())[0]);
    await expect(
      t.mutation(api.moderation.act, {
        ...as(staff),
        reportId: report._id,
        action: "ban",
      } as any),
    ).rejects.toThrow("CANT_BAN_ACCOUNT");
  });
});

describe("the text filter in chat", () => {
  test("masks profanity between adults, keeping the length", async () => {
    const t = convexTest(schema);
    const { ada, bob, roomId } = await scene(t);
    const id = await send(t, ada, roomId, "oh shit");
    const row: any = await t.run((ctx) => ctx.db.get(id));
    expect(row!.content).toBe("oh ****");
    expect(await moderationRoom(t)).toBeNull();
    void bob;
  });

  test("a slur is masked and filed as a filter hit", async () => {
    const t = convexTest(schema);
    const { ada, roomId } = await scene(t);
    const id = await send(t, ada, roomId, "you faggot");
    const row: any = await t.run((ctx) => ctx.db.get(id));
    expect(row!.content).not.toContain("faggot");
    const room = await moderationRoom(t);
    const cards = await roomMessages(t, room!._id);
    expect(cards).toHaveLength(1);
    expect(cards[0].content).toContain("FILTER HIT");
    const report = await t.run(async (ctx) => (await ctx.db.query("reports").collect())[0]);
    expect(report.source).toBe("filter");
    expect(report.reportedUserId).toBe(ada.userId);
  });

  test("text to a child is refused, and sexual text is filed", async () => {
    const t = convexTest(schema);
    const { ada, roomId } = await scene(t);
    // A child member, written directly: how they got in is not the point.
    const kid = await t.run(async (ctx) => {
      const id = await ctx.db.insert("users", {
        username: "kid",
        name: "kid",
        passwordHash: "x",
        createdAt: Date.now(),
        accountType: "child",
      } as any);
      await ctx.db.insert("roomMembers", {
        roomId,
        userId: id,
        joinedAt: Date.now(),
        role: "member",
      } as any);
      return id;
    });
    expect(kid).toBeTruthy();

    const res = await send(t, ada, roomId, "send nudes");
    expect(res).toBe(ERR_FILTER_BLOCKED);
    const inRoom = await roomMessages(t, roomId);
    expect(inRoom.some((m) => m.content.includes("nudes"))).toBe(false);
    const room = await moderationRoom(t);
    const cards = await roomMessages(t, room!._id);
    expect(cards).toHaveLength(1);
    expect(cards[0].content).toContain("Child involved: yes");
    expect(cards[0].content).toContain("blocked");

    // Profanity is refused too, but files nothing.
    expect(await send(t, ada, roomId, "shit")).toBe(ERR_FILTER_BLOCKED);
    expect(await roomMessages(t, room!._id)).toHaveLength(1);

    // Clean text still goes through.
    const ok = await send(t, ada, roomId, "hello there");
    expect(ok).not.toBe(ERR_FILTER_BLOCKED);
  });

  test("an edit cannot launder a word past the filter", async () => {
    const t = convexTest(schema);
    const { ada, roomId } = await scene(t);
    const id = await send(t, ada, roomId, "fine");
    const res = await t.mutation(api.messages.editMessage, {
      ...as(ada),
      messageId: id,
      content: "fucking fine",
    } as any);
    expect(res).toBe("OK");
    const row: any = await t.run((ctx) => ctx.db.get(id));
    expect(row!.content).toBe("******* fine");
  });

  test("names are refused", async () => {
    const t = convexTest(schema);
    await expect(signUp(t, "bigfucker")).rejects.toThrow("NAME_INAPPROPRIATE");
    const ada = await signUp(t, "ada");
    await expect(
      t.mutation(api.rooms.create, {
        ...as(ada),
        name: "shit club",
        isPrivate: true,
      } as any),
    ).rejects.toThrow("NAME_INAPPROPRIATE");
  });
});

describe("terms acceptance", () => {
  test("a sign-up with the box ticked is stamped", async () => {
    const t = convexTest(schema);
    const ada = await signUp(t, "ada", { termsVersion: TERMS_VERSION });
    const status = await t.query(api.terms.status, as(ada) as any);
    expect(status.accepted).toBe(true);
  });

  test("an old client is let in unaccepted, and accepts later", async () => {
    const t = convexTest(schema);
    const ada = await signUp(t, "ada");
    expect((await t.query(api.terms.status, as(ada) as any)).accepted).toBe(false);
    await t.mutation(api.terms.accept, { ...as(ada), version: TERMS_VERSION } as any);
    expect((await t.query(api.terms.status, as(ada) as any)).accepted).toBe(true);
  });

  test("a stale version is refused", async () => {
    const t = convexTest(schema);
    await expect(signUp(t, "ada", { termsVersion: 0 })).rejects.toThrow(
      "TERMS_NOT_ACCEPTED",
    );
  });
});

describe("evidence retention", () => {
  test("old moderation-room messages are swept", async () => {
    const t = convexTest(schema);
    const { ada, bob } = await scene(t);
    await t.mutation(api.users.report, {
      ...tok(ada),
      reporterId: ada.userId,
      targetType: "user",
      targetId: bob.userId,
      reason: "SPAM",
    } as any);
    const room = await moderationRoom(t);
    await t.run(async (ctx) => {
      for (const m of await ctx.db
        .query("messages")
        .withIndex("by_room_time", (q) => q.eq("roomId", room!._id))
        .collect()) {
        await ctx.db.patch(m._id, { createdAt: 1 });
      }
    });
    await t.mutation(internal.moderation.gcExpiredEvidence, {});
    expect(await roomMessages(t, room!._id)).toHaveLength(0);
  });
});
