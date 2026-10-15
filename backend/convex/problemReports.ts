import { internalMutation } from "./_generated/server";
import { mutation } from "./functions";
import { v } from "convex/values";
import { internal } from "./_generated/api";
import { galleryBucketFor } from "./messages";
import {
  LOG_DISPLAY_NAME,
  LOG_ROOM_NAME,
  logRoomStaffUsernames,
  LOG_USERNAME,
  LOG_FORMER_USERNAMES,
  REPORT_INBOX_USERNAME,
  SYSTEM_ROOM_LOGS,
} from "./systemAccount";
import {
  type SystemRoomSpec,
  provisionSystemInbox,
  resolveStaff,
} from "./systemRooms";
import { claimUpload } from "./files";
import { consume } from "./rateLimit";

/**
 * Delivery for the "Report a problem" screen.
 *
 * The report used to leave through the share sheet: the user tapped send, chose
 * an app, and typed a recipient. Nothing arrived unless they finished all three,
 * and most people did not — which made the screen a form that mostly produced
 * nothing.
 *
 * So delivery happens here instead, and it deliberately reuses the only
 * transport this app already has: a chat message. A dedicated account posts the
 * report into a private staff room. That buys the whole existing stack for
 * free — push notification, unread badge, attachment rendering, the image
 * viewer, reply-to for asking a follow-up question — where an HTTP endpoint into
 * a table would have bought a table nobody opens.
 *
 * Reusing the chat stack is also what makes the room's shape a routing decision
 * rather than a rebuild: reports needed to reach more than one person, and the
 * answer was to add a member. See `systemRooms.ensureSystemRoom`, which now
 * builds this room and the moderation room alike.
 *
 * What the user sees is "report sent". They are not shown the account, the
 * handle it lands in, or that it is a chat room at all; the mechanism is not
 * something a bug reporter should have to hold an opinion about.
 */

// The account's identity, the handle it writes to, and the marker that makes it
// recognisable all live in `systemAccount.ts`, which imports nothing — so the
// guards that keep this account unreachable can sit in `friends.ts`, `calls.ts`,
// `rooms.ts` and `auth.ts` without any of them importing the report path.

/** Reports one device may file before it has to wait. */
const MAX_REPORTS_PER_WINDOW = 6;

/** The window that limit is counted over. */
const REPORT_WINDOW_MS = 60 * 60 * 1000;

export const ERR_TOO_MANY_REPORTS = "TOO_MANY_REPORTS";

/**
 * Thrown when [REPORT_INBOX_USERNAME] names nobody on this deployment.
 *
 * Loud on purpose. The alternative — accept the report, drop it, tell the user
 * it was sent — is the exact failure this whole change exists to remove, and it
 * would be invisible: no error, no row, no message, just silence on a screen
 * that says thank you.
 */
export const ERR_NO_INBOX = "REPORT_INBOX_MISSING";

/** Belt-and-braces cap on the note. The client caps the field at 2000. */
/** Screenshots kept per report; the rest are dropped (and swept). */
const MAX_SCREENSHOTS = 3;

const MAX_BODY_CHARS = 8000;

/**
 * The log inbox, as a [SystemRoomSpec]. The account, the room, the roster and
 * the contacts are all built by `systemRooms.ts`, which this file used to own
 * outright — see the note there on why it moved when the moderation inbox
 * arrived.
 */
export const LOG_ROOM_SPEC: SystemRoomSpec = {
  username: LOG_USERNAME,
  formerUsernames: LOG_FORMER_USERNAMES,
  displayName: LOG_DISPLAY_NAME,
  roomName: LOG_ROOM_NAME,
  slug: SYSTEM_ROOM_LOGS,
  // The pre-slug shape: the DM this file used to mint, named `dm:regular:`
  // plus the two member ids sorted. Adopted and renamed rather than
  // duplicated, so a deployment's existing reports stay in the one room.
  isLegacyRoom: (room: any, accountId: any) =>
    typeof room.name === "string" &&
    room.name.startsWith("dm:regular:") &&
    room.name.includes(accountId.toString()),
};

