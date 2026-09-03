import { internalAction, internalQuery } from "./_generated/server";
import { internal } from "./_generated/api";
import { v } from "convex/values";
import type { Id } from "./_generated/dataModel";
import {
  apnsPost,
  fcmPost,
  stringifyValues,
  type ApnsEnv,
} from "./pushTransport";
import { badgeTotalFor } from "./badges";
import { liveSessionDeviceIds } from "./sessionCore";
import { resolveMute } from "./mute";

// Deliberately NOT imported from ./webPush: that module runs in the Node
// runtime (Convex's V8 isolate has no ECDH), and importing it here would drag
// Node into this bundle. It is reached over ctx.runAction instead.
type WebPushSubscription = {
  endpoint: string;
  p256dh: string;
  auth: string;
};

// Alert notifications — everything a person sees on a lock screen. Chat
// messages, guardian approvals, call banners, and the invisible push that
// takes them back down again.
//
// One entry point (`sendAlert`) and three transports, chosen per device:
//   apnsToken → APNs on the `<bundle>` topic
//   fcmToken  → FCM v1, data-only (Android renders it in ChatNotifications.kt)
//   web*      → Web Push, encrypted per RFC 8291 (webPush.ts)
//
// Ringing is NOT here — that is voipPush.ts, on a different token and a
// different topic. The two must never be confused; see `_loadAlertTargets`.

// ────────────────────────── the wire contract ──────────────────────────

export type AlertKind =
  | "message"
  | "approval"
  | "call_invite"
  | "group_call_invite"
  | "dismiss"
  | "daily_games";

export type AlertSpec = {
  kind: AlertKind;
  title?: string;
  /**
   * `aps.alert.subtitle` on iOS — a line distinct from both `title` and
   * `body`, e.g. the group's name under the sender's name for a group-room
   * message. Android and web have no equivalent chrome and read the same
   * information back out of `data.roomName`/`data.isGroup` instead (see
   * ChatNotifications.kt / mh-push-sw.js) rather than a separate field.
   */
  subtitle?: string;
  body?: string;
  /**
   * Custom keys, delivered FLAT — as siblings of `aps` on iOS, as FCM `data`
   * on Android, as the JSON body on web. Every consumer reads the same names:
   * AppDelegate.swift, ChatNotifications.kt and mh-push-sw.js. The Dart test
   * `push_payload_contract_test.dart` pins them.
   */
  data: Record<string, string>;
  badge: number;
  /** roomId — APNs `thread-id`, Android group key, web notification group. */
  threadId?: string;
  /** messageId/callId — replaces an already-displayed notification. */
  collapseId?: string;
};

/**
 * How long the transport should keep trying, per kind.
 *
 * A chat notification is worth a day. A ring is worth as long as the phone is
 * still ringing and not one second more — a call banner that lands after the
 * call ended is worse than no banner. The dismiss push gets an hour because it
 * is chasing a device that may simply be asleep.
 */
const KIND_TTL_SECONDS: Record<AlertKind, number> = {
  message: 86400,
  approval: 86400,
  call_invite: 45,
  group_call_invite: 60,
  dismiss: 3600,
  // Three hours, and short on purpose. This one is sent because it is
  // lunchtime where the person is standing; a phone that was off all afternoon
  // should get nothing when it wakes rather than a reminder about a moment
  // that has passed. Unlike a chat message, nothing is lost by dropping it —
  // there is another one tomorrow.
  daily_games: 10800,
};

// APNs and FCM both cap a payload at 4096 bytes and Web Push has less than
// that after encryption framing. `messages.send` does not bound its preview
// (a filename or a long paste can be arbitrary), so clamp here rather than
// discover it as a 400 PayloadTooLarge — which, misclassified, would look
// like a dead token.
const TITLE_MAX = 64;
const BODY_MAX = 200;

function clamp(s: string, max: number): string {
  return s.length <= max ? s : `${s.slice(0, max - 1)}…`;
}

/**
 * The iOS payload: `aps` plus our flat custom keys.
 *
 * Pure and ctx-free so it can be unit-tested, and so the shape is readable in
 * one place instead of being assembled across a send loop.
 */
