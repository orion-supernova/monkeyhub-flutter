import { convexTest } from "convex-test";
import { describe, expect, test } from "vitest";
import { api, internal } from "./_generated/api";
import type { Id } from "./_generated/dataModel";
import { emojiForCode, OFFICIAL_PACKS } from "./expressions";
import { isKlipyUrl, permissionsFor, roomPreviewFor } from "./messages";
import schema from "./schema";

/**
 * GIFs and stickers: what `messages:send` lets onto a row, what the child
 * guard makes of it, and the recents/favourites/personal-pack bookkeeping.
 *
 * The URL tests matter most. A GIF row's `mediaUrl` is loaded by every member's
 * app the moment it scrolls into view, so the host check in `isKlipyUrl` is
 * the only thing standing between this feature and a way to plant a tracking
 * pixel in somebody else's transcript.
 */

const DEVICE = "device-a";
const GIF = "https://static.klipy.com/ii/abc/59/da/jp6423Rq.webp";
const GIF_PREVIEW = "https://static.klipy.com/ii/abc/59/da/uKXF.jpg";

async function signUp(t: ReturnType<typeof convexTest>, username: string) {
  return await t.mutation(api.auth.signup, {
    username,
    name: username,
    passwordHash: `hash-${username}`,
    recoveryKeyHash: `recovery-${username}`,
    deviceId: DEVICE,
  });
}

async function setup() {
  const t = convexTest(schema);
  const me = await signUp(t, "sender");
  const roomId = await t.mutation(api.rooms.create, {
    sessionToken: me.token,
    userId: me.userId as any,
    name: "room",
    isPrivate: false,
  });
  return { t, me, roomId: roomId as Id<"rooms"> };
}

/** A one-sticker official pack, inserted directly. */
async function officialSticker(t: ReturnType<typeof convexTest>) {
  return await t.run(async (ctx) => {
    const packId = await ctx.db.insert("stickerPacks", {
      slug: "test-pack",
      title: "Test",
      kind: "official",
      order: 0,
      createdAt: Date.now(),
    });
    const storageId = await ctx.storage.store(
      new Blob(["{}"], { type: "application/json" })
    );
    const stickerId = await ctx.db.insert("stickers", {
      packId,
      storageId,
      format: "lottie",
      emoji: "😂",
      width: 512,
      height: 512,
      order: 0,
      createdAt: Date.now(),
    });
    return { packId, storageId, stickerId };
  });
}

describe("isKlipyUrl", () => {
  test("accepts KLIPY's hosts over https", () => {
    expect(isKlipyUrl(GIF)).toBe(true);
    expect(isKlipyUrl("https://static2.klipy.com/x.gif")).toBe(true);
    expect(isKlipyUrl("https://klipy.com/x.gif")).toBe(true);
  });

  test("refuses everything else", () => {
    expect(isKlipyUrl("http://static.klipy.com/x.gif")).toBe(false);
    expect(isKlipyUrl("https://evil.com/x.gif")).toBe(false);
    // The classic suffix trick: ends with the right letters, wrong domain.
    expect(isKlipyUrl("https://notklipy.com/x.gif")).toBe(false);
    expect(isKlipyUrl("https://klipy.com.evil.com/x.gif")).toBe(false);
    expect(isKlipyUrl("https://evil.com/?u=https://klipy.com")).toBe(false);
    expect(isKlipyUrl("javascript:alert(1)")).toBe(false);
    expect(isKlipyUrl("")).toBe(false);
    expect(isKlipyUrl(undefined)).toBe(false);
    expect(isKlipyUrl(`https://static.klipy.com/${"a".repeat(3000)}`)).toBe(false);
  });
});

describe("permissionsFor", () => {
  test("an official pack sticker needs no media grant", () => {
    expect(permissionsFor("sticker", false, "pack")).toEqual({
      location: false,
      media: false,
    });
  });

  test("KLIPY media and personal stickers are pictures", () => {
    expect(permissionsFor("gif", false, "klipy").media).toBe(true);
    expect(permissionsFor("sticker", false, "klipy").media).toBe(true);
    expect(permissionsFor("sticker", false, "personal").media).toBe(true);
    // No source at all is not an official pack either.
    expect(permissionsFor("sticker", false, undefined).media).toBe(true);
  });
});

describe("roomPreviewFor", () => {
  test("names a GIF without its title and a sticker by its emoji", () => {
    expect(roomPreviewFor({ type: "gif", content: "Hello" })).toBe("[GIF]");
    expect(roomPreviewFor({ type: "sticker", content: "😂" })).toBe(
      "[sticker] 😂"
    );
  });
});

