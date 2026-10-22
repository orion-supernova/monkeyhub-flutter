// Presence write logic, shared by every endpoint and sign-in path.
//
// Two tables (see the Phase 5 design):
//   presence      who is online. Written ONLY on a status transition, so the
//                 `presenceApi.forUsers` subscribers re-run a few times a day.
//   presenceBeats the 90 s liveness stamp. Nothing subscribes to it; the sweep
//                 reads it to demote clients that vanished.
//
// `presence.lastSeen` is ABSENT while online and set when the user leaves the
// foreground (away/offline), or to the last beat when the sweep demotes. That
// is what keeps the beat off `presence`.
//
// Compat mirror: until old builds are gone, `users.status/lastSeen` are what
// they read. Writers here copy to `users` on transitions, and refresh
// `users.lastSeen` at most every COMPAT_MIRROR_MS while live. Env
// `PRESENCE_COMPAT_MIRROR=off` stops all of it without a redeploy. Callers on
// the OLD endpoints (which patch `users` themselves) pass `mirror: false`.
//
// None of these functions rate-limit or touch sessions; the endpoint does.
import { PRESENCE_WRITE_INTERVAL_MS } from "./presence";
import { isSystemAccount } from "./systemAccount";

export type PresenceStatus = "online" | "away" | "offline";

/** A live beat younger than this is not rewritten. Same as the old users throttle. */
export const BEAT_THROTTLE_MS = PRESENCE_WRITE_INTERVAL_MS; // 90_000
/** Live refresh of `users.lastSeen` for old viewers, at most this often. */
export const COMPAT_MIRROR_MS = 300_000;
/** Window old-path readers must use against `users.lastSeen` while mirrored. */
export const COMPAT_OFFLINE_MS = 420_000;

/** A beat this soon after an explicit offline does not bring the user back. */
export const RESURRECT_GUARD_MS = 60_000;

/** Tombstoned or suspended: presence must not be written for them. */
function isGone(user: any): boolean {
  return user.deletingAt !== undefined || user.suspendedAt !== undefined;
}

export function compatMirrorEnabled(): boolean {
  return process.env.PRESENCE_COMPAT_MIRROR !== "off";
}

export function isPresenceStatus(s: unknown): s is PresenceStatus {
  return s === "online" || s === "away" || s === "offline";
}

type Opts = {
  /** One `Date.now()` for the whole call. */
  now: number;
  /** Mirror to `users` (default true). Old endpoints pass false. */
  mirror?: boolean;
};

async function presenceRow(ctx: any, userId: any) {
  return await ctx.db
    .query("presence")
    .withIndex("by_user", (q: any) => q.eq("userId", userId))
    .first();
}

async function beatRow(ctx: any, userId: any) {
  return await ctx.db
    .query("presenceBeats")
    .withIndex("by_user", (q: any) => q.eq("userId", userId))
    .first();
}

/** Insert or patch the beat. Always writes; callers decide whether to. */
async function writeBeat(ctx: any, userId: any, row: any, beatAt: number, live: boolean) {
  if (row) {
    if (row.beatAt === beatAt && row.live === live) return;
    await ctx.db.patch(row._id, { beatAt, live });
  } else {
    await ctx.db.insert("presenceBeats", { userId, beatAt, live });
  }
}

/** Copy a transition to the users row, for old viewers. */
async function mirrorTransition(
  ctx: any,
  user: any,
  status: PresenceStatus,
  lastSeen: number,
) {
  if (!compatMirrorEnabled() || !user) return;
  await ctx.db.patch(user._id, { status, lastSeen });
}

/**
 * Throttled live refresh of `users.lastSeen`. Reads the users row, so only
 * call it from a path that is already writing a beat.
 */
async function mirrorLive(ctx: any, user: any, now: number, status: PresenceStatus) {
  if (!compatMirrorEnabled()) return;
  // The old sweep may have flipped users.status to offline between refreshes;
  // restore it whenever it disagrees with presence.
  const statusDiffers = user.status !== status;
  const stale = user.lastSeen == null || now - user.lastSeen >= COMPAT_MIRROR_MS;
  if (!statusDiffers && !stale) return;
  await ctx.db.patch(user._id, {
    ...(statusDiffers ? { status } : {}),
    ...(stale || statusDiffers ? { lastSeen: now } : {}),
  });
}

/**
 * The 90 s heartbeat.
 *
 * - Fresh live beat (< BEAT_THROTTLE_MS) and presence online/away: read only.
 * - Presence absent or offline and `resurrect` is not set: does nothing at all
 *   (a stray late beat from a signed-out client must not bring anyone back,
 *   and an old-build user with no row yet is covered by `setStatus`).
 * - Otherwise stamps the beat (live: true). With `resurrect`, a missing or
 *   offline presence row becomes `resurrect` ("online" | "away").
 *
 * Returns whether any document was written.
 */
export async function noteBeat(
  ctx: any,
  userId: any,
  opts: Opts & { resurrect?: "online" | "away" },
): Promise<{ wrote: boolean }> {
  const { now } = opts;
  const mirror = opts.mirror ?? true;
  const [beat, pres] = await Promise.all([beatRow(ctx, userId), presenceRow(ctx, userId)]);
  const alive = pres != null && pres.status !== "offline";
  if (alive && beat?.live && now - beat.beatAt < BEAT_THROTTLE_MS) {
    return { wrote: false };
  }
  if (!alive && !opts.resurrect) return { wrote: false };
  // A beat already in flight when the client went offline on purpose must not
  // undo it. Sweep-demoted rows have lastSeen = beatAt (>= 180 s old), so they
  // still resurrect after a network gap.
  if (
    !alive &&
    pres?.status === "offline" &&
    pres.lastSeen != null &&
    now - pres.lastSeen < RESURRECT_GUARD_MS
  ) {
    return { wrote: false };
  }
  // Only reached when a write is due, so the extra users read is off the hot path.
  const user = await ctx.db.get(userId);
  if (!user || isSystemAccount(user) || isGone(user)) return { wrote: false };
  if (!alive && opts.resurrect) {
    await writePresence(ctx, user, pres, opts.resurrect, now, mirror);
  } else if (mirror) {
    await mirrorLive(ctx, user, now, pres!.status);
  }
  await writeBeat(ctx, userId, beat, now, true);
  return { wrote: true };
}

