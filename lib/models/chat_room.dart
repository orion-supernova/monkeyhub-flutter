import 'enums.dart';
import 'room_mute.dart';

class ChatRoom {
  ChatRoom({
    required this.id,
    required this.name,
    required this.createdBy,
    required this.createdAt,
    required this.isPrivate,
    required this.memberCount,
    this.description,
    this.lastMessage,
    this.lastMessageTime,
    this.lastMessageSenderId,
    this.lastReadAt,
    this.lastDeliveredAt,
    this.passwordHash,
    this.hasPassword = false,
    this.type = RoomType.regular,
    this.messageLifetime,
    this.avatarStorageId,
    this.unreadCount = 0,
    this.unreadCountFromServer = false,
    this.unreadCapped = false,
    this.hasMention = false,
    this.isMember = false,
    this.isPinned = false,
    this.pinnedAt,
    this.isArchived = false,
    this.archivedAt,
    this.mute = RoomMute.none,
    this.systemRole,
    this.postingPolicy,
    List<String>? participantIds,
  }) : participantIds = participantIds ?? const [];

  final String id;
  String name;
  String? description;
  final String createdBy;
  final DateTime createdAt;
  bool isPrivate;
  int memberCount;
  String? lastMessage;
  DateTime? lastMessageTime;

  /// Who sent the message [lastMessage] previews (`rooms.lastMessageSenderId`).
  ///
  /// Null on a backend that predates the field and on a room whose newest
  /// write did too. The one question it answers is "is the newest message
  /// mine?" (see [isLastMessageFrom]): a message you sent from your phone
  /// moves `lastMessageTime` on your Mac exactly like an inbound one does.
  String? lastMessageSenderId;

  /// Whether [lastMessageSenderId] names [myId]. False when either is unknown,
  /// so an old backend keeps today's behaviour.
  bool isLastMessageFrom(String? myId) =>
      myId != null && myId.isNotEmpty && lastMessageSenderId == myId;

  /// This user's own read cursor for the room (ms since epoch, from
  /// roomMembers.lastReadAt). Null until the user has ever read the room.
  DateTime? lastReadAt;

  /// This user's own DELIVERY cursor for the room (roomMembers.lastDeliveredAt)
  /// — how far this account's devices have confirmed they hold the room's
  /// traffic, whether or not anyone looked at it.
  ///
  /// Not rendered anywhere. It is here so the repository can tell which rooms
  /// it has already reported and stay quiet about them; see
  /// `ChatRepository._reportDelivery`. Null on a room this account has never
  /// confirmed, and on every room read back from a cache written before the
  /// field existed.
  DateTime? lastDeliveredAt;
  String? passwordHash; // not sent to clients per backend; kept nullable
  bool hasPassword;
  RoomType type;
  Duration? messageLifetime;
  String? avatarStorageId;

  /// Number of messages in this room newer than [lastReadAt] and not sent by
  /// this user, computed server-side and capped at 99 (see backend
  /// `badges.UNREAD_CAP`). [unreadCapped] is true when the real number is
  /// higher, so the UI can render "99+".
  int unreadCount;
  bool unreadCapped;

  /// Whether [unreadCount] is the server's answer rather than the constructor
  /// default. Set by [fromJson] when the payload carries `unreadCount` (every
  /// backend since the field shipped, and every cached room, since [toJson]
  /// always writes it). It is what lets [hasUnread] take a 0 at its word.
  final bool unreadCountFromServer;

  /// Whether any of those unread messages named this user with an `@` (or
  /// addressed the whole room with `@everyone`).
  ///
  /// The room list draws this differently from an ordinary unread count: a
  /// number says "there is traffic", this says "some of it is yours". Computed
  /// server-side from rows the unread scan already had in hand, so it is free —
  /// and, like the count, it only sees the first 99 unread messages.
  bool hasMention;

  final List<String> participantIds;

  /// Whether the viewer is already a member. Only `rooms:listPublic` fills this
  /// in — every other room source is *by definition* a list of rooms you're in,
  /// so it stays false there and callers rely on
  /// [ChatRepository.isMemberOf] instead. Exists so Discover can tell the two
  /// apart during the cold-start window before the room list has hydrated.
  final bool isMember;

  /// This viewer's own chat-list organization — per-membership state, not a
  /// property of the room itself (roomMembers.isPinned/isArchived).
  bool isPinned;
  DateTime? pinnedAt;
  bool isArchived;
  DateTime? archivedAt;

  /// What this viewer has silenced about the room, and until when
  /// (roomMembers.muteNotifications / .muteBadges / .mutedUntil).
  ///
  /// Per-membership like the four fields above it, and carried RAW rather than
  /// pre-resolved — see [RoomMute] for why a boolean off the wire would have a
  /// shelf life and a deadline doesn't. Everything that draws a count goes
  /// through [visibleUnreadCount] / [hasUnread] rather than reading this
  /// directly, so the "is it still muted?" comparison happens in one place.
  RoomMute mute;

