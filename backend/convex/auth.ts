import { internalMutation } from "./_generated/server";
import {  mutation, publicMutation, query  } from "./functions";
import {
  ERR_SESSION_REVOKED,
  mintSession,
  revokeSessionsForDevice,
} from "./sessionCore";
import { v } from "convex/values";
import { internal } from "./_generated/api";
import { ACCOUNT_CHILD, ERR_MUST_PAIR, ERR_NOT_ALLOWED } from "./childGuard";
import { SOCIAL_ONLY_PASSWORD_SENTINEL, ERR_USE_SOCIAL } from "./socialAuth";
import { wipeRoomCompletely } from "./roomCleanup";
import { purgeSpeakerColorsForUser } from "./speakerColors";
import { ensureOwner } from "./roomAdmin";
import { purgeScheduledForUser } from "./scheduledMessages";
import { purgeRecordsOf } from "./recordBook";
import { leaveMatchesInRoom, purgeChallengesOfUser } from "./matchCore";
import {
  ERR_DISPLAY_NAME_RESERVED,
  ERR_USERNAME_RESERVED,
  isReservedName,
} from "./systemAccount";
import { deleteStored } from "./files";
import { assertCleanName } from "./contentFilter";
import { termsStamp } from "./terms";
import { removeMessageAndFanout } from "./messages";
import { purgeUserExpressions } from "./expressions";
import { purgeMomentComments, purgeUserComments } from "./momentComments";
import {
  assertNotLocked,
  clearFailures,
  loginKey,
  noteFailure,
  recoveryKey,
  MAX_RECOVERY_FAILURES,
} from "./rateLimit";

/**
 * Who the caller actually is, resolved from the bearer token alone.
 *
 * The client has never had a way to ask this. Its identity at launch comes
 * entirely from the keychain, and the keychain holds the token and the
 * username as separate items — so a half-finished write leaves a device
 * carrying one account's token next to another account's name, and every
 * screen renders the name. `functions.ts` overwrites the client-supplied id
 * with the token's, so such a device operates correctly and displays wrongly,
 * forever, because nothing ever compares the two.
 *
 * This is that comparison's other half. Takes no arguments on purpose: an
 * argument is a thing a confused client could get wrong, and the entire point
 * is to trust nothing it says about itself.
 *
 * Session loss surfaces the usual way — `requireSession` throws before the
 * handler runs, and `SessionGuard` turns it into a sign-out.
 */
export const whoami = query({
  args: {},
  returns: v.object({
    userId: v.id("users"),
    username: v.string(),
    name: v.string(),
    accountType: v.string(),
  }),
  handler: async (ctx, { userId }) => {
    const user = await ctx.db.get(userId);
    // Unreachable: `requireSession` already refuses a token whose account is
    // gone. Kept because the alternative to a thrown error here is a silent
    // `null` that the client would file under "offline" — the exact failure
    // mode this function exists to end.
    if (!user) throw new Error(ERR_SESSION_REVOKED);
    return {
      userId: user._id,
      username: user.username,
      name: user.name ?? user.username,
      accountType: user.accountType ?? "adult",
    };
  },
});

export const signup = publicMutation({
  args: {
    username: v.string(),
    name: v.string(),
    passwordHash: v.string(),
    recoveryKeyHash: v.optional(v.string()),
    email: v.optional(v.string()),
    // Which device this session belongs to. Required: a session that is not
    // tied to a device cannot be shown in the Devices list or revoked from it,
    // which is the whole reason sessions exist here.
    deviceId: v.string(),
    // The EULA version the user ticked the box for. Optional only so old
    // builds can still sign up — see the compatibility note in `terms.ts`.
    termsVersion: v.optional(v.number()),
  },
  handler: async (
    ctx,
    { username, name, passwordHash, recoveryKeyHash, email, deviceId, termsVersion },
  ) => {
    // Before anything else: a present-but-stale version is a refusal.
    const terms = termsStamp(termsVersion);
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
    // The objectionable-word filter, on both names. See `contentFilter.ts`.
    assertCleanName(username);
    assertCleanName(name);

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
      ...terms,
    });
    return { userId, username, name, token: await mintSession(ctx, userId, deviceId) };
  },
});

