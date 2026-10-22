import {
  internalAction,
  internalMutation,
  internalQuery,
} from "./_generated/server";
import { action, mutation, query } from "./functions";
import { internal } from "./_generated/api";
import { v } from "convex/values";
import type { Doc, Id } from "./_generated/dataModel";
import { childMayReach, childPolicyOf } from "./childGuard";
import { assertNoSystemAccount } from "./systemAccount";
import { assertRoomAllowsById } from "./roomPolicy";
import { lensFor } from "./visibility";
import { consume } from "./rateLimit";
import { getLiveUser, isTombstoned } from "./deletionCore";

// ────────────────────────────── helpers ──────────────────────────────

const CALL_RING_TIMEOUT_MS = 30 * 1000; // missed after 30s un-answered

// A `ringing` row older than this is a scheduler orphan (the 30s expire
// never fired); `initiate`'s busy check reaps it inline rather than
// refusing with BUSY. Twice the ring timeout, well before gcStuckRinging.
const BUSY_RINGING_STALE_MS = 60 * 1000;

// Every terminal transition chases its realtime signal with a native `taken`
// push, so a card in a KILLED process — the invite VoIP push rang it and its
// subscription never attached — still gets dismissed. A LIVE process
// dismisses its own card from the signal within a few hundred milliseconds
// and then has nothing left for the push to end; on iOS a PushKit push with
// nothing to end must still report a call, which surfaces as a one-second
// phantom "Call" that rings and vanishes (AppDelegate.reportAndEndCall).
// So the push waits this long first, and `voipPush.sendVoipTaken` skips every
// device that acked its dismissal (`ackNativeDismissed`) in the meantime. A
// dead process pays the grace on top of its ring; a live one never sees the
// push. Sized for the slow path — signal delivery, the native end-call
// round-trip and the ack mutation on a loaded backend — not the typical one.
export const TAKEN_PUSH_GRACE_MS = 3000;

type TakenPushArgs = {
  callId: Id<"calls">;
  targetUserId: Id<"users">;
  excludeDeviceId: string | null;
  reason: "accepted" | "rejected" | "cancelled" | "timeout" | "ended" | "stuck";
  iosVoip?: boolean;
};

// The one way a native `taken` push gets scheduled — see TAKEN_PUSH_GRACE_MS.
async function scheduleTakenPush(ctx: any, args: TakenPushArgs) {
  // Android first, and now: the grace is for iOS's phantom ring, which an
  // FCM `taken` cannot cause, and it held every killed or backgrounded
  // Android ring three seconds past a cancel. See `sendVoipTaken.fcmOnly`.
  await ctx.scheduler.runAfter(0, internal.voipPush.sendVoipTaken, {
    ...args,
    fcmOnly: true,
  });
  await ctx.scheduler.runAfter(
    TAKEN_PUSH_GRACE_MS,
    internal.voipPush.sendVoipTaken,
    args,
  );
}

async function isPairBlocked(
  ctx: any,
  a: any,
  b: any,
): Promise<boolean> {
  const ab = await ctx.db
    .query("blocks")
    .withIndex("by_pair", (q: any) => q.eq("userId", a).eq("blockedUserId", b))
    .first();
  if (ab) return true;
  const ba = await ctx.db
    .query("blocks")
    .withIndex("by_pair", (q: any) => q.eq("userId", b).eq("blockedUserId", a))
    .first();
  return !!ba;
}

// `nativeClearNeedsPush` used to live here, gating cancel/end's "taken"
// dismissal push on the target USER reading `effectiveStatus === "online"`.
// Removed: the CallKit card is per-DEVICE, so a user whose laptop kept them
// "online" got no push at all while their iPhone's card sat orphaned — and
// worse, iOS reports `inactive` (which writes NO presence) the whole time a
// CallKit card is up, so the exact device the push exists for is also the
// one whose staleness the gate misread as "online" for up to 3 minutes.
// These were the ONLY two gated paths (accept/reject/expire/gc always
// pushed) — precisely the cancel-leaves-stale-CallKit report. The cost of
// always sending is a report-then-immediately-end on a device that has no
// card left in-process — which turned out NOT to be invisible: iOS shows it
// as a one-second phantom "Call". That is what the scheduling grace, the
// dismissal ack and `iosVoip` below are for (see TAKEN_PUSH_GRACE_MS);
// `reportCallEndedElsewhere` dismisses cleanly whenever a card is live.

// Shared terminal transition: mark ended, notify the peer over realtime
// (`bye`) AND native push (`taken`), purge everything else. Used by `end`,
// by `cancel` when it loses the race to an accept, and by the busy-check
// reaper in `initiate`.
async function endCallImpl(ctx: any, call: any, byUserId: any) {
  // Read BEFORE the patch below flips it: this is the state the peer's
  // native card is in, and it decides whether a VoIP push can help it.
  const wasRinging = call.status === "ringing";
  await ctx.db.patch(call._id, {
    status: "ended",
    endedAt: Date.now(),
  });
  const peer =
    call.callerId.toString() === byUserId.toString()
      ? call.calleeId
      : call.callerId;
  const peerIsCallee = peer.toString() === call.calleeId.toString();
  const sigId = await ctx.db.insert("callSignals", {
    callId: call._id,
    fromUserId: byUserId,
    toUserId: peer,
    kind: "bye",
    payload: "{}",
    createdAt: Date.now(),
    consumed: false,
  });
  await purgeCallSignals(ctx, call._id, sigId);
  // Clear the peer's native CallKit/ConnectionService card too. Without
  // this, a peer whose app is backgrounded/killed never learns the call
  // ended — the realtime `bye` above only reaches a live subscription —
  // and their native call UI is orphaned "active" indefinitely.
  //
  // The PushKit leg is sent ONLY when the peer is the callee of a call that
  // was still ringing — the one case where an iOS card can outlive the app
  // that showed it (the invite VoIP push rings a killed process, whose
  // subscription never attaches). Everywhere else the card belongs to a
  // live process that receives the `bye` above and dismisses it itself:
  //   - the peer of an ACTIVE call is mid-WebRTC, which keeps the process
  //     (and its subscription) alive, and CallKit drops the card with the
  //     process if that ever dies;
  //   - a CALLER never gets an invite push at all — their outbound card
  //     exists only inside the process that placed the call.
  // A VoIP push landing on an iOS device with no card left for this call
  // has exactly one effect: PushKit's every-push-must-report contract makes
  // AppDelegate report-and-end a placeholder call, which iOS renders as a
  // one-second incoming "Call" that rings and vanishes — a phantom on
  // EVERY remote hangup. FCM keeps going regardless (Android's handleTaken
  // is a no-op for a card it never showed).
  await scheduleTakenPush(ctx, {
    callId: call._id,
    targetUserId: peer,
    excludeDeviceId: null,
    reason: "ended",
    iosVoip: peerIsCallee && wasRinging,
  });
}

// Body of `expireRingingCall`, factored so `initiate`'s busy check can
// reap a scheduler-orphaned ringing row inline instead of refusing with
// BUSY for a call that died a minute ago.
async function expireRingingImpl(ctx: any, call: any) {
  await ctx.db.patch(call._id, {
    status: "missed",
    endedAt: Date.now(),
  });
  // Notify both sides so their UI can transition out of ringing. Both
  // signals are kept by [purgeCallSignals] so each peer sees its own.
  const sigToCallee = await ctx.db.insert("callSignals", {
    callId: call._id,
    fromUserId: call.callerId,
    toUserId: call.calleeId,
    kind: "cancel",
    payload: '{"reason":"timeout"}',
    createdAt: Date.now(),
    consumed: false,
  });
  const sigToCaller = await ctx.db.insert("callSignals", {
    callId: call._id,
    fromUserId: call.calleeId,
    toUserId: call.callerId,
    kind: "reject",
    payload: '{"reason":"timeout"}',
    createdAt: Date.now(),
    consumed: false,
  });
  await purgeCallSignals(ctx, call._id, [sigToCallee, sigToCaller]);
  // Dismiss the callee's native CallKit ringer on timeout — the realtime
  // "cancel" signal above can't reach a locked/killed device.
  await scheduleTakenPush(ctx, {
    callId: call._id,
    targetUserId: call.calleeId,
    excludeDeviceId: null,
    reason: "timeout",
  });
}

