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

// Direct VoIP push delivery — wakes a *killed* app for CallKit (iOS) or
// ConnectionService (Android).
//
// iOS: APNs HTTP/2 with the PushKit topic `<bundle>.voip`, which is a
//      DIFFERENT topic and a DIFFERENT token from the alert pushes in
//      `push.ts`. Both are signed with the same developer-account `.p8`.
// Android: FCM HTTP v1, data-only `priority: high` message, handled by
//      CallFcmService.
//
// The HTTP mechanics, provider-JWT caching and error classification all live
// in `pushTransport.ts`; this file is only about what a call needs.
//
// Any missing piece on a given platform → that platform's branch logs and
// skips (the other can still deliver). Never throws back to the caller.

// Returns every push-eligible device row for [userId]. If the registry is
// empty (older client that hasn't relogged since the migration), synthesizes
// a single fallback row from the legacy `users.voipToken`/`fcmToken` so
// pushes keep flowing until the next login refreshes the per-device record.
//
// Each row carries its own `_id` so the dead-token cleanup path can target
// the specific device — `deviceRowId: null` marks the legacy fallback (we
// clear the user-level field instead).
export const _loadUserDevices = internalQuery({
  args: { userId: v.id("users") },
  handler: async (ctx, { userId }): Promise<DeviceRow[]> => {
    const rows = await ctx.db
      .query("userDevices")
      .withIndex("by_user", (q) => q.eq("userId", userId))
      .collect();
    if (rows.length > 0) {
      return rows.map((r) => ({
        deviceRowId: r._id,
        legacy: false as const,
        deviceId: r.deviceId,
        platform: r.platform,
        voipToken: r.voipToken,
        apnsEnv: r.apnsEnv,
        fcmToken: r.fcmToken,
      }));
    }
    const u = await ctx.db.get(userId);
    if (!u) return [];
    if (!u.voipToken && !u.fcmToken) return [];
    return [
      {
        deviceRowId: null,
        legacy: true as const,
        deviceId: "_legacy",
        platform: u.voipToken ? "ios" : "android",
        voipToken: u.voipToken,
        fcmToken: u.fcmToken,
      },
    ];
  },
});

export const sendVoip = internalAction({
  args: {
    callId: v.id("calls"),
    calleeId: v.id("users"),
    callerId: v.id("users"),
    callerName: v.string(),
    callerAvatarUrl: v.optional(v.union(v.string(), v.null())),
    type: v.string(),
    roomId: v.id("rooms"),
  },
  handler: async (ctx, args) => {
    // Ring-path guard. This action is scheduled `runAfter(0)` at initiate with
    // every payload field precomputed, so it can execute AFTER a fast cancel /
    // sibling-accept / reject has already flipped the row terminal — and
    // nothing between the schedule and here re-reads it. Ringing a device for
    // a call that is already over is the "ghost ring": a native card that
    // appears then gets dismissed a beat later by the chasing `taken` push.
    // Re-confirm the call is still ringing before waking anyone.
    const status: string | null = await ctx.runQuery(
      internal.calls.callStatusInternal,
      { callId: args.callId },
    );
    if (status !== "ringing") {
      console.log(
        `sendVoip: call ${args.callId} no longer ringing (${status ?? "gone"}) — skipping invite`,
      );
      return;
    }
    // Annotated at the USE site, not just on the query.
    //
    // `internal` is typed from `fullApi`, which includes `typeof voipPush` —
    // this whole module, this action included. Resolving that needs the
    // module's type, which needs this line's type: a cycle TypeScript ends by
    // making the lot `any`. Declaring the type here needs nothing from
    // `internal` and so cannot participate in the cycle. Without it `devices`
    // is `any[]`, every `.map((d) => …)` below loses its parameter type, and
    // `d.apnsEnv` resolves on legacy rows that have never had one.
    const devices: DeviceRow[] = await ctx.runQuery(internal.voipPush._loadUserDevices, {
      userId: args.calleeId,
    });
    if (devices.length === 0) {
      console.log("sendVoip: no devices registered for callee");
      return;
    }
    const payload = {
      kind: "invite",
      callId: args.callId.toString(),
      callerId: args.callerId.toString(),
      callerName: args.callerName,
      callerHandle: args.callerName,
      // Android's native full-screen ringer renders this URL as the
      // caller avatar (plugin `avatar` field, wired in CallFcmService).
      callerAvatarUrl: args.callerAvatarUrl ?? "",
      callType: args.type,
      roomId: args.roomId.toString(),
    };
    // Fan out in parallel — one slow APNs round-trip shouldn't block the
    // sibling devices. allSettled because we never want one failure to
    // suppress logging for the others.
    const results = await Promise.allSettled(
      devices.map((d) => pushToDevice(ctx, args.calleeId, d, payload)),
    );
    // Alert-banner rescue: if the VoIP push failed for EVERY device the
    // callee would otherwise get complete silence. The usual cause is a
    // voipToken cleared by the dead-token sweep on a device whose ordinary
    // APNs alert token is still perfectly good — so a time-sensitive banner
    // naming the caller has a real chance of landing where the ring didn't,
    // and is strictly better than nothing either way.
    const anyDelivered = results.some(
      (r) => r.status === "fulfilled" && r.value === true,
    );
    if (!anyDelivered) {
      console.warn(
        `sendVoip: no native push delivered for callee=${args.calleeId} — alert rescue`,
      );
      await ctx.scheduler.runAfter(0, internal.calls.sendCallPush, {
        callId: args.callId,
        calleeId: args.calleeId,
        callerId: args.callerId,
        callerName: args.callerName,
        // Already lens-checked against the CALLEE in `calls.initiate` — the
        // same value the native ringer would have drawn, forwarded so the
        // rescue banner is not the one call surface with a faceless caller.
        callerAvatarUrl: args.callerAvatarUrl ?? undefined,
        type: args.type,
        roomId: args.roomId,
      });
    }
  },
});

