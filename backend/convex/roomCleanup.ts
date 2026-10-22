/**
 * Room teardown entry points.
 *
 * Convex has no foreign keys and no cascade deletes, so every row that hangs
 * off a room has to be removed by hand. Getting that list wrong leaves
 * orphaned messages, reactions, or — worst — media files sitting in storage
 * that nothing points at any more. The list lives in one place now: the room
 * plan (`deletionSteps/roomSteps.ts` plus the generic steps `deletionPlans.ts`
 * builds from `REFERENCE_RULES`), run in bounded slices by the lifecycle engine
 * (docs/data-integrity-phase2-design.md). Both the block flow and the guardian
 * "take back" flow, and the last member leaving, start that same teardown here.
 *
 * Plain helpers, not Convex functions: callers pass their own `ctx`.
 */

import { enqueueDeletion, startRoomDeletion, tuning } from "./deletionCore";
import { internalMutation, internalQuery } from "./_generated/server";
import { v } from "convex/values";
import { internal } from "./_generated/api";

/**
 * Starts the teardown of a room: messages, their reactions, their media in
 * `ctx.storage`, typing rows, memberships, the room's own avatar, and the room
 * row itself.
 *
 * Returns at once: the room is hidden (tombstoned) in this transaction, and a
 * `deletions` job finishes the rest in the background, the room row last. This
 * is destructive for EVERY member, not just the caller — a wiped DM is gone for
 * both people. Callers must have confirmed that with the user first.
 */
export async function wipeRoomCompletely(
  ctx: any,
  roomId: any,
  opts: { reason?: string } = {},
) {
  return await startRoomDeletion(ctx, roomId, opts);
}

/**
 * Shim for one release: a message-wiping chain scheduled by the old teardown
 * names this function, so it has to keep existing. It hands the room to the
 * engine, which sweeps whatever messages are left (the room row is already
 * gone, and every step copes with that). Delete once nothing is scheduled.
 */
export const wipeMessagesLater = internalMutation({
  args: { roomId: v.id("rooms") },
  handler: async (ctx, { roomId }) => {
    // A live room is not this shim's to touch.
    const row = await ctx.db.get(roomId);
    if (row && row.deletingAt === undefined) return;
    await enqueueDeletion(ctx, {
      kind: "room",
      targetId: roomId,
      reason: "legacy",
    });
  },
});

/**
 * Read-only orphan report — which roomMembers rows point at rooms that no
 * longer exist. Membership and messages for a deleted room become permanently
 * invisible: there is no room to open and mark read. This can happen if a
 * room teardown crashes partway through (e.g., `wipeRoomCompletely` calls
 * `ctx.db.delete(roomId)` before the loop finishes) or if the room is deleted
 * outside the normal path.
 *
 * This function is the dry run for `gcOrphanedRoomMemberships` — inspect the
 * output before that sweep runs to confirm no live rooms will be deleted.
 *
 *   npx convex run roomCleanup:listOrphanedRoomMemberships '{}'
 */
export const listOrphanedRoomMemberships = internalQuery({
  args: {},
  returns: v.object({
    totalMemberships: v.number(),
    orphanedMemberships: v.number(),
    orphanedRoomCount: v.number(),
    orphanRoomsWithMessageCount: v.array(
      v.object({
        roomId: v.string(),
        membershipCount: v.number(),
        messageCount: v.number(),
      }),
    ),
  }),
  handler: async (ctx) => {
    const allMembers = await ctx.db
      .query("roomMembers")
      .take(50000);
    const roomCache = new Map();
    let orphanedMemberships = 0;
    const orphanedRoomIds = new Set<string>();
    const orphansByRoomId: { [roomId: string]: any[] } = {};

    for (const m of allMembers) {
      const key = m.roomId.toString();
      if (!roomCache.has(key)) {
        const room = await ctx.db.get(m.roomId);
        roomCache.set(key, room);
      }
      const room = roomCache.get(key);
      if (!room) {
        orphanedMemberships++;
        orphanedRoomIds.add(key);
        if (!orphansByRoomId[key]) orphansByRoomId[key] = [];
        orphansByRoomId[key].push(m);
      }
    }

    const orphanRoomsWithMessageCount: Array<{
      roomId: string;
      membershipCount: number;
      messageCount: number;
    }> = [];
    for (const roomId of orphanedRoomIds) {
      const msgs = await ctx.db
        .query("messages")
        .withIndex("by_room_time", (q: any) => q.eq("roomId", roomId as any))
        .take(100000);
      orphanRoomsWithMessageCount.push({
        roomId,
        membershipCount: orphansByRoomId[roomId].length,
        messageCount: msgs.length,
      });
    }

    return {
      totalMemberships: allMembers.length,
      orphanedMemberships,
      orphanedRoomCount: orphanedRoomIds.size,
      orphanRoomsWithMessageCount,
    };
  },
});

