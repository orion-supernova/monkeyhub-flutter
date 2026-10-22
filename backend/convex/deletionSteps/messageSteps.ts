import { cursorOf, pageAfter, tuning, type Step } from "../deletionCore";
import { markReplyDeleted, removeMessageBounded } from "../messages";
import { purgeMatchForMessage } from "../matchCore";

/**
 * Custom teardown steps for the `message` deletion kind: what
 * `messages.removeMessageImmediate` left when a message was popular (more
 * reactions, answers, pins, bookmarks, view-once rows or replies than fit
 * inline). `targetId` is the dead message's id; `args.deletedStorageIds` are
 * the blobs the immediate part really deleted. Reactions, bookmarks, pins,
 * view-once rows, answers and the `matchMoves` clearing are generic steps.
 */
export const messageSteps: Step[] = [
  {
    id: "match",
    tier: 10,
    claims: ["matches.messageId"],
    /**
     * A card's game the immediate part did not reach (it takes the first ten
     * and a page of moves). The move bubbles of this slice are removed here;
     * an overflowing game queues its own `match` job.
     */
    async run(ctx, job, b) {
      if (!job.targetId) return { done: true };
      const bubbles = await purgeMatchForMessage(ctx, job.targetId);
      b.read(Math.max(bubbles.length, 1));
      for (const id of bubbles) {
        const move = await ctx.db.get(id);
        if (move) {
          await removeMessageBounded(ctx, move, id);
          b.write(3);
        }
      }
      return { done: true };
    },
  },
  {
    id: "replies",
    tier: 20,
    /**
     * Mark every reply's preview deleted. Replies stay in the `by_replyTo`
     * range, so this walks it with a `{creation time, id}` cursor (`pageAfter`:
     * rows that share a creation time are not skipped) and never re-patches (a
     * preview already `__DELETED__` is skipped).
     */
    async run(ctx, job, b) {
      if (!job.targetId) return { done: true };
      const gone = new Set<string>(
        Array.isArray(job.args?.deletedStorageIds)
          ? job.args.deletedStorageIds
          : [],
      );
      let cursor = job.cursor;
      for (;;) {
        if (b.spent()) return { done: false, cursor };
        const rows = await pageAfter(
          (t, k) =>
            ctx.db
              .query("messages")
              .withIndex("by_replyTo", (q) =>
                q.eq("replyToId", job.targetId as any).gte("_creationTime", t),
              )
              .take(k),
          cursor,
          tuning.pageRows,
        );
        b.read(Math.max(rows.length, 1));
        if (rows.length === 0) return { done: true };
        for (const child of rows) {
          if (b.spent()) return { done: false, cursor };
          if (await markReplyDeleted(ctx, child, gone)) b.write();
          cursor = cursorOf(child);
        }
      }
    },
  },
];
