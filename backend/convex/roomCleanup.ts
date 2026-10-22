/**
 * Room teardown, in one place.
 *
 * Convex has no foreign keys and no cascade deletes, so every row that hangs
 * off a room has to be removed by hand. Getting that list wrong leaves
 * orphaned messages, reactions, or — worst — media files sitting in storage
 * that nothing points at any more. Both the block flow and the guardian
 * "take back" flow need exactly the same teardown, so it lives here rather
 * than being copied.
 *
 * Plain helpers, not Convex functions: callers pass their own `ctx`.
 */

import { deleteStored, releaseMessageBlobs } from "./files";
import { purgeScheduledForRoom } from "./scheduledMessages";
import { purgeSpeakerColorsForRoom } from "./speakerColors";
import { endLiveCallsInRoom } from "./calls";
import { endGroupCallsInRoom } from "./groupCalls";
import { purgeChallengesForRoom, purgeMatchesForRoom } from "./matchCore";
import { internalMutation, internalQuery } from "./_generated/server";
import { v } from "convex/values";
import { revokeAllRoomAccess } from "./roomAccess";
import { releaseRoomPhoto } from "./roomAdmin";
import { internal } from "./_generated/api";

/**
 * Deletes messages, reactions, media, and membership-related data for a room.
 * Does NOT delete the room document itself or its avatar — used by both
 * `wipeRoomCompletely` (when the room doc is live) and as a repair sweep for
 * orphaned memberships (when the room doc is already gone).
 */
async function wipeRoomContents(ctx: any, roomId: any) {
  // Messages go in batches. A room with thousands of them could not be
  // deleted in one transaction (Convex caps reads and writes per call), and
  // because the last member leaving also lands here, nobody could leave it
  // either. The rest is gone by the time this returns; leftover messages are
  // unreadable already (memberships and access are dropped below) and are
  // finished by [wipeMessagesLater].
  if (await wipeMessagesBatch(ctx, roomId, WIPE_BATCH)) {
    await ctx.scheduler.runAfter(0, internal.roomCleanup.wipeMessagesLater, {
      roomId,
    });
  }
  await wipeRoomRows(ctx, roomId);
}

/** Messages deleted per transaction during a room teardown. */
const WIPE_BATCH = 300;

/**
 * Deletes up to [limit] of [roomId]'s messages with their reactions, media
 * and view-once rows. True when more remain.
 */
async function wipeMessagesBatch(ctx: any, roomId: any, limit: number) {
  // Messages → reactions + media + row
  const msgs = await ctx.db
    .query("messages")
    .withIndex("by_room_time", (q: any) => q.eq("roomId", roomId))
    .take(limit + 1);
  for (const msg of msgs.slice(0, limit)) {
    const reactions = await ctx.db
      .query("reactions")
      .withIndex("by_message", (q: any) => q.eq("messageId", msg._id))
      .collect();
    for (const r of reactions) await ctx.db.delete(r._id);
    // Refcounted: a message forwarded OUT of this room still points at these
    // bytes from wherever it landed. See `releaseMessageBlobs`.
    await releaseMessageBlobs(ctx, msg);
    // View-once ledger. Empty index range for ordinary messages.
    const views = await ctx.db
      .query("viewOnceViews")
      .withIndex("by_message", (q: any) => q.eq("messageId", msg._id))
      .collect();
    for (const vw of views) await ctx.db.delete(vw._id);
    await ctx.db.delete(msg._id);
  }
  return msgs.length > limit;
}

/** Finishes a teardown's messages, one batch per transaction. */
export const wipeMessagesLater = internalMutation({
  args: { roomId: v.id("rooms") },
  handler: async (ctx, { roomId }) => {
    if (await wipeMessagesBatch(ctx, roomId, WIPE_BATCH)) {
      await ctx.scheduler.runAfter(0, internal.roomCleanup.wipeMessagesLater, {
        roomId,
      });
    }
  },
});

