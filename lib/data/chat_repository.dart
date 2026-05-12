import 'dart:async';

import 'package:flutter/foundation.dart';

import '../backend/chat_api.dart';
import '../backend/convex_client.dart';
import '../models/chat_message.dart';
import '../models/chat_room.dart';
import '../models/enums.dart';

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

  final Map<String, List<ChatMessage>> _messages = {}; // roomId → ordered list
  final Map<String, List<ChatMessage>> _pending = {}; // optimistic messages

  Subscription? _roomsSub;
  String? _activeRoomId;
  Subscription? _messagesSub;

  // ───────────── lifecycle ─────────────

  Future<void> attach(String userId) async {
    _userId = userId;
    _rooms = await api.listUserRooms(userId);
    notifyListeners();
    _roomsSub?.cancel();
    _roomsSub = await cv.subscribe(
      'rooms:listUserRooms',
      {'userId': userId},
      onData: (data) {
        final list = (data as List?) ?? const [];
        _rooms = list
            .map((e) => ChatRoom.fromJson((e as Map).cast<String, dynamic>()))
            .toList();
        notifyListeners();
      },
      onError: (err) => debugPrint('rooms sub error: $err'),
    );
  }

  Future<void> detach() async {
    _roomsSub?.cancel();
    _messagesSub?.cancel();
    _roomsSub = null;
    _messagesSub = null;
    _activeRoomId = null;
    _userId = null;
    _rooms = [];
    _messages.clear();
    _pending.clear();
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
    _messages[roomId] = await api.listMessages(roomId: roomId);
    _pending[roomId] = [];
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
        notifyListeners();
      },
      onError: (err) => debugPrint('messages sub error: $err'),
    );
  }

  void closeRoom() {
    _messagesSub?.cancel();
    _messagesSub = null;
    _activeRoomId = null;
  }

  Future<void> sendText(String roomId, String text) async {
    final id = _userId;
    if (id == null) return;
    final tempId = 'tmp_${DateTime.now().microsecondsSinceEpoch}';
    final optimistic = ChatMessage(
      id: tempId,
      roomId: roomId,
      senderId: id,
      senderName: '',
      content: text,
      createdAt: DateTime.now(),
      status: MessageStatus.pending,
    );
    _pending.putIfAbsent(roomId, () => []).add(optimistic);
    notifyListeners();
    try {
      await api.sendMessage(roomId: roomId, userId: id, content: text);
      // The live subscription will deliver the server-side row; _reconcile
      // removes the optimistic version when it sees a matching pair.
    } catch (e) {
      optimistic.status = MessageStatus.error;
      notifyListeners();
    }
  }

  Future<void> deleteMessage(String messageId) async {
    final id = _userId;
    if (id == null) return;
    await api.deleteMessage(messageId: messageId, userId: id);
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
