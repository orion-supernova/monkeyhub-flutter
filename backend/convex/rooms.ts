import { internalQuery } from "./_generated/server";
import { mutation, query } from "./functions";
import { internal } from "./_generated/api";
import { v } from "convex/values";
import {
  ERR_APPROVAL_REQUIRED,
  assertChildMayReach,
  assertChildPolicy,
  childMayUseRoom,
  isChild,
} from "./childGuard";
import { assertNoSystemAccount, assertNotSystemRoom } from "./systemAccount";
import { lensFor, publicUserView, seenVisibilityOf } from "./visibility";
import { unreadForRoom } from "./badges";
import { MUTE_ALWAYS, resolveMute } from "./mute";
import { deleteStored } from "./files";
import { wipeRoomCompletely } from "./roomCleanup";
import {
  ROLE_MEMBER,
  ROLE_OWNER,
  addMembership,
  assertAdmin,
  assertOwner,
  isGroupRoom,
  membershipOf,
  removeMembership,
} from "./roomAdmin";

export const create = mutation({
  args: {
    name: v.string(),
    description: v.optional(v.string()),
    isPrivate: v.boolean(),
    userId: v.id("users"),
    passwordHash: v.optional(v.string()),
    type: v.optional(v.string()),           // "regular" | "secret"
    messageLifetime: v.optional(v.number()), // seconds
  },
  handler: async (ctx, { name, description, isPrivate, userId, passwordHash, type, messageLifetime }) => {
    // Children can't make rooms unless a guardian switched it on, and even
    // then only private ones — a child publishing a public room would be a
    // discoverable surface nobody approved.
    await assertChildPolicy(ctx, userId, "canCreateRooms");
    const creatorIsChild = await isChild(ctx, userId);
    const visibility = creatorIsChild ? true : isPrivate;

    const existing = await ctx.db
      .query("rooms")
      .withIndex("by_name", (q) => q.eq("name", name))
      .first();
    if (existing) throw new Error("ROOM_EXISTS");

    const roomId = await ctx.db.insert("rooms", {
      name,
      description,
      createdBy: userId,
      createdAt: Date.now(),
      isPrivate: visibility,
      memberCount: 1,
      passwordHash: passwordHash && passwordHash.length > 0 ? passwordHash : undefined,
      type: type ?? "regular",
      messageLifetime,
    });
    await ctx.db.insert("roomMembers", {
      roomId,
      userId,
      joinedAt: Date.now(),
      role: ROLE_OWNER,
      seenVisibility: await seenVisibilityOf(ctx, userId),
    });
    return roomId;
  },
});

export const join = mutation({
  args: {
    roomId: v.id("rooms"),
    userId: v.id("users"),
    passwordHash: v.optional(v.string()),
  },
  handler: async (ctx, { roomId, userId, passwordHash }) => {
    const room = await ctx.db.get(roomId);
    if (!room) throw new Error("ROOM_NOT_FOUND");

    // This is the DISCOVER door, and Discover lists public rooms only. A
    // private room is reachable here solely by knowing its id, and room ids
    // travel further than people assume — they ride along in forwarded
    // content, in shared-media payloads, in anything a member ever copied.
    // Every legitimate way into a private room now goes through a token
    // somebody chose to hand out (`roomInvites.redeem`) or a person who was
    // named (`roomInvitations.respond`), so the id alone stops being a key.
    //
    // Existing rooms are unaffected: nothing in the client has ever called
    // this with a private room, because nothing shows the user one to call it
    // with.
    if (room.isPrivate) throw new Error("ROOM_IS_PRIVATE");

    if (room.passwordHash) {
      if (!passwordHash || passwordHash.length === 0) throw new Error("ROOM_PASSWORD_REQUIRED");
      if (passwordHash !== room.passwordHash) throw new Error("ROOM_PASSWORD_INVALID");
    }

    // Children need a guardian's yes first. `childMayUseRoom` already lets a
    // family-only room through, so a parent adding their kid to the family
    // group chat doesn't need an approval round-trip. The client turns this
    // error into the "ask a grown-up" sheet rather than a failure.
    if (await isChild(ctx, userId)) {
      if (!(await childMayUseRoom(ctx, userId, roomId))) {
        throw new Error(ERR_APPROVAL_REQUIRED);
      }
    }

    // Idempotent, and the single place `memberCount` and the `seenVisibility`
    // stamp are kept honest — shared with the invite and link paths so the
    // three cannot drift. See `roomAdmin.addMembership`.
    await addMembership(ctx, roomId, userId, ROLE_MEMBER);
  },
});

