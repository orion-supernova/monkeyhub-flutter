import { internalMutation } from "./_generated/server";
import { mutation, query } from "./functions";
import { internal } from "./_generated/api";
import { v } from "convex/values";
import { guardOutgoing, permissionsFor, sendCore } from "./messages";

// ── Tuning ──────────────────────────────────────────────────────────────────

/**
 * Closest a message may be scheduled to now.
 *
 * Not a UI nicety — it is the slack that makes a client's clock harmless. The
 * custom picker sends an absolute instant it computed from the DEVICE's clock
 * (it has to: "Friday 9pm" is a wall-clock intent in the user's timezone, and
 * the server cannot derive a timezone it was never told). A phone running two
 * minutes fast would otherwise be able to name an instant already in the past,
 * and `runAt` on a past date fires immediately — turning "schedule" into "send
 * now" with no way for the user to tell what happened.
 *
 * A minute is comfortably more than any plausible phone skew and small enough
 * that nobody meets it by accident; the picker refuses below two minutes so
 * this is only ever reached by a stale screen or a hostile client.
 */
const MIN_LEAD_MS = 60_000;

/**
 * Furthest ahead a message may be scheduled: one year.
 *
 * Convex's scheduler takes any instant, so the horizon is a product decision
 * rather than a technical limit, and a year is where the useful cases stop —
 * birthdays and anniversaries are the reason this feature is worth having at
 * all, and everything beyond them is a reminder app.
 *
 * It is also the number that makes `jobId` worth storing: at this range a
 * cancelled schedule that left its job behind would sit in `_scheduled_
 * functions` for twelve months.
 */
const MAX_HORIZON_MS = 365 * 24 * 60 * 60 * 1000;

/**
 * How many messages one person may have queued in one room, and in total.
 *
 * A staging table is writable by any client that can call `schedule`, and
 * unlike `messages` nothing else bounds it — a scheduled row is invisible to
 * everyone but its author, so the social check that keeps people from flooding
 * a room does not apply. These are the backstop.
 *
 * Sized to be unreachable by hand and cheap to enforce: both counts come from
 * a `.take(cap + 1)` on an index that already leads with the right key, so the
 * check reads at most twenty-one rows.
 */
const MAX_PENDING_PER_ROOM = 20;
const MAX_PENDING_PER_USER = 100;

/**
 * Rows the overdue sweep will release in one pass.
 *
 * Small on purpose: this runs on the box `crons.ts` describes, and each item is
 * a full `sendCore` — an insert, a room patch and a push schedule. A backlog
 * this size means the scheduler lost jobs wholesale, and draining it over
 * several ticks is better than one mutation that blows the 1s limit and
 * therefore never finishes any of them.
 */
const OVERDUE_SWEEP_LIMIT = 25;

/** The wire shape of one formatting span. Mirrors `messages.formattingArg`. */
const formattingArg = v.optional(
  v.array(
    v.object({
      start: v.number(),
      end: v.number(),
      type: v.string(),
      url: v.optional(v.string()),
    })
  )
);

// ── Helpers ─────────────────────────────────────────────────────────────────

/**
 * Turns what the client asked for into the instant this will actually send.
 *
 * Accepts either form, and the split is deliberate rather than sloppy:
 *
 *  * `delayMs` — "in an hour". A LENGTH, so the server adds it to its own
 *    clock and a phone running fast cannot schedule short. This is the
 *    `rooms:muteRoom` rule, and every relative preset uses it.
 *  * `sendAt` — "Friday at 9pm". A wall-clock intent, which only means anything
 *    in the user's own timezone. The server has no timezone for the user and
 *    should not start storing one for this, so the client resolves the instant
 *    and the server range-checks it. [MIN_LEAD_MS] is what makes that safe.
 *
 * Throws rather than clamping. Clamping a year-and-a-day into a year would send
 * the message on a date the user did not pick and was never shown, which is a
 * worse outcome than being told no — and the client already refuses out-of-range
 * values, so reaching this means a stale screen.
 */
