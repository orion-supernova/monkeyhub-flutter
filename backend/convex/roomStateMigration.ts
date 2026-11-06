import { v } from "convex/values";
import { internal } from "./_generated/api";
import type { Id } from "./_generated/dataModel";
import { internalQuery } from "./_generated/server";
import { internalMutation } from "./dbHooks";
import { unreadForRoom } from "./badges";
import { MAX_OWN_RUNS, STATE_MARKER, dmPeerFor, stateOf } from "./roomState";
import { roomUnread } from "./unread";

/**
 * C1 backfill (docs/backend/c1-cursors-design.md, "Rollout"). Deploy the
 * dual-mode backend first; then, in this order, to completion each:
 *
 *   1. npx convex run roomStateMigration:assignSeq '{}'
 *        Gives every room's messages their `seq` (oldest first) and sets
 *        `rooms.lastSeq` in the SAME transaction that scans the room's tail,
 *        so a concurrent send either gets the next number from the hook or
 *        conflicts and retries. A big room continues in its own chain.
 *   2. npx convex run roomStateMigration:createStates '{}'
 *        One `roomUserState` + `roomReceipts` row per membership whose room
 *        has a sequence (`readSeq` = seq of the newest message at or before
 *        `lastReadAt`, own messages above it as runs). Rooms step 1 has not
 *        reached are skipped and counted; run again after step 1 finishes.
 *   3. shadow compare: npx convex run roomStateMigration:shadowCompare '{}'
 *        (internal query; pass the returned `next` as `cursor` until `done`)
 *        must return no mismatches before step 4.
 *   4. npx convex run roomStateMigration:finish '{}'
 *        Refuses (and says why) while any room lacks `lastSeq` or any
 *        membership lacks a state row; otherwise sets the `roomUserState`
 *        marker, which retires every reader's legacy fallback.
 *
 * Every step is paged, self-chaining and idempotent: a re-run skips what is
 * done. Run step 1 once at a time (a second concurrent run of the same room
 * is safe, since rows that already have a `seq` are skipped, but wasteful).
 * Legacy `roomMembers` cursor fields are left in place until the D1 cutover.
 */

const ROOM_PAGE = 10;
const MESSAGE_PAGE = 300;
/** Messages above a cursor read to find the member's own runs. */
const OWN_SCAN = 400;
const MEMBER_PAGE = 20;

// ───────────────────────── 1. sequence numbers ─────────────────────────

/**
 * One page of a room's messages: numbers the ones without a `seq` (continuing
 * from [next]) and, when the tail is reached, sets `rooms.lastSeq`. Returns the
 * continuation, or null when the room is finished.
 */
async function sequenceRoomPage(
  ctx: any,
  roomId: Id<"rooms">,
  afterAt: number,
  next: number,
): Promise<{ afterAt: number; next: number } | null> {
  const rows = await ctx.db
    .query("messages")
    .withIndex("by_room_time", (q: any) => q.eq("roomId", roomId).gte("createdAt", afterAt))
    .take(MESSAGE_PAGE);
  let counter = next;
  let assigned = 0;
  for (const m of rows) {
    if (m.seq !== undefined) {
      counter = Math.max(counter, m.seq);
      continue;
    }
    counter++;
    assigned++;
    await ctx.db.patch(m._id, { seq: counter });
  }
  if (rows.length === MESSAGE_PAGE) {
    const last = rows[rows.length - 1].createdAt;
    // A whole page of already-numbered rows at one timestamp would never move.
    return { afterAt: assigned === 0 && last === afterAt ? last + 1 : last, next: counter };
  }
  // Tail reached. Catch a message a clock-skewed concurrent send stamped just
  // before `afterAt`, then close the room.
  const newest = await ctx.db
    .query("messages")
    .withIndex("by_room_time", (q: any) => q.eq("roomId", roomId))
    .order("desc")
    .take(5);
  for (const m of newest.reverse()) {
    if (m.seq !== undefined) continue;
    counter++;
    await ctx.db.patch(m._id, { seq: counter });
  }
  await ctx.db.patch(roomId, { lastSeq: counter });
  return null;
}

export const assignSeq = internalMutation({
  args: { cursor: v.optional(v.union(v.string(), v.null())), rooms: v.optional(v.number()) },
  handler: async (ctx, { cursor, rooms }) => {
    const page = await ctx.db
      .query("rooms")
      .paginate({ numItems: ROOM_PAGE, cursor: cursor ?? null });
    let started = rooms ?? 0;
    for (const room of page.page) {
      if (room.lastSeq !== undefined) continue;
      started++;
      const more = await sequenceRoomPage(ctx, room._id, 0, 0);
      if (more) {
        await ctx.scheduler.runAfter(0, internal.roomStateMigration.assignRoomSeq, {
          roomId: room._id,
          ...more,
        });
      }
    }
    if (!page.isDone) {
      await ctx.scheduler.runAfter(0, internal.roomStateMigration.assignSeq, {
        cursor: page.continueCursor,
        rooms: started,
      });
      return { done: false, started };
    }
    console.log(`roomStateMigration.assignSeq: walked all rooms, ${started} sequenced`);
    return { done: true, started };
  },
});

