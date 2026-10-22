import { convexTest } from "convex-test";
import { describe, expect, test } from "vitest";
import { api } from "./_generated/api";
import schema from "./schema";

/**
 * An album is the messages of one send, sharing an `albumId`. Its first
 * message carries the album's own reactions (flagged, kept apart from that
 * photo's) and is the parent of a reply to the whole album, whose preview
 * counts the members.
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

async function setUp() {
  const t = convexTest(schema);
  const me = await signUp(t, "me");
  const roomId = await t.mutation(api.rooms.create, {
    sessionToken: me.token,
    userId: me.userId as any,
    name: "room",
    isPrivate: false,
  });
  const send = async (args: Record<string, unknown>) => {
    const sent: any = await t.mutation(api.messages.send, {
      sessionToken: me.token,
      userId: me.userId as any,
      roomId,
      content: "",
      ...args,
    } as any);
    return typeof sent === "string" ? sent : sent._id ?? sent.id;
  };
  return { t, me, roomId, send };
}

describe("albums", () => {
  test("the album id is stored on every member", async () => {
    const { t, send } = await setUp();
    const a = await send({ albumId: "alb-1" });
    const b = await send({ albumId: "alb-1" });
    const rows = await t.run(async (ctx) => [await ctx.db.get(a), await ctx.db.get(b)]);
    expect(rows.map((r: any) => r.albumId)).toEqual(["alb-1", "alb-1"]);
  });

  test("an album reaction and the same emoji on its first photo are two reactions", async () => {
    const { t, me, send } = await setUp();
    const first = await send({ albumId: "alb-1" });
    await send({ albumId: "alb-1" });
    const react = (album: boolean) =>
      t.mutation(api.reactions.addReaction, {
        sessionToken: me.token,
        userId: me.userId as any,
        messageId: first,
        emoji: "❤️",
        ...(album ? { album: true } : {}),
      } as any);
    await react(true);
    await react(false);
    await react(true); // idempotent within its own set
    let rows = await t.run(async (ctx) => ctx.db.query("reactions").collect());
    expect(rows).toHaveLength(2);
    expect(rows.filter((r: any) => r.album === true)).toHaveLength(1);

    await t.mutation(api.reactions.removeReaction, {
      sessionToken: me.token,
      userId: me.userId as any,
      messageId: first,
      emoji: "❤️",
      album: true,
    } as any);
    rows = await t.run(async (ctx) => ctx.db.query("reactions").collect());
    expect(rows).toHaveLength(1);
    expect((rows[0] as any).album).toBeUndefined();
  });

  test("a reply to the whole album counts its members; a reply to one photo does not", async () => {
    const { t, send } = await setUp();
    const first = await send({ albumId: "alb-1" });
    await send({ albumId: "alb-1" });
    await send({ albumId: "alb-1" });
    const toAlbum = await send({ content: "nice", replyToId: first, replyToAlbum: true });
    const toPhoto = await send({ content: "this one", replyToId: first });
    const rows: any[] = await t.run(async (ctx) => [
      await ctx.db.get(toAlbum),
      await ctx.db.get(toPhoto),
    ]);
    expect(rows[0].replyToPreview.albumCount).toBe(3);
    expect(rows[1].replyToPreview.albumCount).toBeUndefined();
  });
});
