import { mutation, query, internalMutation, internalQuery } from "./_generated/server";
import { internal } from "./_generated/api";
import { v } from "convex/values";
import {
  ERR_APPROVAL_REQUIRED,
  ERR_NOT_ALLOWED,
  childMayUseRoom,
  childPolicyOf,
} from "./childGuard";
import { deleteStored } from "./files";

// ── View-once tuning ────────────────────────────────────────────────────────

/** Burn an armed photo this long after it was sent, opened or not. */
const VIEW_ONCE_DEADLINE_MS = 14 * 24 * 60 * 60 * 1000;

/**
 * How long a download ticket stays valid. This is also the retry window: a
 * client whose fetch dies on bad cellular asks `openViewOnce` again and gets
 * the SAME nonce back, because re-minting would be indistinguishable from a
 * second view. Long enough for a multi-megabyte photo on a bad connection.
 */
const VIEW_ONCE_NONCE_TTL_MS = 120_000;

/**
 * Delay between "the last recipient opened it" and deleting the blob. Must
 * exceed the nonce TTL, or we would delete the file out from under the very
 * download that triggered the burn.
 */
const VIEW_ONCE_BURN_GRACE_MS = VIEW_ONCE_NONCE_TTL_MS + 30_000;

/**
 * Strips a view-once message down to what a client is allowed to hold.
 *
 * This is the whole feature. `files:getFileUrl` is a public query, and on a
 * self-hosted deployment `ctx.storage.getUrl` returns an unsigned URL with no
 * expiry (see the comment in lib/media/file_url_cache.dart). So the storage id
 * IS the picture: any client that learns one can fetch the bytes forever,
 * without ever calling `openViewOnce`. Every read path therefore has to remove
 * it — and remove it unconditionally, including for the sender, so no branch
 * can leak it by being forgotten.
 *
 * `viewOnceOpened` costs one indexed lookup, and only for armed messages, so
 * ordinary rooms pay nothing. Scoping it to the viewer's OWN ledger rows is
 * also what keeps this safe in a subscribed query: inserting a row refires
 * that viewer's `list` (which is how opening on web greys the bubble out on
 * their phone) and nobody else's.
 */
async function sanitizeViewOnce(ctx: any, msg: any, viewerUserId: any) {
  if (msg?.viewOnce !== true) return msg;
  const { mediaStorageId: _id, mediaWidth: _w, mediaHeight: _h, ...rest } = msg;
  let opened = false;
  if (viewerUserId) {
    const row = await ctx.db
      .query("viewOnceViews")
      .withIndex("by_message_user", (q: any) =>
        q.eq("messageId", msg._id).eq("userId", viewerUserId)
      )
      .first();
    opened = row !== null;
  }
  return { ...rest, viewOnceOpened: opened };
}

