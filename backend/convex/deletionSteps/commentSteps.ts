import { tuning, type Step } from "../deletionCore";

/**
 * Custom teardown steps for the `comment` deletion kind: the leftover of a
 * `momentComments.deleteCommentCore` whose reply subtree did not fit inline.
 * `targetId` is the dead comment's id (a thread root, or a reply whose
 * reactions overflowed). The reactions on the target itself are the generic
 * `momentCommentReactions.commentId` step; replies are here.
 */
export const commentSteps: Step[] = [
  {
    id: "replies",
    tier: 10,
    claims: ["momentComments.parentId"],
    /**
     * Delete replies under the dead root, each with its reactions, and move the
     * moment's counter by what went. No cursor: a deleted reply leaves the
     * `by_parent` range, so the next probe starts from the top.
     */
    async run(ctx, job, b) {
      // `eq(undefined)` would match every top-level comment.
      if (!job.targetId) return { done: true };
      for (;;) {
        if (b.spent()) return { done: false };
        const replies = await ctx.db
          .query("momentComments")
          .withIndex("by_parent", (q) => q.eq("parentId", job.targetId as any))
          .take(tuning.pageRows);
        b.read(Math.max(replies.length, 1));
        if (replies.length === 0) return { done: true };
        const gone = new Map<string, number>();
        let stoppedEarly = false;
        for (const reply of replies) {
          if (b.spent()) {
            stoppedEarly = true;
            break;
          }
          // A reply with a long tail of reactions: take what the budget
          // allows; the reply goes only once its reactions are all gone, so
          // a re-run picks the rest up.
          const rx = await ctx.db
            .query("momentCommentReactions")
            .withIndex("by_comment", (q) => q.eq("commentId", reply._id))
            .take(tuning.pageRows);
          b.read(Math.max(rx.length, 1));
          let cut = false;
          for (const r of rx) {
            if (b.spent()) {
              cut = true;
              break;
            }
            await ctx.db.delete(r._id);
            b.write();
          }
          if (cut || rx.length === tuning.pageRows) {
            stoppedEarly = true;
            break;
          }
          await ctx.db.delete(reply._id);
          b.write();
          const k = reply.momentId.toString();
          gone.set(k, (gone.get(k) ?? 0) + 1);
        }
        for (const [momentId, n] of gone) {
          const m = await ctx.db.get(momentId as any);
          b.read();
          const count = (m as any)?.commentCount;
          if (m && count !== undefined && count > 0) {
            await ctx.db.patch(m._id, { commentCount: Math.max(0, count - n) } as any);
            b.write();
          }
        }
        if (stoppedEarly) return { done: false };
      }
    },
  },
];
