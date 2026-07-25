// Presence staleness helpers.
//
// `users.status` is a stored string ("online" | "away" | "offline") written by
// the client on lifecycle transitions. The problem it can't solve on its own:
// when a client vanishes without a clean "offline" write — a closed browser
// tab (Flutter web never reliably fires AppLifecycleState.detached), a crash,
// or a hard-killed native app — the stored value stays "online"/"away" forever.
//
// The fix is time-based: the client stamps `lastSeen` on a periodic heartbeat
// (see users.heartbeat), and readers treat a user whose `lastSeen` is older
// than PRESENCE_OFFLINE_MS as offline regardless of the stored string. That
// self-heals every platform, and a cron (users.sweepStalePresence) persists the
// demotion so the stored value stays honest too.

/** Heartbeat cadence on the client, in ms. Keep the window below comfortably
 *  larger than this so a throttled background tab (browsers slow timers to
 *  ~once/minute) still counts as present. */
export const PRESENCE_OFFLINE_MS = 180_000; // 3 minutes

/**
 * How stale `lastSeen` must be before a heartbeat actually writes.
 *
 * Every write to a `users` row invalidates all subscriptions that read it, and
 * several hot ones do (rooms.listRooms, friends.list, the request lists). So an
 * unconditional 30s patch per client recomputed the room and friend lists of
 * everyone sharing a room or friendship with that client, continuously — enough
 * to push a single-document mutation past Convex's 1s function limit on a small
 * deployment.
 *
 * Skipping the write while `lastSeen` is fresh makes most beats pure reads, at
 * the cost of `lastSeen` precision. That budget is what PRESENCE_OFFLINE_MS
 * spends: keep this comfortably below it, or a present user reads as offline
 * between writes. Clients still call every 30s — the round-trip is also their
 * connectivity canary — they just usually don't cause a write.
 */
export const PRESENCE_WRITE_INTERVAL_MS = 90_000; // 1.5 minutes

/**
 * The effective presence status accounting for heartbeat staleness. Returns
 * "offline" when the stored status is already offline, or when `lastSeen` is
 * older than the offline window; otherwise the stored status.
 */
export function effectiveStatus(
  status: string | undefined,
  lastSeen: number | undefined,
  now: number = Date.now(),
): string {
  if (status === "offline") return "offline";
  if (lastSeen == null) return status ?? "offline";
  return now - lastSeen > PRESENCE_OFFLINE_MS ? "offline" : status ?? "offline";
}
