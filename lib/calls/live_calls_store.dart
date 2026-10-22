import 'dart:async';

import 'package:flutter/foundation.dart';

import '../backend/group_call_api.dart';
import 'call_models.dart';
import 'call_service.dart';

/// Binds `groupCalls:liveInMyRooms`; returns the canceller. [roomIds] null
/// means every room. Injected for tests.
typedef LiveSubscribe = Future<void Function()> Function(
  List<String>? roomIds,
  void Function(List<Map<String, dynamic>> rows) onCalls,
  void Function(Object error) onError,
);

/// A call going on in one room right now, as the chat list shows it.
@immutable
class LiveRoomCall {
  const LiveRoomCall({
    required this.roomId,
    required this.video,
    required this.count,
    required this.mine,
    this.groupCallId,
    this.startedAt,
  });

  final String roomId;

  /// The room's group call, for the Join pill. Null for a 1:1 call.
  final String? groupCallId;
  final bool video;

  /// How many are in it.
  final int count;

  /// You are in it, on this device or another.
  final bool mine;
  final DateTime? startedAt;

  @override
  bool operator ==(Object other) =>
      other is LiveRoomCall &&
      other.roomId == roomId &&
      other.groupCallId == groupCallId &&
      other.video == video &&
      other.count == count &&
      other.mine == mine &&
      other.startedAt == startedAt;

  @override
  int get hashCode =>
      Object.hash(roomId, groupCallId, video, count, mine, startedAt);
}

/// The calls going on in your rooms, for the chat list's live rows.
///
/// Group calls come from ONE subscription for every room
/// (`groupCalls:liveInMyRooms`, which reads only the call rows, never the
/// participants a heartbeat patches every 15 seconds). A 1:1 call needs no
/// subscription of its own: [CallService] already knows the call on this
/// device and, through `activeCallForUser`, the one on your other devices.
///
/// Notifies only when what a row would show changes: [CallService]
/// notifies on every stream tick and stats sample, and a chat list must not
/// rebuild with it.
class LiveCallsStore extends ChangeNotifier {
  LiveCallsStore._();
  static final LiveCallsStore instance = LiveCallsStore._();

  String? _user;
  void Function()? _cancelSub;
  LiveSubscribe? _subscribe;
  CallService? _calls;

  /// The rooms the chat list has loaded, sorted, and their joined key. The key
  /// is what makes a re-announcement of the same set free.
  List<String> _roomIds = const [];
  String? _roomsKey;

  /// Bumped on every (re)subscribe and on detach, so a late subscribe result
  /// from a superseded attempt is cancelled instead of kept.
  int _gen = 0;

  /// An older server rejects the `roomIds` argument; once seen, ask for every
  /// room instead.
  bool _idsRejected = false;

  /// The ids the live subscription was opened with; null when it asked for
  /// every room. For tests.
  @visibleForTesting
  List<String>? subscribedRoomIds;

  Map<String, LiveRoomCall> _group = const {};
  LiveRoomCall? _direct;

  /// The call in [roomId], if one is going on.
  LiveRoomCall? forRoom(String roomId) {
    final g = _group[roomId];
    if (g != null) return g;
    final d = _direct;
    return d != null && d.roomId == roomId ? d : null;
  }

  Future<void> attach(GroupCallApi api, String userId) => attachWith(
    (roomIds, onCalls, onError) async {
      final sub = await api.subscribeLiveInMyRooms(
        userId: userId,
        roomIds: roomIds,
        onCalls: onCalls,
        onError: onError,
      );
      return sub.cancel;
    },
    userId,
  );

  /// [attach] with the subscribe call injected, for tests.
  @visibleForTesting
  Future<void> attachWith(LiveSubscribe subscribe, String userId) async {
    if (_user == userId && _subscribe != null) return;
    detach();
    _user = userId;
    _subscribe = subscribe;
    final calls = CallService.maybeInstance;
    if (calls != null) {
      _calls = calls..addListener(_onCalls);
      _onCalls();
    }
    await _resubscribe();
  }

  /// Tells the store which rooms the chat list has loaded (at most
  /// [maxRooms]). Subscribes once the first non-empty set arrives, and again
  /// only when the SET changes: the sorted ids are compared as one key, so a
  /// list that merely reorders or refreshes costs nothing.
  void syncRooms(Iterable<String> ids) {
    final sorted = ids.toSet().toList()..sort();
    if (sorted.length > maxRooms) sorted.removeRange(maxRooms, sorted.length);
    final key = sorted.join(',');
    if (key == _roomsKey) return;
    _roomsKey = key;
    _roomIds = sorted;
    if (_user != null) unawaited(_resubscribe());
  }

