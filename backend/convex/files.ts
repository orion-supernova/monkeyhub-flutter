import { internalMutation, internalQuery } from "./_generated/server";
import { mutation, query } from "./functions";
import { v } from "convex/values";
import { canReadRoom } from "./roomAccess";
import { consume } from "./rateLimit";
import { internal } from "./_generated/api";

// ─── Upload limits ──────────────────────────────────────────────────────────
//
// Nothing used to stop an account using the app as a free drive or CDN: no
// size check (only the client's), no quota, no limit on upload URLs, and
// unsigned URLs that never expire. The server now owns each limit:
//
//  * [generateUploadUrl] is rate limited per user.
//  * A file is CLAIMED ([claimUpload]) by whichever call attaches it. The
//    claim checks the real stored size and type, records the owner, and
//    counts it against the owner's quota. A file somebody else claimed cannot
//    be attached, which is also what stops "set my avatar to your photo, then
//    change it" from deleting your photo.
//  * A file nobody claims is swept after [UNCLAIMED_GRACE_MS]
//    ([sweepUnclaimed]).
//
// Files from before the ledger existed have no owner on record, so they can
// no longer be attached by anyone ([UPLOADS_EPOCH]). Nothing legitimate does:
// every send uploads a fresh file, and forwards share the blob directly.

/** Before this, files have no ledger row; see the header above. */
export const UPLOADS_EPOCH = Date.UTC(2026, 9, 15, 18, 0, 0);

const MB = 1024 * 1024;
/** Per file. The client compresses photos and video to 20 MB before upload. */
export const MAX_FILE_BYTES = { media: 25 * MB, avatar: 10 * MB, report: 10 * MB } as const;
/** Per user per rolling day, across everything. */
export const MAX_DAILY_BYTES = 1024 * MB;
/** Per user, everything still stored. */
export const MAX_TOTAL_BYTES = 10 * 1024 * MB;
/** Per user, media kept where nobody else can see it: the "drive" use. */
export const MAX_SOLO_BYTES = 1024 * MB;
/** Upload URLs per user per hour. A busy chat sends a few dozen photos. */
export const MAX_UPLOAD_URLS_PER_HOUR = 120;
/** How long an uploaded file may sit unattached before it is reclaimed. */
const UNCLAIMED_GRACE_MS = 6 * 60 * 60 * 1000;

export const ERR_NOT_YOUR_FILE = "NOT_YOUR_FILE";
export const ERR_FILE_TOO_LARGE = "FILE_TOO_LARGE";
export const ERR_QUOTA = "STORAGE_QUOTA_EXCEEDED";

const DAY_MS = 24 * 60 * 60 * 1000;

// Generate a short-lived upload URL for the client to PUT a file directly to Convex storage
export const generateUploadUrl = mutation({
  handler: async (ctx, { userId }) => {
    await consume(ctx, `upload:${userId}`, MAX_UPLOAD_URLS_PER_HOUR, 60 * 60 * 1000);
    return await ctx.storage.generateUploadUrl();
  },
});

async function ledgerRow(ctx: any, storageId: any) {
  return await ctx.db
    .query("uploads")
    .withIndex("by_storage", (q: any) => q.eq("storageId", storageId))
    .first();
}

async function usageRow(ctx: any, userId: any) {
  return await ctx.db
    .query("uploadUsage")
    .withIndex("by_user", (q: any) => q.eq("userId", userId))
    .first();
}

/**
 * Takes ownership of an uploaded file for [userId] (or for the server, when
 * [userId] is undefined), enforcing the per-file cap for [kind] and the
 * owner's quotas. Idempotent for the same owner, so attaching one file as
 * both a message and, say, its poster is fine.
 *
 * Throws, rolling back the attach: the refused file stays unclaimed and is
 * swept like any other orphan.
 */
