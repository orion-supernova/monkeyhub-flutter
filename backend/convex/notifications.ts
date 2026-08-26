import { internalAction } from "./_generated/server";
import { internal } from "./_generated/api";
import { v } from "convex/values";

// What each kind of event says on a lock screen.
//
// This file decides WHO gets told and WHAT it reads; `push.ts` decides how the
// bytes reach the device. The split matters because the "who" is full of
// product rules — a deleted message must not be announced, a supervised
// request must not leak before a guardian releases it, a sender never notifies
// themselves — and none of those belong next to an APNs header.
//
// The four exports here are the entire notification surface of the backend.
// Their names and signatures are load-bearing: messages.ts, friends.ts and
// family.ts schedule them by name from ten call sites.

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
    if (userIds.length === 0) return;
    await ctx.runAction(internal.push.sendAlert, {
      userIds: userIds as any,
      kind: "approval",
      title,
      body,
      data: { kind: "approval" },
    });
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
  handler: async (
    ctx,
    {
      roomId,
      messageId,
      senderId,
      senderName,
      content,
      type,
      mentionedUserIds,
      mentionsEveryone,
    },
  ) => {
    // Cheapest possible guard against the "typed it, sent it, deleted it"
    // race: `send` schedules us with runAfter(0), but under load this action
    // can start after the message is already gone. Folded into the member
    // fetch below as one `runQuery` rather than two sequential ones — `send`
    // schedules this action, under load, for every message, so a second
    // round trip here was a fixed cost on the hottest push path in the app.
    const {
      exists,
      members: allMembers,
      isGroup,
      roomName,
      senderAvatarUrl,
    }: {
      exists: boolean;
      members: Array<{
        userId: string;
        mutesNotifications: boolean;
        mutesBadges: boolean;
        avatarVisible: boolean;
      }>;
      isGroup?: boolean;
      roomName?: string;
      senderAvatarUrl?: string | null;
    } = await ctx.runQuery(internal.rooms.getMemberIds, {
      roomId,
      excludeUserId: senderId,
      messageId,
      resolvePushContext: true,
    });
    if (!exists) {
      console.log("sendMessagePush: message deleted before send — skipped.");
      return;
    }
    if (allMembers.length === 0) return;

    // The room's mute sorts recipients into three buckets, and this is the
    // only place all three exist at once.
    //
    //  * Nothing muted → the ordinary alert, unchanged.
    //  * Notifications muted, counts NOT → no banner, but their app icon still
    //    has to move, and on a locked phone a push is the ONLY thing that can
    //    move it. `dismissAndSync` with an empty id list and no roomId is
    //    exactly that push and nothing else: `buildApnsBody` gives the dismiss
    //    kind `content-available` plus an absolute `aps.badge` and no alert or
    //    sound key, so iOS applies the count and displays nothing. Empty ids
    //    and no room mean it sweeps no existing notification on the way past —
    //    which is why this reuses the existing kind rather than inventing a
    //    "badge only" one that every client platform would have to learn.
    //  * Both muted → nothing at all. `badges.badgeTotalFor` has already
    //    dropped the room, so there is no number to correct either.
    //
    // A mention does NOT break through. That is a deliberate third switch this
    // feature doesn't ship rather than a hidden exception: a mute whose small
    // print is "unless someone types your name" is a mute the user cannot
    // trust, and the room they muted is usually the one where they get named.
    const members = allMembers.filter((m) => !m.mutesNotifications);
    const badgeOnly = allMembers.filter(
      (m) => m.mutesNotifications && !m.mutesBadges,
    );
    if (members.length === 0 && badgeOnly.length === 0) return;

    // The silent badge push is dispatched at the END of this handler, after
    // the real alert has gone out. Sending it first would put an extra round
    // trip in front of every notification in a room where one person has
    // muted, and the people who asked to be interrupted should not wait on the
    // people who asked not to be.
    const syncBadgeOnly = async () => {
      if (badgeOnly.length === 0) return;
      await ctx.runAction(internal.notifications.dismissAndSync, {
        userIds: badgeOnly.map((m) => m.userId) as any,
        dismissIds: [],
      });
    };
    if (members.length === 0) {
      await syncBadgeOnly();
      return;
    }

    const body =
      type === "text"
        ? content
        : type === "image"
          ? "📷 Image"
          : type === "video"
            ? "🎥 Video"
            : type === "audio"
              ? "🎵 Audio"
              : type === "file"
                ? // `content` here is the room preview `send` already computed,
                  // which for a document is its filename (see `roomPreviewFor`).
                  // Naming it beats "📎 File" for the same reason it does on the
                  // room card: one document is not interchangeable with another.
                  `📎 ${content}`
                : type === "location"
                  ? "📍 Location"
                  : type === "liveLocation"
                    ? // Named as live, because whether the sender is still
                      // moving is the entire difference between the two and a
                      // banner is often all the recipient sees for a while.
                      // No coordinates and no duration: a push body is rendered
                      // on a locked screen, and where somebody is should take
                      // one deliberate tap to see, not a glance from across a
                      // table.
                      "📍 Live location"
                    : // The three interactive kinds. `content` here is the room
                      // preview `send` already computed, which for these is
                      // `[poll] <the question>` — see `roomPreviewFor`. Stripping
                      // that machine-readable prefix and putting a glyph in front
                      // of the question is the same move the document case above
                      // makes with a filename, and for the same reason: what the
                      // poll ASKS is the thing worth waking somebody for, and
                      // "New message" is the thing that is not.
                      type === "poll" || type === "checklist" || type === "event"
                      ? `${
                          type === "poll" ? "📊" : type === "checklist" ? "☑️" : "📅"
                        } ${content.replace(/^\[\w+\]\s*/, "")}`.trim()
                      : "New message";

    // Who, of this room, was named. `@everyone` makes that everybody, which is
    // the whole point of it — every recipient below is already the roster minus
    // the sender.
    const mentioned = new Set((mentionedUserIds ?? []).map(String));
    const mentionsAll = mentionsEveryone === true;

    // A mention is the one message in a busy room that is genuinely addressed
    // to you, so it says so on the lock screen. Only the differing fields go
    // in the override map; everyone else shares one payload.
    //
    // The avatar rides the same map for a different reason: `getMemberIds`
    // resolved `avatarVisible` per RECIPIENT (their view of the sender's own
    // avatar-visibility setting — "public"/"friends"/"nobody" — same as the
    // call ringer in calls.ts), so it can't be a single top-level data key.
    // Left OUT of the shared `data` below and only ever added here — failing
    // closed, not open, if a future recipient bucket is added and forgets it.
    const perUser: Record<
      string,
      { title?: string; subtitle?: string; data: Record<string, string> }
    > = {};
    for (const m of members) {
      const uid = m.userId.toString();
      const mentionedHere = mentionsAll || mentioned.has(uid);
      const extra: Record<string, string> = {};
      if (senderAvatarUrl && m.avatarVisible) {
        extra.senderAvatarUrl = senderAvatarUrl;
      }
      if (mentionedHere) {
        perUser[uid] = {
          title: `${senderName} mentioned you`,
          // iOS draws a communication notification's title from the INPerson
          // the extension builds, which overwrites the title above — so on that
          // platform the mention has to live in the one line
          // `updating(from:)` leaves alone. In a group that line was carrying
          // the room name; being named is the more urgent of the two facts and
          // the room is still one tap away.
          subtitle:
            isGroup && roomName
              ? `mentioned you in ${roomName}`
              : "mentioned you",
          data: { mention: "true", ...extra },
        };
      } else if (Object.keys(extra).length > 0) {
        perUser[uid] = { data: extra };
      }
    }

    await ctx.runAction(internal.push.sendAlert, {
      userIds: members.map((m) => m.userId) as any,
      kind: "message",
      title: senderName,
      // The group's name under the sender's name — see `AlertSpec.subtitle`.
      // Absent for a DM: `isGroup` there is false, and a DM's `rooms.name` is
      // the internal `dm:...` key, never something worth showing anyone.
      subtitle: isGroup ? roomName : undefined,
      body,
      data: {
        kind: "message",
        roomId: roomId.toString(),
        messageId: messageId.toString(),
        senderId: senderId.toString(),
        senderName,
        content: body,
        type,
        mention: "false",
        isGroup: isGroup ? "true" : "false",
        // Duplicated off `subtitle` for Android/web, which have no `aps.alert`
        // to read it from — see ChatNotifications.kt / mh-push-sw.js.
        ...(isGroup && roomName ? { roomName } : {}),
      },
      roomId,
      // Deleting this message later sends a silent push carrying the same
      // string, which the client hands to removeDeliveredNotifications — the
      // only way to pull an already-shown notification off a device.
      collapseId: messageId.toString(),
      // Anyone whose read cursor passes this instant while we're sending has
      // already seen the message; they get nothing rather than a notification
      // that was stale before it landed.
      sentAt: Date.now(),
      perUser,
    });

    await syncBadgeOnly();
  },
});

