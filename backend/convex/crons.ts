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

// Safety net: any 'active' call whose heartbeat has gone silent for 3+ min
// (client crashed, battery died, OS jetsam) gets forced to 'ended' and both
// sides' native CallKit/ConnectionService cards are cleared. See calls.ts
// heartbeat/gcStuckActive.
crons.interval(
  "calls.gcStuckActive",
  { minutes: 5 },
  internal.calls.gcStuckActive,
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

// Burn view-once photos past their 14-day deadline. Every armed send already
// schedules its own `burnViewOnce` at exactly that moment, so this is purely a
// repair sweep for the ones the scheduler lost (a restart mid-flight, say).
// Cheap: `by_viewOnce_deadline` leads with the boolean, so the scan touches
// only armed messages, not the whole table. See messages.gcExpiredViewOnce.
crons.interval(
  "messages.gcExpiredViewOnce",
  { hours: 6 },
  internal.messages.gcExpiredViewOnce,
  {},
);

// Reap failed-login counters nobody has touched in a day. Pure tidiness —
// assertNotLocked already treats a closed window as clean, so a backlog here
// costs disk and nothing else. See rateLimit.gcAuthAttempts.
crons.interval(
  "rateLimit.gcAuthAttempts",
  { hours: 6 },
  internal.rateLimit.gcAuthAttempts,
  {},
);

// Re-check stored Sign in with Apple refresh tokens. Unlike everything above
// this is not a garbage collector — Apple's TN3194 asks that grants be
// validated periodically, so that one the user revoked from their own Apple ID
// settings is noticed rather than sat on indefinitely.
//
// Cheap by construction: each identity is only re-checked once a day, the batch
// is capped at 50, and only accounts that actually signed in with Apple have a
// token at all. See socialAuth.validateAppleGrants.
crons.interval(
  "socialAuth.validateAppleGrants",
  { hours: 12 },
  internal.socialAuth.validateAppleGrants,
  {},
);

// Delete moderation reports past the 24-month retention period. Like the Apple
// grant check above, this is not a garbage collector: nothing else ever deletes
// a report, so this job IS the retention policy the privacy policy publishes.
// Daily rather than hourly — the cutoff moves by a day at a time, so anything
// more frequent is a scan for nothing. See users.gcExpiredReports.
crons.interval(
  "users.gcExpiredReports",
  { hours: 24 },
  internal.users.gcExpiredReports,
  {},
);

// The same job for problem-report receipts, which are a different table and a
// much shorter period — 90 days, not 24 months. Same reason it exists at all:
// nothing else deletes one, so without this the table is an append-only ledger
// of device identifiers. See problemReports.gcExpiredReports.
crons.interval(
  "problemReports.gcExpiredReports",
  { hours: 24 },
  internal.problemReports.gcExpiredReports,
  {},
);

export default crons;
