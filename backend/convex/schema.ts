import { defineSchema, defineTable } from "convex/server";
import { v } from "convex/values";

/**
 * One GIF or sticker, as a user's recents and favourites remember it.
 *
 * A snapshot, not a reference: it carries everything needed to draw the tile
 * and to send it again, so the picker's RECENT row costs no lookups. `kind` is
 * the message type it sends as ("gif" | "sticker"); `source` is where the art
 * lives ("klipy" | "pack"), with the KLIPY fields or the pack fields filled in
 * accordingly.
 */
export const expressionRef = v.object({
  kind: v.string(),
  source: v.string(),
  stickerId: v.optional(v.id("stickers")),
  storageId: v.optional(v.id("_storage")),
  format: v.optional(v.string()),
  url: v.optional(v.string()),
  previewUrl: v.optional(v.string()),
  ref: v.optional(v.string()),
  width: v.optional(v.number()),
  height: v.optional(v.number()),
  title: v.optional(v.string()),
});

export default defineSchema({
  users: defineTable({
    username: v.string(),
    name: v.optional(v.string()),
    passwordHash: v.string(),
    recoveryKeyHash: v.optional(v.string()),
    createdAt: v.number(),
    status: v.optional(v.string()), // "online" | "away" | "offline"
    lastSeen: v.optional(v.number()),
    email: v.optional(v.string()),
    avatarStorageId: v.optional(v.id("_storage")),
    // When the handle was last changed. Absent on every account still using the
    // name it signed up with, which is why it is optional rather than
    // backfilled — "never renamed" and "renamed long ago" want the same answer
    // from the cooldown, and that is what a missing value already gives.
    //
    // Read only by `users.applyUsernameChange`, which is the single place the
    // handle can change at all. Not indexed: it is looked up by `_id`, never
    // ranged over.
    usernameChangedAt: v.optional(v.number()),
    // The local day key ("2026-08-21") this account was last sent the daily
    // "you haven't played today" nudge for.
    //
    // This IS the once-a-day guarantee, and it is a claim rather than a log:
    // `dailyNudge.claimNudges` reads and writes it in one mutation, so a
    // second cron tick — a retry, a deploy that overlapped one, or simply a
    // person carrying two devices in two time zones whose local noons both
    // come round — finds the day already claimed and sends nothing. Absent on
    // every account that has not been nudged since this shipped, which reads
    // correctly as "not today".
    lastNudgedDayKey: v.optional(v.string()),
    // `deviceTokens` used to sit here: raw APNs tokens from before the
    // per-device `userDevices` registry existed. Stripped from every row by
    // `migrations.stripDeviceTokens` and removed 2026-08-08. Convex rejects a
    // schema that omits a field still present on disk, which is why deleting
    // one is a deploy → migrate → deploy sequence rather than an edit.
    // PushKit VoIP token (iOS) — a DIFFERENT token from the regular APNs
    // alert token, on the `<bundle>.voip` topic rather than `<bundle>`. Used
    // to wake the app for CallKit ringing when killed.
    voipToken: v.optional(v.string()),
    // FCM token (Android) — used to send data-only high-priority pushes that
    // wake a killed app for the native ConnectionService ringer.
    fcmToken: v.optional(v.string()),
    // Per-field visibility — each value is "public" | "friends" | "nobody".
    // username + name are always public since they're identity. Missing keys
    // read as `visibility.ts`'s DEFAULT_LEVEL on both server and client; this object stores exactly what the user has set, verbatim.
    visibility: v.optional(
      v.object({
        avatar: v.optional(v.string()),
        status: v.optional(v.string()),
        lastSeen: v.optional(v.string()),
        // Whether this user's read receipts ("SEEN" indicator) are surfaced
        // to message senders. Reader-side control: when "nobody", the server
        // omits this user's lastReadAt from getReadState responses.
        seen: v.optional(v.string()),
        friendRequests: v.optional(v.string()), // "public" | "nobody"
        // ── Feed board ───────────────────────────────────────────────────
        // All three are "friends" | "nobody" — never "public". The board is
        // friends-only by construction and a "public" value here would be a
        // lie the UI could not honour, so `updateVisibility` refuses it.
        //
        // Absent reads as "friends" for `feed`/`puzzle` and as "nobody" for
        // `pointsPast`, which is the split the product asks for: today is
        // shared, history is opt-in. That is the ONE place in this object
        // where a missing key does not mean "nobody", so it is spelled out at
        // the single read site (feed.ts `visibilityOf`) rather than being
        // re-derived per caller.
        feed: v.optional(v.string()),        // my HIGHLIGHTS (photos) reach friends
        points: v.optional(v.string()),      // my POINTS (jinx/fate/…) reach friends
        puzzle: v.optional(v.string()),      // my daily puzzle score is comparable
        pointsPast: v.optional(v.string()),  // friends may look past today
      })
    ),
    // Supervised (child) accounts. Absent === "adult" — every pre-existing
    // row, so there is nothing to backfill. A child account is created by a
    // guardian via `family.createChildAccount`, can only sign in by redeeming
    // a pairing code (never a password), and cannot sign itself out.
    accountType: v.optional(v.string()), // "adult" | "child"
    birthYear: v.optional(v.number()),
    // What this child is allowed to do without asking. Guardian-controlled
    // via `family.setChildPolicy`; the child can never edit it. Only ever set
    // on accountType === "child" rows.
    childPolicy: v.optional(
      v.object({
        publicRoomsEnabled: v.boolean(), // false → Discover is hidden entirely
        callsEnabled: v.boolean(),
        mediaEnabled: v.boolean(),       // photo/video/voice sends
        canRequestContacts: v.boolean(), // "ask to add someone"
        canCreateRooms: v.boolean(),
        // Static and live location shares. OPTIONAL where its five siblings
        // are required, and that is not laziness: every child account written
        // before this flag existed has a stored policy object without it, and
        // a required field here would make those rows fail schema validation
        // on the next `setChildPolicy` write — i.e. would break the one
        // mutation a guardian would use to set it.
        //
        // The absent case is read as `false` at the enforcement site
        // (`guardOutgoing`), so an un-backfilled child cannot share location
        // until a guardian says so. See LOCATION_POLICY_FLAG in childGuard.ts.
        locationSharingEnabled: v.optional(v.boolean()),
      })
    ),
  })
    .index("by_username", ["username"])
    // Presence staleness sweep (users.sweepStalePresence) ranges over lastSeen
    // to find clients that stopped heartbeating. See presence.ts.
    //
    // `status` leads on purpose. Ranging `lastSeen` alone gave the 200 OLDEST
    // rows in the table, and the sweep only patches `status` — so a swept row
    // kept its ancient `lastSeen`, stayed in the range forever, and every tick
    // re-read the same prefix of long-dead accounts. Past ~200 of those, nobody
    // newly stale was ever reached. Leading with `status` means a patched row
    // leaves the scanned range immediately, which is what makes the bound on
    // the query a page size rather than a permanent ceiling.
    .index("by_status_lastSeen", ["status", "lastSeen"]),

  // Per-device push registration. One row per (userId, deviceId) — every
  // logged-in device gets its own entry so a sibling device login doesn't
  // overwrite this device's wake-up token. Replaces the single-string
  // voipToken/fcmToken fields on `users` (those remain as a read-only
  // fallback for clients that haven't relogged since the migration).
  // `voipPush.sendVoip` fans out across all rows for a user; on dead-token
  // errors we clear just the affected row, not the user's other devices.
  userDevices: defineTable({
    userId: v.id("users"),
    deviceId: v.string(),                    // client-persisted UUIDv4
    platform: v.string(),                    // "ios" | "ios-simulator" | "android" | "macos" | "windows" | "linux" | "web"
    voipToken: v.optional(v.string()),       // iOS PushKit — topic <bundle>.voip
    // Regular APNs alert/background token, from
    // application(_:didRegisterForRemoteNotificationsWithDeviceToken:).
    // NOT interchangeable with voipToken: different token, different topic
    // (`<bundle>`). Sending one on the other's topic gets a 400
    // DeviceTokenNotForTopic — and since the dead-token sweep would then
    // clear a perfectly good token, crossing them silently stops a phone
    // ringing. `push.ts` never reads voipToken for exactly this reason.
    apnsToken: v.optional(v.string()),
    // APNs environment both iOS tokens were minted under. Debug/dev builds
    // produce sandbox tokens, distribution (TestFlight/App Store) builds
    // produce production tokens; the two are NOT interchangeable. Stored
    // per-device so one deployment can reach both. Missing → fall back to
    // the APNS_SANDBOX env default. Resolved from the embedded provisioning
    // profile, not the build mode — see AppDelegate.apnsEnvironment().
    apnsEnv: v.optional(
      v.union(v.literal("sandbox"), v.literal("production")),
    ),
    fcmToken: v.optional(v.string()),        // Android FCM
    // Web Push subscription (RFC 8030), on `platform: "web"` rows only. The
    // three fields are what `PushSubscription.toJSON()` yields, and all three
    // are needed: the endpoint says which push service to POST to, and the
    // two keys seed the RFC 8291 payload encryption. Cleared together.
    webEndpoint: v.optional(v.string()),
    webP256dh: v.optional(v.string()),       // base64url, 65-byte P-256 pubkey
    webAuth: v.optional(v.string()),         // base64url, 16-byte auth secret
    // Per-device notification opt-out. `undefined` means enabled, so every
    // row that predates this field keeps working untouched.
    //
    // Governs ALERT pushes only. A ringing call is not a notification
    // preference — silencing chat should never silence the phone — so
    // voipPush deliberately ignores it.
    pushEnabled: v.optional(v.boolean()),
    // Per-device opt-out for the once-a-day "you haven't played today" nudge,
    // and ONLY that. Separate from `pushEnabled` above on purpose: the whole
    // point of a daily broadcast having a switch is that turning it off must
    // not also cost you your messages. `undefined` means enabled, so every row
    // predating the field keeps working. See dailyNudge.ts.
    gameRemindersEnabled: v.optional(v.boolean()),
    // Per-device opt-out for FRIEND ACTIVITY — "Ada posted a highlight",
    // "Ada finished Queens in 2:14". Its own switch for the same reason
    // `gameRemindersEnabled` has one: this is the only class of push in the
    // app whose volume is set by other people, so the person who has twelve
    // chatty friends must be able to quiet it without also quieting the
    // twelve people talking to them. `undefined` means enabled, so every row
    // predating the field keeps working. See socialPush.ts.
    friendActivityEnabled: v.optional(v.boolean()),
    // Human-readable label shown in the "Move call here" pill. Captured
    // from `UIDevice.current.name` / `Host.current().localizedName` /
    // `Settings.Global.DEVICE_NAME` etc. at login. Optional — clients
    // fall back to a friendly platform name when missing.
    deviceName: v.optional(v.string()),
    // The language this device's app SETTLED on — not the device language and
    // not the user's override, but the one Flutter resolved from both against
    // `AppLocalizations.supportedLocales`. A BCP-47-ish tag: "tr", "pt-BR".
    //
    // Per device rather than per user because it is a property of the running
    // app, not of the person: a shared family handset in Turkish and its
    // owner's laptop in English are both correct at once, and the notification
    // each receives should read in the language its own screen is already in.
    // Written by `setDeviceContext`, which the client re-runs whenever the
    // resolved locale changes.
    locale: v.optional(v.string()),
    // Minutes this device's wall clock is ahead of UTC — `+180` in Istanbul,
    // `-480` in California. Every real zone is a multiple of 15 (Kathmandu is
    // +345, Chatham +765), which is why the nudge cron ticks quarter-hourly.
    //
    // A raw offset rather than an IANA zone name because that is what Dart can
    // report without a plugin, and it is re-uploaded on every resume — so
    // travel and DST are both picked up the next time the app is opened, and
    // a device that has not been opened in weeks has a stale `lastSeenAt` that
    // already excludes it from the audience.
    tzOffsetMinutes: v.optional(v.number()),
    lastSeenAt: v.number(),
    createdAt: v.number(),
  })
    .index("by_user", ["userId"])
    .index("by_user_device", ["userId", "deviceId"])
    // Account-change eviction: one physical device, one account. `upsertDevice`
    // deletes every OTHER user's row for the deviceId it is registering, so a
    // phone that signs in as B after A stops carrying A's push credentials.
    .index("by_device", ["deviceId"])
    // Token-reassignment dedupe. A push token is unique to one device-app
    // pair at any moment, so a token appearing under a second (userId,
    // deviceId) means it moved and the old row must stop being pushed to.
    // Indexed rather than `.filter()`-scanned — the original voipToken sweep
    // reads the whole table on every login.
    .index("by_voip_token", ["voipToken"])
    .index("by_apns_token", ["apnsToken"])
    .index("by_fcm_token", ["fcmToken"])
    .index("by_web_endpoint", ["webEndpoint"])
    // Bounds `push.coverageReport` to devices that have been seen recently,
    // so "can we actually reach our users" stays a cheap question to ask.
    .index("by_last_seen", ["lastSeenAt"])
    // "Whose clock reads noon right now?" — the whole audience query for the
    // daily nudge, in one equality probe plus a range on the second column.
    // Without the `lastSeenAt` suffix this would hand back every device that
    // ever registered in that zone and filter them in code, which is the shape
    // that turns one cron tick into a full-table scan.
    .index("by_tz_offset", ["tzOffsetMinutes", "lastSeenAt"]),

  friendships: defineTable({
    userId: v.id("users"),
    friendId: v.id("users"),
    status: v.string(), // "pending" | "accepted"
    createdAt: v.number(),
    respondedAt: v.optional(v.number()),
    roomType: v.optional(v.string()),
    messageLifetime: v.optional(v.number()),
    initialMessage: v.optional(v.string()),
    roomId: v.optional(v.id("rooms")),
    // ── Supervision relay ────────────────────────────────────────────────
    // How far a pending request has been released along the guardian chain:
    //
    //   child A → child B    A's guardian → B's guardian → B decides
    //   child A → adult B    A's guardian →                B decides
    //   adult A → child B                   B's guardian → B decides
    //   adult A → adult B                                  B decides
    //
    // A party who has not been released to sees NOTHING — the row is filtered
    // out of their incoming list and no push fires. `undefined` means "fully
    // visible to the recipient" so every pre-existing row keeps working with
    // no migration.
    stage: v.optional(v.string()),
    //   "awaitingSenderGuardian" | "awaitingRecipientGuardian" | "awaitingRecipient"
    deniedBy: v.optional(v.string()),
    //   "senderGuardian" | "recipientGuardian" | "recipient"
  })
    .index("by_user", ["userId"])
    .index("by_friend", ["friendId"])
    .index("by_pair", ["userId", "friendId"])
    // Guardian queue lookups: "requests my child sent that I must release"
    // and "requests addressed to my child that I must release".
    .index("by_stage_user", ["stage", "userId"])
    .index("by_stage_friend", ["stage", "friendId"]),

  rooms: defineTable({
    name: v.string(),
    description: v.optional(v.string()),
    createdBy: v.id("users"),
    createdAt: v.number(),
    isPrivate: v.boolean(),
    memberCount: v.number(),
    passwordHash: v.optional(v.string()),
    // New fields
    type: v.optional(v.string()),          // "regular" | "secret"
    messageLifetime: v.optional(v.number()), // auto-expiry in seconds
    avatarStorageId: v.optional(v.id("_storage")),
    lastMessage: v.optional(v.string()),
    lastMessageTime: v.optional(v.number()),
    // Set only on rooms the APP owns rather than people — see
    // `systemAccount.SYSTEM_ROOM_LOGS`. Absent on every ordinary room, and the
    // client reads it straight off the row (`listUserRooms` spreads the whole
    // document) to decide which chrome the room gets.
    system: v.optional(v.string()),
    // ── Who may widen the room ──────────────────────────────────────────
    //
    // Both absent on every room written before they existed, and both read
    // through a default that preserves exactly the behaviour those rooms
    // already had. No backfill.
    //
    //   membersCanInvite — may a plain member invite one of their friends?
    //     Defaults to TRUE (`roomAdmin.membersMayInvite`). An admin turning it
    //     off narrows invites to admins; it never gates the LINK, which is
    //     admin-only regardless — a member handing out a permanent join token
    //     is a different and much larger act than naming one person.
    //   linkJoinPolicy — what redeeming the invite link does. "open" (the
    //     default) puts the holder straight in: the link IS the secret, and
    //     rotating it is how an admin takes that back. "approval" turns a
    //     redemption into a `roomJoinRequests` row an admin rules on, for
    //     rooms where holding the link should not be the whole test.
    membersCanInvite: v.optional(v.boolean()),
    linkJoinPolicy: v.optional(v.string()), // "open" | "approval"
  })
    .index("by_name", ["name"])
    .index("by_last_activity", ["lastMessageTime"])
    // Discover lists public rooms only.
    .index("by_visibility", ["isPrivate"]),

  roomMembers: defineTable({
    roomId: v.id("rooms"),
    userId: v.id("users"),
    joinedAt: v.number(),
    // "owner" | "admin" | "member".
    //
    // THIS ROW IS THE AUTHORITY on what someone may do in a room. It did not
    // used to be: every check in `rooms.ts` tested `rooms.createdBy` instead,
    // which made the role decorative and capped a group at exactly one
    // privileged person — the one who happened to create it. `roomAdmin.ts`
    // now reads this field and nothing else, and `rooms.createdBy` is left as
    // what it always honestly was, a record of who opened the room.
    //
    // Exactly one "owner" per room, kept true by `roomAdmin.transferOwnership`
    // (which demotes the old owner in the same mutation) and by the heir
    // promotion in `auth.purgeUser`. Rooms written before the admin tier
    // existed have one "owner" and the rest "member", which is already valid.
    role: v.string(),
    // ms since epoch — last time this user "read" the room. Used to compute
    // read receipts: a message is "seen by X" when roomMembers[room,X].lastReadAt >= message.createdAt.
    lastReadAt: v.optional(v.number()),
    // ms since epoch — last time this user's device HAD the room's traffic,
    // whether or not they looked at it. The second tick.
    //
    // A cursor on the membership row, exactly like `lastReadAt` and for exactly
    // the same reason: "delivered" as a per-message × per-recipient fact is
    // O(messages × members) rows and a write per message per recipient, which
    // is the fan-out this whole schema is built to avoid (see the
    // `viewOnceViews` and `pins` comments). One row per membership answers the
    // only question the UI asks — "is this message past the recipient's
    // cursor?" — at O(rooms × members), and it is the same shape the read
    // receipt has already proven at this scale.
    //
    // Written by `markRoomDelivered` when the recipient's client sees the room
    // move, and by `markRoomRead`, which advances it too: reading a room is
    // proof of delivery, and folding it into the same patch means the two
    // cursors can never cross. That also means a recipient on a build too old
    // to call `markRoomDelivered` still advances this the moment they open the
    // room, so senders are not stuck on one tick waiting for a rollout.
    //
    // Absent on every row written before this field existed. It reads as 0,
    // which is behind every message, so those simply show one tick until the
    // recipient's client writes the cursor once. No backfill.
    lastDeliveredAt: v.optional(v.number()),
    // WALL-CLOCK times the two cursors above last advanced — what the receipts
    // screen shows. The cursors themselves cannot be shown: `markRoomRead`
    // writes the newest read message's own `createdAt` as `lastReadAt` (an OCC
    // fix, see there), so displaying it made every "read" time equal the
    // message's sent time. Comparisons stay on the cursors; these are display
    // only. Absent on rows not advanced since they were added; the client
    // falls back to the cursor.
    lastReadClock: v.optional(v.number()),
    lastDeliveredClock: v.optional(v.number()),
    // Each cursor's recent moves, so a message's own delivered/read time can
    // be found again after the cursor has moved past it — the clocks above
    // only ever hold the newest move. Bounded; see receiptLog.ts. Absent on
    // rows not advanced since it was added.
    readLog: v.optional(
      v.array(v.object({ upTo: v.number(), at: v.number() })),
    ),
    deliveredLog: v.optional(
      v.array(v.object({ upTo: v.number(), at: v.number() })),
    ),
    // Per-viewer chat-list organization. Lives here, not on `rooms`, because
    // pinning/archiving a chat is inherently per-member — the same room can
    // be pinned for one member and untouched for everyone else in it.
    isPinned: v.optional(v.boolean()),
    pinnedAt: v.optional(v.number()),
    isArchived: v.optional(v.boolean()),
    archivedAt: v.optional(v.number()),
    // ── Per-viewer mute ─────────────────────────────────────────────────
    //
    // Same per-membership reasoning as `isPinned`/`isArchived` above: muting
    // a chat is one person's decision about their own attention, and the same
    // room stays loud for everyone else in it.
    //
    // TWO switches, not one, because "stop buzzing me about this" and "hide
    // this from my counts entirely" are different requests. The first is the
    // everyday one; the second is the stronger "I don't want to see this at
    // all". They are read independently everywhere — a room muted for
    // notifications only still climbs its unread count and still bolds in the
    // chat list, which is exactly what someone who picked only that switch
    // asked for.
    //
    //   muteNotifications — suppresses the push before it is sent. The check
    //     lives server-side, at `push.sendAlert`, because a notification
    //     suppressed on the device has already buzzed. Only `kind: "message"`
    //     is gated: an incoming call carries a roomId too, and silencing a
    //     ringing phone is not what anyone means by muting a chat.
    //   muteBadges — drops the room out of `badges.badgeTotalFor`, so it stops
    //     contributing to the OS app-icon count, and tells the client to hide
    //     its unread pill, its dot and its bold name.
    //
    // `mutedUntil` is the clock both switches hang on: an absolute instant in
    // ms since epoch, computed server-side from a duration the client asks for
    // so a phone with a skewed clock cannot mute for the wrong length of time.
    // Absent means no mute; a value in the past means one lapsed and is read
    // as nothing, with no sweep and nothing to clean up. "Always" is the
    // sentinel `mute.MUTE_ALWAYS` rather than a null — see that file for why
    // the sentinel is the safe direction to forget about.
    //
    // Absent on every row written before these fields existed, which reads as
    // "not muted". No backfill.
    muteNotifications: v.optional(v.boolean()),
    muteBadges: v.optional(v.boolean()),
    mutedUntil: v.optional(v.number()),
    // Denormalized copy of this member's `users.visibility.seen`, the ONLY
    // field `messages:getReadState` needs from the full `users` row it used
    // to read per member. Reading the row for one near-static field meant
    // that query re-fired on every member's presence heartbeat too, since
    // Convex subscribes at document granularity. Stamped at membership
    // creation (`visibility.seenVisibilityOf`) and kept current by
    // `users.updateVisibility`'s fan-out whenever the owner changes the
    // setting. Absent on every row written before this field existed —
    // resolves through `DEFAULT_LEVEL.seen` ("friends") until the one-time
    // backfill migration runs; see `migrations.backfillSeenVisibility`.
    seenVisibility: v.optional(v.string()),
  })
    // No standalone `by_room` — `by_room_user` alone serves every "all
    // members of this room" read as a prefix scan on `roomId`.
    .index("by_user", ["userId"])
    .index("by_room_user", ["roomId", "userId"]),

  // ── Group invites ─────────────────────────────────────────────────────────

  // The room's join token. ONE row is live per room at a time — see
  // `roomInvites.rotate`, which stamps `revokedAt` on the outgoing row in the
  // same mutation that inserts the replacement. Old rows are kept, not
  // deleted, so a redemption attempt on a rotated code can answer
  // INVITE_REVOKED instead of the indistinguishable INVITE_NOT_FOUND, and so
  // an admin can see that a link was rotated rather than never made.
  //
  // The `code` is the whole secret and the whole address: the shared URL is
  // just `<site>/j/<code>`, and typing the code by hand is the same act as
  // opening the link. There is no second "invite code" concept — one token,
  // rendered two ways.
  roomInvites: defineTable({
    roomId: v.id("rooms"),
    // Uppercase, from `roomInvites.ALPHABET` — no O/0/I/1, because this is
    // read aloud and retyped. Stored exactly as generated; redemption
    // normalizes the caller's input rather than the stored value.
    code: v.string(),
    createdBy: v.id("users"),
    createdAt: v.number(),
    // Set the moment a newer link replaces this one, or an admin revokes
    // without issuing a replacement. A row with this set is dead forever.
    revokedAt: v.optional(v.number()),
    // Optional admin-set limits. Absent means "no limit" for both, which is
    // the default an admin gets without opening the sheet.
    //
    // Both are checked at redemption against the SERVER's clock and the
    // stored counter, never trusted from the client, and neither is swept:
    // an expired or exhausted row simply stops redeeming. There is nothing
    // to garbage-collect and nothing that can fire late.
    expiresAt: v.optional(v.number()),
    maxUses: v.optional(v.number()),
    // Incremented on every redemption that actually admits someone — a join
    // request that an admin later rejects still counted, because the link
    // did its work. Existing members re-opening the link do not count.
    useCount: v.number(),
  })
    .index("by_code", ["code"])
    .index("by_room", ["roomId"])
    // Account teardown: links this user issued.
    .index("by_creator", ["createdBy"]),

  // A directed invite: one member naming one person, who then accepts or
  // rejects. Deliberately the same shape as a friend request in `friendships`
  // — including the guardian relay in `stage` — because it is the same social
  // act and must not behave differently when either party is a child.
  //
  // Separate from `roomJoinRequests` even though both end in a membership,
  // because they point opposite ways: this one is the ROOM asking a person,
  // and needs the invitee's yes; that one is a person asking the room, and
  // needs an admin's. Merging them would mean one table where "who decides"
  // depends on a direction column, and every query would have to remember it.
  roomInvitations: defineTable({
    roomId: v.id("rooms"),
    inviterId: v.id("users"),
    inviteeId: v.id("users"),
    status: v.string(), // "pending" | "accepted" | "rejected" | "cancelled"
    createdAt: v.number(),
    respondedAt: v.optional(v.number()),
    // Same three values and same meaning as `friendships.stage`, resolved by
    // the same `childGuard.initialStageFor`. Absent means fully visible to
    // the invitee. A party who has not been released to sees NOTHING — the
    // row is filtered out of their list and no push fires.
    stage: v.optional(v.string()),
  })
    // The invitee's pending list, which is the query that runs constantly.
    .index("by_invitee_status", ["inviteeId", "status"])
    // "Is this person already invited here?" — the duplicate guard, and the
    // per-room roster of outstanding invites. Prefix-scannable on roomId
    // alone, so it serves both without a separate by_room index.
    .index("by_room_invitee", ["roomId", "inviteeId"])
    .index("by_inviter", ["inviterId"])
    // Guardian queues, mirroring `friendships`.
    .index("by_stage_invitee", ["stage", "inviteeId"])
    .index("by_stage_inviter", ["stage", "inviterId"]),

  // Someone redeemed the link on a room whose `linkJoinPolicy` is "approval".
  // They are not a member yet and cannot read anything; this row is only the
  // question, and any admin may answer it.
  roomJoinRequests: defineTable({
    roomId: v.id("rooms"),
    userId: v.id("users"),
    // Which link let them ask. Kept so rotating a link can also be read as
    // "these pending requests came in on the code I just killed", and so a
    // request survives its invite row being rotated away.
    inviteId: v.optional(v.id("roomInvites")),
    status: v.string(), // "pending" | "approved" | "rejected"
    createdAt: v.number(),
    decidedAt: v.optional(v.number()),
    decidedBy: v.optional(v.id("users")),
  })
    // The admin queue for one room.
    .index("by_room_status", ["roomId", "status"])
    // Duplicate guard, and "have I already asked?" for the requester's UI.
    .index("by_room_user", ["roomId", "userId"])
    .index("by_user", ["userId"])
    // Account teardown: requests this user ruled on.
    .index("by_decider", ["decidedBy"]),

  // A member who may NOT edit the room asking for it to be edited anyway —
  // "use this photo instead", "call it Trip 2026". See `roomChangeRequests.ts`
  // for why the admin-only rule on `rooms.updateRoom` grew an answer rather
  // than being loosened.
  //
  // Separate from `roomJoinRequests` even though both are a person asking an
  // admin for something: that one is answered by a membership and comes from
  // somebody who cannot see the room, this one is answered by a patch to the
  // room document and comes from somebody already inside it. One table would
  // mean half the columns null depending on a discriminator.
  //
  // At most ONE pending row per (room, user, field) — `propose` replaces
  // rather than queueing, which is both the flood control and what somebody
  // who picks a second photo actually meant.
  roomChangeRequests: defineTable({
    roomId: v.id("rooms"),
    userId: v.id("users"),
    // "avatar" | "name" | "description". A field this build has never heard of
    // is refused at `propose`; nothing reads this without matching it.
    field: v.string(),
    // The proposed text, for "name" and "description". An empty string is a
    // real proposal on a description — "take it off" — and is why this is not
    // collapsed into "absent means unset".
    value: v.optional(v.string()),
    // The proposed picture, for "avatar". Already uploaded: the file exists
    // from the moment the row does, and every ending except approval releases
    // it (see `releaseProposal`), because the row is then its last pointer.
    storageId: v.optional(v.id("_storage")),
    // "pending" | "approved" | "rejected". A WITHDRAWN row is deleted rather
    // than stamped — "forget I asked" that leaves something for an admin to
    // read later is not a withdrawal.
    status: v.string(),
    createdAt: v.number(),
    decidedAt: v.optional(v.number()),
    decidedBy: v.optional(v.id("users")),
  })
    // The admin queue for one room.
    .index("by_room_status", ["roomId", "status"])
    // The replace-my-own-suggestion guard, the proposer's own view, and —
    // prefix-scanned on roomId alone — the room teardown sweep.
    .index("by_room_user", ["roomId", "userId"])
    // Account teardown, both directions.
    .index("by_user", ["userId"])
    .index("by_decider", ["decidedBy"]),

  // ── Family ────────────────────────────────────────────────────────────────

  // Who supervises whom. A child may have several guardians; ANY of them can
  // approve, deny, or revoke — approvals are not quorum-based.
  guardianships: defineTable({
    guardianId: v.id("users"),
    childId: v.id("users"),
    role: v.string(), // "primary" | "guardian"
    createdAt: v.number(),
  })
    .index("by_guardian", ["guardianId"])
    .index("by_child", ["childId"])
    .index("by_pair", ["guardianId", "childId"]),

  // Short-lived, single-use codes that hand a child account to a device.
  // The plaintext six digits never touch the database — the client hashes
  // them with the same sha256 helper it uses for passwords, and we compare
  // hashes. A code is dead the moment it is redeemed or `expiresAt` passes.
  pairingCodes: defineTable({
    childId: v.id("users"),
    createdByGuardianId: v.id("users"),
    codeHash: v.string(),
    expiresAt: v.number(),
    consumedAt: v.optional(v.number()),
    consumedDeviceId: v.optional(v.string()),
  })
    .index("by_child", ["childId"])
    .index("by_codeHash", ["codeHash"])
    // Account teardown: codes a departing guardian minted for other children.
    .index("by_creator", ["createdByGuardianId"]),

  // Short-lived, single-use codes that hand a child's device BACK — the exact
  // inverse of `pairingCodes`, and deliberately a separate table rather than a
  // `purpose` field on that one.
  //
  // `redeemPairingCode` finds codes by `codeHash` alone. Were both kinds to
  // share a table, a single missed purpose-check would let a release code be
  // redeemed as a *sign-in* code — a child who watched a parent release one
  // handset could pair themselves onto another. Separate tables make that
  // impossible structurally instead of by remembering to check.
  releaseCodes: defineTable({
    childId: v.id("users"),
    createdByGuardianId: v.id("users"),
    codeHash: v.string(),
    expiresAt: v.number(),
    consumedAt: v.optional(v.number()),
    consumedDeviceId: v.optional(v.string()),
  })
    .index("by_child", ["childId"])
    .index("by_codeHash", ["codeHash"])
    .index("by_creator", ["createdByGuardianId"]),

  // QR / short-code sign-in for a signed-out web or desktop client — the
  // "scan this with your phone" pattern, and the third member of this
  // short-lived-code family. Deliberately its OWN table rather than a
  // `purpose` flag on `pairingCodes`, for the same reason `releaseCodes` is
  // separate: a missed purpose-check must never be the thing standing between
  // a family pairing code and a full account sign-in.
  //
  // Unlike the two tables above, a row here starts out belonging to NOBODY —
  // the desktop that created it is anonymous until some phone approves it —
  // so there is no `childId`/`by_creator` to hang account-teardown or a
  // "supersede the old one" rule on. Two consequences:
  //   * `auth.purgeUser` can only ever clean up the `by_approver` side (a row
  //     this user approved for one of their OWN other devices); an
  //     unapproved row belongs to no account there is to purge.
  //   * nothing else in this app naturally reaps an abandoned row, so — unlike
  //     pairing/release codes — this table gets a real cron sweep on
  //     `expiresAt`. See `deviceLogin.gcExpiredDeviceLoginRequests`.
  //
  // Two secrets, not one, protecting two different surfaces of the same
  // pending row:
  //   `requestId` — high-entropy, minted by the SERVER, carried inside the QR
  //                 payload. Stored in the clear: it names an anonymous
  //                 request rather than proving anything about an account, and
  //                 the desktop that will read it back already holds it —
  //                 hashing would only defend a database dump, which this
  //                 single self-hosted deployment gets nothing from.
  //   `codeHash`  — the human-typeable fallback, minted on the DESKTOP the
  //                 same way a guardian mints a pairing code, and hashed
  //                 before it ever reaches this table. Six digits is
  //                 guessable, so every lookup by `codeHash` — not by
  //                 `requestId` — runs behind the same failed-attempt
  //                 throttle `auth.login` uses (see `deviceLoginKey` in
  //                 deviceLogin.ts).
  //
  // `status` is "pending" → "approved" | "denied", and "approved" →
  // "consumed" the instant the desktop collects its session
  // (`exchangeDeviceLoginRequest`). There is no stored "expired" status —
  // `expiresAt` is checked at every read/write that matters instead, the same
  // way `redeemPairingCode` checks it inline rather than needing a sweep to
  // stay correct in the meantime. Kept short (a few minutes): this is a
  // "someone is standing at their computer right now" flow, not a code read
  // aloud over a phone call.
  //
  // The finished session (`userId`/`username`/`name`) is deliberately NOT a
  // field here and never rides on the status a subscribed query returns —
  // only `exchangeDeviceLoginRequest` hands it out, once, to whoever holds
  // `requestId`. A polled/subscribed query is something a shoulder-surfer's
  // screenshot or an open devtools tab can see for free; a separate guarded
  // exchange call is not.
  deviceLoginRequests: defineTable({
    requestId: v.string(),
    codeHash: v.string(),
    status: v.string(), // "pending" | "approved" | "denied" | "consumed"
    // OS/browser string the requesting client sent up front, shown to the
    // phone at approval time — the whole of this feature's phishing
    // resistance rests on a person actually reading this before tapping
    // Approve, so it is the one piece of information every read of a pending
    // row carries.
    deviceInfo: v.string(),
    createdAt: v.number(),
    expiresAt: v.number(),
    approvedByUserId: v.optional(v.id("users")),
    approvedAt: v.optional(v.number()),
  })
    .index("by_requestId", ["requestId"])
    .index("by_codeHash", ["codeHash"])
    // Account teardown: sign-ins this user approved for one of their own
    // other devices.
    .index("by_approver", ["approvedByUserId"])
    // The cron sweep's only access path — see the class comment above.
    .index("by_expiresAt", ["expiresAt"]),

  // Standing grants. One row is both the request AND, once approved, the
  // grant — revoking is a status flip, so the whole audit trail stays in one
  // place.
  //
  // Two kinds:
  //   "joinRoom" — raised by the child, decided by a guardian.
  //   "contact"  — the whitelist. Created already-approved by a guardian, and
  //                consulted by `initialStageFor` to SKIP that guardian's hop
  //                in the relay. It is a pre-approval, not a friendship: the
  //                other person still has to accept.
  approvalRequests: defineTable({
    childId: v.id("users"),
    kind: v.string(),   // "joinRoom" | "contact"
    status: v.string(), // "pending" | "approved" | "denied" | "revoked"
    targetRoomId: v.optional(v.id("rooms")),
    targetUserId: v.optional(v.id("users")),
    note: v.optional(v.string()), // the child's "why I want this"
    createdAt: v.number(),
    decidedAt: v.optional(v.number()),
    decidedByGuardianId: v.optional(v.id("users")),
  })
    .index("by_child_status", ["childId", "status"])
    .index("by_child_room", ["childId", "targetRoomId"])
    .index("by_child_user", ["childId", "targetUserId"])
    // Account teardown: rows where the departing user is the person being
    // asked about, or the guardian who ruled on one.
    .index("by_target_user", ["targetUserId"])
    .index("by_decider", ["decidedByGuardianId"]),

  blocks: defineTable({
    userId: v.id("users"),         // who is doing the blocking
    blockedUserId: v.id("users"),  // who is blocked
    createdAt: v.number(),
  })
    .index("by_user", ["userId"])
    .index("by_pair", ["userId", "blockedUserId"])
    // Account teardown: a block survives its author otherwise, leaving the
    // blocked party invisible to a ghost.
    .index("by_blocked", ["blockedUserId"]),

  reports: defineTable({
    // Nulled out — not deleted — when the reporter deletes their account.
    // A report is a moderation record, so it outlives the person who filed
    // it; leaving the id dangling instead would point at a nonexistent user.
    reporterId: v.optional(v.id("users")),
    targetType: v.string(),  // "user" | "message" | "room"
    targetId: v.string(),    // string-encoded id; resolved by targetType
    reason: v.string(),
    note: v.optional(v.string()),
    createdAt: v.number(),
    status: v.optional(v.string()), // "open" | "resolved" | "rejected"
  })
    .index("by_reporter", ["reporterId"])
    .index("by_target", ["targetType", "targetId"])
    // Retention sweep only. Reports used to be kept forever, which is a weak
    // answer under GDPR Art. 13(2)(a) and is not one the amended COPPA Rule
    // permits at all for a service children use — it requires a published
    // retention policy and forbids holding children's data indefinitely.
    // The published period is 24 months; see users.gcExpiredReports.
    .index("by_createdAt", ["createdAt"]),

  // Problem reports — the "Report a problem" screen, NOT the moderation
  // `reports` table above. Different thing entirely: this is a bug report about
  // the app, that one is a complaint about a person.
  //
  // Holds no content on purpose. The report itself is delivered as a chat
  // message (see problemReports.ts) and that message IS the record; duplicating
  // the text, the device facts and the log here would mean a second copy of a
  // child's screenshot living in a table nobody reads, with its own retention
  // problem. What is left is exactly the throttle key and an audit trail.
  problemReports: defineTable({
    // The device, not the account, because the throttle has to work for a
    // signed-out reporter too — and because one person with two accounts is
    // still one person hammering the inbox.
    deviceId: v.string(),
    // Absent when nobody was signed in. Nulled the same way `reports` does it
    // if the account later goes away.
    reporterId: v.optional(v.id("users")),
    createdAt: v.number(),
    // The delivered text message. Absent only if delivery was skipped.
    messageId: v.optional(v.id("messages")),
  })
    // Serves the rate limiter, which asks one question: how many reports has
    // THIS device filed since a cutoff. Compound so the answer is a bounded
    // index range rather than a scan of every report ever filed.
    .index("by_device_createdAt", ["deviceId", "createdAt"])
    // Account deletion, which tombstones `reporterId` the same way it does on
    // `reports`. Exists only so that sweep is an index range and not a full
    // table scan on every account deletion.
    .index("by_reporter", ["reporterId"])
    // Retention sweep only, and load-bearing for the same reason the identical
    // index on `reports` is: nothing else ever deletes one of these rows, so
    // without the job that reads this index the table is an append-only ledger
    // of device identifiers. See problemReports.gcExpiredReports.
    .index("by_createdAt", ["createdAt"]),

  messages: defineTable({
    roomId: v.id("rooms"),
    userId: v.id("users"),
    content: v.string(),
    createdAt: v.number(),
    edited: v.optional(v.boolean()),
    // When the author last edited this message (see `messages.editMessage`).
    // Server-minted like `createdAt`, and separate from it on purpose:
    // `createdAt` orders the transcript and anchors the edit window, so
    // overwriting it would let a message drift down the room and re-open its
    // own window. `edited` stays a plain boolean beside it because every
    // pre-edit client already round-trips that field and renders nothing for
    // it — the timestamp is for the long-press detail view, the boolean is
    // for the stamp.
    editedAt: v.optional(v.number()),
    // Rich-text runs over `content` — bold, italic, spoiler, an explicit
    // link, and friends. A sidecar array of {start, end, type, url?} spans
    // (UTF-16 code-unit offsets into `content`) rather than markup in the
    // string, for the same reasons `mentions` below stores ids beside the
    // text instead of `<@id>` tokens: `content` is reused verbatim as the
    // push body, as `rooms.lastMessage` and as `replyToPreview.contentPreview`,
    // and markup would leak syntax into all three. A client that predates the
    // feature renders the plain text untouched — unknown fields afford
    // nothing. Validated and clamped server-side by `sanitizeFormatting`;
    // present or absent, never `[]` (the sparse-field rule below).
    formatting: v.optional(
      v.array(
        v.object({
          start: v.number(),
          end: v.number(),
          type: v.string(),
          url: v.optional(v.string()),
        })
      )
    ),
    // New fields
    // "text" | "image" | "video" | "videoNote" | "audio" | "file" | "url"
    // | "system" | "location" | "liveLocation" | "poll" | "checklist" | "event"
    //
    // The last three are interactive messages, whose body lives in
    // `messageInteractions` rather than here — see that table's header for why.
    // `content` on such a row is the question, the checklist title or the event
    // name, which is what makes every denormalized copy of it below correct
    // without any of them knowing what a poll is.
    type: v.optional(v.string()),
    mediaStorageId: v.optional(v.id("_storage")),
    // Pixel size of `mediaStorageId`, recorded by the sender who already holds
    // it. A photo bubble lays out at the picture's own ratio, and without this
    // the receiver can only learn that ratio by decoding the file — i.e. one
    // frame *after* it has already laid the bubble out at a guess. Optional
    // because every message sent before this field existed has neither, and
    // those fall back to a client-side measurement cache.
    mediaWidth: v.optional(v.number()),
    mediaHeight: v.optional(v.number()),
    // Documents (`type: "file"`). Convex storage keeps none of these: a stored
    // blob is a UUID with no name, no declared type and no extension, served
    // from a URL that carries no `Content-Disposition`. So unlike `mediaWidth`
    // above — an optimisation for a bubble that would otherwise measure the
    // picture itself — these are the only record that exists. Without them a
    // received document can be downloaded but not identified, named or opened
    // by anything that dispatches on file type.
    //
    // `mimeType` is derived from the name by the SENDER (see
    // `mimeTypeForFileName`) rather than taken from its file picker, which
    // omits it entirely on most Android providers and flattens it to
    // `application/octet-stream` on web.
    fileName: v.optional(v.string()),
    fileSize: v.optional(v.number()),
    mimeType: v.optional(v.string()),

    // ── The room's shared-content browser ───────────────────────────────────
    //
    // Which tab of "shared content" this message belongs in: "media" (a photo
    // or a video), "file", or "voice". Written at send time, and UNSET — not
    // set to "none" — on everything that belongs in no tab: text, system rows,
    // every view-once photo, and any attachment whose upload never produced a
    // storage id (`chat_repository` posts an image-typed message with no blob
    // when its retained-bytes cap refuses one; bucketing that would render a
    // grid tile that can never load).
    //
    // Unset rather than a sentinel because Convex has no sparse indexes but
    // `eq()` never matches an absent field. The excluded rows are therefore not
    // filtered out of the scan, they are outside it — the same trick, and the
    // same reasoning, as `viewOnceLive` below. That is also what keeps a
    // view-once photo out of the gallery structurally rather than by a check
    // somebody has to remember to write.
    galleryBucket: v.optional(v.string()),

    // Whether this message carries at least one URL — in `content` itself
    // (see `LINK_PATTERN` in messages.ts) or as a `formatting` link entity —
    // decided by the server at send and edit time so the LINKS tab can range
    // over history instead of re-parsing every message it has never loaded.
    //
    // Set to `true` or left absent, never written `false` — for the index
    // reason above. The URLs themselves are deliberately NOT stored: they
    // would duplicate `content` on a row that `messages:list` re-sends to
    // every member on every reaction change, and a client-supplied copy would
    // let a message render a tappable URL that appears nowhere in its text.
    // The tab already receives `content` and re-derives with the real
    // `UrlDetector`.
    hasLink: v.optional(v.boolean()),

    // Playing time of an audio or video attachment, in milliseconds, when the
    // sender could measure it. Lets a list row show "0:42" without fetching
    // and decoding the media first — the same argument as `mediaWidth`.
    mediaDurationMs: v.optional(v.number()),

    // A still frame of a video, uploaded alongside it as a second blob.
    //
    // Extraction is Android/iOS only, so this is absent on every video sent
    // from web or desktop and on all history. That is permanent, not a
    // migration state — the grid's play-glyph tile is the real fallback, not a
    // placeholder waiting to be filled in.
    //
    // NEVER written on an armed send. A view-once video's poster is a still of
    // the thing whose entire promise is that it leaks nothing, and neither
    // guard that protects `mediaStorageId` can see this one: `sanitizeViewOnce`
    // strips a fixed list of fields, and `files:getFileUrl` refuses view-once
    // by looking up `by_media`, which is keyed on `mediaStorageId` alone.
    // Not writing it is the guard; the sanitizer lists it as well, in depth.
    posterStorageId: v.optional(v.id("_storage")),

    // ── GIFs and stickers (`type: "gif"` / `type: "sticker"`) ───────────────
    //
    // `mediaSource` says where the picture lives: "klipy" (a GIF or sticker
    // from the KLIPY catalogue) or "pack" (one of our own sticker packs).
    //
    // KLIPY media is NEVER copied into storage. Its API terms forbid storing,
    // mirroring or proxying the files, so the row carries the URL exactly as
    // the API returned it and every client loads it straight from KLIPY's CDN.
    // `messages:send` refuses any host outside KLIPY's allowlist, which is what
    // stops this field from becoming a way to plant an arbitrary URL (a
    // tracking pixel, say) in somebody else's transcript.
    //
    // `mediaUrl` is the animated rendition; `mediaPreviewUrl` a small one for
    // reply thumbnails. `mediaRef` is KLIPY's slug, which its report and share
    // endpoints key on.
    mediaSource: v.optional(v.string()),
    mediaUrl: v.optional(v.string()),
    mediaPreviewUrl: v.optional(v.string()),
    mediaRef: v.optional(v.string()),
    // Pack stickers. The server copies the storage id and size off the
    // `stickers` row at send time; the client only names the sticker.
    //
    // A field of its own rather than `mediaStorageId`, and deliberately so: the
    // blob belongs to the PACK, and every message-teardown path
    // (`releaseMessageBlobs`, the view-once burn, account deletion) deletes
    // whatever `mediaStorageId` points at. One deleted sticker message would
    // otherwise take the sticker away from everybody.
    stickerId: v.optional(v.id("stickers")),
    stickerStorageId: v.optional(v.id("_storage")),
    // "lottie" or "image". Pack stickers can be either; KLIPY is always image.
    stickerFormat: v.optional(v.string()),

    senderName: v.optional(v.string()),
    expiresAt: v.optional(v.number()),       // Unix ms timestamp — set for Chamber of Secrets rooms
    // Reply support. `replyToId` points at the parent message; `replyToPreview`
    // is a denormalized snapshot of that parent taken at send time so the
    // inline tether keeps rendering even after the parent is deleted/expired
    // (sentinel: contentPreview === "__DELETED__").
    replyToId: v.optional(v.id("messages")),
    replyToPreview: v.optional(
      v.object({
        senderId: v.id("users"),
        senderName: v.string(),
        contentPreview: v.string(),
        type: v.string(),
        mediaStorageId: v.optional(v.id("_storage")),
        // A thumbnail for a quoted GIF or sticker, which has no
        // `mediaStorageId` to show. KLIPY's preview URL, or the pack sticker's
        // blob.
        mediaUrl: v.optional(v.string()),
        stickerStorageId: v.optional(v.id("_storage")),
        stickerFormat: v.optional(v.string()),
        // Set when the reply is to a whole album rather than one of its
        // photos: how many items it held. The parent is then the album's
        // first message, and the tether reads "4 items" with a stack.
        albumCount: v.optional(v.number()),
      })
    ),
    // The album this message was sent in: one id shared by every photo and
    // video of one send, generated by the sending client. The client stacks
    // an album by it exactly, rather than guessing from timing; a reply or a
    // reaction to the whole album is addressed through the album's first
    // message (see `replyToPreview.albumCount`, `reactions.album`).
    albumId: v.optional(v.string()),
    // Thread membership, denormalized at send time: the id of the message at
    // the top of this reply chain. Set ONLY on replies — a root message has
    // no `rootId`, so a thread is `{root} ∪ {m : m.rootId === root._id}`.
    //
    // This exists purely so threads can be *paged*. Deriving a thread by BFS
    // over `by_replyTo` produces a set that can't be split into pages: the
    // cap truncates in BFS order but the result renders in time order, so
    // page N+1 is not a prefix-extension of page N and newly-loaded messages
    // land in the middle of the list. `by_root_time` makes a thread page a
    // plain time-ordered range scan, exactly like `by_room_time` does for a
    // room. Never written without `replyToId` — see `messages:send`.
    rootId: v.optional(v.id("messages")),

    // ── @-mentions ──────────────────────────────────────────────────────────
    //
    // `content` keeps the literal `@handle` the sender typed; this array names
    // who those handles resolved to. The text is NOT rewritten into `<@id>`
    // markup the way Slack does it, because this table keeps four denormalized
    // copies of `content` and two of them are byte slices that would cut such a
    // token in half: `rooms.lastMessage` (100 chars), the push body,
    // `replyToPreview.contentPreview` (140 chars), and the clipboard. Literal
    // text needs no resolver in any of them, and a client too old to know about
    // mentions renders a readable sentence rather than a raw id.
    //
    // The username is stored ALONGSIDE the id, denormalized exactly like
    // `replyToPreview` above it, so rendering a mention needs no roster at all.
    // That matters in three places a live member list isn't available: history
    // containing someone who has since left the room, the thread overlay, and a
    // cold boot off the disk cache.
    //
    // Handles ARE mutable — `users.applyUsernameChange` exists — but this array
    // still cannot drift, and the reason is subtler than immutability. It is
    // frozen in the same write as the `content` it anchors to, so the two age
    // as ONE: the reader matches this snapshot against that text, never against
    // the live roster (see `MentionDetector` and `ChatMessage.mentionHandles`).
    // A rename leaves both halves alone and the old message keeps highlighting,
    // still routing on `userId`. What a rename does cost is that a much older
    // message shows a handle its owner has since given up — which is the honest
    // rendering of what was actually typed, and the same thing that already
    // happens when an account is deleted and its handle re-registered.
    //
    // Rebuilt server-side on every send: the client sends ids, the server says
    // what they are called. `messages:send` keeps only current members of the
    // room, drops the sender's own id, de-duplicates, caps the count, and
    // requires the handle to actually appear in `content` — otherwise "hi"
    // could ping twenty people. Left undefined rather than `[]` when nothing
    // survives, so the field stays sparse; nothing queries it, so it has no index.
    mentions: v.optional(
      v.array(
        v.object({
          userId: v.id("users"),
          username: v.string(),
        })
      )
    ),
    // `@everyone`. A flag rather than an expanded roster: membership changes
    // between send and read, and a snapshot would notify people who have since
    // left while missing people who have since joined.
    mentionsEveryone: v.optional(v.boolean()),

    // ── View-once photos ────────────────────────────────────────────────────
    //
    // Armed by the sender in the pre-send editor. The promise is that the blob
    // leaves the server once every recipient has opened it (or after
    // `viewOnceDeadline`), while THIS ROW SURVIVES as a greyed ghost bubble so
    // the transcript keeps its shape.
    //
    // The enforcement is not in the bubble — it is in the read path. Every
    // query that returns messages strips `mediaStorageId` from a view-once row
    // (see `sanitizeViewOnce` in messages.ts), because `files:getFileUrl` is a
    // public query and, on a self-hosted deployment, hands back an unsigned
    // URL with no expiry. A client that learns the id has the picture forever,
    // whether or not it ever called `openViewOnce`.
    viewOnce: v.optional(v.boolean()),
    // Eligible recipients (members other than the sender) snapshotted at send
    // time, and how many of them have opened it. A counter rather than a
    // per-open member scan: the room's roster is walked once on send instead
    // of once per open, which matters on the box crons.ts:6-13 describes.
    viewOnceRecipients: v.optional(v.number()),
    viewOnceViewCount: v.optional(v.number()),
    // Set when the blob is gone. The client renders the ghost off this.
    viewOnceBurnedAt: v.optional(v.number()),
    // Hard deadline — burn even if somebody never opens it.
    viewOnceDeadline: v.optional(v.number()),
    // True exactly while the blob still exists; UNSET (not `false`) on burn.
    //
    // This is what the repair sweep ranges over, and it is a separate field
    // from `viewOnce` for a reason worth stating: Convex orders `undefined`
    // ahead of every number, so a scan of `lt("viewOnceDeadline", now)` matches
    // rows whose deadline has been cleared just as readily as rows that are
    // genuinely overdue. Keyed on `viewOnce` alone, every photo ever burned
    // would pile up at the head of the index and the sweep's row budget would
    // be spent re-skipping them long before it reached anything due. Keying on
    // a flag that is *removed* on burn takes those rows out of the bucket
    // altogether, because `eq(true)` never matches an absent field.
    viewOnceLive: v.optional(v.boolean()),

    // Idempotency key, minted by the sender before the first attempt and reused
    // verbatim on every retry of that same message. `messages:send` returns the
    // existing row instead of writing a second one when it sees a repeat.
    //
    // Needed because "did this send happen?" is genuinely unanswerable from the
    // client. A socket that dies between the server committing and the ack
    // arriving leaves the sender with a failed-looking message that in fact
    // landed, and every recovery path — the user tapping retry, the reconnect
    // sweep, the native client's own `resend_ongoing_queries_mutations` — then
    // sends it again. Without a key each of those is a new row.
    //
    // Optional because every message written before this field existed has
    // none, and Convex has no sparse indexes: `eq("clientId", <string>)` never
    // matches a row where it is absent, so those are simply invisible to the
    // dedupe lookup, which is the correct behaviour and needs no backfill.
    clientId: v.optional(v.string()),

    // `true` while any `reactions` row points at this message — a cache of
    // "`reactions.by_message` is non-empty". Set by `reactions.addReaction`
    // in the same transaction as the row it inserts, cleared (to `false`) by
    // `removeReaction` when the last one goes. Never written on insert: a
    // message starts with no reactions, and absent already says so.
    //
    // Exists for the read path. Every transcript query (`list`, `listBefore`,
    // `listAfter`, `listAround`, `getThreadPage`) used to do one indexed
    // `reactions` read PER MESSAGE it returned, and `list` is a subscription
    // that re-runs for every viewer on every send: a hundred index reads to
    // discover, nearly every time, that nobody had reacted to anything. With
    // the flag, `messages.reactionsFor` reads only for `true` rows and the
    // query costs its one range scan.
    //
    // The invariant is one-directional on purpose: `true` means "look", and
    // anything else means "there are none". A stale `true` (the clear-back
    // somehow missed) is harmless — one wasted read. A missing `true` would
    // HIDE reactions, so the flag is set in the same transaction as the
    // reaction, and `migrations.backfillHasReactions` walks the `reactions`
    // table once to set it on every message that already had some. That walk
    // touches only messages with reactions — a few hundred rows, not the
    // whole table — which is what keeps the backfill from writing a fresh
    // revision of every message on a box where every byte of disk is paid for
    // twice over in swap.
    hasReactions: v.optional(v.boolean()),

    // ── Location sharing ────────────────────────────────────────────────────
    //
    // Two message types share these: `"location"` (one fix, frozen at send
    // time) and `"liveLocation"` (the same fields, patched in place as the
    // sharer moves). Deliberately ONE row that gets patched rather than a
    // `liveLocationPoints` side table appended to:
    //
    //  * `messages:list` is already a live subscription that returns rows
    //    verbatim, so patching the row IS the delivery mechanism. A side table
    //    would need a second subscription per visible share.
    //  * A breadcrumb trail is a location HISTORY. Keeping only the newest fix
    //    means the thing the sharer stops sharing actually stops existing —
    //    where they were an hour ago is not recoverable from the transcript.
    //  * Cost: an 8-hour share is ~320 patches to one row rather than ~320
    //    inserts plus the sweep that would have to delete them, on the box
    //    crons.ts:6-13 describes.
    //
    // The trade-off, stated so nobody has to rediscover it: there is no
    // "replay the route" feature available without a schema change.
    latitude: v.optional(v.number()),
    longitude: v.optional(v.number()),
    // Horizontal accuracy in metres as the device reported it. The bubble draws
    // an accuracy ring from this, and refuses to draw one when it is absent
    // rather than inventing a radius — a fix from a laptop's Wi-Fi lookup can
    // be a kilometre wide and claiming otherwise would be a lie about how well
    // this locates somebody.
    locationAccuracyM: v.optional(v.number()),

    // ── Live shares only ────────────────────────────────────────────────────
    //
    // When the share stops on its own. THE authority — the client is never
    // trusted to end its own share, because a client that is force-quit,
    // crashes, or loses its battery would otherwise broadcast forever. See
    // `expireLiveLocation`.
    liveExpiresAt: v.optional(v.number()),
    // When `latitude`/`longitude` were last written. Lets a viewer distinguish
    // "stationary" from "the sharer's phone stopped talking to us", which are
    // very different things to show on a map and indistinguishable without it.
    liveUpdatedAt: v.optional(v.number()),
    // Set when the share ends — early by the sharer, or on its own at
    // `liveExpiresAt`. Presence of this is what the bubble's expired state
    // reads; the coordinates are deliberately left in place so the transcript
    // still says where the person was when it ended, exactly as a static share
    // would. Nothing new is disclosed by that: every one of those fixes was
    // already delivered to this room while the share was running.
    liveEndedAt: v.optional(v.number()),
    // True exactly while the share is running; UNSET (not `false`) when it
    // ends. Identical mechanism and identical reasoning to `viewOnceLive`
    // above — see `by_liveLocation_live_expiry`.
    liveShareLive: v.optional(v.boolean()),
  })
    // No standalone `by_room` — every call site ranges by time too, so
    // `by_room_time` alone serves both as a prefix scan on `roomId` and as
    // the time-ordered read; a narrower index would only add write cost.
    .index("by_room_time", ["roomId", "createdAt"])
    // The dedupe lookup. Scoped by sender as well as room so a client can only
    // ever collide with — or discover — its own keys.
    .index("by_room_user_client", ["roomId", "userId", "clientId"])
    .index("by_replyTo", ["replyToId"])
    .index("by_root_time", ["rootId", "createdAt"])
    // An album's members, to count them for a reply to the whole album.
    .index("by_album", ["albumId", "createdAt"])
    // Account teardown walks every message a user ever sent.
    .index("by_user", ["userId"])
    // The expired-view-once sweep. `viewOnceLive` MUST lead: Convex has no
    // sparse indexes and orders `undefined` before every number, so a lone
    // `q.lt("viewOnceDeadline", now)` would range-scan every message in the
    // deployment — precisely the >1s mutation crons.ts warns about. With the
    // boolean in front the scan is `q.eq("viewOnceLive", true).lt(...)`, which
    // touches only armed photos whose file is still there.
    .index("by_viewOnce_live_deadline", ["viewOnceLive", "viewOnceDeadline"])
    // The overdue-live-share repair sweep, and the same shape as the line
    // above for the same reason: `liveShareLive` MUST lead, because it is
    // absent on every message in the deployment except the handful of shares
    // running right now. Scanned as `q.eq("liveShareLive", true).lt(...)`.
    //
    // A repair sweep and not the mechanism. Each share gets its own
    // `ctx.scheduler.runAt` at send time (see `messages:send`); this only
    // catches shares whose schedule was lost, which matters more here than it
    // does for a view-once photo — a share that fails to expire keeps
    // broadcasting a live position, which is the one failure this feature is
    // not allowed to have.
    .index("by_liveLocation_live_expiry", ["liveShareLive", "liveExpiresAt"])
    // Reverse lookup for `files:getFileUrl`, so it can refuse a storage id
    // belonging to a view-once message. Defence in depth — after sanitizing,
    // no client should be able to name one in the first place.
    .index("by_media", ["mediaStorageId"])
    // The shared-content browser, one page per tab. `galleryBucket` leads for
    // the same reason `viewOnceLive` does: it is absent on the overwhelming
    // majority of rows, and Convex orders `undefined` before every string, so
    // the excluded messages form a contiguous prefix of each room's range that
    // `eq(roomId).eq(bucket)` never enters. A bare `by_room_time` scan filtered
    // in JS would instead read a whole transcript to find a dozen photos.
    .index("by_room_bucket_time", ["roomId", "galleryBucket", "createdAt"])
    // The LINKS tab. Same shape, same reasoning.
    .index("by_room_link_time", ["roomId", "hasLink", "createdAt"]),

  // ── Scheduled messages ────────────────────────────────────────────────────
  //
  // Messages the sender wrote now and asked to be delivered later. A STAGING
  // table rather than a `visible: false` flag on `messages`, and that is the
  // load-bearing decision: `messages:list` is a live subscription that hands
  // every row it finds to every member of the room, and the ten-odd other read
  // paths (`listBefore`, `listAround`, the shared-content buckets, the LINKS
  // tab, `getReadState`, `badges.unreadForRoom`, search) each range over the
  // same table. A hidden-row flag would have to be learned by all of them, and
  // every one that forgot it would publish the message early — to the one
  // person it must not reach yet.
  //
  // Nothing here is written into `messages` until `scheduledMessages:release`
  // fires, at which point the row is built by the ordinary `send` core with a
  // release-time `createdAt`. Stamping compose time instead would land the
  // message BELOW every recipient's `lastReadAt` cursor — silently already
  // read, and buried mid-transcript (see `badges.unreadForRoom`).
  //
  // Text only, on purpose. An attachment would mean a blob sitting in storage
  // referenced by nothing `files.gcOrphanedFiles` knows how to see, for up to a
  // year; the sweep would reclaim it and the message would send with a dead id.
  scheduledMessages: defineTable({
    roomId: v.id("rooms"),
    userId: v.id("users"),
    content: v.string(),
    // Absolute instant, ms since epoch, ALWAYS resolved server-side —
    // `schedule` takes either a `delayMs` (which it adds to its own clock) or a
    // wall-clock `sendAt` it range-checks. The stored value is the single
    // source of truth for both the scheduler job and the client's countdown.
    sendAt: v.number(),
    // When the user asked for it, not when it sends. Only used to order the
    // list sheet's ties and to show "scheduled 3 days ago".
    createdAt: v.number(),
    // Whether this row is still waiting to be sent.
    //
    // UNSET rather than written `false` once it leaves the bucket, which is the
    // `viewOnceLive` / `liveShareLive` idiom above and for exactly the same
    // reason: Convex has no sparse indexes and orders `undefined` before every
    // number, so `by_pending_due` can only be scanned cheaply as
    // `q.eq("pending", true).lt("sendAt", now)`. A `false` here would keep
    // every failed row inside the sweep's range forever.
    //
    // Successful releases delete the row outright, so in practice this only
    // ever goes from `true` to absent on a row that FAILED — which is the state
    // the list sheet renders as a retry affordance.
    pending: v.optional(v.boolean()),
    // The composer's context, carried verbatim so the released message is
    // indistinguishable from one sent by hand at that moment. Re-validated at
    // release (the parent may have been deleted, a mentioned member may have
    // left), never trusted from here.
    replyToId: v.optional(v.id("messages")),
    mentionedUserIds: v.optional(v.array(v.id("users"))),
    mentionsEveryone: v.optional(v.boolean()),
    formatting: v.optional(
      v.array(
        v.object({
          start: v.number(),
          end: v.number(),
          type: v.string(),
          url: v.optional(v.string()),
        })
      )
    ),
    // A scheduled PHOTO. Absent `type` is text — every row written before
    // photos could be scheduled. The blob is uploaded at schedule time, so the
    // picture the sender reviewed is the one that goes out; this row is its
    // only pointer until release, which is why `files.collectReferenced` scans
    // this table and why `cancel` and both purges delete it.
    type: v.optional(v.literal("image")),
    mediaStorageId: v.optional(v.id("_storage")),
    mediaWidth: v.optional(v.number()),
    mediaHeight: v.optional(v.number()),
    viewOnce: v.optional(v.boolean()),
    // Idempotency key, minted at schedule time and carried into the insert.
    // Required rather than optional: a release job that runs twice — the
    // deployment restarted between the insert and the commit — must find its
    // own row through `messages.by_room_user_client` and return it, exactly as
    // a retried hand-send does. See the head of `messages:send`.
    clientId: v.string(),
    // The `runAt` job this row is waiting on, so `reschedule` and `cancel` can
    // tidy it away. NOT the correctness mechanism — `release` re-reads the row
    // and bails unless `pending` is still true AND `sendAt` still matches what
    // the job was created for, which is what makes a lost `cancel` harmless.
    // Stored because a one-year horizon otherwise accumulates dead jobs.
    jobId: v.optional(v.id("_scheduled_functions")),
    // Why the release was refused, when it was: one of `guardOutgoing`'s thrown
    // strings (a revoked child grant, a room the sender was removed from, a DM
    // block raised after scheduling). There is no client on the line at release
    // time to throw at, so the reason is stored and the row is kept.
    failedReason: v.optional(v.string()),
    failedAt: v.optional(v.number()),
  })
    // The room's own list, and the only index the interactive path uses.
    // Scoped by sender as well as room because a scheduled message is private
    // to its author until it sends — nobody else may enumerate them.
    .index("by_room_user_due", ["roomId", "userId", "sendAt"])
    // The overdue repair sweep. `pending` MUST lead, for the reason spelled out
    // on `by_viewOnce_live_deadline` above. Scanned as
    // `q.eq("pending", true).lt("sendAt", now)`, which stops at the first row
    // that is not yet due — so an idle deployment pays one index probe.
    .index("by_pending_due", ["pending", "sendAt"])
    // Account teardown, and the room teardown's per-sender pass.
    .index("by_user", ["userId"])
    // Room teardown: everything staged for a room that no longer exists.
    .index("by_room", ["roomId"]),

  // Who has opened which view-once message. A side table rather than a
  // `readBy` array on `messages`, for the reason the roomMembers comment gives:
  // O(messages × members) fan-out is what this schema deliberately avoids. It
  // also means a client's read set can be scoped to its OWN rows, so one person
  // opening a photo doesn't refire every other member's message subscription.
  //
  // A row is created at GRANT time, not when the viewer closes the picture. A
  // client that crashes mid-view has still spent its view — that is the whole
  // point, and it's what stops a hostile client from fetching bytes for free.
  viewOnceViews: defineTable({
    messageId: v.id("messages"),
    roomId: v.id("rooms"),
    userId: v.id("users"),
    viewedAt: v.number(),
    // Whether this view counts toward the burn. False for someone who joined
    // the room after the message was sent: they may open it, but they can't
    // release the blob on the real recipients' behalf.
    countsToward: v.boolean(),
    // Server-minted, single-purpose download ticket. The bytes are streamed by
    // the `/viewOnce` HTTP action against this, so the storage URL itself never
    // reaches a client. Reusable until `grantExpiresAt` — that window is the
    // retry path for a download that dies on bad cellular, and it opens no
    // cross-device hole because the nonce is ours, not the client's.
    grantNonce: v.optional(v.string()),
    grantExpiresAt: v.optional(v.number()),
  })
    .index("by_message", ["messageId"])
    .index("by_message_user", ["messageId", "userId"])
    .index("by_room_user", ["roomId", "userId"])
    // Account teardown: rows where the departing user was the VIEWER.
    .index("by_user", ["userId"]),

  reactions: defineTable({
    messageId: v.id("messages"),
    userId: v.id("users"),
    emoji: v.string(),
    createdAt: v.number(),
    // A reaction to the whole album `messageId` heads, rather than to that
    // one photo. Kept on the first message so it needs no table of its own;
    // the flag keeps the two apart for uniqueness, the per-person cap and
    // display. Older clients see it as a reaction on the first photo.
    album: v.optional(v.boolean()),
  })
    .index("by_message", ["messageId"])
    .index("by_message_user", ["messageId", "userId"])
    // Account teardown walks every reaction a user ever left, including those
    // on messages that survive them.
    .index("by_user", ["userId"]),

  // ── Sticker packs ─────────────────────────────────────────────────────────
  //
  // Two kinds. "official" packs are seeded by `expressions:seedOfficialPacks`
  // and everybody sees them. A "personal" pack belongs to one user and holds
  // the stickers they made from their own photos; there is at most one per
  // user, created on their first sticker.
  //
  // KLIPY's stickers are NOT in here. They come from its API at browse time
  // and are never stored — see `messages.mediaSource`.
  stickerPacks: defineTable({
    // Stable name for idempotent seeding ("noto-moods"). Personal packs use
    // "personal:<userId>".
    slug: v.string(),
    title: v.string(),
    kind: v.string(), // "official" | "personal"
    ownerId: v.optional(v.id("users")),
    // Credit and licence for the art, shown in the pack's info sheet. The
    // Noto packs are CC BY 4.0, which requires exactly this.
    author: v.optional(v.string()),
    license: v.optional(v.string()),
    sourceUrl: v.optional(v.string()),
    // Where it sorts in the picker's pack strip.
    order: v.number(),
    createdAt: v.number(),
  })
    .index("by_slug", ["slug"])
    .index("by_kind_order", ["kind", "order"])
    .index("by_owner", ["ownerId"]),

  stickers: defineTable({
    packId: v.id("stickerPacks"),
    storageId: v.id("_storage"),
    // "lottie" (a Lottie JSON animation) or "image" (PNG, WebP or GIF, still
    // or animated).
    format: v.string(),
    // The emoji this sticker stands for, which is its alt text, its preview
    // on the chat list, the `content` of the message that carries it, and
    // what typing that emoji suggests it by.
    emoji: v.string(),
    width: v.number(),
    height: v.number(),
    order: v.number(),
    createdAt: v.number(),
    // Set when an owner deletes a personal sticker. The row and its blob stay,
    // because messages already sent point at them (`messages.stickerId`) and
    // must keep rendering; it just stops being listed.
    deletedAt: v.optional(v.number()),
  })
    .index("by_pack_order", ["packId", "order"]),

  // A user's recently sent and starred GIFs and stickers, one row per user,
  // so they follow the account across devices.
  //
  // Each entry is a small self-contained snapshot — enough to draw the tile
  // and send it again without another lookup. A KLIPY entry holds KLIPY's URLs
  // (never its files), exactly as a sent message does.
  userExpressions: defineTable({
    userId: v.id("users"),
    recents: v.array(expressionRef),
    favorites: v.array(expressionRef),
    // The official packs this user has added to their strip, in their order.
    // Absent means "never chosen" and reads as the default set
    // (`DEFAULT_PACK_SLUGS` in expressions.ts), so every account from before
    // the pack store — and every new one — starts somewhere sensible without
    // a backfill. Their personal pack is always shown and never listed here.
    installedPackIds: v.optional(v.array(v.id("stickerPacks"))),
    updatedAt: v.number(),
  })
    .index("by_user", ["userId"]),

  // Messages pinned to the top of a room. Many per room; any member may pin.
  //
  // A side table for the same reason `viewOnceViews` is one, and the reason is
  // sharper here: a `pinned` field on `messages` would patch a document that
  // `messages:list` reads, and that subscription refires on every doc it
  // touches (see the comment in messages.ts:list). One person pinning would
  // rebuild the entire transcript for every member of the room and reset each
  // reader's live window. Pins ride their own small subscription instead and
  // touch nothing the transcript reads.
  //
  // `roomId` is denormalized, like `viewOnceViews`: the only query that matters
  // is "this room's pins", and deriving the room from each message would mean a
  // scan. It is written server-side from `msg.roomId` and never taken from the
  // client, so a pin naming a room its message doesn't live in is not
  // representable.
  //
  // Every field is required, so no `undefined` ever reaches an index and the
  // ordering trap the `viewOnceLive` comment describes cannot apply. Each index
  // leads with an equality field.
  pinnedMessages: defineTable({
    roomId: v.id("rooms"),
    messageId: v.id("messages"),
    // Who pinned it. Named `userId` rather than `pinnedBy` so auth.ts's
    // `byUser` index helper applies verbatim, matching `reactions`.
    userId: v.id("users"),
    pinnedAt: v.number(),
  })
    // Serves both the live room query (prefix on roomId alone) and the
    // idempotence probe / unpin lookup (both fields). Convex indexes are
    // prefix-scannable, so one index covers both.
    .index("by_room_message", ["roomId", "messageId"])
    // Message teardown: `removeMessageAndFanout` holds a messageId and no room
    // scope. Without this there is no way to find a dying message's pin.
    .index("by_message", ["messageId"])
    // Account teardown, for pins this user left on messages that outlive them.
    // Same role as `reactions.by_user`.
    .index("by_user", ["userId"]),

  // One reader keeping one message, inside one room. The "SAVE" row in the
  // bubble menu and the "Saved messages" section of room info.
  //
  // ── Not the Saved Messages ROOM ────────────────────────────────────────────
  //
  // The product already has something called Saved Messages: the single-member
  // `dm:self:<userId>` notes-to-self room (`rooms.ensureSavedMessagesRoom`,
  // `ChatRoom.isSavedMessages` client-side). That is a PLACE you forward a COPY
  // to. This is a MARK on a message where it already lives, and copies nothing.
  //
  // The table is called `messageBookmarks` and not `savedMessages` precisely so
  // the two cannot be confused in code — `savedMessages` would read as "rows of
  // the saved-messages room" to everyone who touched it. The user-facing words
  // stay "Save" and "Saved messages"; only the code disambiguates.
  //
  // The distinction is the whole point of the feature. Forwarding into the
  // self-room duplicates content and strands it away from the conversation that
  // gave it meaning; a bookmark leaves it where it was said, and is how you get
  // back to it. It is also per-reader, so it says nothing to anyone else in the
  // room — unlike a pin, which is room state everybody sees.
  //
  // ── Why a table ────────────────────────────────────────────────────────────
  //
  // Everything the `pinnedMessages` comment above says applies, and one thing
  // more. A `savedBy` array on `messages` would be the O(messages × members)
  // fan-out the `roomMembers` comment rules out, AND every save would patch a
  // document `messages:list` reads — so one person quietly keeping something
  // for themselves would rebuild the transcript for every member of the room.
  // A cursor on the membership row (the `lastReadAt` trick) cannot help either:
  // a bookmark set is sparse and arbitrary, not a monotone watermark.
  //
  // `roomId` is denormalized exactly as `pinnedMessages` and `viewOnceViews`
  // denormalize it. Written server-side from `msg.roomId` and never taken from
  // the client, so a bookmark naming a room its message doesn't live in is not
  // representable. Every field is required, so no `undefined` reaches an index.
  messageBookmarks: defineTable({
    roomId: v.id("rooms"),
    messageId: v.id("messages"),
    // Whose bookmark. Named `userId` rather than `savedBy` so auth.ts's
    // `byUser` index helper applies verbatim, matching `pinnedMessages`.
    userId: v.id("users"),
    savedAt: v.number(),
  })
    // Four reads off one index, because Convex indexes are prefix-scannable:
    // this reader's bookmarks in this room (`roomId`+`userId`, the live query),
    // the idempotence probe and the unsave lookup (all three fields), the sweep
    // when this reader leaves the room (`roomId`+`userId` again), and
    // `wipeRoomCompletely`'s by-room sweep (`roomId` alone) — which is the same
    // one-index-range-instead-of-a-probe-per-message win that comment claims
    // for pins. `userId` sits ahead of `messageId` because no read ever asks
    // for a room's bookmarks across all readers.
    .index("by_room_user_message", ["roomId", "userId", "messageId"])
    // Message teardown: `removeMessageAndFanout` holds a messageId and no room
    // scope. Without this there is no way to find a dying message's bookmarks.
    .index("by_message", ["messageId"])
    // Account teardown. Not subsumed by `by_room_user_message` the way
    // `gameResults` subsumes its own — that index leads with `roomId`, so it
    // cannot answer "everything this user saved" without a full scan.
    .index("by_user", ["userId"]),

  // ── Interactive messages: polls, checklists and events ──────────────────────
  //
  // A message the room ANSWERS rather than reads. Three kinds today — a poll,
  // a checklist and an event with RSVPs — and they share this one table
  // because they are the same object with different words on it: a prompt, a
  // fixed set of choices, and a tally of who picked what.
  //
  // ── Why the definition is not on `messages` ────────────────────────────────
  //
  // It would fit: `latitude`/`longitude` live there, and a poll's question and
  // options are just as immutable as a pin's coordinates. But two of the three
  // kinds mutate their own definition after they are sent — a checklist grows
  // items, a poll gets closed — and `messages:list` is a live subscription that
  // hands every row it reads to every member of the room. Patching a message
  // document rebuilds the entire transcript on every device, which is the exact
  // cost the `pinnedMessages` comment above refuses for the same reason. One
  // person ticking "buy milk" would re-deliver a thousand messages to everyone.
  //
  // So the message row carries only `type` and `content` — and `content` is the
  // question, the checklist title or the event name, deliberately. That single
  // choice is what makes every existing denormalized copy of `content` correct
  // for free: the room card preview, the push body, `replyToPreview`, search and
  // the clipboard all already know what to do with a sentence. Nothing had to
  // learn about polls to render one in a chat list.
  //
  // ── Why the tallies are on this row and not counted on read ────────────────
  //
  // Counting responses inside the read query would make the tally exact by
  // construction, and it is what `messages:list` does for reactions. The
  // difference is fan-out: that query re-reads one small index range per
  // message, whereas a room-scoped read of interaction state would re-read
  // EVERY response of EVERY poll in the room on every single vote, on the box
  // `crons.ts:6-13` describes. Denormalizing moves that work to the writer,
  // where it happens once.
  //
  // The counters cannot drift, and it is not care that stops them: `respond`
  // does not increment anything. It writes the response row and then RECOUNTS
  // this row from the full response set, in the same transaction — so the
  // stored tally is a pure function of the rows it summarises, exactly like
  // `galleryBucket` is a pure function of the message it describes.
  messageInteractions: defineTable({
    // The message this is the body of. One row per message, always — a
    // `poll`-typed message with no row here renders as a bare prompt with no
    // choices, which is why `interactions:create` writes both in one
    // transaction and `removeMessageAndFanout` deletes both.
    messageId: v.id("messages"),
    // Denormalized exactly as `pinnedMessages` and `messageBookmarks`
    // denormalize it, and for the same two reasons: the live read is
    // "this room's interactions", and deriving the room from each message
    // would be a get per row. Written server-side from `msg.roomId`, never
    // taken from the client.
    roomId: v.id("rooms"),
    // "poll" | "checklist" | "event", mirroring `messages.type` on the row this
    // belongs to. Stored rather than read back off the message because every
    // query here ranges over THIS table and would otherwise need a `get` per
    // row to find out what it was looking at.
    kind: v.string(),
    // Who posed it — and ALWAYS the same person as `messages.userId` on the row
    // this belongs to. That is an invariant, not a coincidence, and it is
    // load-bearing: this row is only ever written in the same transaction as
    // its message and by the same caller (`interactions:create`, and
    // `forkInteraction` for a forward, which makes the forwarder the author of
    // their copy). It is what lets account teardown reach every interaction a
    // departing user authored through the message sweep it already does, so
    // this table needs no `by_creator` index — see `auth.ts`.
    //
    // A future path that wrote an interaction on somebody else's message would
    // break that sweep silently. There is deliberately no such path.
    createdBy: v.id("users"),
    createdAt: v.number(),

    // ── The choices, and their tally ─────────────────────────────────────────
    //
    // A poll's options, a checklist's items, or the three RSVP buttons. One
    // array for all three kinds because the read side is identical: walk it,
    // draw a row per entry, show `count` against it.
    //
    // [id] is a stable token, NOT an array index, and that is load-bearing for
    // exactly one kind: a checklist grows items after it is sent, and if ticks
    // were keyed by position then adding an item above a ticked one would move
    // the tick to a different task. Poll options and RSVP statuses cannot move,
    // so for them the distinction costs nothing and buys uniformity.
    //
    // [count] and [respondents] are the recounted tally described above.
    // `count` is the full number; `respondents` is the first
    // `RESPONDENT_PREVIEW_CAP` of them, in the order they answered, so a card
    // can show faces without a second query. The rest come from
    // `interactions:respondents` when somebody taps through — the same
    // count-inline / names-on-demand split `reactions` and its details sheet
    // already use.
    //
    // [respondents] is ABSENT, not empty, on an anonymous poll. Not written
    // rather than stripped on read, for the reason `posterStorageId` is not
    // written on an armed send: a read-path filter is a list somebody has to
    // remember to keep current, and the promise here ("nobody sees who voted")
    // is the entire feature. A name that never reaches this row cannot leak
    // from it. `interactionResponses` still records the voter — one vote per
    // person has to be enforceable, and a vote has to be retractable — but
    // nothing reads those rows out to a client for an anonymous poll.
    choices: v.array(
      v.object({
        id: v.string(),
        label: v.string(),
        count: v.number(),
        respondents: v.optional(
          v.array(
            v.object({
              userId: v.id("users"),
              // Snapshotted at response time, exactly as `messages.mentions`
              // snapshots a handle beside its id and for the same reason: a
              // card must render with no roster available — from the disk
              // cache, in history containing someone who has since left.
              name: v.string(),
              at: v.number(),
            })
          )
        ),
      })
    ),

    // How many distinct people have answered at all. Not derivable from the
    // per-choice counts once `multiple` is on, where one voter contributes to
    // several — and "12 voted" is what a poll footer says, not "19 votes".
    respondentCount: v.number(),

    // ── Poll ─────────────────────────────────────────────────────────────────
    //
    // All four absent on the other two kinds. Sparse rather than defaulted for
    // the reason the whole schema is: an absent field affords nothing to a
    // client that predates it.
    //
    // [multiple] lets one voter pick several options. [anonymous] is the
    // toggle described above, and is OFF by default — a poll in a group chat
    // is a conversation, and who said what is the interesting half of it.
    multiple: v.optional(v.boolean()),
    anonymous: v.optional(v.boolean()),
    // Quiz mode: exactly one option is right, and getting it wrong is the
    // point. Implies single-answer and no retraction — see `interactions.respond`.
    quiz: v.optional(v.boolean()),
    // Which choice is the correct one, and the optional note explaining it.
    //
    // WITHHELD on read from anyone who has not answered yet — see
    // `sanitizeInteraction`. Unlike `respondents` above this one cannot simply
    // be left unwritten, because the server has to know the answer to mark
    // anybody right; so this is the one field here that a read-path filter
    // genuinely guards, and the filter is written as a whitelist of what a
    // pre-answer viewer gets rather than a blacklist of what they don't.
    correctChoiceId: v.optional(v.string()),
    explanation: v.optional(v.string()),

    // ── Checklist ────────────────────────────────────────────────────────────
    //
    // Who, other than the author, may act on it. Both default ON — a checklist
    // one person can tick is a note, not a shared list — and both are enforced
    // server-side in `respond` and `addItem`, not merely hidden client-side.
    othersMayCheck: v.optional(v.boolean()),
    othersMayAdd: v.optional(v.boolean()),
    // The next item id to hand out, as a monotone counter.
    //
    // NOT `choices.length`, and the difference is a correctness bug rather
    // than a style choice: removing an item and adding another would reuse the
    // dead item's id, and any tick still holding that id — a delete that raced
    // a tick, a client replaying a queued one — would reappear on the new
    // task. A counter that only ever goes up cannot be made to point at two
    // different things. Absent on lists written before it existed, which is
    // safe to fall back to the length for: nothing could remove an item from
    // one of those, so no id has ever been retired.
    nextItemId: v.optional(v.number()),

    // ── Event ────────────────────────────────────────────────────────────────
    //
    // Unix ms, and [startsAt] is the only required half — an event with no end
    // is the ordinary case ("dinner at 8"), and inventing a duration for it
    // would put a wrong fact on the card. [place] is free text, deliberately
    // NOT coordinates: an address someone typed is a thing they chose to say,
    // whereas a pin is a location share, and this table is not the place to
    // grow a second one of those with none of `messages`' safeguards.
    startsAt: v.optional(v.number()),
    endsAt: v.optional(v.number()),
    place: v.optional(v.string()),

    // ── Closing ──────────────────────────────────────────────────────────────
    //
    // Set when the author or a room admin ends it. A closed interaction takes
    // no further responses and reveals a quiz's answer to everybody. One-way:
    // there is no reopen, because "the results are final" is the only thing
    // closing communicates and a reopen would make it a lie.
    closedAt: v.optional(v.number()),
    closedBy: v.optional(v.id("users")),
  })
    // The one-row-per-message lookup: every mutation here starts by resolving
    // the message it was handed, and `removeMessageAndFanout` holds a messageId
    // and no room scope.
    .index("by_message", ["messageId"])
    // The room's live window, and `wipeRoomCompletely`'s by-room sweep as a
    // prefix scan on `roomId` alone. Time-ordered because `listForRoom` takes
    // the newest N — see the comment there on why the window matches
    // `messages:list`'s own.
    //
    // No `by_creator`, unlike `reactions.by_user` and `pinnedMessages.by_user`.
    // Those exist because a reaction or a pin can sit on somebody else's
    // message, so account teardown cannot reach them through the sender sweep.
    // An interaction never can — see the invariant on `createdBy` above — so
    // the index would be write cost for a query nothing needs to make.
    .index("by_room_time", ["roomId", "createdAt"]),

  // One person's answer to one choice: a vote, a tick, or an RSVP.
  //
  // The authoritative record; `messageInteractions.choices[].count` is only its
  // summary. Rows exist here even for an anonymous poll, because one-vote-per-
  // person has to be enforceable and a vote has to be retractable — neither is
  // possible against a counter. What anonymity changes is that nothing reads
  // these rows out to a client: the tally is written without names, and
  // `interactions:respondents` refuses the poll outright.
  //
  // A row per (message, user, choice) rather than one row per (message, user)
  // holding an array, because `multiple` polls let one person pick several and
  // an array would make "add one vote" a read-modify-write of somebody's whole
  // ballot. Single-answer kinds enforce their own cardinality by deleting the
  // old row in the same transaction as the new one.
  interactionResponses: defineTable({
    messageId: v.id("messages"),
    // Denormalized for the account- and room-teardown sweeps, exactly as the
    // table above denormalizes it.
    roomId: v.id("rooms"),
    userId: v.id("users"),
    // Which choice — `messageInteractions.choices[].id`, and a string for all
    // three kinds so one index serves them: a poll option's ordinal, a
    // checklist item's stable id, or one of the three RSVP tokens.
    choiceId: v.string(),
    // Snapshotted beside the id, like `messages.mentions` and like the
    // `respondents` preview this feeds. A respondents sheet that resolved names
    // live would re-read a `users` row per voter inside a reactive query — the
    // precise mistake `messages:list`'s header warns about, where one person
    // going offline refires the query for everyone.
    userName: v.string(),
    createdAt: v.number(),
  })
    // Four reads off one index, because Convex indexes are prefix-scannable:
    // the recount (`messageId` alone, which is also the per-choice bucketing —
    // see below), this voter's existing ballot (`messageId`+`userId`), the
    // idempotence probe and the retract lookup (all three).
    //
    // There is deliberately NO `by_message_choice`. It looks like the right
    // index for "who picked option 2", but the recount in `respond` already
    // reads every response for the message in one prefix scan on this index —
    // so that read exists and is the real bound either way, and the
    // respondents sheet can bucket the same scan in JS. A second index would
    // add write amplification to the hottest table this feature has in
    // exchange for a scan the writer is already paying for.
    .index("by_message_user", ["messageId", "userId", "choiceId"])
    // "Everything I answered in this room", which is the per-viewer half of
    // the room's live state — and `wipeRoomCompletely`'s sweep as a prefix on
    // `roomId`. Scoping the live read to one reader's own rows is what keeps
    // one person voting out of every other member's read set; the tally
    // refires them, and nothing else does. Same trick as
    // `speakerColors.by_viewer_room_subject`.
    .index("by_room_user", ["roomId", "userId"])
    // Account teardown. Not subsumed by `by_room_user` — that leads with
    // `roomId`, so it cannot answer "everything this user answered".
    .index("by_user", ["userId"]),

  // One reader's manual colour choices for the people in a room.
  //
  // Per-speaker colours are normally DERIVED (see `SpeakerSlots` on the client):
  // a hash of the user id, de-collided in join order, needing no stored state at
  // all. This table exists only for the overrides — "make jun the teal one" —
  // and holds nothing for the overwhelming majority of readers and rooms.
  //
  // ITS OWN TABLE, deliberately, rather than a field on `roomMembers`. That row
  // looked like the natural home: it is already per-member, already per-room,
  // and already patched per-viewer by `markRoomRead`. But `rooms:getMembers`
  // reads EVERY membership row in the room, so a Convex subscription to it is
  // invalidated by a write to ANY of them — meaning one person picking a colour
  // would re-run the roster query, and re-deliver the whole roster, on every
  // other member's device. Here, `by_viewer_room_subject` scopes the live query
  // to one reader's own rows, so a write lands in nobody else's read set and
  // fans out to nobody.
  //
  // [slot] is an index into the palette, NOT a colour. Colours are conditioned
  // per theme (hue from the slot, saturation and lightness from the theme), so
  // a stored slot follows the reader across all thirteen themes and keeps
  // clearing its contrast floors in each. A stored ARGB would be a Cyberpunk
  // green pasted onto Risograph cream.
  speakerColors: defineTable({
    // WHOSE reading preference. Nobody else's client ever reads these rows —
    // an override is a fact about how one person wants to read a room, not
    // about the person it names, so there is no permission question and
    // nothing to reconcile between two members who disagree.
    viewerId: v.id("users"),
    roomId: v.id("rooms"),
    // Who the colour was pinned ON.
    subjectId: v.id("users"),
    // 0 .. kSpeakerSlotCount-1, validated in `speakerColors.setSlot`.
    slot: v.number(),
  })
    // Three reads off one index, the same prefix-scan trick `messageBookmarks`
    // documents: this reader's whole set (`viewerId` alone — the one live
    // subscription, held app-wide rather than per room), this reader's set in
    // one room, and the exact row for an upsert or a clear.
    .index("by_viewer_room_subject", ["viewerId", "roomId", "subjectId"])
    // Room teardown (`roomCleanup.wipeRoomContents`, every reader's rows), and
    // the half of a departure that the leaver's own sweep cannot see: the
    // overrides OTHER people set about them, which would otherwise pin a colour
    // on someone who is no longer in the room and quietly hold a palette slot
    // shut against whoever joins next.
    .index("by_room_subject", ["roomId", "subjectId"])
    // Account teardown. Not subsumed by the index above — that one leads with
    // `roomId`, so it cannot answer "every room where somebody pinned a colour
    // on this user" without a full scan.
    .index("by_subject", ["subjectId"]),

  // ── Feed board ─────────────────────────────────────────────────────────────
  //
  // ONE table for two features. A "highlight" (a photo worth showing, with an
  // optional caption) and a "point" (you saw a celebrity; you washed the car
  // and it rained) are the same object: media + words + who + when. The only
  // difference is whether it carries a `tag`.
  //
  // That collapse is load-bearing rather than tidy-minded. It means the
  // standings board in phase 4 needs no write path of its own — it is a
  // different READ of the rows the composer already writes — and it means
  // tagging a photo you just took is one tap rather than a second feature.
  moments: defineTable({
    userId: v.id("users"),
    // "YYYY-MM-DD" in the AUTHOR's local zone, computed client-side. Stored
    // rather than derived from createdAt because "which day was this" is a
    // question only the author's timezone can answer, and the server has no
    // idea what that is. Zero-padded so it sorts lexicographically, which is
    // what lets the indexes below range-scan it without a numeric twin.
    dayKey: v.string(),
    // Absent for a plain highlight. Set to a tag id ("fate" | "jinx" | "luck"
    // | "calledIt" | "npc") when the moment also scores.
    //
    // MUST stay UNSET rather than written as "none"/"" for untagged rows.
    // Convex has no sparse indexes and orders `undefined` before every string,
    // so a written sentinel would put every highlight inside the scanned
    // prefix of `by_user_tag` and turn a point-count into a full scan of that
    // user's history. `eq("tag", "jinx")` never enters an absent prefix.
    tag: v.optional(v.string()),
    caption: v.optional(v.string()),
    mediaStorageId: v.optional(v.id("_storage")),
    // Video poster frame. Android/iOS only — video_thumbnail has no web or
    // desktop implementation, so moments composed there keep the play glyph
    // permanently, exactly as `messages.posterStorageId` does.
    posterStorageId: v.optional(v.id("_storage")),
    mediaKind: v.optional(v.string()), // "image" | "video"
    createdAt: v.number(),
    // When this drops off friends' boards. The row and the blob both survive:
    // the author keeps it in their archive forever. So this is a LISTING rule,
    // not a deletion deadline, and deliberately not a `ctx.scheduler.runAt`.
    expiresAt: v.number(),

    // ── Denormalized author projection ─────────────────────────────────────
    // `feed:board` is a SUBSCRIBED query. If it did `ctx.db.get(m.userId)` to
    // render a name, the board would join the invalidation set of every users
    // row it touched — and presence writes land on those rows every 90s per
    // friend. The board would then re-fire, and re-render, continuously, for
    // everyone, forever. This is the exact storm class messages.ts documents.
    //
    // Cost of the copy: a renamed user's older moments keep the old name until
    // they post again. That is the right trade, and it is also how
    // `messages.senderName` already behaves.
    authorName: v.string(),
    authorUsername: v.string(),
    authorAvatarStorageId: v.optional(v.id("_storage")),

    // How many rows `momentComments` holds for this moment, replies included.
    // A counter rather than a count: the board renders a comment pill on every
    // card, and counting would mean one more indexed `.collect()` per moment
    // inside a subscribed query whose cost already scales with friends ×
    // moments. Written in the same transaction as the comment it counts, so it
    // cannot drift. Optional — every moment from before comments existed has
    // none, which reads as 0.
    commentCount: v.optional(v.number()),
  })
    // The author's own archive, newest first. Also the per-friend read the
    // board fans out over.
    .index("by_user_created", ["userId", "createdAt"])
    // "everything this friend posted today" — the board's hot path.
    .index("by_user_day", ["userId", "dayKey"])
    // Per-type point counts for one person. `tag` sits behind `userId`, so an
    // equality match is an exact three-part prefix and the absent-value
    // ordering above never costs a scan.
    .index("by_user_tag_day", ["userId", "tag", "dayKey"])
    // Account teardown (auth.ts purgeUser).
    .index("by_user", ["userId"])
    // Blob release: whether any other moment still points at these bytes.
    .index("by_media", ["mediaStorageId"]),

  // Who has already seen which moment — drives the unseen ring on the rail.
  //
  // Its own table rather than a `seenBy` array on the moment: an array would
  // make every viewer's first look a WRITE to the moment row, which the
  // subscribed board reads, so opening the rail would re-fire the board for
  // every friend. Same reasoning as `pinnedMessages` and `viewOnceViews`.
  momentViews: defineTable({
    momentId: v.id("moments"),
    viewerId: v.id("users"),
    viewedAt: v.number(),
  })
    .index("by_moment_viewer", ["momentId", "viewerId"])
    .index("by_moment", ["momentId"])
    // Account teardown.
    .index("by_viewer", ["viewerId"]),

  // Reactions on a moment. Mirrors `reactions` on messages exactly, including
  // the one-row-per-(moment,user,emoji) idempotency.
  momentReactions: defineTable({
    momentId: v.id("moments"),
    userId: v.id("users"),
    emoji: v.string(),
    createdAt: v.number(),
    // Denormalized at write time, same reason as `moments.authorName`: the
    // board is a subscribed query and must never read a `users` document, so
    // "who reacted" has to already be sitting on the row it's read from.
    // Optional because rows written before this field existed don't have it —
    // they just fall out of the reactor list until reacted again.
    userName: v.optional(v.string()),
    // The reactor's handle and face, denormalized for the same reason, so the
    // story can show WHO reacted (Instagram's avatar row) without the board
    // ever touching a `users` row. `userAvatarLevel` is their avatar setting
    // as of the reaction; `feed.momentView` applies it against the viewer's
    // friendships, which the board already holds.
    userUsername: v.optional(v.string()),
    userAvatarStorageId: v.optional(v.id("_storage")),
    userAvatarLevel: v.optional(v.string()),
  })
    .index("by_moment", ["momentId"])
    .index("by_moment_user", ["momentId", "userId"])
    // Account teardown.
    .index("by_user", ["userId"]),

  // A comment on a highlight, or a reply to one.
  //
  // Instagram's shape: ONE level of threading. A reply always hangs off a
  // top-level comment (`parentId` is that root, never another reply), and
  // replying to a reply keeps it in the same thread with `replyToName` saying
  // who it answers. Deeper trees read as a maze on a phone, and every
  // big-platform comment surface has converged on exactly this.
  //
  // Words, a sticker, or a GIF — never a photo. A photo comment would be a
  // second highlight posted onto somebody else's, outside their control; a
  // sticker or a GIF is a reaction with more to say. So there is no storage-id
  // column for the commenter to fill: the sticker blob is resolved from the
  // `stickers` row server-side (see `messages.expressionFieldsFor`), and a GIF
  // is a KLIPY URL that passed `isKlipyUrl`.
  momentComments: defineTable({
    momentId: v.id("moments"),
    userId: v.id("users"),
    // Denormalized at write time, as `momentReactions.userName` is.
    userName: v.string(),
    // The thread root this replies to. Absent on a top-level comment.
    parentId: v.optional(v.id("momentComments")),
    // Who a reply answers, when it answers a reply rather than the root —
    // rendered as a leading "@name". Denormalized for the same reason as
    // `userName`.
    replyToUserId: v.optional(v.id("users")),
    replyToName: v.optional(v.string()),
    text: v.optional(v.string()),
    // "gif" | "sticker" when the comment carries one. Absent for words alone.
    expressionKind: v.optional(v.string()),
    mediaSource: v.optional(v.string()), // "klipy" | "pack" | "personal"
    mediaUrl: v.optional(v.string()),
    mediaPreviewUrl: v.optional(v.string()),
    mediaRef: v.optional(v.string()),
    mediaWidth: v.optional(v.number()),
    mediaHeight: v.optional(v.number()),
    stickerId: v.optional(v.id("stickers")),
    stickerStorageId: v.optional(v.id("_storage")),
    stickerFormat: v.optional(v.string()),
    // The sticker's emoji, as alt text.
    alt: v.optional(v.string()),
    createdAt: v.number(),
  })
    // A moment's whole conversation, oldest first.
    .index("by_moment_created", ["momentId", "createdAt"])
    // A thread's replies, for cascading a root's delete.
    .index("by_parent", ["parentId"])
    // Account teardown.
    .index("by_user", ["userId"]),

  // Reactions on a comment. `momentReactions` again, one level down — and
  // carrying `momentId` so the comments query can read every reaction on a
  // moment's conversation in ONE indexed range instead of one per comment.
  momentCommentReactions: defineTable({
    commentId: v.id("momentComments"),
    momentId: v.id("moments"),
    userId: v.id("users"),
    userName: v.optional(v.string()),
    emoji: v.string(),
    createdAt: v.number(),
  })
    .index("by_moment", ["momentId"])
    .index("by_comment", ["commentId"])
    .index("by_comment_user", ["commentId", "userId"])
    // Account teardown.
    .index("by_user", ["userId"]),

  // One row per player per day of the daily puzzle.
  //
  // There is no companion `puzzleDays` table: the answer is derived from the
  // day key by a pure function (`puzzle.answerFor`), so there is nothing to
  // create, nothing to seed, and no race between the day's first two players.
  puzzleResults: defineTable({
    userId: v.id("users"),
    dayKey: v.string(),
    // Every guess so far, oldest first, each an array of SLOTS symbol indices.
    // Feedback is NOT stored — it is a pure function of (guess, answer) and
    // storing it would be a second source of truth that can disagree.
    guesses: v.array(v.array(v.number())),
    solved: v.boolean(),
    createdAt: v.number(),
    updatedAt: v.number(),
    // Set once the player can no longer act: solved, or out of guesses.
    finishedAt: v.optional(v.number()),
    // When the player told their friends about this result — the same gate,
    // for the same reason, as `gameResults.sharedAt` below: a fan-out to every
    // friend must be refused by the server the second time, not by a client a
    // reinstall away from forgetting it pressed the button.
    sharedAt: v.optional(v.number()),
  })
    .index("by_user_day", ["userId", "dayKey"])
    // Account teardown (auth.ts purgeUser).
    .index("by_user", ["userId"]),

  // One row per player per day per daily GAME — Queens, Tango, Zip, Mini
  // Sudoku. Same model as `puzzleResults` above and for the same reasons: the
  // board is a pure function of the day key (`convex/games/*.ts`), so there is
  // nothing to seed and no race between the day's first two players.
  //
  // Deliberately NOT folded into `puzzleResults`. That table stores a list of
  // guesses and is ranked by how many were needed; these are ranked by elapsed
  // time and store a finished grid. Sharing a row would mean half the columns
  // being optional and every reader re-deriving which game it is holding.
  //
  // One index, three uses: its prefixes serve [userId] for account teardown,
  // [userId, dayKey] for "everything I played today" (the whole hub in one
  // read), and the full triple for a single game's row.
  gameResults: defineTable({
    userId: v.id("users"),
    dayKey: v.string(),
    // "queens" | "tango" | "zip" | "sudoku". A string rather than a union so
    // adding next month's game is a deploy of one file, not a schema migration
    // over live rows — `games.ts` owns the list that is actually accepted.
    game: v.string(),
    // Server clock at the player's first move. The ceiling on a reported time:
    // see `submit` in games.ts for why the duration itself is client-reported.
    startedAt: v.number(),
    // How long the player says the board was actually in front of them. Absent
    // until they finish. Solved rows are ranked by this.
    durationMs: v.optional(v.number()),
    solved: v.boolean(),
    // Asked for the answer. Kept apart from `solved: false` because an
    // unfinished board is private and a surrender is a result — the standings
    // show it, the way an unsolved daily puzzle shows as X/6.
    gaveUp: v.boolean(),
    finishedAt: v.optional(v.number()),
    // Advisory, shown next to a result and never used for ranking. Sorting on
    // a number the client reports and the server cannot check would make the
    // leaderboard a claim rather than a race.
    hintsUsed: v.number(),
    mistakes: v.number(),
    // The board as they left it, so closing the app mid-game does not throw
    // the work away. Written on leaving the screen, not per move.
    progress: v.optional(v.array(v.number())),
    // The stopwatch, saved alongside `progress`. Without it a player who backs
    // out at four minutes and returns is handed a clock reading zero, which is
    // a better time than anyone who sat still and finished it.
    elapsedMs: v.optional(v.number()),
    // When the player pushed this result to their friends, via the "tell
    // friends" action on the result card. Absent until they do, and the whole
    // gate on doing it twice.
    //
    // Stored rather than tracked client-side because the client that would
    // remember is the one being defended against: the share is a fan-out to
    // every friend, and a button that survives a reinstall is a button that
    // notifies fifty people again. `games:shareResult` refuses a row that
    // already carries this.
    sharedAt: v.optional(v.number()),
  }).index("by_user_day_game", ["userId", "dayKey", "game"]),

  // One row per player per game, ALL TIME: their best, and how many times they
  // have solved it. Kept by `records.noteSolve` from `games.submit` and
  // `puzzle.guess`, and filled for history once by `records.backfill`.
  //
  // Denormalized on purpose. "Every friend's best Queens" computed from
  // `gameResults` is a scan of each friend's entire history — a year of four
  // games a day is ~1,500 rows per person, times two hundred friends, on every
  // open of a screen. Here it is one indexed read per person.
  gameRecords: defineTable({
    userId: v.id("users"),
    // One of the four dailies' ids (`games.GAMES`), or "code" for the symbol
    // puzzle. A string for the reason `gameResults.game` is one.
    game: v.string(),
    // Lower wins in both units: milliseconds for the timed boards, guesses
    // for the code.
    best: v.number(),
    // The day the best was set, and when — `achievedAt` is also what a
    // reaction is FOR (see `recordReactions`), so a new best starts clean.
    dayKey: v.string(),
    achievedAt: v.number(),
    // Every solve of this game, best or not. Surrenders do not count.
    solves: v.number(),
    // Consecutive days solved, ending on `lastSolvedDayKey`, and the longest
    // run ever. Optional only for rows written before streaks existed;
    // `records.backfill` fills them. A surrender is not a solve, so a day
    // given up breaks the run exactly as a day skipped does.
    streak: v.optional(v.number()),
    bestStreak: v.optional(v.number()),
    lastSolvedDayKey: v.optional(v.string()),
  })
    // Its [userId] prefix is both "everything this person holds" (the board,
    // account teardown) and, with the game, the upsert on every solve.
    .index("by_user_game", ["userId", "game"]),

  // A friend's reaction to somebody's all-time best. One per friend per record;
  // choosing another emoji replaces it.
  recordReactions: defineTable({
    recordId: v.id("gameRecords"),
    // The `gameRecords.achievedAt` this was a reaction TO. When the record is
    // beaten the row is swept, and a straggler that survived would be filtered
    // by this — cheering a time that no longer stands would be cheering the
    // wrong thing.
    achievedAt: v.number(),
    userId: v.id("users"),
    // Denormalized at write time, as `momentReactions.userName` is, so the
    // board never reads a `users` document per reactor.
    userName: v.optional(v.string()),
    emoji: v.string(),
    createdAt: v.number(),
  })
    // [recordId] prefix: everything on one record.
    .index("by_record_user", ["recordId", "userId"])
    // Account teardown of the reactor.
    .index("by_user", ["userId"]),

  // `pushReceipts` used to live here. It held a OneSignal notification id per
  // (user, message) so a delete-or-read could call DELETE /notifications/{id}
  // and cancel a push OneSignal had not yet handed to APNs/FCM. Talking to
  // Apple and Google directly means there is no such queue and no such API —
  // a push is accepted or it isn't. Its three jobs are now done by
  // apns-collapse-id / the Android notification tag / the Web Push Topic
  // header (a later push replaces the displayed one), by the sentAt-vs-
  // lastReadAt check in push.sendAlert (which skips the send rather than
  // racing to undo it), and by per-kind expiration.

  typingIndicators: defineTable({
    roomId: v.id("rooms"),
    userId: v.id("users"),
    updatedAt: v.number(),
    // Denormalized at write time (`typing:setTyping`), same reason
    // `messages.senderName`/`moments.authorName` are: `getTypingForUser` is a
    // GLOBAL subscription held for the whole signed-in session, so a
    // `ctx.db.get(userId)` here would subscribe it to every typist's full
    // `users` document — including `status`/`lastSeen`, patched by that
    // typist's presence heartbeat — and refire continuously for anyone
    // sharing a room with an active typist, regardless of what screen they're
    // on. Re-stamped every 2s while composing (the same cadence that patches
    // `updatedAt`), so it is at most ~2s stale — tighter than the 8s TTL that
    // already governs the whole feature. Optional rather than required: a row
    // written a moment before this field existed would otherwise fail schema
    // validation at deploy time instead of just aging out within its own
    // 2s/8s lifecycle like every other row.
    userName: v.optional(v.string()),
    avatarStorageId: v.optional(v.id("_storage")),
    // The raw `visibility.avatar` level, not a resolved boolean — so readers
    // can still run it through `visibility.ts`'s one real `canSee` check
    // instead of a second copy of that logic.
    avatarVisibility: v.optional(v.string()),
  })
    // No standalone `by_room` — `by_room_user` alone serves every
    // "typing indicators in this room" read as a prefix scan on `roomId`.
    .index("by_room_user", ["roomId", "userId"])
    // Account teardown clears every room this user was typing in.
    .index("by_user", ["userId"]),

  friendRequestMessages: defineTable({
    requestId: v.id("friendships"),
    userId: v.id("users"),
    content: v.string(),
    createdAt: v.number(),
  })
    .index("by_request", ["requestId"])
    .index("by_user", ["userId"]),

  // 1:1 voice/video calls. Peer-to-peer WebRTC; this table only tracks the
  // call session lifecycle. The actual SDP/ICE signaling rides on callSignals.
  calls: defineTable({
    callerId: v.id("users"),
    calleeId: v.id("users"),
    roomId: v.id("rooms"),
    type: v.string(),            // "audio" | "video"
    status: v.string(),          // "ringing" | "active" | "ended" | "rejected" | "missed" | "cancelled" | "failed"
    startedAt: v.number(),
    acceptedAt: v.optional(v.number()),
    endedAt: v.optional(v.number()),
    // Which callee device currently holds the active WebRTC connection.
    // Set when the call is accepted; updated on handoff. Sibling devices
    // watch this through `activeCallForUser` to render the global "Move
    // call here" pill (pill renders when this !== my deviceId).
    acceptingDeviceId: v.optional(v.string()),
    // Set by `heartbeat` while status is "active"; `gcStuckActive` treats a
    // stale value as an abandoned call (crash, dead battery, OS jetsam) that
    // neither side ever explicitly ended.
    lastHeartbeatAt: v.optional(v.number()),
    // Devices that reported their native call card (CallKit /
    // ConnectionService) for this call gone — `ackNativeDismissed`. The
    // grace-delayed `taken` push skips them (see `scheduleTakenPush`).
    dismissedDeviceIds: v.optional(v.array(v.string())),
    // When a callee device first reported its ringer up (`markRinging`):
    // the line between the caller's "calling" and "ringing". Unset while
    // the push is still on its way, or if it never landed anywhere.
    ringingAt: v.optional(v.number()),
  })
    .index("by_callee_status", ["calleeId", "status"])
    .index("by_caller_status", ["callerId", "status"])
    .index("by_status_started", ["status", "startedAt"])
    // gcStuckActive's sweep: unset lastHeartbeatAt sorts before every set
    // value, so `eq(status).lt(lastHeartbeatAt, cutoff)` yields exactly the
    // never-beat + stale-beat rows without scanning healthy calls.
    .index("by_status_heartbeat", ["status", "lastHeartbeatAt"])
    // Account teardown needs every call regardless of status; the pair above
    // is status-scoped.
    .index("by_caller", ["callerId"])
    .index("by_callee", ["calleeId"]),

  // Signaling messages between the two peers. Client subscribes by toUserId
  // and marks each delivered signal `consumed: true`. A cron cleans old rows.
  callSignals: defineTable({
    callId: v.id("calls"),
    fromUserId: v.id("users"),
    toUserId: v.id("users"),
    kind: v.string(),            // "invite" | "ringing" | "offer" | "answer" | "ice" | "ice-batch" | "state" | "bye" | "reject" | "cancel" | "taken" | "handoff-prepare" | "handoff-takeover" | "handoff-offer" | "handoff-answer" | "restart-request" | "restart-offer" | "restart-answer" | "renegotiate" | "reoffer" | "reanswer"
    payload: v.string(),         // JSON-encoded (SDP, ICE candidate, state object, …)
    createdAt: v.number(),
    consumed: v.boolean(),
    // When set, only the recipient device whose deviceId matches acts on
    // this signal — siblings of the same user ignore it. Used during
    // handoff to target a specific device. `null` keeps the original
    // broadcast-to-all-my-devices behavior.
    targetDeviceId: v.optional(v.string()),
    // The sender's deviceId. Informational — lets the recipient learn
    // which device of the peer is currently in the call so subsequent
    // signals can be device-targeted back.
    fromDeviceId: v.optional(v.string()),
  })
    .index("by_to_unconsumed", ["toUserId", "consumed", "createdAt"])
    .index("by_call", ["callId"])
    // GC sweep: consumed rows older than the retention window, without a
    // table scan (gcConsumedSignals in calls.ts).
    .index("by_consumed", ["consumed", "createdAt"])
    // Account teardown: signals this user sent, and consumed ones addressed to
    // them (which by_to_unconsumed can't reach without scanning both values).
    .index("by_from", ["fromUserId"])
    .index("by_to", ["toUserId"]),

  // ── group calls (mesh, one active call per room) ──
  // Each participant holds a P2P PeerConnection to every other joined
  // participant; the backend is signaling + roster only, no media.
  groupCalls: defineTable({
    roomId: v.id("rooms"),
    startedBy: v.id("users"),
    type: v.string(),   // "audio" | "video"
    status: v.string(), // "active" | "ended"
    startedAt: v.number(),
    endedAt: v.optional(v.number()),
    // Devices that reported their native call card (CallKit /
    // ConnectionService) for this call gone — `ackNativeDismissed`. The
    // grace-delayed `group_taken` push skips them (see `dismissRingers`),
    // exactly as `calls.dismissedDeviceIds` does for a 1:1 call.
    dismissedDeviceIds: v.optional(v.array(v.string())),
  })
    .index("by_room_status", ["roomId", "status"])
    .index("by_status", ["status", "startedAt"]),

  groupCallParticipants: defineTable({
    groupCallId: v.id("groupCalls"),
    userId: v.id("users"),
    // "invited" | "joined" | "left" | "declined" | "missed"
    // `missed` is terminal for a ring: set by `dismissRingers` the moment a
    // fan-out `group_taken` (call ended / ring timed out) is scheduled for
    // the row, so the next fan-out finds nobody and no device is ever sent
    // two dismissals for one card. A missed user can still `join` from the
    // room banner — `join` patches any existing row.
    status: v.string(),
    deviceId: v.optional(v.string()),
    invitedAt: v.number(),
    joinedAt: v.optional(v.number()),
    leftAt: v.optional(v.number()),
    // Heartbeat while joined — gcStaleGroupParticipants reaps rows whose
    // app died without calling leave(), so ghost calls can't linger.
    lastSeenAt: v.optional(v.number()),
  })
    .index("by_call", ["groupCallId"])
    .index("by_call_user", ["groupCallId", "userId"])
    .index("by_user_status", ["userId", "status"]),

  // Pair-addressed signaling inside a group call. Same delivery contract as
  // callSignals: subscribe by toUserId, consume after dispatch, GC sweeps.
  groupCallSignals: defineTable({
    groupCallId: v.id("groupCalls"),
    fromUserId: v.id("users"),
    toUserId: v.id("users"),
    kind: v.string(), // "offer" | "answer" | "ice-batch" | "state" | "restart-request" | "restart-offer" | "restart-answer" | "renegotiate" | "reoffer" | "reanswer"
    payload: v.string(),
    createdAt: v.number(),
    consumed: v.boolean(),
    fromDeviceId: v.optional(v.string()),
    targetDeviceId: v.optional(v.string()),
  })
    .index("by_to_unconsumed", ["toUserId", "consumed", "createdAt"])
    .index("by_call", ["groupCallId"])
    .index("by_consumed", ["consumed", "createdAt"]),

  // Cached push-provider auth tokens, one row per provider ("apns" | "fcm").
  // APNs REQUIRES the same provider JWT be reused for 20-60 minutes —
  // signing a fresh one per push trips the TooManyProviderTokenUpdates 429
  // rate limit, which then rejects EVERY push for the key (observed as
  // "calling randomly breaks entirely under rapid testing"). keyRef pins
  // the token to the signing key so a key rotation invalidates the cache.
  pushAuthTokens: defineTable({
    provider: v.string(),
    token: v.string(),
    keyRef: v.string(),
    issuedAt: v.number(),
  }).index("by_provider", ["provider"]),

  // Latest shipped build, one row per distribution channel. `channel` matches
  // ReleaseChannel.wire on the client ("ios-testflight", "android-apk", …) —
  // the same build goes to different channels at different times, so TestFlight
  // being on 1.3.30 says nothing about what the App Store is serving.
  //
  // `updateUrl` is server-owned on purpose. A shipped 1.3.29 has to be able to
  // send its user somewhere that didn't exist when it was compiled — the App
  // Store listing isn't live yet, and Play was not even the delivery mechanism
  // when the Android APKs were built. Setting this field fixes every
  // already-installed build retroactively; the client only falls back to a
  // compiled-in default when it's absent.
  //
  // That is exactly what retired the APK: the `android-apk` row now points at
  // the migration page instead of a download, and carries the explanation in
  // `notes`. No client release was needed to do it. See DEPLOY.md →
  // "Retired: the APK".
  appReleases: defineTable({
    channel: v.string(),
    // Display version only, no "+N" build suffix — matches what the client
    // reads from PackageInfo.version and compares.
    version: v.string(),
    // Below this, the client's update prompt loses its "Later" button. Leave
    // unset unless old clients are actually broken.
    minSupported: v.optional(v.string()),
    updateUrl: v.optional(v.string()),
    notes: v.optional(v.string()),
    publishedAt: v.number(),
  }).index("by_channel", ["channel"]),

  // Which of the two interchangeable deployments — the VPS or the home server —
  // clients should be talking to. Exactly one row.
  //
  // ───────── why a table and not an env var ─────────
  //
  // It started as `SERVE_FROM`, and env vars are a perfectly good way to
  // configure a backend and a terrible way to notify one: a Convex query
  // invalidates on the DATABASE reads it made, so a query over `process.env`
  // recomputes for nobody. Clients could only learn about a move by asking
  // again, which meant a relaunch.
  //
  // A row is reactive by construction. `serverDirectory:current` reads it, every
  // client subscribes to that query, and flipping the row moves everyone inside
  // a second with no relaunch and no polling. The env vars still work as a
  // fallback for a deployment that has never had this row written — see the
  // query — so the older `npx convex env set` workflow keeps functioning.
  //
  // `key` is a literal with one legal value; it exists so the single row can be
  // fetched by index rather than by scanning.
  serverDirectory: defineTable({
    key: v.literal("current"),
    serve: v.union(v.literal("primary"), v.literal("homeserver")),
    // Address overrides. Absent means "use the pair compiled into the client",
    // which is the normal case; they exist so a host can be renamed without a
    // client release.
    primaryUrl: v.optional(v.string()),
    homeserverUrl: v.optional(v.string()),
    // Shown verbatim in the client's info sheet — "migrating the VPS", "back by
    // Sunday". The one place the operator gets to explain themselves.
    note: v.optional(v.string()),
    updatedAt: v.number(),
  }).index("by_key", ["key"]),

  // Failed-attempt counters for the credential paths: auth.login,
  // auth.resetPasswordWithRecoveryKey, auth.setRecoveryKey. Before this table
  // every one of those accepted unlimited guesses.
  //
  // Hand-rolled rather than @convex-dev/rate-limiter because this deployment
  // has no convex.config.ts and installs no components.
  //
  // Keyed by the ACCOUNT under attack, not by the caller. Convex functions
  // see no client IP, and there are no sessions, so the account is the only
  // stable subject available — and it is the right one anyway, since it is
  // what we are protecting. The cost is that one user's failures throttle
  // that account everywhere, which is the intended behaviour.
  //
  // `lockedUntil` is a TIMESTAMP, never a flag. There is no email in this app
  // and therefore no unlock mail, and no admin console — so a lockout that
  // could not expire on its own would be a permanent account loss. Every
  // lockout here heals itself.
  // Bearer sessions. Added 2026-08-25 as the foundation for real remote
  // sign-out; see DEVICES.md for the staged rollout.
  //
  // Until enforcement lands this table is WRITTEN and never READ for
  // authorization: every function still takes `userId` as a plain argument, so
  // minting a row changes no behaviour and cannot lock anyone out. That is the
  // whole point of landing it separately — a half-enforced auth layer is worse
  // than an unenforced one, and this half is the one that is safe to ship
  // alone.
  //
  // `tokenHash`, never the token. The plaintext is returned to the client
  // exactly once, at mint time, and is not recoverable from here — so a leaked
  // database snapshot is not a set of working credentials. Same reasoning the
  // `users.passwordHash` column already follows.
  //
  // `deviceId` ties a session to a `userDevices` row so the Devices screen can
  // show one list rather than two, and so "remove this device" can grow into
  // "sign this device out" without the user learning a second concept.
  sessions: defineTable({
    userId: v.id("users"),
    tokenHash: v.string(),
    deviceId: v.string(),
    createdAt: v.number(),
    lastSeenAt: v.number(),
    // Set rather than deleted, so a revoked session can answer "this was
    // signed out" instead of "no such session" — the two are indistinguishable
    // to a client and one of them is a much better error message.
    revokedAt: v.optional(v.number()),
  })
    // The hot path once enforcement lands: one equality probe per request.
    .index("by_token_hash", ["tokenHash"])
    .index("by_user", ["userId"])
    .index("by_user_device", ["userId", "deviceId"])
    // Bounds the sweep below. Without a GC this table and its indexes grow
    // forever — a row per sign-in, kept after revocation — and this deployment
    // shares a 1 GB box with two others and already lives in swap. Every other
    // ephemeral table here (deviceLoginRequests, callSignals, pairingCodes)
    // has had a sweep from the start; this one shipped without and should not
    // have.
    .index("by_revoked_at", ["revokedAt"]),

  authAttempts: defineTable({
    key: v.string(), // "login:<userId>" | "recovery:<userId>"
    failures: v.number(),
    windowStartedAt: v.number(),
    lockedUntil: v.optional(v.number()),
    updatedAt: v.number(),
  })
    .index("by_key", ["key"])
    .index("by_updatedAt", ["updatedAt"]),

  // Apple / Google identities attached to an account.
  //
  // A separate table rather than columns on `users` because one account may
  // carry both providers, and because the hot lookup is provider+subject → user
  // (sign-in), which wants its own index.
  //
  // KEYED ON `subject`, NEVER ON EMAIL. Apple stops sending the email after the
  // first authorization and its private-relay addresses are not stable identity,
  // so email is stored for display only. Matching an inbound identity to an
  // existing account by email would also be an account-takeover path — two
  // providers can assert the same unverified address. Attaching a provider to an
  // existing account is therefore always an explicit, password-gated act
  // (`socialAuth.link`), never an automatic merge.
  //
  // Uniqueness on (provider, subject) is PROCEDURAL, like `users.by_username` —
  // Convex has no unique constraints. Same accepted race as `auth.signup`.
  socialIdentities: defineTable({
    provider: v.string(), // "apple" | "google"
    subject: v.string(), // the provider's `sub` claim
    userId: v.id("users"),
    email: v.optional(v.string()),
    isPrivateRelay: v.optional(v.boolean()),
    createdAt: v.number(),
    lastUsedAt: v.number(),
    // Apple only, and the reason `socialAuth.signIn` bothers to exchange the
    // authorization code at all: Apple requires that deleting an account also
    // revokes the token (TN3194), and revocation needs a refresh token.
    //
    // Apple returns a fresh authorization code on EVERY authorization, so this
    // is not strictly one-shot — but this app's sessions never expire, so a user
    // who signed in once may never present another code. Capture it the first
    // time or you may not get another chance for that user.
    appleRefreshToken: v.optional(v.string()),
    appleRefreshCheckedAt: v.optional(v.number()),
  })
    .index("by_provider_subject", ["provider", "subject"])
    .index("by_user", ["userId"]),
});
