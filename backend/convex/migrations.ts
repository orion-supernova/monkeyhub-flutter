import { internalMutation } from "./_generated/server";
import { internal } from "./_generated/api";
import { v } from "convex/values";

/**
 * One-off backfill for `messages.rootId` (see the field comment in schema.ts).
 *
 * Every message sent after the `rootId` deploy carries the field already;
 * this walks history and fills it in for replies written before it existed.
 *
 * Resolution is by walking *up* the `replyToId` chain rather than by
 * processing parents before children, which makes the job order-independent,
 * idempotent, and safe to re-run or resume after a failure. Only messages
 * with `replyToId` are touched — roots deliberately keep `rootId` undefined.
 *
 * Self-chains through the scheduler until the table is exhausted. Kick it off
 * with:
 *
 *     npx convex run migrations:backfillRootIds '{}'
 *
 * and watch the returned/logged counts. Re-running after completion is a
 * no-op.
 */
export const backfillRootIds = internalMutation({
  args: {
    cursor: v.optional(v.string()),
    batchSize: v.optional(v.number()),
    scanned: v.optional(v.number()),
    patched: v.optional(v.number()),
  },
  handler: async (ctx, { cursor, batchSize, scanned, patched }) => {
    const numItems = Math.min(batchSize ?? 200, 500);
    const page = await ctx.db
      .query("messages")
      .paginate({ numItems, cursor: cursor ?? null });

    let totalScanned = scanned ?? 0;
    let totalPatched = patched ?? 0;

    for (const msg of page.page) {
      totalScanned++;
      if (!msg.replyToId || msg.rootId) continue;

      // Walk up to the top of the chain. Bounded by 20 hops with a cycle
      // guard, matching the walk in the legacy `messages:getThread`. Stops
      // early if an ancestor already carries a rootId.
      let rootId: any = msg.replyToId;
      const seen = new Set<string>([msg._id.toString()]);
      for (let i = 0; i < 20; i++) {
        const key = rootId.toString();
        if (seen.has(key)) break;
        seen.add(key);
        const parent = await ctx.db.get(rootId);
        // Missing parent (deleted/expired): the chain is orphaned, so the
        // message we stopped at is the best available root. Grouping is
        // preserved as long as every sibling resolves to the same id.
        if (!parent) break;
        if (parent.rootId) {
          rootId = parent.rootId;
          break;
        }
        if (!parent.replyToId) break;
        rootId = parent.replyToId;
      }

      // A message can never be its own root.
      if (rootId.toString() === msg._id.toString()) continue;

      await ctx.db.patch(msg._id, { rootId });
      totalPatched++;
    }

    if (!page.isDone) {
      await ctx.scheduler.runAfter(0, internal.migrations.backfillRootIds, {
        cursor: page.continueCursor,
        batchSize: numItems,
        scanned: totalScanned,
        patched: totalPatched,
      });
      return { done: false, scanned: totalScanned, patched: totalPatched };
    }

    console.log(
      `backfillRootIds complete: scanned ${totalScanned}, patched ${totalPatched}`
    );
    return { done: true, scanned: totalScanned, patched: totalPatched };
  },
});

/**
 * Verification helper for the backfill: counts messages that still need a
 * rootId. Must reach 0 and stay there.
 *
 *     npx convex run migrations:countMissingRootIds '{}'
 */
export const countMissingRootIds = internalMutation({
  args: {
    cursor: v.optional(v.string()),
    total: v.optional(v.number()),
    replies: v.optional(v.number()),
    missing: v.optional(v.number()),
  },
  handler: async (ctx, { cursor, total, replies, missing }) => {
    // Paginated rather than `.collect()` — this runs against the full
    // messages table and would otherwise blow the per-function read limit.
    const page = await ctx.db
      .query("messages")
      .paginate({ numItems: 500, cursor: cursor ?? null });

    let t = total ?? 0;
    let r = replies ?? 0;
    let m = missing ?? 0;
    for (const msg of page.page) {
      t++;
      if (!msg.replyToId) continue;
      r++;
      if (!msg.rootId) m++;
    }

    if (!page.isDone) {
      await ctx.scheduler.runAfter(0, internal.migrations.countMissingRootIds, {
        cursor: page.continueCursor,
        total: t,
        replies: r,
        missing: m,
      });
      return { done: false, total: t, replies: r, missing: m };
    }

    console.log(
      `countMissingRootIds: ${t} messages, ${r} replies, ${m} missing rootId`
    );
    return { done: true, total: t, replies: r, missing: m };
  },
});
