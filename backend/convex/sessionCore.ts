import { v } from "convex/values";
import type { Id } from "./_generated/dataModel";
import type { QueryCtx, MutationCtx } from "./_generated/server";
import { internalMutation } from "./_generated/server";
import { internal } from "./_generated/api";
import { continueSweep, sweepArgs } from "./sweep";

/**
 * Bearer sessions: the primitives.
 *
 * Split from `sessions.ts` to break an import cycle, and the split earns its
 * keep on its own: this file defines no Convex functions, so `functions.ts` can
 * import [requireSession] without dragging in the builders that import
 * `functions.ts` right back.
 *
 * ## Read this before wiring anything to it
 *
 * As of this commit the table is WRITTEN and never READ for authorization.
 * Every public function still takes `userId` as a plain argument and still
 * trusts it, exactly as before. Minting a session changes no behaviour, and
 * revoking one currently stops nothing.
 *
 * That is deliberate, and it is the only safe way to land the first half. A
 * partially-enforced auth layer is strictly worse than an unenforced one: some
 * calls would start failing for clients that have no token yet, and the app is
 * live on TestFlight with installs that will never send one until they update.
 * So the order is: mint everywhere → ship → clients carry tokens → THEN
 * enforce, file by file, with `requireSession` below.
 *
 * ## What "enforce" will mean
 *
 * Replacing `userId: v.id("users")` in a function's args with
 * `token: v.string()`, and opening the handler with
 * `const userId = await requireSession(ctx, token)`. 187 argument sites across
 * 26 files, so it is done in batches, highest-value first (messages, rooms,
 * family, auth) rather than in one sweep.
 *
 * ## Why the hash and not the token
 *
 * `tokenHash` is a SHA-256 of the bearer string; the plaintext is returned to
 * the client exactly once, at mint. A database snapshot is therefore not a set
 * of working credentials — the same bargain `users.passwordHash` already
 * makes. The client stores its token in the OS keychain alongside the userId
 * it already keeps there.
 */

/** 32 bytes of CSPRNG, hex. Same helper shape as `deviceLogin.randomHex`. */
function randomHex(bytes: number): string {
  const buf = new Uint8Array(bytes);
  crypto.getRandomValues(buf);
  return Array.from(buf, (b) => b.toString(16).padStart(2, "0")).join("");
}

/**
 * SHA-256, hex. Async because that is the only digest the runtime offers.
 *
 * Deliberately unsalted and un-stretched, which would be wrong for a password
 * and is right here: the input is 256 bits of CSPRNG output, so there is no
 * dictionary to attack and nothing for a work factor to buy. Stretching would
 * only add latency to the hottest path in the app once enforcement lands.
 */
export async function hashToken(token: string): Promise<string> {
  const data = new TextEncoder().encode(token);
  const digest = await crypto.subtle.digest("SHA-256", data);
  return Array.from(new Uint8Array(digest), (b) =>
    b.toString(16).padStart(2, "0"),
  ).join("");
}

/**
 * sha256 hex of a client's `deviceSecret`, or undefined when there is none.
 *
 * The contract is 64 hex characters, generated once per install. Anything else
 * is treated as "no secret" rather than refused, so a malformed value from a
 * buggy build degrades to the old behaviour (no eviction) instead of breaking
 * sign-in.
 */
export async function deviceSecretHashOf(
  secret: string | undefined,
): Promise<string | undefined> {
  if (secret === undefined || !/^[0-9a-f]{64}$/i.test(secret)) return undefined;
  return await hashToken(secret.toLowerCase());
}

/**
 * Mint a session for a user on a device, returning the plaintext token.
 *
 * Call this from every entry point that establishes identity: password login,
 * signup, social sign-in, child pairing, and the device-login exchange. A path
 * that forgets to mint is a client that will fail to authenticate the moment
 * its area is enforced, which is exactly the failure this staging exists to
 * avoid — so add the call when you add the path, not later.
 *
 * One live session per (user, device): re-minting revokes whatever that device
 * held before. Signing in again on the same phone should not leave a second
 * credential behind that nothing in the UI can ever show or revoke.
 */
