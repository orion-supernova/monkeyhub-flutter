import {
  mutation,
  query,
  internalAction,
  internalMutation,
} from "./_generated/server";
import { internal } from "./_generated/api";
import { v } from "convex/values";
import { childMayReach, childPolicyOf } from "./childGuard";

// ────────────────────────────── constants ──────────────────────────────

// Mesh topology: N participants means N-1 uplinks per phone. 6 is the safe
// ceiling for mobile encoders + typical uplink; beyond that an SFU is the
// right architecture, not a bigger mesh.
export const MAX_GROUP_CALL_PARTICIPANTS = 6;

// A pending invite older than this no longer rings — the room banner is the
// discovery surface after that.
const INVITE_RING_WINDOW_MS = 60 * 1000;

const HEARTBEAT_STALE_MS = 90 * 1000;

const ONESIGNAL_APP_ID = "c191a9f0-15cf-402a-8a04-dcc16108f4b0";
const ONESIGNAL_BASE = "https://api.onesignal.com";

// ────────────────────────────── helpers ──────────────────────────────

async function requireMember(ctx: any, roomId: any, userId: any) {
  const m = await ctx.db
    .query("roomMembers")
    .withIndex("by_room_user", (q: any) =>
      q.eq("roomId", roomId).eq("userId", userId),
    )
    .first();
  if (!m) throw new Error("NOT_A_MEMBER");
  return m;
}

async function activeCallForRoom(ctx: any, roomId: any) {
  return await ctx.db
    .query("groupCalls")
    .withIndex("by_room_status", (q: any) =>
      q.eq("roomId", roomId).eq("status", "active"),
    )
    .first();
}

async function participantRow(ctx: any, groupCallId: any, userId: any) {
  return await ctx.db
    .query("groupCallParticipants")
    .withIndex("by_call_user", (q: any) =>
      q.eq("groupCallId", groupCallId).eq("userId", userId),
    )
    .first();
}

async function joinedParticipants(ctx: any, groupCallId: any) {
  const rows = await ctx.db
    .query("groupCallParticipants")
    .withIndex("by_call", (q: any) => q.eq("groupCallId", groupCallId))
    .collect();
  return rows.filter((r: any) => r.status === "joined");
}

async function purgeGroupSignals(ctx: any, groupCallId: any) {
  const rows = await ctx.db
    .query("groupCallSignals")
    .withIndex("by_call", (q: any) => q.eq("groupCallId", groupCallId))
    .collect();
  for (const r of rows) await ctx.db.delete(r._id);
}

async function endCallIfEmpty(ctx: any, groupCallId: any) {
  const joined = await joinedParticipants(ctx, groupCallId);
  if (joined.length > 0) return false;
  const call = await ctx.db.get(groupCallId);
  if (!call || call.status !== "active") return true;
  await ctx.db.patch(groupCallId, { status: "ended", endedAt: Date.now() });
  await purgeGroupSignals(ctx, groupCallId);
  return true;
}

// ────────────────────────── lifecycle ──────────────────────────

