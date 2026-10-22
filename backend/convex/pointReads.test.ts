import { convexTest } from "convex-test";
import { describe, expect, test } from "vitest";
import { api, internal } from "./_generated/api";
import { findDmRoomsBetween, dmRoomNamesBetween } from "./roomCleanup";
import schema from "./schema";
import { searchNameOf } from "./userSearch";

/**
 * Phase 4D: point reads instead of scans. Each test proves the new path is the
 * one in use (a row the old scan would have found but the point read cannot is
 * ignored) and that the answers are the ones callers always got.
 */

type T = ReturnType<typeof convexTest>;
type Who = { token: string; userId: string };

const signUp = (t: T, username: string, name = username): Promise<Who> =>
  t.mutation(api.auth.signup, {
    username,
    name,
    passwordHash: `hash-${username}`,
    recoveryKeyHash: `recovery-${username}`,
    deviceId: `device-${username}`,
  }) as any;
const as = (w: Who) => ({ sessionToken: w.token, userId: w.userId as any });

const befriend = (t: T, a: Who, b: Who) =>
  t.run(async (ctx: any) => {
    await ctx.db.insert("friendships", {
      userId: a.userId,
      friendId: b.userId,
      status: "accepted",
      createdAt: Date.now(),
    });
  });
const friendshipCount = (t: T) =>
  t.run(async (ctx: any) => (await ctx.db.query("friendships").collect()).length);

describe("users.blockCore reads the friendship pair, not both users' lists", () => {
  test("removes the pair's rows in both directions and leaves every other friendship", async () => {
    const t = convexTest(schema);
    const a = await signUp(t, "ann");
    const b = await signUp(t, "bob");
    const c = await signUp(t, "cat");
    await befriend(t, a, b);
    await befriend(t, b, a); // a stray duplicate in the other direction
    await befriend(t, a, c);
    await befriend(t, c, b);
    expect(await friendshipCount(t)).toBe(4);

    await t.mutation(api.users.blockUser, { ...as(a), targetUserId: b.userId as any });
    // Only a<->b went; a-c and c-b are untouched.
    expect(await friendshipCount(t)).toBe(2);
    const left = await t.run(async (ctx: any) =>
      (await ctx.db.query("friendships").collect()).map(
        (f: any) => `${f.userId}>${f.friendId}`,
      ),
    );
    expect(left.sort()).toEqual([`${a.userId}>${c.userId}`, `${c.userId}>${b.userId}`].sort());
    const blocks = await t.run(async (ctx: any) => ctx.db.query("blocks").collect());
    expect(blocks).toHaveLength(1);
  });
});

describe("roomCleanup.findDmRoomsBetween point-reads rooms.by_name", () => {
  test("names cover regular, secret, legacy, and self", () => {
    expect(dmRoomNamesBetween("b", "a")).toEqual(["dm:regular:a:b", "dm:secret:a:b", "dm:a:b"]);
    expect(dmRoomNamesBetween("a", "a")).toContain("dm:self:a");
  });

  test("finds every variant, requires both members, ignores unrelated dm: rooms", async () => {
    const t = convexTest(schema);
    const a = await signUp(t, "ann");
    const b = await signUp(t, "bob");
    const c = await signUp(t, "cat");
    const [lo, hi] = [a.userId, b.userId].sort();
    const mk = (name: string, members: Who[]) =>
      t.run(async (ctx: any) => {
        const roomId = await ctx.db.insert("rooms", {
          name,
          createdBy: a.userId,
          isPrivate: true,
          createdAt: Date.now(),
          memberCount: members.length,
        } as any);
        for (const m of members) {
          await ctx.db.insert("roomMembers", {
            roomId,
            userId: m.userId,
            joinedAt: Date.now(),
            role: "member",
          } as any);
        }
        return roomId as string;
      });
    const regular = await mk(`dm:regular:${lo}:${hi}`, [a, b]);
    const secret = await mk(`dm:secret:${lo}:${hi}`, [a, b]);
    const legacy = await mk(`dm:${lo}:${hi}`, [a, b]);
    // A room whose name is not derivable: the old membership walk found it, the
    // point reads must not (and nothing creates such a name).
    await mk("dm:custom:whatever", [a, b]);
    // A DM of a with someone else, and a DM of the pair that b already left.
    await mk(`dm:regular:${[a.userId, c.userId].sort().join(":")}`, [a, c]);

    const found: string[] = await t.run((ctx: any) => findDmRoomsBetween(ctx, a.userId, b.userId));
    expect(found.sort()).toEqual([regular, secret, legacy].sort());
    // Symmetric in its arguments.
    const swapped: string[] = await t.run((ctx: any) => findDmRoomsBetween(ctx, b.userId, a.userId));
    expect(swapped.sort()).toEqual(found.sort());

    await t.run(async (ctx: any) => {
      const m = await ctx.db
        .query("roomMembers")
        .withIndex("by_room_user", (q: any) => q.eq("roomId", secret).eq("userId", b.userId))
        .first();
      await ctx.db.delete(m._id);
    });
    const afterLeave: string[] = await t.run((ctx: any) =>
      findDmRoomsBetween(ctx, a.userId, b.userId),
    );
    expect(afterLeave.sort()).toEqual([regular, legacy].sort());
  });

  test("a block with deleteDm wipes the real DM", async () => {
    const t = convexTest(schema);
    const a = await signUp(t, "ann");
    const b = await signUp(t, "bob");
    await befriend(t, a, b);
    const roomId = await t.mutation(api.rooms.getOrCreateDM, {
      ...as(a),
      friendId: b.userId as any,
    });
    await t.mutation(api.users.blockUser, {
      ...as(a),
      targetUserId: b.userId as any,
      deleteDm: true,
    });
    const room = await t.run(async (ctx: any) => ctx.db.get(roomId));
    expect(room === null || room.deletingAt !== undefined).toBe(true);
  });
});

