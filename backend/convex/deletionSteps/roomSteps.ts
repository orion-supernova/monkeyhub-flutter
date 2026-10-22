import type { Id } from "../_generated/dataModel";
import type { MutationCtx } from "../_generated/server";
import { endLiveCallsInRoom } from "../calls";
import {
  deleteCapped,
  enqueueDeletion,
  runRow,
  tuning,
  type Budget,
  type Job,
  type Step,
} from "../deletionCore";
import { releaseMessageBlobs, releaseRowFiles } from "../files";
import { endGroupCallsInRoom } from "../groupCalls";
import { purgeScheduledForRoom } from "../scheduledMessages";

/**
 * Custom teardown steps for the `room` deletion kind. `deletionPlans.planFor`
 * merges them with the generic cascade/setNull steps; a step lists the rule keys
 * it handles itself in `claims` so no generic step also runs for them.
 *
 * The order is the plan's: close the gates first (calls, invites, requests,
 * then access and membership), then the data (games, queued messages, the
 * messages), and the room row last (`parent`). The tombstone already refuses
 * new writes, so a row that races it is caught by a step that re-queries until
 * its range is empty.
 *
 * Whatever a rule needs nothing special for (pins, bookmarks, polls, speaker
 * colours, challenges, view-once rows, bans, typing rows, the DM friendship's
 * pointer) is left to the generic steps, which run after these and before the
 * parent.
 */

/** Matches erased per transaction; each one carries a handful of rows. */
const MATCH_PAGE = 25;

/** The room a job names, or null when its id no longer resolves (an orphan job). */
export function roomOf(ctx: MutationCtx, job: { targetId: string }): Id<"rooms"> | null {
  return job.targetId ? ctx.db.normalizeId("rooms", job.targetId) : null;
}

/**
 * Handle every row `fetch` returns, a page at a time, until the range is empty
 * or the budget is spent. True when empty.
 *
 * No cursor: `each` must take the row out of the range (delete it, or clear the
 * field the index leads with), so every probe starts from the top and a re-run
 * is a no-op. A row that survives its own handling would loop forever, so that
 * throws instead. Shared by the room and user steps.
 */
export async function sweep(
  b: Budget,
  fetch: (n: number) => Promise<any[]>,
  each: (row: any) => Promise<void>,
  /** Writes `each` is counted as, when it does more than one. */
  cost = 1,
  /** Rows per probe. */
  page = tuning.pageRows,
): Promise<boolean> {
  const seen = new Set<string>();
  for (;;) {
    if (b.spent()) return false;
    const rows = await fetch(page);
    b.read(Math.max(rows.length, 1));
    if (rows.length === 0) return true;
    const fresh = rows.filter((r) => !seen.has(r._id));
    if (fresh.length === 0) throw new Error("STUCK sweep rows stayed in range");
    for (const row of fresh) {
      if (b.spent()) return false;
      seen.add(row._id);
      await each(row);
      b.write(cost);
    }
    if (rows.length < page) return true;
  }
}

/**
 * [sweep] for a heavy per-row step: each row's work runs in its own nested
 * mutation (`runRow`, handled by the step's `row`), so a row that always throws
 * is retried once and then skipped instead of failing the job. Skipped rows
 * stay in their range, so the probe asks for that many extra rows and filters
 * them out. True when no unskipped row is left.
 */
export async function sweepRows(
  ctx: MutationCtx,
  job: Job,
  b: Budget,
  stepId: string,
  fetch: (n: number) => Promise<any[]>,
  page = tuning.pageRows,
): Promise<boolean> {
  const skipped = new Set<string>(job.skipped ?? []);
  const seen = new Set<string>();
  for (;;) {
    if (b.spent()) return false;
    const rows = await fetch(page + skipped.size);
    b.read(Math.max(rows.length, 1));
    const live = rows.filter((r) => !skipped.has(r._id)).slice(0, page);
    if (live.length === 0) return true;
    for (const row of live) {
      if (b.spent()) return false;
      // A row that survived its own (successful) handling would loop forever.
      if (seen.has(row._id)) throw new Error(`STUCK ${stepId} rows stayed in range`);
      seen.add(row._id);
      const out = await runRow(ctx, job, stepId, row._id, b);
      if (out === "retry" || out === "more") return false;
      if (out === "skipped") skipped.add(row._id);
    }
  }
}

