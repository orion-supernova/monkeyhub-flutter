import { mutation, query, internalMutation, internalQuery } from "./_generated/server";
import { v } from "convex/values";

// Generate a short-lived upload URL for the client to PUT a file directly to Convex storage
export const generateUploadUrl = mutation({
  handler: async (ctx) => {
    return await ctx.storage.generateUploadUrl();
  },
});

// Retrieve the serving URL for a stored file
export const getFileUrl = query({
  args: { storageId: v.id("_storage") },
  handler: async (ctx, { storageId }) => {
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
 * is the signal to index the four storage fields (including the nested
 * `replyToPreview.mediaStorageId` path) and check per-candidate instead of
 * building a set up front.
 */
const MAX_SCAN = 4000;

/** Files considered per run, so one tick can't run away. */
const SWEEP_LIMIT = 200;

/**
 * Every storage id any row currently points at.
 *
 * The four fields are the complete set of `v.id("_storage")` in `schema.ts`.
 * `replyToPreview.mediaStorageId` is a *denormalized copy* of a parent
 * message's id, snapshotted at send time — it counts as a live reference, or a
 * file still rendered inside a reply preview would be swept out from under it.
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
  }

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
