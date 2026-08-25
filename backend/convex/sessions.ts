import { v } from "convex/values";
import { mutation, query } from "./functions";

/**
 * The session table's own public surface.
 *
 * Authenticated like everything else — revoking a session is an account
 * action, so it needs one. `userId` here is injected by the wrapper, never
 * taken from the caller; see `functions.ts`.
 */
/** Revoke one device's session. The half of "remove device" that will make it
 *  a real sign-out once enforcement lands. */
export const revokeForDevice = mutation({
  args: { userId: v.id("users"), deviceId: v.string() },
  returns: v.object({ revoked: v.number() }),
  handler: async (ctx, { userId, deviceId }) => {
    const now = Date.now();
    const rows = await ctx.db
      .query("sessions")
      .withIndex("by_user_device", (q) =>
        q.eq("userId", userId).eq("deviceId", deviceId),
      )
      .collect();
    let revoked = 0;
    for (const row of rows) {
      if (row.revokedAt !== undefined) continue;
      await ctx.db.patch(row._id, { revokedAt: now });
      revoked++;
    }
    return { revoked };
  },
});

/** Revoke every session except the caller's own device. */
export const revokeOthers = mutation({
  args: { userId: v.id("users"), deviceId: v.string() },
  returns: v.object({ revoked: v.number() }),
  handler: async (ctx, { userId, deviceId }) => {
    const now = Date.now();
    const rows = await ctx.db
      .query("sessions")
      .withIndex("by_user", (q) => q.eq("userId", userId))
      .collect();
    let revoked = 0;
    for (const row of rows) {
      if (row.deviceId === deviceId || row.revokedAt !== undefined) continue;
      await ctx.db.patch(row._id, { revokedAt: now });
      revoked++;
    }
    return { revoked };
  },
});

/** Live sessions for a user, for the Devices screen to merge with its rows. */
export const listSessions = query({
  args: { userId: v.id("users") },
  returns: v.array(
    v.object({
      deviceId: v.string(),
      createdAt: v.number(),
      lastSeenAt: v.number(),
    }),
  ),
  handler: async (ctx, { userId }) => {
    const rows = await ctx.db
      .query("sessions")
      .withIndex("by_user", (q) => q.eq("userId", userId))
      .collect();
    return rows
      .filter((r) => r.revokedAt === undefined)
      .map((r) => ({
        deviceId: r.deviceId,
        createdAt: r.createdAt,
        lastSeenAt: r.lastSeenAt,
      }));
  },
});
