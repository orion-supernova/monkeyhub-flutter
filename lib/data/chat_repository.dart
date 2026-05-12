import 'dart:async';

import 'package:flutter/foundation.dart';

import '../backend/chat_api.dart';
import '../backend/convex_client.dart';
import '../models/chat_message.dart';
import '../models/chat_room.dart';
import '../models/chat_user.dart';
import '../models/enums.dart';
import '../models/friend_request.dart';
import 'cache_store.dart';

/// Source of truth for chat data (rooms + open-room messages).
///
/// Mirrors v02's `ChatRepository` SSOT pattern. Owns:
///   - rooms list (subscription-driven)
///   - per-room cached message lists
///   - active subscriptions (rooms; messages of currently open room)
///   - optimistic pending sends
class ChatRepository extends ChangeNotifier {
  ChatRepository({required this.api, required this.cv});

  final ChatApi api;
  final ConvexBackend cv;

  String? _userId;
  String? get userId => _userId;

  List<ChatRoom> _rooms = [];
  List<ChatRoom> get rooms => List.unmodifiable(_rooms);

  /// Lookup a user by id from any cached source the repo currently knows
  /// (friends list). Returns null when the user isn't cached — callers may
  /// fall back to a placeholder.
  ChatUser? userById(String id) {
    for (final u in _friends) {
      if (u.id == id) return u;
    }
    return null;
  }

  /// For a DM room, returns the other participant's user if cached.
  ChatUser? otherUserFor(ChatRoom room) {
    if (!room.isDm) return null;
    final myId = _userId;
    if (myId == null) return null;
    final otherId = room.otherParticipantId(myId);
    if (otherId == null) return null;
    return userById(otherId);
  }

  List<ChatUser> _friends = [];
  List<ChatUser> get friends => List.unmodifiable(_friends);

  List<FriendRequest> _incomingRequests = [];
  List<FriendRequest> get incomingRequests => List.unmodifiable(_incomingRequests);

  List<FriendRequest> _outgoingRequests = [];
  List<FriendRequest> get outgoingRequests => List.unmodifiable(_outgoingRequests);

  final Map<String, List<ChatMessage>> _messages = {}; // roomId → ordered list
  final Map<String, List<ChatMessage>> _pending = {}; // optimistic messages

  // Map of roomId → list of typing-user display names (other users only).
  final Map<String, List<String>> _typingByRoom = {};
  List<String> typingIn(String roomId) =>
      List.unmodifiable(_typingByRoom[roomId] ?? const []);

  Subscription? _roomsSub;
  Subscription? _friendsSub;
  Subscription? _incomingSub;
  Subscription? _outgoingSub;
  Subscription? _globalTypingSub;
  String? _activeRoomId;
  Subscription? _messagesSub;
  Subscription? _activeTypingSub;
  Timer? _typingHeartbeat;
  bool _typingActive = false;

  // ───────────── lifecycle ─────────────

  Future<void> attach(String userId) async {
    _userId = userId;
    // 1) Hydrate from disk so the first frame already shows last-known state
    //    even if we're cold-booting offline. This is cheap (~ms) and the
    //    live subscriptions will overwrite as they connect.
    try {
      final cachedRooms = await CacheStore.instance.loadRooms(userId);
      if (cachedRooms.isNotEmpty) {
        _rooms = cachedRooms;
        notifyListeners();
      }
    } catch (_) {}

    // 2) Seed from a single API hit before subscriptions take over.
    try {
      _rooms = await api.listUserRooms(userId);
      CacheStore.instance.scheduleSaveRooms(userId, _rooms);
    } catch (_) {/* network down; cached rooms remain visible */}
    try {
      _friends = await api.listFriends(userId);
    } catch (_) {}
    try {
      _incomingRequests = await api.listIncomingDirectRequests(userId);
    } catch (_) {}
    try {
      _outgoingRequests = await api.listOutgoingDirectRequests(userId);
    } catch (_) {}
    notifyListeners();

    _roomsSub?.cancel();
    _friendsSub?.cancel();
    _incomingSub?.cancel();
    _outgoingSub?.cancel();

    _roomsSub = await cv.subscribe(
      'rooms:listUserRooms',
      {'userId': userId},
      onData: (data) {
        final list = (data as List?) ?? const [];
        _rooms = list
            .map((e) => ChatRoom.fromJson((e as Map).cast<String, dynamic>()))
            .toList();
        CacheStore.instance.scheduleSaveRooms(userId, _rooms);
        notifyListeners();
      },
      onError: (err) => debugPrint('rooms sub error: $err'),
    );

    _friendsSub = await cv.subscribe(
      'friends:listFriends',
      {'userId': userId},
      onData: (data) {
        final list = (data as List?) ?? const [];
        _friends = list
            .map((e) => ChatUser.fromJson((e as Map).cast<String, dynamic>()))
            .toList();
        notifyListeners();
      },
      onError: (err) => debugPrint('friends sub error: $err'),
    );

    _incomingSub = await cv.subscribe(
      'friends:listIncomingDirectRequests',
      {'userId': userId},
      onData: (data) {
        final list = (data as List?) ?? const [];
        _incomingRequests = list
            .map((e) => FriendRequest.fromJson((e as Map).cast<String, dynamic>()))
            .toList();
        notifyListeners();
      },
      onError: (err) => debugPrint('incoming sub error: $err'),
    );

    _outgoingSub = await cv.subscribe(
      'friends:listOutgoingDirectRequests',
      {'userId': userId},
      onData: (data) {
        final list = (data as List?) ?? const [];
        _outgoingRequests = list
            .map((e) => FriendRequest.fromJson((e as Map).cast<String, dynamic>()))
            .toList();
        notifyListeners();
      },
      onError: (err) => debugPrint('outgoing sub error: $err'),
    );

    // Global typing — used to surface a thin indicator on room cards.
    _globalTypingSub = await cv.subscribe(
      'typing:getTypingForUser',
      {'userId': userId},
      onData: (data) {
        _typingByRoom.clear();
        if (data is Map) {
          data.forEach((roomId, names) {
            if (names is List) {
              _typingByRoom[roomId.toString()] =
                  names.map((e) => e.toString()).toList();
            }
          });
        }
        notifyListeners();
      },
      onError: (err) => debugPrint('typing(global) sub error: $err'),
    );
  }

