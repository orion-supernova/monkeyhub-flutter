import { cronJobs } from "convex/server";
import { internal } from "./_generated/api";

const crons = cronJobs();

// A note on the intervals below. This runs on a small self-hosted box, and
// every sweep here is an index scan plus a write loop. Several of them used to
// fire every minute, which on its own is a steady background load competing
// with the interactive path — a one-document mutation has been observed
// exceeding Convex's 1s function limit under it. These are all backstops for
// paths that already clean up after themselves inline, so the cost of running
// them less often is a slightly longer tail of garbage, not incorrect
// behaviour. The one exception is called out where it appears.

// Sweep consumed callSignals older than 1 min. The subscription has already
// delivered them; keeping the rows around bloats the by_to_unconsumed index.
crons.interval(
  "calls.gcConsumedSignals",
  { minutes: 2 },
  internal.calls.gcConsumedSignals,
  {},
);

// Sweep terminal-status calls older than 1 day, plus any lingering signals
// (defense in depth — purgeCallSignals should already have cleaned them).
crons.interval(
  "calls.gcTerminalCalls",
  { hours: 1 },
  internal.calls.gcTerminalCalls,
  {},
);

// Safety net: any 'ringing' call older than 90s gets forced to 'missed'.
// The per-call scheduled expireRingingCall fires at 30s; this catches the
// edge case where it didn't (backend restart, scheduler glitch, etc.).
crons.interval(
  "calls.gcStuckRinging",
  { minutes: 5 },
  internal.calls.gcStuckRinging,
  {},
);

// Group calls: reap joined participants whose heartbeat went silent and end
// emptied calls; sweep consumed pair signals. See groupCalls.ts.
// Stays at 1 minute — the exception noted above. This one is not a garbage
// collector: a participant whose heartbeat went silent keeps occupying the
// roster until it runs, so slowing it down is directly visible in a live call.
crons.interval(
  "groupCalls.gcStaleGroupParticipants",
  { minutes: 1 },
  internal.groupCalls.gcStaleGroupParticipants,
  {},
);
crons.interval(
  "groupCalls.gcConsumedGroupSignals",
  { minutes: 5 },
  internal.groupCalls.gcConsumedGroupSignals,
  {},
);

// Presence backstop: demote users who stopped heartbeating (closed tab, killed
// app) to 'offline'. Readers already correct this on the fly via
// effectiveStatus; this keeps the stored value honest. See presence.ts.
crons.interval(
  "users.sweepStalePresence",
  { minutes: 5 },
  internal.users.sweepStalePresence,
  {},
);

// Sweep push receipts past the notification TTL. Rows are normally removed on
// delete or on read; this catches the ones nobody ever acted on. See
// notifications.gcPushReceipts.
crons.interval(
  "notifications.gcPushReceipts",
  { hours: 6 },
  internal.notifications.gcPushReceipts,
  {},
);

// Reclaim stored files nothing references any more. Every code path that drops
// a storageId now deletes the blob with it, so this is the backstop for the one
// case the backend can't reach: the client uploads, then the mutation that would
// have referenced the file fails or the app is killed. Files under 24h old are
// exempt — an upload still in flight is indistinguishable from an orphan.
// See files.gcOrphanedFiles.
crons.interval(
  "files.gcOrphanedFiles",
  { hours: 24 },
  internal.files.gcOrphanedFiles,
  {},
);

export default crons;