function resolveSendAt(delayMs?: number, sendAt?: number): number {
  const now = Date.now();
  if (delayMs === undefined && sendAt === undefined) {
    throw new Error("SCHEDULE_NO_TIME");
  }
  if (delayMs !== undefined && sendAt !== undefined) {
    throw new Error("SCHEDULE_AMBIGUOUS_TIME");
  }
  const at = delayMs !== undefined ? now + delayMs : sendAt!;
  if (!Number.isFinite(at)) throw new Error("SCHEDULE_OUT_OF_RANGE");
  if (at < now + MIN_LEAD_MS) throw new Error("SCHEDULE_OUT_OF_RANGE");
  if (at > now + MAX_HORIZON_MS) throw new Error("SCHEDULE_OUT_OF_RANGE");
  return Math.round(at);
}

/**
 * Loads a row and proves the caller wrote it.
 *
 * Ownership is checked against the STORED `userId`, never against an id the
 * caller supplied alongside the row id — a scheduled message is private to its
 * author until it sends, so "whose is this" must not be answerable by asserting
 * it. `NOT_YOURS` rather than a not-found, because the row genuinely exists and
 * pretending otherwise would make a real bug indistinguishable from a race.
 */
async function ownedRow(ctx: any, id: any, userId: any) {
  const row = await ctx.db.get(id);
  if (!row) throw new Error("SCHEDULE_GONE");
  if (row.userId.toString() !== userId.toString()) {
    throw new Error("NOT_YOURS");
  }
  return row;
}

/**
 * Drops the `runAt` job a row is waiting on, if it still has one.
 *
 * Tidiness, NOT correctness. `release` re-reads its row and refuses unless
 * `pending` is still set and `sendAt` still matches the instant the job was
 * created for, so a cancel that never happened costs one no-op invocation. That
 * is the same "the handler checks, so a lost schedule is survivable" contract
 * every other scheduled job in this deployment runs on (`expireMessage`,
 * `burnViewOnce`, `expireLiveLocation`) — this is the first place that also
 * bothers to clean up, because a one-year horizon makes the alternative a
 * year's worth of dead jobs.
 *
 * Swallows its own failure: cancelling an already-finished job is legal but
 * cancelling one whose id has been reaped is not, and a tidying step must never
 * be the reason a user's delete fails.
 */
async function dropJob(ctx: any, jobId: any) {
  if (!jobId) return;
  try {
    await ctx.scheduler.cancel(jobId);
  } catch (_) {
    // See above.
  }
}

/**
 * Everything `sendCore` needs to post [row], and nothing it doesn't.
 *
 * Spelled out rather than spread from the row so the staging table can grow a
 * column without silently handing it to `send` as an argument it happens to
 * share a name with.
 */
function sendArgsFor(row: any) {
  return {
    roomId: row.roomId,
    userId: row.userId,
    content: row.content,
    type: "text",
    replyToId: row.replyToId,
    mentionedUserIds: row.mentionedUserIds,
    mentionsEveryone: row.mentionsEveryone,
    formatting: row.formatting,
    // THE idempotency key, and the reason `clientId` is required on the table.
    // A release that commits its insert and then loses the transaction — the
    // deployment restarts mid-flight — re-runs and finds its own message
    // through `messages.by_room_user_client` instead of posting a second one.
    clientId: row.clientId,
  };
}

// ── Scheduling ──────────────────────────────────────────────────────────────

/**
 * Stages a message for later delivery.
 *
 * Runs the full outgoing guard NOW as well as at release, which is not
 * redundant: it is the only moment there is a client on the line to be told
 * why. A child whose room needs a grown-up's approval gets
 * `ERR_APPROVAL_REQUIRED` here and lands in the same "ask a grown-up" sheet a
 * live send would have opened; without this the schedule would be accepted and
 * fail silently a week later, when nobody is watching.
 *
 * ## Refused in a Chamber of Secrets room
 *
 * A room with `messageLifetime` promises that what is said there fades. A
 * scheduled message parks its plaintext on the server for up to a year before
 * anybody has said anything at all — the message has no lifetime to run,
 * because it has not been delivered. That is not a self-destructing message
 * held briefly; it is the exact opposite of the room's promise, and it would be
 * invisible to everyone but the sender while it sat there.
 *
 * The precedent and the reasoning are `send`'s own: a live-location share is
 * refused in these rooms because "two self-destruct clocks on one row is a
 * promise the app cannot keep". The client hides the affordance in such a room,
 * so reaching this is a stale screen rather than the normal path.
 */