export const send = mutation({
  args: {
    roomId: v.id("rooms"),
    userId: v.id("users"),
    content: v.string(),
    type: v.optional(v.string()),          // "text" | "image" | "video" | "audio" | "url" | "system"
    mediaStorageId: v.optional(v.id("_storage")),
    // Pixel size of the attachment, so a receiver can lay the bubble out at the
    // picture's real ratio before decoding it. See the schema comment.
    mediaWidth: v.optional(v.number()),
    mediaHeight: v.optional(v.number()),
    senderName: v.optional(v.string()),
    replyToId: v.optional(v.id("messages")),
    // Burn-after-reading. Armed by the sender in the pre-send editor; see the
    // schema comment on `messages.viewOnce`.
    viewOnce: v.optional(v.boolean()),
    // Idempotency key. Optional so older clients keep working — they just get
    // the old at-least-once behaviour. See the schema comment on
    // `messages.clientId`.
    clientId: v.optional(v.string()),
  },
  handler: async (ctx, { roomId, userId, content, type, mediaStorageId, mediaWidth, mediaHeight, senderName, replyToId, viewOnce, clientId }) => {
    // Idempotency, checked before anything else has a chance to happen twice.
    //
    // Everything below this line has side effects that must not be repeated:
    // a second row, a second `rooms.lastMessage` bump, a second push, a second
    // pair of view-once burn schedules. Returning the original id makes a retry
    // indistinguishable from the send having succeeded the first time, which is
    // exactly what the caller believes when it retries.
    if (clientId !== undefined) {
      const existing = await ctx.db
        .query("messages")
        .withIndex("by_room_user_client", (q) =>
          q.eq("roomId", roomId).eq("userId", userId).eq("clientId", clientId)
        )
        .first();
      if (existing) return existing._id;
    }

    // Verify membership
    const membership = await ctx.db
      .query("roomMembers")
      .withIndex("by_room_user", (q) => q.eq("roomId", roomId).eq("userId", userId))
      .first();
    if (!membership) throw new Error("NOT_A_MEMBER");

    const msgType = type ?? "text";

    // Child guard. Membership alone isn't enough: a grant can be revoked
    // while the child is still sitting in the room, and the room's members
    // can change after approval. Re-checked on every send so revocation is
    // immediate rather than "until they close the screen".
    const policy = await childPolicyOf(ctx, userId);
    if (policy !== null) {
      if (!(await childMayUseRoom(ctx, userId, roomId))) {
        throw new Error(ERR_APPROVAL_REQUIRED);
      }
      if (msgType !== "text" && !policy.mediaEnabled) {
        throw new Error(ERR_NOT_ALLOWED);
      }
    }

    // Resolve senderName if not provided
    let resolvedSenderName = senderName;
    if (!resolvedSenderName) {
      const user = await ctx.db.get(userId);
      resolvedSenderName = user?.name ?? user?.username ?? "Unknown";
    }

    const room = await ctx.db.get(roomId);

    // DM block enforcement.
    //
    // Group rooms allow blocks to be one-way (the blocker hides the blockee
    // client-side). For DMs we hard-stop sends in either direction so the
    // block is absolute. The error is intentionally generic — never reveal
    // to the sender that they're the one being blocked.
    if (room?.name?.startsWith("dm:")) {
      const otherMember = await ctx.db
        .query("roomMembers")
        .withIndex("by_room", (q) => q.eq("roomId", roomId))
        .collect();
      const otherId = otherMember.find(
        (m) => m.userId.toString() !== userId.toString()
      )?.userId;
      if (otherId) {
        const iBlockedThem = await ctx.db
          .query("blocks")
          .withIndex("by_pair", (q) =>
            q.eq("userId", userId).eq("blockedUserId", otherId)
          )
          .first();
        const theyBlockedMe = await ctx.db
          .query("blocks")
          .withIndex("by_pair", (q) =>
            q.eq("userId", otherId).eq("blockedUserId", userId)
          )
          .first();
        if (iBlockedThem) throw new Error("UNBLOCK_FIRST");
        if (theyBlockedMe) throw new Error("MESSAGE_FAILED");
      }
    }

    // Check if the room has a message lifetime (Chamber of Secrets)
    const expiresAt = room?.messageLifetime
      ? Date.now() + room.messageLifetime * 1000
      : undefined;

    // Build a denormalized snapshot of the parent at send time. Survives the
    // parent's later deletion so the inline reply tether keeps rendering. We
    // intentionally drop both replyToId AND replyToPreview together if the
    // parent isn't reachable from the same room — never store a dangling id.
    let replyToPreview: {
      senderId: any;
      senderName: string;
      contentPreview: string;
      type: string;
      mediaStorageId?: any;
    } | undefined;
    let resolvedReplyToId: any | undefined;
    // Thread root, derived from the *resolved* parent. Computing it from the
    // raw `replyToId` arg would let a cross-room parent produce a message
    // that belongs to a thread but has no tether — it'd render in the thread
    // with nothing above it. Written only alongside replyToId/replyToPreview.
    let resolvedRootId: any | undefined;
    if (replyToId) {
      const parent = await ctx.db.get(replyToId);
      if (parent && parent.roomId.toString() === roomId.toString()) {
        const parentContent = parent.content ?? "";
        // Quoting a view-once photo must not re-publish it. The preview is a
        // permanent, un-burnable copy of the parent, so carrying the parent's
        // `mediaStorageId` here would hand every reader the storage id the
        // read path works so hard to withhold — and would keep the blob
        // looking referenced to `files.gcOrphanedFiles` after the burn.
        // Sentinel mirrors the "__DELETED__" one used by the fanout below.
        const parentIsViewOnce = parent.viewOnce === true;
        replyToPreview = {
          senderId: parent.userId,
          senderName: parent.senderName ?? "unknown",
          contentPreview: parentIsViewOnce
            ? "__VIEW_ONCE__"
            : parentContent.slice(0, 140),
          type: parent.type ?? "text",
          mediaStorageId: parentIsViewOnce ? undefined : parent.mediaStorageId,
        };
        resolvedReplyToId = replyToId;
        resolvedRootId = parent.rootId ?? parent._id;
      }
    }

    // View-once bookkeeping, done once here rather than once per open. The
    // roster walk is O(members), but only on an armed send.
    const armed = viewOnce === true && mediaStorageId !== undefined;
    let viewOnceFields: Record<string, any> = {};
    if (armed) {
      const roster = await ctx.db
        .query("roomMembers")
        .withIndex("by_room", (q) => q.eq("roomId", roomId))
        .collect();
      const recipients = roster.filter(
        (m) => m.userId.toString() !== userId.toString()
      ).length;
      viewOnceFields = {
        viewOnce: true,
        viewOnceLive: true,
        viewOnceRecipients: recipients,
        viewOnceViewCount: 0,
        viewOnceDeadline: Date.now() + VIEW_ONCE_DEADLINE_MS,
      };
    }

    const messageId = await ctx.db.insert("messages", {
      roomId,
      userId,
      content,
      createdAt: Date.now(),
      type: msgType,
      mediaStorageId,
      // Deliberately dropped on an armed send. The sealed tile is a fixed size,
      // so the picture's true aspect ratio buys the receiver nothing and is one
      // more thing leaking out of a message whose whole point is to leak
      // nothing until it's opened.
      mediaWidth: armed ? undefined : mediaWidth,
      mediaHeight: armed ? undefined : mediaHeight,
      senderName: resolvedSenderName,
      expiresAt,
      // Stored so the retry that arrives after this one commits can find it.
      clientId,
      ...viewOnceFields,
      ...(replyToPreview
        ? { replyToId: resolvedReplyToId, replyToPreview, rootId: resolvedRootId }
        : {}),
    });

    // Schedule server-side deletion for self-destructing messages
    if (expiresAt !== undefined) {
      await ctx.scheduler.runAt(
        new Date(expiresAt),
        internal.messages.expireMessage,
        { messageId }
      );
    }

    // Hard deadline for an armed photo nobody ever opens. The per-message
    // schedule is the primary mechanism — `gcExpiredViewOnce` is only a repair
    // sweep for anything the scheduler dropped.
    if (armed) {
      await ctx.scheduler.runAfter(
        VIEW_ONCE_DEADLINE_MS,
        internal.messages.burnViewOnce,
        { messageId }
      );
      // A room with exactly one member has no recipients at all, so the
      // "everyone has seen it" condition is already true on arrival. Without
      // this the blob would idle for the full deadline.
      if ((viewOnceFields.viewOnceRecipients ?? 0) === 0) {
        await ctx.scheduler.runAfter(
          VIEW_ONCE_BURN_GRACE_MS,
          internal.messages.burnViewOnce,
          { messageId }
        );
      }
    }

    // Update room's last message preview
    const preview = msgType === "text"
      ? content.slice(0, 100)
      : armed
        ? "[photo]"
        : `[${msgType}]`;
    await ctx.db.patch(roomId, {
      lastMessage: preview,
      lastMessageTime: Date.now(),
    });

    // Fire push notifications in background (non-blocking)
    await ctx.scheduler.runAfter(0, internal.notifications.sendMessagePush, {
      roomId,
      messageId,
      senderId: userId,
      senderName: resolvedSenderName,
      content: preview,
      type: msgType,
    });

    return messageId;
  },
});

