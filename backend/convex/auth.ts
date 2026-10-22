import { internalMutation, mutation as rawMutation } from "./_generated/server";
import {  mutation, publicMutation, query  } from "./functions";
import {
  ERR_SESSION_REVOKED,
  mintSession,
  requireSession,
  revokeOtherSessions,
  revokeSessionsForDevice,
} from "./sessionCore";
import { v } from "convex/values";
import { internal } from "./_generated/api";
import {
  ACCOUNT_CHILD,
  ERR_LAST_GUARDIAN,
  ERR_MUST_PAIR,
  ERR_NOT_ALLOWED,
} from "./childGuard";
import {
  SOCIAL_ONLY_PASSWORD_SENTINEL,
  ERR_USE_SOCIAL,
  assertNoCaseTwin,
  normaliseUsername,
} from "./socialAuth";
import {
  ERR_DISPLAY_NAME_RESERVED,
  ERR_USERNAME_RESERVED,
  isReservedName,
} from "./systemAccount";
import { assertCleanName } from "./contentFilter";
import { termsStamp } from "./terms";
import { searchNameOf } from "./userSearch";
import {
  assertNotLocked,
  clearFailures,
  loginKey,
  noteFailure,
  recoveryKey,
  MAX_RECOVERY_FAILURES,
  refusal,
  throttleSignup,
} from "./rateLimit";
import { isRetiredHandle } from "./retiredHandles";
import { enqueueDeletion, getLiveUser, isTombstoned, startUserDeletion } from "./deletionCore";
import { hashPassword, upgradeIfLegacy, verifyPassword } from "./passwords";

/** A guardian supervises a handful of children, a child has a few guardians. */
const MAX_SUPERVISED = 100;
const MAX_GUARDIANS_PER_CHILD = 20;

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
  returns: v.union(
    v.object({
      userId: v.id("users"),
      username: v.string(),
      name: v.string(),
      accountType: v.string(),
    }),
    v.null(),
  ),
  handler: async (ctx, { userId }) => {
    const user = await ctx.db.get(userId);
    // Unreachable: `requireSession` already refuses a token whose account is
    // gone. Kept because the alternative to a thrown error here is a silent
    // `null` that the client would file under "offline" — the exact failure
    // mode this function exists to end.
    if (!user) throw new Error(ERR_SESSION_REVOKED);
    // An account being deleted (tombstoned) is already gone to everyone else.
    // `requireSession` refuses its sessions first, so this is the belt to that
    // pair of braces.
    if (isTombstoned(user)) return null;
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
    // Per-install secret (64 hex chars) proving this really is the install
    // that owns `deviceId`; see `sessionCore.mintSession`. Optional so older
    // builds keep signing in.
    deviceSecret: v.optional(v.string()),
    // The EULA version the user ticked the box for. Optional only so old
    // builds can still sign up — see the compatibility note in `terms.ts`.
    termsVersion: v.optional(v.number()),
  },
  handler: async (
    ctx,
    {
      username: rawUsername,
      name,
      passwordHash,
      recoveryKeyHash,
      email,
      deviceId,
      deviceSecret,
      termsVersion,
    },
  ) => {
    let username = rawUsername;
    // Before anything else: a present-but-stale version is a refusal.
    const terms = termsStamp(termsVersion);
    // Same handle rules as social signup and rename, which this path skipped.
    username = normaliseUsername(username);
    await assertNoCaseTwin(ctx, username);
    await throttleSignup(ctx, deviceId);
    // Reserved handles — anything reading as the brand, not just the exact
    // system names. Checked before the collision test so the answer does not
    // depend on whether a system account happens to exist yet: they are created
    // lazily, so until the first problem report the handle is simply free, and
    // whoever took it would own the name every report is posted from.
    if (isReservedName(username) || (await isRetiredHandle(ctx, username))) {
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
      searchName: searchNameOf(username, name),
      passwordHash: await hashPassword(passwordHash),
      recoveryKeyHash,
      email,
      createdAt: Date.now(),
      status: "online",
      lastSeen: Date.now(),
      ...terms,
    });
    return { userId, username, name, token: await mintSession(ctx, userId, deviceId, deviceSecret) };
  },
});

