/**
 * The room's join link, and the join requests it can produce.
 *
 * ONE token per room, rendered two ways. `https://<site>/j/MUZU4KUP7V` and
 * typing `MUZU-4KUP-7V` into the join box are the same act on the same secret
 * — there is no separate "invite code" concept to keep in sync, no second
 * thing to revoke, and no way for the two to disagree about who is allowed in.
 *
 * Rotation IS revocation. Issuing a new link stamps `revokedAt` on the old row
 * in the same mutation, which is what makes "regenerate" a real security
 * action rather than a cosmetic one: the moment an admin taps it, every copy
 * of the old link that has been forwarded, screenshotted, or pasted into a
 * group somewhere stops working. Old rows are kept rather than deleted so a
 * stale link can answer INVITE_REVOKED — "this link is no longer valid" — and
 * not the indistinguishable "no such link", which reads like a typo and sends
 * people back to ask for it again.
 *
 * What redemption DOES depends on the room, not on the link: see
 * `rooms.linkJoinPolicy`. Under "open" the holder joins; under "approval" they
 * get a `roomJoinRequests` row and an admin decides. The link is identical
 * either way, so an admin can tighten a room without reissuing anything.
 */

import { mutation, query } from "./functions";
import { internal } from "./_generated/api";
import { v } from "convex/values";
import {
  ERR_APPROVAL_REQUIRED,
  childMayUseRoom,
  isChild,
} from "./childGuard";
import { lensFor, publicUserView } from "./visibility";
import { isTombstoned } from "./deletionCore";
import {
  JOIN_APPROVAL,
  addMembership,
  assertAdmin,
  assertAdministrableRoom,
  clearPendingFor,
  getRoomOrThrow,
  isAdminRole,
  linkJoinPolicyOf,
  membershipOf,
  roleOf,
  assertNotRemoved,
} from "./roomAdmin";

/**
 * Crockford base32: no I, L, O or U. The first three because this code gets
 * read off a screen and retyped — `1/I/l` and `0/O` are the two mistakes
 * everyone makes — and U because excluding it is what keeps a random ten
 * characters from occasionally spelling something an admin has to apologize
 * for. `normalize` below folds the confusable characters back in, so someone
 * who types the letter O where the code has a zero still gets in.
 */
const ALPHABET = "0123456789ABCDEFGHJKMNPQRSTVWXYZ";

/** 10 characters over a 32-symbol alphabet = 50 bits. Not guessable. */
const CODE_LENGTH = 10;

export const ERR_INVITE_NOT_FOUND = "INVITE_NOT_FOUND";
export const ERR_INVITE_REVOKED = "INVITE_REVOKED";
export const ERR_INVITE_EXPIRED = "INVITE_EXPIRED";
export const ERR_INVITE_EXHAUSTED = "INVITE_EXHAUSTED";
export const ERR_ALREADY_MEMBER = "ALREADY_MEMBER";
export const ERR_REQUEST_PENDING = "JOIN_REQUEST_PENDING";
export const ERR_REQUEST_NOT_FOUND = "JOIN_REQUEST_NOT_FOUND";

/**
 * Ceiling on an admin-set expiry. Not a security control — an admin who wants
 * a permanent link simply leaves expiry off — but a year is the point past
 * which "expires" stops meaning anything and the field is better left unset.
 */
const MAX_EXPIRY_MS = 365 * 24 * 60 * 60 * 1000;

// ─────────────────────────────── the code ───────────────────────────────

function mintCode(): string {
  const bytes = new Uint8Array(CODE_LENGTH);
  crypto.getRandomValues(bytes);
  // Modulo bias over a 32-symbol alphabet and a 256-value byte is exactly
  // zero — 256 is a whole multiple of 32 — so the cheap mapping is also the
  // correct one here. That stops being true if ALPHABET ever changes length.
  let out = "";
  for (const b of bytes) out += ALPHABET[b % ALPHABET.length];
  return out;
}

/**
 * Fold whatever the human typed into the stored form: uppercase, dashes and
 * spaces dropped, and the four confusable letters mapped to the digits they
 * are always mistaken for. U is NOT folded to V: U never appears in a minted
 * code, so leaving it alone makes a typo'd U fail cleanly, where mapping it
 * could land on a different room's live code. A code is stored exactly as
 * minted and never re-normalized, so this only ever has to be right about
 * INPUT.
 */
export function normalizeCode(raw: string): string {
  return raw
    .trim()
    .toUpperCase()
    .replace(/[^0-9A-Z]/g, "")
    .replace(/[IL]/g, "1")
    .replace(/O/g, "0");
}

