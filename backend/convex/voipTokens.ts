import { v } from "convex/values";
import { internalMutation } from "./_generated/server";
import { mutation, query } from "./functions";
import { revokeSessionsForDevice, revokeOtherSessions } from "./sessionCore";
import type { Doc, Id } from "./_generated/dataModel";

// Per-device push registry. Rows live in `userDevices`, keyed by
// (userId, deviceId), so two devices for the same user keep their own
// credentials instead of overwriting each other.
//
// A device can hold up to four independent push credentials, and they are NOT
// interchangeable:
//   voipToken   iOS PushKit, topic `<bundle>.voip`  → voipPush.ts (ringing)
//   apnsToken   iOS alert/background, topic `<bundle>` → push.ts (banners)
//   fcmToken    Android FCM v1                       → both
//   web*        Web Push subscription (RFC 8030)     → push.ts
//
// The file name is historical: it registered only VoIP tokens once.

type DevicePatch = Partial<
  Pick<
    Doc<"userDevices">,
    | "voipToken"
    | "apnsToken"
    | "apnsEnv"
    | "fcmToken"
    | "webEndpoint"
    | "webP256dh"
    | "webAuth"
    | "pushEnabled"
    | "gameRemindersEnabled"
    | "locale"
    | "tzOffsetMinutes"
  >
>;

/**
 * The language and time zone a caller may stamp alongside whatever else it is
 * writing. See [deviceContextPatch].
 */
type DeviceContextArgs = {
  locale?: string;
  tzOffsetMinutes?: number;
};

/**
 * Convex validators for [DeviceContextArgs], spread into the token setters.
 */
const vDeviceContext = {
  /** BCP-47-ish, as Flutter resolved it: "en", "tr", "pt-BR". */
  locale: v.optional(v.string()),
  /** Minutes ahead of UTC: +180 Istanbul, -480 California. */
  tzOffsetMinutes: v.optional(v.number()),
};

/**
 * [DeviceContextArgs] as a patch — only what was actually passed, so a caller
 * that knows one of the two never clears the other.
 *
 * Every path that writes a push credential carries these now, which is a
 * deliberate belt-and-braces on top of [setDeviceContext] rather than a
 * replacement for it. `setDeviceContext` remains the entry point that *tracks*
 * the two values and re-sends them when either moves; what this adds is an
 * invariant the daily nudge could not otherwise rely on — **a row that holds a
 * push token has a time zone**. Without it, a login whose context call failed
 * or never ran (a hang in the notification prompt, a socket that dropped
 * between the two mutations, an app build older than the feature) leaves a row
 * that is perfectly pushable and permanently invisible to `dailyNudge`, which
 * addresses its audience through `by_tz_offset` and cannot see a row that is
 * missing the field. That was five of eleven live phones the day the nudge
 * shipped.
 */
function deviceContextPatch(args: DeviceContextArgs): DevicePatch {
  const patch: DevicePatch = {};
  if (args.locale !== undefined) patch.locale = args.locale;
  if (args.tzOffsetMinutes !== undefined) {
    patch.tzOffsetMinutes = snapOffset(args.tzOffsetMinutes);
  }
  return patch;
}

/**
 * A reported UTC offset, snapped to the quarter hour the audience query probes
 * on.
 *
 * Every real zone already is one (Kathmandu +345, Chatham +765); a device whose
 * clock reports something else is broken, and rounding it is the difference
 * between that device being nudged an odd number of minutes late and never
 * being nudged at all.
 */
function snapOffset(minutes: number): number {
  return Math.round(minutes / 15) * 15;
}

/**
 * Find-or-create this user's row for [deviceId] and apply [patch].
 *
 * Every registration entry point funnels through here so that "which fields
 * does a brand-new row start with" has exactly one answer. `lastSeenAt` is
 * refreshed on every call — it is what the migration coverage view and any
 * future stale-device sweep range over.
 */
async function upsertDevice(
  ctx: any,
  userId: Id<"users">,
  deviceId: string,
  platform: string,
  deviceName: string | undefined,
  patch: DevicePatch,
): Promise<void> {
  const now = Date.now();
  const existing = await ctx.db
    .query("userDevices")
    .withIndex("by_user_device", (q: any) =>
      q.eq("userId", userId).eq("deviceId", deviceId),
    )
    .first();
  if (existing) {
    await ctx.db.patch(existing._id, {
      platform,
      deviceName: deviceName ?? existing.deviceName,
      lastSeenAt: now,
      ...patch,
    });
    return;
  }
  await ctx.db.insert("userDevices", {
    userId,
    deviceId,
    platform,
    deviceName: deviceName ?? undefined,
    lastSeenAt: now,
    createdAt: now,
    ...patch,
  });
}