export const schedule = mutation({
  args: {
    roomId: v.id("rooms"),
    userId: v.id("users"),
    content: v.string(),
    // Exactly one of these. See `resolveSendAt` for why both forms exist.
    delayMs: v.optional(v.number()),
    sendAt: v.optional(v.number()),
    replyToId: v.optional(v.id("messages")),
    mentionedUserIds: v.optional(v.array(v.id("users"))),
    mentionsEveryone: v.optional(v.boolean()),
    formatting: formattingArg,
    // Minted by the client so a retried `schedule` cannot stage the same
    // message twice, and carried all the way into the eventual insert.
    clientId: v.string(),
  },
  handler: async (
    ctx,
    {
      roomId,
      userId,
      content,
      delayMs,
      sendAt,
      replyToId,
      mentionedUserIds,
      mentionsEveryone,
      formatting,
      clientId,
    }
  ) => {
    const text = content.trim();
    if (text.length === 0) throw new Error("SCHEDULE_EMPTY");

    // Idempotency, before anything with a side effect — the same rule and the
    // same reason as the head of `sendCore`. A `schedule` that times out on the
    // wire and is retried must not leave two rows and two jobs.
    const existing = await ctx.db
      .query("scheduledMessages")
      .withIndex("by_room_user_due", (q: any) =>
        q.eq("roomId", roomId).eq("userId", userId)
      )
      .collect();
    const dupe = existing.find((r: any) => r.clientId === clientId);
    if (dupe) return dupe._id;

    const at = resolveSendAt(delayMs, sendAt);

    // Membership, the child guard, DM blocks — and `expiresAt`, which is how we
    // learn the room self-destructs. Text with no blob, so neither guarded
    // capability is needed; asking `permissionsFor` rather than writing the
    // pair by hand keeps this honest if the text gate ever changes.
    const { expiresAt } = await guardOutgoing(
      ctx,
      roomId,
      userId,
      permissionsFor("text", false)
    );
    if (expiresAt !== undefined) throw new Error("SCHEDULE_NOT_IN_EPHEMERAL");

    // Per-room cap from the rows already in hand; per-user cap needs its own
    // read, and only when the room count did not already settle it.
    const pendingHere = existing.filter((r: any) => r.pending === true).length;
    if (pendingHere >= MAX_PENDING_PER_ROOM) {
      throw new Error("TOO_MANY_SCHEDULED");
    }
    const mine = await ctx.db
      .query("scheduledMessages")
      .withIndex("by_user", (q: any) => q.eq("userId", userId))
      .take(MAX_PENDING_PER_USER + 1);
    if (mine.filter((r: any) => r.pending === true).length >= MAX_PENDING_PER_USER) {
      throw new Error("TOO_MANY_SCHEDULED");
    }

    const id = await ctx.db.insert("scheduledMessages", {
      roomId,
      userId,
      content: text,
      sendAt: at,
      createdAt: Date.now(),
      pending: true,
      replyToId,
      mentionedUserIds,
      mentionsEveryone,
      formatting,
      clientId,
    });

    const jobId = await ctx.scheduler.runAt(
      new Date(at),
      internal.scheduledMessages.release,
      { id, expectSendAt: at }
    );
    await ctx.db.patch(id, { jobId });
    return id;
  },
});

/**
 * Posts a staged message, at its time.
 *
 * The `expireMessage` shape, with one extra guard. Three ways this can be a
 * no-op, and all three are ordinary rather than exceptional:
 *
 *  * the row is gone — the sender cancelled it, or sent it early;
 *  * `pending` is unset — it already failed, and this is a duplicate job;
 *  * `sendAt` has moved — the sender rescheduled, and THIS job belongs to the
 *    old instant. That check is what makes rescheduling correct without relying
 *    on `scheduler.cancel` having worked: the new instant has its own job, and
 *    the old one lands here and declines.
 *
 * ## A refusal is stored, not thrown
 *
 * `guardOutgoing` throws when a grant was revoked, the sender left the room, or
 * a block went up in the days since this was written. At send time there was a
 * client to catch that; here there is nobody. Throwing would put the failure in
 * a server log the sender cannot read and drop the message on the floor, so the
 * reason is written onto the row and the row is kept — the list sheet renders it
 * as something that needs attention rather than as a message that quietly never
 * happened.
 */
