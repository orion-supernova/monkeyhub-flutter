/**
 * "Add a friend to this room" — a directed invite one person sends another,
 * which that person accepts or rejects.
 *
 * Modelled on the friend request in `friends.ts` on purpose, down to the
 * guardian relay in `stage`. Being pulled into a group chat is the same
 * category of act as being added as a contact: somebody you may or may not
 * know is proposing to put you somewhere, and the answer has to be yours. A
 * room invite that just dropped people into rooms would be the one place in
 * this app where that stopped being true — and it would be the place with the
 * biggest audience.
 *
 * The other direction — a stranger with the link asking to come IN — is
 * `roomInvites.roomJoinRequests`, and an admin answers that one. See the
 * schema comment on `roomInvitations` for why the two are separate tables.
 */

import { mutation, query } from "./functions";
import { internal } from "./_generated/api";
import { v } from "convex/values";
import {
  STAGE_RECIPIENT,
  STAGE_RECIPIENT_GUARDIAN,
  STAGE_SENDER_GUARDIAN,
  assertGuardian,
  childMayUseRoom,
  guardiansOf,
  initialStageForRoomInvite,
  isChild,
  isReleasedToRecipient,
  ERR_APPROVAL_REQUIRED,
} from "./childGuard";
import { ERR_SYSTEM_ACCOUNT, isSystemAccount } from "./systemAccount";
import { lensFor, publicUserView } from "./visibility";
import {
  addMembership,
  assertAdministrableRoom,
  assertMayInvite,
  clearPendingFor,
  isAdminRole,
  membershipOf,
  roleOf,
} from "./roomAdmin";
import { consume } from "./rateLimit";
import { getLiveUser, isTombstoned } from "./deletionCore";

export const ERR_ALREADY_MEMBER = "ALREADY_MEMBER";
export const ERR_ALREADY_INVITED = "ALREADY_INVITED";
export const ERR_INVITATION_NOT_FOUND = "INVITATION_NOT_FOUND";
export const ERR_CANNOT_INVITE_SELF = "CANNOT_INVITE_SELF";

// ─────────────────────────────── sending ───────────────────────────────

/**
 * Invite one person to this room.
 *
 * Who may call this is `roomAdmin.assertMayInvite` and nowhere else: admins
 * always, members only while the room's `membersCanInvite` switch is on. The
 * switch is re-read here on every call rather than trusted from whatever the
 * client last saw, so flipping it off takes effect on the next tap, not on the
 * next app launch.
 *
 * Anyone can be named, not just friends — an admin rebuilding a group should
 * not have to befriend everyone first — but the block and child rules below
 * are exactly the ones `friends.sendRequest` applies, because reaching someone
 * through a room invite must not be a way around them.
 */