/**
 * Strip a credential from every row that is not (userId, deviceId).
 *
 * A push credential belongs to exactly one device-app pair at any moment, so
 * finding it under a second row means it was reassigned — reinstall, restore
 * from backup, or a second account on a shared browser. Leaving the stale row
 * intact double-pushes to one handle, and on the web it would deliver one
 * account's notifications to another's session.
 *
 * [rows] comes from the caller's indexed lookup so the scan stays bounded;
 * this used to be a `.filter()` over the whole table on every login.
 */
async function claimExclusively(
  ctx: any,
  rows: Array<Doc<"userDevices">>,
  userId: Id<"users">,
  deviceId: string,
  clear: DevicePatch,
): Promise<void> {
  for (const d of rows) {
    if (d.userId.toString() === userId.toString() && d.deviceId === deviceId) {
      continue;
    }
    await ctx.db.patch(d._id, clear);
  }
}

export const setVoipToken = mutation({
  args: {
    userId: v.id("users"),
    deviceId: v.string(),
    platform: v.string(), // "ios" | "ios-simulator" | "android" | "macos" | …
    token: v.string(),
    deviceName: v.optional(v.string()),
    // "sandbox" for debug/dev builds, "production" for TestFlight/App Store.
    // Lets the backend pick the matching APNs host per token.
    apnsEnv: v.optional(v.union(v.literal("sandbox"), v.literal("production"))),
    ...vDeviceContext,
  },
  handler: async (
    ctx,
    { userId, deviceId, platform, token, deviceName, apnsEnv, ...context },
  ) => {
    await upsertDevice(ctx, userId, deviceId, platform, deviceName, {
      voipToken: token,
      ...(apnsEnv ? { apnsEnv } : {}),
      ...deviceContextPatch(context),
    });
    const dupes = await ctx.db
      .query("userDevices")
      .withIndex("by_voip_token", (q) => q.eq("voipToken", token))
      .collect();
    await claimExclusively(ctx, dupes, userId, deviceId, {
      voipToken: undefined,
    });
  },
});

/**
 * The regular APNs alert token — the one every banner, badge and silent
 * dismiss goes to. Separate from [setVoipToken] because they are separate
 * tokens on separate topics; a device registers both, independently, and
 * either can be revoked without the other.
 */
export const setApnsToken = mutation({
  args: {
    userId: v.id("users"),
    deviceId: v.string(),
    platform: v.string(),
    token: v.string(),
    deviceName: v.optional(v.string()),
    apnsEnv: v.optional(v.union(v.literal("sandbox"), v.literal("production"))),
    ...vDeviceContext,
  },
  handler: async (
    ctx,
    { userId, deviceId, platform, token, deviceName, apnsEnv, ...context },
  ) => {
    await upsertDevice(ctx, userId, deviceId, platform, deviceName, {
      apnsToken: token,
      ...(apnsEnv ? { apnsEnv } : {}),
      ...deviceContextPatch(context),
    });
    const dupes = await ctx.db
      .query("userDevices")
      .withIndex("by_apns_token", (q) => q.eq("apnsToken", token))
      .collect();
    await claimExclusively(ctx, dupes, userId, deviceId, {
      apnsToken: undefined,
    });
  },
});

export const setFcmToken = mutation({
  args: {
    userId: v.id("users"),
    deviceId: v.string(),
    platform: v.string(),
    token: v.string(),
    deviceName: v.optional(v.string()),
    ...vDeviceContext,
  },
  handler: async (
    ctx,
    { userId, deviceId, platform, token, deviceName, ...context },
  ) => {
    await upsertDevice(ctx, userId, deviceId, platform, deviceName, {
      fcmToken: token,
      ...deviceContextPatch(context),
    });
    const dupes = await ctx.db
      .query("userDevices")
      .withIndex("by_fcm_token", (q) => q.eq("fcmToken", token))
      .collect();
    await claimExclusively(ctx, dupes, userId, deviceId, {
      fcmToken: undefined,
    });
  },
});

/**
 * Browser Web Push subscription. All three fields move together — a partial
 * update would produce a subscription that can be addressed but not
 * encrypted for, which fails as an opaque 400 from the push service.
 */
export const setWebPushSubscription = mutation({
  args: {
    userId: v.id("users"),
    deviceId: v.string(),
    endpoint: v.string(),
    p256dh: v.string(),
    auth: v.string(),
    deviceName: v.optional(v.string()),
  },
  handler: async (
    ctx,
    { userId, deviceId, endpoint, p256dh, auth, deviceName },
  ) => {
    await upsertDevice(ctx, userId, deviceId, "web", deviceName, {
      webEndpoint: endpoint,
      webP256dh: p256dh,
      webAuth: auth,
    });
    const dupes = await ctx.db
      .query("userDevices")
      .withIndex("by_web_endpoint", (q) => q.eq("webEndpoint", endpoint))
      .collect();
    await claimExclusively(ctx, dupes, userId, deviceId, {
      webEndpoint: undefined,
      webP256dh: undefined,
      webAuth: undefined,
    });
  },
});