/**
 * Everything that has to happen when a message stops existing, whether the
 * user deleted it or it self-destructed. Both paths ran verbatim copies of
 * this before; they had already drifted (neither repaired the room preview).
 *
 * Ordering matters: this must run BEFORE `ctx.db.delete(messageId)`, because
 * it reads the message's siblings to re-derive the room preview.
 */
async function removeMessageAndFanout(ctx: any, msg: any, messageId: any) {
  // Reactions.
  const reactions = await ctx.db
    .query("reactions")
    .withIndex("by_message", (q: any) => q.eq("messageId", messageId))
    .collect();
  for (const r of reactions) await ctx.db.delete(r._id);

  // Media. Via `deleteStored` rather than a bare `ctx.storage.delete`, which
  // throws on a file some other path already removed — and would abort the
  // fanout below half-done, leaving children tethered to a deleted parent.
  await deleteStored(ctx, msg.mediaStorageId);

  // View-once ledger. Also runs for messages that were never armed, where the
  // scan is a single empty index range.
  await purgeViewOnceViews(ctx, messageId);

  // Mark every child reply's denormalized preview as deleted so their inline
  // tether keeps rendering ("message removed") instead of pointing at a
  // vanished parent.
  const children = await ctx.db
    .query("messages")
    .withIndex("by_replyTo", (q: any) => q.eq("replyToId", messageId))
    .collect();
  for (const child of children) {
    const existing = child.replyToPreview;
    if (!existing) continue;
    // Drop the copied `mediaStorageId` too. It's a snapshot of the parent's id
    // (see `send`), and the file it named was just deleted — leaving it set
    // points the preview at a blob that no longer exists, and makes the file
    // look referenced to `files.gcOrphanedFiles`.
    const { mediaStorageId: _stale, ...rest } = existing;
    await ctx.db.patch(child._id, {
      replyToPreview: { ...rest, contentPreview: "__DELETED__" },
    });
  }

  await ctx.db.delete(messageId);

  // Repair the room's last-message preview. Only when the removed message was
  // actually the newest — a mid-history delete would otherwise re-write the
  // room doc and needlessly invalidate every member's listUserRooms
  // subscription. Previously nothing did this at all, so deleting the newest
  // message left its text on the room card forever.
  const room = await ctx.db.get(msg.roomId);
  if (room && room.lastMessageTime === msg.createdAt) {
    const newest = await ctx.db
      .query("messages")
      .withIndex("by_room_time", (q: any) => q.eq("roomId", msg.roomId))
      .order("desc")
      .first();
    await ctx.db.patch(msg.roomId, {
      lastMessage: newest
        ? newest.type === "text"
          ? (newest.content ?? "").slice(0, 100)
          : `[${newest.type}]`
        : undefined,
      lastMessageTime: newest ? newest.createdAt : undefined,
    });
  }

  // Take back the pushes. Cancels anything still queued, and asks devices that
  // already showed it to remove it. See notifications.revokeMessagePushes.
  await ctx.scheduler.runAfter(0, internal.notifications.revokeMessagePushes, {
    messageId,
    roomId: msg.roomId,
  });
}

/** Existence probe for `sendMessagePush`, which can't touch the db directly. */
export const stillExists = internalQuery({
  args: { messageId: v.id("messages") },
  handler: async (ctx, { messageId }) => (await ctx.db.get(messageId)) !== null,
});

export const deleteMessage = mutation({
  args: {
    messageId: v.id("messages"),
    userId: v.id("users"),
  },
  handler: async (ctx, { messageId, userId }) => {
    const msg = await ctx.db.get(messageId);
    if (!msg) throw new Error("MESSAGE_NOT_FOUND");

    // Only sender or room owner can delete
    if (msg.userId.toString() !== userId.toString()) {
      const membership = await ctx.db
        .query("roomMembers")
        .withIndex("by_room_user", (q) => q.eq("roomId", msg.roomId).eq("userId", userId))
        .first();
      if (!membership || membership.role !== "owner") {
        throw new Error("NOT_AUTHORIZED");
      }
    }

    await removeMessageAndFanout(ctx, msg, messageId);
  },
});

