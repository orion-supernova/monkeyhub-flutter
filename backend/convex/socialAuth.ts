/**
 * Sign in with Apple / Google.
 *
 * Deliberately NOT a new auth model. Every function here ends by returning the
 * same `{userId, username, name}` tuple `auth.login` and
 * `family.redeemPairingCode` already return, so the client's session plumbing is
 * identical for all three paths and no existing backend signature changes. The
 * `userId`-as-argument trust model is untouched — fixing that is its own project
 * (see ACCOUNT_LIFECYCLE_AUDIT.md §8), and coupling it to a feature launch would
 * fork the authorization story across 89 call sites mid-flight.
 *
 * ADULTS ONLY, and not by preference: Apple does not permit Sign in with Apple
 * for under-13 Child Accounts at all, and Google's User Data Policy says the
 * same for child-directed apps. Children keep guardian-issued pairing codes,
 * which is also the right product answer — a child binding their own external
 * identity would route around guardianship.
 *
 * The two-step shape (`signIn` may answer `needsUsername`, then
 * `completeSignUp`) exists because Apple/Google give us a subject and maybe an
 * email, but this app's public identity is a user-chosen `username`. Rather than
 * mint a claim ticket the client could forge, `completeSignUp` simply re-verifies
 * the same ID token — stateless, and no extra table.
 */

import {
  action,
  mutation,
  query,
  internalAction,
  internalMutation,
  internalQuery,
} from "./_generated/server";
import { v } from "convex/values";
import { internal } from "./_generated/api";
import { ACCOUNT_CHILD, ERR_MUST_PAIR } from "./childGuard";
import { verifyIdToken, PROVIDER_APPLE, type Provider } from "./idToken";
import {
  exchangeAuthorizationCode,
  revokeRefreshToken,
  refreshTokenStillValid,
} from "./appleTokens";
import { assertNotLocked, clearFailures, loginKey, noteFailure } from "./rateLimit";

/**
 * Parked in `users.passwordHash`, which is non-optional, for accounts that have
 * only ever signed in with a provider. Exactly the trick child accounts use
 * (`family.ts CHILD_PASSWORD_SENTINEL`), and safe for the same reason: a real
 * stored value is always a 64-char hex SHA-256, so no password can ever hash to
 * this literal.
 */
export const SOCIAL_ONLY_PASSWORD_SENTINEL = "__SOCIAL_NO_PASSWORD__";

/** Told to a user whose account has no password, so the UI can point at the right button. */
export const ERR_USE_SOCIAL = "USE_SOCIAL_SIGN_IN";
export const ERR_ALREADY_LINKED = "SOCIAL_ALREADY_LINKED";
export const ERR_LINKED_ELSEWHERE = "SOCIAL_LINKED_TO_OTHER_ACCOUNT";
export const ERR_NOT_LINKED = "SOCIAL_NOT_LINKED";
export const ERR_LAST_CREDENTIAL = "SOCIAL_LAST_CREDENTIAL";

const providerValidator = v.union(v.literal("apple"), v.literal("google"));

/** Once a day per identity is well inside what Apple's TN3194 contemplates. */
const APPLE_REFRESH_CHECK_INTERVAL_MS = 24 * 60 * 60 * 1000;

const authResultValidator = v.object({
  status: v.literal("signedIn"),
  userId: v.id("users"),
  username: v.string(),
  name: v.string(),
  accountType: v.string(),
});

const signInResultValidator = v.union(
  authResultValidator,
  v.object({
    status: v.literal("needsUsername"),
    suggestedName: v.optional(v.string()),
    email: v.optional(v.string()),
  }),
);

/** Max 32 chars mirrors the client's own signup validation. */
function normaliseUsername(raw: string): string {
  const username = raw.trim();
  if (username.length === 0 || username.length > 32) {
    throw new Error("USERNAME_INVALID");
  }
  return username;
}

/**
 * Apple only, and only worth attempting when we don't already hold one. Never
 * throws — see the module comment in appleTokens.ts for why capture failure must
 * not fail a sign-in.
 */
async function captureAppleRefresh(
  provider: Provider,
  authorizationCode: string | undefined,
): Promise<string | undefined> {
  if (provider !== PROVIDER_APPLE || !authorizationCode) return undefined;
  return (await exchangeAuthorizationCode(authorizationCode)) ?? undefined;
}

// ────────────────────────────── public actions ──────────────────────────────

/**
 * Verify a provider token and either sign the user in or ask for a username.
 *
 * An ACTION rather than a mutation because verification fetches the provider's
 * JWKS, and only actions can `fetch`.
 */