export const roomSteps: Step[] = [
  {
    id: "gates",
    tier: 0,
    claims: [
      "roomInvites.roomId",
      "roomInvitations.roomId",
      "roomJoinRequests.roomId",
      "roomChangeRequests.roomId",
      "approvalRequests.targetRoomId",
    ],
    /**
     * Everything that lets someone in or keeps a promise about the room: live
     * calls end (a call in a room that no longer exists would carry on with
     * nobody able to reach it), the join link, invitations and requests go, a
     * pending photo proposal releases its file, and a guardian's pending ask
     * about the room goes with it (a decided one keeps the row, loses the
     * pointer).
     */
    async run(ctx, job, b) {
      const roomId = roomOf(ctx, job);
      if (!roomId) return { done: true };

      // Calls leave their ranges once ended. Both helpers are bounded, so end
      // what they take and let the next slice look again for the rest.
      const liveGroup = await ctx.db
        .query("groupCalls")
        .withIndex("by_room_status", (q) =>
          q.eq("roomId", roomId).eq("status", "active"),
        )
        .first();
      b.read();
      if (liveGroup) {
        await endGroupCallsInRoom(ctx, roomId);
        b.write(10);
        return { done: false };
      }
      for (const status of ["ringing", "active"]) {
        const live = await ctx.db
          .query("calls")
          .withIndex("by_room_status", (q) =>
            q.eq("roomId", roomId).eq("status", status),
          )
          .first();
        b.read();
        if (live) {
          await endLiveCallsInRoom(ctx, roomId);
          b.write(10);
          return { done: false };
        }
      }

      // The link matters most and is the easiest to forget: a `roomInvites`
      // row that outlives its room is a live code whose redemption resolves
      // to a deleted roomId, which crashes the join screen.
      const plain: [string, string][] = [
        ["roomInvites", "by_room"],
        ["roomInvitations", "by_room_invitee"],
        ["roomJoinRequests", "by_room_status"],
      ];
      for (const [table, index] of plain) {
        const done = await sweep(
          b,
          (n) =>
            (ctx.db.query(table as any) as any)
              .withIndex(index, (q: any) => q.eq("roomId", roomId))
              .take(n),
          (row) => ctx.db.delete(row._id),
        );
        if (!done) return { done: false };
      }

      // Every status, not just pending: an approved row is an audit trail of a
      // room that no longer exists. A row with a file is that file's only
      // pointer, so it is released first (refcounted: the same blob can be a
      // room's picture or another room's proposal).
      let done = await sweep(
        b,
        (n) =>
          ctx.db
            .query("roomChangeRequests")
            .withIndex("by_room_status", (q) => q.eq("roomId", roomId))
            .take(n),
        async (row) => {
          await releaseRowFiles(ctx, "roomChangeRequests", row);
          await ctx.db.delete(row._id);
        },
        // The delete, plus a release that can free the file (ref, ledger,
        // usage, and the sweep for strays).
        5,
      );
      if (!done) return { done: false };

      done = await sweep(
        b,
        (n) =>
          ctx.db
            .query("approvalRequests")
            .withIndex("by_target_room", (q) => q.eq("targetRoomId", roomId))
            .take(n),
        async (row) => {
          if (row.status === "pending") await ctx.db.delete(row._id);
          else await ctx.db.patch(row._id, { targetRoomId: undefined });
        },
      );
      return { done };
    },
  },
  {
    id: "access",
    tier: 1,
    claims: ["roomAccess.roomId"],
    /** Read grants first, so nobody can open the room's messages from here on. */
    async run(ctx, job, b) {
      const roomId = roomOf(ctx, job);
      if (!roomId) return { done: true };
      const done = await sweep(
        b,
        (n) =>
          ctx.db
            .query("roomAccess")
            .withIndex("by_room_user", (q) => q.eq("roomId", roomId))
            .take(n),
        (row) => ctx.db.delete(row._id),
      );
      return { done };
    },
  },
  {
    id: "members",
    tier: 1,
    claims: ["roomMembers.roomId"],
    /** Memberships, a page at a time. The room row is the tombstone's, not theirs. */
    async run(ctx, job, b) {
      const roomId = roomOf(ctx, job);
      if (!roomId) return { done: true };
      const done = await sweep(
        b,
        (n) =>
          ctx.db
            .query("roomMembers")
            .withIndex("by_room_user", (q) => q.eq("roomId", roomId))
            .take(n),
        (row) => ctx.db.delete(row._id),
      );
      return { done };
    },
  },
  {
    id: "matches",
    tier: 2,
    claims: ["matches.roomId"],
    /**
     * Every game the room held, one nested mutation per game. The row and its
     * secrets and heartbeats go inline (capped); a long move history is handed
     * to a `match` job, which skips the move bubbles because the messages step
     * removes every message anyway.
     */
    async run(ctx, job, b) {
      const roomId = roomOf(ctx, job);
      if (!roomId) return { done: true };
      const done = await sweepRows(
        ctx,
        job,
        b,
        "matches",
        (n) =>
          ctx.db
            .query("matches")
            .withIndex("by_room_status", (q) => q.eq("roomId", roomId))
            .take(n),
        Math.min(MATCH_PAGE, tuning.pageRows),
      );
      return { done };
    },
    async row(ctx, _job, rowId) {
      const id = ctx.db.normalizeId("matches", rowId);
      const match = id ? await ctx.db.get(id) : null;
      if (!match) return;
      const hidden = await deleteCapped(
        ctx,
        ctx.db
          .query("matchHidden")
          .withIndex("by_match", (q) => q.eq("matchId", match._id)),
      );
      const presence = await deleteCapped(
        ctx,
        ctx.db
          .query("matchPresence")
          .withIndex("by_match_user", (q) => q.eq("matchId", match._id)),
      );
      const move = await ctx.db
        .query("matchMoves")
        .withIndex("by_match_seq", (q) => q.eq("matchId", match._id))
        .first();
      await ctx.db.delete(match._id);
      if (move || hidden.overflow || presence.overflow) {
        await enqueueDeletion(ctx, {
          kind: "match",
          targetId: match._id,
          args: { skipBubbles: true },
          reason: "room",
        });
      }
    },
  },
  {
    id: "scheduled",
    tier: 3,
    claims: ["scheduledMessages.roomId"],
    /**
     * Messages staged for the room, every member's: left behind, each would
     * wake up, fail its membership guard and sit in its author's list as a
     * permanent error. Their jobs and unsent photos go too.
     */
    async run(ctx, job, b) {
      const roomId = roomOf(ctx, job);
      if (!roomId) return { done: true };
      return { done: await purgeScheduledForRoom(ctx, roomId, b) };
    },
  },
  {
    id: "messages",
    tier: 4,
    claims: ["messages.roomId"],
    /**
     * The messages, oldest first, one nested mutation per message. Each goes
     * with its reactions and its (refcounted) media, which a forward out of this
     * room may still be using. There is no per-message fan-out: reply previews
     * and the like live in this room, and the room is going.
     */
    async run(ctx, job, b) {
      const roomId = roomOf(ctx, job);
      if (!roomId) return { done: true };
      const done = await sweepRows(ctx, job, b, "messages", (n) =>
        ctx.db
          .query("messages")
          .withIndex("by_room_time", (q) => q.eq("roomId", roomId))
          .take(n),
      );
      return { done };
    },
    async row(ctx, _job, rowId) {
      const id = ctx.db.normalizeId("messages", rowId);
      const msg = id ? await ctx.db.get(id) : null;
      if (!msg) return;
      // A message with more reactions than one slice may take stays until the
      // next one: it goes only once its reactions are all gone.
      const reactions = await deleteCapped(
        ctx,
        ctx.db
          .query("reactions")
          .withIndex("by_message", (q) => q.eq("messageId", msg._id)),
        Math.max(1, Math.floor(tuning.maxWrites / 2)),
      );
      if (reactions.overflow) return "more";
      await releaseMessageBlobs(ctx, msg);
      await ctx.db.delete(msg._id);
    },
  },
  {
    id: "parent",
    tier: 1000,
    /**
     * The room's own avatar, then the room row. Easy to forget because the
     * avatar isn't a row: the document is about to vanish, and with it the only
     * pointer to the file. A system room holds its own ref like any other (its
     * avatar is shared-attached or its own blob), so the release is the same,
     * except for a file not yet tracked: that one is the account's legacy
     * avatar, which the legacy checks cannot see the account's claim on, so it
     * is left alone until the backfill marks it. A row that is already gone (a
     * re-run, or an orphan job) is skipped.
     */
    async run(ctx, job, b) {
      const roomId = roomOf(ctx, job);
      const room = roomId ? await ctx.db.get(roomId) : null;
      b.read();
      if (room === null) return { done: true };
      if (room.avatarStorageId !== undefined) {
        const ledger = await ctx.db
          .query("uploads")
          .withIndex("by_storage", (q) => q.eq("storageId", room.avatarStorageId!))
          .first();
        b.read();
        if (room.system === undefined || ledger?.tracked === true) {
          await releaseRowFiles(ctx, "rooms", room);
          b.write(5);
        }
      }
      await ctx.db.delete(room._id);
      b.write();
      return { done: true };
    },
  },
];