export const list = query({
  args: {
    roomId: v.id("rooms"),
    limit: v.optional(v.number()),
    // Optional so already-shipped clients keep working. Without it a
    // view-once message still comes back stripped — the viewer just can't be
    // told whether they personally opened it.
    viewerUserId: v.optional(v.id("users")),
  },
  handler: async (ctx, { roomId, limit, viewerUserId }) => {
    const msgs = await ctx.db
      .query("messages")
      .withIndex("by_room_time", (q) => q.eq("roomId", roomId))
      .order("desc")
      .take(limit ?? 100);

    // Do NOT read `users` here. Convex reactivity tracks every doc read, so
    // including `ctx.db.get(msg.userId)` made this subscription re-fire on
    // every user.status flip (online/away/offline) for any author in the
    // list — which then triggered markRoomRead, which patched roomMembers,
    // which refired four other subscriptions. The denormalized
    // `msg.senderName` is set at write time in `messages:send` so the
    // client already has the display name.
    const enriched = await Promise.all(
      msgs.map(async (msg) => {
        const reactions = await ctx.db
          .query("reactions")
          .withIndex("by_message", (q) => q.eq("messageId", msg._id))
          .collect();
        const safe = await sanitizeViewOnce(ctx, msg, viewerUserId);
        return { ...safe, reactions };
      })
    );
    return enriched.reverse();
  },
});

export const listBefore = query({
  args: {
    roomId: v.id("rooms"),
    beforeTimestamp: v.number(),
    limit: v.optional(v.number()),
    viewerUserId: v.optional(v.id("users")),
  },
  handler: async (ctx, { roomId, beforeTimestamp, limit, viewerUserId }) => {
    const msgs = await ctx.db
      .query("messages")
      .withIndex("by_room_time", (q) =>
        q.eq("roomId", roomId).lt("createdAt", beforeTimestamp)
      )
      .order("desc")
      .take(limit ?? 30);

    // Mirrors the no-user-doc-read pattern from `list` above — see comment
    // there for why we never enrich with users in a reactive query.
    const enriched = await Promise.all(
      msgs.map(async (msg) => {
        const reactions = await ctx.db
          .query("reactions")
          .withIndex("by_message", (q) => q.eq("messageId", msg._id))
          .collect();
        const safe = await sanitizeViewOnce(ctx, msg, viewerUserId);
        return { ...safe, reactions };
      })
    );
    return enriched.reverse(); // chronological order
  },
});

// Ascending counterpart to `listBefore`. Only used to walk *back down* toward
// the present after a jump into old history — the newest end of the room is
// owned by the live `list` subscription, so nothing subscribes to this.
export const listAfter = query({
  args: {
    roomId: v.id("rooms"),
    afterTimestamp: v.number(),
    limit: v.optional(v.number()),
    viewerUserId: v.optional(v.id("users")),
  },
  handler: async (ctx, { roomId, afterTimestamp, limit, viewerUserId }) => {
    const msgs = await ctx.db
      .query("messages")
      .withIndex("by_room_time", (q) =>
        q.eq("roomId", roomId).gt("createdAt", afterTimestamp)
      )
      .order("asc")
      .take(limit ?? 30);

    // Mirrors the no-user-doc-read pattern from `list` above.
    return await Promise.all(
      msgs.map(async (msg) => {
        const reactions = await ctx.db
          .query("reactions")
          .withIndex("by_message", (q) => q.eq("messageId", msg._id))
          .collect();
        const safe = await sanitizeViewOnce(ctx, msg, viewerUserId);
        return { ...safe, reactions };
      })
    );
  },
});

// A window of history centred on one message, so tapping a reply tether can
// land on a parent that was posted long before anything the client holds —
// without paging the whole gap 40 messages at a time.
//
// Returns the anchor plus `before` older and `after` newer messages,
// chronological, with a flag per side saying whether history continues there.
// `found: false` means the message is gone (deleted) or not in this room.
//
// Messages sharing the anchor's exact `createdAt` fall outside both range
// scans; at millisecond precision that's vanishingly rare, and the client
// dedupes by id anyway.
export const listAround = query({
  args: {
    roomId: v.id("rooms"),
    messageId: v.id("messages"),
    before: v.optional(v.number()),
    after: v.optional(v.number()),
    viewerUserId: v.optional(v.id("users")),
  },
  handler: async (ctx, { roomId, messageId, before, after, viewerUserId }) => {
    const anchor = await ctx.db.get(messageId);
    if (!anchor || anchor.roomId.toString() !== roomId.toString()) {
      return {
        messages: [],
        hasMoreOlder: true,
        hasMoreNewer: true,
        found: false,
      };
    }

    const backCap = Math.min(before ?? 25, 100);
    const fwdCap = Math.min(after ?? 25, 100);

    const older = await ctx.db
      .query("messages")
      .withIndex("by_room_time", (q) =>
        q.eq("roomId", roomId).lt("createdAt", anchor.createdAt)
      )
      .order("desc")
      .take(backCap);
    const newer = await ctx.db
      .query("messages")
      .withIndex("by_room_time", (q) =>
        q.eq("roomId", roomId).gt("createdAt", anchor.createdAt)
      )
      .order("asc")
      .take(fwdCap);

    const collected = [...older.reverse(), anchor, ...newer];

    // Reactions only. Do NOT read `users` here — same reason as `list`.
    const enriched = await Promise.all(
      collected.map(async (msg) => {
        const reactions = await ctx.db
          .query("reactions")
          .withIndex("by_message", (q) => q.eq("messageId", msg._id))
          .collect();
        const safe = await sanitizeViewOnce(ctx, msg, viewerUserId);
        return { ...safe, reactions };
      })
    );

    return {
      messages: enriched,
      hasMoreOlder: older.length === backCap,
      hasMoreNewer: newer.length === fwdCap,
      found: true,
    };
  },
});