export async function claimUpload(
  ctx: any,
  storageId: any,
  userId: any,
  kind: keyof typeof MAX_FILE_BYTES,
  opts: { solo?: boolean } = {},
) {
  if (!storageId) return;
  const existing = await ledgerRow(ctx, storageId);
  if (existing) {
    if (existing.userId?.toString() !== userId?.toString()) {
      throw new Error(ERR_NOT_YOUR_FILE);
    }
    return;
  }
  const meta = await ctx.db.system.get(storageId);
  if (!meta) throw new Error("FILE_NOT_FOUND");
  if (meta._creationTime < UPLOADS_EPOCH) throw new Error(ERR_NOT_YOUR_FILE);
  const size = meta.size ?? 0;
  if (size > MAX_FILE_BYTES[kind]) throw new Error(ERR_FILE_TOO_LARGE);
  const solo = opts.solo === true;

  if (userId) {
    const now = Date.now();
    const usage = await usageRow(ctx, userId);
    const fresh = !usage || now - usage.dayStart >= DAY_MS;
    const next = {
      totalBytes: (usage?.totalBytes ?? 0) + size,
      soloBytes: (usage?.soloBytes ?? 0) + (solo ? size : 0),
      dayStart: fresh ? now : usage.dayStart,
      dayBytes: (fresh ? 0 : usage.dayBytes) + size,
    };
    if (
      next.dayBytes > MAX_DAILY_BYTES ||
      next.totalBytes > MAX_TOTAL_BYTES ||
      next.soloBytes > MAX_SOLO_BYTES
    ) {
      throw new Error(ERR_QUOTA);
    }
    if (usage) await ctx.db.patch(usage._id, next);
    else await ctx.db.insert("uploadUsage", { userId, ...next });
  }
  await ctx.db.insert("uploads", {
    storageId,
    userId: userId ?? undefined,
    size,
    solo: solo || undefined,
    createdAt: Date.now(),
  });
}

/**
 * The largest poster a view-once video note may carry, in bytes.
 *
 * A view-once note's sealed bubble shows its first frame the way Telegram's
 * does: blurred past recognition, under a layer of animated dust. The client
 * makes that a JPEG of at most 16x16 pixels, blurred, typically well under
 * 1 KB. At that size the frame is a smear of colour; no face survives it. So
 * the size is the guarantee, checked against storage metadata rather than
 * anything the client says: a blob over this cap is not a micro poster, and is
 * deleted at send like any other poster on an armed message.
 */
export const VIEW_ONCE_POSTER_MAX_BYTES = 2048;

/** Whether [storageId] exists and is small enough to be a micro poster. */
export async function isMicroPoster(ctx: any, storageId: any): Promise<boolean> {
  if (!storageId) return false;
  const meta = await ctx.db.system.get(storageId);
  return !!meta && typeof meta.size === "number" && meta.size <= VIEW_ONCE_POSTER_MAX_BYTES;
}

/**
 * Deletes an upload the caller sent but the server will not keep, instead of
 * claiming it. Today that is one case: the poster frame of an armed message
 * that is not a micro poster on a video note (see `VIEW_ONCE_POSTER_MAX_BYTES`),
 * which `messages:send` refuses to store. Claiming it and leaving it for the
 * orphan sweep would keep a still of the sender's face fetchable for a day.
 *
 * Never deletes what the caller has no right to: a file claimed by somebody
 * else throws exactly as `claimUpload` would, and a file any message still
 * points at is left alone. Tolerates a file that is already gone, which is
 * what a retried send (same `clientId`) presents the second time.
 */
export async function discardUpload(ctx: any, storageId: any, userId: any) {
  if (!storageId) return;
  const row = await ledgerRow(ctx, storageId);
  if (row && row.userId?.toString() !== userId?.toString()) {
    throw new Error(ERR_NOT_YOUR_FILE);
  }
  const meta = await ctx.db.system.get(storageId);
  if (!meta) {
    if (row) await releaseLedger(ctx, storageId);
    return;
  }
  // No ledger row and older than the ledger: owner unknown, so not ours.
  if (!row && meta._creationTime < UPLOADS_EPOCH) throw new Error(ERR_NOT_YOUR_FILE);
  const inUse =
    (await ctx.db
      .query("messages")
      .withIndex("by_media", (q: any) => q.eq("mediaStorageId", storageId))
      .first()) ??
    (await ctx.db
      .query("messages")
      .withIndex("by_poster", (q: any) => q.eq("posterStorageId", storageId))
      .first());
  if (inUse) return;
  await deleteStored(ctx, storageId);
}

