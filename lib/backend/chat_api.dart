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

  /// Fetch a user's profile. Pass [viewerUserId] so the backend can apply
  /// per-field visibility for the viewer (friends-only / nobody fields are
  /// stripped from the response).
  Future<ChatUser?> getProfile(String userId, {String? viewerUserId}) async {
    final res = await _cv.query('users:getProfile', {
      'userId': userId,
      'viewerUserId': ?viewerUserId,
    });
    if (res == null) return null;
    return ChatUser.fromJson((res as Map).cast<String, dynamic>());
  }

  /// Updates per-field profile visibility. Only non-null fields are touched;
  /// pass exactly what you want to change.
  Future<void> updateVisibility({
    required String userId,
    FieldVisibility? avatar,
    FieldVisibility? status,
    FieldVisibility? lastSeen,
    FieldVisibility? seen,
    FieldVisibility? friendRequests,
  }) async {
    await _cv.mutation('users:updateVisibility', {
      'userId': userId,
      if (avatar != null) 'avatar': avatar.wire,
      if (status != null) 'status': status.wire,
      if (lastSeen != null) 'lastSeen': lastSeen.wire,
      if (seen != null) 'seen': seen.wire,
      if (friendRequests != null) 'friendRequests': friendRequests.wire,
    });
  }

  Future<void> updateProfile({
    required String userId,
    required String name,
    String? email,
  }) async {
    await _cv.mutation('users:updateProfile', {
      'userId': userId,
      'name': name,
      'email': ?email,
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

  /// Pass null/empty password to clear the password on a room. Owner only.
  Future<void> updateRoomPassword({
    required String roomId,
    required String userId,
    String? password,
  }) async {
    await _cv.mutation('rooms:updatePassword', {
      'roomId': roomId,
      'userId': userId,
      if (password != null && password.isNotEmpty)
        'passwordHash': sha256Hash(password),
    });
  }

  Future<void> updateRoomAvatar({
    required String roomId,
    required String userId,
    required String storageId,
  }) async {
    await _cv.mutation('rooms:updateRoomAvatar', {
      'roomId': roomId,
      'userId': userId,
      'storageId': storageId,
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
    String? replyToId,
  }) async {
    final res = await _cv.mutation('messages:send', {
      'roomId': roomId,
      'userId': userId,
      'content': content,
      'type': type.wire,
      'mediaStorageId': ?mediaStorageId,
      'senderName': ?senderName,
      'replyToId': ?replyToId,
    });
    return res.toString();
  }

  /// Fetch the entire conversational thread containing [messageId] — walks
  /// up to the root via the parent chain, then BFS down through all
  /// descendants. Result is chronological (oldest first), capped at
  /// [maxTotal] messages.
  Future<List<ChatMessage>> getThread({
    required String messageId,
    int maxTotal = 50,
  }) async {
    final res = await _cv.query('messages:getThread', {
      'messageId': messageId,
      'maxTotal': maxTotal,
    });
    return _decodeMessages(res);
  }

  Future<void> deleteMessage({required String messageId, required String userId}) async {
    await _cv.mutation('messages:deleteMessage', {'messageId': messageId, 'userId': userId});
  }

  Future<List<ChatMessage>> listMessages({required String roomId, int limit = 100}) async {
    final res = await _cv.query('messages:list', {'roomId': roomId, 'limit': limit});
    return _decodeMessages(res);
  }

  Future<void> markRoomRead({required String roomId, required String userId}) async {
    await _cv.mutation('messages:markRoomRead', {'roomId': roomId, 'userId': userId});
  }

  /// Returns `[{userId, lastReadAt(ms)}]` for every member of the room whose
  /// `seen` visibility allows the viewer to see it. The viewer's own row is
  /// always present. Subscribe via the repo for live read receipts.
  Future<List<({String userId, DateTime lastReadAt})>> getReadState({
    required String roomId,
    required String viewerUserId,
  }) async {
    final res = await _cv.query(
      'messages:getReadState',
      {'roomId': roomId, 'viewerUserId': viewerUserId},
    );
    return ((res as List?) ?? const []).map((e) {
      final m = (e as Map).cast<String, dynamic>();
      final ts = (m['lastReadAt'] as num?)?.toInt() ?? 0;
      return (
        userId: (m['userId']).toString(),
        lastReadAt: DateTime.fromMillisecondsSinceEpoch(ts),
      );
    }).toList();
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

  // ─────────────────────────────────────────────────────────────────────────
  // Blocking + reporting
  // ─────────────────────────────────────────────────────────────────────────

  /// Block a user. When [deleteDm] is true, the shared DM room (if any) is
  /// wiped completely on the backend — every message, reaction, media file,
  /// and both memberships go. Group rooms are not touched.
  Future<void> blockUser({
    required String userId,
    required String targetUserId,
    bool deleteDm = false,
  }) async {
    await _cv.mutation('users:blockUser', {
      'userId': userId,
      'targetUserId': targetUserId,
      if (deleteDm) 'deleteDm': true,
    });
  }

  Future<void> unblockUser({required String userId, required String targetUserId}) async {
    await _cv.mutation('users:unblockUser', {
      'userId': userId,
      'targetUserId': targetUserId,
    });
  }

  Future<List<ChatUser>> listBlocked(String userId) async {
    final res = await _cv.query('users:listBlocked', {'userId': userId});
    return ((res as List?) ?? const [])
        .map((e) => ChatUser.fromJson((e as Map).cast<String, dynamic>()))
        .toList();
  }

  /// Returns rooms BOTH users belong to, split into group rooms and a
  /// DM-present flag. Used by the block confirm sheet.
  Future<SharedRoomsInfo> listSharedRooms({
    required String userId,
    required String otherUserId,
  }) async {
    final res = await _cv.query('rooms:listShared', {
      'userId': userId,
      'otherUserId': otherUserId,
    });
    final map = (res as Map?)?.cast<String, dynamic>() ?? const {};
    final list = (map['groupRooms'] as List?) ?? const [];
    final rooms = list
        .map((e) => ChatRoom.fromJson((e as Map).cast<String, dynamic>()))
        .toList();
    return SharedRoomsInfo(
      groupRooms: rooms,
      hasDm: (map['hasDm'] as bool?) ?? false,
    );
  }

  Future<bool> isBlocked({required String userId, required String otherUserId}) async {
    final res = await _cv.query('users:isBlocked', {
      'userId': userId,
      'otherUserId': otherUserId,
    });
    return (res as bool?) ?? false;
  }

  /// Submit a report against a user / message / room.
  /// `targetType` ∈ {"user", "message", "room"}.
  Future<void> report({
    required String reporterId,
    required String targetType,
    required String targetId,
    required String reason,
    String? note,
  }) async {
    await _cv.mutation('users:report', {
      'reporterId': reporterId,
      'targetType': targetType,
      'targetId': targetId,
      'reason': reason,
      if (note != null && note.isNotEmpty) 'note': note,
    });
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
  // Calls (WebRTC 1:1)
  // ─────────────────────────────────────────────────────────────────────────

  Future<String> initiateCall({
    required String callerId,
    required String calleeId,
    required String roomId,
    required String type, // "audio" | "video"
  }) async {
    final res = await _cv.mutation('calls:initiate', {
      'callerId': callerId,
      'calleeId': calleeId,
      'roomId': roomId,
      'type': type,
    });
    return res.toString();
  }

  Future<void> acceptCall({required String callId, required String userId}) async {
    await _cv.mutation('calls:accept', {'callId': callId, 'userId': userId});
  }

  Future<void> rejectCall({required String callId, required String userId}) async {
    await _cv.mutation('calls:reject', {'callId': callId, 'userId': userId});
  }

  Future<void> cancelCall({required String callId, required String userId}) async {
    await _cv.mutation('calls:cancel', {'callId': callId, 'userId': userId});
  }

  Future<void> endCall({required String callId, required String userId}) async {
    await _cv.mutation('calls:end', {'callId': callId, 'userId': userId});
  }

  Future<void> sendCallSignal({
    required String callId,
    required String fromUserId,
    required String toUserId,
    required String kind, // "offer"|"answer"|"ice"|"state"|"bye"|"reject"|"cancel"
    required String payload,
  }) async {
    await _cv.mutation('calls:sendSignal', {
      'callId': callId,
      'fromUserId': fromUserId,
      'toUserId': toUserId,
      'kind': kind,
      'payload': payload,
    });
  }

  Future<void> consumeCallSignal({
    required String signalId,
    required String userId,
  }) async {
    await _cv.mutation('calls:consumeSignal', {
      'signalId': signalId,
      'userId': userId,
    });
  }

  Future<Map<String, dynamic>?> activeCallForUser(String userId) async {
    final res = await _cv.query('calls:activeCallForUser', {'userId': userId});
    if (res == null) return null;
    return (res as Map).cast<String, dynamic>();
  }

  /// Returns `{ iceServers: [{urls, username?, credential?}, …] }`.
  Future<List<Map<String, dynamic>>> getIceConfig(String userId) async {
    final res = await _cv.action('calls:getIceConfig', {'userId': userId});
    final list = ((res as Map?)?['iceServers'] as List?) ?? const [];
    return list
        .map((e) => (e as Map).cast<String, dynamic>())
        .toList(growable: false);
  }

  /// Live subscription to my unconsumed inbound signals. The caller is
  /// responsible for calling [consumeCallSignal] for each signal it processes.
  Future<Subscription> subscribeCallSignals({
    required String userId,
    required void Function(List<Map<String, dynamic>> signals) onSignals,
    void Function(Object error)? onError,
  }) {
    return _cv.subscribe(
      'calls:signalsForUser',
      {'userId': userId},
      onData: (raw) {
        final list = (raw as List?) ?? const [];
        final out = list
            .map((e) => (e as Map).cast<String, dynamic>())
            .toList(growable: false);
        onSignals(out);
      },
      onError: onError,
    );
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

class SharedRoomsInfo {
  SharedRoomsInfo({required this.groupRooms, required this.hasDm});
  final List<ChatRoom> groupRooms;
  final bool hasDm;
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
