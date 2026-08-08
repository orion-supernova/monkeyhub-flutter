import { mutation, query, internalQuery } from "./_generated/server";
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
import { lensFor, publicUserView } from "./visibility";
import { unreadForRoom } from "./badges";
import { deleteStored } from "./files";
import { wipeRoomCompletely } from "./roomCleanup";

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
      role: "owner",
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

    const existing = await ctx.db
      .query("roomMembers")
      .withIndex("by_room_user", (q) => q.eq("roomId", roomId).eq("userId", userId))
      .first();
    if (existing) return;

    await ctx.db.insert("roomMembers", {
      roomId,
      userId,
      joinedAt: Date.now(),
      role: "member",
    });
    await ctx.db.patch(roomId, { memberCount: room.memberCount + 1 });
  },
});

export const leave = mutation({
  args: { roomId: v.id("rooms"), userId: v.id("users") },
  handler: async (ctx, { roomId, userId }) => {
    // Leaving a system room is the worst of the three refusals below, because
    // it half-works: the membership row goes, the room lives on, and the next
    // report arrives somewhere the maintainer can no longer see.
    await assertNotSystemRoom(ctx, roomId);
    const member = await ctx.db
      .query("roomMembers")
      .withIndex("by_room_user", (q) => q.eq("roomId", roomId).eq("userId", userId))
      .first();
    if (!member) return;

    await ctx.db.delete(member._id);
    const room = await ctx.db.get(roomId);
    if (room && room.memberCount > 0) {
      await ctx.db.patch(roomId, { memberCount: room.memberCount - 1 });
    }

    // Auto-delete room if now empty
    const remaining = await ctx.db
      .query("roomMembers")
      .withIndex("by_room", (q) => q.eq("roomId", roomId))
      .collect();
    if (remaining.length === 0) {
      await wipeRoomCompletely(ctx, roomId);
      return;
    }

    // Someone leaving can complete a view-once photo's audience: the people
    // still here may all have opened it already, and were only waiting on the
    // person who just walked out. Without this the blob idles until its 14-day
    // deadline. Deferred rather than inline — this is repair work, and it has
    // no business lengthening the mutation the user is waiting on.
    await ctx.scheduler.runAfter(
      0,
      internal.messages.recountViewOnceRecipients,
      { roomId },
    );
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
    if (room.name.startsWith("dm:")) {
      const membership = await ctx.db
        .query("roomMembers")
        .withIndex("by_room_user", (q) => q.eq("roomId", roomId).eq("userId", userId))
        .first();
      if (!membership) throw new Error("NOT_AUTHORIZED");
    } else if (room.createdBy.toString() !== userId.toString()) {
      throw new Error("NOT_OWNER");
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
    if (room.createdBy.toString() !== userId.toString()) throw new Error("NOT_OWNER");
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
    const membership = await ctx.db
      .query("roomMembers")
      .withIndex("by_room_user", (q) => q.eq("roomId", roomId).eq("userId", userId))
      .first();
    if (!membership) throw new Error("NOT_AUTHORIZED"); // any member can update

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
    const membership = await ctx.db
      .query("roomMembers")
      .withIndex("by_room_user", (q) => q.eq("roomId", roomId).eq("userId", userId))
      .first();
    if (!membership) throw new Error("NOT_AUTHORIZED"); // any member can update avatar
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
        // Include participant IDs for the iOS app
        const members = await ctx.db
          .query("roomMembers")
          .withIndex("by_room", (q) => q.eq("roomId", m.roomId))
          .collect();
        const participantIds = members.map((mem) => mem.userId.toString());
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
  args: {
    roomId: v.id("rooms"),
    viewerUserId: v.optional(v.id("users")),
  },
  handler: async (ctx, { roomId, viewerUserId }) => {
    const members = await ctx.db
      .query("roomMembers")
      .withIndex("by_room", (q) => q.eq("roomId", roomId))
      .collect();
    const lens = await lensFor(ctx, viewerUserId);
    const users = await Promise.all(
      members.map(async (m) => {
        const user = await ctx.db.get(m.userId);
        if (!user) return null;
        return {
          // No `email`. Sharing a room with someone is not consent to hand
          // them your address — a public room would have leaked it to every
          // member. users.getProfile serves it to self only.
          ...publicUserView(lens, user),
          role: m.role,
        };
      })
    );
    return users.filter(Boolean);
  },
});

// Internal query: who, other than [excludeUserId], is in this room. Feeds the
// notification fan-out, which resolves each user's devices itself.
export const getMemberIds = internalQuery({
  args: { roomId: v.id("rooms"), excludeUserId: v.id("users") },
  handler: async (ctx, { roomId, excludeUserId }) => {
    const members = await ctx.db
      .query("roomMembers")
      .withIndex("by_room", (q) => q.eq("roomId", roomId))
      .collect();
    return members
      .filter((m) => m.userId.toString() !== excludeUserId.toString())
      .map((m) => ({ userId: m.userId }));
  },
});

export const getRoom = query({
  args: { roomId: v.id("rooms") },
  handler: async (ctx, { roomId }) => {
    const room = await ctx.db.get(roomId);
    if (!room) return null;
    const members = await ctx.db
      .query("roomMembers")
      .withIndex("by_room", (q) => q.eq("roomId", roomId))
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

    await ctx.db.insert("roomMembers", { roomId, userId, joinedAt: Date.now(), role: "owner" });
    await ctx.db.insert("roomMembers", { roomId, userId: friendId, joinedAt: Date.now(), role: "member" });

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
