import { UNREAD_CAP, unreadForRoom } from "./badges";
import { GAP_HORIZON_MS } from "./roomState";

/**
 * Exact unread for one member of one room, without scanning messages
 * (docs/backend/c1-cursors-design.md, "Unread").
 *
 *     unread = room.lastSeq - state.readSeq
 *              - gaps in (readSeq, lastSeq]       (deleted messages)
 *              - own messages in that range that are not gaps
 *
 * Reads: the `roomUserState` row and the room doc the caller already holds,
 * plus (only while something is unread) the `messageGaps` rows above the read
 * position and one `mentionInbox` probe. A room read to the end costs nothing
 * more than those two docs.
 *
 * Falls back to the capped message scan (the old `unreadForRoom`) when the
 * arithmetic cannot be exact: own messages overflowed the 8-run budget, the
 * cursor is older than the gap horizon (deletes of older messages log no gap),
 * or 100 or more gaps sit above the cursor (the gap read is capped).
 */

/** Gap rows read before the arithmetic gives up and scans. */
const GAP_READ_CAP = 100;

export type Unread = { count: number; capped: boolean; hasMention: boolean };

const NONE: Unread = { count: 0, capped: false, hasMention: false };

export async function roomUnread(
  ctx: any,
  room: any,
  state: any,
  now: number = Date.now(),
): Promise<Unread> {
  const lastSeq: number = room.lastSeq ?? 0;
  const readSeq: number = state.readSeq ?? 0;
  const R = lastSeq - readSeq;
  if (R <= 0) return NONE;

  const cursor: number = state.readAt ?? room.createdAt ?? 0;
  if (state.ownOverflow === true || cursor < now - GAP_HORIZON_MS) {
    return await scan(ctx, room, state);
  }

  const gaps: { seq: number }[] = await ctx.db
    .query("messageGaps")
    .withIndex("by_room_seq", (q: any) =>
      q.eq("roomId", room._id).gt("seq", readSeq).lte("seq", lastSeq),
    )
    .take(GAP_READ_CAP);
  if (gaps.length >= GAP_READ_CAP) return await scan(ctx, room, state);

  // Own messages above the cursor, minus the ones that were since deleted
  // (those are already counted as gaps).
  let own = 0;
  for (const run of state.ownRuns ?? []) {
    const from = Math.max(run.from, readSeq + 1);
    const to = Math.min(run.to, lastSeq);
    if (to >= from) own += to - from + 1;
  }
  if (own > 0) {
    for (const g of gaps) {
      for (const run of state.ownRuns ?? []) {
        if (g.seq >= run.from && g.seq <= run.to) {
          own--;
          break;
        }
      }
    }
  }
  const raw = R - gaps.length - own;
  const count = Math.max(0, Math.min(raw, UNREAD_CAP));
  const capped = raw > UNREAD_CAP;
  if (count === 0) return NONE;

  const mention = await ctx.db
    .query("mentionInbox")
    .withIndex("by_user_room", (q: any) =>
      q
        .eq("userId", state.userId)
        .eq("roomId", room._id)
        .gt("createdAt", state.readAt ?? 0),
    )
    .first();
  return { count, capped, hasMention: mention !== null };
}

async function scan(ctx: any, room: any, state: any): Promise<Unread> {
  const r = await unreadForRoom(
    ctx,
    room._id,
    state.userId,
    state.readAt,
    room.lastMessageTime,
  );
  return { count: r.count, capped: r.capped, hasMention: r.hasMention };
}