/** The grouped form the UI shows and a person reads aloud: `MUZU-4KUP-7V`. */
export function formatCode(code: string): string {
  return (code.match(/.{1,4}/g) ?? [code]).join("-");
}

/**
 * Why a link cannot be used right now, or null if it can.
 *
 * A pure function of the row and the clock so the preview screen and the
 * redemption mutation cannot disagree about whether a link is alive — the one
 * bug that would let someone tap a link labelled "join" and get an error.
 */
function invalidReason(invite: any, now: number): string | null {
  if (!invite) return ERR_INVITE_NOT_FOUND;
  if (invite.revokedAt) return ERR_INVITE_REVOKED;
  if (invite.expiresAt !== undefined && invite.expiresAt <= now) {
    return ERR_INVITE_EXPIRED;
  }
  if (invite.maxUses !== undefined && (invite.useCount ?? 0) >= invite.maxUses) {
    return ERR_INVITE_EXHAUSTED;
  }
  return null;
}

/** The room's one live link, or null. */
async function activeInviteFor(ctx: any, roomId: any) {
  const rows = await ctx.db
    .query("roomInvites")
    .withIndex("by_room", (q: any) => q.eq("roomId", roomId))
    .collect();
  // Newest first: rotation guarantees at most one un-revoked row, but reading
  // in this order means a half-applied rotation (a crash between the two
  // writes) resolves to the NEW link rather than resurrecting the old one.
  rows.sort((a: any, b: any) => b.createdAt - a.createdAt);
  return rows.find((r: any) => !r.revokedAt) ?? null;
}

function publicInviteView(invite: any) {
  if (!invite) return null;
  return {
    inviteId: invite._id,
    code: invite.code,
    formattedCode: formatCode(invite.code),
    createdAt: invite.createdAt,
    createdBy: invite.createdBy,
    expiresAt: invite.expiresAt ?? null,
    maxUses: invite.maxUses ?? null,
    useCount: invite.useCount ?? 0,
    // Resolved server-side rather than left to the client's clock, which is
    // the one thing in this system that can be wrong by hours.
    invalidReason: invalidReason(invite, Date.now()),
  };
}

// ─────────────────────────── admin: the link ───────────────────────────

/**
 * The room's current link, for the admin sheet. Admin-only — a member who
 * could read the code could hand out joins the `membersCanInvite` switch was
 * specifically flipped to stop.
 *
 * Returns null when no link has ever been issued. Issuing is an explicit act
 * (`rotate`), never a side effect of looking: a room that has no link should
 * not grow one because an admin opened a settings screen.
 */
export const getLink = query({
  args: { roomId: v.id("rooms"), userId: v.id("users") },
  handler: async (ctx, { roomId, userId }) => {
    const role = await roleOf(ctx, roomId, userId);
    if (!isAdminRole(role)) return null;
    return publicInviteView(await activeInviteFor(ctx, roomId));
  },
});

/**
 * Issue a link, replacing any existing one.
 *
 * The same mutation for "create" and "regenerate", because they are the same
 * act and splitting them would let the two drift on the revocation step. The
 * outgoing row is stamped `revokedAt` BEFORE the replacement is inserted, so
 * there is no instant at which two live links exist.
 *
 * [expiresInMs] and [maxUses] are the optional limits from the admin sheet.
 * Omitting either means no limit, which is what an admin who never opens the
 * sheet gets. `expiresAt` is computed here, from the server's clock, rather
 * than accepted as an absolute instant — a client with a skewed clock must not
 * be able to mint a link that is already dead or effectively permanent.
 */
export const rotate = mutation({
  args: {
    roomId: v.id("rooms"),
    userId: v.id("users"),
    expiresInMs: v.optional(v.number()),
    maxUses: v.optional(v.number()),
  },
  handler: async (ctx, { roomId, userId, expiresInMs, maxUses }) => {
    await assertAdministrableRoom(ctx, roomId);
    await assertAdmin(ctx, roomId, userId);

    const now = Date.now();
    const current = await activeInviteFor(ctx, roomId);
    if (current) await ctx.db.patch(current._id, { revokedAt: now });

    if (expiresInMs !== undefined && (expiresInMs <= 0 || expiresInMs > MAX_EXPIRY_MS)) {
      throw new Error("INVALID_EXPIRY");
    }
    if (maxUses !== undefined && (!Number.isInteger(maxUses) || maxUses < 1)) {
      throw new Error("INVALID_MAX_USES");
    }

    // A collision at 50 bits is not something to plan a retry loop around, but
    // a code that silently shadowed another room's would be unrecoverable, so
    // it is checked rather than assumed. Bounded: if this ever fails twice the
    // randomness is broken and a third draw will not help.
    let code = mintCode();
    for (let attempt = 0; attempt < 3; attempt++) {
      const clash = await ctx.db
        .query("roomInvites")
        .withIndex("by_code", (q: any) => q.eq("code", code))
        .first();
      if (!clash) break;
      code = mintCode();
    }

    const inviteId = await ctx.db.insert("roomInvites", {
      roomId,
      code,
      createdBy: userId,
      createdAt: now,
      useCount: 0,
      ...(expiresInMs !== undefined ? { expiresAt: now + expiresInMs } : {}),
      ...(maxUses !== undefined ? { maxUses } : {}),
    });
    return publicInviteView(await ctx.db.get(inviteId));
  },
});