  Future<void> detach() async {
    _roomsSub?.cancel();
    _friendsSub?.cancel();
    _incomingSub?.cancel();
    _outgoingSub?.cancel();
    _globalTypingSub?.cancel();
    _messagesSub?.cancel();
    _activeTypingSub?.cancel();
    _typingHeartbeat?.cancel();
    _roomsSub = null;
    _friendsSub = null;
    _incomingSub = null;
    _outgoingSub = null;
    _globalTypingSub = null;
    _messagesSub = null;
    _activeTypingSub = null;
    _typingHeartbeat = null;
    _activeRoomId = null;
    _userId = null;
    _rooms = [];
    _friends = [];
    _incomingRequests = [];
    _outgoingRequests = [];
    _messages.clear();
    _pending.clear();
    _typingByRoom.clear();
    notifyListeners();
  }

  // ───────────── rooms ─────────────

  ChatRoom? roomById(String id) {
    for (final r in _rooms) {
      if (r.id == id) return r;
    }
    return null;
  }

  Future<String> createRoom({
    required String name,
    required bool isPrivate,
    String? description,
    String? password,
    RoomType type = RoomType.regular,
    Duration? messageLifetime,
  }) async {
    final id = _userId;
    if (id == null) throw StateError('Not signed in');
    return api.createRoom(
      userId: id,
      name: name,
      isPrivate: isPrivate,
      description: description,
      password: password,
      type: type,
      messageLifetime: messageLifetime,
    );
    // Subscription will deliver the new room on the next tick.
  }

  Future<void> joinRoom({required String roomId, String? password}) async {
    final id = _userId;
    if (id == null) return;
    await api.joinRoom(roomId: roomId, userId: id, password: password);
  }

  Future<void> leaveRoom(String roomId) async {
    final id = _userId;
    if (id == null) return;
    await api.leaveRoom(roomId: roomId, userId: id);
  }

  // ───────────── messages ─────────────

  List<ChatMessage> messagesFor(String roomId) {
    final live = _messages[roomId] ?? const [];
    final pend = _pending[roomId] ?? const [];
    if (pend.isEmpty) return live;
    final merged = [...live, ...pend];
    merged.sort((a, b) => a.createdAt.compareTo(b.createdAt));
    return merged;
  }