export function buildApnsBody(spec: AlertSpec): Record<string, unknown> {
  if (spec.kind === "dismiss") {
    // Carries a badge, and that is load-bearing rather than incidental.
    //
    // A payload with ONLY content-available is a pure background push: the
    // most aggressively throttled class iOS has, undelivered entirely to a
    // force-quit app, and "delivered at a time of the system's choosing"
    // otherwise. This push is the only thing that takes a deleted message's
    // banner off a lock screen, so throttling it is throttling the feature.
    //
    // A badge makes it a legitimate `alert`-type push instead — prompt and
    // reliable — while still displaying nothing at all, because there is no
    // alert or sound key. That is exactly what the previous push vendor sent
    // (ios_badgeType: "SetTo"), and why this used to work.
    //
    // content-available stays so didReceiveRemoteNotification still runs and
    // can do the removal. The badge is duplicated as a data key for Android
    // and web, which have no `aps`.
    return {
      aps: { "content-available": 1, badge: spec.badge },
      ...spec.data,
      badge: String(spec.badge),
    };
  }
  const alert: Record<string, string> = {
    title: clamp(spec.title ?? "", TITLE_MAX),
    body: clamp(spec.body ?? "", BODY_MAX),
  };
  // The group name for a group-room message, e.g. "SenderName" (title) over
  // "Group Name" (subtitle) over the message (body) — mirrors how
  // WhatsApp/Telegram/iMessage separate who's talking from where. Absent for
  // a DM, where the room has no name of its own to show.
  if (spec.subtitle) {
    alert.subtitle = clamp(spec.subtitle, TITLE_MAX);
  }
  const aps: Record<string, unknown> = {
    alert,
    sound: "default",
  };
  // An incoming call is not an unread item — badging it would leave the count
  // wrong the moment the call is answered, with nothing to correct it.
  if (spec.kind === "message" || spec.kind === "approval") {
    aps.badge = spec.badge;
  }
  if (spec.threadId) aps["thread-id"] = spec.threadId;
  if (spec.kind === "message") {
    aps.category = "CHAT_MESSAGE";
  } else if (spec.kind === "call_invite" || spec.kind === "group_call_invite") {
    aps.category = "CALL_INVITE";
    // Breaks through Focus. Requires the
    // com.apple.developer.usernotifications.time-sensitive entitlement — with
    // it missing this is silently ignored, no error and no log, and the banner
    // just gets swallowed. See ios/Runner/*.entitlements.
    aps["interruption-level"] = "time-sensitive";
  }
  // Wakes the Notification Service Extension — see
  // ios/NotificationService/NotificationService.swift. It does two jobs now:
  // swaps the app icon for the sender's face, and writes the message into the
  // App Group inbox so the room can open already showing it.
  //
  // It used to be set ONLY when there was a face to draw, on the grounds that
  // `mutable-content` launches a second process before anything is shown and
  // spending that on a sender with no avatar bought a notification identical
  // to the one that would have rendered anyway. That reasoning was right and
  // is now out of date: for a chat message the launch also buys the seed, and
  // the seed is worth far more than the face — it is the difference between
  // tapping a notification into a room that is already showing the message and
  // tapping into one that has to go and ask for it. The face remains the only
  // reason for every OTHER kind.
  //
  // `spec.data` is the MERGED map (see `sendAlert`, which spreads the per-user
  // override over the shared data), so a recipient whose view of the sender's
  // `visibility.avatar` hides it has no `senderAvatarUrl` here — and for a
  // non-message kind still never pays for the launch. The privacy gate and the
  // battery gate remain the same line for those.
  if (spec.kind === "message" || spec.data.senderAvatarUrl) {
    aps["mutable-content"] = 1;
  }
  return { aps, ...spec.data };
}

/**
 * The Android payload. Data-only, always.
 *
 * A `notification` block would make Android render the notification itself and
 * skip `onMessageReceived` entirely while the app is backgrounded — which
 * forfeits tag collapse, group summaries, per-room dismissal and active-room
 * suppression. Owning the render is the whole point.
 */
export function buildFcmMessage(
  spec: AlertSpec,
  token: string,
): Record<string, unknown> {
  const data: Record<string, string> = {
    ...spec.data,
    // Omitted for the daily nudge, which is not an unread item and has no
    // count of its own to report. iOS already skips it (see `buildApnsBody`);
    // sending a number here would make the two platforms disagree about what
    // a nudge means, for a key neither of them renders on one.
    ...(spec.kind === "daily_games" ? {} : { badge: String(spec.badge) }),
  };
  if (spec.title) data.title = clamp(spec.title, TITLE_MAX);
  if (spec.body) data.body = clamp(spec.body, BODY_MAX);
  if (spec.threadId) data.threadId = spec.threadId;
  if (spec.collapseId) data.collapseId = spec.collapseId;
  return {
    token,
    data,
    android: {
      priority: spec.kind === "dismiss" ? "normal" : "high",
      ttl: `${KIND_TTL_SECONDS[spec.kind]}s`,
      // Deliberately NO collapse_key. FCM's collapse discards an UNDELIVERED
      // message, which for chat means silently losing messages — it is not
      // the same thing as APNs collapse-id, which replaces a DISPLAYED
      // notification. Android collapse is done client-side via the tag.
    },
  };
}