export const signIn = action({
  args: {
    provider: providerValidator,
    idToken: v.string(),
    rawNonce: v.optional(v.string()),
    // Apple only. Apple returns a fresh one on every authorization, but this
    // app's sessions never expire, so a user who signs in once may never present
    // another — capture it whenever it shows up.
    authorizationCode: v.optional(v.string()),
    // Apple only, and ONLY on the very first authorization for this Apple ID.
    // Never sent again, by anyone, ever. Used purely to prefill the username step.
    fullName: v.optional(v.string()),
  },
  returns: signInResultValidator,
  handler: async (ctx, args) => {
    const identity = await verifyIdToken(args.provider, args.idToken, args.rawNonce);

    const existing = await ctx.runQuery(internal.socialAuth.findIdentity, {
      provider: identity.provider,
      subject: identity.subject,
    });

    if (!existing) {
      return {
        status: "needsUsername" as const,
        suggestedName: args.fullName,
        email: identity.email,
      };
    }

    const appleRefreshToken = existing.hasAppleRefreshToken
      ? undefined
      : await captureAppleRefresh(args.provider, args.authorizationCode);

    return await ctx.runMutation(internal.socialAuth.touchIdentity, {
      identityId: existing.identityId,
      email: identity.email,
      isPrivateRelay: identity.isPrivateRelay,
      appleRefreshToken,
    });
  },
});

/**
 * Second half of a first-time social sign-up: create the account.
 *
 * Re-verifies the SAME token rather than trusting a handle from `signIn`. Apple
 * ID tokens live 24h and Google's an hour, so there is ample room for a user to
 * pick a username.
 */
export const completeSignUp = action({
  args: {
    provider: providerValidator,
    idToken: v.string(),
    rawNonce: v.optional(v.string()),
    authorizationCode: v.optional(v.string()),
    username: v.string(),
    name: v.optional(v.string()),
  },
  returns: authResultValidator,
  handler: async (ctx, args) => {
    const identity = await verifyIdToken(args.provider, args.idToken, args.rawNonce);
    const appleRefreshToken = await captureAppleRefresh(
      args.provider,
      args.authorizationCode,
    );

    return await ctx.runMutation(internal.socialAuth.createWithIdentity, {
      provider: identity.provider,
      subject: identity.subject,
      email: identity.email,
      isPrivateRelay: identity.isPrivateRelay,
      username: args.username,
      name: args.name,
      appleRefreshToken,
    });
  },
});

/**
 * Attaches a provider to an account proved with username + password, and signs
 * in. The path for "I already have an account".
 *
 * This is the most common real-world first tap of a provider button by a long
 * way — an existing user of months tapping "Continue with Apple" — and its
 * absence was a dead end: they reached the username step, found their own
 * username taken, and had nowhere to go.
 *
 * Distinct from [link] because the caller is NOT signed in here and has no
 * `userId` to offer; the username is the lookup and the password is the proof.
 */
export const linkExistingAccount = action({
  args: {
    provider: providerValidator,
    idToken: v.string(),
    rawNonce: v.optional(v.string()),
    authorizationCode: v.optional(v.string()),
    username: v.string(),
    passwordHash: v.string(),
  },
  returns: authResultValidator,
  handler: async (ctx, args) => {
    const identity = await verifyIdToken(args.provider, args.idToken, args.rawNonce);
    const appleRefreshToken = await captureAppleRefresh(
      args.provider,
      args.authorizationCode,
    );
    return await ctx.runMutation(internal.socialAuth.attachToExistingAccount, {
      username: args.username,
      passwordHash: args.passwordHash,
      provider: identity.provider,
      subject: identity.subject,
      email: identity.email,
      isPrivateRelay: identity.isPrivateRelay,
      appleRefreshToken,
    });
  },
});

/**
 * Attach a provider to an EXISTING account, from Profile.
 *
 * Password-gated for the same reason `auth.setRecoveryKey` is: without it, this
 * would be a complete account-takeover primitive — anyone who learned a `userId`
 * could bolt their own Apple ID onto that account and then sign in as it. The
 * password is the only credential available here, so the password is the gate.
 */
