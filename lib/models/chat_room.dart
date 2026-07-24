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

  final List<String> participantIds;

  bool get isEphemeral => type == RoomType.secret;
  bool get isPublic => !isPrivate;
  bool get isDm => name.startsWith('dm:');

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
        'participantIds': participantIds,
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
      participantIds: (j['participantIds'] as List?)?.map((e) => e.toString()).toList() ?? const [],
    );
  }
}
