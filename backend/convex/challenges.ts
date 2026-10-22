import { mutation, query } from "./functions";
import { internalQuery } from "./_generated/server";
import { v } from "convex/values";
import { sendCore } from "./messages";
import { GAMES } from "./games";
import { lensFor } from "./visibility";
import { byNameThenId, competitionPlaces, shownSeconds } from "./ranking";
import { challengeContent } from "./challengeCopy";

/**
 * "Beat my time" — a finished daily result sent into a chat as a dare.
 *
 * The sender must actually have solved that board: the time on the card is
 * read from their own `gameResults` row, never taken from the client, so a
 * challenge is exactly as honest as the standings it came from. One card per
 * room the sender picked, each a `messages` row of type "challenge" with a
 * readable `content` (so a transcript, a preview, a push and an old client all
 * degrade to a sentence) and a `gameChallenges` row as its body.
 *
 * Nothing here ranks anything or writes to the daily tables. Whether the
 * recipient beat it is read off their own result for the same board when the
 * card is drawn.
 */

const MAX_ROOMS = 20;

/** English names for the card's `content`; the app shows its own. */
const NAMES: Record<string, string> = {
  queens: "Queens",
  tango: "Tango",
  zip: "Zip",
  sudoku: "Mini Sudoku",
  flow: "Flow",
  futoshiki: "Futoshiki",
  nonogram: "Nonogram",
  minesweeper: "Minesweeper",
  starbattle: "Star Battle",
  patches: "Patches",
};

export const send = mutation({
  args: {
    userId: v.id("users"),
    roomIds: v.array(v.id("rooms")),
    game: v.string(),
    dayKey: v.string(),
    clientId: v.optional(v.string()),
  },
  handler: async (ctx, { userId, roomIds, game, dayKey, clientId }) => {
    if (!(GAMES as readonly string[]).includes(game)) {
      throw new Error("UNKNOWN_GAME");
    }
    if (roomIds.length === 0 || roomIds.length > MAX_ROOMS) {
      throw new Error("BAD_ARGS");
    }
    if (clientId !== undefined && (clientId.length === 0 || clientId.length > 64)) {
      throw new Error("BAD_ARGS");
    }
    const row = await ctx.db
      .query("gameResults")
      .withIndex("by_user_day_game", (q: any) =>
        q.eq("userId", userId).eq("dayKey", dayKey).eq("game", game),
      )
      .first();
    if (!row || !row.solved || row.durationMs === undefined) {
      throw new Error("NOT_SOLVED");
    }
    const me: any = await ctx.db.get(userId);
    const name = (me?.name ?? me?.username ?? "").slice(0, 60);
    // A question, never "Beat my time: Zip 0:17" — see `challengeCopy.ts`
    // for what a voice assistant made of that.
    const content = challengeContent(NAMES[game] ?? game, row.durationMs);
    const sent: string[] = [];
    for (const roomId of [...new Set(roomIds)]) {
      // `sendCore` is the guard: membership, blocks, a child's policy.
      const messageId = await sendCore(ctx, {
        roomId,
        userId,
        content,
        type: "challenge",
        clientId: clientId === undefined ? undefined : `${clientId}:${roomId}`,
      });
      const existing = await ctx.db
        .query("gameChallenges")
        .withIndex("by_message", (q: any) => q.eq("messageId", messageId))
        .first();
      if (!existing) {
        await ctx.db.insert("gameChallenges", {
          messageId,
          roomId,
          userId,
          name,
          game,
          dayKey,
          durationMs: row.durationMs,
          hintsUsed: row.hintsUsed ?? 0,
          createdAt: Date.now(),
        });
      }
      sent.push(messageId);
    }
    return sent;
  },
});

/** The bodies behind [messageIds], for the viewer's rooms only. One-shot. */
export const forMessages = query({
  identityArg: "viewerUserId" as const,
  args: {
    messageIds: v.array(v.id("messages")),
    viewerUserId: v.optional(v.id("users")),
  },
  handler: async (ctx, { messageIds, viewerUserId }) => {
    if (!viewerUserId || messageIds.length > 100) return [];
    const allowed = new Map<string, boolean>();
    const rooms = new Map<string, { isGroup: boolean; roomName?: string }>();
    const out: any[] = [];
    for (const messageId of messageIds) {
      const c = await ctx.db
        .query("gameChallenges")
        .withIndex("by_message", (q: any) => q.eq("messageId", messageId))
        .first();
      if (!c) continue;
      const key = c.roomId as string;
      if (!allowed.has(key)) {
        const m = await ctx.db
          .query("roomMembers")
          .withIndex("by_room_user", (q: any) =>
            q.eq("roomId", c.roomId).eq("userId", viewerUserId),
          )
          .first();
        allowed.set(key, !!m);
      }
      if (!allowed.get(key)) continue;
      if (!rooms.has(key)) {
        const room: any = await ctx.db.get(c.roomId);
        // The same DM rule `rooms.getMemberIds` uses. The room's name rides
        // along for the result card's "Reply in <room>" — a DM's `dm:...`
        // key is never shown.
        const isGroup = !!room && !String(room.name ?? "").startsWith("dm:");
        rooms.set(key, {
          isGroup,
          roomName: isGroup ? (room.name as string) : undefined,
        });
      }
      const r = rooms.get(key)!;
      out.push({
        messageId: c.messageId,
        roomId: c.roomId,
        isGroup: r.isGroup,
        ...(r.roomName !== undefined ? { roomName: r.roomName } : {}),
        userId: c.userId,
        name: c.name,
        game: c.game,
        dayKey: c.dayKey,
        durationMs: c.durationMs,
        hintsUsed: c.hintsUsed,
      });
    }
    return out;
  },
});

