import 'package:flutter/widgets.dart';
import 'enums.dart';

/// Per-field visibility for a user's profile. Matches backend's
/// `users.visibility` shape. Missing fields default to `public`.
enum FieldVisibility { public, friends, nobody }

extension FieldVisibilityWire on FieldVisibility {
  String get wire => name;
  static FieldVisibility parse(String? s) {
    switch (s) {
      case 'friends':
        return FieldVisibility.friends;
      case 'nobody':
        return FieldVisibility.nobody;
      default:
        return FieldVisibility.public;
    }
  }
}

class ProfileVisibility {
  ProfileVisibility({
    this.avatar = FieldVisibility.public,
    this.status = FieldVisibility.public,
    this.lastSeen = FieldVisibility.public,
    this.friendRequests = FieldVisibility.public, // public | nobody only
  });

  FieldVisibility avatar;
  FieldVisibility status;
  FieldVisibility lastSeen;
  FieldVisibility friendRequests;

  factory ProfileVisibility.fromJson(Map<String, dynamic> j) => ProfileVisibility(
        avatar: FieldVisibilityWire.parse(j['avatar'] as String?),
        status: FieldVisibilityWire.parse(j['status'] as String?),
        lastSeen: FieldVisibilityWire.parse(j['lastSeen'] as String?),
        friendRequests: FieldVisibilityWire.parse(j['friendRequests'] as String?),
      );

  ProfileVisibility copyWith({
    FieldVisibility? avatar,
    FieldVisibility? status,
    FieldVisibility? lastSeen,
    FieldVisibility? friendRequests,
  }) =>
      ProfileVisibility(
        avatar: avatar ?? this.avatar,
        status: status ?? this.status,
        lastSeen: lastSeen ?? this.lastSeen,
        friendRequests: friendRequests ?? this.friendRequests,
      );
}

class ChatUser {
  ChatUser({
    required this.id,
    required this.username,
    required this.name,
    this.email,
    this.avatarStorageId,
    this.status,
    this.lastSeen,
    this.friendshipStatus = FriendshipStatus.none,
    this.requestId,
    this.role,
    this.visibility,
    this.isRedacted = false,
    this.acceptsFriendRequests = true,
  });

  final String id;
  final String username;
  String name;
  String? email;
  String? avatarStorageId;
  String? status; // "online" | "away" | "offline"
  DateTime? lastSeen;

  FriendshipStatus friendshipStatus;
  String? requestId; // friendship row id (for accept/reject ops)
  String? role; // "owner" | "member" (room context)

  /// Present only on a self-profile fetch — null when viewing other users.
  /// Other viewers seeing someone's settings would itself be a privacy leak.
  ProfileVisibility? visibility;

  /// True when the backend redacted at least one field for this viewer.
  /// Drives the "limited view" indicator on profile.
  bool isRedacted;

  /// True when the target accepts friend requests. False means the SEND
  /// REQUEST button should be disabled (or return USER_NOT_FOUND server-side).
  bool acceptsFriendRequests;

  String get displayName => name.trim().isNotEmpty ? name : username;
  String get displayInitial {
    final n = displayName.trim();
    if (n.isEmpty) return '?';
    return n.characters.first.toUpperCase();
  }

  factory ChatUser.fromJson(Map<String, dynamic> j) {
    final ls = j['lastSeen'];
    final visRaw = j['visibility'];
    return ChatUser(
      id: (j['_id'] ?? j['id']).toString(),
      username: (j['username'] ?? '') as String,
      name: (j['name'] ?? '') as String,
      email: j['email'] as String?,
      avatarStorageId: j['avatarStorageId'] as String?,
      status: j['status'] as String?,
      lastSeen: ls is num ? DateTime.fromMillisecondsSinceEpoch(ls.toInt()) : null,
      friendshipStatus: FriendshipStatusWire.parse(j['friendshipStatus'] as String?),
      requestId: j['requestId'] as String?,
      role: j['role'] as String?,
      visibility: visRaw is Map
          ? ProfileVisibility.fromJson(visRaw.cast<String, dynamic>())
          : null,
      isRedacted: (j['isRedacted'] as bool?) ?? false,
      acceptsFriendRequests: (j['acceptsFriendRequests'] as bool?) ?? true,
    );
  }

  ChatUser copyWith({
    String? name,
    String? email,
    String? avatarStorageId,
    String? status,
    FriendshipStatus? friendshipStatus,
    String? requestId,
    String? role,
    ProfileVisibility? visibility,
    bool? isRedacted,
    bool? acceptsFriendRequests,
  }) => ChatUser(
        id: id,
        username: username,
        name: name ?? this.name,
        email: email ?? this.email,
        avatarStorageId: avatarStorageId ?? this.avatarStorageId,
        status: status ?? this.status,
        lastSeen: lastSeen,
        friendshipStatus: friendshipStatus ?? this.friendshipStatus,
        requestId: requestId ?? this.requestId,
        role: role ?? this.role,
        visibility: visibility ?? this.visibility,
        isRedacted: isRedacted ?? this.isRedacted,
        acceptsFriendRequests: acceptsFriendRequests ?? this.acceptsFriendRequests,
      );
}
