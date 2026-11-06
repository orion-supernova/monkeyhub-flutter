import { isReleasedToRecipient } from "./childGuard";

/**
 * Two derived per-user rows, maintained by the write hooks in `dbHooks.ts`.
 *
 *  - `userPushState`: the devices a push may reach. A pure function of the
 *    user's `userDevices` rows and live `sessions` (see [buildPushDevices]), so
 *    the hooks simply recompute it whenever either table changes a field that
 *    matters. Both lists are tiny (a handful of handsets).
 *  - `userBadgeCounts`: pending friend requests and room invitations released
 *    to the user. Moved by exact deltas (see [applyPendingChange]).
 *
 * A MISSING row means "not computed yet" to every reader, which falls back to
 * the old computation; `userDerived.backfill` fills the rest.
 *
 * Session liveness here is `revokedAt === undefined`, identical to
 * `sessionCore.liveSessionDeviceIds`. Idle expiry (90 days) is enforced by the
 * sweep that REVOKES idle sessions by a patch of `revokedAt`, which runs the
 * hook, so a row cannot outlive an expired session by more than the sweep
 * interval, exactly as before. `lastSeenAt` touches are not hooked.
 */

/** Fields of `userDevices` that change who a push can reach. */
export const PUSH_DEVICE_FIELDS = [
  "userId", "deviceId", "platform", "pushEnabled", "apnsToken", "apnsEnv",
  "fcmToken", "webEndpoint", "webP256dh", "webAuth", "locale",
] as const;

/** Fields of `sessions` that change which handsets are signed in. */
export const PUSH_SESSION_FIELDS = ["userId", "deviceId", "revokedAt"] as const;

export const FRIEND_PENDING_FIELDS = ["friendId", "status", "stage"] as const;
export const INVITE_PENDING_FIELDS = ["inviteeId", "status", "stage"] as const;

export type PushDevice = {
  deviceRowId: string;
  deviceId: string;
  platform: string;
  apnsToken?: string;
  apnsEnv?: "sandbox" | "production";
  fcmToken?: string;
  web?: { endpoint: string; p256dh: string; auth: string };
  locale?: string;
};

/** The alertable devices, from the user's device rows and live device ids. */
export function buildPushDevices(rows: any[], live: Set<string>): PushDevice[] {
  const devices: PushDevice[] = [];
  for (const r of rows) {
    if (r.pushEnabled === false) continue;
    if (!live.has(r.deviceId)) continue;
    const web =
      r.webEndpoint && r.webP256dh && r.webAuth
        ? { endpoint: r.webEndpoint, p256dh: r.webP256dh, auth: r.webAuth }
        : undefined;
    if (!r.apnsToken && !r.fcmToken && !web) continue;
    const d: PushDevice = {
      deviceRowId: r._id,
      deviceId: r.deviceId,
      platform: r.platform,
    };
    if (r.apnsToken !== undefined) d.apnsToken = r.apnsToken;
    if (r.apnsEnv !== undefined) d.apnsEnv = r.apnsEnv;
    if (r.fcmToken !== undefined) d.fcmToken = r.fcmToken;
    if (web) d.web = web;
    if (r.locale !== undefined) d.locale = r.locale;
    devices.push(d);
  }
  return devices;
}

/** Recompute [userId]'s push state from the source tables (absolute). */
export async function computePushDevices(db: any, userId: any): Promise<PushDevice[]> {
  const rows = await db
    .query("userDevices")
    .withIndex("by_user", (q: any) => q.eq("userId", userId))
    .collect();
  const sessions = await db
    .query("sessions")
    .withIndex("by_user_live_seen", (q: any) =>
      q.eq("userId", userId).eq("revokedAt", undefined),
    )
    .collect();
  const live = new Set<string>(sessions.map((s: any) => s.deviceId));
  return buildPushDevices(rows, live);
}

/** False for an account that is deleted or mid-deletion. */
async function isLiveUser(db: any, userId: any): Promise<boolean> {
  const user = await db.get(userId);
  return !!user && user.deletingAt === undefined;
}