export const invite = mutation({
  args: {
    roomId: v.id("rooms"),
    userId: v.id("users"),      // the inviter
    inviteeId: v.id("users"),
  },
  handler: async (ctx, { roomId, userId, inviteeId }) => {
    // Each invite pushes the invitee, and a declined one used to be
    // re-sendable at once. 50 a day per inviter, 3 a week per room+person.
    await consume(ctx, `invite:${userId}`, 50, 24 * 60 * 60 * 1000);
    await consume(ctx, `invitepair:${roomId}:${inviteeId}`, 3, 7 * 24 * 60 * 60 * 1000);
    const room = await assertAdministrableRoom(ctx, roomId);
    await assertMayInvite(ctx, room, userId);
    if (inviteeId.toString() === userId.toString()) {
      throw new Error(ERR_CANNOT_INVITE_SELF);
    }

    const invitee = await getLiveUser(ctx, inviteeId);
    if (!invitee) throw new Error("USER_NOT_FOUND");
    if (isSystemAccount(invitee)) throw new Error(ERR_SYSTEM_ACCOUNT);

    if (await membershipOf(ctx, roomId, inviteeId)) {
      throw new Error(ERR_ALREADY_MEMBER);
    }

    // Asymmetric exactly as `friends.sendRequest` is, and for the same reason:
    // the caller may learn about their OWN block (so the UI can offer to
    // unblock), and must never learn about the other person's.
    const iBlockedThem = await ctx.db
      .query("blocks")
      .withIndex("by_pair", (q: any) =>
        q.eq("userId", userId).eq("blockedUserId", inviteeId),
      )
      .first();
    const theyBlockedMe = await ctx.db
      .query("blocks")
      .withIndex("by_pair", (q: any) =>
        q.eq("userId", inviteeId).eq("blockedUserId", userId),
      )
      .first();
    if (iBlockedThem) throw new Error("UNBLOCK_FIRST");
    if (theyBlockedMe) throw new Error("USER_NOT_FOUND");

    const prior = (
      await ctx.db
        .query("roomInvitations")
        .withIndex("by_room_invitee", (q: any) =>
          q.eq("roomId", roomId).eq("inviteeId", inviteeId),
        )
        .collect()
    ).sort((a: any, b: any) => b.createdAt - a.createdAt);

    const pending = prior.find((r: any) => r.status === "pending");
    if (pending) throw new Error(ERR_ALREADY_INVITED);
    // A previous "no" is not permanent — the same row shape `friends` uses for
    // a denied request. Clearing it is what lets a second, better-timed ask
    // through instead of wedging the pair forever.
    for (const stale of prior) {
      if (stale.status === "rejected" || stale.status === "cancelled") {
        await ctx.db.delete(stale._id);
      }
    }

    // NOT `initialStageFor`: a contact whitelist must not silently waive the
    // question "may my child be in THIS room". See `initialStageForRoomInvite`.
    const stage = await initialStageForRoomInvite(ctx, userId, inviteeId, roomId);
    const invitationId = await ctx.db.insert("roomInvitations", {
      roomId,
      inviterId: userId,
      inviteeId,
      status: "pending",
      createdAt: Date.now(),
      ...(stage ? { stage } : {}),
    });
    await notifyHolder(ctx, stage, userId, inviteeId, room.name);
    return invitationId;
  },
});

/**
 * Whoever is actually holding this decision right now gets the push — and
 * nobody else does. While a request sits at a guardian hop the invitee is not
 * told it exists, which is the whole point of the relay: a child does not get
 * to see, and then argue about, a request their guardian is about to decline.
 */
async function notifyHolder(
  ctx: any,
  stage: string | undefined,
  inviterId: any,
  inviteeId: any,
  roomName: string,
) {
  const audience =
    stage === STAGE_SENDER_GUARDIAN
      ? await guardiansOf(ctx, inviterId)
      : stage === STAGE_RECIPIENT_GUARDIAN
        ? await guardiansOf(ctx, inviteeId)
        : [inviteeId];
  if (audience.length === 0) return;
  const inviter = await ctx.db.get(inviterId);
  const who = inviter?.name ?? inviter?.username ?? "Someone";
  await ctx.scheduler.runAfter(0, internal.notifications.sendApprovalPush, {
    userIds: audience.map((u: any) => u.toString()),
    title:
      stage === STAGE_SENDER_GUARDIAN || stage === STAGE_RECIPIENT_GUARDIAN
        ? "Needs your OK"
        : "Group invite",
    body:
      stage === STAGE_SENDER_GUARDIAN
        ? `${who} wants to invite someone to ${roomName}`
        : stage === STAGE_RECIPIENT_GUARDIAN
          ? `${who} invited your child to ${roomName}`
          : `${who} invited you to ${roomName}`,
  });
}

// ────────────────────────────── answering ──────────────────────────────

/**
 * The invitee's answer.
 *
 * Accepting is where the membership is actually created — never at invite
 * time, and never by the inviter. A child accepting still has to satisfy
 * `childMayUseRoom`; see `advance` below for why that is usually already true
 * by the time they see the invite at all.
 */
