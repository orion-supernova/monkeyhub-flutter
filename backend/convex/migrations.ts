import { internalMutation } from "./_generated/server";
import { internal } from "./_generated/api";
import { v } from "convex/values";
import type { Id } from "./_generated/dataModel";
import { LINK_PATTERN, galleryBucketFor } from "./messages";

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
      // Typed for the same reason as `messages.threadFor`'s walker: as `any`,
      // `ctx.db.get(rootId)` resolved to the union of every table's document
      // and neither `rootId` nor `replyToId` existed on it.
      let rootId: Id<"messages"> = msg.replyToId;
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

/**
 * One-off backfill for `messages.galleryBucket` and `messages.hasLink` (see
 * the field comments in schema.ts).
 *
 * Every message sent after the shared-content deploy carries both already;
 * this walks history so the browser can reach anything older than the ~100
 * messages a client holds. Without it the MEDIA/FILES/LINKS tabs are empty for
 * every room that existed before the deploy, which looks exactly like a broken
 * feature rather than a pending migration.
 *
 * Both values are derived from the message alone — no parent walk, no ordering
 * constraint — so this is order-independent, idempotent, and safe to re-run or
 * resume after a failure. Rows that should carry neither (text without a link,
 * system rows, view-once photos, attachments whose upload never landed) are
 * left with both fields ABSENT rather than written false/none, because an
 * absent field is what keeps them outside the index range entirely.
 *
 * Self-chains through the scheduler until the table is exhausted. Kick it off
 * with:
 *
 *     npx convex run migrations:backfillRoomContent '{}'
 *
 * and watch the returned/logged counts. Re-running after completion is a
 * no-op.
 */
export const backfillRoomContent = internalMutation({
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

      const bucket = galleryBucketFor(
        msg.type ?? "text",
        msg.mediaStorageId !== undefined,
        msg.viewOnce === true
      );
      const linked =
        msg.viewOnce !== true && LINK_PATTERN.test(msg.content ?? "");

      // Only the fields that would actually change, so a re-run patches
      // nothing and a partial run resumes without rewriting what it did.
      const patch: Record<string, any> = {};
      if (bucket !== msg.galleryBucket) patch.galleryBucket = bucket;
      if (linked && msg.hasLink !== true) patch.hasLink = true;
      // `undefined` in a patch is how Convex clears a field — which is what a
      // row wrongly marked by an earlier version of this needs.
      if (!linked && msg.hasLink !== undefined) patch.hasLink = undefined;

      if (Object.keys(patch).length === 0) continue;
      await ctx.db.patch(msg._id, patch);
      totalPatched++;
    }

    if (!page.isDone) {
      await ctx.scheduler.runAfter(0, internal.migrations.backfillRoomContent, {
        cursor: page.continueCursor,
        batchSize: numItems,
        scanned: totalScanned,
        patched: totalPatched,
      });
      return { done: false, scanned: totalScanned, patched: totalPatched };
    }

    console.log(
      `backfillRoomContent complete: scanned ${totalScanned}, patched ${totalPatched}`
    );
    return { done: true, scanned: totalScanned, patched: totalPatched };
  },
});

/**
 * Strip the dead `users.deviceTokens` field.
 *
 * It held raw APNs tokens back when the app managed them itself, before the
 * per-device `userDevices` registry existed. Nothing has read it in a long
 * time, but Convex will not accept a schema that omits a field still present
 * on disk — so removing it is a three-step dance, and this is step two:
 *
 *   1. keep `deviceTokens: v.optional(...)` in the schema, deploy
 *   2. npx convex run migrations:stripDeviceTokens '{}'   ← reaches remaining: 0
 *   3. delete the field from the schema, deploy again
 *
 * Paginated and self-chaining like the backfills above, so it can't blow the
 * per-function read limit and is safe to re-run.
 */
