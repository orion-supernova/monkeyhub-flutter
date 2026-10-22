import { v } from "convex/values";
import { internalMutation, internalQuery } from "./_generated/server";
import { mutation, query } from "./functions";
import {
  revokeSessionsForDevice,
  revokeOtherSessions,
  liveSessionDeviceIds,
  hasAnyLiveSession,
} from "./sessionCore";
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
    | "friendActivityEnabled"
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
 * The `deviceSecretHash` this user's most recent session on [deviceId] carries,
 * revoked or not (the session that was just ended by a newer sign-in on the
 * same install is exactly the evidence needed), or undefined for none.
 */
async function secretHashOnDevice(
  ctx: any,
  userId: Id<"users">,
  deviceId: string,
): Promise<string | undefined> {
  const rows = await ctx.db
    .query("sessions")
    .withIndex("by_user_device", (q: any) =>
      q.eq("userId", userId).eq("deviceId", deviceId),
    )
    .order("desc")
    .take(5);
  return rows.find((r: any) => r.deviceSecretHash !== undefined)
    ?.deviceSecretHash;
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
  // One physical device, one account. The deviceId is minted once per
  // install and survives sign-out, so a phone that signs in as B after A
  // used to keep A's row — and A's row still held live push credentials for
  // THIS handset, so A's banners and A's call invites kept landing on a phone
  // B was holding (observed 2026-09-01: the caller's own iPhone was still a
  // registered device of the callee). The row is not "A's other device", it
  // is this one, and this one is B's now.
  //
  // But the deviceId is not a secret (call rosters and call rows show it to
  // peers), and this runs for ANY signed-in caller naming ANY deviceId: with an
  // unconditional delete, anybody could register a victim's deviceId under
  // their own account and wipe the victim's push and VoIP credentials, so the
  // victim silently stops getting calls. Another account's row is evicted only
  // when that account's session on this device and the caller's carry the same
  // `deviceSecretHash`, i.e. provably one install. Clients without a secret
  // evict nothing; their stale rows are harmless because the push senders only
  // trust a device row with a live session (`liveSessionDeviceIds`).
  const sameDevice = await ctx.db
    .query("userDevices")
    .withIndex("by_device", (q: any) => q.eq("deviceId", deviceId))
    .collect();
  const foreign = sameDevice.filter(
    (d: Doc<"userDevices">) => d.userId.toString() !== userId.toString(),
  );
  if (foreign.length > 0) {
    const mine = await secretHashOnDevice(ctx, userId, deviceId);
    if (mine !== undefined) {
      for (const d of foreign) {
        if ((await secretHashOnDevice(ctx, d.userId, deviceId)) === mine) {
          await ctx.db.delete(d._id);
        }
      }
    }
  }
  const existing = sameDevice.find(
    (d: Doc<"userDevices">) => d.userId.toString() === userId.toString(),
  );
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

/**
 * Per-device opt-out for friend activity — highlights, points and shared game
 * results — and nothing else.
 *
 * A third switch rather than a wider one, for the reason the second exists:
 * this is the only class of push whose VOLUME is set by other people, so the
 * person with twelve chatty friends has to be able to quiet it without also
 * quieting the twelve people talking to them, or the daily reminder they do
 * still want. See socialPush.ts.
 */
export const setFriendActivity = mutation({
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
    // No row means this device has not registered yet, and nothing is lost —
    // app.dart re-asserts the stored preference after the next login creates
    // one. Same as `setGameReminders` above.
    if (!row) return;
    await ctx.db.patch(row._id, { friendActivityEnabled: enabled });
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
    const live = await liveSessionDeviceIds(ctx, userId);
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
          // Signed out on that handset. The senders skip it (see
          // [liveSessionDeviceIds]), so saying "reachable" here would be the
          // screen promising something the backend has stopped doing.
          live.has(row.deviceId) &&
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
    // `auth.logout` does this too, and on a sign-out the two race — whichever
    // lands first does the whole job and the other is rejected for the very
    // revocation it was trying to perform. Doing it here as well means the
    // presence dot is right either way. Guarded, because "remove this device"
    // is also reachable from the Devices screen of a phone the user is still
    // holding, and that phone is not offline.
    if (!(await hasAnyLiveSession(ctx, userId))) {
      await ctx.db.patch(userId, { status: "offline", lastSeen: Date.now() });
    }
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

/**
 * How long a device may go unseen before its row is reaped.
 *
 * Every sign-out path already deletes its own row inline — [clearDeviceToken]
 * and [removeOtherDevices] both do — so this sweep only ever catches the ones
 * that never landed: an app killed before the request completed, an
 * uninstall or a browser tab closed without running any unload path, or a
 * row written before that inline cleanup shipped at all.
 *
 * Longer than `dailyNudge.ACTIVE_WINDOW_DAYS` (30) on purpose — that window
 * decides "still worth nudging", a decision that costs nothing to get wrong
 * for a quiet device. Deleting the row is not costless in the same way: it
 * drops the device from the "Devices" screen and the active-call handoff
 * pill, so the cutoff stays well clear of anyone who merely opens the app
 * infrequently.
 */
const STALE_DEVICE_RETENTION_MS = 90 * 24 * 60 * 60 * 1000;

/** Rows reaped per tick, like every other bounded sweep in this backend. */
const STALE_DEVICE_PAGE = 200;

/**
 * Reap `userDevices` rows nobody has used in [STALE_DEVICE_RETENTION_MS].
 *
 * Ranged over `by_last_seen`, which `upsertDevice` refreshes on every login,
 * resume, and token upload — the "future stale-device sweep" that comment
 * already named. A device still in use never approaches the cutoff, so this
 * is a backstop for abandoned rows, not a guess at who stopped playing.
 *
 * Bounded per run for the same reason `sessionCore.gcRevokedSessions` is: a
 * deleted row leaves the range immediately, so a normal tick costs one index
 * probe and a backlog only ever costs a longer tail, never a function that
 * blows past Convex's per-call limits.
 */
/**
 * How many device rows are addressed to a handset that is no longer signed in.
 *
 *   npx convex run voipTokens:strandedDevices
 *
 * The triage query for the incident that produced [liveSessionDeviceIds]: a
 * user locked out of her own account, sitting on the login screen, still
 * getting notifications for it. The senders now skip these rows, so a non-zero
 * count is no longer a live bug — it is the backlog left by every sign-out
 * that ran before the fix, draining as `gcStaleDevices` collects it.
 *
 * Bounded by [limit] because it walks device rows and then their owners'
 * sessions, and a query that dies on the read limit is no use to whoever is
 * trying to answer a support ticket with it. `truncated` says when the answer
 * is a floor rather than a total.
 */
export const strandedDevices = internalQuery({
  args: { limit: v.optional(v.number()) },
  returns: v.object({
    scanned: v.number(),
    /** …of those, no live session on that (user, device). */
    stranded: v.number(),
    /** …of THOSE, still holding a credential a sender could have used. */
    strandedWithCredential: v.number(),
    truncated: v.boolean(),
  }),
  handler: async (ctx, { limit }) => {
    const cap = Math.min(limit ?? 2000, 5000);
    const rows = await ctx.db.query("userDevices").take(cap + 1);
    const truncated = rows.length > cap;
    const scan = truncated ? rows.slice(0, cap) : rows;
    // One session read per ACCOUNT: a person's handsets sit together here.
    const liveByUser = new Map<string, Set<string>>();
    let stranded = 0;
    let strandedWithCredential = 0;
    for (const row of scan) {
      const key = row.userId.toString();
      let live = liveByUser.get(key);
      if (live === undefined) {
        live = await liveSessionDeviceIds(ctx, row.userId);
        liveByUser.set(key, live);
      }
      if (live.has(row.deviceId)) continue;
      stranded += 1;
      if (
        row.pushEnabled !== false &&
        (row.voipToken ?? row.apnsToken ?? row.fcmToken ?? row.webEndpoint)
      ) {
        strandedWithCredential += 1;
      }
    }
    return {
      scanned: scan.length,
      stranded,
      strandedWithCredential,
      truncated,
    };
  },
});

export const gcStaleDevices = internalMutation({
  args: {},
  handler: async (ctx) => {
    const cutoff = Date.now() - STALE_DEVICE_RETENTION_MS;
    const stale = await ctx.db
      .query("userDevices")
      .withIndex("by_last_seen", (q) => q.lt("lastSeenAt", cutoff))
      .take(STALE_DEVICE_PAGE);
    for (const row of stale) {
      await ctx.db.delete(row._id);
    }
  },
});