/**
 * Kill the link without issuing a replacement — the room becomes unreachable
 * by link until an admin makes a new one. Distinct from `rotate` because
 * "nobody else gets in" and "here is a different door" are different
 * decisions, and an admin reaching for the first should not be handed the
 * second along with a fresh code to accidentally share.
 */
export const revoke = mutation({
  args: { roomId: v.id("rooms"), userId: v.id("users") },
  handler: async (ctx, { roomId, userId }) => {
    await assertAdministrableRoom(ctx, roomId);
    await assertAdmin(ctx, roomId, userId);
    const current = await activeInviteFor(ctx, roomId);
    if (current) await ctx.db.patch(current._id, { revokedAt: Date.now() });
  },
});

// ─────────────────────────── redeeming a link ───────────────────────────

/**
 * What is behind this code, for the confirmation screen — WITHOUT joining.
 *
 * Deliberately answers for private rooms too. The caller already holds the
 * secret; showing them the name and member count of the room they are about
 * to join is not the leak, it is the entire point of a confirmation step. What
 * it never returns is anything from INSIDE the room: no messages, no roster,
 * no member identities.
 *
 * Never throws. A dead or mistyped code comes back as `{ status: "..." }` with
 * no room, because this is the first screen someone sees after tapping a link
 * and an exception there surfaces as a crash-shaped failure for something as
 * ordinary as a typo.
 */
/**
 * Where one child stands with one room: may they already use it, have they
 * asked and not been answered yet, or has nobody heard of it. The three states
 * the join screen has to tell apart to stay honest about what its button does.
 *
 * Not derivable on the client. `family.listMyApprovals` lists PENDING requests
 * only, so it cannot distinguish "approved" from "never asked" — and those are
 * the two states whose buttons differ most.
 */
async function childGateFor(ctx: any, childId: any, roomId: any) {
  if (await childMayUseRoom(ctx, childId, roomId)) return "granted";
  const rows = await ctx.db
    .query("approvalRequests")
    .withIndex("by_child_room", (q: any) =>
      q.eq("childId", childId).eq("targetRoomId", roomId),
    )
    .collect();
  const asked = rows.some(
    (r: any) => r.kind === "joinRoom" && r.status === "pending",
  );
  return asked ? "asked" : "needed";
}

export const preview = query({
  args: { code: v.string(), userId: v.optional(v.id("users")) },
  handler: async (ctx, { code, userId }) => {
    const normalized = normalizeCode(code);
    if (normalized.length !== CODE_LENGTH) {
      return { status: ERR_INVITE_NOT_FOUND, room: null };
    }
    const invite = await ctx.db
      .query("roomInvites")
      .withIndex("by_code", (q: any) => q.eq("code", normalized))
      .first();
    const reason = invalidReason(invite, Date.now());
    if (reason) return { status: reason, room: null };

    const room = await ctx.db.get(invite!.roomId);
    // A room being deleted still has its invites until the first teardown step.
    if (!room || isTombstoned(room)) {
      return { status: ERR_INVITE_NOT_FOUND, room: null };
    }

    const membership = userId
      ? await membershipOf(ctx, room._id, userId)
      : null;
    const pending = userId
      ? (
          await ctx.db
            .query("roomJoinRequests")
            .withIndex("by_room_user", (q: any) =>
              q.eq("roomId", room._id).eq("userId", userId),
            )
            .collect()
        ).find((r: any) => r.status === "pending")
      : null;

    // Answered here rather than guessed at by the client: a child must not be
    // shown a JOIN button `redeem` is certain to refuse, and once a guardian
    // has said yes the same button has to start working. Null for everyone
    // else, so an adult — or a signed-out visitor — pays no extra reads.
    const childGate =
      userId && !membership && (await isChild(ctx, userId))
        ? await childGateFor(ctx, userId, room._id)
        : null;

    return {
      status: membership
        ? ERR_ALREADY_MEMBER
        : pending
          ? ERR_REQUEST_PENDING
          : "ok",
      // About the VIEWER, not the room, so it sits beside `status` rather than
      // inside the room payload everyone gets the same copy of.
      childGate,
      room: {
        roomId: room._id,
        name: room.name,
        description: room.description ?? null,
        memberCount: room.memberCount,
        isPrivate: room.isPrivate,
        // The storage id, NOT a resolved URL: the client renders room and user
        // images through `RemoteImage`, which caches bytes on disk across
        // launches and decodes to the painted size. Handing it a URL here
        // would opt this one screen out of both. `files:getFileUrl` takes no
        // identity, so this still resolves for a signed-out visitor who just
        // tapped an invite link.
        avatarStorageId: room.avatarStorageId ?? null,
        // Lets the confirmation button say "Request to join" instead of
        // "Join" before the user commits, rather than after.
        joinPolicy: linkJoinPolicyOf(room),
      },
    };
  },
});

