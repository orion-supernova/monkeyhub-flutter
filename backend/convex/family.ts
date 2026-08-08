import { mutation, query } from "./_generated/server";
import { internal } from "./_generated/api";
import {
  ERR_DISPLAY_NAME_RESERVED,
  ERR_USERNAME_RESERVED,
  isReservedName,
} from "./systemAccount";
import { lensFor } from "./visibility";
import { v } from "convex/values";
import {
  ACCOUNT_ADULT,
  ACCOUNT_CHILD,
  DEFAULT_CHILD_POLICY,
  ERR_CODE_EXPIRED,
  ERR_CODE_INVALID,
  ERR_LAST_GUARDIAN,
  ERR_NOT_ALLOWED,
  ERR_NOT_GUARDIAN,
  STAGE_RECIPIENT,
  STAGE_RECIPIENT_GUARDIAN,
  STAGE_SENDER_GUARDIAN,
  assertGuardian,
  childrenOf,
  familyOf,
  guardiansOf,
  initialStageFor,
  isChild,
  isGuardianOf,
} from "./childGuard";
import {
  findDmRoomsBetween,
  summariseRooms,
  wipeRoomCompletely,
} from "./roomCleanup";

/** Pairing codes are deliberately short-lived — they're six digits read aloud. */
const PAIRING_TTL_MS = 5 * 60 * 1000;

/**
 * Child accounts never authenticate with a password: `auth.login` rejects them
 * outright and pairing is the only way in. The `users.passwordHash` column is
 * non-optional though, so we park an unusable sentinel there. Nothing ever
 * compares against it.
 */
const CHILD_PASSWORD_SENTINEL = "__CHILD_NO_PASSWORD__";

/**
 * Accepted friendship in both directions between two family members.
 *
 * Family is already reachable with no approval (see `childMayReach`), so this
 * changes visibility rather than permission: without a `friendships` row the
 * two are allowed to talk but don't appear in each other's lists, which reads
 * as "my child isn't in my friends".
 *
 * Idempotent, and deliberately upgrades rather than skips: a pair may already
 * have a pending — or guardian-denied — row from before they were family, and
 * that must not outrank the family link.
 */
async function linkFamilyFriendship(ctx: any, a: any, b: any) {
  if (a.toString() === b.toString()) return;
  const now = Date.now();
  for (const [from, to] of [
    [a, b],
    [b, a],
  ]) {
    const existing = await ctx.db
      .query("friendships")
      .withIndex("by_pair", (q: any) =>
        q.eq("userId", from).eq("friendId", to),
      )
      .first();
    if (existing) {
      if (existing.status !== "accepted") {
        await ctx.db.patch(existing._id, {
          status: "accepted",
          respondedAt: now,
          stage: undefined,
          deniedBy: undefined,
        });
      }
      continue;
    }
    await ctx.db.insert("friendships", {
      userId: from,
      friendId: to,
      status: "accepted",
      createdAt: now,
      respondedAt: now,
    });
  }
}

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
    // Reserved handles. Third of the three paths that can claim a username —
    // `auth.signup` and `socialAuth.completeSocialSignUp` are the others, and all
    // three need this, because reserving a name in two of them reserves nothing.
    if (isReservedName(handle)) {
      throw new Error(ERR_USERNAME_RESERVED);
    }
    // The child's display name too — a guardian naming a child account
    // "MonkeyHub Support" would be handing it the same disguise, and this is the
    // one creation path where the person choosing the name is not the person the
    // account belongs to.
    if (isReservedName(name)) {
      throw new Error(ERR_DISPLAY_NAME_RESERVED);
    }
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

    // Existing siblings, captured BEFORE the new guardianship row exists so
    // the new child isn't in the list.
    const siblings = await childrenOf(ctx, guardianId);

    await ctx.db.insert("guardianships", {
      guardianId,
      childId,
      role: "primary",
      createdAt: Date.now(),
    });

    // Put the family in each other's lists. Every guardian, not just the
    // creator — a second parent added earlier supervises this child too.
    await linkFamilyFriendship(ctx, guardianId, childId);
    for (const sibling of siblings) {
      await linkFamilyFriendship(ctx, sibling, childId);
    }

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

    // The new guardian and the child are now family — and so are the new
    // guardian's other children and this one, since they share a guardian.
    await linkFamilyFriendship(ctx, target._id, childId);
    for (const sibling of await childrenOf(ctx, target._id)) {
      await linkFamilyFriendship(ctx, sibling, childId);
    }
  },
});