// MARK: - Chamber of Secrets: scheduled self-destruction

export const expireMessage = internalMutation({
  args: { messageId: v.id("messages") },
  handler: async (ctx, { messageId }) => {
    const msg = await ctx.db.get(messageId);
    if (!msg) return; // Already deleted (e.g. manually deleted before expiry)

    await removeMessageAndFanout(ctx, msg, messageId);
  },
});

// Paged thread read. Supersedes `getThread` below, which is kept only for
// already-shipped clients.
//
// A thread is `{root} ∪ {m : m.rootId === rootId}` — see the `rootId` comment
// in schema.ts for why the tree is flattened this way. Because `by_root_time`
// is time-ordered, a page is a plain range scan and page N+1 is always a
// prefix-extension of page N: newly-loaded messages can only ever appear
// above what's already on screen, never in the middle of it.
//
// Walks *older*, mirroring `listBefore`: pass the oldest `createdAt` you hold
// as `beforeTimestamp`. The newest end is owned by the room's live
// subscription on the client, so there is deliberately no "load newer".
//
// The root itself carries no `rootId`, so it isn't in the index scan — it's
// unshifted once the scan runs dry (a reply's createdAt always postdates its
// parent's, so the root is unconditionally the head of the thread).
export const getThreadPage = query({
  args: {
    roomId: v.id("rooms"),
    rootId: v.id("messages"),
    viewerUserId: v.id("users"),
    beforeTimestamp: v.optional(v.number()),
    limit: v.optional(v.number()),
  },
  handler: async (ctx, { roomId, rootId, viewerUserId, beforeTimestamp, limit }) => {
    // `getThread` has no authorization at all — any messageId reads a thread.
    // Checking here is safe precisely because this query is only ever fetched
    // one-shot, never subscribed: reading `roomMembers` from a live query
    // would make it refire on every `markRoomRead` patch (see the comment on
    // `list` about why reactive queries must stay off shared docs).
    const membership = await ctx.db
      .query("roomMembers")
      .withIndex("by_room_user", (q) =>
        q.eq("roomId", roomId).eq("userId", viewerUserId)
      )
      .first();
    if (!membership) throw new Error("NOT_A_MEMBER");

    const cap = Math.min(limit ?? 25, 100);

    let q = ctx.db
      .query("messages")
      .withIndex("by_root_time", (ix) =>
        beforeTimestamp === undefined
          ? ix.eq("rootId", rootId)
          : ix.eq("rootId", rootId).lt("createdAt", beforeTimestamp)
      );

    const descendants = await q.order("desc").take(cap);
    const hasMore = descendants.length === cap;
    const collected = descendants.reverse(); // chronological

    // Scan ran dry — prepend the root, unless the caller already has it.
    if (!hasMore) {
      const root = await ctx.db.get(rootId);
      if (
        root &&
        root.roomId.toString() === roomId.toString() &&
        (beforeTimestamp === undefined || root.createdAt < beforeTimestamp)
      ) {
        collected.unshift(root);
      }
    }

    // Reactions only. Do NOT read `users` here — same reason as `list`.
    const enriched = await Promise.all(
      collected.map(async (msg) => {
        const reactions = await ctx.db
          .query("reactions")
          .withIndex("by_message", (ix) => ix.eq("messageId", msg._id))
          .collect();
        const safe = await sanitizeViewOnce(ctx, msg, viewerUserId);
        return { ...safe, reactions };
      })
    );

    return { messages: enriched, hasMore };
  },
});

