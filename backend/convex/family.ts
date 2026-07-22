import { mutation, query } from "./_generated/server";
import { internal } from "./_generated/api";
import { v } from "convex/values";
import {
  ACCOUNT_ADULT,
  ACCOUNT_CHILD,
  DEFAULT_CHILD_POLICY,
  ERR_CODE_EXPIRED,
  ERR_CODE_INVALID,
  ERR_NOT_ALLOWED,
  ERR_NOT_GUARDIAN,
  STAGE_RECIPIENT,
  STAGE_RECIPIENT_GUARDIAN,
  STAGE_SENDER_GUARDIAN,
  assertGuardian,
  childrenOf,
  guardiansOf,
  isChild,
  isGuardianOf,
} from "./childGuard";

/** Pairing codes are deliberately short-lived — they're six digits read aloud. */
const PAIRING_TTL_MS = 5 * 60 * 1000;

/**
 * Child accounts never authenticate with a password: `auth.login` rejects them
 * outright and pairing is the only way in. The `users.passwordHash` column is
 * non-optional though, so we park an unusable sentinel there. Nothing ever
 * compares against it.
 */
const CHILD_PASSWORD_SENTINEL = "__CHILD_NO_PASSWORD__";

// ───────────────────────────── accounts & pairing ─────────────────────────────

export const createChildAccount = mutation({
  args: {
    guardianId: v.id("users"),
    username: v.string(),
    name: v.string(),
    birthYear: v.optional(v.number()),
  },
  handler: async (ctx, { guardianId, username, name, birthYear }) => {
    const guardian = await ctx.db.get(guardianId);
    if (!guardian) throw new Error("USER_NOT_FOUND");
    // A child cannot itself become a guardian.
    if (await isChild(ctx, guardianId)) throw new Error(ERR_NOT_ALLOWED);

    const handle = username.trim();
    if (!handle) throw new Error("USERNAME_REQUIRED");
    const existing = await ctx.db
      .query("users")
      .withIndex("by_username", (q) => q.eq("username", handle))
      .first();
    if (existing) throw new Error("USERNAME_TAKEN");

    const childId = await ctx.db.insert("users", {
      username: handle,
      name: name.trim() || handle,
      passwordHash: CHILD_PASSWORD_SENTINEL,
      createdAt: Date.now(),
      status: "offline",
      lastSeen: Date.now(),
      accountType: ACCOUNT_CHILD,
      birthYear,
      childPolicy: { ...DEFAULT_CHILD_POLICY },
    });

    await ctx.db.insert("guardianships", {
      guardianId,
      childId,
      role: "primary",
      createdAt: Date.now(),
    });

    return { userId: childId, username: handle, name: name.trim() || handle };
  },
});

/**
 * Adds a second guardian to an existing child. Any existing guardian can do
 * this; approvals are never quorum-based, so the new guardian has equal say.
 */
export const addGuardian = mutation({
  args: {
    guardianId: v.id("users"),
    childId: v.id("users"),
    newGuardianUsername: v.string(),
  },
  handler: async (ctx, { guardianId, childId, newGuardianUsername }) => {
    await assertGuardian(ctx, guardianId, childId);
    const target = await ctx.db
      .query("users")
      .withIndex("by_username", (q) => q.eq("username", newGuardianUsername.trim()))
      .first();
    if (!target) throw new Error("USER_NOT_FOUND");
    if (await isChild(ctx, target._id)) throw new Error(ERR_NOT_ALLOWED);
    if (await isGuardianOf(ctx, target._id, childId)) return;

    await ctx.db.insert("guardianships", {
      guardianId: target._id,
      childId,
      role: "guardian",
      createdAt: Date.now(),
    });
  },
});

/**
 * Mints a pairing code for [childId]. The guardian's device generates the six
 * digits and hashes them with the same sha256 helper it uses for passwords —
 * plaintext never reaches the database. Any previous unconsumed code for this
 * child is invalidated so only one code is ever live.
 */
