import { mutation, query } from "./functions";
import { internal } from "./_generated/api";
import { v } from "convex/values";
import type { Id } from "./_generated/dataModel";
import {
  ERR_NOT_ALLOWED,
  STAGE_RECIPIENT_GUARDIAN,
  STAGE_SENDER_GUARDIAN,
  childPolicyOf,
  familyOf,
  guardiansOf,
  initialStageFor,
  isReleasedToRecipient,
} from "./childGuard";
import { ERR_SYSTEM_ACCOUNT, isSystemAccount } from "./systemAccount";
import { lensFor, publicUserView, seenVisibilityOf } from "./visibility";
import { searchUsersCore } from "./users";

/**
 * Pings whoever now holds a request.
 *
 * Deliberately explicit about the audience: while a request sits at a
 * guardian hop, the person it's addressed to must learn nothing about it —
 * so the push goes to the guardian, never to them.
 *
 * When nothing is holding it (`stage === undefined`, i.e. no supervision on
 * either side) the recipient gets it directly. That case had no push at all
 * before — friend requests have always arrived silently — which is why a
 * request to a child looked like "notifications are broken" even though the
 * guardian hop was firing correctly.
 */
async function notifyHolder(
  ctx: any,
  stage: string | undefined,
  senderId: any,
  recipientId: any,
) {
  const audience =
    stage === STAGE_SENDER_GUARDIAN
      ? await guardiansOf(ctx, senderId)
      : stage === STAGE_RECIPIENT_GUARDIAN
        ? await guardiansOf(ctx, recipientId)
        : [recipientId];
  if (audience.length === 0) return;
  const sender = await ctx.db.get(senderId);
  const who = sender?.name ?? sender?.username ?? "Someone";
  const forGuardian =
    stage === STAGE_SENDER_GUARDIAN || stage === STAGE_RECIPIENT_GUARDIAN;
  await ctx.scheduler.runAfter(0, internal.notifications.sendApprovalPush, {
    userIds: audience.map((u: any) => u.toString()),
    title: forGuardian ? "Needs your OK" : "New request",
    body:
      stage === STAGE_SENDER_GUARDIAN
        ? `${who} wants to add someone`
        : stage === STAGE_RECIPIENT_GUARDIAN
          ? `${who} wants to add your child`
          : `${who} sent you a request`,
  });
}

async function insertRequestMessage(
  ctx: any,
  requestId: string,
  userId: string,
  content: string,
  timestamp = Date.now()
) {
  await ctx.db.insert("friendRequestMessages", {
    requestId,
    userId,
    content,
    createdAt: timestamp,
  });
}

async function clearRequestMessages(ctx: any, requestId: string) {
  const messages = await ctx.db
    .query("friendRequestMessages")
    .withIndex("by_request", (q: any) => q.eq("requestId", requestId))
    .collect();
  for (const message of messages) {
    await ctx.db.delete(message._id);
  }
}

async function getDirectFriendship(ctx: any, userId: any, otherUserId: any) {
  const outgoing = await ctx.db
    .query("friendships")
    .withIndex("by_pair", (q: any) => q.eq("userId", userId).eq("friendId", otherUserId))
    .first();
  const incoming = await ctx.db
    .query("friendships")
    .withIndex("by_pair", (q: any) => q.eq("userId", otherUserId).eq("friendId", userId))
    .first();

  return { outgoing, incoming };
}

