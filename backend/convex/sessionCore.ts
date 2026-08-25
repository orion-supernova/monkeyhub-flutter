import type { Id } from "./_generated/dataModel";
import type { QueryCtx, MutationCtx } from "./_generated/server";

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
): Promise<string> {
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
  const token = randomHex(32);
  await ctx.db.insert("sessions", {
    userId,
    tokenHash: await hashToken(token),
    deviceId,
    createdAt: now,
    lastSeenAt: now,
  });
  return token;
}

/** Thrown by [requireSession]; the two are deliberately distinguishable. */
export const ERR_SESSION_UNKNOWN = "SESSION_UNKNOWN";
export const ERR_SESSION_REVOKED = "SESSION_REVOKED";

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
): Promise<Id<"users">> {
  const tokenHash = await hashToken(token);
  const row = await ctx.db
    .query("sessions")
    .withIndex("by_token_hash", (q) => q.eq("tokenHash", tokenHash))
    .first();
  if (!row) throw new Error(ERR_SESSION_UNKNOWN);
  if (row.revokedAt !== undefined) throw new Error(ERR_SESSION_REVOKED);
  return row.userId;
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