export const createPairingCode = mutation({
  args: {
    guardianId: v.id("users"),
    childId: v.id("users"),
    codeHash: v.string(),
  },
  handler: async (ctx, { guardianId, childId, codeHash }) => {
    await assertGuardian(ctx, guardianId, childId);

    const prior = await ctx.db
      .query("pairingCodes")
      .withIndex("by_child", (q) => q.eq("childId", childId))
      .collect();
    for (const p of prior) {
      if (!p.consumedAt) await ctx.db.delete(p._id);
    }

    const expiresAt = Date.now() + PAIRING_TTL_MS;
    await ctx.db.insert("pairingCodes", {
      childId,
      createdByGuardianId: guardianId,
      codeHash,
      expiresAt,
    });
    return { expiresAt };
  },
});

export const revokePairingCode = mutation({
  args: { guardianId: v.id("users"), childId: v.id("users") },
  handler: async (ctx, { guardianId, childId }) => {
    await assertGuardian(ctx, guardianId, childId);
    const rows = await ctx.db
      .query("pairingCodes")
      .withIndex("by_child", (q) => q.eq("childId", childId))
      .collect();
    for (const r of rows) {
      if (!r.consumedAt) await ctx.db.delete(r._id);
    }
  },
});

/**
 * Redeems a pairing code on the child's device. Single-use: the row is stamped
 * consumed, so a shoulder-surfed code is dead the moment it's used. Returns
 * the same shape `auth.login` does, plus `accountType`, so the client's session
 * plumbing is identical for both paths.
 */
export const redeemPairingCode = mutation({
  args: {
    codeHash: v.string(),
    deviceId: v.string(),
    platform: v.string(),
    deviceName: v.optional(v.string()),
  },
  handler: async (ctx, { codeHash, deviceId, platform, deviceName }) => {
    const row = await ctx.db
      .query("pairingCodes")
      .withIndex("by_codeHash", (q) => q.eq("codeHash", codeHash))
      .first();
    if (!row || row.consumedAt) throw new Error(ERR_CODE_INVALID);
    if (row.expiresAt < Date.now()) throw new Error(ERR_CODE_EXPIRED);

    const child = await ctx.db.get(row.childId);
    if (!child) throw new Error("USER_NOT_FOUND");

    await ctx.db.patch(row._id, {
      consumedAt: Date.now(),
      consumedDeviceId: deviceId,
    });
    await ctx.db.patch(child._id, { status: "online", lastSeen: Date.now() });

    // Register the device so the "Move call here" pill and call wake-ups work
    // for the child exactly as they do for an adult.
    const existingDevice = await ctx.db
      .query("userDevices")
      .withIndex("by_user_device", (q) =>
        q.eq("userId", child._id).eq("deviceId", deviceId),
      )
      .first();
    if (existingDevice) {
      await ctx.db.patch(existingDevice._id, {
        platform,
        deviceName,
        lastSeenAt: Date.now(),
      });
    } else {
      await ctx.db.insert("userDevices", {
        userId: child._id,
        deviceId,
        platform,
        deviceName,
        lastSeenAt: Date.now(),
        createdAt: Date.now(),
      });
    }

    return {
      userId: child._id,
      username: child.username,
      name: child.name ?? child.username,
      accountType: ACCOUNT_CHILD,
    };
  },
});

// ───────────────────────────────── policy ─────────────────────────────────

export const setChildPolicy = mutation({
  args: {
    guardianId: v.id("users"),
    childId: v.id("users"),
    publicRoomsEnabled: v.optional(v.boolean()),
    callsEnabled: v.optional(v.boolean()),
    mediaEnabled: v.optional(v.boolean()),
    canRequestContacts: v.optional(v.boolean()),
    canCreateRooms: v.optional(v.boolean()),
  },
  handler: async (ctx, { guardianId, childId, ...flags }) => {
    await assertGuardian(ctx, guardianId, childId);
    const child = await ctx.db.get(childId);
    if (!child) throw new Error("USER_NOT_FOUND");

    const prev = child.childPolicy ?? DEFAULT_CHILD_POLICY;
    const next = { ...prev };
    for (const [k, val] of Object.entries(flags)) {
      if (val !== undefined) (next as any)[k] = val;
    }
    await ctx.db.patch(childId, { childPolicy: next });
    return next;
  },
});

