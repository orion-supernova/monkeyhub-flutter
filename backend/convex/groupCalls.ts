import { internalAction, internalMutation } from "./_generated/server";
import { mutation, query } from "./functions";
import { internal } from "./_generated/api";
import { v } from "convex/values";
import type { Doc } from "./_generated/dataModel";
import { childMayReach, childPolicyOf } from "./childGuard";
import { assertNoSystemAccount } from "./systemAccount";
import { lensFor } from "./visibility";

// ────────────────────────────── constants ──────────────────────────────

// Mesh topology: N participants means N-1 uplinks per phone. 6 is the safe
// ceiling for mobile encoders + typical uplink; beyond that an SFU is the
// right architecture, not a bigger mesh.
export const MAX_GROUP_CALL_PARTICIPANTS = 6;

// A pending invite older than this no longer rings — the room banner is the
// discovery surface after that.
const INVITE_RING_WINDOW_MS = 60 * 1000;

// Joined clients ping every 15s; anything silent for 45s (3 missed beats)
// counts as dead. The reaper cron formalizes it, but activeForRoom /
// pendingInviteForUser already hide non-live participants immediately so a
// killed app never leaves a lingering "ongoing call" banner.
const HEARTBEAT_STALE_MS = 45 * 1000;


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

// Joined AND heartbeating. A row the reaper hasn't flipped yet but whose
// client is dead must not count toward any user-visible surface.
function isLive(p: any, now: number): boolean {
  return (
    p.status === "joined" && (p.lastSeenAt ?? p.joinedAt ?? 0) > now - HEARTBEAT_STALE_MS
  );
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

    // Scoped by ROOM rather than by callee, so unlike `calls.initiate` there is
    // no target id to check — the guard is that the room must contain no system
    // account. That is exactly the report DM, where a group call would invite an
    // account with no device and then wait for it.
    await assertNoSystemAccount(
      ctx,
      ...(
        await ctx.db
          .query("roomMembers")
          .withIndex("by_room_user", (q) => q.eq("roomId", roomId))
          .collect()
      ).map((m) => m.userId),
    );

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
      .withIndex("by_room_user", (q) => q.eq("roomId", roomId))
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

// Joined clients ping every 15s; gcStaleGroupParticipants reaps anything
// silent past HEARTBEAT_STALE_MS (45s — app killed without leave()).
//
// Returns "ok" | "not-in-call". The client self-ejects on "not-in-call":
// its roster subscription is the ONLY other thing that can end its call
// locally, so this doubles as that subscription's liveness check — a
// reaped-but-still-beating client (dead subscription) learns here that its
// call is over and releases its media instead of holding the mic forever.
export const heartbeat = mutation({
  args: { groupCallId: v.id("groupCalls"), userId: v.id("users") },
  returns: v.string(),
  handler: async (ctx, { groupCallId, userId }) => {
    const mine = await participantRow(ctx, groupCallId, userId);
    if (!mine || mine.status !== "joined") return "not-in-call";
    const call = await ctx.db.get(groupCallId);
    if (!call || call.status !== "active") return "not-in-call";
    await ctx.db.patch(mine._id, { lastSeenAt: Date.now() });
    return "ok";
  },
});

// ────────────────────────── queries ──────────────────────────

async function inflateParticipants(ctx: any, viewerUserId: any, groupCallId: any) {
  const lens = await lensFor(ctx, viewerUserId);
  const rows = await ctx.db
    .query("groupCallParticipants")
    .withIndex("by_call", (q: any) => q.eq("groupCallId", groupCallId))
    .collect();
  const now = Date.now();
  const out = [] as any[];
  for (const r of rows) {
    const u = await ctx.db.get(r.userId);
    out.push({
      userId: r.userId,
      status: r.status,
      // False for a joined row whose client stopped heartbeating (killed
      // app the reaper hasn't flipped yet) — UI surfaces must ignore it.
      live: isLive(r, now),
      deviceId: r.deviceId ?? null,
      name: u?.name ?? u?.username ?? "Someone",
      // Redacted per the participant's setting. Being in the same call is a
      // stronger tie than sharing a room, but it is still not the consent the
      // avatar control asks about — someone at "nobody" shows as initials in
      // the grid, exactly as they do everywhere else.
      avatarStorageId:
        u && lens.canSee(u, "avatar")
          ? u.avatarStorageId?.toString() ?? null
          : null,
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
    const participants = await inflateParticipants(ctx, userId, call._id);
    // A call whose every participant went silent is dead for UI purposes —
    // hide it now; the reaper cron formalizes the end shortly after.
    if (!participants.some((p) => p.live)) return null;
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
    const participants = await inflateParticipants(ctx, userId, groupCallId);
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
/**
 * How many invite rows this query will look at, newest first.
 *
 * Hardening, not a bug fix — worth being clear about, because the timeout that
 * sent me here turned out to be something else (see the class doc on
 * SubscriptionRegistry). This used to `.collect()` every matching row, and that
 * read is the only genuinely unbounded thing in this query: `invited` becomes
 * something else only when the user ACTS on it — join, decline, leave — so an
 * invite that is simply ignored stays `invited` until gcTerminalGroupCalls
 * deletes its call a day later. That GC is what keeps the table small today,
 * which means an unbounded read here is one broken GC away from mattering, on a
 * query whose budget is one second.
 *
 * 16 newest is plenty: the loop below wants the most recent invite still inside
 * INVITE_RING_WINDOW_MS, and nobody is invited to sixteen group calls within one
 * ring window. Anything older is discarded by the loop anyway, so reading it was
 * always pure cost.
 */
const INVITE_SCAN_LIMIT = 16;

export const pendingInviteForUser = query({
  args: { userId: v.id("users") },
  handler: async (ctx, { userId }) => {
    // Newest first, and only a handful. Both halves matter: `take` without
    // `order("desc")` would return the OLDEST rows, which are exactly the
    // expired ones the loop throws away — a bounded query that never finds
    // anything.
    //
    // Both index fields are equality-matched, so within the range the residual
    // order is by creation, which is the order `invitedAt` is written in.
    const invites = await ctx.db
      .query("groupCallParticipants")
      .withIndex("by_user_status", (q) =>
        q.eq("userId", userId).eq("status", "invited"),
      )
      .order("desc")
      .take(INVITE_SCAN_LIMIT);
    const now = Date.now();
    // Typed, so `best.call.startedBy` is an `Id<"users">` and the `db.get`
    // below resolves to a user rather than the union of every table — which is
    // what made `starter?.name` unreachable on the line that names the caller.
    let best: { inv: Doc<"groupCallParticipants">; call: Doc<"groupCalls"> } | null =
      null;
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
    const live = joined.filter((p: any) => isLive(p, now));
    // Everyone who was in the call is gone — nothing to join, don't ring.
    if (live.length === 0) return null;
    return {
      groupCallId: best.call._id,
      roomId: best.call.roomId,
      roomName: room?.name ?? "a room",
      type: best.call.type,
      starterName: starter?.name ?? starter?.username ?? "Someone",
      invitedAt: best.inv.invitedAt,
      joinedCount: live.length,
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

// Banner push, not VoIP — group invites ring in-app via pendingInviteForUser;
// the banner is the killed/backgrounded-app path. The invitee list goes in as
// one call and fans out per recipient inside `sendAlert`, which is what lets
// each person's banner carry their own badge total.
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
    ctx,
    { groupCallId, roomId, inviteeIds, starterName, roomName, type },
  ) => {
    if (inviteeIds.length === 0) return;
    const verb = type === "video" ? "video call" : "voice call";
    await ctx.runAction(internal.push.sendAlert, {
      userIds: inviteeIds,
      kind: "group_call_invite",
      title: roomName,
      body: `${starterName} started a ${verb} — tap to join`,
      data: {
        kind: "group_call_invite",
        groupCallId: groupCallId.toString(),
        roomId: roomId.toString(),
        callType: type,
        starterName,
        roomName,
      },
      roomId,
      collapseId: groupCallId.toString(),
    });
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

// The group counterpart of calls.gcTerminalCalls, which never existed:
// ended groupCalls rows, their participants, and any signals (consumed or
// not — unconsumed ones are only purged by endCallIfEmpty, which several
// end paths skip) accumulated forever. Day-old ended calls have no readers.
export const gcTerminalGroupCalls = internalMutation({
  args: {},
  returns: v.null(),
  handler: async (ctx) => {
    const cutoff = Date.now() - 24 * 60 * 60 * 1000;
    const rows = await ctx.db
      .query("groupCalls")
      .withIndex("by_status", (q) =>
        q.eq("status", "ended").lt("startedAt", cutoff),
      )
      .take(50);
    let deleted = 0;
    for (const call of rows) {
      const parts = await ctx.db
        .query("groupCallParticipants")
        .withIndex("by_call", (q: any) => q.eq("groupCallId", call._id))
        .collect();
      for (const p of parts) await ctx.db.delete(p._id);
      const sigs = await ctx.db
        .query("groupCallSignals")
        .withIndex("by_call", (q: any) => q.eq("groupCallId", call._id))
        .collect();
      for (const s of sigs) await ctx.db.delete(s._id);
      await ctx.db.delete(call._id);
      deleted++;
    }
    if (deleted > 0) {
      console.log(`gcTerminalGroupCalls: deleted ${deleted} call(s)`);
    }
    return null;
  },
});