/**
 * Links up a family created before auto-friending existed. Idempotent and
 * cheap, so the family screen can just call it on load rather than needing a
 * migration or a "repair" button the user has to find.
 */
export const backfillFamilyFriendships = mutation({
  args: { guardianId: v.id("users") },
  handler: async (ctx, { guardianId }) => {
    const kids = await childrenOf(ctx, guardianId);
    let linked = 0;
    for (const childId of kids) {
      // Every guardian of this child, not just the caller.
      for (const g of await guardiansOf(ctx, childId)) {
        await linkFamilyFriendship(ctx, g, childId);
        linked++;
      }
      for (const sibling of kids) {
        if (sibling.toString() === childId.toString()) continue;
        await linkFamilyFriendship(ctx, sibling, childId);
        linked++;
      }
    }
    return linked;
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

// ──────────────────────────────── release ────────────────────────────────
//
// Handing a child's phone back. A child cannot sign themselves out — that is
// the point of a supervised device — so releasing one takes a grown-up's
// credential, presented on the child's handset:
//
//   • a six-digit code the guardian mints on their own device, or
//   • a guardian's own username + password, for when there is only one phone
//     (pairing a child signs the adult out, so there is no session left to
//     mint a code from).

/**
 * The teardown both release paths share: the handset stops being the child's.
 * Deleting the device row matters as much as ending the session — a stale row
 * keeps waking a phone that no longer belongs to that account.
 */
async function releaseDevice(ctx: any, childId: any, deviceId: string) {
  const device = await ctx.db
    .query("userDevices")
    .withIndex("by_user_device", (q: any) =>
      q.eq("userId", childId).eq("deviceId", deviceId),
    )
    .first();
  if (device) await ctx.db.delete(device._id);
  await ctx.db.patch(childId, { status: "offline", lastSeen: Date.now() });
  return { childId };
}

/** Guardian-side: mint a release code, exactly as `createPairingCode` does. */
export const createReleaseCode = mutation({
  args: {
    guardianId: v.id("users"),
    childId: v.id("users"),
    codeHash: v.string(),
  },
  handler: async (ctx, { guardianId, childId, codeHash }) => {
    await assertGuardian(ctx, guardianId, childId);

    const prior = await ctx.db
      .query("releaseCodes")
      .withIndex("by_child", (q) => q.eq("childId", childId))
      .collect();
    for (const p of prior) {
      if (!p.consumedAt) await ctx.db.delete(p._id);
    }

    const expiresAt = Date.now() + PAIRING_TTL_MS;
    await ctx.db.insert("releaseCodes", {
      childId,
      createdByGuardianId: guardianId,
      codeHash,
      expiresAt,
    });
    return { expiresAt };
  },
});

/** Child-device side: redeem a guardian's release code. Single-use. */
export const releaseDeviceByCode = mutation({
  args: { codeHash: v.string(), deviceId: v.string() },
  handler: async (ctx, { codeHash, deviceId }) => {
    const row = await ctx.db
      .query("releaseCodes")
      .withIndex("by_codeHash", (q) => q.eq("codeHash", codeHash))
      .first();
    if (!row || row.consumedAt) throw new Error(ERR_CODE_INVALID);
    if (row.expiresAt < Date.now()) throw new Error(ERR_CODE_EXPIRED);

    await ctx.db.patch(row._id, {
      consumedAt: Date.now(),
      consumedDeviceId: deviceId,
    });
    return releaseDevice(ctx, row.childId, deviceId);
  },
});

/**
 * Child-device side: a guardian proves themselves with their own password.
 *
 * Every failure throws the same error on purpose. This runs on a handset the
 * child is holding, so distinguishing "no such user" from "not a guardian"
 * from "wrong password" would let them map out who supervises them and then
 * grind on the one account that matters.
 */
export const releaseDeviceByGuardianPassword = mutation({
  args: {
    childId: v.id("users"),
    guardianUsername: v.string(),
    passwordHash: v.string(),
    deviceId: v.string(),
  },
  handler: async (ctx, { childId, guardianUsername, passwordHash, deviceId }) => {
    const guardian = await ctx.db
      .query("users")
      .withIndex("by_username", (q) => q.eq("username", guardianUsername.trim()))
      .first();

    // A child account has no usable password (the stored sentinel), and must
    // never be a way out of supervision — same guard `auth.login` applies.
    const ok =
      !!guardian &&
      (guardian.accountType ?? ACCOUNT_ADULT) !== ACCOUNT_CHILD &&
      guardian.passwordHash === passwordHash &&
      (await isGuardianOf(ctx, guardian._id, childId));
    if (!ok) throw new Error(ERR_NOT_GUARDIAN);

    return releaseDevice(ctx, childId, deviceId);
  },
});

// ───────────────────────────────── policy ─────────────────────────────────

export const setChildPolicy = mutation({
  args: {
    guardianId: v.id("users"),
    childId: v.id("users"),
    // `publicRoomsEnabled` is deliberately NOT here. It is no longer a guardian
    // decision — see DEFAULT_CHILD_POLICY in childGuard.ts. Removing the
    // argument rather than ignoring it means an old client that still sends it
    // gets a validation error instead of silently believing it worked.
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
    // Forced, not merged. Any child whose guardian switched Discover on before
    // this became fixed gets it switched back the next time any policy is
    // touched. `rooms.listPublic` ignores the stored value regardless, so this
    // is tidiness rather than the enforcement point.
    next.publicRoomsEnabled = false;
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
    const lens = await lensFor(ctx, guardianId);
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
          other: briefOf(lens, other),
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
          other: briefOf(lens, other),
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

/**
 * The thumbnail identity of one person on a family screen.
 *
 * The avatar goes through the viewer's lens like everywhere else. For the
 * guardian's own children that is a no-op — the lens bypasses the setting for
 * a ward, which is the whole point of guardianship — but the same helper also
 * renders co-guardians and the strangers in a child's approval queue, and
 * neither of those has consented to anything.
 */
function briefOf(lens: any, u: any) {
  return {
    _id: u._id,
    username: u.username,
    name: u.name ?? u.username,
    avatarStorageId: lens.canSee(u, "avatar") ? u.avatarStorageId : undefined,
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
 * Takes back a previously approved grant, and undoes what it allowed.
 *
 * A revoked grant the child is still living inside would be meaningless, so
 * this cascades by kind:
 *   "joinRoom" — remove the child from the room.
 *   "contact"  — sever the friendship and wipe the DMs, exactly as
 *                `revokeContact` does.
 *
 * The contact case lives here rather than in the client so it's one atomic
 * mutation: a two-call sequence that failed halfway would leave the
 * pre-approval revoked but the conversation still live.
 */
export const revokeApproval = mutation({
  args: { guardianId: v.id("users"), approvalId: v.id("approvalRequests") },
  handler: async (ctx, { guardianId, approvalId }) => {
    const req = await ctx.db.get(approvalId);
    if (!req) throw new Error("REQUEST_NOT_FOUND");
    await assertGuardian(ctx, guardianId, req.childId);

    if (req.kind === "contact" && req.targetUserId) {
      await severContact(ctx, req.childId, req.targetUserId);
    }

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

/**
 * Whitelists a username for a child: a standing pre-approval, NOT a
 * friendship. From here on, a request between these two skips this
 * guardian's hop in the relay (see `initialStageFor`) — in both directions,
 * so the parent stops being asked whether the child reaches out or the other
 * person does.
 *
 * The other person is never forced into anything: they still have to accept.
 * With [sendRequestNow] the request is fired on the child's behalf straight
 * away, so a parent setting up "add grandma" doesn't have to hand the phone
 * over for the child to do it.
 */
export const allowContactByUsername = mutation({
  args: {
    guardianId: v.id("users"),
    childId: v.id("users"),
    username: v.string(),
    sendRequestNow: v.optional(v.boolean()),
  },
  handler: async (ctx, { guardianId, childId, username, sendRequestNow }) => {
    await assertGuardian(ctx, guardianId, childId);

    const target = await ctx.db
      .query("users")
      .withIndex("by_username", (q) => q.eq("username", username.trim()))
      .first();
    if (!target) throw new Error("USER_NOT_FOUND");
    if (target._id.toString() === childId.toString()) {
      throw new Error("CANNOT_ADD_SELF");
    }

    // Idempotent: re-adding a live entry is a no-op rather than a duplicate.
    const existing = await ctx.db
      .query("approvalRequests")
      .withIndex("by_child_user", (q) =>
        q.eq("childId", childId).eq("targetUserId", target._id),
      )
      .collect();
    const live = existing.find(
      (r) => r.kind === "contact" && r.status === "approved",
    );
    if (!live) {
      // Superseded rows (revoked/denied) are cleared so the audit trail shows
      // one live decision per person rather than an ambiguous pile.
      for (const r of existing) {
        if (r.kind === "contact") await ctx.db.delete(r._id);
      }
      await ctx.db.insert("approvalRequests", {
        childId,
        kind: "contact",
        status: "approved",
        targetUserId: target._id,
        createdAt: Date.now(),
        decidedAt: Date.now(),
        decidedByGuardianId: guardianId,
      });
    }

    if (!sendRequestNow) return { userId: target._id, requested: false };

    // Already connected (or mid-flight) — the whitelist entry is enough.
    const { outgoing, incoming } = await directPair(ctx, childId, target._id);
    if (
      outgoing?.status === "accepted" ||
      incoming?.status === "accepted" ||
      outgoing?.status === "pending" ||
      incoming?.status === "pending"
    ) {
      return { userId: target._id, requested: false };
    }
    if (outgoing?.status === "denied") await ctx.db.delete(outgoing._id);
    if (incoming?.status === "denied") await ctx.db.delete(incoming._id);

    // Enters the relay at whatever hop the pre-approval just unlocked: with
    // the recipient if they're an adult, with THEIR guardian if they're a
    // child. The guardian doing this only speaks for their own side.
    const stage = await initialStageFor(ctx, childId, target._id);
    await ctx.db.insert("friendships", {
      userId: childId,
      friendId: target._id,
      status: "pending",
      createdAt: Date.now(),
      roomType: "Regular Room",
      initialMessage: "",
      ...(stage ? { stage } : {}),
    });

    const child = await ctx.db.get(childId);
    const who = child?.name ?? child?.username ?? "Someone";
    const audience =
      stage === STAGE_RECIPIENT_GUARDIAN
        ? await guardiansOf(ctx, target._id)
        : [target._id];
    await ctx.scheduler.runAfter(0, internal.notifications.sendApprovalPush, {
      userIds: audience.map((u: any) => u.toString()),
      title: stage === STAGE_RECIPIENT_GUARDIAN ? "Needs your OK" : "New request",
      body:
        stage === STAGE_RECIPIENT_GUARDIAN
          ? `${who} wants to add your child`
          : `${who} sent you a request`,
    });

    return { userId: target._id, requested: true };
  },
});

/** Both directions of a pair, in one place. Mirrors friends.ts's helper. */
async function directPair(ctx: any, a: any, b: any) {
  const outgoing = await ctx.db
    .query("friendships")
    .withIndex("by_pair", (q: any) => q.eq("userId", a).eq("friendId", b))
    .first();
  const incoming = await ctx.db
    .query("friendships")
    .withIndex("by_pair", (q: any) => q.eq("userId", b).eq("friendId", a))
    .first();
  return { outgoing, incoming };
}

/**
 * Severs a contact for a child and wipes the conversation with them.
 *
 * Taking someone away has to take the conversation away too, or the child
 * still has the whole history sitting in their chat list. The wipe is
 * unconditional and total: every DM the pair share, every message, reaction,
 * and media file, for BOTH of them — the same thing BLOCK & DELETE DM does.
 * The UI confirms this first (see `previewContactRemoval`).
 *
 * Shared group rooms are deliberately untouched — those are separate grants,
 * revoked from the rooms list.
 */
async function severContact(ctx: any, childId: any, contactUserId: any) {
  const a = await ctx.db
    .query("friendships")
    .withIndex("by_pair", (q: any) =>
      q.eq("userId", childId).eq("friendId", contactUserId),
    )
    .first();
  const b = await ctx.db
    .query("friendships")
    .withIndex("by_pair", (q: any) =>
      q.eq("userId", contactUserId).eq("friendId", childId),
    )
    .first();
  if (a) await ctx.db.delete(a._id);
  if (b) await ctx.db.delete(b._id);

  for (const roomId of await findDmRoomsBetween(ctx, childId, contactUserId)) {
    await wipeRoomCompletely(ctx, roomId);
  }
}

export const revokeContact = mutation({
  args: {
    guardianId: v.id("users"),
    childId: v.id("users"),
    contactUserId: v.id("users"),
  },
  handler: async (ctx, { guardianId, childId, contactUserId }) => {
    await assertGuardian(ctx, guardianId, childId);
    await severContact(ctx, childId, contactUserId);
  },
});

/**
 * What taking this person away would actually destroy, so the confirmation
 * can be specific instead of a vague "this cannot be undone".
 *
 * Group rooms are reported but NOT removed — the sheet names them so a parent
 * knows the two still share a space, and can revoke that separately.
 */
export const previewContactRemoval = query({
  args: {
    guardianId: v.id("users"),
    childId: v.id("users"),
    contactUserId: v.id("users"),
  },
  handler: async (ctx, { guardianId, childId, contactUserId }) => {
    if (!(await isGuardianOf(ctx, guardianId, childId))) {
      throw new Error(ERR_NOT_GUARDIAN);
    }

    const dmRoomIds = await findDmRoomsBetween(ctx, childId, contactUserId);
    const { messageCount, lastMessageAt } = await summariseRooms(ctx, dmRoomIds);

    // Group rooms both are in. Same shape as the loop in `rooms.listShared`,
    // scoped to this pair.
    const childMemberships = await ctx.db
      .query("roomMembers")
      .withIndex("by_user", (q) => q.eq("userId", childId))
      .collect();
    const sharedGroupRooms: any[] = [];
    for (const m of childMemberships) {
      const room = await ctx.db.get(m.roomId);
      if (!room || room.name?.startsWith("dm:")) continue;
      const other = await ctx.db
        .query("roomMembers")
        .withIndex("by_room_user", (q) =>
          q.eq("roomId", m.roomId).eq("userId", contactUserId),
        )
        .first();
      if (!other) continue;
      sharedGroupRooms.push({
        _id: room._id,
        name: room.name,
        memberCount: room.memberCount,
        avatarStorageId: room.avatarStorageId,
      });
    }

    return {
      dmCount: dmRoomIds.length,
      messageCount,
      lastMessageAt,
      sharedGroupRooms,
    };
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
    const lens = await lensFor(ctx, userId);
    const child = (me.accountType ?? ACCOUNT_ADULT) === ACCOUNT_CHILD;

    const guardianIds = child ? await guardiansOf(ctx, userId) : [];
    const guardians = [];
    for (const g of guardianIds) {
      const u: any = await ctx.db.get(g);
      if (u) guardians.push(briefOf(lens, u));
    }

    const kidIds = child ? [] : await childrenOf(ctx, userId);
    const children = [];
    let pendingCount = 0;
    for (const k of kidIds) {
      const u: any = await ctx.db.get(k);
      if (!u) continue;
      const n = await pendingCountFor(ctx, k);
      pendingCount += n;

      // Who else supervises this child. Lets the guardian screen list
      // co-parents, and tell whether "stop supervising" would strand the
      // account, without a second round trip.
      const coGuardians = [];
      for (const g of await guardiansOf(ctx, k)) {
        const gu: any = await ctx.db.get(g);
        if (gu) coGuardians.push(briefOf(lens, gu));
      }

      children.push({
        ...briefOf(lens, u),
        status: u.status,
        lastSeen: u.lastSeen,
        childPolicy: u.childPolicy ?? DEFAULT_CHILD_POLICY,
        pendingCount: n,
        guardians: coGuardians,
        guardianCount: coGuardians.length,
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
    const lens = await lensFor(ctx, guardianId);

    const approved = await ctx.db
      .query("approvalRequests")
      .withIndex("by_child_status", (q) =>
        q.eq("childId", childId).eq("status", "approved"),
      )
      .collect();

    const rooms = [];
    // userId → the whitelist row that pre-approved them.
    const preApproved = new Map<string, any>();
    for (const a of approved) {
      if (a.kind === "joinRoom" && a.targetRoomId) {
        const room = await ctx.db.get(a.targetRoomId);
        if (room) {
          rooms.push({
            approvalId: a._id,
            _id: room._id,
            name: room.name,
            memberCount: room.memberCount,
            avatarStorageId: room.avatarStorageId,
          });
        }
      } else if (a.kind === "contact" && a.targetUserId) {
        preApproved.set(a.targetUserId.toString(), a._id);
      }
    }

    const friendships = await ctx.db
      .query("friendships")
      .withIndex("by_user", (q) => q.eq("userId", childId))
      .collect();
    const connected = new Set<string>();
    for (const f of friendships) {
      if (f.status === "accepted") connected.add(f.friendId.toString());
    }

    // Family is excluded: guardians and siblings are auto-friended, so they
    // would otherwise fill this list — which is specifically about people
    // from OUTSIDE the family that a guardian has let in.
    const family = await familyOf(ctx, childId);

    // One row per person, whether they got there by whitelist, by approval,
    // or both — a parent thinks in people, not in grant records.
    const seen = new Set<string>();
    const contacts = [];
    for (const id of [...connected, ...preApproved.keys()]) {
      if (seen.has(id)) continue;
      if (family.has(id)) continue;
      seen.add(id);
      const u: any = await ctx.db.get(id as any);
      if (!u) continue;
      contacts.push({
        ...briefOf(lens, u),
        connected: connected.has(id),
        // Present only for whitelist entries — it's what `revokeApproval`
        // needs to take the pre-approval back.
        approvalId: preApproved.get(id) ?? null,
      });
    }

    return { rooms, contacts };
  },
});

// ────────────────────────────── teardown ──────────────────────────────

/**
 * Drops one supervision link but leaves the account standing.
 *
 * Refuses to remove the *last* guardian: that would strand the child account
 * for good (see [ERR_LAST_GUARDIAN]). The two real exits from supervision are
 * `promoteToAdult` and `deleteChildAccount`; a guardian who wants out while
 * someone else stays responsible has to add that someone else first.
 */
export const unlinkChild = mutation({
  args: { guardianId: v.id("users"), childId: v.id("users") },
  handler: async (ctx, { guardianId, childId }) => {
    await assertGuardian(ctx, guardianId, childId);

    const all = await ctx.db
      .query("guardianships")
      .withIndex("by_child", (q) => q.eq("childId", childId))
      .collect();
    if (all.length <= 1) throw new Error(ERR_LAST_GUARDIAN);

    const row = all.find(
      (g) => g.guardianId.toString() === guardianId.toString(),
    );
    if (row) await ctx.db.delete(row._id);
  },
});

/**
 * Graduates a child to a normal account: clears the supervision flags, sets a
 * real password, and drops every guardianship. Irreversible by design — after
 * this the former guardians have no special visibility.
 *
 * The row is left *indistinguishable* from one `auth.signup` would create —
 * every supervision-only field is removed rather than rewritten. `accountType`
 * included: signup never sets it, and absent already reads as adult everywhere
 * (`accountType ?? ACCOUNT_ADULT`), so writing "adult" would be the only trace
 * that this account was ever somebody's child.
 *
 * The family friendships stay. They are ordinary `accepted` rows with no
 * marker, so the former guardians and siblings simply remain friends — losing
 * supervision shouldn't silently unfriend the family.
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
      accountType: undefined,
      childPolicy: undefined,
      // Only ever collected for a child account, and read nowhere.
      birthYear: undefined,
      passwordHash,
    });

    const links = await ctx.db
      .query("guardianships")
      .withIndex("by_child", (q) => q.eq("childId", childId))
      .collect();
    for (const l of links) await ctx.db.delete(l._id);

    // Both kinds of code die with supervision: a graduated account is nobody's
    // child, so neither pairing nor releasing it means anything any more.
    for (const table of ["pairingCodes", "releaseCodes"] as const) {
      const codes = await ctx.db
        .query(table)
        .withIndex("by_child", (q) => q.eq("childId", childId))
        .collect();
      for (const c of codes) await ctx.db.delete(c._id);
    }
  },
});

/**
 * Deletes a child account outright.
 *
 * The family-specific rows (guardianships, pairing codes, approvals, devices)
 * used to be cleared here; `auth.purgeUser` now covers every table that can
 * point at a user, so duplicating a subset of it here would only be a second
 * list to keep in sync.
 */
export const deleteChildAccount = mutation({
  args: { guardianId: v.id("users"), childId: v.id("users") },
  handler: async (ctx, { guardianId, childId }) => {
    await assertGuardian(ctx, guardianId, childId);
    await ctx.runMutation(internal.auth.purgeAccount, { userId: childId });
  },
});