  Future<void> openRoom(String roomId) async {
    if (_activeRoomId == roomId) return;
    _activeRoomId = roomId;
    _messagesSub?.cancel();
    _activeTypingSub?.cancel();
    final me = _userId;
    // Hydrate from disk first for an instant render.
    if (me != null && (_messages[roomId] == null || _messages[roomId]!.isEmpty)) {
      try {
        final cached = await CacheStore.instance.loadMessages(me, roomId);
        if (cached.isNotEmpty) {
          _messages[roomId] = cached;
          notifyListeners();
        }
      } catch (_) {}
    }
    try {
      _messages[roomId] = await api.listMessages(roomId: roomId);
      if (me != null) {
        CacheStore.instance.scheduleSaveMessages(me, roomId, _messages[roomId]!);
      }
    } catch (_) {/* offline — cached messages remain */}
    _pending[roomId] ??= [];
    notifyListeners();
    _messagesSub = await cv.subscribe(
      'messages:list',
      {'roomId': roomId, 'limit': 100},
      onData: (data) {
        final list = (data as List?) ?? const [];
        final parsed = list
            .map((e) => ChatMessage.fromJson((e as Map).cast<String, dynamic>()))
            .toList();
        _messages[roomId] = parsed;
        _reconcilePending(roomId);
        if (me != null) {
          CacheStore.instance.scheduleSaveMessages(me, roomId, parsed);
        }
        notifyListeners();
      },
      onError: (err) => debugPrint('messages sub error: $err'),
    );
    final id = _userId;
    if (id != null) {
      _activeTypingSub = await cv.subscribe(
        'typing:getTypingUsers',
        {'roomId': roomId, 'currentUserId': id},
        onData: (data) {
          final list = (data as List?) ?? const [];
          _typingByRoom[roomId] = list
              .map((e) => ((e as Map)['name'] ?? '').toString())
              .where((s) => s.isNotEmpty)
              .toList();
          notifyListeners();
        },
        onError: (err) => debugPrint('typing(room) sub error: $err'),
      );
    }
  }

  void closeRoom() {
    _stopTyping();
    _messagesSub?.cancel();
    _activeTypingSub?.cancel();
    _messagesSub = null;
    _activeTypingSub = null;
    _activeRoomId = null;
    _loadingOlder.clear();
    _exhausted.clear();
  }

  // ───────────── pagination ─────────────

  final Set<String> _loadingOlder = {};
  final Set<String> _exhausted = {};

  bool isLoadingOlder(String roomId) => _loadingOlder.contains(roomId);
  bool hasMoreOlder(String roomId) => !_exhausted.contains(roomId);

  /// Fetches a page of messages older than the earliest one we have. Returns
  /// the number of newly-prepended messages. Idempotent if a page is already
  /// loading; no-op when [hasMoreOlder] returns false.
  Future<int> loadOlder(String roomId, {int pageSize = 40}) async {
    if (_loadingOlder.contains(roomId)) return 0;
    if (_exhausted.contains(roomId)) return 0;
    final cur = _messages[roomId] ?? const [];
    if (cur.isEmpty) return 0;
    _loadingOlder.add(roomId);
    notifyListeners();
    try {
      final earliest = cur.first.createdAt;
      final older = await api.listBefore(
        roomId: roomId,
        before: earliest,
        limit: pageSize,
      );
      if (older.isEmpty) {
        _exhausted.add(roomId);
        return 0;
      }
      // Dedupe by id in case backend page boundary overlaps.
      final seen = {for (final m in cur) m.id};
      final fresh = older.where((m) => !seen.contains(m.id)).toList()
        ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
      _messages[roomId] = [...fresh, ...cur];
      if (older.length < pageSize) _exhausted.add(roomId);
      return fresh.length;
    } catch (_) {
      return 0;
    } finally {
      _loadingOlder.remove(roomId);
      notifyListeners();
    }
  }

  // ───────────── typing heartbeat ─────────────

  /// Call on each keystroke. Sends `typing:setTyping` immediately, then
  /// re-pings every 2s while [keepAlive] keeps being called. Schedule a
  /// final `clearTyping` 3s after the last call.
  void noteTyping() {
    final id = _userId;
    final roomId = _activeRoomId;
    if (id == null || roomId == null) return;
    if (!_typingActive) {
      _typingActive = true;
      api.setTyping(roomId: roomId, userId: id).catchError((_) {});
      _typingHeartbeat?.cancel();
      _typingHeartbeat = Timer.periodic(const Duration(seconds: 2), (_) {
        api.setTyping(roomId: roomId, userId: id).catchError((_) {});
      });
    }
    // Reset the idle timer: stop typing 3s after the most recent keystroke.
    _scheduleStopTyping();
  }

  Timer? _stopTypingTimer;
  void _scheduleStopTyping() {
    _stopTypingTimer?.cancel();
    _stopTypingTimer = Timer(const Duration(seconds: 3), _stopTyping);
  }

  void _stopTyping() {
    _stopTypingTimer?.cancel();
    _typingHeartbeat?.cancel();
    _stopTypingTimer = null;
    _typingHeartbeat = null;
    if (!_typingActive) return;
    _typingActive = false;
    final id = _userId;
    final roomId = _activeRoomId;
    if (id != null && roomId != null) {
      api.clearTyping(roomId: roomId, userId: id).catchError((_) {});
    }
  }