export const link = action({
  args: {
    userId: v.id("users"),
    passwordHash: v.string(),
    provider: providerValidator,
    idToken: v.string(),
    rawNonce: v.optional(v.string()),
    authorizationCode: v.optional(v.string()),
  },
  returns: v.null(),
  handler: async (ctx, args) => {
    const identity = await verifyIdToken(args.provider, args.idToken, args.rawNonce);
    const appleRefreshToken = await captureAppleRefresh(
      args.provider,
      args.authorizationCode,
    );

    await ctx.runMutation(internal.socialAuth.attachIdentity, {
      userId: args.userId,
      passwordHash: args.passwordHash,
      provider: identity.provider,
      subject: identity.subject,
      email: identity.email,
      isPrivateRelay: identity.isPrivateRelay,
      appleRefreshToken,
    });
    return null;
  },
});

/**
 * Detach a provider. Password-gated like `link`, and refuses to strand the
 * account: an account whose only credential is the identity being removed would
 * become unreachable forever, since there is no email and therefore no reset
 * mail.
 */
export const unlink = mutation({
  args: {
    userId: v.id("users"),
    passwordHash: v.string(),
    provider: providerValidator,
  },
  returns: v.null(),
  handler: async (ctx, { userId, passwordHash, provider }) => {
    const user = await ctx.db.get(userId);
    if (!user) throw new Error("USER_NOT_FOUND");
    if (user.accountType === ACCOUNT_CHILD) throw new Error(ERR_MUST_PAIR);

    // Shares the LOGIN bucket rather than owning one, so this cannot be used as
    // a password-guessing oracle that sidesteps the login limiter.
    const key = loginKey(user._id);
    await assertNotLocked(ctx, key);
    if (user.passwordHash !== passwordHash) {
      await noteFailure(ctx, key);
      throw new Error("WRONG_PASSWORD");
    }
    await clearFailures(ctx, key);

    const rows = await ctx.db
      .query("socialIdentities")
      .withIndex("by_user", (q) => q.eq("userId", userId))
      .collect();
    const target = rows.find((r) => r.provider === provider);
    if (!target) throw new Error(ERR_NOT_LINKED);

    // A real password (not the sentinel) is itself a way back in, so it alone
    // satisfies this. Otherwise at least one other identity must remain.
    const hasPassword = user.passwordHash !== SOCIAL_ONLY_PASSWORD_SENTINEL;
    if (!hasPassword && rows.length <= 1) throw new Error(ERR_LAST_CREDENTIAL);

    await ctx.db.delete(target._id);
    return null;
  },
});

/**
 * Which providers this account has attached — drives the Profile rows.
 *
 * Deliberately does NOT return the provider email. Like every other function
 * here it takes `userId` as a client-supplied argument (the app-wide model), so
 * anyone who knows an id can call it — and `users.getProfile` goes to real
 * trouble with a self/guardian/friend visibility check before revealing far less
 * sensitive fields. Leaking "this account's Apple ID is x@y.com" to any caller
 * would be a step down from that bar. The provider name alone is enough to draw
 * the Profile row; the address is not needed to render "Apple · Linked".
 */
export const linkedProviders = query({
  args: { userId: v.id("users") },
  returns: v.array(
    v.object({
      provider: v.string(),
      createdAt: v.number(),
    }),
  ),
  handler: async (ctx, { userId }) => {
    const rows = await ctx.db
      .query("socialIdentities")
      .withIndex("by_user", (q) => q.eq("userId", userId))
      .collect();
    return rows.map((r) => ({
      provider: r.provider,
      createdAt: r.createdAt,
    }));
  },
});

// ───────────────────────────── internal plumbing ─────────────────────────────

/**
 * Revokes an Apple grant. Scheduled by `purgeUser` rather than called inline,
 * because revocation needs `fetch` and the teardown is a mutation.
 *
 * Takes the token by value, not a row id, precisely because the row is being
 * deleted in the same transaction that schedules this — by the time it runs
 * there is nothing left to read.
 *
 * Never throws. A failure here must not retry-loop a scheduled job forever, and
 * must never be able to block or undo an account deletion; the user's right to
 * delete outranks our ability to tell Apple about it. It is logged loudly so a
 * systematic failure (expired .p8, wrong key id) is visible in the logs.
 */
export const revokeAppleGrant = internalAction({
  args: { refreshToken: v.string() },
  returns: v.null(),
  handler: async (_ctx, { refreshToken }) => {
    const ok = await revokeRefreshToken(refreshToken);
    if (!ok) {
      console.error(
        "[socialAuth] Apple grant revocation failed for a deleted account. " +
          "The account is gone; the Apple grant may not be.",
      );
    }
    return null;
  },
});