// ──────────────────────────── the contact relay ────────────────────────────

/**
 * Moves a pending contact request one hop along the guardian chain, or kills
 * it. This is the single mutation behind every "approve"/"deny" tap on a
 * contact request, whichever end of the chain the guardian is standing at.
 *
 *   awaitingSenderGuardian    + approve → recipient is a child
 *                                           ? awaitingRecipientGuardian
 *                                           : awaitingRecipient
 *   awaitingRecipientGuardian + approve → awaitingRecipient
 *   any stage                 + deny    → status "denied", stamped with which
 *                                         side said no
 *
 * A guardian may only release the hop belonging to *their own* child — a
 * sender's guardian cannot wave the request past the recipient's guardian.
 * Approving never creates the friendship: the recipient still decides.
 */
export const advanceContactRequest = mutation({
  args: {
    friendshipId: v.id("friendships"),
    guardianId: v.id("users"),
    approve: v.boolean(),
  },
  handler: async (ctx, { friendshipId, guardianId, approve }) => {
    const req = await ctx.db.get(friendshipId);
    if (!req || req.status !== "pending") throw new Error("REQUEST_NOT_FOUND");

    // Which side of the chain is this, and therefore whose guardian may act?
    let supervisedId: any;
    if (req.stage === STAGE_SENDER_GUARDIAN) {
      supervisedId = req.userId;
    } else if (req.stage === STAGE_RECIPIENT_GUARDIAN) {
      supervisedId = req.friendId;
    } else {
      // Already released to the recipient (or never supervised) — a guardian
      // has nothing left to decide here.
      throw new Error("REQUEST_NOT_PENDING_APPROVAL");
    }
    await assertGuardian(ctx, guardianId, supervisedId);

    if (!approve) {
      await ctx.db.patch(friendshipId, {
        status: "denied",
        deniedBy:
          req.stage === STAGE_SENDER_GUARDIAN
            ? "senderGuardian"
            : "recipientGuardian",
        respondedAt: Date.now(),
      });
      return { stage: null, status: "denied" };
    }

    let nextStage: string;
    if (req.stage === STAGE_SENDER_GUARDIAN) {
      nextStage = (await isChild(ctx, req.friendId))
        ? STAGE_RECIPIENT_GUARDIAN
        : STAGE_RECIPIENT;
    } else {
      nextStage = STAGE_RECIPIENT;
    }
    await ctx.db.patch(friendshipId, { stage: nextStage });

    // Tell whoever is now holding it. When the next hop is another guardian
    // the recipient still learns nothing.
    const notify =
      nextStage === STAGE_RECIPIENT_GUARDIAN
        ? await guardiansOf(ctx, req.friendId)
        : [req.friendId];
    const sender = await ctx.db.get(req.userId);
    const who = sender?.name ?? sender?.username ?? "Someone";
    await ctx.scheduler.runAfter(0, internal.notifications.sendApprovalPush, {
      userIds: notify.map((u: any) => u.toString()),
      title: nextStage === STAGE_RECIPIENT_GUARDIAN ? "Needs your OK" : "New request",
      body:
        nextStage === STAGE_RECIPIENT_GUARDIAN
          ? `${who} wants to add your child`
          : `${who} sent you a request`,
    });

    return { stage: nextStage, status: "pending" };
  },
});

/**
 * The parent inbox: everything waiting on this guardian, across all their
 * children and both kinds of approval, oldest first.
 *
 * Three shapes, distinguished by `type`, because they read very differently
 * to a parent: "Leo wants to add @zoe" / "@zoe wants to add Leo" /
 * "Leo wants to join #minecraft".
 */