/**
 * Garbage collect orphaned room memberships: scans for roomMembers rows whose
 * room document no longer exists, and finishes the teardown by deleting their
 * messages, reactions, pins, bookmarks, and membership rows. This is a repair
 * sweep for teardowns that crashed or were interrupted.
 *
 * Runs daily via cron as a backstop; the main path is that room deletion never
 * produces orphaned data in the first place. See `gcOrphanedRoomMemberships`
 * in `crons.ts`.
 */
export const gcOrphanedRoomMemberships = internalMutation({
  args: { cursor: v.optional(v.union(v.string(), v.null())) },
  returns: v.object({ cleaned: v.number() }),
  handler: async (ctx, { cursor }) => {
    // A page of memberships at a time, rescheduling itself for the rest: one
    // pass over every membership could not fit in a transaction.
    const page = await ctx.db
      .query("roomMembers")
      .paginate({ cursor: cursor ?? null, numItems: Math.min(GC_PAGE, tuning.pageRows) });
    const checked = new Set<string>();
    let cleaned = 0;
    for (const m of page.page) {
      const key = m.roomId.toString();
      if (checked.has(key)) continue;
      checked.add(key);
      if (await ctx.db.get(m.roomId)) continue;
      // The room row is gone already; the engine's room plan finishes the
      // rest by id (every step copes with a missing row).
      await enqueueDeletion(ctx, {
        kind: "room",
        targetId: key,
        reason: "orphan",
      });
      cleaned++;
    }
    if (!page.isDone) {
      await ctx.scheduler.runAfter(0, internal.roomCleanup.gcOrphanedRoomMemberships, {
        cursor: page.continueCursor,
      });
    }
    if (cleaned > 0) {
      console.log(`gcOrphanedRoomMemberships: cleaned ${cleaned} orphaned rooms`);
    }
    return { cleaned };
  },
});

/** Memberships looked at per transaction by the orphan sweep. */
const GC_PAGE = 200;

/**
 * Every room name a DM between [a] and [b] can have, exactly as
 * `rooms.getOrCreateDM` / `friends` build them: `dm:regular:` and `dm:secret:`
 * with the two ids sorted, the legacy unkeyed `dm:<a>:<b>`, and, when [a] and
 * [b] are the same person, their Saved Messages room `dm:self:<id>`.
 */
export function dmRoomNamesBetween(a: any, b: any): string[] {
  const ids = [a.toString(), b.toString()].sort();
  const names = [
    `dm:regular:${ids[0]}:${ids[1]}`,
    `dm:secret:${ids[0]}:${ids[1]}`,
    `dm:${ids[0]}:${ids[1]}`,
  ];
  if (ids[0] === ids[1]) names.push(`dm:self:${ids[0]}`);
  return names;
}

/**
 * Every DM room shared by [a] and [b].
 *
 * Returns a list, not a single room, on purpose: DM rooms are named
 * `dm:<roomKey>:<sortedIdA>:<sortedIdB>` (see `rooms.getOrCreateDM`), so a
 * pair can legitimately hold two at once — a regular one and a Chamber of
 * Secrets one — plus a legacy `dm:<a>:<b>` from before the roomKey existed.
 * The names are deterministic, so each variant is one `rooms.by_name` point
 * read (see `dmRoomNamesBetween`), then a membership check for both people.
 */
export async function findDmRoomsBetween(
  ctx: any,
  a: any,
  b: any,
): Promise<any[]> {
  const out: any[] = [];
  const seen = new Set<string>();
  for (const name of dmRoomNamesBetween(a, b)) {
    const rooms = await ctx.db
      .query("rooms")
      .withIndex("by_name", (q: any) => q.eq("name", name))
      .take(5);
    for (const room of rooms) {
      if (seen.has(room._id.toString())) continue;
      // Both must still be in it: a DM row outlives either member leaving.
      const inA = await ctx.db
        .query("roomMembers")
        .withIndex("by_room_user", (q: any) =>
          q.eq("roomId", room._id).eq("userId", a),
        )
        .first();
      if (!inA) continue;
      const inB = await ctx.db
        .query("roomMembers")
        .withIndex("by_room_user", (q: any) =>
          q.eq("roomId", room._id).eq("userId", b),
        )
        .first();
      if (!inB) continue;
      seen.add(room._id.toString());
      out.push(room._id);
    }
  }
  return out;
}

/**
 * How much is actually in these rooms, so a confirmation can say "128
 * messages, last one on Tuesday" instead of a vague "this cannot be undone".
 */
export async function summariseRooms(
  ctx: any,
  roomIds: any[],
): Promise<{ messageCount: number; lastMessageAt: number | null }> {
  let messageCount = 0;
  let lastMessageAt: number | null = null;
  for (const roomId of roomIds) {
    const msgs = await ctx.db
      .query("messages")
      .withIndex("by_room_time", (q: any) => q.eq("roomId", roomId))
      .collect();
    messageCount += msgs.length;
    for (const m of msgs) {
      if (lastMessageAt === null || m.createdAt > lastMessageAt) {
        lastMessageAt = m.createdAt;
      }
    }
  }
  return { messageCount, lastMessageAt };
}
