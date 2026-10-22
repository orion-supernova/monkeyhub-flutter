import { tuning, type Step } from "../deletionCore";
import { removeMessageBounded } from "../messages";

/**
 * Custom teardown steps for the `match` deletion kind: what `matchCore.eraseMatch`
 * left when a game had more moves, hidden rows or heartbeats than fit inline.
 * `targetId` is the dead match's id; `args.skipBubbles` is set when the move
 * bubbles are swept some other way (a room being wiped removes every message).
 * Hidden state and heartbeats are the generic `matchHidden.matchId` and
 * `matchPresence.matchId` steps.
 */
export const matchSteps: Step[] = [
  {
    id: "moves",
    tier: 10,
    claims: ["matchMoves.matchId"],
    /**
     * Page the move history, removing each move's bubble first unless
     * `skipBubbles`. No cursor: a deleted move leaves the `by_match_seq` range.
     */
    async run(ctx, job, b) {
      if (!job.targetId) return { done: true };
      const skipBubbles = job.args?.skipBubbles === true;
      for (;;) {
        if (b.spent()) return { done: false };
        const moves = await ctx.db
          .query("matchMoves")
          .withIndex("by_match_seq", (q) => q.eq("matchId", job.targetId as any))
          .take(tuning.pageRows);
        b.read(Math.max(moves.length, 1));
        if (moves.length === 0) return { done: true };
        for (const m of moves) {
          if (b.spent()) return { done: false };
          if (!skipBubbles && m.messageId) {
            const bubble = await ctx.db.get(m.messageId);
            b.read();
            if (bubble) {
              await removeMessageBounded(ctx, bubble, bubble._id);
              b.write(3);
            }
          }
          await ctx.db.delete(m._id);
          b.write();
        }
      }
    },
  },
];
