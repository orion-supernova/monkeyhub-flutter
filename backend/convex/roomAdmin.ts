/**
 * Who may do what in a room, in one place.
 *
 * Before this file, "authorization" in `rooms.ts` meant comparing
 * `rooms.createdBy` to the caller. That has two problems and they compound:
 * a group could never have more than one privileged person, and the
 * `roomMembers.role` column that looked like the answer was never actually
 * read. Anyone auditing the code found a role field and reasonably assumed it
 * meant something.
 *
 * The rule now: `roomMembers.role` is the authority, always, and it is read
 * through the helpers below rather than compared inline — so "is this person
 * an admin" has exactly one definition and adding a tier later is one edit.
 * `rooms.createdBy` keeps its honest, non-load-bearing meaning: who opened the
 * room. It is never consulted for permission again.
 *
 *   owner  — one per room. Everything an admin can do, plus: delete the room,
 *            transfer ownership, and demote admins. Cannot be demoted or
 *            removed by anyone; the only ways out are transferring first, or
 *            leaving (which hands the room to the longest-standing member the
 *            same way account deletion does).
 *   admin  — invite, issue and rotate the link, rule on join requests, remove
 *            members, edit the room, and promote other members to admin.
 *            Flat powers: every admin can do the same things, so the UI never
 *            has to explain why one admin's buttons differ from another's.
 *   member — read, write, leave, and (unless an admin turned it off) invite
 *            their own friends.
 *
 * Plain helpers plus the small set of mutations that change a role. The invite
 * machinery lives in `roomInvites.ts` and calls in here for its checks.
 */

import { mutation, query } from "./functions";
import { internal } from "./_generated/api";
import { v } from "convex/values";
import { assertNotSystemRoom } from "./systemAccount";
import { seenVisibilityOf } from "./visibility";
import { wipeRoomCompletely } from "./roomCleanup";
import { purgeSpeakerColorsForMember } from "./speakerColors";

export const ROLE_OWNER = "owner";
export const ROLE_ADMIN = "admin";
export const ROLE_MEMBER = "member";

export const ERR_NOT_MEMBER = "NOT_A_MEMBER";
export const ERR_NOT_ADMIN = "NOT_ADMIN";
export const ERR_NOT_OWNER = "NOT_OWNER";
export const ERR_ROOM_NOT_FOUND = "ROOM_NOT_FOUND";
/** Admin roles are a group concept; a two-person DM has no such thing. */
export const ERR_NOT_A_GROUP = "NOT_A_GROUP";
export const ERR_OWNER_IMMUTABLE = "OWNER_IMMUTABLE";
export const ERR_INVITES_LOCKED = "INVITES_ADMINS_ONLY";
/** "Use the door." `rooms.leave` is the same teardown plus the intent. */
export const ERR_CANNOT_REMOVE_SELF = "CANNOT_REMOVE_SELF";

/** Link-redemption policies. See `rooms.linkJoinPolicy`. */
export const JOIN_OPEN = "open";
export const JOIN_APPROVAL = "approval";

// ─────────────────────────────── reads ───────────────────────────────

export async function membershipOf(ctx: any, roomId: any, userId: any) {
  return await ctx.db
    .query("roomMembers")
    .withIndex("by_room_user", (q: any) =>
      q.eq("roomId", roomId).eq("userId", userId),
    )
    .first();
}

/** The caller's role, or null if they are not in the room at all. */
export async function roleOf(
  ctx: any,
  roomId: any,
  userId: any,
): Promise<string | null> {
  const m = await membershipOf(ctx, roomId, userId);
  return m ? (m.role ?? ROLE_MEMBER) : null;
}

/**
 * Owner counts as admin everywhere. Every "can they do the admin thing"
 * question goes through this rather than `role === "admin"`, which would
 * silently exclude the owner from their own room's controls.
 */
export function isAdminRole(role: string | null | undefined): boolean {
  return role === ROLE_OWNER || role === ROLE_ADMIN;
}

/**
 * A DM's `name` is the internal `dm:regular:<id>:<id>` / `dm:self:<id>` key,
 * never a real title — the same test `rooms.getMemberIds` and the client's
 * `ChatRoom.isDm` use. There is no `isGroup` column to drift out of sync.
 */
