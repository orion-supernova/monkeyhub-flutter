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
export const PRESENCE_OFFLINE_MS = 120_000; // 2 minutes

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
