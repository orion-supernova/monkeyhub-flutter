import type { Id } from "../_generated/dataModel";
import type { MutationCtx } from "../_generated/server";
import {
  cursorOf,
  isTombstoned,
  pageAfter,
  startRoomDeletion,
  tuning,
  type Step,
} from "../deletionCore";
import { purgeUserExpressions } from "../expressions";
import { releaseFile, releaseRowFiles } from "../files";
import { removeUserFromRoomGroupCall } from "../groupCalls";
import { leaveMatchesInRoom } from "../matchCore";
import { removeMessageBounded } from "../messages";
import { deleteCommentCore } from "../momentComments";
import { deleteMomentCore } from "../momentCleanup";
import { purgeRecordsOf } from "../recordBook";
import { ensureOwner, ROLE_OWNER } from "../roomAdmin";
import { revokeRoomAccess } from "../roomAccess";
import { purgeScheduledForRoomUser, purgeScheduledForUser } from "../scheduledMessages";
import { purgeSpeakerColorsForUser } from "../speakerColors";
import { deleteFriendshipRow } from "../users";
import { sweep, sweepRows } from "./roomSteps";

/**
 * Custom teardown steps for the `user` deletion kind. `deletionPlans.planFor`
 * merges them with the generic cascade/setNull steps; a step lists the rule keys
 * it handles itself in `claims` so no generic step also runs for them.
 *
 * The first transaction (`deletionCore.startUserDeletion`) already scrubbed the
 * row, revoked sessions and removed the sign-in identities, so from the first
 * step on the account is a ghost nobody can sign into. These steps do what is
 * left: leave every room, delete the messages and the rest of the person's
 * rows, and (`parent`) the stored avatar and the user row, last.
 *
 * This plan must always finish: Apple requires account deletion to work. So
 * nothing here throws on a row that is already gone, and every step re-queries
 * its range instead of trusting a cursor.
 *
 * Plain deletes (blocks, reactions, pins, bookmarks, calls, devices, group-call
 * rows, invitations, join requests, approvals, pairing codes, reports, uploads
 * and the rest) are the generic steps' job and run after these.
 */

/** Memberships left per transaction: each one touches a whole room's state. */
const MEMBERSHIP_PAGE = 20;
/** Moments deleted per transaction. */
const MOMENT_PAGE = 10;

function userOf(ctx: MutationCtx, job: { targetId: string }): Id<"users"> | null {
  return job.targetId ? ctx.db.normalizeId("users", job.targetId) : null;
}