export const stripDeviceTokens = internalMutation({
  args: {
    cursor: v.optional(v.string()),
    scanned: v.optional(v.number()),
    cleared: v.optional(v.number()),
  },
  handler: async (ctx, { cursor, scanned, cleared }) => {
    const page = await ctx.db
      .query("users")
      .paginate({ numItems: 200, cursor: cursor ?? null });

    let totalScanned = scanned ?? 0;
    let totalCleared = cleared ?? 0;
    for (const user of page.page) {
      totalScanned++;
      if ((user as any).deviceTokens === undefined) continue;
      // Patching a field to undefined is how Convex removes it.
      await ctx.db.patch(user._id, { deviceTokens: undefined } as any);
      totalCleared++;
    }

    if (!page.isDone) {
      await ctx.scheduler.runAfter(0, internal.migrations.stripDeviceTokens, {
        cursor: page.continueCursor,
        scanned: totalScanned,
        cleared: totalCleared,
      });
      return { done: false, scanned: totalScanned, cleared: totalCleared };
    }

    console.log(
      `stripDeviceTokens complete: scanned ${totalScanned}, cleared ${totalCleared}`
    );
    return { done: true, scanned: totalScanned, cleared: totalCleared };
  },
});

/**
 * One-off backfill for `roomMembers.seenVisibility` (see the field comment in
 * schema.ts).
 *
 * Every `roomMembers` row created after the `messages:getReadState` bandwidth
 * fix carries this already, stamped from the joining user's current
 * `visibility.seen` at insert time. This walks existing rows and fills it in
 * for memberships written before the field existed, so read receipts don't
 * silently go dark (missing ⇒ "nobody" per `visibility.ts`'s `DEFAULT_LEVEL`)
 * for a member who actually shares them, until they next touch the setting.
 *
 * Only patches rows where the owning user has an explicit, non-default
 * `visibility.seen` — a row left with `seenVisibility` absent resolves through
 * `DEFAULT_LEVEL.seen` exactly the way an absent `users.visibility.seen`
 * already does, so there's nothing to backfill for the common case.
 *
 * Self-chains through the scheduler until the table is exhausted. Kick it off
 * with:
 *
 *     npx convex run migrations:backfillSeenVisibility '{}'
 *
 * and watch the returned/logged counts. Re-running after completion is a
 * no-op.
 */
export const backfillSeenVisibility = internalMutation({
  args: {
    cursor: v.optional(v.string()),
    batchSize: v.optional(v.number()),
    scanned: v.optional(v.number()),
    patched: v.optional(v.number()),
  },
  handler: async (ctx, { cursor, batchSize, scanned, patched }) => {
    const numItems = Math.min(batchSize ?? 200, 500);
    const page = await ctx.db
      .query("roomMembers")
      .paginate({ numItems, cursor: cursor ?? null });

    let totalScanned = scanned ?? 0;
    let totalPatched = patched ?? 0;

    for (const m of page.page) {
      totalScanned++;
      if (m.seenVisibility !== undefined) continue;
      const user = await ctx.db.get(m.userId);
      const seen = user?.visibility?.seen;
      if (seen === undefined) continue;
      await ctx.db.patch(m._id, { seenVisibility: seen });
      totalPatched++;
    }

    if (!page.isDone) {
      await ctx.scheduler.runAfter(0, internal.migrations.backfillSeenVisibility, {
        cursor: page.continueCursor,
        batchSize: numItems,
        scanned: totalScanned,
        patched: totalPatched,
      });
      return { done: false, scanned: totalScanned, patched: totalPatched };
    }

    console.log(
      `backfillSeenVisibility complete: scanned ${totalScanned}, patched ${totalPatched}`
    );
    return { done: true, scanned: totalScanned, patched: totalPatched };
  },
});

/**
 * How many user rows still carry `deviceTokens`. Must read 0 before step 3.
 *
 *     npx convex run migrations:countDeviceTokens '{}'
 */
export const countDeviceTokens = internalMutation({
  args: {
    cursor: v.optional(v.string()),
    total: v.optional(v.number()),
    remaining: v.optional(v.number()),
  },
  handler: async (ctx, { cursor, total, remaining }) => {
    const page = await ctx.db
      .query("users")
      .paginate({ numItems: 500, cursor: cursor ?? null });

    let t = total ?? 0;
    let r = remaining ?? 0;
    for (const user of page.page) {
      t++;
      if ((user as any).deviceTokens !== undefined) r++;
    }

    if (!page.isDone) {
      await ctx.scheduler.runAfter(0, internal.migrations.countDeviceTokens, {
        cursor: page.continueCursor,
        total: t,
        remaining: r,
      });
      return { done: false, total: t, remaining: r };
    }
    console.log(`countDeviceTokens: ${r} of ${t} users still carry the field`);
    return { done: true, total: t, remaining: r };
  },
});