// Sent to callee iOS devices to dismiss a ringing CallKit card with
// `.answeredElsewhere`, even on a killed app where the in-app `taken` signal
// can't be delivered in time. Two uses:
//   - A sibling device accepted/rejected → pass that device's id as
//     `excludeDeviceId` so it doesn't dismiss its own (now-active) call.
//   - The caller cancelled, or the ring timed out / got stuck → pass
//     `excludeDeviceId: null` to clear the ringer on EVERY callee device.
export const sendVoipTaken = internalAction({
  args: {
    callId: v.id("calls"),
    // Whose devices to clear the native card on. Historically only ever the
    // callee (accept/reject/cancel/expire all dismiss the ringer on the
    // callee's other devices), but `calls.end` and `gcStuckActive` also need
    // to clear an *active* call's card on either side — so this is just
    // "the user whose native call UI should be dismissed," not necessarily
    // the original callee.
    targetUserId: v.id("users"),
    excludeDeviceId: v.optional(v.union(v.string(), v.null())),
    // Embedded verbatim in the native push payload (see `payload` below) —
    // a literal union so a typo is a schema-validation error at the call
    // site, not a silently-wrong string reaching CallKit/ConnectionService.
    reason: v.union(
      v.literal("accepted"),
      v.literal("rejected"),
      v.literal("cancelled"),
      v.literal("timeout"),
      v.literal("ended"),
      v.literal("stuck"),
    ),
    // `false` drops the APNs/PushKit leg and keeps FCM. Set by
    // `calls.endCallImpl` when every iOS card for this call is known to
    // live in a process that gets the realtime signal — there a VoIP push
    // cannot dismiss anything, and PushKit's report-every-push contract
    // turns it into a one-second phantom "Call" ring (see the comment at
    // the call site). Absent means true: every other sender may be
    // clearing a card in a killed process, which only PushKit can reach.
    iosVoip: v.optional(v.boolean()),
  },
  handler: async (ctx, args) => {
    // Annotated at the USE site, not just on the query.
    //
    // `internal` is typed from `fullApi`, which includes `typeof voipPush` —
    // this whole module, this action included. Resolving that needs the
    // module's type, which needs this line's type: a cycle TypeScript ends by
    // making the lot `any`. Declaring the type here needs nothing from
    // `internal` and so cannot participate in the cycle. Without it `devices`
    // is `any[]`, every `.map((d) => …)` below loses its parameter type, and
    // `d.apnsEnv` resolves on legacy rows that have never had one.
    const devices: DeviceRow[] = await ctx.runQuery(internal.voipPush._loadUserDevices, {
      userId: args.targetUserId,
    });
    // Any device with a native token, exactly like the invite fan-out in
    // sendVoip — pushToDevice picks APNs or FCM per device and skips
    // simulators itself. This used to require `voipToken`, which quietly
    // excluded every Android handset: their ringer was never dismissed after
    // the call was answered elsewhere, and CallFcmService.handleTaken (which
    // exists solely to service this push) was dead code.
    //
    // Devices that already acked their card gone (`calls.ackNativeDismissed`
    // during the scheduling grace — see `calls.TAKEN_PUSH_GRACE_MS`) have
    // nothing for this push to end, and on iOS a `taken` with nothing to end
    // is a phantom ring. Skip them.
    const dismissedIds: string[] = await ctx.runQuery(
      internal.calls.dismissedDevicesInternal,
      { callId: args.callId },
    );
    const targets = selectTakenTargets(devices, {
      excludeDeviceId: args.excludeDeviceId,
      iosVoip: args.iosVoip ?? true,
      dismissed: new Set(dismissedIds),
    });
    if (targets.length === 0) {
      console.log(
        `sendVoipTaken: nothing to dismiss for call ${args.callId} (${args.reason}) — every device excluded or acked`,
      );
      return;
    }
    const payload = {
      kind: "taken",
      callId: args.callId.toString(),
      reason: args.reason,
    };
    await Promise.allSettled(
      targets.map((d) => pushToDevice(ctx, args.targetUserId, d, payload)),
    );
  },
});