async function createDirectRoom(
  ctx: any,
  requesterId: any,
  receiverId: any,
  roomType?: string,
  messageLifetime?: number,
): Promise<Id<"rooms">> {
  const normalizedRoomType = roomType ?? "Regular Room";
  const roomKey = normalizedRoomType === "Chamber of Secrets" ? "secret" : "regular";
  const ordered = [requesterId.toString(), receiverId.toString()].sort();
  const roomName = `dm:${roomKey}:${ordered[0]}:${ordered[1]}`;

  const existingRoom = await ctx.db
    .query("rooms")
    .withIndex("by_name", (q: any) => q.eq("name", roomName))
    .first();
  if (existingRoom) return existingRoom._id;

  if (roomKey === "regular") {
    const legacyName = `dm:${ordered[0]}:${ordered[1]}`;
    const legacyRoom = await ctx.db
      .query("rooms")
      .withIndex("by_name", (q: any) => q.eq("name", legacyName))
      .first();
    if (legacyRoom) return legacyRoom._id;
  }

  const roomId = await ctx.db.insert("rooms", {
    name: roomName,
    createdBy: requesterId,
    createdAt: Date.now(),
    isPrivate: true,
    memberCount: 2,
    type: normalizedRoomType,
    messageLifetime,
  });

  await ctx.db.insert("roomMembers", {
    roomId,
    userId: requesterId,
    joinedAt: Date.now(),
    role: "owner",
    seenVisibility: await seenVisibilityOf(ctx, requesterId),
  });
  await ctx.db.insert("roomMembers", {
    roomId,
    userId: receiverId,
    joinedAt: Date.now(),
    role: "member",
    seenVisibility: await seenVisibilityOf(ctx, receiverId),
  });

  return roomId;
}

export const sendRequest = mutation({
  args: { userId: v.id("users"), friendUsername: v.string() },
  handler: async (ctx, { userId, friendUsername }) => {
    const friend = await ctx.db
      .query("users")
      .withIndex("by_username", (q) => q.eq("username", friendUsername))
      .first();
    if (!friend) throw new Error("USER_NOT_FOUND");
    if (friend._id === userId) throw new Error("CANNOT_ADD_SELF");
    // Nobody befriends a system account. This path resolves its target from a
    // typed USERNAME, so unlike everywhere else it is reachable without the
    // search filter ever being consulted — someone who learned the handle could
    // otherwise queue a request that nothing will ever accept or decline.
    if (isSystemAccount(friend)) throw new Error(ERR_SYSTEM_ACCOUNT);

    // Block check.
    //
    // Asymmetric on purpose:
    //   - If I (caller) blocked them: actionable error so the UI can prompt
    //     to unblock first. The caller already knows about their own block.
    //   - If they blocked me: generic USER_NOT_FOUND. The caller MUST NOT
    //     learn they are blocked — that would defeat the point of a block.
    const iBlockedThem = await ctx.db
      .query("blocks")
      .withIndex("by_pair", (q) =>
        q.eq("userId", userId).eq("blockedUserId", friend._id)
      )
      .first();
    const theyBlockedMe = await ctx.db
      .query("blocks")
      .withIndex("by_pair", (q) =>
        q.eq("userId", friend._id).eq("blockedUserId", userId)
      )
      .first();
    if (iBlockedThem) throw new Error("UNBLOCK_FIRST");
    if (theyBlockedMe) throw new Error("USER_NOT_FOUND");

    // Friend-request privacy is *not* a personal judgment (unlike a block),
    // it's just a global setting — so we name it honestly. The client also
    // surfaces this state up-front via getProfile's `acceptsFriendRequests`
    // flag (the SEND REQUEST button is pre-disabled). This error is the
    // safety net for stale-cache races.
    if ((friend.visibility?.friendRequests ?? "public") === "nobody") {
      throw new Error("NOT_ACCEPTING_REQUESTS");
    }

    const existing = await ctx.db
      .query("friendships")
      .withIndex("by_pair", (q) =>
        q.eq("userId", userId).eq("friendId", friend._id)
      )
      .first();
    // A guardian's "no" isn't permanent — a denied row is replaceable.
    if (existing && existing.status === "denied") {
      await ctx.db.delete(existing._id);
    } else if (existing) {
      throw new Error("ALREADY_FRIENDS_OR_PENDING");
    }

    const stage = await initialStageFor(ctx, userId, friend._id);
    await ctx.db.insert("friendships", {
      userId,
      friendId: friend._id,
      status: "pending",
      createdAt: Date.now(),
      ...(stage ? { stage } : {}),
    });
    await notifyHolder(ctx, stage, userId, friend._id);
    return friend._id;
  },
});

