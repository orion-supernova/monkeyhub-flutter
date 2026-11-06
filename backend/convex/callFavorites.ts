/**
 * Calls tab favourites (docs/design/calls.md): people the user pins
 * themselves. The app suggests a frequent contact on the client; only the
 * user's own "Add" writes here. One row per pinned person, so reads are a
 * single bounded index range and writes happen only on add/remove.
 */
import { v } from "convex/values";
import { mutation, query } from "./functions";
import { consume } from "./rateLimit";

const MAX_FAVORITES = 24;

/** My favourites, oldest first (the order I added them in). */
export const list = query({
  args: {},
  returns: v.array(v.object({ peerId: v.id("users"), addedAt: v.number() })),
  handler: async (ctx, { userId }) => {
    const rows = await ctx.db
      .query("callFavorites")
      .withIndex("by_user_added", (q) => q.eq("userId", userId))
      .take(MAX_FAVORITES);
    return rows.map((r) => ({ peerId: r.peerId, addedAt: r.addedAt }));
  },
});

/** Pin [peerId]. Idempotent; refuses past the cap and for oneself. */
export const add = mutation({
  args: { peerId: v.id("users") },
  returns: v.null(),
  handler: async (ctx, { userId, peerId }) => {
    await consume(ctx, `callfav:${userId}`, 30, 60 * 1000);
    if (peerId.toString() === userId.toString()) throw new Error("CANNOT_FAVORITE_SELF");
    const existing = await ctx.db
      .query("callFavorites")
      .withIndex("by_user_peer", (q) => q.eq("userId", userId).eq("peerId", peerId))
      .first();
    if (existing) return null;
    const peer = await ctx.db.get(peerId);
    if (!peer) throw new Error("USER_NOT_FOUND");
    const mine = await ctx.db
      .query("callFavorites")
      .withIndex("by_user_added", (q) => q.eq("userId", userId))
      .take(MAX_FAVORITES);
    if (mine.length >= MAX_FAVORITES) throw new Error("TOO_MANY_FAVORITES");
    await ctx.db.insert("callFavorites", { userId, peerId, addedAt: Date.now() });
    return null;
  },
});

/** Unpin [peerId]. Missing is a no-op. */
export const remove = mutation({
  args: { peerId: v.id("users") },
  returns: v.null(),
  handler: async (ctx, { userId, peerId }) => {
    const row = await ctx.db
      .query("callFavorites")
      .withIndex("by_user_peer", (q) => q.eq("userId", userId).eq("peerId", peerId))
      .first();
    if (row) await ctx.db.delete(row._id);
    return null;
  },
});
