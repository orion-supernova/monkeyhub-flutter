/**
 * Test helper for the dual-mode window (C1): puts a room back into its
 * pre-backfill shape (no sequence, memberships on their `roomMembers` rows
 * alone), so a test can exercise the legacy paths that stay live until the
 * backfill marker is set. Not a test file, so it must not import vitest.
 */
export async function makeLegacyRoom(
  t: { run: (fn: (ctx: any) => Promise<void>) => Promise<unknown> },
  roomId: any,
): Promise<void> {
  await t.run(async (ctx: any) => {
    const receipts = await ctx.db
      .query("roomReceipts")
      .withIndex("by_room_user", (q: any) => q.eq("roomId", roomId))
      .collect();
    for (const r of receipts) {
      const m = await ctx.db
        .query("roomMembers")
        .withIndex("by_room_user", (q: any) => q.eq("roomId", roomId).eq("userId", r.userId))
        .first();
      if (m && r.seenVisibility !== undefined) {
        await ctx.db.patch(m._id, { seenVisibility: r.seenVisibility });
      }
      await ctx.db.delete(r._id);
    }
    const states = await ctx.db
      .query("roomUserState")
      .withIndex("by_room_user", (q: any) => q.eq("roomId", roomId))
      .collect();
    for (const s of states) await ctx.db.delete(s._id);
    await ctx.db.patch(roomId, { lastSeq: undefined });
  });
}
