import { internalMutation } from "./_generated/server";
import type { MutationCtx } from "./_generated/server";

/**
 * Failed-attempt throttling for the credential paths.
 *
 * Lives in its own module rather than inside auth.ts so that
 * family.releaseDeviceByGuardianPassword — which is also an unlimited password
 * oracle today — can adopt it later without a circular import.
 *
 * See the `authAttempts` comment in schema.ts for why the key is the account
 * rather than the caller, and why the lockout is a timestamp.
 */

export const ERR_TOO_MANY = "TOO_MANY_ATTEMPTS";

/** Failures older than this are forgotten entirely. */
export const WINDOW_MS = 15 * 60 * 1000;

/** How long a tripped key stays shut. Must expire on its own — see schema.ts. */
export const LOCKOUT_MS = 15 * 60 * 1000;

/**
 * Ten tries before a password path shuts. Someone who genuinely forgot their
 * password gets a realistic number of attempts; a script gets nowhere.
 */
export const MAX_PASSWORD_FAILURES = 10;

/**
 * Five tries on the recovery path.
 *
 * A 12-word phrase is ~132 bits and unguessable, so five costs a real user
 * nothing — they will paste it correctly or give up. The tighter limit is
 * doing its real work against the LEGACY freehand phrases, which were typed by
 * hand and may well be "my dog barney". Those, not the generated ones, are the
 * reason this limiter exists.
 */
export const MAX_RECOVERY_FAILURES = 5;

export const loginKey = (userId: string) => `login:${userId}`;
export const pairingDeviceKey = (deviceId: string) => `pair:device:${deviceId}`;
/** One bucket for every pairing-code guess, whoever makes it. */
export const PAIRING_GLOBAL_KEY = "pair:global";
export const MAX_PAIRING_DEVICE_FAILURES = 10;
export const MAX_PAIRING_GLOBAL_FAILURES = 60;
export const roomPasswordKey = (roomId: string, userId: string) =>
  `roompw:${roomId}:${userId}`;

/**
 * A credential failure, RETURNED rather than thrown.
 *
 * Convex mutations are transactions: a `throw` rolls back every write the
 * call made, [noteFailure]'s included. Each credential path used to record
 * the failure and then throw, so the count never survived and the lockout
 * never engaged. Returning this commits the count; the client's mutation
 * wrapper (`lib/backend/convex_client.dart`) turns it back into an error
 * carrying [code], so every screen matching on the code still works.
 */
export const REFUSED = "__refused";
export function refusal(code: string): { [REFUSED]: string } {
  return { [REFUSED]: code };
}
export const recoveryKey = (userId: string) => `recovery:${userId}`;

/**
 * Throws ERR_TOO_MANY while [key] is locked out.
 *
 * MUST be called before the hash comparison, not after — the point is to stop
 * the compare from happening at all.
 *
 * Never throws on a missing row, and treats a row whose window has closed as
 * clean, so a key can only ever be shut by recent activity.
 */
export async function assertNotLocked(
  ctx: MutationCtx,
  key: string,
): Promise<void> {
  const row = await ctx.db
    .query("authAttempts")
    .withIndex("by_key", (q) => q.eq("key", key))
    .first();
  if (!row) return;
  const now = Date.now();
  if (row.lockedUntil !== undefined && row.lockedUntil > now) {
    throw new Error(ERR_TOO_MANY);
  }
  // Window closed: the row is stale. Left in place for gcAuthAttempts to reap;
  // noteFailure will restart the window if the caller fails again.
}

/** Records one failure, locking the key once it crosses [max]. */
export async function noteFailure(
  ctx: MutationCtx,
  key: string,
  max: number = MAX_PASSWORD_FAILURES,
): Promise<void> {
  const now = Date.now();
  const row = await ctx.db
    .query("authAttempts")
    .withIndex("by_key", (q) => q.eq("key", key))
    .first();

  if (!row || now - row.windowStartedAt > WINDOW_MS) {
    const fresh = { key, failures: 1, windowStartedAt: now, updatedAt: now };
    if (row) await ctx.db.patch(row._id, { ...fresh, lockedUntil: undefined });
    else await ctx.db.insert("authAttempts", fresh);
    return;
  }

  const failures = row.failures + 1;
  await ctx.db.patch(row._id, {
    failures,
    updatedAt: now,
    ...(failures >= max ? { lockedUntil: now + LOCKOUT_MS } : {}),
  });
}