export const login = publicMutation({
  args: {
    username: v.string(),
    passwordHash: v.string(),
    deviceId: v.string(),
  },
  handler: async (ctx, { username, passwordHash, deviceId }) => {
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
    return {
      userId: user._id,
      username: user.username,
      name: user.name ?? user.username,
      token: await mintSession(ctx, user._id, deviceId),
    };
  },
});

export const logout = mutation({
  // The device signing itself out, so its session can be revoked rather than
  // left live for anyone holding the token.
  args: { deviceId: v.string() },
  handler: async (ctx, { userId, deviceId }) => {
    await revokeSessionsForDevice(ctx, userId, deviceId);
    // And its push row, which is the OTHER half of signing out and used to be
    // somebody else's job entirely: the client called this to end the session
    // and `voipTokens.clearDeviceToken` to drop the row, both after clearing
    // its own token, so both were rejected and the handset kept receiving
    // notifications for the account it had just left. Doing it here means one
    // surviving call is enough — the two are now the same operation from
    // either end, and each is a no-op once the other has run.
    const device = await ctx.db
      .query("userDevices")
      .withIndex("by_user_device", (q: any) =>
        q.eq("userId", userId).eq("deviceId", deviceId),
      )
      .first();
    if (device) await ctx.db.delete(device._id);
    await ctx.db.patch(userId, { status: "offline", lastSeen: Date.now() });
  },
});

