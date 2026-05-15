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
  }).index("by_username", ["username"]),

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
  })
    .index("by_user", ["userId"])
    .index("by_friend", ["friendId"])
    .index("by_pair", ["userId", "friendId"]),

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
    .index("by_last_activity", ["lastMessageTime"]),

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

  blocks: defineTable({
    userId: v.id("users"),         // who is doing the blocking
    blockedUserId: v.id("users"),  // who is blocked
    createdAt: v.number(),
  })
    .index("by_user", ["userId"])
    .index("by_pair", ["userId", "blockedUserId"]),

  reports: defineTable({
    reporterId: v.id("users"),
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
  })
    .index("by_room", ["roomId"])
    .index("by_room_time", ["roomId", "createdAt"])
    .index("by_replyTo", ["replyToId"]),

  reactions: defineTable({
    messageId: v.id("messages"),
    userId: v.id("users"),
    emoji: v.string(),
    createdAt: v.number(),
  })
    .index("by_message", ["messageId"])
    .index("by_message_user", ["messageId", "userId"]),

  typingIndicators: defineTable({
    roomId: v.id("rooms"),
    userId: v.id("users"),
    updatedAt: v.number(),
  })
    .index("by_room", ["roomId"])
    .index("by_room_user", ["roomId", "userId"]),

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
  })
    .index("by_callee_status", ["calleeId", "status"])
    .index("by_caller_status", ["callerId", "status"])
    .index("by_status_started", ["status", "startedAt"]),

  // Signaling messages between the two peers. Client subscribes by toUserId
  // and marks each delivered signal `consumed: true`. A cron cleans old rows.
  callSignals: defineTable({
    callId: v.id("calls"),
    fromUserId: v.id("users"),
    toUserId: v.id("users"),
    kind: v.string(),            // "offer" | "answer" | "ice" | "state" | "bye" | "reject" | "cancel"
    payload: v.string(),         // JSON-encoded (SDP, ICE candidate, state object, …)
    createdAt: v.number(),
    consumed: v.boolean(),
  })
    .index("by_to_unconsumed", ["toUserId", "consumed", "createdAt"])
    .index("by_call", ["callId"]),
});
