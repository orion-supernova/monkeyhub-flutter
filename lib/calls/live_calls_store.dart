import 'dart:async';

import 'package:flutter/foundation.dart';

import '../backend/convex_client.dart';
import '../backend/group_call_api.dart';
import 'call_models.dart';
import 'call_service.dart';

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
  Subscription? _sub;
  CallService? _calls;

  Map<String, LiveRoomCall> _group = const {};
  LiveRoomCall? _direct;

  /// The call in [roomId], if one is going on.
  LiveRoomCall? forRoom(String roomId) {
    final g = _group[roomId];
    if (g != null) return g;
    final d = _direct;
    return d != null && d.roomId == roomId ? d : null;
  }

  Future<void> attach(GroupCallApi api, String userId) async {
    if (_user == userId && _sub != null) return;
    detach();
    _user = userId;
    final calls = CallService.maybeInstance;
    if (calls != null) {
      _calls = calls..addListener(_onCalls);
      _onCalls();
    }
    try {
      final sub = await api.subscribeLiveInMyRooms(
        userId: userId,
        onCalls: (rows) => _onGroup(userId, rows),
        onError: (e) => debugPrint('LiveCallsStore: $e'),
      );
      if (_user != userId) {
        sub.cancel();
        return;
      }
      _sub = sub;
    } catch (e) {
      debugPrint('groupCalls:liveInMyRooms failed: $e');
    }
  }

  void detach() {
    _sub?.cancel();
    _sub = null;
    _calls?.removeListener(_onCalls);
    _calls = null;
    _user = null;
    final had = _group.isNotEmpty || _direct != null;
    _group = const {};
    _direct = null;
    if (had) notifyListeners();
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
