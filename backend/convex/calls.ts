import {
  mutation,
  query,
  action,
  internalAction,
  internalMutation,
} from "./_generated/server";
import { internal } from "./_generated/api";
import { v } from "convex/values";
import type { Doc } from "./_generated/dataModel";
import { childMayReach, childPolicyOf } from "./childGuard";
import { assertNoSystemAccount } from "./systemAccount";
import { lensFor } from "./visibility";

// ────────────────────────────── helpers ──────────────────────────────

const CALL_RING_TIMEOUT_MS = 30 * 1000; // missed after 30s un-answered

// A `ringing` row older than this is a scheduler orphan (the 30s expire
// never fired); `initiate`'s busy check reaps it inline rather than
// refusing with BUSY. Twice the ring timeout, well before gcStuckRinging.
const BUSY_RINGING_STALE_MS = 60 * 1000;

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
// always sending is a report-then-immediately-end blip only on a device
// that has no card left in-process; `reportCallEndedElsewhere` dismisses
// cleanly whenever the mapping exists.

// Shared terminal transition: mark ended, notify the peer over realtime
// (`bye`) AND native push (`taken`), purge everything else. Used by `end`,
// by `cancel` when it loses the race to an accept, and by the busy-check
// reaper in `initiate`.
async function endCallImpl(ctx: any, call: any, byUserId: any) {
  await ctx.db.patch(call._id, {
    status: "ended",
    endedAt: Date.now(),
  });
  const peer =
    call.callerId.toString() === byUserId.toString()
      ? call.calleeId
      : call.callerId;
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
  await ctx.scheduler.runAfter(0, internal.voipPush.sendVoipTaken, {
    callId: call._id,
    targetUserId: peer,
    excludeDeviceId: null,
    reason: "ended",
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
  await ctx.scheduler.runAfter(0, internal.voipPush.sendVoipTaken, {
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
    await ctx.scheduler.runAfter(0, internal.voipPush.sendVoipTaken, {
      callId: call._id,
      targetUserId: toUserId,
      excludeDeviceId: null,
      reason: "stuck",
    });
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
async function purgeCallSignals(
  ctx: any,
  callId: any,
  keep?: any | any[],
) {
  const keepIds = new Set<string>();
  if (Array.isArray(keep)) {
    for (const k of keep) if (k) keepIds.add(k.toString());
  } else if (keep) {
    keepIds.add(keep.toString());
  }
  const rows = await ctx.db
    .query("callSignals")
    .withIndex("by_call", (q: any) => q.eq("callId", callId))
    .collect();
  for (const r of rows) {
    if (keepIds.has(r._id.toString())) continue;
    await ctx.db.delete(r._id);
  }
}

// ────────────────────────── initiate / lifecycle ──────────────────────────

export const initiate = mutation({
  args: {
    callerId: v.id("users"),
    calleeId: v.id("users"),
    roomId: v.id("rooms"),
    type: v.string(), // "audio" | "video"
  },
  handler: async (ctx, { callerId, calleeId, roomId, type }) => {
    if (callerId.toString() === calleeId.toString()) {
      throw new Error("CANNOT_CALL_SELF");
    }
    if (type !== "audio" && type !== "video") throw new Error("BAD_CALL_TYPE");

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
    await ctx.db.patch(callId, {
      status: "active",
      acceptedAt: Date.now(),
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
    // For killed-iOS siblings (subscription not alive), fan a PushKit
    // payload with kind="taken" so CallKit can dismiss with
    // .answeredElsewhere. The accepting device is excluded.
    await ctx.scheduler.runAfter(0, internal.voipPush.sendVoipTaken, {
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
    await ctx.scheduler.runAfter(0, internal.voipPush.sendVoipTaken, {
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
    await ctx.scheduler.runAfter(0, internal.voipPush.sendVoipTaken, {
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
    const oldDeviceId = call.acceptingDeviceId;
    if (oldDeviceId === newDeviceId) {
      return { oldDeviceId: oldDeviceId ?? null };
    }
    await ctx.db.patch(callId, { acceptingDeviceId: newDeviceId });
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

export const consumeSignal = mutation({
  args: { signalId: v.id("callSignals"), userId: v.id("users") },
  handler: async (ctx, { signalId, userId }) => {
    const sig = await ctx.db.get(signalId);
    if (!sig) return;
    if (sig.toUserId.toString() !== userId.toString()) {
      throw new Error("NOT_RECIPIENT");
    }
    await ctx.db.patch(signalId, { consumed: true });
  },
});

export const consumeSignals = mutation({
  args: {
    signalIds: v.array(v.id("callSignals")),
    userId: v.id("users"),
  },
  returns: v.null(),
  handler: async (ctx, { signalIds, userId }) => {
    for (const signalId of signalIds) {
      const sig = await ctx.db.get(signalId);
      // Missing rows are fine — GC or purge may have raced us.
      if (!sig) continue;
      if (sig.toUserId.toString() !== userId.toString()) continue;
      if (sig.consumed) continue;
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
export const getIceConfig = action({
  args: { userId: v.id("users") },
  handler: async (_ctx, { userId }) => {
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
    type: v.string(),
    roomId: v.id("rooms"),
  },
  handler: async (
    ctx,
    { callId, calleeId, callerId, callerName, type, roomId },
  ) => {
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
      await ctx.scheduler.runAfter(0, internal.voipPush.sendVoipTaken, {
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
