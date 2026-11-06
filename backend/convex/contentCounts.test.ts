import { convexTest } from "convex-test";
import { describe, expect, test } from "vitest";
import { api, internal } from "./_generated/api";
import type { Id } from "./_generated/dataModel";
import schema from "./schema";

// Vite inlines every module's text at transform time, so no node:fs is needed.
const RAW: Record<string, string> = (import.meta as any).glob(
  ["./*.ts", "./**/*.ts", "!./_generated/**"],
  { query: "?raw", import: "default", eager: true }
);

/**
 * The write hook is only as good as its coverage: a mutation built from the
 * generated builders writes messages without updating `roomContentCounts`, and
 * the counts drift silently. So the rule is a test, the way the session
 * boundary is.
 */
describe("every mutation goes through the write hooks", () => {
  test("no file imports a mutation builder from _generated/server", () => {
    const offenders: string[] = [];
    for (const [path, src] of Object.entries(RAW)) {
      if (path.endsWith(".test.ts") || path.endsWith("/dbHooks.ts")) continue;
      const imports = src.matchAll(
        /^import\s*\{([^}]*)\}\s*from\s*"(?:\.\.?\/)+_generated\/server"/gm
      );
      for (const m of imports) {
        const names = m[1].split(",").map((s) => s.trim().split(/\s+as\s+/)[0]);
        if (names.includes("mutation") || names.includes("internalMutation")) {
          offenders.push(path);
        }
      }
    }
    expect(Object.keys(RAW).length).toBeGreaterThan(50);
    expect(offenders).toEqual([]);
  });
});

describe("room content counts", () => {
  async function signUp(t: ReturnType<typeof convexTest>, username: string) {
    return await t.mutation(api.auth.signup, {
      username,
      name: username,
      passwordHash: `hash-${username}`,
      recoveryKeyHash: `recovery-${username}`,
      deviceId: `device-${username}`,
    });
  }

  const store = (t: ReturnType<typeof convexTest>, type = "image/jpeg") =>
    t.run((ctx) => ctx.storage.store(new Blob([new Uint8Array(64)], { type })));

  async function room(t: ReturnType<typeof convexTest>) {
    const me = await signUp(t, "sender");
    const roomId = await t.mutation(api.rooms.create, {
      sessionToken: me.token,
      userId: me.userId as any,
      name: "room",
      isPrivate: false,
    });
    return { me, roomId };
  }

  async function send(t: any, me: any, roomId: any, extra: Record<string, unknown>) {
    return (await t.mutation(api.messages.send, {
      sessionToken: me.token,
      userId: me.userId,
      roomId,
      content: "",
      ...extra,
    })) as Id<"messages">;
  }

  const counts = async (t: any, me: any, roomId: any) =>
    (await t.query(api.roomContent.counts, {
      sessionToken: me.token,
      userId: me.userId,
      roomId,
    })) as Record<string, { count: number; capped: boolean }>;

  const row = (t: any, roomId: any) =>
    t.run((ctx: any) =>
      ctx.db
        .query("roomContentCounts")
        .withIndex("by_room", (q: any) => q.eq("roomId", roomId))
        .first()
    );

  test("sends, edits and deletes keep the totals exact", async () => {
    const t = convexTest(schema);
    const { me, roomId } = await room(t);

    const photo = await send(t, me, roomId, { type: "image", mediaStorageId: await store(t) });
    await send(t, me, roomId, { type: "image", mediaStorageId: await store(t) });
    await send(t, me, roomId, { type: "video", mediaStorageId: await store(t, "video/mp4") });
    await send(t, me, roomId, {
      type: "file",
      mediaStorageId: await store(t, "application/pdf"),
      fileName: "a.pdf",
    });
    const linked = await send(t, me, roomId, { content: "see https://example.com" });
    // Text with nothing to share: no tab, no write to the counts row.
    await send(t, me, roomId, { content: "hello" });

    let c = await counts(t, me, roomId);
    expect(c.media).toEqual({ count: 3, capped: false });
    expect(c.photos.count).toBe(2);
    expect(c.videos.count).toBe(1);
    expect(c.file.count).toBe(1);
    expect(c.link.count).toBe(1);
    expect(c.voice.count).toBe(0);

    // An edit that drops the URL takes the message out of LINKS.
    await t.mutation(api.messages.editMessage, {
      sessionToken: me.token,
      userId: me.userId,
      messageId: linked,
      content: "never mind",
    } as any);
    await t.mutation(api.messages.deleteMessage, {
      sessionToken: me.token,
      userId: me.userId,
      messageId: photo,
    } as any);

    c = await counts(t, me, roomId);
    expect(c.photos.count).toBe(1);
    expect(c.media.count).toBe(2);
    expect(c.link.count).toBe(0);
  });

  test("the backfill recounts from the tabs and overwrites a drifted row", async () => {
    const t = convexTest(schema);
    const { me, roomId } = await room(t);
    await send(t, me, roomId, { type: "image", mediaStorageId: await store(t) });
    await send(t, me, roomId, { content: "https://a.example" });

    // A wrong row, as an early hook write in a not-yet-counted room would leave.
    const existing = await row(t, roomId);
    await t.run((ctx: any) => ctx.db.patch(existing._id, { photos: 40, links: 0 }));

    await t.mutation(internal.contentCounts.backfill, {});
    await t.finishAllScheduledFunctions(() => {});

    const fixed = await row(t, roomId);
    expect(fixed.photos).toBe(1);
    expect(fixed.links).toBe(1);
  });

  test("a room with no row falls back to the bounded scan", async () => {
    const t = convexTest(schema);
    const { me, roomId } = await room(t);
    await send(t, me, roomId, { type: "image", mediaStorageId: await store(t) });
    const r = await row(t, roomId);
    await t.run((ctx: any) => ctx.db.delete(r._id));

    const c = await counts(t, me, roomId);
    expect(c.media).toEqual({ count: 1, capped: false });
    expect(c.photos.count).toBe(1);
  });
});
