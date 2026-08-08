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
  | "dismiss";

export type AlertSpec = {
  kind: AlertKind;
  title?: string;
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
    // Apple documents `apns-push-type: background` as requiring
    // content-available and FORBIDDING alert/badge/sound. APNs is lenient in
    // practice, but a payload that only works by leniency is one behaviour
    // change away from breaking. The badge therefore rides as a data key and
    // AppDelegate applies it — same result on screen, compliant on the wire.
    return {
      aps: { "content-available": 1 },
      ...spec.data,
      badge: String(spec.badge),
    };
  }
  const aps: Record<string, unknown> = {
    alert: {
      title: clamp(spec.title ?? "", TITLE_MAX),
      body: clamp(spec.body ?? "", BODY_MAX),
    },
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
  // No `mutable-content`: it does nothing without a Notification Service
  // Extension and this app ships none. Add it the day one exists.
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
    badge: String(spec.badge),
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
    badge: String(spec.badge),
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
};

type AlertTarget = {
  userId: Id<"users">;
  devices: AlertDevice[];
  badge: number;
  lastReadAt: number;
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
      const devices: AlertDevice[] = [];
      for (const r of rows) {
        // undefined means enabled — every row predating the field.
        if (r.pushEnabled === false) continue;
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
        });
      }
      const { total } = await badgeTotalFor(ctx, userId);
      let lastReadAt = 0;
      if (roomId) {
        const m = await ctx.db
          .query("roomMembers")
          .withIndex("by_room_user", (q) =>
            q.eq("roomId", roomId).eq("userId", userId),
          )
          .first();
        lastReadAt = m?.lastReadAt ?? 0;
      }
      out.push({ userId, devices, badge: total, lastReadAt });
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
        if (t.devices.length === 0) return;
        const over = (a.perUser ?? {})[t.userId.toString()] ?? {};
        const spec: AlertSpec = {
          kind: a.kind,
          title: over.title ?? a.title,
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
        pushType: spec.kind === "dismiss" ? "background" : "alert",
        priority: spec.kind === "dismiss" ? "5" : "10",
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