export function isGroupRoom(room: any): boolean {
  return !!room && !room.name.startsWith("dm:");
}

/** Defaults to true: rooms created before the flag existed stay as they were. */
export function membersMayInvite(room: any): boolean {
  return room?.membersCanInvite ?? true;
}

/** Defaults to "open": holding the link is the whole test unless told otherwise. */
export function linkJoinPolicyOf(room: any): string {
  return room?.linkJoinPolicy === JOIN_APPROVAL ? JOIN_APPROVAL : JOIN_OPEN;
}

// ──────────────────────────── assertions ────────────────────────────

/** Loads the room or throws. Every mutation below starts here. */
export async function getRoomOrThrow(ctx: any, roomId: any) {
  const room = await ctx.db.get(roomId);
  if (!room) throw new Error(ERR_ROOM_NOT_FOUND);
  return room;
}

export async function assertMember(ctx: any, roomId: any, userId: any) {
  const role = await roleOf(ctx, roomId, userId);
  if (role === null) throw new Error(ERR_NOT_MEMBER);
  return role;
}

export async function assertAdmin(ctx: any, roomId: any, userId: any) {
  const role = await roleOf(ctx, roomId, userId);
  if (role === null) throw new Error(ERR_NOT_MEMBER);
  if (!isAdminRole(role)) throw new Error(ERR_NOT_ADMIN);
  return role;
}

export async function assertOwner(ctx: any, roomId: any, userId: any) {
  const role = await roleOf(ctx, roomId, userId);
  if (role === null) throw new Error(ERR_NOT_MEMBER);
  if (role !== ROLE_OWNER) throw new Error(ERR_NOT_OWNER);
  return role;
}

/**
 * The gate every invite path shares: link issuance, direct invites, and ruling
 * on join requests all funnel through one of the two calls below so the
 * "members can invite" switch can never be enforced in one place and forgotten
 * in another.
 *
 * Admins always pass. A member passes only while `membersCanInvite` is on.
 */
export async function assertMayInvite(ctx: any, room: any, userId: any) {
  const role = await roleOf(ctx, room._id, userId);
  if (role === null) throw new Error(ERR_NOT_MEMBER);
  if (isAdminRole(role)) return role;
  if (!membersMayInvite(room)) throw new Error(ERR_INVITES_LOCKED);
  return role;
}

/**
 * Room-shape guard for every administrative action. A system room's roster is
 * the app's business (`assertNotSystemRoom`), and a DM has no roles to hand
 * out — promoting someone in a two-person chat is meaningless, and letting a
 * "remove member" land there would silently turn a delete-for-both into a
 * delete-for-one.
 */
export async function assertAdministrableRoom(ctx: any, roomId: any) {
  await assertNotSystemRoom(ctx, roomId);
  const room = await getRoomOrThrow(ctx, roomId);
  if (!isGroupRoom(room)) throw new Error(ERR_NOT_A_GROUP);
  return room;
}

// ────────────────────────── membership writes ──────────────────────────

/**
 * Insert a membership, idempotently, and keep `memberCount` honest.
 *
 * Every path that admits someone — `rooms.join`, accepting a direct invite,
 * an admin approving a join request, redeeming an open link — ends here, so
 * the denormalized count and the `seenVisibility` stamp cannot be right on one
 * path and missing on another. Returns whether a row was actually inserted, so
 * callers can skip the "X joined" side effects for a no-op re-join.
 *
 * Deliberately does NOT check child policy or room password: those are
 * caller-specific questions (a guardian-approved invite is not the same act as
 * typing a password) and each entry point answers them before calling in.
 */
export async function addMembership(
  ctx: any,
  roomId: any,
  userId: any,
  role: string = ROLE_MEMBER,
): Promise<boolean> {
  const existing = await membershipOf(ctx, roomId, userId);
  if (existing) return false;
  await ctx.db.insert("roomMembers", {
    roomId,
    userId,
    joinedAt: Date.now(),
    role,
    seenVisibility: await seenVisibilityOf(ctx, userId),
  });
  const room = await ctx.db.get(roomId);
  if (room) await ctx.db.patch(roomId, { memberCount: room.memberCount + 1 });
  return true;
}

