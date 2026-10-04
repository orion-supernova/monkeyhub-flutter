import { convexTest } from "convex-test";
import { makeFunctionReference } from "convex/server";
import { expect, test } from "vitest";
import { api } from "./_generated/api";
import schema from "./schema";

const send = makeFunctionReference<"mutation">("designSamples:send");
const inspect = makeFunctionReference<"query">("designSamples:inspect");

async function fixture() {
  const t = convexTest(schema);
  const owner = await t.mutation(api.auth.signup, {
    username: "designer", name: "Designer", passwordHash: "test-hash",
    recoveryKeyHash: "test-recovery", deviceId: "design-test-device",
  });
  const roomId = await t.mutation(api.rooms.ensureSavedMessagesRoom, {
    userId: owner.userId as any, sessionToken: owner.token,
  });
  const assets = await t.run(async ctx => {
    const store = () => ctx.storage.store(new Blob(["sample"], { type: "image/png" }));
    const media = {
      image: await store(), video: await store(), videoNote: await store(),
      audio: await store(), file: await store(), videoPoster: await store(), videoNotePoster: await store(),
    };
    const packId = await ctx.db.insert("stickerPacks", {
      slug: "design-test", title: "Test", kind: "official", order: 0, createdAt: Date.now(),
    });
    const stickerId = await ctx.db.insert("stickers", {
      packId, storageId: await store(), format: "image", emoji: "✨",
      width: 512, height: 512, order: 0, createdAt: Date.now(),
    });
    return { media, stickerId };
  });
  const args = { username: "designer", ...assets, gif: {
    url: "https://static.klipy.com/design-test.webp", width: 320, height: 240,
  } };
  return { t, owner, roomId, args };
}

test("all 15 types renderable; four interactive bodies remain usable and retries preserve edits", async () => {
  const { t, owner, roomId, args } = await fixture();
  const first = await t.mutation(send, args);
  expect(first.messages).toHaveLength(16); // All types plus a quiz variant.
  const rows = await t.run(ctx => ctx.db.query("messages")
    .withIndex("by_room_time", q => q.eq("roomId", roomId)).collect());
  expect(new Set(rows.map(m => m.type))).toEqual(new Set([
    "text", "image", "video", "videoNote", "audio", "file", "gif", "sticker",
    "url", "system", "location", "liveLocation", "poll", "checklist", "event",
  ]));
  expect(rows.map(m => m.type)).toEqual(first.messages.map((m: any) => m.type));
  const bodies = await t.query(api.interactions.listForRoom, {
    sessionToken: owner.token, viewerUserId: owner.userId as any, roomId,
  });
  expect(bodies).toHaveLength(4);
  for (const variant of ["poll", "quiz", "checklist", "event"]) {
    const messageId = first.messages.find((m: any) => m.variant === variant)!.id;
    const choiceId = variant === "event" ? "going" : "1";
    await t.mutation(api.interactions.respond, {
      sessionToken: owner.token, userId: owner.userId as any, messageId, choiceId,
    });
  }
  await t.run(ctx => ctx.db.patch(rows[0]._id, { content: "My edited sample" }));
  const beforeRoom = await t.run(ctx => ctx.db.get(roomId));
  const second = await t.mutation(send, args);
  expect(second.messages.every((m: any) => !m.added)).toBe(true);
  expect(second.messages.map((m: any) => m.id)).toEqual(first.messages.map((m: any) => m.id));
  const after = await t.run(ctx => ctx.db.query("messages")
    .withIndex("by_room_time", q => q.eq("roomId", roomId)).collect());
  expect(after).toHaveLength(16);
  expect(after[0].content).toBe("My edited sample");
  expect(await t.run(ctx => ctx.db.get(roomId))).toEqual(beforeRoom);
  const state = await t.query(inspect, { username: "designer" });
  expect(state.samples).toHaveLength(16);
  expect(state.stickerId).toBe(args.stickerId);
});

test("refuses a shared room even if it has the canonical Saved Messages name", async () => {
  const { t, roomId, args } = await fixture();
  await t.run(ctx => ctx.db.patch(roomId, { memberCount: 2 }));
  await expect(t.mutation(send, args)).rejects.toThrow("SAMPLE_SAVED_ROOM_REQUIRED");
  expect(await t.run(ctx => ctx.db.query("messages").collect())).toHaveLength(0);
});

test("refuses missing accounts and non-provider GIFs before writing any messages", async () => {
  const { t, args } = await fixture();
  await expect(t.mutation(send, { ...args, username: "unknown" })).rejects.toThrow("SAMPLE_USER_NOT_FOUND");
  await expect(t.mutation(send, { ...args, gif: { url: "https://example.com/image.gif" } }))
    .rejects.toThrow("SAMPLE_REAL_GIF_REQUIRED");
  expect(await t.run(ctx => ctx.db.query("messages").collect())).toHaveLength(0);
});