async function releaseRow(ctx: any, id: any, expectSendAt: number) {
  const row = await ctx.db.get(id);
  if (!row) return;
  if (row.pending !== true) return;
  if (row.sendAt !== expectSendAt) return;

  try {
    await sendCore(ctx, sendArgsFor(row));
  } catch (err: any) {
    // Out of the sweep bucket as well as out of `pending`: a row that failed
    // its guard will fail it again on every pass, and leaving it in
    // `by_pending_due` would make the sweep re-attempt it every five minutes
    // forever. Retrying is the sender's call, from the list sheet.
    await ctx.db.patch(id, {
      pending: undefined,
      failedReason: String(err?.message ?? err),
      failedAt: Date.now(),
    });
    return;
  }

  // Deleted in the same transaction as the insert, which is what makes this
  // exactly-once rather than at-least-once: either both happened or neither
  // did. The sender's confirmation is the real bubble arriving in the
  // transcript — a "sent" tombstone here would be a second thing to dismiss.
  await ctx.db.delete(id);
}

export const release = internalMutation({
  args: { id: v.id("scheduledMessages"), expectSendAt: v.number() },
  handler: async (ctx, { id, expectSendAt }) =>
    await releaseRow(ctx, id, expectSendAt),
});

// ── Editing what is queued ──────────────────────────────────────────────────

/**
 * Moves a queued message to a new time.
 *
 * Patches first and schedules second so the new job's `expectSendAt` can never
 * disagree with the row it will read. The old job is cancelled afterwards, and
 * its failure is survivable — see `dropJob`.
 */
export const reschedule = mutation({
  args: {
    id: v.id("scheduledMessages"),
    userId: v.id("users"),
    delayMs: v.optional(v.number()),
    sendAt: v.optional(v.number()),
  },
  handler: async (ctx, { id, userId, delayMs, sendAt }) => {
    const row = await ownedRow(ctx, id, userId);
    const at = resolveSendAt(delayMs, sendAt);
    const oldJob = row.jobId;

    // Rescheduling a FAILED row is how retry works, so `pending` comes back on.
    // The failure is cleared with it: leaving the reason behind would render a
    // freshly-queued message as broken.
    await ctx.db.patch(id, {
      sendAt: at,
      pending: true,
      failedReason: undefined,
      failedAt: undefined,
    });
    const jobId = await ctx.scheduler.runAt(
      new Date(at),
      internal.scheduledMessages.release,
      { id, expectSendAt: at }
    );
    await ctx.db.patch(id, { jobId });
    await dropJob(ctx, oldJob);
    return at;
  },
});

/**
 * Rewrites a queued message's text.
 *
 * The mention and formatting sets come with it rather than being preserved: an
 * edit that kept the old spans would bold whatever now sits at those offsets,
 * and an edit that kept the old mention ids would notify someone whose name is
 * no longer in the words. Both are re-validated at release regardless.
 *
 * Leaves `sendAt` and the job alone. Fixing a typo is not a reason to move the
 * message, and silently doing so would be the sort of thing nobody notices
 * until the message goes out at the wrong time.
 */
export const updateText = mutation({
  args: {
    id: v.id("scheduledMessages"),
    userId: v.id("users"),
    content: v.string(),
    mentionedUserIds: v.optional(v.array(v.id("users"))),
    mentionsEveryone: v.optional(v.boolean()),
    formatting: formattingArg,
  },
  handler: async (
    ctx,
    { id, userId, content, mentionedUserIds, mentionsEveryone, formatting }
  ) => {
    await ownedRow(ctx, id, userId);
    const text = content.trim();
    if (text.length === 0) throw new Error("SCHEDULE_EMPTY");
    await ctx.db.patch(id, {
      content: text,
      mentionedUserIds,
      mentionsEveryone,
      formatting,
    });
  },
});

/** Drops a queued message. The row goes, and its job with it. */
export const cancel = mutation({
  args: { id: v.id("scheduledMessages"), userId: v.id("users") },
  handler: async (ctx, { id, userId }) => {
    const row = await ownedRow(ctx, id, userId);
    await ctx.db.delete(id);
    await dropJob(ctx, row.jobId);
  },
});

/**
 * Sends a queued message right now.
 *
 * Deliberately NOT "reschedule to now": that would go through the scheduler and
 * land somewhere between instantly and a second later, so the transcript would
 * not have the message by the time the sheet closed. This posts it inline, on
 * the caller's transaction, which is what makes the bubble appear under the
 * user's finger.
 *
 * A guard refusal here DOES throw, unlike in `release` — there is a client on
 * the line, and it can say why.
 */