  /// Set only on rooms the APP owns rather than people — the maintainer's
  /// `MonkeyHub Logs` feed today, a support or announcements channel later.
  /// The value names WHICH fixture (`rooms.system` server-side, see
  /// `backend/convex/systemAccount.ts`); null on every ordinary room.
  ///
  /// Never inspected directly by UI code. It is the key into the capability
  /// table in `room_capabilities.dart`, which is what decides whether a room
  /// gets a call button, a member list or a way to end it.
  final String? systemRole;

  /// What members may post here: the NAME of a preset (`rooms.postingPolicy`
  /// server-side, `"open"` | `"readOnly"` | `"agent"`). Null on every ordinary
  /// room and on any backend that predates the field.
  ///
  /// Like [systemRole], never inspected directly by UI code: it is resolved by
  /// `roomPostingPolicyOf` in `room_posting_policy.dart` and reaches widgets as
  /// `RoomCapabilities.posting`.
  final String? postingPolicy;

  bool get isEphemeral => type == RoomType.secret;

  /// Whether a message posted here goes away on its own: a secret room, or
  /// any room with a message lifetime. Nothing that has to outlive its card
  /// (a game) can start in one.
  bool get messagesExpire =>
      isEphemeral || (messageLifetime != null && messageLifetime! > Duration.zero);
  bool get isPublic => !isPrivate;
  bool get isDm => name.startsWith('dm:');

  /// The always-pinned, single-member Saved Messages room: `dm:self:<userId>`.
  /// A DM by the [isDm] test above, but every entry in [participantIds] is
  /// the viewer, so [otherParticipantId] correctly resolves to null for it.
  bool get isSavedMessages => name.startsWith('dm:self:');

  /// True for a room stamped with a [systemRole] — an app fixture, not a
  /// conversation. See [systemRole].
  bool get isSystemRoom => systemRole != null && systemRole!.isNotEmpty;

  /// A real group: not a DM, not Saved Messages, not a room the app owns.
  ///
  /// The one place "does this room have admins and members" is decided on the
  /// client. Mirrors `roomAdmin.isGroupRoom` server-side, and exists so screens
  /// can answer that question from the room they already have rather than
  /// waiting on `roomAdmin:myPermissions` — a permission query in flight must
  /// not be the reason a control is drawn.
  bool get isGroupChat => !isDm && !isSystemRoom;

  // ───────────── mute, resolved against the wall clock ─────────────
  //
  // Four getters rather than four `room.mute.silences...(DateTime.now())` call
  // sites, so the app can never end up with two widgets that disagree about
  // whether the same room is muted because one of them wrote the comparison
  // itself. [RoomMute] is where the arithmetic lives and where it is tested;
  // this is just the app's `now`.

  /// Whether anything about this room is currently silenced.
  bool get isMuted => mute.isLiveAt(DateTime.now());

  /// Whether pushes from this room are currently silenced.
  bool get notificationsMuted => mute.silencesNotificationsAt(DateTime.now());

  /// Whether this room is currently kept out of every count.
  bool get badgesMuted => mute.silencesBadgesAt(DateTime.now());

  /// The unread count as far as anything on screen is concerned.
  ///
  /// Zero for a badge-muted room even though [unreadCount] is the true figure
  /// the server computed. Both are wanted: the room info screen can still say
  /// how much is waiting in a room you've silenced, while every pill, dot and
  /// aggregate reads this one and goes quiet.
  int get visibleUnreadCount => badgesMuted ? 0 : unreadCount;

  /// True when the room has a message newer than this user's read cursor.
  ///
  /// The server-computed [unreadCount] decides whenever the server sent one,
  /// zero included. It never counts the user's own sends, which the timestamp
  /// comparison below cannot tell apart: sending from another device moves
  /// `lastMessageTime` past `lastReadAt` (only reading moves the cursor), so
  /// the fallback used to light up a room whose newest message was your own.
  ///
  /// The timestamp comparison is left for a room built without a server count
  /// (a backend that predates it), and even then not for a room whose newest
  /// message is known to be from someone who has read it — see
  /// [isLastMessageFrom], which the caller with a user id applies.
  ///
  /// Answers "does this room look unread", not "does it hold unread messages",
  /// which is why muting badges makes it false: hiding the pill but keeping
  /// the glowing dot and the bold name would silence the number and none of
  /// the noise around it.
  bool get hasUnread {
    if (badgesMuted) return false;
    if (unreadCount > 0) return true;
    if (unreadCountFromServer) return false;
    final t = lastMessageTime;
    if (t == null) return false;
    final read = lastReadAt;
    return read == null || t.isAfter(read);
  }

  /// [hasMention], with the same badge-mute suppression as [hasUnread]. An `@`
  /// marker is a louder unread count, so it cannot outlive one.
  bool get hasVisibleMention => hasMention && !badgesMuted;

  /// Badge text for the room list — "99+" once the server-side cap is hit.
  String get unreadLabel => unreadCapped ? '99+' : '$visibleUnreadCount';

