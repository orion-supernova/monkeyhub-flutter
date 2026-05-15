import {
  mutation,
  query,
  action,
  internalAction,
  internalMutation,
} from "./_generated/server";
import { internal } from "./_generated/api";
import { v } from "convex/values";

// ────────────────────────────── helpers ──────────────────────────────

const CALL_RING_TIMEOUT_MS = 30 * 1000; // missed after 30s un-answered

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

async function assertCallParticipant(ctx: any, callId: any, userId: any) {
  const call = await ctx.db.get(callId);
  if (!call) throw new Error("CALL_NOT_FOUND");
  const u = userId.toString();
  if (call.callerId.toString() !== u && call.calleeId.toString() !== u) {
    throw new Error("NOT_A_PARTICIPANT");
  }
  return call;
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

    // Honor block list — generic error so we don't reveal who blocked whom.
    if (await isPairBlocked(ctx, callerId, calleeId)) {
      throw new Error("CALL_FAILED");
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

    // Reject if either user is already in a live call (ringing / active).
    for (const uid of [callerId, calleeId]) {
      const liveAsCallee = await ctx.db
        .query("calls")
        .withIndex("by_callee_status", (q) =>
          q.eq("calleeId", uid).eq("status", "ringing"),
        )
        .first();
      const liveAsCalleeActive = await ctx.db
        .query("calls")
        .withIndex("by_callee_status", (q) =>
          q.eq("calleeId", uid).eq("status", "active"),
        )
        .first();
      const liveAsCaller = await ctx.db
        .query("calls")
        .withIndex("by_caller_status", (q) =>
          q.eq("callerId", uid).eq("status", "ringing"),
        )
        .first();
      const liveAsCallerActive = await ctx.db
        .query("calls")
        .withIndex("by_caller_status", (q) =>
          q.eq("callerId", uid).eq("status", "active"),
        )
        .first();
      if (
        liveAsCallee ||
        liveAsCalleeActive ||
        liveAsCaller ||
        liveAsCallerActive
      ) {
        throw new Error("BUSY");
      }
    }

    const caller = await ctx.db.get(callerId);
    const callerName = caller?.name ?? caller?.username ?? "Someone";

    const callId = await ctx.db.insert("calls", {
      callerId,
      calleeId,
      roomId,
      type,
      status: "ringing",
      startedAt: Date.now(),
    });

    // Fire push so the callee's app wakes if backgrounded.
    await ctx.scheduler.runAfter(0, internal.calls.sendCallPush, {
      callId,
      calleeId,
      callerId,
      callerName,
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
  args: { callId: v.id("calls"), userId: v.id("users") },
  handler: async (ctx, { callId, userId }) => {
    const call = await assertCallParticipant(ctx, callId, userId);
    if (call.calleeId.toString() !== userId.toString()) {
      throw new Error("ONLY_CALLEE_CAN_ACCEPT");
    }
    if (call.status !== "ringing") throw new Error("NOT_RINGING");
    await ctx.db.patch(callId, {
      status: "active",
      acceptedAt: Date.now(),
    });
  },
});

export const reject = mutation({
  args: { callId: v.id("calls"), userId: v.id("users") },
  handler: async (ctx, { callId, userId }) => {
    const call = await assertCallParticipant(ctx, callId, userId);
    if (call.calleeId.toString() !== userId.toString()) {
      throw new Error("ONLY_CALLEE_CAN_REJECT");
    }
    if (call.status !== "ringing") return; // idempotent
    await ctx.db.patch(callId, {
      status: "rejected",
      endedAt: Date.now(),
    });
    // Drop a terminal signal so the caller sees the rejection promptly.
    await ctx.db.insert("callSignals", {
      callId,
      fromUserId: userId,
      toUserId: call.callerId,
      kind: "reject",
      payload: "{}",
      createdAt: Date.now(),
      consumed: false,
    });
  },
});

export const cancel = mutation({
  args: { callId: v.id("calls"), userId: v.id("users") },
  handler: async (ctx, { callId, userId }) => {
    const call = await assertCallParticipant(ctx, callId, userId);
    if (call.callerId.toString() !== userId.toString()) {
      throw new Error("ONLY_CALLER_CAN_CANCEL");
    }
    if (call.status !== "ringing") return;
    await ctx.db.patch(callId, {
      status: "cancelled",
      endedAt: Date.now(),
    });
    await ctx.db.insert("callSignals", {
      callId,
      fromUserId: userId,
      toUserId: call.calleeId,
      kind: "cancel",
      payload: "{}",
      createdAt: Date.now(),
      consumed: false,
    });
  },
});

export const end = mutation({
  args: { callId: v.id("calls"), userId: v.id("users") },
  handler: async (ctx, { callId, userId }) => {
    const call = await assertCallParticipant(ctx, callId, userId);
    if (call.status === "ended" || call.status === "failed") return;
    await ctx.db.patch(callId, {
      status: "ended",
      endedAt: Date.now(),
    });
    const peer =
      call.callerId.toString() === userId.toString()
        ? call.calleeId
        : call.callerId;
    await ctx.db.insert("callSignals", {
      callId,
      fromUserId: userId,
      toUserId: peer,
      kind: "bye",
      payload: "{}",
      createdAt: Date.now(),
      consumed: false,
    });
  },
});

export const expireRingingCall = internalMutation({
  args: { callId: v.id("calls") },
  handler: async (ctx, { callId }) => {
    const call = await ctx.db.get(callId);
    if (!call) return;
    if (call.status !== "ringing") return;
    await ctx.db.patch(callId, {
      status: "missed",
      endedAt: Date.now(),
    });
    // Notify both sides so their UI can transition out of ringing.
    await ctx.db.insert("callSignals", {
      callId,
      fromUserId: call.callerId,
      toUserId: call.calleeId,
      kind: "cancel",
      payload: '{"reason":"timeout"}',
      createdAt: Date.now(),
      consumed: false,
    });
    await ctx.db.insert("callSignals", {
      callId,
      fromUserId: call.calleeId,
      toUserId: call.callerId,
      kind: "reject",
      payload: '{"reason":"timeout"}',
      createdAt: Date.now(),
      consumed: false,
    });
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
  },
  handler: async (
    ctx,
    { callId, fromUserId, toUserId, kind, payload },
  ) => {
    const call = await assertCallParticipant(ctx, callId, fromUserId);
    // toUserId must be the other participant.
    const expectedPeer =
      call.callerId.toString() === fromUserId.toString()
        ? call.calleeId.toString()
        : call.callerId.toString();
    if (toUserId.toString() !== expectedPeer) {
      throw new Error("WRONG_PEER");
    }
    await ctx.db.insert("callSignals", {
      callId,
      fromUserId,
      toUserId,
      kind,
      payload,
      createdAt: Date.now(),
      consumed: false,
    });
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

export const activeCallForUser = query({
  args: { userId: v.id("users") },
  handler: async (ctx, { userId }) => {
    // Resolves to my live `ringing` or `active` call so the UI can re-attach
    // after a cold start. Caller side first.
    for (const status of ["ringing", "active"] as const) {
      const asCallee = await ctx.db
        .query("calls")
        .withIndex("by_callee_status", (q) =>
          q.eq("calleeId", userId).eq("status", status),
        )
        .first();
      if (asCallee) return asCallee;
      const asCaller = await ctx.db
        .query("calls")
        .withIndex("by_caller_status", (q) =>
          q.eq("callerId", userId).eq("status", status),
        )
        .first();
      if (asCaller) return asCaller;
    }
    return null;
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
    return {
      iceServers: [
        ...stun,
        {
          urls: turnUrl, // e.g. "turn:1.2.3.4:3478"
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

const ONESIGNAL_APP_ID = "c191a9f0-15cf-402a-8a04-dcc16108f4b0";
const ONESIGNAL_BASE = "https://api.onesignal.com";

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
    _ctx,
    { callId, calleeId, callerId, callerName, type, roomId },
  ) => {
    const apiKey = process.env.ONESIGNAL_API_KEY;
    if (!apiKey) {
      console.error("sendCallPush: ONESIGNAL_API_KEY env var is not set");
      return;
    }
    const verb = type === "video" ? "Video call" : "Voice call";
    const payload = {
      app_id: ONESIGNAL_APP_ID,
      target_channel: "push",
      include_aliases: { external_id: [calleeId.toString()] },
      headings: { en: callerName },
      contents: { en: `${verb} from ${callerName}` },
      priority: 10,
      ios_interruption_level: "time-sensitive",
      data: {
        type: "call_invite",
        callId: callId.toString(),
        callerId: callerId.toString(),
        callerName,
        callType: type,
        roomId: roomId.toString(),
      },
      ios_category: "CALL_INVITE",
    };
    const response = await fetch(`${ONESIGNAL_BASE}/notifications`, {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        Authorization: `Key ${apiKey}`,
      },
      body: JSON.stringify(payload),
    });
    const text = await response.text();
    if (!response.ok) {
      console.error(`sendCallPush: OneSignal HTTP ${response.status} ${text}`);
    } else {
      console.log(`sendCallPush: dispatched — ${text}`);
    }
  },
});
