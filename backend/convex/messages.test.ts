import { convexTest } from "convex-test";
import { describe, expect, test, vi } from "vitest";
import { api, internal } from "./_generated/api";
import { SPOILER_MASK, maskSpoilers, roomPreviewFor } from "./messages";
import type { Id } from "./_generated/dataModel";
import schema from "./schema";

/**
 * The spoiler mask, pinned at the unit level.
 *
 * `maskSpoilers` is what keeps hidden words off the lock screen: the push
 * body IS `roomPreviewFor`'s string, and `notifications.ts` never sees the
 * formatting array at all. So if this function lets one span through, the
 * banner shows the text — and nothing else in the pipeline would notice.
 */
describe("maskSpoilers", () => {
  test("replaces a spoiler span with the mask and nothing else", () => {
    expect(
      maskSpoilers("the winner is Ada", [
        { start: 14, end: 17, type: "spoiler" },
      ])
    ).toBe(`the winner is ${SPOILER_MASK}`);
  });

  test("the mask does not scale with what it hides", () => {
    const short = maskSpoilers("x", [{ start: 0, end: 1, type: "spoiler" }]);
    const long = maskSpoilers("a much longer secret here", [
      { start: 0, end: 25, type: "spoiler" },
    ]);
    expect(short).toBe(SPOILER_MASK);
    expect(long).toBe(SPOILER_MASK);
  });

  test("non-spoiler spans leave the text alone", () => {
    const text = "bold and *italic*";
    expect(
      maskSpoilers(text, [
        { start: 0, end: 4, type: "bold" },
        { start: 9, end: 17, type: "italic" },
        { start: 0, end: 4, type: "link", url: "https://x.y" },
      ])
    ).toBe(text);
    expect(maskSpoilers(text, undefined)).toBe(text);
    expect(maskSpoilers(text, [])).toBe(text);
  });

  test("touching and overlapping spoilers collapse into one mask", () => {
    expect(
      maskSpoilers("abcdefgh", [
        { start: 4, end: 6, type: "spoiler" },
        { start: 1, end: 3, type: "spoiler" },
        { start: 3, end: 5, type: "spoiler" },
      ])
    ).toBe(`a${SPOILER_MASK}gh`);
    expect(
      maskSpoilers("abcdefgh", [
        { start: 1, end: 3, type: "spoiler" },
        { start: 5, end: 7, type: "spoiler" },
      ])
    ).toBe(`a${SPOILER_MASK}de${SPOILER_MASK}h`);
  });

  test("malformed offsets are clamped, never thrown on", () => {
    expect(
      maskSpoilers("abc", [{ start: -4, end: 99, type: "spoiler" }])
    ).toBe(SPOILER_MASK);
    expect(
      maskSpoilers("abc", [{ start: 2, end: 1, type: "spoiler" }])
    ).toBe("abc");
  });
});

describe("roomPreviewFor", () => {
  test("masks spoilers in a text preview before truncating", () => {
    const content = `${"x".repeat(98)} secret`;
    const preview = roomPreviewFor({
      type: "text",
      content,
      formatting: [{ start: 99, end: 105, type: "spoiler" }],
    });
    expect(preview).not.toContain("secret");
    expect(preview.length).toBeLessThanOrEqual(100);
  });

  test("a message that is all spoiler previews as the mask alone", () => {
    expect(
      roomPreviewFor({
        type: "text",
        content: "shh",
        formatting: [{ start: 0, end: 3, type: "spoiler" }],
      })
    ).toBe(SPOILER_MASK);
  });

  test("no formatting means the old preview, byte for byte", () => {
    expect(roomPreviewFor({ type: "text", content: "hello" })).toBe("hello");
    expect(roomPreviewFor({ type: "image", content: "cap" })).toBe("[image]");
  });
});

/**
 * The same promise, end to end: a spoiler never reaches a room card, whether
 * the message was sent after masking landed or before it.
 */