// Start a call in [roomId] — or, if one is already active there, join it
// (two people tapping "call" at once must converge, not race). Invitees:
// null/absent = everyone in the room except the starter; otherwise the
// given subset. Members blocked from/by the starter, and child accounts
// the starter may not reach, are silently skipped.
export const start = mutation({
  args: {
    roomId: v.id("rooms"),
    userId: v.id("users"),
    deviceId: v.optional(v.string()),
    type: v.string(), // "audio" | "video"
    inviteeIds: v.optional(v.array(v.id("users"))),
  },
  handler: async (ctx, { roomId, userId, deviceId, type, inviteeIds }) => {
    if (type !== "audio" && type !== "video") throw new Error("BAD_CALL_TYPE");
    await requireMember(ctx, roomId, userId);

    const existing = await activeCallForRoom(ctx, roomId);
    if (existing) {
      return { groupCallId: existing._id, existing: true };
    }

    const starterPolicy = await childPolicyOf(ctx, userId);
    if (starterPolicy !== null && !starterPolicy.callsEnabled) {
      throw new Error("CALL_FAILED");
    }

    const now = Date.now();
    const groupCallId = await ctx.db.insert("groupCalls", {
      roomId,
      startedBy: userId,
      type,
      status: "active",
      startedAt: now,
    });
    await ctx.db.insert("groupCallParticipants", {
      groupCallId,
      userId,
      status: "joined",
      deviceId: deviceId ?? undefined,
      invitedAt: now,
      joinedAt: now,
      lastSeenAt: now,
    });

    // Resolve the invite list against actual room membership.
    const members = await ctx.db
      .query("roomMembers")
      .withIndex("by_room", (q) => q.eq("roomId", roomId))
      .collect();
    const memberIds = new Set(members.map((m) => m.userId.toString()));
    const requested =
      inviteeIds ?? members.map((m) => m.userId);
    const invited: any[] = [];
    for (const inviteeId of requested) {
      const key = inviteeId.toString();
      if (key === userId.toString()) continue;
      if (!memberIds.has(key)) continue;
      if (invited.some((i) => i.toString() === key)) continue;
      // Block list, both directions — skip silently, never error the call.
      const blocked = await ctx.db
        .query("blocks")
        .withIndex("by_pair", (q: any) =>
          q.eq("userId", userId).eq("blockedUserId", inviteeId),
        )
        .first();
      const blockedRev = await ctx.db
        .query("blocks")
        .withIndex("by_pair", (q: any) =>
          q.eq("userId", inviteeId).eq("blockedUserId", userId),
        )
        .first();
      if (blocked || blockedRev) continue;
      // Child guard, both directions.
      let guarded = false;
      for (const [a, b] of [
        [userId, inviteeId],
        [inviteeId, userId],
      ]) {
        const policy = await childPolicyOf(ctx, a);
        if (policy === null) continue;
        if (!policy.callsEnabled || !(await childMayReach(ctx, a, b))) {
          guarded = true;
          break;
        }
      }
      if (guarded) continue;
      invited.push(inviteeId);
      await ctx.db.insert("groupCallParticipants", {
        groupCallId,
        userId: inviteeId,
        status: "invited",
        invitedAt: now,
      });
    }

    if (invited.length > 0) {
      const starter = await ctx.db.get(userId);
      const room = await ctx.db.get(roomId);
      await ctx.scheduler.runAfter(0, internal.groupCalls.sendGroupInvitePush, {
        groupCallId,
        roomId,
        inviteeIds: invited,
        starterName: starter?.name ?? starter?.username ?? "Someone",
        roomName: room?.name ?? "a room",
        type,
      });
    }

    return { groupCallId, existing: false };
  },
});

export const join = mutation({
  args: {
    groupCallId: v.id("groupCalls"),
    userId: v.id("users"),
    deviceId: v.optional(v.string()),
  },
  handler: async (ctx, { groupCallId, userId, deviceId }) => {
    const call = await ctx.db.get(groupCallId);
    if (!call || call.status !== "active") throw new Error("CALL_ENDED");
    await requireMember(ctx, call.roomId, userId);

    const joined = await joinedParticipants(ctx, groupCallId);
    const mine = await participantRow(ctx, groupCallId, userId);
    const alreadyJoined = mine?.status === "joined";
    if (!alreadyJoined && joined.length >= MAX_GROUP_CALL_PARTICIPANTS) {
      throw new Error("CALL_FULL");
    }

    const now = Date.now();
    if (mine) {
      await ctx.db.patch(mine._id, {
        status: "joined",
        deviceId: deviceId ?? mine.deviceId,
        joinedAt: mine.joinedAt ?? now,
        leftAt: undefined,
        lastSeenAt: now,
      });
    } else {
      await ctx.db.insert("groupCallParticipants", {
        groupCallId,
        userId,
        status: "joined",
        deviceId: deviceId ?? undefined,
        invitedAt: now,
        joinedAt: now,
        lastSeenAt: now,
      });
    }
    return { type: call.type, roomId: call.roomId };
  },
});

export const leave = mutation({
  args: { groupCallId: v.id("groupCalls"), userId: v.id("users") },
  returns: v.null(),
  handler: async (ctx, { groupCallId, userId }) => {
    const mine = await participantRow(ctx, groupCallId, userId);
    if (mine && mine.status === "joined") {
      await ctx.db.patch(mine._id, { status: "left", leftAt: Date.now() });
    }
    // Drop this user's pending pair signals so remaining peers don't chew
    // through them.
    const call = await ctx.db.get(groupCallId);
    if (call) {
      const rows = await ctx.db
        .query("groupCallSignals")
        .withIndex("by_call", (q: any) => q.eq("groupCallId", groupCallId))
        .collect();
      for (const r of rows) {
        if (
          r.fromUserId.toString() === userId.toString() ||
          r.toUserId.toString() === userId.toString()
        ) {
          await ctx.db.delete(r._id);
        }
      }
    }
    await endCallIfEmpty(ctx, groupCallId);
  },
});

export const decline = mutation({
  args: { groupCallId: v.id("groupCalls"), userId: v.id("users") },
  returns: v.null(),
  handler: async (ctx, { groupCallId, userId }) => {
    const mine = await participantRow(ctx, groupCallId, userId);
    if (mine && mine.status === "invited") {
      await ctx.db.patch(mine._id, { status: "declined" });
    }
  },
});