/** Drops [storageId]'s ledger row and gives its bytes back to the owner. */
async function releaseLedger(ctx: any, storageId: any) {
  const row = await ledgerRow(ctx, storageId);
  if (!row) return;
  await ctx.db.delete(row._id);
  if (!row.userId) return;
  const usage = await usageRow(ctx, row.userId);
  if (!usage) return;
  await ctx.db.patch(usage._id, {
    totalBytes: Math.max(0, usage.totalBytes - row.size),
    soloBytes: Math.max(0, usage.soloBytes - (row.solo ? row.size : 0)),
  });
}

/**
 * What one user has stored and may still store, for a settings screen.
 */
export const myUsage = query({
  args: {},
  handler: async (ctx, { userId }) => {
    const usage = await usageRow(ctx, userId);
    return {
      totalBytes: usage?.totalBytes ?? 0,
      soloBytes: usage?.soloBytes ?? 0,
      maxTotalBytes: MAX_TOTAL_BYTES,
      maxSoloBytes: MAX_SOLO_BYTES,
    };
  },
});

/**
 * Reclaims files uploaded since [UPLOADS_EPOCH] that nothing ever claimed:
 * the upload that never got sent, and every file a script PUT on purpose.
 *
 * Walks `_storage` in creation order from a saved cursor, so each run costs
 * one page however large storage grows. A message pointing at an unclaimed
 * file (a path that forgot to claim) is claimed for its author instead of
 * deleted: the sweep must never be the thing that loses a photo.
 */
export const sweepUnclaimed = internalMutation({
  args: {},
  returns: v.object({ deleted: v.number(), scanned: v.number() }),
  handler: async (ctx) => {
    const state = await ctx.db.query("uploadSweep").first();
    const from = Math.max(state?.cursor ?? 0, UPLOADS_EPOCH);
    const until = Date.now() - UNCLAIMED_GRACE_MS;
    const page = await ctx.db.system
      .query("_storage")
      .withIndex("by_creation_time", (q: any) =>
        q.gt("_creationTime", from).lt("_creationTime", until),
      )
      .take(200);
    let deleted = 0;
    for (const f of page) {
      if (await ledgerRow(ctx, f._id)) continue;
      const msg = await ctx.db
        .query("messages")
        .withIndex("by_media", (q: any) => q.eq("mediaStorageId", f._id))
        .first();
      if (msg) {
        await ctx.db.insert("uploads", {
          storageId: f._id,
          userId: msg.userId,
          size: f.size ?? 0,
          createdAt: Date.now(),
        });
        continue;
      }
      await ctx.storage.delete(f._id);
      deleted++;
    }
    const cursor = page.length > 0 ? page[page.length - 1]._creationTime : from;
    if (state) await ctx.db.patch(state._id, { cursor });
    else await ctx.db.insert("uploadSweep", { cursor });
    if (page.length === 200) {
      await ctx.scheduler.runAfter(0, internal.files.sweepUnclaimed, {});
    }
    return { deleted, scanned: page.length };
  },
});

// Retrieve the serving URL for a stored file.
//
// This is a PUBLIC query over an id-shaped argument, and on a self-hosted
// deployment the URL it returns is unsigned and never expires (see
// lib/media/file_url_cache.dart). So it is, by construction, an oracle: name a
// storage id, receive the bytes forever. That is fine for avatars and ordinary
// attachments, whose ids are handed out with the message anyway.
//
// It is NOT fine for a view-once photo, whose entire promise is that the id is
// never handed out. `sanitizeViewOnce` in messages.ts strips those ids from
// every read path, so a well-behaved client can't name one — this check is the
// second lock, for the case where an id leaks by some route we didn't foresee.
// View-once bytes are served exclusively by the `/viewOnce` HTTP action against
// a single-use nonce.
//
// Message media is also members-only: the id travels with the message, but a
// copy forwarded or leaked out of a room must not open it for a non-member.
// A forward shares the blob, so any one readable copy is enough. Ids that
// belong to no message (avatars, stickers, moments) keep the old behaviour.
//
// A video's poster frame is looked up as well (`by_poster`), and gets both
// rules: it is a picture of the video, so it is members-only like the video,
// and a poster on an armed message is refused. The one exception is a view-
// once video note's micro poster, a blurred frame of at most
// `VIEW_ONCE_POSTER_MAX_BYTES` that reveals nothing; its size is re-checked
// here against storage, so a poster that is not micro is refused even if it
// somehow reached an armed row.
export const getFileUrl = query({
  args: { storageId: v.id("_storage") },
  handler: async (ctx, { storageId, userId }) => {
    const owners = [
      ...(await ctx.db
        .query("messages")
        .withIndex("by_media", (q) => q.eq("mediaStorageId", storageId))
        .take(50)),
      ...(await ctx.db
        .query("messages")
        .withIndex("by_poster", (q) => q.eq("posterStorageId", storageId))
        .take(50)),
    ];
    for (const m of owners) {
      if (m.viewOnce !== true) continue;
      const microPoster =
        m.type === "videoNote" &&
        m.posterStorageId === storageId &&
        (await isMicroPoster(ctx, storageId));
      if (!microPoster) return null;
    }
    if (owners.length > 0) {
      let readable = false;
      for (const m of owners) {
        if (await canReadRoom(ctx, m.roomId, userId)) {
          readable = true;
          break;
        }
      }
      if (!readable) return null;
    }
    return await ctx.storage.getUrl(storageId);
  },
});