export const acceptRequest = mutation({
  args: { userId: v.id("users"), requesterId: v.id("users") },
  handler: async (ctx, { userId, requesterId }) => {
    const request = await ctx.db
      .query("friendships")
      .withIndex("by_pair", (q) =>
        q.eq("userId", requesterId).eq("friendId", userId)
      )
      .first();
    if (!request) throw new Error("REQUEST_NOT_FOUND");

    await ctx.db.patch(request._id, { status: "accepted" });
    // Create reverse friendship
    await ctx.db.insert("friendships", {
      userId,
      friendId: requesterId,
      status: "accepted",
      createdAt: Date.now(),
    });
  },
});

export const rejectRequest = mutation({
  args: { userId: v.id("users"), requesterId: v.id("users") },
  handler: async (ctx, { userId, requesterId }) => {
    const request = await ctx.db
      .query("friendships")
      .withIndex("by_pair", (q) =>
        q.eq("userId", requesterId).eq("friendId", userId)
      )
      .first();
    if (request) await ctx.db.delete(request._id);
  },
});

export const listFriends = query({
  args: { userId: v.id("users") },
  handler: async (ctx, { userId }) => {
    const rows = await ctx.db
      .query("friendships")
      .withIndex("by_user", (q) => q.eq("userId", userId))
      .collect();
    const friendships = rows.filter((f) => f.status === "accepted");

    const friends = await Promise.all(
      friendships.map((f) => ctx.db.get(f.friendId))
    );
    // Everyone here IS a friend of the viewer, so "friends" passes and only a
    // "nobody" setting redacts — but the lens is still what decides that, not
    // an assumption made in this handler.
    const lens = await lensFor(ctx, userId);
    const now = Date.now();
    return friends.filter(Boolean).map((u) => publicUserView(lens, u!, now));
  },
});

/**
 * No current caller — the app subscribes to `listIncomingDirectRequests`
 * instead. Kept (and fixed) rather than deleted because it stays callable by
 * any build already in users' hands; delete it once that's no longer a concern.
 */
export const listPendingRequests = query({
  args: { userId: v.id("users") },
  handler: async (ctx, { userId }) => {
    // Requests sent TO this user. Rows still held at a guardian hop are
    // invisible here — that filter is what keeps an unreleased request from
    // ever reaching a child.
    const rows = await ctx.db
      .query("friendships")
      .withIndex("by_friend", (q) => q.eq("friendId", userId))
      .collect();
    const incoming = rows.filter(
      (f) => f.status === "pending" && isReleasedToRecipient(f.stage),
    );

    const lens = await lensFor(ctx, userId);
    const now = Date.now();
    const requesters = await Promise.all(
      incoming.map(async (f) => {
        const user = await ctx.db.get(f.userId);
        return user
          ? { ...publicUserView(lens, user, now), friendshipId: f._id }
          : null;
      })
    );
    return requesters.filter(Boolean);
  },
});