export const leave = mutation({
  args: { roomId: v.id("rooms"), userId: v.id("users") },
  handler: async (ctx, { roomId, userId }) => {
    // Leaving a system room is the worst of the three refusals below, because
    // it half-works: the membership row goes, the room lives on, and the next
    // report arrives somewhere the maintainer can no longer see.
    await assertNotSystemRoom(ctx, roomId);

    // The teardown itself lives in `roomAdmin.removeMembership`, shared with
    // being removed by an admin. Walking out and being shown the door leave
    // exactly the same debris — the departing member's bookmarks (which go,
    // pointedly unlike their pins), their outstanding invite and join-request
    // rows, the room's member count, the empty-room wipe, and the deferred
    // view-once recount — and that sweep is easy to get subtly wrong twice.
    //
    // It also re-seats the owner if the person leaving held that seat, which
    // this mutation never used to do: before the admin tier, an owner walking
    // out left a room nobody could rename, retitle or delete ever again.
    await removeMembership(ctx, roomId, userId);
  },
});

export const deleteRoom = mutation({
  args: { roomId: v.id("rooms"), userId: v.id("users") },
  handler: async (ctx, { roomId, userId }) => {
    const room = await ctx.db.get(roomId);
    if (!room) throw new Error("ROOM_NOT_FOUND");
    // Before the DM branch below, which would otherwise wave this through:
    // the report room IS a DM, so "either side may end it" would apply to it.
    await assertNotSystemRoom(ctx, roomId);

    // A DM has no real "owner" — createdBy is just whichever of the two
    // people happened to open it first. Gating deletion on that would leave
    // the other participant unable to ever end the conversation, so either
    // side of a DM may delete it. Group rooms keep the owner-only rule.
    //
    // For groups that rule is now the membership ROLE, not `createdBy`. The
    // difference is load-bearing: ownership can be transferred, and an owner
    // who deletes their account hands the room to an heir. Both left the old
    // `createdBy` test pointing at somebody who could no longer act — or, after
    // `auth.purgeUser`, at a row nobody could reach at all.
    if (!isGroupRoom(room)) {
      if (!(await membershipOf(ctx, roomId, userId))) {
        throw new Error("NOT_AUTHORIZED");
      }
    } else {
      await assertOwner(ctx, roomId, userId);
    }

    await wipeRoomCompletely(ctx, roomId);
  },
});

export const updatePassword = mutation({
  args: {
    roomId: v.id("rooms"),
    userId: v.id("users"),
    passwordHash: v.optional(v.string()),
  },
  handler: async (ctx, { roomId, userId, passwordHash }) => {
    const room = await ctx.db.get(roomId);
    if (!room) throw new Error("ROOM_NOT_FOUND");
    // Any admin, not just the creator. A room password is a door key like the
    // invite link is, and the people trusted to rotate one are the people
    // trusted to rotate the other.
    await assertAdmin(ctx, roomId, userId);
    await ctx.db.patch(roomId, {
      passwordHash: passwordHash && passwordHash.length > 0 ? passwordHash : undefined,
    });
  },
});

export const updateRoom = mutation({
  args: {
    roomId: v.id("rooms"),
    userId: v.id("users"),
    name: v.string(),
    description: v.optional(v.string()),
    isPrivate: v.optional(v.boolean()),
    messageLifetime: v.optional(v.number()),
  },
  handler: async (ctx, { roomId, userId, name, description, isPrivate, messageLifetime }) => {
    const room = await ctx.db.get(roomId);
    if (!room) throw new Error("ROOM_NOT_FOUND");
    // A system room's name is load-bearing (`ensureReportRoom` looks it up by
    // the exact `dm:regular:<a>:<b>` string), and it has no description or
    // visibility a user should be setting. The client hides the fields; this
    // makes it a rule.
    await assertNotSystemRoom(ctx, roomId);
    // Group settings are an ADMIN act now. This used to be "any member can
    // update", which in a group of any size meant the name, description,
    // visibility and disappearing-message timer were editable by whoever felt
    // like it — including someone who joined a minute ago off a link.
    //
    // A DM keeps the any-participant rule: it has no admins to ask, and the
    // client only ever sends the message-lifetime field for one.
    if (isGroupRoom(room)) {
      await assertAdmin(ctx, roomId, userId);
    } else if (!(await membershipOf(ctx, roomId, userId))) {
      throw new Error("NOT_AUTHORIZED");
    }

    const trimmed = name.trim();
    if (!trimmed) throw new Error("ROOM_NAME_REQUIRED");
    if (trimmed !== room.name) {
      const existing = await ctx.db
        .query("rooms")
        .withIndex("by_name", (q) => q.eq("name", trimmed))
        .first();
      if (existing && existing._id.toString() !== roomId.toString()) {
        throw new Error("ROOM_EXISTS");
      }
    }

    await ctx.db.patch(roomId, {
      name: trimmed,
      description: description && description.length > 0 ? description : undefined,
      ...(isPrivate !== undefined ? { isPrivate } : {}),
      ...(messageLifetime !== undefined ? { messageLifetime } : {}),
    });
  },
});