/** The web payload — plain JSON; the service worker owns the render. */
export function buildWebPushPayload(spec: AlertSpec): Record<string, string> {
  const out: Record<string, string> = {
    ...spec.data,
    ...(spec.kind === "daily_games" ? {} : { badge: String(spec.badge) }),
  };
  if (spec.title) out.title = clamp(spec.title, TITLE_MAX);
  if (spec.body) out.body = clamp(spec.body, BODY_MAX);
  if (spec.threadId) out.threadId = spec.threadId;
  if (spec.collapseId) out.collapseId = spec.collapseId;
  return out;
}

// ────────────────────────── target loading ──────────────────────────

type AlertDevice = {
  deviceRowId: Id<"userDevices">;
  deviceId: string;
  platform: string;
  apnsToken?: string;
  apnsEnv?: ApnsEnv;
  fcmToken?: string;
  web?: WebPushSubscription;
  /**
   * The language this device's app is running in — see the `locale` column on
   * `userDevices`. Read only by senders that compose their own copy
   * (`dailyNudge.ts`); a chat notification's text is a person's message and is
   * not ours to translate.
   */
  locale?: string;
};

type AlertTarget = {
  userId: Id<"users">;
  devices: AlertDevice[];
  badge: number;
  lastReadAt: number;
  /** Room mute, resolved at query time. False whenever there is no room. */
  mutesNotifications: boolean;
};

/**
 * Everything the fan-out needs for one batch of recipients, in one query:
 * their push-capable devices, their absolute badge total, and — when the push
 * belongs to a room — their read cursor.
 *
 * The read cursor is what replaced the old `pushReceipts` race arbitration.
 * That machinery sent the push, then raced to cancel it if the recipient had
 * read the room in the meantime; this simply doesn't send.
 *
 * NOTE: `voipToken` is deliberately absent from the returned shape, not merely
 * unused. It is a PushKit token on the `<bundle>.voip` topic; sending it as an
 * alert gets 400 DeviceTokenNotForTopic, and the dead-token sweep would then
 * clear it — silently stopping that phone from ringing, with a symptom that
 * points nowhere near notifications. Not projecting it makes that unwritable.
 */
export const _loadAlertTargets = internalQuery({
  args: {
    userIds: v.array(v.id("users")),
    roomId: v.optional(v.id("rooms")),
  },
  handler: async (ctx, { userIds, roomId }): Promise<AlertTarget[]> => {
    const out: AlertTarget[] = [];
    for (const userId of userIds) {
      const rows = await ctx.db
        .query("userDevices")
        .withIndex("by_user", (q) => q.eq("userId", userId))
        .collect();
      // One read for the whole account, reused by every row below.
      const live = await liveSessionDeviceIds(ctx, userId);
      const devices: AlertDevice[] = [];
      for (const r of rows) {
        // undefined means enabled — every row predating the field.
        if (r.pushEnabled === false) continue;
        // Signed out on this handset. A `userDevices` row outlives the session
        // whenever the client could not delete it, and a banner for an account
        // the phone can no longer open is exactly what that leaves behind —
        // reported by a user sitting on the login screen, locked out, still
        // being notified. See [liveSessionDeviceIds].
        if (!live.has(r.deviceId)) continue;
        const web =
          r.webEndpoint && r.webP256dh && r.webAuth
            ? {
                endpoint: r.webEndpoint,
                p256dh: r.webP256dh,
                auth: r.webAuth,
              }
            : undefined;
        if (!r.apnsToken && !r.fcmToken && !web) continue;
        devices.push({
          deviceRowId: r._id,
          deviceId: r.deviceId,
          platform: r.platform,
          apnsToken: r.apnsToken,
          apnsEnv: r.apnsEnv,
          fcmToken: r.fcmToken,
          web,
          locale: r.locale,
        });
      }
      const { total } = await badgeTotalFor(ctx, userId);
      let lastReadAt = 0;
      let mutesNotifications = false;
      if (roomId) {
        const m = await ctx.db
          .query("roomMembers")
          .withIndex("by_room_user", (q) =>
            q.eq("roomId", roomId).eq("userId", userId),
          )
          .first();
        lastReadAt = m?.lastReadAt ?? 0;
        // Free: the row we already fetched for the read cursor carries the
        // mute columns too, so the gate below costs no extra read.
        mutesNotifications = resolveMute(m, Date.now()).notifications;
      }
      out.push({ userId, devices, badge: total, lastReadAt, mutesNotifications });
    }
    return out;
  },
});

