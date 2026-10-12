import { mutation, query } from "./functions";
import { v } from "convex/values";
import { sendCore } from "./messages";
import { GAMES } from "./games";

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

function clock(ms: number): string {
  const s = Math.max(0, Math.floor(ms / 1000));
  return `${Math.floor(s / 60)}:${String(s % 60).padStart(2, "0")}`;
}

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
    const content = `Beat my time: ${NAMES[game] ?? game} ${clock(row.durationMs)}`;
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
      out.push({
        messageId: c.messageId,
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