export const createDirectRequest = mutation({
  args: {
    userId: v.id("users"),
    friendId: v.id("users"),
    roomType: v.string(),
    messageLifetime: v.optional(v.number()),
    initialMessage: v.optional(v.string()),
  },
  handler: async (ctx, { userId, friendId, roomType, messageLifetime, initialMessage }) => {
    if (userId.toString() === friendId.toString()) throw new Error("CANNOT_ADD_SELF");

    const target = await ctx.db.get(friendId);
    if (!target) throw new Error("USER_NOT_FOUND");
    // See `sendRequest`. Redundant with `SYSTEM_VISIBILITY.friendRequests`, which
    // the check further down already honours — kept because that one is a data
    // value on one row and this one is the rule.
    if (isSystemAccount(target)) throw new Error(ERR_SYSTEM_ACCOUNT);

    // Block check — asymmetric (see sendRequest for the rationale).
    const iBlockedThem = await ctx.db
      .query("blocks")
      .withIndex("by_pair", (q) =>
        q.eq("userId", userId).eq("blockedUserId", friendId)
      )
      .first();
    const theyBlockedMe = await ctx.db
      .query("blocks")
      .withIndex("by_pair", (q) =>
        q.eq("userId", friendId).eq("blockedUserId", userId)
      )
      .first();
    if (iBlockedThem) throw new Error("UNBLOCK_FIRST");
    if (theyBlockedMe) throw new Error("USER_NOT_FOUND");

    // Friend-request privacy (see sendRequest for rationale on the name).
    if ((target.visibility?.friendRequests ?? "public") === "nobody") {
      throw new Error("NOT_ACCEPTING_REQUESTS");
    }

    // A child reaching outside the family needs the "ask to add" permission.
    // Family members are exempt — they're reachable with no request at all.
    const senderPolicy = await childPolicyOf(ctx, userId);
    if (senderPolicy !== null) {
      const family = await familyOf(ctx, userId);
      if (!family.has(friendId.toString()) && !senderPolicy.canRequestContacts) {
        throw new Error(ERR_NOT_ALLOWED);
      }
    }

    const { outgoing, incoming } = await getDirectFriendship(ctx, userId, friendId);

    if (outgoing?.status === "accepted" || incoming?.status === "accepted") {
      throw new Error("ALREADY_FRIENDS");
    }
    if (outgoing?.status === "pending") {
      throw new Error("REQUEST_ALREADY_PENDING");
    }
    if (incoming?.status === "pending") {
      throw new Error("REQUEST_ALREADY_RECEIVED");
    }
    // A guardian's "no" isn't permanent. Clear the dead row so the child can
    // ask again later; the guardian simply sees the request a second time.
    if (outgoing?.status === "denied") await ctx.db.delete(outgoing._id);
    if (incoming?.status === "denied") await ctx.db.delete(incoming._id);

    // Where this request enters the guardian relay. `undefined` for adult to
    // adult, which behaves exactly as it did before child accounts existed.
    const stage = await initialStageFor(ctx, userId, friendId);

    const trimmed = initialMessage?.trim() ?? "";
    const requestId = await ctx.db.insert("friendships", {
      userId,
      friendId,
      status: "pending",
      createdAt: Date.now(),
      roomType,
      messageLifetime,
      initialMessage: trimmed,
      ...(stage ? { stage } : {}),
    });
    if (trimmed.length > 0) {
      await insertRequestMessage(ctx, requestId, userId, trimmed);
    }
    await notifyHolder(ctx, stage, userId, friendId);
    return requestId;
  },
});

export const appendDirectRequestMessage = mutation({
  args: {
    requestId: v.id("friendships"),
    userId: v.id("users"),
    content: v.string(),
  },
  handler: async (ctx, { requestId, userId, content }) => {
    const request = await ctx.db.get(requestId);
    if (!request || request.status !== "pending") throw new Error("REQUEST_NOT_FOUND");

    await insertRequestMessage(ctx, requestId, userId, content.trim());
  },
});

export const listDirectRequestMessages = query({
  args: { requestId: v.id("friendships") },
  handler: async (ctx, { requestId }) => {
    const messages = await ctx.db
      .query("friendRequestMessages")
      .withIndex("by_request", (q: any) => q.eq("requestId", requestId))
      .collect();
    return messages
      .sort((a, b) => a.createdAt - b.createdAt)
      .map((m) => ({
        _id: m._id,
        userId: m.userId,
        content: m.content,
        createdAt: m.createdAt,
      }));
  },
});