  /// The server reads at most this many rooms (`ROOMS_PER_USER_CAP`).
  static const int maxRooms = 500;

  Future<void> _resubscribe() async {
    final userId = _user;
    final subscribe = _subscribe;
    if (userId == null || subscribe == null) return;
    final gen = ++_gen;
    _cancelSub?.call();
    _cancelSub = null;
    // Nothing loaded yet: no rooms means no calls to find, and asking the
    // server for "every room" here is the very read this avoids.
    if (_roomIds.isEmpty && !_idsRejected) {
      subscribedRoomIds = null;
      if (_group.isNotEmpty) {
        _group = const {};
        notifyListeners();
      }
      return;
    }
    final ids = _idsRejected ? null : _roomIds;
    subscribedRoomIds = ids;
    try {
      final cancel = await subscribe(
        ids,
        (rows) => _onGroup(userId, rows),
        (e) {
          debugPrint('LiveCallsStore: $e');
          if (gen != _gen || ids == null) return;
          // Only an argument the server does not know justifies the fallback.
          final m = e.toString();
          if (m.contains('ArgumentValidationError') ||
              m.contains('roomIds')) {
            _idsRejected = true;
            unawaited(_resubscribe());
          }
        },
      );
      if (gen != _gen || _user != userId) {
        cancel();
        return;
      }
      _cancelSub = cancel;
    } catch (e) {
      debugPrint('groupCalls:liveInMyRooms failed: $e');
    }
  }

  void detach() {
    _gen++;
    _cancelSub?.call();
    _cancelSub = null;
    _subscribe = null;
    _calls?.removeListener(_onCalls);
    _calls = null;
    _user = null;
    _roomIds = const [];
    _roomsKey = null;
    _idsRejected = false;
    subscribedRoomIds = null;
    final had = _group.isNotEmpty || _direct != null;
    _group = const {};
    _direct = null;
    if (had) notifyListeners();
  }

  /// Puts [calls] on the list without a backend, for previews and widget
  /// tests. An empty list clears them.
  @visibleForTesting
  void debugShow(List<LiveRoomCall> calls) {
    _group = {for (final c in calls) c.roomId: c};
    notifyListeners();
  }

  void _onGroup(String userId, List<Map<String, dynamic>> rows) {
    if (_user != userId) return;
    final next = <String, LiveRoomCall>{
      for (final r in rows)
        if (_groupRow(userId, r) case final e?) e.key: e.value,
    };
    if (mapEquals(next, _group)) return;
    _group = next;
    notifyListeners();
  }

  static MapEntry<String, LiveRoomCall>? _groupRow(
    String userId,
    Map<String, dynamic> r,
  ) {
    final roomId = r['roomId']?.toString();
    final joined = [
      for (final id in (r['joinedUserIds'] as List?) ?? const []) id.toString(),
    ];
    if (roomId == null || joined.isEmpty) return null;
    final started = (r['startedAt'] as num?)?.toInt();
    return MapEntry(
      roomId,
      LiveRoomCall(
        roomId: roomId,
        groupCallId: r['groupCallId']?.toString(),
        video: r['type'] == 'video',
        count: joined.length,
        mine: joined.contains(userId),
        startedAt: started == null
            ? null
            : DateTime.fromMillisecondsSinceEpoch(started),
      ),
    );
  }

  void _onCalls() {
    final next = directCallFrom(_calls);
    if (next == _direct) return;
    _direct = next;
    notifyListeners();
  }

  /// The 1:1 call [svc] knows of: this device's, once it is connected,
  /// else the one on another of your devices.
  @visibleForTesting
  static LiveRoomCall? directCallFrom(CallService? svc) {
    if (svc == null) return null;
    final s = svc.session;
    if (s != null &&
        (s.status == CallStatus.active ||
            s.status == CallStatus.switching ||
            s.status == CallStatus.connecting)) {
      return LiveRoomCall(
        roomId: s.roomId,
        video: s.mediaKind == CallMediaKind.video,
        count: 2,
        mine: true,
        startedAt: s.connectedAt ?? s.startedAt,
      );
    }
    final c = svc.activeCallElsewhere;
    final roomId = c?['roomId']?.toString();
    if (c == null || roomId == null) return null;
    final at = (c['acceptedAt'] as num?) ?? (c['startedAt'] as num?);
    return LiveRoomCall(
      roomId: roomId,
      video: c['type'] == 'video',
      count: 2,
      mine: true,
      startedAt:
          at == null ? null : DateTime.fromMillisecondsSinceEpoch(at.toInt()),
    );
  }
}
