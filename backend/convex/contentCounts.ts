import { v } from "convex/values";
import { internal } from "./_generated/api";
import { internalMutation } from "./dbHooks";
import { ZERO, contribution, countsRow, type ContentCounts } from "./contentCountsCore";

/**
 * Exact totals for a room's shared-content tabs: photos, videos, files, voice
 * messages and links.
 *
 * `roomContent:counts` used to scan each tab's index up to 100 rows on every
 * room-info open (as many as 400 message reads) and still answered only "99+".
 * Now it reads one row of `roomContentCounts`.
 *
 * ## How the row stays true
 *
 * A message's place in the tabs is a pure function of three of its fields:
 * `galleryBucket`, `type` and `hasLink` (see [contribution]). The write hook in
 * `dbHooks.ts` sees EVERY insert, patch, replace and delete of a `messages` row
 * from every mutation in the backend, works out how that write moved the
 * row's contribution, and applies the difference here. There is no list of
 * call sites to keep in step: a new send path, sweep or deletion cascade is
 * counted because it cannot write a message any other way.
 * `dbHooks.test.ts` fails the build if a file bypasses the hook.
 *
 * ## Cost
 *
 *  - A text message, a reaction, a read receipt or any patch that leaves the
 *    three fields alone: nothing. The hook returns before reading anything.
 *  - A photo, video, file, voice message or link: one indexed read and one
 *    write of this room's row, in the transaction that wrote the message. The
 *    send already writes the `rooms` row, so the room's sends are already
 *    serialised and this adds no new contention.
 *  - Opening room info: one indexed read, down from up to 400.
 *
 * ## Rollout without a stop-the-world migration
 *
 * A MISSING row means "not counted yet", as in `roomCounts.ts`:
 *
 *  - [backfill] recounts every room once and writes the absolute totals. It
 *    is the only full scan, it runs once, and it can be re-run freely.
 *  - Before it reaches a room, the hook may already have started a row from
 *    that room's newest messages. The backfill's absolute write corrects it.
 *  - After the backfill, every room that existed has a row, so a missing row
 *    can only be a room born after it, which had nothing in it: the hook
 *    starts that room's row from zero, which is right.
 *  - `roomContent:counts` falls back to the old bounded scan for a room with
 *    no row. After the backfill that is only rooms with nothing shared, whose
 *    index ranges are empty, so the fallback reads nothing.
 */

/**
 * Most rows one tab may hold for the backfill to count its room in a single
 * transaction: four tabs at this size stay well inside Convex's per-mutation
 * read limits. A room with more is marked `tooLarge`, logged, and keeps the
 * old bounded "99+" answer. No tester room is near this.
 */
const BACKFILL_TAB_LIMIT = 2000;

/**
 * Counts every room's shared content and writes the absolute totals. The one
 * full scan in this design, run once after deploy:
 *
 *     npx convex run contentCounts:backfill '{}'
 *
 * Self-scheduling, a few rooms per transaction, and idempotent: a re-run
 * recounts and overwrites, so it may be started again at any time.
 */
export const backfill = internalMutation({
  args: { cursor: v.optional(v.union(v.string(), v.null())) },
  returns: v.null(),
  handler: async (ctx, { cursor }) => {
    // One room per transaction: a busy room's four tabs are the whole budget.
    const page = await ctx.db
      .query("rooms")
      .paginate({ cursor: cursor ?? null, numItems: 1 });
    for (const room of page.page) {
      const totals = await countRoom(ctx, room._id);
      const row = await countsRow(ctx, room._id);
      if (totals === null) {
        console.warn(`contentCounts.backfill: ${room._id} too large to count`);
        const marker = { ...ZERO, tooLarge: true };
        if (row) await ctx.db.patch(row._id, marker);
        else await ctx.db.insert("roomContentCounts", { roomId: room._id, ...marker });
        continue;
      }
      const fields = { ...totals, tooLarge: undefined };
      if (row) await ctx.db.patch(row._id, fields);
      else await ctx.db.insert("roomContentCounts", { roomId: room._id, ...totals });
    }
    if (!page.isDone) {
      await ctx.scheduler.runAfter(0, internal.contentCounts.backfill, {
        cursor: page.continueCursor,
      });
    } else {
      console.log("contentCounts.backfill: done");
    }
    return null;
  },
});

/** Exact totals from the tab indexes, or null when a tab is too big to count. */
async function countRoom(ctx: any, roomId: any): Promise<ContentCounts | null> {
  const totals = { ...ZERO };
  for (const bucket of ["media", "file", "voice"]) {
    const rows = await ctx.db
      .query("messages")
      .withIndex("by_room_bucket_time", (q: any) =>
        q.eq("roomId", roomId).eq("galleryBucket", bucket)
      )
      .take(BACKFILL_TAB_LIMIT + 1);
    if (rows.length > BACKFILL_TAB_LIMIT) return null;
    for (const m of rows) {
      const c = contribution(m);
      totals.photos += c.photos;
      totals.videos += c.videos;
      totals.files += c.files;
      totals.voice += c.voice;
    }
  }
  const links = await ctx.db
    .query("messages")
    .withIndex("by_room_link_time", (q: any) =>
      q.eq("roomId", roomId).eq("hasLink", true)
    )
    .take(BACKFILL_TAB_LIMIT + 1);
  if (links.length > BACKFILL_TAB_LIMIT) return null;
  totals.links = links.length;
  return totals;
}