// Per-call body of `gcStuckActive`, factored for the same reason: an
// abandoned `active` row must not BUSY-block a fresh call for the sweep
// cadence (worst case ~8 minutes of "you can't call each other").
async function reapActiveCall(ctx: any, call: any) {
  await ctx.db.patch(call._id, {
    status: "ended",
    endedAt: Date.now(),
  });
  // Either side's native card could be the orphaned one (the abandoned
  // device, or a live peer whose app never heard the other side vanish) —
  // drop a bye signal and clear the native card for both.
  for (const [fromUserId, toUserId] of [
    [call.callerId, call.calleeId],
    [call.calleeId, call.callerId],
  ]) {
    await ctx.db.insert("callSignals", {
      callId: call._id,
      fromUserId,
      toUserId,
      kind: "bye",
      payload: '{"reason":"stuck"}',
      createdAt: Date.now(),
      consumed: false,
    });
    await scheduleTakenPush(ctx, {
      callId: call._id,
      targetUserId: toUserId,
      excludeDeviceId: null,
      reason: "stuck",
    });
  }
}

/**
 * End every live 1:1 call in [roomId]. Room deletion.
 *
 * One `by_room_status` range per live status. Each call ends through
 * `endCallImpl` (the callee gets `bye` and the `taken` push, with the PushKit
 * leg if it was still ringing) and the caller is sent a `bye` of its own,
 * since `endCallImpl` only addresses the peer. Bounded: a user is on at most
 * one live call, so a room has a handful at most.
 */
export async function endLiveCallsInRoom(ctx: any, roomId: any) {
  for (const status of ["ringing", "active"]) {
    const rows = await ctx.db
      .query("calls")
      .withIndex("by_room_status", (q: any) =>
        q.eq("roomId", roomId).eq("status", status),
      )
      .take(50);
    for (const call of rows) {
      await endCallImpl(ctx, call, call.callerId);
      await ctx.db.insert("callSignals", {
        callId: call._id,
        fromUserId: call.calleeId,
        toUserId: call.callerId,
        kind: "bye",
        payload: '{"reason":"room_deleted"}',
        createdAt: Date.now(),
        consumed: false,
      });
    }
  }
}

async function assertCallParticipant(ctx: any, callId: any, userId: any) {
  const call = await ctx.db.get(callId);
  if (!call) throw new Error("CALL_NOT_FOUND");
  const u = userId.toString();
  if (call.callerId.toString() !== u && call.calleeId.toString() !== u) {
    throw new Error("NOT_A_PARTICIPANT");
  }
  return call;
}

// Cascade delete every signal for [callId] except any id in [keep] (the
// terminal bye/reject/cancel/taken signals we just inserted, which a
// subscriber still needs to see). Called after every terminal-state
// transition so late-arriving ICE candidates can't race into a re-entered
// session.
//
// DEFERRED, never inline. The sweep has to read the whole `by_call` index
// range, and a Convex mutation whose read set covers a range conflicts with
// EVERY concurrent insert into it — which is exactly what `sendSignal` does,
// continuously, while a call is up (ICE trickles for the whole life of a
// video call). Run inside `end`, the purge lost OCC to `sendSignal` four
// times in a row, backed off past half a second, and then failed outright
// (2026-08-31 10:17 TR, home server); the caller's hangup took 5.5 s to
// land and one side's `end` threw. The terminal mutation itself now touches
// only the `calls` row and the terminal signal it inserts, so nothing it
// reads overlaps a `sendSignal` write. The sweep runs a beat later, by which
// point `sendSignal` sees the terminal status and drops everything — so it
// converges on its first or second try instead of racing a live stream.
// Signals a peer sees in that beat are for a call whose `bye` already tore
// its session down, and `handleRemoteSignal` ignores them.
async function purgeCallSignals(
  ctx: any,
  callId: any,
  keep?: any | any[],
) {
  const keepIds: any[] = [];
  if (Array.isArray(keep)) {
    for (const k of keep) if (k) keepIds.push(k);
  } else if (keep) {
    keepIds.push(keep);
  }
  await ctx.scheduler.runAfter(0, internal.calls.purgeCallSignalsInternal, {
    callId,
    keepIds,
  });
}

// The sweep behind [purgeCallSignals]. Its own transaction, so its range
// read can lose OCC and retry without dragging a terminal transition along.
export const purgeCallSignalsInternal = internalMutation({
  args: {
    callId: v.id("calls"),
    keepIds: v.array(v.id("callSignals")),
  },
  returns: v.null(),
  handler: async (ctx, { callId, keepIds }) => {
    const keep = new Set(keepIds.map((k) => k.toString()));
    const rows = await ctx.db
      .query("callSignals")
      .withIndex("by_call", (q: any) => q.eq("callId", callId))
      .collect();
    for (const r of rows) {
      if (keep.has(r._id.toString())) continue;
      await ctx.db.delete(r._id);
    }
    return null;
  },
});

// Retires every untargeted, still-unconsumed row to the callee that was
// written while the call rang — the rows `heldFrom` kept visible to
// all of the callee's devices. Bounded by [acceptedAt]: anything newer is
// live-call traffic. The `taken` row `accept` itself inserted stays: siblings
// still need it to stop ringing.
//
// Retired means addressed to [acceptingDeviceId], not consumed. Consuming
// them hid the offer and the caller's early ICE from the device that had
// just answered whenever its subscription had not delivered them yet (an
// accept off the invite alone, or a Mac a beat behind): it answered nothing,
// or answered with no candidates, and the call sat on "connecting" with
// both self-previews up (2026-10-21). Targeted, the answering device still
// reads them and its siblings skip them. Only a client that never sent a
// device id falls back to the old consume.
export const retireRingPhaseSignalsInternal = internalMutation({
  args: {
    callId: v.id("calls"),
    calleeId: v.id("users"),
    acceptedAt: v.number(),
    acceptingDeviceId: v.optional(v.string()),
  },
  returns: v.null(),
  handler: async (ctx, { callId, calleeId, acceptedAt, acceptingDeviceId }) => {
    const rows = await ctx.db
      .query("callSignals")
      .withIndex("by_call", (q: any) => q.eq("callId", callId))
      .collect();
    for (const r of rows) {
      if (r.consumed || r.targetDeviceId || r.kind === "taken") continue;
      if (r.createdAt > acceptedAt) continue;
      if (r.toUserId.toString() !== calleeId.toString()) continue;
      await ctx.db.patch(
        r._id,
        acceptingDeviceId
          ? { targetDeviceId: acceptingDeviceId }
          : { consumed: true },
      );
    }
    return null;
  },
});

// ────────────────────────── initiate / lifecycle ──────────────────────────