/** The continuation of a room too big for one transaction. */
export const assignRoomSeq = internalMutation({
  args: { roomId: v.id("rooms"), afterAt: v.number(), next: v.number() },
  handler: async (ctx, { roomId, afterAt, next }) => {
    const room = await ctx.db.get(roomId);
    if (!room || room.lastSeq !== undefined) return { done: true };
    const more = await sequenceRoomPage(ctx, roomId, afterAt, next);
    if (more) {
      await ctx.scheduler.runAfter(0, internal.roomStateMigration.assignRoomSeq, {
        roomId,
        ...more,
      });
      return { done: false };
    }
    return { done: true };
  },
});

// ───────────────────── 2. state + receipts per membership ─────────────────────

/** `seq` of the newest message at or before [cursor] (highest of the newest few). */
async function seqAtOrBefore(ctx: any, roomId: any, cursor: number): Promise<number> {
  const rows = await ctx.db
    .query("messages")
    .withIndex("by_room_time", (q: any) => q.eq("roomId", roomId).lte("createdAt", cursor))
    .order("desc")
    .take(3);
  let seq = 0;
  for (const m of rows) if ((m.seq ?? 0) > seq) seq = m.seq;
  return seq;
}

/** [userId]'s own messages above [cursor] as runs, or overflow when they cannot all be told. */
async function ownRunsAbove(
  ctx: any,
  roomId: any,
  userId: any,
  cursor: number,
): Promise<{ runs: { from: number; to: number }[]; overflow: boolean }> {
  const rows = await ctx.db
    .query("messages")
    .withIndex("by_room_time", (q: any) => q.eq("roomId", roomId).gt("createdAt", cursor))
    .take(OWN_SCAN);
  const mine = userId.toString();
  const seqs: number[] = rows
    .filter((m: any) => m.userId.toString() === mine && m.seq !== undefined)
    .map((m: any) => m.seq)
    .sort((a: number, b: number) => a - b);
  const runs: { from: number; to: number }[] = [];
  for (const s of seqs) {
    const last = runs[runs.length - 1];
    if (last && last.to === s - 1) last.to = s;
    else runs.push({ from: s, to: s });
  }
  const overflow = rows.length === OWN_SCAN || runs.length > MAX_OWN_RUNS;
  return { runs: overflow ? [] : runs, overflow };
}

export const createStates = internalMutation({
  args: {
    cursor: v.optional(v.union(v.string(), v.null())),
    created: v.optional(v.number()),
    pending: v.optional(v.number()),
  },
  handler: async (ctx, { cursor, created, pending }) => {
    const page = await ctx.db
      .query("roomMembers")
      .paginate({ numItems: MEMBER_PAGE, cursor: cursor ?? null });
    let made = created ?? 0;
    let waiting = pending ?? 0;
    for (const m of page.page) {
      if (await stateOf(ctx, m.roomId, m.userId)) continue;
      const room = await ctx.db.get(m.roomId);
      if (!room) continue; // an orphan; the room cleanup owns it
      if (room.lastSeq === undefined) {
        waiting++;
        continue;
      }
      const readAt = m.lastReadAt;
      const readSeq = readAt === undefined ? 0 : await seqAtOrBefore(ctx, m.roomId, readAt);
      const own = await ownRunsAbove(ctx, m.roomId, m.userId, readAt ?? 0);
      const peer = dmPeerFor(ctx.db, room.name, m.userId);
      await ctx.db.insert("roomUserState", {
        roomId: m.roomId,
        userId: m.userId,
        readSeq,
        ...(readAt !== undefined ? { readAt } : {}),
        ...(own.runs.length > 0 ? { ownRuns: own.runs } : {}),
        ...(own.overflow ? { ownOverflow: true } : {}),
        archived: m.isArchived === true,
        ...(m.archivedAt !== undefined ? { archivedAt: m.archivedAt } : {}),
        ...(m.isPinned !== undefined ? { isPinned: m.isPinned } : {}),
        ...(m.pinnedAt !== undefined ? { pinnedAt: m.pinnedAt } : {}),
        ...(m.muteNotifications !== undefined ? { muteNotifications: m.muteNotifications } : {}),
        ...(m.muteBadges !== undefined ? { muteBadges: m.muteBadges } : {}),
        ...(m.mutedUntil !== undefined ? { mutedUntil: m.mutedUntil } : {}),
        ...(peer !== undefined ? { dmPeerId: peer } : {}),
        ...(m.vanishShareReads !== undefined ? { vanishShareReads: m.vanishShareReads } : {}),
      });
      const haveReceipt = await ctx.db
        .query("roomReceipts")
        .withIndex("by_room_user", (q) => q.eq("roomId", m.roomId).eq("userId", m.userId))
        .first();
      if (!haveReceipt) {
        await ctx.db.insert("roomReceipts", {
          roomId: m.roomId,
          userId: m.userId,
          ...(m.lastReadAt !== undefined ? { lastReadAt: m.lastReadAt } : {}),
          ...(m.lastDeliveredAt !== undefined ? { lastDeliveredAt: m.lastDeliveredAt } : {}),
          ...(m.lastReadClock !== undefined ? { readClock: m.lastReadClock } : {}),
          ...(m.lastDeliveredClock !== undefined ? { deliveredClock: m.lastDeliveredClock } : {}),
          vanishSeenAt: m.vanishSeenAt ?? m.joinedAt,
          ...(m.seenVisibility !== undefined ? { seenVisibility: m.seenVisibility } : {}),
        });
      }
      made++;
    }
    if (!page.isDone) {
      await ctx.scheduler.runAfter(0, internal.roomStateMigration.createStates, {
        cursor: page.continueCursor,
        created: made,
        pending: waiting,
      });
      return { done: false, created: made, pending: waiting };
    }
    console.log(`roomStateMigration.createStates: ${made} created, ${waiting} waiting on assignSeq`);
    return { done: true, created: made, pending: waiting };
  },
});

