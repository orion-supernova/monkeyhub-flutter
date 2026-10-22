import { deleteCapped, enqueueDeletion, tuning } from "./deletionCore";
import { deleteStored } from "./files";

/**
 * Deletes a moment and everything hanging off it, in one bounded transaction.
 * Shared by `feed.remove` and the account teardown (`userSteps`).
 *
 * The row goes first, then its blobs, then up to `cap` rows of each child
 * table (reactions, views, comment reactions, comments). If any table had more,
 * one `moment` job keyed by the dead id finishes the range (the generic
 * cascades, comment reactions before comments). Children are only ever read
 * through the moment, so none of them is reachable once the row is gone.
 *
 * The blob goes too: this is the author asking for it to be gone, which is a
 * different act from a moment merely expiring off friends' boards.
 */
export async function deleteMomentCore(
  ctx: any,
  m: any,
  cap: number = tuning.inlineCap,
): Promise<void> {
  await ctx.db.delete(m._id);
  await releaseMomentFiles(ctx, m);

  let overflow = false;
  // Comment reactions before comments, so a half-done sweep never leaves a
  // reaction whose comment is gone.
  for (const [table, index, field] of [
    ["momentReactions", "by_moment", "momentId"],
    ["momentViews", "by_moment", "momentId"],
    ["momentCommentReactions", "by_moment", "momentId"],
    ["momentComments", "by_moment_created", "momentId"],
  ] as const) {
    const r = await deleteCapped(
      ctx,
      ctx.db
        .query(table)
        .withIndex(index, (q: any) => q.eq(field, m._id)),
      cap,
    );
    if (r.overflow) overflow = true;
  }
  if (overflow) {
    await enqueueDeletion(ctx, { kind: "moment", targetId: m._id.toString() });
  }
}

/**
 * Releases a deleted moment's picture and poster, each only when no other
 * moment still points at the same bytes.
 *
 * The two fields are different columns, and each blob is checked against BOTH
 * indexes: a file can be one moment's picture and another's poster (a poster
 * re-posted as a photo), so "anyone else using my picture" and "anyone else
 * using my poster" differ. The row is already deleted, so any hit is another
 * moment. Through `deleteStored`, never `ctx.storage.delete`, which throws on
 * an already-deleted blob.
 */
async function releaseMomentFiles(ctx: any, m: any): Promise<void> {
  const usedElsewhere = async (id: any) =>
    (await ctx.db
      .query("moments")
      .withIndex("by_media", (q: any) => q.eq("mediaStorageId", id))
      .first()) !== null ||
    (await ctx.db
      .query("moments")
      .withIndex("by_poster", (q: any) => q.eq("posterStorageId", id))
      .first()) !== null;

  const media = m.mediaStorageId;
  if (media && !(await usedElsewhere(media))) await deleteStored(ctx, media);
  const poster = m.posterStorageId;
  if (
    poster &&
    poster.toString() !== media?.toString() &&
    !(await usedElsewhere(poster))
  ) {
    await deleteStored(ctx, poster);
  }
}