// Joined clients ping every 30s; gcStaleGroupParticipants reaps anything
// silent for 90s (app killed without leave()).
export const heartbeat = mutation({
  args: { groupCallId: v.id("groupCalls"), userId: v.id("users") },
  returns: v.null(),
  handler: async (ctx, { groupCallId, userId }) => {
    const mine = await participantRow(ctx, groupCallId, userId);
    if (mine && mine.status === "joined") {
      await ctx.db.patch(mine._id, { lastSeenAt: Date.now() });
    }
  },
});

// ────────────────────────── queries ──────────────────────────

async function inflateParticipants(ctx: any, groupCallId: any) {
  const rows = await ctx.db
    .query("groupCallParticipants")
    .withIndex("by_call", (q: any) => q.eq("groupCallId", groupCallId))
    .collect();
  const out = [] as any[];
  for (const r of rows) {
    const u = await ctx.db.get(r.userId);
    out.push({
      userId: r.userId,
      status: r.status,
      deviceId: r.deviceId ?? null,
      name: u?.name ?? u?.username ?? "Someone",
      avatarStorageId: u?.avatarStorageId?.toString() ?? null,
      joinedAt: r.joinedAt ?? null,
    });
  }
  return out;
}

// The live call in [roomId], if any — drives the in-room "ongoing call"
// banner and its Join button.
export const activeForRoom = query({
  args: { roomId: v.id("rooms"), userId: v.id("users") },
  handler: async (ctx, { roomId, userId }) => {
    await requireMember(ctx, roomId, userId);
    const call = await activeCallForRoom(ctx, roomId);
    if (!call) return null;
    const participants = await inflateParticipants(ctx, call._id);
    return {
      groupCallId: call._id,
      roomId: call.roomId,
      type: call.type,
      startedAt: call.startedAt,
      startedBy: call.startedBy,
      participants,
    };
  },
});

// Roster + call state for the in-call screen and the mesh driver: joining
// clients diff `joined` participants against their PC map.
export const roster = query({
  args: { groupCallId: v.id("groupCalls"), userId: v.id("users") },
  handler: async (ctx, { groupCallId, userId }) => {
    const call = await ctx.db.get(groupCallId);
    if (!call) return null;
    await requireMember(ctx, call.roomId, userId);
    const participants = await inflateParticipants(ctx, groupCallId);
    return {
      groupCallId,
      roomId: call.roomId,
      type: call.type,
      status: call.status,
      startedAt: call.startedAt,
      participants,
    };
  },
});

// Freshest ring-worthy invite for this user (active call, invited status,
// within the ring window). Drives the in-app incoming group-call UI on app
// open / while foregrounded.
export const pendingInviteForUser = query({
  args: { userId: v.id("users") },
  handler: async (ctx, { userId }) => {
    const invites = await ctx.db
      .query("groupCallParticipants")
      .withIndex("by_user_status", (q) =>
        q.eq("userId", userId).eq("status", "invited"),
      )
      .collect();
    const now = Date.now();
    let best: any = null;
    for (const inv of invites) {
      if (now - inv.invitedAt > INVITE_RING_WINDOW_MS) continue;
      const call = await ctx.db.get(inv.groupCallId);
      if (!call || call.status !== "active") continue;
      if (!best || inv.invitedAt > best.inv.invitedAt) best = { inv, call };
    }
    if (!best) return null;
    const starter = await ctx.db.get(best.call.startedBy);
    const room = await ctx.db.get(best.call.roomId);
    const joined = await joinedParticipants(ctx, best.call._id);
    return {
      groupCallId: best.call._id,
      roomId: best.call.roomId,
      roomName: room?.name ?? "a room",
      type: best.call.type,
      starterName: starter?.name ?? starter?.username ?? "Someone",
      invitedAt: best.inv.invitedAt,
      joinedCount: joined.length,
    };
  },
});

// ────────────────────────── signaling ──────────────────────────

export const sendSignal = mutation({
  args: {
    groupCallId: v.id("groupCalls"),
    fromUserId: v.id("users"),
    toUserId: v.id("users"),
    kind: v.string(),
    payload: v.string(),
    fromDeviceId: v.optional(v.string()),
    targetDeviceId: v.optional(v.string()),
  },
  returns: v.null(),
  handler: async (
    ctx,
    { groupCallId, fromUserId, toUserId, kind, payload, fromDeviceId, targetDeviceId },
  ) => {
    const call = await ctx.db.get(groupCallId);
    // Idempotent silent drop for terminal calls — same rationale as 1:1
    // sendSignal: late ICE must not resurrect a dead session.
    if (!call || call.status !== "active") return;
    const from = await participantRow(ctx, groupCallId, fromUserId);
    const to = await participantRow(ctx, groupCallId, toUserId);
    if (!from || from.status !== "joined") throw new Error("NOT_IN_CALL");
    if (!to || to.status !== "joined") return; // peer already left — drop
    await ctx.db.insert("groupCallSignals", {
      groupCallId,
      fromUserId,
      toUserId,
      kind,
      payload,
      createdAt: Date.now(),
      consumed: false,
      fromDeviceId: fromDeviceId ?? undefined,
      targetDeviceId: targetDeviceId ?? undefined,
    });
  },
});

