import 'dart:async';
import 'package:crypto/crypto.dart';
import 'dart:convert' show utf8;

import '../env.dart';
import '../models/app_release.dart';
import '../models/chat_message.dart';
import '../models/chat_room.dart';
import '../models/chat_user.dart';
import '../models/enums.dart';
import '../models/friend_request.dart';
import '../models/family.dart';
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

  /// Presence keepalive — refreshes `lastSeen` without changing the stored
  /// online/away status. Called on an interval by the app so a client that
  /// stops heartbeating (closed browser tab, killed app) is treated as offline
  /// by the server's staleness fallback. See backend `users:heartbeat`.
  Future<void> heartbeat({required String userId}) async {
    await _cv.mutation('users:heartbeat', {'userId': userId});
  }

  /// Persist the PushKit (iOS) VoIP token so the backend can wake this device
  /// into CallKit even when the app is killed. Keyed by (userId, deviceId)
  /// so multiple devices for the same user keep their own tokens.
  Future<void> setVoipToken({
    required String userId,
    required String deviceId,
    required String platform,
    required String token,
    String? deviceName,
    String? apnsEnv, // "sandbox" | "production"
  }) async {
    await _cv.mutation('voipTokens:setVoipToken', {
      'userId': userId,
      'deviceId': deviceId,
      'platform': platform,
      'token': token,
      'deviceName': ?deviceName,
      'apnsEnv': ?apnsEnv,
    });
  }

  /// Persist the FCM (Android) token for high-priority data pushes that wake
  /// a killed app into the native ConnectionService ringer.
  Future<void> setFcmToken({
    required String userId,
    required String deviceId,
    required String platform,
    required String token,
    String? deviceName,
  }) async {
    await _cv.mutation('voipTokens:setFcmToken', {
      'userId': userId,
      'deviceId': deviceId,
      'platform': platform,
      'token': token,
      'deviceName': ?deviceName,
    });
  }

  /// Tokenless device registration for platforms without native push
  /// (macOS, Windows, Linux, Web). Records the deviceId + label so the
  /// global "Move call here" pill can name this device when it holds
  /// the active call.
  Future<void> registerDevice({
    required String userId,
    required String deviceId,
    required String platform,
    String? deviceName,
  }) async {
    await _cv.mutation('voipTokens:registerDevice', {
      'userId': userId,
      'deviceId': deviceId,
      'platform': platform,
      'deviceName': ?deviceName,
    });
  }

  /// Logout from a single device — remove only this device's row from
  /// the userDevices registry. Sibling devices stay logged in.
  Future<void> clearDeviceToken({
    required String userId,
    required String deviceId,
  }) async {
    await _cv.mutation('voipTokens:clearDeviceToken', {
      'userId': userId,
      'deviceId': deviceId,
    });
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

  /// Pass [viewerUserId] so the backend can return an empty list for a child
  /// whose guardian hasn't unlocked public rooms — the client hides Discover
  /// too, but this is the half that can't be worked around.
  Future<List<ChatRoom>> listPublic({String? viewerUserId}) async {
    final res = await _cv.query('rooms:listPublic', {
      'viewerUserId': ?viewerUserId,
    });
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
    /// Pixel size of [mediaStorageId] when the sender knows it, so receivers can
    /// lay the bubble out at the picture's real ratio without decoding it first.
    double? mediaWidth,
    double? mediaHeight,

    /// Set on [MessageType.file] and nothing else. Convex storage records
    /// neither the original name nor a usable content type, so a document that
    /// doesn't carry them here can never be presented as anything but a UUID.
    String? fileName,
    int? fileSize,
    String? mimeType,
    String? senderName,
    String? replyToId,

    /// Burn-after-reading. The server drops [mediaWidth]/[mediaHeight] for one
    /// of these and never hands the storage id back out again.
    bool viewOnce = false,
    /// Idempotency key — the optimistic message's local id, reused verbatim on
    /// every retry of that message. The server returns the row it already wrote
    /// rather than writing a second one.
    String? clientId,
    /// Who this message names with an `@`. Ids only: the server resolves each
    /// one to a handle itself, and drops any that isn't a current member of the
    /// room or isn't actually written into [content].
    List<String> mentionedUserIds = const [],
    bool mentionsEveryone = false,
  }) async {
    final res = await _cv.mutation('messages:send', {
      'roomId': roomId,
      'userId': userId,
      'content': content,
      'type': type.wire,
      'clientId': ?clientId,
      'mediaStorageId': ?mediaStorageId,
      'mediaWidth': ?mediaWidth,
      'mediaHeight': ?mediaHeight,
      'fileName': ?fileName,
      'fileSize': ?fileSize,
      'mimeType': ?mimeType,
      'senderName': ?senderName,
      'replyToId': ?replyToId,
      if (viewOnce) 'viewOnce': true,
      // Omitted rather than sent empty, matching `viewOnce` above — the common
      // message mentions nobody and shouldn't widen the wire to say so.
      if (mentionedUserIds.isNotEmpty) 'mentionedUserIds': mentionedUserIds,
      if (mentionsEveryone) 'mentionsEveryone': true,
    });
    return res.toString();
  }

  /// Spends this viewer's one look at a view-once photo and returns a ticket
  /// for [viewOnceStreamUrl].
  ///
  /// The view is recorded server-side the moment this returns a nonce, NOT when
  /// the picture is dismissed — a client that crashes mid-view has still used
  /// its look, because it could not have got the ticket otherwise. Calling
  /// again with the same nonce still live is a retry, not a second view.
  ///
  /// Returns a null [nonce] when the photo is spent, burned, or was never
  /// armed; [alreadyViewed] distinguishes "you had your look" from "it's gone".
  Future<({String? nonce, bool alreadyViewed, bool gone})> openViewOnce({
    required String messageId,
    required String userId,
  }) async {
    final res = await _cv.mutation('messages:openViewOnce', {
      'messageId': messageId,
      'userId': userId,
    });
    final m = (res as Map?)?.cast<String, dynamic>() ?? const {};
    return (
      nonce: m['nonce'] as String?,
      alreadyViewed: (m['alreadyViewed'] as bool?) ?? false,
      gone: (m['gone'] as bool?) ?? false,
    );
  }

  /// Where to fetch the bytes for a ticket minted by [openViewOnce].
  ///
  /// Deliberately not a Convex storage URL: those are unsigned and never
  /// expire on this deployment, so one would be a permanent copy of a photo
  /// that is supposed to stop existing. This URL dies with its nonce.
  static Uri viewOnceStreamUrl({
    required String messageId,
    required String userId,
    required String nonce,
  }) {
    final base = Env.convexSiteUrl.replaceAll(RegExp(r'/+$'), '');
    return Uri.parse('$base/viewOnce').replace(queryParameters: {
      'm': messageId,
      'u': userId,
      'n': nonce,
    });
  }

  /// One page of the thread rooted at [rootId], walking *older*: pass the
  /// oldest `createdAt` you already hold as [before], or omit it for the
  /// newest page. Result is chronological (oldest first).
  ///
  /// There is deliberately no "load newer" — the newest end of a thread is
  /// covered by the room's live `messages:list` subscription, which
  /// [ChatRepository.threadFor] merges in.
  Future<({List<ChatMessage> messages, bool hasMore})> getThreadPage({
    required String roomId,
    required String rootId,
    required String viewerUserId,
    DateTime? before,
    int limit = 25,
  }) async {
    final res = await _cv.query('messages:getThreadPage', {
      'roomId': roomId,
      'rootId': rootId,
      'viewerUserId': viewerUserId,
      'beforeTimestamp': ?before?.millisecondsSinceEpoch,
      'limit': limit,
    });
    final map = (res as Map?)?.cast<String, dynamic>() ?? const {};
    return (
      messages: _decodeMessages(map['messages']),
      hasMore: (map['hasMore'] as bool?) ?? false,
    );
  }

  /// DEPRECATED — use [getThreadPage]. Fetches the entire conversational
  /// thread containing [messageId] in one unpaged shot, capped at [maxTotal].
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

  /// [viewerUserId] doesn't filter anything — it only lets the server say
  /// whether *this* viewer has already spent their look at each view-once
  /// photo. Omitting it costs the "Opened" state, not correctness.
  Future<List<ChatMessage>> listMessages({
    required String roomId,
    int limit = 100,
    String? viewerUserId,
  }) async {
    final res = await _cv.query('messages:list', {
      'roomId': roomId,
      'limit': limit,
      'viewerUserId': ?viewerUserId,
    });
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
    String? viewerUserId,
  }) async {
    final res = await _cv.query('messages:listBefore', {
      'roomId': roomId,
      'beforeTimestamp': before.millisecondsSinceEpoch,
      'limit': limit,
      'viewerUserId': ?viewerUserId,
    });
    return _decodeMessages(res);
  }

  /// The ascending counterpart to [listBefore]. Only used to walk back down
  /// toward the present after [listAround] dropped the reader into old
  /// history — the newest end is covered by the live `messages:list`
  /// subscription.
  Future<List<ChatMessage>> listAfter({
    required String roomId,
    required DateTime after,
    int limit = 30,
    String? viewerUserId,
  }) async {
    final res = await _cv.query('messages:listAfter', {
      'roomId': roomId,
      'afterTimestamp': after.millisecondsSinceEpoch,
      'limit': limit,
      'viewerUserId': ?viewerUserId,
    });
    return _decodeMessages(res);
  }

  /// A window of history centred on [messageId] — the message itself plus
  /// [before] older and [after] newer, chronological. Lets the UI jump
  /// straight to a quoted message that predates everything it holds instead
  /// of paging the whole gap. `found` is false when the message has been
  /// deleted or doesn't belong to this room.
  Future<
      ({
        List<ChatMessage> messages,
        bool hasMoreOlder,
        bool hasMoreNewer,
        bool found,
      })> listAround({
    required String roomId,
    required String messageId,
    int before = 25,
    int after = 25,
    String? viewerUserId,
  }) async {
    final res = await _cv.query('messages:listAround', {
      'roomId': roomId,
      'messageId': messageId,
      'before': before,
      'after': after,
      'viewerUserId': ?viewerUserId,
    });
    final map = (res as Map?)?.cast<String, dynamic>() ?? const {};
    return (
      messages: _decodeMessages(map['messages']),
      hasMoreOlder: (map['hasMoreOlder'] as bool?) ?? false,
      hasMoreNewer: (map['hasMoreNewer'] as bool?) ?? false,
      found: (map['found'] as bool?) ?? false,
    );
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
  // Pins
  // ─────────────────────────────────────────────────────────────────────────

  /// Neither of these takes a `roomId`: the server derives it from the message,
  /// so a pin naming a room its message doesn't live in cannot be expressed.
  Future<void> pinMessage({
    required String messageId,
    required String userId,
  }) async {
    await _cv.mutation('pins:pin', {
      'messageId': messageId,
      'userId': userId,
    });
  }

  Future<void> unpinMessage({
    required String messageId,
    required String userId,
  }) async {
    await _cv.mutation('pins:unpin', {
      'messageId': messageId,
      'userId': userId,
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
  // Family
  // ─────────────────────────────────────────────────────────────────────────

  /// Am I a child, what may I do, who's in my family, and how much is waiting
  /// on me. One call — the client leans on this to decide what to render.
  Future<FamilyContext?> getFamilyContext(String userId) async {
    final res = await _cv.query('family:getFamilyContext', {'userId': userId});
    if (res == null) return null;
    return FamilyContext.fromJson((res as Map).cast<String, dynamic>());
  }

  /// Live version of [getFamilyContext]. A guardian tightening or loosening a
  /// rule reaches the child's phone over the socket that's already open, so
  /// the child doesn't have to restart the app to lose (or gain) a tab.
  Future<Subscription> subscribeFamilyContext({
    required String userId,
    required void Function(FamilyContext? context) onContext,
    void Function(Object error)? onError,
  }) {
    return _cv.subscribe(
      'family:getFamilyContext',
      {'userId': userId},
      onData: (raw) {
        if (raw == null) {
          onContext(null);
          return;
        }
        onContext(FamilyContext.fromJson((raw as Map).cast<String, dynamic>()));
      },
      onError: onError,
    );
  }

  Future<AuthResult> createChildAccount({
    required String guardianId,
    required String username,
    required String name,
    int? birthYear,
  }) async {
    final res = await _cv.mutation('family:createChildAccount', {
      'guardianId': guardianId,
      'username': username,
      'name': name,
      'birthYear': ?birthYear,
    });
    return AuthResult.fromJson((res as Map).cast<String, dynamic>());
  }

  Future<void> addGuardian({
    required String guardianId,
    required String childId,
    required String newGuardianUsername,
  }) async {
    await _cv.mutation('family:addGuardian', {
      'guardianId': guardianId,
      'childId': childId,
      'newGuardianUsername': newGuardianUsername,
    });
  }

  /// Registers a pairing code for a child device. [code] is generated on this
  /// device and shown to the user; only its hash crosses the wire, exactly as
  /// passwords do. Returns when the code expires.
  Future<DateTime> createPairingCode({
    required String guardianId,
    required String childId,
    required String code,
  }) async {
    final res = await _cv.mutation('family:createPairingCode', {
      'guardianId': guardianId,
      'childId': childId,
      'codeHash': sha256Hash(code),
    });
    final map = (res as Map).cast<String, dynamic>();
    return DateTime.fromMillisecondsSinceEpoch(
      ((map['expiresAt'] ?? 0) as num).toInt(),
    );
  }

  Future<void> revokePairingCode({
    required String guardianId,
    required String childId,
  }) async {
    await _cv.mutation('family:revokePairingCode', {
      'guardianId': guardianId,
      'childId': childId,
    });
  }

  /// Mints the code that hands a child's phone back. Same shape as
  /// [createPairingCode] — only the hash crosses the wire — but a different
  /// table server-side, so a release code can never be redeemed as a sign-in.
  Future<DateTime> createReleaseCode({
    required String guardianId,
    required String childId,
    required String code,
  }) async {
    final res = await _cv.mutation('family:createReleaseCode', {
      'guardianId': guardianId,
      'childId': childId,
      'codeHash': sha256Hash(code),
    });
    final map = (res as Map).cast<String, dynamic>();
    return DateTime.fromMillisecondsSinceEpoch(
      ((map['expiresAt'] ?? 0) as num).toInt(),
    );
  }

  /// Releases this handset with a guardian's six-digit code. Single-use.
  Future<void> releaseDeviceByCode({
    required String code,
    required String deviceId,
  }) async {
    await _cv.mutation('family:releaseDeviceByCode', {
      'codeHash': sha256Hash(code),
      'deviceId': deviceId,
    });
  }

  /// Releases this handset with a guardian's own password — the path that
  /// works when there's only one phone and no adult session to mint a code.
  /// Every failure comes back as the same error by design.
  Future<void> releaseDeviceByGuardianPassword({
    required String childId,
    required String guardianUsername,
    required String password,
    required String deviceId,
  }) async {
    await _cv.mutation('family:releaseDeviceByGuardianPassword', {
      'childId': childId,
      'guardianUsername': guardianUsername,
      'passwordHash': sha256Hash(password),
      'deviceId': deviceId,
    });
  }

  /// Trades a pairing code for a session on the child's device. Single-use —
  /// a second attempt with the same code fails with PAIRING_CODE_INVALID.
  Future<AuthResult> redeemPairingCode({
    required String code,
    required String deviceId,
    required String platform,
    String? deviceName,
  }) async {
    final res = await _cv.mutation('family:redeemPairingCode', {
      'codeHash': sha256Hash(code),
      'deviceId': deviceId,
      'platform': platform,
      'deviceName': ?deviceName,
    });
    return AuthResult.fromJson((res as Map).cast<String, dynamic>());
  }

  /// Everything waiting on this guardian, across all their children.
  Future<List<QueueItem>> listGuardianQueue(String guardianId) async {
    final res = await _cv.query('family:listGuardianQueue', {
      'guardianId': guardianId,
    });
    return ((res as List?) ?? const [])
        .map((e) => QueueItem.fromJson((e as Map).cast<String, dynamic>()))
        .whereType<QueueItem>()
        .toList();
  }

  /// Moves a contact request one hop along the guardian relay, or kills it.
  /// Used for both [QueueItemType.contactOutgoing] and `contactIncoming`.
  Future<void> advanceContactRequest({
    required String friendshipId,
    required String guardianId,
    required bool approve,
  }) async {
    await _cv.mutation('family:advanceContactRequest', {
      'friendshipId': friendshipId,
      'guardianId': guardianId,
      'approve': approve,
    });
  }

  /// Raises a "can I join this room?" with the child's guardians.
  Future<String> requestApproval({
    required String childId,
    required String kind,
    String? targetRoomId,
    String? note,
  }) async {
    final res = await _cv.mutation('family:requestApproval', {
      'childId': childId,
      'kind': kind,
      'targetRoomId': ?targetRoomId,
      'note': ?note,
    });
    return res.toString();
  }

  /// Approving also performs the join, so the child doesn't have to re-tap.
  Future<String?> decideApproval({
    required String approvalId,
    required String guardianId,
    required bool approve,
  }) async {
    final res = await _cv.mutation('family:decideApproval', {
      'approvalId': approvalId,
      'guardianId': guardianId,
      'approve': approve,
    });
    return res?.toString();
  }

  Future<void> revokeApproval({
    required String guardianId,
    required String approvalId,
  }) async {
    await _cv.mutation('family:revokeApproval', {
      'guardianId': guardianId,
      'approvalId': approvalId,
    });
  }

  /// Whitelists [username] for a child: a standing pre-approval that skips
  /// this guardian's hop in the relay from now on, in both directions. Not a
  /// friendship — the other person still has to accept.
  ///
  /// With [sendRequestNow] the request is also fired on the child's behalf,
  /// entering the relay at whatever hop the pre-approval just unlocked.
  /// Returns whether a request actually went out (false when they were
  /// already connected, or one was already in flight).
  Future<bool> allowContactByUsername({
    required String guardianId,
    required String childId,
    required String username,
    bool sendRequestNow = false,
  }) async {
    final res = await _cv.mutation('family:allowContactByUsername', {
      'guardianId': guardianId,
      'childId': childId,
      'username': username,
      if (sendRequestNow) 'sendRequestNow': true,
    });
    final map = (res as Map?)?.cast<String, dynamic>() ?? const {};
    return (map['requested'] as bool?) ?? false;
  }

  /// Links up a family created before auto-friending existed. Idempotent —
  /// safe to call on every family-screen load.
  Future<void> backfillFamilyFriendships(String guardianId) async {
    await _cv.mutation('family:backfillFamilyFriendships', {
      'guardianId': guardianId,
    });
  }

  /// What removing this contact would destroy. Call before confirming — the
  /// removal itself is unconditional and total.
  Future<ContactRemovalPreview> previewContactRemoval({
    required String guardianId,
    required String childId,
    required String contactUserId,
  }) async {
    final res = await _cv.query('family:previewContactRemoval', {
      'guardianId': guardianId,
      'childId': childId,
      'contactUserId': contactUserId,
    });
    return ContactRemovalPreview.fromJson(
      (res as Map?)?.cast<String, dynamic>() ?? const {},
    );
  }

  /// Severs the contact AND wipes every DM the pair share — messages,
  /// reactions, and media, for both of them. Not reversible.
  Future<void> revokeContact({
    required String guardianId,
    required String childId,
    required String contactUserId,
  }) async {
    await _cv.mutation('family:revokeContact', {
      'guardianId': guardianId,
      'childId': childId,
      'contactUserId': contactUserId,
    });
  }

  Future<List<PendingApproval>> listMyApprovals(String childId) async {
    final res = await _cv.query('family:listMyApprovals', {'childId': childId});
    return ((res as List?) ?? const [])
        .map((e) => PendingApproval.fromJson((e as Map).cast<String, dynamic>()))
        .toList();
  }

  Future<ChildGrants> listChildGrants({
    required String guardianId,
    required String childId,
  }) async {
    final res = await _cv.query('family:listChildGrants', {
      'guardianId': guardianId,
      'childId': childId,
    });
    return ChildGrants.fromJson(
      (res as Map?)?.cast<String, dynamic>() ?? const {},
    );
  }

  /// Only the flags you pass are touched.
  Future<ChildPolicy> setChildPolicy({
    required String guardianId,
    required String childId,
    bool? publicRoomsEnabled,
    bool? callsEnabled,
    bool? mediaEnabled,
    bool? canRequestContacts,
    bool? canCreateRooms,
  }) async {
    final res = await _cv.mutation('family:setChildPolicy', {
      'guardianId': guardianId,
      'childId': childId,
      'publicRoomsEnabled': ?publicRoomsEnabled,
      'callsEnabled': ?callsEnabled,
      'mediaEnabled': ?mediaEnabled,
      'canRequestContacts': ?canRequestContacts,
      'canCreateRooms': ?canCreateRooms,
    });
    return ChildPolicy.fromJson((res as Map).cast<String, dynamic>());
  }

  Future<void> unlinkChild({
    required String guardianId,
    required String childId,
  }) async {
    await _cv.mutation('family:unlinkChild', {
      'guardianId': guardianId,
      'childId': childId,
    });
  }

  Future<void> promoteToAdult({
    required String guardianId,
    required String childId,
    required String password,
  }) async {
    await _cv.mutation('family:promoteToAdult', {
      'guardianId': guardianId,
      'childId': childId,
      'passwordHash': sha256Hash(password),
    });
  }

  Future<void> deleteChildAccount({
    required String guardianId,
    required String childId,
  }) async {
    await _cv.mutation('family:deleteChildAccount', {
      'guardianId': guardianId,
      'childId': childId,
    });
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Files
  // ─────────────────────────────────────────────────────────────────────────

  Future<String> generateUploadUrl() async {
    final res = await _cv.mutation('files:generateUploadUrl', const {});
    return res.toString();
  }

  /// The serving URL for [storageId], or null when there isn't one.
  ///
  /// Nullable because the backend query is: `files:getFileUrl` returns null for
  /// a view-once file and for an id whose blob has been swept. This used to be
  /// a bare `res.toString()`, and `null.toString()` is the four-character
  /// string "null" — which every caller then treated as a URL, handed to a
  /// player or an image loader, and persisted in [FileUrlCache] for the life of
  /// the install.
  Future<String?> getFileUrl(String storageId) async {
    final res = await _cv.query('files:getFileUrl', {'storageId': storageId});
    if (res == null) return null;
    final url = res.toString();
    return url.isEmpty ? null : url;
  }

  // No deleteFile: freeing a stored file is the server's job, done in the same
  // mutation that drops the reference (users:updateAvatar, rooms:deleteRoom,
  // messages:deleteMessage, …). The old `files:deleteFile` endpoint let any
  // client delete any file given its id, and nothing ever called it.

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

  // ─────────────────────────────────────────────────────────────────────────
  // Releases
  // ─────────────────────────────────────────────────────────────────────────

  /// The latest build published for one distribution channel, or null when
  /// nothing has been published for it yet.
  ///
  /// Unauthenticated on the backend on purpose — the update check runs before
  /// the session is restored, so it works on the login screen too.
  Future<AppRelease?> latestRelease(String channel) async {
    final res = await _cv.query('releases:latest', {'channel': channel});
    if (res == null) return null;
    return AppRelease.fromJson((res as Map).cast<String, dynamic>());
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
