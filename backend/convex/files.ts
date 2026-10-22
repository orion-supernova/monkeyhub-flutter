import { internalMutation, internalQuery } from "./_generated/server";
import { mutation, query } from "./functions";
import { v } from "convex/values";
import { canReadRoom } from "./roomAccess";
import { consume } from "./rateLimit";
import { internal } from "./_generated/api";
import { cursorOf, pageAfter } from "./deletionCore";
import { FILE_FIELDS } from "./referenceRules";

// Kept importable from here for the call sites; the table lives in referenceRules.ts.
export { FILE_FIELDS };

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
//
// ─── References ─────────────────────────────────────────────────────────────
//
// A claimed file is then ATTACHED to whatever uses it ([attachFile]): one
// `fileRefs` row per (holder, field). Releasing the last ref frees the file
// ([releaseFile]), so a forward, a reply or a second room can share a blob and
// nothing has to scan other tables to know whether it is still wanted.
//
// `uploads.tracked` says refs are authoritative for a file. Files from before
// refs are untracked until `fileBackfill.markTracked`: they are released by
// the old index checks ([legacyInUse]), so a missing ref never deletes a file
// somebody still points at. See docs/data-integrity-phase3-design.md.

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
 *
 * A second claim by the same owner is fine and changes nothing: `messages.send`
 * claims before `sendCore` dedupes on `clientId`, so a retry presents the same
 * file. "Is somebody else using it" is [attachFile]'s question, not this one's.
 * `permanent` marks server-owned art that is never ref'd or freed.
 */
