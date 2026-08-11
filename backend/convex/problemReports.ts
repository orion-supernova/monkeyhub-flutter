import { internalMutation, mutation } from "./_generated/server";
import { v } from "convex/values";
import { internal } from "./_generated/api";
import { galleryBucketFor } from "./messages";
import { seenVisibilityOf } from "./visibility";
import {
  LOG_DISPLAY_NAME,
  LOG_USERNAME,
  REPORT_INBOX_USERNAME,
  SYSTEM_PASSWORD_PREFIX,
  SYSTEM_ROOM_LOGS,
  SYSTEM_VISIBILITY,
  isSystemAccount,
} from "./systemAccount";

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
 * report into a DM with the maintainer. That buys the whole existing stack for
 * free — push notification, unread badge, attachment rendering, the image
 * viewer, reply-to for asking a follow-up question — where an HTTP endpoint into
 * a table would have bought a table nobody opens.
 *
 * What the user sees is "report sent". They are not shown the account, the
 * username it lands in, or that it is a DM at all; the mechanism is not
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
const MAX_BODY_CHARS = 8000;

/** Same shape as `messages.mintNonce` — see the note there on `Math.random`. */
function randomHex(bytes: number): string {
  const buf = new Uint8Array(bytes);
  crypto.getRandomValues(buf);
  return Array.from(buf, (b) => b.toString(16).padStart(2, "0")).join("");
}

/**
 * The log account, created on first report.
 *
 * Created lazily rather than seeded by a migration so a fresh deployment needs
 * no setup step to make the report screen work.
 *
 * Throws if the handle is already held by a REAL account. `isReservedUsername`
 * refuses anything containing the brand at all three signup paths, so this cannot
 * happen going forward — but a deployment that predates the reservation could
 * already have one, and quietly posting as somebody else's account would
 * put messages the user never wrote into their sent history and show the
 * maintainer a report apparently from a stranger. A collision has to stop the
 * report, not reroute it.
 */
async function ensureLogAccount(ctx: any) {
  const existing = await ctx.db
    .query("users")
    .withIndex("by_username", (q: any) => q.eq("username", LOG_USERNAME))
    .first();
  if (existing) {
    if (!isSystemAccount(existing)) throw new Error("LOG_USERNAME_TAKEN");
    // Repair a row created before `SYSTEM_VISIBILITY` existed, which would
    // otherwise keep the server's "public" defaults for avatar and presence.
    // Idempotent: patched only when it differs, so this is not a write per
    // report.
    if (existing.visibility?.avatar !== SYSTEM_VISIBILITY.avatar) {
      await ctx.db.patch(existing._id, { visibility: SYSTEM_VISIBILITY });
    }
    return existing._id;
  }

  return await ctx.db.insert("users", {
    username: LOG_USERNAME,
    name: LOG_DISPLAY_NAME,
    passwordHash: SYSTEM_PASSWORD_PREFIX + randomHex(16),
    createdAt: Date.now(),
    // Never "online": this account has no client and no heartbeat, and letting
    // it read as online would put a green dot on a thing that cannot answer.
    // It also keeps the row permanently outside `sweepStalePresence`, which
    // ranges only within status "online" and "away" — so this account costs
    // that cron nothing, forever, rather than being re-read every five minutes.
    status: "offline",
    // Absent `lastSeen` on purpose, for the same reason — there is no last
    // time this account was seen, and inventing one would be a lie the
    // presence UI would happily render.
    //
    // The visibility block is what makes the account private, and leaving it
    // absent would have done the OPPOSITE of that: the server's defaults in
    // `visibility.DEFAULT_LEVEL` are "public" for avatar, status and lastSeen.
    // See the note on `SYSTEM_VISIBILITY`.
    visibility: SYSTEM_VISIBILITY,
    // `avatarStorageId` is deliberately absent. A mutation cannot create a blob
    // (`ctx.storage.store` is action-only), so the avatar is deployment data —
    // see `tools/monkeyhub-logs-avatar.md` for the file and the three commands
    // that attach it. Until that runs the client draws its usual monogram, which
    // is a working account with a plain face rather than a broken one.
  });
}

/**
 * The DM the reports land in, created on first use.
 *
 * Built here rather than through `rooms.getOrCreateDM` because that mutation
 * requires an accepted friendship in both directions, and this pair has none —
 * the log account files no friend requests and accepts none. The room NAME is
 * kept byte-identical to the one that mutation would produce (`dm:regular:` plus
 * the two ids sorted), because that name is what every read path uses to tell a
 * DM from a group room: the block check in `guardOutgoing`, the `@everyone`
 * suppression, and the client's peer resolution all key off the prefix.
 */