// ────────────────────────── fan-out ──────────────────────────

export const sendAlert = internalAction({
  args: {
    userIds: v.array(v.id("users")),
    kind: v.union(
      v.literal("message"),
      v.literal("approval"),
      v.literal("call_invite"),
      v.literal("group_call_invite"),
      v.literal("dismiss"),
    ),
    title: v.optional(v.string()),
    /** See `AlertSpec.subtitle` — iOS only; Android/web read `data` instead. */
    subtitle: v.optional(v.string()),
    body: v.optional(v.string()),
    /** Flat custom keys; values are stringified for FCM's benefit. */
    data: v.optional(v.any()),
    roomId: v.optional(v.id("rooms")),
    collapseId: v.optional(v.string()),
    /**
     * When set, a recipient whose read cursor is at or past this instant is
     * skipped — they opened the room while this push was being assembled.
     */
    sentAt: v.optional(v.number()),
    /** userId → { title?, body?, data? } overrides. Used for @mentions. */
    perUser: v.optional(v.any()),
  },
  returns: v.null(),
  handler: async (ctx, a) => {
    if (a.userIds.length === 0) return null;
    const targets: AlertTarget[] = await ctx.runQuery(
      internal.push._loadAlertTargets,
      { userIds: a.userIds, roomId: a.roomId },
    );
    await Promise.allSettled(
      targets.map(async (t) => {
        if (a.sentAt !== undefined && t.lastReadAt >= a.sentAt) {
          return;
        }
        // The mute, enforced at the last possible moment before bytes leave
        // the building. `notifications.sendMessagePush` has already dropped
        // these recipients from its own list; this is the choke point that
        // makes that impossible to get wrong from a future caller, and it
        // costs one boolean because `_loadAlertTargets` had the row anyway.
        //
        // `kind === "message"` and nothing else, on purpose. `call_invite` and
        // `group_call_invite` both carry a roomId (see calls.ts / groupCalls.ts),
        // so a looser test would stop a muted room's phone from ringing — which
        // is not what anybody means by muting a chat, and is the kind of bug
        // that gets noticed as "the app doesn't ring any more". `dismiss` is
        // exempt for the opposite reason: it is silent by construction and its
        // entire job is correcting a badge, including for the muted.
        if (a.kind === "message" && t.mutesNotifications) return;
        if (t.devices.length === 0) return;
        const over = (a.perUser ?? {})[t.userId.toString()] ?? {};
        const spec: AlertSpec = {
          kind: a.kind,
          title: over.title ?? a.title,
          subtitle: over.subtitle ?? a.subtitle,
          body: over.body ?? a.body,
          data: stringifyValues({ ...(a.data ?? {}), ...(over.data ?? {}) }),
          badge: t.badge,
          threadId: a.roomId?.toString(),
          collapseId: a.collapseId,
        };
        // Per device rather than per recipient: someone with a phone and a
        // laptop gets both, each with its own transport and its own failure.
        await Promise.allSettled(
          t.devices.map((d) => alertToDevice(ctx, t.userId, d, spec)),
        );
      }),
    );
    return null;
  },
});

/**
 * The same fan-out, addressed to DEVICES rather than to people.
 *
 * `sendAlert` above composes one payload per recipient and copies it to every
 * screen they own, which is right for a chat message: the text is the sender's
 * and it reads the same everywhere. The daily nudge is the opposite case —
 * every word of it is ours, and the language it should be written in is a
 * property of the handset, not of the account (see `userDevices.locale`). A
 * shared family phone in Turkish and its owner's laptop in English are both
 * correct at once.
 *
 * So the caller resolves copy per device and hands the finished specs over.
 * Everything below the composition step — transport selection, the three error
 * classes, dead-credential clearing, the single retry — is `alertToDevice`,
 * unchanged and shared, which is the whole reason this lives here rather than
 * growing a second sender inside dailyNudge.ts.
 *
 * There is no room, so there is no mute to resolve and no read cursor to race:
 * the caller's own audience query is the entire gate. `pushEnabled` is the one
 * exception, and it is applied there too — a device that has opted out of push
 * must not be reachable from any sender in this file.
 */