export const updateRoomAvatar = mutation({
  args: {
    roomId: v.id("rooms"),
    userId: v.id("users"),
    storageId: v.id("_storage"),
  },
  handler: async (ctx, { roomId, userId, storageId }) => {
    const room = await ctx.db.get(roomId);
    if (!room) throw new Error("ROOM_NOT_FOUND");
    // Same rule as `updateRoom`, for the same reason — the avatar is the most
    // visible thing about a group, and it is the one a griefer reaches for.
    if (isGroupRoom(room)) {
      await assertAdmin(ctx, roomId, userId);
    } else if (!(await membershipOf(ctx, roomId, userId))) {
      throw new Error("NOT_AUTHORIZED");
    }
    const previous = room.avatarStorageId;
    await ctx.db.patch(roomId, { avatarStorageId: storageId });
    // Free the blob we just stopped pointing at, or it bills forever with
    // nothing referencing it. Skip when the id is unchanged — deleting that
    // file would leave the room with a broken avatar.
    if (previous && previous !== storageId) {
      await deleteStored(ctx, previous);
    }
  },
});

export const listPublic = query({
  identityArg: "viewerUserId" as const,
  args: { viewerUserId: v.optional(v.id("users")) },
  handler: async (ctx, { viewerUserId }) => {
    // A child doesn't get a filtered Discover — they get no Discover at all.
    // Returning [] here is the enforcement point; the client also hides the tab.
    //
    // Deliberately NOT conditioned on `childPolicy.publicRoomsEnabled` any
    // more. That flag is fixed at false and no longer settable (see
    // childGuard.DEFAULT_CHILD_POLICY), but rows written before that change can
    // still carry `true`, so reading it here would leave exactly the accounts
    // this is meant to protect still browsing strangers' rooms. The account
    // type is the whole test.
    if (viewerUserId) {
      const viewer = await ctx.db.get(viewerUserId);
      if (viewer?.accountType === "child") return [];
    }
    const rooms = await ctx.db
      .query("rooms")
      .withIndex("by_visibility", (q) => q.eq("isPrivate", false))
      .collect();

    // Which of these the viewer is already in. Read once over `by_user` and
    // held as a Set — a per-room `by_room_user` lookup would be one query per
    // tile for something a single index scan answers.
    //
    // Without this, Discover has no way to tell a room you're in from one you
    // aren't until `rooms:join` rejects it server-side, which is after the join
    // sheet (and, for a child, the approval gate) has already been shown.
    const joined = new Set<string>();
    if (viewerUserId) {
      const memberships = await ctx.db
        .query("roomMembers")
        .withIndex("by_user", (q) => q.eq("userId", viewerUserId))
        .collect();
      for (const m of memberships) joined.add(m.roomId.toString());
    }

    // Strip passwordHash for security — expose only a boolean indicator
    return rooms.map(({ passwordHash, ...rest }) => ({
      ...rest,
      hasPassword: !!passwordHash,
      isMember: joined.has(rest._id.toString()),
    }));
  },
});