export const login = publicMutation({
  args: {
    username: v.string(),
    passwordHash: v.string(),
    deviceId: v.string(),
    // Per-install secret (64 hex chars) proving this really is the install
    // that owns `deviceId`; see `sessionCore.mintSession`. Optional so older
    // builds keep signing in.
    deviceSecret: v.optional(v.string()),
  },
  handler: async (ctx, { username, passwordHash, deviceId, deviceSecret }) => {
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
    if (!(await verifyPassword(user.passwordHash, passwordHash))) {
      await noteFailure(ctx, key);
      return refusal("WRONG_PASSWORD");
    }
    await clearFailures(ctx, key);
    await upgradeIfLegacy(ctx, user, passwordHash);

    await ctx.db.patch(user._id, { status: "online", lastSeen: Date.now() });
    return {
      userId: user._id,
      username: user.username,
      name: user.name ?? user.username,
      token: await mintSession(ctx, user._id, deviceId, deviceSecret),
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
    // Per-install secret (64 hex chars) proving this really is the install
    // that owns `deviceId`; see `sessionCore.mintSession`. Optional so older
    // builds keep signing in.
    deviceSecret: v.optional(v.string()),
  },
  handler: async (
    ctx,
    {
      username,
      recoveryKeyHash,
      legacyRecoveryKeyHash,
      newPasswordHash,
      deviceId,
      deviceSecret,
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
      return refusal("INVALID_RECOVERY_KEY");
    }
    await clearFailures(ctx, key);

    await ctx.db.patch(user._id, {
      passwordHash: await hashPassword(newPasswordHash),
      status: "online",
      lastSeen: Date.now(),
    });
    // A reset is what someone does when they think the password is known to
    // somebody else, so every other signed-in device goes with it.
    await revokeOtherSessions(ctx, user._id, deviceId);
    // `name` is not optional for the client: AuthResult.fromJson does
    // `j['name'].toString()`, so omitting it here wrote the literal string
    // "null" into the keychain as the user's display name on every reset.
    // Matches the shape `login` returns above.
    return {
      userId: user._id,
      username: user.username,
      name: user.name ?? user.username,
      token: await mintSession(ctx, user._id, deviceId, deviceSecret),
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
    if (!(await verifyPassword(user.passwordHash, passwordHash))) {
      await noteFailure(ctx, key);
      return refusal("WRONG_PASSWORD");
    }
    await clearFailures(ctx, key);
    await upgradeIfLegacy(ctx, user, passwordHash);

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
  returns: v.union(
    v.object({ username: v.string() }),
    v.object({ __refused: v.string() }),
  ),
  // Annotated to break a self-referential inference cycle: this handler calls
  // through `internal.users.applyUsernameChange`, and the generated api type
  // covers this module too — so inferring the return type needs the return
  // type. TypeScript gives up and makes the mutation `any`, which is worse
  // than it sounds: `any` is what every CALLER then sees. The type restates
  // the `returns:` validator directly above, so the two cannot drift.
  handler: async (
    ctx,
    { userId, passwordHash, username },
  ): Promise<{ username: string } | { __refused: string }> => {
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
    if (!(await verifyPassword(user.passwordHash, passwordHash))) {
      await noteFailure(ctx, key);
      return refusal("WRONG_PASSWORD");
    }
    await clearFailures(ctx, key);
    await upgradeIfLegacy(ctx, user, passwordHash);

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
 *
 * Refuses while this user is any child's ONLY guardian: purging them would
 * delete the last guardianship and leave a child nobody can pair, release or
 * delete again. A guardian has to add another one (or graduate or delete the
 * child) first. `family.unlinkChild` enforces the same rule.
 *
 * Built on the RAW mutation builder, on purpose, and the only function here
 * that is. A suspended account has the right to delete its own data, and the
 * wrapper's `requireSession` refuses a suspended account with
 * ACCOUNT_SUSPENDED before any handler runs. The exception lives in
 * `requireSession`'s `allowSuspended` option and this is its only caller, so
 * every other function stays blocked for a suspended user. The identity still
 * comes from the session token alone; `userId` is accepted (the client sends
 * it) and ignored. `sessionToken` is declared on the args line itself because
 * the wrapper would have injected it.
 */
export const deleteAccount = rawMutation({
  args: { userId: v.id("users"), sessionToken: v.string() },
  handler: async (ctx, { sessionToken }) => {
    const userId = await requireSession(ctx, sessionToken, {
      allowSuspended: true,
    });
    const user = await ctx.db.get(userId);
    if (user?.accountType === ACCOUNT_CHILD) throw new Error(ERR_NOT_ALLOWED);

    const supervising = await ctx.db
      .query("guardianships")
      .withIndex("by_guardian", (q) => q.eq("guardianId", userId))
      .take(MAX_SUPERVISED);
    for (const link of supervising) {
      // Guardianship rows go in the background when an account is deleted, so a
      // row alone proves nothing: count only guardians who are still live. A
      // co-guardian's stuck deletion must not block this one, and two
      // co-guardians must not both leave the child with nobody.
      const guardians = await ctx.db
        .query("guardianships")
        .withIndex("by_child", (q) => q.eq("childId", link.childId))
        .take(MAX_GUARDIANS_PER_CHILD);
      let others = 0;
      for (const g of guardians) {
        if (g.guardianId === userId) continue;
        if (await getLiveUser(ctx, g.guardianId)) others++;
      }
      if (others === 0) throw new Error(ERR_LAST_GUARDIAN);
    }

    await startUserDeletion(ctx, userId, { reason: "self" });
  },
});

/**
 * The teardown itself, callable from other modules. Split out of
 * `deleteAccount` so `family.deleteChildAccount` doesn't have to duplicate it.
 *
 * Starts the deletion (`deletionCore.startUserDeletion`: scrub the row, revoke
 * sessions, queue the job) and returns; the lifecycle engine finishes it in
 * bounded slices, the user row last (`deletionSteps/userSteps.ts`).
 */
export const purgeAccount = internalMutation({
  args: { userId: v.id("users") },
  handler: async (ctx, { userId }) => {
    await startUserDeletion(ctx, userId, { reason: "guardian" });
  },
});

/**
 * Shim for one release: the old teardown scheduled this to finish a removed
 * account's messages, so a job already in the queue names it. The account row
 * is gone by then; the engine's user plan finishes the messages (and anything
 * else left) by id. Delete once nothing is scheduled.
 */
export const purgeMessagesLater = internalMutation({
  args: { userId: v.id("users") },
  handler: async (ctx, { userId }) => {
    // A live account is not this shim's to touch (an id reused by mistake).
    const row = await ctx.db.get(userId);
    if (row && !isTombstoned(row)) return;
    await enqueueDeletion(ctx, {
      kind: "user",
      targetId: userId,
      reason: "legacy",
    });
  },
});