export const sendAlertToDevices = internalAction({
  args: {
    /** `{ userId, device, spec }` triples — see `AlertDevice`/`AlertSpec`. */
    targets: v.array(v.any()),
  },
  returns: v.null(),
  handler: async (ctx, { targets }) => {
    if (targets.length === 0) return null;
    await Promise.allSettled(
      targets.map((t: any) =>
        alertToDevice(
          ctx,
          t.userId as Id<"users">,
          t.device as AlertDevice,
          t.spec as AlertSpec,
        ),
      ),
    );
    return null;
  },
});

const TRANSIENT_RETRY_DELAY_MS = 2000;

// Re-attempts one device after a transient (429/5xx) failure. Scheduled once
// with isRetry so it cannot loop.
export const retryAlertToDevice = internalAction({
  args: { userId: v.id("users"), device: v.any(), spec: v.any() },
  returns: v.null(),
  handler: async (ctx, { userId, device, spec }) => {
    await alertToDevice(ctx, userId, device as AlertDevice, spec as AlertSpec, {
      isRetry: true,
    });
    return null;
  },
});

/**
 * Deliver one spec to one device over whichever transports it holds.
 *
 * Mirrors `voipPush.pushToDevice`: three error classes, three responses —
 * clear the dead credential, shout about a misconfiguration without touching
 * the credential, or retry once after a blip.
 */
async function alertToDevice(
  ctx: any,
  userId: Id<"users">,
  d: AlertDevice,
  spec: AlertSpec,
  opts: { isRetry?: boolean } = {},
): Promise<void> {
  let scheduledRetry = false;
  const scheduleRetry = async () => {
    if (opts.isRetry || scheduledRetry) return;
    scheduledRetry = true;
    await ctx.scheduler.runAfter(
      TRANSIENT_RETRY_DELAY_MS,
      internal.push.retryAlertToDevice,
      { userId, device: d, spec },
    );
  };
  const ttl = KIND_TTL_SECONDS[spec.kind];

  if (d.apnsToken) {
    try {
      await apnsPost(ctx, {
        token: d.apnsToken,
        env: d.apnsEnv,
        topicSuffix: "",
        // Every kind is an `alert` push, including the invisible dismiss —
        // see buildApnsBody on why that one carries a badge. `background` at
        // priority 5 is the throttled path, and a dismissal nobody receives
        // is a message whose banner outlives it.
        pushType: "alert",
        priority: "10",
        expiration: Math.floor(Date.now() / 1000) + ttl,
        collapseId: spec.collapseId,
        body: buildApnsBody(spec),
      });
      console.log(`sendAlert: APNs OK device=${d.deviceId} kind=${spec.kind}`);
    } catch (e) {
      const msg = e instanceof Error ? e.message : String(e);
      console.error(`sendAlert: APNs failed device=${d.deviceId}: ${msg}`);
      if (msg.startsWith("APNS_BAD_TOKEN")) {
        await ctx.runMutation(
          internal.voipTokens.clearApnsTokenForDeviceInternal,
          { deviceRowId: d.deviceRowId },
        );
        console.warn(
          `sendAlert: cleared apnsToken device=${d.deviceId} after ${msg}`,
        );
      } else if (msg.startsWith("APNS_MISCONFIG")) {
        // A wrong topic or a bad key fails EVERY device, so this must be loud
        // and must never be answered by deleting tokens.
        console.error(
          `ALERT_PUSH_MISCONFIG: APNs cannot send — fix deployment env. ${msg}`,
        );
      } else if (msg.startsWith("APNS_TRANSIENT")) {
        await scheduleRetry();
      }
    }
  }

  if (d.fcmToken) {
    try {
      await fcmPost(ctx, buildFcmMessage(spec, d.fcmToken));
      console.log(`sendAlert: FCM OK device=${d.deviceId} kind=${spec.kind}`);
    } catch (e) {
      const msg = e instanceof Error ? e.message : String(e);
      console.error(`sendAlert: FCM failed device=${d.deviceId}: ${msg}`);
      if (msg.startsWith("FCM_BAD_TOKEN")) {
        await ctx.runMutation(
          internal.voipTokens.clearFcmTokenForDeviceInternal,
          { deviceRowId: d.deviceRowId },
        );
        console.warn(
          `sendAlert: cleared fcmToken device=${d.deviceId} after ${msg}`,
        );
      } else if (msg.startsWith("FCM_MISCONFIG")) {
        console.error(
          `ALERT_PUSH_MISCONFIG: FCM cannot send — fix deployment env. ${msg}`,
        );
      } else if (msg.startsWith("FCM_TRANSIENT")) {
        await scheduleRetry();
      }
    }
  }

  // Web gets everything EXCEPT the silent dismiss. Chrome enforces
  // `userVisibleOnly: true` on the subscription: a push that shows no
  // notification spends a hidden budget and, once it runs out, Chrome
  // displays its own "this site was updated in the background" banner — worse
  // than the stale notification we were trying to clear. The page reconciles
  // its own notifications on focus instead (see web/mh-push-sw.js).
  if (d.web && spec.kind !== "dismiss") {
    // Returns a result instead of throwing: an error crossing a runtime
    // boundary arrives wrapped, and the three-class prefix branched on below
    // would no longer be at the start of the message.
    const res: { ok: boolean; error?: string } = await ctx.runAction(
      internal.webPush.sendOne,
      {
        endpoint: d.web.endpoint,
        p256dh: d.web.p256dh,
        auth: d.web.auth,
        payload: buildWebPushPayload(spec),
        ttlSeconds: ttl,
        // Everything that reaches here is user-visible by definition, which
        // is also what `userVisibleOnly` obliges us to deliver promptly.
        urgency: "high",
        topic: spec.collapseId,
      },
    );
    if (res.ok) {
      console.log(
        `sendAlert: WebPush OK device=${d.deviceId} kind=${spec.kind}`,
      );
    } else {
      const msg = res.error ?? "unknown";
      console.error(`sendAlert: WebPush failed device=${d.deviceId}: ${msg}`);
      if (msg.startsWith("WEBPUSH_BAD_TOKEN")) {
        await ctx.runMutation(
          internal.voipTokens.clearWebPushForDeviceInternal,
          { deviceRowId: d.deviceRowId },
        );
        console.warn(
          `sendAlert: cleared web subscription device=${d.deviceId} after ${msg}`,
        );
      } else if (msg.startsWith("WEBPUSH_MISCONFIG")) {
        console.error(
          `ALERT_PUSH_MISCONFIG: Web Push cannot send — check VAPID env. ${msg}`,
        );
      } else if (msg.startsWith("WEBPUSH_TRANSIENT")) {
        await scheduleRetry();
      }
    }
  }
}