/**
 * Writes the presence row for a transition to [status]. `lastSeen` absent for
 * online, [lastSeen] (default now) otherwise. Levels are copied from the
 * users row on insert.
 */
async function writePresence(
  ctx: any,
  user: any,
  existing: any,
  status: PresenceStatus,
  now: number,
  mirror: boolean,
  lastSeen: number = now,
) {
  const ls = status === "online" ? undefined : lastSeen;
  if (existing) {
    await ctx.db.patch(existing._id, { status, lastSeen: ls });
  } else {
    await ctx.db.insert("presence", {
      userId: user._id,
      status,
      ...(ls !== undefined ? { lastSeen: ls } : {}),
      ...(user.visibility?.status !== undefined
        ? { statusLevel: user.visibility.status }
        : {}),
      ...(user.visibility?.lastSeen !== undefined
        ? { lastSeenLevel: user.visibility.lastSeen }
        : {}),
    });
  }
  if (mirror) await mirrorTransition(ctx, user, status, lastSeen);
}

/**
 * Move the user to [status].
 *
 * Repeats (same status) write no `presence` row. The beat is upserted:
 * online/away -> live now (only when stale or not live, unless the status
 * changed); offline -> live: false, so the sweep skips them. System accounts
 * and missing users are ignored (absent reads as offline).
 *
 * Does NOT rate-limit: the endpoint does that before calling.
 */
export async function setStatus(
  ctx: any,
  userId: any,
  status: PresenceStatus,
  opts: Opts,
): Promise<{ changed: boolean }> {
  const { now } = opts;
  const mirror = opts.mirror ?? true;
  const user = await ctx.db.get(userId);
  if (!user || isSystemAccount(user)) return { changed: false };
  // Nothing comes back online for a tombstoned or suspended account; going
  // offline stays allowed (suspension and deletion use it).
  if (isGone(user) && status !== "offline") return { changed: false };
  const [beat, pres] = await Promise.all([beatRow(ctx, userId), presenceRow(ctx, userId)]);
  const changed = !pres || pres.status !== status;
  if (changed) await writePresence(ctx, user, pres, status, now, mirror);
  const live = status !== "offline";
  if (changed || !beat || beat.live !== live || (live && now - beat.beatAt >= BEAT_THROTTLE_MS)) {
    await writeBeat(ctx, userId, beat, now, live);
  }
  return { changed };
}

/** Sign-in / pairing: the user is now online. Same as `setStatus(online)`. */
export async function markOnline(ctx: any, userId: any, opts: Opts) {
  return await setStatus(ctx, userId, "online", opts);
}

/** Sign-out / suspension / last session gone: the user is now offline. */
export async function markOffline(ctx: any, userId: any, opts: Opts) {
  return await setStatus(ctx, userId, "offline", opts);
}

/**
 * Sweep demotion for a client whose beat went stale: beat -> live: false,
 * presence -> offline with `lastSeen = beatAt`. No-op if presence is already
 * offline/absent (the beat is still retired).
 */
export async function demoteStale(
  ctx: any,
  userId: any,
  beatAt: number,
  opts: Opts,
): Promise<{ changed: boolean }> {
  const mirror = opts.mirror ?? true;
  const [beat, pres] = await Promise.all([beatRow(ctx, userId), presenceRow(ctx, userId)]);
  if (beat?.live) await writeBeat(ctx, userId, beat, beat.beatAt, false);
  if (!pres || pres.status === "offline") return { changed: false };
  const user = await ctx.db.get(userId);
  await ctx.db.patch(pres._id, { status: "offline", lastSeen: beatAt });
  if (mirror) await mirrorTransition(ctx, user, "offline", beatAt);
  return { changed: true };
}

/** Account deletion: remove both rows. Returns how many documents went. */
export async function clearPresence(ctx: any, userId: any): Promise<number> {
  let n = 0;
  for (const table of ["presence", "presenceBeats"] as const) {
    const rows = await ctx.db
      .query(table)
      .withIndex("by_user", (q: any) => q.eq("userId", userId))
      .take(50);
    for (const r of rows) {
      await ctx.db.delete(r._id);
      n++;
    }
  }
  return n;
}

/**
 * Copy `users.visibility.status/lastSeen` onto the presence row after the
 * user changed them. Pass the NEW visibility map. Writes only on a real
 * difference; no row means nothing to do (levels are copied on insert).
 */
export async function syncLevels(
  ctx: any,
  userId: any,
  visibility: { status?: string; lastSeen?: string } | undefined,
): Promise<{ changed: boolean }> {
  const pres = await presenceRow(ctx, userId);
  if (!pres) return { changed: false };
  const statusLevel = visibility?.status;
  const lastSeenLevel = visibility?.lastSeen;
  if (pres.statusLevel === statusLevel && pres.lastSeenLevel === lastSeenLevel) {
    return { changed: false };
  }
  await ctx.db.patch(pres._id, { statusLevel, lastSeenLevel });
  return { changed: true };
}