/**
 * Drops a stored file, tolerating one that's already gone.
 *
 * Lives here rather than in `auth.ts` (its original home) because every write
 * to a `v.id("_storage")` field needs it: replacing an avatar, tearing down a
 * room, deleting a message. A bare `ctx.storage.delete` on a file some other
 * path already removed *throws*, which would abort whatever teardown was
 * half-done around it — so the swallow is load-bearing, not lazy.
 *
 * A plain helper taking `ctx: any`, following `roomCleanup.ts`: callers pass
 * their own ctx, and it stays reachable from mutations in any module.
 */
export async function deleteStored(ctx: any, storageId: any) {
  if (!storageId) return;
  await releaseLedger(ctx, storageId);
  try {
    await ctx.storage.delete(storageId);
  } catch (_) {/* already gone */}
}

// ─── Orphan reclamation ─────────────────────────────────────────────────────
//
// Convex bills for stored files, not for rows pointing at them, so a file
// nothing references costs money forever and is invisible: `_storage` is a
// system table, so nothing in the app can stumble over it. Historically three
// code paths abandoned files (avatar replacement, room teardown, message
// media) — those are fixed at the source now. What remains, and what no
// server-side fix can prevent, is the client dying between the upload PUT and
// the mutation that would have referenced the result. Hence this sweep.

/** Files younger than this are never touched. See `collectReferenced`. */
const GRACE_MS = 24 * 60 * 60 * 1000;

/**
 * Per-table row cap while building the reference set.
 *
 * No index exists on any storage field, so the only way to answer "is this file
 * referenced?" is to read every row that could hold an id. If that scan is
 * truncated the reference set is incomplete, and an incomplete reference set
 * means deleting *live* files — the one failure here nobody can undo. So the
 * sweep aborts rather than guesses.
 *
 * 4000 × 3 tables leaves headroom under Convex's ~16k-document per-function
 * read limit with `_storage` still to enumerate. Currently the largest of the
 * three is `messages` at ~460 rows, so there is roughly 9× slack. Tripping this
 * is the signal to index the five storage fields (including the nested
 * `replyToPreview.mediaStorageId` path) and check per-candidate instead of
 * building a set up front.
 */
const MAX_SCAN = 4000;

/** Files considered per run, so one tick can't run away. */
const SWEEP_LIMIT = 200;

/**
 * Reclaims the blobs belonging to [msg] — unless another message still points
 * at them.
 *
 * Forwarding re-references a file rather than re-uploading it, so one blob can
 * now be named by several messages in several rooms. A bare
 * `deleteStored(msg.mediaStorageId)` would therefore let deleting a forwarded
 * copy — or wiping the room it was forwarded out of, or purging the account
 * that first sent it — take the bytes out from under every other copy, leaving
 * live messages pointing at nothing. `by_media` exists for exactly this kind of
 * reverse lookup and makes the check one indexed read.
 *
 * [msg] is usually still in the table when this runs (`removeMessageAndFanout`
 * deletes it afterwards, because it reads siblings first), so the message being
 * removed is excluded from the count by id rather than assumed absent.
 *
 * The poster is gated on its OWN lookup (`by_poster`). It used to ride the
 * media lookup on the theory that a poster is only ever copied together with
 * its video, but a file reaches `posterStorageId` of one message and
 * `mediaStorageId` of another (a poster re-sent as a photo, a forward that
 * keeps one field), and then "is anyone else using my video" and "is anyone
 * else using my poster" differ. Each blob is checked against both columns.
 *
 * Returns the storage ids it really deleted (as strings), so the caller can
 * strip a reply preview's copy of the id only when the file is gone: a forward
 * that keeps the bytes alive keeps the preview's picture alive too.
 */