/**
 * Which of [devices] a `taken` push goes to. Pure, so the selection rules
 * are unit-testable without a push transport:
 *   - never the device that settled the call (`excludeDeviceId`);
 *   - never a device that acked its card already gone (`dismissed`);
 *   - with `iosVoip: false` the PushKit leg is stripped off the DEVICE row
 *     rather than checked inside pushToDevice — the row is what a
 *     transient-failure retry (`retryPushToDevice`) is scheduled with, so
 *     stripping it here is what makes the retry honour the decision too;
 *   - and only rows that still have a channel left after all that.
 */
export function selectTakenTargets(
  devices: DeviceRow[],
  opts: {
    excludeDeviceId: string | null | undefined;
    iosVoip: boolean;
    dismissed: ReadonlySet<string>;
  },
): DeviceRow[] {
  return devices
    .filter((d) => d.deviceId !== opts.excludeDeviceId)
    .filter((d) => !opts.dismissed.has(d.deviceId))
    .map((d) => (opts.iosVoip ? d : { ...d, voipToken: undefined }))
    .filter((d) => d.voipToken || d.fcmToken);
}

/**
 * One push destination, in the two shapes `_loadUserDevices` can produce:
 * a row from `userDevices`, or the pre-`userDevices` fallback that reads the
 * tokens straight off the user document. `legacy` is the discriminant, and it
 * is why `deviceRowId` is nullable — a legacy row has no device row for the
 * dead-token sweep in `pushToDevice` to clear.
 *
 * Named, and declared as `_loadUserDevices`'s return type, because the actions
 * below cannot infer it. They read the query back through
 * `internal.voipPush._loadUserDevices`, and `internal` is typed from `fullApi`
 * — which includes this whole module, those actions included. TypeScript ends
 * that cycle by making the lot `any`: `devices` became `any[]`, every
 * `.map((d) => …)` lost its parameter type, and `d.apnsEnv` resolved happily on
 * legacy rows that have never had one.
 *
 * Annotating the query alone does NOT fix that — the cycle is over the module,
 * not over one function — which is why each `ctx.runQuery` call site below
 * declares `DeviceRow[]` too. That annotation needs nothing from `internal`, so
 * it cannot be part of the cycle. This type is what both ends name.
 */
type DeviceRow =
  | {
      deviceRowId: Id<"userDevices">;
      legacy: false;
      deviceId: string;
      platform: string;
      voipToken?: string;
      apnsEnv?: ApnsEnv;
      fcmToken?: string;
    }
  | {
      deviceRowId: null;
      legacy: true;
      deviceId: string;
      platform: string;
      voipToken?: string;
      apnsEnv?: ApnsEnv;
      fcmToken?: string;
    };

