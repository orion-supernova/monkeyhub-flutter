import { convexTest } from "convex-test";
import { describe, expect, test } from "vitest";
import { api, internal } from "./_generated/api";
import schema from "./schema";

/**
 * Scheduled PHOTOS, executed.
 *
 * A scheduled photo is uploaded when it is scheduled and sits in storage with
 * the scheduled row as its only pointer until it goes out — possibly a year
 * later. The promises worth pinning are the ones about that file:
 *
 *   1. It goes out as a real photo, with its caption, when released.
 *   2. Cancelling (or a purge) takes the file with it — nothing else will.
 *   3. The orphan sweep does NOT see it as an orphan while it waits.
 *   4. A photo and its file come together or not at all.
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

type Who = { token: string; userId: string };

async function makeRoom(t: ReturnType<typeof convexTest>, owner: Who) {
  return await t.mutation(api.rooms.create, {
    sessionToken: owner.token,
    userId: owner.userId as any,
    name: "the group",
    isPrivate: false,
  });
}

async function upload(t: ReturnType<typeof convexTest>) {
  return await t.run(
    async (ctx: any) =>
      await ctx.storage.store(new Blob(["jpeg"], { type: "image/jpeg" }))
  );
}

async function stored(t: ReturnType<typeof convexTest>, storageId: any) {
  return await t.run(
    async (ctx: any) => (await ctx.storage.get(storageId)) !== null
  );
}

async function schedulePhoto(
  t: ReturnType<typeof convexTest>,
  who: Who,
  roomId: any,
  storageId: any,
  caption = "",
  clientId = "sch_1"
) {
  return await t.mutation(api.scheduledMessages.schedule, {
    sessionToken: who.token,
    userId: who.userId as any,
    roomId,
    content: caption,
    delayMs: 60 * 60 * 1000,
    type: "image",
    mediaStorageId: storageId,
    mediaWidth: 1200,
    mediaHeight: 900,
    clientId,
  } as any);
}

async function rowOf(t: ReturnType<typeof convexTest>, id: any) {
  return await t.run(async (ctx: any) => await ctx.db.get(id));
}

describe("scheduled photos", () => {
  test("release posts the photo with its caption, and keeps the file", async () => {
    const t = convexTest(schema);
    const me = await signUp(t, "sender");
    const roomId = await makeRoom(t, me);
    const file = await upload(t);

    const id = await schedulePhoto(t, me, roomId, file, "  sunset  ");
    const row = await rowOf(t, id);
    expect(row.type).toBe("image");
    expect(row.content).toBe("sunset");

    await t.mutation(internal.scheduledMessages.release, {
      id,
      expectSendAt: row.sendAt,
    });

    expect(await rowOf(t, id)).toBeNull();
    const sent = await t.run(async (ctx: any) =>
      (await ctx.db.query("messages").collect()).filter(
        (m: any) => m.type === "image"
      )
    );
    expect(sent).toHaveLength(1);
    expect(sent[0].content).toBe("sunset");
    expect(sent[0].mediaStorageId).toEqual(file);
    expect(sent[0].mediaWidth).toBe(1200);
    // The message is the file's pointer now; it must still be there.
    expect(await stored(t, file)).toBe(true);
  });

  test("a photo needs no caption", async () => {
    const t = convexTest(schema);
    const me = await signUp(t, "sender");
    const roomId = await makeRoom(t, me);
    const id = await schedulePhoto(t, me, roomId, await upload(t));
    expect((await rowOf(t, id)).content).toBe("");
  });

  test("cancelling deletes the file, which nothing else points at", async () => {
    const t = convexTest(schema);
    const me = await signUp(t, "sender");
    const roomId = await makeRoom(t, me);
    const file = await upload(t);
    const id = await schedulePhoto(t, me, roomId, file);

    await t.mutation(api.scheduledMessages.cancel, {
      sessionToken: me.token,
      userId: me.userId as any,
      id,
    } as any);

    expect(await rowOf(t, id)).toBeNull();
    expect(await stored(t, file)).toBe(false);
  });

  test("the orphan sweep leaves a waiting photo alone", async () => {
    const t = convexTest(schema);
    const me = await signUp(t, "sender");
    const roomId = await makeRoom(t, me);
    const file = await upload(t);
    await schedulePhoto(t, me, roomId, file);

    const report: any = await t.query(internal.files.listOrphans, {});
    const orphanIds = (report.orphans ?? []).map((o: any) =>
      o.storageId.toString()
    );
    expect(orphanIds).not.toContain(file.toString());
  });

  test("a photo without its file, or a file on a text row, is refused", async () => {
    const t = convexTest(schema);
    const me = await signUp(t, "sender");
    const roomId = await makeRoom(t, me);

    await expect(
      t.mutation(api.scheduledMessages.schedule, {
        sessionToken: me.token,
        userId: me.userId as any,
        roomId,
        content: "",
        delayMs: 60 * 60 * 1000,
        type: "image",
        clientId: "sch_a",
      } as any)
    ).rejects.toThrow("SCHEDULE_BAD_MEDIA");

    await expect(
      t.mutation(api.scheduledMessages.schedule, {
        sessionToken: me.token,
        userId: me.userId as any,
        roomId,
        content: "hi",
        delayMs: 60 * 60 * 1000,
        mediaStorageId: await upload(t),
        clientId: "sch_b",
      } as any)
    ).rejects.toThrow("SCHEDULE_BAD_MEDIA");
  });

  test("a caption can be taken off a photo, but text cannot be emptied", async () => {
    const t = convexTest(schema);
    const me = await signUp(t, "sender");
    const roomId = await makeRoom(t, me);
    const photo = await schedulePhoto(t, me, roomId, await upload(t), "hi");

    await t.mutation(api.scheduledMessages.updateText, {
      sessionToken: me.token,
      userId: me.userId as any,
      id: photo,
      content: "",
    } as any);
    expect((await rowOf(t, photo)).content).toBe("");

    const text = await t.mutation(api.scheduledMessages.schedule, {
      sessionToken: me.token,
      userId: me.userId as any,
      roomId,
      content: "hello",
      delayMs: 60 * 60 * 1000,
      clientId: "sch_t",
    } as any);
    await expect(
      t.mutation(api.scheduledMessages.updateText, {
        sessionToken: me.token,
        userId: me.userId as any,
        id: text,
        content: "  ",
      } as any)
    ).rejects.toThrow("SCHEDULE_EMPTY");
  });
});

describe("scheduled spoiler photos", () => {
  test("a scheduled spoiler photo is released as a spoiler", async () => {
    const t = convexTest(schema);
    const me = await signUp(t, "sender");
    const roomId = await makeRoom(t, me);
    const id = await t.mutation(api.scheduledMessages.schedule, {
      sessionToken: me.token,
      userId: me.userId as any,
      roomId,
      content: "",
      delayMs: 60 * 60 * 1000,
      type: "image",
      mediaStorageId: await upload(t),
      mediaSpoiler: true,
      clientId: "sch_spoiler",
    } as any);
    const row = await rowOf(t, id);
    expect(row.mediaSpoiler).toBe(true);

    await t.mutation(internal.scheduledMessages.release, {
      id,
      expectSendAt: row.sendAt,
    });
    const sent = await t.run(async (ctx: any) =>
      (await ctx.db.query("messages").collect()).filter(
        (m: any) => m.type === "image"
      )
    );
    expect(sent).toHaveLength(1);
    expect(sent[0].mediaSpoiler).toBe(true);
  });
});
