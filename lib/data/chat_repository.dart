import 'dart:async';
import 'dart:collection';

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
import '../models/location_share.dart';
import '../models/message_bookmark.dart';
import '../models/message_capabilities.dart';
import '../models/message_formatting.dart';
import '../models/message_interaction.dart';
import '../models/pending_upload.dart';
import '../models/room_admin.dart';
import '../models/room_capabilities.dart';
import '../models/room_mute.dart';
import '../models/room_pin.dart';
import '../models/scheduled_message.dart';
import '../push/push_manager.dart';
import '../services/live_location_permission.dart';
import '../services/live_location_platform.dart';
import '../services/live_location_publisher.dart';
import '../services/live_share_resume_store.dart';
import '../services/location_service.dart';
import 'cache_store.dart';
import 'pending_reconcile.dart';
import 'room_filter.dart';
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

  List<ChatRoom> _roomsStore = [];

  /// Every write to the room list goes through this setter so the memoised
  /// [facetCounts] cannot go stale. There are six assignment sites; adding a
  /// seventh should not depend on remembering to invalidate by hand.
  ///
  /// Safe because rooms are only ever replaced wholesale — nothing anywhere
  /// mutates `unreadCount`, `hasMention` or `lastReadAt` on a live [ChatRoom].
  List<ChatRoom> get _rooms => _roomsStore;
  set _rooms(List<ChatRoom> next) {
    _roomsStore = next;
    _facetCounts = null;
  }

  List<ChatRoom> get rooms => List.unmodifiable(_rooms);

  /// The chat list's main feed: everything in [rooms] except what's archived.
  /// [rooms] itself stays unfiltered — push alerts and the forward-target
  /// picker both need archived rooms still reachable.
  List<ChatRoom> get activeRooms =>
      List.unmodifiable(_rooms.where((r) => !r.isArchived));

  /// Only the archived ones — feeds the Archived Chats sheet.
  List<ChatRoom> get archivedRooms =>
      List.unmodifiable(_rooms.where((r) => r.isArchived));

  RoomFacetCounts? _facetCounts;

  /// How many rooms match each filter facet, plus the unread aggregates —
  /// computed in a single pass and cached until the room list changes.
  ///
  /// Worth the cache: [notifyListeners] fires on every typing keystroke in any
  /// room, so recomputing per getter call meant ten linear scans per keystroke
  /// once the filter UI started asking for counts. Now it's one scan per room
  /// push.
  RoomFacetCounts get facetCounts =>
      _facetCounts ??= RoomFacetCounts.of(_roomsStore);

  /// Number of rooms with messages newer than this user's read cursor.
  int get unreadRoomCount => facetCounts.unreadRooms;

  /// Total unread *messages* across every room — drives the Chat tab badge
  /// and, via [BadgeManager], the OS app-icon badge. Counts messages rather
  /// than rooms so it matches what the push payload's absolute
  /// `ios_badgeCount` says.
  int get unreadMessageTotal => facetCounts.unreadMessages;

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

  /// What [room] affords — which buttons, fields and lists its chrome may draw.
  /// See `lib/models/room_capabilities.dart`.
  ///
  /// The entry point every UI site should use, because it resolves the DM peer
  /// itself: that is the half of the answer a widget holding only a [ChatRoom]
  /// cannot work out, and forgetting it silently downgrades a bot room to an
  /// ordinary DM.
  RoomCapabilities capabilitiesFor(ChatRoom room) =>
      roomCapabilitiesFor(room, peer: otherUserFor(room));

  /// What [message] affords in the long-press menu. See
  /// `lib/models/message_capabilities.dart` for the table and its history.
  ///
  /// The entry point every menu call site should use, because it resolves the
  /// three inputs a widget holding only a message cannot: whose message it is,
  /// what the room affords, and what time the SERVER thinks it is (the edit
  /// window is measured against [serverNow], not the device clock).
  ///
  /// [room] is nullable for `ThreadOverlay`, which holds only a room id that
  /// [roomById] may fail to resolve — an unresolvable room affords the
  /// locked-down floor, which drops SAVE/FORWARD rather than offering rows
  /// that would throw.
  MessageCapabilities capabilitiesForMessage(ChatMessage message, ChatRoom? room) {
    final me = _userId;
    return messageCapabilitiesFor(
      message: message,
      isMine: me != null && message.senderId == me,
      room: room == null ? RoomCapabilities.system : capabilitiesFor(room),
      roomIsEphemeral: room?.isEphemeral ?? true,
      serverNow: serverNow,
    );
  }

  List<ChatUser> _friends = [];
  List<ChatUser> get friends => List.unmodifiable(_friends);

  List<FriendRequest> _incomingRequests = [];
  List<FriendRequest> get incomingRequests => List.unmodifiable(_incomingRequests);

  List<FriendRequest> _outgoingRequests = [];
  List<FriendRequest> get outgoingRequests => List.unmodifiable(_outgoingRequests);

  /// Group invites waiting on this user's yes or no.
  ///
  /// Lives here, next to the friend requests, because it is the same kind of
  /// thing and shares their fate: both feed the Discover badge, both have to be
  /// live rather than fetched on screen-open, and both must be empty the
  /// instant the account changes. Rows still held at a guardian hop are
  /// filtered out server-side, so anything in this list is genuinely the
  /// user's to answer.
  List<RoomInvitation> _roomInvitations = [];
  String _roomInvitationsSig = '';
  List<RoomInvitation> get roomInvitations => List.unmodifiable(_roomInvitations);

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
  Subscription? _roomInvitationsSub;
  Subscription? _globalTypingSub;
  Subscription? _speakerColorsSub;

  /// This reader's manual speaker colours: roomId → subjectId → palette slot.
  ///
  /// ONE app-wide subscription rather than one per room, and it is worth being
  /// precise about why both halves of that are cheap. The set is bounded at
  /// twelve per room by the server and is empty for almost every reader, so
  /// holding all of it costs nothing; and the query reads only rows keyed to
  /// this reader, so it is invalidated by this reader's own writes and by
  /// nothing anyone else in any room does. A per-room subscription would be a
  /// live query opened and torn down on every room entry, for a feature most
  /// people never touch.
  Map<String, Map<String, int>> _speakerColors = const {};

  String? _activeRoomIdValue;

  /// The room currently visible to the user (if any).
  ///
  /// Assigning also tells the platform, so an incoming-message push for the
  /// chat already on screen doesn't raise a banner over it. The native side
  /// caches the value rather than calling back into Dart: iOS makes that
  /// decision inside a completion handler it must answer promptly, and a round
  /// trip into an isolate that may be suspended is a good way to hang it.
  ///
  /// Wrapped in a setter rather than pushed from each call site because there
  /// are three assignment points (open, close, detach) and a missed one leaves
  /// the platform believing a room is still on screen — which silently
  /// suppresses that room's notifications for the rest of the session.
  String? get _activeRoomId => _activeRoomIdValue;

  set _activeRoomId(String? value) {
    if (_activeRoomIdValue == value) return;
    _activeRoomIdValue = value;
    unawaited(PushManager.instance.setActiveRoom(value));
  }

  String? get activeRoomId => _activeRoomIdValue;

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
  Subscription? _pinsSub;
  Subscription? _bookmarksSub;
  Subscription? _scheduledSub;
  Subscription? _interactionsSub;

  /// Pinned messages, keyed by room.
  ///
  /// Room-keyed rather than a bare list for the same reason `_messages` is: a
  /// late `onData` from the room being left must not paint over the room being
  /// entered. `_activeReadState` is the counter-example this avoids — it is not
  /// keyed, which is why `openRoom` has to clear it by hand.
  final Map<String, List<RoomPin>> _pins = {};

  /// This viewer's saved messages, keyed by room. Room-keyed for the same
  /// reason [_pins] is.
  ///
  /// Only ever holds the SIGNED-IN user's bookmarks — the query is keyed by
  /// (room, viewer), so there is no other reader's data in here to leak into a
  /// menu. [detach] still clears it, because the next account's rooms are not
  /// this one's.
  final Map<String, List<MessageBookmark>> _bookmarks = {};

  /// This viewer's queued messages, keyed by room. Room-keyed for the same
  /// reason [_pins] is, and holding only the signed-in user's rows for the same
  /// reason [_bookmarks] does — the query is keyed by (room, author), and a
  /// scheduled message is private to its author until it sends.
  final Map<String, List<ScheduledMessage>> _scheduled = {};

  /// Poll, checklist and event bodies for the open room: messageId →
  /// [MessageInteraction], keyed by room like everything above it.
  ///
  /// A SECOND map rather than fields on the [ChatMessage] in `_messages`,
  /// mirroring the split the backend makes and for the same reason: a vote must
  /// not rebuild the transcript. Merging the two here would undo that on the
  /// client — every tally change would rewrite the message list, and every
  /// widget that rebuilds off it would rebuild.
  ///
  /// Filled from two sources that must not fight, so both go through
  /// [_mergeInteractions] and neither ever clears the map. The
  /// `interactions:listForRoom` subscription owns the newest hundred and
  /// upserts them on every fire; [_hydrateInteractions] fills in older ones a
  /// page load brought into view, one shot each. A fire that replaced the map
  /// wholesale would blank every scrolled-back poll on the next vote anybody
  /// cast — the live window does not mention them, and "not mentioned" is not
  /// "gone".
  final Map<String, Map<String, MessageInteraction>> _interactions = {};

  /// Message ids [_hydrateInteractions] has already asked the server about,
  /// keyed by room.
  ///
  /// Without this, every `notifyListeners()` that repaints a scrolled-back poll
  /// would re-issue the same one-shot query — a room the reader is idly
  /// scrolling would fetch the same rows continuously. Ids are remembered
  /// whether or not the fetch found anything, because "this old message has no
  /// interaction row" is an answer worth keeping too.
  final Map<String, Set<String>> _interactionsAsked = {};
  Timer? _typingHeartbeat;
  bool _typingActive = false;

  /// Read state for the currently-open room: userId → lastReadAt.
  ///
  /// Only members who share their reads have an entry — a member who hides
  /// `seen` is absent here even when they are present in [_activeDeliveredState].
  final Map<String, DateTime> _activeReadState = {};

  /// Delivery state for the currently-open room: userId → lastDeliveredAt.
  ///
  /// Kept apart from [_activeReadState] rather than folded into one record per
  /// member because the two are gated by DIFFERENT visibility levels server-side
  /// (`seen` for reads, `lastSeen` for deliveries), so a member can legitimately
  /// appear in one map and not the other. A single map of nullable pairs would
  /// have let a missing read silently read as "delivered at epoch".
  final Map<String, DateTime> _activeDeliveredState = {};

  /// The latest `lastReadAt` of any user other than me in the current room.
  /// Used to render the "SEEN" indicator on my own messages. Returns null
  /// when the local "view read receipts" preference is off, suppressing the
  /// indicator regardless of what the server delivers.
  DateTime? get latestOthersReadAt {
    if (!SettingsStore.instance.viewReadReceipts) return null;
    return _latestOthers(_activeReadState);
  }

  /// The latest `lastDeliveredAt` of any user other than me in the current
  /// room — the second tick.
  ///
  /// Deliberately NOT gated on `viewReadReceipts`. That preference is spelled
  /// "show read receipts", and it exists so a reader can decline to be told
  /// when their message was *looked at*; a message reaching the other person's
  /// phone is a fact about the network, not about them, and hiding it would
  /// leave every outgoing message looking half-sent. The reader's own
  /// `lastSeen` level is the control that governs this one, and it is applied
  /// server-side in `messages:getReadState`.
  DateTime? get latestOthersDeliveredAt => _latestOthers(_activeDeliveredState);

  /// Every member's read cursor for the open room, keyed by user id.
  ///
  /// The per-person form of [latestOthersReadAt], for the one surface that
  /// asks who rather than whether — the receipts screen behind a bubble's
  /// swipe. Same subscription, same rows, no extra query: this map is already
  /// live for the room the reader is in, and a caller folding over it costs a
  /// map walk.
  ///
  /// A member missing from BOTH this and [roomDeliveredCursors] is withholding
  /// receipts (`visibility.seen`), which is not the same as being behind — see
  /// `messages:getReadState`, which drops such a row rather than zeroing it.
  ///
  /// Deliberately NOT gated on the local `viewReadReceipts` preference, unlike
  /// [latestOthersReadAt]. That preference is spelled "see the SEEN mark on
  /// your own messages" and governs a passive indicator the reader never asked
  /// for; a screen you drag onto the display is the asking.
  Map<String, DateTime> get roomReadCursors =>
      UnmodifiableMapView(_activeReadState);

  /// Every member's delivery cursor for the open room. The companion to
  /// [roomReadCursors]; the two are separate maps for the reason
  /// [_activeDeliveredState] gives.
  Map<String, DateTime> get roomDeliveredCursors =>
      UnmodifiableMapView(_activeDeliveredState);

  DateTime? _latestOthers(Map<String, DateTime> cursors) {
    final me = _userId;
    DateTime? best;
    for (final entry in cursors.entries) {
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

  /// Serialises attach/detach so two of them can never interleave.
  ///
  /// [attach] awaits four network round-trips between cancelling the previous
  /// subscription handles and assigning the new ones. Two concurrent attaches
  /// therefore both reached the cancel block while every handle was still
  /// null, cancelled nothing, and both went on to subscribe — the later
  /// assignment winning and the earlier subscriptions staying live on the wire
  /// with nothing left holding their handles. Unclosable duplicates, every
  /// update delivered twice, for the rest of the session.
  ///
  /// The double-attach at sign-in is gone (app.dart no longer attaches from
  /// bootstrap as well as from the auth listener), but this path is reachable
  /// on its own: [resubscribe] calls [attach] on every reconnect, and a
  /// reconnect during a cold-start attach is ordinary — the connection log
  /// shows one within the first second of launch.
  Future<void> _attachQueue = Future<void>.value();

  Future<void> attach(String userId) {
    // Published synchronously, before any awaiting: callers guard re-attach on
    // `repo.userId`, and an id that only appeared after the first await would
    // wave a second caller straight through while this attach was in flight.
    _userId = userId;
    final done = _attachQueue.then((_) => _attach(userId));
    // Swallowed on the queue only — `done` still carries the error to the
    // caller. Without this a single failed attach would poison the chain and
    // every later attach would reject without running.
    _attachQueue = done.catchError((_) {});
    return done;
  }

  Future<void> _attach(String userId) async {
    // Re-emit when the local "view read receipts" pref flips so any open
    // chat screen rebuilds and the SEEN indicator appears/disappears live.
    SettingsStore.instance.removeListener(_onSettingsChanged);
    SettingsStore.instance.addListener(_onSettingsChanged);
    // Fire-and-forget: nothing below depends on it, and [attach] re-runs on
    // every reconnect, so a sample lost to a dead socket is retaken by the
    // reconnect that revives it.
    unawaited(_sampleServerClock());
    // 1) Hydrate from disk so the first frame already shows last-known state
    //    even if we're cold-booting offline. This is cheap (~ms) and the
    //    live subscriptions will overwrite as they connect.
    //
    //    Friends load alongside rooms, not after them: a DM room's display
    //    name is resolved client-side against `_friends` (see
    //    `otherUserFor`) rather than carried on the room itself, so a cold
    //    frame with rooms but no friends yet paints every DM by its raw
    //    `dm:<id>_<id>` name until the network round trip in step 2 lands —
    //    exactly the flash this hydration step exists to avoid.
    try {
      final results = await Future.wait<dynamic>([
        CacheStore.instance.loadRooms(userId),
        CacheStore.instance.loadFriends(userId),
      ]);
      final cachedRooms = results[0] as List<ChatRoom>;
      final cachedFriends = results[1] as List<ChatUser>;
      if (cachedRooms.isNotEmpty) _rooms = cachedRooms;
      if (cachedFriends.isNotEmpty) _friends = cachedFriends;
      if (cachedRooms.isNotEmpty || cachedFriends.isNotEmpty) notifyListeners();
    } catch (_) {}

    // 2) Seed from parallel API hits before subscriptions take over.
    try {
      final results = await Future.wait<dynamic>([
        api.listUserRooms(userId).catchError((_) => <ChatRoom>[]),
        api.listFriends(userId).catchError((_) => <ChatUser>[]),
        api.listIncomingDirectRequests(userId).catchError((_) => <FriendRequest>[]),
        api.listOutgoingDirectRequests(userId).catchError((_) => <FriendRequest>[]),
        // Idempotent — self-heals the Saved Messages room on every launch for
        // new and pre-existing accounts alike. Result unused: the room itself
        // arrives through the rooms:listUserRooms subscription below.
        api.ensureSavedMessagesRoom(userId: userId).catchError((_) => ''),
      ]);
      final roomsResult = results[0] as List<ChatRoom>;
      if (roomsResult.isNotEmpty) {
        _rooms = roomsResult;
        CacheStore.instance.scheduleSaveRooms(userId, _rooms);
      }
      final friendsResult = results[1] as List<ChatUser>;
      if (friendsResult.isNotEmpty) {
        _friends = friendsResult;
        CacheStore.instance.scheduleSaveFriends(userId, _friends);
      }
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
    _roomInvitationsSub?.cancel();
    _globalTypingSub?.cancel();
    _speakerColorsSub?.cancel();
    _speakerColorsSub = null;
    _roomsSub = null;
    _friendsSub = null;
    _incomingSub = null;
    _outgoingSub = null;
    _roomInvitationsSub = null;
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
        // This stream landing IS the delivery: the traffic it describes is on
        // this device now, whichever screen the user happens to be looking at.
        _scheduleDeliveryReport(userId);
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
        CacheStore.instance.scheduleSaveFriends(userId, _friends);
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

    _roomInvitationsSub = await cv.subscribe(
      'roomInvitations:listIncoming',
      {'userId': userId},
      onData: (data) {
        final list = (data as List?) ?? const [];
        final fresh = list
            .map((e) => RoomInvitation.fromJson((e as Map).cast<String, dynamic>()))
            .toList();
        // Deduped before notifying, unlike its siblings above, because this
        // query re-fires far more often than its contents change: it reads the
        // ROOM document of every group that has invited this user, and
        // `messages.send` patches `rooms.lastMessage` on every message. A
        // notify here rebuilds the chat list and the shell's badge, so an
        // active group somebody was invited to would have re-laid-out the whole
        // home screen on every message in it.
        //
        // Signature over the fields anything actually renders — the id, the
        // room's name and size, the inviter. Not the object: these are fresh
        // instances every fire, so identity comparison would never dedup.
        final sig = fresh
            .map((i) =>
                '${i.invitationId}|${i.roomName}|${i.memberCount}|${i.inviter.id}')
            .join(';');
        if (sig == _roomInvitationsSig) return;
        _roomInvitationsSig = sig;
        _roomInvitations = fresh;
        notifyListeners();
      },
      onError: (err) => debugPrint('room invitations sub error: $err'),
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

    // Manual speaker colours — see [_speakerColors]. Deliberately NOT gated on
    // the reader's `speakerTint` preference: a reader who turns colours off and
    // back on should find their pins where they left them, and skipping the
    // subscription would mean the first room they open after re-enabling paints
    // in derived colours and then visibly re-paints when the overrides land.
    _speakerColorsSub = await cv.subscribe(
      'speakerColors:mine',
      {'viewerId': userId},
      onData: (data) {
        final fresh = <String, Map<String, int>>{};
        if (data is Map) {
          data.forEach((roomId, byUser) {
            if (byUser is! Map) return;
            final inner = <String, int>{};
            byUser.forEach((subjectId, slot) {
              if (slot is num) inner[subjectId.toString()] = slot.toInt();
            });
            if (inner.isNotEmpty) fresh[roomId.toString()] = inner;
          });
        }
        _speakerColors = fresh;
        notifyListeners();
      },
      onError: (err) => debugPrint('speaker colors sub error: $err'),
    );

    // Stuck sends used to be retried from a raw `cv.connectionState` listener
    // here — a second, independent reconnect trigger with none of
    // [ConnectionHealth]'s verification. convex-rs toggles connecting/connected
    // on every lap of its own internal backoff, so it fired on laps that were
    // not reconnects at all, re-posting messages against a socket that had not
    // come back. [ConnectionHealth] owns that edge now, and it hands it to
    // [flushPending], of which the old handler was a strict subset.

    // Last, and unawaited. A live share left over from a previous process is
    // real but it is not urgent — nothing on screen is waiting for it — and
    // putting a disk read and a permission check in front of the subscriptions
    // above would delay the first frame of every launch for a case that is rare.
    // Its own re-entrancy guard means the `resubscribe()` path costs one boolean.
    unawaited(_resumeLiveShareIfAny());
  }

  /// The newest `lastMessageTime` we have already reported delivered, per room.
  ///
  /// Purely an in-flight guard. `markRoomDelivered` patches our own membership
  /// row, which re-fires `rooms:listUserRooms` — so without this the echo of
  /// our own write would arrive before the new cursor did and we would report
  /// the same room again, and again. The durable version of this guard is the
  /// server's own `lastDeliveredAt`, which [_reportDelivery] reads off the room
  /// and which survives a relaunch; this map only covers the window between
  /// firing the mutation and seeing it come back.
  final Map<String, DateTime> _deliveryReported = {};

  /// How many messages the live `messages:list` subscription holds open.
  ///
  /// Every send, edit, reaction or delete in this window re-runs that query
  /// for every viewer of the room and re-sends them the WHOLE window — Convex
  /// pushes full results, not deltas — so this number is a multiplier on the
  /// two things the receive path is made of: the server's work per message and
  /// the bytes each phone parses per message. It was 100. Fifty still fills
  /// several screens on the tallest phone, and everything older arrives
  /// through [loadOlder] on the first scroll back, exactly as messages 101+
  /// always did. The one thing given up: a reaction on a message that has
  /// scrolled out of the window no longer updates live — which was already
  /// true past 100, and is the same freeze the thread overlay documents.
  static const kLiveWindow = 50;

  /// Pending `markRoomRead`, coalesced — see [_scheduleMarkRead].
  Timer? _readDebounce;
  ({String roomId, String userId, DateTime upTo})? _pendingRead;

  /// A burst of arrivals — a sender's queue flushing, a reconnect replay —
  /// lands as several `messages:list` fires in quick succession, and each used
  /// to send its own `markRoomRead`. One write per burst instead; the sender's
  /// SEEN lags by at most this, which is invisible next to the round trip.
  static const _kReadDebounce = Duration(milliseconds: 400);

  /// Queues a read receipt for [roomId] up to [upTo], the newest message this
  /// device has on screen. Later cursors for the same room fold into the one
  /// already queued; a different room flushes the queued one first, so a quick
  /// room switch never loses the previous room's read.
  void _scheduleMarkRead(String roomId, String userId, DateTime upTo) {
    final cur = _pendingRead;
    if (cur != null && cur.roomId != roomId) _flushMarkRead();
    final queued = _pendingRead;
    if (queued != null && !upTo.isAfter(queued.upTo)) upTo = queued.upTo;
    _pendingRead = (roomId: roomId, userId: userId, upTo: upTo);
    _readDebounce?.cancel();
    _readDebounce = Timer(_kReadDebounce, _flushMarkRead);
  }

  void _flushMarkRead() {
    _readDebounce?.cancel();
    _readDebounce = null;
    final p = _pendingRead;
    _pendingRead = null;
    if (p == null) return;
    api
        .markRoomRead(roomId: p.roomId, userId: p.userId, upTo: p.upTo)
        .catchError((_) {});
  }

  Timer? _deliveryDebounce;

  /// How long a burst of incoming traffic is allowed to settle before we report
  /// it delivered.
  ///
  /// Every message moves its room's `lastMessageTime`, so ten messages in three
  /// seconds is ten distinct things to report — and each report patches a
  /// roomMembers row, which re-fires `getReadState` for everyone in the room
  /// and `listUserRooms` for us. Coalescing turns the burst into one write. The
  /// cost is that the sender's second tick can lag by up to this long, which is
  /// invisible next to the round trip it is already waiting on.
  static const _kDeliveryDebounce = Duration(milliseconds: 1200);

  /// Largest room that still reports delivery — the second tick's fan-out cap.
  ///
  /// Skipping the call here saves the round trip; the server holds the same
  /// line in `messages.ts`'s `DELIVERY_MEMBER_LIMIT`, which is what makes the
  /// cap true for an old client as well. Keep the two in step.
  ///
  /// Past this, one delivery patch re-runs `getReadState` for every member of
  /// the room, so the write grows more expensive exactly as what it claims
  /// grows emptier — in a room of hundreds, "someone's device has it" is true
  /// the moment the message is sent. Those rooms stay on one tick.
  static const kDeliveryMemberLimit = 50;

  void _scheduleDeliveryReport(String userId) {
    _deliveryDebounce?.cancel();
    _deliveryDebounce = Timer(_kDeliveryDebounce, () => _reportDelivery(userId));
  }

  /// Tells the server which rooms this device now holds the traffic for.
  ///
  /// The second tick, and the whole of the client's half of it. Called from the
  /// chat-list subscription rather than from the transcript because the case
  /// that matters is the one where the recipient is NOT in the room: a message
  /// they are looking at is already covered by `markRoomRead`, which advances
  /// both cursors.
  ///
  /// At most one mutation per room per burst of new traffic, and none at all on
  /// a launch that brings no news:
  ///
  ///  * `unreadCount == 0` means nothing of anyone else's is outstanding — our
  ///    own sends do not need reporting to ourselves;
  ///  * a `lastDeliveredAt` already at or past the room's newest message means
  ///    the server knows, from this device or another of ours;
  ///  * [_deliveryReported] covers the round trip in between.
  ///
  /// Failures are swallowed. A delivery cursor that misses a beat corrects
  /// itself on the next message, and there is no user-visible action to offer.
  ///
  /// Rooms above [kDeliveryMemberLimit] are skipped and stay on one tick.
  ///
  /// Muting a room does NOT stop this, and the raw [ChatRoom.unreadCount]
  /// below is deliberate rather than an oversight to be tidied into
  /// `visibleUnreadCount`. The two ticks are a fact reported to the SENDER
  /// about their own message; whether this device chose to draw a badge for it
  /// is none of their business. Silencing delivery along with the badge would
  /// mean muting a chat quietly downgraded the other person's receipts, with a
  /// symptom pointing nowhere near notification settings.
  void _reportDelivery(String userId) {
    for (final room in _rooms) {
      final newest = room.lastMessageTime;
      if (newest == null) continue;
      if (room.unreadCount <= 0) continue;
      if (room.memberCount > kDeliveryMemberLimit) continue;
      final onServer = room.lastDeliveredAt;
      if (onServer != null && !newest.isAfter(onServer)) continue;
      final inFlight = _deliveryReported[room.id];
      if (inFlight != null && !newest.isAfter(inFlight)) continue;
      _deliveryReported[room.id] = newest;
      api
          .markRoomDelivered(roomId: room.id, userId: userId)
          .catchError((_) {});
    }
  }

  /// Queued behind any in-flight [attach] for the same reason attaches are
  /// queued behind each other: a sign-out that overtook a running attach would
  /// null every handle the attach had not assigned yet, and the attach would
  /// then finish by subscribing the account that just signed out.
  Future<void> detach() {
    final done = _attachQueue.then((_) => _detach());
    _attachQueue = done.catchError((_) {});
    return done;
  }

  Future<void> _detach() async {
    SettingsStore.instance.removeListener(_onSettingsChanged);
    _roomsSub?.cancel();
    _friendsSub?.cancel();
    _incomingSub?.cancel();
    _outgoingSub?.cancel();
    _roomInvitationsSub?.cancel();
    _globalTypingSub?.cancel();
    _messagesSub?.cancel();
    _activeTypingSub?.cancel();
    // Signing out has to take this one with it too: left live, it keeps
    // writing the previous account's read receipts into `_activeReadState`
    // for whoever signs in next.
    _readStateSub?.cancel();
    _pinsSub?.cancel();
    _bookmarksSub?.cancel();
    _scheduledSub?.cancel();
    _speakerColorsSub?.cancel();
    _typingHeartbeat?.cancel();
    _roomsSub = null;
    _friendsSub = null;
    _incomingSub = null;
    _outgoingSub = null;
    _globalTypingSub = null;
    _messagesSub = null;
    _activeTypingSub = null;
    _readStateSub = null;
    _pinsSub = null;
    _bookmarksSub = null;
    _scheduledSub = null;
    _speakerColorsSub = null;
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
    _roomInvitations = [];
    _roomInvitationsSig = '';
    _messages.clear();
    // Unlike [closeRoom], which keeps these so re-entry paints instantly, this
    // is a sign-out: they are the previous account's room state.
    _pins.clear();
    // And these are the previous account's PRIVATE room state, so if anything
    // the case for dropping them is stronger.
    _bookmarks.clear();
    // Poll state, which is both: the tallies are shared, but `myChoiceIds` is
    // the departing account's own ballot. Leaving it would show the next person
    // on this handset their predecessor's votes rendered as their own.
    _interactions.clear();
    _interactionsAsked.clear();
    // How the departing account chose to read the rooms it was in. Same
    // argument as the bookmarks above — private, per-account state — with one
    // sharper consequence if it were left: the next person on this handset
    // would open a shared room and find its colours already pinned by someone
    // whose choices they cannot see the reason for.
    _speakerColors = const {};
    // Same argument again, and one step further: these are messages the
    // departing account has not sent yet. Leaving them cached would show the
    // next person on this device a pill counting somebody else's unsent words.
    _scheduled.clear();
    // Room ids are per-account, so a stale entry could only ever suppress a
    // delivery report the next account genuinely owed. The pending timer has to
    // go with it: it closes over the departing user's id.
    _deliveryDebounce?.cancel();
    _deliveryDebounce = null;
    _deliveryReported.clear();
    // Dropped, not flushed: the queued receipt names the account signing out.
    _readDebounce?.cancel();
    _readDebounce = null;
    _pendingRead = null;
    // Stop feeding any live share. Signing out has to take the GPS with it —
    // the next account on this device must not inherit a position stream, and
    // the departing account's publisher would be writing to a message it can no
    // longer authenticate for.
    //
    // Deliberately does NOT end the share itself. The share belongs to the
    // account, not to this device: it keeps running for the recipients until
    // its own deadline, exactly as it would if the phone were switched off.
    // Ending it here would make signing out a way to stop being findable that
    // nobody asked for, and would need a mutation as the credentials go away.
    //
    // It DOES forget the resume handle, which is a different thing and the right
    // one. The handle is this device's standing instruction to keep publishing
    // after a reboot, and a signed-out device has no business carrying out a
    // signed-out account's instructions — least of all if the next person to
    // sign in on this handset is a different person. The server would refuse
    // those writes anyway; not making them is better than being refused.
    liveLocation.stop(forget: true);
    _resumeAttempted = false;
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

  // ── Group administration ────────────────────────────────────────────────
  //
  // Thin pass-throughs: the repository holds the signed-in id so no screen has
  // to, and that is the whole of its job here. There is no local cache of any
  // of this on purpose — a stale copy of "am I still an admin" is worse than a
  // spinner, because it draws controls that then refuse.

  Future<RoomPermissions?> roomPermissions(String roomId) async {
    final id = _userId;
    if (id == null) return null;
    return api.roomPermissions(roomId: roomId, userId: id);
  }

  Future<void> setRoomAdmin({
    required String roomId,
    required String targetUserId,
    required bool makeAdmin,
  }) async {
    final id = _userId;
    if (id == null) return;
    await api.setRoomAdmin(
      roomId: roomId,
      userId: id,
      targetUserId: targetUserId,
      makeAdmin: makeAdmin,
    );
  }

  Future<void> transferRoomOwnership({
    required String roomId,
    required String targetUserId,
  }) async {
    final id = _userId;
    if (id == null) return;
    await api.transferRoomOwnership(
      roomId: roomId,
      userId: id,
      targetUserId: targetUserId,
    );
  }

  Future<void> removeRoomMember({
    required String roomId,
    required String targetUserId,
  }) async {
    final id = _userId;
    if (id == null) return;
    await api.removeRoomMember(
      roomId: roomId,
      userId: id,
      targetUserId: targetUserId,
    );
  }

  Future<void> setRoomPolicy({
    required String roomId,
    bool? membersCanInvite,
    RoomJoinPolicy? linkJoinPolicy,
  }) async {
    final id = _userId;
    if (id == null) return;
    await api.setRoomPolicy(
      roomId: roomId,
      userId: id,
      membersCanInvite: membersCanInvite,
      linkJoinPolicy: linkJoinPolicy,
    );
  }

  Future<RoomInviteLink?> roomInviteLink(String roomId) async {
    final id = _userId;
    if (id == null) return null;
    return api.getRoomInviteLink(roomId: roomId, userId: id);
  }

  Future<RoomInviteLink?> rotateRoomInviteLink(
    String roomId, {
    Duration? expiresIn,
    int? maxUses,
  }) async {
    final id = _userId;
    if (id == null) return null;
    return api.rotateRoomInviteLink(
      roomId: roomId,
      userId: id,
      expiresIn: expiresIn,
      maxUses: maxUses,
    );
  }

  Future<void> revokeRoomInviteLink(String roomId) async {
    final id = _userId;
    if (id == null) return;
    await api.revokeRoomInviteLink(roomId: roomId, userId: id);
  }

  /// Signed-in id is OPTIONAL here, unlike everything else in this section: a
  /// tapped invite link can land on a logged-out app, and the preview is what
  /// tells that person what they are being invited to before they are asked to
  /// sign in for it.
  Future<InvitePreview> previewInvite(String code) =>
      api.previewInvite(code: code, userId: _userId);

  Future<({RedeemOutcome outcome, String roomId})?> redeemInvite(String code) async {
    final id = _userId;
    if (id == null) return null;
    return api.redeemInvite(code: code, userId: id);
  }

  Future<List<RoomJoinRequest>> listJoinRequests(String roomId) async {
    final id = _userId;
    if (id == null) return const [];
    return api.listJoinRequests(roomId: roomId, userId: id);
  }

  Future<void> decideJoinRequest({
    required String requestId,
    required bool approve,
  }) async {
    final id = _userId;
    if (id == null) return;
    await api.decideJoinRequest(requestId: requestId, userId: id, approve: approve);
  }

  Future<List<ChatUser>> invitableFriends(String roomId) async {
    final id = _userId;
    if (id == null) return const [];
    return api.invitableFriends(roomId: roomId, userId: id);
  }

  Future<void> inviteToRoom({
    required String roomId,
    required String inviteeId,
  }) async {
    final id = _userId;
    if (id == null) return;
    await api.inviteToRoom(roomId: roomId, userId: id, inviteeId: inviteeId);
  }

  Future<String?> respondToRoomInvitation({
    required String invitationId,
    required bool accept,
  }) async {
    final id = _userId;
    if (id == null) return null;
    return api.respondToRoomInvitation(
      invitationId: invitationId,
      userId: id,
      accept: accept,
    );
  }

  Future<void> cancelRoomInvitation(String invitationId) async {
    final id = _userId;
    if (id == null) return;
    await api.cancelRoomInvitation(invitationId: invitationId, userId: id);
  }

  Future<List<RoomInvitation>> incomingRoomInvitations() async {
    final id = _userId;
    if (id == null) return const [];
    return api.listIncomingRoomInvitations(id);
  }

  /// One-shot read of the invites a room has out. Named apart from the
  /// [roomInvitations] getter above, which is the signed-in user's own INBOX —
  /// the two point in opposite directions and sharing a name made that
  /// impossible to see at a call site.
  Future<List<PendingRoomInvite>> pendingRoomInvites(String roomId) async {
    final id = _userId;
    if (id == null) return const [];
    return api.listRoomInvitations(roomId: roomId, userId: id);
  }

  Future<void> pinRoom(String roomId) async {
    final id = _userId;
    if (id == null) return;
    await api.pinRoom(roomId: roomId, userId: id);
  }

  Future<void> unpinRoom(String roomId) async {
    final id = _userId;
    if (id == null) return;
    await api.unpinRoom(roomId: roomId, userId: id);
  }

  Future<void> archiveRoom(String roomId) async {
    final id = _userId;
    if (id == null) return;
    await api.archiveRoom(roomId: roomId, userId: id);
  }

  Future<void> unarchiveRoom(String roomId) async {
    final id = _userId;
    if (id == null) return;
    await api.unarchiveRoom(roomId: roomId, userId: id);
  }

  /// Silence [roomId] for this user — see `lib/models/room_mute.dart`.
  ///
  /// No optimistic local patch, unlike some of the writes above. The mute the
  /// user picked is a duration, and the thing every surface renders is the
  /// DEADLINE the server computes from it; guessing that deadline here with
  /// this device's clock would show the user a time that then quietly changed
  /// under them when the subscription caught up a beat later.
  Future<void> muteRoom(
    String roomId, {
    required bool notifications,
    required bool badges,
    required MuteDuration duration,
  }) async {
    final id = _userId;
    if (id == null) return;
    await api.muteRoom(
      roomId: roomId,
      userId: id,
      notifications: notifications,
      badges: badges,
      durationMs: duration.wireMs,
    );
  }

  Future<void> unmuteRoom(String roomId) async {
    final id = _userId;
    if (id == null) return;
    await api.unmuteRoom(roomId: roomId, userId: id);
  }

  // ───────────── messages ─────────────

  @visibleForTesting
  void debugSeedMessages(String roomId, List<ChatMessage> messages) =>
      _messages[roomId] = List.of(messages);

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
    _pinsSub?.cancel();
    _bookmarksSub?.cancel();
    _scheduledSub?.cancel();
    _interactionsSub?.cancel();
    // Nulled immediately, not just reassigned at the end: this open can now
    // bail at any of the `gen` checks below, and [closeRoom] would otherwise
    // find and re-cancel a handle that is already dead.
    _messagesSub = null;
    _activeTypingSub = null;
    _readStateSub = null;
    _pinsSub = null;
    _bookmarksSub = null;
    _scheduledSub = null;
    _interactionsSub = null;
    // Dropped here rather than beside the new subscription below: several
    // awaits separate the two, and until then the old room would keep serving
    // whoever was typing in it when we left.
    _openTypingRoomId = null;
    _openTypingUsers = const [];
    _activeReadState.clear();
    _activeDeliveredState.clear();
    _initialLoaded.remove(roomId);
    _liveMessagesLoaded.remove(roomId);
    final me = _userId;
    // Guarantees at least one microtask boundary before the first
    // `notifyListeners()` below, on every path — including the one where
    // `_messages[roomId]` is already warm and the cache read beneath is
    // skipped entirely. `openRoom` is called synchronously from
    // `RoomScreen.initState()`, which can itself be running mid-build (e.g.
    // inside a `LayoutBuilder` rebuild triggered during layout); a
    // `notifyListeners()` reached with no await ahead of it hits a
    // listener's `setState()` on that SAME synchronous stack and crashes
    // with "setState() or markNeedsBuild() called during build." Dropping
    // the old one-shot `listMessages` fetch below removed the await that
    // used to guarantee this for free.
    await Future<void>.value();
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
    // Superseded while reading disk: bail before registering anything.
    // Nothing is dangling yet — no subscription has been created, and
    // everything written above is keyed by `roomId`, so a late write can't
    // corrupt whichever room won.
    if (gen != _openGen) return;
    _pending[roomId] ??= [];
    // Prime the dedup baseline with whatever we already have (cache, if any),
    // so the live subscription's first fire only trips `markRoomRead` when it
    // carries a message genuinely newer than what's already on screen.
    _lastSeenNewestMsgId[roomId] = _messages[roomId]?.isNotEmpty == true
        ? _messages[roomId]!.last.id
        : null;
    notifyListeners();
    // Subscribed directly rather than one-shot-fetched-then-subscribed: both
    // roads run the exact same `messages:list` query with the exact same
    // args, so fetching it here first only bought a SECOND round trip to the
    // same query in front of the subscription's own first `onData` — on a
    // resource-constrained backend, a redundant query per room-open that
    // competes with the one that actually matters. The subscription's first
    // fire below IS the initial load.
    final messagesSub = await cv.subscribe(
      'messages:list',
      // `viewerUserId` widens the subscription's read set by this viewer's OWN
      // view-once ledger rows and nothing else, which is deliberate: opening a
      // photo on another device refires this query here (so the bubble greys
      // out live) without refiring it for anybody else in the room.
      {'roomId': roomId, 'limit': kLiveWindow, 'viewerUserId': ?me},
      onData: (data) {
        final list = (data as List?) ?? const [];
        final parsed = list
            .map((e) => ChatMessage.fromJson((e as Map).cast<String, dynamic>()))
            .toList();
        // Re-attach any pages the user scrolled back through. A bare
        // `_messages[roomId] = parsed` would drop them: this subscription
        // refires on every reaction add/remove too, so a single reaction
        // used to collapse the room back to the newest [kLiveWindow] and —
        // because `_exhausted` isn't reset here — permanently kill
        // `hasMoreOlder`.
        _messages[roomId] = _withOlderPrefix(roomId, parsed);
        _initialLoaded.add(roomId);
        // Distinct from `_initialLoaded`: that one also flips true off a
        // cache-hydrate or bare subscription registration, neither of which
        // means the SERVER's own view of this room has actually landed. A
        // caller deciding whether to keep waiting for a message that isn't
        // in the cached snapshot yet — see `RoomScreen._maybeLandOnUnread` —
        // needs this stronger signal, or it gives up mid-race against the
        // live data that would have answered it.
        _liveMessagesLoaded.add(roomId);
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
            _scheduleMarkRead(roomId, me, parsed.last.createdAt);
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
    // Marked once the subscription is registered rather than held for its
    // first `onData`: registration is a local/instant op (see
    // `ConvexBackend.subscribe`), so this keeps `hasLoadedInitial` from
    // spinning forever on a device that opens a never-cached room offline.
    _initialLoaded.add(roomId);

    // Pinned messages. Registered here rather than by the room screen so the
    // `gen` guard and `SubscriptionRegistry`'s reconnect rebinding cover it for
    // free, exactly like the three around it.
    //
    // No paired one-shot fetch, unlike `messages:list` above: the banner is
    // zero-height until this lands, and the list is `reverse: true`, so a
    // reader sitting at the newest message sees nothing move when it arrives.
    final pinsSub = await cv.subscribe(
      'pins:listForRoom',
      {'roomId': roomId, 'viewerUserId': ?me},
      onData: (data) {
        final list = (data as List?) ?? const [];
        _pins[roomId] = list
            .whereType<Map>()
            .map((e) => RoomPin.fromJson(e.cast<String, dynamic>()))
            .toList();
        notifyListeners();
      },
      onError: (err) => debugPrint('pins sub error: $err'),
    );
    if (gen != _openGen) {
      pinsSub.cancel();
      return;
    }
    _pinsSub = pinsSub;

    // Poll, checklist and event state for this room's live window.
    //
    // Its own subscription and NOT part of `messages:list`, for the reason the
    // backend splits the tables: that query re-delivers a hundred messages to
    // every member whenever anything it reads changes, and a tally changes far
    // too often to ride on it. Here a vote re-delivers a handful of small rows.
    //
    // Registered beside the pins, and unconditional like them: `viewerUserId`
    // is optional server-side, so a signed-out reader still gets the tallies
    // and simply has no `myChoiceIds` — which is the correct state rather than
    // a gap. No paired one-shot fetch, for the same reason the pins have none:
    // a card renders its prompt from the message the moment the transcript
    // lands, and grows its choices when this arrives.
    final interactionsSub = await cv.subscribe(
      'interactions:listForRoom',
      {'roomId': roomId, 'viewerUserId': ?me},
      onData: (data) {
        final list = (data as List?) ?? const [];
        _mergeInteractions(
          roomId,
          list
              .whereType<Map>()
              .map((e) =>
                  MessageInteraction.fromJson(e.cast<String, dynamic>()))
              .toList(),
          // THE server's own word on the live window. Anything this fire does
          // not mention has either scrolled out of the window or been deleted,
          // and a pending tap on it is spent either way — see
          // [_mergeInteractions].
          authoritative: true,
        );
        // Written from the MERGED map rather than from `list`, so a poll
        // scrolled back to and hydrated by [ensureInteractionsFor] survives a
        // relaunch too — the live window does not mention it, and saving only
        // what this fire carried would quietly drop it.
        if (me != null) {
          CacheStore.instance.scheduleSaveInteractions(
            me,
            roomId,
            _interactions[roomId]?.values ?? const [],
          );
        }
        notifyListeners();
      },
      onError: (err) => debugPrint('interactions sub error: $err'),
    );
    if (gen != _openGen) {
      interactionsSub.cancel();
      return;
    }
    _interactionsSub = interactionsSub;

    // This viewer's saved messages. Registered beside the pins for the same
    // reasons, and gated on `me` because unlike `viewerUserId` above the
    // server's `userId` is required here — a bookmark list with no reader is
    // not a thing. Signed out there is nobody to have saved anything, so the
    // absent subscription is the correct state rather than a gap.
    if (me != null) {
      final bookmarksSub = await cv.subscribe(
        'bookmarks:listForRoom',
        {'roomId': roomId, 'userId': me},
        onData: (data) {
          final list = (data as List?) ?? const [];
          _bookmarks[roomId] = list
              .whereType<Map>()
              .map((e) => MessageBookmark.fromJson(e.cast<String, dynamic>()))
              .toList();
          notifyListeners();
        },
        onError: (err) => debugPrint('bookmarks sub error: $err'),
      );
      if (gen != _openGen) {
        bookmarksSub.cancel();
        return;
      }
      _bookmarksSub = bookmarksSub;
    }

    // This viewer's queued messages for this room. Gated on `me` for the same
    // reason the bookmarks above are: the server's `userId` is required, and a
    // scheduled message is private to its author, so there is nothing to
    // subscribe to for a reader who is not one.
    //
    // Room-scoped rather than account-wide on purpose. The pill and the list
    // only ever ask about the room on screen, and a whole-account subscription
    // would re-fire this room's UI whenever anything was queued in any other.
    if (me != null) {
      final scheduledSub = await cv.subscribe(
        'scheduledMessages:listForRoom',
        {'roomId': roomId, 'userId': me},
        onData: (data) {
          final list = (data as List?) ?? const [];
          final parsed = list
              .whereType<Map>()
              .map((e) => ScheduledMessage.fromJson(e.cast<String, dynamic>()))
              .toList()
            // The index already returns these in `sendAt` order, but the sort
            // is what keeps the list stable after an optimistic local insert
            // (see [scheduleText]) that has not been echoed by the server yet.
            ..sort((a, b) => a.sendAt.compareTo(b.sendAt));
          _scheduled[roomId] = parsed;
          notifyListeners();
        },
        onError: (err) => debugPrint('scheduled sub error: $err'),
      );
      if (gen != _openGen) {
        scheduledSub.cancel();
        return;
      }
      _scheduledSub = scheduledSub;
    }

    if (me != null) {
      final readStateSub = await cv.subscribe(
        'messages:getReadState',
        {'roomId': roomId, 'viewerUserId': me},
        onData: (data) {
          final list = (data as List?) ?? const [];
          _activeReadState.clear();
          _activeDeliveredState.clear();
          for (final e in list) {
            final m = (e as Map).cast<String, dynamic>();
            final uid = m['userId'].toString();
            // Each cursor is absent — not zero — when this member has not
            // shared it, so an `?? 0` here would invent an epoch receipt for
            // someone who shared nothing. Skipped instead, which is what the
            // "latest other" fold already expects.
            final read = m['lastReadAt'] as num?;
            if (read != null) {
              _activeReadState[uid] =
                  DateTime.fromMillisecondsSinceEpoch(read.toInt());
            }
            final delivered = m['lastDeliveredAt'] as num?;
            if (delivered != null) {
              _activeDeliveredState[uid] =
                  DateTime.fromMillisecondsSinceEpoch(delivered.toInt());
            }
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

    // Mark the room read on entry too. `upTo` is whatever this device already
    // holds — the disk cache, or the live window on re-entry — so the server
    // can skip its own room read. Anything newer than that arrives through the
    // subscription above and is marked from there, which is also the honest
    // order: a message is read when it is on screen, not when the room opens.
    // With nothing held it is omitted, and the server falls back to the room's
    // `lastMessageTime` as it always did.
    if (me != null) {
      final held = _messages[roomId];
      api
          .markRoomRead(
            roomId: roomId,
            userId: me,
            upTo: held != null && held.isNotEmpty ? held.last.createdAt : null,
          )
          .catchError((_) {});
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
    // Flushed, not dropped: whatever was queued was on screen a moment ago.
    _flushMarkRead();
    _messagesSub?.cancel();
    _activeTypingSub?.cancel();
    _readStateSub?.cancel();
    _pinsSub?.cancel();
    _bookmarksSub?.cancel();
    _scheduledSub?.cancel();
    _interactionsSub?.cancel();
    _messagesSub = null;
    _activeTypingSub = null;
    _readStateSub = null;
    _pinsSub = null;
    _bookmarksSub = null;
    _scheduledSub = null;
    _interactionsSub = null;
    _activeRoomId = null;
    // Hand the room back to the global stream's name-only entry.
    _openTypingRoomId = null;
    _openTypingUsers = const [];
    _activeReadState.clear();
    _activeDeliveredState.clear();
    _loadingOlder.clear();
    _exhausted.clear();
    _olderPrefix.clear();
    // The asked-for set, but NOT `_interactions` itself: the tallies are kept
    // exactly as `_pins` and `_messages` are, so re-entering the room paints a
    // complete card instantly instead of a poll with no bars. The ask-set goes
    // because the subscription will re-deliver the live window on re-entry, and
    // an old page's ids should be re-fetched if the reader scrolls back to
    // them again — a poll they last saw a week ago has moved on.
    _interactionsAsked.clear();
    _clearHistoryWindows();
  }

  /// Whether the first batch of messages (cache or server) has landed for
  /// [roomId]. Lets the UI show a loading state instead of the empty-state
  /// placeholder during the initial fetch.
  bool hasLoadedInitial(String roomId) => _initialLoaded.contains(roomId);

  /// Whether the `messages:list` SUBSCRIPTION has delivered at least once for
  /// [roomId] — stronger than [hasLoadedInitial], which a cache-hydrate alone
  /// already satisfies. A disk cache can be older than the last time this
  /// device was online, so a caller that needs to know the room's messages
  /// are actually current (not just non-empty) has to wait for this instead.
  bool hasLiveMessages(String roomId) => _liveMessagesLoaded.contains(roomId);

  final Set<String> _initialLoaded = {};
  final Set<String> _liveMessagesLoaded = {};

  // ───────────── pagination ─────────────

  final Set<String> _loadingOlder = {};
  final Set<String> _exhausted = {};

  /// Pages fetched by [loadOlder], kept separately from `_messages` so the
  /// `messages:list` subscription can rebuild its [kLiveWindow]-message live window
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
      // Poll/checklist/event bodies for anything on this page too old for the
      // live subscription's window. Deliberately NOT awaited: the page is
      // already assembled and the caller's scroll anchoring depends on this
      // returning promptly, while a card filling in a moment later is exactly
      // what happens when the subscription fires anyway.
      unawaited(ensureInteractionsFor(roomId, fresh));
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

      // Every branch below keeps this page one way or another, so ask once
      // here rather than in each of them. Un-awaited for the reason `loadOlder`
      // gives — the jump's scroll anchoring must not wait on a tally.
      unawaited(ensureInteractionsFor(roomId, page.messages));

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
      unawaited(ensureInteractionsFor(roomId, fresh));
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
      if (fresh.isNotEmpty) unawaited(ensureInteractionsFor(roomId, fresh));

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
    List<FormattingEntity> formatting = const [],
  }) async {
    return _send(
      roomId: roomId,
      content: text,
      type: MessageType.text,
      replyToId: replyToId,
      mentions: mentions,
      mentionsEveryone: mentionsEveryone,
      formatting: formatting,
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

  // ───────────── location ─────────────

  /// Feeds whichever live share this device is currently running. At most one
  /// — see [LiveLocationPublisher.start] for why that is a rule and not a
  /// simplification.
  final LiveLocationPublisher liveLocation = LiveLocationPublisher();

  /// The live share this device is publishing, if any. Read by the bubble to
  /// decide whether to offer STOP, and by the composer to decide whether
  /// offering to start another one makes sense.
  String? get activeLiveShareMessageId => liveLocation.activeMessageId;
  String? get activeLiveShareRoomId => liveLocation.activeRoomId;

  /// Listens for the STOP button on the platform's own notification.
  ///
  /// Installed once per repository rather than per share, and never cancelled:
  /// this object lives as long as the process does. The field is the
  /// double-subscribe guard, not a handle for teardown — a second listener would
  /// mean every STOP press firing two `messages:stopLiveLocation` mutations.
  ///
  /// Per-repository and not per-share on purpose. A subscription that came and
  /// went with each share would have a window — between the user pressing STOP
  /// and Dart noticing the share ended — in which the press went nowhere.
  StreamSubscription<void>? _platformStopSub;

  /// Whether the app has already picked up a share left behind by a previous
  /// process, this session.
  ///
  /// [attach] is re-entrant — `resubscribe()` calls it on every reconnect — and
  /// a resume that ran per reconnect would tear down and rebuild the position
  /// stream every time the socket blinked.
  bool _resumeAttempted = false;

  /// Wires the notification's STOP action to the same path the in-app button
  /// takes. Idempotent; called from [attach].
  ///
  /// Routed through [stopLiveLocation] rather than straight to the publisher
  /// because stopping from a notification has to mean the same thing as stopping
  /// from the bubble: the server is told, the row goes grey for the recipients,
  /// and the handle is forgotten. A version that only stopped the publisher
  /// would leave the share live for its full eight hours, silently stale, for a
  /// user who believes they turned it off — which is the worst outcome this
  /// feature has.
  void _bindPlatformStop() {
    LiveLocationPlatform.instance.ensureStarted();
    _platformStopSub ??= LiveLocationPlatform.instance.onStopRequested.listen((_) {
      final id = liveLocation.activeMessageId;
      if (id == null) return;
      unawaited(stopLiveLocation(messageId: id));
    });
  }

  /// Picks up a live share this device was running before the process died.
  ///
  /// Called from [attach], which is the first moment both halves exist: a
  /// restored session (so mutations can be authenticated) and an api. On iOS
  /// that point is reached even on a background relaunch, because the engine is
  /// started in `didFinishLaunchingWithOptions` before anything is on screen; on
  /// Android the boot receiver's service starts the same engine the same way.
  /// Neither path needs a widget tree, which is what makes this headless.
  ///
  /// Three things have to be true before a single GPS query is spent:
  ///
  ///  * a handle exists on disk — the share was started on THIS device;
  ///  * its deadline has not passed — [LiveShareResumeStore.takeResumable]
  ///    erases it if it has, so an expired share never resumes and never gets
  ///    re-examined;
  ///  * the platform still has location authorization at all.
  ///
  /// The server remains the authority over all three. The first published fix
  /// carries the same `messages:updateLiveLocation` checks as any other, so a
  /// share stopped from another handset, deleted, or belonging to a different
  /// account than the one that just signed in comes back `ok: false` and the
  /// publisher shuts itself down and forgets the handle. That is why this can be
  /// optimistic: the cost of a wrong guess is one refused mutation.
  Future<void> _resumeLiveShareIfAny() async {
    if (_resumeAttempted) return;
    _resumeAttempted = true;
    // A share is already running in this process — a reconnect, not a cold
    // start. Nothing to pick up.
    if (liveLocation.isRunning) return;

    final userId = _userId;
    if (userId == null) return;

    // Everything below is best-effort and none of it may throw out of here.
    // This runs unawaited from inside `attach`, so an escaping error surfaces as
    // an unhandled async exception during SIGN-IN — and there is nothing in a
    // failed resume worth that. Every one of these calls is a platform channel
    // that is legitimately absent on some hosts (a test binding, a background
    // isolate mid-registration), and the correct behaviour there is the one the
    // app already ships and describes honestly: the share stops when the
    // process does.
    try {
      final handle =
          await LiveShareResumeStore.instance.takeResumable(DateTime.now());
      if (handle == null) return;
      if (_userId != userId) return; // signed out again while we read the disk

      final availability = await LocationService.instance.check();
      if (availability != LocationAvailability.ready) {
        // Location was revoked or switched off while we were away. Deliberately
        // NOT cleared: the share is still live server-side and still within its
        // window, and a user who re-grants in the next five minutes should have
        // it pick up rather than have been quietly written off.
        return;
      }

      final tier = await LiveLocationPlatform.instance.authorizationTier();
      _bindPlatformStop();
      liveLocation.resume(
        handle: handle,
        monitorSignificantChanges: tierSurvivesTermination(tier),
        publish: (f) => api.updateLiveLocation(
          messageId: handle.messageId,
          userId: userId,
          latitude: f.latitude,
          longitude: f.longitude,
          accuracyM: f.accuracyM,
        ),
        onEnded: notifyListeners,
      );
      notifyListeners();
    } catch (e) {
      debugPrint('live share resume skipped: $e');
    }
  }

  /// Sends one position, frozen at send time.
  Future<void> sendLocation({
    required String roomId,
    required LocationFix fix,
    String? replyToId,
  }) async {
    await _send(
      roomId: roomId,
      content: '',
      type: MessageType.location,
      replyToId: replyToId,
      latitude: fix.latitude,
      longitude: fix.longitude,
      locationAccuracyM: fix.accuracyM,
    );
  }

  /// Posts a poll, checklist or event.
  ///
  /// ## Why there is no optimistic bubble
  ///
  /// Every other send in this repository draws one immediately and reconciles
  /// on the ack — see [_buildOptimistic]. This one cannot usefully, and the
  /// reason is the same split that makes the whole feature cheap: the message
  /// row carries only the prompt, and the CHOICES live in a second table this
  /// device does not have until the server writes them. An optimistic bubble
  /// would therefore be a card showing the question with no options under it,
  /// replaced a round trip later by the real one — a card that visibly grows
  /// while the sender watches, for a send they will wait on anyway.
  ///
  /// So this awaits the create and lets the two subscriptions deliver the
  /// finished card together. The cost is one round trip of latency on an act
  /// that already took a sheet and half a minute of typing; the alternative
  /// costs a flicker on every poll ever sent.
  ///
  /// Returns the new message's id, or null if the send was refused — the child
  /// gate, a block, a malformed definition the server would not take, or no
  /// connection. The caller says so; this does not throw, matching every other
  /// send here.
  Future<String?> sendInteraction({
    required String roomId,
    required MessageType kind,
    required String prompt,
    List<String>? labels,
    bool multiple = false,
    bool anonymous = false,
    bool quiz = false,
    int? correctIndex,
    String? explanation,
    bool othersMayCheck = true,
    bool othersMayAdd = true,
    DateTime? startsAt,
    DateTime? endsAt,
    String? place,
    String? replyToId,
  }) async {
    final me = _userId;
    if (me == null) return null;
    try {
      return await api.createInteraction(
        roomId: roomId,
        userId: me,
        kind: kind,
        prompt: prompt,
        labels: labels,
        multiple: multiple,
        anonymous: anonymous,
        quiz: quiz,
        correctIndex: correctIndex,
        explanation: explanation,
        othersMayCheck: othersMayCheck,
        othersMayAdd: othersMayAdd,
        startsAt: startsAt,
        endsAt: endsAt,
        place: place,
        replyToId: replyToId,
        // No `senderName`, matching [_postMessage]: `guardOutgoing` resolves
        // the sender's display name server-side, and a client-supplied one is
        // only ever a second chance to be wrong about it.
        //
        // Idempotency below. There is no retry loop for this send — no pending
        // bubble, so nothing sweeps it on reconnect — but the convex client
        // re-issues in-flight mutations across a reconnect on its own, and a
        // create that lands twice would be two polls asking the same question.
        // The server returns the existing message id on a repeat and skips
        // writing a second body; see `interactions:create`.
        clientId: 'int_${DateTime.now().microsecondsSinceEpoch}',
      );
    } catch (_) {
      return null;
    }
  }

  /// Starts a time-boxed live share and begins publishing to it.
  ///
  /// Written out rather than routed through [_send] because this is the one
  /// send in the app that needs the SERVER's id before it is finished: the
  /// publisher patches that exact row, and an optimistic `tmp_` id patches
  /// nothing. So the post is awaited and the publisher started from the ack.
  ///
  /// The publisher is deliberately started only on a confirmed send. Starting
  /// it optimistically would mean a failed send leaves a device quietly running
  /// its GPS for a share that does not exist.
  ///
  /// Returns whether the share started. False covers both a refused send (the
  /// child gate, a block, no connection) and an ack with no id.
  ///
  /// [notice] is the copy for the persistent notification the platform posts
  /// while the share runs — passed down from the room screen because that is
  /// where a `BuildContext`, and therefore a locale, exists. It is persisted
  /// with the share; see [LiveShareNotice].
  ///
  /// [monitorSignificantChanges] asks the platform for the relaunch-after-death
  /// behaviour, and is the caller's job to compute because it depends on a
  /// permission tier the caller has just been through a whole sheet about — see
  /// [decideLiveShareStart]. Passing false is not a degraded mode with a
  /// warning; it is the ordinary When-In-Use experience, which is complete.
  Future<bool> startLiveLocation({
    required String roomId,
    required LocationFix fix,
    required LiveShareDuration duration,
    required LiveShareNotice notice,
    bool monitorSignificantChanges = false,
  }) async {
    final userId = _userId;
    if (userId == null) return false;

    // Ending the previous share first is belt and braces: the server ends a
    // sender's earlier share in a room when a new one starts, and the publisher
    // stops its own predecessor. Doing it here as well is what makes the OLD
    // bubble go grey immediately rather than at the next subscription tick, and
    // covers the case where the earlier share is in a different room, which the
    // server's rule deliberately does not touch.
    final previous = liveLocation.activeMessageId;
    if (previous != null) {
      await stopLiveLocation(messageId: previous);
    }

    final optimistic = _buildOptimistic(
      roomId: roomId,
      content: '',
      type: MessageType.liveLocation,
      latitude: fix.latitude,
      longitude: fix.longitude,
      locationAccuracyM: fix.accuracyM,
      // The deadline the SERVER is about to compute, computed again here so the
      // sender's own bubble counts down from the moment they tapped rather than
      // from whenever the ack lands. The two can differ by the round trip; the
      // echo replaces this copy with the authoritative value.
      liveExpiresAt: DateTime.now().add(duration.duration),
      liveUpdatedAt: DateTime.now(),
      liveDurationMs: duration.milliseconds,
    );
    if (optimistic == null) return false;
    _pending.putIfAbsent(roomId, () => []).add(optimistic);
    notifyListeners();
    await _postMessage(roomId, optimistic);

    final serverId = optimistic.serverId;
    if (serverId == null || optimistic.status == MessageStatus.error) {
      // The honest limit here: an ack lost in transit means the share may
      // genuinely exist server-side while this device believes it failed. The
      // reconnect sweeper will re-post the bubble and collapse onto the same
      // row (the `clientId` key), but nothing restarts the publisher, so that
      // share sits at its first position until its deadline. Bounded by the
      // duration the user chose, visible to viewers as a stale share, and
      // preferable to the alternative — starting a publisher against an id this
      // device never actually received.
      return false;
    }

    _bindPlatformStop();
    liveLocation.start(
      messageId: serverId,
      roomId: roomId,
      expiresAt: optimistic.liveExpiresAt ?? DateTime.now(),
      firstFix: fix,
      notice: notice,
      monitorSignificantChanges: monitorSignificantChanges,
      publish: (f) => api.updateLiveLocation(
        messageId: serverId,
        userId: userId,
        latitude: f.latitude,
        longitude: f.longitude,
        accuracyM: f.accuracyM,
      ),
      // The publisher shutting down is not the share ending, but it IS the
      // moment the sender's own controls have to stop claiming to be live.
      onEnded: notifyListeners,
    );
    notifyListeners();
    return true;
  }

  /// Ends a live share early.
  ///
  /// Stops the publisher first, then tells the server. That order matters: the
  /// reverse leaves a window in which the server has ended the share and this
  /// device is still sending fixes into it — harmless, because
  /// `updateLiveShare` refuses them, but it produces a burst of pointless
  /// mutations for every stop.
  ///
  /// The local row is patched straight away rather than waiting for the echo,
  /// so the bubble greys out on the tap. The subscription overwrites it with
  /// the server's version a moment later; the two agree.
  Future<void> stopLiveLocation({required String messageId}) async {
    final userId = _userId;
    if (liveLocation.isRunningFor(messageId)) {
      // `forget: true` — this is the share ending, not merely this process
      // letting go of it. Leaving the handle behind would have the next launch
      // cheerfully restart a share the user has just switched off, and it would
      // be right to, because nothing else on disk says otherwise.
      await liveLocation.stop(forget: true);
    } else {
      // Stopping a share this device is not feeding — from the notification of
      // a share whose publisher already gave up, or from another room's bubble.
      // The handle still has to go, for the same reason.
      unawaited(LiveShareResumeStore.instance.clear());
    }
    _markLiveShareEndedLocally(messageId);
    if (userId == null) return;
    try {
      await api.stopLiveLocation(messageId: messageId, userId: userId);
    } catch (_) {
      // The share still ends on its own deadline, and the local row already
      // reads as ended. Surfacing this would offer the user a retry for
      // something that has, from where they are standing, already happened.
    }
  }

  void _markLiveShareEndedLocally(String messageId) {
    var touched = false;
    for (final list in [..._messages.values, ..._pending.values]) {
      for (final m in list) {
        if (m.id != messageId && m.serverId != messageId) continue;
        if (m.liveEndedAt != null) continue;
        m.liveEndedAt = DateTime.now();
        touched = true;
      }
    }
    if (touched) notifyListeners();
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
  // The honest limit: only the newest [kLiveWindow] room messages are live, so thread
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
    List<FormattingEntity> formatting = const [],
    double? latitude,
    double? longitude,
    double? locationAccuracyM,
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
      formatting: formatting,
      latitude: latitude,
      longitude: longitude,
      locationAccuracyM: locationAccuracyM,
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
    String? fileName,
    int? fileSize,
    String? mimeType,
    int? mediaDurationMs,
    String? replyToId,
    bool viewOnce = false,
    MessageStatus status = MessageStatus.pending,
    PendingUpload? upload,
    List<MessageMention> mentions = const [],
    bool mentionsEveryone = false,
    List<FormattingEntity> formatting = const [],
    double? latitude,
    double? longitude,
    double? locationAccuracyM,
    DateTime? liveExpiresAt,
    DateTime? liveUpdatedAt,

    /// Carried on the optimistic bubble so [_postMessage] — and therefore both
    /// reconnect sweepers, which re-post from the bubble alone — send the same
    /// duration on a retry that the first attempt sent. A retry that dropped it
    /// would turn the user's eight-hour share into a static pin.
    int? liveDurationMs,
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
      fileName: fileName,
      fileSize: fileSize,
      mimeType: mimeType,
      mediaDurationMs: mediaDurationMs,
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
      // Same story: the bold the sender applied must render bold on their own
      // pending bubble, and both reconnect sweepers re-post from this object
      // alone — a retry that dropped the spans would deliver the text
      // unformatted.
      formatting: formatting,
      latitude: latitude,
      longitude: longitude,
      locationAccuracyM: locationAccuracyM,
      liveExpiresAt: liveExpiresAt,
      liveUpdatedAt: liveUpdatedAt,
      liveShareDurationMs: liveDurationMs,
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
        // Read off the message for the same reason as everything else here: a
        // reconnect sweeper re-posting this must not turn a named document into
        // an anonymous one, and neither sweeper knows documents exist.
        fileName: optimistic.fileName,
        fileSize: optimistic.fileSize,
        mimeType: optimistic.mimeType,
        mediaDurationMs: optimistic.mediaDurationMs,
        // Assigned by the upload queue a moment before this runs. Read off the
        // message for the same reason as everything else here: both reconnect
        // sweepers re-post through this path and neither knows posters exist.
        posterStorageId: optimistic.posterStorageId,
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
        // Read off the message like the mentions above, and for the same
        // reason: the spans must survive a reconnect retry.
        formatting: optimistic.formatting,
        // The bubble's own local id, which is stable across every retry of this
        // message — that stability is the entire mechanism. Two attempts at the
        // same send carry the same key and collapse to one row; two genuinely
        // different sends never share one.
        clientId: optimistic.id,
        // Read off the message for exactly the same reason as everything above:
        // a reconnect sweeper re-posting this knows nothing about locations, and
        // a retry that dropped these would turn the user's live share into a
        // static pin — or into an empty bubble with no coordinates at all.
        latitude: optimistic.latitude,
        longitude: optimistic.longitude,
        locationAccuracyM: optimistic.locationAccuracyM,
        liveDurationMs: optimistic.liveShareDurationMs,
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
    String? fileName,
    int? fileSize,
    int? mediaDurationMs,

    /// A JPEG still frame for a video, extracted by the sender before the
    /// picker's file was read. Uploaded ahead of the video itself and
    /// best-effort — see `_runUpload`. Always null on web and desktop, where
    /// extraction is not possible.
    Uint8List? posterBytes,
    String? caption,
    String? replyToId,
    bool viewOnce = false,
  }) async {
    final upload = PendingUpload(
      bytes: bytes,
      contentType: contentType,
      // Never on an armed send: the server refuses to store a poster for one,
      // so uploading it would only orphan a blob — and a still frame of a
      // view-once video is the exact thing that must not leak.
      posterBytes: viewOnce ? null : posterBytes,
    );
    final optimistic = _buildOptimistic(
      roomId: roomId,
      content: caption ?? '',
      type: type,
      fileName: fileName,
      fileSize: fileSize,
      mimeType: fileName == null ? null : contentType,
      mediaDurationMs: viewOnce ? null : mediaDurationMs,
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
              // Kept even on the refusal bubble: a failed document row with no
              // name is an anonymous grey plate, and the user needs to see
              // *which* file was too big to send.
              fileName: fileName,
              fileSize: fileSize,
              mimeType: fileName == null ? null : contentType,
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
      // The poster first, and best-effort. It is a fraction of the video's
      // size, so it costs the sender almost nothing — and going first means a
      // video that succeeds always has its poster, rather than the pair racing
      // and sometimes landing a video with a poster id it has to patch in
      // afterwards.
      //
      // A failure here is swallowed on purpose: a poster is an enhancement to
      // a send that must happen regardless, and `gcOrphanedFiles` reclaims a
      // blob nothing ever referenced. Not passed the cancel `task` either —
      // cancelling should stop the video, and a poster upload that outlives it
      // by a moment is reclaimed the same way.
      if (upload.posterBytes != null && message.posterStorageId == null) {
        try {
          message.posterStorageId = await UploadService(api).uploadFile(
            bytes: upload.posterBytes!,
            contentType: 'image/jpeg',
          );
        } catch (e) {
          debugPrint('poster upload failed (sending video anyway): $e');
        }
        if (upload.disposed) return;
      }

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

  // ───────────── editing ─────────────

  /// How far this device's clock is from the server's, sampled by
  /// [_sampleServerClock]. Zero until the first sample lands, which fails
  /// safe in both directions: the mutation re-checks the window with the
  /// server's own clock regardless, so the worst an unsampled offset can do
  /// is offer an Edit row the server refuses (surfaced as the expired snack)
  /// or hide one a minute early.
  Duration _serverSkew = Duration.zero;

  /// The current moment as the SERVER understands it. What every edit-window
  /// question must be asked against — `DateTime.now()` on a device that
  /// drifted five minutes would offer edits the server refuses, or withhold
  /// ones it would take.
  DateTime get serverNow => DateTime.now().add(_serverSkew);

  /// One-shot skew sample, the `feed.serverNow` pattern. Half the round-trip
  /// is deliberately NOT compensated for: the window is fifteen minutes and
  /// the affordance already keeps a client-side grace besides, so NTP-grade
  /// precision buys nothing a comment has to justify.
  Future<void> _sampleServerClock() async {
    try {
      final server = await api.serverNow();
      _serverSkew = server.difference(DateTime.now());
    } catch (_) {/* offline — zero skew remains, and the server re-checks */}
  }

  /// Rewrites [message]'s text (the caller's own, inside the 15-minute
  /// window). Returns null on success, or an error code the caller must
  /// surface — the [pinMessage] shape, because a menu row that silently does
  /// nothing reads as broken.
  ///
  /// Optimistic: the in-memory row is patched before the mutation is awaited,
  /// so the sender's own transcript shows the new text immediately, and
  /// reverted if the server refuses. On success nothing further happens here —
  /// `messages:list` re-fires with the authoritative row and overwrites the
  /// guess (the mark-read dedupe keys on the newest id, so an edit never
  /// triggers a spurious markRoomRead).
  ///
  /// Online-only by design: there is no pending-edit sweeper. A queued edit
  /// against a fifteen-minute window is mostly a way to fail later instead of
  /// now, with the composer long since torn down and nowhere to put the text
  /// back.
  Future<String?> editMessage({
    required String roomId,
    required ChatMessage message,
    required String content,
    List<MessageMention> mentions = const [],
    bool mentionsEveryone = false,
    List<FormattingEntity> formatting = const [],
  }) async {
    final id = _userId;
    if (id == null) return null;

    // Patch the live copy in place, remembering how to undo it. The list
    // entry is swapped for a copy rather than mutated so the revert is one
    // assignment of the untouched original.
    final list = _messages[roomId];
    final idx = list?.indexWhere((m) => m.id == message.id) ?? -1;
    final ChatMessage? snapshot = idx >= 0 ? list![idx] : null;
    if (snapshot != null) {
      list![idx] = snapshot.copyWith(
        content: content,
        edited: true,
        mentions: mentions,
        mentionsEveryone: mentionsEveryone,
        formatting: formatting,
      );
      notifyListeners();
    }

    final err = await api.editMessage(
      messageId: message.id,
      userId: id,
      content: content,
      mentionedUserIds: [for (final m in mentions) m.userId],
      mentionsEveryone: mentionsEveryone,
      formatting: formatting,
    );
    if (err != null && snapshot != null) {
      // Refused: put the original back — unless the subscription has already
      // replaced the whole list, in which case whatever it delivered IS the
      // authoritative state and overwriting it would resurrect the failure.
      final cur = _messages[roomId];
      final curIdx = cur?.indexWhere((m) => m.id == message.id) ?? -1;
      if (curIdx >= 0 && cur![curIdx].edited && !snapshot.edited) {
        cur[curIdx] = snapshot;
        notifyListeners();
      }
    }
    return err;
  }

  // ───────────── pins ─────────────

  /// This room's pinned messages, oldest message first. Empty until the
  /// subscription lands, and offline.
  // ───────────── interactive messages ─────────────

  /// The poll, checklist or event body for [messageId], or null.
  ///
  /// Null is an ordinary, expected state and NOT an error: the transcript and
  /// the interaction subscription land independently, and the message usually
  /// arrives first. Every card is built to draw the prompt from
  /// [ChatMessage.content] and grow its choices when this fills in — which is
  /// also what it shows for an interaction too old for the live window, until
  /// [ensureInteractionsFor] fetches it.
  MessageInteraction? interactionFor(String roomId, String messageId) =>
      _interactions[roomId]?[messageId];

  /// Folds a batch of server state into [_interactions].
  ///
  /// Upsert, never replace — see the field's own comment for why. The two
  /// callers differ only in [authoritative]: the live subscription knows its
  /// rows are the server's current word and so may retire this device's
  /// pending taps on them, while a one-shot page hydrate is a snapshot that may
  /// already be older than a tap still in flight, and must leave those alone.
  void _mergeInteractions(
    String roomId,
    List<MessageInteraction> incoming, {
    required bool authoritative,
  }) {
    if (incoming.isEmpty) return;
    final slot = _interactions[roomId] ??= {};
    for (final fresh in incoming) {
      final existing = slot[fresh.messageId];
      // Carry this device's in-flight taps forward across a fire that isn't
      // about them. A vote by somebody else refires this subscription, and
      // dropping the marker there would un-fill the control the reader is
      // still waiting on.
      final pending = authoritative
          ? const <String>{}
          : (existing?.pendingChoiceIds ?? const <String>{});
      slot[fresh.messageId] =
          pending.isEmpty ? fresh : fresh.copyWith(pendingChoiceIds: pending);
    }
  }

  /// Fetches interaction state for any of [messages] that needs it and hasn't
  /// been asked about yet.
  ///
  /// The paging counterpart to the live subscription. Called after a page of
  /// history lands, because `interactions:listForRoom` only carries the newest
  /// hundred — a poll scrolled back to would otherwise render its question with
  /// no bars, forever.
  ///
  /// Filters to the interactive types before asking, so an ordinary page of
  /// text costs no round trip at all. Fire-and-forget: the caller is a
  /// pagination path whose own result must not wait on this, and a card that
  /// fills in a moment later is the same experience as one that fills in when
  /// the subscription fires.
  Future<void> ensureInteractionsFor(
    String roomId,
    List<ChatMessage> messages,
  ) async {
    final me = _userId;
    if (me == null) return;
    final asked = _interactionsAsked[roomId] ??= {};
    final want = <String>[
      for (final m in messages)
        if (m.type.isInteractive &&
            !asked.contains(m.id) &&
            // An optimistic bubble has no server id to ask about.
            !m.id.startsWith('tmp_'))
          m.id,
    ];
    if (want.isEmpty) return;
    // Marked BEFORE the await, not after. Two page loads can overlap, and a
    // set updated on completion would let the second re-ask for everything the
    // first is still fetching.
    asked.addAll(want);
    try {
      final rows =
          await api.interactionStateFor(messageIds: want, userId: me);
      if (rows.isEmpty) return;
      _mergeInteractions(roomId, rows, authoritative: false);
      notifyListeners();
    } catch (_) {
      // Let them be re-asked. A card with no bars is recoverable by scrolling
      // away and back; an id stuck in the asked-set after a dropped request
      // never is.
      asked.removeAll(want);
    }
  }

  /// Records this reader's answer to one choice, optimistically.
  ///
  /// The optimism is deliberately PARTIAL: the tapped control fills in at once,
  /// and the tally does not move until the server says it has. Moving the bar
  /// locally would make a dropped mutation indistinguishable from a counted
  /// vote — the bar would grow and then shrink back, which is the one thing an
  /// optimistic update must never do. A control that fills and then un-fills is
  /// legible; a percentage that changes twice is not.
  ///
  /// Toggles, exactly as the server does: tapping a choice you already hold
  /// takes it back. The server owns that rule — this only mirrors it well
  /// enough to draw the pending state.
  ///
  /// Returns false when the server refused (a closed poll, a quiz already
  /// answered, a checklist somebody else's tick), so the caller can say so.
  Future<bool> respondToInteraction({
    required String roomId,
    required String messageId,
    required String choiceId,
  }) async {
    final me = _userId;
    if (me == null) return false;
    final current = _interactions[roomId]?[messageId];
    if (current != null) {
      _interactions[roomId]![messageId] = current.copyWith(
        pendingChoiceIds: {...current.pendingChoiceIds, choiceId},
      );
      notifyListeners();
    }
    try {
      await api.respondToInteraction(
        messageId: messageId,
        userId: me,
        choiceId: choiceId,
      );
      return true;
    } catch (_) {
      return false;
    } finally {
      // Cleared whichever way it went, and harmlessly racing the subscription
      // fire that also clears it: both settle on the same state, so whoever
      // wins is right. Re-read rather than closing over `current`, because the
      // fire may have replaced the row while this was in flight.
      final after = _interactions[roomId]?[messageId];
      if (after != null && after.pendingChoiceIds.contains(choiceId)) {
        _interactions[roomId]![messageId] = after.copyWith(
          pendingChoiceIds: {...after.pendingChoiceIds}..remove(choiceId),
        );
        notifyListeners();
      }
    }
  }

  /// Clears every answer this reader holds on one interaction.
  ///
  /// Not the same as toggling one choice off: a multiple-answer poll needs one
  /// control meaning "retract my vote" rather than six taps, and the server has
  /// a separate mutation for exactly that.
  Future<bool> retractInteraction({
    required String roomId,
    required String messageId,
  }) async {
    final me = _userId;
    if (me == null) return false;
    try {
      await api.retractInteraction(messageId: messageId, userId: me);
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Appends an item to a checklist.
  ///
  /// No optimistic row. Unlike a tap on an existing control — which has
  /// somewhere to show pending — a new item has no widget yet, and inserting a
  /// provisional one that might vanish is worse than the half-second wait.
  Future<bool> addChecklistItem({
    required String messageId,
    required String label,
  }) async {
    final me = _userId;
    if (me == null) return false;
    try {
      await api.addChecklistItem(
        messageId: messageId,
        userId: me,
        label: label,
      );
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> removeChecklistItem({
    required String messageId,
    required String choiceId,
  }) async {
    final me = _userId;
    if (me == null) return false;
    try {
      await api.removeChecklistItem(
        messageId: messageId,
        userId: me,
        choiceId: choiceId,
      );
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Ends a poll, checklist or event. One-way — there is no reopen.
  Future<bool> closeInteraction({required String messageId}) async {
    final me = _userId;
    if (me == null) return false;
    try {
      await api.closeInteraction(messageId: messageId, userId: me);
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Whether to OFFER this reader the close / remove-item controls.
  ///
  /// The author, and only the author — which is deliberately NARROWER than the
  /// server's rule. `interactions.mayAdminister` also admits room admins, so an
  /// abandoned poll always has somebody who can settle it; but knowing whether
  /// this reader is one would mean a `roomAdmin:myPermissions` subscription per
  /// room open, and the transcript's subscription budget is the one thing this
  /// repository guards hardest (see the `messages:list` comments, and
  /// `speakerColors`' whole reason for existing). One more live query on every
  /// room open, to decide whether to draw a menu row that is used once a month,
  /// is not a trade worth making.
  ///
  /// Narrower is the safe direction: an admin who taps CLOSE from a surface
  /// that does offer it — room info, where the permissions are already
  /// loaded — is still allowed by the server. Nothing is lost except a row, and
  /// no privilege is granted by a stale answer here.
  bool canAdministerInteraction(MessageInteraction interaction) =>
      _userId != null && interaction.createdBy == _userId;

  List<RoomPin> pinsFor(String roomId) => _pins[roomId] ?? const [];

  bool isMessagePinned(String roomId, String messageId) =>
      pinsFor(roomId).any((p) => p.message.id == messageId);

  /// Pins [messageId]. Returns null on success, or an error code the caller
  /// must surface.
  ///
  /// Deviates from [toggleReaction]'s swallow-and-reconcile on purpose: a
  /// refused pin is a refusal the user has to see. The per-room cap is the
  /// entire reason this can fail, and silently doing nothing would read as the
  /// button being broken.
  Future<String?> pinMessage(String roomId, String messageId) async {
    final id = _userId;
    if (id == null) return null;
    try {
      await api.pinMessage(messageId: messageId, userId: id);
      return null;
    } catch (e) {
      return e.toString().contains('PIN_LIMIT_REACHED')
          ? 'PIN_LIMIT_REACHED'
          : 'PIN_FAILED';
    }
  }

  Future<void> unpinMessage(String roomId, String messageId) async {
    final id = _userId;
    if (id == null) return;
    try {
      await api.unpinMessage(messageId: messageId, userId: id);
    } catch (_) {/* swallow — live subscription will reconcile */}
  }

  // ───────────── scheduled messages ─────────────

  /// This viewer's queued messages for [roomId], soonest first. Empty until the
  /// subscription lands, and offline.
  ///
  /// Includes rows whose release FAILED — they keep their place in the order,
  /// because the user last saw them at that position and a failure moving them
  /// would read as a second thing having happened. Callers that want only the
  /// live ones filter on [ScheduledMessage.pending]; [pendingScheduledCount]
  /// is the one that matters for the pill.
  List<ScheduledMessage> scheduledFor(String roomId) =>
      _scheduled[roomId] ?? const [];

  /// How many messages are still waiting to go out in [roomId].
  ///
  /// What the composer's badge and the pill both count, and deliberately NOT
  /// `scheduledFor(...).length`: a failed row is something to deal with, not
  /// something that is going to be sent, and counting it would make the pill
  /// promise a delivery that is not coming.
  int pendingScheduledCount(String roomId) =>
      scheduledFor(roomId).where((s) => s.pending).length;

  /// Whether any queued message in [roomId] needs the sender's attention.
  bool hasFailedScheduled(String roomId) =>
      scheduledFor(roomId).any((s) => s.hasFailed);

  /// Queues [text] for [sendAt] (absolute) or [delayMs] (a length). Returns
  /// null on success, or an error code the caller must surface.
  ///
  /// Follows [pinMessage]'s report-don't-swallow contract rather than
  /// [unpinMessage]'s, and for a sharper version of the same reason: every way
  /// this fails is a refusal the user has to see, and the whole point of the
  /// feature is that nothing happens now — so a silently dropped schedule looks
  /// exactly like a successful one until the day it doesn't arrive.
  ///
  /// The child-gate codes are passed through unwrapped so the room screen can
  /// route them into `showApprovalGate` the way a live send's refusal already
  /// goes (see `_RoomScreenState._handleSendGate`).
  Future<String?> scheduleText(
    String roomId,
    String text, {
    int? delayMs,
    int? sendAt,
    String? replyToId,
    List<MessageMention> mentions = const [],
    bool mentionsEveryone = false,
    List<FormattingEntity> formatting = const [],
  }) async {
    final id = _userId;
    if (id == null) return 'SCHEDULE_FAILED';
    try {
      await api.scheduleMessage(
        roomId: roomId,
        userId: id,
        content: text,
        delayMs: delayMs,
        sendAt: sendAt,
        replyToId: replyToId,
        mentionedUserIds: [for (final m in mentions) m.userId],
        mentionsEveryone: mentionsEveryone,
        formatting: formatting,
        // The local id shape `_buildOptimistic` already uses, for the same
        // purpose: one key that survives every retry of this one message.
        clientId: 'sch_${DateTime.now().microsecondsSinceEpoch}',
      );
      return null;
    } catch (e) {
      return _scheduleErrorCode(e);
    }
  }

  /// Moves a queued message to a new time, or retries a failed one.
  Future<String?> rescheduleMessage(
    String id, {
    int? delayMs,
    int? sendAt,
  }) async {
    final me = _userId;
    if (me == null) return 'SCHEDULE_FAILED';
    try {
      await api.rescheduleMessage(
        id: id,
        userId: me,
        delayMs: delayMs,
        sendAt: sendAt,
      );
      return null;
    } catch (e) {
      return _scheduleErrorCode(e);
    }
  }

  /// Rewrites a queued message's text, leaving its time alone.
  Future<String?> updateScheduledText(
    String id,
    String text, {
    List<MessageMention> mentions = const [],
    bool mentionsEveryone = false,
    List<FormattingEntity> formatting = const [],
  }) async {
    final me = _userId;
    if (me == null) return 'SCHEDULE_FAILED';
    try {
      await api.updateScheduledText(
        id: id,
        userId: me,
        content: text,
        mentionedUserIds: [for (final m in mentions) m.userId],
        mentionsEveryone: mentionsEveryone,
        formatting: formatting,
      );
      return null;
    } catch (e) {
      return _scheduleErrorCode(e);
    }
  }

  /// Drops a queued message.
  ///
  /// The one call here that swallows, [unpinMessage]-style: the row vanishing
  /// from the live subscription is the confirmation, and a delete that failed
  /// leaves the row visibly still there, which says so without a message.
  Future<void> cancelScheduledMessage(String id) async {
    final me = _userId;
    if (me == null) return;
    try {
      await api.cancelScheduledMessage(id: id, userId: me);
    } catch (_) {/* swallow — live subscription will reconcile */}
  }

  /// Sends a queued message now.
  Future<String?> sendScheduledNow(String id) async {
    final me = _userId;
    if (me == null) return 'SCHEDULE_FAILED';
    try {
      await api.sendScheduledNow(id: id, userId: me);
      return null;
    } catch (e) {
      return _scheduleErrorCode(e);
    }
  }

  /// Narrows a thrown Convex error to the code the UI knows how to say.
  ///
  /// Substring matching rather than parsing, matching [pinMessage]: the wire
  /// carries the server's `Error.message` wrapped in framing that differs by
  /// platform, so the code is looked for inside it rather than expected to BE
  /// it. An unrecognised failure becomes the generic code rather than leaking
  /// a stack trace into a sheet.
  ///
  /// The child-gate strings deliberately pass through verbatim: the room screen
  /// tests them with `isChildBlockedOutright` and routes them into the approval
  /// sheet, exactly as it does for a refused live send.
  String _scheduleErrorCode(Object e) {
    final s = e.toString();
    for (final code in const [
      'SCHEDULE_OUT_OF_RANGE',
      'SCHEDULE_NOT_IN_EPHEMERAL',
      'TOO_MANY_SCHEDULED',
      'SCHEDULE_EMPTY',
      'SCHEDULE_GONE',
      'NOT_YOURS',
      'UNBLOCK_FIRST',
      'NOT_A_MEMBER',
    ]) {
      if (s.contains(code)) return code;
    }
    // The two child-guard codes, returned verbatim so the caller can put them
    // straight through `isChildBlockedOutright` — the same value a refused live
    // send leaves in `takeChildGateError`.
    if (s.contains(kChildNotAllowed)) return kChildNotAllowed;
    if (s.contains(kChildApprovalRequired)) return kChildApprovalRequired;
    return 'SCHEDULE_FAILED';
  }

  // ───────────── saved messages (per-reader bookmarks) ─────────────
  //
  // Not the `dm:self:` Saved Messages ROOM, which is a place you forward copies
  // to and which this repository reaches through the ordinary room APIs. See
  // `lib/models/message_bookmark.dart`.

  /// The messages THIS viewer saved in [roomId], most recently saved first.
  /// Empty until the subscription lands, and offline.
  List<MessageBookmark> savedFor(String roomId) =>
      _bookmarks[roomId] ?? const [];

  bool isMessageSaved(String roomId, String messageId) =>
      savedFor(roomId).any((b) => b.message.id == messageId);

  /// This reader's manual speaker colours in [roomId] — subject id to palette
  /// slot, empty for the overwhelming majority of rooms.
  ///
  /// Handed straight to `SpeakerSlots.forMembers`, which folds the pins into
  /// the assignment so nothing downstream of it pays for this feature.
  Map<String, int> speakerColorsFor(String roomId) =>
      _speakerColors[roomId] ?? const {};

  /// Pins [subjectId] to [slot] for this reader in [roomId], or clears the pin
  /// when [slot] is null. Returns null on success, or an error code to surface.
  ///
  /// Applied locally first. The round trip is short but it is a round trip, and
  /// a colour that arrives a beat after the tap reads as a laggy picker — this
  /// is a preference, not a fact being negotiated with anyone. The subscription
  /// echo that follows is identical to what is already on screen, so it lands
  /// as a no-op rather than a second repaint.
  Future<String?> setSpeakerSlot(
    String roomId,
    String subjectId,
    int? slot,
  ) async {
    final id = _userId;
    if (id == null) return null;
    final before = _speakerColors;
    final next = {
      for (final e in before.entries) e.key: Map<String, int>.from(e.value),
    };
    final room = next.putIfAbsent(roomId, () => <String, int>{});
    if (slot == null) {
      room.remove(subjectId);
      if (room.isEmpty) next.remove(roomId);
    } else {
      room[subjectId] = slot;
    }
    _speakerColors = next;
    notifyListeners();
    try {
      await api.setSpeakerSlot(
        viewerId: id,
        roomId: roomId,
        subjectId: subjectId,
        slot: slot,
      );
      return null;
    } catch (e) {
      // Put the old map back rather than leaving the optimistic one to be
      // corrected by the next subscription delivery — which, on the failure
      // that matters here (the per-room cap), never comes, because nothing was
      // written and so nothing invalidates.
      _speakerColors = before;
      notifyListeners();
      return e.toString().contains('OVERRIDE_LIMIT')
          ? 'OVERRIDE_LIMIT'
          : 'SPEAKER_COLOR_FAILED';
    }
  }

  /// Drops every override this reader holds in [roomId] — the picker's "back to
  /// automatic for everyone" affordance.
  Future<void> clearSpeakerSlots(String roomId) async {
    final id = _userId;
    if (id == null) return;
    final before = _speakerColors;
    if (!before.containsKey(roomId)) return;
    _speakerColors = {
      for (final e in before.entries)
        if (e.key != roomId) e.key: e.value,
    };
    notifyListeners();
    try {
      await api.clearSpeakerSlots(viewerId: id, roomId: roomId);
    } catch (_) {
      _speakerColors = before;
      notifyListeners();
    }
  }

  /// Saves [messageId]. Returns null on success, or an error code the caller
  /// must surface.
  ///
  /// Shaped like [pinMessage] rather than [toggleReaction] for the same reason:
  /// the per-room cap is the only way this fails, and a menu row that silently
  /// does nothing reads as broken.
  Future<String?> saveMessage(String roomId, String messageId) async {
    final id = _userId;
    if (id == null) return null;
    try {
      await api.saveMessage(messageId: messageId, userId: id);
      return null;
    } catch (e) {
      return e.toString().contains('SAVE_LIMIT_REACHED')
          ? 'SAVE_LIMIT_REACHED'
          : 'SAVE_FAILED';
    }
  }

  Future<void> unsaveMessage(String roomId, String messageId) async {
    final id = _userId;
    if (id == null) return;
    try {
      await api.unsaveMessage(messageId: messageId, userId: id);
    } catch (_) {/* swallow — live subscription will reconcile */}
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