/**
 * Clears the counter after a successful authentication.
 *
 * A pure READ when no row exists, which is the overwhelmingly common case.
 * Writing on every successful login would put a steady background write on a
 * small self-hosted box for no benefit — see the note at the top of crons.ts.
 */
export async function clearFailures(
  ctx: MutationCtx,
  key: string,
): Promise<void> {
  const row = await ctx.db
    .query("authAttempts")
    .withIndex("by_key", (q) => q.eq("key", key))
    .first();
  if (row) await ctx.db.delete(row._id);
}

/**
 * Reaps rows nobody has touched in a day.
 *
 * Pure tidiness: assertNotLocked already treats an expired window as clean, so
 * a backlog here costs disk, never correctness. Bounded with `.take` for the
 * reason spelled out at users.sweepStalePresence — an unbounded `.collect()`
 * eventually blows the read limit, at which point the sweep silently stops
 * working and nobody notices.
 */
export const gcAuthAttempts = internalMutation({
  args: {},
  handler: async (ctx) => {
    const cutoff = Date.now() - 24 * 60 * 60 * 1000;
    const stale = await ctx.db
      .query("authAttempts")
      .withIndex("by_updatedAt", (q) => q.lt("updatedAt", cutoff))
      .take(200);
    for (const r of stale) await ctx.db.delete(r._id);
  },
});

/** Refused by [consume] once a key is out of calls for its window. */
export const ERR_RATE_LIMITED = "RATE_LIMITED";

/**
 * Counts one call against [key], refusing past [max] per [windowMs].
 *
 * For how OFTEN something may happen, unlike the failure counters above,
 * which only count mistakes. A fixed window: simple, one indexed row per key,
 * and a burst at a window edge costs at most double, which every limit here
 * is sized to tolerate. Throwing is right for this one: a refused call has
 * nothing to record, so the rollback loses nothing.
 */
export async function consume(
  ctx: MutationCtx,
  key: string,
  max: number,
  windowMs: number,
): Promise<void> {
  const now = Date.now();
  const row = await ctx.db
    .query("rateBuckets")
    .withIndex("by_key", (q) => q.eq("key", key))
    .first();
  if (!row) {
    await ctx.db.insert("rateBuckets", { key, windowStart: now, count: 1 });
    return;
  }
  if (now - row.windowStart >= windowMs) {
    await ctx.db.patch(row._id, { windowStart: now, count: 1 });
    return;
  }
  if (row.count >= max) throw new Error(ERR_RATE_LIMITED);
  await ctx.db.patch(row._id, { count: row.count + 1 });
}

/** Drops counter rows idle for a day; scheduled from `crons.ts`. */
export const gcRateBuckets = internalMutation({
  args: {},
  handler: async (ctx) => {
    const cutoff = Date.now() - 24 * 60 * 60 * 1000;
    const stale = await ctx.db
      .query("rateBuckets")
      .withIndex("by_window", (q) => q.lt("windowStart", cutoff))
      .take(500);
    for (const row of stale) await ctx.db.delete(row._id);
  },
});

/** Accounts one device may create per day, and everyone per minute. */
export const MAX_SIGNUPS_PER_DEVICE_PER_DAY = 5;
export const MAX_SIGNUPS_PER_MINUTE = 30;

/**
 * Signup has no session to key on, and Convex can't see the caller's IP, so
 * this limits what it can: the device id the client sends, and the whole
 * app's rate. A script rotating device ids still meets the global ceiling,
 * which is far above any real launch-day rate.
 */
export async function throttleSignup(ctx: MutationCtx, deviceId: string) {
  await consume(ctx, `signup:device:${deviceId}`, MAX_SIGNUPS_PER_DEVICE_PER_DAY, 24 * 60 * 60 * 1000);
  await consume(ctx, "signup:global", MAX_SIGNUPS_PER_MINUTE, 60 * 1000);
}
