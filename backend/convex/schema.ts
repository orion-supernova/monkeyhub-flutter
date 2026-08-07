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
    .index("by_target", ["targetType", "targetId"])
    // Retention sweep only. Reports used to be kept forever, which is a weak
    // answer under GDPR Art. 13(2)(a) and is not one the amended COPPA Rule
    // permits at all for a service children use — it requires a published
    // retention policy and forbids holding children's data indefinitely.
    // The published period is 24 months; see users.gcExpiredReports.
    .index("by_createdAt", ["createdAt"]),

  messages: defineTable({
    roomId: v.id("rooms"),
    userId: v.id("users"),
    content: v.string(),
    createdAt: v.number(),
    edited: v.optional(v.boolean()),
    // New fields
    type: v.optional(v.string()),            // "text" | "image" | "video" | "audio" | "file" | "url" | "system"
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

    // Whether `content` contains at least one URL, decided by the server at
    // send time (see `LINK_PATTERN` in messages.ts) so the LINKS tab can range
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
    // cold boot off the disk cache. `username` is immutable — `users:updateProfile`
    // patches `name` and `email` only — so unlike a display-name snapshot this
    // one can never drift from the truth.
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
  })
    .index("by_room", ["roomId"])
    .index("by_room_time", ["roomId", "createdAt"])
    // The dedupe lookup. Scoped by sender as well as room so a client can only
    // ever collide with — or discover — its own keys.
    .index("by_room_user_client", ["roomId", "userId", "clientId"])
    .index("by_replyTo", ["replyToId"])
    .index("by_root_time", ["rootId", "createdAt"])
    // Account teardown walks every message a user ever sent.
    .index("by_user", ["userId"])
    // The expired-view-once sweep. `viewOnceLive` MUST lead: Convex has no
    // sparse indexes and orders `undefined` before every number, so a lone
    // `q.lt("viewOnceDeadline", now)` would range-scan every message in the
    // deployment — precisely the >1s mutation crons.ts warns about. With the
    // boolean in front the scan is `q.eq("viewOnceLive", true).lt(...)`, which
    // touches only armed photos whose file is still there.
    .index("by_viewOnce_live_deadline", ["viewOnceLive", "viewOnceDeadline"])
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
  })
    .index("by_message", ["messageId"])
    .index("by_message_user", ["messageId", "userId"])
    // Account teardown walks every reaction a user ever left, including those
    // on messages that survive them.
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
  })
    .index("by_moment", ["momentId"])
    .index("by_moment_user", ["momentId", "userId"])
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
  }).index("by_user_day_game", ["userId", "dayKey", "game"]),

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
    // Set by `heartbeat` while status is "active"; `gcStuckActive` treats a
    // stale value as an abandoned call (crash, dead battery, OS jetsam) that
    // neither side ever explicitly ended.
    lastHeartbeatAt: v.optional(v.number()),
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
    kind: v.string(),            // "invite" | "offer" | "answer" | "ice" | "ice-batch" | "state" | "bye" | "reject" | "cancel" | "taken" | "handoff-prepare" | "handoff-takeover" | "handoff-offer" | "handoff-answer" | "restart-request" | "restart-offer" | "restart-answer"
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
  })
    .index("by_room_status", ["roomId", "status"])
    .index("by_status", ["status", "startedAt"]),

  groupCallParticipants: defineTable({
    groupCallId: v.id("groupCalls"),
    userId: v.id("users"),
    status: v.string(), // "invited" | "joined" | "left" | "declined"
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
    kind: v.string(), // "offer" | "answer" | "ice-batch" | "state" | "restart-request" | "restart-offer" | "restart-answer"
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
