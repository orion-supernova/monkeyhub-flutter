import { v } from "convex/values";
import { internalMutation, mutation } from "./_generated/server";

// Persists the device's PushKit (iOS) VoIP token. Called by PushManager
// once iOS hands the token to Dart via the `monkeyhub/voip` method channel.
// One token per user → device pair; the latest call wins. Tokens rotate, so
// re-uploads are normal and expected.
export const setVoipToken = mutation({
  args: { userId: v.id("users"), token: v.string() },
  handler: async (ctx, { userId, token }) => {
    await ctx.db.patch(userId, { voipToken: token });
  },
});

// Persists the device's FCM (Android) token. Used by `calls.initiateCall` to
// send a data-only high-priority push that wakes the callee for the native
// ConnectionService ringer.
export const setFcmToken = mutation({
  args: { userId: v.id("users"), token: v.string() },
  handler: async (ctx, { userId, token }) => {
    await ctx.db.patch(userId, { fcmToken: token });
  },
});

// Called when the user logs out or revokes the token on the device side, so
// the server stops trying to push to a dead handle.
export const clearTokens = mutation({
  args: { userId: v.id("users") },
  handler: async (ctx, { userId }) => {
    await ctx.db.patch(userId, { voipToken: undefined, fcmToken: undefined });
  },
});

// Server-side cleanup for dead VoIP tokens. Invoked by `voipPush.sendVoip`
// when APNs returns 410 Unregistered or 400 BadDeviceToken — clearing the
// field stops us from spamming Apple with a token they've revoked, and
// the next app launch will re-register a fresh one via PushManager.login.
export const clearVoipTokenInternal = internalMutation({
  args: { userId: v.id("users") },
  handler: async (ctx, { userId }) => {
    await ctx.db.patch(userId, { voipToken: undefined });
  },
});

// Same idea for Android: clear a dead FCM token when FCM tells us it's
// no longer registered.
export const clearFcmTokenInternal = internalMutation({
  args: { userId: v.id("users") },
  handler: async (ctx, { userId }) => {
    await ctx.db.patch(userId, { fcmToken: undefined });
  },
});