/**
 * The notifications toggle in Settings, per device.
 *
 * Deliberately a stored preference rather than "throw the token away": the
 * token stays valid, so turning it back on is instant and doesn't depend on
 * the OS handing us a fresh one. Suppresses alert pushes only — calls still
 * ring, because muting chat is not consenting to miss the phone.
 */
export const setPushEnabled = mutation({
  args: {
    userId: v.id("users"),
    deviceId: v.string(),
    enabled: v.boolean(),
  },
  handler: async (ctx, { userId, deviceId, enabled }) => {
    const row = await ctx.db
      .query("userDevices")
      .withIndex("by_user_device", (q) =>
        q.eq("userId", userId).eq("deviceId", deviceId),
      )
      .first();
    // No row means the device hasn't registered yet. Nothing to store, and
    // nothing is lost: registration happens on the next login/resume and the
    // client re-asserts the toggle then.
    if (!row) return;
    await ctx.db.patch(row._id, { pushEnabled: enabled });
  },
});

/**
 * This device's language and time zone, as its running app resolves them.
 *
 * Its own entry point, and NOT because the token setters cannot carry these —
 * they do, see [deviceContextPatch] — but because nothing else is re-run on
 * this schedule. A token changes when the OS mints a new one; these two change
 * when the user picks a language, boards a plane, or the zone shifts for DST.
 * Only wiring them into `setApnsToken` would mean a person who never rotates a
 * token never updates a time zone. The token setters are the floor (a pushable
 * row always has a zone); this is the ceiling (the zone is the current one).
 *
 * Both arguments are optional and only what is passed is written, so one can
 * move without disturbing the other — changing app language must not silently
 * re-stamp a stale offset, and vice versa. The client sends both together
 * anyway (it reads both fresh, and only calls when either differs), which
 * makes that belt-and-braces rather than load-bearing.
 *
 * Creates the row if this device has none yet, exactly like every other
 * registration path here: a desktop that never uploads a token still wants a
 * language on file for the day the nudge reaches it over some other transport.
 */
export const setDeviceContext = mutation({
  args: {
    userId: v.id("users"),
    deviceId: v.string(),
    platform: v.string(),
    deviceName: v.optional(v.string()),
    /** BCP-47-ish, as Flutter resolved it: "en", "tr", "pt-BR". */
    locale: v.optional(v.string()),
    /** Minutes ahead of UTC: +180 Istanbul, -480 California. */
    tzOffsetMinutes: v.optional(v.number()),
  },
  handler: async (
    ctx,
    { userId, deviceId, platform, deviceName, locale, tzOffsetMinutes },
  ) => {
    await upsertDevice(
      ctx,
      userId,
      deviceId,
      platform,
      deviceName,
      deviceContextPatch({ locale, tzOffsetMinutes }),
    );
  },
});

/**
 * Per-device opt-out for the daily games nudge, and nothing else.
 *
 * Deliberately not folded into `setPushEnabled`: that switch is "reach this
 * device at all", and a person who wants the once-a-day reminder to stop
 * almost never means "and also stop telling me about messages".
 */
export const setGameReminders = mutation({
  args: {
    userId: v.id("users"),
    deviceId: v.string(),
    enabled: v.boolean(),
  },
  handler: async (ctx, { userId, deviceId, enabled }) => {
    const row = await ctx.db
      .query("userDevices")
      .withIndex("by_user_device", (q) =>
        q.eq("userId", userId).eq("deviceId", deviceId),
      )
      .first();
    // Same as `setPushEnabled` above: no row means this device has not
    // registered yet, and nothing is lost — app.dart re-asserts the stored
    // preference immediately after the next login creates one.
    if (!row) return;
    await ctx.db.patch(row._id, { gameRemindersEnabled: enabled });
  },
});

// Tokenless registration — for devices that don't get a push wake-up
// (macOS, Windows, Linux) but still want to participate in the active-call
// subscription and "Move call here" handoff. Records the deviceId/platform/
// deviceName so the pill can label this device when it holds the active call.
export const registerDevice = mutation({
  args: {
    userId: v.id("users"),
    deviceId: v.string(),
    platform: v.string(),
    deviceName: v.optional(v.string()),
  },
  handler: async (ctx, { userId, deviceId, platform, deviceName }) => {
    await upsertDevice(ctx, userId, deviceId, platform, deviceName, {});
  },
});