export const approveDirectRequest = mutation({
  args: { userId: v.id("users"), requesterId: v.id("users") },
  handler: async (ctx, { userId, requesterId }) => {
    const request = await ctx.db
      .query("friendships")
      .withIndex("by_pair", (q) =>
        q.eq("userId", requesterId).eq("friendId", userId)
      )
      .first();
    if (!request || request.status !== "pending") throw new Error("REQUEST_NOT_FOUND");
    // A child cannot release their own request. Until a guardian has advanced
    // it to `awaitingRecipient` this row isn't theirs to accept — and they
    // can't even see it, so reaching here means a hand-crafted call.
    if (!isReleasedToRecipient(request.stage)) {
      throw new Error("REQUEST_NOT_FOUND");
    }

    const requestMessages = await ctx.db
      .query("friendRequestMessages")
      .withIndex("by_request", (q: any) => q.eq("requestId", request._id))
      .collect();
    requestMessages.sort((a, b) => a.createdAt - b.createdAt);

    // Only create a room if there are messages to migrate (or a room already exists).
    // A plain friend request with no messages just marks the friendship as accepted.
    const hasMessages = requestMessages.length > 0;
    // `Id<"rooms">`, not `string`. This annotation was hand-written as `string`,
    // which is not the same type — every `db.insert`/`db.patch` that took this
    // value below was rejected, and the id itself lost the table it belongs to.
    const roomId: Id<"rooms"> | null = hasMessages
      ? (request.roomId ??
          (await createDirectRoom(
            ctx,
            requesterId,
            userId,
            request.roomType,
            request.messageLifetime
          )))
      : null;

    const now = Date.now();
    await ctx.db.patch(request._id, {
      status: "accepted",
      respondedAt: now,
      ...(roomId ? { roomId } : {}),
    });

    const reverse = await ctx.db
      .query("friendships")
      .withIndex("by_pair", (q) =>
        q.eq("userId", userId).eq("friendId", requesterId)
      )
      .first();

    if (reverse) {
      await ctx.db.patch(reverse._id, {
        status: "accepted",
        respondedAt: now,
        roomType: reverse.roomType ?? request.roomType,
        messageLifetime: reverse.messageLifetime ?? request.messageLifetime,
        ...(roomId ? { roomId } : {}),
      });
    } else {
      await ctx.db.insert("friendships", {
        userId,
        friendId: requesterId,
        status: "accepted",
        createdAt: now,
        respondedAt: now,
        roomType: request.roomType,
        messageLifetime: request.messageLifetime,
        ...(roomId ? { roomId } : {}),
      });
    }

    if (roomId && hasMessages) {
      // Compute expiry from approval time if this is a secret room.
      const expiresAt = request.messageLifetime
        ? now + request.messageLifetime * 1000
        : undefined;

      for (const msg of requestMessages) {
        const messageId = await ctx.db.insert("messages", {
          roomId,
          userId: msg.userId,
          content: msg.content,
          createdAt: msg.createdAt,
          type: "text",
          expiresAt,
        });
        if (expiresAt !== undefined) {
          await ctx.scheduler.runAt(
            new Date(expiresAt),
            internal.messages.expireMessage,
            { messageId }
          );
        }
      }
      const last = requestMessages[requestMessages.length - 1];
      await ctx.db.patch(roomId, {
        lastMessage: last.content.slice(0, 100),
        lastMessageTime: last.createdAt,
      });
      await clearRequestMessages(ctx, request._id);
    }

    // Tell the sender their request landed. Without this the other half of
    // the exchange is silent: they ask, and then nothing ever tells them yes.
    const accepter = await ctx.db.get(userId);
    await ctx.scheduler.runAfter(0, internal.notifications.sendApprovalPush, {
      userIds: [requesterId.toString()],
      title: "Request accepted",
      body: `${accepter?.name ?? accepter?.username ?? "They"} accepted your request`,
    });

    return roomId;
  },
});

export const cancelDirectRequest = mutation({
  args: { userId: v.id("users"), friendId: v.id("users") },
  handler: async (ctx, { userId, friendId }) => {
    const request = await ctx.db
      .query("friendships")
      .withIndex("by_pair", (q) => q.eq("userId", userId).eq("friendId", friendId))
      .first();
    if (request?.status === "pending") {
      await clearRequestMessages(ctx, request._id);
      await ctx.db.delete(request._id);
    }
  },
});

export const rejectDirectRequest = mutation({
  args: { userId: v.id("users"), requesterId: v.id("users") },
  handler: async (ctx, { userId, requesterId }) => {
    const request = await ctx.db
      .query("friendships")
      .withIndex("by_pair", (q) =>
        q.eq("userId", requesterId).eq("friendId", userId)
      )
      .first();
    // Same gate as approve: an unreleased row belongs to a guardian, who
    // declines it via `family.advanceContactRequest`.
    if (request?.status === "pending" && isReleasedToRecipient(request.stage)) {
      await clearRequestMessages(ctx, request._id);
      await ctx.db.delete(request._id);
    }
  },
});

