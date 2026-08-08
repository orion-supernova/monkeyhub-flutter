import 'enums.dart';

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
    this.lastReadAt,
    this.passwordHash,
    this.hasPassword = false,
    this.type = RoomType.regular,
    this.messageLifetime,
    this.avatarStorageId,
    this.unreadCount = 0,
    this.unreadCapped = false,
    this.hasMention = false,
    this.isMember = false,
    this.isPinned = false,
    this.pinnedAt,
    this.isArchived = false,
    this.archivedAt,
    this.systemRole,
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
  /// This user's own read cursor for the room (ms since epoch, from
  /// roomMembers.lastReadAt). Null until the user has ever read the room.
  DateTime? lastReadAt;
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

  /// Set only on rooms the APP owns rather than people — the maintainer's
  /// `MonkeyHub Logs` feed today, a support or announcements channel later.
  /// The value names WHICH fixture (`rooms.system` server-side, see
  /// `backend/convex/systemAccount.ts`); null on every ordinary room.
  ///
  /// Never inspected directly by UI code. It is the key into the capability
  /// table in `room_capabilities.dart`, which is what decides whether a room
  /// gets a call button, a member list or a way to end it.
  final String? systemRole;

  bool get isEphemeral => type == RoomType.secret;
  bool get isPublic => !isPrivate;
  bool get isDm => name.startsWith('dm:');

  /// The always-pinned, single-member Saved Messages room: `dm:self:<userId>`.
  /// A DM by the [isDm] test above, but every entry in [participantIds] is
  /// the viewer, so [otherParticipantId] correctly resolves to null for it.
  bool get isSavedMessages => name.startsWith('dm:self:');

  /// True for a room stamped with a [systemRole] — an app fixture, not a
  /// conversation. See [systemRole].
  bool get isSystemRoom => systemRole != null && systemRole!.isNotEmpty;

  /// True when the room has a message newer than this user's read cursor.
  ///
  /// Prefers the server-computed [unreadCount], which — unlike the timestamp
  /// comparison — doesn't count the user's own sends. The timestamp fallback
  /// is kept for the deploy window where a client is talking to a backend that
  /// doesn't send `unreadCount` yet.
  bool get hasUnread =>
      unreadCount > 0 ||
      (unreadCount == 0 &&
          lastMessageTime != null &&
          (lastReadAt == null || lastMessageTime!.isAfter(lastReadAt!)));

  /// Badge text for the room list — "99+" once the server-side cap is hit.
  String get unreadLabel => unreadCapped ? '99+' : '$unreadCount';

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
        if (lastReadAt != null) 'lastReadAt': lastReadAt!.millisecondsSinceEpoch,
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
        if (systemRole != null) 'system': systemRole,
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
      lastReadAt: j['lastReadAt'] is num
          ? DateTime.fromMillisecondsSinceEpoch((j['lastReadAt'] as num).toInt())
          : null,
      hasPassword: (j['hasPassword'] ?? false) as bool,
      type: RoomTypeWire.parse(j['type'] as String?),
      messageLifetime: ml is num ? Duration(seconds: ml.toInt()) : null,
      avatarStorageId: j['avatarStorageId'] as String?,
      unreadCount: ((j['unreadCount'] ?? 0) as num).toInt(),
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
      // Absent on every ordinary room and on any backend that predates the
      // field, which both mean the same thing: not a system room.
      systemRole: j['system'] as String?,
      participantIds: (j['participantIds'] as List?)?.map((e) => e.toString()).toList() ?? const [],
    );
  }
}
