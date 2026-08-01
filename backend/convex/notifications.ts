import { internalAction, internalMutation } from "./_generated/server";
import { internal } from "./_generated/api";
import { v } from "convex/values";

// Required Convex environment variables (set in Convex dashboard → Settings → Environment Variables):
//   ONESIGNAL_API_KEY  — REST API key from OneSignal dashboard → Settings → Keys & IDs
//
// The App ID is hardcoded (same as PushNotificationManager.swift — not a secret).

const ONESIGNAL_APP_ID = "c191a9f0-15cf-402a-8a04-dcc16108f4b0";
const ONESIGNAL_BASE = "https://api.onesignal.com";

/**
 * POST one notification and return the OneSignal notification id, or null if
 * the request failed.
 *
 * That id is the whole basis for revocation — it's what `DELETE
 * /notifications/{id}` takes. It used to be logged and thrown away.
 *
 * Every caller sends ONE request per recipient rather than a single
 * `include_aliases` fan-out. Two reasons, both hard requirements:
 *   1. `ios_badgeType: "SetTo"` needs each recipient's own unread total.
 *   2. A shared notification id can't be cancelled for one reader without
 *      cancelling it for everyone else in the room.
 * Rooms here hold a handful of people and OneSignal allows 150 req/s, so the
 * cost is a non-issue when the calls are issued concurrently.
 */
async function oneSignalPost(
  apiKey: string,
  payload: Record<string, any>,
  tag: string,
): Promise<string | null> {
  const response = await fetch(`${ONESIGNAL_BASE}/notifications`, {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      Authorization: `Key ${apiKey}`,
    },
    body: JSON.stringify(payload),
  });

  const responseText = await response.text();
  if (!response.ok) {
    console.error(`${tag}: OneSignal API error (HTTP ${response.status}): ${responseText}`);
    return null;
  }
  try {
    return (JSON.parse(responseText)?.id as string) ?? null;
  } catch {
    console.error(`${tag}: could not parse OneSignal response: ${responseText}`);
    return null;
  }
}

/**
 * Push for anything sitting in a guardian's approval queue, and for a request
 * that has just been released to its recipient. Takes explicit userIds rather
 * than deriving them, because the caller already knows exactly who the next
 * hop is — and getting that wrong would leak a request to someone who isn't
 * supposed to know it exists yet.
 */
export const sendApprovalPush = internalAction({
  args: {
    userIds: v.array(v.string()),
    title: v.string(),
    body: v.string(),
  },
  handler: async (ctx, { userIds, title, body }) => {
    const apiKey = process.env.ONESIGNAL_API_KEY;
    if (!apiKey) {
      console.error(
        "sendApprovalPush: ONESIGNAL_API_KEY env var is not set — push skipped."
      );
      return;
    }
    if (userIds.length === 0) return;

    console.log(
      `sendApprovalPush: targeting ${userIds.length} user(s) by external_id: ${userIds.join(", ")}`
    );

    // Per-recipient for the same reason as sendMessagePush: the absolute
    // badge value differs per user.
    const badges: Record<string, number> = await ctx.runQuery(
      internal.badges.badgeSnapshot,
      { userIds: userIds as any }
    );

    await Promise.allSettled(
      userIds.map((uid) =>
        oneSignalPost(
          apiKey,
          {
            app_id: ONESIGNAL_APP_ID,
            target_channel: "push",
            include_aliases: { external_id: [uid] },
            headings: { en: title },
            contents: { en: body },
            data: { kind: "approval" },
            ios_badgeType: "SetTo",
            ios_badgeCount: badges[uid] ?? 1,
          },
          "sendApprovalPush"
        )
      )
    );
  },
});

