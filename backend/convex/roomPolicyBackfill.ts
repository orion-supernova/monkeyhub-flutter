import { internalMutation } from "./_generated/server";
import { v } from "convex/values";
import { LOG_ROOM_POSTING_PRESET } from "./roomPolicy";
import { SYSTEM_ROOM_LOGS } from "./systemAccount";

/**
 * ONE-OFF. Delete this file after it has run (deploy, run, delete, redeploy).
 *
 * Stamps `rooms.postingPolicy = "readOnly"` on the `MonkeyHub Logs` room.
 *
 * Belt and braces, not a prerequisite: an unstamped system room already
 * resolves to read-only (`roomPolicy.postingPresetOf`), and
 * `problemReports.repairLogRoom` stamps it on the next report anyway. This makes
 * the row say so now, without waiting for somebody to file a bug.
 *
 * Finds the room by its `system` slug, never by name (any user may name a group
 * "MonkeyHub Logs"). Rooms are few enough on this deployment to page through in
 * one pass; it is still paginated so it cannot hit the read limit, and it
 * reports what it touched. Idempotent: a stamped room is skipped.
 *
 *     npx convex run roomPolicyBackfill:stampLogRoomReadOnly '{}'
 */
export const stampLogRoomReadOnly = internalMutation({
  args: { cursor: v.optional(v.union(v.string(), v.null())) },
  returns: v.object({
    scanned: v.number(),
    stamped: v.array(v.id("rooms")),
    isDone: v.boolean(),
    continueCursor: v.string(),
  }),
  handler: async (ctx, { cursor }) => {
    const page = await ctx.db
      .query("rooms")
      .paginate({ numItems: 500, cursor: cursor ?? null });
    const stamped = [];
    for (const room of page.page) {
      if (room.system !== SYSTEM_ROOM_LOGS) continue;
      if (room.postingPolicy !== undefined) continue;
      await ctx.db.patch(room._id, { postingPolicy: LOG_ROOM_POSTING_PRESET });
      stamped.push(room._id);
    }
    return {
      scanned: page.page.length,
      stamped,
      isDone: page.isDone,
      continueCursor: page.continueCursor,
    };
  },
});