export const initiate = mutation({
  // The caller is spelled `callerId` here, so the wrapper is told to inject
  // under that name. Without this the arg stayed CLIENT-SUPPLIED and
  // trusted — on `respondToDeviceLoginRequest` that meant approving a
  // sign-in as anybody.
  identityArg: "callerId" as const,
  args: {
    callerId: v.id("users"),
    calleeId: v.id("users"),
    roomId: v.id("rooms"),
    type: v.string(), // "audio" | "video"
    // The dialing device. Optional for older clients; `sendSignal` learns
    // it from their first signal instead. See `calls.callerDeviceId`.
    callerDeviceId: v.optional(v.string()),
  },
  handler: async (ctx, { callerId, calleeId, roomId, type, callerDeviceId }) => {
    if (callerId.toString() === calleeId.toString()) {
      throw new Error("CANNOT_CALL_SELF");
    }
    // A ring is a full-screen interruption on someone else's phone. Calling,
    // cancelling and calling again used to ring them without limit.
    await consume(ctx, `ring:${callerId}:${calleeId}`, 3, 2 * 60 * 1000);
    await consume(ctx, `ringh:${callerId}`, 30, 60 * 60 * 1000);
    if (type !== "audio" && type !== "video") throw new Error("BAD_CALL_TYPE");

    // Nobody rings an account being deleted (its devices are already gone).
    if (!(await getLiveUser(ctx, calleeId))) throw new Error("USER_NOT_FOUND");

    // A system account has no device to ring. The membership check below would
    // pass for the report DM — both parties really are in it — and the call would
    // sit ringing until `expireRingingCall` swept it, having reached nothing.
    await assertNoSystemAccount(ctx, callerId, calleeId);

    // Honor block list — generic error so we don't reveal who blocked whom.
    if (await isPairBlocked(ctx, callerId, calleeId)) {
      throw new Error("CALL_FAILED");
    }

    // Child guard, both directions. A child can only be on a call with family
    // or an approved contact, and only while calls are switched on for them.
    // Same generic error as a block, for the same reason: the other party
    // learns nothing about why.
    for (const [a, b] of [
      [callerId, calleeId],
      [calleeId, callerId],
    ]) {
      const policy = await childPolicyOf(ctx, a);
      if (policy === null) continue;
      if (!policy.callsEnabled) throw new Error("CALL_FAILED");
      if (!(await childMayReach(ctx, a, b))) throw new Error("CALL_FAILED");
    }

    // Membership sanity check: both users must belong to the room.
    const callerMembership = await ctx.db
      .query("roomMembers")
      .withIndex("by_room_user", (q) =>
        q.eq("roomId", roomId).eq("userId", callerId),
      )
      .first();
    const calleeMembership = await ctx.db
      .query("roomMembers")
      .withIndex("by_room_user", (q) =>
        q.eq("roomId", roomId).eq("userId", calleeId),
      )
      .first();
    if (!callerMembership || !calleeMembership) {
      throw new Error("NOT_A_MEMBER");
    }

    // The room's posting policy: a room that takes no calls takes none
    // between two of its members either. See `roomPolicy.ts`.
    await assertRoomAllowsById(ctx, roomId, callerId, { actions: ["call"] });

    // Reject if either user is already in a live call (ringing / active) —
    // with a staleness allowance: a row every sweeper would agree is dead
    // (scheduler-orphaned ring, heartbeat-silent active call) is reaped
    // HERE instead of blocking the fresh call for the sweep cadence, which
    // used to mean up to ~8 minutes of BUSY after a crash.
    const busyNow = Date.now();
    for (const uid of [callerId, calleeId]) {
      const liveRows = [
        await ctx.db
          .query("calls")
          .withIndex("by_callee_status", (q) =>
            q.eq("calleeId", uid).eq("status", "ringing"),
          )
          .first(),
        await ctx.db
          .query("calls")
          .withIndex("by_callee_status", (q) =>
            q.eq("calleeId", uid).eq("status", "active"),
          )
          .first(),
        await ctx.db
          .query("calls")
          .withIndex("by_caller_status", (q) =>
            q.eq("callerId", uid).eq("status", "ringing"),
          )
          .first(),
        await ctx.db
          .query("calls")
          .withIndex("by_caller_status", (q) =>
            q.eq("callerId", uid).eq("status", "active"),
          )
          .first(),
      ];
      for (const live of liveRows) {
        if (!live) continue;
        if (
          live.status === "ringing" &&
          live.startedAt < busyNow - BUSY_RINGING_STALE_MS
        ) {
          // The 30s expireRingingCall never fired (backend restart, lost
          // schedule) — twice the ring timeout gone means nobody is ringing.
          await expireRingingImpl(ctx, live);
          continue;
        }
        if (live.status === "active") {
          const lastSeen =
            live.lastHeartbeatAt ?? live.acceptedAt ?? live.startedAt;
          if (lastSeen < busyNow - STUCK_ACTIVE_MS) {
            await reapActiveCall(ctx, live);
            continue;
          }
        }
        throw new Error("BUSY");
      }
    }

    const caller = await ctx.db.get(callerId);
    const callerName = caller?.name ?? caller?.username ?? "Someone";
    // Caller identity for the callee's ringer UIs. The storage id feeds the
    // in-app screens (RemoteImage); the resolved URL feeds Android's native
    // full-screen ringer, which can only load plain image URLs.
    //
    // Both obey the caller's own avatar setting, resolved from the CALLEE's
    // side — the ringer is the one surface that pushes a face onto a screen
    // uninvited, so it is the last place to make an exception. The name is
    // always sent: a ringing phone has to say who it is.
    const callerLens = await lensFor(ctx, calleeId);
    const callerAvatarVisible = caller ? callerLens.canSee(caller, "avatar") : false;
    const callerAvatarStorageId = callerAvatarVisible
      ? caller?.avatarStorageId?.toString() ?? null
      : null;
    const callerAvatarUrl =
      callerAvatarVisible && caller?.avatarStorageId
        ? await ctx.storage.getUrl(caller.avatarStorageId)
        : null;

    const callId = await ctx.db.insert("calls", {
      callerId,
      calleeId,
      roomId,
      type,
      status: "ringing",
      startedAt: Date.now(),
      callerDeviceId: callerDeviceId ?? undefined,
    });

    // Surface an "invite" signal IMMEDIATELY. Every callee device with an
    // active `signalsForUser` subscription receives it within ~50–150ms,
    // which lets the in-app IncomingCallScreen open before the caller has
    // finished getUserMedia/createOffer (otherwise the screen waits for
    // the `offer` signal — adds 500ms+ on first call). The eventual offer
    // hydrates the same session (see CallService._onRemoteOffer).
    await ctx.db.insert("callSignals", {
      callId,
      fromUserId: callerId,
      toUserId: calleeId,
      kind: "invite",
      payload: JSON.stringify({
        callerName,
        type,
        roomId: roomId.toString(),
        callerAvatarStorageId,
        callerAvatarUrl,
      }),
      createdAt: Date.now(),
      consumed: false,
    });

    // The alert banner (`sendCallPush`) is deliberately NOT scheduled here.
    // It used to be, gated on a per-device "do all phones have native tokens"
    // check — and any tokenless sibling row (stale reinstall, Android without
    // an fcmToken, a token not yet uploaded) opened that gate and
    // banner-notified the very iPhone that was already ringing through
    // CallKit. A double alert for one call.
    //
    // `voipPush.sendVoip` schedules it instead, and only once it knows no
    // device actually received the ring — which covers the all-tokenless
    // callee without ever duplicating CallKit.

    // Direct VoIP push (APNs PushKit + FCM data-only). This is what wakes a
    // *killed* app into the native CallKit / ConnectionService UI.
    await ctx.scheduler.runAfter(0, internal.voipPush.sendVoip, {
      callId,
      calleeId,
      callerId,
      callerName,
      callerAvatarUrl,
      type,
      roomId,
    });

    // Auto-mark as "missed" if still ringing after the timeout.
    await ctx.scheduler.runAfter(
      CALL_RING_TIMEOUT_MS,
      internal.calls.expireRingingCall,
      { callId },
    );

    return callId;
  },
});