export const listUserRooms = query({
  args: { userId: v.id("users") },
  handler: async (ctx, { userId }) => {
    const memberships = await ctx.db
      .query("roomMembers")
      .withIndex("by_user", (q) => q.eq("userId", userId))
      .collect();

    const rooms = await Promise.all(
      memberships.map(async (m) => {
        const room = await ctx.db.get(m.roomId);
        if (!room) return null;

        // Participant ids, for DMs ONLY. The narrowing is a fan-out fix, not a
        // payload saving.
        //
        // Collecting every member put each of their `roomMembers` rows into
        // this subscription's read set, once per room the viewer is in. That
        // row is patched by `markRoomRead` on every incoming message — so four
        // people talking quickly re-ran this entire query, N rooms x (a room
        // read + a member scan + an unread scan), for every member on every
        // message. It was the top UserTimeout in the server logs by a wide
        // margin, and the work was mostly for nobody: the client reads
        // `participantIds` at exactly one place, `ChatRoom.otherParticipantId`,
        // which its only caller guards behind `isDm` and which returns null for
        // anything else. A group room's copy was built, shipped and dropped.
        //
        // Restricting the read to DMs leaves that one consumer exactly as
        // correct while taking group rooms out of the invalidation path
        // entirely. Older clients are safe: `ChatRoom.fromJson` already
        // defaults the field to `const []`, which is what a group room now
        // sends.
        //
        // A DM still collects, and still refires when its two members read —
        // two rows, one peer, which is the cost of knowing who you are talking
        // to. `startsWith("dm:")` is the same test the rest of the backend uses
        // (roomAdmin.isGroupRoom, childGuard, roomCleanup).
        const participantIds = room.name?.startsWith("dm:")
          ? (
              await ctx.db
                .query("roomMembers")
                .withIndex("by_room_user", (q) => q.eq("roomId", m.roomId))
                .collect()
            ).map((mem) => mem.userId.toString())
          : [];
        const { passwordHash, ...rest } = room;
        // Surface the caller's own read cursor so the client can flag rooms
        // with messages newer than lastReadAt as unread (m is this user's
        // membership row). markRoomRead keeps lastReadAt current.
        //
        // `unreadCount` is a capped scan rather than a denormalized counter.
        // This subscription already re-runs on every message — `messages.send`
        // patches rooms.lastMessage, and we ctx.db.get(m.roomId) right above —
        // so counting here adds no new invalidation for the common case, while
        // a counter on roomMembers would patch N member rows per send and
        // re-fire getReadState for the whole room. See badges.ts.
        const unread = await unreadForRoom(ctx, m.roomId, userId, m.lastReadAt);
        return {
          ...rest,
          participantIds,
          hasPassword: !!passwordHash,
          lastReadAt: m.lastReadAt ?? null,
          // The caller's own delivery cursor, for the same reason: it lets the
          // client see which rooms it has ALREADY reported as delivered and
          // skip them. Without it, a cold start with twenty unread rooms would
          // fire twenty `markRoomDelivered` mutations on every launch instead
          // of only on rooms that genuinely moved since.
          lastDeliveredAt: m.lastDeliveredAt ?? null,
          unreadCount: unread.count,
          unreadCapped: unread.capped,
          // Computed from the rows `unreadForRoom` already read — see badges.ts.
          hasMention: unread.hasMention,
          isPinned: m.isPinned ?? false,
          pinnedAt: m.pinnedAt ?? null,
          isArchived: m.isArchived ?? false,
          archivedAt: m.archivedAt ?? null,
          // The caller's own mute, RAW rather than resolved against the clock.
          //
          // Sending a resolved `isMuted: true` would be a lie with a shelf
          // life: this is a reactive subscription, and `mutedUntil` passing is
          // not a database change, so nothing re-fires the query when a mute
          // lapses under an open client. It would sit there claiming the room
          // is muted until the next unrelated write to it.
          //
          // The deadline itself has no shelf life, so the client re-resolves
          // it at render time (`lib/models/room_mute.dart`) and gets the same
          // answer this backend would. It needs the instant anyway to say
          // "until 8:00 PM" in the viewer's own timezone.
          //
          // `unreadCount` above is deliberately the TRUE count even when
          // `muteBadges` is set: the room info screen can then say "muted, 12
          // unread", and hiding the pill stays a presentation decision in one
          // place rather than a hole in the data. `badges.badgeTotalFor` is
          // where a badge-muted room actually stops counting.
          muteNotifications: m.muteNotifications ?? false,
          muteBadges: m.muteBadges ?? false,
          mutedUntil: m.mutedUntil ?? null,
        };
      })
    );

    return rooms
      .filter(Boolean)
      .sort((a, b) => (b!.lastMessageTime ?? b!.createdAt) - (a!.lastMessageTime ?? a!.createdAt));
  },
});

/**
 * Per-viewer chat-list organization: pin/unpin and archive/unarchive a room
 * for the calling user only. Same lookup-then-patch shape as `markRoomRead`
 * (messages.ts) — patched on the caller's own `roomMembers` row, so it never
 * touches how the room looks to anyone else in it.
 */
async function patchOwnMembership(
  ctx: any,
  roomId: any,
  userId: any,
  patch: Record<string, unknown>
) {
  const membership = await ctx.db
    .query("roomMembers")
    .withIndex("by_room_user", (q: any) => q.eq("roomId", roomId).eq("userId", userId))
    .first();
  if (!membership) return; // not a member, silently no-op — same as markRoomRead
  await ctx.db.patch(membership._id, patch);
}

export const pinRoom = mutation({
  args: { roomId: v.id("rooms"), userId: v.id("users") },
  returns: v.null(),
  handler: async (ctx, { roomId, userId }) => {
    await patchOwnMembership(ctx, roomId, userId, { isPinned: true, pinnedAt: Date.now() });
    return null;
  },
});

export const unpinRoom = mutation({
  args: { roomId: v.id("rooms"), userId: v.id("users") },
  returns: v.null(),
  handler: async (ctx, { roomId, userId }) => {
    await patchOwnMembership(ctx, roomId, userId, { isPinned: false, pinnedAt: undefined });
    return null;
  },
});