/**
 * Who the report room is for: the maintainer, plus whatever staff handles
 * resolve.
 *
 * Two different failure modes on purpose. A missing [REPORT_INBOX_USERNAME]
 * throws — that is the deployment having nowhere to put reports, which is the
 * silent-drop this whole module was written to eliminate. A missing staff
 * handle is skipped, because refusing a bug report over a typo in a constant
 * would be trading the thing for the bookkeeping about the thing.
 */
export async function resolveLogRoomReaders(ctx: any): Promise<any[]> {
  const readers = await resolveStaff(ctx, [
    REPORT_INBOX_USERNAME,
    ...logRoomStaffUsernames(),
  ]);
  if (readers[0]?.username !== REPORT_INBOX_USERNAME) {
    throw new Error(ERR_NO_INBOX);
  }
  return readers;
}

/**
 * Files one problem report.
 *
 * Writes the message rows directly rather than calling `messages.send`, which is
 * a public mutation and so not callable from here. What it skips is the set of
 * guards that only make sense for a person typing into a room they chose: the
 * membership check (this mutation just created the membership), the child media
 * policy (the sender is not a child), the block check (nobody can have blocked
 * an account that cannot be found or added), mention resolution (there
 * is no `@` handling in a machine-written report) and idempotency-by-clientId —
 * the report screen sends once per tap and reports the outcome, so a retry is a
 * deliberate second report.
 *
 * `deviceId` is the throttle key rather than `reporterId`, so the limit still
 * applies when nobody is signed in, and so two accounts on one handset share one
 * budget.
 */
export const submit = mutation({
  args: {
    deviceId: v.string(),
    // Absent when the reporter is signed out — the screen is reachable from a
    // shake, and a session is not a precondition for something being broken.
    reporterId: v.optional(v.id("users")),
    // The note plus the device facts, already formatted for reading.
    body: v.string(),
    // The captured event log, uploaded as a blob by the client. A blob rather
    // than more `body` because it routinely runs to hundreds of kilobytes, and
    // a chat bubble that long is unreadable where a file attachment is one tap.
    logStorageId: v.optional(v.id("_storage")),
    logFileName: v.optional(v.string()),
    logFileSize: v.optional(v.number()),
    screenshots: v.optional(v.array(v.id("_storage"))),
  },
  returns: v.object({ ok: v.boolean() }),
  handler: async (
    ctx,
    { deviceId, reporterId, body, logStorageId, logFileName, logFileSize, screenshots, userId },
  ) => {
    // Per account as well as per device: the device id is the client's word,
    // so a script rotating it was never limited at all.
    await consume(ctx, `report:${userId}`, MAX_REPORTS_PER_WINDOW, REPORT_WINDOW_MS);
    screenshots = (screenshots ?? []).slice(0, MAX_SCREENSHOTS);
    await claimUpload(ctx, logStorageId, userId, "report");
    for (const id of screenshots) await claimUpload(ctx, id, userId, "report");
    // Throttle first, before anything is created or written. A device that has
    // spent its budget must not be able to conjure the log account or the room
    // as a side effect of being refused.
    const since = Date.now() - REPORT_WINDOW_MS;
    const recent = await ctx.db
      .query("problemReports")
      .withIndex("by_device_createdAt", (q) =>
        q.eq("deviceId", deviceId).gt("createdAt", since),
      )
      // One more than the limit is all the count needs to resolve, and it keeps
      // a device that filed hundreds from reading hundreds of rows per attempt.
      .take(MAX_REPORTS_PER_WINDOW + 1);
    if (recent.length >= MAX_REPORTS_PER_WINDOW) {
      throw new Error(ERR_TOO_MANY_REPORTS);
    }

    const readers = await resolveLogRoomReaders(ctx);
    const { accountId: logUserId, roomId } = await provisionSystemInbox(
      ctx,
      LOG_ROOM_SPEC,
      readers,
    );

    // `Date.now()` is fixed for the whole mutation — Convex freezes it so a
    // replay is deterministic. Every row below would therefore share one
    // timestamp, and `by_room_time` would order the report's own attachments
    // arbitrarily against its text. Offsetting by one millisecond per row is
    // what keeps the note above the screenshots it describes.
    const now = Date.now();
    let seq = 0;

    const text = body.slice(0, MAX_BODY_CHARS);
    const messageId = await ctx.db.insert("messages", {
      roomId,
      userId: logUserId,
      content: text,
      createdAt: now + seq++,
      type: "text",
      senderName: LOG_DISPLAY_NAME,
    });

    if (logStorageId !== undefined) {
      const fileName = logFileName ?? "diagnostics.txt";
      await ctx.db.insert("messages", {
        roomId,
        userId: logUserId,
        // Empty, not `fileName` — `content` is the bubble's user-typed
        // caption, and `FileMessage`/`message_bubble.dart`'s file case already
        // draw the name from the `fileName` field. A non-empty caption here
        // used to render as a second bubble underneath the file tile holding
        // nothing but the name again.
        content: "",
        createdAt: now + seq++,
        type: "file",
        mediaStorageId: logStorageId,
        fileName,
        fileSize: logFileSize,
        mimeType: "text/plain",
        galleryBucket: galleryBucketFor("file", true, false),
        senderName: LOG_DISPLAY_NAME,
      });
    }

    for (const shot of screenshots ?? []) {
      await ctx.db.insert("messages", {
        roomId,
        userId: logUserId,
        content: "",
        createdAt: now + seq++,
        type: "image",
        mediaStorageId: shot,
        galleryBucket: galleryBucketFor("image", true, false),
        senderName: LOG_DISPLAY_NAME,
      });
    }

    // The room card's one line, and the push body below. Built from the note
    // rather than from the newest row on purpose: "screenshot" tells the
    // maintainer nothing, and the first line of what the user typed tells them
    // whether to open it now.
    const preview = text.slice(0, 100);
    await ctx.db.patch(roomId, {
      lastMessage: preview,
      lastMessageTime: now + seq - 1,
      lastMessageSenderId: logUserId,
    });

    await ctx.db.insert("problemReports", {
      deviceId,
      reporterId,
      createdAt: now,
      messageId,
    });

    // One push for the whole report, pointed at the text message — the
    // attachments are part of the same report, and three banners for one tap of
    // "send" would be three times the noise for none of the information.
    await ctx.scheduler.runAfter(0, internal.notifications.sendMessagePush, {
      roomId,
      messageId,
      senderId: logUserId,
      senderName: LOG_DISPLAY_NAME,
      content: preview,
      type: "text",
    });

    return { ok: true };
  },
});