export const accept = mutation({
  args: {
    callId: v.id("calls"),
    userId: v.id("users"),
    acceptingDeviceId: v.optional(v.string()),
  },
  // "accepted" | "not-ringing" — a late accept (the call already timed out,
  // was cancelled, or a sibling device settled it first) tells the client so
  // instead of throwing. Mirrors reject/cancel/end, which all resolve this
  // same stale-state race with a soft return instead of an uncaught error.
  returns: v.string(),
  handler: async (ctx, { callId, userId, acceptingDeviceId }) => {
    const call = await assertCallParticipant(ctx, callId, userId);
    if (call.calleeId.toString() !== userId.toString()) {
      throw new Error("ONLY_CALLEE_CAN_ACCEPT");
    }
    if (call.status !== "ringing") return "not-ringing";
    const acceptedAt = Date.now();
    await ctx.db.patch(callId, {
      status: "active",
      acceptedAt,
      // Recorded so sibling devices' active-call subscriptions can compare
      // against their own deviceId and render the "Move call here" pill.
      acceptingDeviceId: acceptingDeviceId ?? undefined,
    });
    // Tell every other device of the callee to dismiss its ringer. All
    // callee devices share the `toUserId == calleeId` subscription; the
    // accepting device filters its own echo via `byDeviceId`.
    await ctx.db.insert("callSignals", {
      callId,
      fromUserId: userId,
      toUserId: call.calleeId,
      kind: "taken",
      payload: JSON.stringify({
        reason: "accepted",
        byDeviceId: acceptingDeviceId ?? null,
      }),
      createdAt: Date.now(),
      consumed: false,
    });
    // The ring-phase rows every callee device was held to (see
    // `heldFrom`) have done their job; a device that comes online
    // now must not ring an answered call off them. Deferred for the same
    // OCC reason as `purgeCallSignals`: a `by_call` range read here would
    // conflict with the caller's ICE inserts.
    await ctx.scheduler.runAfter(
      0,
      internal.calls.retireRingPhaseSignalsInternal,
      {
        callId,
        calleeId: call.calleeId,
        acceptedAt,
        acceptingDeviceId: acceptingDeviceId ?? undefined,
      },
    );
    // For killed-iOS siblings (subscription not alive), fan a PushKit
    // payload with kind="taken" so CallKit can dismiss with
    // .answeredElsewhere. The accepting device is excluded.
    await scheduleTakenPush(ctx, {
      callId,
      targetUserId: call.calleeId,
      excludeDeviceId: acceptingDeviceId ?? null,
      reason: "accepted",
    });
    return "accepted";
  },
});

export const reject = mutation({
  args: {
    callId: v.id("calls"),
    userId: v.id("users"),
    acceptingDeviceId: v.optional(v.string()),
  },
  // "rejected" | "not-ringing" — a late reject (cancel or a sibling accept
  // already resolved the row) tells the client so instead of silently
  // no-oping; the reject path needs no fallback verb, so this is
  // informational.
  returns: v.string(),
  handler: async (ctx, { callId, userId, acceptingDeviceId }) => {
    const call = await assertCallParticipant(ctx, callId, userId);
    if (call.calleeId.toString() !== userId.toString()) {
      throw new Error("ONLY_CALLEE_CAN_REJECT");
    }
    if (call.status !== "ringing") return "not-ringing"; // idempotent
    await ctx.db.patch(callId, {
      status: "rejected",
      endedAt: Date.now(),
    });
    // Drop a terminal signal so the caller sees the rejection promptly.
    const sigToCaller = await ctx.db.insert("callSignals", {
      callId,
      fromUserId: userId,
      toUserId: call.callerId,
      kind: "reject",
      payload: "{}",
      createdAt: Date.now(),
      consumed: false,
    });
    // And tell sibling callee devices to dismiss their ringer.
    const sigToCallee = await ctx.db.insert("callSignals", {
      callId,
      fromUserId: userId,
      toUserId: call.calleeId,
      kind: "taken",
      payload: JSON.stringify({
        reason: "rejected",
        byDeviceId: acceptingDeviceId ?? null,
      }),
      createdAt: Date.now(),
      consumed: false,
    });
    await purgeCallSignals(ctx, callId, [sigToCaller, sigToCallee]);
    await scheduleTakenPush(ctx, {
      callId,
      targetUserId: call.calleeId,
      excludeDeviceId: acceptingDeviceId ?? null,
      reason: "rejected",
    });
    return "rejected";
  },
});

export const cancel = mutation({
  args: { callId: v.id("calls"), userId: v.id("users") },
  // "cancelled" | "ended" | "already-terminal". The middle one is the
  // accept/cancel race resolved server-side: the callee answered inside the
  // window, so the cancel auto-converts into a full end — the callee gets a
  // `bye` + taken push instead of being stranded `active` on a hot mic
  // while the caller's UI already hung up. (The old silent `return` on that
  // race left BOTH users BUSY-locked until the stuck-active sweep, up to
  // ~8 minutes.)
  returns: v.string(),
  handler: async (ctx, { callId, userId }) => {
    const call = await assertCallParticipant(ctx, callId, userId);
    if (call.callerId.toString() !== userId.toString()) {
      throw new Error("ONLY_CALLER_CAN_CANCEL");
    }
    if (call.status === "active") {
      await endCallImpl(ctx, call, userId);
      return "ended";
    }
    if (call.status !== "ringing") return "already-terminal";
    await ctx.db.patch(callId, {
      status: "cancelled",
      endedAt: Date.now(),
    });
    const sigId = await ctx.db.insert("callSignals", {
      callId,
      fromUserId: userId,
      toUserId: call.calleeId,
      kind: "cancel",
      payload: "{}",
      createdAt: Date.now(),
      consumed: false,
    });
    await purgeCallSignals(ctx, callId, sigId);
    // Dismiss the callee's native CallKit ringer too — unconditionally. A
    // locked/killed callee woken by the invite VoIP push has a suspended
    // realtime subscription, so the "cancel" signal above never reaches it;
    // only a "taken" VoIP push can clear the lingering ring. This used to
    // be gated on per-USER presence, but the card is per-DEVICE (a laptop
    // keeping the user "online" starved the iPhone's dismissal) and iOS
    // under a CallKit card reports `inactive`, which writes no presence at
    // all — the gate misread exactly the device it existed for. Fan to ALL
    // callee devices (no exclude).
    await scheduleTakenPush(ctx, {
      callId,
      targetUserId: call.calleeId,
      excludeDeviceId: null,
      reason: "cancelled",
    });
    return "cancelled";
  },
});

export const end = mutation({
  args: { callId: v.id("calls"), userId: v.id("users") },
  // "ended" | "already-terminal". The guard refuses ALL terminal states now
  // — the old one only refused ended/failed, so a late `end` (a device
  // whose accept lost a race) could overwrite `cancelled`→`ended` and, via
  // the purge inside, delete a sibling device's still-undelivered `cancel`
  // row — that sibling then rang for a dead call until touched.
  returns: v.string(),
  handler: async (ctx, { callId, userId }) => {
    const call = await assertCallParticipant(ctx, callId, userId);
    if (call.status !== "active" && call.status !== "ringing") {
      return "already-terminal";
    }
    await endCallImpl(ctx, call, userId);
    return "ended";
  },
});

export const expireRingingCall = internalMutation({
  args: { callId: v.id("calls") },
  returns: v.null(),
  handler: async (ctx, { callId }) => {
    const call = await ctx.db.get(callId);
    if (!call) return null;
    if (call.status !== "ringing") return null;
    await expireRingingImpl(ctx, call);
    return null;
  },
});

// ────────────────────────── signaling ──────────────────────────