export const archiveRoom = mutation({
  args: { roomId: v.id("rooms"), userId: v.id("users") },
  returns: v.null(),
  handler: async (ctx, { roomId, userId }) => {
    await patchOwnMembership(ctx, roomId, userId, { isArchived: true, archivedAt: Date.now() });
    return null;
  },
});

export const unarchiveRoom = mutation({
  args: { roomId: v.id("rooms"), userId: v.id("users") },
  returns: v.null(),
  handler: async (ctx, { roomId, userId }) => {
    await patchOwnMembership(ctx, roomId, userId, { isArchived: false, archivedAt: undefined });
    return null;
  },
});

/**
 * Silence a room for the caller — either or both of its two noises, for a
 * bounded stretch or until they say otherwise. See `mute.ts`.
 *
 * [durationMs] is a LENGTH, not a deadline, and the deadline is computed here.
 * A client sending its own absolute instant would mute for the wrong length of
 * time on any device whose clock has drifted, and "muted until 8pm" would mean
 * 7:50 on a phone ten minutes fast. What lands in the row is still an absolute
 * epoch — the client needs one to say "until 8:00 PM" in the user's own
 * timezone — it is just this server's arithmetic rather than the caller's.
 * Omitting it means "always", stored as the `MUTE_ALWAYS` sentinel.
 *
 * A plain overwrite of all three columns, which is what makes re-muting an
 * already-muted room a non-case: there is no previous deadline to extend or
 * reconcile, only the one the user just picked.
 *
 * Deliberately permissive about WHICH rooms may be muted. Saved Messages
 * cannot usefully be muted — every push and every unread count already
 * excludes the sender, and you are the only sender there — but that is a fact
 * about the room's shape, and the client's capability table
 * (`lib/models/room_capabilities.dart`) is where this app decides what a kind
 * of room affords. Re-deriving that here in a second language would give the
 * two a chance to disagree, in exchange for stopping a mutation that provably
 * does nothing.
 */
export const muteRoom = mutation({
  args: {
    roomId: v.id("rooms"),
    userId: v.id("users"),
    notifications: v.boolean(),
    badges: v.boolean(),
    /** How long from now. Absent = always. */
    durationMs: v.optional(v.number()),
  },
  returns: v.null(),
  handler: async (ctx, { roomId, userId, notifications, badges, durationMs }) => {
    // Neither switch on is not a mute, it's an unmute — and letting it write a
    // live `mutedUntil` with nothing behind it would show a "Muted" pill on a
    // room that is anything but.
    if (!notifications && !badges) {
      await patchOwnMembership(ctx, roomId, userId, {
        muteNotifications: undefined,
        muteBadges: undefined,
        mutedUntil: undefined,
      });
      return null;
    }
    const until =
      durationMs === undefined || durationMs === null
        ? MUTE_ALWAYS
        // Clamped forward: a zero or negative duration would write a deadline
        // already in the past, i.e. a mute that was over before the mutation
        // returned, and the user would watch their own tap do nothing.
        : Date.now() + Math.max(1000, durationMs);
    await patchOwnMembership(ctx, roomId, userId, {
      muteNotifications: notifications,
      muteBadges: badges,
      mutedUntil: until,
    });
    return null;
  },
});

/**
 * End a mute early. Clears all three columns rather than winding `mutedUntil`
 * back, so an unmuted row is byte-identical to one that was never muted and
 * there is no half-state for a reader to misinterpret.
 */
export const unmuteRoom = mutation({
  args: { roomId: v.id("rooms"), userId: v.id("users") },
  returns: v.null(),
  handler: async (ctx, { roomId, userId }) => {
    await patchOwnMembership(ctx, roomId, userId, {
      muteNotifications: undefined,
      muteBadges: undefined,
      mutedUntil: undefined,
    });
    return null;
  },
});

/**
 * The room's members, with each one's avatar and presence redacted to what
 * [viewerUserId] is allowed to see.
 *
 * This list is the app's single biggest source of other people's faces — it
 * backs the member sheet, room info, the chat header, and the avatar beside
 * every message bubble, because messages carry only a sender name and the
 * client resolves the face from here. It used to hand out `avatarStorageId`,
 * `status` and `lastSeen` raw, on the reasoning that everyone in the list is
 * already in a room with the viewer. Sharing a room is not consent: a public
 * room anyone can join made "avatar: nobody" mean nothing at all.
 *
 * `viewerUserId` is optional so builds already in users' hands keep working —
 * they just get the public-only view, which is the safe direction to fail.
 */