describe("messages.by_room_album scopes the album count to the room", () => {
  test("the same albumId in another room is not counted", async () => {
    const t = convexTest(schema);
    const me = await signUp(t, "me");
    const mkRoom = (name: string) =>
      t.mutation(api.rooms.create, { ...as(me), name, isPrivate: false });
    const r1 = await mkRoom("one");
    const r2 = await mkRoom("two");
    const send = async (roomId: any, args: Record<string, unknown>) => {
      const sent: any = await t.mutation(api.messages.send, {
        ...as(me),
        roomId,
        content: "",
        ...args,
      } as any);
      return typeof sent === "string" ? sent : sent._id ?? sent.id;
    };
    const first = await send(r1, { albumId: "alb-x" });
    await send(r1, { albumId: "alb-x" });
    await send(r2, { albumId: "alb-x" });
    await send(r2, { albumId: "alb-x" });
    await send(r2, { albumId: "alb-x" });
    const reply = await send(r1, { content: "nice", replyToId: first, replyToAlbum: true });
    const row: any = await t.run(async (ctx: any) => ctx.db.get(reply));
    expect(row.replyToPreview.albumCount).toBe(2);
  });
});

describe("roomInvites: the live link is read through by_room_revoked", () => {
  test("getLink returns the newest un-revoked link after several rotations", async () => {
    const t = convexTest(schema);
    const owner = await signUp(t, "owner");
    const roomId = await t.mutation(api.rooms.create, {
      ...as(owner),
      name: "club",
      isPrivate: false,
    });
    const codes: string[] = [];
    for (let i = 0; i < 4; i++) {
      const link: any = await t.mutation(api.roomInvites.rotate, { ...as(owner), roomId });
      codes.push(link.code);
    }
    const live: any = await t.query(api.roomInvites.getLink, { ...as(owner), roomId });
    expect(live.code).toBe(codes[3]);
    const rows = await t.run(async (ctx: any) => ctx.db.query("roomInvites").collect());
    expect(rows.filter((r: any) => !r.revokedAt)).toHaveLength(1);

    // A half-applied rotation (two un-revoked rows): the NEWER one wins.
    await t.run(async (ctx: any) => {
      await ctx.db.insert("roomInvites", {
        roomId,
        code: "ZZZZZZZZZZ",
        createdBy: owner.userId,
        createdAt: Date.now() + 1000,
        useCount: 0,
      } as any);
    });
    const newest: any = await t.query(api.roomInvites.getLink, { ...as(owner), roomId });
    expect(newest.code).toBe("ZZZZZZZZZZ");

    await t.mutation(api.roomInvites.revoke, { ...as(owner), roomId });
    await t.mutation(api.roomInvites.revoke, { ...as(owner), roomId });
    const none: any = await t.query(api.roomInvites.getLink, { ...as(owner), roomId });
    // revoke stamps one live link per call; the earlier half-applied row is
    // revoked by the second call.
    expect(none).toBeNull();
  });
});