export const sendSignal = mutation({
  args: {
    callId: v.id("calls"),
    fromUserId: v.id("users"),
    toUserId: v.id("users"),
    kind: v.string(),
    payload: v.string(),
    // Optional during handoff: deliver only to a specific recipient
    // device. Siblings of the same toUserId ignore the signal. See
    // SignalingSubscriber's targetDeviceId filter on the client.
    targetDeviceId: v.optional(v.string()),
    // Optional: the sending device's id. Lets the recipient learn which
    // device of the peer holds the call so it can target its own
    // outgoing signals back.
    fromDeviceId: v.optional(v.string()),
  },
  handler: async (
    ctx,
    {
      callId,
      fromUserId,
      toUserId,
      kind,
      payload,
      targetDeviceId,
      fromDeviceId,
    },
  ) => {
    const call = await assertCallParticipant(ctx, callId, fromUserId);
    // toUserId must be the other participant OR — during handoff — the
    // SAME user (handoff-takeover is sent to my own callee/caller userId
    // but targets a specific deviceId).
    const isHandoffToSelf =
      toUserId.toString() === fromUserId.toString() &&
      (kind === "handoff-takeover" || kind === "handoff-prepare");
    if (!isHandoffToSelf) {
      const expectedPeer =
        call.callerId.toString() === fromUserId.toString()
          ? call.calleeId.toString()
          : call.callerId.toString();
      if (toUserId.toString() !== expectedPeer) {
        throw new Error("WRONG_PEER");
      }
    }
    // Refuse signals for terminal calls. Late-arriving ICE candidates from a
    // slow network could otherwise repopulate rows after [purgeCallSignals]
    // already ran, and resurrect a dead call in the peer's subscription.
    if (call.status !== "ringing" && call.status !== "active") {
      return; // idempotent silent drop
    }
    // A caller on a build that predates `initiate`'s `callerDeviceId` names
    // its device on its first signal (the offer). One patch per call.
    if (
      !isHandoffToSelf &&
      fromDeviceId &&
      !call.callerDeviceId &&
      call.callerId.toString() === fromUserId.toString()
    ) {
      await ctx.db.patch(callId, { callerDeviceId: fromDeviceId });
    }
    await ctx.db.insert("callSignals", {
      callId,
      fromUserId,
      toUserId,
      kind,
      payload,
      createdAt: Date.now(),
      consumed: false,
      targetDeviceId: targetDeviceId ?? undefined,
      fromDeviceId: fromDeviceId ?? undefined,
    });
  },
});

// Transfer an active call from whichever device currently holds it to
// [newDeviceId]. The new device performs a fresh WebRTC negotiation with
// the peer; the old device tears down. See addendum design notes.
export const handoffCall = mutation({
  args: {
    callId: v.id("calls"),
    userId: v.id("users"),
    newDeviceId: v.string(),
  },
  handler: async (ctx, { callId, userId, newDeviceId }) => {
    const call = await assertCallParticipant(ctx, callId, userId);
    if (call.status !== "active") throw new Error("CALL_NOT_ACTIVE");
    // Each side's holder moves on its own field. This used to move
    // `acceptingDeviceId` for a caller too, which pointed the takeover at the
    // CALLEE's device (so the caller's old device never stood down) and left
    // the callee's siblings reading the caller's device as the callee's.
    const iAmCaller = call.callerId.toString() === userId.toString();
    const oldDeviceId = iAmCaller
      ? call.callerDeviceId
      : call.acceptingDeviceId;
    if (oldDeviceId === newDeviceId) {
      return { oldDeviceId: oldDeviceId ?? null };
    }
    await ctx.db.patch(
      callId,
      iAmCaller
        ? { callerDeviceId: newDeviceId }
        : { acceptingDeviceId: newDeviceId },
    );
    // Tell the old device (if known) to tear down its PC quietly. Only
    // it acts because the signal is targetDeviceId-scoped.
    if (oldDeviceId) {
      await ctx.db.insert("callSignals", {
        callId,
        fromUserId: userId,
        toUserId: userId, // same user, different device
        targetDeviceId: oldDeviceId,
        fromDeviceId: newDeviceId,
        kind: "handoff-takeover",
        payload: JSON.stringify({ newDeviceId }),
        createdAt: Date.now(),
        consumed: false,
      });
    }
    // Tell the peer to close its existing PC and expect a fresh offer
    // from the new device.
    const peerId =
      call.callerId.toString() === userId.toString()
        ? call.calleeId
        : call.callerId;
    await ctx.db.insert("callSignals", {
      callId,
      fromUserId: userId,
      toUserId: peerId,
      fromDeviceId: newDeviceId,
      kind: "handoff-prepare",
      payload: JSON.stringify({ newDeviceId }),
      createdAt: Date.now(),
      consumed: false,
    });
    return { oldDeviceId: oldDeviceId ?? null };
  },
});

export const signalsForUser = query({
  args: { userId: v.id("users") },
  handler: async (ctx, { userId }) => {
    const rows = await ctx.db
      .query("callSignals")
      .withIndex("by_to_unconsumed", (q) =>
        q.eq("toUserId", userId).eq("consumed", false),
      )
      .order("asc")
      .take(50);
    return rows.map((r) => ({
      _id: r._id,
      callId: r.callId,
      fromUserId: r.fromUserId,
      kind: r.kind,
      payload: r.payload,
      createdAt: r.createdAt,
      targetDeviceId: r.targetDeviceId ?? null,
      fromDeviceId: r.fromDeviceId ?? null,
    }));
  },
});

// Signals are consumed per USER, but a ringing call rings on every one of
// the callee's devices, and each needs the invite, the offer and the ICE
// that follow it. Consumed by whichever device drained first, a row vanished
// from every slower sibling's `signalsForUser` before it was read: a Mac
// throttled in the background rang late or never, and could not answer the
// offer it never saw. So while the call still rings, an untargeted row to
// the callee stays visible to all of them (each device dedupes what it has
// dispatched), and `accept` retires the lot once one device has it — see
// [retireRingPhaseSignalsInternal]. Terminal rows are not held: the purge
// deletes the ring-phase rows anyway, and every device watches
// `activeCallForUser` to stop ringing whoever consumed the `cancel`.
//
// The same race outlived the ring. Once a call is live it is held by ONE
// device per side (`acceptingDeviceId`, `callerDeviceId`), yet every sibling
// still drained — and consumed — the answer and ICE meant for that device,
// including the rows it skipped as someone else's. On 2026-10-21 a call
// answered on a Mac, with the callee's iPhone still awake from the VoIP
// push, never connected: both sides sat on their own preview. So a device
// that names itself ([deviceId]) may only consume what is its own: a row
// targeted at it, or an untargeted one on a side whose holder it is (or
// whose holder is unknown). Everything else it leaves for the holder; the
// purge at call end deletes what nobody consumed. A live call's `taken`
// is held from everyone: it is the siblings' ring dismissal, and the
// accepting device draining its own echo first used to take it from them.
// A client that sends no device id keeps the old per-user consume.
async function heldFrom(
  ctx: any,
  sig: Doc<"callSignals">,
  deviceId: string | undefined,
) {
  const call: Doc<"calls"> | null = await ctx.db.get(sig.callId);
  if (!call) return false;
  const toCallee = call.calleeId.toString() === sig.toUserId.toString();
  if (!sig.targetDeviceId && toCallee && call.status === "ringing") {
    return true;
  }
  if (!deviceId) return false;
  // Terminal rows go to whoever drains them: a holder that died would
  // otherwise leave them unconsumed for a day, ahead of the next call's
  // invite in `signalsForUser`'s oldest-first window.
  if (call.status !== "ringing" && call.status !== "active") return false;
  if (sig.targetDeviceId) return sig.targetDeviceId !== deviceId;
  if (sig.kind === "taken") return call.status === "active";
  const holder = toCallee ? call.acceptingDeviceId : call.callerDeviceId;
  return !!holder && holder !== deviceId;
}