/** Everything about a room except its messages. */
async function wipeRoomRows(ctx: any, roomId: any) {
  // Memberships
  const members = await ctx.db
    .query("roomMembers")
    .withIndex("by_room_user", (q: any) => q.eq("roomId", roomId))
    .collect();
  // Live calls first: a call in a room that no longer exists would carry on
  // (nothing else ends it until the stuck-call sweeps) with nobody able to
  // reach its room.
  await endGroupCallsInRoom(ctx, roomId);
  await endLiveCallsInRoom(ctx, roomId);
  for (const m of members) await ctx.db.delete(m._id);
  await revokeAllRoomAccess(ctx, roomId);
  // Pins. Swept by room rather than inside the per-message loop above,
  // precisely because this table denormalizes roomId: one index range instead
  // of an index probe per message in the room.
  const pins = await ctx.db
    .query("pinnedMessages")
    .withIndex("by_room_message", (q: any) => q.eq("roomId", roomId))
    .collect();
  for (const p of pins) await ctx.db.delete(p._id);
  // Bookmarks, every member's. Swept by room for the same reason the pins above
  // are — `messageBookmarks` denormalizes roomId, and `by_room_user_message` is
  // prefix-scannable on roomId alone, so this is one index range rather than a
  // probe per message.
  const bookmarks = await ctx.db
    .query("messageBookmarks")
    .withIndex("by_room_user_message", (q: any) => q.eq("roomId", roomId))
    .collect();
  for (const b of bookmarks) await ctx.db.delete(b._id);
  // Poll/checklist/event bodies, and every answer to them. Swept by room off
  // the denormalized `roomId` for exactly the reason the pins and bookmarks
  // above are: two index ranges instead of two probes per message in the room,
  // and the overwhelming majority of those probes would find nothing.
  const interactions = await ctx.db
    .query("messageInteractions")
    .withIndex("by_room_time", (q: any) => q.eq("roomId", roomId))
    .collect();
  for (const i of interactions) await ctx.db.delete(i._id);
  const answers = await ctx.db
    .query("interactionResponses")
    .withIndex("by_room_user", (q: any) => q.eq("roomId", roomId))
    .collect();
  for (const a of answers) await ctx.db.delete(a._id);
  // Every reader's manual speaker colours for this room. Swept by room off
  // `by_room_subject`, one index range rather than a probe per member — and
  // unlike almost everything else here, these rows belong to readers rather
  // than to the room, so missing them would leave live rows pointing at a
  // roomId nothing resolves.
  await purgeSpeakerColorsForRoom(ctx, roomId);
  // In-chat games, their move history and their heartbeats.
  await purgeMatchesForRoom(ctx, roomId);
  await purgeChallengesForRoom(ctx, roomId);
  // Typing indicators
  const typing = await ctx.db
    .query("typingIndicators")
    .withIndex("by_room_user", (q: any) => q.eq("roomId", roomId))
    .collect();
  for (const t of typing) await ctx.db.delete(t._id);
  // The room's join link, its outstanding invites, and its join-request queue.
  //
  // The link matters most and is the easiest to forget, because it is the one
  // row here that is not obviously "about" a member: a `roomInvites` row that
  // outlives its room is a live code whose redemption resolves to a deleted
  // roomId, which is a crash on the join screen rather than the "this link is
  // no longer valid" a person deserves. Swept, not revoked — the room is gone,
  // so there is nothing left for the row to be the audit trail OF.
  const invites = await ctx.db
    .query("roomInvites")
    .withIndex("by_room", (q: any) => q.eq("roomId", roomId))
    .collect();
  for (const i of invites) await ctx.db.delete(i._id);
  const invitations = await ctx.db
    .query("roomInvitations")
    .withIndex("by_room_invitee", (q: any) => q.eq("roomId", roomId))
    .collect();
  for (const i of invitations) await ctx.db.delete(i._id);
  const joinRequests = await ctx.db
    .query("roomJoinRequests")
    .withIndex("by_room_user", (q: any) => q.eq("roomId", roomId))
    .collect();
  for (const r of joinRequests) await ctx.db.delete(r._id);
  // Suggestions for this room's name, description or picture — see
  // `roomChangeRequests.ts`. Every status, not just pending: an approved row
  // is an audit trail of a room that no longer exists.
  //
  // A pending avatar proposal carries a FILE, and this row is its only
  // pointer. Deleting the rows without releasing the blobs is the same leak
  // the room's own avatar has two functions down, at a spot that is much
  // easier to miss because the pointer is one field on one row in a table
  // most of whose rows have no file at all.
  const proposals = await ctx.db
    .query("roomChangeRequests")
    .withIndex("by_room_user", (q: any) => q.eq("roomId", roomId))
    .collect();
  for (const r of proposals) {
    if (r.storageId) {
      await releaseRoomPhoto(ctx, r.storageId, { roomId, requestId: r._id });
    }
    await ctx.db.delete(r._id);
  }
  // Messages staged for a room that is about to stop existing — every member's,
  // not just the caller's. Left behind, each would wake up on its own schedule,
  // fail `guardOutgoing` against a room with no memberships, and settle as a
  // permanent error in its author's list for a conversation they can no longer
  // open. Their scheduler jobs go too; see `purgeScheduledForRoom`.
  await purgeScheduledForRoom(ctx, roomId);
  // Nothing to clean up for notifications: there is no server-side record of
  // one. Any banner still on a device for this room is already moot, and the
  // badge corrects on the recipient's next push or foreground.
}

