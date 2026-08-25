import { query } from "./functions";
import { v } from "convex/values";

/**
 * The room's shared-content browser: everything a room has ever sent, split
 * into MEDIA / FILES / LINKS and paged newest-first.
 *
 * ── Why these check membership when `pins:listForRoom` deliberately doesn't ──
 *
 * The rule `pins.ts` documents is about *subscribed* queries: reading
 * `roomMembers` from one makes it refire on every `markRoomRead` patch, which
 * is the cascade `messages:getThreadPage` describes. Nothing here is
 * subscribed. These are one-shot pages fetched when a screen opens and when it
 * scrolls, exactly like `messages:listBefore`, so a membership read costs one
 * document once and refires nothing.
 *
 * The check also matters more here than it would there. A pin list is a strict
 * subset of what `messages:list` already hands out for the same room id; this
 * reaches messages nobody has loaded and nobody will scroll back to, which is
 * a materially different thing to leave keyed on a room id alone.
 *
 * ── Pagination ──
 *
 * Timestamp cursors over `createdAt`, matching `messages:listBefore` rather
 * than Convex's `.paginate()`, because that is what every other paged read in
 * this deployment does and because the client already knows how to drive it.
 * `hasMore` comes from asking for one row past the limit, so "is there another
 * page" is answered without a second query and without a count.
 */

/** Rows per page. Matches `messages:listBefore`'s default. */
const DEFAULT_LIMIT = 30;

/** Ceiling on a client-supplied limit, so one call can't read a transcript. */
const MAX_LIMIT = 60;

/**
 * How far the tab counters will look before giving up and saying "lots".
 *
 * A true count means reading every matching row, which for an old room is the
 * whole gallery on every room-info open. The badge is decoration — it tells
 * you whether a tab is worth opening, and "99+" answers that as well as "412"
 * does.
 */
const COUNT_CAP = 99;

/** The buckets `messages.galleryBucket` can hold. */
const BUCKETS = ["media", "file", "voice"] as const;

async function assertMember(ctx: any, roomId: any, userId: any) {
  const membership = await ctx.db
    .query("roomMembers")
    .withIndex("by_room_user", (q: any) =>
      q.eq("roomId", roomId).eq("userId", userId)
    )
    .first();
  if (!membership) throw new Error("NOT_A_MEMBER");
}

/**
 * One page of a room's attachments, newest first.
 *
 * No `sanitizeViewOnce` here, and that is not an oversight: an armed message is
 * never given a `galleryBucket` (see `galleryBucketFor`), so a view-once photo
 * is not filtered out of this scan — it is outside the index range the scan
 * covers. Sanitizing would be a second answer to a question already answered,
 * and would cost a `viewOnceViews` lookup per row to do it.
 */
export const listBucket = query({
  args: {
    roomId: v.id("rooms"),
    userId: v.id("users"),
    // "media" | "file" | "voice".
    bucket: v.string(),
    // Exclusive upper bound — the `createdAt` of the oldest row the client
    // already holds. Absent for the first page.
    beforeTimestamp: v.optional(v.number()),
    limit: v.optional(v.number()),
  },
  handler: async (ctx, { roomId, userId, bucket, beforeTimestamp, limit }) => {
    await assertMember(ctx, roomId, userId);
    if (!(BUCKETS as readonly string[]).includes(bucket)) {
      throw new Error("UNKNOWN_BUCKET");
    }

    const take = Math.min(limit ?? DEFAULT_LIMIT, MAX_LIMIT);
    const rows = await ctx.db
      .query("messages")
      .withIndex("by_room_bucket_time", (q: any) => {
        const scoped = q.eq("roomId", roomId).eq("galleryBucket", bucket);
        return beforeTimestamp === undefined
          ? scoped
          : scoped.lt("createdAt", beforeTimestamp);
      })
      .order("desc")
      // One more than asked for: coming back with it is how we learn there is
      // another page, without a count and without a second round trip.
      .take(take + 1);

    const hasMore = rows.length > take;
    return { items: rows.slice(0, take), hasMore };
  },
});

/**
 * One page of the messages in a room that contain a URL, newest first.
 *
 * Returns whole messages rather than extracted links. `hasLink` is only ever a
 * yes/no — the URLs themselves are deliberately not stored (see the schema) —
 * so the client re-derives them from `content` with the same `UrlDetector` the
 * bubbles linkify with. That also means one message can produce several rows on
 * screen, and the client is what decides that.
 *
 * `formatting` link entities ride along the same way: the row already carries
 * the spans, `hasLink` is set for them at send/edit time, and the client's
 * links tab reads `formatting` off the returned document — nothing extra to
 * return here.
 */
export const listLinks = query({
  args: {
    roomId: v.id("rooms"),
    userId: v.id("users"),
    beforeTimestamp: v.optional(v.number()),
    limit: v.optional(v.number()),
  },
  handler: async (ctx, { roomId, userId, beforeTimestamp, limit }) => {
    await assertMember(ctx, roomId, userId);

    const take = Math.min(limit ?? DEFAULT_LIMIT, MAX_LIMIT);
    const rows = await ctx.db
      .query("messages")
      .withIndex("by_room_link_time", (q: any) => {
        const scoped = q.eq("roomId", roomId).eq("hasLink", true);
        return beforeTimestamp === undefined
          ? scoped
          : scoped.lt("createdAt", beforeTimestamp);
      })
      .order("desc")
      .take(take + 1);

    const hasMore = rows.length > take;
    return { items: rows.slice(0, take), hasMore };
  },
});

/**
 * How much is in each tab, capped at [COUNT_CAP].
 *
 * Separate from the pages on purpose: room info wants all four numbers at once
 * to decide which tabs to offer, while the browser wants one tab's rows. Fusing
 * them would make opening room info read four pages of documents it will never
 * render.
 *
 * `capped` says the number is a floor rather than a total, so the client can
 * render "99+" without hardcoding the same constant.
 */
export const counts = query({
  args: {
    roomId: v.id("rooms"),
    userId: v.id("users"),
  },
  handler: async (ctx, { roomId, userId }) => {
    await assertMember(ctx, roomId, userId);

    const out: Record<string, { count: number; capped: boolean }> = {};

    for (const bucket of BUCKETS) {
      const rows = await ctx.db
        .query("messages")
        .withIndex("by_room_bucket_time", (q: any) =>
          q.eq("roomId", roomId).eq("galleryBucket", bucket)
        )
        .take(COUNT_CAP + 1);
      out[bucket] = {
        count: Math.min(rows.length, COUNT_CAP),
        capped: rows.length > COUNT_CAP,
      };
    }

    const linkRows = await ctx.db
      .query("messages")
      .withIndex("by_room_link_time", (q: any) =>
        q.eq("roomId", roomId).eq("hasLink", true)
      )
      .take(COUNT_CAP + 1);
    out.link = {
      count: Math.min(linkRows.length, COUNT_CAP),
      capped: linkRows.length > COUNT_CAP,
    };

    return out;
  },
});