export const signalsForUser = query({
  args: { userId: v.id("users") },
  handler: async (ctx, { userId }) => {
    const rows = await ctx.db
      .query("groupCallSignals")
      .withIndex("by_to_unconsumed", (q) =>
        q.eq("toUserId", userId).eq("consumed", false),
      )
      .order("asc")
      .take(64);
    return rows.map((r) => ({
      _id: r._id,
      groupCallId: r.groupCallId,
      fromUserId: r.fromUserId,
      kind: r.kind,
      payload: r.payload,
      createdAt: r.createdAt,
      fromDeviceId: r.fromDeviceId ?? null,
      targetDeviceId: r.targetDeviceId ?? null,
    }));
  },
});

export const consumeSignals = mutation({
  args: {
    signalIds: v.array(v.id("groupCallSignals")),
    userId: v.id("users"),
  },
  returns: v.null(),
  handler: async (ctx, { signalIds, userId }) => {
    for (const signalId of signalIds) {
      const sig = await ctx.db.get(signalId);
      if (!sig) continue;
      if (sig.toUserId.toString() !== userId.toString()) continue;
      if (sig.consumed) continue;
      await ctx.db.patch(signalId, { consumed: true });
    }
  },
});

// ────────────────────────── push ──────────────────────────

// One OneSignal call for the whole invitee list (external_id aliases fan
// out server-side). Banner push, not VoIP — group invites ring in-app via
// pendingInviteForUser; the banner is the killed/backgrounded-app path.
export const sendGroupInvitePush = internalAction({
  args: {
    groupCallId: v.id("groupCalls"),
    roomId: v.id("rooms"),
    inviteeIds: v.array(v.id("users")),
    starterName: v.string(),
    roomName: v.string(),
    type: v.string(),
  },
  handler: async (
    _ctx,
    { groupCallId, roomId, inviteeIds, starterName, roomName, type },
  ) => {
    const apiKey = process.env.ONESIGNAL_API_KEY;
    if (!apiKey) {
      console.error("sendGroupInvitePush: ONESIGNAL_API_KEY is not set");
      return;
    }
    const verb = type === "video" ? "video call" : "voice call";
    const payload = {
      app_id: ONESIGNAL_APP_ID,
      target_channel: "push",
      include_aliases: {
        external_id: inviteeIds.map((i) => i.toString()),
      },
      headings: { en: roomName },
      contents: { en: `${starterName} started a ${verb} — tap to join` },
      priority: 10,
      ios_interruption_level: "time_sensitive",
      data: {
        type: "group_call_invite",
        groupCallId: groupCallId.toString(),
        roomId: roomId.toString(),
        callType: type,
        starterName,
        roomName,
      },
    };
    const response = await fetch(`${ONESIGNAL_BASE}/notifications`, {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        Authorization: `Key ${apiKey}`,
      },
      body: JSON.stringify(payload),
    });
    if (!response.ok) {
      console.error(
        `sendGroupInvitePush: OneSignal HTTP ${response.status} ${await response.text()}`,
      );
    }
  },
});

// ────────────────────────── GC sweeps ──────────────────────────

// Reap joined participants whose heartbeat went silent (killed app, dead
// network) and end calls that emptied out. Bounded per tick.
export const gcStaleGroupParticipants = internalMutation({
  handler: async (ctx) => {
    const cutoff = Date.now() - HEARTBEAT_STALE_MS;
    const active = await ctx.db
      .query("groupCalls")
      .withIndex("by_status", (q) => q.eq("status", "active"))
      .take(50);
    for (const call of active) {
      const joined = await joinedParticipants(ctx, call._id);
      for (const p of joined) {
        if ((p.lastSeenAt ?? p.joinedAt ?? 0) < cutoff) {
          await ctx.db.patch(p._id, { status: "left", leftAt: Date.now() });
        }
      }
      await endCallIfEmpty(ctx, call._id);
    }
  },
});

export const gcConsumedGroupSignals = internalMutation({
  handler: async (ctx) => {
    const cutoff = Date.now() - 60 * 1000;
    const rows = await ctx.db
      .query("groupCallSignals")
      .withIndex("by_consumed", (q) => q.eq("consumed", true))
      .take(200);
    for (const r of rows) {
      if (r.createdAt < cutoff) await ctx.db.delete(r._id);
    }
  },
});