export const getMembers = query({
  identityArg: "viewerUserId" as const,
  args: {
    roomId: v.id("rooms"),
    viewerUserId: v.optional(v.id("users")),
  },
  handler: async (ctx, { roomId, viewerUserId }) => {
    const members = await ctx.db
      .query("roomMembers")
      .withIndex("by_room_user", (q) => q.eq("roomId", roomId))
      .collect();
    const lens = await lensFor(ctx, viewerUserId);
    const now = Date.now();
    const users = await Promise.all(
      members.map(async (m) => {
        const user = await ctx.db.get(m.userId);
        if (!user) return null;
        return {
          // No `email`. Sharing a room with someone is not consent to hand
          // them your address — a public room would have leaked it to every
          // member. users.getProfile serves it to self only.
          ...publicUserView(lens, user, now),
          role: m.role,
          // When they joined, not who they are — and not redacted with the
          // rest, because it says nothing about the person: everyone in the
          // room can already see the join notice and the roster order.
          //
          // The client settles each member's per-speaker colour in join order
          // so an existing member never has their colour taken by someone who
          // arrived later. Ordering by user id instead (what an older client,
          // or an older backend, falls back to) still agrees across devices;
          // it just reshuffles when the roster grows.
          joinedAt: m.joinedAt,
        };
      })
    );
    return users.filter(Boolean);
  },
});

// Internal query: who, other than [excludeUserId], is in this room. Feeds the
// notification fan-out, which resolves each user's devices itself.
//
// Carries each member's resolved mute (see `mute.ts`) because the rows are
// already in hand and the fan-out has to sort recipients into three buckets:
// people who get the message, people who muted the alert but still want their
// app-icon count moved, and people who muted both and get nothing. Resolved
// here against a single `Date.now()` so every recipient of one message is
// judged against the same instant.
//
// Callers that only want the roster (`revokeMessagePushes`) can ignore the two
// flags — a dismiss push must reach a muted member anyway, since it is silent
// and its whole job is correcting a badge.
//
// `messageId` is optional and, when passed, folds in the existence probe
// `sendMessagePush` used to make as a separate `runQuery` first: two
// sequential reads with no side effect between them are one wasted round trip
// on the hottest push path in the app. `revokeMessagePushes` deliberately
// omits it — it operates on an already-deleted message and must not
// short-circuit on that fact.
export const getMemberIds = internalQuery({
  args: {
    roomId: v.id("rooms"),
    excludeUserId: v.id("users"),
    messageId: v.optional(v.id("messages")),
    /**
     * When true, also resolves what a chat-message push needs beyond the
     * roster: whether the room is a group (not a 1:1 DM) and its name for a
     * subtitle, plus — respecting [excludeUserId]'s own avatar-visibility
     * setting, exactly like the ringer in calls.ts — a resolved avatar URL
     * for each member actually allowed to see it.
     *
     * Optional so `revokeMessagePushes`, which only ever wants the roster,
     * doesn't pay for a lookup it never uses.
     */
    resolvePushContext: v.optional(v.boolean()),
  },
  handler: async (
    ctx,
    { roomId, excludeUserId, messageId, resolvePushContext },
  ) => {
    if (messageId !== undefined) {
      const msg = await ctx.db.get(messageId);
      if (!msg) return { exists: false, members: [] };
    }
    const memberRows = await ctx.db
      .query("roomMembers")
      .withIndex("by_room_user", (q) => q.eq("roomId", roomId))
      .collect();
    const now = Date.now();
    const filtered = memberRows.filter(
      (m) => m.userId.toString() !== excludeUserId.toString(),
    );

    // isGroup mirrors the client's own `ChatRoom.isDm` getter
    // (lib/models/chat_room.dart): a DM's `name` is the internal
    // `dm:regular:<id>:<id>` / `dm:self:<id>` key, never a real title, so
    // "not a dm:-prefixed name" IS the group test — there is no separate
    // `isGroup` column to drift out of sync with it.
    let isGroup = false;
    let roomName: string | undefined;
    // `any`, like the rest of this file's cross-table reads (e.g. `room` a
    // few lines down): `ctx.db.get` on an `Id<"users">` already narrows to
    // `Doc<"users"> | null` on its own, but declaring the var ahead of the
    // conditional that fills it in forces a wider annotation up front.
    let senderRow: any = null;
    let senderAvatarUrl: string | null = null;

    if (resolvePushContext) {
      const room = await ctx.db.get(roomId);
      isGroup = !!room && !room.name.startsWith("dm:");
      roomName = isGroup ? room!.name : undefined;

      senderRow = await ctx.db.get(excludeUserId);
      if (senderRow?.avatarStorageId) {
        senderAvatarUrl = await ctx.storage.getUrl(senderRow.avatarStorageId);
      }
    }
    // "public" unless the sender said otherwise — see visibility.ts's
    // DEFAULT_LEVEL. Read straight off the row rather than through a lens
    // here: a lens is built once per VIEWER and tested against many subjects,
    // which is backwards for one sender and many recipients, so building one
    // per member below is reserved for the minority ("friends"/"nobody") case
    // that actually needs a per-recipient answer. This is the hottest push
    // path in the app; the common "public" avatar should cost nothing extra.
    const avatarLevel = senderRow?.visibility?.avatar ?? "public";

    const members = [];
    for (const m of filtered) {
      const mute = resolveMute(m, now);
      let avatarVisible = false;
      if (resolvePushContext && senderAvatarUrl && senderRow) {
        if (avatarLevel === "public") {
          avatarVisible = true;
        } else {
          const lens = await lensFor(ctx, m.userId);
          avatarVisible = lens.canSee(senderRow, "avatar");
        }
      }
      members.push({
        userId: m.userId,
        mutesNotifications: mute.notifications,
        mutesBadges: mute.badges,
        avatarVisible,
      });
    }

    return { exists: true, isGroup, roomName, senderAvatarUrl, members };
  },
});

