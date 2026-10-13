import {
  internalAction,
  internalMutation,
  internalQuery,
} from "./_generated/server";
import { mutation, query } from "./functions";
import { internal } from "./_generated/api";
import { v } from "convex/values";
import type { Doc } from "./_generated/dataModel";
import { childMayReach, childPolicyOf } from "./childGuard";
import { assertNoSystemAccount } from "./systemAccount";
import { assertRoomAllowsById } from "./roomPolicy";
import { lensFor, levelOf } from "./visibility";
import { TAKEN_PUSH_GRACE_MS } from "./calls";

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
  // Anyone whose phone is still ringing for a call that no longer exists.
  // Their realtime subscription drops the invite on its own, but a KILLED
  // app has no subscription — and a native card nothing can reach rings for
  // its full minute and then posts a missed call for a call nobody is in.
  await dismissRingers(ctx, groupCallId, "ended");
  return true;
}

/// Everyone still sitting on an unanswered invite, as of right now — the
/// rows, because the fan-out below flips them.
async function invitedRows(ctx: any, groupCallId: any) {
  const rows = await ctx.db
    .query("groupCallParticipants")
    .withIndex("by_call", (q: any) => q.eq("groupCallId", groupCallId))
    .collect();
  return rows.filter((r: any) => r.status === "invited");
}

/// Take the native ringer down on [userIds]' devices.
///
/// The realtime `pendingInviteForUser` subscription is what stops a LIVE app
/// ringing: `GroupCallService` ends its own card the moment the invite
/// leaves that subscription and acks it (`ackNativeDismissed`). This push is
/// for the process that cannot be reached that way — a killed app whose card
/// was raised by the push itself — and is the group twin of
/// `calls.scheduleTakenPush`, with the same two protections and for the same
/// reason: it waits `TAKEN_PUSH_GRACE_MS` so a live app can report its card
/// gone first, and `sendGroupVoipTaken` skips every device that did. On iOS
/// a PushKit `taken` with nothing to end is not a no-op, it is a one-second
/// phantom "Call" (AppDelegate.reportAndEndCall).
///
/// Two audiences. With `opts.userIds` (join, decline) it is one person's
/// OTHER phones. Without (call ended, ring timed out) it is everyone still
/// `invited` — and those rows are flipped to `missed` here, in the same
/// mutation, so the other fan-out finds nobody: an ignored invite used to be
/// dismissed twice, once when the call ended and again at the ring timeout,
/// and the second push always landed on a card the first had already ended.
async function dismissRingers(
  ctx: any,
  groupCallId: any,
  reason: "joined" | "declined" | "ended" | "timeout",
  opts: { userIds?: any[]; excludeDeviceId?: string | null } = {},
) {
  let userIds: any[];
  if (opts.userIds) {
    userIds = opts.userIds;
  } else {
    const rows = await invitedRows(ctx, groupCallId);
    for (const r of rows) await ctx.db.patch(r._id, { status: "missed" });
    userIds = rows.map((r: any) => r.userId);
  }
  if (userIds.length === 0) return;
  // Android first, and now; see `calls.scheduleTakenPush`.
  await ctx.scheduler.runAfter(0, internal.voipPush.sendGroupVoipTaken, {
    groupCallId,
    targetUserIds: userIds,
    excludeDeviceId: opts.excludeDeviceId ?? null,
    reason,
    fcmOnly: true,
  });
  await ctx.scheduler.runAfter(
    TAKEN_PUSH_GRACE_MS,
    internal.voipPush.sendGroupVoipTaken,
    {
      groupCallId,
      targetUserIds: userIds,
      excludeDeviceId: opts.excludeDeviceId ?? null,
      reason,
    },
  );
}