  Future<void> sendText(String roomId, String text) async {
    return _send(roomId: roomId, content: text, type: MessageType.text);
  }

  Future<void> sendMedia({
    required String roomId,
    required String storageId,
    required MessageType type,
    String? caption,
  }) async {
    return _send(
      roomId: roomId,
      content: caption ?? '',
      type: type,
      mediaStorageId: storageId,
    );
  }

  Future<void> _send({
    required String roomId,
    required String content,
    required MessageType type,
    String? mediaStorageId,
  }) async {
    final id = _userId;
    if (id == null) return;
    final tempId = 'tmp_${DateTime.now().microsecondsSinceEpoch}';
    final optimistic = ChatMessage(
      id: tempId,
      roomId: roomId,
      senderId: id,
      senderName: '',
      content: content,
      type: type,
      mediaStorageId: mediaStorageId,
      createdAt: DateTime.now(),
      status: MessageStatus.pending,
    );
    _pending.putIfAbsent(roomId, () => []).add(optimistic);
    notifyListeners();
    try {
      await api.sendMessage(
        roomId: roomId,
        userId: id,
        content: content,
        type: type,
        mediaStorageId: mediaStorageId,
      );
    } catch (_) {
      optimistic.status = MessageStatus.error;
      notifyListeners();
    }
  }

  Future<void> deleteMessage(String messageId) async {
    final id = _userId;
    if (id == null) return;
    await api.deleteMessage(messageId: messageId, userId: id);
  }

  // ───────────── reactions ─────────────

  Future<void> toggleReaction({
    required String messageId,
    required String emoji,
  }) async {
    final id = _userId;
    if (id == null) return;
    // Determine current state from cached message.
    bool mineExists = false;
    for (final list in _messages.values) {
      for (final m in list) {
        if (m.id == messageId) {
          mineExists = m.reactions.any((r) => r.userId == id && r.emoji == emoji);
          break;
        }
      }
    }
    try {
      if (mineExists) {
        await api.removeReaction(messageId: messageId, userId: id, emoji: emoji);
      } else {
        await api.addReaction(messageId: messageId, userId: id, emoji: emoji);
      }
    } catch (_) {/* swallow — live subscription will reconcile */}
  }

  // ───────────── friends + direct requests ─────────────

  Future<String> createDirectRequest({
    required String friendId,
    required RoomType roomType,
    Duration? messageLifetime,
    String? initialMessage,
  }) async {
    final id = _userId;
    if (id == null) throw StateError('Not signed in');
    return api.createDirectRequest(
      userId: id,
      friendId: friendId,
      roomType: roomType,
      messageLifetime: messageLifetime,
      initialMessage: initialMessage,
    );
  }

  Future<String?> approveDirectRequest(String requesterId) async {
    final id = _userId;
    if (id == null) return null;
    return api.approveDirectRequest(userId: id, requesterId: requesterId);
  }

  Future<void> rejectDirectRequest(String requesterId) async {
    final id = _userId;
    if (id == null) return;
    await api.rejectDirectRequest(userId: id, requesterId: requesterId);
  }

  Future<void> cancelDirectRequest(String friendId) async {
    final id = _userId;
    if (id == null) return;
    await api.cancelDirectRequest(userId: id, friendId: friendId);
  }

  Future<void> removeFriend(String friendId) async {
    final id = _userId;
    if (id == null) return;
    await api.removeFriend(userId: id, friendId: friendId);
  }

  Future<String> openDmWith(ChatUser friend, {
    RoomType roomType = RoomType.regular,
    Duration? messageLifetime,
  }) async {
    final id = _userId;
    if (id == null) throw StateError('Not signed in');
    return api.getOrCreateDM(
      userId: id,
      friendId: friend.id,
      roomType: roomType,
      messageLifetime: messageLifetime,
    );
  }

  Future<void> appendDirectRequestMessage({
    required String requestId,
    required String content,
  }) async {
    final id = _userId;
    if (id == null) return;
    await api.appendDirectRequestMessage(requestId: requestId, userId: id, content: content);
  }

  /// Drop optimistic pending messages that the server now confirms exist.
  /// Match by (senderId, content, createdAt within 30s).
  void _reconcilePending(String roomId) {
    final pend = _pending[roomId];
    if (pend == null || pend.isEmpty) return;
    final live = _messages[roomId] ?? const [];
    pend.removeWhere((p) {
      return live.any((l) =>
          l.senderId == p.senderId &&
          l.content == p.content &&
          (l.createdAt.difference(p.createdAt).inSeconds).abs() < 30);
    });
  }
}