export async function mintSession(
  ctx: MutationCtx,
  userId: Id<"users">,
  deviceId: string,
  deviceSecret?: string,
): Promise<string> {
  // The one door every sign-in path walks through, so the one place a ban has
  // to be checked to cover them all.
  const account = await ctx.db.get(userId);
  if (account?.suspendedAt !== undefined && account !== null) {
    throw new Error(ERR_ACCOUNT_SUSPENDED);
  }
  // A scrubbed ghost (`deletionCore.startUserDeletion`) must not sign in. Inline
  // rather than `isTombstoned`: deletionCore imports this file.
  if (account?.deletingAt !== undefined) throw new Error(ERR_SESSION_REVOKED);
  const now = Date.now();
  const previous = await ctx.db
    .query("sessions")
    .withIndex("by_user_device", (q) =>
      q.eq("userId", userId).eq("deviceId", deviceId),
    )
    .collect();
  for (const row of previous) {
    if (row.revokedAt === undefined) {
      await ctx.db.patch(row._id, { revokedAt: now });
    }
  }
  // One physical device, one account: signing in as B on a phone that A is
  // still signed in on used to leave A's token live on that handset.
  //
  // But `deviceId` is NOT a secret (group-call rosters and 1:1 call rows show
  // it to peers), so on its own it must never be enough to sign somebody out:
  // anyone could sign in to their own account with a victim's deviceId and
  // force them out, repeatedly. The proof is `deviceSecret`, a per-install
  // value only that install knows; another account's session is revoked only
  // when BOTH sessions carry a secret hash and the hashes are equal. A client
  // without a secret evicts nothing and is evicted by nothing.
  //
  // Found through `sessions.by_device` (undefined `revokedAt` sorts lowest, so
  // the equality ranges over live rows). Bounded: a device hosts a handful of
  // accounts.
  const secretHash = await deviceSecretHashOf(deviceSecret);
  if (secretHash !== undefined) {
    const live = await ctx.db
      .query("sessions")
      .withIndex("by_device", (q) =>
        q.eq("deviceId", deviceId).eq("revokedAt", undefined),
      )
      .take(50);
    for (const row of live) {
      if (row.userId !== userId && row.deviceSecretHash === secretHash) {
        await ctx.db.patch(row._id, { revokedAt: now });
      }
    }
  }
  const token = randomHex(32);
  await ctx.db.insert("sessions", {
    userId,
    tokenHash: await hashToken(token),
    deviceId,
    ...(secretHash !== undefined ? { deviceSecretHash: secretHash } : {}),
    createdAt: now,
    lastSeenAt: now,
  });
  return token;
}

/**
 * The key a banned social identity is remembered by: sha256 of
 * "provider:subject". Subject only, never email (email is display-only and
 * Apple's relay address is per-app; see `socialIdentities`).
 */
export async function identityBanHash(
  provider: string,
  subject: string,
): Promise<string> {
  return await hashToken(`${provider}:${subject}`);
}

/**
 * Refuse an identity that belonged to an account deleted while SUSPENDED
 * (`auth.purgeUser` records it). Same code a suspended account answers with, so
 * the client shows the one ban screen it already has.
 */
export async function assertIdentityNotBanned(
  ctx: QueryCtx | MutationCtx,
  provider: string,
  subject: string,
): Promise<void> {
  const hash = await identityBanHash(provider, subject);
  const banned = await ctx.db
    .query("bannedIdentities")
    .withIndex("by_hash", (q) => q.eq("hash", hash))
    .first();
  if (banned) throw new Error(ERR_ACCOUNT_SUSPENDED);
}

/** Thrown by [requireSession]; the two are deliberately distinguishable. */
export const ERR_SESSION_UNKNOWN = "SESSION_UNKNOWN";
export const ERR_SESSION_REVOKED = "SESSION_REVOKED";
/**
 * The account was banned by a moderator (`moderation.suspendAccount`). Thrown
 * by [requireSession] and by [mintSession], so a banned person can neither
 * keep using a session nor mint a new one by ANY sign-in path — password,
 * Apple/Google, QR device login or a pairing code all end in [mintSession].
 */
export const ERR_ACCOUNT_SUSPENDED = "ACCOUNT_SUSPENDED";

/**
 * A session unused for this long is dead (decided 2026-10-22: 90 days without
 * use, refreshed on use). Checked by [requireSession] and swept by
 * [expireIdleSessions].
 */
export const SESSION_IDLE_MS = 90 * 24 * 60 * 60 * 1000;

/** How stale `lastSeenAt` must be before [touchSessions] writes it. */
export const SESSION_TOUCH_MS = 24 * 60 * 60 * 1000;

