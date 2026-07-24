import { defineSchema, defineTable } from "convex/server";
import { v } from "convex/values";

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
    deviceTokens: v.optional(v.array(v.string())), // legacy field — OneSignal manages tokens now
    // PushKit VoIP token (iOS) — separate from the regular APNs/OneSignal
    // token. Used to wake the app for CallKit ringing when killed.
    voipToken: v.optional(v.string()),
    // FCM token (Android) — used to send data-only high-priority pushes that
    // wake a killed app for the native ConnectionService ringer.
    fcmToken: v.optional(v.string()),
    // Per-field visibility — each value is "public" | "friends" | "nobody".
    // username + name are always public since they're identity. New accounts
    // and missing keys default to "nobody" on the client; this object stores
    // exactly what the user has set, verbatim.
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
      })
    ),
  })
    .index("by_username", ["username"])
    // Presence staleness sweep (users.sweepStalePresence) ranges over lastSeen
    // to find clients that stopped heartbeating. See presence.ts.
    .index("by_lastSeen", ["lastSeen"]),

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
    voipToken: v.optional(v.string()),       // iOS PushKit
    // APNs environment the voipToken was minted under. Debug/dev builds
    // produce sandbox tokens, distribution (TestFlight/App Store) builds
    // produce production tokens; the two are NOT interchangeable. Stored
    // per-device so one deployment can ring both. Missing → fall back to
    // the APNS_SANDBOX env default.
    apnsEnv: v.optional(
      v.union(v.literal("sandbox"), v.literal("production")),
    ),
    fcmToken: v.optional(v.string()),        // Android FCM
    // Human-readable label shown in the "Move call here" pill. Captured
    // from `UIDevice.current.name` / `Host.current().localizedName` /
    // `Settings.Global.DEVICE_NAME` etc. at login. Optional — clients
    // fall back to a friendly platform name when missing.
    deviceName: v.optional(v.string()),
    lastSeenAt: v.number(),
    createdAt: v.number(),
  })
    .index("by_user", ["userId"])
    .index("by_user_device", ["userId", "deviceId"]),

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
  })
    .index("by_name", ["name"])
    .index("by_last_activity", ["lastMessageTime"])
    // Discover lists public rooms only.
    .index("by_visibility", ["isPrivate"]),

  roomMembers: defineTable({
    roomId: v.id("rooms"),
    userId: v.id("users"),
    joinedAt: v.number(),
    role: v.string(), // "owner" | "member"
    // ms since epoch — last time this user "read" the room. Used to compute
    // read receipts: a message is "seen by X" when roomMembers[room,X].lastReadAt >= message.createdAt.
    lastReadAt: v.optional(v.number()),
  })
    .index("by_room", ["roomId"])
    .index("by_user", ["userId"])
    .index("by_room_user", ["roomId", "userId"]),

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
    .index("by_target", ["targetType", "targetId"]),

  messages: defineTable({
    roomId: v.id("rooms"),
    userId: v.id("users"),
    content: v.string(),
    createdAt: v.number(),
    edited: v.optional(v.boolean()),
    // New fields
    type: v.optional(v.string()),            // "text" | "image" | "video" | "audio" | "url" | "system"
    mediaStorageId: v.optional(v.id("_storage")),
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
      })
    ),
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
  })
    .index("by_room", ["roomId"])
    .index("by_room_time", ["roomId", "createdAt"])
    .index("by_replyTo", ["replyToId"])
    .index("by_root_time", ["rootId", "createdAt"])
    // Account teardown walks every message a user ever sent.
    .index("by_user", ["userId"]),

  reactions: defineTable({
    messageId: v.id("messages"),
    userId: v.id("users"),
    emoji: v.string(),
    createdAt: v.number(),
  })
    .index("by_message", ["messageId"])
    .index("by_message_user", ["messageId", "userId"])
    // Account teardown walks every reaction a user ever left, including those
    // on messages that survive them.
    .index("by_user", ["userId"]),

  // One row per (recipient, message) push OneSignal accepted.
  //
  // Exists so deleting a message can call DELETE /notifications/{id} while the
  // push is still queued — that endpoint cancels undelivered notifications
  // only, it cannot pull one off a device. Removing an *already delivered*
  // notification is the client's job, driven by the silent dismiss push, and
  // needs no lookup here because the notification's identifier is just the
  // messageId (sent as collapse_id).
  //
  // Deliberately NOT a field on roomMembers: that table is read by three hot
  // reactive queries (listUserRooms / getReadState / getMemberIds), and
  // writing to it on every send would re-fire all of them for every member —
  // the subscription-storm class already documented in messages.ts.
  pushReceipts: defineTable({
    userId: v.id("users"),
    roomId: v.id("rooms"),
    // Dangles once the message is deleted. Only ever compared against, never
    // ctx.db.get()'d, so a stale id is harmless.
    messageId: v.id("messages"),
    onesignalId: v.string(),
    sentAt: v.number(),
  })
    .index("by_message", ["messageId"])
    // Also serves ["userId"] as a prefix, which is what account teardown walks.
    .index("by_user_room", ["userId", "roomId"])
    .index("by_room", ["roomId"])
    .index("by_sent", ["sentAt"]),

  typingIndicators: defineTable({
    roomId: v.id("rooms"),
    userId: v.id("users"),
    updatedAt: v.number(),
  })
    .index("by_room", ["roomId"])
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
  })
    .index("by_callee_status", ["calleeId", "status"])
    .index("by_caller_status", ["callerId", "status"])
    .index("by_status_started", ["status", "startedAt"])
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
    kind: v.string(),            // "invite" | "offer" | "answer" | "ice" | "state" | "bye" | "reject" | "cancel" | "taken" | "handoff-prepare" | "handoff-takeover" | "handoff-offer" | "handoff-answer"
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
  // send its user somewhere that didn't exist when it was compiled: the App
  // Store and Play listings aren't live yet, and the hosted APK's filename
  // changes every release. Setting this field fixes every already-installed
  // build retroactively; the client only falls back to a compiled-in default
  // when it's absent.
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
});