// Re-attempts a single device after a transient APNs/FCM failure (429/5xx).
// Scheduled once from pushToDevice with isRetry=true so it can't loop; ~2s
// keeps the second attempt well inside the 60s ring window.
export const retryPushToDevice = internalAction({
  args: {
    userId: v.id("users"),
    device: v.any(),
    payload: v.any(),
  },
  returns: v.null(),
  handler: async (ctx, { userId, device, payload }) => {
    // Ring-path guard, mirroring `sendVoip`: an invite retry fires ~2s after
    // the first attempt, easily long enough to cross a cancel/accept. Re-ring
    // only if the call is still ringing. `taken` retries are exempt — a
    // dismissal is always safe (and wanted) to re-send. If the guard skips,
    // the original invite either never delivered (nothing to dismiss) or the
    // terminal `taken` push already cleared the card.
    const kind = (payload as { kind?: string })?.kind;
    const callId = (payload as { callId?: string })?.callId;
    if (kind === "invite" && callId) {
      const status: string | null = await ctx.runQuery(
        internal.calls.callStatusInternal,
        { callId: callId as Id<"calls"> },
      );
      if (status !== "ringing") {
        console.log(
          `retryPushToDevice: invite for ${callId} no longer ringing (${status ?? "gone"}) — skipping retry`,
        );
        return null;
      }
    }
    // A `taken` retry is always safe to send — unless the device acked its
    // card gone in the meantime, in which case it is the phantom ring
    // `sendVoipTaken` just avoided. Same check, two seconds later.
    if (kind === "taken" && callId) {
      const dismissedIds: string[] = await ctx.runQuery(
        internal.calls.dismissedDevicesInternal,
        { callId: callId as Id<"calls"> },
      );
      const deviceId = (device as DeviceRow).deviceId;
      if (dismissedIds.includes(deviceId)) {
        console.log(
          `retryPushToDevice: taken for ${callId} — device ${deviceId} acked dismissal, skipping retry`,
        );
        return null;
      }
    }
    await pushToDevice(ctx, userId, device as DeviceRow, payload, {
      isRetry: true,
    });
    return null;
  },
});

const TRANSIENT_RETRY_DELAY_MS = 2000;

// Returns true when at least one channel (APNs / FCM) accepted the push
// for this device — sendVoip uses this to trigger the alert rescue when NO
// device could be reached natively.
async function pushToDevice(
  ctx: any,
  userId: Id<"users">,
  d: DeviceRow,
  payload: Record<string, unknown>,
  opts: { isRetry?: boolean } = {},
): Promise<boolean> {
  let delivered = false;
  // One retry per device per push; scheduled at most once from below.
  let scheduledRetry = false;
  const scheduleRetry = async () => {
    if (opts.isRetry || scheduledRetry) return;
    scheduledRetry = true;
    await ctx.scheduler.runAfter(
      TRANSIENT_RETRY_DELAY_MS,
      internal.voipPush.retryPushToDevice,
      { userId, device: d, payload },
    );
  };
  // Skip simulator rows for APNs (PushKit doesn't reach simulators); the
  // realtime subscription path covers them.
  if (d.voipToken && d.platform !== "ios-simulator") {
    try {
      await sendApnsVoip(ctx, d.voipToken, payload, d.apnsEnv);
      delivered = true;
      console.log(
        `sendVoip: APNs OK device=${d.deviceId} env=${d.apnsEnv ?? "default"}`,
      );
    } catch (e) {
      const msg = e instanceof Error ? e.message : String(e);
      console.error(`sendVoip: APNs failed device=${d.deviceId}: ${msg}`);
      // Apple replies 410 (Unregistered) or 400 BadDeviceToken when the token
      // has been revoked — usually after we miss the iOS 13+ 5-second
      // `reportNewIncomingCall` deadline once too often. Clear just this
      // device's token; siblings keep theirs.
      if (msg.startsWith("APNS_BAD_TOKEN")) {
        if (!d.legacy) {
          await ctx.runMutation(
            internal.voipTokens.clearVoipTokenForDeviceInternal,
            { deviceRowId: d.deviceRowId },
          );
        } else {
          await ctx.runMutation(
            internal.voipTokens.clearLegacyVoipTokenInternal,
            { userId },
          );
        }
        console.warn(
          `sendVoip: cleared voipToken device=${d.deviceId} after ${msg}`,
        );
      } else if (msg.startsWith("APNS_MISCONFIG")) {
        // Server-side: bad/expired APNs key, wrong team/bundle, or 401/403.
        // Every call will fail until an operator fixes env config — make it
        // loud and never clear the (perfectly valid) device token.
        console.error(
          `CALL_PUSH_MISCONFIG: APNs cannot send — fix deployment env. ${msg}`,
        );
      } else if (msg.startsWith("APNS_TRANSIENT")) {
        // APNs blip (429/5xx): keep the token and try this device once more
        // in ~2s — a ring is time-critical, "next call" is too late.
        await scheduleRetry();
      }
      // Any other error: keep the token, retry next call.
    }
  }
  if (d.fcmToken) {
    try {
      await sendFcmData(ctx, d.fcmToken, payload);
      delivered = true;
      console.log(`sendVoip: FCM OK device=${d.deviceId}`);
    } catch (e) {
      const msg = e instanceof Error ? e.message : String(e);
      console.error(`sendVoip: FCM failed device=${d.deviceId}: ${msg}`);
      if (msg.startsWith("FCM_BAD_TOKEN")) {
        if (!d.legacy) {
          await ctx.runMutation(
            internal.voipTokens.clearFcmTokenForDeviceInternal,
            { deviceRowId: d.deviceRowId },
          );
        } else {
          await ctx.runMutation(
            internal.voipTokens.clearLegacyFcmTokenInternal,
            { userId },
          );
        }
        console.warn(
          `sendVoip: cleared fcmToken device=${d.deviceId} after ${msg}`,
        );
      } else if (msg.startsWith("FCM_MISCONFIG")) {
        // Server-side: missing/invalid service account or 401/403. Loud,
        // and never clear the valid device token.
        console.error(
          `CALL_PUSH_MISCONFIG: FCM cannot send — fix deployment env. ${msg}`,
        );
      } else if (msg.startsWith("FCM_TRANSIENT")) {
        // FCM blip (429/5xx): same single in-ring-window retry as APNs.
        await scheduleRetry();
      }
      // Any other error: keep the token, retry next call.
    }
  }
  return delivered;
}

