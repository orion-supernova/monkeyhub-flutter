import { mutation, query, internalMutation } from "./_generated/server";
import { v } from "convex/values";
import { internal } from "./_generated/api";
import { ACCOUNT_CHILD, ERR_MUST_PAIR, ERR_NOT_ALLOWED } from "./childGuard";
import { SOCIAL_ONLY_PASSWORD_SENTINEL, ERR_USE_SOCIAL } from "./socialAuth";
import { wipeRoomCompletely } from "./roomCleanup";
import {
  ERR_DISPLAY_NAME_RESERVED,
  ERR_USERNAME_RESERVED,
  isReservedName,
} from "./systemAccount";
import { deleteStored, releaseMessageBlobs } from "./files";
import {
  assertNotLocked,
  clearFailures,
  loginKey,
  noteFailure,
  recoveryKey,
  MAX_RECOVERY_FAILURES,
} from "./rateLimit";

export const signup = mutation({
  args: {
    username: v.string(),
    name: v.string(),
    passwordHash: v.string(),
    recoveryKeyHash: v.optional(v.string()),
    email: v.optional(v.string()),
  },
  handler: async (ctx, { username, name, passwordHash, recoveryKeyHash, email }) => {
    // Reserved handles — anything reading as the brand, not just the exact
    // system names. Checked before the collision test so the answer does not
    // depend on whether a system account happens to exist yet: they are created
    // lazily, so until the first problem report the handle is simply free, and
    // whoever took it would own the name every report is posted from.
    if (isReservedName(username)) {
      throw new Error(ERR_USERNAME_RESERVED);
    }
    // And the display name, which is the field that actually renders next to
    // every message this account would ever send.
    if (isReservedName(name)) {
      throw new Error(ERR_DISPLAY_NAME_RESERVED);
    }

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
    // Sign-in deliberately keeps USER_NOT_FOUND and CHILD_MUST_PAIR distinct
    // rather than collapsing them the way reset does below. Username
    // enumeration is unavoidable here regardless — signup answers
    // USERNAME_TAKEN — and the child message is load-bearing UX ("ask a
    // grown-up for a pairing code"). Known and accepted, not an oversight.
    if (!user) throw new Error("USER_NOT_FOUND");

    // Child accounts have no usable password — a guardian-issued pairing code
    // is the only way in. Checked BEFORE the hash compare so the stored
    // sentinel can never be brute-forced into a session, and so a child who
    // somehow learned a password can't sign in on an unsupervised device.
    if (user.accountType === ACCOUNT_CHILD) throw new Error(ERR_MUST_PAIR);

    // Same shape, different reason: an account created through Apple/Google has
    // no password either. Answering WRONG_PASSWORD here would send someone to
    // the reset flow, which cannot help them — they have no recovery phrase
    // either. Point them at the button that actually works.
    //
    // Also before the hash compare, for the same sentinel-safety reason as the
    // child case above.
    if (user.passwordHash === SOCIAL_ONLY_PASSWORD_SENTINEL) {
      throw new Error(ERR_USE_SOCIAL);
    }

    // Before this, login accepted unlimited password guesses. Keyed by the
    // resolved user, so a nonexistent username never creates a row.
    const key = loginKey(user._id);
    await assertNotLocked(ctx, key);
    if (user.passwordHash !== passwordHash) {
      await noteFailure(ctx, key);
      throw new Error("WRONG_PASSWORD");
    }
    await clearFailures(ctx, key);

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
    // Required, not optional: clients from before the 12-word scheme are still
    // live on TestFlight and Play and send only this field. Convex rejects
    // undeclared args, so widening here is the only backwards-compatible move.
    recoveryKeyHash: v.string(),
    // Sent only by clients that know about the 12-word scheme. See the compat
    // table in lib/auth/recovery_phrase.dart#recoveryResetHashes.
    legacyRecoveryKeyHash: v.optional(v.string()),
    newPasswordHash: v.string(),
  },
  handler: async (
    ctx,
    { username, recoveryKeyHash, legacyRecoveryKeyHash, newPasswordHash },
  ) => {
    const user = await ctx.db
      .query("users")
      .withIndex("by_username", (q) => q.eq("username", username))
      .first();

    // ONE answer for "no such user", "that's a child account", and "no phrase
    // set". Reset is the only endpoint a stranger can probe with no credential
    // at all, so it must not answer any of those questions.
    //
    // The child case matters most: distinguishing it here would turn reset
    // into an "is this username a kid?" oracle, which is materially worse than
    // username existence. The rejection itself is preserved — a child still
    // cannot reset a password, since that would be a way around pairing.
    if (!user || user.accountType === ACCOUNT_CHILD || !user.recoveryKeyHash) {
      throw new Error("INVALID_RECOVERY_KEY");
    }

    const key = recoveryKey(user._id);
    await assertNotLocked(ctx, key);

    // Two candidates. A phrase set before the 12-word scheme was hashed from
    // the raw trimmed string, and the server can never upgrade those itself —
    // it never sees plaintext. So it accepts both shapes, permanently.
    const ok =
      user.recoveryKeyHash === recoveryKeyHash ||
      (legacyRecoveryKeyHash !== undefined &&
        user.recoveryKeyHash === legacyRecoveryKeyHash);
    if (!ok) {
      await noteFailure(ctx, key, MAX_RECOVERY_FAILURES);
      throw new Error("INVALID_RECOVERY_KEY");
    }
    await clearFailures(ctx, key);

    await ctx.db.patch(user._id, {
      passwordHash: newPasswordHash,
      status: "online",
      lastSeen: Date.now(),
    });
    // `name` is not optional for the client: AuthResult.fromJson does
    // `j['name'].toString()`, so omitting it here wrote the literal string
    // "null" into the keychain as the user's display name on every reset.
    // Matches the shape `login` returns above.
    return {
      userId: user._id,
      username: user.username,
      name: user.name ?? user.username,
    };
  },
});