/**
 * Use the code. Joins, or files a request, depending on the room's policy.
 *
 * Returns a status rather than throwing for the outcomes that are not errors —
 * already a member, request already pending — because both are things a person
 * reaches by tapping the same link twice, and neither is a failure. Genuine
 * refusals (dead link, child needs a guardian) still throw, so the client's
 * error mapping stays the single place those are worded.
 */
export const redeem = mutation({
  args: { code: v.string(), userId: v.id("users") },
  handler: async (ctx, { code, userId }) => {
    const normalized = normalizeCode(code);
    const invite = await ctx.db
      .query("roomInvites")
      .withIndex("by_code", (q: any) => q.eq("code", normalized))
      .first();
    const reason = invalidReason(invite, Date.now());
    if (reason) throw new Error(reason);

    const roomId = invite!.roomId;
    const room = await getRoomOrThrow(ctx, roomId);

    const existing = await membershipOf(ctx, roomId, userId);
    if (existing) return { status: "already", roomId };

    // Same gate `rooms.join` applies, and for the same reason: a link is not a
    // way around a guardian. `childMayUseRoom` already waves through a
    // family-only room, so a parent sharing the family group's link with their
    // own kid does not need an approval round-trip.
    if (await isChild(ctx, userId)) {
      if (!(await childMayUseRoom(ctx, userId, roomId))) {
        throw new Error(ERR_APPROVAL_REQUIRED);
      }
    }

    const now = Date.now();

    if (linkJoinPolicyOf(room) === JOIN_APPROVAL) {
      const prior = (
        await ctx.db
          .query("roomJoinRequests")
          .withIndex("by_room_user", (q: any) =>
            q.eq("roomId", roomId).eq("userId", userId),
          )
          .collect()
      ).find((r: any) => r.status === "pending");
      if (prior) return { status: "pending", roomId };

      await ctx.db.insert("roomJoinRequests", {
        roomId,
        userId,
        inviteId: invite!._id,
        status: "pending",
        createdAt: now,
      });
      // The link did its work whether or not an admin says yes, so the use is
      // counted here rather than at approval. A link capped at 10 uses admits
      // at most 10 ATTEMPTS, which is the reading that actually bounds the
      // queue an admin has to work through.
      await ctx.db.patch(invite!._id, { useCount: (invite!.useCount ?? 0) + 1 });
      await notifyAdmins(ctx, roomId, userId, room.name);
      return { status: "pending", roomId };
    }

    await assertNotRemoved(ctx, roomId, userId);
    await addMembership(ctx, roomId, userId);
    await clearPendingFor(ctx, roomId, userId);
    await ctx.db.patch(invite!._id, { useCount: (invite!.useCount ?? 0) + 1 });
    return { status: "joined", roomId };
  },
});

// ─────────────────────────── join requests ───────────────────────────

/** Every admin of the room, for the "someone wants in" fan-out. */
async function adminIdsOf(ctx: any, roomId: any, exclude?: any): Promise<string[]> {
  const rows = await ctx.db
    .query("roomMembers")
    .withIndex("by_room_user", (q: any) => q.eq("roomId", roomId))
    .collect();
  return rows
    .filter((m: any) => isAdminRole(m.role))
    .map((m: any) => m.userId.toString())
    .filter((id: string) => id !== exclude?.toString());
}

