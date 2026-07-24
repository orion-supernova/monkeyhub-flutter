import { cronJobs } from "convex/server";
import { internal } from "./_generated/api";

const crons = cronJobs();

// Sweep consumed callSignals older than 1 min. The subscription has already
// delivered them; keeping the rows around bloats the by_to_unconsumed index.
crons.interval(
  "calls.gcConsumedSignals",
  { minutes: 1 },
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
  { minutes: 2 },
  internal.calls.gcStuckRinging,
  {},
);

// Presence backstop: demote users who stopped heartbeating (closed tab, killed
// app) to 'offline'. Readers already correct this on the fly via
// effectiveStatus; this keeps the stored value honest. See presence.ts.
crons.interval(
  "users.sweepStalePresence",
  { minutes: 2 },
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

export default crons;