export const consumeSignal = mutation({
  args: {
    signalId: v.id("callSignals"),
    userId: v.id("users"),
    deviceId: v.optional(v.string()),
  },
  handler: async (ctx, { signalId, userId, deviceId }) => {
    const sig = await ctx.db.get(signalId);
    if (!sig) return;
    if (sig.toUserId.toString() !== userId.toString()) {
      throw new Error("NOT_RECIPIENT");
    }
    if (await heldFrom(ctx, sig, deviceId)) return;
    await ctx.db.patch(signalId, { consumed: true });
  },
});

export const consumeSignals = mutation({
  args: {
    signalIds: v.array(v.id("callSignals")),
    userId: v.id("users"),
    // The draining device. See [heldFrom].
    deviceId: v.optional(v.string()),
  },
  returns: v.null(),
  handler: async (ctx, { signalIds, userId, deviceId }) => {
    for (const signalId of signalIds) {
      const sig = await ctx.db.get(signalId);
      // Missing rows are fine — GC or purge may have raced us.
      if (!sig) continue;
      if (sig.toUserId.toString() !== userId.toString()) continue;
      if (sig.consumed) continue;
      if (await heldFrom(ctx, sig, deviceId)) continue;
      await ctx.db.patch(signalId, { consumed: true });
    }
  },
});

export const activeCallForUser = query({
  args: { userId: v.id("users") },
  handler: async (ctx, { userId }) => {
    // Resolves to my live `ringing` or `active` call so the UI can re-attach
    // after a cold start. Active calls (the more interesting state for the
    // global "Move call here" pill) are checked first.
    // `Doc<"calls"> | null`, not `any`. The `any` here spread: `peerId` became
    // `any`, `ctx.db.get(peerId)` fell back to the union of EVERY table's
    // document type, and `peer.name` stopped resolving — on a line whose whole
    // job is reading a name.
    let call: Doc<"calls"> | null = null;
    outer: for (const status of ["active", "ringing"] as const) {
      const asCallee = await ctx.db
        .query("calls")
        .withIndex("by_callee_status", (q) =>
          q.eq("calleeId", userId).eq("status", status),
        )
        .first();
      if (asCallee) {
        call = asCallee;
        break outer;
      }
      const asCaller = await ctx.db
        .query("calls")
        .withIndex("by_caller_status", (q) =>
          q.eq("callerId", userId).eq("status", status),
        )
        .first();
      if (asCaller) {
        call = asCaller;
        break outer;
      }
    }
    if (!call) return null;
    // Hydrate peer display fields so the pill doesn't need a second
    // round-trip. Peer = the participant who isn't me.
    const peerId =
      call.callerId.toString() === userId.toString()
        ? call.calleeId
        : call.callerId;
    const peer = await ctx.db.get(peerId);
    // The other side is being deleted: its call rows go in the first teardown
    // step, and until then there is nothing to re-attach to.
    if (isTombstoned(peer)) return null;
    const peerName = peer?.name ?? peer?.username ?? "Unknown";
    // The deviceName for the device currently holding the call — for the
    // "Move call here · On Bob's MacBook" label. Falls back to platform.
    let acceptingDeviceName: string | null = null;
    let acceptingPlatform: string | null = null;
    if (call.acceptingDeviceId) {
      // Captured into consts before the index callback. `call` is a `let`, so
      // TypeScript discards the narrowing from the guard above the moment the
      // value is read inside a closure — it cannot prove nothing reassigns
      // `call` in between. Nothing does, but the fix is to stop asking it to
      // prove that rather than to assert past it.
      const { calleeId, acceptingDeviceId } = call;
      const dev = await ctx.db
        .query("userDevices")
        .withIndex("by_user_device", (q) =>
          q.eq("userId", calleeId).eq("deviceId", acceptingDeviceId),
        )
        .first();
      if (dev) {
        acceptingDeviceName = dev.deviceName ?? null;
        acceptingPlatform = dev.platform;
      }
    }
    return {
      _id: call._id,
      callerId: call.callerId,
      calleeId: call.calleeId,
      roomId: call.roomId,
      type: call.type,
      status: call.status,
      startedAt: call.startedAt,
      acceptedAt: call.acceptedAt,
      acceptingDeviceId: call.acceptingDeviceId ?? null,
      peerName,
      acceptingDeviceName,
      acceptingPlatform,
    };
  },
});

// ────────────────────────── ICE config ──────────────────────────
// Returns the iceServers list the client should hand to RTCPeerConnection.
// Always includes Google's public STUN. If TURN_URL + TURN_SECRET are set in
// Convex env, generates short-lived TURN REST API credentials (HMAC-SHA1 of
// "<unix-ts + ttl>:<userId>", 1 hour validity). Coturn must be running with
// `use-auth-secret` + the matching `static-auth-secret`.
/**
 * Spends one TURN credential from [userId]'s hourly budget. Credentials are
 * a relay on our server, and any account could mint them on a loop with no
 * call in sight; a real user fetches one per call attempt.
 */
export const spendIceQuota = internalMutation({
  args: { userId: v.id("users") },
  handler: async (ctx, { userId }) => {
    await consume(ctx, `ice:${userId}`, MAX_ICE_CONFIGS_PER_HOUR, 60 * 60 * 1000);
  },
});

const MAX_ICE_CONFIGS_PER_HOUR = 60;

export const getIceConfig = action({
  args: { userId: v.id("users") },
  handler: async (ctx, { userId }) => {
    await ctx.runMutation(internal.calls.spendIceQuota, { userId });
    const stun = [
      { urls: "stun:stun.l.google.com:19302" },
      { urls: "stun:stun1.l.google.com:19302" },
    ];
    const turnUrl = process.env.TURN_URL;
    const turnSecret = process.env.TURN_SECRET;
    if (!turnUrl || !turnSecret) {
      return { iceServers: stun };
    }
    const ttlSeconds = 3600;
    const expiry = Math.floor(Date.now() / 1000) + ttlSeconds;
    const username = `${expiry}:${userId.toString()}`;
    const credential = await hmacSha1Base64(turnSecret, username);
    // TURN_URL may be a comma-separated list, e.g.
    // "turn:1.2.3.4:3478?transport=udp,turn:1.2.3.4:3478?transport=tcp"
    // — the TCP variant reaches clients on UDP-blocked networks.
    const urls = turnUrl
      .split(",")
      .map((u) => u.trim())
      .filter((u) => u.length > 0);
    return {
      iceServers: [
        ...stun,
        {
          urls: urls.length === 1 ? urls[0] : urls,
          username,
          credential,
        },
      ],
    };
  },
});

async function hmacSha1Base64(secret: string, message: string): Promise<string> {
  const enc = new TextEncoder();
  const key = await crypto.subtle.importKey(
    "raw",
    enc.encode(secret),
    { name: "HMAC", hash: "SHA-1" },
    false,
    ["sign"],
  );
  const sig = await crypto.subtle.sign("HMAC", key, enc.encode(message));
  const bytes = new Uint8Array(sig);
  let bin = "";
  for (let i = 0; i < bytes.byteLength; i++) {
    bin += String.fromCharCode(bytes[i]);
  }
  // btoa is available in Convex's V8 runtime.
  return btoa(bin);
}

// ────────────────────────── push (wakes the callee) ──────────────────────────