/**
 * Remove a membership and everything that hangs off it.
 *
 * Shared by `rooms.leave` and `roomAdmin.removeMember` because walking out and
 * being shown the door leave exactly the same debris, and the sweep below is
 * easy to get subtly wrong twice. See `rooms.leave` for why bookmarks go and
 * pins stay, and why the view-once recount is deferred.
 *
 * Returns "wiped" when that was the last member and the room itself is gone,
 * so callers know not to touch it again.
 */
export async function removeMembership(
  ctx: any,
  roomId: any,
  userId: any,
): Promise<"removed" | "absent" | "wiped"> {
  const member = await membershipOf(ctx, roomId, userId);
  if (!member) return "absent";

  await ctx.db.delete(member._id);

  const bookmarks = await ctx.db
    .query("messageBookmarks")
    .withIndex("by_room_user_message", (q: any) =>
      q.eq("roomId", roomId).eq("userId", userId),
    )
    .collect();
  for (const b of bookmarks) await ctx.db.delete(b._id);

  // Their manual speaker colours, and — the half that is easy to miss —
  // everyone ELSE's pins on them. See `purgeSpeakerColorsForMember`: a pin left
  // behind names somebody who is no longer here and holds a palette slot shut
  // against whoever joins next.
  await purgeSpeakerColorsForMember(ctx, roomId, userId);

  // Anything still outstanding for this person in this room is moot now, and
  // leaving it would let a stale row re-admit someone an admin just removed.
  await clearPendingFor(ctx, roomId, userId);

  const room = await ctx.db.get(roomId);
  if (room && room.memberCount > 0) {
    await ctx.db.patch(roomId, { memberCount: room.memberCount - 1 });
  }

  const remaining = await ctx.db
    .query("roomMembers")
    .withIndex("by_room_user", (q: any) => q.eq("roomId", roomId))
    .collect();
  if (remaining.length === 0) {
    await wipeRoomCompletely(ctx, roomId);
    return "wiped";
  }

  // The room outlives them, so the owner seat must not leave with them.
  await ensureOwner(ctx, roomId, remaining);

  await ctx.scheduler.runAfter(
    0,
    internal.messages.recountViewOnceRecipients,
    { roomId },
  );
  return "removed";
}

/**
 * Drop this person's outstanding invitation and join request for this room.
 *
 * Called when they leave, when they are removed, and when they are admitted —
 * in every one of those cases the question the row asks has been overtaken by
 * events, and a "pending" row that outlives its own answer is how someone ends
 * up rejoining a room they were kicked from by tapping an old notification.
 */
export async function clearPendingFor(ctx: any, roomId: any, userId: any) {
  const invitations = await ctx.db
    .query("roomInvitations")
    .withIndex("by_room_invitee", (q: any) =>
      q.eq("roomId", roomId).eq("inviteeId", userId),
    )
    .collect();
  for (const row of invitations) {
    if (row.status === "pending") await ctx.db.delete(row._id);
  }
  const requests = await ctx.db
    .query("roomJoinRequests")
    .withIndex("by_room_user", (q: any) =>
      q.eq("roomId", roomId).eq("userId", userId),
    )
    .collect();
  for (const row of requests) {
    if (row.status === "pending") await ctx.db.delete(row._id);
  }
}

/**
 * Guarantee the room still has exactly one owner.
 *
 * A room with no owner is not merely untidy — nobody can delete it, transfer
 * it, or demote a rogue admin, and there is no admin surface anywhere that can
 * repair that. The heir is the longest-standing ADMIN if there is one, else
 * the longest-standing member, which is the same rule `auth.purgeUser` applies
 * when an owner deletes their account, extended to prefer people who were
 * already trusted.
 *
 * `rooms.createdBy` is dragged along so it keeps describing someone who is
 * actually still here. It grants nothing either way.
 */