export async function releaseMessageBlobs(ctx: any, msg: any): Promise<string[]> {
  const deleted: string[] = [];
  const storageId = msg?.mediaStorageId;
  if (!storageId) {
    // No media means no poster: a poster is never written without one.
    return deleted;
  }

  const selfId = msg._id.toString();
  // Whether some OTHER message still points at [id] with either column.
  const usedElsewhere = async (id: any) => {
    const [asMedia, asPoster] = await Promise.all([
      ctx.db
        .query("messages")
        .withIndex("by_media", (q: any) => q.eq("mediaStorageId", id))
        .take(2),
      ctx.db
        .query("messages")
        .withIndex("by_poster", (q: any) => q.eq("posterStorageId", id))
        .take(2),
    ]);
    return [...asMedia, ...asPoster].some(
      (m: any) => m._id.toString() !== selfId
    );
  };

  if (!(await usedElsewhere(storageId))) {
    await deleteStored(ctx, storageId);
    deleted.push(storageId.toString());
  }
  const poster = msg.posterStorageId;
  if (poster && poster.toString() !== storageId.toString()) {
    if (!(await usedElsewhere(poster))) {
      await deleteStored(ctx, poster);
      deleted.push(poster.toString());
    }
  }
  return deleted;
}

/**
 * Every storage id any row currently points at.
 *
 * Every `v.id("_storage")` field in `schema.ts` that can be a file's only
 * pointer.
 * `replyToPreview.mediaStorageId` is a *denormalized copy* of a parent
 * message's id, snapshotted at send time — it counts as a live reference, or a
 * file still rendered inside a reply preview would be swept out from under it.
 * `posterStorageId` is reachable only through the message that owns it, so it
 * would otherwise look orphaned from the moment it was uploaded.
 *
 * Returns null when the scan can't be trusted (see `MAX_SCAN`).
 */
async function collectReferenced(ctx: any): Promise<Set<string> | null> {
  const referenced = new Set<string>();
  const add = (id: any) => { if (id) referenced.add(id.toString()); };

  // Every scan asks for one row more than the cap: coming back over the cap is
  // how we learn the read was truncated and the set is therefore untrustworthy.
  const scan = async (table: string) => {
    const rows = await ctx.db.query(table).take(MAX_SCAN + 1);
    return rows.length > MAX_SCAN ? null : rows;
  };

  const users = await scan("users");
  if (users === null) return null;
  for (const u of users) add(u.avatarStorageId);

  const rooms = await scan("rooms");
  if (rooms === null) return null;
  for (const r of rooms) add(r.avatarStorageId);

  const msgs = await scan("messages");
  if (msgs === null) return null;
  for (const m of msgs) {
    add(m.mediaStorageId);
    add(m.replyToPreview?.mediaStorageId);
    // A video's poster frame. Nothing else in the deployment points at it —
    // it is reachable only through the message that owns it — so leaving it
    // out here would make every poster look orphaned and have this sweep
    // delete it out from under its own video.
    add(m.posterStorageId);
  }

  // Feed moments. WITHOUT THIS BLOCK the daily sweep sees every highlight blob
  // as unreferenced and deletes it 24 hours after upload — silently, a day
  // late, and unrecoverably. Any future table carrying a `v.id("_storage")`
  // has to be added here too; that is the whole contract of this function.
  const moments = await scan("moments");
  if (moments === null) return null;
  for (const m of moments) {
    add(m.mediaStorageId);
    add(m.posterStorageId);
  }

  // Sticker art, official and personal — soft-deleted rows included, because
  // messages already sent still point at them. Sticker MESSAGES carry the id as
  // `stickerStorageId`, which is always one of these, so the rows are the
  // complete set.
  const stickers = await scan("stickers");
  if (stickers === null) return null;
  for (const s of stickers) add(s.storageId);

  // Scheduled photos. Uploaded when the sender scheduled them and pointed at
  // by nothing else until they go out — up to a year later. Without this the
  // sweep deletes the picture a day after it was scheduled, and the release
  // posts a photo whose bytes are gone.
  const scheduled = await scan("scheduledMessages");
  if (scheduled === null) return null;
  for (const r of scheduled) add(r.mediaStorageId);

  // A proposed room picture waiting on an admin. Same shape: the row is the
  // file's only pointer until it is approved, and an admin who takes more
  // than a day to decide must not find the picture already gone.
  const proposals = await scan("roomChangeRequests");
  if (proposals === null) return null;
  for (const r of proposals) add(r.storageId);

  return referenced;
}

