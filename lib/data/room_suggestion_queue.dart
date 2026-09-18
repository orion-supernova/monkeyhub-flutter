import 'dart:async';

import 'package:flutter/widgets.dart';

import '../models/chat_room.dart';
import '../models/chat_user.dart';
import '../models/room_admin.dart';
import 'chat_repository.dart';

/// The suggestions waiting on THIS reader, for the room they have open.
///
/// A member's suggested group photo used to reach an admin one way only: a
/// push, and then a row near the bottom of Room Info. When the push did not
/// arrive — a device with no FCM token, notifications muted, a banner swiped
/// away — the suggestion existed for the member and for nobody else, which is
/// exactly how it looked from both ends ("only I can see what I suggested").
/// The room itself is where an admin actually is, so that is where this puts
/// it.
///
/// ── Why fetched and not subscribed ─────────────────────────────────────────
///
/// A room's live-query budget is guarded hard (see the `messages:list` notes in
/// [ChatRepository]); one more subscription per room open, for a queue that is
/// empty in nearly every room nearly all the time, is not worth it. So this
/// reads once when the reader turns out to be an admin, again whenever they
/// come back to the app, and again after anything that could have answered a
/// suggestion — the review sheet, Room Info. A suggestion filed while the
/// admin is staring at the room is announced by its push, and is here the next
/// time they return.
///
/// Admin standing comes from the roster the room already subscribes to
/// (`rooms:getMembers` carries each member's role), so a plain member costs
/// nothing at all: no query is ever issued for them.
class RoomSuggestionQueue extends ChangeNotifier with WidgetsBindingObserver {
  /// The four things this needs, as functions rather than a repository, so it
  /// can be driven without one. [RoomSuggestionQueue.forRoom] wires them to
  /// [ChatRepository].
  RoomSuggestionQueue({
    required String? Function() me,
    required ChatRoom? Function() room,
    required List<ChatUser> Function() roster,
    required Future<List<RoomChangeRequest>> Function() fetch,
  })  : _me = me,
        _roomOf = room,
        _roster = roster,
        _fetch = fetch {
    WidgetsBinding.instance.addObserver(this);
  }

  factory RoomSuggestionQueue.forRoom(ChatRepository repo, String roomId) =>
      RoomSuggestionQueue(
        me: () => repo.userId,
        room: () => repo.roomById(roomId),
        roster: () => repo.membersFor(roomId),
        fetch: () => repo.listRoomChangeRequests(roomId),
      );

  final String? Function() _me;
  final ChatRoom? Function() _roomOf;
  final List<ChatUser> Function() _roster;
  final Future<List<RoomChangeRequest>> Function() _fetch;

  List<RoomChangeRequest> _pending = const [];
  bool _reviewer = false;
  bool _disposed = false;
  Future<void>? _inFlight;
  bool _again = false;

  /// Oldest first — the order the admin's sheet lists them in.
  List<RoomChangeRequest> get pending => _pending;

  /// Whether the reader can answer suggestions here. False until the roster
  /// says otherwise, so a member is never shown an admin's strip for a frame.
  bool get isReviewer => _reviewer;

  /// Re-derives admin standing from the roster, and reads the queue on the
  /// transition into being an admin — the only moment it has to.
  void syncStanding() {
    final next = _computeReviewer();
    if (next == _reviewer) return;
    _reviewer = next;
    if (!next) {
      _set(const []);
      return;
    }
    unawaited(refresh());
  }

  bool _computeReviewer() {
    final me = _me();
    final room = _roomOf();
    if (me == null || room == null) return false;
    if (!room.isGroupChat || room.isSystemRoom) return false;
    for (final u in _roster()) {
      if (u.id != me) continue;
      return RoomRoleWire.parse(u.role).isAdmin;
    }
    return false;
  }

  /// Reads the queue again. Coalesced: a call while one is in flight schedules
  /// exactly one more read after it, so the answer always reflects the newest
  /// ask without stacking up round trips.
  Future<void> refresh() {
    if (!_reviewer || _disposed) return Future.value();
    if (_inFlight != null) {
      _again = true;
      return _inFlight!;
    }
    return _inFlight = _read().whenComplete(() {
      _inFlight = null;
      if (_again && !_disposed) {
        _again = false;
        unawaited(refresh());
      }
    });
  }

  Future<void> _read() async {
    try {
      final list = await _fetch();
      if (_disposed || !_reviewer) return;
      _set(list);
    } catch (e) {
      // Offline, or a backend without the queue deployed. The strip simply
      // stays as it was; the next resume asks again.
      debugPrint('RoomSuggestionQueue: $e');
    }
  }

  void _set(List<RoomChangeRequest> next) {
    if (_sameIds(next, _pending)) return;
    _pending = List.unmodifiable(next);
    notifyListeners();
  }

  static bool _sameIds(List<RoomChangeRequest> a, List<RoomChangeRequest> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i].requestId != b[i].requestId) return false;
    }
    return true;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) unawaited(refresh());
  }

  @override
  void dispose() {
    _disposed = true;
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }
}