describe("user search uses the search index", () => {
  const search = (t: T, viewer: Who, query: string): Promise<any[]> =>
    t.query(api.users.searchUsers, { sessionToken: viewer.token, query, currentUserId: viewer.userId as any }) as any;
  const handles = (rows: any[]) => rows.map((r) => r.username);

  test("exact handle first, then name/handle prefix; the viewer and others excluded", async () => {
    const t = convexTest(schema);
    const me = await signUp(t, "viewer");
    await signUp(t, "annabel", "Zed Zulu");
    await signUp(t, "ann", "Someone Else");
    await signUp(t, "zoe", "Ann Marie");
    await signUp(t, "unrelated", "Nobody");

    // "ann": the exact handle leads, then the other prefix matches.
    const rows = await search(t, me, "ann");
    expect(handles(rows)[0]).toBe("ann");
    expect(handles(rows).sort()).toEqual(["ann", "annabel", "zoe"]);
    // Case-insensitive, and on the display name's word prefix.
    expect(handles(await search(t, me, "MARIE"))).toEqual(["zoe"]);
    expect(await search(t, me, "   ")).toEqual([]);
    expect(await search(t, me, "viewer")).toEqual([]);
  });

  test("it never scans the table: a row not in the index is found only by exact handle", async () => {
    const t = convexTest(schema);
    const me = await signUp(t, "viewer");
    await t.run(async (ctx: any) => {
      await ctx.db.insert("users", {
        username: "legacyuser",
        name: "Old Timer",
        passwordHash: "x",
        createdAt: Date.now(),
        // Not indexed (convex-test's search fake cannot take a missing field;
        // real Convex skips such a row the same way).
        searchName: "",
      });
      await ctx.db.insert("users", {
        username: "other",
        name: "x",
        passwordHash: "x",
        createdAt: Date.now(),
        searchName: "other x",
      });
    });
    expect(await search(t, me, "old")).toEqual([]);
    expect(await search(t, me, "legacy")).toEqual([]);
    expect(handles(await search(t, me, "legacyuser"))).toEqual(["legacyuser"]);
  });

  test("a tombstoned user and a blocked user are excluded", async () => {
    const t = convexTest(schema);
    const me = await signUp(t, "viewer");
    const gone = await signUp(t, "tombstone");
    const blocked = await signUp(t, "tomblocked");
    const blocker = await signUp(t, "tomblocker");
    await signUp(t, "tomkeep");
    await t.run(async (ctx: any) => {
      await ctx.db.patch(gone.userId, { deletingAt: Date.now() });
    });
    await t.mutation(api.users.blockUser, { ...as(me), targetUserId: blocked.userId as any });
    await t.mutation(api.users.blockUser, { ...as(blocker), targetUserId: me.userId as any });
    expect(handles(await search(t, me, "tom"))).toEqual(["tomkeep"]);
    // Even their exact handle is invisible.
    expect(await search(t, me, "tombstone")).toEqual([]);
    expect(await search(t, me, "tomblocked")).toEqual([]);
    expect(await search(t, me, "tomblocker")).toEqual([]);
  });

  test("a child surfaces to an adult only by exact handle", async () => {
    const t = convexTest(schema);
    const me = await signUp(t, "viewer");
    await t.run(async (ctx: any) => {
      await ctx.db.insert("users", {
        username: "kiddo",
        name: "Kiddo",
        passwordHash: "x",
        createdAt: Date.now(),
        accountType: "child",
        searchName: searchNameOf("kiddo", "Kiddo"),
      });
    });
    expect(await search(t, me, "kid")).toEqual([]);
    expect(handles(await search(t, me, "kiddo"))).toEqual(["kiddo"]);
  });

  test("friendship status is still reported", async () => {
    const t = convexTest(schema);
    const me = await signUp(t, "viewer");
    const pal = await signUp(t, "palmer");
    await befriend(t, me, pal);
    const rows = await search(t, me, "pal");
    expect(rows[0].friendshipStatus).toBe("friend");
  });

  test("searchName follows renames and the backfill fills old rows", async () => {
    const t = convexTest(schema);
    const me = await signUp(t, "viewer");
    const u = await signUp(t, "mover", "First Name");
    const field = () =>
      t.run(async (ctx: any) => (await ctx.db.get(u.userId)).searchName);
    expect(await field()).toBe("mover first name");
    await t.mutation(api.users.updateProfile, { ...as(u), name: "Brand New" } as any);
    expect(await field()).toBe("mover brand new");
    expect(handles(await search(t, me, "brand"))).toEqual(["mover"]);
    expect(await search(t, me, "first")).toEqual([]);

    await t.run(async (ctx: any) => {
      await ctx.db.patch(u.userId, { searchName: undefined });
    });
    const r: any = await t.mutation(internal.userSearch.backfillSearchName, {});
    expect(r.done).toBe(true);
    expect(await field()).toBe("mover brand new");
  });
});
