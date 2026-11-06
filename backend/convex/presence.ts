// Presence timing constants.
//
// Presence lives in the `presence` / `presenceBeats` tables (presenceCore.ts,
// presenceApi.ts). A client that vanishes without a clean "offline" (closed
// tab, crash, killed app) stops beating; `presenceApi.sweepStale` demotes it
// once its last beat is older than PRESENCE_OFFLINE_MS.

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
