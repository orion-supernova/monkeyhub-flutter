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
import { liveSessionDeviceIds } from "./sessionCore";

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
      // Ring only handsets that are still signed in. The filter is applied
      // INSIDE this branch on purpose: a user whose every row is stale must
      // come back empty rather than fall through to the legacy fallback
      // below, which would resurrect the very pushes this stops. See
      // [liveSessionDeviceIds].
      const live = await liveSessionDeviceIds(ctx, userId);
      return rows
        .filter((r) => live.has(r.deviceId))
        .map((r) => ({
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

/**
 * Ring every invitee's phones for a GROUP call.
 *
 * The 1:1 twin above addresses one callee and one call row; this addresses a
 * list of people and a `groupCallParticipants` row each, which is the only
 * structural difference. Everything below the fan-out — transport choice per
 * device, the three error classes, dead-credential clearing, the single retry
 * — is `pushToDevice`, shared and unchanged.
 *
 * The card's identity is DERIVED from the groupCallId rather than minted here
 * (`uuidForCallId` on Android, `derivedCallUuid` on iOS, `derivedUuid` in
 * Dart — all three are UUIDv3 over the same bytes and are pinned against each
 * other by test/call_native_uuid_test.dart). A minted id would have to be
 * carried to whoever later needs to dismiss the card, and the process holding
 * it is precisely the one that may not exist any more.
 *
 * Falls back to the ordinary banner, per invitee, for anyone no native
 * transport could reach.
 */
export const sendGroupVoip = internalAction({
  args: {
    groupCallId: v.id("groupCalls"),
    roomId: v.id("rooms"),
    inviteeIds: v.array(v.id("users")),
    starterName: v.string(),
    roomName: v.string(),
    type: v.string(),
    /** `{ [inviteeId]: { data: { senderAvatarUrl } } }` — see `start`. */
    perUser: v.optional(v.any()),
  },
  handler: async (ctx, args) => {
    // Ring-path guard, exactly as `sendVoip` has: this is scheduled
    // runAfter(0) with the payload precomputed, so it can execute after an
    // invitee has already joined elsewhere, declined, or the call has ended.
    const pending: string[] = await ctx.runQuery(
      internal.groupCalls._pendingInvitees,
      { groupCallId: args.groupCallId, userIds: args.inviteeIds },
    );
    if (pending.length === 0) {
      console.log(
        `sendGroupVoip: nobody left to ring for ${args.groupCallId} — skipping`,
      );
      return;
    }

    const unreached: Id<"users">[] = [];
    await Promise.allSettled(
      pending.map(async (raw) => {
        const userId = raw as Id<"users">;
        const devices: DeviceRow[] = await ctx.runQuery(
          internal.voipPush._loadUserDevices,
          { userId },
        );
        if (devices.length === 0) {
          unreached.push(userId);
          return;
        }
        const payload = {
          kind: "group_invite",
          groupCallId: args.groupCallId.toString(),
          roomId: args.roomId.toString(),
          // Who is calling, and where — in the one field both native ringers
          // title their card with. A group call belongs to the room, not to
          // whoever pressed the button, but the person deciding whether to
          // answer wants both facts and the CallKit card has exactly one
          // line to put them on; Android draws the same line under the
          // starter's face. The handle stays the room: it is what the card's
          // identity is keyed on, and it is what `roomName` below still says
          // on its own for anyone who wants the parts.
          callerName: groupCallerName(args.starterName, args.roomName),
          callerHandle: args.roomName,
          roomName: args.roomName,
          starterName: args.starterName,
          // Android's full-screen ringer renders this URL as the caller
          // avatar (plugin `avatar` field, wired in CallFcmService). Already
          // lens-checked against THIS invitee in `groupCalls.start`.
          callerAvatarUrl:
            (args.perUser ?? {})[raw]?.data?.senderAvatarUrl ?? "",
          callType: args.type,
        };
        const results = await Promise.allSettled(
          devices.map((d) => pushToDevice(ctx, userId, d, payload)),
        );
        if (!results.some((r) => r.status === "fulfilled" && r.value === true)) {
          unreached.push(userId);
        }
      }),
    );

    if (unreached.length > 0) {
      console.warn(
        `sendGroupVoip: no native push delivered for ${unreached.length} invitee(s) — banner rescue`,
      );
      await ctx.scheduler.runAfter(
        0,
        internal.groupCalls.sendGroupInvitePush,
        {
          groupCallId: args.groupCallId,
          roomId: args.roomId,
          inviteeIds: unreached,
          starterName: args.starterName,
          roomName: args.roomName,
          type: args.type,
          perUser: args.perUser,
        },
      );
    }
  },
});

/**
 * "Ayşe · Design Crew" — the line a group ring titles its native card with.
 * The overlay in lib/app.dart composes the same line for the card a
 * foregrounded Android app raises itself, so the two read identically.
 */
export function groupCallerName(starterName: string, roomName: string): string {
  return `${starterName} · ${roomName}`;
}

/**
 * Take a group call's native ringer down on [targetUserIds]' devices.
 *
 * The group twin of `sendVoipTaken`, and simpler in one way that matters:
 * there is no "answered elsewhere" to report on iOS, because a group call is
 * not answered — it is joined, and it goes on without you. The card is ended
 * on both platforms and the person is left with the room banner, which is the
 * quiet join surface for exactly this case.
 *
 * `excludeDeviceId` spares the phone that settled the invite: its card is
 * already gone, and on iOS a `taken` with nothing to end is a one-second
 * phantom ring rather than a no-op. Devices that acked their card gone during
 * the scheduling grace (`groupCalls.ackNativeDismissed`, recorded while
 * `dismissRingers` waits `TAKEN_PUSH_GRACE_MS`) are skipped for the same
 * reason — that is every live app, which ends its own card the instant the
 * invite leaves `pendingInviteForUser`.
 *
 * `iosVoip` is always true here, on purpose. The 1:1 `endCallImpl` can drop
 * the PushKit leg because the peer of an ACTIVE call is mid-WebRTC and never
 * had an invite card; a group `taken` only ever targets someone still
 * `invited`, or the settler's other phones, and either can be a card sitting
 * in a killed process that only PushKit can reach. The ack list, not a
 * blanket skip, is what keeps this from ringing a phantom.
 */
export const sendGroupVoipTaken = internalAction({
  args: {
    groupCallId: v.id("groupCalls"),
    targetUserIds: v.array(v.id("users")),
    excludeDeviceId: v.optional(v.union(v.string(), v.null())),
    reason: v.union(
      v.literal("joined"),
      v.literal("declined"),
      v.literal("ended"),
      v.literal("timeout"),
    ),
  },
  handler: async (ctx, args) => {
    const payload = {
      kind: "group_taken",
      groupCallId: args.groupCallId.toString(),
      reason: args.reason,
    };
    const dismissedIds: string[] = await ctx.runQuery(
      internal.groupCalls.dismissedDevicesInternal,
      { groupCallId: args.groupCallId },
    );
    const dismissed = new Set(dismissedIds);
    let sent = 0;
    await Promise.allSettled(
      args.targetUserIds.map(async (userId) => {
        const devices: DeviceRow[] = await ctx.runQuery(
          internal.voipPush._loadUserDevices,
          { userId },
        );
        const targets = selectTakenTargets(devices, {
          excludeDeviceId: args.excludeDeviceId,
          iosVoip: true,
          dismissed,
        });
        sent += targets.length;
        await Promise.allSettled(
          targets.map((d) => pushToDevice(ctx, userId, d, payload)),
        );
      }),
    );
    if (sent === 0) {
      console.log(
        `sendGroupVoipTaken: nothing to dismiss for ${args.groupCallId} (${args.reason}) — every device excluded or acked`,
      );
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
 *   - a device that acked its card already gone (`dismissed`) loses its
 *     PushKit leg and KEEPS its FCM one. The ack exists for iOS alone, where
 *     a `taken` with no card left to end is a phantom ring; on Android
 *     `CallFcmService.handleTaken` ending an id that is not showing is a
 *     no-op. And the ack is a claim, not a proof: on 2026-10-07 a cancelled
 *     call left an iPhone AND a Galaxy ringing after both had acked, and the
 *     push that skipped them was the one thing that could have stopped the
 *     Galaxy. A harmless push to a device that was right beats a skipped
 *     push to one that was wrong;
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
    .map((d) =>
      opts.iosVoip && !opts.dismissed.has(d.deviceId)
        ? d
        : { ...d, voipToken: undefined },
    )
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
    const groupCallId = (payload as { groupCallId?: string })?.groupCallId;
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
    // A `taken` retry is always safe to send — except on the PushKit leg of a
    // device that acked its card gone in the meantime, which would be the
    // phantom ring `sendVoipTaken` just avoided. Same rule as
    // `selectTakenTargets`, two seconds later: the FCM leg still goes.
    let target = device as DeviceRow;
    if (kind === "taken" && callId) {
      const dismissedIds: string[] = await ctx.runQuery(
        internal.calls.dismissedDevicesInternal,
        { callId: callId as Id<"calls"> },
      );
      const deviceId = target.deviceId;
      if (dismissedIds.includes(deviceId)) {
        target = { ...target, voipToken: undefined };
        if (!target.fcmToken) {
          console.log(
            `retryPushToDevice: taken for ${callId} — device ${deviceId} acked dismissal, skipping retry`,
          );
          return null;
        }
      }
    }
    // The group twins of both guards. These were missing: a `group_invite`
    // retry re-rang a call that had ended in the two seconds since, and a
    // `group_taken` retry had no ack list to consult.
    if (kind === "group_invite" && groupCallId) {
      const pending: string[] = await ctx.runQuery(
        internal.groupCalls._pendingInvitees,
        { groupCallId: groupCallId as Id<"groupCalls">, userIds: [userId] },
      );
      if (pending.length === 0) {
        console.log(
          `retryPushToDevice: group invite for ${groupCallId} no longer pending — skipping retry`,
        );
        return null;
      }
    }
    if (kind === "group_taken" && groupCallId) {
      const dismissedIds: string[] = await ctx.runQuery(
        internal.groupCalls.dismissedDevicesInternal,
        { groupCallId: groupCallId as Id<"groupCalls"> },
      );
      const deviceId = target.deviceId;
      if (dismissedIds.includes(deviceId)) {
        target = { ...target, voipToken: undefined };
        if (!target.fcmToken) {
          console.log(
            `retryPushToDevice: group taken for ${groupCallId} — device ${deviceId} acked dismissal, skipping retry`,
          );
          return null;
        }
      }
    }
    await pushToDevice(ctx, userId, target, payload, {
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

/**
 * The one id an invite and its own `taken` share on the wire — the APNs
 * `apns-collapse-id` and the FCM `collapse_key` — so that when a device is
 * briefly unreachable the transport keeps only the LATEST push for the call:
 * a `taken` posted while the invite is still pending overwrites it, and the
 * device never rings a call that is already over. Live delivery is unaffected
 * (nothing to coalesce). Distinct calls keep distinct ids.
 *
 * A 1:1 call is keyed by its `callId`, a group call by its `groupCallId`. The
 * second half was missing: group pushes carry no `callId`, so a queued
 * `group_invite` was never superseded by its `group_taken`, and a phone back
 * from Doze full-screen-rang a call that had ended minutes earlier, then
 * dismissed it. Pure, so the pairing is pinned by voipPush.test.ts.
 */
export function voipCollapseId(
  payload: Record<string, unknown>,
): string | undefined {
  if (typeof payload.callId === "string") return payload.callId;
  if (typeof payload.groupCallId === "string") return payload.groupCallId;
  return undefined;
}

/**
 * How long the transport may hold a push for an unreachable device. An
 * invite is only meaningful inside its ring window; a dismissal must chase a
 * reconnecting device longer, or its CallKit ringer lingers as a ghost — for
 * a group card, one that then rings out its full minute and posts a missed
 * call for a call nobody is in. Both kinds of `taken` get the longer window.
 */
export function voipExpirySeconds(payload: Record<string, unknown>): number {
  return payload.kind === "taken" || payload.kind === "group_taken" ? 60 : 30;
}

async function sendApnsVoip(
  ctx: any,
  voipToken: string,
  payload: Record<string, unknown>,
  apnsEnv?: ApnsEnv,
): Promise<void> {
  await apnsPost(ctx, {
    token: voipToken,
    env: apnsEnv,
    topicSuffix: ".voip",
    pushType: "voip",
    priority: "10",
    expiration: Math.floor(Date.now() / 1000) + voipExpirySeconds(payload),
    collapseId: voipCollapseId(payload),
    // A PushKit payload has no `aps` — the whole body is ours.
    body: payload,
  });
}

async function sendFcmData(
  ctx: any,
  fcmToken: string,
  payload: Record<string, unknown>,
): Promise<void> {
  // Same coalescing as the APNs side — see `voipCollapseId`. FCM caps
  // distinct collapse keys at 4, but only PENDING messages count, so per-call
  // keys are fine.
  const collapseKey = voipCollapseId(payload);
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