describe("sending a GIF", () => {
  test("a KLIPY GIF lands with its URLs and size", async () => {
    const { t, me, roomId } = await setup();
    const id = await t.mutation(api.messages.send, {
      sessionToken: me.token,
      userId: me.userId as any,
      roomId,
      content: "Hello",
      type: "gif",
      mediaSource: "klipy",
      mediaUrl: GIF,
      mediaPreviewUrl: GIF_PREVIEW,
      mediaRef: "hello-hi-662",
      mediaWidth: 498,
      mediaHeight: 374,
    });
    const msg = await t.run((ctx) => ctx.db.get(id as Id<"messages">));
    expect(msg).toMatchObject({
      type: "gif",
      content: "Hello",
      mediaSource: "klipy",
      mediaUrl: GIF,
      mediaPreviewUrl: GIF_PREVIEW,
      mediaRef: "hello-hi-662",
      mediaWidth: 498,
      mediaHeight: 374,
    });
    expect(msg?.galleryBucket).toBeUndefined();
    const room = await t.run((ctx) => ctx.db.get(roomId));
    expect(room?.lastMessage).toBe("[GIF]");
  });

  test("a foreign host is downgraded to text and the URL never stored", async () => {
    const { t, me, roomId } = await setup();
    const id = await t.mutation(api.messages.send, {
      sessionToken: me.token,
      userId: me.userId as any,
      roomId,
      content: "Hello",
      type: "gif",
      mediaSource: "klipy",
      mediaUrl: "https://tracker.example/pixel.gif",
    });
    const msg = await t.run((ctx) => ctx.db.get(id as Id<"messages">));
    expect(msg?.type).toBe("text");
    expect(msg?.mediaUrl).toBeUndefined();
  });

  test("a bad preview URL is dropped without losing the GIF", async () => {
    const { t, me, roomId } = await setup();
    const id = await t.mutation(api.messages.send, {
      sessionToken: me.token,
      userId: me.userId as any,
      roomId,
      content: "",
      type: "gif",
      mediaSource: "klipy",
      mediaUrl: GIF,
      mediaPreviewUrl: "https://tracker.example/p.jpg",
    });
    const msg = await t.run((ctx) => ctx.db.get(id as Id<"messages">));
    expect(msg?.type).toBe("gif");
    expect(msg?.mediaPreviewUrl).toBeUndefined();
    // Empty alt text is filled so an old app has something to show.
    expect(msg?.content).toBe("GIF");
  });

  test("a GIF cannot smuggle an uploaded blob", async () => {
    const { t, me, roomId } = await setup();
    const blob = await t.run((ctx) =>
      ctx.storage.store(new Blob(["x"], { type: "image/png" }))
    );
    const id = await t.mutation(api.messages.send, {
      sessionToken: me.token,
      userId: me.userId as any,
      roomId,
      content: "Hello",
      type: "gif",
      mediaSource: "klipy",
      mediaUrl: GIF,
      mediaStorageId: blob,
    });
    const msg = await t.run((ctx) => ctx.db.get(id as Id<"messages">));
    expect(msg?.mediaStorageId).toBeUndefined();
  });
});

describe("sending a sticker", () => {
  test("a pack sticker's blob, format and size come from its row", async () => {
    const { t, me, roomId } = await setup();
    const { stickerId, storageId } = await officialSticker(t);
    const id = await t.mutation(api.messages.send, {
      sessionToken: me.token,
      userId: me.userId as any,
      roomId,
      content: "",
      type: "sticker",
      stickerId,
      // Lies the server must ignore.
      mediaWidth: 1,
      mediaHeight: 9999,
      mediaSource: "klipy",
    });
    const msg = await t.run((ctx) => ctx.db.get(id as Id<"messages">));
    expect(msg).toMatchObject({
      type: "sticker",
      mediaSource: "pack",
      stickerId,
      stickerStorageId: storageId,
      stickerFormat: "lottie",
      mediaWidth: 512,
      mediaHeight: 512,
    });
    expect(msg?.mediaStorageId).toBeUndefined();
    const room = await t.run((ctx) => ctx.db.get(roomId));
    // Empty alt text falls back to the sticker's own emoji.
    expect(room?.lastMessage).toBe("[sticker] 😂");
  });

  test("deleting a sticker message leaves the pack's blob alone", async () => {
    const { t, me, roomId } = await setup();
    const { stickerId, storageId } = await officialSticker(t);
    const id = await t.mutation(api.messages.send, {
      sessionToken: me.token,
      userId: me.userId as any,
      roomId,
      content: "😂",
      type: "sticker",
      stickerId,
    });
    await t.mutation(api.messages.deleteMessage, {
      sessionToken: me.token,
      userId: me.userId as any,
      messageId: id,
    });
    const meta = await t.run((ctx) => ctx.db.system.get(storageId));
    expect(meta).not.toBeNull();
  });

  test("a deleted personal sticker can no longer be sent", async () => {
    const { t, me, roomId } = await setup();
    const blob = await t.run((ctx) =>
      ctx.storage.store(new Blob(["png"], { type: "image/png" }))
    );
    const stickerId = await t.mutation(api.expressions.createPersonalSticker, {
      sessionToken: me.token,
      storageId: blob,
      emoji: "🐶",
      width: 400,
      height: 380,
    });
    await t.mutation(api.expressions.deletePersonalSticker, {
      sessionToken: me.token,
      stickerId,
    });
    const id = await t.mutation(api.messages.send, {
      sessionToken: me.token,
      userId: me.userId as any,
      roomId,
      content: "🐶",
      type: "sticker",
      stickerId,
    });
    const msg = await t.run((ctx) => ctx.db.get(id as Id<"messages">));
    expect(msg?.type).toBe("text");
  });

  test("forwarding carries the picture", async () => {
    const { t, me, roomId } = await setup();
    const target = await t.mutation(api.rooms.create, {
      sessionToken: me.token,
      userId: me.userId as any,
      name: "other",
      isPrivate: false,
    });
    const id = await t.mutation(api.messages.send, {
      sessionToken: me.token,
      userId: me.userId as any,
      roomId,
      content: "Hello",
      type: "gif",
      mediaSource: "klipy",
      mediaUrl: GIF,
    });
    await t.mutation(api.messages.forwardToRoom, {
      sessionToken: me.token,
      userId: me.userId as any,
      sourceRoomId: roomId,
      targetRoomId: target,
      messageIds: [id],
    });
    const copy = await t.run(async (ctx) =>
      (
        await ctx.db
          .query("messages")
          .withIndex("by_room_time", (q) => q.eq("roomId", target as any))
          .collect()
      ).find((m) => m.type === "gif")
    );
    expect(copy?.mediaUrl).toBe(GIF);
    expect(copy?.mediaSource).toBe("klipy");
  });
});