export const respond = mutation({
  args: {
    invitationId: v.id("roomInvitations"),
    userId: v.id("users"),      // the invitee
    accept: v.boolean(),
  },
  handler: async (ctx, { invitationId, userId, accept }) => {
    const row = await ctx.db.get(invitationId);
    if (!row || row.status !== "pending") throw new Error(ERR_INVITATION_NOT_FOUND);
    if (row.inviteeId.toString() !== userId.toString()) {
      throw new Error(ERR_INVITATION_NOT_FOUND);
    }
    // A child cannot release their own invite. Until a guardian advances it
    // they cannot even see the row, so reaching here means a hand-made call.
    if (!isReleasedToRecipient(row.stage)) {
      throw new Error(ERR_INVITATION_NOT_FOUND);
    }

    const now = Date.now();
    if (!accept) {
      await ctx.db.patch(invitationId, { status: "rejected", respondedAt: now });
      return { status: "rejected", roomId: row.roomId };
    }

    // The room can have been deleted, or the invitee added by another route,
    // between the invite and the answer. Neither is an error worth showing.
    const room = await ctx.db.get(row.roomId);
    // A room being deleted has its invitations swept in the first teardown
    // step; until then it is as good as gone.
    if (!room || isTombstoned(room)) {
      // Returned, not thrown: a throw rolls the delete back, and the dead
      // invitation would stay in the invitee's list forever.
      await ctx.db.delete(invitationId);
      return { status: "gone", roomId: row.roomId };
    }
    if (await membershipOf(ctx, row.roomId, userId)) {
      await ctx.db.patch(invitationId, { status: "accepted", respondedAt: now });
      return { status: "accepted", roomId: row.roomId };
    }

    // Re-checked at the moment of joining, not at invite time. A guardian can
    // revoke a room grant in between, and their revocation has to win over an
    // invite that was already in flight.
    if (await isChild(ctx, userId)) {
      if (!(await childMayUseRoom(ctx, userId, row.roomId))) {
        throw new Error(ERR_APPROVAL_REQUIRED);
      }
    }

    await ctx.db.patch(invitationId, { status: "accepted", respondedAt: now });
    await addMembership(ctx, row.roomId, userId);
    await clearPendingFor(ctx, row.roomId, userId);

    const invitee = await ctx.db.get(userId);
    await ctx.scheduler.runAfter(0, internal.notifications.sendApprovalPush, {
      userIds: [row.inviterId.toString()],
      title: "Invite accepted",
      body: `${invitee?.name ?? invitee?.username ?? "They"} joined ${room.name}`,
      // The inviter is a member and the news IS the room, so the tap opens it.
      // Without this the push fell through to the requests view — which sits
      // under Discover, and had nothing waiting on it: the invite it would
      // have shown is the one that was just answered.
      roomId: row.roomId,
    });
    return { status: "accepted", roomId: row.roomId };
  },
});

/**
 * Withdraw an invite. The inviter can take back their own; an admin can take
 * back anyone's, which is the counterpart to `membersCanInvite` — a room that
 * can stop members inviting should also be able to undo one that already went
 * out, without waiting on the invitee to answer.
 */
export const cancel = mutation({
  args: { invitationId: v.id("roomInvitations"), userId: v.id("users") },
  handler: async (ctx, { invitationId, userId }) => {
    const row = await ctx.db.get(invitationId);
    if (!row || row.status !== "pending") throw new Error(ERR_INVITATION_NOT_FOUND);
    const mine = row.inviterId.toString() === userId.toString();
    if (!mine && !isAdminRole(await roleOf(ctx, row.roomId, userId))) {
      throw new Error("NOT_AUTHORIZED");
    }
    await ctx.db.patch(invitationId, {
      status: "cancelled",
      respondedAt: Date.now(),
    });
  },
});

// ──────────────────────────── guardian relay ────────────────────────────

/**
 * A guardian releasing (or refusing) one hop of a room invite. The exact
 * counterpart of `family.advanceContactRequest`, and a guardian may only act
 * on the hop belonging to their OWN child.
 *
 * Approving the RECIPIENT's hop also writes the child a `joinRoom` grant. That
 * is the whole point of this hop: the guardian has just been shown "this room,
 * this child, yes" — making them approve the identical question a second time
 * when the child taps accept would read as the app not having listened. The
 * grant is an ordinary `approvalRequests` row, so a guardian can later revoke
 * it from the same screen as any other, and `childMayUseRoom` finds it without
 * knowing invitations exist.
 */