export const getRoom = query({
  args: { roomId: v.id("rooms") },
  handler: async (ctx, { roomId }) => {
    const room = await ctx.db.get(roomId);
    if (!room) return null;
    const members = await ctx.db
      .query("roomMembers")
      .withIndex("by_room_user", (q) => q.eq("roomId", roomId))
      .collect();
    const { passwordHash, ...rest } = room;
    return { ...rest, participantIds: members.map((m) => m.userId.toString()), hasPassword: !!passwordHash };
  },
});

export const getOrCreateDM = mutation({
  args: {
    userId: v.id("users"),
    friendId: v.id("users"),
    roomType: v.optional(v.string()),
    messageLifetime: v.optional(v.number()),
  },
  handler: async (ctx, { userId, friendId, roomType, messageLifetime }) => {
    if (userId.toString() === friendId.toString()) throw new Error("CANNOT_DM_SELF");

    // Either party being a child gates the DM: family is always fine, anyone
    // else has to have cleared the guardian relay into an accepted contact.
    await assertChildMayReach(ctx, userId, friendId);
    await assertChildMayReach(ctx, friendId, userId);

    const acceptedForward = await ctx.db
      .query("friendships")
      .withIndex("by_pair", (q) => q.eq("userId", userId).eq("friendId", friendId))
      .first();
    const acceptedReverse = await ctx.db
      .query("friendships")
      .withIndex("by_pair", (q) => q.eq("userId", friendId).eq("friendId", userId))
      .first();

    const isAccepted =
      acceptedForward?.status === "accepted" || acceptedReverse?.status === "accepted";
    if (!isAccepted) throw new Error("FRIENDSHIP_REQUIRED");

    const resolvedRoomType = roomType ?? "Regular Room";
    const roomKey = resolvedRoomType === "Chamber of Secrets" ? "secret" : "regular";
    const ordered = [userId.toString(), friendId.toString()].sort();
    const name = `dm:${roomKey}:${ordered[0]}:${ordered[1]}`;

    const existingByName = await ctx.db
      .query("rooms")
      .withIndex("by_name", (q) => q.eq("name", name))
      .first();
    if (existingByName) return existingByName._id;

    if (roomKey === "regular") {
      const legacyName = `dm:${ordered[0]}:${ordered[1]}`;
      const legacyRoom = await ctx.db
        .query("rooms")
        .withIndex("by_name", (q) => q.eq("name", legacyName))
        .first();
      if (legacyRoom) return legacyRoom._id;
    }

    // No NEW DM with a system account — deliberately here, below every lookup
    // above, so this is a "create" guard and not an "open" one.
    //
    // Placing it at the top of the handler is the obvious move and it is wrong.
    // The report room's name is exactly the one this function derives, so every
    // return above hands back the room that already exists; refusing early would
    // mean the maintainer tapping MonkeyHub Logs in their friends list got an
    // error instead of the thread they were looking at yesterday.
    //
    // Nothing is lost by allowing that: `ensureReportRoom` builds the room, and
    // this cannot produce a second one for the same pair even without the guard.
    // What the guard stops is a room for a pair that has none — a second system
    // account, or a Chamber of Secrets variant of the report DM, whose
    // `messageLifetime` would delete bug reports on a timer.
    await assertNoSystemAccount(ctx, userId, friendId);

    const roomId = await ctx.db.insert("rooms", {
      name,
      createdBy: userId,
      createdAt: Date.now(),
      isPrivate: true,
      memberCount: 2,
      type: resolvedRoomType,
      messageLifetime,
    });

    await ctx.db.insert("roomMembers", {
      roomId,
      userId,
      joinedAt: Date.now(),
      role: "owner",
      seenVisibility: await seenVisibilityOf(ctx, userId),
    });
    await ctx.db.insert("roomMembers", {
      roomId,
      userId: friendId,
      joinedAt: Date.now(),
      role: "member",
      seenVisibility: await seenVisibilityOf(ctx, friendId),
    });

    return roomId;
  },
});