/**
 * Take back the pushes for one removed message.
 *
 * A delivered notification cannot be recalled on any platform, by any API. The
 * silent dismiss push is the only mechanism there has ever been, and it does
 * not reach a force-quit iOS app or a force-stopped Android one — so a banner
 * can outlive its message until next launch. Nothing about talking to APNs
 * directly changes that; it was equally true through OneSignal.
 *
 * Excludes the sender: they never got a push for their own message, so there
 * is nothing on their devices to remove.
 */
export const revokeMessagePushes = internalAction({
  args: {
    messageId: v.id("messages"),
    roomId: v.id("rooms"),
    senderId: v.id("users"),
  },
  handler: async (ctx, { messageId, roomId, senderId }) => {
    const { members }: { members: Array<{ userId: string }> } =
      await ctx.runQuery(internal.rooms.getMemberIds, {
        roomId,
        excludeUserId: senderId,
      });
    if (members.length === 0) return;
    await ctx.runAction(internal.notifications.dismissAndSync, {
      userIds: members.map((m) => m.userId) as any,
      dismissIds: [messageId.toString()],
      roomId,
    });
  },
});

/**
 * The invisible push: no alert body, so it never displays.
 *
 * Carries the notification identifiers to remove (the messageIds we sent as
 * the collapse id) and an absolute badge value, so the icon self-corrects even
 * on a device that can't act on the dismissal itself.
 *
 * [dismissIds] may be empty — for "this user has read the room" the client
 * sweeps by thread/group id instead, and never needed the list.
 */
export const dismissAndSync = internalAction({
  args: {
    userIds: v.array(v.id("users")),
    dismissIds: v.optional(v.array(v.string())),
    roomId: v.optional(v.id("rooms")),
  },
  handler: async (ctx, { userIds, dismissIds, roomId }) => {
    if (userIds.length === 0) return;
    await ctx.runAction(internal.push.sendAlert, {
      userIds,
      kind: "dismiss",
      data: {
        kind: "dismiss",
        // A JSON string, not an array: FCM v1 requires every data value to be
        // a string, and a naive stringify would flatten ["a","b"] to "a,b".
        // iOS and the service worker parse the same encoding, so there is one
        // wire format rather than two.
        dismissIds: JSON.stringify(dismissIds ?? []),
        roomId: roomId ? roomId.toString() : "",
      },
      roomId,
    });
  },
});