export const advance = mutation({
  // The caller IS the guardian — see the note on `family.advanceContactRequest`,
  // which this mutation is the exact counterpart of. Without it `guardianId`
  // stays whatever the client sent and `assertGuardian` below asks the wrong
  // question.
  identityArg: "guardianId" as const,
  args: {
    invitationId: v.id("roomInvitations"),
    guardianId: v.id("users"),
    approve: v.boolean(),
  },
  handler: async (ctx, { invitationId, guardianId, approve }) => {
    const row = await ctx.db.get(invitationId);
    if (!row || row.status !== "pending") throw new Error(ERR_INVITATION_NOT_FOUND);

    let supervisedId: any;
    if (row.stage === STAGE_SENDER_GUARDIAN) {
      supervisedId = row.inviterId;
    } else if (row.stage === STAGE_RECIPIENT_GUARDIAN) {
      supervisedId = row.inviteeId;
    } else {
      throw new Error("REQUEST_NOT_PENDING_APPROVAL");
    }
    await assertGuardian(ctx, guardianId, supervisedId);

    if (!approve) {
      await ctx.db.patch(invitationId, {
        status: "rejected",
        respondedAt: Date.now(),
      });
      return { stage: null, status: "rejected" };
    }

    // Read once, up front: approving into a room being deleted would grant
    // access to a ghost. A missing room keeps its old fallback name below.
    const room = await ctx.db.get(row.roomId);
    if (isTombstoned(room)) throw new Error("ROOM_NOT_FOUND");

    let nextStage: string;
    if (row.stage === STAGE_SENDER_GUARDIAN) {
      nextStage = (await isChild(ctx, row.inviteeId))
        ? STAGE_RECIPIENT_GUARDIAN
        : STAGE_RECIPIENT;
    } else {
      nextStage = STAGE_RECIPIENT;
    }
    await ctx.db.patch(invitationId, { stage: nextStage });

    if (row.stage === STAGE_RECIPIENT_GUARDIAN) {
      // The grant is a row about the child; one written for a child being
      // deleted would outlive the teardown that sweeps them.
      if (!(await getLiveUser(ctx, row.inviteeId))) throw new Error("USER_NOT_FOUND");
      await grantRoomAccess(ctx, row.inviteeId, row.roomId, guardianId);
    }

    const roomName = room?.name ?? "a group";
    const notify =
      nextStage === STAGE_RECIPIENT_GUARDIAN
        ? await guardiansOf(ctx, row.inviteeId)
        : [row.inviteeId];
    const inviter = await ctx.db.get(row.inviterId);
    const who = inviter?.name ?? inviter?.username ?? "Someone";
    await ctx.scheduler.runAfter(0, internal.notifications.sendApprovalPush, {
      userIds: notify.map((u: any) => u.toString()),
      title: nextStage === STAGE_RECIPIENT_GUARDIAN ? "Needs your OK" : "Group invite",
      body:
        nextStage === STAGE_RECIPIENT_GUARDIAN
          ? `${who} invited your child to ${roomName}`
          : `${who} invited you to ${roomName}`,
    });
    return { stage: nextStage, status: "pending" };
  },
});

/**
 * Record an approved `joinRoom` grant, the shape `childGuard.hasRoomGrant`
 * looks for. Idempotent: a child invited to the same room twice must not
 * accumulate grants a guardian would then have to revoke one by one.
 */
async function grantRoomAccess(
  ctx: any,
  childId: any,
  roomId: any,
  guardianId: any,
) {
  const existing = await ctx.db
    .query("approvalRequests")
    .withIndex("by_child_room", (q: any) =>
      q.eq("childId", childId).eq("targetRoomId", roomId),
    )
    .collect();
  const live = existing.find(
    (r: any) => r.kind === "joinRoom" && r.status === "approved",
  );
  if (live) return;
  const now = Date.now();
  const reusable = existing.find((r: any) => r.kind === "joinRoom");
  if (reusable) {
    await ctx.db.patch(reusable._id, {
      status: "approved",
      decidedAt: now,
      decidedByGuardianId: guardianId,
    });
    return;
  }
  await ctx.db.insert("approvalRequests", {
    childId,
    kind: "joinRoom",
    status: "approved",
    targetRoomId: roomId,
    note: "",
    createdAt: now,
    decidedAt: now,
    decidedByGuardianId: guardianId,
  });
}

// ─────────────────────────────── reads ───────────────────────────────

/**
 * "Who wants me in a group?" — the invitee's inbox.
 *
 * Rows still held at a guardian hop are filtered out, not merely hidden by the
 * client: `isReleasedToRecipient` is the same test `respond` enforces, so a
 * child cannot see an invite they also cannot answer.
 */