export const sendNow = mutation({
  args: { id: v.id("scheduledMessages"), userId: v.id("users") },
  handler: async (ctx, { id, userId }) => {
    const row = await ownedRow(ctx, id, userId);
    const messageId = await sendCore(ctx, sendArgsFor(row));
    await ctx.db.delete(id);
    await dropJob(ctx, row.jobId);
    return messageId;
  },
});

// ── Reading ─────────────────────────────────────────────────────────────────

/**
 * This viewer's queued messages for one room, soonest first.
 *
 * Scoped to `(roomId, userId)` by the index rather than filtered afterwards,
 * which is a privacy property and not an optimisation: this is a subscribed
 * query, and a Convex subscription's read set is what it actually touched. A
 * whole-room scan filtered in JS would re-fire this query on every other
 * member's scheduling activity, and tell the client something about it.
 *
 * Failed rows come back too — they sort by the instant they were meant to go
 * out, which keeps them in the place the user last saw them.
 */
export const listForRoom = query({
  args: { roomId: v.id("rooms"), userId: v.id("users") },
  handler: async (ctx, { roomId, userId }) => {
    return await ctx.db
      .query("scheduledMessages")
      .withIndex("by_room_user_due", (q: any) =>
        q.eq("roomId", roomId).eq("userId", userId)
      )
      .collect();
  },
});

// ── Sweeps and teardown ─────────────────────────────────────────────────────

/**
 * Releases anything whose time has passed and whose job never came.
 *
 * A repair pass, exactly like `gcExpiredViewOnce` and `gcExpiredLiveShares` —
 * every row's own `runAt` is the mechanism. It runs far more often than those
 * two (five minutes against six hours) for a reason worth stating: their
 * failure mode is a stale row, and this one's is a message the user was
 * promised would be sent and was not. That puts it in `gcStuckRinging`'s
 * category rather than the garbage collectors'.
 *
 * Affordable at that interval because `by_pending_due` leads with the boolean
 * and the range stops at the first row that is not yet due — an idle deployment
 * pays one index probe and writes nothing. See the header of `crons.ts`.
 */
export const gcOverdue = internalMutation({
  args: {},
  handler: async (ctx) => {
    const now = Date.now();
    const due = await ctx.db
      .query("scheduledMessages")
      .withIndex("by_pending_due", (q: any) =>
        q.eq("pending", true).lt("sendAt", now)
      )
      .take(OVERDUE_SWEEP_LIMIT);
    for (const row of due) {
      // Through the same function the scheduled job uses, passing the row's own
      // `sendAt` so every guard reads exactly as it would have. Shared rather
      // than re-implemented for the `endLiveShare` reason: three ways to release
      // a row must produce one outcome.
      await releaseRow(ctx, row._id, row.sendAt);
    }
    return due.length;
  },
});

/**
 * Everything one user has queued, anywhere. Account teardown.
 *
 * Jobs are dropped as well as rows: a departing account's year-out message must
 * not leave an invocation behind that wakes up to find nothing.
 *
 * A plain helper taking the caller's `ctx`, matching `roomCleanup`'s convention
 * and for its reason — teardown runs inside somebody else's transaction, and a
 * separate mutation would commit the deletions apart from the rest of it.
 */
export async function purgeScheduledForUser(ctx: any, userId: any) {
  const rows = await ctx.db
    .query("scheduledMessages")
    .withIndex("by_user", (q: any) => q.eq("userId", userId))
    .collect();
  for (const row of rows) {
    await ctx.db.delete(row._id);
    await dropJob(ctx, row.jobId);
  }
  return rows.length;
}

/**
 * Everything queued for one room, from every sender. Room teardown.
 *
 * Not covered by [purgeScheduledForUser]: a deleted room's OTHER members have
 * queued messages of their own, and without this each would fail its membership
 * guard at release and sit in that person's list as a permanent error for a
 * room that no longer exists.
 */
export async function purgeScheduledForRoom(ctx: any, roomId: any) {
  const rows = await ctx.db
    .query("scheduledMessages")
    .withIndex("by_room", (q: any) => q.eq("roomId", roomId))
    .collect();
  for (const row of rows) {
    await ctx.db.delete(row._id);
    await dropJob(ctx, row.jobId);
  }
  return rows.length;
}