/**
 * The grace floor for sessions minted before idle expiry existed.
 *
 * `lastSeenAt` was set at sign-in and never updated, so a tester who signs in
 * every day still has a `lastSeenAt` from weeks or months ago. Judged by the raw
 * value, deploying this would sign out everyone who signed in more than 90 days
 * back, active or not. So an idle judgement reads `max(lastSeenAt, floor)`: no
 * session can expire before `floor + 90 days`, and one that is used in that
 * window is refreshed by [touchSessions] and judged by its own clock from then
 * on. A constant rather than a backfill: nothing to run, nothing to forget,
 * and it stops mattering by itself. Set to the day of the change; moving it
 * later only extends the grace.
 */
export const SESSION_GRACE_FLOOR = Date.UTC(2026, 9, 22);

/** When [lastSeenAt] stops counting as use, after the grace floor. */
export function sessionIdleSince(lastSeenAt: number): number {
  return Math.max(lastSeenAt, SESSION_GRACE_FLOOR);
}

/**
 * Refresh `lastSeenAt` on [userId]'s live sessions that have not been written
 * for a day. MUTATIONS only: a query cannot write, and `requireSession` runs in
 * both. Called from the presence heartbeat, which every signed-in client
 * already sends, so nothing else pays a write.
 *
 * The range is on `by_user_live_seen`, so a heartbeat with nothing stale is one
 * empty index probe. The write invalidates every subscription of that device
 * (each one read the row in `requireSession`), once a day per session.
 *
 * The heartbeat does not know which session it came in on (the wrapper strips
 * the token), so this refreshes all of the user's live sessions: a phone left in
 * a drawer lasts as long as the account's most recent activity on any device.
 */
export async function touchSessions(
  ctx: MutationCtx,
  userId: Id<"users">,
): Promise<void> {
  const now = Date.now();
  const stale = await ctx.db
    .query("sessions")
    .withIndex("by_user_live_seen", (q) =>
      q
        .eq("userId", userId)
        .eq("revokedAt", undefined)
        .lt("lastSeenAt", now - SESSION_TOUCH_MS),
    )
    .take(20);
  for (const row of stale) await ctx.db.patch(row._id, { lastSeenAt: now });
}

/**
 * Resolve a bearer token to the user it belongs to, or throw.
 *
 * **Not yet called by anything.** This is the function every handler will open
 * with once its file is migrated; it lives here now so the enforcement batches
 * are a mechanical edit against a helper that already exists and is tested,
 * rather than 26 files each inventing the check.
 *
 * The digest is awaited BEFORE the query is built, because `withIndex` takes a
 * synchronous callback and cannot await inside it.
 *
 * Distinguishes revoked from unknown on purpose: "you were signed out" sends a
 * client to the login screen, while "no such session" is the shape a bug takes
 * and should not be silently laundered into the same message.
 */
export async function requireSession(
  ctx: QueryCtx | MutationCtx,
  token: string,
  opts?: { allowSuspended?: boolean },
): Promise<Id<"users">> {
  const tokenHash = await hashToken(token);
  const row = await ctx.db
    .query("sessions")
    .withIndex("by_token_hash", (q) => q.eq("tokenHash", tokenHash))
    .first();
  if (!row) throw new Error(ERR_SESSION_UNKNOWN);
  // A banned account answers ACCOUNT_SUSPENDED rather than REVOKED, even
  // though the ban also revoked its sessions: the client signs out either way,
  // but only this code lets the login screen say WHY. Checked before the
  // revoked test for exactly that reason — which costs a revoked token one
  // extra `get`, on a path that ends in a sign-out anyway.
  if (row.revokedAt !== undefined) {
    const owner = await ctx.db.get(row.userId);
    // Deleting beats suspended: a suspended user who deleted themselves gets the
    // plain sign-out, and a second `deleteAccount` call ends here (not allowed
    // through `allowSuspended`). `deletingAt` is checked inline, see `mintSession`.
    if (owner?.deletingAt !== undefined) throw new Error(ERR_SESSION_REVOKED);
    if (owner?.suspendedAt !== undefined && owner !== null) {
      // The one exception, for `auth.deleteAccount` alone: the session the BAN
      // revoked still proves who is asking. Only that one — a token revoked
      // before the ban (signed out, "sign out everywhere") stays dead, so an
      // old credential cannot be used to delete somebody's account.
      if (opts?.allowSuspended && row.revokedAt >= owner.suspendedAt) {
        return row.userId;
      }
      throw new Error(ERR_ACCOUNT_SUSPENDED);
    }
    throw new Error(ERR_SESSION_REVOKED);
  }
  // Idle expiry. Free: `lastSeenAt` is on the row already in hand. Same code
  // as a revoked session, so the client says "you were signed out".
  if (Date.now() - sessionIdleSince(row.lastSeenAt) > SESSION_IDLE_MS) {
    throw new Error(ERR_SESSION_REVOKED);
  }
  // The account itself must still exist. `purgeUser` now revokes sessions on
  // its way out, so this is belt-and-braces for the rows it already left
  // behind — but it is the check that actually closes the hole, because a
  // token whose `users` row is gone otherwise authenticates FOREVER and hands
  // every caller a dangling id. `users.getProfile` then answers `null` rather
  // than erroring, so nothing downstream ever notices.
  //
  // REVOKED, not UNKNOWN: a deleted account is "you were signed out", which is
  // exactly what the client should say. UNKNOWN is reserved for the shape a bug
  // takes (see the doc comment above) and a purge is not one.
  //
  // Cost: one document get by id on every authenticated call, in the same
  // transaction as the index read above. Bought deliberately — the alternative
  // is a session layer that cannot tell a live account from a deleted one.
  const user = await ctx.db.get(row.userId);
  if (!user) throw new Error(ERR_SESSION_REVOKED);
  // Free: a tombstoned account (deletion in flight) is signed out, even for
  // `allowSuspended`: the delete has started and cannot be asked for twice.
  if (user.deletingAt !== undefined) throw new Error(ERR_SESSION_REVOKED);
  // Free: the row is already in hand. See `moderation.suspendAccount`.
  if (user.suspendedAt !== undefined && !opts?.allowSuspended) {
    throw new Error(ERR_ACCOUNT_SUSPENDED);
  }
  return row.userId;
}