export const sendMessagePush = internalAction({
  args: {
    roomId: v.id("rooms"),
    messageId: v.id("messages"),
    senderId: v.id("users"),
    senderName: v.string(),
    content: v.string(),
    type: v.string(),
    // Already validated by `messages:send` — these name people who really are
    // members and really were written into the text.
    mentionedUserIds: v.optional(v.array(v.id("users"))),
    mentionsEveryone: v.optional(v.boolean()),
  },
  handler: async (ctx, { roomId, messageId, senderId, senderName, content, type, mentionedUserIds, mentionsEveryone }) => {
    const apiKey = process.env.ONESIGNAL_API_KEY;

    if (!apiKey) {
      console.error(
        "sendMessagePush: ONESIGNAL_API_KEY env var is not set — push skipped."
      );
      return;
    }

    // Cheapest possible guard against the "typed it, sent it, deleted it"
    // race: `send` schedules us with runAfter(0), but under load this action
    // can start after the message is already gone. One read saves a push that
    // would immediately need revoking.
    const stillThere = await ctx.runQuery(internal.messages.stillExists, { messageId });
    if (!stillThere) {
      console.log("sendMessagePush: message deleted before send — skipped.");
      return;
    }

    // Fetch all room members except the sender
    const members: Array<{ userId: string }> = await ctx.runQuery(
      internal.rooms.getMemberIds,
      { roomId, excludeUserId: senderId }
    );

    if (members.length === 0) return;

    const externalIds = members.map((m) => m.userId.toString());

    // Absolute badge value per recipient. `SetTo` is computed here rather than
    // `Increase`d on-device: `Increase` is applied by the iOS Notification
    // Service Extension out of App-Group state, and this app ships neither, so
    // an incrementing badge silently never worked.
    const badges: Record<string, number> = await ctx.runQuery(
      internal.badges.badgeSnapshot,
      { userIds: members.map((m) => m.userId) }
    );

    const body =
      type === "text"
        ? content
        : type === "image"
        ? "📷 Image"
        : type === "video"
        ? "🎥 Video"
        : type === "audio"
        ? "🎵 Audio"
        : "New message";

    console.log(
      `sendMessagePush: targeting ${externalIds.length} user(s) by external_id`
    );

    // Who, of this room, was named. `@everyone` makes that everybody, which is
    // the whole point of it — every recipient below is already the roster minus
    // the sender.
    const mentioned = new Set((mentionedUserIds ?? []).map(String));
    const mentionsAll = mentionsEveryone === true;

    const sentAt = Date.now();

    // Use the OneSignal v5 User Model API: target users by external_id via
    // include_aliases + target_channel. This lets OneSignal resolve the correct
    // subscription server-side — no client-side subscription ID fetch needed.
    // This is the only approach that is race-condition free when a device switches
    // between APNs environments (Xcode dev ↔ TestFlight prod).
    const results = await Promise.allSettled(
      members.map(async (m) => {
        const uid = m.userId.toString();
        // A mention is the one message in a busy room that is genuinely
        // addressed to you, so it says so on the lock screen. Costs nothing
        // extra: this loop already builds a payload per recipient in order to
        // stamp a per-user badge count.
        const isMention = mentionsAll || mentioned.has(uid);
        const payload = {
          app_id: ONESIGNAL_APP_ID,
          target_channel: "push",
          include_aliases: { external_id: [uid] },
          headings: { en: isMention ? `${senderName} mentioned you` : senderName },
          contents: { en: body },
          data: {
            roomId: roomId.toString(),
            messageId: messageId.toString(),
            senderId: senderId.toString(),
            senderName,
            content: body,
            type,
            // Read by nothing today — tap routing goes through `roomId`, which
            // a mention carries like any other message. Carried so a future
            // in-app treatment doesn't need a server change to find out.
            mention: isMention,
          },
          // The delivered notification's identifier. Deleting the message
          // later sends a silent push carrying this same string, which the
          // client hands to removeDeliveredNotifications — the only way to
          // pull an already-shown notification off a device.
          collapse_id: messageId.toString(),
          // Groups a room's notifications together, and gives the client a
          // handle for "dismiss everything from this room" on read.
          thread_id: roomId.toString(),
          android_group: roomId.toString(),
          web_push_topic: roomId.toString(),
          ios_badgeType: "SetTo",
          ios_badgeCount: badges[uid] ?? 1,
          ios_category: "CHAT_MESSAGE",
          // A day-old chat notification is noise, and this also bounds how
          // long a pushReceipts row can still matter. Default is 3 days.
          ttl: 86400,
        };
        const onesignalId = await oneSignalPost(apiKey, payload, "sendMessagePush");
        return onesignalId
          ? { userId: m.userId, roomId, onesignalId }
          : null;
      })
    );

    // A recipient whose POST failed simply gets no receipt row: we lose the
    // ability to cancel that one push, which is the correct degradation.
    const receipts = results
      .filter((r) => r.status === "fulfilled" && r.value)
      .map((r) => (r as PromiseFulfilledResult<any>).value);

    if (receipts.length > 0) {
      await ctx.runMutation(internal.notifications.recordPushReceipts, {
        messageId,
        sentAt,
        receipts,
      });
    }
  },
});