/// Which of [userIds] still has an unanswered invite to [groupCallId] — read
/// at SEND time rather than at schedule time.
///
/// `start` precomputes the whole ring payload and schedules the push with
/// `runAfter(0)`, so between the schedule and the send an invitee can already
/// have joined from another device, declined, or watched the call end. Ringing
/// a phone for a call that is over is the "ghost ring" `sendVoip` guards
/// against for 1:1, and it is worse here: nothing else is coming to dismiss a
/// card that should never have been raised.
/**
 * Stop ringing for an invite nobody answered.
 *
 * `pendingInviteForUser` already stops offering the invite past
 * INVITE_RING_WINDOW_MS, which ends the ring for anyone whose app is alive to
 * be told. A native card is not offered, it is PLACED — and iOS never takes
 * one down on its own, because CallKit expects the caller to hang up. So
 * without this the phone of anyone who missed a group call rings until they
 * touch it. (Android's plugin does auto-time-out at its `duration`, so this
 * arrives as a no-op there; sending it anyway is what keeps the two platforms
 * describable in one sentence.)
 *
 * Scheduled by `start`, one per call. Anyone who joined, declined, or watched
 * the call end has already had their card dismissed and is no longer
 * `invited` (the ended fan-out marks its targets `missed`), so this addresses
 * exactly the people it should — and nobody twice. Deliberately NOT gated on
 * the call still being active: `endCallIfEmpty` is the only thing that ends
 * a call and it dismisses its own ringers, but if that ever changes, this is
 * the last thing standing between a killed phone and a card that rings until
 * it is touched.
 */
export const _expireRingers = internalMutation({
  args: { groupCallId: v.id("groupCalls") },
  returns: v.null(),
  handler: async (ctx, { groupCallId }) => {
    await dismissRingers(ctx, groupCallId, "timeout");
    return null;
  },
});

