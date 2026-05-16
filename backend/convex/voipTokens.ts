import { v } from "convex/values";
import { internalMutation, mutation } from "./_generated/server";

// Per-device push token registry. Rows live in `userDevices`, keyed by
// (userId, deviceId), so two devices for the same user keep their own
// tokens instead of overwriting each other. Multi-device fanout in
// `voipPush.sendVoip` reads this table.

export const setVoipToken = mutation({
  args: {
    userId: v.id("users"),
    deviceId: v.string(),
    platform: v.string(), // "ios" | "ios-simulator" | "android"
    token: v.string(),
  },
  handler: async (ctx, { userId, deviceId, platform, token }) => {
    const now = Date.now();
    const existing = await ctx.db
      .query("userDevices")
      .withIndex("by_user_device", (q) =>
        q.eq("userId", userId).eq("deviceId", deviceId),
      )
      .first();
    if (existing) {
      await ctx.db.patch(existing._id, {
        platform,
        voipToken: token,
        lastSeenAt: now,
      });
    } else {
      await ctx.db.insert("userDevices", {
        userId,
        deviceId,
        platform,
        voipToken: token,
        fcmToken: undefined,
        lastSeenAt: now,
        createdAt: now,
      });
    }
    // Token-reassignment defense: if APNs reissued this token under a
    // different (userId, deviceId), strip the old row so we don't double-
    // push to the same handle. APNs guarantees a token is unique to one
    // device-app pair at any moment.
    const dupes = await ctx.db
      .query("userDevices")
      .filter((q) => q.eq(q.field("voipToken"), token))
      .collect();
    for (const d of dupes) {
      if (d.userId.toString() === userId.toString() && d.deviceId === deviceId) {
        continue;
      }
      await ctx.db.patch(d._id, { voipToken: undefined });
    }
  },
});

export const setFcmToken = mutation({
  args: {
    userId: v.id("users"),
    deviceId: v.string(),
    platform: v.string(),
    token: v.string(),
  },
  handler: async (ctx, { userId, deviceId, platform, token }) => {
    const now = Date.now();
    const existing = await ctx.db
      .query("userDevices")
      .withIndex("by_user_device", (q) =>
        q.eq("userId", userId).eq("deviceId", deviceId),
      )
      .first();
    if (existing) {
      await ctx.db.patch(existing._id, {
        platform,
        fcmToken: token,
        lastSeenAt: now,
      });
    } else {
      await ctx.db.insert("userDevices", {
        userId,
        deviceId,
        platform,
        voipToken: undefined,
        fcmToken: token,
        lastSeenAt: now,
        createdAt: now,
      });
    }
  },
});

// Logout from a single device — drop only this device's row.
export const clearDeviceToken = mutation({
  args: { userId: v.id("users"), deviceId: v.string() },
  handler: async (ctx, { userId, deviceId }) => {
    const row = await ctx.db
      .query("userDevices")
      .withIndex("by_user_device", (q) =>
        q.eq("userId", userId).eq("deviceId", deviceId),
      )
      .first();
    if (row) await ctx.db.delete(row._id);
  },
});

// Deprecated: legacy path that nuked every token for a user. Kept as a
// shim so any leftover call site still does the right thing — also sweeps
// the new per-device rows. New code should call `clearDeviceToken`.
export const clearTokens = mutation({
  args: { userId: v.id("users") },
  handler: async (ctx, { userId }) => {
    await ctx.db.patch(userId, { voipToken: undefined, fcmToken: undefined });
    const rows = await ctx.db
      .query("userDevices")
      .withIndex("by_user", (q) => q.eq("userId", userId))
      .collect();
    for (const r of rows) await ctx.db.delete(r._id);
  },
});

// Called by voipPush when APNs reports 410 Unregistered / 400 BadDeviceToken
// for a specific device row. Clears just that device's voipToken — sibling
// devices keep theirs.
export const clearVoipTokenForDeviceInternal = internalMutation({
  args: { deviceRowId: v.id("userDevices") },
  handler: async (ctx, { deviceRowId }) => {
    await ctx.db.patch(deviceRowId, { voipToken: undefined });
  },
});

// FCM equivalent — for completeness even though Android FCM is disabled.
export const clearFcmTokenForDeviceInternal = internalMutation({
  args: { deviceRowId: v.id("userDevices") },
  handler: async (ctx, { deviceRowId }) => {
    await ctx.db.patch(deviceRowId, { fcmToken: undefined });
  },
});

// Fallback for the legacy single-string field on `users`. Only invoked when
// fanout hits a fallback row synthesized from the user record (no userDevices
// rows exist yet). Old behavior is preserved so already-logged-in clients
// don't break before they relog.
export const clearLegacyVoipTokenInternal = internalMutation({
  args: { userId: v.id("users") },
  handler: async (ctx, { userId }) => {
    await ctx.db.patch(userId, { voipToken: undefined });
  },
});

export const clearLegacyFcmTokenInternal = internalMutation({
  args: { userId: v.id("users") },
  handler: async (ctx, { userId }) => {
    await ctx.db.patch(userId, { fcmToken: undefined });
  },
});