describe("recents and favourites", () => {
  const ref = {
    kind: "gif",
    source: "klipy",
    url: GIF,
    previewUrl: GIF_PREVIEW,
    ref: "hello",
    width: 498,
    height: 374,
    title: "Hello",
  };

  test("recents dedupe and move to the front", async () => {
    const { t, me } = await setup();
    const other = { ...ref, url: "https://static.klipy.com/other.webp" };
    for (const r of [ref, other, ref]) {
      await t.mutation(api.expressions.recordUse, {
        sessionToken: me.token,
        ref: r,
      });
    }
    const s = await t.query(api.expressions.state, { sessionToken: me.token });
    expect(s.recents.map((r: any) => r.url)).toEqual([GIF, other.url]);
  });

  test("a foreign URL is never remembered", async () => {
    const { t, me } = await setup();
    await t.mutation(api.expressions.recordUse, {
      sessionToken: me.token,
      ref: { ...ref, url: "https://tracker.example/x.gif" },
    });
    const s = await t.query(api.expressions.state, { sessionToken: me.token });
    expect(s.recents).toEqual([]);
  });

  test("toggling a favourite twice removes it", async () => {
    const { t, me } = await setup();
    const args = { sessionToken: me.token, ref };
    expect(await t.mutation(api.expressions.toggleFavorite, args)).toBe(true);
    expect(await t.mutation(api.expressions.toggleFavorite, args)).toBe(false);
    const s = await t.query(api.expressions.state, { sessionToken: me.token });
    expect(s.favorites).toEqual([]);
  });
});

describe("personal stickers", () => {
  test("only the owner may delete one", async () => {
    const { t, me } = await setup();
    const stranger = await signUp(t, "stranger");
    const blob = await t.run((ctx) =>
      ctx.storage.store(new Blob(["png"], { type: "image/png" }))
    );
    const stickerId = await t.mutation(api.expressions.createPersonalSticker, {
      sessionToken: me.token,
      storageId: blob,
      emoji: "🐶",
      width: 400,
      height: 400,
    });
    await expect(
      t.mutation(api.expressions.deletePersonalSticker, {
        sessionToken: stranger.token,
        stickerId,
      })
    ).rejects.toThrow("NOT_AUTHORIZED");
  });

  test("the personal pack is listed only to its owner", async () => {
    const { t, me } = await setup();
    const stranger = await signUp(t, "stranger");
    const blob = await t.run((ctx) =>
      ctx.storage.store(new Blob(["png"], { type: "image/png" }))
    );
    await t.mutation(api.expressions.createPersonalSticker, {
      sessionToken: me.token,
      storageId: blob,
      emoji: "🐶",
      width: 400,
      height: 400,
    });
    const mine = await t.query(api.expressions.packs, { sessionToken: me.token });
    const theirs = await t.query(api.expressions.packs, {
      sessionToken: stranger.token,
    });
    expect(mine.map((p: any) => p.kind)).toEqual(["personal"]);
    expect(theirs).toEqual([]);
  });

  test("the sweep keeps sticker blobs", async () => {
    const { t } = await setup();
    const { storageId } = await officialSticker(t);
    await t.mutation(internal.files.gcOrphanedFiles, { graceMs: 0 });
    const meta = await t.run((ctx) => ctx.db.system.get(storageId));
    expect(meta).not.toBeNull();
  });
});

describe("official packs", () => {
  test("every codepoint decodes to an emoji", () => {
    expect(emojiForCode("1f602")).toBe("😂");
    expect(emojiForCode("2764_fe0f")).toBe("❤️");
    for (const pack of OFFICIAL_PACKS) {
      const emoji = pack.codes.map(emojiForCode);
      // Seeding dedupes on the emoji, so a repeat would silently vanish.
      expect(new Set(emoji).size).toBe(emoji.length);
    }
  });
});
