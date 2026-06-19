import 'convex_client.dart';

/// Client for the WebRTC 1:1 calling backend (Convex `calls:*` functions plus
/// the `calls:getIceConfig` action).
///
/// Split out of [ChatApi] so the call stack ([CallService],
/// [SignalingSubscriber], [ActiveCallPill]) depends only on the call surface
/// instead of the full chat/rooms/friends facade. Depends only on
/// [ConvexBackend] — no model imports.
class CallApi {
  CallApi(this._cv);
  final ConvexBackend _cv;

  Future<String> initiateCall({
    required String callerId,
    required String calleeId,
    required String roomId,
    required String type, // "audio" | "video"
  }) async {
    final res = await _cv.mutation('calls:initiate', {
      'callerId': callerId,
      'calleeId': calleeId,
      'roomId': roomId,
      'type': type,
    });
    return res.toString();
  }

  Future<void> acceptCall({
    required String callId,
    required String userId,
    String? acceptingDeviceId,
  }) async {
    await _cv.mutation('calls:accept', {
      'callId': callId,
      'userId': userId,
      'acceptingDeviceId': ?acceptingDeviceId,
    });
  }

  Future<void> rejectCall({
    required String callId,
    required String userId,
    String? acceptingDeviceId,
  }) async {
    await _cv.mutation('calls:reject', {
      'callId': callId,
      'userId': userId,
      'acceptingDeviceId': ?acceptingDeviceId,
    });
  }

  Future<void> cancelCall({required String callId, required String userId}) async {
    await _cv.mutation('calls:cancel', {'callId': callId, 'userId': userId});
  }

  Future<void> endCall({required String callId, required String userId}) async {
    await _cv.mutation('calls:end', {'callId': callId, 'userId': userId});
  }

  Future<void> sendCallSignal({
    required String callId,
    required String fromUserId,
    required String toUserId,
    required String kind, // "offer"|"answer"|"ice"|"state"|"bye"|"reject"|"cancel"|"handoff-*"
    required String payload,
    String? fromDeviceId,
    String? targetDeviceId,
  }) async {
    await _cv.mutation('calls:sendSignal', {
      'callId': callId,
      'fromUserId': fromUserId,
      'toUserId': toUserId,
      'kind': kind,
      'payload': payload,
      'fromDeviceId': ?fromDeviceId,
      'targetDeviceId': ?targetDeviceId,
    });
  }

  /// Transfer an active call from whichever device holds it to [newDeviceId].
  /// Returns the old deviceId (or null) so the client can update local
  /// state. Side effects on the backend: writes `handoff-takeover` to the
  /// old device and `handoff-prepare` to the peer.
  Future<String?> handoffCall({
    required String callId,
    required String userId,
    required String newDeviceId,
  }) async {
    final res = await _cv.mutation('calls:handoffCall', {
      'callId': callId,
      'userId': userId,
      'newDeviceId': newDeviceId,
    });
    if (res is Map) {
      final old = res['oldDeviceId'];
      return old?.toString();
    }
    return null;
  }

  Future<void> consumeCallSignal({
    required String signalId,
    required String userId,
  }) async {
    await _cv.mutation('calls:consumeSignal', {
      'signalId': signalId,
      'userId': userId,
    });
  }

  /// Live subscription to my current `ringing` or `active` call (if any).
  /// Backs the global "Move call here" pill and any other UI that needs
  /// to know "is there a call happening on one of my devices right now?".
  /// Each emission is an inflated record with peer name, type, status,
  /// acceptingDeviceId, and the holding device's deviceName / platform
  /// (null when there is no live call).
  Future<Subscription> subscribeActiveCall({
    required String userId,
    required void Function(Map<String, dynamic>? call) onCall,
    void Function(Object error)? onError,
  }) {
    return _cv.subscribe(
      'calls:activeCallForUser',
      {'userId': userId},
      onData: (raw) {
        if (raw == null) {
          onCall(null);
          return;
        }
        onCall((raw as Map).cast<String, dynamic>());
      },
      onError: onError,
    );
  }

  /// Returns `{ iceServers: [{urls, username?, credential?}, …] }`.
  Future<List<Map<String, dynamic>>> getIceConfig(String userId) async {
    final res = await _cv.action('calls:getIceConfig', {'userId': userId});
    final list = ((res as Map?)?['iceServers'] as List?) ?? const [];
    return list
        .map((e) => (e as Map).cast<String, dynamic>())
        .toList(growable: false);
  }

  /// Live subscription to my unconsumed inbound signals. The caller is
  /// responsible for calling [consumeCallSignal] for each signal it processes.
  Future<Subscription> subscribeCallSignals({
    required String userId,
    required void Function(List<Map<String, dynamic>> signals) onSignals,
    void Function(Object error)? onError,
  }) {
    return _cv.subscribe(
      'calls:signalsForUser',
      {'userId': userId},
      onData: (raw) {
        final list = (raw as List?) ?? const [];
        final out = list
            .map((e) => (e as Map).cast<String, dynamic>())
            .toList(growable: false);
        onSignals(out);
      },
      onError: onError,
    );
  }
}
