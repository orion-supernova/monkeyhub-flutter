import 'dart:async';

import 'package:flutter/foundation.dart';

import '../backend/chat_api.dart';
import '../backend/convex_client.dart';
import '../media/upload_service.dart';
import '../models/chat_message.dart';
import '../models/chat_room.dart';
import '../models/chat_user.dart';
import '../models/enums.dart';
import '../models/family.dart';
import '../models/friend_request.dart';
import '../models/pending_upload.dart';
import '../push/push_manager.dart';
import 'cache_store.dart';
import 'pending_reconcile.dart';
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

  /// Whoever asked for the open room — the `RoomScreen` state that called
  /// [openRoom]. [closeRoom] only tears the room down for THIS holder.
  ///
  /// An opaque token rather than a roomId because the two screens are
  /// sometimes for the SAME room: a push tap for the chat already on screen
  /// mounts a second `RoomScreen` before the first one is disposed, so a
  /// roomId comparison would match and let the departing screen close the
  /// room its replacement is now serving.
  Object? _openOwner;

  /// Bumped by [openRoom], [closeRoom] and [detach]. An open that started
  /// before the bump has been superseded and must not publish the
  /// subscriptions it is still awaiting.
  int _openGen = 0;
  Subscription? _messagesSub;
  Subscription? _activeTypingSub;
  Subscription? _readStateSub;
  Timer? _typingHeartbeat;
  bool _typingActive = false;

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

    // 2) Seed from parallel API hits before subscriptions take over.
    try {
      final results = await Future.wait<dynamic>([
        api.listUserRooms(userId).catchError((_) => <ChatRoom>[]),
        api.listFriends(userId).catchError((_) => <ChatUser>[]),
        api.listIncomingDirectRequests(userId).catchError((_) => <FriendRequest>[]),
        api.listOutgoingDirectRequests(userId).catchError((_) => <FriendRequest>[]),
      ]);
      final roomsResult = results[0] as List<ChatRoom>;
      if (roomsResult.isNotEmpty) {
        _rooms = roomsResult;
        CacheStore.instance.scheduleSaveRooms(userId, _rooms);
      }
      final friendsResult = results[1] as List<ChatUser>;
      if (friendsResult.isNotEmpty) _friends = friendsResult;
      _incomingRequests = results[2] as List<FriendRequest>;
      _outgoingRequests = results[3] as List<FriendRequest>;
    } catch (_) {/* network down; cached rooms/friends remain visible */}
    notifyListeners();

    // All five, and nulled immediately — [attach] is re-entrant (resubscribe()
    // calls it), and the global typing handle used to be missing from this
    // block while still being reassigned below. Every reconnect therefore left
    // one live `typing:getTypingForUser` subscription behind with no handle to
    // cancel it, so the query set grew by one per reconnect and every
    // subsequent replay cost more than the last.
    _roomsSub?.cancel();
    _friendsSub?.cancel();
    _incomingSub?.cancel();
    _outgoingSub?.cancel();
    _globalTypingSub?.cancel();
    _roomsSub = null;
    _friendsSub = null;
    _incomingSub = null;
    _outgoingSub = null;
    _globalTypingSub = null;

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

    // Stuck sends used to be retried from a raw `cv.connectionState` listener
    // here — a second, independent reconnect trigger with none of
    // [ConnectionHealth]'s verification. convex-rs toggles connecting/connected
    // on every lap of its own internal backoff, so it fired on laps that were
    // not reconnects at all, re-posting messages against a socket that had not
    // come back. [ConnectionHealth] owns that edge now, and it hands it to
    // [flushPending], of which the old handler was a strict subset.
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
    // Signing out has to take this one with it too: left live, it keeps
    // writing the previous account's read receipts into `_activeReadState`
    // for whoever signs in next.
    _readStateSub?.cancel();
    _typingHeartbeat?.cancel();
    _roomsSub = null;
    _friendsSub = null;
    _incomingSub = null;
    _outgoingSub = null;
    _globalTypingSub = null;
    _messagesSub = null;
    _activeTypingSub = null;
    _readStateSub = null;
    _typingHeartbeat = null;
    _activeRoomId = null;
    _openOwner = null;
    // Any open still in flight belongs to the account being signed out.
    _openGen++;
    _userId = null;
    _rooms = [];
    _friends = [];
    _incomingRequests = [];
    _outgoingRequests = [];
    _messages.clear();
    // Abort and release anything still going up. Signing out has to take the
    // bytes with it: they are one user's unsent photos, and the next account to
    // sign in on this device has no business holding them in memory — quite
    // apart from the megabytes.
    for (final list in _pending.values) {
      for (final m in list) {
        m.upload?.dispose();
      }
    }
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

  /// Whether the signed-in user is already a member of [roomId].
  ///
  /// `_rooms` IS the membership list — it's fed by the `rooms:listUserRooms`
  /// subscription, so this stays correct the moment a join or leave lands, with
  /// no extra round trip. Discover and search both branch on this to open a
  /// joined room directly instead of re-running the join flow against it.
  ///
  /// Returns false during the pre-hydration window on a cold start; prefer
  /// [isJoined], which also consults the server's answer.
  bool isMemberOf(String roomId) => roomById(roomId) != null;

  /// The membership rule Discover and search branch on before deciding whether
  /// to open [room] or run the join flow against it.
  ///
  /// Two sources because neither alone is complete: [isMemberOf] is live but
  /// empty until the room subscription delivers, while [ChatRoom.isMember] is
  /// a snapshot from `rooms:listPublic` that goes stale the moment you join
  /// something. Either saying yes is enough.
  bool isJoined(ChatRoom room) => isMemberOf(room.id) || room.isMember;

  @visibleForTesting
  void debugSeedRooms(List<ChatRoom> rooms) => _rooms = List.of(rooms);

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

  /// Makes [roomId] the open room: drops the previous room's subscriptions,
  /// loads its transcript, and registers messages / read-state / typing.
  ///
  /// [owner] is the token that will later hand the room back via [closeRoom] —
  /// pass the `State` doing the opening. Ownership transfers even when this
  /// short-circuits on an already-open room, so re-entering the chat you are
  /// already in (a push tap for the room on screen) leaves the NEW screen
  /// holding it and makes the old screen's `dispose` a no-op.
  ///
  /// [force] re-registers the subscriptions of an already-open room without
  /// disturbing ownership or blanking [activeRoomId] — [resubscribe]'s case
  /// after a reconnect.
  Future<void> openRoom(String roomId, {Object? owner, bool force = false}) async {
    // Before the short-circuit on purpose: a second screen for the room
    // already open still has to take ownership, or the first screen's dispose
    // will close the room out from under it.
    if (owner != null) _openOwner = owner;
    if (_activeRoomId == roomId && !force) return;
    if (_activeRoomId != roomId) {
      // The room being left still has a typing heartbeat and a pending clear,
      // both of which read `_activeRoomId` when they fire — so stop it here,
      // while that still means the OLD room. [closeRoom] can no longer be
      // relied on for this: on a superseded screen it is now a no-op, and
      // before the ownership guard existed it was clearing typing in the room
      // the user had just ENTERED.
      _stopTyping();
    }
    final gen = ++_openGen;
    _activeRoomId = roomId;
    _messagesSub?.cancel();
    _activeTypingSub?.cancel();
    _readStateSub?.cancel();
    // Nulled immediately, not just reassigned at the end: this open can now
    // bail at any of the `gen` checks below, and [closeRoom] would otherwise
    // find and re-cancel a handle that is already dead.
    _messagesSub = null;
    _activeTypingSub = null;
    _readStateSub = null;
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
      _messages[roomId] = await api.listMessages(roomId: roomId, viewerUserId: me);
      if (me != null) {
        CacheStore.instance.scheduleSaveMessages(me, roomId, _messages[roomId]!);
      }
    } catch (_) {/* offline — cached messages remain */}
    // Superseded while reading disk / fetching: bail before registering
    // anything. Nothing is dangling yet — no subscription has been created,
    // and everything written above is keyed by `roomId`, so a late write
    // can't corrupt whichever room won.
    if (gen != _openGen) return;
    _pending[roomId] ??= [];
    _initialLoaded.add(roomId);
    // Prime the dedup baseline with the newest message we already loaded, so
    // the first onData fire (which echoes the same set) doesn't fire a
    // redundant markRoomRead.
    _lastSeenNewestMsgId[roomId] = _messages[roomId]?.isNotEmpty == true
        ? _messages[roomId]!.last.id
        : null;
    notifyListeners();
    final messagesSub = await cv.subscribe(
      'messages:list',
      // `viewerUserId` widens the subscription's read set by this viewer's OWN
      // view-once ledger rows and nothing else, which is deliberate: opening a
      // photo on another device refires this query here (so the bubble greys
      // out live) without refiring it for anybody else in the room.
      {'roomId': roomId, 'limit': 100, 'viewerUserId': ?me},
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
    if (gen != _openGen) {
      // A newer open (or a [closeRoom]) landed while this one was
      // registering. Publishing the handle would wire the room actually on
      // screen to the wrong query, with nobody holding a handle to cancel it.
      messagesSub.cancel();
      return;
    }
    _messagesSub = messagesSub;

    if (me != null) {
      final readStateSub = await cv.subscribe(
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
      if (gen != _openGen) {
        // Not merely wasteful: this one's onData clears and refills
        // `_activeReadState`, which is NOT keyed by room, so a stale copy
        // would paint the old room's read receipts on the new room's bubbles.
        readStateSub.cancel();
        return;
      }
      _readStateSub = readStateSub;
    }

    // Mark the room read on entry too.
    if (me != null) {
      api.markRoomRead(roomId: roomId, userId: me).catchError((_) {});
      PushManager.instance.dismissRoomNotifications(roomId);
    }
    final id = _userId;
    if (id != null) {
      final typingSub = await cv.subscribe(
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
      if (gen != _openGen) {
        typingSub.cancel();
        return;
      }
      // Below the await, not above it: `_openTypingRoomId` is the key
      // [typingIn] branches on, so claiming it for a room that then lost the
      // race serves the wrong room's typists.
      _openTypingRoomId = roomId;
      _activeTypingSub = typingSub;
    }
  }

  /// Hands the open room back. [owner] must be the token that opened it (see
  /// [openRoom]); any other caller is a no-op.
  ///
  /// The guard is the whole point. Route transitions dispose the OUTGOING room
  /// screen long after the incoming one has already called [openRoom]: a push
  /// tap runs an animated `popUntil` and then a synchronous `push`
  /// (app.dart's `_openRoomFromPush`), so the old screen's dispose lands ~300ms
  /// into the new room's life; the desktop two-pane keeps the outgoing
  /// `RoomScreen` mounted for the whole `AnimatedSwitcher` fade
  /// (home_shell.dart's `_ChatTwoPane`); and a resize reconciliation pops the
  /// stale route a frame later still. Unconditional teardown therefore
  /// cancelled the subscriptions of the room the user was now looking at and
  /// cleared [activeRoomId] underneath it — which is why push banners kept
  /// firing for the chat on screen, and in the worst case why that room went
  /// live-message-dead until it was re-entered.
  ///
  /// Mirrors the identity guard `_RoomScreenState.dispose` already applies to
  /// its `UiSelectionStore` clear.
  void closeRoom(Object owner) {
    if (!identical(_openOwner, owner)) return;
    _openOwner = null;
    // An open still in flight for this same owner (backed out before its
    // subscriptions landed) must not publish them after the teardown, or the
    // room closes with live subscriptions nobody holds a handle to.
    _openGen++;
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
        viewerUserId: _userId,
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
        viewerUserId: _userId,
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
        viewerUserId: _userId,
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
        viewerUserId: _userId,
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

  Future<void> sendText(
    String roomId,
    String text, {
    String? replyToId,
    List<MessageMention> mentions = const [],
    bool mentionsEveryone = false,
  }) async {
    return _send(
      roomId: roomId,
      content: text,
      type: MessageType.text,
      replyToId: replyToId,
      mentions: mentions,
      mentionsEveryone: mentionsEveryone,
    );
  }

  Future<void> sendMedia({
    required String roomId,
    required String storageId,
    required MessageType type,
    String? caption,
    String? replyToId,
    /// Pixel size of the attachment when the sender measured it. Carried so the
    /// receiving bubble lays out at the picture's own ratio immediately, and so
    /// the *sender's* optimistic bubble does too — without it the photo you just
    /// sent is the one photo in the room that has to settle into shape.
    double? mediaWidth,
    double? mediaHeight,
    /// Burn-after-reading photo. Carried into the optimistic bubble too, or the
    /// sender would watch their own picture sit in the transcript until the ack
    /// arrived and replaced it with a sealed tile.
    bool viewOnce = false,
  }) async {
    return _send(
      roomId: roomId,
      content: caption ?? '',
      type: type,
      mediaStorageId: storageId,
      // The server drops these for an armed send — the sealed tile is a fixed
      // size and the real ratio is a leak — so don't let the optimistic bubble
      // claim otherwise either.
      mediaWidth: viewOnce ? null : mediaWidth,
      mediaHeight: viewOnce ? null : mediaHeight,
      replyToId: replyToId,
      viewOnce: viewOnce,
    );
  }

  /// Spends this viewer's one look at a view-once photo and returns a ticket.
  ///
  /// Marks the local copy opened on success so the bubble greys out without
  /// waiting for the subscription to come back around. The server is the
  /// authority either way — a stale local `false` just means the user taps and
  /// is told no.
  Future<({String? nonce, bool alreadyViewed, bool gone})> openViewOnce({
    required String roomId,
    required String messageId,
  }) async {
    final id = _userId;
    if (id == null) return (nonce: null, alreadyViewed: false, gone: true);
    final res = await api.openViewOnce(messageId: messageId, userId: id);
    if (res.nonce != null || res.alreadyViewed) {
      _markViewOnceOpenedLocally(roomId, messageId);
    }
    return res;
  }

  void _markViewOnceOpenedLocally(String roomId, String messageId) {
    final list = _messages[roomId];
    if (list == null) return;
    final i = list.indexWhere((m) => m.id == messageId);
    if (i < 0 || list[i].viewOnceOpened) return;
    list[i] = list[i].copyWith(viewOnceOpened: true);
    notifyListeners();
  }

  /// The URL that streams the bytes for a ticket from [openViewOnce].
  Uri viewOnceStreamUrl({required String messageId, required String nonce}) =>
      ChatApi.viewOnceStreamUrl(
        messageId: messageId,
        userId: _userId ?? '',
        nonce: nonce,
      );

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
    double? mediaWidth,
    double? mediaHeight,
    String? replyToId,
    bool viewOnce = false,
    List<MessageMention> mentions = const [],
    bool mentionsEveryone = false,
  }) async {
    final optimistic = _buildOptimistic(
      roomId: roomId,
      content: content,
      type: type,
      mediaStorageId: mediaStorageId,
      mediaWidth: mediaWidth,
      mediaHeight: mediaHeight,
      replyToId: replyToId,
      viewOnce: viewOnce,
      mentions: mentions,
      mentionsEveryone: mentionsEveryone,
    );
    if (optimistic == null) return;
    _pending.putIfAbsent(roomId, () => []).add(optimistic);
    notifyListeners();
    await _postMessage(roomId, optimistic);
  }

  /// Builds the bubble that stands in for a message until the server confirms it,
  /// and returns null when there is nobody signed in to send as.
  ///
  /// Split out of [_send] so an attachment can have its bubble on screen *before*
  /// its bytes have finished uploading — which is the whole point of
  /// [sendMediaLocal]. [_postMessage] is the other half.
  ChatMessage? _buildOptimistic({
    required String roomId,
    required String content,
    required MessageType type,
    String? mediaStorageId,
    double? mediaWidth,
    double? mediaHeight,
    String? replyToId,
    bool viewOnce = false,
    MessageStatus status = MessageStatus.pending,
    PendingUpload? upload,
    List<MessageMention> mentions = const [],
    bool mentionsEveryone = false,
  }) {
    final id = _userId;
    if (id == null) return null;

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
          // Match the sentinel `messages:send` will denormalize server-side, so
          // the optimistic tether doesn't render one thing and then flip to
          // another when the ack lands. (`parent.mediaStorageId` is already
          // null on a view-once parent — the server never sent it — so this is
          // about the label, not about leaking the id.)
          senderId: parent.senderId,
          senderName: parent.senderName,
          contentPreview: parent.viewOnce ? '__VIEW_ONCE__' : preview,
          type: parent.type,
          mediaStorageId: parent.viewOnce ? null : parent.mediaStorageId,
        );
        optimisticRootId = parent.threadKey;
      }
    }

    final tempId = 'tmp_${DateTime.now().microsecondsSinceEpoch}';
    return ChatMessage(
      id: tempId,
      roomId: roomId,
      senderId: id,
      senderName: '',
      content: content,
      type: type,
      mediaStorageId: mediaStorageId,
      mediaWidth: mediaWidth,
      mediaHeight: mediaHeight,
      createdAt: DateTime.now(),
      status: status,
      replyToId: optimisticPreview != null ? replyToId : null,
      replyToPreview: optimisticPreview,
      rootId: optimisticPreview != null ? optimisticRootId : null,
      viewOnce: viewOnce,
      upload: upload,
      // Carried on the pending bubble so the sender's own mention is
      // highlighted the instant they hit send, rather than flatly for the
      // round-trip and then lighting up when the echo lands. The server may
      // still drop one it refuses; the echo replaces this copy with the truth.
      mentions: mentions,
      mentionsEveryone: mentionsEveryone,
    );
  }

  /// Posts [optimistic] to the server, reading every argument off the message.
  ///
  /// Reading off the message rather than taking them again as parameters is what
  /// lets this one function serve the first attempt *and* both reconnect
  /// sweepers, which used to carry their own near-identical copies of this call —
  /// three places that had to be kept in step, and twice already hadn't been.
  Future<void> _postMessage(String roomId, ChatMessage optimistic) async {
    final id = _userId;
    if (id == null) return;
    try {
      final serverId = await api.sendMessage(
        roomId: roomId,
        userId: id,
        content: optimistic.content,
        type: optimistic.type,
        mediaStorageId: optimistic.mediaStorageId,
        mediaWidth: optimistic.mediaWidth,
        mediaHeight: optimistic.mediaHeight,
        replyToId: optimistic.replyToId,
        // Must ride along, or a view-once photo that happened to be sent while
        // the socket was frozen comes back as an ordinary, permanent one — the
        // flag dropped on the retry rather than on the send the user made.
        viewOnce: optimistic.viewOnce,
        // Read off the message for exactly the same reason: a retry that
        // dropped these would deliver the text "@bob" to a Bob who is never
        // told about it. Storing them on the bubble is what gets both reconnect
        // sweepers this for free.
        mentionedUserIds: [for (final m in optimistic.mentions) m.userId],
        mentionsEveryone: optimistic.mentionsEveryone,
        // The bubble's own local id, which is stable across every retry of this
        // message — that stability is the entire mechanism. Two attempts at the
        // same send carry the same key and collapse to one row; two genuinely
        // different sends never share one.
        clientId: optimistic.id,
      );
      // The ack is proof, so stop drawing "sending". The bubble stays in the
      // pending list — the live copy is still what carries reactions, read
      // state and the real id — but it is now marked `sent`, which is what
      // [_reconcilePending] matches on by id and what keeps [flushPending] and
      // [_retryPendingErrors] (both of which only touch pending/error) from
      // posting it a second time.
      //
      // Waiting for the subscription instead is what left this bubble spinning
      // on web while the recipient's phone already had the message: the socket
      // had been rebuilt underneath us and the query set never replayed, so the
      // echo that was supposed to clear it was never coming.
      if (optimistic.status != MessageStatus.error) {
        optimistic.serverId = serverId;
        optimistic.status = MessageStatus.sent;
        notifyListeners();
      }
    } catch (e) {
      // A child guard rejection is not a transient failure, so it must not
      // sit in the pending list waiting to be retried forever — the retry
      // would fail identically until a guardian acts. Drop the optimistic
      // bubble and surface it so the composer can explain.
      if (isChildGateError(e)) {
        _pending[roomId]?.removeWhere((m) => m.id == optimistic.id);
        // A refusal that cannot be retried must not sit on several megabytes for
        // the rest of the session.
        optimistic.upload?.dispose();
        _lastChildGateError = e.toString();
        notifyListeners();
        return;
      }
      optimistic.status = MessageStatus.error;
      notifyListeners();
    }
  }

  // ───────────── outgoing attachments ─────────────

  /// Total bytes this repository will hold on behalf of unfinished sends.
  ///
  /// A send whose bytes are still in memory is a send that can be retried, which
  /// is worth real megabytes — but not unbounded ones. Five 12-megapixel photos
  /// is already ~20 MB of retained `Uint8List` before their decodes, and a phone
  /// that runs out of memory mid-conversation is a worse outcome than a send that
  /// is honestly refused.
  static const _maxRetainedUploadBytes = 48 * 1024 * 1024;

  /// Uploads chained rather than raced. Bounds retained bytes, and lands
  /// attachments in the order they were sent with one honest progress arc at a
  /// time instead of five fighting over the same uplink.
  Future<void> _uploadQueue = Future.value();

  int get _retainedUploadBytes {
    var total = 0;
    for (final list in _pending.values) {
      for (final m in list) {
        final up = m.upload;
        if (up != null && !up.disposed) total += up.bytes.length;
      }
    }
    return total;
  }

  /// Puts an attachment in the transcript now and uploads it behind the bubble.
  ///
  /// The old shape awaited the upload and only then called [sendMedia], which is
  /// where the optimistic bubble was built — so the bubble existed for the length
  /// of the mutation (milliseconds) rather than the upload (seconds), and the
  /// sender watched an unchanged transcript until their photo appeared fully
  /// formed. Owning the upload here also means the send outlives the room screen:
  /// walking out mid-upload no longer abandons it.
  ///
  /// Fire-and-forget by design — the returned future completes when the send has
  /// settled, but nothing needs to await it. Failure is reported by the bubble,
  /// not by an exception.
  Future<void> sendMediaLocal({
    required String roomId,
    required Uint8List bytes,
    required String contentType,
    required MessageType type,
    double? mediaWidth,
    double? mediaHeight,
    String? caption,
    String? replyToId,
    bool viewOnce = false,
  }) async {
    final upload = PendingUpload(bytes: bytes, contentType: contentType);
    final optimistic = _buildOptimistic(
      roomId: roomId,
      content: caption ?? '',
      type: type,
      // Null until the upload hands one back. This is exactly why
      // MessageStatus.uploading exists — see enums.dart.
      mediaStorageId: null,
      // The server drops these for an armed send — the sealed tile is a fixed
      // size and the real ratio is a leak — so don't let the optimistic bubble
      // claim otherwise either.
      mediaWidth: viewOnce ? null : mediaWidth,
      mediaHeight: viewOnce ? null : mediaHeight,
      replyToId: replyToId,
      viewOnce: viewOnce,
      status: MessageStatus.uploading,
      upload: upload,
    );
    if (optimistic == null) {
      upload.dispose();
      return;
    }

    if (_retainedUploadBytes + bytes.length > _maxRetainedUploadBytes) {
      // Refused before it starts, and refused *without* keeping the bytes —
      // holding them would defeat the cap, since a refusal that retains its
      // payload just moves the memory rather than declining to spend it.
      //
      // Still shown, as a failed bubble, because a tap that silently does nothing
      // is worse. It offers no retry: there is nothing left to re-upload, and
      // [retryPending] refuses it for the same reason. Discard is the way out.
      upload.dispose();
      _pending.putIfAbsent(roomId, () => []).add(
            _buildOptimistic(
              roomId: roomId,
              content: caption ?? '',
              type: type,
              replyToId: replyToId,
              viewOnce: viewOnce,
              status: MessageStatus.error,
            )!,
          );
      notifyListeners();
      return;
    }

    _pending.putIfAbsent(roomId, () => []).add(optimistic);
    // The frame the picture appears on.
    notifyListeners();
    return _enqueueUpload(roomId, optimistic);
  }

  /// Retry a send that failed — either its upload or its mutation.
  ///
  /// Re-uploading is cheap to do freely: `files.gcOrphanedFiles` reclaims any
  /// blob that was stored but never referenced by a message, after a grace
  /// period, explicitly covering the case of a client dying between the upload
  /// and the mutation. So a retry that duplicates a blob costs a day of storage,
  /// not a leak.
  Future<void> retryPending(String messageId) async {
    for (final entry in _pending.entries) {
      for (final m in entry.value) {
        if (m.id != messageId) continue;
        if (m.status != MessageStatus.error) return;
        final up = m.upload;
        if (up != null && !up.disposed && m.mediaStorageId == null) {
          m.status = MessageStatus.uploading;
          up.report(0);
          notifyListeners();
          return _enqueueUpload(entry.key, m);
        }
        // Nothing to re-upload and nothing to reference — the bytes are gone and
        // no storage id ever arrived, so posting this would put an attachment
        // message pointing at nothing into the room. Leave it failed; discard is
        // the only honest way out.
        if (m.isMedia && m.mediaStorageId == null) return;
        // Bytes already up, or a text message: only the mutation is left.
        m.status = MessageStatus.pending;
        notifyListeners();
        return _postMessage(entry.key, m);
      }
    }
  }

  /// Throw a failed send away, bytes and all.
  void discardPending(String messageId) {
    for (final list in _pending.values) {
      final i = list.indexWhere((m) => m.id == messageId);
      if (i < 0) continue;
      list.removeAt(i).upload?.dispose();
      notifyListeners();
      return;
    }
  }

  /// Chains [message]'s upload behind whatever is already going up.
  ///
  /// The `catchError` is load-bearing despite looking like belt-and-braces over a
  /// `_runUpload` that already handles its own failures. A rejected future at the
  /// tail of a `then` chain makes every subsequent callback skip, so one
  /// unexpected throw — a listener raising inside `notifyListeners`, say — would
  /// silently stop every attachment sent for the rest of the session, with nothing
  /// anywhere to explain it. Anything arriving here is a bug rather than a send
  /// failure, and a bug must not be able to wedge the queue.
  Future<void> _enqueueUpload(String roomId, ChatMessage message) {
    _uploadQueue = _uploadQueue
        .then((_) => _runUpload(roomId, message))
        .catchError((Object e) {
      debugPrint('upload queue step threw (continuing): $e');
    });
    return _uploadQueue;
  }

  Future<void> _runUpload(String roomId, ChatMessage message) async {
    final upload = message.upload;
    if (upload == null || upload.disposed) return;
    // Discarded while it sat in the queue.
    if (!(_pending[roomId]?.contains(message) ?? false)) return;

    final task = UploadTask();
    upload.task = task;
    try {
      final storageId = await UploadService(api).uploadFile(
        bytes: upload.bytes,
        contentType: upload.contentType,
        task: task,
        onProgress: (sent, total) {
          if (total <= 0) return;
          upload.report(sent / total);
        },
      );
      if (upload.disposed) return;
      message.mediaStorageId = storageId;
      message.status = MessageStatus.pending;
      notifyListeners();
      await _postMessage(roomId, message);
    } on UploadCancelled {
      // Nothing to report: whoever cancelled it already removed the bubble.
    } catch (_) {
      if (upload.disposed) return;
      // Bytes and progress are kept: they are what makes retry possible.
      message.status = MessageStatus.error;
      notifyListeners();
    } finally {
      upload.task = null;
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
  ///
  /// The rule itself lives in `pending_reconcile.dart` — see there for what it
  /// matches on and which bug the one-to-one claiming exists to fix.
  void _reconcilePending(String roomId) {
    final pend = _pending[roomId];
    if (pend == null || pend.isEmpty) return;
    final live = _messages[roomId] ?? const [];
    final keep = survivingPending(live, pend);
    if (keep.length == pend.length) return;
    // Release the bytes of everything that just landed, at the same moment the
    // bubble holding them goes. A confirmed send has no use for its local copy,
    // and several megapixels per message is not something to leak.
    final kept = keep.toSet();
    for (final m in pend) {
      if (!kept.contains(m)) m.upload?.dispose();
    }
    pend
      ..clear()
      ..addAll(keep);
  }

  /// Whether a stuck optimistic message can be handed to `messages:send` as it
  /// stands.
  ///
  /// Both belts are needed. The status says what state the message is in, so a
  /// send whose bytes are still going up is left alone rather than posted with a
  /// null storage id — which is what a reconnect mid-upload would otherwise do,
  /// putting an image message pointing at nothing into the room. The second
  /// clause catches the message that got as far as `error` *before* its bytes
  /// landed: its status says retryable, but there is nothing yet to reference.
  /// Those are recovered by [retryPending], which re-uploads first.
  static bool _isPostable(ChatMessage m) =>
      m.status != MessageStatus.uploading &&
      !(m.isMedia && m.mediaStorageId == null);

  /// Rebuild every subscription this repository owns from scratch: the
  /// top-level subs via [attach], the open room's message/read/typing subs by
  /// re-opening it, then a flush of stuck sends.
  ///
  /// **No longer on the reconnect path.** Both transports replay their own
  /// query set across a reconnect, and `ConvexBackend`'s `SubscriptionRegistry`
  /// covers the one case they cannot — a forced native rebuild, where the
  /// client is brand new. Doing it again from here cost twelve teardowns, five
  /// REST round-trips and a serial flush on every reconnect, which was most of
  /// what a reconnect felt like. See `_resubscribeAll` in app.dart.
  ///
  /// Kept because a full local rebuild is still a coherent operation, and
  /// because its interleaving with [openRoom]/[closeRoom] is the sharpest test
  /// of the `_openGen` generation guard that push taps and screen switches
  /// depend on.
  Future<void> resubscribe() async {
    final uid = _userId;
    if (uid == null) return;
    final open = _activeRoomId;
    await attach(uid); // cancels + recreates rooms/friends/typing subs
    // Re-checked rather than trusting the snapshot: `attach` is four network
    // round-trips and five subscriptions, and the user can leave the room (or
    // land in a different one from a push tap) during it.
    if (open != null && _activeRoomId == open) {
      // `force` rather than the old `_activeRoomId = null` poke, which existed
      // only to defeat openRoom's same-room short-circuit. That poke blinded
      // PushManager's suppression check (app.dart wires it to `activeRoomId`)
      // for the whole of attach() plus the re-open — so every reconnect opened
      // a window where the room ON SCREEN got banners, which is exactly when
      // queued pushes arrive. `force` also preserves `_openOwner`, so the room
      // screen keeps its claim across the reconnect.
      await openRoom(open, force: true); // recreates messages/read/typing subs
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
        if ((m.status == MessageStatus.pending ||
                m.status == MessageStatus.error) &&
            _isPostable(m)) {
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
      await _postMessage(roomId, m);
    }
  }
}
