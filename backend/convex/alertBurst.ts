/**
 * The burst rule for the devices that cannot run it themselves.
 *
 * The first message of a burst in a room alerts; the rest land quietly in the
 * same stack; a burst that keeps going alerts again every few minutes. The
 * phones decide this on the device (ios/Shared/ShareGroup.swift and
 * android/.../ChatNotifications.kt, `AlertBurst`), the desktop app's in-app
 * ping does too (lib/push/alert_burst.dart). Same two numbers everywhere —
 * keep them in step.
 *
 * A Mac has no Notification Service Extension and a browser's service worker
 * keeps no state between pushes, so for those two the OS (or the browser)
 * plays every APNs / Web Push banner it is handed. The server decides for
 * them instead (`push.sendAlert`, `AlertSpec.quiet`).
 *
 * It costs nothing per recipient: the timing of a burst is the room's, the
 * same for everyone in it, so the state is one field on the room
 * (`rooms.alertBurstAt`) written in the patch `sendCore` already makes. What
 * is per recipient (being mentioned, having caught up since the burst began)
 * comes from the read cursor `_loadAlertTargets` fetches anyway.
 */

/** A message within this long of the room's previous one is the same burst. */
export const ALERT_BURST_GAP_MS = 45_000;

/** However long the burst runs, it alerts again after this long. */
export const ALERT_BURST_REMINDER_MS = 3 * 60_000;

/**
 * One message's step through the rule. [prevAt] is the room's previous
 * message time, [burstAt] when the room's burst last alerted.
 *
 * `alerts` false means quiet for anyone who has not read since [prevAt];
 * `burstAt` is the value to store back on the room.
 */
export function alertBurstStep(
  prevAt: number | undefined,
  burstAt: number | undefined,
  now: number,
): { alerts: boolean; burstAt: number } {
  if (
    prevAt !== undefined &&
    burstAt !== undefined &&
    now - prevAt < ALERT_BURST_GAP_MS &&
    now - burstAt < ALERT_BURST_REMINDER_MS
  ) {
    return { alerts: false, burstAt };
  }
  return { alerts: true, burstAt: now };
}

/**
 * Platforms whose banners the server quiets mid-burst. Everything else either
 * applies the rule on the device (ios, android), or never gets a push at all
 * (windows, linux — the app's own ping covers them).
 */
export const SERVER_BURST_PLATFORMS: ReadonlySet<string> = new Set([
  "macos",
  "web",
]);