/**
 * What `notifications.sendMessagePush` needs to word a challenge per
 * recipient: the board and the time, and each recipient's language (their
 * most recently used handset's, as `_reactionPushPlan` resolves it). Null
 * when the body is gone — the push then falls back to the message's own
 * English `content`.
 */
export const _pushPlan = internalQuery({
  args: { messageId: v.id("messages"), userIds: v.array(v.id("users")) },
  returns: v.any(),
  handler: async (ctx, { messageId, userIds }) => {
    const c: any = await ctx.db
      .query("gameChallenges")
      .withIndex("by_message", (q: any) => q.eq("messageId", messageId))
      .first();
    if (!c) return null;
    const locales: Record<string, string> = {};
    for (const userId of userIds.slice(0, 500)) {
      const devices = await ctx.db
        .query("userDevices")
        .withIndex("by_user", (q: any) => q.eq("userId", userId))
        .take(50);
      const locale = devices
        .filter((d: any) => typeof d.locale === "string" && d.locale)
        .sort((a: any, b: any) => b.lastSeenAt - a.lastSeenAt)[0]?.locale;
      if (locale) locales[userId as string] = locale;
    }
    return { game: c.game, durationMs: c.durationMs, locales };
  },
});

/** Members whose result for the board a room card reads. */
const MAX_RESULT_MEMBERS = 50;
/** Members scanned for the viewer's friends. Read as ids only. */
const MAX_COUNTED_MEMBERS = 500;

/**
 * "Who played": one board's finished results among a room's members, for the
 * challenge card in that room. One-shot — the card refetches when it is drawn
 * again after a while and when the viewer finishes the board themselves,
 * never subscribing: a reactive read over `roomMembers` would re-run on every
 * read cursor in the room.
 *
 * The standings' rules, applied to a room instead of a friend list:
 *
 *  * The viewer's friends only, as on the standings. Sharing a room is not
 *    consent to a stranger seeing your times.
 *  * Finished rows only. An unfinished board never leaves its owner's device.
 *  * `visibility.puzzle === "nobody"` keeps a member off the card entirely,
 *    as it keeps them off the standings — except the viewer, who always sees
 *    their own row.
 *  * Faces through the viewer's own lens; names as the standings send them,
 *    the viewer's blanked to "" (the client says "you").
 *  * Solved first, then whole seconds, shared places (1, 1, 2); a
 *    surrender is one group below every solver.
 *
 * Every row comes back (at most [MAX_RESULT_MEMBERS]): the card shows the top
 * three plus the viewer, and the sheet behind it shows them all, from one
 * fetch. Null for a non-member or an unknown game.
 */
export const roomResults = query({
  identityArg: "viewerUserId" as const,
  args: {
    roomId: v.id("rooms"),
    game: v.string(),
    dayKey: v.string(),
    viewerUserId: v.optional(v.id("users")),
  },
  handler: async (ctx, { roomId, game, dayKey, viewerUserId }) => {
    if (!viewerUserId) return null;
    if (!(GAMES as readonly string[]).includes(game)) return null;
    const mine = await ctx.db
      .query("roomMembers")
      .withIndex("by_room_user", (q: any) =>
        q.eq("roomId", roomId).eq("userId", viewerUserId),
      )
      .first();
    if (!mine) return null;
    const room: any = await ctx.db.get(roomId);
    const isGroup = !!room && !String(room.name ?? "").startsWith("dm:");

    const members = await ctx.db
      .query("roomMembers")
      .withIndex("by_room_user", (q: any) => q.eq("roomId", roomId))
      .take(MAX_COUNTED_MEMBERS);
    // The viewer, then their friends among the members. Filtered while
    // collecting, so the cap counts friends: a friend who joined after the
    // first fifty members still makes the card. The lens already holds the
    // friend set, so a stranger costs no read at all.
    const lens = await lensFor(ctx, viewerUserId);
    const ids: any[] = [viewerUserId];
    for (const m of members) {
      if (ids.length >= MAX_RESULT_MEMBERS) break;
      if (m.userId !== viewerUserId && lens.isFriend(m.userId)) ids.push(m.userId);
    }

    const rows: any[] = [];
    for (const id of ids) {
      const self = id === viewerUserId;
      const user: any = await ctx.db.get(id);
      if (!user) continue;
      if (!self && (user.visibility?.puzzle ?? "friends") === "nobody") continue;
      const row: any = await ctx.db
        .query("gameResults")
        .withIndex("by_user_day_game", (q: any) =>
          q.eq("userId", id).eq("dayKey", dayKey).eq("game", game),
        )
        .first();
      if (!row || !row.finishedAt) continue;
      rows.push({
        userId: id,
        name: user.name ?? user.username ?? "",
        ...(user.avatarStorageId && lens.canSee(user, "avatar")
          ? { avatarStorageId: user.avatarStorageId }
          : {}),
        game,
        solved: !!row.solved,
        gaveUp: !!row.gaveUp,
        durationMs: row.solved ? row.durationMs : undefined,
        hintsUsed: row.hintsUsed ?? 0,
        finishedAt: row.finishedAt,
      });
    }

    const shown = (r: any) => (r.solved ? shownSeconds(r.durationMs) : -1);
    rows.sort((a, b) => {
      if (a.solved !== b.solved) return a.solved ? -1 : 1;
      const at = shown(a);
      const bt = shown(b);
      if (at !== bt) return at - bt;
      return byNameThenId(a, b);
    });
    const places = competitionPlaces(rows, shown);
    return {
      isGroup,
      played: rows.length,
      rows: rows.map((r, i) => ({
        ...r,
        place: places[i],
        name: r.userId === viewerUserId ? "" : r.name,
      })),
    };
  },
});