// ───────────────────────────── 3. shadow compare ─────────────────────────────

/**
 * The new arithmetic against the old scan, for every membership that has a
 * state row, using the state's own cursor for both so live traffic since the
 * backfill cannot show up as a difference. A page at a time: pass `next` back
 * as `cursor` until `done`. Mismatches name the membership and both numbers.
 */
export const shadowCompare = internalQuery({
  args: {
    cursor: v.optional(v.union(v.string(), v.null())),
    numItems: v.optional(v.number()),
  },
  handler: async (ctx, { cursor, numItems }) => {
    const page = await ctx.db
      .query("roomUserState")
      .paginate({ numItems: Math.min(numItems ?? 20, 50), cursor: cursor ?? null });
    const now = Date.now();
    const mismatches: any[] = [];
    for (const s of page.page) {
      const room = await ctx.db.get(s.roomId);
      if (!room) continue;
      const fresh = await roomUnread(ctx, room, s, now);
      const old = await unreadForRoom(ctx, s.roomId, s.userId, s.readAt, room.lastMessageTime);
      const countDiffers = fresh.count !== old.count;
      const cappedDiffers = fresh.count === 99 && old.count === 99 && fresh.capped !== old.capped;
      if (countDiffers || cappedDiffers) {
        mismatches.push({
          roomId: s.roomId,
          userId: s.userId,
          readSeq: s.readSeq,
          lastSeq: room.lastSeq,
          fresh: fresh.count,
          old: old.count,
        });
      }
    }
    return {
      scanned: page.page.length,
      mismatches,
      done: page.isDone,
      next: page.isDone ? null : page.continueCursor,
    };
  },
});

// ─────────────────────────────── 4. marker ───────────────────────────────

/**
 * Verifies the backfill is complete, then sets the marker. Two paged passes
 * (rooms must have `lastSeq`; memberships must have a state row), chained.
 * Refuses with the first offender; fix and run again.
 */
export const finish = internalMutation({
  args: {
    phase: v.optional(v.union(v.literal("rooms"), v.literal("members"))),
    cursor: v.optional(v.union(v.string(), v.null())),
  },
  handler: async (ctx, { phase, cursor }) => {
    const marker = await ctx.db
      .query("migrationMarkers")
      .withIndex("by_name", (q: any) => q.eq("name", STATE_MARKER))
      .first();
    if (marker !== null) return { ok: true, already: true };
    const which = phase ?? "rooms";
    if (which === "rooms") {
      const page = await ctx.db.query("rooms").paginate({ numItems: 100, cursor: cursor ?? null });
      for (const r of page.page) {
        if (r.lastSeq === undefined) {
          // Logged: later pages run on the scheduler and their result is lost.
          console.warn(`[roomStateMigration.finish] refused: room without lastSeq ${r._id}`);
          return { ok: false, why: "room without lastSeq", roomId: r._id };
        }
      }
      await ctx.scheduler.runAfter(0, internal.roomStateMigration.finish, page.isDone
        ? { phase: "members" as const }
        : { phase: "rooms" as const, cursor: page.continueCursor });
      return { ok: true, pending: true };
    }
    const page = await ctx.db.query("roomMembers").paginate({ numItems: 100, cursor: cursor ?? null });
    for (const m of page.page) {
      if (await stateOf(ctx, m.roomId, m.userId)) continue;
      // An orphan row (its room is gone) is the room cleanup's, not ours.
      if (!(await ctx.db.get(m.roomId))) continue;
      console.warn(
        `[roomStateMigration.finish] refused: membership without state ${m.roomId}/${m.userId}`,
      );
      return { ok: false, why: "membership without state", roomId: m.roomId, userId: m.userId };
    }
    if (!page.isDone) {
      await ctx.scheduler.runAfter(0, internal.roomStateMigration.finish, {
        phase: "members" as const,
        cursor: page.continueCursor,
      });
      return { ok: true, pending: true };
    }
    await ctx.db.insert("migrationMarkers", { name: STATE_MARKER, doneAt: Date.now() });
    console.log("roomStateMigration.finish: marker set");
    return { ok: true, done: true };
  },
});