/**
 * How long a `problemReports` row is kept.
 *
 * The throttle needs one hour of it. The rest is audit trail: enough to answer
 * "did that report reach us, and when" for as long as anybody is still asking,
 * and no longer. Deliberately far shorter than the 24 months `reports` keeps —
 * a moderation record is evidence about an incident between people, while this
 * is a receipt for a bug report, and there is no argument for holding a device
 * identifier from a children's app for two years to prove one was filed.
 */
export const RETENTION_MS = 90 * 24 * 60 * 60 * 1000;

/**
 * Deletes report receipts past [RETENTION_MS].
 *
 * Like `users.gcExpiredReports`, this is not a garbage collector tidying up
 * after a path that already cleans itself — nothing else ever deletes one of
 * these rows, so this job IS the retention policy. Without it the table is an
 * append-only ledger of device identifiers, which is the exact shape the
 * moderation table was fixed for.
 *
 * Batched at 200 like the other sweeps: the cron is daily and the table is
 * small, so a backlog drains over a few days instead of risking the 1s function
 * limit on a box that is also serving live traffic.
 *
 * The delivered chat messages are untouched. They live in the staff room and
 * are bug reports about the app, not personal data about whoever filed one —
 * and a report deleted out from under an open conversation about it would be a
 * worse outcome than keeping it.
 */
export const gcExpiredReports = internalMutation({
  args: {},
  returns: v.null(),
  handler: async (ctx) => {
    const cutoff = Date.now() - RETENTION_MS;
    const expired = await ctx.db
      .query("problemReports")
      .withIndex("by_createdAt", (q) => q.lt("createdAt", cutoff))
      .take(200);
    for (const row of expired) await ctx.db.delete(row._id);
    return null;
  },
});