/**
 * Read-only orphan report — the dry run for `gcOrphanedFiles`.
 *
 * Deliberately ignores `GRACE_MS` and `SWEEP_LIMIT`: this is for a human
 * deciding what should happen, so it shows everything, and flags with
 * `withinGrace` the ones the sweep would currently skip. Includes a serving
 * URL per file so you can look at an image before agreeing to lose it.
 *
 *   npx convex run files:listOrphans '{}'
 */
export const listOrphans = internalQuery({
  args: {},
  handler: async (ctx) => {
    const referenced = await collectReferenced(ctx);
    if (referenced === null) {
      return {
        aborted:
          `a scanned table exceeds ${MAX_SCAN} rows, so the reference set would ` +
          `be incomplete — see MAX_SCAN in files.ts`,
      };
    }

    const files = await ctx.db.system.query("_storage").collect();
    const cutoff = Date.now() - GRACE_MS;
    const orphans = [];
    for (const f of files) {
      if (referenced.has(f._id.toString())) continue;
      orphans.push({
        storageId: f._id,
        contentType: f.contentType,
        sizeKB: Math.round((f.size ?? 0) / 1024),
        uploaded: new Date(f._creationTime).toISOString(),
        sha256: f.sha256,
        withinGrace: f._creationTime >= cutoff,
        url: await ctx.storage.getUrl(f._id),
      });
    }

    const bytes = (rows: any[]) => rows.reduce((a, r) => a + r.sizeKB * 1024, 0);
    return {
      totalFiles: files.length,
      referencedFiles: files.length - orphans.length,
      orphanCount: orphans.length,
      orphanMB: +(bytes(orphans) / 1048576).toFixed(2),
      sweepableNow: orphans.filter((o) => !o.withinGrace).length,
      orphans,
    };
  },
});

/**
 * Deletes unreferenced files older than `GRACE_MS`.
 *
 * The age floor is what makes this safe to run unattended: a file that has been
 * PUT but whose `updateAvatar`/`send` hasn't landed yet is indistinguishable
 * from an orphan, so anything recent is off limits. 24h leaves room for a
 * retry, a lost-network resume, or a backgrounded app to finish the job.
 *
 * Runs daily from `crons.ts`; also safe to run by hand after `listOrphans`.
 */
export const gcOrphanedFiles = internalMutation({
  args: {
    /**
     * Override the age floor, in ms. For an operator who has already eyeballed
     * `listOrphans` output and accepts the risk on a specific file — pass 0 to
     * sweep regardless of age. The cron never sets this; leaving it unset is
     * what makes unattended runs safe.
     */
    graceMs: v.optional(v.number()),
  },
  handler: async (ctx, { graceMs }) => {
    const referenced = await collectReferenced(ctx);
    if (referenced === null) {
      console.warn(
        `files.gcOrphanedFiles: skipped — a scanned table exceeds ${MAX_SCAN} ` +
        `rows, so the reference set would be incomplete and live files could be ` +
        `deleted. Index the storage fields instead. See MAX_SCAN in files.ts.`,
      );
      return { skipped: true, deleted: 0, bytesFreed: 0 };
    }

    const cutoff = Date.now() - (graceMs ?? GRACE_MS);
    const files = await ctx.db.system.query("_storage").collect();

    let deleted = 0;
    let bytesFreed = 0;
    for (const f of files) {
      if (deleted >= SWEEP_LIMIT) break;
      if (f._creationTime >= cutoff) continue;
      if (referenced.has(f._id.toString())) continue;
      await deleteStored(ctx, f._id);
      deleted++;
      bytesFreed += f.size ?? 0;
    }

    if (deleted > 0) {
      console.log(
        `files.gcOrphanedFiles: reclaimed ${deleted} orphaned file(s), ` +
        `${(bytesFreed / 1048576).toFixed(2)} MB`,
      );
    }
    return { skipped: false, deleted, bytesFreed };
  },
});
