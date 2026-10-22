import { deleteCapped, enqueueDeletion, tuning } from "./deletionCore";
import { releaseRowFiles } from "./files";

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
  await releaseRowFiles(ctx, "moments", m);

  let overflow = false;
  // Comment reactions before comments, so a half-done sweep never leaves a
  // reaction whose comment is gone.
  for (const [table, index, field] of [
    ["momentReactions", "by_moment", "momentId"],
    ["momentViews", "by_moment", "momentId"],
    ["momentCommentReactions", "by_moment", "momentId"],
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
  // Comments last, each releasing its sticker ref; `repairRefs` is the net for
  // the rest of a job's range.
  const comments = await ctx.db
    .query("momentComments")
    .withIndex("by_moment_created", (q: any) => q.eq("momentId", m._id))
    .take(cap + 1);
  for (const c of comments.slice(0, cap)) {
    await ctx.db.delete(c._id);
    await releaseRowFiles(ctx, "momentComments", c);
  }
  if (comments.length > cap) overflow = true;
  if (overflow) {
    await enqueueDeletion(ctx, { kind: "moment", targetId: m._id.toString() });
  }
}