/**
 * A plain banner naming the caller — the rescue path, not the normal one.
 *
 * A 1:1 call rings through CallKit/ConnectionService via `voipPush.sendVoip`.
 * This is only scheduled when that failed for every one of the callee's
 * devices, which in practice means a device whose PushKit token was revoked
 * while its ordinary alert token is still good. `calls.initiate` deliberately
 * does NOT send it alongside the ring: an iPhone that is already ringing does
 * not also want a notification about it.
 */
export const sendCallPush = internalAction({
  args: {
    callId: v.id("calls"),
    calleeId: v.id("users"),
    callerId: v.id("users"),
    callerName: v.string(),
    callerAvatarUrl: v.optional(v.string()),
    type: v.string(),
    roomId: v.id("rooms"),
  },
  handler: async (
    ctx,
    { callId, calleeId, callerId, callerName, callerAvatarUrl, type, roomId },
  ) => {
    // Ring-path guard: this rescue is scheduled from `voipPush.sendVoip` only
    // after every native push failed, which can be a second or more after
    // initiate — long enough for a cancel/accept/reject to have ended the
    // call. Don't alert about a call that is no longer ringing.
    const status: string | null = await ctx.runQuery(
      internal.calls.callStatusInternal,
      { callId },
    );
    if (status !== "ringing") {
      console.log(
        `sendCallPush: call ${callId} no longer ringing (${status ?? "gone"}) — skipping alert`,
      );
      return;
    }
    const verb = type === "video" ? "Video call" : "Voice call";
    await ctx.runAction(internal.push.sendAlert, {
      userIds: [calleeId],
      kind: "call_invite",
      title: callerName,
      body: `${verb} from ${callerName}`,
      data: {
        kind: "call_invite",
        callId: callId.toString(),
        callerId: callerId.toString(),
        callerName,
        callType: type,
        roomId: roomId.toString(),
      },
      roomId,
      // A second invite for the same call replaces the first rather than
      // stacking a second banner on the lock screen.
      collapseId: callId.toString(),
      // The caller's face, under the SAME key the chat path uses so iOS's
      // extension and the payload contract each have one branch instead of two
      // (ios/NotificationService/NotificationService.swift).
      //
      // There is exactly one recipient here, so the shared `data` block would
      // be equivalent today — but `senderAvatarUrl` travelling per-recipient is
      // an invariant with no exceptions anywhere else, and an exception is what
      // somebody copies the day this action grows a second callee.
      perUser: callerAvatarUrl
        ? { [calleeId.toString()]: { data: { senderAvatarUrl: callerAvatarUrl } } }
        : undefined,
    });
  },
});

// ────────────────────────── GC sweeps ──────────────────────────
// These run on a schedule from crons.ts. Each one bounds its work with
// `.take(200)` so a single tick can't run away — if more is pending, the
// next tick picks it up.

const CONSUMED_SIGNAL_RETENTION_MS = 60 * 1000;      // 1 min
const TERMINAL_CALL_RETENTION_MS = 24 * 60 * 60 * 1000; // 1 day
const STUCK_RINGING_MS = 90 * 1000;                  // 90s safety net

// Delete callSignals where consumed=true and createdAt is older than 1 min.
export const gcConsumedSignals = internalMutation({
  args: {},
  handler: async (ctx) => {
    const cutoff = Date.now() - CONSUMED_SIGNAL_RETENTION_MS;
    // Index-backed: by_consumed = (consumed, createdAt) hits exactly the
    // consumed=true partition older than the cutoff — no table scan.
    // Cap each run at 200 deletes; the next tick picks up the rest.
    const rows = await ctx.db
      .query("callSignals")
      .withIndex("by_consumed", (q) =>
        q.eq("consumed", true).lt("createdAt", cutoff),
      )
      .take(200);
    for (const r of rows) {
      await ctx.db.delete(r._id);
    }
    if (rows.length > 0) {
      console.log(`gcConsumedSignals: deleted ${rows.length} row(s)`);
    }
  },
});

// Delete terminal-status calls older than 1 day, plus any of their lingering
// signals (defense in depth — purgeCallSignals should have already cleaned
// them at terminal time).
export const gcTerminalCalls = internalMutation({
  args: {},
  handler: async (ctx) => {
    const cutoff = Date.now() - TERMINAL_CALL_RETENTION_MS;
    const terminal = ["ended", "rejected", "cancelled", "missed", "failed"];
    let totalDeleted = 0;
    for (const status of terminal) {
      const rows = await ctx.db
        .query("calls")
        .withIndex("by_status_started", (q) =>
          q.eq("status", status).lt("startedAt", cutoff),
        )
        .take(50);
      for (const call of rows) {
        // Cascade — sweep any signals that survived purge-on-terminal.
        const sigs = await ctx.db
          .query("callSignals")
          .withIndex("by_call", (q: any) => q.eq("callId", call._id))
          .collect();
        for (const sig of sigs) await ctx.db.delete(sig._id);
        await ctx.db.delete(call._id);
        totalDeleted++;
      }
    }
    if (totalDeleted > 0) {
      console.log(`gcTerminalCalls: deleted ${totalDeleted} call(s)`);
    }
  },
});

// Safety net for `ringing` calls older than 90s. The per-call scheduled
// `expireRingingCall` should have fired at 30s; this catches the edge case
// where a backend restart or scheduler failure left a call ringing forever.
export const gcStuckRinging = internalMutation({
  args: {},
  handler: async (ctx) => {
    const cutoff = Date.now() - STUCK_RINGING_MS;
    const rows = await ctx.db
      .query("calls")
      .withIndex("by_status_started", (q) =>
        q.eq("status", "ringing").lt("startedAt", cutoff),
      )
      .take(50);
    for (const call of rows) {
      await ctx.db.patch(call._id, {
        status: "missed",
        endedAt: Date.now(),
      });
      // Drop terminal signals so each side's UI clears.
      await ctx.db.insert("callSignals", {
        callId: call._id,
        fromUserId: call.callerId,
        toUserId: call.calleeId,
        kind: "cancel",
        payload: '{"reason":"stuck"}',
        createdAt: Date.now(),
        consumed: false,
      });
      await ctx.db.insert("callSignals", {
        callId: call._id,
        fromUserId: call.calleeId,
        toUserId: call.callerId,
        kind: "reject",
        payload: '{"reason":"stuck"}',
        createdAt: Date.now(),
        consumed: false,
      });
      // Clear any native CallKit ringer still up on a locked/killed callee.
      await scheduleTakenPush(ctx, {
        callId: call._id,
        targetUserId: call.calleeId,
        excludeDeviceId: null,
        reason: "timeout",
      });
    }
    if (rows.length > 0) {
      console.log(`gcStuckRinging: rescued ${rows.length} call(s)`);
    }
  },
});

// Client pings this every ~20s while status is "active" (see
// CallService's heartbeat timer). Powers `gcStuckActive` below — an active
// call with no recent heartbeat from either side is treated as abandoned.
export const heartbeat = mutation({
  args: { callId: v.id("calls"), userId: v.id("users") },
  // "ok" | "not-in-call" — mirrors groupCalls:heartbeat; a beat against a
  // terminal call tells the client its call is over even if every signal
  // was missed.
  returns: v.string(),
  handler: async (ctx, { callId, userId }) => {
    const call = await assertCallParticipant(ctx, callId, userId);
    if (call.status !== "active") return "not-in-call";
    await ctx.db.patch(callId, { lastHeartbeatAt: Date.now() });
    return "ok";
  },
});

// Safety net for `active` calls abandoned by both sides without either ever
// calling `end` (app crash, dead battery, OS jetsam killing the process
// outright). Unlike `gcStuckRinging`, staleness can't be judged from
// `startedAt` alone — calls legitimately run for a long time — so this keys
// off `lastHeartbeatAt` (falling back to `acceptedAt`/`startedAt` for a call
// that's never received one, e.g. one that went stale within the first
// heartbeat interval). Generous cutoff vs. the ~20s client interval, same
// backstop posture as `gcStuckRinging`.
const STUCK_ACTIVE_MS = 3 * 60 * 1000; // 3 min without a heartbeat

