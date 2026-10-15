import 'dart:async';
import 'dart:collection';

import 'package:flutter/foundation.dart';

import '../backend/chat_api.dart';
import '../backend/convex_client.dart';
import '../diagnostics/diag_log.dart';
import '../media/image_raster.dart' show CroppedImage;
import '../media/upload_service.dart';
import '../models/chat_message.dart';
import '../models/chat_room.dart';
import '../models/chat_user.dart';
import '../models/enums.dart';
import '../models/expression_item.dart';
import '../models/family.dart';
import '../models/friend_request.dart';
import '../models/location_share.dart';
import '../models/message_bookmark.dart';
import '../models/message_capabilities.dart';
import '../models/message_formatting.dart';
import '../models/message_interaction.dart';
import '../models/message_reaction.dart';
import '../models/reaction_limits.dart';
import '../models/pending_upload.dart';
import '../models/room_admin.dart';
import '../models/room_capabilities.dart';
import '../models/room_mute.dart';
import '../models/room_pin.dart';
import '../models/scheduled_message.dart';
import '../push/push_manager.dart';
import '../push/viewer_presence.dart';
import '../services/live_location_permission.dart';
import '../services/live_location_platform.dart';
import '../services/live_location_publisher.dart';
import '../services/live_share_resume_store.dart';
import '../services/location_service.dart';
import 'cache_store.dart';
import 'ordered_send_queue.dart';
import 'pending_reconcile.dart';
import 'room_filter.dart';
import 'settings_store.dart';

/// Server refusals a send can hit that a retry can't fix right away. See
/// `backend/convex/rateLimit.ts`, `files.ts` and `messages.ts`.
const kSendLimitCodes = [
  'RATE_LIMITED',
  'STORAGE_QUOTA_EXCEEDED',
  'FILE_TOO_LARGE',
  'MESSAGE_TOO_LONG',
];

/// Source of truth for chat data (rooms + open-room messages).
///
/// Mirrors v02's `ChatRepository` SSOT pattern. Owns:
///   - rooms list (subscription-driven)
///   - per-room cached message lists
///   - active subscriptions (rooms; messages of currently open room)
///   - optimistic pending sends
class ChatRepository extends ChangeNotifier {
  /// Every change to an unsent message already announces itself here — a new
  /// bubble, a status flip, an upload landing, a discard, a reconciliation — so
  /// this is where the outbox follows it to disk, rather than at each of the
  /// dozen sites that touch [_pending] and the next one somebody adds.
  @override
  void notifyListeners() {
    _saveOutboxIfChanged();
    super.notifyListeners();
  }

  /// Whether [m] is an unsent message worth keeping across a restart.
  ///
  /// Not one the server has acked (`sent` — it exists, the echo is only late),
  /// and not a live location share, whose publisher does not survive a restart
  /// either: re-sent later it would be a share nobody is feeding. An attachment
  /// needs either its storage id or its bytes; one with neither (the
  /// too-large refusal) has nothing to retry with.
  static bool _belongsInOutbox(ChatMessage m) {
    if (m.status == MessageStatus.sent) return false;
    if (m.liveShareDurationMs != null) return false;
    if (!m.isMedia || m.mediaStorageId != null) return true;
    final up = m.upload;
    return up != null && !up.disposed;
  }

  void _saveOutboxIfChanged() {
    final uid = _userId;
    if (uid == null || _outboxLoadedFor != uid) return;
    final unsent = <ChatMessage>[
      for (final list in _pending.values)
        for (final m in list)
          if (_belongsInOutbox(m)) m,
    ];
    final sig = [
      for (final m in unsent)
        '${m.id}|${m.status.index}|${m.mediaStorageId}|${m.posterStorageId}',
    ].join(',');
    if (sig == _outboxSig) return;
    _outboxSig = sig;
    CacheStore.instance.scheduleSaveOutbox(uid, unsent);
  }

