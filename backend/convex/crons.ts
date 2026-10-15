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
// Day-old ended group calls, their participants, and their signals. The 1:1
// table had this from the start (calls.gcTerminalCalls); the group tables
// grew forever.
crons.interval(
  "groupCalls.gcTerminalGroupCalls",
  { hours: 1 },
  internal.groupCalls.gcTerminalGroupCalls,
  {},
);

// Presence backstop: demote users who stopped heartbeating (closed tab, killed
// app) to 'offline'. Readers already correct this on the fly via
// effectiveStatus; this keeps the stored value honest. See presence.ts.
//
// Every minute: a subscription does not re-run because time passed, so a
// reader's `effectiveStatus` only goes offline when this patch lands. At five
// minutes a closed app read as online for up to eight. The range is per
// status and usually empty, so a tick is a couple of index reads.
crons.interval(
  "users.sweepStalePresence",
  { minutes: 1 },
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

// Repair incomplete room teardowns: scan for roomMembers rows whose room
// document no longer exists (can happen if a teardown crashes mid-flow), and
// delete the orphaned messages, reactions, and membership rows. A deleted room
// becomes permanently invisible — its unread messages are unreachable and would
// otherwise inflate the badge forever. See roomCleanup.ts and badges.ts.
crons.interval(
  "roomCleanup.gcOrphanedRoomMemberships",
  { hours: 24 },
  internal.roomCleanup.gcOrphanedRoomMemberships,
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

// End live-location shares past their deadline. Same shape and same reasoning
// as the sweep above: every share schedules its own `expireLiveLocation` at
// exactly its deadline, and `by_liveLocation_live_expiry` leads with the
// boolean so the scan touches only shares that are still running.
//
// Six-hourly and not by the minute, which needs saying because the failure this
// repairs is the worst one this feature has — a position still being broadcast
// after its time. Three things make the interval right anyway: the per-share
// `runAt` is the actual mechanism and this only catches schedules the
// deployment lost; `updateLiveLocation` refuses (and ends) an overdue share on
// the very next fix, so a share whose publisher is alive stops itself; and the
// clients render expiry from `liveExpiresAt`, so an overdue row already reads
// as ended on every screen showing it. Tightening this to a minute would buy
// tidier rows at the cost the header of this file describes.
// See messages.gcExpiredLiveShares.
crons.interval(
  "messages.gcExpiredLiveShares",
  { hours: 6 },
  internal.messages.gcExpiredLiveShares,
  {},
);

// Release scheduled messages whose time passed and whose `runAt` never came.
//
// The one job in this file that is neither a garbage collector nor a tidiness
// pass, and the interval says so: five minutes rather than six hours. Every
// other sweep here repairs a stale ROW, which costs disk and nothing else. This
// one repairs a message the user was told would be sent and was not — the same
// category as calls.gcStuckRinging above, and the same interval for the same
// reason.
//
// Affordable at that rate despite the header's warning because
// `by_pending_due` leads with the boolean and the range stops at the first row
// that is not yet due: a deployment with nothing overdue pays a single index
// probe and writes nothing at all. The per-pass cap keeps a genuine backlog
// (the scheduler lost jobs wholesale) from turning into one mutation that
// exceeds the 1s limit and therefore never drains any of it.
// See scheduledMessages.gcOverdue.
crons.interval(
  "scheduledMessages.gcOverdue",
  { minutes: 5 },
  internal.scheduledMessages.gcOverdue,
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

// The moderation room's evidence snapshots, on the same 24-month period as the
// `reports` rows they belong to. They outlive their source messages on purpose
// (a reported self-destructing message must still be reviewable), so they
// need a lifetime of their own. See moderation.gcExpiredEvidence.
crons.interval(
  "moderation.gcExpiredEvidence",
  { hours: 24 },
  internal.moderation.gcExpiredEvidence,
  {},
);

// Sweep expired device-login requests (QR / short-code sign-in for a
// signed-out web or desktop client). Unlike pairingCodes/releaseCodes, a row
// here often belongs to nobody at all — the desktop that created it may never
// be scanned, approved, or exchanged — so nothing else ever reaps it.
// `expiresAt` is fixed at creation regardless of how the row ends, so an
// hourly sweep is plenty for a value measured in minutes. See deviceLogin.ts.
crons.interval(
  "deviceLogin.gcExpiredDeviceLoginRequests",
  { hours: 1 },
  internal.deviceLogin.gcExpiredDeviceLoginRequests,
  {},
);

// Reap userDevices rows nobody has used in 90 days. Every sign-out path
// already deletes its own row inline (voipTokens.clearDeviceToken,
// removeOtherDevices) — this is the backstop for the ones that never landed:
// an app killed mid-request, an uninstall, a browser tab closed without
// running any unload path, or a row written before that inline cleanup
// shipped. `by_last_seen` is refreshed on every login, resume and token
// upload, so a device still in use never approaches the cutoff.
// See voipTokens.gcStaleDevices.
crons.interval(
  "voipTokens.gcStaleDevices",
  { hours: 24 },
  internal.voipTokens.gcStaleDevices,
  {},
);

// The once-a-day "you haven't played today" nudge — the only push this backend
// sends that nobody's action produced. Quarter-hourly, and that is not a
// frequency: it is a resolution. Each tick asks whose wall clock reads 12:00
// right now and nudges only them, so one job delivers at local noon worldwide.
// Fifteen minutes because India (+5:30), Nepal (+5:45) and Chatham (+12:45)
// have noons an hourly job would never land on.
//
// A cron STRING and not `crons.interval({ minutes: 15 })`, which is what this
// was and which quietly does not mean the same thing. An interval is measured
// from the end of the previous run, so the ticks slide later by however long
// each one took — a few seconds a tick, several minutes a day, without bound.
// Every other sweep in this file shrugs that off; this one cannot. A tick is
// snapped to the nearest quarter hour to decide WHICH TIME ZONE it belongs to,
// so a schedule that drifts past the halfway mark simply skips a quarter — and
// the zone that quarter addresses hears nothing at all that day. `0,15,30,45`
// is wall-clock anchored, so all 96 ticks happen, exactly once each.
//
// Cheap despite the rate, which this file's header demands justifying: a tick
// is one equality probe on `by_tz_offset` per candidate zone, and the great
// majority of the 96 daily ticks match a zone nobody lives in and return
// nothing. Only the handful that hit a populated offset do any work at all —
// and a zone already nudged today costs one document read per person to
// establish that, which is what makes the hour-long catch-up window in
// `dueOffsetsAt` affordable. See dailyNudge.ts.
crons.cron(
  "dailyNudge.run",
  "0,15,30,45 * * * *",
  internal.dailyNudge.run,
  {},
);

// Sweep revoked sessions a week after revocation. Live sessions are never
// touched — they do not expire — so this only reclaims rows nobody can use.
crons.interval(
  "sessions.gcRevokedSessions",
  { hours: 6 },
  internal.sessionCore.gcRevokedSessions,
  {},
);

export default crons;