/**
 * Apple TN3194 asks that stored refresh tokens be validated periodically rather
 * than only at deletion time, so that a grant the user revoked from their own
 * Apple ID settings is noticed rather than sat on.
 *
 * Batched and bounded with `.take` for the reason spelled out at
 * `users.sweepStalePresence`: an unbounded `.collect()` eventually blows the
 * read limit, at which point the sweep silently stops working and nobody
 * notices.
 *
 * Only a definitive 400/invalid_grant clears the token. A 5xx or a network
 * blip returns null and is left alone — treating "Apple was down" as "the user
 * revoked us" would throw away the only token that can ever revoke that grant.
 */
export const validateAppleGrants = internalAction({
  args: {},
  returns: v.null(),
  handler: async (ctx) => {
    const due = await ctx.runQuery(internal.socialAuth.appleGrantsDueForCheck, {
      before: Date.now() - APPLE_REFRESH_CHECK_INTERVAL_MS,
      limit: 50,
    });
    for (const row of due) {
      const valid = await refreshTokenStillValid(row.appleRefreshToken);
      if (valid === null) continue; // inconclusive — try again next sweep
      await ctx.runMutation(internal.socialAuth.recordAppleGrantCheck, {
        identityId: row.identityId,
        stillValid: valid,
      });
    }
    return null;
  },
});

export const appleGrantsDueForCheck = internalQuery({
  args: { before: v.number(), limit: v.number() },
  returns: v.array(
    v.object({
      identityId: v.id("socialIdentities"),
      appleRefreshToken: v.string(),
    }),
  ),
  handler: async (ctx, { before, limit }) => {
    // No index on (provider, appleRefreshCheckedAt): this table is small and
    // Apple-with-a-token is a fraction of it. Revisit if it ever grows enough
    // for the scan to show up.
    const rows = await ctx.db
      .query("socialIdentities")
      .withIndex("by_provider_subject", (q) => q.eq("provider", PROVIDER_APPLE))
      .take(500);
    return rows
      .filter(
        (r) =>
          r.appleRefreshToken !== undefined &&
          (r.appleRefreshCheckedAt ?? 0) < before,
      )
      .slice(0, limit)
      .map((r) => ({
        identityId: r._id,
        appleRefreshToken: r.appleRefreshToken!,
      }));
  },
});

export const recordAppleGrantCheck = internalMutation({
  args: { identityId: v.id("socialIdentities"), stillValid: v.boolean() },
  returns: v.null(),
  handler: async (ctx, { identityId, stillValid }) => {
    const row = await ctx.db.get(identityId);
    if (!row) return null;
    await ctx.db.patch(identityId, {
      appleRefreshCheckedAt: Date.now(),
      // Apple says the grant is gone. Drop the dead token but KEEP the identity
      // row: the (provider, subject) mapping is what lets this person sign in
      // again, and deleting it would silently orphan their account. They simply
      // have no revocable grant until they next authorize.
      ...(stillValid ? {} : { appleRefreshToken: undefined }),
    });
    return null;
  },
});

export const findIdentity = internalQuery({
  args: { provider: v.string(), subject: v.string() },
  returns: v.union(
    v.null(),
    v.object({
      identityId: v.id("socialIdentities"),
      userId: v.id("users"),
      hasAppleRefreshToken: v.boolean(),
    }),
  ),
  handler: async (ctx, { provider, subject }) => {
    const row = await ctx.db
      .query("socialIdentities")
      .withIndex("by_provider_subject", (q) =>
        q.eq("provider", provider).eq("subject", subject),
      )
      .first();
    if (!row) return null;
    return {
      identityId: row._id,
      userId: row.userId,
      hasAppleRefreshToken: row.appleRefreshToken !== undefined,
    };
  },
});

export const touchIdentity = internalMutation({
  args: {
    identityId: v.id("socialIdentities"),
    email: v.optional(v.string()),
    isPrivateRelay: v.optional(v.boolean()),
    appleRefreshToken: v.optional(v.string()),
  },
  returns: authResultValidator,
  handler: async (ctx, args) => {
    const row = await ctx.db.get(args.identityId);
    if (!row) throw new Error("SOCIAL_IDENTITY_GONE");

    const user = await ctx.db.get(row.userId);
    if (!user) throw new Error("USER_NOT_FOUND");
    // Defence in depth: we never create an identity on a child account, but a
    // conversion could in principle produce one, and a child must never reach a
    // password-free sign-in path.
    if (user.accountType === ACCOUNT_CHILD) throw new Error(ERR_MUST_PAIR);

    const now = Date.now();
    await ctx.db.patch(args.identityId, {
      lastUsedAt: now,
      // Apple withholds the email after the first authorization, so only
      // overwrite when the provider actually told us something.
      ...(args.email !== undefined ? { email: args.email } : {}),
      ...(args.isPrivateRelay !== undefined
        ? { isPrivateRelay: args.isPrivateRelay }
        : {}),
      ...(args.appleRefreshToken !== undefined
        ? { appleRefreshToken: args.appleRefreshToken, appleRefreshCheckedAt: now }
        : {}),
    });
    await ctx.db.patch(user._id, { status: "online", lastSeen: now });

    return {
      status: "signedIn" as const,
      userId: user._id,
      username: user.username,
      name: user.name ?? user.username,
      accountType: user.accountType ?? "adult",
    };
  },
});

