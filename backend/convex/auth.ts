import { mutation, query, internalMutation } from "./_generated/server";
import { v } from "convex/values";
import { ACCOUNT_CHILD, ERR_MUST_PAIR, ERR_NOT_ALLOWED } from "./childGuard";
import { wipeRoomCompletely } from "./roomCleanup";
import { deleteStored } from "./files";

export const signup = mutation({
  args: {
    username: v.string(),
    name: v.string(),
    passwordHash: v.string(),
    recoveryKeyHash: v.optional(v.string()),
    email: v.optional(v.string()),
  },
  handler: async (ctx, { username, name, passwordHash, recoveryKeyHash, email }) => {
    const existing = await ctx.db
      .query("users")
      .withIndex("by_username", (q) => q.eq("username", username))
      .first();
    if (existing) throw new Error("USERNAME_TAKEN");

    const userId = await ctx.db.insert("users", {
      username,
      name,
      passwordHash,
      recoveryKeyHash,
      email,
      createdAt: Date.now(),
      status: "online",
      lastSeen: Date.now(),
    });
    return { userId, username, name };
  },
});

export const login = mutation({
  args: {
    username: v.string(),
    passwordHash: v.string(),
  },
  handler: async (ctx, { username, passwordHash }) => {
    const user = await ctx.db
      .query("users")
      .withIndex("by_username", (q) => q.eq("username", username))
      .first();
    if (!user) throw new Error("USER_NOT_FOUND");

    // Child accounts have no usable password — a guardian-issued pairing code
    // is the only way in. Checked BEFORE the hash compare so the stored
    // sentinel can never be brute-forced into a session, and so a child who
    // somehow learned a password can't sign in on an unsupervised device.
    if (user.accountType === ACCOUNT_CHILD) throw new Error(ERR_MUST_PAIR);

    if (user.passwordHash !== passwordHash) throw new Error("WRONG_PASSWORD");

    await ctx.db.patch(user._id, { status: "online", lastSeen: Date.now() });
    return { userId: user._id, username: user.username, name: user.name ?? user.username };
  },
});

export const logout = mutation({
  args: { userId: v.id("users") },
  handler: async (ctx, { userId }) => {
    await ctx.db.patch(userId, { status: "offline", lastSeen: Date.now() });
  },
});

export const resetPasswordWithRecoveryKey = mutation({
  args: {
    username: v.string(),
    recoveryKeyHash: v.string(),
    newPasswordHash: v.string(),
  },
  handler: async (ctx, { username, recoveryKeyHash, newPasswordHash }) => {
    const user = await ctx.db
      .query("users")
      .withIndex("by_username", (q) => q.eq("username", username))
      .first();
    if (!user) throw new Error("USER_NOT_FOUND");
    // Same reasoning as login: recovery is a password path, and children
    // don't have one. Without this, setting a recovery phrase on a child
    // account would be a way around pairing.
    if (user.accountType === ACCOUNT_CHILD) throw new Error(ERR_MUST_PAIR);
    if (!user.recoveryKeyHash || user.recoveryKeyHash !== recoveryKeyHash) {
      throw new Error("INVALID_RECOVERY_KEY");
    }
    await ctx.db.patch(user._id, {
      passwordHash: newPasswordHash,
      status: "online",
      lastSeen: Date.now(),
    });
    return { userId: user._id, username: user.username };
  },
});

/**
 * Self-serve account deletion. A child cannot delete their own account — that
 * would be an escape hatch out of supervision. Guardians remove a child via
 * `family.deleteChildAccount`, which runs the same teardown.
 */
export const deleteAccount = mutation({
  args: { userId: v.id("users") },
  handler: async (ctx, { userId }) => {
    const user = await ctx.db.get(userId);
    if (user?.accountType === ACCOUNT_CHILD) throw new Error(ERR_NOT_ALLOWED);
    await purgeUser(ctx, userId);
  },
});

/**
 * The teardown itself, callable from other modules. Split out of
 * `deleteAccount` so `family.deleteChildAccount` doesn't have to duplicate it.
 */
export const purgeAccount = internalMutation({
  args: { userId: v.id("users") },
  handler: async (ctx, { userId }) => {
    await purgeUser(ctx, userId);
  },
});

/**
 * Deletes every row across the given groups, skipping ids already seen.
 *
 * Most of the teardown below queries a table from two directions at once
 * (`by_user` + `by_friend`, `by_caller` + `by_callee`, …). Those can return
 * the same row twice, and a second `ctx.db.delete` on one id throws — so the
 * dedupe is load-bearing, not defensive.
 */
async function deleteRows(ctx: any, ...groups: any[][]) {
  const seen = new Set<string>();
  for (const rows of groups) {
    for (const row of rows) {
      const key = row._id.toString();
      if (seen.has(key)) continue;
      seen.add(key);
      await ctx.db.delete(row._id);
    }
  }
}