async function ensureReportRoom(ctx: any, logUserId: any, inboxUserId: any) {
  const ordered = [logUserId.toString(), inboxUserId.toString()].sort();
  const name = `dm:regular:${ordered[0]}:${ordered[1]}`;

  const existing = await ctx.db
    .query("rooms")
    .withIndex("by_name", (q: any) => q.eq("name", name))
    .first();
  if (existing) {
    // Repair a room created before `rooms.system` existed. Without this the
    // deployment's ONE report room is the only room in the app that would never
    // get the slug — it already exists, so the insert below never runs again —
    // and it would keep drawing a call button that rings nothing.
    if (existing.system !== SYSTEM_ROOM_LOGS) {
      await ctx.db.patch(existing._id, { system: SYSTEM_ROOM_LOGS });
    }
    return existing._id;
  }

  const roomId = await ctx.db.insert("rooms", {
    name,
    createdBy: logUserId,
    createdAt: Date.now(),
    isPrivate: true,
    memberCount: 2,
    type: "Regular Room",
    // What tells the client this is a fixture and not a conversation: no call,
    // no "end conversation", no description, no member list. See
    // `systemAccount.SYSTEM_ROOM_LOGS`.
    system: SYSTEM_ROOM_LOGS,
    // No `messageLifetime`. A Chamber-of-Secrets lifetime here would delete
    // bug reports on a timer, which is the one thing this room must not do.
  });
  await ctx.db.insert("roomMembers", {
    roomId,
    userId: logUserId,
    joinedAt: Date.now(),
    role: "owner",
    seenVisibility: await seenVisibilityOf(ctx, logUserId),
  });
  await ctx.db.insert("roomMembers", {
    roomId,
    userId: inboxUserId,
    joinedAt: Date.now(),
    role: "member",
    seenVisibility: await seenVisibilityOf(ctx, inboxUserId),
  });
  return roomId;
}

/**
 * Makes the two parties accepted contacts, both directions.
 *
 * Not decoration, and not a shortcut around the check `ensureReportRoom`
 * deliberately skips — it is what makes the room render. `ChatRepository`
 * resolves a DM's peer with `userById`, which searches ONE cache: the friends
 * list. A DM with somebody who is not in it resolves to null, every consumer
 * falls back to `room.name`, and the room list, the chat header, room info and
 * the forward sheet all title the room `dm:regular:jn7ab…:kx02…`.
 *
 * Fixed here rather than by teaching the client to fetch an uncached peer,
 * because this account is not a special case that the UI should learn about — it
 * is a correspondent the maintainer answers, and "a DM you have is with a contact
 * you have" is already true of every other room in the list. Doing it the other
 * way would put a per-room profile fetch on the room list's build path to serve
 * exactly one room.
 *
 * Written in both directions because the friends list is read from `by_user`
 * only, so one row would render for one side and not the other.
 *
 * Called on every report rather than only when the room is created, so it also
 * repairs a deployment whose room predates this function — and so unfriending
 * the log account is undone by the next report instead of permanently breaking
 * the room's title.
 */
async function ensureFriendship(
  ctx: any,
  a: any,
  b: any,
  roomId: any,
): Promise<void> {
  for (const [userId, friendId] of [
    [a, b],
    [b, a],
  ]) {
    const existing = await ctx.db
      .query("friendships")
      .withIndex("by_pair", (q: any) =>
        q.eq("userId", userId).eq("friendId", friendId),
      )
      .first();
    if (existing) {
      // Never downgrade a row somebody else wrote, and never re-stamp one that
      // is already right — a patch here would re-fire the friends subscription
      // on every report.
      if (existing.status !== "accepted") {
        await ctx.db.patch(existing._id, {
          status: "accepted",
          respondedAt: Date.now(),
          stage: undefined,
          deniedBy: undefined,
        });
      }
      continue;
    }
    await ctx.db.insert("friendships", {
      userId,
      friendId,
      status: "accepted",
      createdAt: Date.now(),
      respondedAt: Date.now(),
      roomId,
      // No `stage`: absent means "fully visible to the recipient", which is the
      // only correct value for a contact that was never requested and never
      // needed releasing along a guardian chain.
    });
  }
}

/**
 * Files one problem report.
 *
 * Writes the message rows directly rather than calling `messages.send`, which is
 * a public mutation and so not callable from here. What it skips is the set of
 * guards that only make sense for a person typing into a room they chose: the
 * membership check (this mutation just created the membership), the child media
 * policy (the sender is not a child), the DM block check (neither party can have
 * blocked an account that cannot be found or added), mention resolution (there
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
    { deviceId, reporterId, body, logStorageId, logFileName, logFileSize, screenshots },
  ) => {
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

    const inbox = await ctx.db
      .query("users")
      .withIndex("by_username", (q) => q.eq("username", REPORT_INBOX_USERNAME))
      .first();
    if (!inbox) throw new Error(ERR_NO_INBOX);

    const logUserId = await ensureLogAccount(ctx);
    const roomId = await ensureReportRoom(ctx, logUserId, inbox._id);
    await ensureFriendship(ctx, logUserId, inbox._id, roomId);

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
 * The delivered chat messages are untouched. They live in the maintainer's DM
 * and are bug reports about the app, not personal data about whoever filed one —
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