export const createWithIdentity = internalMutation({
  args: {
    provider: v.string(),
    subject: v.string(),
    email: v.optional(v.string()),
    isPrivateRelay: v.optional(v.boolean()),
    username: v.string(),
    name: v.optional(v.string()),
    appleRefreshToken: v.optional(v.string()),
  },
  returns: authResultValidator,
  handler: async (ctx, args) => {
    const username = normaliseUsername(args.username);

    // Both uniqueness checks live inside this one mutation on purpose. Convex
    // mutations are serializable, so a concurrent signup that would collide is
    // detected and retried by OCC — which is what makes a check-then-insert
    // actually safe here despite there being no unique constraint.
    const taken = await ctx.db
      .query("users")
      .withIndex("by_username", (q) => q.eq("username", username))
      .first();
    if (taken) throw new Error("USERNAME_TAKEN");

    const claimed = await ctx.db
      .query("socialIdentities")
      .withIndex("by_provider_subject", (q) =>
        q.eq("provider", args.provider).eq("subject", args.subject),
      )
      .first();
    // Lost a race with another tab/device that just created this account. Sign
    // them into it rather than failing — the outcome they wanted either way.
    if (claimed) {
      const user = await ctx.db.get(claimed.userId);
      if (user) {
        return {
          status: "signedIn" as const,
          userId: user._id,
          username: user.username,
          name: user.name ?? user.username,
          accountType: user.accountType ?? "adult",
        };
      }
    }

    const now = Date.now();
    const name = args.name?.trim();
    const userId = await ctx.db.insert("users", {
      username,
      name: name && name.length > 0 ? name : username,
      // No password, ever, unless the user later sets one. See the sentinel.
      passwordHash: SOCIAL_ONLY_PASSWORD_SENTINEL,
      // Deliberately no recoveryKeyHash: the provider IS the recovery path, and
      // a 12-word phrase that resets a password this account does not have would
      // be theatre. `recovery_gate.dart` short-circuits for these accounts.
      email: args.email,
      createdAt: now,
      status: "online",
      lastSeen: now,
    });

    await ctx.db.insert("socialIdentities", {
      provider: args.provider,
      subject: args.subject,
      userId,
      email: args.email,
      isPrivateRelay: args.isPrivateRelay,
      createdAt: now,
      lastUsedAt: now,
      appleRefreshToken: args.appleRefreshToken,
      appleRefreshCheckedAt: args.appleRefreshToken !== undefined ? now : undefined,
    });

    return {
      status: "signedIn" as const,
      userId,
      username,
      name: name && name.length > 0 ? name : username,
      accountType: "adult",
    };
  },
});