  /// For DM rooms, returns the "other" participant id (the one that's not me).
  String? otherParticipantId(String myId) {
    if (!isDm) return null;
    for (final p in participantIds) {
      if (p != myId) return p;
    }
    return null;
  }

  Map<String, dynamic> toJson() => {
        '_id': id,
        'name': name,
        if (description != null) 'description': description,
        'createdBy': createdBy,
        'createdAt': createdAt.millisecondsSinceEpoch,
        'isPrivate': isPrivate,
        'memberCount': memberCount,
        if (lastMessage != null) 'lastMessage': lastMessage,
        if (lastMessageTime != null) 'lastMessageTime': lastMessageTime!.millisecondsSinceEpoch,
        if (lastMessageSenderId != null)
          'lastMessageSenderId': lastMessageSenderId,
        if (lastReadAt != null) 'lastReadAt': lastReadAt!.millisecondsSinceEpoch,
        if (lastDeliveredAt != null)
          'lastDeliveredAt': lastDeliveredAt!.millisecondsSinceEpoch,
        'hasPassword': hasPassword,
        'type': type.wire,
        if (messageLifetime != null) 'messageLifetime': messageLifetime!.inSeconds,
        if (avatarStorageId != null) 'avatarStorageId': avatarStorageId,
        'unreadCount': unreadCount,
        'unreadCapped': unreadCapped,
        if (hasMention) 'hasMention': true,
        'participantIds': participantIds,
        if (isPinned) 'isPinned': true,
        if (pinnedAt != null) 'pinnedAt': pinnedAt!.millisecondsSinceEpoch,
        if (isArchived) 'isArchived': true,
        if (archivedAt != null) 'archivedAt': archivedAt!.millisecondsSinceEpoch,
        ...mute.toJson(),
        if (systemRole != null) 'system': systemRole,
        if (postingPolicy != null) 'postingPolicy': postingPolicy,
      };

  factory ChatRoom.fromJson(Map<String, dynamic> j) {
    final ml = j['messageLifetime'];
    return ChatRoom(
      id: (j['_id'] ?? j['id']).toString(),
      name: (j['name'] ?? '') as String,
      description: j['description'] as String?,
      createdBy: (j['createdBy'] ?? '').toString(),
      createdAt: DateTime.fromMillisecondsSinceEpoch((j['createdAt'] as num).toInt()),
      isPrivate: (j['isPrivate'] ?? false) as bool,
      memberCount: ((j['memberCount'] ?? 0) as num).toInt(),
      lastMessage: j['lastMessage'] as String?,
      lastMessageTime: j['lastMessageTime'] is num
          ? DateTime.fromMillisecondsSinceEpoch((j['lastMessageTime'] as num).toInt())
          : null,
      // Parsed defensively: an `Id<"users">` arrives as a string, and anything
      // else (absent, null, a shape this build never heard of) means unknown.
      lastMessageSenderId: j['lastMessageSenderId'] is String &&
              (j['lastMessageSenderId'] as String).isNotEmpty
          ? j['lastMessageSenderId'] as String
          : null,
      lastReadAt: j['lastReadAt'] is num
          ? DateTime.fromMillisecondsSinceEpoch((j['lastReadAt'] as num).toInt())
          : null,
      lastDeliveredAt: j['lastDeliveredAt'] is num
          ? DateTime.fromMillisecondsSinceEpoch(
              (j['lastDeliveredAt'] as num).toInt())
          : null,
      hasPassword: (j['hasPassword'] ?? false) as bool,
      type: RoomTypeWire.parse(j['type'] as String?),
      messageLifetime: ml is num ? Duration(seconds: ml.toInt()) : null,
      avatarStorageId: j['avatarStorageId'] as String?,
      unreadCount: ((j['unreadCount'] ?? 0) as num).toInt(),
      unreadCountFromServer: j['unreadCount'] is num,
      unreadCapped: (j['unreadCapped'] ?? false) as bool,
      hasMention: (j['hasMention'] ?? false) as bool,
      isMember: (j['isMember'] ?? false) as bool,
      isPinned: (j['isPinned'] ?? false) as bool,
      pinnedAt: j['pinnedAt'] is num
          ? DateTime.fromMillisecondsSinceEpoch((j['pinnedAt'] as num).toInt())
          : null,
      isArchived: (j['isArchived'] ?? false) as bool,
      archivedAt: j['archivedAt'] is num
          ? DateTime.fromMillisecondsSinceEpoch((j['archivedAt'] as num).toInt())
          : null,
      mute: RoomMute.fromJson(j),
      // Absent on every ordinary room and on any backend that predates the
      // field, which both mean the same thing: not a system room.
      systemRole: j['system'] as String?,
      // Absent means "decide from the room's kind" — see `roomPostingPolicyOf`.
      postingPolicy: j['postingPolicy'] as String?,
      participantIds: (j['participantIds'] as List?)?.map((e) => e.toString()).toList() ?? const [],
    );
  }
}