/**
 * The self-chat every account has: a one-member DM-shaped room named
 * `dm:self:<userId>`, pinned to start with. Idempotent — called on every
 * launch from ChatRepository._attach so pre-existing accounts self-heal it
 * too, not just new signups. The early return on an existing room is what
 * makes "pinned to start with" hold: a viewer who unpins or archives it stays
 * unpinned/archived, because this never runs again for them.
 *
 * Built the same way `problemReports.ts`'s `ensureReportRoom` builds the
 * system-account report room, and for the same reason: `getOrCreateDM`
 * throws CANNOT_DM_SELF and assumes two distinct members, neither of which
 * fits a room with exactly one. This function is a deliberate bypass of
 * `getOrCreateDM`, not a variant of it — it must never call
 * `assertChildMayReach`, since that check tests reachability of *someone
 * else* and a child account has no family/friendship row pointing at itself,
 * so calling it here would incorrectly throw CHILD_APPROVAL_REQUIRED on a
 * child's own notes-to-self room.
 */
export const ensureSavedMessagesRoom = mutation({
  args: { userId: v.id("users") },
  returns: v.id("rooms"),
  handler: async (ctx, { userId }) => {
    const name = `dm:self:${userId.toString()}`;

    const existing = await ctx.db
      .query("rooms")
      .withIndex("by_name", (q) => q.eq("name", name))
      .first();
    if (existing) return existing._id;

    const roomId = await ctx.db.insert("rooms", {
      name,
      createdBy: userId,
      createdAt: Date.now(),
      isPrivate: true,
      memberCount: 1,
      type: "Regular Room",
      // No messageLifetime — a self-notes chat that erases itself on a timer
      // is the one thing this room must not do (same reasoning as the report
      // room, problemReports.ts).
    });
    await ctx.db.insert("roomMembers", {
      roomId,
      userId,
      joinedAt: Date.now(),
      role: "owner",
      seenVisibility: await seenVisibilityOf(ctx, userId),
      // Pinned on day one so it opens at the top of the list, but it's an
      // ordinary per-viewer membership flag from here on: pinRoom/unpinRoom
      // and archiveRoom/unarchiveRoom all accept this room like any other,
      // and room_filter.dart's partitionPinned reads the flag rather than
      // assuming it.
      isPinned: true,
      pinnedAt: Date.now(),
    });
    return roomId;
  },
});

export const isMember = query({
  args: { roomId: v.id("rooms"), userId: v.id("users") },
  handler: async (ctx, { roomId, userId }) => {
    const member = await ctx.db
      .query("roomMembers")
      .withIndex("by_room_user", (q) => q.eq("roomId", roomId).eq("userId", userId))
      .first();
    return !!member;
  },
});

export const getMembership = query({
  args: { roomId: v.id("rooms"), userId: v.id("users") },
  handler: async (ctx, { roomId, userId }) => {
    const m = await ctx.db
      .query("roomMembers")
      .withIndex("by_room_user", (q) => q.eq("roomId", roomId).eq("userId", userId))
      .first();
    return m ? { role: m.role } : null;
  },
});

/**
 * Returns the set of rooms both [userId] and [otherUserId] are members of,
 * split into group rooms vs. the DM (if any). Used by the block-confirm sheet
 * so the blocker can see exactly what will (and won't) be affected.
 */
export const listShared = query({
  args: { userId: v.id("users"), otherUserId: v.id("users") },
  handler: async (ctx, { userId, otherUserId }) => {
    const mine = await ctx.db
      .query("roomMembers")
      .withIndex("by_user", (q) => q.eq("userId", userId))
      .collect();
    const groupRooms: any[] = [];
    let hasDm = false;
    for (const m of mine) {
      const otherMembership = await ctx.db
        .query("roomMembers")
        .withIndex("by_room_user", (q) =>
          q.eq("roomId", m.roomId).eq("userId", otherUserId)
        )
        .first();
      if (!otherMembership) continue;
      const room = await ctx.db.get(m.roomId);
      if (!room) continue;
      if (room.name?.startsWith("dm:")) {
        hasDm = true;
      } else {
        groupRooms.push({
          _id: room._id,
          name: room.name,
          memberCount: room.memberCount,
          avatarStorageId: room.avatarStorageId,
          isPrivate: room.isPrivate,
          type: room.type,
        });
      }
    }
    return { groupRooms, hasDm };
  },
});