/**
 * The deviceIds [userId] is currently signed in on.
 *
 * The push senders' authorization check, and the reason it exists: a
 * `userDevices` row is NOT evidence that anyone is signed in on that handset.
 * The row is written at login and deleted by `voipTokens.clearDeviceToken`,
 * which is an authenticated call the client can only make while it still holds
 * a live token — so every path that ends a session WITHOUT one (a revoked
 * session, a sign-out that raced its own teardown, an install whose keychain
 * lost the session) leaves the row behind with a working APNs/FCM credential
 * on it. `push._loadAlertTargets`, `voipPush._loadUserDevices` and
 * `dailyNudge` then kept ringing and buzzing a phone parked on the login
 * screen, for the account it could no longer open, until the 90-day sweep in
 * `voipTokens.gcStaleDevices` collected the row.
 *
 * Sessions are the honest signal because they are the ONE thing every entry
 * point mints (`auth.login`/`signup`/`resetPasswordWithRecoveryKey`,
 * `socialAuth`, `deviceLogin`, `family.redeemPairingCode`) and the one thing
 * every exit revokes — including the exits the client is not around for.
 * [mintSession] revokes the previous session for the same pair, so this set
 * holds at most one entry per device.
 *
 * One indexed read per USER, not per device: callers hold the set across all
 * of that account's rows.
 */
export async function liveSessionDeviceIds(
  ctx: QueryCtx | MutationCtx,
  userId: Id<"users">,
): Promise<Set<string>> {
  const rows = await ctx.db
    .query("sessions")
    .withIndex("by_user", (q) => q.eq("userId", userId))
    .collect();
  const live = new Set<string>();
  for (const row of rows) {
    if (row.revokedAt === undefined) live.add(row.deviceId);
  }
  return live;
}

/**
 * Whether [userId] still holds a live session anywhere.
 *
 * Asked by the sign-out paths before marking the account offline: signing out
 * one handset does not put someone offline while their other phone is open.
 */
export async function hasAnyLiveSession(
  ctx: QueryCtx | MutationCtx,
  userId: Id<"users">,
): Promise<boolean> {
  const rows = await ctx.db
    .query("sessions")
    .withIndex("by_user", (q) => q.eq("userId", userId))
    .collect();
  return rows.some((row) => row.revokedAt === undefined);
}

/** Revoke every live session on one device. */
export async function revokeSessionsForDevice(
  ctx: MutationCtx,
  userId: Id<"users">,
  deviceId: string,
): Promise<number> {
  const now = Date.now();
  const rows = await ctx.db
    .query("sessions")
    .withIndex("by_user_device", (q) =>
      q.eq("userId", userId).eq("deviceId", deviceId),
    )
    .collect();
  let revoked = 0;
  for (const row of rows) {
    if (row.revokedAt !== undefined) continue;
    await ctx.db.patch(row._id, { revokedAt: now });
    revoked++;
  }
  return revoked;
}