/**
 * Deletes every trace of a room: messages, their reactions, their media in
 * `ctx.storage`, typing rows, memberships, the room's own avatar, and the room
 * row itself.
 *
 * This is destructive for EVERY member, not just the caller — a wiped DM is
 * gone for both people. Callers must have confirmed that with the user first.
 */
export async function wipeRoomCompletely(ctx: any, roomId: any) {
  await wipeRoomContents(ctx, roomId);
  // The room's own avatar. Easy to forget because it isn't a row — the room
  // document is about to vanish, and with it the only pointer to the file.
  const room = await ctx.db.get(roomId);
  await releaseRoomPhoto(ctx, room?.avatarStorageId, { roomId });
  // The room itself
  await ctx.db.delete(roomId);
}

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
  args: {},
  returns: v.object({ cleaned: v.number() }),
  handler: async (ctx) => {
    const allMembers = await ctx.db
      .query("roomMembers")
      .take(50000);
    const roomCache = new Map();
    const orphanedRoomIds = new Set<string>();

    for (const m of allMembers) {
      const key = m.roomId.toString();
      if (!roomCache.has(key)) {
        const room = await ctx.db.get(m.roomId);
        roomCache.set(key, room);
      }
      const room = roomCache.get(key);
      if (!room) {
        orphanedRoomIds.add(key);
      }
    }

    let cleaned = 0;
    for (const roomId of orphanedRoomIds) {
      await wipeRoomContents(ctx, roomId as any);
      cleaned++;
    }

    console.log(`gcOrphanedRoomMemberships: cleaned ${cleaned} orphaned rooms`);
    return { cleaned };
  },
});

/**
 * Every DM room shared by [a] and [b].
 *
 * Returns a list, not a single room, on purpose: DM rooms are named
 * `dm:<roomKey>:<sortedIdA>:<sortedIdB>` (see `rooms.getOrCreateDM`), so a
 * pair can legitimately hold two at once — a regular one and a Chamber of
 * Secrets one — plus a legacy `dm:<a>:<b>` from before the roomKey existed.
 * We don't know which variants exist, so we walk [a]'s memberships and keep
 * the `dm:`-prefixed rooms [b] is also in.
 */
export async function findDmRoomsBetween(
  ctx: any,
  a: any,
  b: any,
): Promise<any[]> {
  const out: any[] = [];
  const mine = await ctx.db
    .query("roomMembers")
    .withIndex("by_user", (q: any) => q.eq("userId", a))
    .collect();
  for (const m of mine) {
    const room = await ctx.db.get(m.roomId);
    if (!room || !room.name?.startsWith("dm:")) continue;
    const otherMember = await ctx.db
      .query("roomMembers")
      .withIndex("by_room_user", (q: any) =>
        q.eq("roomId", m.roomId).eq("userId", b),
      )
      .first();
    if (!otherMember) continue;
    out.push(m.roomId);
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