  /// Reads last run's unsent messages back into [_pending], once per account.
  Future<void> _restoreOutbox(String userId) async {
    if (_outboxLoadedFor == userId) return;
    final unsent = await CacheStore.instance.loadOutbox(userId);
    if (_userId != userId) {
      for (final m in unsent) {
        m.upload?.dispose();
      }
      return;
    }
    final touched = <List<ChatMessage>>{};
    for (final m in unsent) {
      final list = _pending.putIfAbsent(m.roomId, () => []);
      if (list.any((p) => p.id == m.id)) {
        m.upload?.dispose();
        continue;
      }
      list.add(m);
      touched.add(list);
      _heldFromLastRun.add(m.id);
    }
    for (final list in touched) {
      list.sort((a, b) => a.createdAt.compareTo(b.createdAt));
    }
    _outboxLoadedFor = userId;
    // Unconditionally: anything sent between launch and this read has not
    // reached the disk yet, because writes were held until now.
    notifyListeners();
  }

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
    // The one place a room list can appear, so the one place an unread anchor
    // waiting on it can be answered — see [_resolveUnreadAnchor]. A no-op once
    // it has been, which is every write after the first.
    _resolveUnreadAnchor();
  }

  List<ChatRoom> get rooms => List.unmodifiable(_rooms);

  /// Whether anything has ever answered the question "what rooms does this
  /// user have?" — cache, seed fetch or subscription, whichever got there
  /// first.
  ///
  /// The chat list cannot tell "you have no rooms" from "I have not been told
  /// yet" out of [rooms] alone: both are an empty list. It used to guess, and
  /// on a slow connection it guessed wrong every single launch — the home
  /// screen said "no rooms yet" to people with a hundred of them, for as long
  /// as the network took. This is the missing bit: false means the answer is
  /// still coming, and a list that has not been answered draws a skeleton
  /// rather than an epitaph.
  ///
  /// Set by whichever source lands first, including an EMPTY one — a genuinely
  /// empty account is an answer, and waiting past it would leave a new user
  /// shimmering forever.
  bool get roomsLoaded => _roomsLoaded;
  bool _roomsLoaded = false;

  /// Whether the SERVER's own room list has been delivered — stronger than
  /// [roomsLoaded], and the same distinction [hasLiveMessages] draws against
  /// [hasLoadedInitial].
  ///
  /// [roomsLoaded] is satisfied by three things that are not the same: the disk
  /// snapshot, the seed call, and this subscription. The first two are why it
  /// cannot answer "is this room really gone?".
  ///
  ///   * The disk snapshot predates the launch, so a room this device has never
  ///     seen — a group somebody added you to an hour ago, the first DM from a
  ///     new person — is missing from it while very much existing.
  ///   * The seed goes through `catchError((_) => <ChatRoom>[])`, so a call that
  ///     failed outright is indistinguishable from an account with no rooms, and
  ///     [_markRoomsLoaded] runs either way.
  ///
  /// A room opened from a notification tap is precisely the case both of those
  /// get wrong: the push is proof the room exists, and it arrives before the
  /// room list does. Anything about to tell the reader a room is GONE has to
  /// wait for this instead — see `RoomScreen.build`.
  ///
  /// Never true offline, by construction, which is why the waits that gate on
  /// it are bounded by [PendingPlaceholder] rather than open-ended.
  bool get hasLiveRoomList => _hasLiveRoomList;
  bool _hasLiveRoomList = false;

  /// Records that the rooms question has been answered, and tells anyone
  /// listening if that is news.
  void _markRoomsLoaded() {
    if (_roomsLoaded) return;
    _roomsLoaded = true;
    notifyListeners();
  }

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
  MessageCapabilities capabilitiesForMessage(
    ChatMessage message,
    ChatRoom? room, {
    bool senderIsSystem = false,
  }) {
    final me = _userId;
    return messageCapabilitiesFor(
      message: message,
      isMine: me != null && message.senderId == me,
      room: room == null ? RoomCapabilities.system : capabilitiesFor(room),
      roomIsEphemeral: room?.isEphemeral ?? true,
      serverNow: serverNow,
      senderIsSystem: senderIsSystem,
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

  /// The account whose outbox has been read back into [_pending]. Nothing is
  /// written to the outbox until this matches [_userId] — a write before the
  /// read would replace last run's unsent messages with whatever this run has
  /// produced so far, which at launch is nothing.
  String? _outboxLoadedFor;

  /// What the outbox on disk was last told to hold, so [notifyListeners] —
  /// which fires constantly — only writes when an unsent message actually came,
  /// went or changed state.
  String _outboxSig = '';

  /// Unsent messages read back from a previous run. Shown failed, with retry
  /// and discard, and left out of [flushPending]'s reconnect sweep: whether a
  /// message typed before a restart should still go out — maybe days later —
  /// is the sender's call, and a reconnect is not them making it.
  final Set<String> _heldFromLastRun = {};
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
    // Leaving a room while away discards the read this device was holding for
    // it — see [_markReadOrDefer]. Walking out of a chat you never looked at is
    // the clearest possible statement that you did not read it, and the room
    // has to stay unread (and badged) until you come back to it.
    _deferredRead = null;
    unawaited(PushManager.instance.setActiveRoom(value));
  }

  String? get activeRoomId => _activeRoomIdValue;

  // ──── unread anchor ────
  // Where "unread" starts for the room a screen is currently reading: the
  // room's `lastReadAt` as it stood BEFORE this device advanced it.
  //
  // Owned here rather than snapshotted by `RoomScreen.initState` because the
  // screen can mount before the room list does, and that is not a corner case
  // — it is the notification tap. A cold start from a banner opens the room
  // while `attach` is still hydrating, so `roomById` answers null; a tap that
  // wakes a backgrounded app opens it against a room list frozen at the moment
  // the app went away, whose `unreadCount` is the pre-push value (usually 0)
  // and whose `lastReadAt` is the one thing about it that IS still true. A
  // one-shot read in `initState` therefore saw "nothing unread" on exactly the
  // two paths the divider exists for, which is why the label and the landing
  // only ever appeared off a chat-list tap.
  //
  // So the capture is split from the resolve. [beginUnreadAnchor] pins WHICH
  // room is being read; the value is taken from the first room-list snapshot
  // that carries it — synchronously when the room is already known, otherwise
  // from the `_rooms` setter below. Nothing this device does can pollute it in
  // between: every path that advances the cursor is gated on `_userId`, and a
  // room opened before `attach` published one cannot send a read until the
  // re-open at the end of [_attach] — which runs after the same hydrate that
  // resolves this.
  String? _anchorRoomId;
  DateTime? _unreadAnchor;
  bool _unreadAnchorResolved = false;

  /// Pin [roomId] as the room being read and start resolving its unread
  /// anchor. Call from the reading screen's `initState`, before [openRoom].
  void beginUnreadAnchor(String roomId) {
    _anchorRoomId = roomId;
    _unreadAnchor = null;
    _unreadAnchorResolved = false;
    _resolveUnreadAnchor();
  }

  /// The read cursor [roomId] had when its screen opened, or null when there
  /// is none (a room never read before) or the answer has not landed yet —
  /// [unreadAnchorSettled] tells the two apart.
  DateTime? unreadAnchorFor(String roomId) =>
      _anchorRoomId == roomId ? _unreadAnchor : null;

  /// Whether [unreadAnchorFor] is an answer rather than a "not yet". A caller
  /// deciding where to open the transcript has to wait for this: landing at the
  /// bottom because the room list has not arrived is the bug, not the fallback.
  bool unreadAnchorSettled(String roomId) =>
      _anchorRoomId == roomId && _unreadAnchorResolved;

  /// Latch the anchor off the room list the moment it carries the room.
  ///
  /// Once only — a later snapshot has our own `markRoomRead` in it, and taking
  /// that would move the divider down over the very messages it is marking.
  void _resolveUnreadAnchor() {
    final id = _anchorRoomId;
    if (id == null || _unreadAnchorResolved) return;
    for (final r in _roomsStore) {
      if (r.id != id) continue;
      _unreadAnchor = r.lastReadAt;
      _unreadAnchorResolved = true;
      // The cursor the divider will be drawn from, and the count that used to
      // gate it. Logged because the two disagree on exactly the entry this is
      // for — a warm notification tap resolves with a true cursor and a stale
      // zero — and because a room list that never carries the room is the one
      // shape that leaves the divider undecided with nothing else to show it.
      DiagLog.roomOpen(
        'unread-anchor',
        '$id cursor=${_unreadAnchor?.toIso8601String() ?? 'none'} '
        'listUnread=${r.unreadCount}',
      );
      return;
    }
  }

  /// Whoever asked for the open room — the `RoomScreen` state that called
  /// [openRoom]. [closeRoom] only tears the room down for THIS holder.
  ///
  /// An opaque token rather than a roomId because the two screens are
  /// sometimes for the SAME room: a push tap for the chat already on screen
  /// mounts a second `RoomScreen` before the first one is disposed, so a
  /// roomId comparison would match and let the departing screen close the
  /// room its replacement is now serving.
  Object? _openOwner;

  /// True when the open room was opened with no `_userId` in hand — see the
  /// note at its assignment in [openRoom]. Cleared by the repair at the end of
  /// [_attach], and by any open that did have an id.
  bool _openedWithoutUser = false;

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
  Subscription? _membersSub;

  /// How long the room's other seven subscriptions wait for the transcript
  /// before registering anyway. See [_scheduleSecondaryRoomSubscriptions].
  ///
  /// Long enough that a healthy backend always answers first and the deferral
  /// is invisible; short enough that a reader on a dead connection does not
  /// notice their typing indicator missing.
  ///
  /// Mutable only so a test can prove the fallback fires without sleeping for
  /// it; nothing in the app writes it.
  @visibleForTesting
  static Duration secondaryFallback = const Duration(milliseconds: 600);

  /// The `_openGen` whose secondary subscriptions have been registered, and the
  /// timer that will register them if the transcript never arrives. Both are
  /// per-open: [closeRoom] cancels the timer so a room backed out of before its
  /// transcript landed does not register subscriptions nobody holds.
  int? _secondaryGen;
  Timer? _secondaryFallback;

  /// Pinned messages, keyed by room.
  ///
  /// Room-keyed rather than a bare list for the same reason `_messages` is: a
  /// late `onData` from the room being left must not paint over the room being
  /// entered. `_activeReadState` is the counter-example this avoids — it is not
  /// keyed, which is why `openRoom` has to clear it by hand.
  final Map<String, List<RoomPin>> _pins = {};

  /// Who is in each room — the roster behind every sender name, avatar and
  /// speaker colour in the transcript. Keyed by room for the same reason
  /// [_pins] is.
  ///
  /// It lives HERE, and not on the room screen where it used to, for three
  /// reasons that all point the same way.
  ///
  ///   * It can be seeded from disk. `rooms:getMembers` was the last input the
  ///     transcript needs that had no cache at all, so a room the reader had
  ///     opened a hundred times still painted every bubble in theme ink and
  ///     then repainted the lot when the network answered. See
  ///     `CacheStore.loadMembers`.
  ///   * It survives leaving the room, exactly as [_pins] and `_interactions`
  ///     do, so stepping out of a chat and back into it is a zero-frame
  ///     re-entry rather than a second disk read.
  ///   * There was more than one subscription to it. The transcript held one
  ///     and Room Info opened a second on the same query; now both read this.
  final Map<String, List<ChatUser>> _roomMembers = {};

  /// Fingerprint of the last roster actually published per room, so the
  /// dedup the two screens each used to keep survives the move up here.
  ///
  /// Convex refires `rooms:getMembers` whenever ANY `roomMembers` row is
  /// written, and `markRoomRead` patches `lastReadAt` on that table for every
  /// incoming message while somebody is in the room. Nothing rendered from
  /// this roster reads `lastReadAt`, so without the dedup an active group chat
  /// would rebuild the transcript once per message on top of the rebuild the
  /// message itself causes — which is what used to fight the overscroll bounce
  /// physics and visibly jitter the list at its edges.
  final Map<String, String> _roomMembersSig = {};

  /// The roster of [roomId] — empty until either the disk seed or
  /// `rooms:getMembers` has landed.
  ///
  /// Order is the server's. Callers that render a list sort it themselves;
  /// callers that settle speaker colours must NOT, because
  /// `SpeakerSlots.forMembers` owns that ordering and is the only thing whose
  /// answer has to match on every device.
  List<ChatUser> membersFor(String roomId) =>
      _roomMembers[roomId] ?? const <ChatUser>[];

  /// Stable fingerprint over the roster fields anything downstream renders or
  /// settles colours from. See [_roomMembersSig] for why the dedup exists.
  ///
  /// The UNION of what the two screens each used to fingerprint separately,
  /// which is the one thing that had to be got right when their subscriptions
  /// were merged into this one: a field only the transcript reads (`username`,
  /// which the @-picker filters and inserts on, and which
  /// `users.applyUsernameChange` made load-bearing) has to survive a dedup that
  /// now also serves Room Info, and vice versa. Dropping one would silently
  /// stop that screen updating.
  ///
  /// `joinedAt` is in here for a different reason than the rest: nothing
  /// displays it, but `SpeakerSlots.forMembers` settles the whole palette from
  /// it, so a roster whose join instants moved is a roster that must re-paint
  /// even when every visible field is identical.
  ///
  /// Order-insensitive, because no reader of [membersFor] renders in server
  /// order — the colour picker sorts by name, Room Info sorts its own list, the
  /// @-picker ranks, and the palette sorts internally. A reorder from the
  /// backend is therefore not a change anybody can see.
  static String _roomMemberSignature(List<ChatUser> users) {
    final parts = [
      for (final u in users)
        '${u.id}|${u.status ?? ''}|${u.lastSeen?.millisecondsSinceEpoch ?? 0}'
            '|${u.name}|${u.username}|${u.avatarStorageId ?? ''}|${u.role ?? ''}'
            '|${u.joinedAt?.millisecondsSinceEpoch ?? 0}',
    ]..sort();
    return parts.join(';');
  }

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
  final Map<String, Future<bool>> _interactionWrites = {};

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

  /// When each member's read / delivery cursor last ADVANCED, by the wall
  /// clock. The cursors above are for comparing against `createdAt`; they
  /// cannot be shown, because `markRoomRead` writes the read message's own
  /// timestamp as the cursor, so a read time drawn from one always equalled
  /// the sent time. Absent for a member whose row predates the stamp.
  final Map<String, DateTime> _activeReadClock = {};
  final Map<String, DateTime> _activeDeliveredClock = {};

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

  /// The wall-clock times behind [roomReadCursors] — what a receipt DISPLAYS.
  Map<String, DateTime> get roomReadTimes =>
      UnmodifiableMapView(_activeReadClock);

  /// The wall-clock times behind [roomDeliveredCursors].
  Map<String, DateTime> get roomDeliveredTimes =>
      UnmodifiableMapView(_activeDeliveredClock);

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
    //
    //    The speaker pins ride along for a reason of their own, and it is not
    //    the round trip. They are applied FIRST and absolutely by
    //    `SpeakerSlots.forMembers`, and the slots they take are then off-limits
    //    to everyone the room places automatically — so a room that paints its
    //    roster from disk (see [openRoom]) without them settles to a genuinely
    //    DIFFERENT palette, not a nearly-right one, and the reader watches the
    //    whole room rearrange when `speakerColors:mine` answers. Cached here
    //    rather than beside the roster because the subscription is app-wide.
    try {
      final results = await Future.wait<dynamic>([
        CacheStore.instance.loadRooms(userId),
        CacheStore.instance.loadFriends(userId),
        CacheStore.instance.loadSpeakerColors(userId),
      ]);
      final cachedRooms = results[0] as List<ChatRoom>;
      final cachedFriends = results[1] as List<ChatUser>;
      final cachedColors = results[2] as Map<String, Map<String, int>>;
      // A non-empty cache is an answer; an empty one is indistinguishable from
      // never having cached anything, so it does not clear the skeleton.
      if (cachedRooms.isNotEmpty) {
        _rooms = cachedRooms;
        _roomsLoaded = true;
      }
      if (cachedFriends.isNotEmpty) _friends = cachedFriends;
      if (cachedColors.isNotEmpty) _speakerColors = cachedColors;
      if (cachedRooms.isNotEmpty ||
          cachedFriends.isNotEmpty ||
          cachedColors.isNotEmpty) {
        notifyListeners();
      }
    } catch (_) {}

    // 1b) Messages this account never got onto the server last time. Read
    //     before anything else can write the outbox, and before the reconnect
    //     sweep can see them — see [_heldFromLastRun].
    try {
      await _restoreOutbox(userId);
    } catch (e) {
      debugPrint('outbox restore failed: $e');
    }

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
      // Outside the `isNotEmpty` guard on purpose. The guard is there because
      // a failed call comes back as `[]` and must not wipe a good cache — but
      // `listUserRooms` returning nothing on a call that DID complete is a
      // real answer, and a new account with no rooms has to be allowed to
      // reach its empty state.
      _markRoomsLoaded();
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
        _roomsLoaded = true;
        // The server has spoken — see [hasLiveRoomList]. Only here, and not
        // beside the two weaker sources that also set `_roomsLoaded`: this is
        // the one delivery that can be trusted to say a room is absent because
        // it does not exist, rather than because nobody has looked yet.
        _hasLiveRoomList = true;
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
        // Written on the SERVER's word, not on the optimistic apply in
        // [setSpeakerSlot] — a pin that the round trip then refuses (the
        // per-room cap) must not be the one a relaunch settles the palette
        // from. [_persistSpeakerColors] is called again after each successful
        // mutation, which closes the only gap this leaves: an app killed
        // between the mutation landing and its echo arriving.
        _persistSpeakerColors();
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

    // A room that was already on screen before this attach published a user id
    // is subscribed read-blind — see `_openedWithoutUser` in [openRoom]. The
    // room list has landed by now (hydrate and seed both ran above), so the
    // unread anchor is already latched and re-opening cannot move it; what the
    // re-open buys is the rest of the room: the disk cache, the read cursor,
    // the notification dismiss and the seven secondary subscriptions.
    //
    // `force` for [resubscribe]'s reason: ownership stays with the screen that
    // holds it, and `activeRoomId` never blinks off — which is what keeps push
    // suppression honest for the room on screen while this runs.
    final reopen = _activeRoomId;
    if (reopen != null && _openedWithoutUser) {
      _openedWithoutUser = false;
      unawaited(openRoom(reopen, force: true));
    }

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
  /// the bytes each phone parses per message. It was 100, then 50.
  ///
  /// And the multiplier is per VIEWER, with no sharing between them. Every
  /// query in this app is wrapped by `authedQuery`, which appends a
  /// `sessionToken` to its declared args (`backend/convex/functions.ts:114`)
  /// before overwriting `viewerUserId` with the session-resolved id. Convex
  /// caches a query result against (path, args), and that token is unique per
  /// device session — so two people looking at the same room share nothing.
  /// Total server work is therefore LINEAR in this number, and halving it
  /// halves it.
  ///
  /// It also shrinks the query's READ SET, which is the part that is easy to
  /// miss: a reaction on a message outside the window now invalidates nothing
  /// at all, rather than costing every viewer a full re-run. Fewer bytes is the
  /// smaller half of the win; fewer re-runs is the larger.
  ///
  /// Twenty-five still fills a screen and a half on the tallest phone, and
  /// everything older arrives through [loadOlder] on the first scroll back,
  /// exactly as messages 51+ already did. The one thing given up is unchanged
  /// from the last cut: a reaction on a message that has scrolled out of the
  /// window no longer updates live — the same freeze the thread overlay
  /// documents, and now bounded by the local rendering of your OWN reactions,
  /// deletes and edits (see [_patchMessageEverywhere]), which is what makes a
  /// smaller window safe to take.
  static const kLiveWindow = 25;

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

  /// A read the open room earned but nobody was present to take — see
  /// [_markReadOrDefer]. At most one, because only the open room is ever
  /// marked read from here and a later cursor supersedes an earlier one.
  ({String roomId, String userId, DateTime upTo})? _deferredRead;

  /// Advance the open room's read cursor — but only if someone is actually
  /// looking at it.
  ///
  /// The unguarded version is why the macOS Dock icon never badged. Everywhere
  /// else, "the room is open" is a safe stand-in for "you are reading it",
  /// because a backgrounded app is suspended within seconds and its
  /// subscriptions stop firing — nothing arrives to be marked read. On macOS
  /// the process is kept alive on purpose with its window hidden, since it IS
  /// the delivery path (macos/Runner/MainFlutterWindow.swift), so messages kept
  /// landing in the open room and kept being marked read on behalf of somebody
  /// who had closed the window hours ago. `unreadCount` never left zero, so
  /// [BadgeManager] had nothing to draw, and the sender was told SEEN for a
  /// message that had never been on anyone's screen. A background browser tab
  /// had the same hole.
  ///
  /// Held rather than dropped: the messages ARE on screen in the open room, so
  /// the moment the person comes back to the app they have read them, and
  /// [flushDeferredRead] takes the cursor then.
  void _markReadOrDefer(String roomId, String userId, DateTime upTo) {
    if (!viewerIsPresent) {
      _deferredRead = (roomId: roomId, userId: userId, upTo: upTo);
      return;
    }
    _deferredRead = null;
    _scheduleMarkRead(roomId, userId, upTo);
    // Reading it means its notifications are spent. Done locally rather than
    // waiting for the server's silent dismiss push, which is best-effort and
    // can't reach a force-quit app at all. Deferred with the read for the same
    // reason: clearing the banner for a message nobody has looked at is how it
    // goes missing.
    PushManager.instance.dismissRoomNotifications(roomId);
  }

  /// Take the read [_markReadOrDefer] held back, now that the viewer is here.
  ///
  /// Called from the app's `resumed` lifecycle handler (lib/app.dart). Cheap
  /// and idempotent: no deferral, or one for a room that is no longer open,
  /// costs nothing and sends nothing.
  void flushDeferredRead() {
    final d = _deferredRead;
    _deferredRead = null;
    if (d == null || d.roomId != _activeRoomId) return;
    _scheduleMarkRead(d.roomId, d.userId, d.upTo);
    PushManager.instance.dismissRoomNotifications(d.roomId);
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
      // The newest message this device has seen, not "now": a message sent
      // after this snapshot has not reached the device, and must not be
      // claimed by it.
      api
          .markRoomDelivered(roomId: room.id, userId: userId, upTo: newest)
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
    // Left live it would keep writing the previous account's roster into
    // `_roomMembers`, and its `onData` re-reads `_userId` to decide where to
    // cache it — so a delivery arriving after the next sign-in would file the
    // departing account's roster under the arriving account's id.
    _membersSub?.cancel();
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
    _membersSub = null;
    _speakerColorsSub = null;
    _typingHeartbeat = null;
    _secondaryFallback?.cancel();
    _secondaryFallback = null;
    _activeRoomId = null;
    _anchorRoomId = null;
    _unreadAnchor = null;
    _unreadAnchorResolved = false;
    _openedWithoutUser = false;
    _openOwner = null;
    // Any open still in flight belongs to the account being signed out.
    _openGen++;
    _userId = null;
    _rooms = [];
    // The next account has not answered yet either, and inheriting this one's
    // "answered" would show them an empty chat list instead of a skeleton — or,
    // for the stronger flag, tell them a room they were pushed into is gone on
    // the strength of a list belonging to somebody else.
    _roomsLoaded = false;
    _hasLiveRoomList = false;
    _friends = [];
    _incomingRequests = [];
    _outgoingRequests = [];
    _roomInvitations = [];
    _roomInvitationsSig = '';
    _messages.clear();
    // Unlike [closeRoom], which keeps these so re-entry paints instantly, this
    // is a sign-out: they are the previous account's room state.
    _pins.clear();
    // The roster the same way, and with a sharper edge than the pins have: a
    // `rooms:getMembers` row is scoped to a viewer who is a member, so keeping
    // it would hand the next person on this handset the membership of a room
    // they may not be in. The signature goes with it or the next account's
    // first delivery for the same room would dedup against a roster it never
    // saw and never paint.
    _roomMembers.clear();
    _roomMembersSig.clear();
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
    // The outbox on disk goes with the cache directory (`CacheStore.clearFor`);
    // these make sure the next sign-in reads it again rather than overwriting it.
    _outboxLoadedFor = null;
    _outboxSig = '';
    _heldFromLastRun.clear();
    _lastSeenNewestMsgId.clear();
    _lastLiveRaw.clear();
    _deletedLocally.clear();
    _pushStubs.clear();
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

  /// Seeding IS an answer, empty list included — a test that hands this an
  /// empty list is describing an account with no rooms, not a network that has
  /// not replied, and must reach the empty state rather than a skeleton.
  ///
  /// Both flags, for that same reason: a test seeding no rooms and then opening
  /// one is describing a room that genuinely is not there, and must reach "room
  /// gone" rather than sit on the skeleton [hasLiveRoomList] would otherwise
  /// hold it on.
  @visibleForTesting
  void debugSeedRooms(List<ChatRoom> rooms) {
    _rooms = List.of(rooms);
    _roomsLoaded = true;
    _hasLiveRoomList = true;
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

  // ── Change requests (a member asking to redecorate the group) ────────────

  /// Ask for the group's name, description or picture to change. Resolves to
  /// true when an admin now has to answer — see [ChatApi.proposeRoomChange]
  /// for the one case where that is false.
  Future<bool> proposeRoomChange({
    required String roomId,
    required RoomChangeField field,
    String? value,
    String? storageId,
  }) async {
    final id = _userId;
    if (id == null) return false;
    return api.proposeRoomChange(
      roomId: roomId,
      userId: id,
      field: field,
      value: value,
      storageId: storageId,
    );
  }

  Future<void> withdrawRoomChange(String requestId) async {
    final id = _userId;
    if (id == null) return;
    await api.withdrawRoomChange(requestId: requestId, userId: id);
  }

  Future<void> decideRoomChange({
    required String requestId,
    required bool approve,
  }) async {
    final id = _userId;
    if (id == null) return;
    await api.decideRoomChange(
      requestId: requestId,
      userId: id,
      approve: approve,
    );
  }

  Future<List<RoomChangeRequest>> listRoomChangeRequests(String roomId) async {
    final id = _userId;
    if (id == null) return const [];
    return api.listRoomChangeRequests(roomId: roomId, userId: id);
  }

  Future<List<RoomChangeRequest>> myRoomChangeRequests(String roomId) async {
    final id = _userId;
    if (id == null) return const [];
    return api.myRoomChangeRequests(roomId: roomId, userId: id);
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
    final stubs = _pushStubs[roomId];
    // Rare — only between a push landing and the transcript answering — so it
    // sits ahead of the memo rather than inside it, and costs a null check on
    // every other call.
    if (stubs != null && stubs.isNotEmpty) {
      final known = {
        for (final m in live) m.id,
        for (final m in _olderPrefix[roomId] ?? const <ChatMessage>[]) m.id,
      };
      final unseen = stubs.where((m) => !known.contains(m.id)).toList();
      if (unseen.isNotEmpty) {
        final merged = <ChatMessage>[
          ...live,
          ...?_pending[roomId],
          ...unseen,
        ]..sort((a, b) => a.createdAt.compareTo(b.createdAt));
        return merged;
      }
    }
    final pend = _pending[roomId] ?? const [];
    if (pend.isEmpty) return live;
    // Memoised on the identity of both inputs, because the room screen's item
    // pass is memoised on the identity of THIS list (see `_buildItems`) and its
    // ticker calls straight through here every second. Allocating a fresh
    // merged list per call meant that memo could never hold while a send was in
    // flight, so the whole transcript was flattened and rebuilt once a second
    // for as long as one bubble was going up.
    //
    // Length is part of the key alongside identity: a pending list is mutated
    // in place (a status flip), which changes neither identity nor — for a
    // status flip — the set of instances the merge would produce. An append
    // does change it, and shows up as a length change.
    if (identical(live, _mergedLiveSource) &&
        identical(pend, _mergedPendingSource) &&
        pend.length == _mergedPendingLength) {
      return _mergedResult!;
    }
    final merged = [...live, ...pend];
    merged.sort((a, b) => a.createdAt.compareTo(b.createdAt));
    _mergedLiveSource = live;
    _mergedPendingSource = pend;
    _mergedPendingLength = pend.length;
    _mergedResult = merged;
    return merged;
  }

  /// The inputs [messagesFor]'s last merge was built from, and its result.
  List<ChatMessage>? _mergedLiveSource;
  List<ChatMessage>? _mergedPendingSource;
  int _mergedPendingLength = -1;
  List<ChatMessage>? _mergedResult;

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
    //
    // And a new owner now defeats the short-circuit outright, because a second
    // screen for the same room is a second READING SESSION, not a repeat of
    // the first. That distinction has one entry: tapping the banner for the
    // chat you were already inside when the app went away. `_openRoomFromPush`
    // pops to the shell and pushes a fresh `RoomScreen`, which lands here with
    // `_activeRoomId` still equal to `roomId` — so this used to return having
    // done nothing at all, and the new screen inherited a room that was set up
    // for the old one. `_liveMessagesLoaded` is the field that hurt: it still
    // said the subscription had delivered, from a delivery that happened
    // before the app was suspended. The new screen asked "has the transcript
    // spoken yet?", was told yes, looked at a transcript the frozen socket had
    // not yet caught up on, found nothing past the read cursor and settled on
    // "nothing unread" — permanently, one frame before the message the reader
    // had tapped the notification for arrived. No divider, on the one entry
    // where the reader most expects one.
    //
    // Everything else this re-runs is wanted too: the push inbox is drained so
    // the tapped message is on screen before the network answers, and the
    // entry read fires for a room whose banner was just tapped. It costs one
    // re-registration of the room's subscriptions, on a path that happens once
    // per notification tap — `resubscribe` has taken the same cost on every
    // reconnect for far longer.
    final newReader = owner != null && !identical(_openOwner, owner);
    if (owner != null) _openOwner = owner;
    if (_activeRoomId == roomId && !force && !newReader) return;
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
    DiagLog.roomOpen('open', roomId);
    _activeRoomId = roomId;
    _messagesSub?.cancel();
    _activeTypingSub?.cancel();
    _readStateSub?.cancel();
    _pinsSub?.cancel();
    _bookmarksSub?.cancel();
    _scheduledSub?.cancel();
    _interactionsSub?.cancel();
    _membersSub?.cancel();
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
    _membersSub = null;
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
    // A room can be opened before there is an account to open it as: a cold
    // start from a notification tap pushes the screen from `_bootstrap`, which
    // runs while `ChatRepository.attach` is still in flight. Every branch below
    // that needs an id — the disk hydrate, the read cursor, the six secondary
    // subscriptions — then quietly does nothing, and the room stays subscribed
    // read-blind for the rest of the session: nothing cached, nothing marked
    // read, notifications never dismissed. That is the badge that survives
    // reading a room you reached from its own banner. Recorded here and
    // repaired at the end of [_attach], once there is an id to re-open with.
    _openedWithoutUser = me == null;
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
    // Ahead of the disk read on purpose: a tap IS the launch, so whatever the
    // notification handler staged is the newest thing this device knows and
    // belongs on the first frame — before the cache, which by definition
    // predates it, and long before the network.
    await takePushedMessages();
    if (gen != _openGen) return;
    // Hydrate from disk first for an instant render.
    //
    // Both files read together and behind ONE `notifyListeners`, and that is
    // the substance of this rather than a tidy-up. The transcript and
    // the roster have to reach the same frame: what a bubble says comes from
    // the first, and who said it — their name, their avatar, the colour they
    // speak in — comes entirely from the second. Painting the messages and
    // then the roster a beat later would not remove the two-stage render this
    // cache exists to delete, it would just move it earlier.
    final wantMessages =
        me != null && (_messages[roomId] == null || _messages[roomId]!.isEmpty);
    // Kept across [closeRoom] like the transcript, so stepping out of a room
    // and back in skips the disk entirely and re-enters on one frame.
    final wantMembers = me != null && membersFor(roomId).isEmpty;
    if (me != null && (wantMessages || wantMembers)) {
      try {
        // Both started before either is awaited, so the two reads overlap;
        // awaiting them in sequence below does not serialise them.
        final messagesRead =
            wantMessages ? CacheStore.instance.loadMessages(me, roomId) : null;
        final membersRead =
            wantMembers ? CacheStore.instance.loadMembers(me, roomId) : null;
        var painted = false;
        if (messagesRead != null) {
          final cached = await messagesRead;
          if (cached.isNotEmpty) {
            _messages[roomId] = cached;
            _initialLoaded.add(roomId);
            // How stale the first painted frame is. Read against the
            // `messages:list` `first` event that follows: the gap between them
            // is how long the reader sat looking at this snapshot.
            DiagLog.roomOpen(
              'cache',
              '${cached.length} msgs, newest '
              '${DateTime.now().difference(cached.last.createdAt).inSeconds}s old',
            );
            painted = true;
          } else {
            DiagLog.roomOpen('cache', 'empty');
          }
        }
        if (membersRead != null) {
          final roster = await membersRead;
          if (roster.isNotEmpty) {
            _roomMembers[roomId] = roster;
            // Deliberately NOT seeding `_roomMembersSig`. The seed carries no
            // presence (see `CacheStore.scheduleSaveMembers`), so the first
            // live delivery is genuinely different from it and must be allowed
            // through the dedup to light everybody's status dot. Leaving the
            // signature empty says exactly that: nothing live has landed yet.
            DiagLog.roomOpen('cache', '${roster.length} members');
            painted = true;
          }
        }
        if (painted) notifyListeners();
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
    //
    // `_messages` and NOT `messagesFor`, which is the difference between a
    // working read cursor and a message that is never marked read: a push stub
    // is on screen but unconfirmed, and priming from one would make the first
    // live delivery look like it carried nothing new, so `markRoomRead` would
    // never fire for the very message the reader came here to read.
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
        // Re-read rather than the `me` captured above: this closure outlives
        // the open that made it, and on a cold start from a notification tap
        // that open ran before `attach` published an id. The re-open at the end
        // of [_attach] repairs the rest of the room, but this is what stops the
        // messages the reader is looking at RIGHT NOW from staying unread in
        // the seconds before it lands.
        final me = _userId;
        final list = (data as List?) ?? const [];
        final parsed = _parseLiveWindow(roomId, list);
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
        // The server has spoken, so the stand-ins go — all of them, not just
        // the ones this window happens to contain. Trying to keep the rest
        // would mean keeping a message the server has since deleted, or one
        // that fell off the back of a window fifty newer messages have pushed
        // past, and no rule that tells those apart is worth its own bugs.
        // `_maybeLandOnUnread` already owns putting the reader in the right
        // place when a backlog lands.
        if (_pushStubs.remove(roomId) != null) {
          _mergedResult = null;
        }
        // The transcript is on screen, so the furniture around it can go and
        // ask for itself now. Idempotent — this fires again on every reaction
        // and edit, and only the first one through the gate registers.
        _startSecondaryRoomSubscriptions(roomId, gen, me);
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
            _markReadOrDefer(roomId, me, parsed.last.createdAt);
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

    // Everything below the transcript is now deferred behind it — see
    // [_scheduleSecondaryRoomSubscriptions]. These six used to be issued in the
    // same breath as `messages:list` and then race it on a backend that answers
    // one query at a time, so the one the reader is actually waiting for queued
    // behind pins, bookmarks and a scheduled-message list nobody is looking at
    // yet.
    _scheduleSecondaryRoomSubscriptions(roomId, gen, me);
  }

  /// Hold the room's non-transcript subscriptions until the transcript lands.
  ///
  /// `messages:list` is the only query anybody is waiting on when a room opens:
  /// until it answers there is nothing on screen but a disk snapshot that
  /// predates whatever the reader came here to see. The other seven —
  /// the roster, pins, interactions, bookmarks, scheduled messages, read
  /// state, typing — paint furniture around a transcript that is not there
  /// yet, and on a resource-constrained backend every one of them is a query
  /// competing with the one that matters.
  ///
  /// So they are gated: whichever comes first, the transcript's own first
  /// delivery or [secondaryFallback]. The fallback is not a nicety — a room
  /// opened offline, or one whose subscription never answers, must still get
  /// its typing indicator and its read state rather than waiting forever on a
  /// signal that is not coming.
  ///
  /// The roster joined this set rather than staying on the room screen, and it
  /// is the one member of it whose deferral is worth defending, because unlike
  /// the other six it changes something the reader can already see. Two things
  /// make it the right call anyway. It used to be issued in the same tick as
  /// `messages:list` and simply raced it, so on a backend that answers one
  /// query at a time it was making the transcript — the thing nobody can read
  /// without — arrive later. And a room that has been opened before now paints
  /// its roster from disk on the first frame, so for the overwhelmingly common
  /// case this subscription no longer has a first impression to make: it
  /// arrives to confirm what is already on screen and to light the presence
  /// dots the cache deliberately does not keep.
  void _scheduleSecondaryRoomSubscriptions(String roomId, int gen, String? me) {
    _secondaryFallback?.cancel();
    _secondaryFallback = Timer(
      secondaryFallback,
      () => _startSecondaryRoomSubscriptions(roomId, gen, me),
    );
  }

  /// Open the gate. Idempotent per open: the transcript's first delivery and
  /// the fallback timer both call this, and a transcript that fires again a
  /// moment later (a reaction, an edit) must not register a second set.
  void _startSecondaryRoomSubscriptions(String roomId, int gen, String? me) {
    if (gen != _openGen) return;
    if (_secondaryGen == gen) return;
    _secondaryGen = gen;
    _secondaryFallback?.cancel();
    _secondaryFallback = null;
    unawaited(_registerSecondaryRoomSubscriptions(roomId, gen, me));
  }

  /// The deferred half of [openRoom]. Every registration keeps the same `gen`
  /// guard it had when it lived inline — a superseded open still cancels its
  /// handle rather than publishing it.
  Future<void> _registerSecondaryRoomSubscriptions(
    String roomId,
    int gen,
    String? me,
  ) async {
    // The roster — who is in the room. FIRST in this method, and the order is
    // deliberate: it is the only query here that changes pixels already on
    // screen. Everything else registered below paints chrome that is currently
    // absent (a zero-height pin banner, a bookmark tick, a scheduled-send
    // pill), so a reader cannot tell whether it arrived early or late. This one
    // decides every sender's name, avatar and speaker colour, so on the one
    // path where the disk seed had nothing to offer — a room being opened for
    // the very first time — it is the query whose latency the reader actually
    // sees.
    //
    // Registered here rather than by the room screen so the `gen` guard and
    // `SubscriptionRegistry`'s reconnect rebinding cover it for free, exactly
    // like the six around it — and so Room Info, which used to open a second
    // live subscription to this same query, can read the one answer instead.
    final membersSub = await cv.subscribe(
      'rooms:getMembers',
      {'roomId': roomId, 'viewerUserId': ?me},
      onData: (data) {
        final list = (data as List?) ?? const [];
        final fresh = list
            .whereType<Map>()
            .map((e) => ChatUser.fromJson(e.cast<String, dynamic>()))
            .toList();
        // See [_roomMembersSig]: `markRoomRead` writes a `roomMembers` row for
        // every incoming message, so this query refires constantly in an
        // active group chat while saying nothing this app renders.
        final sig = _roomMemberSignature(fresh);
        if (sig == _roomMembersSig[roomId]) return;
        _roomMembersSig[roomId] = sig;
        _roomMembers[roomId] = fresh;
        // Re-read rather than the `me` captured by this registration, for the
        // reason the transcript's own closure re-reads it: on a cold start
        // from a notification tap the open that made this ran before [attach]
        // published an id. The repair at the end of [_attach] re-opens the
        // room and would eventually cache it anyway, but taking the id as it
        // stands now means the roster this reader is looking at RIGHT NOW is
        // the one on disk for the next launch.
        final viewer = _userId;
        if (viewer != null) {
          CacheStore.instance.scheduleSaveMembers(viewer, roomId, fresh);
        }
        notifyListeners();
      },
      onError: (err) => debugPrint('members sub error: $err'),
    );
    if (gen != _openGen) {
      membersSub.cancel();
      return;
    }
    _membersSub = membersSub;

    // Pinned messages. Registered here rather than by the room screen so the
    // `gen` guard and `SubscriptionRegistry`'s reconnect rebinding cover it for
    // free, exactly like the three around it.
    //
    // No paired one-shot fetch, unlike `messages:list` in [openRoom]: the banner is
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
          _activeReadClock.clear();
          _activeDeliveredClock.clear();
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
            final readClock = m['readClock'] as num?;
            if (readClock != null) {
              _activeReadClock[uid] =
                  DateTime.fromMillisecondsSinceEpoch(readClock.toInt());
            }
            final deliveredClock = m['deliveredClock'] as num?;
            if (deliveredClock != null) {
              _activeDeliveredClock[uid] =
                  DateTime.fromMillisecondsSinceEpoch(deliveredClock.toInt());
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
    // subscription in [openRoom] and is marked from there, which is also the honest
    // order: a message is read when it is on screen, not when the room opens.
    // With nothing held it is omitted, and the server falls back to the room's
    // `lastMessageTime` as it always did.
    //
    // Gated on presence for the same reason [_markReadOrDefer] is, and this is
    // the path that would otherwise walk straight around it: opening a room is
    // normally an act of looking, but this runs on every RE-entry too — and a
    // socket that drops and re-subscribes while the macOS window is hidden
    // re-enters with a live window full of messages nobody has seen. That would
    // mark the lot read, silently, hours after the person walked away. Nothing
    // is lost by skipping it: whatever actually arrives is deferred and taken
    // on the way back in.
    //
    // Held back once more while the reader's own cursor is still unknown. With
    // nothing held this call marks the room read to its newest message, and
    // doing that before [_resolveUnreadAnchor] has latched would erase the very
    // cursor the divider is drawn from — the offline cold start, where neither
    // the disk cache nor the seed answered and only the live subscription can.
    // The anchor lands with the room list, and whatever arrives is marked read
    // from the transcript's own delivery either way.
    final anchorPending = _anchorRoomId == roomId && !_unreadAnchorResolved;
    if (me != null && viewerIsPresent && !anchorPending) {
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
    _membersSub?.cancel();
    // The `_openGen` bump above already makes a late firing a no-op; this stops
    // it holding the closure for the rest of the fallback window.
    _secondaryFallback?.cancel();
    _secondaryFallback = null;
    _messagesSub = null;
    _activeTypingSub = null;
    _readStateSub = null;
    _pinsSub = null;
    _bookmarksSub = null;
    _scheduledSub = null;
    _interactionsSub = null;
    _membersSub = null;
    _activeRoomId = null;
    // Nothing left for [_attach]'s repair to re-open. The anchor itself stays:
    // a route transition disposes the OUTGOING screen after its replacement has
    // already pinned the room, and clearing here would throw away the answer
    // the screen now on the wire is waiting for.
    _openedWithoutUser = false;
    // Hand the room back to the global stream's name-only entry.
    _openTypingRoomId = null;
    _openTypingUsers = const [];
    _activeReadState.clear();
    _activeDeliveredState.clear();
    _loadingOlder.clear();
    _exhausted.clear();
    _olderPrefix.clear();
    // Both are per-open caches of the live window: the raw rows the reuse check
    // in [_parseLiveWindow] compares against, and the deletes it is still
    // hiding. Re-entering the room re-delivers the window from scratch, so
    // carrying either across would compare against a stale snapshot.
    _lastLiveRaw.clear();
    _deletedLocally.clear();
    _pushStubs.clear();
    // The asked-for set, but NOT `_interactions` itself: the tallies are kept
    // exactly as `_pins` and `_messages` are, so re-entering the room paints a
    // complete card instantly instead of a poll with no bars. The ask-set goes
    // because the subscription will re-deliver the live window on re-entry, and
    // an old page's ids should be re-fetched if the reader scrolls back to
    // them again — a poll they last saw a week ago has moved on.
    _interactionsAsked.clear();
    // `_roomMembers` and `_roomMembersSig` are NOT cleared here, on the same
    // argument as `_pins`, `_messages` and `_interactions` above, and they are
    // the pair that argument pays off hardest for: the roster is what a bubble
    // gets its sender's name, avatar and colour from, so dropping it would
    // make stepping out of a room and straight back into it repaint the whole
    // transcript in theme ink for as long as the round trip takes. Kept
    // together on purpose — a roster held without its signature would let the
    // re-entry's first identical delivery through the dedup and rebuild the
    // list for nothing.
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

    /// Set when the reply is to the whole album [replyToId] heads: how many
    /// items it holds. See [ReplyPreview.albumCount].
    int? replyAlbumCount,
    List<MessageMention> mentions = const [],
    bool mentionsEveryone = false,
    List<FormattingEntity> formatting = const [],
  }) async {
    return _send(
      roomId: roomId,
      content: text,
      type: MessageType.text,
      replyToId: replyToId,
      replyAlbumCount: replyAlbumCount,
      mentions: mentions,
      mentionsEveryone: mentionsEveryone,
      formatting: formatting,
    );
  }

  /// Sends a GIF or sticker.
  ///
  /// Nothing to upload — the picture is a KLIPY URL or a pack sticker's
  /// existing blob — so this is a text-shaped send: the optimistic bubble
  /// draws the picture straight away and the post goes out at once.
  Future<void> sendExpression(
    String roomId,
    ExpressionItem item, {
    String? replyToId,
    int? replyAlbumCount,
  }) {
    return _send(
      roomId: roomId,
      // The alt text, and what an app too old for these types shows instead.
      content: item.title ?? '',
      type: item.isSticker ? MessageType.sticker : MessageType.gif,
      mediaWidth: item.width,
      mediaHeight: item.height,
      replyToId: replyToId,
      replyAlbumCount: replyAlbumCount,
      expression: item,
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
    int? replyAlbumCount,
    bool viewOnce = false,
    List<MessageMention> mentions = const [],
    bool mentionsEveryone = false,
    List<FormattingEntity> formatting = const [],
    double? latitude,
    double? longitude,
    double? locationAccuracyM,
    ExpressionItem? expression,
  }) async {
    final optimistic = _buildOptimistic(
      roomId: roomId,
      content: content,
      type: type,
      mediaStorageId: mediaStorageId,
      mediaWidth: mediaWidth,
      mediaHeight: mediaHeight,
      replyToId: replyToId,
      replyAlbumCount: replyAlbumCount,
      viewOnce: viewOnce,
      mentions: mentions,
      mentionsEveryone: mentionsEveryone,
      formatting: formatting,
      latitude: latitude,
      longitude: longitude,
      locationAccuracyM: locationAccuracyM,
      expression: expression,
    );
    if (optimistic == null) return;
    _pending.putIfAbsent(roomId, () => []).add(optimistic);
    notifyListeners();
    // Issue the send FIRST, then retire the typing heartbeat.
    //
    // Order matters because both ride one socket whose worker handles one
    // frame at a time: starting `_postMessage` here puts `messages:send` in
    // front of the `clearTyping` rather than behind it. And retiring the
    // heartbeat at all is the point — without this it keeps firing
    // `typing:setTyping` every 2s for up to 3s more (`_scheduleStopTyping`),
    // which lands squarely inside the round trip the clock icon is waiting on.
    // It was also simply wrong: you are not still typing, you just sent.
    final posted = _postMessage(roomId, optimistic);
    _stopTyping();
    await posted;
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

    /// Set for a reply to the whole album [replyToId] heads: its item count,
    /// which the pending tether shows at once and [_postMessage] sends.
    int? replyAlbumCount,

    /// The album a photo or video is sent in. See [ChatMessage.albumId].
    String? albumId,
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

    /// The GIF or sticker. Spread onto the bubble's own fields so it draws the
    /// picture at once, and so [_postMessage] — and both reconnect sweepers,
    /// which re-post from the bubble alone — send the same picture on a retry.
    ExpressionItem? expression,
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
          // Mirrors the thumbnail `messages:send` will snapshot for a quoted
          // GIF or sticker.
          mediaUrl: parent.mediaPreviewUrl ?? parent.mediaUrl,
          stickerStorageId: parent.stickerStorageId,
          stickerFormat: parent.stickerFormat,
          albumCount: replyAlbumCount,
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
      albumId: albumId,
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
      mediaSource: expression?.source.name,
      mediaUrl: expression?.url,
      mediaPreviewUrl: expression?.previewUrl,
      mediaRef: expression?.ref,
      stickerId: expression?.stickerId,
      stickerStorageId: expression?.storageId,
      stickerFormat: expression == null || !expression.isSticker
          ? null
          : expression.format,
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
        // Read off the bubble, like everything here, so a reconnect retry
        // still replies to the whole album and still lands in its album.
        replyToAlbum: optimistic.replyToPreview?.albumCount != null,
        replyAlbumCount: optimistic.replyToPreview?.albumCount,
        albumId: optimistic.albumId,
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
        // Read off the message like everything above: a sweeper re-posting a
        // GIF must still name the GIF.
        expression: optimistic.expression,
      );
      // The filter's refusal comes back as a VALUE, not a throw, so the server
      // can keep the moderator card it filed (see `messages.send`). Turned
      // back into the refusal it is, for the catch below.
      if (serverId == kMessageFilterBlocked) {
        throw StateError(kMessageFilterBlocked);
      }
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
      // A server limit (too fast, storage full, too large, too long) leaves
      // the bubble failed like any error, but says which, so the room can
      // tell the user why a retry won't help yet.
      final text = e.toString();
      for (final code in kSendLimitCodes) {
        if (text.contains(code)) {
          _lastSendLimit = code;
          break;
        }
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

  /// Attachments go up a few at a time but are POSTED one at a time, in the
  /// order they were sent.
  ///
  /// They used to be fully chained, upload and post together, which kept the
  /// order but made every photo of an album wait out the previous one's server
  /// round trip before its own bytes started moving: ten photos were ten
  /// back-to-back trips on a backend whose latency is the slow part. Now the
  /// bytes overlap, and only the message that references them waits its
  /// turn ([OrderedSendQueue]), so what the other side sees is the
  /// preview's order however the uploads happen to finish.
  ///
  /// A photo whose upload fails does not hold up the ones after it; a retry
  /// posts it whenever it lands, after them.
  final OrderedSendQueue _attachments = OrderedSendQueue();

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
    int? replyAlbumCount,

    /// The album this photo or video is sent in, shared by every item of one
    /// send. See [ChatMessage.albumId].
    String? albumId,
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
      replyAlbumCount: replyAlbumCount,
      albumId: albumId,
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
              albumId: albumId,
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
        // The sender has decided; from here it is an ordinary send, and a
        // failure is swept up on the next reconnect like any other.
        _heldFromLastRun.remove(m.id);
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
      _heldFromLastRun.remove(messageId);
      list.removeAt(i).upload?.dispose();
      notifyListeners();
      return;
    }
  }

  /// Starts [message]'s upload as soon as a slot is free, and queues its post
  /// behind every attachment sent before it. See [OrderedSendQueue].
  Future<void> _enqueueUpload(String roomId, ChatMessage message) =>
      _attachments.add(
        upload: () => _runUpload(roomId, message),
        post: () => _runPost(roomId, message),
      );

  /// Puts [message]'s bytes (and a video's poster) up. True when it is ready
  /// to post; false when there is nothing to post (discarded, cancelled, or
  /// failed, which is marked on the bubble here).
  Future<bool> _runUpload(String roomId, ChatMessage message) async {
    final upload = message.upload;
    if (upload == null || upload.disposed) return false;
    // Discarded while it sat in the queue.
    if (!(_pending[roomId]?.contains(message) ?? false)) return false;

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
        if (upload.disposed) return false;
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
      if (upload.disposed) return false;
      message.mediaStorageId = storageId;
      message.status = MessageStatus.pending;
      notifyListeners();
      return true;
    } on UploadCancelled {
      // Nothing to report: whoever cancelled it already removed the bubble.
      return false;
    } catch (_) {
      if (upload.disposed) return false;
      // Bytes and progress are kept: they are what makes retry possible.
      message.status = MessageStatus.error;
      notifyListeners();
      return false;
    } finally {
      upload.task = null;
    }
  }

  /// Posts an uploaded attachment, on its turn in [_attachments].
  Future<void> _runPost(String roomId, ChatMessage message) async {
    final upload = message.upload;
    // Discarded while it waited for the ones before it.
    if (upload != null && upload.disposed) return;
    if (!(_pending[roomId]?.contains(message) ?? false)) return;
    try {
      await _postMessage(roomId, message);
    } catch (_) {
      if (upload?.disposed ?? false) return;
      message.status = MessageStatus.error;
      notifyListeners();
    }
  }

  /// Set when the last send was refused by a child guard, so the room screen
  /// can show the "ask a grown-up" sheet instead of a silent failure.
  /// Read-and-clear: consuming it resets the flag.
  String? _lastSendLimit;

  /// The server limit the last failed send ran into, read-and-clear.
  String? takeSendLimit() {
    final code = _lastSendLimit;
    _lastSendLimit = null;
    return code;
  }

  String? _lastChildGateError;
  String? takeChildGateError() {
    final e = _lastChildGateError;
    _lastChildGateError = null;
    return e;
  }

  /// Apply [transform] to [messageId] wherever this room holds a copy of it,
  /// returning the rows that were replaced so the caller can put them back.
  ///
  /// The same `ChatMessage` can sit in FOUR lists at once — the live window,
  /// the retained older pages, a detached history window, and the outgoing
  /// queue — and they are separate `List`s holding the same instances. So
  /// patching one by index, which is what every caller here used to do, leaves
  /// the other three on the old value; `_withOlderPrefix` then splices a stale
  /// copy back in front of the fresh one on the very next subscription fire and
  /// the edit the user just made visibly reverts. That was a real bug in
  /// [editMessage] before this existed.
  ///
  /// A null return from [transform] removes the row instead of replacing it,
  /// which is how a delete renders before the server has confirmed it.
  ///
  /// Returns a per-list undo record. Empty means nothing here held the message,
  /// which is not an error — it may have scrolled out of every window.
  List<_MessagePatch> _patchMessageEverywhere(
    String roomId,
    String messageId,
    ChatMessage? Function(ChatMessage) transform,
  ) {
    final undo = <_MessagePatch>[];
    for (final list in [
      _messages[roomId],
      _olderPrefix[roomId],
      _historyWindow[roomId],
      _pending[roomId],
    ]) {
      if (list == null) continue;
      final i = list.indexWhere((m) => m.id == messageId);
      if (i < 0) continue;
      final before = list[i];
      final after = transform(before);
      if (after == null) {
        list.removeAt(i);
      } else {
        list[i] = after;
      }
      undo.add(_MessagePatch(list, i, before, removed: after == null));
    }
    return undo;
  }

  /// Put back what [_patchMessageEverywhere] changed, newest list first so an
  /// index recorded before a removal is still the right one to re-insert at.
  void _revertMessagePatches(List<_MessagePatch> patches) {
    for (final p in patches.reversed) {
      if (p.removed) {
        p.list.insert(p.index.clamp(0, p.list.length), p.before);
      } else if (p.index < p.list.length && p.list[p.index].id == p.before.id) {
        // Only if the subscription has not already replaced this row: whatever
        // it delivered IS the authoritative state, and overwriting it with our
        // snapshot would resurrect the thing the server just corrected.
        p.list[p.index] = p.before;
      }
    }
  }

  /// Removes the message locally first, then asks the server.
  ///
  /// It used to be three lines with no local removal at all, so a deleted
  /// bubble sat on screen — looking undeleted — until `messages:list` refired.
  /// That is a whole server round trip on a backend that can take seconds to
  /// answer, spent staring at the thing you just asked to be gone. The server
  /// remains the authority: a refusal puts the bubble back, and the refire that
  /// follows a success is a no-op because the row is already gone.
  Future<void> deleteMessage(String messageId) async {
    final id = _userId;
    if (id == null) return;
    final roomId = _activeRoomId;
    final undo = roomId == null
        ? const <_MessagePatch>[]
        : _patchMessageEverywhere(roomId, messageId, (_) => null);
    if (roomId != null) {
      // Held until the server stops sending the row. Removing it from the lists
      // is not enough on its own: this subscription refires on anything that
      // touches the window, and a delivery that arrives before the delete has
      // landed still carries the row — which would put the bubble back for a
      // round trip. See [_parseLiveWindow].
      (_deletedLocally[roomId] ??= <String>{}).add(messageId);
    }
    if (undo.isNotEmpty) notifyListeners();
    try {
      await api.deleteMessage(messageId: messageId, userId: id);
    } catch (_) {
      if (roomId != null) _deletedLocally[roomId]?.remove(messageId);
      _revertMessagePatches(undo);
      if (undo.isNotEmpty) notifyListeners();
      rethrow;
    }
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

    // Patch every copy, remembering how to undo it. The entry is swapped for a
    // copy rather than mutated so the revert is one assignment of the untouched
    // original.
    //
    // EVERY copy, not just the live window's, and that is the whole reason
    // [_patchMessageEverywhere] exists: `_olderPrefix` holds the same instances
    // in a different list, so patching by index here used to leave the old one
    // sitting in the prefix, and the next subscription fire spliced it back in
    // front via `_withOlderPrefix` — an edit to a message you had scrolled back
    // to reverted itself a moment later.
    final undo = _patchMessageEverywhere(
      roomId,
      message.id,
      (m) => m.copyWith(
        content: content,
        edited: true,
        mentions: mentions,
        mentionsEveryone: mentionsEveryone,
        formatting: formatting,
      ),
    );
    if (undo.isNotEmpty) notifyListeners();

    final err = await api.editMessage(
      messageId: message.id,
      userId: id,
      content: content,
      mentionedUserIds: [for (final m in mentions) m.userId],
      mentionsEveryone: mentionsEveryone,
      formatting: formatting,
    );
    if (err != null && undo.isNotEmpty) {
      // Refused: put the originals back. [_revertMessagePatches] skips any list
      // the subscription has already replaced under us, for the reason the old
      // inline version guarded by hand — whatever it delivered IS the
      // authoritative state, and overwriting it would resurrect the failure.
      _revertMessagePatches(undo);
      notifyListeners();
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
      final writing = _interactionWrites.containsKey('$roomId/${fresh.messageId}');
      final pending = authoritative && !writing
          ? const <String>{}
          : (existing?.pendingChoiceIds ?? const <String>{});
      slot[fresh.messageId] =
          pending.isEmpty ? fresh : fresh.copyWith(
            pendingChoiceIds: pending,
            pendingSelectedChoiceIds: existing?.pendingSelectedChoiceIds,
          );
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
  /// Returns false when the server refused (a closed poll or a checklist somebody else's tick), so the caller can say so.
  Future<bool> respondToInteraction({
    required String roomId,
    required String messageId,
    required String choiceId,
  }) async {
    final key = '$roomId/$messageId';
    final active = _interactionWrites[key];
    if (active != null) return active; // A second tap must not toggle it back.
    final task = Future<bool>.microtask(() => _respondToInteraction(roomId, messageId, choiceId));
    _interactionWrites[key] = task;
    try {
      return await task;
    } finally {
      if (identical(_interactionWrites[key], task)) _interactionWrites.remove(key);
    }
  }

  Future<bool> _respondToInteraction(
    String roomId, String messageId, String choiceId,
  ) async {
    final me = _userId;
    if (me == null) return false;
    final current = _interactions[roomId]?[messageId];
    final selected = current?.myChoiceIds.toSet() ?? <String>{};
    if (selected.contains(choiceId)) {
      if (current?.quiz == true) return true;
      selected.remove(choiceId);
    } else {
      if (current?.kind != MessageType.checklist && current?.multiple != true) {
        selected.clear();
      }
      selected.add(choiceId);
    }
    if (current != null) {
      final visualSelection = current.kind == MessageType.checklist
          ? current.choices.where((choice) => choice.count > 0).map((choice) => choice.id).toSet()
          : selected;
      if (current.kind == MessageType.checklist) {
        if (!visualSelection.remove(choiceId)) visualSelection.add(choiceId);
      }
      _interactions[roomId]![messageId] = current.copyWith(
        pendingChoiceIds: {choiceId},
        pendingSelectedChoiceIds: visualSelection,
      );
      notifyListeners();
    }
    try {
      await api.respondToInteraction(
        messageId: messageId, userId: me, choiceId: choiceId,
      );
      if (_userId != me) return true;
      // The mutation may finish before the subscription delivers the tally.
      // Keep the acknowledged selection until a fresh one-message read lands.
      final after = _interactions[roomId]?[messageId];
      if (after != null && current?.kind != MessageType.checklist) {
        _interactions[roomId]![messageId] = after.copyWith(myChoiceIds: selected.toList());
      }
      try {
        final rows = await api.interactionStateFor(messageIds: [messageId], userId: me);
        if (_userId == me) _mergeInteractions(roomId, rows, authoritative: false);
      } catch (_) {
        // The vote succeeded. A failed refresh is not a failed vote; the live
        // subscription will bring the tally when the connection catches up.
      }
      return true;
    } catch (_) {
      return false;
    } finally {
      if (_userId == me) {
        final after = _interactions[roomId]?[messageId];
        if (after != null) {
          _interactions[roomId]![messageId] = after.copyWith(pendingChoiceIds: {});
          notifyListeners();
        }
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

  /// Queues finished photos for [sendAt], each with its own caption. Returns
  /// null on success, or an error code the caller must surface — the
  /// [scheduleText] contract.
  ///
  /// Each picture is uploaded NOW, so what goes out is exactly what the sender
  /// reviewed, and the server holds the file against the scheduled row.
  ///
  /// One after another rather than all at once, for the album: each photo is
  /// due one millisecond after the one before it, so the server releases them
  /// in the order they sat in the composer — the same order a live multi-send
  /// posts them in. [replyToId] rides on the first, as a live send's does.
  Future<String?> schedulePhotos(
    String roomId,
    List<({CroppedImage image, String? caption})> photos, {
    required int sendAt,
    bool viewOnce = false,
    String? replyToId,
  }) async {
    final id = _userId;
    if (id == null) return 'SCHEDULE_FAILED';
    final stamp = DateTime.now().microsecondsSinceEpoch;
    try {
      for (var i = 0; i < photos.length; i++) {
        final photo = photos[i];
        final storageId = await UploadService(api).uploadFile(
          bytes: photo.image.bytes,
          contentType: photo.image.contentType,
        );
        await api.scheduleMessage(
          roomId: roomId,
          userId: id,
          content: photo.caption ?? '',
          sendAt: sendAt + i,
          replyToId: i == 0 ? replyToId : null,
          mediaStorageId: storageId,
          mediaWidth: photo.image.width.toDouble(),
          mediaHeight: photo.image.height.toDouble(),
          viewOnce: viewOnce,
          clientId: 'sch_${stamp}_$i',
        );
      }
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
      'MESSAGE_FILTER_BLOCKED',
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

  /// Snapshot the pins to disk, so the next cold start settles a cached roster
  /// to the same palette this session is showing rather than to the derived one
  /// the pins override. See `CacheStore.scheduleSaveSpeakerColors`.
  ///
  /// Only ever called where `_speakerColors` holds state the server has agreed
  /// to — the subscription's own delivery, and each mutation that returned
  /// without throwing. Never from the optimistic apply.
  void _persistSpeakerColors() {
    final id = _userId;
    if (id == null) return;
    CacheStore.instance.scheduleSaveSpeakerColors(id, _speakerColors);
  }

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
      // The mutation landed, so the optimistic map is now the server's answer
      // whether or not the echo has arrived — and an app killed in that window
      // would otherwise relaunch onto the pre-pin palette.
      _persistSpeakerColors();
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
      // Same reason as [setSpeakerSlot]: confirmed, so it is safe — and
      // necessary — to let the snapshot follow.
      _persistSpeakerColors();
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

  /// Adds or removes this viewer's [emoji] on [messageId], on screen first.
  ///
  /// This used to be server-first: decide add-vs-remove from the cached row,
  /// fire the mutation, and swallow the result because "the live subscription
  /// will reconcile". It does — eventually. Until then a double-tap produced
  /// nothing at all, and a second tap re-read the same unchanged row, decided
  /// `mineExists` was still false, and re-added. On a backend that can take a
  /// second or more to answer, the feature reads as broken.
  ///
  /// The optimistic row is applied everywhere the message is held (see
  /// [_patchMessageEverywhere]) and reverted if the mutation throws. The
  /// subscription echo that follows a success is identical to what is already
  /// on screen, so it lands as a no-op rather than a second repaint.
  ///
  /// Returns null when the toggle went through, or [kReactionLimitError] when
  /// adding would take the viewer past [kMaxMessageReactionsPerPerson] on this
  /// message — shaped like [pinMessage] for its reason: a refusal the user has
  /// to see. The cap is checked here first so nothing is painted and then
  /// snatched back; the server's own refusal is the backstop for a stale row.
  Future<String?> toggleReaction({
    required String messageId,
    required String emoji,

    /// A reaction to the whole album [messageId] heads rather than to that
    /// one photo: a separate set on the same message, with its own cap.
    bool album = false,
  }) async {
    final id = _userId;
    if (id == null) return null;
    final roomId = _activeRoomId;
    // Read the CURRENT state from the row we are about to patch, not from a
    // scan of every room: after the patch below the answer changes, and the
    // mutation has to be chosen from the state the user tapped on.
    final held = roomId == null ? null : _findMessage(roomId, messageId);
    bool inSet(MessageReaction r) => r.album == album;
    final mineExists = held?.reactions.any(
            (r) => inSet(r) && r.userId == id && r.emoji == emoji) ??
        false;
    if (!mineExists && held != null) {
      final mineCount =
          held.reactions.where((r) => inSet(r) && r.userId == id).length;
      if (mineCount >= kMaxMessageReactionsPerPerson) return kReactionLimitError;
    }

    final undo = roomId == null
        ? const <_MessagePatch>[]
        : _patchMessageEverywhere(roomId, messageId, (m) {
            final next = [...m.reactions];
            if (mineExists) {
              next.removeWhere(
                  (r) => inSet(r) && r.userId == id && r.emoji == emoji);
            } else {
              next.add(MessageReaction(
                // Provisional, and replaced by the server's own row on the
                // next fire. Prefixed like the optimistic message ids so
                // anything keying off it can tell it apart from a real one.
                id: 'tmp_${messageId}_${id}_${emoji}_${album ? 'a' : 'p'}',
                messageId: messageId,
                userId: id,
                emoji: emoji,
                createdAt: DateTime.now(),
                album: album,
              ));
            }
            return m.copyWith(reactions: next);
          });
    if (undo.isNotEmpty) notifyListeners();

    try {
      if (mineExists) {
        await api.removeReaction(
            messageId: messageId, userId: id, emoji: emoji, album: album);
      } else {
        await api.addReaction(
            messageId: messageId, userId: id, emoji: emoji, album: album);
      }
    } catch (e) {
      // Put it back rather than leaving the optimistic row to be corrected by
      // the next delivery — on the failure that matters here nothing was
      // written, so nothing invalidates and no delivery is coming.
      _revertMessagePatches(undo);
      if (undo.isNotEmpty) notifyListeners();
      if (e.toString().contains(kReactionLimitError)) return kReactionLimitError;
    }
    return null;
  }

  /// Messages this device learned about from a push and has not yet seen on
  /// the wire, per room.
  ///
  /// Held apart from [_pending], and that separation is load-bearing rather
  /// than tidy. `_pending` means "something THIS device is trying to send":
  /// [flushPending] walks it on every reconnect and re-posts anything still at
  /// `pending`/`error`, so a received message parked there would make the
  /// RECIPIENT re-send the sender's message from their own account. It is also
  /// why [reconcilesWith] cannot be borrowed for these — its first branch is
  /// `if (live.clientId != null) return live.clientId == pending.id`, and every
  /// message from a modern client carries a `clientId`, so a stub would compare
  /// a Convex document id against a client-minted uuid, never match, and render
  /// as a permanent duplicate. Stubs carry the server's own id, so their rule
  /// is one line: drop them when the transcript arrives.
  final Map<String, List<ChatMessage>> _pushStubs = {};

  /// The raw rows the last `messages:list` delivery carried, per room, keyed by
  /// message id. Compared against the next delivery so an unchanged row can
  /// keep the object it already has — see [_parseLiveWindow].
  final Map<String, Map<String, Map<String, dynamic>>> _lastLiveRaw = {};

  /// Ids this device has deleted optimistically and the server has not yet
  /// confirmed. See [_parseLiveWindow] for why they have to be held.
  final Map<String, Set<String>> _deletedLocally = {};

  /// Take whatever the native notification handlers staged and turn it into
  /// provisional bubbles, so a room opened from a notification is already
  /// showing the message that caused it.
  ///
  /// The push has carried the text all along — `notifications.ts` puts
  /// `messageId`, `senderName`, `content` and `type` in its `data` map — it
  /// simply had nowhere to go. Without this, tapping a banner paints a disk
  /// cache that predates the very message you tapped and then waits on the
  /// network to be told something the phone already knew.
  ///
  /// Text only, and only `plain` text at that. The `content` key is the room
  /// PREVIEW, so for anything else it is a glyph label — `"📷 Image"`,
  /// `"📊 <question>"` — and a stub built from one would be a photo bubble
  /// pointing at nothing or a poll card with no options. And a message
  /// carrying formatting, mentions or a reply tether would appear bare and
  /// then RE-LAY-OUT when the real row arrived, which is worse than a moment
  /// of nothing. `rooms:getMemberIds` decides `plain` server-side.
  Future<void> takePushedMessages() async {
    final me = _userId;
    if (me == null) return;
    final rows = await PushManager.instance.takePushInbox();
    if (rows.isEmpty) return;
    // Matches KIND_TTL_SECONDS.message on the backend: past it the push itself
    // would no longer be delivered, so a stub that old is a leftover from a
    // long-offline stretch rather than news. Without this a device that stopped
    // opening some rooms would carry their stubs for the rest of the session.
    final stale = DateTime.now().subtract(const Duration(hours: 24));
    var added = false;
    for (final data in rows) {
      final stub = _stubFromPush(data);
      if (stub == null) continue;
      if (stub.createdAt.isBefore(stale)) continue;
      final list = _pushStubs[stub.roomId] ??= [];
      if (list.any((m) => m.id == stub.id)) continue;
      list.add(stub);
      added = true;
    }
    if (added) {
      // The stub path in [messagesFor] sits ahead of the memo, so nothing there
      // is stale — but a merged list built a moment ago is, and it is the one
      // the room screen's item pass is memoised on.
      _mergedResult = null;
      notifyListeners();
    }
  }

  /// One push `data` map as a provisional message, or null if it is not
  /// something that can honestly be drawn from a notification.
  ChatMessage? _stubFromPush(Map<String, String> data) {
    if (data['kind'] != 'message') return null;
    if (data['type'] != 'text') return null;
    if (data['plain'] != 'true') return null;
    final id = data['messageId'];
    final roomId = data['roomId'];
    final senderId = data['senderId'];
    final at = int.tryParse(data['createdAt'] ?? '');
    // `createdAt` is the one field with no safe default: a stub without it
    // cannot be ordered, and inventing one would sort the bubble against a
    // clock nobody else is using. A native binary older than the server that
    // sends it simply seeds nothing, which is the pre-existing behaviour.
    if (id == null || roomId == null || senderId == null || at == null) {
      return null;
    }
    if (id.isEmpty || roomId.isEmpty) return null;
    return ChatMessage(
      id: id,
      roomId: roomId,
      senderId: senderId,
      senderName: data['senderName'] ?? '',
      content: data['content'] ?? '',
      createdAt: DateTime.fromMillisecondsSinceEpoch(at),
    );
  }

  /// Turn a `messages:list` payload into messages, keeping the instance we
  /// already hold for every row that did not change.
  ///
  /// Convex re-sends the WHOLE window on every change, so a single arriving
  /// message used to mean [kLiveWindow] `fromJson` calls and a transcript in
  /// which every row was a new object — which makes every row's props look
  /// changed, misses the item-pass memo in `RoomScreen`, and rebuilds the
  /// entire visible list to show one new bubble. Comparing the raw maps and
  /// reusing the unchanged ones turns that back into "one row is new".
  ///
  /// Compared as raw JSON rather than by giving [ChatMessage] a value
  /// `operator ==`: it has some forty fields, four of them non-final and one a
  /// mutable list, so a value `hashCode` would change under any in-place
  /// mutation and quietly corrupt every `Map` and `Set` holding one.
  ///
  /// Reusing an instance also preserves an optimistic local patch of it (see
  /// [_patchMessageEverywhere]) for as long as the server's own row is
  /// unchanged — which is the behaviour you want: a refire triggered by
  /// somebody else's reaction should not flicker your own un-acked edit back to
  /// its old text. The moment the server's row does change, it is re-parsed and
  /// the server wins.
  List<ChatMessage> _parseLiveWindow(String roomId, List<dynamic> rows) {
    final prevRaw = _lastLiveRaw[roomId];
    final prevById = <String, ChatMessage>{
      for (final m in _messages[roomId] ?? const <ChatMessage>[]) m.id: m,
    };
    final tombstones = _deletedLocally[roomId];
    final nextRaw = <String, Map<String, dynamic>>{};
    // Every id this delivery carried, tombstoned ones included — see the
    // tombstone cleanup at the end.
    final sent = <String>{};
    final out = <ChatMessage>[];
    for (final e in rows) {
      if (e is! Map) continue;
      final raw = e.cast<String, dynamic>();
      final id = (raw['_id'] ?? raw['id']).toString();
      // Recorded before the tombstone check, not after: this is "what the
      // server sent", which is exactly the question the cleanup below asks. A
      // hidden row is still a row the server sent, and dropping its tombstone
      // here would un-hide it on the very next delivery.
      sent.add(id);
      // Still carrying a row we have already taken off screen: the delete is in
      // flight and this delivery was triggered by something else entirely.
      // Re-parsing it here would resurrect the bubble for one round trip.
      if (tombstones != null && tombstones.contains(id)) continue;
      nextRaw[id] = raw;
      final before = prevById[id];
      if (before != null &&
          prevRaw != null &&
          _jsonEquals(prevRaw[id], raw)) {
        out.add(before);
        continue;
      }
      out.add(ChatMessage.fromJson(raw));
    }
    // Anything the server no longer sends has been deleted for real, so the
    // tombstone has done its job and must not outlive it — otherwise an id the
    // server later reuses (or a room reopened) would be invisible.
    if (tombstones != null) {
      tombstones.removeWhere((id) => !sent.contains(id));
      if (tombstones.isEmpty) _deletedLocally.remove(roomId);
    }
    _lastLiveRaw[roomId] = nextRaw;
    return out;
  }

  /// Structural equality for decoded JSON — maps, lists and scalars.
  ///
  /// Hand-rolled rather than `DeepCollectionEquality`, to avoid taking a
  /// dependency on `package:collection` for one function on a hot path.
  static bool _jsonEquals(Object? a, Object? b) {
    if (identical(a, b)) return true;
    if (a is Map && b is Map) {
      if (a.length != b.length) return false;
      for (final k in a.keys) {
        if (!b.containsKey(k) || !_jsonEquals(a[k], b[k])) return false;
      }
      return true;
    }
    if (a is List && b is List) {
      if (a.length != b.length) return false;
      for (var i = 0; i < a.length; i++) {
        if (!_jsonEquals(a[i], b[i])) return false;
      }
      return true;
    }
    return a == b;
  }

  /// The room's copy of [messageId] from whichever list holds it, or null.
  ChatMessage? _findMessage(String roomId, String messageId) {
    for (final list in [
      _messages[roomId],
      _olderPrefix[roomId],
      _historyWindow[roomId],
      _pending[roomId],
    ]) {
      if (list == null) continue;
      for (final m in list) {
        if (m.id == messageId) return m;
      }
    }
    return null;
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
            _isPostable(m) &&
            !_heldFromLastRun.contains(m.id)) {
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

/// One list's worth of undo for [ChatRepository._patchMessageEverywhere].
///
/// A class rather than a record because it carries a live `List` reference and
/// is meant to be read back in one place only; naming the fields is what makes
/// [ChatRepository._revertMessagePatches] legible.
class _MessagePatch {
  _MessagePatch(this.list, this.index, this.before, {required this.removed});

  final List<ChatMessage> list;
  final int index;
  final ChatMessage before;

  /// Whether the patch took the row out, as opposed to replacing it. Decides
  /// between `insert` and an assignment on the way back.
  final bool removed;
}

