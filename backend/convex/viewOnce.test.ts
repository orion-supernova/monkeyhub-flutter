import { convexTest } from "convex-test";
import { describe, expect, test } from "vitest";
import { api, internal } from "./_generated/api";
import { roomPreviewFor, viewOncePreviewFor } from "./messages";
import { viewOnceContentType } from "./http";
import { VIEW_ONCE_POSTER_MAX_BYTES } from "./files";
import type { Id } from "./_generated/dataModel";
import schema from "./schema";

/**
 * View-once beyond photos: voice messages and video notes.
 *
 * The photo path was written first and is type-agnostic in its core, so what
 * these pin is the part that is not: a video note's poster is the sender's
 * face and must never be stored, served or left behind; the room card and push
 * must name the kind without describing it; and the byte stream must carry a
 * type a player will accept.
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

const store = (t: ReturnType<typeof convexTest>, type: string, bytes = 512) =>
  t.run((ctx) =>
    ctx.storage.store(new Blob([new Uint8Array(bytes)], { type }))
  );

async function pair(t: ReturnType<typeof convexTest>) {
  const me = await signUp(t, "sender");
  const peer = await signUp(t, "peer");
  const roomId = await t.mutation(api.rooms.create, {
    sessionToken: me.token,
    userId: me.userId as any,
    name: "room",
    isPrivate: false,
  });
  await t.mutation(api.rooms.join, {
    sessionToken: peer.token,
    userId: peer.userId as any,
    roomId,
  } as any);
  return { me, peer, roomId };
}

describe("view-once previews", () => {
  test("name the kind, never the content", () => {
    expect(viewOncePreviewFor("image")).toBe("[photo]");
    expect(viewOncePreviewFor("audio")).toBe("[voice message]");
    expect(viewOncePreviewFor("videoNote")).toBe("[video note]");
    expect(viewOncePreviewFor("video")).toBe("[video]");
    expect(viewOncePreviewFor("file")).toBe("[media]");
    expect(
      roomPreviewFor({
        type: "file",
        fileName: "secret.pdf",
        content: "caption",
        viewOnce: true,
      })
    ).toBe("[media]");
    // Unarmed wording is untouched.
    expect(roomPreviewFor({ type: "audio", content: "" })).toBe("[audio]");
  });
});

describe("viewOnceContentType", () => {
  test("keeps a stored type from the message's own family", () => {
    expect(viewOnceContentType("audio", "audio/mp4")).toBe("audio/mp4");
    expect(viewOnceContentType("videoNote", "video/mp4")).toBe("video/mp4");
    expect(viewOnceContentType("image", "image/png")).toBe("image/png");
  });

  test("falls back to the family default when missing or foreign", () => {
    expect(viewOnceContentType("audio", "")).toBe("audio/mp4");
    expect(viewOnceContentType("audio", "text/html")).toBe("audio/mp4");
    expect(viewOnceContentType("videoNote", "application/octet-stream")).toBe(
      "video/mp4"
    );
    expect(viewOnceContentType("image", "")).toBe("image/jpeg");
    expect(viewOnceContentType("file", "text/html")).toBe(
      "application/octet-stream"
    );
  });
});

describe("view-once video note", () => {
  test("a full-size poster is deleted at send, the duration kept, the card generic", async () => {
    const t = convexTest(schema);
    const { me, roomId } = await pair(t);
    const video = await store(t, "video/mp4");
    const poster = await store(t, "image/jpeg", VIEW_ONCE_POSTER_MAX_BYTES + 1);

    const messageId = await t.mutation(api.messages.send, {
      sessionToken: me.token,
      userId: me.userId as any,
      roomId,
      content: "",
      type: "videoNote",
      mediaStorageId: video,
      posterStorageId: poster,
      mediaDurationMs: 4200,
      mediaWidth: 384,
      mediaHeight: 384,
      viewOnce: true,
      clientId: "vn-1",
    });

    const row = await t.run((ctx) =>
      ctx.db.get(messageId as Id<"messages">)
    );
    expect(row?.viewOnce).toBe(true);
    expect(row?.posterStorageId).toBeUndefined();
    expect(row?.mediaDurationMs).toBe(4200);
    expect(row?.mediaWidth).toBeUndefined();
    expect(row?.galleryBucket).toBeUndefined();
    // The poster blob itself is gone, not merely unreferenced.
    expect(await t.run((ctx) => ctx.db.system.get(poster))).toBeNull();
    expect(await t.run((ctx) => ctx.db.system.get(video))).not.toBeNull();

    const room = await t.run((ctx) => ctx.db.get(roomId as Id<"rooms">));
    expect(room?.lastMessage).toBe("[video note]");

    // A retry presents the same, now-deleted poster: it must return the
    // original row rather than throw FILE_NOT_FOUND.
    const again = await t.mutation(api.messages.send, {
      sessionToken: me.token,
      userId: me.userId as any,
      roomId,
      content: "",
      type: "videoNote",
      mediaStorageId: video,
      posterStorageId: poster,
      viewOnce: true,
      clientId: "vn-1",
    });
    expect(again).toBe(messageId);
  });

  test("a micro poster is kept, served to members, and burned with the note", async () => {
    const t = convexTest(schema);
    const { me, peer, roomId } = await pair(t);
    const outsider = await signUp(t, "outsider");
    const video = await store(t, "video/mp4");
    const poster = await store(t, "image/jpeg", VIEW_ONCE_POSTER_MAX_BYTES);
    const messageId = await t.mutation(api.messages.send, {
      sessionToken: me.token,
      userId: me.userId as any,
      roomId,
      content: "",
      type: "videoNote",
      mediaStorageId: video,
      posterStorageId: poster,
      viewOnce: true,
    });
    const listed = (await t.query(api.messages.list, {
      sessionToken: peer.token,
      roomId,
      viewerUserId: peer.userId as any,
    } as any)) as any[];
    const m = listed.find((x) => x._id === messageId);
    expect(m.posterStorageId).toBe(poster);
    expect(m.mediaStorageId).toBeUndefined();
    const url = (storageId: any, who: any) =>
      t.query(api.files.getFileUrl, { sessionToken: who.token, storageId } as any);
    expect(await url(poster, peer)).not.toBeNull();
    expect(await url(poster, outsider)).toBeNull();
    expect(await url(video, peer)).toBeNull();

    await t.mutation(internal.messages.burnViewOnce, {
      messageId: messageId as Id<"messages">,
    });
    expect(await t.run((ctx) => ctx.db.system.get(poster))).toBeNull();
  });

  test("a micro poster on an armed voice message is deleted", async () => {
    const t = convexTest(schema);
    const { me, roomId } = await pair(t);
    const audio = await store(t, "audio/mp4");
    const poster = await store(t, "image/jpeg", 100);
    const messageId = await t.mutation(api.messages.send, {
      sessionToken: me.token,
      userId: me.userId as any,
      roomId,
      content: "",
      type: "audio",
      mediaStorageId: audio,
      posterStorageId: poster,
      viewOnce: true,
    });
    const row = await t.run((ctx) => ctx.db.get(messageId as Id<"messages">));
    expect(row?.posterStorageId).toBeUndefined();
    expect(await t.run((ctx) => ctx.db.system.get(poster))).toBeNull();
  });

  test("normal URLs refuse both the media and a full poster on an armed row", async () => {
    const t = convexTest(schema);
    const { me, peer, roomId } = await pair(t);
    const video = await store(t, "video/mp4");
    const messageId = await t.mutation(api.messages.send, {
      sessionToken: me.token,
      userId: me.userId as any,
      roomId,
      content: "",
      type: "videoNote",
      mediaStorageId: video,
      viewOnce: true,
    });
    // A full poster that reached an armed row some other way (an older server).
    const poster = await store(t, "image/jpeg", VIEW_ONCE_POSTER_MAX_BYTES + 1);
    await t.run((ctx) =>
      ctx.db.patch(messageId as Id<"messages">, { posterStorageId: poster })
    );

    for (const storageId of [video, poster]) {
      expect(
        await t.query(api.files.getFileUrl, {
          sessionToken: peer.token,
          storageId,
        } as any)
      ).toBeNull();
    }

    // The transcript never carries either id.
    const listed = (await t.query(api.messages.list, {
      sessionToken: peer.token,
      roomId,
      viewerUserId: peer.userId as any,
    } as any)) as any[];
    const m = listed.find((x) => x._id === messageId);
    expect(m.mediaStorageId).toBeUndefined();
    expect(m.posterStorageId).toBeUndefined();

    // The burn takes the poster with the media.
    await t.mutation(internal.messages.burnViewOnce, {
      messageId: messageId as Id<"messages">,
    });
    expect(await t.run((ctx) => ctx.db.system.get(video))).toBeNull();
    expect(await t.run((ctx) => ctx.db.system.get(poster))).toBeNull();
    const ghost = await t.run((ctx) =>
      ctx.db.get(messageId as Id<"messages">)
    );
    expect(ghost?.posterStorageId).toBeUndefined();
    expect(ghost?.viewOnceBurnedAt).toBeDefined();
  });

  test("a poster on an UNarmed video is members-only", async () => {
    const t = convexTest(schema);
    const { me, peer, roomId } = await pair(t);
    const outsider = await signUp(t, "outsider");
    const video = await store(t, "video/mp4");
    const poster = await store(t, "image/jpeg");
    await t.mutation(api.messages.send, {
      sessionToken: me.token,
      userId: me.userId as any,
      roomId,
      content: "",
      type: "videoNote",
      mediaStorageId: video,
      posterStorageId: poster,
    });
    expect(
      await t.query(api.files.getFileUrl, {
        sessionToken: peer.token,
        storageId: poster,
      } as any)
    ).not.toBeNull();
    expect(
      await t.query(api.files.getFileUrl, {
        sessionToken: outsider.token,
        storageId: poster,
      } as any)
    ).toBeNull();
  });
});

describe("view-once voice message", () => {
  test("opens once, streams with an audio type, then burns", async () => {
    const t = convexTest(schema);
    const { me, peer, roomId } = await pair(t);
    const audio = await store(t, "audio/mp4");
    const messageId = await t.mutation(api.messages.send, {
      sessionToken: me.token,
      userId: me.userId as any,
      roomId,
      content: "",
      type: "audio",
      mediaStorageId: audio,
      mediaDurationMs: 12000,
      mimeType: "audio/mp4",
      viewOnce: true,
    });
    const room = await t.run((ctx) => ctx.db.get(roomId as Id<"rooms">));
    expect(room?.lastMessage).toBe("[voice message]");
    const row = await t.run((ctx) => ctx.db.get(messageId as Id<"messages">));
    expect(row?.mediaDurationMs).toBe(12000);
    expect(row?.mimeType).toBeUndefined();

    const grant = (await t.mutation(api.messages.openViewOnce, {
      sessionToken: peer.token,
      messageId: messageId as Id<"messages">,
      userId: peer.userId as any,
    } as any)) as any;
    expect(typeof grant.nonce).toBe("string");

    const res = await t.fetch(
      `/viewOnce?m=${messageId}&u=${peer.userId}&n=${grant.nonce}`,
      { method: "GET", headers: { Range: "bytes=0-1" } }
    );
    expect(res.status).toBe(200);
    expect(res.headers.get("Content-Type")).toBe("audio/mp4");
    expect(res.headers.get("Accept-Ranges")).toBe("none");
    expect((await res.arrayBuffer()).byteLength).toBe(512);

    // Second open: already spent (the ticket is reused inside its window,
    // but no fresh one is minted).
    const second = (await t.mutation(api.messages.openViewOnce, {
      sessionToken: peer.token,
      messageId: messageId as Id<"messages">,
      userId: peer.userId as any,
    } as any)) as any;
    expect(second.nonce === grant.nonce || second.alreadyViewed === true).toBe(
      true
    );

    await t.mutation(internal.messages.burnViewOnce, {
      messageId: messageId as Id<"messages">,
    });
    expect(await t.run((ctx) => ctx.db.system.get(audio))).toBeNull();
    const dead = await t.fetch(
      `/viewOnce?m=${messageId}&u=${peer.userId}&n=${grant.nonce}`,
      { method: "GET" }
    );
    expect(dead.status).toBe(403);
  });

  test("a reply to it carries no storage id and no content", async () => {
    const t = convexTest(schema);
    const { me, peer, roomId } = await pair(t);
    const audio = await store(t, "audio/mp4");
    const parent = await t.mutation(api.messages.send, {
      sessionToken: me.token,
      userId: me.userId as any,
      roomId,
      content: "",
      type: "audio",
      mediaStorageId: audio,
      viewOnce: true,
    });
    const reply = await t.mutation(api.messages.send, {
      sessionToken: peer.token,
      userId: peer.userId as any,
      roomId,
      content: "ok",
      replyToId: parent as Id<"messages">,
    });
    const row = await t.run((ctx) => ctx.db.get(reply as Id<"messages">));
    expect(row?.replyToPreview?.type).toBe("audio");
    expect(row?.replyToPreview?.mediaStorageId).toBeUndefined();
    expect(row?.replyToPreview?.contentPreview).toBe("__VIEW_ONCE__");
  });
});