export async function ensureOwner(ctx: any, roomId: any, members?: any[]) {
  const rows =
    members ??
    (await ctx.db
      .query("roomMembers")
      .withIndex("by_room_user", (q: any) => q.eq("roomId", roomId))
      .collect());
  if (rows.length === 0) return;
  if (rows.some((m: any) => m.role === ROLE_OWNER)) return;

  const admins = rows.filter((m: any) => m.role === ROLE_ADMIN);
  const pool = admins.length > 0 ? admins : rows;
  const heir = pool.reduce((a: any, b: any) =>
    (a.joinedAt ?? 0) <= (b.joinedAt ?? 0) ? a : b,
  );
  await ctx.db.patch(heir._id, { role: ROLE_OWNER });
  await ctx.db.patch(roomId, { createdBy: heir.userId });
}

// ─────────────────────────────── mutations ───────────────────────────────

/**
 * Promote a member to admin, or an admin back to member.
 *
 * One mutation rather than two, because the two directions share every check
 * and differ only in the value written — and because the client's row action
 * is a single toggle. `makeAdmin: false` on someone who is already a plain
 * member is a no-op rather than an error, so a double-tap on a slow connection
 * cannot fail.
 *
 * An admin may promote a member and may demote another admin. Neither may
 * touch the owner: `ERR_OWNER_IMMUTABLE` is the one refusal here that is not
 * about the caller's rank.
 */
export const setAdmin = mutation({
  args: {
    roomId: v.id("rooms"),
    userId: v.id("users"),      // the caller
    targetUserId: v.id("users"),
    makeAdmin: v.boolean(),
  },
  handler: async (ctx, { roomId, userId, targetUserId, makeAdmin }) => {
    await assertAdministrableRoom(ctx, roomId);
    await assertAdmin(ctx, roomId, userId);

    const target = await membershipOf(ctx, roomId, targetUserId);
    if (!target) throw new Error(ERR_NOT_MEMBER);
    // The owner's seat changes hands through `transferOwnership` and nowhere
    // else. Without this an admin could demote the owner and take the room.
    if (target.role === ROLE_OWNER) throw new Error(ERR_OWNER_IMMUTABLE);

    const next = makeAdmin ? ROLE_ADMIN : ROLE_MEMBER;
    if ((target.role ?? ROLE_MEMBER) === next) return;
    await ctx.db.patch(target._id, { role: next });

    // Only the promotion is announced. Being quietly demoted is not something
    // to push a banner about — the room's controls simply stop appearing.
    if (makeAdmin) {
      const room = await ctx.db.get(roomId);
      await ctx.scheduler.runAfter(0, internal.notifications.sendApprovalPush, {
        userIds: [targetUserId.toString()],
        title: "You're an admin",
        body: `You can now manage ${room?.name ?? "the group"}`,
      });
    }
  },
});

/**
 * Hand the room to another member. Owner-only, and atomic in the sense that
 * matters: the old owner is demoted in the same mutation that promotes the
 * new one, so the "exactly one owner" invariant is never observably broken.
 *
 * The outgoing owner becomes an ADMIN, not a member. Someone giving a group
 * away is almost never asking to also give up the ability to help run it, and
 * a room that punished the transfer that way would just never see one.
 */
export const transferOwnership = mutation({
  args: {
    roomId: v.id("rooms"),
    userId: v.id("users"),      // current owner
    targetUserId: v.id("users"),
  },
  handler: async (ctx, { roomId, userId, targetUserId }) => {
    await assertAdministrableRoom(ctx, roomId);
    await assertOwner(ctx, roomId, userId);
    if (targetUserId.toString() === userId.toString()) return;

    const target = await membershipOf(ctx, roomId, targetUserId);
    if (!target) throw new Error(ERR_NOT_MEMBER);
    const self = await membershipOf(ctx, roomId, userId);

    await ctx.db.patch(target._id, { role: ROLE_OWNER });
    if (self) await ctx.db.patch(self._id, { role: ROLE_ADMIN });
    // Keeps the honest "who runs this" record pointing somewhere useful. Still
    // grants nothing — the membership row above is what was just changed.
    await ctx.db.patch(roomId, { createdBy: targetUserId });

    const room = await ctx.db.get(roomId);
    await ctx.scheduler.runAfter(0, internal.notifications.sendApprovalPush, {
      userIds: [targetUserId.toString()],
      title: "You own this group",
      body: `${room?.name ?? "A group"} was handed to you`,
    });
  },
});