/**
 * Revoke every live session EXCEPT the caller's own device.
 *
 * Derives the victims from `deviceId` rather than taking a list, so a device
 * that signed in during the seconds since the screen last rendered is swept
 * too. That is the only promise "sign out everywhere else" actually makes.
 */
export async function revokeOtherSessions(
  ctx: MutationCtx,
  userId: Id<"users">,
  deviceId: string,
): Promise<number> {
  const now = Date.now();
  const rows = await ctx.db
    .query("sessions")
    .withIndex("by_user", (q) => q.eq("userId", userId))
    .collect();
  let revoked = 0;
  for (const row of rows) {
    if (row.deviceId === deviceId || row.revokedAt !== undefined) continue;
    await ctx.db.patch(row._id, { revokedAt: now });
    revoked++;
  }
  return revoked;
}


/**
 * How long a revoked session is kept before it is swept.
 *
 * Not zero. A device that was signed out remotely asks the server one more
 * time on its next request, and the answer it gets decides what the user is
 * told: a row still present answers SESSION_REVOKED — "you were signed out" —
 * while a deleted one answers SESSION_UNKNOWN, which is the shape a bug takes.
 * A week is long enough that anyone who was signed out gets the honest message.
 */
const REVOKED_RETENTION_MS = 7 * 24 * 60 * 60 * 1000;

/**
 * Delete revoked sessions past their retention.
 *
 * Never deletes a live session: expiry REVOKES (see [expireIdleSessions]) and
 * this removes the row a week after that. A full page schedules the next, so
 * a backlog drains within the firing (see sweep.ts).
 */
export const gcRevokedSessions = internalMutation({
  args: sweepArgs,
  returns: v.null(),
  handler: async (ctx, { chain }) => {
    const cutoff = Date.now() - REVOKED_RETENTION_MS;
    const stale = await ctx.db
      .query("sessions")
      // The lower bound is load-bearing, not tidiness. In a Convex index
      // `undefined` sorts BELOW every number, so a bare `lt("revokedAt",
      // cutoff)` matches every LIVE session — `revokedAt` is undefined on all
      // of them. This sweep would then have deleted every session on the
      // deployment every six hours, signing out every user. Caught by the test
      // below and by nothing else: it typechecks, it reads correctly, and on a
      // fresh table it even appears to work.
      .withIndex("by_revoked_at", (q) =>
        q.gt("revokedAt", 0).lt("revokedAt", cutoff),
      )
      .take(REVOKED_SESSIONS_PAGE);
    for (const row of stale) {
      // Belt and braces: never delete a live session, whatever the range did.
      if (row.revokedAt === undefined) continue;
      await ctx.db.delete(row._id);
    }
    await continueSweep(
      ctx,
      internal.sessionCore.gcRevokedSessions,
      stale.length === REVOKED_SESSIONS_PAGE,
      chain,
    );
    return null;
  },
});

const REVOKED_SESSIONS_PAGE = 200;

/**
 * Revoke live sessions idle past [SESSION_IDLE_MS].
 *
 * [requireSession] already refuses them the moment they are presented; this is
 * so the rows are cleaned up (revoked, then deleted by [gcRevokedSessions]) even
 * when nobody ever presents them again. Honours the grace floor: nothing
 * expires before `SESSION_GRACE_FLOOR + 90 days`.
 *
 * The range is bounded on `lastSeenAt` and on live rows only (`revokedAt`
 * undefined), and revoking takes a row out of it, so each page starts at the
 * next stale session.
 */
export const expireIdleSessions = internalMutation({
  args: sweepArgs,
  returns: v.null(),
  handler: async (ctx, { chain }) => {
    const now = Date.now();
    const cutoff = now - SESSION_IDLE_MS;
    // Nothing can be idle yet: every session is still inside the grace floor.
    if (cutoff <= SESSION_GRACE_FLOOR) return null;
    const idle = await ctx.db
      .query("sessions")
      .withIndex("by_live_seen", (q) =>
        q.eq("revokedAt", undefined).lt("lastSeenAt", cutoff),
      )
      .take(IDLE_SESSIONS_PAGE);
    for (const row of idle) await ctx.db.patch(row._id, { revokedAt: now });
    await continueSweep(
      ctx,
      internal.sessionCore.expireIdleSessions,
      idle.length === IDLE_SESSIONS_PAGE,
      chain,
    );
    return null;
  },
});

const IDLE_SESSIONS_PAGE = 200;
