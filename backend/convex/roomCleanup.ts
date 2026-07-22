/**
 * Room teardown, in one place.
 *
 * Convex has no foreign keys and no cascade deletes, so every row that hangs
 * off a room has to be removed by hand. Getting that list wrong leaves
 * orphaned messages, reactions, or — worst — media files sitting in storage
 * that nothing points at any more. Both the block flow and the guardian
 * "take back" flow need exactly the same teardown, so it lives here rather
 * than being copied.
 *
 * Plain helpers, not Convex functions: callers pass their own `ctx`.
 */

/**
 * Deletes every trace of a room: messages, their reactions, their media in
 * `ctx.storage`, typing rows, memberships, and the room row itself.
 *
 * This is destructive for EVERY member, not just the caller — a wiped DM is
 * gone for both people. Callers must have confirmed that with the user first.
 */
export async function wipeRoomCompletely(ctx: any, roomId: any) {
  // Messages → reactions + media + row
  const msgs = await ctx.db
    .query("messages")
    .withIndex("by_room", (q: any) => q.eq("roomId", roomId))
    .collect();
  for (const msg of msgs) {
    const reactions = await ctx.db
      .query("reactions")
      .withIndex("by_message", (q: any) => q.eq("messageId", msg._id))
      .collect();
    for (const r of reactions) await ctx.db.delete(r._id);
    if (msg.mediaStorageId) {
      try {
        await ctx.storage.delete(msg.mediaStorageId);
      } catch (_) {/* already gone */}
    }
    await ctx.db.delete(msg._id);
  }
  // Memberships
  const members = await ctx.db
    .query("roomMembers")
    .withIndex("by_room", (q: any) => q.eq("roomId", roomId))
    .collect();
  for (const m of members) await ctx.db.delete(m._id);
  // Typing indicators
  const typing = await ctx.db
    .query("typingIndicators")
    .withIndex("by_room", (q: any) => q.eq("roomId", roomId))
    .collect();
  for (const t of typing) await ctx.db.delete(t._id);
  // The room itself
  await ctx.db.delete(roomId);
}

/**
 * Every DM room shared by [a] and [b].
 *
 * Returns a list, not a single room, on purpose: DM rooms are named
 * `dm:<roomKey>:<sortedIdA>:<sortedIdB>` (see `rooms.getOrCreateDM`), so a
 * pair can legitimately hold two at once — a regular one and a Chamber of
 * Secrets one — plus a legacy `dm:<a>:<b>` from before the roomKey existed.
 * We don't know which variants exist, so we walk [a]'s memberships and keep
 * the `dm:`-prefixed rooms [b] is also in.
 */
export async function findDmRoomsBetween(
  ctx: any,
  a: any,
  b: any,
): Promise<any[]> {
  const out: any[] = [];
  const mine = await ctx.db
    .query("roomMembers")
    .withIndex("by_user", (q: any) => q.eq("userId", a))
    .collect();
  for (const m of mine) {
    const room = await ctx.db.get(m.roomId);
    if (!room || !room.name?.startsWith("dm:")) continue;
    const otherMember = await ctx.db
      .query("roomMembers")
      .withIndex("by_room_user", (q: any) =>
        q.eq("roomId", m.roomId).eq("userId", b),
      )
      .first();
    if (!otherMember) continue;
    out.push(m.roomId);
  }
  return out;
}

/**
 * How much is actually in these rooms, so a confirmation can say "128
 * messages, last one on Tuesday" instead of a vague "this cannot be undone".
 */
export async function summariseRooms(
  ctx: any,
  roomIds: any[],
): Promise<{ messageCount: number; lastMessageAt: number | null }> {
  let messageCount = 0;
  let lastMessageAt: number | null = null;
  for (const roomId of roomIds) {
    const msgs = await ctx.db
      .query("messages")
      .withIndex("by_room", (q: any) => q.eq("roomId", roomId))
      .collect();
    messageCount += msgs.length;
    for (const m of msgs) {
      if (lastMessageAt === null || m.createdAt > lastMessageAt) {
        lastMessageAt = m.createdAt;
      }
    }
  }
  return { messageCount, lastMessageAt };
}