/**
 * Sets or replaces the recovery phrase hash on an existing account.
 *
 * Before this existed there was no way to add a recovery phrase after signup,
 * which is the core of the bug this change fixes: an account created without
 * one was permanently unrecoverable.
 *
 * Password-authenticated on purpose. Every other mutation in this backend
 * trusts a client-supplied `userId` — there are no sessions, which is a known
 * and separate problem. This one MUST NOT inherit that, because it is a
 * complete account-takeover primitive: anyone who learned a userId could plant
 * their own recovery phrase and then reset the password with it. The password
 * is the only credential available here, so the password is the gate.
 */
export const setRecoveryKey = mutation({
  args: {
    userId: v.id("users"),
    passwordHash: v.string(),
    recoveryKeyHash: v.string(),
  },
  handler: async (ctx, { userId, passwordHash, recoveryKeyHash }) => {
    const user = await ctx.db.get(userId);
    if (!user) throw new Error("USER_NOT_FOUND");

    // BEFORE the password compare, mirroring login. This is the most important
    // guard in the file: without it, guessing the CHILD_PASSWORD_SENTINEL
    // (family.ts) would let anyone plant a recovery phrase on a child account
    // and then reset its password — a complete bypass of pairing.
    if (user.accountType === ACCOUNT_CHILD) throw new Error(ERR_MUST_PAIR);

    // Shares the LOGIN bucket, not a bucket of its own, so this cannot be used
    // as a password-guessing oracle that sidesteps the login limiter.
    const key = loginKey(user._id);
    await assertNotLocked(ctx, key);
    if (user.passwordHash !== passwordHash) {
      await noteFailure(ctx, key);
      throw new Error("WRONG_PASSWORD");
    }
    await clearFailures(ctx, key);

    await ctx.db.patch(user._id, { recoveryKeyHash });
  },
});

/**
 * Change the handle, proved with the account's password.
 *
 * The handle IS the login credential — `login` and
 * `resetPasswordWithRecoveryKey` both find an account by it — so this is a
 * credential change, and it is gated like one. Identity in this deployment is a
 * client-supplied `userId` (there is no `ctx.auth` anywhere; see the note in
 * feed.ts), which is exactly why the password cannot be skipped here: without
 * it, anyone who learned an id could rename that account out from under its
 * owner and take the name it signs in with.
 *
 * The rules themselves live in `users.applyUsernameChange`. This function owns
 * ONLY the proof, so that the Apple/Google path can present a different proof
 * and still land on identical rules.
 */