export const userSteps: Step[] = [
  {
    id: "sessions",
    tier: 0,
    claims: ["sessions.userId"],
    /**
     * Revoke the rest, a page at a time (the first transaction did the first
     * hundred). REVOKED rather than deleted, so a device's next call gets the
     * honest SESSION_REVOKED instead of SESSION_UNKNOWN, and `gcRevokedSessions`
     * collects the rows on the schedule it already owns. A revoked row stays in
     * the `by_user` range, hence the cursor.
     */
    async run(ctx, job, b) {
      const userId = userOf(ctx, job);
      if (!userId) return { done: true };
      // No account left to sign in to (a re-run, or an old chain's job): the
      // revoked rows that remain are `gcRevokedSessions`'s.
      b.read();
      if ((await ctx.db.get(userId)) === null) return { done: true };
      const now = Date.now();
      let cursor = job.cursor;
      for (;;) {
        if (b.spent()) return { done: false, cursor };
        const rows = await pageAfter(
          (t, k) =>
            ctx.db
              .query("sessions")
              .withIndex("by_user", (q) =>
                q.eq("userId", userId).gte("_creationTime", t),
              )
              .take(k),
          cursor,
          tuning.pageRows,
        );
        b.read(Math.max(rows.length, 1));
        if (rows.length === 0) return { done: true };
        for (const row of rows) {
          if (b.spent()) return { done: false, cursor };
          if (row.revokedAt === undefined) {
            await ctx.db.patch(row._id, { revokedAt: now });
            b.write();
          }
          cursor = cursorOf(row);
        }
      }
    },
  },
  {
    id: "social",
    tier: 0,
    claims: ["friendships.userId", "friendships.friendId", "guardianships.guardianId"],
    /**
     * Friendships both ways, through `deleteFriendshipRow`: a pending request
     * carries messages, and the OTHER person's rows (requests they sent this
     * user, or received from them) would otherwise leave theirs behind. A
     * guardian's links go too (a last guardian was refused before the deletion
     * started; the child's own approvals stay, see `approvalRequests`).
     */
    async run(ctx, job, b) {
      const userId = userOf(ctx, job);
      if (!userId) return { done: true };
      const ranges: ((n: number) => Promise<any[]>)[] = [
        (n) =>
          ctx.db
            .query("friendships")
            .withIndex("by_user", (q) => q.eq("userId", userId))
            .take(n),
        (n) =>
          ctx.db
            .query("friendships")
            .withIndex("by_friend", (q) => q.eq("friendId", userId))
            .take(n),
      ];
      for (const fetch of ranges) {
        const done = await sweep(b, fetch, (row) => deleteFriendshipRow(ctx, row), 2);
        if (!done) return { done: false };
      }
      const done = await sweep(
        b,
        (n) =>
          ctx.db
            .query("guardianships")
            .withIndex("by_guardian", (q) => q.eq("guardianId", userId))
            .take(n),
        (row) => ctx.db.delete(row._id),
      );
      return { done };
    },
  },
  {
    id: "memberships",
    tier: 1,
    claims: ["roomMembers.userId", "matches.seatRequest.userId"],
    /**
     * Leave every room the way `removeMembership` does, a few at a time, one
     * nested mutation per room: the row and the read grant go, their open games
     * are forfeited, they leave the room's group call and their queued messages
     * go. The last one out starts the room's own teardown (emptiness is one
     * `take(1)`, however big the room was); otherwise the count drops, and an
     * owner's seat is handed on by `ensureOwner` so the room is not frozen for
     * everyone still in it. A room the leaver created but did not own is
     * re-pointed at the owner, so `createdBy` keeps naming somebody who is still
     * here. `leaveMatchesInRoom` also clears a pending seat request of theirs on
     * each game (`matches.seatRequest.userId`).
     */
    async run(ctx, job, b) {
      const userId = userOf(ctx, job);
      if (!userId) return { done: true };
      const done = await sweepRows(
        ctx,
        job,
        b,
        "memberships",
        (n) =>
          ctx.db
            .query("roomMembers")
            .withIndex("by_user", (q) => q.eq("userId", userId))
            .take(n),
        Math.min(MEMBERSHIP_PAGE, tuning.pageRows),
      );
      return { done };
    },
    async row(ctx, job, rowId) {
      const userId = userOf(ctx, job);
      const id = ctx.db.normalizeId("roomMembers", rowId);
      const membership = id ? await ctx.db.get(id) : null;
      if (!userId || !membership) return;
      const roomId: Id<"rooms"> = membership.roomId;
      await ctx.db.delete(membership._id);
      await revokeRoomAccess(ctx, roomId, userId);
      // Before the room can go: forfeiting writes to the games.
      await leaveMatchesInRoom(ctx, roomId, userId);
      await removeUserFromRoomGroupCall(ctx, roomId, userId);
      await purgeScheduledForRoomUser(ctx, roomId, userId);

      const left = await ctx.db
        .query("roomMembers")
        .withIndex("by_room_user", (q) => q.eq("roomId", roomId))
        .take(1);
      if (left.length === 0) {
        await startRoomDeletion(ctx, roomId, { reason: "lastMember" });
        return;
      }
      const room = await ctx.db.get(roomId);
      if (!room || isTombstoned(room)) return;
      await ctx.db.patch(roomId, {
        memberCount: Math.max(0, room.memberCount - 1),
      });
      if (membership.role === ROLE_OWNER) await ensureOwner(ctx, roomId);
      const fresh = await ctx.db.get(roomId);
      if (fresh && fresh.createdBy === userId) {
        const owner = await ctx.db
          .query("roomMembers")
          .withIndex("by_room_role", (q) =>
            q.eq("roomId", roomId).eq("role", ROLE_OWNER),
          )
          .first();
        if (owner) await ctx.db.patch(roomId, { createdBy: owner.userId });
      }
    },
  },
  {
    id: "messages",
    tier: 2,
    claims: ["messages.userId"],
    /**
     * Their messages, a page at a time, one nested mutation per message,
     * through the bounded per-message delete (the same teardown every delete
     * path uses: reactions, pins and bookmarks other people put on it,
     * refcounted media, the view-once ledger, a poll's answers, a game card's
     * game and its move bubbles, reply tethers; an overflow becomes its own
     * `message` job). A game card can cost thousands of writes (every bubble is
     * a message of its own), which is why the cost is measured, not guessed.
     * The row is re-read: a game card earlier in the page takes its move
     * bubbles with it, and some of those may be this user's own.
     */
    async run(ctx, job, b) {
      const userId = userOf(ctx, job);
      if (!userId) return { done: true };
      const done = await sweepRows(ctx, job, b, "messages", (n) =>
        ctx.db
          .query("messages")
          .withIndex("by_user", (q) => q.eq("userId", userId))
          .take(n),
      );
      return { done };
    },
    async row(ctx, _job, rowId) {
      const id = ctx.db.normalizeId("messages", rowId);
      const live = id ? await ctx.db.get(id) : null;
      if (live) await removeMessageBounded(ctx, live, live._id);
    },
  },
  {
    id: "scheduled",
    tier: 3,
    claims: ["scheduledMessages.userId"],
    /**
     * Messages queued in every room, including the ones that survive. Not
     * merely a dangling row: each holds a live scheduler job that would wake up
     * months from now and post in a deleted person's name.
     */
    async run(ctx, job, b) {
      const userId = userOf(ctx, job);
      if (!userId) return { done: true };
      return { done: await purgeScheduledForUser(ctx, userId, b) };
    },
  },
  {
    id: "speakerColors",
    tier: 3,
    claims: ["speakerColors.subjectId", "speakerColors.viewerId"],
    /** Colours this user set and the ones other people set about them. */
    async run(ctx, job, b) {
      const userId = userOf(ctx, job);
      if (!userId) return { done: true };
      return { done: await purgeSpeakerColorsForUser(ctx, userId, b) };
    },
  },
  {
    id: "proposals",
    tier: 4,
    claims: ["roomChangeRequests.userId"],
    /**
     * Suggestions this account made about a room's name, description or
     * picture: a pending row addressed to nobody is a queue item no admin can
     * resolve. Only a PENDING row's file is released: an approved one's file is
     * the room's live avatar, which the room outlives this account. (The
     * file's refs guard the rest.) The decider pointer on
     * other people's rows is the generic `roomChangeRequests.decidedBy` step.
     */
    async run(ctx, job, b) {
      const userId = userOf(ctx, job);
      if (!userId) return { done: true };
      const done = await sweep(
        b,
        (n) =>
          ctx.db
            .query("roomChangeRequests")
            .withIndex("by_user", (q) => q.eq("userId", userId))
            .take(n),
        async (row) => {
          if (row.status === "pending" && row.storageId) {
            await releaseRowFiles(ctx, "roomChangeRequests", row);
          }
          await ctx.db.delete(row._id);
        },
        // The delete, plus a release that can free the file.
        5,
      );
      return { done };
    },
  },
  {
    id: "invites",
    tier: 4,
    claims: ["roomInvites.createdBy"],
    /**
     * The links this user issued. A live link outliving its creator is a
     * working join token attributed to somebody who no longer exists. Requests
     * that came in through one survive it, minus the pointer.
     */
    async run(ctx, job, b) {
      const userId = userOf(ctx, job);
      if (!userId) return { done: true };
      for (;;) {
        if (b.spent()) return { done: false };
        const invites = await ctx.db
          .query("roomInvites")
          .withIndex("by_creator", (q) => q.eq("createdBy", userId))
          .take(tuning.pageRows);
        b.read(Math.max(invites.length, 1));
        if (invites.length === 0) return { done: true };
        for (const invite of invites) {
          const cleared = await sweep(
            b,
            (n) =>
              ctx.db
                .query("roomJoinRequests")
                .withIndex("by_invite", (q) => q.eq("inviteId", invite._id))
                .take(n),
            (row) => ctx.db.patch(row._id, { inviteId: undefined }),
          );
          if (!cleared) return { done: false };
          await ctx.db.delete(invite._id);
          b.write();
        }
      }
    },
  },
  {
    id: "comments",
    tier: 5,
    claims: ["momentComments.userId"],
    /**
     * What they said under other people's highlights (and under their own, if
     * a moment's comment is still around), one nested mutation per comment,
     * through the bounded comment delete; a thread root takes its replies with
     * it, so each is re-read first.
     */
    async run(ctx, job, b) {
      const userId = userOf(ctx, job);
      if (!userId) return { done: true };
      const done = await sweepRows(ctx, job, b, "comments", (n) =>
        ctx.db
          .query("momentComments")
          .withIndex("by_user", (q) => q.eq("userId", userId))
          .take(n),
      );
      return { done };
    },
    async row(ctx, _job, rowId) {
      const id = ctx.db.normalizeId("momentComments", rowId);
      const live = id ? await ctx.db.get(id) : null;
      if (live) await deleteCommentCore(ctx, live);
    },
  },
  {
    id: "moments",
    tier: 5,
    claims: ["moments.userId"],
    /**
     * Their moments, a few per transaction, one nested mutation each, with its
     * files (shared-file check included) and, capped, its reactions, views and
     * comments; a moment with more hands the rest to a `moment` job. Last in
     * the feed group so a failure part-way never leaves a child pointing at a
     * row that is gone.
     */
    async run(ctx, job, b) {
      const userId = userOf(ctx, job);
      if (!userId) return { done: true };
      const done = await sweepRows(
        ctx,
        job,
        b,
        "moments",
        (n) =>
          ctx.db
            .query("moments")
            .withIndex("by_user", (q) => q.eq("userId", userId))
            .take(n),
        Math.min(MOMENT_PAGE, tuning.pageRows),
      );
      return { done };
    },
    async row(ctx, _job, rowId) {
      const id = ctx.db.normalizeId("moments", rowId);
      const live = id ? await ctx.db.get(id) : null;
      if (live) await deleteMomentCore(ctx, live);
    },
  },
  {
    id: "expressions",
    tier: 6,
    claims: ["userExpressions.userId", "stickerPacks.ownerId"],
    /**
     * Their personal stickers are cut out of their own photos, so the files go
     * with the account (rows are tombstoned, since other people's messages
     * still hold the ids), along with their recents and favourites.
     */
    async run(ctx, job, b) {
      const userId = userOf(ctx, job);
      if (!userId) return { done: true };
      return { done: await purgeUserExpressions(ctx, userId, b) };
    },
  },
  {
    id: "records",
    tier: 6,
    claims: ["gameRecords.userId"],
    /** All-time records: theirs, the reactions on them, and the ones they left. */
    async run(ctx, job, b) {
      const userId = userOf(ctx, job);
      if (!userId) return { done: true };
      return { done: await purgeRecordsOf(ctx, userId, b) };
    },
  },
  {
    id: "parent",
    tier: 1000,
    /**
     * The stored avatar (the first transaction cleared the row's pointer and
     * kept the id on the job), then the user row. Without the row there is
     * nothing to do: a re-run, or the shim for an old chain.
     */
    async run(ctx, job, b) {
      const userId = userOf(ctx, job);
      const user = userId ? await ctx.db.get(userId) : null;
      b.read();
      if (user === null) return { done: true };
      // The id the first transaction took off the row, then whatever the row
      // still names and any stray ref under it. A release with no ref left is a
      // no-op, so a re-run, or a job enqueued without the first step, is safe.
      await releaseFile(ctx, job.args?.avatarStorageId, {
        table: "users",
        id: user._id.toString(),
        field: "avatarStorageId",
      });
      await releaseRowFiles(ctx, "users", user);
      await ctx.db.delete(user._id);
      b.write(6);
      return { done: true };
    },
  },
];
