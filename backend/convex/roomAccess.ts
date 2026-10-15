import { internalMutation } from "./_generated/server";
import { internal } from "./_generated/api";
import { v } from "convex/values";

/**
 * Who may READ a room, as a table that only changes when someone joins or
 * leaves.
 *
 * `roomMembers` already says who is in a room, but it is the wrong row for a
 * live query to read: every delivery and read receipt patches it
 * (`lastDeliveredAt`, `lastReadAt`, the receipt logs), and Convex re-runs a
 * subscription whenever any document it read changes. Gating `messages.list`
 * on it would re-run every open chat two or three times per message. A row
 * here is written once on join and deleted on leave, so reading it costs a
 * subscription nothing.
 *
 * Every place that inserts or deletes a `roomMembers` row calls
 * [grantRoomAccess] / [revokeRoomAccess] next to it. [canReadRoom] still
 * falls back to `roomMembers` when the access row is missing, so a member
 * written by a path that forgot the grant (or before [backfill] ran) is never
 * locked out: they only pay the extra re-runs. The opposite drift, an access
 * row outliving its membership, is the one that would leak, which is why the
 * revoke calls sit beside every delete rather than in a cleanup job.
 *
 * Imports nothing from the room modules, so any of them can call in.
 */

async function accessRow(ctx: any, roomId: any, userId: any) {
  return await ctx.db
    .query("roomAccess")
    .withIndex("by_room_user", (q: any) =>
      q.eq("roomId", roomId).eq("userId", userId),
    )
    .first();
}

export async function grantRoomAccess(ctx: any, roomId: any, userId: any) {
  if (await accessRow(ctx, roomId, userId)) return;
  await ctx.db.insert("roomAccess", { roomId, userId });
}

export async function revokeRoomAccess(ctx: any, roomId: any, userId: any) {
  const row = await accessRow(ctx, roomId, userId);
  if (row) await ctx.db.delete(row._id);
}

/** Every grant on [roomId], for teardown of the whole room. */
export async function revokeAllRoomAccess(ctx: any, roomId: any) {
  const rows = await ctx.db
    .query("roomAccess")
    .withIndex("by_room_user", (q: any) => q.eq("roomId", roomId))
    .collect();
  for (const row of rows) await ctx.db.delete(row._id);
}

/** Every grant held by [userId], for account deletion. */
export async function revokeUserRoomAccess(ctx: any, userId: any) {
  const rows = await ctx.db
    .query("roomAccess")
    .withIndex("by_user", (q: any) => q.eq("userId", userId))
    .collect();
  for (const row of rows) await ctx.db.delete(row._id);
}

/**
 * True when [userId] is a member of [roomId]. Safe to call from a live query:
 * on the common path it reads only the churn-free access row.
 */
export async function canReadRoom(
  ctx: any,
  roomId: any,
  userId: any,
): Promise<boolean> {
  if (!roomId || !userId) return false;
  if (await accessRow(ctx, roomId, userId)) return true;
  const member = await ctx.db
    .query("roomMembers")
    .withIndex("by_room_user", (q: any) =>
      q.eq("roomId", roomId).eq("userId", userId),
    )
    .first();
  return member !== null;
}

/**
 * Seeds an access row for every existing membership. Idempotent; run until
 * `done` after the deploy that introduced the table:
 *
 *   npx convex run roomAccess:backfill '{}'
 */
export const backfill = internalMutation({
  args: { cursor: v.optional(v.union(v.string(), v.null())) },
  returns: v.object({ granted: v.number(), done: v.boolean() }),
  handler: async (ctx, { cursor }) => {
    const page = await ctx.db
      .query("roomMembers")
      .paginate({ cursor: cursor ?? null, numItems: 500 });
    let granted = 0;
    for (const m of page.page) {
      if (!(await accessRow(ctx, m.roomId, m.userId))) {
        await ctx.db.insert("roomAccess", { roomId: m.roomId, userId: m.userId });
        granted++;
      }
    }
    if (!page.isDone) {
      await ctx.scheduler.runAfter(0, internal.roomAccess.backfill, {
        cursor: page.continueCursor,
      });
    }
    return { granted, done: page.isDone };
  },
});