export const resetPasswordWithRecoveryKey = publicMutation({
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
    // Reset signs the account straight back in, so it mints like any other
    // entry point — without this the client would hold a session with no
    // token and be signed out again on its very next request.
    deviceId: v.string(),
  },
  handler: async (
    ctx,
    {
      username,
      recoveryKeyHash,
      legacyRecoveryKeyHash,
      newPasswordHash,
      deviceId,
    },
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
      token: await mintSession(ctx, user._id, deviceId),
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
  // Annotated to break a self-referential inference cycle: this handler calls
  // through `internal.users.applyUsernameChange`, and the generated api type
  // covers this module too — so inferring the return type needs the return
  // type. TypeScript gives up and makes the mutation `any`, which is worse
  // than it sounds: `any` is what every CALLER then sees. The type restates
  // the `returns:` validator directly above, so the two cannot drift.
  handler: async (
    ctx,
    { userId, passwordHash, username },
  ): Promise<{ username: string }> => {
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

  // "Beat my time" bodies this account sent, wherever they were sent.
  await purgeChallengesOfUser(ctx, userId);

  // ── Rooms ────────────────────────────────────────────────────────────────
  const memberships = await ctx.db
    .query("roomMembers")
    .withIndex("by_user", byUser(userId))
    .collect();

  for (const membership of memberships) {
    const roomId = membership.roomId;
    await ctx.db.delete(membership._id);
    // Before the room can be wiped below: forfeiting writes to the games.
    await leaveMatchesInRoom(ctx, roomId, userId);

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

    await ctx.db.patch(roomId, patch);

    // The owner SEAT, not `rooms.createdBy`, is what would otherwise be left
    // pointing at a deleted user — and a room with no owner is frozen for
    // everyone still in it: nobody can rename it, delete it, or demote a rogue
    // admin, and no screen anywhere can repair that.
    //
    // `ensureOwner` is the same re-seating that runs when an owner simply
    // leaves, and it prefers the longest-standing ADMIN over the
    // longest-standing member — people the departing owner had already
    // trusted. It drags `createdBy` along so that record keeps naming somebody
    // who is actually still here; it grants nothing either way.
    await ensureOwner(ctx, roomId, remaining);
  }

  // ── Messages this user sent in rooms that survived ───────────────────────
  const userMessages = await ctx.db
    .query("messages")
    .withIndex("by_user", byUser(userId))
    .collect();
  // Through the same per-message teardown every other delete path uses
  // (`messages.removeMessageAndFanout`): reactions and pins and bookmarks
  // OTHER people put on these messages, the refcounted media, the view-once
  // ledger, a posed poll's answers, a game's card taking its game (and the
  // other player's move bubbles) with it, reply tethers, and the room preview.
  //
  // Re-read first: a game card earlier in this list takes its move bubbles
  // with it, and some of those may be this user's own, still in the list.
  // A second delete of one id throws.
  for (const msg of userMessages) {
    const live = await ctx.db.get(msg._id);
    if (!live) continue;
    await removeMessageAndFanout(ctx, live, msg._id);
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

  // Votes, ticks and RSVPs this user left on other people's polls, which
  // outlive the loop above. Same shape as the reactions case, and the only
  // reason `interactionResponses.by_user` exists.
  //
  // Note what this leaves behind, deliberately: the interaction rows those
  // answers belonged to keep their tallies until somebody next writes to them,
  // at which point `recount` derives the truth from the surviving rows. A sweep
  // that patched every affected poll here would be a fan-out over every room
  // this account ever voted in, to correct a number nobody is looking at — and
  // it could not be complete anyway, since the same drift already follows a
  // member simply leaving a room.
  await deleteRows(
    ctx,
    await ctx.db
      .query("interactionResponses")
      .withIndex("by_user", byUser(userId))
      .collect(),
  );

  // Manual speaker colours, both directions: the ones this user set, and the
  // ones other people set about them in rooms that outlive this account. The
  // second direction is why `speakerColors.by_subject` exists — the room pass
  // above only reaches rooms this user was still in.
  await purgeSpeakerColorsForUser(ctx, userId);

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

  // Messages this account had queued for later, in every room — including the
  // rooms that survived it above, which the room pass never touched. Not merely
  // a dangling row: each one still holds a live scheduler job that would wake up
  // days or months from now and post in a deleted person's name.
  //
  // Not `deleteRows`, because these carry a job that has to be cancelled with
  // them. See `purgeScheduledForUser`.
  await purgeScheduledForUser(ctx, userId);

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

  // ── Group invites ────────────────────────────────────────────────────────
  //
  // Every direction each table can point at this user. Missed rows here are
  // not cosmetic: a surviving `roomInvitations` row addressed to a deleted
  // account is a pending invite nobody can ever answer, and one SENT by a
  // deleted account still shows their name to the person deciding.
  //
  // The links this user issued go too. A live `roomInvites` row outliving its
  // creator is a working join token for a room, attributed to somebody who no
  // longer exists — the rooms themselves survive (they have other members, or
  // the loop above already wiped them), so the token would keep admitting
  // people with no admin able to explain where it came from.
  const invitationGroups = [];
  for (const status of ["pending", "accepted", "rejected", "cancelled"]) {
    invitationGroups.push(
      await ctx.db
        .query("roomInvitations")
        .withIndex("by_invitee_status", (q: any) =>
          q.eq("inviteeId", userId).eq("status", status),
        )
        .collect(),
    );
  }
  invitationGroups.push(
    await ctx.db
      .query("roomInvitations")
      .withIndex("by_inviter", (q: any) => q.eq("inviterId", userId))
      .collect(),
  );
  await deleteRows(ctx, ...invitationGroups);

  await deleteRows(
    ctx,
    await ctx.db
      .query("roomJoinRequests")
      .withIndex("by_user", byUser(userId))
      .collect(),
    await ctx.db
      .query("roomJoinRequests")
      .withIndex("by_decider", (q: any) => q.eq("decidedBy", userId))
      .collect(),
  );

  await deleteRows(
    ctx,
    await ctx.db
      .query("roomInvites")
      .withIndex("by_creator", (q: any) => q.eq("createdBy", userId))
      .collect(),
  );

  // Suggestions this account made about a room's name, description or picture,
  // and the ones it ruled on — see `roomChangeRequests.ts`. Both directions,
  // for the same reason the invite tables above take both: a pending row
  // addressed to nobody is a queue item no admin can ever resolve, and a
  // decided row still names a person who no longer exists.
  //
  // The blob is released for PENDING rows ONLY, and that distinction is
  // load-bearing rather than tidy. A pending proposal's file is referenced by
  // nothing else, so it must go. An APPROVED one's file is the room's live
  // avatar — the room survives this account, and freeing that blob would leave
  // a group everybody is still in with a broken picture.
  const proposals = [
    ...(await ctx.db
      .query("roomChangeRequests")
      .withIndex("by_user", byUser(userId))
      .collect()),
    ...(await ctx.db
      .query("roomChangeRequests")
      .withIndex("by_decider", (q: any) => q.eq("decidedBy", userId))
      .collect()),
  ];
  for (const row of proposals) {
    if (row.status === "pending" && row.storageId) {
      await deleteStored(ctx, row.storageId);
    }
  }
  await deleteRows(ctx, proposals);
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
  // What they said under other people's highlights, and their reactions to
  // comments. Their own moments' conversations go with the moments below.
  await purgeUserComments(ctx, userId);
  // Their personal stickers are cut out of their own photos, so they go with
  // the account — rows and blobs — along with their recents and favourites.
  await purgeUserExpressions(ctx, userId);
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
    await purgeMomentComments(ctx, m._id);
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
  // All-time records: theirs, the reactions on them, and the reactions they
  // left on everybody else's.
  await purgeRecordsOf(ctx, userId);

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
  // Device-login requests (QR / short-code sign-in for web and desktop) this
  // user approved from their phone. An unapproved row belongs to no account
  // there is to purge — it's reaped by its own short expiry instead; see
  // deviceLogin.gcExpiredDeviceLoginRequests.
  await deleteRows(
    ctx,
    await ctx.db
      .query("deviceLoginRequests")
      .withIndex("by_approver", (q: any) => q.eq("approvedByUserId", userId))
      .collect(),
  );

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

  // ── Sessions ─────────────────────────────────────────────────────────────
  // The one omission that let a deleted account keep signing in. `sessions`
  // landed after this teardown was written, so every purge before this line
  // existed left a live bearer token pointing at a row that was about to
  // vanish — and `requireSession` handed that dangling id straight to callers.
  //
  // REVOKED rather than deleted, so the device's next call gets the honest
  // SESSION_REVOKED ("you were signed out") instead of SESSION_UNKNOWN, and so
  // `gcRevokedSessions` collects the rows on the schedule it already owns
  // rather than this becoming a second disposal path.
  const now = Date.now();
  for (const row of await ctx.db
    .query("sessions")
    .withIndex("by_user", byUser(userId))
    .collect()) {
    if (row.revokedAt === undefined) {
      await ctx.db.patch(row._id, { revokedAt: now });
    }
  }

  // ── Group calls ──────────────────────────────────────────────────────────
  // Same class of omission as `sessions`: three tables carrying `v.id("users")`
  // that arrived after this teardown was written.
  //
  // Only the indexed edges are swept. `groupCallSignals.fromUserId` and
  // `groupCalls.startedBy` have no index, and unlike `rooms.createdBy` — which
  // must be re-seated because a room outlives everyone in it — both belong to
  // a record that is already ephemeral: `gcTerminalGroupCalls` reaps ended
  // calls and `gcConsumedSignals` their signals, so a dangling id there has a
  // bounded life and nothing reads it for authorization. A purge-only full
  // table scan to beat the sweep to it is the worse trade.
  await deleteRows(
    ctx,
    await ctx.db
      .query("groupCallParticipants")
      .withIndex("by_user_status", (q: any) => q.eq("userId", userId))
      .collect(),
  );
  await deleteRows(
    ctx,
    await ctx.db
      .query("groupCallSignals")
      .withIndex("by_to_unconsumed", (q: any) => q.eq("toUserId", userId))
      .collect(),
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