export const attachToExistingAccount = internalMutation({
  args: {
    username: v.string(),
    passwordHash: v.string(),
    provider: v.string(),
    subject: v.string(),
    email: v.optional(v.string()),
    isPrivateRelay: v.optional(v.boolean()),
    appleRefreshToken: v.optional(v.string()),
  },
  returns: authResultValidator,
  handler: async (ctx, args) => {
    const user = await ctx.db
      .query("users")
      .withIndex("by_username", (q) => q.eq("username", args.username.trim()))
      .first();
    if (!user) throw new Error("USER_NOT_FOUND");

    // Both guards BEFORE the password compare, mirroring auth.login exactly —
    // the stored sentinels must never be reachable by guessing.
    if (user.accountType === ACCOUNT_CHILD) throw new Error(ERR_MUST_PAIR);
    if (user.passwordHash === SOCIAL_ONLY_PASSWORD_SENTINEL) {
      // No password to prove ownership with. Sending them to `signIn` would
      // just bounce them back here, so say what is actually true.
      throw new Error(ERR_USE_SOCIAL);
    }

    const key = loginKey(user._id);
    await assertNotLocked(ctx, key);
    if (user.passwordHash !== args.passwordHash) {
      await noteFailure(ctx, key);
      throw new Error("WRONG_PASSWORD");
    }
    await clearFailures(ctx, key);

    const claimed = await ctx.db
      .query("socialIdentities")
      .withIndex("by_provider_subject", (q) =>
        q.eq("provider", args.provider).eq("subject", args.subject),
      )
      .first();
    if (claimed && claimed.userId !== user._id) {
      throw new Error(ERR_LINKED_ELSEWHERE);
    }

    const now = Date.now();
    if (claimed) {
      // Already attached to this very account — treat as a plain sign-in rather
      // than an error. Re-tapping the button must not be punished.
      await ctx.db.patch(claimed._id, {
        lastUsedAt: now,
        ...(args.appleRefreshToken !== undefined
          ? { appleRefreshToken: args.appleRefreshToken, appleRefreshCheckedAt: now }
          : {}),
      });
    } else {
      const sameProvider = (
        await ctx.db
          .query("socialIdentities")
          .withIndex("by_user", (q) => q.eq("userId", user._id))
          .collect()
      ).some((r) => r.provider === args.provider);
      // One account, one identity per provider — otherwise a second Apple ID
      // silently becomes a co-owner of the account.
      if (sameProvider) throw new Error(ERR_ALREADY_LINKED);

      await ctx.db.insert("socialIdentities", {
        provider: args.provider,
        subject: args.subject,
        userId: user._id,
        email: args.email,
        isPrivateRelay: args.isPrivateRelay,
        createdAt: now,
        lastUsedAt: now,
        appleRefreshToken: args.appleRefreshToken,
        appleRefreshCheckedAt:
          args.appleRefreshToken !== undefined ? now : undefined,
      });
    }

    await ctx.db.patch(user._id, { status: "online", lastSeen: now });
    return {
      status: "signedIn" as const,
      userId: user._id,
      username: user.username,
      name: user.name ?? user.username,
      accountType: user.accountType ?? "adult",
    };
  },
});

export const attachIdentity = internalMutation({
  args: {
    userId: v.id("users"),
    passwordHash: v.string(),
    provider: v.string(),
    subject: v.string(),
    email: v.optional(v.string()),
    isPrivateRelay: v.optional(v.boolean()),
    appleRefreshToken: v.optional(v.string()),
  },
  returns: v.null(),
  handler: async (ctx, args) => {
    const user = await ctx.db.get(args.userId);
    if (!user) throw new Error("USER_NOT_FOUND");

    // BEFORE the password compare, mirroring auth.login and auth.setRecoveryKey.
    // Without this, guessing the child sentinel would let someone bolt an Apple
    // ID onto a child account and sign in as that child, bypassing pairing.
    if (user.accountType === ACCOUNT_CHILD) throw new Error(ERR_MUST_PAIR);

    const key = loginKey(user._id);
    await assertNotLocked(ctx, key);
    if (user.passwordHash !== args.passwordHash) {
      await noteFailure(ctx, key);
      throw new Error("WRONG_PASSWORD");
    }
    await clearFailures(ctx, key);

    const existing = await ctx.db
      .query("socialIdentities")
      .withIndex("by_provider_subject", (q) =>
        q.eq("provider", args.provider).eq("subject", args.subject),
      )
      .first();
    if (existing) {
      // Distinguished on purpose: "you already did this" is a no-op the UI can
      // ignore, whereas "this Apple ID belongs to a different account" needs a
      // real explanation and a different remedy.
      throw new Error(
        existing.userId === args.userId ? ERR_ALREADY_LINKED : ERR_LINKED_ELSEWHERE,
      );
    }

    const already = await ctx.db
      .query("socialIdentities")
      .withIndex("by_user", (q) => q.eq("userId", args.userId))
      .collect();
    if (already.some((r) => r.provider === args.provider)) {
      throw new Error(ERR_ALREADY_LINKED);
    }

    const now = Date.now();
    await ctx.db.insert("socialIdentities", {
      provider: args.provider,
      subject: args.subject,
      userId: args.userId,
      email: args.email,
      isPrivateRelay: args.isPrivateRelay,
      createdAt: now,
      lastUsedAt: now,
      appleRefreshToken: args.appleRefreshToken,
      appleRefreshCheckedAt: args.appleRefreshToken !== undefined ? now : undefined,
    });
    return null;
  },
});