// DEPRECATED — superseded by `getThreadPage`. Retained so app versions
// already in the wild keep working; delete once they've aged out.
//
// Returns the entire conversational thread containing [messageId]: walks up
// to the root via replyToId, then BFS down through the by_replyTo index to
// collect every descendant. Result is sorted chronologically (oldest first)
// and enriched the same way `list` enriches its rows. Capped at 50 messages
// to keep the round-trip bounded; branching threads still work but only the
// first 50 BFS-collected rows come back.
export const getThread = query({
  args: {
    messageId: v.id("messages"),
    maxTotal: v.optional(v.number()),
  },
  handler: async (ctx, { messageId, maxTotal }) => {
    const cap = Math.min(maxTotal ?? 50, 100);

    // 1. Walk up to the root. Bounded by 20 hops + cycle-guard set.
    let rootId: any = messageId;
    const seenUp = new Set<string>();
    for (let i = 0; i < 20; i++) {
      const key = rootId.toString();
      if (seenUp.has(key)) break;
      seenUp.add(key);
      const m = await ctx.db.get(rootId);
      if (!m || !m.replyToId) break;
      rootId = m.replyToId;
    }

    // 2. BFS down from the root through the by_replyTo index.
    const collected: any[] = [];
    const seenDown = new Set<string>();
    const queue: any[] = [rootId];
    while (queue.length > 0 && collected.length < cap) {
      const id = queue.shift();
      const key = id.toString();
      if (seenDown.has(key)) continue;
      seenDown.add(key);
      const m = await ctx.db.get(id);
      if (!m) continue;
      collected.push(m);
      const kids = await ctx.db
        .query("messages")
        .withIndex("by_replyTo", (q) => q.eq("replyToId", id))
        .collect();
      for (const k of kids) queue.push(k._id);
    }

    // 3. Enrich + sort chronologically.
    //
    // Sanitized with no viewer: this function takes no user id and does no
    // authorization at all, so it must never be the one path that hands out a
    // view-once storage id. Clients old enough to still call this simply can't
    // open view-once photos, which is the correct failure direction.
    const enriched = await Promise.all(
      collected.map(async (m) => {
        const user = await ctx.db.get(m.userId);
        const reactions = await ctx.db
          .query("reactions")
          .withIndex("by_message", (q) => q.eq("messageId", m._id))
          .collect();
        const safe = await sanitizeViewOnce(ctx, m, undefined);
        return {
          ...safe,
          username: user?.username ?? "unknown",
          name: user?.name ?? user?.username ?? "unknown",
          reactions,
        };
      })
    );
    enriched.sort((a, b) => a.createdAt - b.createdAt);
    return enriched;
  },
});

// ─────────────────────────────── View-once photos ────────────────────────────

/** Drops every ledger row for one message. Shared by all three delete paths. */
export async function purgeViewOnceViews(ctx: any, messageId: any) {
  const rows = await ctx.db
    .query("viewOnceViews")
    .withIndex("by_message", (q: any) => q.eq("messageId", messageId))
    .collect();
  for (const r of rows) await ctx.db.delete(r._id);
}

/**
 * A 32-hex-character ticket. `crypto.getRandomValues` is available in Convex's
 * runtime; `Math.random` would not be acceptable here, since guessing a nonce
 * is guessing a photo.
 */
function mintNonce(): string {
  const bytes = new Uint8Array(16);
  crypto.getRandomValues(bytes);
  return Array.from(bytes, (b) => b.toString(16).padStart(2, "0")).join("");
}

/**
 * Hands out a download ticket for a view-once photo, spending the caller's one
 * view in the same breath.
 *
 * The view is recorded at GRANT time rather than when the picture is dismissed.
 * That ordering is the whole security property: a client that crashes, force
 * quits, or simply lies about having closed the image has still spent its view,
 * because it could not have obtained the ticket otherwise.
 *
 * Returns one of:
 *   { nonce, expiresInMs } — go fetch it
 *   { alreadyViewed: true } — spent, and past the retry window
 *   { gone: true }          — burned, expired, deleted, or never armed
 */
export const openViewOnce = mutation({
  args: { messageId: v.id("messages"), userId: v.id("users") },
  handler: async (ctx, { messageId, userId }) => {
    const msg = await ctx.db.get(messageId);
    if (!msg) return { gone: true };

    // Membership, and the child guard on top of it. `send` re-checks the child
    // policy on every call because a guardian can revoke a grant while the
    // child is still sitting in the room; opening media has to be re-checked
    // for exactly the same reason, or revocation would only take effect for
    // photos that haven't been sent yet.
    const membership = await ctx.db
      .query("roomMembers")
      .withIndex("by_room_user", (q) =>
        q.eq("roomId", msg.roomId).eq("userId", userId)
      )
      .first();
    if (!membership) throw new Error("NOT_A_MEMBER");

    const policy = await childPolicyOf(ctx, userId);
    if (policy !== null) {
      if (!(await childMayUseRoom(ctx, userId, msg.roomId))) {
        throw new Error(ERR_APPROVAL_REQUIRED);
      }
      if (!policy.mediaEnabled) throw new Error(ERR_NOT_ALLOWED);
    }

    if (msg.viewOnce !== true || !msg.mediaStorageId) return { gone: true };

    // The sender gets no reopen path, and this is a security decision rather
    // than a UX one. There is no authentication here — `userId` is a plain
    // argument — and a message's sender id is visible to everyone who receives
    // it. A "the sender may always look again" branch is therefore an oracle
    // any recipient can drive: pass the sender's id, get unlimited views.
    if (msg.userId.toString() === userId.toString()) return { gone: true };

    const now = Date.now();
    const existing = await ctx.db
      .query("viewOnceViews")
      .withIndex("by_message_user", (q) =>
        q.eq("messageId", messageId).eq("userId", userId)
      )
      .first();

    if (existing) {
      // Same ticket, not a fresh one. Re-minting would be indistinguishable
      // from granting a second view; handing back the still-live ticket is
      // just letting the first download finish over a bad connection.
      if (
        existing.grantNonce &&
        existing.grantExpiresAt &&
        now < existing.grantExpiresAt
      ) {
        return {
          nonce: existing.grantNonce,
          expiresInMs: existing.grantExpiresAt - now,
        };
      }
      return { alreadyViewed: true };
    }

    // Somebody who joined after the photo was sent may still open it, but must
    // not be able to satisfy the burn condition on the real recipients' behalf.
    const countsToward = membership.joinedAt <= msg.createdAt;

    const nonce = mintNonce();
    await ctx.db.insert("viewOnceViews", {
      messageId,
      roomId: msg.roomId,
      userId,
      viewedAt: now,
      countsToward,
      grantNonce: nonce,
      grantExpiresAt: now + VIEW_ONCE_NONCE_TTL_MS,
    });

    if (countsToward) {
      const seen = (msg.viewOnceViewCount ?? 0) + 1;
      await ctx.db.patch(messageId, { viewOnceViewCount: seen });
      if (seen >= (msg.viewOnceRecipients ?? 0)) {
        // Everyone has had their look. Wait out the grace period before
        // deleting, or we would pull the file out from under the download this
        // very grant just authorized.
        await ctx.scheduler.runAfter(
          VIEW_ONCE_BURN_GRACE_MS,
          internal.messages.burnViewOnce,
          { messageId }
        );
      }
    }

    return { nonce, expiresInMs: VIEW_ONCE_NONCE_TTL_MS };
  },
});

