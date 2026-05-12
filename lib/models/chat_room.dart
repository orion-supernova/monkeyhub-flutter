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
    this.passwordHash,
    this.hasPassword = false,
    this.type = RoomType.regular,
    this.messageLifetime,
    this.avatarStorageId,
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
  String? passwordHash; // not sent to clients per backend; kept nullable
  bool hasPassword;
  RoomType type;
  Duration? messageLifetime;
  String? avatarStorageId;
  final List<String> participantIds;

  bool get isEphemeral => type == RoomType.secret;
  bool get isPublic => !isPrivate;
  bool get isDm => name.startsWith('dm:');

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
        'hasPassword': hasPassword,
        'type': type.wire,
        if (messageLifetime != null) 'messageLifetime': messageLifetime!.inSeconds,
        if (avatarStorageId != null) 'avatarStorageId': avatarStorageId,
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
      hasPassword: (j['hasPassword'] ?? false) as bool,
      type: RoomTypeWire.parse(j['type'] as String?),
      messageLifetime: ml is num ? Duration(seconds: ml.toInt()) : null,
      avatarStorageId: j['avatarStorageId'] as String?,
      participantIds: (j['participantIds'] as List?)?.map((e) => e.toString()).toList() ?? const [],
    );
  }
}