export const listIncoming = query({
  args: { userId: v.id("users") },
  handler: async (ctx, { userId }) => {
    const rows = await ctx.db
      .query("roomInvitations")
      .withIndex("by_invitee_status", (q: any) =>
        q.eq("inviteeId", userId).eq("status", "pending"),
      )
      .collect();
    rows.sort((a: any, b: any) => b.createdAt - a.createdAt);
    const lens = await lensFor(ctx, userId);
    const now = Date.now();
    const out = [];
    for (const r of rows) {
      if (!isReleasedToRecipient(r.stage)) continue;
      const room = await ctx.db.get(r.roomId);
      const inviter = await ctx.db.get(r.inviterId);
      if (!room || !inviter) continue;
      // Rows survive until the teardown's first step; hide them at once.
      if (isTombstoned(room) || isTombstoned(inviter)) continue;
      out.push({
        invitationId: r._id,
        createdAt: r.createdAt,
        room: {
          roomId: room._id,
          name: room.name,
          description: room.description ?? null,
          memberCount: room.memberCount,
          isPrivate: room.isPrivate,
          // Storage id, not a URL — see the note in `roomInvites.preview`.
          avatarStorageId: room.avatarStorageId ?? null,
        },
        inviter: publicUserView(lens, inviter, now),
      });
    }
    return out;
  },
});

/**
 * Invites this room has out but not yet answered — shown under the member list
 * so the roster reads as the truth about who is coming, and so an admin can
 * see a member's invite and withdraw it.
 *
 * Members-only. Rows held at a guardian hop are still listed here, because
 * from the ROOM's side the invite genuinely is outstanding; what is withheld
 * is only ever the invitee's own knowledge of it, which this query does not
 * reach.
 */
export const listForRoom = query({
  args: { roomId: v.id("rooms"), userId: v.id("users") },
  handler: async (ctx, { roomId, userId }) => {
    const role = await roleOf(ctx, roomId, userId);
    if (role === null) return [];
    const rows = (
      await ctx.db
        .query("roomInvitations")
        .withIndex("by_room_invitee", (q: any) => q.eq("roomId", roomId))
        .collect()
    ).filter((r: any) => r.status === "pending");
    rows.sort((a: any, b: any) => b.createdAt - a.createdAt);
    const lens = await lensFor(ctx, userId);
    const now = Date.now();
    const out = [];
    for (const r of rows) {
      const invitee = await ctx.db.get(r.inviteeId);
      if (!invitee) continue;
      out.push({
        invitationId: r._id,
        createdAt: r.createdAt,
        inviterId: r.inviterId,
        awaitingGuardian: !isReleasedToRecipient(r.stage),
        invitee: publicUserView(lens, invitee, now),
        canCancel:
          isAdminRole(role) || r.inviterId.toString() === userId.toString(),
      });
    }
    return out;
  },
});

/**
 * The friend picker's list: this caller's accepted friends, minus everyone
 * already in the room and everyone already invited to it.
 *
 * Filtered server-side rather than in the client because the client would need
 * the full member roster to do it, and a member of a room you are not in is
 * not something to hand out just to grey out a row.
 */
export const invitableFriends = query({
  args: { roomId: v.id("rooms"), userId: v.id("users") },
  handler: async (ctx, { roomId, userId }) => {
    const role = await roleOf(ctx, roomId, userId);
    if (role === null) return [];

    const members = await ctx.db
      .query("roomMembers")
      .withIndex("by_room_user", (q: any) => q.eq("roomId", roomId))
      .collect();
    const taken = new Set(members.map((m: any) => m.userId.toString()));

    const invited = await ctx.db
      .query("roomInvitations")
      .withIndex("by_room_invitee", (q: any) => q.eq("roomId", roomId))
      .collect();
    for (const inv of invited) {
      if (inv.status === "pending") taken.add(inv.inviteeId.toString());
    }

    const friendships = await ctx.db
      .query("friendships")
      .withIndex("by_user", (q: any) => q.eq("userId", userId))
      .collect();
    const lens = await lensFor(ctx, userId);
    const now = Date.now();
    const out = [];
    for (const f of friendships) {
      if (f.status !== "accepted") continue;
      if (taken.has(f.friendId.toString())) continue;
      const friend = await ctx.db.get(f.friendId);
      if (!friend || isSystemAccount(friend) || isTombstoned(friend)) continue;
      out.push(publicUserView(lens, friend, now));
    }
    return out;
  },
});