// ────────────────────────── transport adapters ──────────────────────────

async function sendApnsVoip(
  ctx: any,
  voipToken: string,
  payload: Record<string, unknown>,
  apnsEnv?: ApnsEnv,
): Promise<void> {
  // An invite is only meaningful inside the 30s ring window; a "taken"
  // dismissal must chase a reconnecting device longer, or its CallKit ringer
  // lingers as a ghost.
  const expirationSeconds = payload.kind === "taken" ? 60 : 30;
  // Collapse the invite and its own `taken` onto ONE APNs id (the callId), so
  // that when a device is briefly unreachable APNs keeps only the LATEST push
  // for the call: a `taken` posted while the invite is still pending overwrites
  // it, and the device never rings a call that is already over. Live delivery
  // is unaffected (nothing to coalesce). Distinct calls keep distinct ids.
  const collapseId =
    typeof payload.callId === "string" ? payload.callId : undefined;
  await apnsPost(ctx, {
    token: voipToken,
    env: apnsEnv,
    topicSuffix: ".voip",
    pushType: "voip",
    priority: "10",
    expiration: Math.floor(Date.now() / 1000) + expirationSeconds,
    collapseId,
    // A PushKit payload has no `aps` — the whole body is ours.
    body: payload,
  });
}

async function sendFcmData(
  ctx: any,
  fcmToken: string,
  payload: Record<string, unknown>,
): Promise<void> {
  // Same coalescing as the APNs side: key the invite and its `taken` to one
  // `collapse_key` (the callId) so FCM, when the handset is in Doze/offline
  // with both queued, delivers only the latest — a `taken` supersedes the
  // still-queued invite and the phone never full-screen-rings a dead call on
  // reconnect. FCM caps distinct collapse keys at 4, but only PENDING messages
  // count, so per-call keys are fine.
  const collapseKey =
    typeof payload.callId === "string" ? payload.callId : undefined;
  await fcmPost(ctx, {
    token: fcmToken,
    data: stringifyValues(payload),
    android: {
      priority: "high",
      ttl: "60s",
      ...(collapseKey ? { collapse_key: collapseKey } : {}),
    },
  });
}
