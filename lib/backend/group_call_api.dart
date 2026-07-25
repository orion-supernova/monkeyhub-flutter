import 'convex_client.dart';

/// Client for the mesh group-call backend (Convex `groupCalls:*`).
/// Mirrors [CallApi]'s shape so the group-call stack depends only on the
/// group-call surface.
class GroupCallApi {
  GroupCallApi(this._cv);
  final ConvexBackend _cv;

  /// Starts a call in [roomId] (or joins the one already active there —
  /// the server converges races). `inviteeIds == null` invites everyone.
  /// Returns `{groupCallId, existing}`.
  Future<({String groupCallId, bool existing})> start({
    required String roomId,
    required String userId,
    required String type,
    String? deviceId,
    List<String>? inviteeIds,
  }) async {
    final res = await _cv.mutation('groupCalls:start', {
      'roomId': roomId,
      'userId': userId,
      'type': type,
      'deviceId': ?deviceId,
      'inviteeIds': ?inviteeIds,
    });
    final map = (res as Map).cast<String, dynamic>();
    return (
      groupCallId: map['groupCallId'].toString(),
      existing: (map['existing'] as bool?) ?? false,
    );
  }

  /// Returns `{type, roomId}` of the joined call.
  Future<({String type, String roomId})> join({
    required String groupCallId,
    required String userId,
    String? deviceId,
  }) async {
    final res = await _cv.mutation('groupCalls:join', {
      'groupCallId': groupCallId,
      'userId': userId,
      'deviceId': ?deviceId,
    });
    final map = (res as Map).cast<String, dynamic>();
    return (
      type: map['type'].toString(),
      roomId: map['roomId'].toString(),
    );
  }

  Future<void> leave({
    required String groupCallId,
    required String userId,
  }) async {
    await _cv.mutation('groupCalls:leave', {
      'groupCallId': groupCallId,
      'userId': userId,
    });
  }

  Future<void> decline({
    required String groupCallId,
    required String userId,
  }) async {
    await _cv.mutation('groupCalls:decline', {
      'groupCallId': groupCallId,
      'userId': userId,
    });
  }

  Future<void> heartbeat({
    required String groupCallId,
    required String userId,
  }) async {
    await _cv.mutation('groupCalls:heartbeat', {
      'groupCallId': groupCallId,
      'userId': userId,
    });
  }

  Future<void> sendSignal({
    required String groupCallId,
    required String fromUserId,
    required String toUserId,
    required String kind,
    required String payload,
    String? fromDeviceId,
    String? targetDeviceId,
  }) async {
    await _cv.mutation('groupCalls:sendSignal', {
      'groupCallId': groupCallId,
      'fromUserId': fromUserId,
      'toUserId': toUserId,
      'kind': kind,
      'payload': payload,
      'fromDeviceId': ?fromDeviceId,
      'targetDeviceId': ?targetDeviceId,
    });
  }

  Future<void> consumeSignals({
    required List<String> signalIds,
    required String userId,
  }) async {
    if (signalIds.isEmpty) return;
    await _cv.mutation('groupCalls:consumeSignals', {
      'signalIds': signalIds,
      'userId': userId,
    });
  }

  Future<Subscription> subscribeSignals({
    required String userId,
    required void Function(List<Map<String, dynamic>> signals) onSignals,
    void Function(Object error)? onError,
  }) {
    return _cv.subscribe(
      'groupCalls:signalsForUser',
      {'userId': userId},
      onData: (raw) {
        final list = (raw as List?) ?? const [];
        onSignals(list
            .map((e) => (e as Map).cast<String, dynamic>())
            .toList(growable: false));
      },
      onError: onError,
    );
  }

  Future<Subscription> subscribeRoster({
    required String groupCallId,
    required String userId,
    required void Function(Map<String, dynamic>? roster) onRoster,
    void Function(Object error)? onError,
  }) {
    return _cv.subscribe(
      'groupCalls:roster',
      {'groupCallId': groupCallId, 'userId': userId},
      onData: (raw) {
        onRoster(raw == null ? null : (raw as Map).cast<String, dynamic>());
      },
      onError: onError,
    );
  }

  /// Live "is there a call in this room?" — drives the in-room banner.
  Future<Subscription> subscribeActiveForRoom({
    required String roomId,
    required String userId,
    required void Function(Map<String, dynamic>? call) onCall,
    void Function(Object error)? onError,
  }) {
    return _cv.subscribe(
      'groupCalls:activeForRoom',
      {'roomId': roomId, 'userId': userId},
      onData: (raw) {
        onCall(raw == null ? null : (raw as Map).cast<String, dynamic>());
      },
      onError: onError,
    );
  }

  /// Live freshest ring-worthy group invite for this user.
  Future<Subscription> subscribePendingInvite({
    required String userId,
    required void Function(Map<String, dynamic>? invite) onInvite,
    void Function(Object error)? onError,
  }) {
    return _cv.subscribe(
      'groupCalls:pendingInviteForUser',
      {'userId': userId},
      onData: (raw) {
        onInvite(raw == null ? null : (raw as Map).cast<String, dynamic>());
      },
      onError: onError,
    );
  }
}
