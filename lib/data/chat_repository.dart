import 'dart:async';

import 'package:flutter/foundation.dart';

import '../backend/chat_api.dart';
import '../backend/convex_client.dart';
import '../models/chat_message.dart';
import '../models/chat_room.dart';
import '../models/chat_user.dart';
import '../models/enums.dart';
import '../models/family.dart';
import '../models/friend_request.dart';
import '../push/push_manager.dart';
import 'cache_store.dart';
import 'settings_store.dart';

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

  /// Number of rooms with messages newer than this user's read cursor.
  int get unreadRoomCount => _rooms.where((r) => r.hasUnread).length;

  /// Total unread *messages* across every room — drives the Chat tab / ROOMS
  /// pill badge and, via [BadgeManager], the OS app-icon badge. Counts
  /// messages rather than rooms so it matches what the push payload's
  /// absolute `ios_badgeCount` says.
  int get unreadMessageTotal =>
      _rooms.fold(0, (sum, r) => sum + r.unreadCount);

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
  // Newest message id we've seen per room. Used to dedup [markRoomRead]
  // when the `messages:list` subscription refires for non-message reasons
  // (e.g. a reaction add/remove) so we don't trip a roomMembers patch →
  // four-subscription cascade.
  final Map<String, String?> _lastSeenNewestMsgId = {};

  // Map of roomId → the users currently typing there, from the global
  // subscription. NAME-ONLY: `typing:getTypingForUser` returns bare strings,
  // so these carry no id and no avatar. Good enough for the room list, which
  // renders a label.
  final Map<String, List<ChatUser>> _typingByRoom = {};

  // The open room's typists, from `typing:getTypingUsers` — full [ChatUser]s
  // with avatarStorageId, which is what the in-room indicator needs to draw
  // real faces.
  //
  // Held apart from [_typingByRoom] rather than written into it: both
  // subscriptions fire on the same keystroke, the global one rebuilds its
  // whole map from scratch, and whichever landed last won. Half the time that
  // was the name-only stream, which is why the in-room avatars kept falling
  // back to initials.
  String? _openTypingRoomId;
  List<ChatUser> _openTypingUsers = const [];

  List<ChatUser> typingIn(String roomId) => List.unmodifiable(
        // The room's own subscription is authoritative for the room it covers,
        // including when it says nobody is typing.
        roomId == _openTypingRoomId
            ? _openTypingUsers
            : (_typingByRoom[roomId] ?? const []),
      );

  Subscription? _roomsSub;
  Subscription? _friendsSub;
  Subscription? _incomingSub;
  Subscription? _outgoingSub;
  Subscription? _globalTypingSub;
  String? _activeRoomId;
  /// The room currently visible to the user (if any). Used by [PushManager] to
  /// suppress incoming-message notifications for the chat already on screen.
  String? get activeRoomId => _activeRoomId;
  Subscription? _messagesSub;
  Subscription? _activeTypingSub;
  Subscription? _readStateSub;
  Timer? _typingHeartbeat;
  bool _typingActive = false;
  StreamSubscription<bool>? _connStateSub;
  bool _wasConnected = true;

  /// Read state for the currently-open room: userId → lastReadAt.
  final Map<String, DateTime> _activeReadState = {};

  /// The latest `lastReadAt` of any user other than me in the current room.
  /// Used to render the "SEEN" indicator on my own messages. Returns null
  /// when the local "view read receipts" preference is off, suppressing the
  /// indicator regardless of what the server delivers.
  DateTime? get latestOthersReadAt {
    if (!SettingsStore.instance.viewReadReceipts) return null;
    final me = _userId;
    DateTime? best;
    for (final entry in _activeReadState.entries) {
      if (entry.key == me) continue;
      if (best == null || entry.value.isAfter(best)) best = entry.value;
    }
    return best;
  }

  // ───────────── lifecycle ─────────────

  void _onSettingsChanged() {
    // Only the view-read-receipts flag affects this repo's outputs. A bool
    // flip changes what [latestOthersReadAt] returns even though the cached
    // [_activeReadState] hasn't moved, so we have to nudge listeners.
    notifyListeners();
  }

  Future<void> attach(String userId) async {
    _userId = userId;
    // Re-emit when the local "view read receipts" pref flips so any open
    // chat screen rebuilds and the SEEN indicator appears/disappears live.
    SettingsStore.instance.removeListener(_onSettingsChanged);
    SettingsStore.instance.addListener(_onSettingsChanged);
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
              // This stream carries names only — the room list renders a
              // label, not avatars. Wrapped in a name-only [ChatUser] so the
              // shared typing widgets take one type regardless of which
              // subscription filled the map. [typingIn] prefers the open
              // room's richer entry over anything written here.
              _typingByRoom[roomId.toString()] = names
                  .map((e) => e.toString())
                  .where((s) => s.isNotEmpty)
                  .map((n) => ChatUser(id: '', username: '', name: n))
                  .toList();
            }
          });
        }
        notifyListeners();
      },
      onError: (err) => debugPrint('typing(global) sub error: $err'),
    );

    // Auto-retry failed sends on socket reconnect. When the user is in a
    // tunnel and a send hits an `error` state, the message often actually
    // reached the server before the socket dropped — but we don't know that
    // locally. On reconnect we both retry (in case it didn't make it) and
    // rely on the widened [_reconcilePending] window to dedupe against the
    // server-delivered copy. See [_retryPendingErrors].
    _wasConnected = cv.isConnected;
    _connStateSub?.cancel();
    _connStateSub = cv.connectionState.listen((connected) {
      if (connected && !_wasConnected) {
        _retryPendingErrors();
      }
      _wasConnected = connected;
    });
  }

  Future<void> detach() async {
    SettingsStore.instance.removeListener(_onSettingsChanged);
    _roomsSub?.cancel();
    _friendsSub?.cancel();
    _incomingSub?.cancel();
    _outgoingSub?.cancel();
    _globalTypingSub?.cancel();
    _messagesSub?.cancel();
    _activeTypingSub?.cancel();
    _typingHeartbeat?.cancel();
    _connStateSub?.cancel();
    _roomsSub = null;
    _friendsSub = null;
    _incomingSub = null;
    _outgoingSub = null;
    _globalTypingSub = null;
    _messagesSub = null;
    _activeTypingSub = null;
    _typingHeartbeat = null;
    _connStateSub = null;
    _activeRoomId = null;
    _userId = null;
    _rooms = [];
    _friends = [];
    _incomingRequests = [];
    _outgoingRequests = [];
    _messages.clear();
    _pending.clear();
    _lastSeenNewestMsgId.clear();
    _typingByRoom.clear();
    _openTypingRoomId = null;
    _openTypingUsers = const [];
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
    _readStateSub?.cancel();
    // Dropped here rather than beside the new subscription below: several
    // awaits separate the two, and until then the old room would keep serving
    // whoever was typing in it when we left.
    _openTypingRoomId = null;
    _openTypingUsers = const [];
    _activeReadState.clear();
    _initialLoaded.remove(roomId);
    final me = _userId;
    // Hydrate from disk first for an instant render.
    if (me != null && (_messages[roomId] == null || _messages[roomId]!.isEmpty)) {
      try {
        final cached = await CacheStore.instance.loadMessages(me, roomId);
        if (cached.isNotEmpty) {
          _messages[roomId] = cached;
          _initialLoaded.add(roomId);
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
    _initialLoaded.add(roomId);
    // Prime the dedup baseline with the newest message we already loaded, so
    // the first onData fire (which echoes the same set) doesn't fire a
    // redundant markRoomRead.
    _lastSeenNewestMsgId[roomId] = _messages[roomId]?.isNotEmpty == true
        ? _messages[roomId]!.last.id
        : null;
    notifyListeners();
    _messagesSub = await cv.subscribe(
      'messages:list',
      {'roomId': roomId, 'limit': 100},
      onData: (data) {
        final list = (data as List?) ?? const [];
        final parsed = list
            .map((e) => ChatMessage.fromJson((e as Map).cast<String, dynamic>()))
            .toList();
        // Re-attach any pages the user scrolled back through. A bare
        // `_messages[roomId] = parsed` would drop them: this subscription
        // refires on every reaction add/remove too, so a single reaction
        // used to collapse the room back to the newest 100 and — because
        // `_exhausted` isn't reset here — permanently kill `hasMoreOlder`.
        _messages[roomId] = _withOlderPrefix(roomId, parsed);
        _reconcilePending(roomId);
        if (me != null) {
          CacheStore.instance.scheduleSaveMessages(me, roomId, parsed);
          // Only mark-read when a NEW message has actually arrived since the
          // last fire. `messages:list` also refires on reaction add/remove
          // and (legacy) any user-doc change — those shouldn't trigger a
          // mutation that cascades into roomMembers and four other queries.
          final newestId = parsed.isNotEmpty ? parsed.last.id : null;
          if (newestId != null && newestId != _lastSeenNewestMsgId[roomId]) {
            _lastSeenNewestMsgId[roomId] = newestId;
            api.markRoomRead(roomId: roomId, userId: me).catchError((_) {});
            // Reading it means its notifications are spent. Done locally
            // rather than waiting for the server's silent dismiss push, which
            // is best-effort and can't reach a force-quit app at all.
            PushManager.instance.dismissRoomNotifications(roomId);
          }
        }
        notifyListeners();
      },
      onError: (err) => debugPrint('messages sub error: $err'),
    );

    if (me != null) {
      _readStateSub = await cv.subscribe(
        'messages:getReadState',
        {'roomId': roomId, 'viewerUserId': me},
        onData: (data) {
          final list = (data as List?) ?? const [];
          _activeReadState.clear();
          for (final e in list) {
            final m = (e as Map).cast<String, dynamic>();
            final uid = m['userId'].toString();
            final ts = (m['lastReadAt'] as num?)?.toInt() ?? 0;
            _activeReadState[uid] = DateTime.fromMillisecondsSinceEpoch(ts);
          }
          notifyListeners();
        },
        onError: (err) => debugPrint('readState sub error: $err'),
      );
    }

    // Mark the room read on entry too.
    if (me != null) {
      api.markRoomRead(roomId: roomId, userId: me).catchError((_) {});
      PushManager.instance.dismissRoomNotifications(roomId);
    }
    final id = _userId;
    if (id != null) {
      _openTypingRoomId = roomId;
      _activeTypingSub = await cv.subscribe(
        'typing:getTypingUsers',
        {'roomId': roomId, 'currentUserId': id},
        onData: (data) {
          final list = (data as List?) ?? const [];
          _openTypingUsers = list
              .whereType<Map>()
              .map((e) => ChatUser.fromJson(e.cast<String, dynamic>()))
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
    _readStateSub?.cancel();
    _messagesSub = null;
    _activeTypingSub = null;
    _readStateSub = null;
    _activeRoomId = null;
    // Hand the room back to the global stream's name-only entry.
    _openTypingRoomId = null;
    _openTypingUsers = const [];
    _activeReadState.clear();
    _loadingOlder.clear();
    _exhausted.clear();
    _olderPrefix.clear();
    _clearHistoryWindows();
  }

  /// Whether the first batch of messages (cache or server) has landed for
  /// [roomId]. Lets the UI show a loading state instead of the empty-state
  /// placeholder during the initial fetch.
  bool hasLoadedInitial(String roomId) => _initialLoaded.contains(roomId);

  final Set<String> _initialLoaded = {};

  // ───────────── pagination ─────────────

  final Set<String> _loadingOlder = {};
  final Set<String> _exhausted = {};

  /// Pages fetched by [loadOlder], kept separately from `_messages` so the
  /// `messages:list` subscription can rebuild its 100-message live window
  /// without discarding scrolled-back history. Oldest first. Cleared by
  /// [closeRoom] alongside `_loadingOlder` / `_exhausted`.
  final Map<String, List<ChatMessage>> _olderPrefix = {};

  /// Splices the retained older pages in front of a fresh live window,
  /// keeping only entries strictly older than the window and dropping any
  /// the window now covers itself.
  List<ChatMessage> _withOlderPrefix(String roomId, List<ChatMessage> live) {
    final prefix = _olderPrefix[roomId];
    if (prefix == null || prefix.isEmpty) return live;
    if (live.isEmpty) return List<ChatMessage>.from(prefix);
    final oldestLive = live.first.createdAt;
    final liveIds = {for (final m in live) m.id};
    final kept = prefix
        .where((m) => m.createdAt.isBefore(oldestLive) && !liveIds.contains(m.id))
        .toList();
    if (kept.isEmpty) return live;
    return [...kept, ...live];
  }

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
      // Retain the page so the next subscription fire can splice it back in.
      _olderPrefix[roomId] = [...fresh, ...(_olderPrefix[roomId] ?? const [])];
      if (older.length < pageSize) _exhausted.add(roomId);
      return fresh.length;
    } catch (_) {
      return 0;
    } finally {
      _loadingOlder.remove(roomId);
      notifyListeners();
    }
  }

  // ───────────── history window (jump to an old message) ─────────────
  //
  // Tapping a reply tether whose parent predates everything we hold can't be
  // served by `loadOlder`: the parent may be thousands of messages back, and
  // paging there 40 at a time is both slow and pointless — the reader doesn't
  // want the gap, they want the message.
  //
  // So `jumpToMessage` fetches a window *centred* on the message and shows
  // that instead of the live tail. The window is a detached but internally
  // contiguous slice: never spliced into `_messages`, because there is a hole
  // between the two and a hole would render as messages silently missing.
  // Scrolling up extends the window with `listBefore`; scrolling down extends
  // it with `listAfter` until it reaches the live tail, at which point the two
  // halves are contiguous and merge back — the reader has caught up to the
  // present and the window quietly stops existing.
  //
  // Only the room transcript reads through `timelineFor`. Threads, read
  // receipts and the cache keep reading `messagesFor`, so nothing else in the
  // app can observe that the transcript is looking at history.

  final Map<String, List<ChatMessage>> _historyWindow = {};
  final Set<String> _windowExhaustedOlder = {};
  final Set<String> _windowExhaustedNewer = {};
  final Set<String> _loadingWindow = {};

  /// True while the transcript is showing detached history rather than the
  /// live tail — the room screen offers a "jump to latest" affordance for it.
  bool inHistoryWindow(String roomId) => _historyWindow.containsKey(roomId);

  /// What the room transcript should render: the history window when one is
  /// open, the live list otherwise.
  List<ChatMessage> timelineFor(String roomId) =>
      _historyWindow[roomId] ?? messagesFor(roomId);

  bool isLoadingTimeline(String roomId) =>
      _loadingWindow.contains(roomId) || _loadingOlder.contains(roomId);

  bool hasMoreOlderTimeline(String roomId) =>
      _historyWindow.containsKey(roomId)
          ? !_windowExhaustedOlder.contains(roomId)
          : hasMoreOlder(roomId);

  /// Drop back to the live tail, discarding the window. The window's messages
  /// are deliberately *not* retained: they aren't contiguous with the live
  /// list, so keeping them would put a hole in the transcript.
  void exitHistoryWindow(String roomId) {
    if (_historyWindow.remove(roomId) == null) return;
    _windowExhaustedOlder.remove(roomId);
    _windowExhaustedNewer.remove(roomId);
    notifyListeners();
  }

  void _clearHistoryWindows() {
    _historyWindow.clear();
    _windowExhaustedOlder.clear();
    _windowExhaustedNewer.clear();
    _loadingWindow.clear();
  }

  /// Make [messageId] renderable in [roomId]'s transcript, fetching a window
  /// of history around it if it isn't loaded. Returns false only when the
  /// message can't be had at all (deleted, wrong room, or offline).
  Future<bool> jumpToMessage(String roomId, String messageId) async {
    final win = _historyWindow[roomId];
    if (win != null) {
      if (win.any((m) => m.id == messageId)) return true;
    } else if (findMessageInRoom(roomId, messageId) != null) {
      return true;
    }
    if (_loadingWindow.contains(roomId)) return false;
    _loadingWindow.add(roomId);
    notifyListeners();
    try {
      final page = await api.listAround(
        roomId: roomId,
        messageId: messageId,
        before: 30,
        after: 30,
      );
      if (!page.found || page.messages.isEmpty) return false;

      final live = _messages[roomId] ?? const <ChatMessage>[];
      final liveIds = {for (final m in live) m.id};
      // If the window already touches the live tail there's no hole to keep
      // apart — splice it into the room's own history and stay in live mode.
      final touchesTail =
          !page.hasMoreNewer || page.messages.any(liveIds.contains);
      if (live.isEmpty) {
        _messages[roomId] = page.messages;
        if (!page.hasMoreOlder) _exhausted.add(roomId);
        _historyWindow.remove(roomId);
        return true;
      }
      if (touchesTail) {
        final oldest = live.first.createdAt;
        final prefix = page.messages
            .where((m) => !liveIds.contains(m.id) && m.createdAt.isBefore(oldest))
            .toList()
          ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
        if (prefix.isNotEmpty) {
          _messages[roomId] = [...prefix, ...live];
          _olderPrefix[roomId] = [
            ...prefix,
            ...(_olderPrefix[roomId] ?? const <ChatMessage>[]),
          ];
          if (!page.hasMoreOlder) _exhausted.add(roomId);
        }
        _historyWindow.remove(roomId);
        _windowExhaustedOlder.remove(roomId);
        _windowExhaustedNewer.remove(roomId);
        return true;
      }

      _historyWindow[roomId] = page.messages;
      _windowExhaustedOlder.remove(roomId);
      _windowExhaustedNewer.remove(roomId);
      if (!page.hasMoreOlder) _windowExhaustedOlder.add(roomId);
      if (!page.hasMoreNewer) _windowExhaustedNewer.add(roomId);
      return true;
    } catch (_) {
      return false;
    } finally {
      _loadingWindow.remove(roomId);
      notifyListeners();
    }
  }

  /// Older page for whatever the transcript is currently showing.
  Future<int> loadOlderTimeline(String roomId, {int pageSize = 40}) async {
    final win = _historyWindow[roomId];
    if (win == null) return loadOlder(roomId, pageSize: pageSize);
    if (_loadingWindow.contains(roomId)) return 0;
    if (_windowExhaustedOlder.contains(roomId) || win.isEmpty) return 0;
    _loadingWindow.add(roomId);
    notifyListeners();
    try {
      final older = await api.listBefore(
        roomId: roomId,
        before: win.first.createdAt,
        limit: pageSize,
      );
      // The window can be closed while the page is in flight.
      final cur = _historyWindow[roomId];
      if (cur == null) return 0;
      if (older.length < pageSize) _windowExhaustedOlder.add(roomId);
      final seen = {for (final m in cur) m.id};
      final fresh = older.where((m) => !seen.contains(m.id)).toList()
        ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
      if (fresh.isEmpty) return 0;
      _historyWindow[roomId] = [...fresh, ...cur];
      return fresh.length;
    } catch (_) {
      return 0;
    } finally {
      _loadingWindow.remove(roomId);
      notifyListeners();
    }
  }

  /// Newer page, extending the window back toward the present. Once it
  /// reaches the newest message the live list holds, the two are contiguous
  /// and the window is merged away — done here rather than on first overlap
  /// so the bottom of the transcript never moves under the reader.
  Future<int> loadNewerTimeline(String roomId, {int pageSize = 40}) async {
    final win = _historyWindow[roomId];
    if (win == null || win.isEmpty) return 0;
    if (_loadingWindow.contains(roomId)) return 0;
    if (_windowExhaustedNewer.contains(roomId)) {
      _mergeHistoryWindow(roomId);
      return 0;
    }
    _loadingWindow.add(roomId);
    notifyListeners();
    try {
      final newer = await api.listAfter(
        roomId: roomId,
        after: win.last.createdAt,
        limit: pageSize,
      );
      final cur = _historyWindow[roomId];
      if (cur == null) return 0;
      if (newer.length < pageSize) _windowExhaustedNewer.add(roomId);
      final seen = {for (final m in cur) m.id};
      final fresh = newer.where((m) => !seen.contains(m.id)).toList()
        ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
      final all = fresh.isEmpty ? cur : <ChatMessage>[...cur, ...fresh];
      _historyWindow[roomId] = all;

      final live = _messages[roomId] ?? const <ChatMessage>[];
      final reachedTail =
          live.isNotEmpty && all.any((m) => m.id == live.last.id);
      if (reachedTail || _windowExhaustedNewer.contains(roomId)) {
        _mergeHistoryWindow(roomId);
      }
      return fresh.length;
    } catch (_) {
      return 0;
    } finally {
      _loadingWindow.remove(roomId);
      notifyListeners();
    }
  }

  /// Fold an open window back into the room's history. Only called once the
  /// window's newest message is the live list's newest too, so the transcript
  /// keeps rendering exactly the same rows at exactly the same offsets.
  void _mergeHistoryWindow(String roomId) {
    final win = _historyWindow.remove(roomId);
    _windowExhaustedOlder.remove(roomId);
    _windowExhaustedNewer.remove(roomId);
    if (win == null || win.isEmpty) return;
    final live = _messages[roomId] ?? const <ChatMessage>[];
    if (live.isEmpty) {
      _messages[roomId] = win;
      return;
    }
    final liveIds = {for (final m in live) m.id};
    final oldest = live.first.createdAt;
    final prefix = win
        .where((m) => !liveIds.contains(m.id) && m.createdAt.isBefore(oldest))
        .toList()
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
    if (prefix.isEmpty) return;
    _messages[roomId] = [...prefix, ...live];
    _olderPrefix[roomId] = [
      ...prefix,
      ...(_olderPrefix[roomId] ?? const <ChatMessage>[]),
    ];
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

  Future<void> sendText(String roomId, String text, {String? replyToId}) async {
    return _send(
      roomId: roomId,
      content: text,
      type: MessageType.text,
      replyToId: replyToId,
    );
  }

  Future<void> sendMedia({
    required String roomId,
    required String storageId,
    required MessageType type,
    String? caption,
    String? replyToId,
  }) async {
    return _send(
      roomId: roomId,
      content: caption ?? '',
      type: type,
      mediaStorageId: storageId,
      replyToId: replyToId,
    );
  }

  /// Locate a message by id within a room's live and pending caches.
  /// Used by the UI to (a) build a local [ReplyPreview] for optimistic
  /// sends and (b) resolve the parent when the user taps a reply tether.
  ChatMessage? findMessageInRoom(String roomId, String id) {
    for (final m in _messages[roomId] ?? const <ChatMessage>[]) {
      if (m.id == id) return m;
    }
    for (final m in _pending[roomId] ?? const <ChatMessage>[]) {
      if (m.id == id) return m;
    }
    return null;
  }

  // ───────────── threads ─────────────
  //
  // A thread is read as two halves that get merged on every build:
  //
  //   1. Pages fetched from `messages:getThreadPage`, kept in `_threadPages`.
  //      Static snapshots — they never update after the fetch.
  //   2. The room's own live message list, filtered to the thread. Every
  //      thread message is also a room message, so this gives live arrivals,
  //      reaction updates, deletions and optimistic `tmp_` bubbles for free.
  //
  // Half 2 is why there's no second Convex subscription for threads:
  // `resubscribe()` only replays the fixed set of room-scoped subscriptions,
  // so an overlay-owned one would go permanently dead after a socket
  // reconnect with no recovery path.
  //
  // The honest limit: only the newest ~100 room messages are live, so thread
  // messages older than that window are frozen snapshots. That's the same
  // guarantee the room screen itself gives.

  final Map<String, List<ChatMessage>> _threadPages = {};
  final Set<String> _loadingThread = {};
  final Set<String> _threadExhausted = {};
  final Set<String> _threadLoaded = {};

  bool isLoadingThread(String rootId) => _loadingThread.contains(rootId);
  bool hasMoreThread(String rootId) => !_threadExhausted.contains(rootId);

  /// Whether at least one page for [rootId] has come back from the server.
  /// Tracked separately from `_threadPages` because a legitimately empty
  /// first page (every thread message already live in the room window) still
  /// counts as loaded — the overlay must stop showing a spinner.
  bool hasLoadedThread(String rootId) => _threadLoaded.contains(rootId);

  /// Every message in the thread rooted at [rootId], oldest first, merged
  /// from fetched pages and the room's live list and deduped by id.
  ///
  /// Live entries win over page snapshots for the same id — a page is a
  /// point-in-time copy, the live list has current reactions and status.
  List<ChatMessage> threadFor(String roomId, String rootId) {
    final byId = <String, ChatMessage>{};
    for (final m in _threadPages[rootId] ?? const <ChatMessage>[]) {
      byId[m.id] = m;
    }
    for (final m in messagesFor(roomId)) {
      if (m.threadKey == rootId) byId[m.id] = m;
    }
    final merged = byId.values.toList()
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
    return merged;
  }

  /// Begin a thread session. Clears any state from a previous open so a
  /// stale `_threadExhausted` entry can't suppress paging.
  void openThread(String rootId) {
    _threadPages.remove(rootId);
    _threadExhausted.remove(rootId);
    _loadingThread.remove(rootId);
    _threadLoaded.remove(rootId);
  }

  void closeThread(String rootId) {
    _threadPages.remove(rootId);
    _threadExhausted.remove(rootId);
    _loadingThread.remove(rootId);
    _threadLoaded.remove(rootId);
  }

  /// Fetches the next older page of the thread rooted at [rootId]. Returns
  /// the number of newly-prepended messages. Idempotent while a page is in
  /// flight; a no-op once [hasMoreThread] is false.
  Future<int> loadOlderThread({
    required String roomId,
    required String rootId,
    int pageSize = 25,
  }) async {
    if (_loadingThread.contains(rootId)) return 0;
    if (_threadExhausted.contains(rootId)) return 0;
    final me = _userId;
    if (me == null) return 0;
    _loadingThread.add(rootId);
    notifyListeners();
    try {
      // Cursor off the merged view, not just `_threadPages` — otherwise the
      // first call after a live message arrives would refetch a page the
      // room subscription already gave us.
      final cur = threadFor(roomId, rootId);
      final page = await api.getThreadPage(
        roomId: roomId,
        rootId: rootId,
        viewerUserId: me,
        before: cur.isEmpty ? null : cur.first.createdAt,
        limit: pageSize,
      );
      _threadLoaded.add(rootId);
      if (!page.hasMore) _threadExhausted.add(rootId);
      if (page.messages.isEmpty) return 0;
      final existing = _threadPages[rootId] ?? const <ChatMessage>[];
      final seen = {for (final m in existing) m.id};
      final fresh = page.messages.where((m) => !seen.contains(m.id)).toList();
      if (fresh.isEmpty) return 0;
      _threadPages[rootId] = [...fresh, ...existing]
        ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
      return fresh.length;
    } catch (_) {
      // Mark loaded but NOT exhausted: the overlay needs to stop spinning
      // and fall back to whatever the room's live list already has, while
      // a scroll can still retry — a transient failure shouldn't disable
      // paging for the rest of the session.
      _threadLoaded.add(rootId);
      return 0;
    } finally {
      _loadingThread.remove(rootId);
      notifyListeners();
    }
  }

  Future<void> _send({
    required String roomId,
    required String content,
    required MessageType type,
    String? mediaStorageId,
    String? replyToId,
  }) async {
    final id = _userId;
    if (id == null) return;

    // Build a local [ReplyPreview] from the cached parent so the inline
    // tether is visible on the pending bubble before the server confirms
    // the send. If the parent isn't cached (rare — to swipe-reply you have
    // to see the bubble), we drop the replyToId on the optimistic message
    // but still attempt the send with it (the server resolves the parent).
    ReplyPreview? optimisticPreview;
    // Thread membership for the pending bubble, resolved from the same
    // cached parent. Without it the optimistic message wouldn't match
    // `threadFor`'s filter and would be invisible in an open thread view
    // until the server echo arrived.
    String? optimisticRootId;
    if (replyToId != null) {
      final parent = findMessageInRoom(roomId, replyToId);
      if (parent != null) {
        final preview = parent.content.length > 140
            ? parent.content.substring(0, 140)
            : parent.content;
        optimisticPreview = ReplyPreview(
          senderId: parent.senderId,
          senderName: parent.senderName,
          contentPreview: preview,
          type: parent.type,
          mediaStorageId: parent.mediaStorageId,
        );
        optimisticRootId = parent.threadKey;
      }
    }

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
      replyToId: optimisticPreview != null ? replyToId : null,
      replyToPreview: optimisticPreview,
      rootId: optimisticPreview != null ? optimisticRootId : null,
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
        replyToId: replyToId,
      );
    } catch (e) {
      // A child guard rejection is not a transient failure, so it must not
      // sit in the pending list waiting to be retried forever — the retry
      // would fail identically until a guardian acts. Drop the optimistic
      // bubble and surface it so the composer can explain.
      if (isChildGateError(e)) {
        _pending[roomId]?.removeWhere((m) => m.id == tempId);
        _lastChildGateError = e.toString();
        notifyListeners();
        return;
      }
      optimistic.status = MessageStatus.error;
      notifyListeners();
    }
  }

  /// Set when the last send was refused by a child guard, so the room screen
  /// can show the "ask a grown-up" sheet instead of a silent failure.
  /// Read-and-clear: consuming it resets the flag.
  String? _lastChildGateError;
  String? takeChildGateError() {
    final e = _lastChildGateError;
    _lastChildGateError = null;
    return e;
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
  /// Match by (senderId, content, createdAt within 10 minutes). The window is
  /// generous so that a metro-tunnel send — where the server received the
  /// message but the client got marked `error` because the ack never made it
  /// — collapses into a single bubble once reconnect delivers the live row.
  void _reconcilePending(String roomId) {
    final pend = _pending[roomId];
    if (pend == null || pend.isEmpty) return;
    final live = _messages[roomId] ?? const [];
    pend.removeWhere((p) {
      return live.any((l) =>
          l.senderId == p.senderId &&
          l.content == p.content &&
          (l.createdAt.difference(p.createdAt).inMinutes).abs() < 10);
    });
  }

  /// Iterate every room's optimistic queue and re-send anything still in
  /// `error`. Triggered on socket reconnect. The bubble flips back to
  /// `pending` (rendered as "SENDING") so the user sees the in-place
  /// retry; on success the live subscription delivers the server copy and
  /// [_reconcilePending] removes the optimistic. On a second failure the
  /// bubble returns to `error` and waits for the next reconnect or a manual
  /// resend.
  Future<void> _retryPendingErrors() async {
    final id = _userId;
    if (id == null) return;
    final retryList = <(String, ChatMessage)>[];
    for (final entry in _pending.entries) {
      for (final m in entry.value) {
        if (m.status == MessageStatus.error) {
          retryList.add((entry.key, m));
        }
      }
    }
    if (retryList.isEmpty) return;
    // Flip every target back to pending first so the UI batches a single
    // "SENDING" frame instead of one per send.
    for (final (_, m) in retryList) {
      m.status = MessageStatus.pending;
    }
    notifyListeners();
    for (final (roomId, m) in retryList) {
      try {
        await api.sendMessage(
          roomId: roomId,
          userId: id,
          content: m.content,
          type: m.type,
          mediaStorageId: m.mediaStorageId,
          replyToId: m.replyToId,
        );
        // Leave as pending — the messages:list subscription will deliver the
        // server-confirmed copy and _reconcilePending will drop this one.
      } catch (_) {
        m.status = MessageStatus.error;
        notifyListeners();
      }
    }
  }

  /// Re-establish every subscription after a socket reconnect. The convex_flutter
  /// web client resets its query set on reconnect but NEVER replays the
  /// subscriptions, so rooms/messages/typing/friends/read-state all go silent
  /// (the client thinks it's subscribed; the server sends nothing). Re-runs the
  /// top-level subs via [attach] and, if a room is open, re-registers its
  /// message/read/typing subs by re-opening it. Then flushes stuck sends.
  Future<void> resubscribe() async {
    final uid = _userId;
    if (uid == null) return;
    final open = _activeRoomId;
    await attach(uid); // cancels + recreates rooms/friends/typing subs
    if (open != null) {
      _activeRoomId = null; // clear openRoom()'s same-room short-circuit
      await openRoom(open); // recreates messages/read/typing subs for the room
    }
    await flushPending();
  }

  /// Retry optimistic sends stuck at pending/error — e.g. a message issued while
  /// the socket was frozen whose ack never arrived. [_reconcilePending]'s
  /// ±10-minute window collapses any duplicate the server already stored.
  Future<void> flushPending() async {
    final id = _userId;
    if (id == null) return;
    final retry = <(String, ChatMessage)>[];
    for (final entry in _pending.entries) {
      for (final m in entry.value) {
        if (m.status == MessageStatus.pending ||
            m.status == MessageStatus.error) {
          retry.add((entry.key, m));
        }
      }
    }
    if (retry.isEmpty) return;
    for (final (_, m) in retry) {
      m.status = MessageStatus.pending;
    }
    notifyListeners();
    for (final (roomId, m) in retry) {
      try {
        await api.sendMessage(
          roomId: roomId,
          userId: id,
          content: m.content,
          type: m.type,
          mediaStorageId: m.mediaStorageId,
          replyToId: m.replyToId,
        );
      } catch (_) {
        m.status = MessageStatus.error;
        notifyListeners();
      }
    }
  }
}
