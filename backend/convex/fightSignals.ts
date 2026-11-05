import { v } from "convex/values";
import { mutation, query } from "./functions";

/**
 * Jungle Fist signalling: how the two phones of a live `fight` match find
 * each other (WebRTC offer, answer and ICE candidates). Once their data
 * channel is open, the fight runs phone to phone and nothing here is touched
 * again until the result is reported through `matches.partyAct`.
 *
 * Only the two seated players of an open fight may signal, and only to each
 * other. Rows are deleted when the recipient consumes them, so a fight leaves
 * a handful of rows behind at most, and those go with the match.
 *
 * Cost: one connection is ~2 + (ICE candidates, batched) writes per side, and
 * one subscription per fighter while the fight screen is connecting.
 */

const KINDS = new Set(["offer", "answer", "ice", "bye"]);
const MAX_PAYLOAD = 16 * 1024; // an SDP with every codec line is a few KB
const MAX_PENDING = 64;

async function seatedFight(ctx: any, matchId: any, userId: any) {
  const match = await ctx.db.get(matchId);
  if (!match || match.game !== "fight") throw new Error("NOT_FOUND");
  const seats: { userId: string }[] = match.seats ?? [];
  const mine = seats.findIndex((s) => s.userId === userId);
  if (mine < 0) throw new Error("NOT_SEATED");
  return { match, seats, mine };
}

export const send = mutation({
  args: {
    matchId: v.id("matches"),
    userId: v.id("users"),
    toUserId: v.id("users"),
    kind: v.string(),
    payload: v.string(),
    fromDeviceId: v.optional(v.string()),
  },
  returns: v.union(v.id("fightSignals"), v.null()),
  handler: async (ctx, { matchId, userId, toUserId, kind, payload, fromDeviceId }) => {
    if (!KINDS.has(kind) || payload.length > MAX_PAYLOAD) throw new Error("BAD_ARGS");
    if (fromDeviceId !== undefined && fromDeviceId.length > 64) throw new Error("BAD_ARGS");
    const { match, seats } = await seatedFight(ctx, matchId, userId);
    if (toUserId === userId || !seats.some((s) => s.userId === toUserId)) {
      throw new Error("WRONG_PEER");
    }
    // A finished fight needs no new connection; drop quietly (a late ICE
    // candidate from a closing phone is not an error worth surfacing).
    if (match.status !== "active" && match.status !== "paused") return null;
    const pending = await ctx.db
      .query("fightSignals")
      .withIndex("by_match_to", (q: any) => q.eq("matchId", matchId).eq("toUserId", toUserId))
      .take(MAX_PENDING);
    if (pending.length >= MAX_PENDING) throw new Error("RATE_LIMITED");
    return await ctx.db.insert("fightSignals", {
      matchId,
      fromUserId: userId,
      toUserId,
      fromDeviceId,
      kind,
      payload,
      createdAt: Date.now(),
    });
  },
});

/** The caller's unconsumed signals for one fight, oldest first. */
export const forMe = query({
  identityArg: "viewerUserId",
  args: { matchId: v.id("matches"), viewerUserId: v.id("users") },
  returns: v.array(
    v.object({
      _id: v.id("fightSignals"),
      fromUserId: v.id("users"),
      fromDeviceId: v.union(v.string(), v.null()),
      kind: v.string(),
      payload: v.string(),
      createdAt: v.number(),
    }),
  ),
  handler: async (ctx, { matchId, viewerUserId }) => {
    const match = await ctx.db.get(matchId);
    if (!match || match.game !== "fight") return [];
    if (!(match.seats ?? []).some((s: any) => s.userId === viewerUserId)) return [];
    const rows = await ctx.db
      .query("fightSignals")
      .withIndex("by_match_to", (q: any) => q.eq("matchId", matchId).eq("toUserId", viewerUserId))
      .take(MAX_PENDING);
    return rows.map((r: any) => ({
      _id: r._id,
      fromUserId: r.fromUserId,
      fromDeviceId: r.fromDeviceId ?? null,
      kind: r.kind,
      payload: r.payload,
      createdAt: r.createdAt,
    }));
  },
});

/** Deletes signals the caller has handled. Rows not addressed to them are ignored. */
export const consume = mutation({
  args: { userId: v.id("users"), signalIds: v.array(v.id("fightSignals")) },
  returns: v.null(),
  handler: async (ctx, { userId, signalIds }) => {
    if (signalIds.length > MAX_PENDING) throw new Error("BAD_ARGS");
    for (const id of signalIds) {
      const row = await ctx.db.get(id);
      if (row && row.toUserId === userId) await ctx.db.delete(id);
    }
    return null;
  },
});