// ─────────────────────── Revocation & badge correction ───────────────────────

/**
 * Persist the ids OneSignal handed back, and arbitrate the two races the
 * sending action can't see because it isn't transactional:
 *
 *   - the message was deleted while the HTTP request was in flight
 *   - the recipient read the room while the HTTP request was in flight
 *
 * In either case we don't store a row; we cancel immediately instead. The
 * mirror-image half lives in `messages.markRoomRead`, which revokes rows that
 * already exist — so whichever transaction commits second sees the other's
 * effect and does the right thing.
 */
export const recordPushReceipts = internalMutation({
  args: {
    messageId: v.id("messages"),
    sentAt: v.number(),
    receipts: v.array(
      v.object({
        userId: v.id("users"),
        roomId: v.id("rooms"),
        onesignalId: v.string(),
      })
    ),
  },
  handler: async (ctx, { messageId, sentAt, receipts }) => {
    const stillThere = await ctx.db.get(messageId);
    const doomed: string[] = [];

    for (const r of receipts) {
      if (!stillThere) {
        doomed.push(r.onesignalId);
        continue;
      }
      const membership = await ctx.db
        .query("roomMembers")
        .withIndex("by_room_user", (q) =>
          q.eq("roomId", r.roomId).eq("userId", r.userId)
        )
        .first();
      if ((membership?.lastReadAt ?? 0) >= sentAt) {
        // They read the room after we started sending — the notification is
        // already stale on arrival.
        doomed.push(r.onesignalId);
        continue;
      }
      await ctx.db.insert("pushReceipts", {
        userId: r.userId,
        roomId: r.roomId,
        messageId,
        onesignalId: r.onesignalId,
        sentAt,
      });
    }

    if (doomed.length > 0) {
      await ctx.scheduler.runAfter(0, internal.notifications.cancelByIds, {
        onesignalIds: doomed,
      });
    }
  },
});

/**
 * Ask OneSignal to cancel notifications that haven't gone out yet.
 *
 * A 404 (or "not found") means it already shipped or was already cancelled —
 * both are success from our point of view, so they're swallowed rather than
 * logged as errors.
 */
export const cancelByIds = internalAction({
  args: { onesignalIds: v.array(v.string()) },
  handler: async (_ctx, { onesignalIds }) => {
    const apiKey = process.env.ONESIGNAL_API_KEY;
    if (!apiKey || onesignalIds.length === 0) return;
    await Promise.allSettled(
      onesignalIds.map(async (id) => {
        const res = await fetch(
          `${ONESIGNAL_BASE}/notifications/${id}?app_id=${ONESIGNAL_APP_ID}`,
          { method: "DELETE", headers: { Authorization: `Key ${apiKey}` } }
        );
        if (!res.ok && res.status !== 404) {
          console.error(`cancelByIds: HTTP ${res.status} for ${id}: ${await res.text()}`);
        }
      })
    );
  },
});

/**
 * Take back the pushes for one removed message.
 *
 * Two mechanisms, because neither is sufficient alone:
 *   1. DELETE /notifications/{id} — kills it if it's still queued (recipient
 *      offline, throttled, or simply fast enough).
 *   2. A silent dismiss push — the only thing that can remove a notification
 *      that already landed. Caveat: on iOS a force-quit app never receives
 *      it, so a notification can outlive its message until next launch. No
 *      API on any platform fixes that.
 */