export const changeUsername = mutation({
  args: {
    userId: v.id("users"),
    passwordHash: v.string(),
    username: v.string(),
  },
  returns: v.object({ username: v.string() }),
  handler: async (ctx, { userId, passwordHash, username }) => {
    const user = await ctx.db.get(userId);
    if (!user) throw new Error("USER_NOT_FOUND");

    // BEFORE the compare, mirroring setRecoveryKey. A child's password is a
    // sentinel, so comparing first would turn guessing that constant into a
    // rename primitive on any supervised account.
    if (user.accountType === ACCOUNT_CHILD) throw new Error(ERR_MUST_PAIR);

    // An Apple/Google-only account has no password to prove anything with, and
    // its sentinel is a known constant — comparing against it would be a gate
    // in name only. Sent back so the UI can raise the provider sheet instead.
    if (user.passwordHash === SOCIAL_ONLY_PASSWORD_SENTINEL) {
      throw new Error(ERR_USE_SOCIAL);
    }

    // Shares the LOGIN bucket rather than owning one, so this cannot be used as
    // a password-guessing oracle that sidesteps the login limiter.
    const key = loginKey(user._id);
    await assertNotLocked(ctx, key);
    if (user.passwordHash !== passwordHash) {
      await noteFailure(ctx, key);
      throw new Error("WRONG_PASSWORD");
    }
    await clearFailures(ctx, key);

    // Same transaction as the check above — a mutation calling a mutation does
    // not open a second one — so the proof and the rename commit or fail as one.
    return await ctx.runMutation(internal.users.applyUsernameChange, {
      userId,
      username,
    });
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
      .withIndex("by_room_user", (q: any) => q.eq("roomId", roomId))
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
    // Bookmarks OTHER people put on this user's messages. The message row is
    // about to go, so these would dangle exactly as the pins above would.
    await deleteRows(
      ctx,
      await ctx.db
        .query("messageBookmarks")
        .withIndex("by_message", (q: any) => q.eq("messageId", msg._id))
        .collect(),
    );
    // Refcounted: somebody else may have forwarded this message's file into a
    // room that has nothing to do with this account. See `releaseMessageBlobs`.
    await releaseMessageBlobs(ctx, msg);
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

  // Bookmarks this user put on other people's messages. Same shape as the pins
  // directly overhead, and the only reason `messageBookmarks.by_user` exists.
  //
  // The policy the pins comment sets out is deliberately NOT copied. A pin is
  // room state, so it survives its author walking out of a group and only the
  // user row vanishing takes it. A bookmark is that user's own private mark, so
  // it dies whenever their access does — `rooms:leave` sweeps it too, and this
  // is only the tail of that same rule for the rooms they never left.
  await deleteRows(
    ctx,
    await ctx.db
      .query("messageBookmarks")
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

  // ── Feed board ───────────────────────────────────────────────────────────
  // Moments last, after their children, so a failure part-way through never
  // leaves reactions or view records pointing at a row that is already gone.
  // Blobs are released explicitly: `deleteRows` only removes documents, and a
  // moment's media would otherwise survive as an invisible billed orphan that
  // `gcOrphanedFiles` cannot attribute to anyone.
  await deleteRows(
    ctx,
    await ctx.db
      .query("momentReactions")
      .withIndex("by_user", byUser(userId))
      .collect(),
  );
  await deleteRows(
    ctx,
    await ctx.db
      .query("momentViews")
      .withIndex("by_viewer", (q: any) => q.eq("viewerId", userId))
      .collect(),
  );
  const moments = await ctx.db
    .query("moments")
    .withIndex("by_user", byUser(userId))
    .collect();
  for (const m of moments) {
    // Reactions and views left by OTHER people on this user's moments — the
    // by_user/by_viewer sweeps above only caught the ones this user authored.
    for (const r of await ctx.db
      .query("momentReactions")
      .withIndex("by_moment", (q: any) => q.eq("momentId", m._id))
      .collect()) {
      await ctx.db.delete(r._id);
    }
    for (const vw of await ctx.db
      .query("momentViews")
      .withIndex("by_moment", (q: any) => q.eq("momentId", m._id))
      .collect()) {
      await ctx.db.delete(vw._id);
    }
    await deleteStored(ctx, m.mediaStorageId);
    await deleteStored(ctx, m.posterStorageId);
  }
  await deleteRows(ctx, moments);
  await deleteRows(
    ctx,
    await ctx.db
      .query("puzzleResults")
      .withIndex("by_user", byUser(userId))
      .collect(),
  );
  // `by_user_day_game`'s leading field is userId, so its prefix is the
  // teardown index — no second index exists purely to be deleted through.
  await deleteRows(
    ctx,
    await ctx.db
      .query("gameResults")
      .withIndex("by_user_day_game", byUser(userId))
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

  // ── Social identities ────────────────────────────────────────────────────
  // Missing these would be worse than untidy: the (provider, subject) row is
  // what `socialAuth.signIn` looks up, so an orphan left pointing at a deleted
  // user would let that Apple ID sign straight into a ghost account — and would
  // also block the same person from ever creating a fresh one.
  //
  // Apple additionally requires that deleting the account revokes the grant
  // (5.1.1(v) / TN3194). Revocation needs `fetch`, which a mutation cannot do,
  // so it is SCHEDULED — and the token is passed by value because the row it
  // came from is deleted in this same transaction.
  const identities = await ctx.db
    .query("socialIdentities")
    .withIndex("by_user", byUser(userId))
    .collect();
  for (const identity of identities) {
    if (identity.appleRefreshToken) {
      await ctx.scheduler.runAfter(0, internal.socialAuth.revokeAppleGrant, {
        refreshToken: identity.appleRefreshToken,
      });
    }
  }
  await deleteRows(ctx, identities);

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

  // Problem reports, tombstoned for a different reason than moderation ones:
  // the row is the rate-limit ledger keyed on `deviceId`, so deleting it would
  // hand anyone a way to reset their own throttle by deleting an account. The
  // delivered chat message is not touched here either — it lives in the log
  // account's DM and is a bug report about the app, not personal data about
  // whoever happened to file it.
  const problems = await ctx.db
    .query("problemReports")
    .withIndex("by_reporter", (q: any) => q.eq("reporterId", userId))
    .collect();
  for (const p of problems) {
    await ctx.db.patch(p._id, { reporterId: undefined });
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
