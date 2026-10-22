import { attachFile, type FileHolder } from "./files";

/**
 * Share-attaches [storageId] to [holder] for a copy of somebody else's file: a
 * forward, report evidence, a sticker use, a scheduled photo going out.
 *
 * Lenient where `attachFile` is strict. The source of a copy can be a file from
 * before the upload ledger existed, which has no ledger row and so nothing to
 * ref; the backfill gives it both. Skipping it here keeps a forward of an old
 * photo working, and the copy is picked up by the same backfill. A file the
 * server owns outright (`permanent`) is a no-op inside `attachFile`.
 */
export async function attachShared(ctx: any, storageId: any, holder: FileHolder): Promise<void> {
  if (!storageId) return;
  const ledger = await ctx.db
    .query("uploads")
    .withIndex("by_storage", (q: any) => q.eq("storageId", storageId))
    .first();
  if (!ledger) return;
  await attachFile(ctx, storageId, holder, { share: true });
}