// ────────────────────────── operational visibility ──────────────────────────

/**
 * How much of the active user base this deployment can actually reach.
 *
 * Worth watching after the OneSignal cutover, because there is no fallback: a
 * user is reachable only once their updated client has registered a token.
 * `iosVoipOnly` is the rollout curve — a live iOS device holding a PushKit
 * token but no alert token is still running the old build.
 *
 *   npx convex run push:coverageReport '{"sinceDays":30}'
 */
export const coverageReport = internalQuery({
  args: { sinceDays: v.optional(v.number()) },
  handler: async (ctx, { sinceDays }) => {
    const cutoff = Date.now() - (sinceDays ?? 30) * 86_400_000;
    // Bounded so this can't outgrow a query's read limit as the table grows.
    const rows = await ctx.db
      .query("userDevices")
      .withIndex("by_last_seen", (q) => q.gt("lastSeenAt", cutoff))
      .take(5000);
    const byUser = new Map<string, boolean>();
    for (const r of rows) {
      const k = r.userId.toString();
      const reachable = !!(r.apnsToken || r.fcmToken || r.webEndpoint);
      byUser.set(k, (byUser.get(k) ?? false) || reachable);
    }
    const covered = [...byUser.values()].filter(Boolean).length;
    return {
      devices: {
        total: rows.length,
        withApns: rows.filter((r) => r.apnsToken).length,
        withFcm: rows.filter((r) => r.fcmToken).length,
        withWeb: rows.filter((r) => r.webEndpoint).length,
        iosVoipOnly: rows.filter(
          (r) => r.platform === "ios" && r.voipToken && !r.apnsToken,
        ).length,
        optedOut: rows.filter((r) => r.pushEnabled === false).length,
      },
      users: { total: byUser.size, covered },
      coveragePct: byUser.size
        ? Math.round((100 * covered) / byUser.size)
        : 0,
      truncated: rows.length === 5000,
    };
  },
});
