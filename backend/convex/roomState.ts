/**
 * Per-member room state after C1 (docs/backend/c1-cursors-design.md).
 *
 * A membership used to be ONE `roomMembers` row carrying the roster fact AND
 * every per-member cursor, so every read, delivery, pin and mute write
 * re-ran every query that listed the roster. It is now three rows:
 *
 *  - `roomMembers`    roster + role,
 *  - `roomUserState`  private: read position, pin/archive/mute (chat list,
 *                     badges, push, send),
 *  - `roomReceipts`   public: delivered / read cursors, vanish cursor
 *                     (read-state, seen-by, vanish).
 *
 * Every membership has both rows and no reader falls back to `roomMembers`.
 */

/** Deleted messages older than this log no gap row; stale cursors scan instead. */
export const GAP_HORIZON_MS = 180 * 24 * 60 * 60 * 1000;

/** Own-message runs kept on a state row before `ownOverflow` is raised. */
export const MAX_OWN_RUNS = 8;

export async function stateOf(ctx: any, roomId: any, userId: any) {
  return await ctx.db
    .query("roomUserState")
    .withIndex("by_room_user", (q: any) =>
      q.eq("roomId", roomId).eq("userId", userId),
    )
    .first();
}

export async function receiptOf(ctx: any, roomId: any, userId: any) {
  return await ctx.db
    .query("roomReceipts")
    .withIndex("by_room_user", (q: any) =>
      q.eq("roomId", roomId).eq("userId", userId),
    )
    .first();
}

/**
 * The other member of a DM, from its room name: `dm:regular:<a>:<b>`,
 * `dm:secret:<a>:<b>`, legacy `dm:<a>:<b>`. `dm:self:<id>` and anything that
 * is not a DM have none. Ids are checked with `normalizeId`, never trusted.
 */
export function dmPeerFor(db: any, roomName: string | undefined, userId: any): any | undefined {
  if (!roomName || !roomName.startsWith("dm:")) return undefined;
  const parts = roomName.split(":");
  let ids: string[];
  if (parts[1] === "self") return undefined;
  if (parts[1] === "regular" || parts[1] === "secret") ids = parts.slice(2, 4);
  else ids = parts.slice(1, 3);
  const me = userId.toString();
  for (const raw of ids) {
    if (!raw || raw === me) continue;
    const id = db.normalizeId("users", raw);
    if (id !== null) return id;
  }
  return undefined;
}

/** The per-viewer fields a caller may hand `addMembership` as `extra`. */
const STATE_EXTRA = new Set([
  "isPinned",
  "pinnedAt",
  "isArchived",
  "archivedAt",
  "muteNotifications",
  "muteBadges",
  "mutedUntil",
  "vanishShareReads",
]);

/**
 * Give a new membership its two rows, in the caller's transaction. Per-viewer
 * `extra` fields (pin, mute...) land on the state row, never on `roomMembers`.
 *
 * A new member starts at `readSeq` 0 with no `readAt`: the whole backlog counts
 * as unread, exactly as a membership with no `lastReadAt` always did.
 */
export async function insertMemberRows(
  ctx: any,
  room: any,
  userId: any,
  joinedAt: number,
  seenVisibility: string | undefined,
  extra: Record<string, any> = {},
): Promise<void> {
  if (!room) return;
  const state: Record<string, any> = {
    roomId: room._id,
    userId,
    readSeq: 0,
    archived: extra.isArchived === true,
  };
  // Joining a room that already has messages: some may be this member's own
  // (a rejoin, or a DM re-added), which `readSeq` can't tell apart. The
  // overflow flag sends unread through the exact capped scan, which excludes
  // own messages as the old code did, until the member first reads the room.
  if ((room.lastSeq ?? 0) > 0) state.ownOverflow = true;
  for (const [k, v] of Object.entries(extra)) {
    if (!STATE_EXTRA.has(k) || v === undefined || k === "isArchived") continue;
    state[k] = v;
  }
  const peer = dmPeerFor(ctx.db, room.name, userId);
  if (peer !== undefined) state.dmPeerId = peer;
  await ctx.db.insert("roomUserState", state);
  await ctx.db.insert("roomReceipts", {
    roomId: room._id,
    userId,
    vanishSeenAt: joinedAt,
    ...(seenVisibility !== undefined ? { seenVisibility } : {}),
  });
}

/**
 * Remove a member's state, receipts and receipt moves for one room. Safe when
 * a row is absent (a legacy membership). Used by leave / kick / account
 * deletion so a rejoin starts clean.
 */
export async function deleteMemberRows(ctx: any, roomId: any, userId: any): Promise<void> {
  const state = await stateOf(ctx, roomId, userId);
  if (state) await ctx.db.delete(state._id);
  const receipt = await receiptOf(ctx, roomId, userId);
  if (receipt) await ctx.db.delete(receipt._id);
  for (const kind of ["read", "delivered"]) {
    const moves = await ctx.db
      .query("receiptMoves")
      .withIndex("by_room_user_kind_at", (q: any) =>
        q.eq("roomId", roomId).eq("userId", userId).eq("kind", kind),
      )
      .take(260);
    for (const m of moves) await ctx.db.delete(m._id);
  }
}

/**
 * Mute columns for every member of a room, merged onto the `roomMembers` rows
 * the caller already holds. Reads every state row: when the caller has no
 * roster of its own, use [muteRoster].
 */
export async function withMuteState(ctx: any, roomId: any, rows: any[]): Promise<any[]> {
  const states = await ctx.db
    .query("roomUserState")
    .withIndex("by_room_user", (q: any) => q.eq("roomId", roomId))
    .collect();
  if (states.length === 0) return rows;
  const byUser = new Map<string, any>(states.map((s: any) => [s.userId.toString(), s]));
  return rows.map((m: any) => {
    const s = byUser.get(m.userId.toString());
    return s ? { ...m, ...pickMute(s) } : m;
  });
}

/**
 * The room's roster with mute columns, from `roomUserState` alone (it carries
 * `userId`, and every membership has exactly one): N reads instead of the
 * 2N of `roomMembers` + [withMuteState]. For fan-outs that need nothing but
 * who is in the room and whether they muted it.
 */
export async function muteRoster(ctx: any, roomId: any): Promise<any[]> {
  const states = await ctx.db
    .query("roomUserState")
    .withIndex("by_room_user", (q: any) => q.eq("roomId", roomId))
    .collect();
  return states.map((s: any) => ({ userId: s.userId, ...pickMute(s) }));
}

function pickMute(s: any) {
  return {
    muteNotifications: s.muteNotifications,
    muteBadges: s.muteBadges,
    mutedUntil: s.mutedUntil,
  };
}

/**
 * The room's members as the public-cursor readers (`getReadState`,
 * `getReceiptTimes`) see them: `roomReceipts` rows shaped like the old
 * membership row. This never touches `roomMembers`, so a join or leave is the
 * only roster change that re-runs it.
 */
export async function receiptRoster(ctx: any, roomId: any): Promise<any[]> {
  const receipts = await ctx.db
    .query("roomReceipts")
    .withIndex("by_room_user", (q: any) => q.eq("roomId", roomId))
    .collect();
  return receipts.map((r: any) => ({
    _id: r._id,
    roomId: r.roomId,
    userId: r.userId,
    lastReadAt: r.lastReadAt,
    lastDeliveredAt: r.lastDeliveredAt,
    lastReadClock: r.readClock,
    lastDeliveredClock: r.deliveredClock,
    seenVisibility: r.seenVisibility,
  }));
}
