import { internalMutation } from "./_generated/server";
import { mutation } from "./functions";
import { v } from "convex/values";
import { internal } from "./_generated/api";
import { galleryBucketFor } from "./messages";
import { seenVisibilityOf } from "./visibility";
import {
  LOG_DISPLAY_NAME,
  LOG_ROOM_NAME,
  LOG_ROOM_STAFF_USERNAMES,
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
 * report into a private staff room. That buys the whole existing stack for
 * free — push notification, unread badge, attachment rendering, the image
 * viewer, reply-to for asking a follow-up question — where an HTTP endpoint into
 * a table would have bought a table nobody opens.
 *
 * Reusing the chat stack is also what makes the room's shape a routing decision
 * rather than a rebuild: reports needed to reach more than one person, and the
 * answer was to add a member. See `ensureReportRoom` for what changed and what
 * a DM could not have done.
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
 * Finds the report room, by the only key that has ever been reliable: the log
 * account's own membership.
 *
 * NOT by name, which is what this used to do and what the rename would have
 * broken. Three things are wrong with a name lookup here. The old name encoded
 * the two member ids (`dm:regular:<a>:<b>`), so it changes the moment the
 * membership does — the exact event this function has to survive. The new name
 * is a display name, and room names are not reserved: any user may create a
 * group called "MonkeyHub Logs", and `by_name` would hand back theirs. And a
 * lookup that misses does not fail loudly, it creates a SECOND report room and
 * silently orphans every report already filed in the first.
 *
 * Membership has none of the three. The log account has no client and no session,
 * so it joins nothing on its own, and this function is the only thing in the
 * codebase that writes a `roomMembers` row for it. So "the room the log account
 * is in" IS the report room, whatever it is currently called.
 *
 * The membership is still a filter and not the whole answer, because `rooms.join`
 * takes the joining user as an ARGUMENT and does not refuse a system account —
 * anybody holding this id could put it in a room. (`systemAccount.ts` is explicit
 * that the id being unobtainable is the protection, not the guard list.) So a
 * candidate must also look like the report room: stamped with the slug, or —
 * for a deployment whose room predates `rooms.system` — carrying the exact DM
 * name this function used to mint. Anything else the account somehow ended up in
 * is skipped rather than adopted and renamed.
 */
async function findLogRoom(ctx: any, logUserId: any) {
  const memberships = await ctx.db
    .query("roomMembers")
    .withIndex("by_user", (q: any) => q.eq("userId", logUserId))
    .collect();
  let legacy: any = null;
  for (const m of memberships) {
    const room = await ctx.db.get(m.roomId);
    if (!room) continue;
    if (room.system === SYSTEM_ROOM_LOGS) return room;
    // The pre-slug shape: the DM `ensureReportRoom` used to mint, whose name is
    // `dm:regular:` plus the two member ids sorted.
    if (
      typeof room.name === "string" &&
      room.name.startsWith("dm:regular:") &&
      room.name.includes(logUserId.toString())
    ) {
      legacy = room;
    }
  }
  return legacy;
}

/**
 * The room the reports land in, created on first use: a private group owned by
 * the log account, with every staff reader in it.
 *
 * ── Why it is a group and not a DM ─────────────────────────────────────────
 *
 * It was a DM, built by hand rather than through `rooms.getOrCreateDM` (that
 * mutation requires an accepted friendship in both directions, and this pair has
 * none), with a name kept byte-identical to the one that mutation would produce
 * so every `startsWith("dm:")` read path would classify it correctly.
 *
 * That shape held exactly one reader, because a DM is defined by having two
 * members and one of them is the bot. Reports have to reach the people who fix
 * things, and that is now more than one person — so the room stops being a pair
 * and becomes what it always was in substance: a staff channel that a bot posts
 * into. Everything that keyed off the `dm:` prefix now correctly classifies it
 * as a group: `@everyone` becomes meaningful (there is a crowd), the DM block
 * check stops applying (there is no counterparty to have blocked), and the
 * client titles the room from `rooms.name` instead of resolving a peer.
 *
 * ── Migration ──────────────────────────────────────────────────────────────
 *
 * In place, on the next report, with no backfill job. The room already holds
 * every report ever filed, so recreating it is not an option — it is patched
 * where it differs and left alone where it does not, which also makes this
 * function the repair path for a room that predates `rooms.system`, one whose
 * roster has drifted, or one whose count is stale.
 */
async function ensureReportRoom(
  ctx: any,
  logUserId: any,
  readerIds: any[],
): Promise<any> {
  const existing = await findLogRoom(ctx, logUserId);
  const roomId = existing
    ? await repairLogRoom(ctx, existing, logUserId)
    : await ctx.db.insert("rooms", {
        name: LOG_ROOM_NAME,
        createdBy: logUserId,
        createdAt: Date.now(),
        // Never discoverable: `by_visibility` lists public rooms only.
        isPrivate: true,
        // Corrected by `reconcileLogRoomMembers` below, in this same mutation,
        // so no reader ever observes the zero.
        memberCount: 0,
        type: "Regular Room",
        // What tells the client this is a fixture and not a conversation: no
        // call, no "end conversation", no description, no settings. See
        // `systemAccount.SYSTEM_ROOM_LOGS`.
        system: SYSTEM_ROOM_LOGS,
        // The room wears the bot's face. Worth doing explicitly now that the
        // room is a group: a DM borrowed the other party's avatar, and a group
        // has only its own, so without this the one room in the app with a
        // designed icon would fall back to a monogram. Absent on a deployment
        // where the avatar has never been attached, which is fine — the client
        // draws the monogram, exactly as it does for any new group.
        avatarStorageId: (await ctx.db.get(logUserId))?.avatarStorageId,
        // No `messageLifetime`. A Chamber-of-Secrets lifetime here would delete
        // bug reports on a timer, which is the one thing this room must not do.
      });
  await reconcileLogRoomMembers(ctx, roomId, logUserId, readerIds);
  return roomId;
}

/**
 * Brings an existing report room up to the current shape.
 *
 * Every field is patched only when it actually differs, and that is not a
 * micro-optimisation: this runs on every report, `rooms` is a live subscription,
 * and an unconditional patch would re-fire the room list of everyone in it once
 * per bug report for no change at all.
 */
async function repairLogRoom(ctx: any, room: any, logUserId: any): Promise<any> {
  const patch: Record<string, any> = {};
  // A room created before `rooms.system` existed. Without this the deployment's
  // ONE report room is the only room in the app that never gets the slug — it
  // already exists, so the insert never runs again — and it would keep drawing
  // chrome that leads nowhere.
  if (room.system !== SYSTEM_ROOM_LOGS) patch.system = SYSTEM_ROOM_LOGS;
  // The rename. A room still carrying `dm:regular:<a>:<b>` is one that has not
  // been through this yet; leaving the name would title the room with a pair of
  // raw ids the moment a third member makes peer resolution impossible.
  if (room.name !== LOG_ROOM_NAME) patch.name = LOG_ROOM_NAME;
  // Belt to `isPrivate`'s braces — a public report room would be listed in
  // Discover, which is the one place bug reports must never appear.
  if (room.isPrivate !== true) patch.isPrivate = true;
  if (!room.avatarStorageId) {
    const avatar = (await ctx.db.get(logUserId))?.avatarStorageId;
    if (avatar) patch.avatarStorageId = avatar;
  }
  if (Object.keys(patch).length > 0) await ctx.db.patch(room._id, patch);
  return room._id;
}

/**
 * Puts the bot and every staff reader in the room, and makes `memberCount`
 * agree with the rows.
 *
 * Additive only: it inserts what is missing and never removes anybody. Taking
 * the roster as authoritative in both directions would mean deleting a
 * membership row on the next bug report anybody happened to file, which is the
 * wrong trigger for that decision no matter how right the decision is. Somebody
 * dropped from [LOG_ROOM_STAFF_USERNAMES] probably should lose access — by a
 * deliberate act, at a moment somebody chose, not as a side effect of a stranger
 * tapping "send" on a crash report. And revoking access is exactly the operation
 * that must not be automated from a list this function cannot verify is current.
 *
 * `memberCount` is recomputed from the rows rather than incremented, because the
 * denormalized count is what the header renders and drift in it is invisible
 * until somebody counts the faces underneath.
 */
async function reconcileLogRoomMembers(
  ctx: any,
  roomId: any,
  logUserId: any,
  readerIds: any[],
): Promise<void> {
  const rows = await ctx.db
    .query("roomMembers")
    .withIndex("by_room_user", (q: any) => q.eq("roomId", roomId))
    .collect();
  const byUser = new Map<string, any>(
    rows.map((r: any) => [r.userId.toString(), r]),
  );
  // Grown as rows are inserted, so the count below is the membership this
  // function is leaving behind rather than arithmetic over the one it found —
  // and so a repeated id in `readerIds` cannot inflate it.
  const present = new Set<string>(byUser.keys());

  // The bot owns the room, and it is the only owner that keeps working: an
  // owner has to be somebody, and every human in here is a reader who may come
  // and go. Re-stamped rather than assumed, because ownership is what the
  // client draws the OWNER badge from and what `_isOwner` gates on.
  const botRow = byUser.get(logUserId.toString());
  if (!botRow) {
    await ctx.db.insert("roomMembers", {
      roomId,
      userId: logUserId,
      joinedAt: Date.now(),
      role: "owner",
      seenVisibility: await seenVisibilityOf(ctx, logUserId),
    });
    present.add(logUserId.toString());
  } else if (botRow.role !== "owner") {
    await ctx.db.patch(botRow._id, { role: "owner" });
  }

  for (const readerId of readerIds) {
    const key = readerId.toString();
    if (present.has(key)) continue;
    await ctx.db.insert("roomMembers", {
      roomId,
      userId: readerId,
      joinedAt: Date.now(),
      role: "member",
      // No `lastReadAt`, which means every report filed before this person
      // arrived counts as unread to them. That is what `rooms.join` does for
      // every other room in the app, and the alternative — seeding the cursor
      // to now — would hide the entire backlog from the one person newly
      // responsible for reading it. A big number on a room they just got
      // access to is the honest one.
      seenVisibility: await seenVisibilityOf(ctx, readerId),
    });
    present.add(key);
  }

  const room = await ctx.db.get(roomId);
  if (room && room.memberCount !== present.size) {
    await ctx.db.patch(roomId, { memberCount: present.size });
  }
}

/**
 * Who the report room is for: the maintainer, plus whatever staff handles
 * resolve.
 *
 * Two different failure modes on purpose. A missing [REPORT_INBOX_USERNAME]
 * throws — that is the deployment having nowhere to put reports, which is the
 * silent-drop this whole module was written to eliminate. A missing staff handle
 * is skipped, because refusing a bug report over a typo in a constant would be
 * trading the thing for the bookkeeping about the thing.
 *
 * A system account named in the staff list is skipped too. It would otherwise be
 * added as a `member` alongside the bot's own `owner` row, giving the room a
 * second occupant that cannot read it.
 *
 * The inbox is first in the returned array and never duplicated, so listing the
 * maintainer's own handle in the staff list is harmless.
 */
async function resolveLogRoomReaders(ctx: any): Promise<any[]> {
  const inbox = await ctx.db
    .query("users")
    .withIndex("by_username", (q: any) => q.eq("username", REPORT_INBOX_USERNAME))
    .first();
  if (!inbox) throw new Error(ERR_NO_INBOX);

  const readers = [inbox];
  const seen = new Set<string>([inbox._id.toString()]);
  for (const username of LOG_ROOM_STAFF_USERNAMES) {
    const user = await ctx.db
      .query("users")
      .withIndex("by_username", (q: any) => q.eq("username", username))
      .first();
    if (!user) continue;
    if (isSystemAccount(user)) continue;
    if (seen.has(user._id.toString())) continue;
    seen.add(user._id.toString());
    readers.push(user);
  }
  return readers;
}

/**
 * Makes the log account and one reader accepted contacts, both directions.
 *
 * Not decoration. It began as the fix for a DM that would not render — the
 * client resolves a DM's peer out of the friends cache, and a DM with a
 * non-contact used to title itself `dm:regular:jn7ab…:kx02…` — and the room
 * being a group has retired that job: a group is titled from `rooms.name`.
 *
 * What it still does is the face. `SYSTEM_VISIBILITY` sets the log account's
 * `avatar` level to `"friends"`, so its picture reaches accepted contacts and
 * nobody else. That is the property worth keeping as the roster grows: the set
 * of people who can see this account is exactly the set of people in its room,
 * maintained by adding contacts rather than by widening the account to
 * `"public"` and hoping nothing else surfaces it.
 *
 * Written in both directions because the friends list is read from `by_user`
 * only, so one row would render for one side and not the other.
 *
 * Called on every report rather than only when the room is created, so it also
 * repairs a deployment whose room predates this function — and so unfriending
 * the log account is undone by the next report instead of leaving one staff
 * member looking at a faceless bot.
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

    const readers = await resolveLogRoomReaders(ctx);
    const logUserId = await ensureLogAccount(ctx);
    const roomId = await ensureReportRoom(
      ctx,
      logUserId,
      readers.map((u) => u._id),
    );
    for (const reader of readers) {
      await ensureFriendship(ctx, logUserId, reader._id, roomId);
    }

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
