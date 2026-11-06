import { v } from "convex/values";
import { internal } from "./_generated/api";
import type { Id } from "./_generated/dataModel";
import { internalMutation } from "./dbHooks";
import { resolveMute } from "./mute";
import { callerSessionId } from "./sessionCore";

/**
 * The "you read this room" dismissal, sent to the reader's OTHER devices.
 *
 * `notifications.dismissAndSync` loads every push target (~85 docs) to clear
 * the notifications a read leaves behind on devices other than the one in the
 * reader's hand (which clears its own locally). Running it on every
 * `markRoomRead` was most of the push-target load, so it now runs only when it
 * can matter and at most once per few seconds per (user, room):
 *
 *  - the caller only gets here when the cursor MOVED past unread messages, i.e.
 *    alerts for them went out (an already-read room never reaches this);
 *  - skipped when the room is fully muted (notifications AND badges): no alert
 *    was shown and no badge changed;
 *  - skipped when the reader has no push-reachable device besides the calling
 *    one (`userPushState`, one doc). An unknown caller device or a missing
 *    state row never skips: better one extra dismissal than a stuck banner.
 *
 * Debounce, leading + trailing, in a `dismissPending` row per (room, user):
 * the first read sends at once and opens a [WINDOW_MS] window; reads inside it
 * only flag the row; when the window closes, one settle job sends the trailing
 * dismissal if flagged (the dismissal sweeps the whole room, so one send covers
 * every read in the burst) and otherwise deletes the row. No per-message jobs.
 */
export const WINDOW_MS = 4000;

export async function scheduleReadDismiss(
  ctx: any,
  args: { userId: Id<"users">; roomId: Id<"rooms">; membership: any },
): Promise<void> {
  const { userId, roomId, membership } = args;
  const now = Date.now();
  const mute = resolveMute(membership, now);
  if (mute.notifications && mute.badges) return;

  const sessionId = callerSessionId(ctx);
  if (sessionId !== undefined) {
    const session = await ctx.db.get(sessionId);
    const state = await ctx.db
      .query("userPushState")
      .withIndex("by_user", (q: any) => q.eq("userId", userId))
      .first();
    if (session && state) {
      const other = state.devices.some((d: any) => d.deviceId !== session.deviceId);
      if (!other) return;
    }
  }

  const row = await ctx.db
    .query("dismissPending")
    .withIndex("by_room_user", (q: any) =>
      q.eq("roomId", roomId).eq("userId", userId),
    )
    .first();
  if (row && row.until > now) {
    if (!row.trailing) await ctx.db.patch(row._id, { trailing: true });
    return;
  }
  if (row) {
    await ctx.db.patch(row._id, { until: now + WINDOW_MS, trailing: false });
  } else {
    await ctx.db.insert("dismissPending", {
      roomId,
      userId,
      until: now + WINDOW_MS,
      trailing: false,
    });
  }
  await ctx.scheduler.runAfter(0, internal.notifications.dismissAndSync, {
    userIds: [userId],
    roomId,
  });
  await ctx.scheduler.runAfter(WINDOW_MS, internal.readDismiss.settle, {
    userId,
    roomId,
  });
}

/** Closes a debounce window: sends the trailing dismissal or retires the row. */
export const settle = internalMutation({
  args: { userId: v.id("users"), roomId: v.id("rooms") },
  handler: async (ctx, { userId, roomId }) => {
    const row = await ctx.db
      .query("dismissPending")
      .withIndex("by_room_user", (q) =>
        q.eq("roomId", roomId).eq("userId", userId),
      )
      .first();
    if (!row) return;
    const now = Date.now();
    if (row.until > now) return; // a newer window owns the row (its own settle follows)
    if (!row.trailing) {
      await ctx.db.delete(row._id);
      return;
    }
    await ctx.db.patch(row._id, { until: now + WINDOW_MS, trailing: false });
    await ctx.scheduler.runAfter(0, internal.notifications.dismissAndSync, {
      userIds: [userId],
      roomId,
    });
    await ctx.scheduler.runAfter(WINDOW_MS, internal.readDismiss.settle, {
      userId,
      roomId,
    });
  },
});