export const listGuardianQueue = query({
  args: { guardianId: v.id("users") },
  handler: async (ctx, { guardianId }) => {
    const kids = await childrenOf(ctx, guardianId);
    const items: any[] = [];

    for (const childId of kids) {
      const child: any = await ctx.db.get(childId);
      if (!child) continue;
      const childBrief = {
        _id: child._id,
        username: child.username,
        name: child.name ?? child.username,
        avatarStorageId: child.avatarStorageId,
      };

      // 1. My child asked to add someone.
      const outgoing = await ctx.db
        .query("friendships")
        .withIndex("by_stage_user", (q) =>
          q.eq("stage", STAGE_SENDER_GUARDIAN).eq("userId", childId),
        )
        .collect();
      for (const r of outgoing) {
        if (r.status !== "pending") continue;
        const other = await ctx.db.get(r.friendId);
        if (!other) continue;
        items.push({
          type: "contactOutgoing",
          _id: r._id,
          createdAt: r.createdAt,
          note: r.initialMessage ?? "",
          child: childBrief,
          other: briefOf(other),
        });
      }

      // 2. Someone asked to add my child.
      const incoming = await ctx.db
        .query("friendships")
        .withIndex("by_stage_friend", (q) =>
          q.eq("stage", STAGE_RECIPIENT_GUARDIAN).eq("friendId", childId),
        )
        .collect();
      for (const r of incoming) {
        if (r.status !== "pending") continue;
        const other = await ctx.db.get(r.userId);
        if (!other) continue;
        items.push({
          type: "contactIncoming",
          _id: r._id,
          createdAt: r.createdAt,
          note: r.initialMessage ?? "",
          child: childBrief,
          other: briefOf(other),
        });
      }

      // 3. My child asked to join a room.
      const approvals = await ctx.db
        .query("approvalRequests")
        .withIndex("by_child_status", (q) =>
          q.eq("childId", childId).eq("status", "pending"),
        )
        .collect();
      for (const a of approvals) {
        const room = a.targetRoomId ? await ctx.db.get(a.targetRoomId) : null;
        items.push({
          type: a.kind,
          _id: a._id,
          createdAt: a.createdAt,
          note: a.note ?? "",
          child: childBrief,
          room: room
            ? {
                _id: room._id,
                name: room.name,
                description: room.description,
                memberCount: room.memberCount,
                avatarStorageId: room.avatarStorageId,
              }
            : null,
        });
      }
    }

    return items.sort((a, b) => a.createdAt - b.createdAt);
  },
});

function briefOf(u: any) {
  return {
    _id: u._id,
    username: u.username,
    name: u.name ?? u.username,
    avatarStorageId: u.avatarStorageId,
    accountType: u.accountType ?? ACCOUNT_ADULT,
  };
}

// ─────────────────────────── room approvals / grants ───────────────────────────

/**
 * A child asks for something a policy or grant doesn't already allow. Deduped:
 * asking twice for the same room reuses the live row rather than spamming the
 * parent.
 */
export const requestApproval = mutation({
  args: {
    childId: v.id("users"),
    kind: v.string(), // "joinRoom"
    targetRoomId: v.optional(v.id("rooms")),
    note: v.optional(v.string()),
  },
  handler: async (ctx, { childId, kind, targetRoomId, note }) => {
    if (!(await isChild(ctx, childId))) throw new Error(ERR_NOT_ALLOWED);
    if (kind !== "joinRoom") throw new Error("UNKNOWN_APPROVAL_KIND");
    if (!targetRoomId) throw new Error("TARGET_REQUIRED");

    const existing = await ctx.db
      .query("approvalRequests")
      .withIndex("by_child_room", (q) =>
        q.eq("childId", childId).eq("targetRoomId", targetRoomId),
      )
      .collect();
    const live = existing.find(
      (r) => r.status === "pending" || r.status === "approved",
    );
    if (live) return live._id;

    const id = await ctx.db.insert("approvalRequests", {
      childId,
      kind,
      status: "pending",
      targetRoomId,
      note: note?.trim() || undefined,
      createdAt: Date.now(),
    });

    const child = await ctx.db.get(childId);
    const room = await ctx.db.get(targetRoomId);
    const guardians = await guardiansOf(ctx, childId);
    await ctx.scheduler.runAfter(0, internal.notifications.sendApprovalPush, {
      userIds: guardians.map((g: any) => g.toString()),
      title: "Needs your OK",
      body: `${child?.name ?? "Your child"} wants to join ${room?.name ?? "a room"}`,
    });

    return id;
  },
});

