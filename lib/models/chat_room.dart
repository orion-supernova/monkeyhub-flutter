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
    this.lastReadAt,
    this.lastDeliveredAt,
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
    this.mute = RoomMute.none,
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
  /// Prefers the server-computed [unreadCount], which — unlike the timestamp
  /// comparison — doesn't count the user's own sends. The timestamp fallback
  /// is kept for the deploy window where a client is talking to a backend that
  /// doesn't send `unreadCount` yet.
  ///
  /// Answers "does this room look unread", not "does it hold unread messages",
  /// which is why muting badges makes it false: hiding the pill but keeping
  /// the glowing dot and the bold name would silence the number and none of
  /// the noise around it.
  bool get hasUnread =>
      !badgesMuted &&
      (unreadCount > 0 ||
          (unreadCount == 0 &&
              lastMessageTime != null &&
              (lastReadAt == null || lastMessageTime!.isAfter(lastReadAt!))));

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
      lastDeliveredAt: j['lastDeliveredAt'] is num
          ? DateTime.fromMillisecondsSinceEpoch(
              (j['lastDeliveredAt'] as num).toInt())
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
      mute: RoomMute.fromJson(j),
      // Absent on every ordinary room and on any backend that predates the
      // field, which both mean the same thing: not a system room.
      systemRole: j['system'] as String?,
      participantIds: (j['participantIds'] as List?)?.map((e) => e.toString()).toList() ?? const [],
    );
  }
}