/**
 * Validates a download ticket and reports which blob to stream. Internal, and
 * called only by the `/viewOnce` HTTP action — the storage id it returns must
 * never reach a client.
 */
export const resolveViewOnceGrant = internalQuery({
  args: {
    messageId: v.id("messages"),
    userId: v.id("users"),
    nonce: v.string(),
  },
  handler: async (ctx, { messageId, userId, nonce }) => {
    const row = await ctx.db
      .query("viewOnceViews")
      .withIndex("by_message_user", (q) =>
        q.eq("messageId", messageId).eq("userId", userId)
      )
      .first();
    if (!row || row.grantNonce !== nonce) return null;
    if (!row.grantExpiresAt || Date.now() >= row.grantExpiresAt) return null;

    const msg = await ctx.db.get(messageId);
    if (!msg || msg.viewOnce !== true || !msg.mediaStorageId) return null;
    return { storageId: msg.mediaStorageId };
  },
});

/**
 * Deletes the blob and leaves the message behind as a ghost.
 *
 * Idempotent, and deliberately so: it is reachable from the per-message
 * deadline schedule, from the "everyone has seen it" schedule, and from the
 * repair sweep, and any two of those can land on the same message.
 */
export const burnViewOnce = internalMutation({
  args: { messageId: v.id("messages") },
  handler: async (ctx, { messageId }) => {
    const msg = await ctx.db.get(messageId);
    if (!msg || msg.viewOnce !== true || !msg.mediaStorageId) return;

    await deleteStored(ctx, msg.mediaStorageId);
    // The ROW SURVIVES. Clearing these fields is what flips every client to the
    // greyed ghost bubble, reactively, without deleting anyone's transcript.
    await ctx.db.patch(messageId, {
      mediaStorageId: undefined,
      mediaWidth: undefined,
      mediaHeight: undefined,
      viewOnceBurnedAt: Date.now(),
      viewOnceDeadline: undefined,
      // Drops the row out of the sweep's index bucket entirely — see the
      // `viewOnceLive` comment in schema.ts.
      viewOnceLive: undefined,
    });
    // Tickets outlive their usefulness the moment the file is gone.
    const rows = await ctx.db
      .query("viewOnceViews")
      .withIndex("by_message", (q) => q.eq("messageId", messageId))
      .collect();
    for (const r of rows) {
      if (r.grantNonce !== undefined) {
        await ctx.db.patch(r._id, {
          grantNonce: undefined,
          grantExpiresAt: undefined,
        });
      }
    }
  },
});

/**
 * Repair sweep for armed photos past their deadline. The per-message
 * `runAfter` scheduled in `send` is the primary mechanism — this only catches
 * what the scheduler dropped (a restart mid-flight, a backfilled row), which is
 * why six hours is frequent enough.
 *
 * The index leads with `viewOnce` on purpose: Convex has no sparse indexes and
 * sorts `undefined` ahead of every number, so ranging on the deadline alone
 * would walk every message in the deployment.
 */
export const gcExpiredViewOnce = internalMutation({
  args: {},
  handler: async (ctx) => {
    const SWEEP_LIMIT = 200;
    const due = await ctx.db
      .query("messages")
      .withIndex("by_viewOnce_live_deadline", (q) =>
        q.eq("viewOnceLive", true).lt("viewOnceDeadline", Date.now())
      )
      .take(SWEEP_LIMIT);

    let burned = 0;
    for (const msg of due) {
      await deleteStored(ctx, msg.mediaStorageId);
      await ctx.db.patch(msg._id, {
        mediaStorageId: undefined,
        mediaWidth: undefined,
        mediaHeight: undefined,
        viewOnceBurnedAt: Date.now(),
        viewOnceDeadline: undefined,
        viewOnceLive: undefined,
      });
      burned++;
    }
    return { scanned: due.length, burned };
  },
});

/**
 * Recomputes the recipient snapshot for a room's live view-once photos.
 *
 * Called when membership changes. Without it, someone leaving a room without
 * opening a photo pins that blob until its 14-day deadline, even though every
 * remaining recipient has already seen it. Bounded by design: only armed,
 * unburned messages in one room.
 */
