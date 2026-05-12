import 'dart:async';
import 'package:crypto/crypto.dart';
import 'dart:convert' show utf8;

import '../models/chat_message.dart';
import '../models/chat_room.dart';
import '../models/chat_user.dart';
import '../models/enums.dart';
import '../models/friend_request.dart';
import '../models/friend_request_message.dart';
import 'convex_client.dart';

/// Client-side SHA-256, matching v02's `SecurityUtils.hashPassword` /
/// CryptoKit usage. Convex backend stores and compares hashes directly.
String sha256Hash(String input) =>
    sha256.convert(utf8.encode(input)).toString();

/// Single home for every Convex function call the client makes.
/// Mirrors v02's `ConvexChatAPI` — one method per backend endpoint.
class ChatApi {
  ChatApi(this._cv);
  final ConvexBackend _cv;

  // ─────────────────────────────────────────────────────────────────────────
  // Auth
  // ─────────────────────────────────────────────────────────────────────────

  Future<AuthResult> signup({
    required String username,
    required String name,
    required String password,
    String? email,
    String? recoveryKey,
  }) async {
    final res = await _cv.mutation('auth:signup', {
      'username': username,
      'name': name,
      'passwordHash': sha256Hash(password),
      if (email != null && email.trim().isNotEmpty) 'email': email.trim(),
      if (recoveryKey != null && recoveryKey.trim().isNotEmpty)
        'recoveryKeyHash': sha256Hash(recoveryKey),
    });
    return AuthResult.fromJson(res as Map<String, dynamic>);
  }

  Future<AuthResult> login({required String username, required String password}) async {
    final res = await _cv.mutation('auth:login', {
      'username': username,
      'passwordHash': sha256Hash(password),
    });
    return AuthResult.fromJson(res as Map<String, dynamic>);
  }

  Future<void> logout({required String userId}) async {
    await _cv.mutation('auth:logout', {'userId': userId});
  }

  Future<AuthResult> resetPassword({
    required String username,
    required String recoveryKey,
    required String newPassword,
  }) async {
    final res = await _cv.mutation('auth:resetPasswordWithRecoveryKey', {
      'username': username,
      'recoveryKeyHash': sha256Hash(recoveryKey),
      'newPasswordHash': sha256Hash(newPassword),
    });
    return AuthResult.fromJson(res as Map<String, dynamic>);
  }