export const revokeMessagePushes = internalAction({
  args: { messageId: v.id("messages"), roomId: v.id("rooms") },
  handler: async (ctx, { messageId, roomId }) => {
    const rows: Array<{ userId: any; onesignalId: string }> =
      await ctx.runMutation(internal.notifications.takeReceiptsForMessage, {
        messageId,
      });
    if (rows.length === 0) return;

    await ctx.runAction(internal.notifications.cancelByIds, {
      onesignalIds: rows.map((r) => r.onesignalId),
    });
    await ctx.runAction(internal.notifications.dismissAndSync, {
      userIds: rows.map((r) => r.userId),
      dismissIds: [messageId.toString()],
      roomId,
    });
  },
});

/** Read-and-delete the receipts for a message, so a retry can't double-cancel. */
export const takeReceiptsForMessage = internalMutation({
  args: { messageId: v.id("messages") },
  handler: async (ctx, { messageId }) => {
    const rows = await ctx.db
      .query("pushReceipts")
      .withIndex("by_message", (q) => q.eq("messageId", messageId))
      .collect();
    for (const r of rows) await ctx.db.delete(r._id);
    return rows.map((r) => ({ userId: r.userId, onesignalId: r.onesignalId }));
  },
});

/** Same, for "this user has now read this room". */
export const takeReceiptsForUserRoom = internalMutation({
  args: { userId: v.id("users"), roomId: v.id("rooms") },
  handler: async (ctx, { userId, roomId }) => {
    const rows = await ctx.db
      .query("pushReceipts")
      .withIndex("by_user_room", (q) =>
        q.eq("userId", userId).eq("roomId", roomId)
      )
      .collect();
    for (const r of rows) await ctx.db.delete(r._id);
    return {
      onesignalIds: rows.map((r) => r.onesignalId),
      messageIds: rows.map((r) => r.messageId.toString()),
    };
  },
});

/**
 * The invisible push: no `contents`, so it never displays. Carries the
 * notification identifiers to remove (the messageIds we sent as collapse_id)
 * and an absolute badge value, so the icon self-corrects even if the client
 * can't act on the dismissal.
 */
export const dismissAndSync = internalAction({
  args: {
    userIds: v.array(v.id("users")),
    dismissIds: v.optional(v.array(v.string())),
    roomId: v.optional(v.id("rooms")),
  },
  handler: async (ctx, { userIds, dismissIds, roomId }) => {
    const apiKey = process.env.ONESIGNAL_API_KEY;
    if (!apiKey || userIds.length === 0) return;

    const badges: Record<string, number> = await ctx.runQuery(
      internal.badges.badgeSnapshot,
      { userIds }
    );

    await Promise.allSettled(
      userIds.map((u) => {
        const uid = u.toString();
        return oneSignalPost(
          apiKey,
          {
            app_id: ONESIGNAL_APP_ID,
            target_channel: "push",
            include_aliases: { external_id: [uid] },
            content_available: true,
            data: {
              kind: "dismiss",
              dismissIds: dismissIds ?? [],
              roomId: roomId ? roomId.toString() : null,
              total: badges[uid] ?? 0,
            },
            ios_badgeType: "SetTo",
            ios_badgeCount: badges[uid] ?? 0,
            priority: 5,
            ttl: 3600,
          },
          "dismissAndSync"
        );
      })
    );
  },
});

/**
 * Sweep receipts past the push TTL (24h) plus slack. Beyond that OneSignal has
 * given up on the notification and the stored id is worthless.
 *
 * The table is bounded by |roomMembers| in the steady state — rows are removed
 * on delete and on read — so this is staleness management, not growth control.
 * Batched so one run can't exceed a mutation's budget.
 */
export const gcPushReceipts = internalMutation({
  args: {},
  handler: async (ctx) => {
    const cutoff = Date.now() - 26 * 60 * 60 * 1000;
    const stale = await ctx.db
      .query("pushReceipts")
      .withIndex("by_sent", (q) => q.lt("sentAt", cutoff))
      .take(500);
    for (const r of stale) await ctx.db.delete(r._id);
  },
});