/**
 * Approve or deny a room request. Approving *performs* the join — mirroring
 * `rooms.join` — so the child doesn't have to come back and tap again.
 *
 * Note: a room password is not re-checked here. The parent seeing the request
 * and saying yes IS the authorization; the child could not have raised the
 * request without clearing the password prompt client-side.
 */
export const decideApproval = mutation({
  args: {
    approvalId: v.id("approvalRequests"),
    guardianId: v.id("users"),
    approve: v.boolean(),
  },
  handler: async (ctx, { approvalId, guardianId, approve }) => {
    const req = await ctx.db.get(approvalId);
    if (!req || req.status !== "pending") throw new Error("REQUEST_NOT_FOUND");
    await assertGuardian(ctx, guardianId, req.childId);

    if (!approve) {
      await ctx.db.patch(approvalId, {
        status: "denied",
        decidedAt: Date.now(),
        decidedByGuardianId: guardianId,
      });
      return null;
    }

    const targetRoomId = req.targetRoomId;
    if (req.kind === "joinRoom" && targetRoomId) {
      const room = await ctx.db.get(targetRoomId);
      if (!room) throw new Error("ROOM_NOT_FOUND");
      const already = await ctx.db
        .query("roomMembers")
        .withIndex("by_room_user", (q) =>
          q.eq("roomId", targetRoomId).eq("userId", req.childId),
        )
        .first();
      if (!already) {
        await ctx.db.insert("roomMembers", {
          roomId: targetRoomId,
          userId: req.childId,
          joinedAt: Date.now(),
          role: "member",
        });
        await ctx.db.patch(targetRoomId, { memberCount: room.memberCount + 1 });
      }
    }

    await ctx.db.patch(approvalId, {
      status: "approved",
      decidedAt: Date.now(),
      decidedByGuardianId: guardianId,
    });
    return targetRoomId ?? null;
  },
});

/**
 * Takes back a previously approved grant. For a room that also removes the
 * child from it — a revoked grant the child is still sitting inside would be
 * meaningless.
 */
export const revokeApproval = mutation({
  args: { guardianId: v.id("users"), approvalId: v.id("approvalRequests") },
  handler: async (ctx, { guardianId, approvalId }) => {
    const req = await ctx.db.get(approvalId);
    if (!req) throw new Error("REQUEST_NOT_FOUND");
    await assertGuardian(ctx, guardianId, req.childId);

    const targetRoomId = req.targetRoomId;
    if (req.kind === "joinRoom" && targetRoomId) {
      const member = await ctx.db
        .query("roomMembers")
        .withIndex("by_room_user", (q) =>
          q.eq("roomId", targetRoomId).eq("userId", req.childId),
        )
        .first();
      if (member) {
        await ctx.db.delete(member._id);
        const room = await ctx.db.get(targetRoomId);
        if (room && room.memberCount > 0) {
          await ctx.db.patch(targetRoomId, { memberCount: room.memberCount - 1 });
        }
      }
    }

    await ctx.db.patch(approvalId, {
      status: "revoked",
      decidedAt: Date.now(),
      decidedByGuardianId: guardianId,
    });
  },
});