export const _pendingInvitees = internalQuery({
  args: {
    groupCallId: v.id("groupCalls"),
    userIds: v.array(v.id("users")),
  },
  handler: async (ctx, { groupCallId, userIds }) => {
    const call = await ctx.db.get(groupCallId);
    if (!call || call.status !== "active") return [];
    const out: string[] = [];
    for (const userId of userIds) {
      const row = await participantRow(ctx, groupCallId, userId);
      if (row?.status === "invited") out.push(userId.toString());
    }
    return out;
  },
});

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
    // The room's posting policy decides whether calls happen here at all.
    // Checked before the roster walk below, which it makes unnecessary.
    await assertRoomAllowsById(ctx, roomId, userId, { actions: ["call"] });

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
      // The starter's face for the invite banner, resolved HERE rather than in
      // the action: this mutation already holds the `starter` doc and a db
      // context, so it costs no round trip, where the action would need an
      // internal query of its own the way notifications.ts does.
      //
      // Per invitee, because `visibility.avatar` is answered from the
      // INVITEE's side — the same lens the 1:1 ringer applies in calls.ts —
      // so it can never be one key everybody shares.
      const starterAvatarUrl = starter?.avatarStorageId
        ? await ctx.storage.getUrl(starter.avatarStorageId)
        : null;
      // Read straight off the row — exactly as `rooms.getMemberIds` does for a
      // message, and for the same reason: a lens costs two full friendship
      // scans to build, and this is the mutation a ringing phone is waiting
      // on. "public", the default, needs no lens; "friends" needs one from the
      // starter's side (friendship is symmetric); only an invitee that one
      // does not clear pays for their own, which is where a guardian is seen.
      const avatarLevel = levelOf(starter, "avatar");
      const perUser: Record<string, { data: Record<string, string> }> = {};
      if (starter && starterAvatarUrl) {
        const starterLens =
          avatarLevel === "friends" ? await lensFor(ctx, starter._id) : null;
        for (const inviteeId of invited) {
          let visible = true;
          if (avatarLevel !== "public" && !starterLens?.isFriend(inviteeId)) {
            const lens = await lensFor(ctx, inviteeId);
            visible = lens.canSee(starter, "avatar");
          }
          if (visible) {
            perUser[inviteeId.toString()] = {
              data: { senderAvatarUrl: starterAvatarUrl },
            };
          }
        }
      }
      // RING, don't merely announce.
      //
      // This used to schedule the banner directly, and the banner was all a
      // group invite ever produced: a backgrounded phone got a notification in
      // the shade, a killed one got the same, and neither ever showed the
      // full-screen incoming-call UI a 1:1 call has had all along. A call is
      // not a message — it is worth exactly one minute of somebody's
      // attention and worthless after that — which is the whole reason
      // CallKit and a full-screen intent exist.
      //
      // `sendGroupVoip` reaches PushKit and FCM the way `sendVoip` does for
      // 1:1, and falls back to `sendGroupInvitePush` per invitee for anyone it
      // could not ring — a browser, a desktop, a phone whose VoIP token the
      // dead-token sweep has cleared. So the banner is still there; it is the
      // rescue rather than the whole feature.
      await ctx.scheduler.runAfter(0, internal.voipPush.sendGroupVoip, {
        groupCallId,
        roomId,
        inviteeIds: invited,
        starterName: starter?.name ?? starter?.username ?? "Someone",
        roomName: room?.name ?? "a room",
        type,
        perUser,
      });
      // And stop ringing when the invite stops being ring-worthy. Same
      // instant `pendingInviteForUser` stops offering it, so a live app and a
      // killed one give up on the same call at the same moment.
      await ctx.scheduler.runAfter(
        INVITE_RING_WINDOW_MS,
        internal.groupCalls._expireRingers,
        { groupCallId },
      );
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
    // Answered here, so stop the other phones in this person's pocket. Their
    // own subscriptions would drop the invite anyway; a killed one's card
    // would not, and would go on ringing for a call its owner is already in.
    if (!alreadyJoined) {
      await dismissRingers(ctx, groupCallId, "joined", {
        userIds: [userId],
        excludeDeviceId: deviceId ?? null,
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
  args: {
    groupCallId: v.id("groupCalls"),
    userId: v.id("users"),
    /**
     * The device that pressed decline. Its own card is already gone — it is
     * the one that dismissed it — and a `taken` push arriving to end nothing
     * is, on iOS, a one-second phantom "Call" that rings and vanishes (see
     * `calls.TAKEN_PUSH_GRACE_MS` for the 1:1 version of this hazard). The
     * SIBLING phones are the ones that still need telling.
     */
    deviceId: v.optional(v.string()),
  },
  returns: v.null(),
  handler: async (ctx, { groupCallId, userId, deviceId }) => {
    const mine = await participantRow(ctx, groupCallId, userId);
    if (mine && mine.status === "invited") {
      await ctx.db.patch(mine._id, { status: "declined" });
      await dismissRingers(ctx, groupCallId, "declined", {
        userIds: [userId],
        excludeDeviceId: deviceId ?? null,
      });
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

// ────────────────────── native-card dismissal acks ──────────────────────

// A device reports that its native card for [groupCallId] is gone — it ended
// the card itself when the invite left `pendingInviteForUser`, or on decline
// or hang-up. Recorded so the grace-delayed `group_taken` (`dismissRingers`)
// leaves that device alone; the twin of `calls.ackNativeDismissed`, and see
// `calls.TAKEN_PUSH_GRACE_MS` for why it matters on iOS. Idempotent, and a
// GC'd row is fine: there is nothing left to push about.
export const ackNativeDismissed = mutation({
  args: {
    groupCallId: v.id("groupCalls"),
    userId: v.id("users"),
    deviceId: v.string(),
  },
  returns: v.null(),
  handler: async (ctx, { groupCallId, userId, deviceId }) => {
    const call = await ctx.db.get(groupCallId);
    if (!call) return null;
    const mine = await participantRow(ctx, groupCallId, userId);
    if (!mine) throw new Error("NOT_A_PARTICIPANT");
    const acked = call.dismissedDeviceIds ?? [];
    if (acked.includes(deviceId)) return null;
    await ctx.db.patch(groupCallId, {
      dismissedDeviceIds: [...acked, deviceId],
    });
    return null;
  },
});

// Internal, no participant check: the device ids `ackNativeDismissed` has
// recorded for a call, for `voipPush.sendGroupVoipTaken` (and its retry) to
// skip. Empty once the row is GC'd — by then every push for it has expired.
export const dismissedDevicesInternal = internalQuery({
  args: { groupCallId: v.id("groupCalls") },
  returns: v.array(v.string()),
  handler: async (ctx, { groupCallId }) => {
    const call = await ctx.db.get(groupCallId);
    return call?.dismissedDeviceIds ?? [];
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
    // The in-call screen is titled with the room. Joining from an invite the
    // client already knows the name; starting from inside the room it does
    // not carry it across, and a screen headed "Group video call" leaves the
    // one question a person in three rooms has — which one is this? — to be
    // guessed. A room's own picture is not lensed: every member may see it.
    const room = await ctx.db.get(call.roomId);
    return {
      groupCallId,
      roomId: call.roomId,
      roomName: room?.name ?? "a room",
      roomAvatarStorageId: room?.avatarStorageId?.toString() ?? null,
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
    // The starter's face, for the in-app ringer and the Android card the
    // foregrounded app raises itself. Lensed from THIS invitee's side, with
    // the same "public" fast path `start` uses for the push: the lens costs
    // two friendship scans and this query re-runs on every roster change
    // while the phone rings. The storage id feeds `UserAvatar`; the URL is
    // what the native card wants. Both null when hidden — never a face the
    // starter's own setting says this person may not see.
    const avatarLevel = levelOf(starter, "avatar");
    let starterAvatarVisible = !!starter?.avatarStorageId;
    if (starterAvatarVisible && avatarLevel !== "public") {
      const lens = await lensFor(ctx, userId);
      starterAvatarVisible = lens.canSee(starter, "avatar");
    }
    const starterAvatarStorageId =
      starterAvatarVisible && starter?.avatarStorageId
        ? starter.avatarStorageId.toString()
        : null;
    const starterAvatarUrl =
      starterAvatarVisible && starter?.avatarStorageId
        ? await ctx.storage.getUrl(starter.avatarStorageId)
        : null;
    return {
      groupCallId: best.call._id,
      roomId: best.call.roomId,
      roomName: room?.name ?? "a room",
      roomAvatarStorageId: room?.avatarStorageId?.toString() ?? null,
      type: best.call.type,
      starterUserId: best.call.startedBy,
      starterName: starter?.name ?? starter?.username ?? "Someone",
      starterAvatarStorageId,
      starterAvatarUrl,
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
  // `deviceId`: the subscribing device. Signals a peer addressed to one
  // specific device of this user (`targetDeviceId`, set from the roster's
  // per-participant deviceId) are left out for every other device — a
  // sibling that is not in the call used to receive them, drop them as
  // "not my call" and mark them consumed, and since a subscription delivers
  // the latest snapshot rather than a log, the device that WAS in the call
  // could miss a round for good. Absent (an older client): unfiltered.
  args: { userId: v.id("users"), deviceId: v.optional(v.string()) },
  handler: async (ctx, { userId, deviceId }) => {
    const all = await ctx.db
      .query("groupCallSignals")
      .withIndex("by_to_unconsumed", (q) =>
        q.eq("toUserId", userId).eq("consumed", false),
      )
      .order("asc")
      .take(64);
    const rows = deviceId
      ? all.filter((r) => !r.targetDeviceId || r.targetDeviceId === deviceId)
      : all;
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
    /**
     * `{ [inviteeId]: { data: { senderAvatarUrl } } }` — the starter's avatar
     * for the invitees their view of the starter's `visibility.avatar` lets
     * see it, resolved in the mutation that schedules this. Shaped like
     * `push.sendAlert`'s own `perUser`, which is where it is going.
     */
    perUser: v.optional(v.any()),
  },
  handler: async (
    ctx,
    { groupCallId, roomId, inviteeIds, starterName, roomName, type, perUser },
  ) => {
    if (inviteeIds.length === 0) return;
    const verb = type === "video" ? "video call" : "voice call";
    await ctx.runAction(internal.push.sendAlert, {
      userIds: inviteeIds,
      kind: "group_call_invite",
      title: roomName,
      body: `${starterName} started a ${verb}. Tap to join`,
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
      perUser,
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