export async function claimUpload(
  ctx: any,
  storageId: any,
  userId: any,
  kind: keyof typeof MAX_FILE_BYTES,
  opts: { solo?: boolean; permanent?: boolean } = {},
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
  const createdAt = Date.now();
  const permanent = opts.permanent === true;
  await ctx.db.insert("uploads", {
    storageId,
    userId: userId ?? undefined,
    size,
    solo: solo || undefined,
    createdAt,
    tracked: true,
    permanent: permanent || undefined,
    // No ref yet: freed after a day at zero unless something attaches it.
    zeroSince: permanent ? undefined : createdAt,
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
 * else throws exactly as `claimUpload` would, and a file anything still
 * references is left alone. Tolerates a file that is already gone, which is
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
  if (await fileInUse(ctx, storageId)) return;
  await destroy(ctx, storageId);
}

/** Drops [storageId]'s ledger row and gives its bytes back to the owner. */
async function releaseLedger(ctx: any, storageId: any) {
  const row = await ledgerRow(ctx, storageId);
  if (!row) return;
  await ctx.db.delete(row._id);
  if (!row.userId || row.uncounted) return;
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
 * one page however large storage grows. A file something still points at (a
 * path that forgot to claim) is given an adopted ledger row instead of deleted:
 * the sweep must never be the thing that loses a photo. [legacyInUse] is the
 * last guard before a delete.
 *
 * Starts at [UPLOADS_EPOCH] until [liftEpoch] is run by hand.
 */
export const sweepUnclaimed = internalMutation({
  args: {},
  returns: v.object({ deleted: v.number(), scanned: v.number() }),
  handler: async (ctx) => {
    const state = await ctx.db.query("uploadSweep").first();
    const from = state?.liftedAt
      ? (state.cursor ?? 0)
      : Math.max(state?.cursor ?? 0, UPLOADS_EPOCH);
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
      if (msg || (await legacyInUse(ctx, f._id))) {
        console.warn("file_unclaimed_in_use", f._id.toString());
        await ctx.db.insert("uploads", {
          storageId: f._id,
          userId: msg?.userId,
          size: f.size ?? 0,
          createdAt: Date.now(),
          // `tracked` stays unset: by_tracked eq(undefined) is "still to mark".
          uncounted: true,
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

/**
 * Lets the sweep reach files from before [UPLOADS_EPOCH]. MANUAL: run it only
 * after the backfill is done and `markTracked` has run, because until then a
 * ledger-less old file may be a live avatar or sticker that [legacyInUse]
 * cannot see (no index on those fields). Refuses otherwise.
 *
 *   npx convex run files:liftEpoch '{}'
 */
export const liftEpoch = internalMutation({
  args: {},
  handler: async (ctx) => {
    const state = await ctx.db.query("uploadSweep").first();
    if (state?.liftedAt) return { lifted: false, reason: "already lifted" };
    const run = await ctx.db.query("fileBackfill").order("desc").first();
    if (!run || run.status !== "done") {
      return { lifted: false, reason: "the file backfill has not finished" };
    }
    const untracked = await ctx.db
      .query("uploads")
      .withIndex("by_tracked", (q: any) => q.eq("tracked", undefined))
      .first();
    if (untracked) {
      return { lifted: false, reason: "files are still untracked: run fileBackfill:markTracked" };
    }
    const liftedAt = Date.now();
    if (state) await ctx.db.patch(state._id, { cursor: 0, liftedAt });
    else await ctx.db.insert("uploadSweep", { cursor: 0, liftedAt });
    return { lifted: true, reason: null };
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


// ─── References ─────────────────────────────────────────────────────────────

/** A row's field that holds a file. `id` is the row's `_id` as a string. */
export type FileHolder = { table: string; id: string; field: string };

/**
 * Untracked files in these fields are never freed by a release: the file is
 * usually a sticker some other row owns, and `stickers.storageId` has no index
 * for [legacyInUse] to check. Tracked files are unaffected; once marked,
 * the reaper frees whatever really has no refs.
 */
// `stickers.storageId` has no index either, so `legacyInUse` can't see the art
// other messages still show; an untracked sticker file is left to the reaper
// once `markTracked` has counted its uses.
const LEGACY_KEEP_FIELDS = new Set([
  "messages.stickerStorageId",
  "momentComments.stickerStorageId",
  "stickers.storageId",
]);

/** Zero refs for this long before `reapUnreferenced` frees a file. */
const ZERO_REF_GRACE_MS = 24 * 60 * 60 * 1000;

/** Read per call so a test, or an operator, can flip it. */
const refsEnforced = () => process.env.FILE_REFS_ENFORCE === "1";

const holderOf = (storageId: any, h: FileHolder, q: any) =>
  q.eq("storageId", storageId).eq("holderId", h.id).eq("field", h.field);

async function refRow(ctx: any, storageId: any, h: FileHolder) {
  return await ctx.db
    .query("fileRefs")
    .withIndex("by_file_holder", (q: any) => holderOf(storageId, h, q))
    .first();
}

/** Whether a ref from a holder other than [exceptId] exists. */
async function otherRef(ctx: any, storageId: any, exceptId?: string): Promise<boolean> {
  // A holder owns at most a few fields of one file, so eight rows always reach
  // a different holder if there is one.
  const refs = await ctx.db
    .query("fileRefs")
    .withIndex("by_file_holder", (q: any) => q.eq("storageId", storageId))
    .take(8);
  return refs.some((r: any) => r.holderId !== exceptId);
}

/**
 * Records that [holder]'s field points at [storageId]. The file needs a ledger
 * row ([claimUpload]) or this throws `FILE_NOT_CLAIMED`.
 *
 * Exclusive by default: a second HOLDER of a tracked file throws `FILE_IN_USE`
 * once `FILE_REFS_ENFORCE=1`, and only logs `file_in_use` before that. A second
 * field on the same holder is fine (a poster equal to its media). `share` is for
 * the paths where sharing is the point (forward, reply, sticker use) and skips
 * the check. Idempotent, and a share onto a hot file writes only the new ref.
 */
export async function attachFile(
  ctx: any,
  storageId: any,
  holder: FileHolder,
  opts: { share?: boolean } = {},
): Promise<void> {
  if (!storageId) return;
  const ledger = await ledgerRow(ctx, storageId);
  if (!ledger) throw new Error("FILE_NOT_CLAIMED");
  if (ledger.permanent) return;
  if (await refRow(ctx, storageId, holder)) return;
  if (opts.share !== true && (await otherRef(ctx, storageId, holder.id))) {
    if (ledger.tracked && refsEnforced()) throw new Error("FILE_IN_USE");
    console.warn("file_in_use", storageId.toString(), holder.table, holder.field);
  }
  await ctx.db.insert("fileRefs", {
    storageId,
    holderTable: holder.table,
    holderId: holder.id,
    field: holder.field,
    createdAt: Date.now(),
  });
  if (ledger.zeroSince !== undefined) {
    await ctx.db.patch(ledger._id, { zeroSince: undefined });
  }
}

/**
 * Drops [holder]'s ref and frees the file when it was the last use.
 * `released` is whether a ref existed (false on a double release), `deleted`
 * whether the file went with it. Immediate, never deferred: a view-once burn or
 * an account deletion gives the bytes back at once.
 *
 * Untracked files (see the header) ignore a missing ref and are freed only
 * when [legacyInUse] finds nothing else pointing at them.
 */
export async function releaseFile(
  ctx: any,
  storageId: any,
  holder: FileHolder,
): Promise<{ released: boolean; deleted: boolean }> {
  if (!storageId) return { released: false, deleted: false };
  const ledger = await ledgerRow(ctx, storageId);
  if (ledger?.permanent) return { released: false, deleted: false };
  const ref = await refRow(ctx, storageId, holder);
  if (ref) await ctx.db.delete(ref._id);
  const released = !!ref;
  if (ledger?.tracked) {
    if (!ref || (await otherRef(ctx, storageId))) return { released, deleted: false };
    // [otherRef] with no exception also sees this holder's other fields, which
    // is what keeps a poster equal to its media alive until both are released.
    await destroy(ctx, storageId);
    return { released, deleted: true };
  }
  if (LEGACY_KEEP_FIELDS.has(`${holder.table}.${holder.field}`)) {
    return { released, deleted: false };
  }
  if (await legacyInUse(ctx, storageId, holder)) return { released, deleted: false };
  await destroy(ctx, storageId);
  return { released, deleted: true };
}

/** Moves a use from one holder to another: the new ref lands before the old goes. */
export async function transferFile(
  ctx: any,
  storageId: any,
  from: FileHolder,
  to: FileHolder,
): Promise<void> {
  await attachFile(ctx, storageId, to, { share: true });
  await releaseFile(ctx, storageId, from);
}

/**
 * Releases every file [row] of [table] holds ([FILE_FIELDS]), then any ref
 * still filed under its id (a field that changed without a release). Returns
 * the storage ids it really deleted, as strings, so a reply preview's copy of
 * an id is dropped only when the file is gone.
 */
export async function releaseRowFiles(ctx: any, table: string, row: any): Promise<string[]> {
  const deleted: string[] = [];
  if (!row) return deleted;
  const id = row._id.toString();
  const done = new Set<string>();
  const one = async (storageId: any, h: FileHolder) => {
    const key = `${storageId}:${h.field}`;
    if (done.has(key)) return;
    done.add(key);
    const r = await releaseFile(ctx, storageId, h);
    if (r.deleted) deleted.push(storageId.toString());
  };
  for (const field of FILE_FIELDS[table] ?? []) {
    if (row[field]) await one(row[field], { table, id, field });
  }
  const strays = await ctx.db
    .query("fileRefs")
    .withIndex("by_holder", (q: any) => q.eq("holderId", id))
    .take(16);
  for (const r of strays) {
    await one(r.storageId, { table: r.holderTable, id, field: r.field });
  }
  return deleted;
}

/**
 * Deletes the file and its ledger row whatever still points at it, for account
 * deletion (a personal sticker goes with its owner). Refs are left for
 * `repairRefs`, which drops those whose file is gone.
 */
export async function forceDeleteFile(ctx: any, storageId: any): Promise<void> {
  await destroy(ctx, storageId);
}

/**
 * Whether anything other than [except] uses [storageId]: refs for a tracked
 * file, the old index checks for the rest.
 */
export async function fileInUse(ctx: any, storageId: any, except?: FileHolder): Promise<boolean> {
  if (!storageId) return false;
  const ledger = await ledgerRow(ctx, storageId);
  if (ledger?.permanent) return true;
  if (ledger?.tracked) return await otherRef(ctx, storageId, except?.id);
  return await legacyInUse(ctx, storageId, except);
}

/**
 * The pre-refs "is anyone else using it": the indexed columns that used to be
 * checked (message media and poster, moment media and poster, room avatar,
 * room-change request), plus any ref from another holder and the ledger
 * owner's current avatar (`users` has no index). Removed after the flip.
 */
export async function legacyInUse(ctx: any, storageId: any, except?: FileHolder): Promise<boolean> {
  const others = (table: string, rows: any[]) =>
    rows.some((r) => !(except && except.table === table && except.id === r._id.toString()));
  const by = (table: string, index: string, field: string) =>
    ctx.db
      .query(table)
      .withIndex(index, (q: any) => q.eq(field, storageId))
      .take(3);
  if (others("messages", await by("messages", "by_media", "mediaStorageId"))) return true;
  if (others("messages", await by("messages", "by_poster", "posterStorageId"))) return true;
  if (others("moments", await by("moments", "by_media", "mediaStorageId"))) return true;
  if (others("moments", await by("moments", "by_poster", "posterStorageId"))) return true;
  if (others("rooms", await by("rooms", "by_avatar", "avatarStorageId"))) return true;
  if (others("roomChangeRequests", await by("roomChangeRequests", "by_storage", "storageId"))) {
    return true;
  }
  if (await otherRef(ctx, storageId, except?.id)) return true;
  const ledger = await ledgerRow(ctx, storageId);
  if (ledger?.userId && !(except?.table === "users" && except.id === ledger.userId.toString())) {
    const owner = await ctx.db.get(ledger.userId);
    if (owner?.avatarStorageId?.toString() === storageId.toString()) return true;
  }
  return false;
}

/** Deletes the file and its ledger row. Not checked: callers decide. */
export async function destroy(ctx: any, storageId: any): Promise<void> {
  if (!storageId) return;
  await releaseLedger(ctx, storageId);
  try {
    await ctx.storage.delete(storageId);
  } catch (_) {/* already gone */}
}

/**
 * Drops a stored file, tolerating one that's already gone.
 *
 * Lives here rather than in `auth.ts` (its original home) because every write
 * to a `v.id("_storage")` field needs it: a bare `ctx.storage.delete` on a file
 * some other path already removed *throws*, which would abort whatever
 * teardown was half-done around it, so the swallow is load-bearing.
 *
 * Unconditional: it is [destroy]. Callers that cannot know whether the file is
 * shared go through [releaseFile]. Goes after the flip.
 */
export async function deleteStored(ctx: any, storageId: any) {
  await destroy(ctx, storageId);
}

/**
 * Releases the blobs belonging to [msg] (media, poster, sticker) and returns
 * the storage ids it really deleted, as strings, so the caller can strip a
 * reply preview's copy of the id only when the file is gone: a forward that
 * keeps the bytes alive keeps the preview's picture alive too.
 *
 * [msg] is usually still in the table when this runs (`removeMessageAndFanout`
 * deletes it afterwards, because it reads siblings first); the release
 * excludes it by id.
 */
export async function releaseMessageBlobs(ctx: any, msg: any): Promise<string[]> {
  return await releaseRowFiles(ctx, "messages", msg);
}

/** Cap on chained runs of the self-rescheduling jobs below. */
const MAX_CHAIN = 50;

/**
 * The reaper's safety gate: refs are only trusted to say "unused" once the
 * latest backfill has finished its mark phase (`fileBackfill.markTracked`) AND
 * an operator has set `FILE_REFS_REAP=1` after checking the rollout. The env is
 * read per call, like [refsEnforced].
 */
async function reapEnabled(ctx: any): Promise<boolean> {
  if (process.env.FILE_REFS_REAP !== "1") return false;
  const run = await ctx.db.query("fileBackfill").order("desc").first();
  return !!run && run.markedAt !== undefined;
}

/**
 * Frees tracked files that have had no refs for [ZERO_REF_GRACE_MS]: an upload
 * claimed and never attached, and files `markTracked` found with no use. A ref
 * that arrived since clears the mark instead (self-heal). Every 10 minutes.
 * Deletes nothing while gated ([reapEnabled]); it logs what it would have freed.
 */
export const reapUnreferenced = internalMutation({
  args: { chain: v.optional(v.number()) },
  handler: async (ctx, { chain }) => {
    const cutoff = Date.now() - ZERO_REF_GRACE_MS;
    const rows = await ctx.db
      .query("uploads")
      .withIndex("by_zero_since", (q: any) => q.gt("zeroSince", 0).lt("zeroSince", cutoff))
      .take(100);
    if (!(await reapEnabled(ctx))) {
      // Safety gate: until the rollout is verified a missed attach would read
      // as "unused" here and delete live media. Count, write nothing.
      let wouldReap = 0;
      for (const row of rows) {
        if (row.permanent || !row.tracked) continue;
        if (!(await otherRef(ctx, row.storageId))) wouldReap++;
      }
      if (wouldReap > 0) {
        console.warn(
          `[files] reapUnreferenced is gated (needs a marked fileBackfill and FILE_REFS_REAP=1): ` +
            `would have reaped ${wouldReap}${rows.length === 100 ? "+" : ""} files`,
        );
      }
      return { reaped: 0, scanned: rows.length, wouldReap, gated: true };
    }
    let reaped = 0;
    for (const row of rows) {
      if (row.permanent || !row.tracked) {
        await ctx.db.patch(row._id, { zeroSince: undefined });
      } else if (await otherRef(ctx, row.storageId)) {
        await ctx.db.patch(row._id, { zeroSince: undefined });
      } else {
        await destroy(ctx, row.storageId);
        reaped++;
      }
    }
    if (rows.length === 100 && (chain ?? 0) + 1 < MAX_CHAIN) {
      await ctx.scheduler.runAfter(0, internal.files.reapUnreferenced, {
        chain: (chain ?? 0) + 1,
      });
    }
    return { reaped, scanned: rows.length };
  },
});

/**
 * Nightly safety net: drops a ref whose holder row is gone, whose field no
 * longer equals the file, or whose ledger row is missing. A tracked file left
 * with no refs gets `zeroSince` (the reaper frees it after the grace period).
 * Pages `fileRefs` with `uploadSweep.refCursor`, wrapping to the start at the end.
 */
export const repairRefs = internalMutation({
  args: { chain: v.optional(v.number()) },
  handler: async (ctx, { chain }) => {
    const state = await ctx.db.query("uploadSweep").first();
    const refs = await pageAfter(
      (t, k) =>
        ctx.db
          .query("fileRefs")
          .withIndex("by_creation_time", (q: any) => q.gte("_creationTime", t))
          .take(k),
      state?.refCursor ?? null,
      200,
    );
    let dropped = 0;
    const touched = new Set<string>();
    for (const r of refs) {
      let alive = false;
      const ledger = await ledgerRow(ctx, r.storageId);
      if (ledger) {
        let holder: any = null;
        try {
          const id = ctx.db.normalizeId(r.holderTable as any, r.holderId);
          holder = id ? await ctx.db.get(id) : null;
        } catch (_) {/* unknown table */}
        alive = !!holder && holder[r.field]?.toString() === r.storageId.toString();
      }
      if (alive) continue;
      await ctx.db.delete(r._id);
      dropped++;
      touched.add(r.storageId.toString());
    }
    for (const r of refs) {
      const key = r.storageId.toString();
      if (!touched.delete(key)) continue;
      const ledger = await ledgerRow(ctx, r.storageId);
      if (ledger?.tracked && !ledger.permanent && ledger.zeroSince === undefined) {
        if (!(await otherRef(ctx, r.storageId))) {
          await ctx.db.patch(ledger._id, { zeroSince: Date.now() });
        }
      }
    }
    const full = refs.length === 200;
    const refCursor = full ? cursorOf(refs[refs.length - 1] as any) : undefined;
    if (state) await ctx.db.patch(state._id, { refCursor });
    else await ctx.db.insert("uploadSweep", { cursor: 0, refCursor });
    if (full && (chain ?? 0) + 1 < MAX_CHAIN) {
      await ctx.scheduler.runAfter(0, internal.files.repairRefs, { chain: (chain ?? 0) + 1 });
    }
    return { dropped, scanned: refs.length };
  },
});

/**
 * Read-only dry run for `fileBackfill.markTracked`: the untracked files with no
 * refs, the ones `markTracked` would schedule for deletion, with a URL so a
 * human can look before agreeing to lose them. Pages `uploads.by_tracked`; pass
 * the returned `next` back as `cursor` until it is null.
 *
 *   npx convex run files:zeroRefReport '{}'
 */
export const zeroRefReport = internalQuery({
  args: { cursor: v.optional(v.string()), limit: v.optional(v.number()) },
  handler: async (ctx, { cursor, limit }) => {
    const n = Math.min(limit ?? 50, 100);
    const rows = await pageAfter(
      (t, k) =>
        ctx.db
          .query("uploads")
          .withIndex("by_tracked", (q: any) => q.eq("tracked", undefined).gte("_creationTime", t))
          .take(k),
      cursor ?? null,
      n,
    );
    const zero = [];
    for (const row of rows) {
      if (row.permanent) continue;
      if (await otherRef(ctx, row.storageId)) continue;
      zero.push({
        storageId: row.storageId,
        userId: row.userId,
        sizeKB: Math.round(row.size / 1024),
        uploaded: new Date(row.createdAt).toISOString(),
        url: await ctx.storage.getUrl(row.storageId),
      });
    }
    return {
      scanned: rows.length,
      zeroRef: zero,
      next: rows.length === n ? cursorOf(rows[rows.length - 1] as any) : null,
    };
  },
});

/**
 * Seeds one ref for the file backfill: makes sure a ledger row exists (adopted:
 * untracked and `uncounted: true`, owner [ownerId] or none), then inserts the
 * ref if absent. A file that no longer exists is reported, never thrown.
 */
export async function backfillRef(
  ctx: any,
  storageId: any,
  holder: FileHolder,
  ownerId: any,
): Promise<"inserted" | "exists" | "missingFile"> {
  const meta = await ctx.db.system.get(storageId);
  if (!meta) return "missingFile";
  const ledger = await ledgerRow(ctx, storageId);
  if (!ledger) {
    await ctx.db.insert("uploads", {
      storageId,
      userId: ownerId ?? undefined,
      size: meta.size ?? 0,
      createdAt: Date.now(),
      // `tracked` stays unset: by_tracked eq(undefined) is "still to mark".
      uncounted: true,
    });
  } else if (ledger.permanent) {
    return "exists";
  }
  if (await refRow(ctx, storageId, holder)) return "exists";
  await ctx.db.insert("fileRefs", {
    storageId,
    holderTable: holder.table,
    holderId: holder.id,
    field: holder.field,
    createdAt: Date.now(),
  });
  return "inserted";
}