/** Severs an accepted contact. Used from the parent dashboard's contact list. */
export const revokeContact = mutation({
  args: {
    guardianId: v.id("users"),
    childId: v.id("users"),
    contactUserId: v.id("users"),
  },
  handler: async (ctx, { guardianId, childId, contactUserId }) => {
    await assertGuardian(ctx, guardianId, childId);
    const a = await ctx.db
      .query("friendships")
      .withIndex("by_pair", (q) =>
        q.eq("userId", childId).eq("friendId", contactUserId),
      )
      .first();
    const b = await ctx.db
      .query("friendships")
      .withIndex("by_pair", (q) =>
        q.eq("userId", contactUserId).eq("friendId", childId),
      )
      .first();
    if (a) await ctx.db.delete(a._id);
    if (b) await ctx.db.delete(b._id);
  },
});

// ───────────────────────────────── reads ─────────────────────────────────

/**
 * Everything the client needs to decide what to render, in one round trip:
 * am I a child, what am I allowed to do, who are my grown-ups, who are my
 * kids, and how many things are waiting on me.
 */
export const getFamilyContext = query({
  args: { userId: v.id("users") },
  handler: async (ctx, { userId }) => {
    const me = await ctx.db.get(userId);
    if (!me) return null;
    const child = (me.accountType ?? ACCOUNT_ADULT) === ACCOUNT_CHILD;

    const guardianIds = child ? await guardiansOf(ctx, userId) : [];
    const guardians = [];
    for (const g of guardianIds) {
      const u: any = await ctx.db.get(g);
      if (u) guardians.push(briefOf(u));
    }

    const kidIds = child ? [] : await childrenOf(ctx, userId);
    const children = [];
    let pendingCount = 0;
    for (const k of kidIds) {
      const u: any = await ctx.db.get(k);
      if (!u) continue;
      const n = await pendingCountFor(ctx, k);
      pendingCount += n;
      children.push({
        ...briefOf(u),
        status: u.status,
        lastSeen: u.lastSeen,
        childPolicy: u.childPolicy ?? DEFAULT_CHILD_POLICY,
        pendingCount: n,
      });
    }

    return {
      accountType: child ? ACCOUNT_CHILD : ACCOUNT_ADULT,
      childPolicy: child ? me.childPolicy ?? DEFAULT_CHILD_POLICY : null,
      guardians,
      children,
      pendingCount,
    };
  },
});

/** How many things are sitting in a guardian's queue for this one child. */
async function pendingCountFor(ctx: any, childId: any): Promise<number> {
  const rooms = await ctx.db
    .query("approvalRequests")
    .withIndex("by_child_status", (q: any) =>
      q.eq("childId", childId).eq("status", "pending"),
    )
    .collect();
  const outgoing = await ctx.db
    .query("friendships")
    .withIndex("by_stage_user", (q: any) =>
      q.eq("stage", STAGE_SENDER_GUARDIAN).eq("userId", childId),
    )
    .collect();
  const incoming = await ctx.db
    .query("friendships")
    .withIndex("by_stage_friend", (q: any) =>
      q.eq("stage", STAGE_RECIPIENT_GUARDIAN).eq("friendId", childId),
    )
    .collect();
  return (
    rooms.length +
    outgoing.filter((r: any) => r.status === "pending").length +
    incoming.filter((r: any) => r.status === "pending").length
  );
}

/** The child's own "waiting on a grown-up" list. */
export const listMyApprovals = query({
  args: { childId: v.id("users") },
  handler: async (ctx, { childId }) => {
    const rows = await ctx.db
      .query("approvalRequests")
      .withIndex("by_child_status", (q) =>
        q.eq("childId", childId).eq("status", "pending"),
      )
      .collect();
    const out = [];
    for (const r of rows) {
      const room = r.targetRoomId ? await ctx.db.get(r.targetRoomId) : null;
      out.push({
        _id: r._id,
        kind: r.kind,
        createdAt: r.createdAt,
        roomId: r.targetRoomId,
        roomName: room?.name ?? null,
      });
    }
    return out;
  },
});