/**
 * Remove someone from the room.
 *
 * Admins can remove members. Admins cannot remove other admins — that would
 * make every promotion a coin flip over who clicks first — so an admin must be
 * demoted (by the owner, or by another admin via `setAdmin`) before they can
 * be removed. The owner can remove anyone but themselves; leaving is the door
 * they use, and it hands the room on properly.
 */
export const removeMember = mutation({
  args: {
    roomId: v.id("rooms"),
    userId: v.id("users"),      // the caller
    targetUserId: v.id("users"),
  },
  handler: async (ctx, { roomId, userId, targetUserId }) => {
    await assertAdministrableRoom(ctx, roomId);
    const callerRole = await assertAdmin(ctx, roomId, userId);
    if (targetUserId.toString() === userId.toString()) {
      // Not a kick. `rooms.leave` is the same teardown plus the intent — and
      // it re-seats the owner on the way out, which this path does not.
      throw new Error(ERR_CANNOT_REMOVE_SELF);
    }

    const target = await membershipOf(ctx, roomId, targetUserId);
    if (!target) return;
    if (target.role === ROLE_OWNER) throw new Error(ERR_OWNER_IMMUTABLE);
    if (target.role === ROLE_ADMIN && callerRole !== ROLE_OWNER) {
      throw new Error(ERR_NOT_OWNER);
    }

    await removeMembership(ctx, roomId, targetUserId);
  },
});

/**
 * The room's two administrative switches, set together because they live in
 * one section of one sheet and a partial save would be a lie about what the
 * user just saw.
 *
 * Admin-only even though `membersCanInvite` governs members: a switch a member
 * could flip back is not a control.
 */
export const setRoomPolicy = mutation({
  args: {
    roomId: v.id("rooms"),
    userId: v.id("users"),
    membersCanInvite: v.optional(v.boolean()),
    linkJoinPolicy: v.optional(v.string()), // "open" | "approval"
  },
  handler: async (ctx, { roomId, userId, membersCanInvite, linkJoinPolicy }) => {
    await assertAdministrableRoom(ctx, roomId);
    await assertAdmin(ctx, roomId, userId);
    if (
      linkJoinPolicy !== undefined &&
      linkJoinPolicy !== JOIN_OPEN &&
      linkJoinPolicy !== JOIN_APPROVAL
    ) {
      throw new Error("INVALID_JOIN_POLICY");
    }
    await ctx.db.patch(roomId, {
      ...(membersCanInvite !== undefined ? { membersCanInvite } : {}),
      ...(linkJoinPolicy !== undefined ? { linkJoinPolicy } : {}),
    });
  },
});

/**
 * Everything the client needs to decide which controls to draw, in one read.
 *
 * Returned for any member; `null` for anyone else, which the client reads as
 * "you are not in this room" rather than as an error — the room info screen is
 * reachable for a beat after being removed, and a thrown error there would
 * surface as a failure the user did nothing to cause.
 *
 * The client MUST NOT treat this as the enforcement point. Every mutation
 * re-checks; this only stops us drawing buttons that would refuse.
 */
export const myPermissions = query({
  args: { roomId: v.id("rooms"), userId: v.optional(v.id("users")) },
  handler: async (ctx, { roomId, userId }) => {
    if (!userId) return null;
    const room = await ctx.db.get(roomId);
    if (!room) return null;
    const role = await roleOf(ctx, roomId, userId);
    if (role === null) return null;

    const group = isGroupRoom(room) && !room.system;
    const admin = group && isAdminRole(role);
    return {
      role,
      isGroup: group,
      isOwner: group && role === ROLE_OWNER,
      isAdmin: admin,
      canEditRoom: admin,
      canRemoveMembers: admin,
      canAssignAdmins: admin,
      canManageLink: admin,
      canReviewJoinRequests: admin,
      canInvite: group && (admin || membersMayInvite(room)),
      membersCanInvite: membersMayInvite(room),
      linkJoinPolicy: linkJoinPolicyOf(room),
    };
  },
});