async function notifyAdmins(
  ctx: any,
  roomId: any,
  requesterId: any,
  roomName: string,
) {
  const admins = await adminIdsOf(ctx, roomId, requesterId);
  if (admins.length === 0) return;
  const who = await ctx.db.get(requesterId);
  await ctx.scheduler.runAfter(0, internal.notifications.sendApprovalPush, {
    userIds: admins,
    title: "Someone wants to join",
    body: `${who?.name ?? who?.username ?? "Someone"} asked to join ${roomName}`,
    // Admins, who are members. The queue they need is inside the room's own
    // info sheet, so the room is the near side of it; the requests view is not
    // on the way at all.
    roomId,
  });
}

/** The admin queue for one room. Admin-only; returns [] rather than throwing
 *  for anyone else, so a demoted admin's open screen empties instead of
 *  erroring. */
export const listJoinRequests = query({
  args: { roomId: v.id("rooms"), userId: v.id("users") },
  handler: async (ctx, { roomId, userId }) => {
    const role = await roleOf(ctx, roomId, userId);
    if (!isAdminRole(role)) return [];
    const rows = await ctx.db
      .query("roomJoinRequests")
      .withIndex("by_room_status", (q: any) =>
        q.eq("roomId", roomId).eq("status", "pending"),
      )
      .collect();
    rows.sort((a: any, b: any) => a.createdAt - b.createdAt);
    // Through the viewer's lens like every other roster in the app. An admin
    // ruling on a stranger is not a reason to hand them fields that stranger
    // set to "friends only" — the decision needs a handle and a face, and
    // `publicUserView` is exactly what `rooms.getMembers` already gives.
    const lens = await lensFor(ctx, userId);
    const now = Date.now();
    const out = [];
    for (const r of rows) {
      const user = await ctx.db.get(r.userId);
      if (!user || isTombstoned(user)) continue;
      out.push({
        requestId: r._id,
        createdAt: r.createdAt,
        user: publicUserView(lens, user, now),
      });
    }
    return out;
  },
});

/**
 * Approve or reject one request. Any admin may answer; the row records which
 * one did, so "who let this person in" is answerable later.
 *
 * The row is kept after a decision rather than deleted — approved rows are the
 * audit trail, and a rejected row is what stops the same person re-queueing
 * on the same link the second an admin says no. A rejected person can still
 * ask again on a NEW link, which is the right escape hatch: the admin who
 * rotated the link chose to reopen the door.
 */
export const decideJoinRequest = mutation({
  args: {
    requestId: v.id("roomJoinRequests"),
    userId: v.id("users"),   // the deciding admin
    approve: v.boolean(),
  },
  handler: async (ctx, { requestId, userId, approve }) => {
    const request = await ctx.db.get(requestId);
    if (!request || request.status !== "pending") {
      throw new Error(ERR_REQUEST_NOT_FOUND);
    }
    const adminRoom = await assertAdministrableRoom(ctx, request.roomId);
    // Deciding into a room being deleted would admit someone to a ghost.
    if (isTombstoned(adminRoom)) throw new Error(ERR_REQUEST_NOT_FOUND);
    await assertAdmin(ctx, request.roomId, userId);

    const now = Date.now();
    await ctx.db.patch(requestId, {
      status: approve ? "approved" : "rejected",
      decidedAt: now,
      decidedBy: userId,
    });
    if (!approve) return;

    // Re-checked at approval, not just at request time. A child could have
    // been paired to a guardian in between, and more importantly a guardian
    // could have revoked a grant — the admin's yes must not overrule that.
    if (await isChild(ctx, request.userId)) {
      if (!(await childMayUseRoom(ctx, request.userId, request.roomId))) {
        throw new Error(ERR_APPROVAL_REQUIRED);
      }
    }

    await addMembership(ctx, request.roomId, request.userId);
    const room = await ctx.db.get(request.roomId);
    await ctx.scheduler.runAfter(0, internal.notifications.sendApprovalPush, {
      userIds: [request.userId.toString()],
      title: "You're in",
      body: `You were added to ${room?.name ?? "the group"}`,
      // "You're in" that lands anywhere other than in is a broken sentence.
      roomId: request.roomId,
    });
  },
});

/**
 * "Have I already asked?" for the requester's own screen — the one query about
 * a join request that a non-member is allowed to run, because it only ever
 * returns their own row.
 */
export const myJoinRequest = query({
  args: { roomId: v.id("rooms"), userId: v.id("users") },
  handler: async (ctx, { roomId, userId }) => {
    const rows = await ctx.db
      .query("roomJoinRequests")
      .withIndex("by_room_user", (q: any) =>
        q.eq("roomId", roomId).eq("userId", userId),
      )
      .collect();
    if (rows.length === 0) return null;
    rows.sort((a: any, b: any) => b.createdAt - a.createdAt);
    const r = rows[0];
    return { requestId: r._id, status: r.status, createdAt: r.createdAt };
  },
});