// The "your devices" list. Everything the screen shows and nothing else — no
// push credentials leave the server, because a token is a send capability and
// this query exists to be rendered, not to be acted on.
//
// `isThis` is resolved HERE rather than compared on the client, so the row the
// UI refuses to offer a Remove button for is decided by the same code that
// would carry out the removal. A client that compared ids itself could be
// talked into showing Remove on its own row by a stale deviceId.
export const listDevices = query({
  args: { userId: v.id("users"), deviceId: v.string() },
  handler: async (ctx, { userId, deviceId }) => {
    const rows = await ctx.db
      .query("userDevices")
      .withIndex("by_user", (q) => q.eq("userId", userId))
      .collect();
    return rows
      .map((row) => ({
        deviceId: row.deviceId,
        platform: row.platform,
        deviceName: row.deviceName,
        lastSeenAt: row.lastSeenAt,
        createdAt: row.createdAt,
        isThis: row.deviceId === deviceId,
        // Whether this row can still be reached by a notification. The screen
        // says so plainly rather than implying every listed device is live:
        // a row with no credential left (swept dead, or a desktop that never
        // had one) is still a device you signed in on, and still worth seeing.
        reachable:
          row.pushEnabled !== false &&
          Boolean(
            row.voipToken ?? row.apnsToken ?? row.fcmToken ?? row.webEndpoint,
          ),
      }))
      // Newest sighting first, and this device pinned to the top regardless —
      // it is the row the reader is looking for confirmation of.
      .sort((a, b) =>
        a.isThis === b.isThis
          ? b.lastSeenAt - a.lastSeenAt
          : a.isThis
            ? -1
            : 1,
      );
  },
});

// "Remove every device except this one."
//
// Deliberately takes the CALLER's deviceId and derives the victims, rather
// than accepting a list from the client. The client's list is whatever it last
// rendered, so a device that signed in during the intervening seconds would
// survive a sweep the user believed was total — the one guarantee this button
// makes.
//
// Returns the count so the UI can report what happened rather than guess.
export const removeOtherDevices = mutation({
  args: { userId: v.id("users"), deviceId: v.string() },
  handler: async (ctx, { userId, deviceId }) => {
    const rows = await ctx.db
      .query("userDevices")
      .withIndex("by_user", (q) => q.eq("userId", userId))
      .collect();
    await revokeOtherSessions(ctx, userId, deviceId);
    let removed = 0;
    for (const row of rows) {
      if (row.deviceId === deviceId) continue;
      await ctx.db.delete(row._id);
      removed++;
    }
    return { removed };
  },
});

// Sign a single device out: revoke its session, then drop its push row.
//
// Order matters. The session goes first, because that is the half that stops
// the device DOING anything; if the second write failed we would rather be
// left with a signed-out device still listed than a silent one still able to
// post. Convex runs both in one transaction anyway, so this is about how the
// code reads under a future refactor, not about what can actually interleave.
export const clearDeviceToken = mutation({
  args: { userId: v.id("users"), deviceId: v.string() },
  handler: async (ctx, { userId, deviceId }) => {
    const row = await ctx.db
      .query("userDevices")
      .withIndex("by_user_device", (q) =>
        q.eq("userId", userId).eq("deviceId", deviceId),
      )
      .first();
    await revokeSessionsForDevice(ctx, userId, deviceId);
    if (row) await ctx.db.delete(row._id);
  },
});

// Called by the senders when a provider reports the credential is dead
// (APNs 410 Unregistered / 400 BadDeviceToken, FCM UNREGISTERED, Web Push
// 404/410 Gone). Each clears exactly one credential on one device row —
// sibling devices, and this device's *other* credentials, keep theirs.

export const clearVoipTokenForDeviceInternal = internalMutation({
  args: { deviceRowId: v.id("userDevices") },
  handler: async (ctx, { deviceRowId }) => {
    await ctx.db.patch(deviceRowId, { voipToken: undefined });
  },
});

export const clearApnsTokenForDeviceInternal = internalMutation({
  args: { deviceRowId: v.id("userDevices") },
  handler: async (ctx, { deviceRowId }) => {
    await ctx.db.patch(deviceRowId, { apnsToken: undefined });
  },
});

export const clearFcmTokenForDeviceInternal = internalMutation({
  args: { deviceRowId: v.id("userDevices") },
  handler: async (ctx, { deviceRowId }) => {
    await ctx.db.patch(deviceRowId, { fcmToken: undefined });
  },
});

export const clearWebPushForDeviceInternal = internalMutation({
  args: { deviceRowId: v.id("userDevices") },
  handler: async (ctx, { deviceRowId }) => {
    await ctx.db.patch(deviceRowId, {
      webEndpoint: undefined,
      webP256dh: undefined,
      webAuth: undefined,
    });
  },
});

// Fallback for the legacy single-string fields on `users`. Only invoked when
// call fanout hits a row synthesized from the user record (no userDevices rows
// exist yet), so already-logged-in clients keep ringing before they relog.
// The alert sender has no such fallback — it only ever reads userDevices.

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