/** Rooms and people a guardian has let this child have, for the dashboard. */
export const listChildGrants = query({
  args: { guardianId: v.id("users"), childId: v.id("users") },
  handler: async (ctx, { guardianId, childId }) => {
    if (!(await isGuardianOf(ctx, guardianId, childId))) {
      throw new Error(ERR_NOT_GUARDIAN);
    }

    const approved = await ctx.db
      .query("approvalRequests")
      .withIndex("by_child_status", (q) =>
        q.eq("childId", childId).eq("status", "approved"),
      )
      .collect();
    const rooms = [];
    for (const a of approved) {
      const room = a.targetRoomId ? await ctx.db.get(a.targetRoomId) : null;
      if (room) {
        rooms.push({
          approvalId: a._id,
          _id: room._id,
          name: room.name,
          memberCount: room.memberCount,
          avatarStorageId: room.avatarStorageId,
        });
      }
    }

    const friendships = await ctx.db
      .query("friendships")
      .withIndex("by_user", (q) => q.eq("userId", childId))
      .collect();
    const contacts = [];
    for (const f of friendships) {
      if (f.status !== "accepted") continue;
      const u: any = await ctx.db.get(f.friendId);
      if (u) contacts.push(briefOf(u));
    }

    return { rooms, contacts };
  },
});

// ────────────────────────────── teardown ──────────────────────────────

/** Drops the supervision link but leaves the account standing. */
export const unlinkChild = mutation({
  args: { guardianId: v.id("users"), childId: v.id("users") },
  handler: async (ctx, { guardianId, childId }) => {
    await assertGuardian(ctx, guardianId, childId);
    const row = await ctx.db
      .query("guardianships")
      .withIndex("by_pair", (q) =>
        q.eq("guardianId", guardianId).eq("childId", childId),
      )
      .first();
    if (row) await ctx.db.delete(row._id);
  },
});

/**
 * Graduates a child to a normal account: clears the supervision flags, sets a
 * real password, and drops every guardianship. Irreversible by design — after
 * this the former guardians have no special visibility.
 */
export const promoteToAdult = mutation({
  args: {
    guardianId: v.id("users"),
    childId: v.id("users"),
    passwordHash: v.string(),
  },
  handler: async (ctx, { guardianId, childId, passwordHash }) => {
    await assertGuardian(ctx, guardianId, childId);

    await ctx.db.patch(childId, {
      accountType: ACCOUNT_ADULT,
      childPolicy: undefined,
      passwordHash,
    });

    const links = await ctx.db
      .query("guardianships")
      .withIndex("by_child", (q) => q.eq("childId", childId))
      .collect();
    for (const l of links) await ctx.db.delete(l._id);

    const codes = await ctx.db
      .query("pairingCodes")
      .withIndex("by_child", (q) => q.eq("childId", childId))
      .collect();
    for (const c of codes) await ctx.db.delete(c._id);
  },
});

/**
 * Deletes a child account outright. Clears the family-specific rows here, then
 * hands off to the shared account teardown for rooms / friendships / messages.
 */
export const deleteChildAccount = mutation({
  args: { guardianId: v.id("users"), childId: v.id("users") },
  handler: async (ctx, { guardianId, childId }) => {
    await assertGuardian(ctx, guardianId, childId);

    const links = await ctx.db
      .query("guardianships")
      .withIndex("by_child", (q) => q.eq("childId", childId))
      .collect();
    for (const l of links) await ctx.db.delete(l._id);

    const codes = await ctx.db
      .query("pairingCodes")
      .withIndex("by_child", (q) => q.eq("childId", childId))
      .collect();
    for (const c of codes) await ctx.db.delete(c._id);

    for (const status of ["pending", "approved", "denied", "revoked"]) {
      const rows = await ctx.db
        .query("approvalRequests")
        .withIndex("by_child_status", (q) =>
          q.eq("childId", childId).eq("status", status),
        )
        .collect();
      for (const a of rows) await ctx.db.delete(a._id);
    }

    const devices = await ctx.db
      .query("userDevices")
      .withIndex("by_user", (q) => q.eq("userId", childId))
      .collect();
    for (const d of devices) await ctx.db.delete(d._id);

    await ctx.runMutation(internal.auth.purgeAccount, { userId: childId });
  },
});
