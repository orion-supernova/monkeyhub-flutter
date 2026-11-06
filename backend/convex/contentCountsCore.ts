/**
 * The counting core behind `roomContentCounts`: what one message contributes
 * to its room's tabs, and how a write moves the room's row. A leaf module (it
 * imports no builders) because `dbHooks.ts` needs it and every mutation
 * module needs `dbHooks.ts`. The design notes are in `contentCounts.ts`.
 */

export type ContentCounts = {
  photos: number;
  videos: number;
  files: number;
  voice: number;
  links: number;
};

const KEYS = ["photos", "videos", "files", "voice", "links"] as const;

export const ZERO: ContentCounts = { photos: 0, videos: 0, files: 0, voice: 0, links: 0 };

/** The only fields of a message that decide which tabs it is in. */
export const COUNTED_FIELDS = ["galleryBucket", "type", "hasLink"] as const;

/**
 * What one message adds to its room's tabs. Mirrors exactly what the tab
 * queries in `roomContent.ts` match: the `by_room_bucket_time` and
 * `by_room_link_time` indexes.
 */
export function contribution(msg: any): ContentCounts {
  const c = { ...ZERO };
  if (!msg) return c;
  switch (msg.galleryBucket) {
    case "media":
      // `galleryBucketFor` puts images, videos and video notes here.
      if (msg.type === "image") c.photos = 1;
      else c.videos = 1;
      break;
    case "file":
      c.files = 1;
      break;
    case "voice":
      c.voice = 1;
      break;
  }
  if (msg.hasLink === true) c.links = 1;
  return c;
}

/** Applies the change from [before] to [after] for one room's message. */
export async function applyMessageChange(
  db: any,
  before: any,
  after: any,
): Promise<void> {
  const roomId = after?.roomId ?? before?.roomId;
  if (!roomId) return;
  const a = contribution(before);
  const b = contribution(after);
  const delta = { ...ZERO };
  let moved = false;
  for (const k of KEYS) {
    delta[k] = b[k] - a[k];
    if (delta[k] !== 0) moved = true;
  }
  if (!moved) return;

  const row = await db
    .query("roomContentCounts")
    .withIndex("by_room", (q: any) => q.eq("roomId", roomId))
    .first();
  // A room too large for the backfill to count keeps the bounded answer; a
  // partial row here would show a confidently wrong small number.
  if (row?.tooLarge === true) return;
  if (row === null) {
    // See "Rollout" above: a fresh room starts from zero, and an old room's
    // early row is overwritten by the backfill.
    const start = { ...ZERO };
    for (const k of KEYS) start[k] = Math.max(0, delta[k]);
    await db.insert("roomContentCounts", { roomId, ...start });
    return;
  }
  const next: Partial<ContentCounts> = {};
  for (const k of KEYS) {
    if (delta[k] === 0) continue;
    const value = row[k] + delta[k];
    if (value < 0) {
      // Heals rather than going negative; the backfill can be re-run to
      // recount a room that ever logs this.
      console.warn(`roomContentCounts: ${k} would go below 0 in ${roomId}`);
    }
    next[k] = Math.max(0, value);
  }
  await db.patch(row._id, next);
}

/** The room's counts row, or null when it has not been counted yet. */
export async function countsRow(ctx: any, roomId: any) {
  return await ctx.db
    .query("roomContentCounts")
    .withIndex("by_room", (q: any) => q.eq("roomId", roomId))
    .first();
}