export const recountViewOnceRecipients = internalMutation({
  args: { roomId: v.id("rooms") },
  handler: async (ctx, { roomId }) => {
    const roster = await ctx.db
      .query("roomMembers")
      .withIndex("by_room", (q) => q.eq("roomId", roomId))
      .collect();
    const memberIds = new Set(roster.map((m) => m.userId.toString()));

    const recent = await ctx.db
      .query("messages")
      .withIndex("by_room_time", (q) => q.eq("roomId", roomId))
      .order("desc")
      .take(200);

    for (const msg of recent) {
      if (msg.viewOnce !== true || !msg.mediaStorageId) continue;
      const recipients = roster.filter(
        (m) => m.userId.toString() !== msg.userId.toString()
      ).length;
      // Only count views from people who are still here — a departed member's
      // row would otherwise keep inflating the tally.
      const rows = await ctx.db
        .query("viewOnceViews")
        .withIndex("by_message", (q) => q.eq("messageId", msg._id))
        .collect();
      const seen = rows.filter(
        (r) => r.countsToward && memberIds.has(r.userId.toString())
      ).length;

      if (
        recipients !== msg.viewOnceRecipients ||
        seen !== msg.viewOnceViewCount
      ) {
        await ctx.db.patch(msg._id, {
          viewOnceRecipients: recipients,
          viewOnceViewCount: seen,
        });
      }
      if (seen >= recipients) {
        await ctx.scheduler.runAfter(
          VIEW_ONCE_BURN_GRACE_MS,
          internal.messages.burnViewOnce,
          { messageId: msg._id }
        );
      }
    }
  },
});

// ─────────────────────────────── Read receipts ───────────────────────────────

/**
 * Mark a room as "read up to now" for the given user. Persisted on the
 * roomMembers row so the relationship is O(rooms × members) rather than
 * O(messages × members).
 *
 * Idempotent — calling repeatedly only updates the timestamp.
 */
export const markRoomRead = mutation({
  args: { roomId: v.id("rooms"), userId: v.id("users") },
  handler: async (ctx, { roomId, userId }) => {
    const membership = await ctx.db
      .query("roomMembers")
      .withIndex("by_room_user", (q) =>
        q.eq("roomId", roomId).eq("userId", userId)
      )
      .first();
    if (!membership) return; // not a member, silently no-op
    await ctx.db.patch(membership._id, { lastReadAt: Date.now() });

    // Reading the room retires its outstanding notifications. The device that
    // did the reading also clears them locally (it doesn't need a round trip);
    // this covers the user's *other* devices and corrects the badge everywhere.
    const rows = await ctx.db
      .query("pushReceipts")
      .withIndex("by_user_room", (q) =>
        q.eq("userId", userId).eq("roomId", roomId)
      )
      .collect();
    for (const r of rows) await ctx.db.delete(r._id);

    if (rows.length > 0) {
      await ctx.scheduler.runAfter(0, internal.notifications.cancelByIds, {
        onesignalIds: rows.map((r) => r.onesignalId),
      });
    }
    await ctx.scheduler.runAfter(0, internal.notifications.dismissAndSync, {
      userIds: [userId],
      dismissIds: rows.map((r) => r.messageId.toString()),
      roomId,
    });
  },
});

/**
 * Returns each member's lastReadAt timestamp for a room, filtered by each
 * reader's `seen` visibility relative to the requesting viewer:
 *
 *   reader.visibility.seen = "public"  → row visible to anyone
 *   reader.visibility.seen = "friends" → row visible only to the reader's friends
 *   reader.visibility.seen = "nobody"  → row hidden (default for missing/unset)
 *
 * The viewer's own row is always returned. Rows whose reader has hidden their
 * `seen` are simply omitted (rather than returned as 0) so the client can
 * compute "latest other read" without a separate filter.
 *
 * The client uses this stream to render the "SEEN" indicator on its own
 * messages. A reader who hasn't opted in to send-read-receipts contributes
 * nothing here — so message senders see no SEEN unless the reader explicitly
 * shares.
 */
export const getReadState = query({
  args: {
    roomId: v.id("rooms"),
    viewerUserId: v.id("users"),
  },
  handler: async (ctx, { roomId, viewerUserId }) => {
    const members = await ctx.db
      .query("roomMembers")
      .withIndex("by_room", (q) => q.eq("roomId", roomId))
      .collect();

    const viewerKey = viewerUserId.toString();
    const out: Array<{ userId: any; lastReadAt: number }> = [];
    for (const m of members) {
      const isSelf = m.userId.toString() === viewerKey;
      if (isSelf) {
        out.push({ userId: m.userId, lastReadAt: m.lastReadAt ?? 0 });
        continue;
      }
      const reader = await ctx.db.get(m.userId);
      const level = reader?.visibility?.seen;
      // Privacy-first default: missing/unknown ⇒ "nobody".
      const allowed =
        level === "public" ||
        (level === "friends" &&
          (await _areFriends(ctx, m.userId, viewerUserId)));
      if (!allowed) continue;
      out.push({ userId: m.userId, lastReadAt: m.lastReadAt ?? 0 });
    }
    return out;
  },
});

async function _areFriends(
  ctx: any,
  a: any,
  b: any,
): Promise<boolean> {
  const fwd = await ctx.db
    .query("friendships")
    .withIndex("by_pair", (q: any) => q.eq("userId", a).eq("friendId", b))
    .first();
  if (fwd?.status === "accepted") return true;
  const rev = await ctx.db
    .query("friendships")
    .withIndex("by_pair", (q: any) => q.eq("userId", b).eq("friendId", a))
    .first();
  return rev?.status === "accepted";
}