/** Write [userId]'s push row. A deleted user gets no row. */
export async function refreshPushState(db: any, userId: any): Promise<void> {
  if (!userId) return;
  const row = await db
    .query("userPushState")
    .withIndex("by_user", (q: any) => q.eq("userId", userId))
    .first();
  // The deletion cascade removes devices and sessions through the hooked db;
  // never leave a row behind for an account that is gone or going (the
  // cascade may already have swept this table before those writes land).
  if (!(await isLiveUser(db, userId))) {
    if (row) await db.delete(row._id);
    return;
  }
  const devices = await computePushDevices(db, userId);
  // Identical content is the common case (a re-registration): no write, so no
  // subscriber or transaction that read the row is disturbed.
  if (row && JSON.stringify(row.devices) === JSON.stringify(devices)) return;
  if (row) await db.replace(row._id, { userId, devices });
  else await db.insert("userPushState", { userId, devices });
}

/** The pending count one `friendships` row adds to its recipient. */
export function friendContribution(row: any): number {
  return row && row.status === "pending" && isReleasedToRecipient(row.stage) ? 1 : 0;
}

/** The pending count one `roomInvitations` row adds to its invitee. */
export function inviteContribution(row: any): number {
  return row && row.status === "pending" && isReleasedToRecipient(row.stage) ? 1 : 0;
}

/** Absolute counts for [userId], by scanning the source tables. */
export async function computePendingCounts(
  db: any,
  userId: any,
): Promise<{ requests: number; invites: number }> {
  const friendRows = await db
    .query("friendships")
    .withIndex("by_friend", (q: any) => q.eq("friendId", userId))
    .collect();
  const inviteRows = await db
    .query("roomInvitations")
    .withIndex("by_invitee_status", (q: any) =>
      q.eq("inviteeId", userId).eq("status", "pending"),
    )
    .collect();
  return {
    requests: friendRows.reduce((n: number, f: any) => n + friendContribution(f), 0),
    invites: inviteRows.reduce((n: number, r: any) => n + inviteContribution(r), 0),
  };
}

/** Write absolute pending counts for [userId]. A deleted user gets no row. */
export async function refreshPendingCounts(db: any, userId: any): Promise<void> {
  if (!userId) return;
  const row = await db
    .query("userBadgeCounts")
    .withIndex("by_user", (q: any) => q.eq("userId", userId))
    .first();
  if (!(await isLiveUser(db, userId))) {
    if (row) await db.delete(row._id);
    return;
  }
  const counts = await computePendingCounts(db, userId);
  if (row) await db.replace(row._id, { userId, ...counts });
  else await db.insert("userBadgeCounts", { userId, ...counts });
}

/**
 * Move a user's pending count by what one write changed. [which] is the
 * counter. A user with no row yet is computed absolutely instead (the write is
 * already applied, so the scan includes it): the one-time cost of a row that
 * the backfill has not reached.
 */
async function bump(db: any, userId: any, which: "requests" | "invites", delta: number) {
  if (!userId) return;
  const row = await db
    .query("userBadgeCounts")
    .withIndex("by_user", (q: any) => q.eq("userId", userId))
    .first();
  if (!row) return refreshPendingCounts(db, userId);
  if (delta === 0) return;
  await db.patch(row._id, { [which]: Math.max(0, row[which] + delta) });
}

/**
 * Apply one `friendships` (or `roomInvitations`) change. Called after the write.
 * The recipient is `friendId` / `inviteeId`; a patch that moves it (never done
 * today) is handled as a removal from one and an add to the other.
 */
export async function applyPendingChange(
  db: any,
  kind: "friend" | "invite",
  before: any,
  after: any,
): Promise<void> {
  const [field, which, contrib] =
    kind === "friend"
      ? (["friendId", "requests", friendContribution] as const)
      : (["inviteeId", "invites", inviteContribution] as const);
  const oldTo = before?.[field];
  const newTo = after?.[field];
  const oldN = contrib(before);
  const newN = contrib(after);
  if (oldTo === newTo) return bump(db, newTo, which, newN - oldN);
  await bump(db, oldTo, which, -oldN);
  await bump(db, newTo, which, newN);
}
