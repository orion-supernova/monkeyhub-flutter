import 'package:flutter/widgets.dart';
import 'enums.dart';

class ChatUser {
  ChatUser({
    required this.id,
    required this.username,
    required this.name,
    this.email,
    this.bio,
    this.avatarStorageId,
    this.status,
    this.lastSeen,
    this.friendshipStatus = FriendshipStatus.none,
    this.requestId,
    this.role,
  });

  final String id;
  final String username;
  String name;
  String? email;
  String? bio;
  String? avatarStorageId;
  String? status; // "online" | "away" | "offline"
  DateTime? lastSeen;

  FriendshipStatus friendshipStatus;
  String? requestId; // friendship row id (for accept/reject ops)
  String? role; // "owner" | "member" (room context)

  String get displayName => name.trim().isNotEmpty ? name : username;
  String get displayInitial {
    final n = displayName.trim();
    if (n.isEmpty) return '?';
    return n.characters.first.toUpperCase();
  }

  factory ChatUser.fromJson(Map<String, dynamic> j) {
    final ls = j['lastSeen'];
    return ChatUser(
      id: (j['_id'] ?? j['id']).toString(),
      username: (j['username'] ?? '') as String,
      name: (j['name'] ?? '') as String,
      email: j['email'] as String?,
      bio: j['bio'] as String?,
      avatarStorageId: j['avatarStorageId'] as String?,
      status: j['status'] as String?,
      lastSeen: ls is num ? DateTime.fromMillisecondsSinceEpoch(ls.toInt()) : null,
      friendshipStatus: FriendshipStatusWire.parse(j['friendshipStatus'] as String?),
      requestId: j['requestId'] as String?,
      role: j['role'] as String?,
    );
  }

  ChatUser copyWith({
    String? name,
    String? email,
    String? bio,
    String? avatarStorageId,
    String? status,
    FriendshipStatus? friendshipStatus,
    String? requestId,
    String? role,
  }) => ChatUser(
        id: id,
        username: username,
        name: name ?? this.name,
        email: email ?? this.email,
        bio: bio ?? this.bio,
        avatarStorageId: avatarStorageId ?? this.avatarStorageId,
        status: status ?? this.status,
        lastSeen: lastSeen,
        friendshipStatus: friendshipStatus ?? this.friendshipStatus,
        requestId: requestId ?? this.requestId,
        role: role ?? this.role,
      );
}