describe("spoilers on the room card", () => {
  const DEVICE = "device-a";

  async function signUp(t: ReturnType<typeof convexTest>, username: string) {
    return await t.mutation(api.auth.signup, {
      username,
      name: username,
      passwordHash: `hash-${username}`,
      recoveryKeyHash: `recovery-${username}`,
      deviceId: DEVICE,
    });
  }

  async function sendSpoiler(
    t: ReturnType<typeof convexTest>,
    who: { token: string; userId: string },
    roomId: any,
    content: string,
    start: number,
    end: number
  ) {
    return await t.mutation(api.messages.send, {
      sessionToken: who.token,
      userId: who.userId as any,
      roomId,
      content,
      formatting: [{ start, end, type: "spoiler" }],
    });
  }

  test("a freshly sent spoiler is masked on the card", async () => {
    const t = convexTest(schema);
    const author = await signUp(t, "author");
    const roomId = await t.mutation(api.rooms.create, {
      sessionToken: author.token,
      userId: author.userId as any,
      name: "room",
      isPrivate: false,
    });
    await sendSpoiler(t, author, roomId, "the winner is Ada", 14, 17);

    const room = await t.run((ctx) => ctx.db.get(roomId as Id<"rooms">));
    expect(room?.lastMessage).toBe(`the winner is ${SPOILER_MASK}`);
  });

  test("the backfill re-masks a card written before masking existed", async () => {
    const t = convexTest(schema);
    const author = await signUp(t, "author");
    const spoiled = await t.mutation(api.rooms.create, {
      sessionToken: author.token,
      userId: author.userId as any,
      name: "spoiled",
      isPrivate: false,
    });
    const plain = await t.mutation(api.rooms.create, {
      sessionToken: author.token,
      userId: author.userId as any,
      name: "plain",
      isPrivate: false,
    });
    await sendSpoiler(t, author, spoiled, "the winner is Ada", 14, 17);
    await t.mutation(api.messages.send, {
      sessionToken: author.token,
      userId: author.userId as any,
      roomId: plain,
      content: "nothing to hide",
    });

    // What a pre-deploy send left behind: the raw words on the card.
    await t.run(async (ctx) => {
      await ctx.db.patch(spoiled as Id<"rooms">, {
        lastMessage: "the winner is Ada",
      });
    });

    const result = await t.mutation(
      internal.migrations.backfillSpoilerPreviews,
      {}
    );
    expect(result.done).toBe(true);
    expect(result.patched).toBe(1);

    const fixed = await t.run((ctx) => ctx.db.get(spoiled as Id<"rooms">));
    expect(fixed?.lastMessage).toBe(`the winner is ${SPOILER_MASK}`);
    const untouched = await t.run((ctx) => ctx.db.get(plain as Id<"rooms">));
    expect(untouched?.lastMessage).toBe("nothing to hide");

    // Idempotent: a second run has nothing left to do.
    const again = await t.mutation(
      internal.migrations.backfillSpoilerPreviews,
      {}
    );
    expect(again.patched).toBe(0);
  });
});

// The receipts screen showed "read" at exactly the sent time: `markRoomRead`
// writes the read MESSAGE's createdAt as the cursor, and that cursor was what
// the screen displayed. The wall-clock stamp beside it is the read time.
describe("read receipts carry a real read time", () => {
  test("reading later stamps later, while the cursor stays the message's", async () => {
    vi.useFakeTimers({ toFake: ["Date"] });
    try {
      vi.setSystemTime(new Date("2026-10-03T10:00:00Z"));
      const t = convexTest(schema);
      const me = await t.mutation(api.auth.signup, {
        username: "reader",
        name: "reader",
        passwordHash: "hash-reader",
        recoveryKeyHash: "recovery-reader",
        deviceId: "device-a",
      });
      const roomId = await t.mutation(api.rooms.create, {
        sessionToken: me.token,
        userId: me.userId as any,
        name: "room",
        isPrivate: false,
      });
      await t.mutation(api.messages.send, {
        sessionToken: me.token,
        userId: me.userId as any,
        roomId,
        content: "hello",
      });
      const sent = (await t.run((ctx) =>
        ctx.db.get(roomId as Id<"rooms">)
      ))!.lastMessageTime!;

      vi.setSystemTime(new Date("2026-10-03T10:20:00Z"));
      // Rewind the cursor so this read is a real advance, whatever `send`
      // did to the author's own row.
      await t.run(async (ctx) => {
        const row = await ctx.db
          .query("roomMembers")
          .withIndex("by_room_user", (q) =>
            q.eq("roomId", roomId as any).eq("userId", me.userId as any)
          )
          .first();
        await ctx.db.patch(row!._id, { lastReadAt: 0, lastDeliveredAt: 0 });
      });
      await t.mutation(api.messages.markRoomRead, {
        sessionToken: me.token,
        userId: me.userId as any,
        roomId,
        upTo: sent,
      } as any);

      const state: any[] = await t.query(api.messages.getReadState, {
        sessionToken: me.token,
        roomId,
        viewerUserId: me.userId as any,
      } as any);
      const mine = state.find((r) => r.userId === me.userId);
      expect(mine.lastReadAt).toBe(sent);
      expect(mine.readClock).toBe(Date.parse("2026-10-03T10:20:00Z"));
      expect(mine.deliveredClock).toBe(Date.parse("2026-10-03T10:20:00Z"));
    } finally {
      vi.useRealTimers();
    }
  });
});