export const gcStuckActive = internalMutation({
  args: {},
  returns: v.null(),
  handler: async (ctx) => {
    const cutoff = Date.now() - STUCK_ACTIVE_MS;
    // Range-filtered on `by_status_heartbeat`: Convex orders rows with an
    // unset `lastHeartbeatAt` BEFORE any set value, so `.lt(cutoff)` covers
    // both never-heartbeat calls (judged below by their fallback
    // timestamps) and stale-heartbeat ones — while rows beating recently
    // fall outside the range entirely. The old unfiltered `.take(50)` over
    // ALL active rows could starve stale calls forever behind healthy
    // ones once >50 calls were live at once.
    const rows = await ctx.db
      .query("calls")
      .withIndex("by_status_heartbeat", (q) =>
        q.eq("status", "active").lt("lastHeartbeatAt", cutoff),
      )
      .take(200);
    let rescued = 0;
    for (const call of rows) {
      const lastSeen =
        call.lastHeartbeatAt ?? call.acceptedAt ?? call.startedAt;
      if (lastSeen >= cutoff) continue;
      rescued++;
      await reapActiveCall(ctx, call);
    }
    if (rescued > 0) {
      console.log(`gcStuckActive: rescued ${rescued} call(s)`);
    }
    return null;
  },
});

// One-shot status probe used by the client to validate a native CallKit
// card before honoring accept/decline on it — a ghost card (call already
// cancelled/missed while the app was dead) must be dismissed, not answered.
// Participants only; null when the call row has been GC'd.
export const getCallStatus = query({
  args: { callId: v.id("calls"), userId: v.id("users") },
  returns: v.union(v.null(), v.object({ status: v.string() })),
  handler: async (ctx, { callId, userId }) => {
    const call = await ctx.db.get(callId);
    if (!call) return null;
    const u = userId.toString();
    if (call.callerId.toString() !== u && call.calleeId.toString() !== u) {
      return null;
    }
    return { status: call.status };
  },
});

// Internal, no participant check: read a call's status so the fire-and-forget
// VoIP push actions (`voipPush.sendVoip`, its retry, and the alert rescue) can
// re-confirm the call is still `ringing` before they RING a device. Those
// actions are scheduled `runAfter(0)` at initiate with every payload field
// precomputed, so they can execute AFTER a fast cancel/accept/reject has
// already flipped the row terminal — and nothing between the schedule and the
// send re-reads it. The result is the "ghost ring": a native card that appears
// for a call that is already over, then gets dismissed a beat later by the
// chasing `taken` push. Guarding the ring path on this closes the window.
// Returns the status string, or null when the row is gone (GC'd).
export const callStatusInternal = internalQuery({
  args: { callId: v.id("calls") },
  returns: v.union(v.null(), v.string()),
  handler: async (ctx, { callId }) => {
    const call = await ctx.db.get(callId);
    return call?.status ?? null;
  },
});

// ────────────────────── native-card dismissal acks ──────────────────────

// A device reports that its native call card for [callId] is gone — it ended
// the card itself from the realtime terminal signal (or never showed one).
// Recorded so the grace-delayed `taken` push (`scheduleTakenPush`) leaves
// that device alone; see TAKEN_PUSH_GRACE_MS for why that matters on iOS.
// Idempotent, and a GC'd row is fine: there is nothing left to push about.
// A callee device has its ringer up: stamp the row and tell the caller,
// whose screen goes from "calling" to "ringing" and whose ringback starts.
// The first report wins; later ones (a second device, the in-app report
// racing the native one) and reports for a call no longer ringing are no-ops.
async function markRingingImpl(ctx: any, call: any) {
  if (call.status !== "ringing" || call.ringingAt !== undefined) return;
  const now = Date.now();
  await ctx.db.patch(call._id, { ringingAt: now });
  await ctx.db.insert("callSignals", {
    callId: call._id,
    fromUserId: call.calleeId,
    toUserId: call.callerId,
    kind: "ringing",
    payload: "{}",
    createdAt: now,
    consumed: false,
  });
}

// The in-app report: a ringer Dart raised itself, or CallKit up while the
// app is in the foreground. Only the callee can say their phone is ringing.
export const markRinging = mutation({
  args: { callId: v.id("calls"), userId: v.id("users") },
  returns: v.null(),
  handler: async (ctx, { callId, userId }) => {
    const call = await ctx.db.get(callId);
    if (!call) return null;
    if (call.calleeId.toString() !== userId.toString()) {
      throw new Error("NOT_THE_CALLEE");
    }
    await markRingingImpl(ctx, call);
    return null;
  },
});

// The native report, from `/calls/ringing` (http.ts) once the signed ring
// proof has checked out. The signature already names the callee.
//
// Answers with the call's status (null: GC'd, or not this callee's call), and
// the endpoint hands it straight back to the phone. That answer is the
// native-side guarantee against the ghost ring: an invite VoIP push that
// lands AFTER the cancel (APNs held it; the app had already dismissed nothing
// and acked, so no `taken` push is coming) raises a card for a dead call, and
// nothing in Dart may be alive to end it. The phone posts this report the
// moment its card is up and ends the card itself on anything but "ringing"
// (AppDelegate.reportRinging).
export const markRingingInternal = internalMutation({
  args: { callId: v.id("calls"), userId: v.id("users") },
  returns: v.union(v.null(), v.string()),
  handler: async (ctx, { callId, userId }) => {
    const call = await ctx.db.get(callId);
    if (!call || call.calleeId.toString() !== userId.toString()) return null;
    await markRingingImpl(ctx, call);
    return call.status;
  },
});

// The read-only twin, for the phone's native ring watch: while a card rings
// un-answered, AppDelegate re-posts the same signed proof with `probe: true`
// every couple of seconds and ends the card the moment the answer is not
// "ringing". That is what takes a card down when the Dart side is not there
// to (a process PushKit launched and Flutter never attached in) or acked a
// dismissal it should not have. A query, so a watch costs no writes.
export const ringStatusInternal = internalQuery({
  args: { callId: v.id("calls"), userId: v.id("users") },
  returns: v.union(v.null(), v.string()),
  handler: async (ctx, { callId, userId }) => {
    const call = await ctx.db.get(callId);
    if (!call || call.calleeId.toString() !== userId.toString()) return null;
    return call.status;
  },
});

export const ackNativeDismissed = mutation({
  args: {
    callId: v.id("calls"),
    userId: v.id("users"),
    deviceId: v.string(),
  },
  returns: v.null(),
  handler: async (ctx, { callId, userId, deviceId }) => {
    const call = await ctx.db.get(callId);
    if (!call) return null;
    const u = userId.toString();
    if (call.callerId.toString() !== u && call.calleeId.toString() !== u) {
      throw new Error("NOT_A_PARTICIPANT");
    }
    const acked = call.dismissedDeviceIds ?? [];
    if (acked.includes(deviceId)) return null;
    await ctx.db.patch(callId, { dismissedDeviceIds: [...acked, deviceId] });
    return null;
  },
});

// Internal, no participant check: the device ids `ackNativeDismissed` has
// recorded for a call, for `voipPush.sendVoipTaken` (and its retry) to skip.
// Empty once the row is GC'd — by then every push for it has long expired.
export const dismissedDevicesInternal = internalQuery({
  args: { callId: v.id("calls") },
  returns: v.array(v.string()),
  handler: async (ctx, { callId }) => {
    const call = await ctx.db.get(callId);
    return call?.dismissedDeviceIds ?? [];
  },
});