export const listIncomingDirectRequests = query({
  args: { userId: v.id("users") },
  handler: async (ctx, { userId }) => {
    // Only rows a guardian has released reach the recipient. This is the
    // single line that makes a supervised request invisible until its turn.
    const rows = await ctx.db
      .query("friendships")
      .withIndex("by_friend", (q) => q.eq("friendId", userId))
      .collect();
    const incoming = rows.filter(
      (f) => f.status === "pending" && isReleasedToRecipient(f.stage),
    );

    const lens = await lensFor(ctx, userId);
    const now = Date.now();
    const requests = await Promise.all(
      incoming.map(async (request) => {
        const requester = await ctx.db.get(request.userId);
        if (!requester) return null;

        const messages = await ctx.db
          .query("friendRequestMessages")
          .withIndex("by_request", (q: any) => q.eq("requestId", request._id))
          .collect();

        return {
          _id: request._id,
          createdAt: request.createdAt,
          roomType: request.roomType ?? "Regular Room",
          messageLifetime: request.messageLifetime,
          initialMessage: request.initialMessage ?? "",
          messageCount: messages.length,
          // A pending request is not a friendship, so a requester at
          // "avatar: friends" arrives faceless — which is the setting working,
          // not a bug. Their handle and name still identify them well enough
          // to decide.
          user: publicUserView(lens, requester, now),
        };
      })
    );

    return requests.filter(Boolean);
  },
});

export const listOutgoingDirectRequests = query({
  args: { userId: v.id("users") },
  handler: async (ctx, { userId }) => {
    const rows = await ctx.db
      .query("friendships")
      .withIndex("by_user", (q) => q.eq("userId", userId))
      .collect();
    const outgoing = rows.filter((f) => f.status === "pending");

    const lens = await lensFor(ctx, userId);
    const now = Date.now();
    const requests = await Promise.all(
      outgoing.map(async (request) => {
        const receiver = await ctx.db.get(request.friendId);
        if (!receiver) return null;

        const messages = await ctx.db
          .query("friendRequestMessages")
          .withIndex("by_request", (q: any) => q.eq("requestId", request._id))
          .collect();

        return {
          _id: request._id,
          createdAt: request.createdAt,
          roomType: request.roomType ?? "Regular Room",
          messageLifetime: request.messageLifetime,
          initialMessage: request.initialMessage ?? "",
          messageCount: messages.length,
          // Lets the sender's UI distinguish "waiting for a grown-up" from
          // "waiting for them" instead of showing a bare "pending".
          stage: request.stage ?? null,
          // Same as the incoming list: sending someone a request doesn't
          // unlock their profile while it's still pending.
          user: publicUserView(lens, receiver, now),
        };
      })
    );

    return requests.filter(Boolean);
  },
});

export const removeFriend = mutation({
  args: { userId: v.id("users"), friendId: v.id("users") },
  handler: async (ctx, { userId, friendId }) => {
    const f1 = await ctx.db
      .query("friendships")
      .withIndex("by_pair", (q) => q.eq("userId", userId).eq("friendId", friendId))
      .first();
    const f2 = await ctx.db
      .query("friendships")
      .withIndex("by_pair", (q) => q.eq("userId", friendId).eq("friendId", userId))
      .first();
    if (f1) await ctx.db.delete(f1._id);
    if (f2) await ctx.db.delete(f2._id);
  },
});

/**
 * No current caller — `users:searchUsers` is the one the client actually
 * calls (`chat_api.dart`); kept and fixed rather than deleted for the same
 * reason `listPendingRequests` above is, since it stays callable by any build
 * already in users' hands. "Fixed" is the operative word: this used to be an
 * independent copy of the scan in `users.searchUsers` that had already
 * drifted — no blocking filter, no child-safe reachability restriction — the
 * exact duplicated-read-path trap `users.searchUsersCore`'s header comment
 * describes. It now calls that one implementation and narrows the shape
 * afterward, so there is nothing left here that can drift again.
 */
export const searchUsers = query({
  args: { query: v.string(), currentUserId: v.id("users") },
  handler: async (ctx, { query, currentUserId }) => {
    const results = await searchUsersCore(ctx, currentUserId, query, 10);
    return results.map((u) => ({ _id: u._id, username: u.username, status: u.status }));
  },
});