const byUser = (userId: any) => (q: any) => q.eq("userId", userId);

/**
 * Removes every trace of an account.
 *
 * Convex has no foreign keys and no cascade deletes, so this has to name every
 * table that can point at a user. Anything missed is not merely untidy: an
 * orphaned `blocks` row keeps two people invisible to each other, a stale
 * `userDevices` row keeps pushing to a dead account, and undeleted
 * `mediaStorageId` files bill forever with nothing referencing them.
 *
 * Ordering matters in one place only — rooms go first, because wiping a room
 * takes its messages with it and leaves the per-message pass less to walk.
 */
async function purgeUser(ctx: any, userId: any) {
  const user = await ctx.db.get(userId);

  // ── Rooms ────────────────────────────────────────────────────────────────
  const memberships = await ctx.db
    .query("roomMembers")
    .withIndex("by_user", byUser(userId))
    .collect();

  for (const membership of memberships) {
    const roomId = membership.roomId;
    await ctx.db.delete(membership._id);

    const remaining = await ctx.db
      .query("roomMembers")
      .withIndex("by_room", (q: any) => q.eq("roomId", roomId))
      .collect();

    if (remaining.length === 0) {
      // Last one out. `wipeRoomCompletely` is the same teardown the block and
      // "take back" flows use — it takes the room's media too.
      await wipeRoomCompletely(ctx, roomId);
      continue;
    }

    const room = await ctx.db.get(roomId);
    if (!room) continue;

    // Recount rather than decrement: `remaining` is the truth, so a count
    // that had already drifted heals here.
    const patch: any = { memberCount: remaining.length };

    // `rooms.createdBy` gates NOT_OWNER (rooms.ts). Leaving it pointing at a
    // deleted user would freeze the room for everyone still in it — nobody
    // could ever rename or delete it again. Hand it to whoever has been there
    // longest, and make that real by promoting their membership too.
    if (room.createdBy?.toString() === userId.toString()) {
      const heir = remaining.reduce((a: any, b: any) =>
        (a.joinedAt ?? 0) <= (b.joinedAt ?? 0) ? a : b,
      );
      patch.createdBy = heir.userId;
      if (heir.role !== "owner") {
        await ctx.db.patch(heir._id, { role: "owner" });
      }
    }
    await ctx.db.patch(roomId, patch);
  }

  // ── Messages this user sent in rooms that survived ───────────────────────
  const userMessages = await ctx.db
    .query("messages")
    .withIndex("by_user", byUser(userId))
    .collect();
  for (const msg of userMessages) {
    const rxns = await ctx.db
      .query("reactions")
      .withIndex("by_message", (q: any) => q.eq("messageId", msg._id))
      .collect();
    await deleteRows(ctx, rxns);
    // Pins OTHER people put on this user's messages.
    await deleteRows(
      ctx,
      await ctx.db
        .query("pinnedMessages")
        .withIndex("by_message", (q: any) => q.eq("messageId", msg._id))
        .collect(),
    );
    await deleteStored(ctx, msg.mediaStorageId);
    // View-once ledger for photos this user SENT.
    await deleteRows(
      ctx,
      await ctx.db
        .query("viewOnceViews")
        .withIndex("by_message", (q: any) => q.eq("messageId", msg._id))
        .collect(),
    );
    await ctx.db.delete(msg._id);
  }
  await deleteStored(ctx, user?.avatarStorageId);

  // Reactions left on other people's messages, which outlive the above.
  await deleteRows(
    ctx,
    await ctx.db.query("reactions").withIndex("by_user", byUser(userId)).collect(),
  );

  // Pins this user put on other people's messages. Same shape as the reactions
  // case overhead, and the only reason `pinnedMessages.by_user` exists.
  //
  // Note this is account DELETION, not leaving a room: a pin survives its
  // author walking out of a group, because a pin is room state like the room's
  // name. Only the user row vanishing takes it, and then only because a
  // dangling `userId` would be a broken reference.
  await deleteRows(
    ctx,
    await ctx.db
      .query("pinnedMessages")
      .withIndex("by_user", byUser(userId))
      .collect(),
  );

  // View-once rows where this user was the VIEWER. These hang off other
  // people's messages, so the loop above never reaches them — same shape as
  // the reactions case directly overhead.
  await deleteRows(
    ctx,
    await ctx.db
      .query("viewOnceViews")
      .withIndex("by_user", byUser(userId))
      .collect(),
  );

  // Push receipts addressed to this user. `by_user_room` is used as a
  // userId-only prefix here.
  await deleteRows(
    ctx,
    await ctx.db
      .query("pushReceipts")
      .withIndex("by_user_room", byUser(userId))
      .collect(),
  );

  // ── Social graph ─────────────────────────────────────────────────────────
  await deleteRows(
    ctx,
    await ctx.db.query("friendships").withIndex("by_user", byUser(userId)).collect(),
    await ctx.db
      .query("friendships")
      .withIndex("by_friend", (q: any) => q.eq("friendId", userId))
      .collect(),
  );
  await deleteRows(
    ctx,
    await ctx.db
      .query("friendRequestMessages")
      .withIndex("by_user", byUser(userId))
      .collect(),
  );
  await deleteRows(
    ctx,
    await ctx.db.query("blocks").withIndex("by_user", byUser(userId)).collect(),
    await ctx.db
      .query("blocks")
      .withIndex("by_blocked", (q: any) => q.eq("blockedUserId", userId))
      .collect(),
  );

  // ── Family ───────────────────────────────────────────────────────────────
  // Both directions: this user may be the child OR the guardian.
  await deleteRows(
    ctx,
    await ctx.db
      .query("guardianships")
      .withIndex("by_guardian", (q: any) => q.eq("guardianId", userId))
      .collect(),
    await ctx.db
      .query("guardianships")
      .withIndex("by_child", (q: any) => q.eq("childId", userId))
      .collect(),
  );
  for (const table of ["pairingCodes", "releaseCodes"]) {
    await deleteRows(
      ctx,
      await ctx.db
        .query(table)
        .withIndex("by_child", (q: any) => q.eq("childId", userId))
        .collect(),
      await ctx.db
        .query(table)
        .withIndex("by_creator", (q: any) => q.eq("createdByGuardianId", userId))
        .collect(),
    );
  }

  const approvalGroups = [];
  for (const status of ["pending", "approved", "denied", "revoked"]) {
    approvalGroups.push(
      await ctx.db
        .query("approvalRequests")
        .withIndex("by_child_status", (q: any) =>
          q.eq("childId", userId).eq("status", status),
        )
        .collect(),
    );
  }
  approvalGroups.push(
    await ctx.db
      .query("approvalRequests")
      .withIndex("by_target_user", (q: any) => q.eq("targetUserId", userId))
      .collect(),
  );
  approvalGroups.push(
    await ctx.db
      .query("approvalRequests")
      .withIndex("by_decider", (q: any) => q.eq("decidedByGuardianId", userId))
      .collect(),
  );
  await deleteRows(ctx, ...approvalGroups);

  // ── Calls ────────────────────────────────────────────────────────────────
  const calls = [
    ...(await ctx.db
      .query("calls")
      .withIndex("by_caller", (q: any) => q.eq("callerId", userId))
      .collect()),
    ...(await ctx.db
      .query("calls")
      .withIndex("by_callee", (q: any) => q.eq("calleeId", userId))
      .collect()),
  ];
  const signalGroups = [];
  for (const call of calls) {
    signalGroups.push(
      await ctx.db
        .query("callSignals")
        .withIndex("by_call", (q: any) => q.eq("callId", call._id))
        .collect(),
    );
  }
  // Strays whose call row is already gone (a cron trims old calls).
  signalGroups.push(
    await ctx.db
      .query("callSignals")
      .withIndex("by_from", (q: any) => q.eq("fromUserId", userId))
      .collect(),
  );
  signalGroups.push(
    await ctx.db
      .query("callSignals")
      .withIndex("by_to", (q: any) => q.eq("toUserId", userId))
      .collect(),
  );
  await deleteRows(ctx, ...signalGroups);
  await deleteRows(ctx, calls);

  // ── Devices ──────────────────────────────────────────────────────────────
  // Left behind, these keep waking a phone for an account that no longer exists.
  await deleteRows(
    ctx,
    await ctx.db.query("userDevices").withIndex("by_user", byUser(userId)).collect(),
  );

  // ── Reports ──────────────────────────────────────────────────────────────
  // Kept, not deleted: a moderation record has to outlive the person who filed
  // it, or anyone could erase their own report trail by deleting their account.
  // Tombstone the author instead of leaving a dangling id.
  const reports = await ctx.db
    .query("reports")
    .withIndex("by_reporter", (q: any) => q.eq("reporterId", userId))
    .collect();
  for (const r of reports) {
    await ctx.db.patch(r._id, { reporterId: undefined });
  }

  // ── Finally ──────────────────────────────────────────────────────────────
  await deleteRows(
    ctx,
    await ctx.db
      .query("typingIndicators")
      .withIndex("by_user", byUser(userId))
      .collect(),
  );
  await ctx.db.delete(userId);
}

export const updateStatus = mutation({
  args: { userId: v.id("users"), status: v.string() },
  handler: async (ctx, { userId, status }) => {
    await ctx.db.patch(userId, { status, lastSeen: Date.now() });
  },
});