  Future<void> deleteAccount({required String userId}) async {
    await _cv.mutation('auth:deleteAccount', {'userId': userId});
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Users
  // ─────────────────────────────────────────────────────────────────────────

  Future<ChatUser?> getProfile(String userId) async {
    final res = await _cv.query('users:getProfile', {'userId': userId});
    if (res == null) return null;
    return ChatUser.fromJson((res as Map).cast<String, dynamic>());
  }

  Future<void> updateProfile({
    required String userId,
    required String name,
    String? email,
    String? bio,
  }) async {
    await _cv.mutation('users:updateProfile', {
      'userId': userId,
      'name': name,
      'email': ?email,
      'bio': ?bio,
    });
  }

  Future<void> updateAvatar({required String userId, required String storageId}) async {
    await _cv.mutation('users:updateAvatar', {'userId': userId, 'storageId': storageId});
  }

  Future<void> updateStatus({required String userId, required String status}) async {
    await _cv.mutation('users:updateStatus', {'userId': userId, 'status': status});
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Rooms
  // ─────────────────────────────────────────────────────────────────────────

  Future<String> createRoom({
    required String userId,
    required String name,
    required bool isPrivate,
    String? description,
    String? password,
    RoomType type = RoomType.regular,
    Duration? messageLifetime,
  }) async {
    final res = await _cv.mutation('rooms:create', {
      'userId': userId,
      'name': name,
      'isPrivate': isPrivate,
      if (description != null && description.isNotEmpty) 'description': description,
      if (password != null && password.isNotEmpty) 'passwordHash': sha256Hash(password),
      'type': type.wire,
      if (messageLifetime != null) 'messageLifetime': messageLifetime.inSeconds,
    });
    return res.toString();
  }

  Future<void> joinRoom({required String roomId, required String userId, String? password}) async {
    await _cv.mutation('rooms:join', {
      'roomId': roomId,
      'userId': userId,
      if (password != null && password.isNotEmpty) 'passwordHash': sha256Hash(password),
    });
  }

  Future<void> leaveRoom({required String roomId, required String userId}) async {
    await _cv.mutation('rooms:leave', {'roomId': roomId, 'userId': userId});
  }

  Future<void> deleteRoom({required String roomId, required String userId}) async {
    await _cv.mutation('rooms:deleteRoom', {'roomId': roomId, 'userId': userId});
  }

  Future<void> updateRoom({
    required String roomId,
    required String userId,
    required String name,
    String? description,
    bool? isPrivate,
    Duration? messageLifetime,
  }) async {
    await _cv.mutation('rooms:updateRoom', {
      'roomId': roomId,
      'userId': userId,
      'name': name,
      'description': ?description,
      'isPrivate': ?isPrivate,
      'messageLifetime': ?messageLifetime?.inSeconds,
    });
  }

  Future<List<ChatRoom>> listUserRooms(String userId) async {
    final res = await _cv.query('rooms:listUserRooms', {'userId': userId});
    return _decodeRooms(res);
  }

  Future<List<ChatRoom>> listPublic() async {
    final res = await _cv.query('rooms:listPublic', const {});
    return _decodeRooms(res);
  }

  Future<ChatRoom?> getRoom(String roomId) async {
    final res = await _cv.query('rooms:getRoom', {'roomId': roomId});
    if (res == null) return null;
    return ChatRoom.fromJson((res as Map).cast<String, dynamic>());
  }

  Future<List<ChatUser>> getMembers(String roomId) async {
    final res = await _cv.query('rooms:getMembers', {'roomId': roomId});
    return ((res as List?) ?? const [])
        .map((e) => ChatUser.fromJson((e as Map).cast<String, dynamic>()))
        .toList();
  }

  Future<String> getOrCreateDM({
    required String userId,
    required String friendId,
    RoomType roomType = RoomType.regular,
    Duration? messageLifetime,
  }) async {
    final res = await _cv.mutation('rooms:getOrCreateDM', {
      'userId': userId,
      'friendId': friendId,
      'roomType': roomType.displayLabel,
      'messageLifetime': ?messageLifetime?.inSeconds,
    });
    return res.toString();
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Messages
  // ─────────────────────────────────────────────────────────────────────────

  Future<String> sendMessage({
    required String roomId,
    required String userId,
    required String content,
    MessageType type = MessageType.text,
    String? mediaStorageId,
    String? senderName,
  }) async {
    final res = await _cv.mutation('messages:send', {
      'roomId': roomId,
      'userId': userId,
      'content': content,
      'type': type.wire,
      'mediaStorageId': ?mediaStorageId,
      'senderName': ?senderName,
    });
    return res.toString();
  }

  Future<void> deleteMessage({required String messageId, required String userId}) async {
    await _cv.mutation('messages:deleteMessage', {'messageId': messageId, 'userId': userId});
  }

  Future<List<ChatMessage>> listMessages({required String roomId, int limit = 100}) async {
    final res = await _cv.query('messages:list', {'roomId': roomId, 'limit': limit});
    return _decodeMessages(res);
  }

  Future<List<ChatMessage>> listBefore({
    required String roomId,
    required DateTime before,
    int limit = 30,
  }) async {
    final res = await _cv.query('messages:listBefore', {
      'roomId': roomId,
      'beforeTimestamp': before.millisecondsSinceEpoch,
      'limit': limit,
    });
    return _decodeMessages(res);
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Reactions
  // ─────────────────────────────────────────────────────────────────────────

  Future<void> addReaction({
    required String messageId,
    required String userId,
    required String emoji,
  }) async {
    await _cv.mutation('reactions:addReaction', {
      'messageId': messageId,
      'userId': userId,
      'emoji': emoji,
    });
  }

  Future<void> removeReaction({
    required String messageId,
    required String userId,
    required String emoji,
  }) async {
    await _cv.mutation('reactions:removeReaction', {
      'messageId': messageId,
      'userId': userId,
      'emoji': emoji,
    });
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Typing
  // ─────────────────────────────────────────────────────────────────────────

  Future<void> setTyping({required String roomId, required String userId}) async {
    await _cv.mutation('typing:setTyping', {'roomId': roomId, 'userId': userId});
  }

  Future<void> clearTyping({required String roomId, required String userId}) async {
    await _cv.mutation('typing:clearTyping', {'roomId': roomId, 'userId': userId});
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Friends
  // ─────────────────────────────────────────────────────────────────────────

  Future<List<ChatUser>> listFriends(String userId) async {
    final res = await _cv.query('friends:listFriends', {'userId': userId});
    return ((res as List?) ?? const [])
        .map((e) => ChatUser.fromJson((e as Map).cast<String, dynamic>()))
        .toList();
  }

  Future<List<FriendRequest>> listIncomingDirectRequests(String userId) async {
    final res = await _cv.query('friends:listIncomingDirectRequests', {'userId': userId});
    return ((res as List?) ?? const [])
        .map((e) => FriendRequest.fromJson((e as Map).cast<String, dynamic>()))
        .toList();
  }

  Future<List<FriendRequest>> listOutgoingDirectRequests(String userId) async {
    final res = await _cv.query('friends:listOutgoingDirectRequests', {'userId': userId});
    return ((res as List?) ?? const [])
        .map((e) => FriendRequest.fromJson((e as Map).cast<String, dynamic>()))
        .toList();
  }

  Future<String> createDirectRequest({
    required String userId,
    required String friendId,
    required RoomType roomType,
    Duration? messageLifetime,
    String? initialMessage,
  }) async {
    final res = await _cv.mutation('friends:createDirectRequest', {
      'userId': userId,
      'friendId': friendId,
      'roomType': roomType.displayLabel,
      'messageLifetime': ?messageLifetime?.inSeconds,
      'initialMessage': ?initialMessage,
    });
    return res.toString();
  }

  Future<void> appendDirectRequestMessage({
    required String requestId,
    required String userId,
    required String content,
  }) async {
    await _cv.mutation('friends:appendDirectRequestMessage', {
      'requestId': requestId,
      'userId': userId,
      'content': content,
    });
  }

  Future<List<FriendRequestMessage>> listDirectRequestMessages(String requestId) async {
    final res = await _cv.query('friends:listDirectRequestMessages', {'requestId': requestId});
    return ((res as List?) ?? const [])
        .map((e) => FriendRequestMessage.fromJson((e as Map).cast<String, dynamic>()))
        .toList();
  }

  Future<String?> approveDirectRequest({required String userId, required String requesterId}) async {
    final res = await _cv.mutation('friends:approveDirectRequest', {
      'userId': userId,
      'requesterId': requesterId,
    });
    return res?.toString();
  }

  Future<void> cancelDirectRequest({required String userId, required String friendId}) async {
    await _cv.mutation('friends:cancelDirectRequest', {'userId': userId, 'friendId': friendId});
  }

  Future<void> rejectDirectRequest({required String userId, required String requesterId}) async {
    await _cv.mutation('friends:rejectDirectRequest', {'userId': userId, 'requesterId': requesterId});
  }

  Future<void> removeFriend({required String userId, required String friendId}) async {
    await _cv.mutation('friends:removeFriend', {'userId': userId, 'friendId': friendId});
  }

  Future<List<ChatUser>> searchUsers({required String query, required String currentUserId}) async {
    final res = await _cv.query('users:searchUsers', {
      'query': query,
      'currentUserId': currentUserId,
    });
    return ((res as List?) ?? const [])
        .map((e) => ChatUser.fromJson((e as Map).cast<String, dynamic>()))
        .toList();
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Files
  // ─────────────────────────────────────────────────────────────────────────

  Future<String> generateUploadUrl() async {
    final res = await _cv.mutation('files:generateUploadUrl', const {});
    return res.toString();
  }

  Future<String> getFileUrl(String storageId) async {
    final res = await _cv.query('files:getFileUrl', {'storageId': storageId});
    return res.toString();
  }

  Future<void> deleteFile(String storageId) async {
    await _cv.mutation('files:deleteFile', {'storageId': storageId});
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Helpers
  // ─────────────────────────────────────────────────────────────────────────

  List<ChatRoom> _decodeRooms(dynamic res) {
    return ((res as List?) ?? const [])
        .map((e) => ChatRoom.fromJson((e as Map).cast<String, dynamic>()))
        .toList();
  }

  List<ChatMessage> _decodeMessages(dynamic res) {
    return ((res as List?) ?? const [])
        .map((e) => ChatMessage.fromJson((e as Map).cast<String, dynamic>()))
        .toList();
  }
}

class AuthResult {
  AuthResult({required this.userId, required this.username, required this.name});
  final String userId;
  final String username;
  final String name;
  factory AuthResult.fromJson(Map<String, dynamic> j) => AuthResult(
        userId: (j['userId']).toString(),
        username: (j['username']).toString(),
        name: (j['name']).toString(),
      );
}
