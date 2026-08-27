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

  /// Returns the backend's disposition ("accepted" | "not-ringing"), or null
  /// from a backend that predates status returns. A late accept — the call
  /// already timed out, was cancelled, or a sibling device settled it first
  /// — comes back as "not-ringing" instead of throwing.
  Future<String?> acceptCall({
    required String callId,
    required String userId,
    String? acceptingDeviceId,
  }) async {
    final res = await _cv.mutation('calls:accept', {
      'callId': callId,
      'userId': userId,
      'acceptingDeviceId': ?acceptingDeviceId,
    });
    return res?.toString();
  }

  /// Returns the backend's disposition ("rejected" | "not-ringing"), or null
  /// from a backend that predates status returns. Callers may ignore it.
  Future<String?> rejectCall({
    required String callId,
    required String userId,
    String? acceptingDeviceId,
  }) async {
    final res = await _cv.mutation('calls:reject', {
      'callId': callId,
      'userId': userId,
      'acceptingDeviceId': ?acceptingDeviceId,
    });
    return res?.toString();
  }

  /// Returns the backend's disposition — "cancelled", "ended" (the callee
  /// accepted inside the race window and the server auto-converted to a
  /// full end), or "already-terminal" — or null from a backend that
  /// predates status returns. Informational: the race is resolved
  /// server-side, so the client never needs a follow-up verb.
  Future<String?> cancelCall({required String callId, required String userId}) async {
    final res = await _cv
        .mutation('calls:cancel', {'callId': callId, 'userId': userId});
    return res?.toString();
  }

  /// Returns "ended" | "already-terminal", or null from an older backend.
  Future<String?> endCall({required String callId, required String userId}) async {
    final res =
        await _cv.mutation('calls:end', {'callId': callId, 'userId': userId});
    return res?.toString();
  }

  /// Pinged periodically while a call is active so `calls:gcStuckActive` can
  /// tell a genuinely abandoned call (crash, dead battery) apart from one
  /// that's just running long. Returns "ok" while the call is active,
  /// "not-in-call" once it isn't (null from an older backend) — the client
  /// tears down on "not-in-call", which covers a dead signaling
  /// subscription that swallowed every terminal signal.
  Future<String?> heartbeat({required String callId, required String userId}) async {
    final res = await _cv
        .mutation('calls:heartbeat', {'callId': callId, 'userId': userId});
    return res?.toString();
  }

  /// This device no longer shows a native card (CallKit/ConnectionService)
  /// for [callId]. Every terminal transition schedules a native `taken` push
  /// after a short grace so a card in a KILLED process still gets dismissed;
  /// a device that acks inside that grace is skipped — which on iOS is the
  /// difference between nothing and a one-second phantom "Call".
  Future<void> ackNativeDismissed({
    required String callId,
    required String userId,
    required String deviceId,
  }) async {
    await _cv.mutation('calls:ackNativeDismissed', {
      'callId': callId,
      'userId': userId,
      'deviceId': deviceId,
    });
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

  /// Batch variant — one mutation for a whole drain pass instead of one per
  /// signal. Missing/foreign ids are skipped server-side.
  Future<void> consumeCallSignals({
    required List<String> signalIds,
    required String userId,
  }) async {
    if (signalIds.isEmpty) return;
    await _cv.mutation('calls:consumeSignals', {
      'signalIds': signalIds,
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

  /// One-shot status probe for a specific call. Returns the status string
  /// ("ringing" | "active" | "ended" | "missed" | "cancelled" | "rejected"),
  /// or null when the call no longer exists (GC'd) or isn't ours. Used to
  /// validate a native CallKit card before honoring accept/decline on it.
  Future<String?> getCallStatus({
    required String callId,
    required String userId,
  }) async {
    final res = await _cv.query('calls:getCallStatus', {
      'callId': callId,
      'userId': userId,
    });
    return (res as Map?)?['status']?.toString();
  }

  /// One-shot snapshot of my live `ringing`/`active` call (same shape as
  /// [subscribeActiveCall] emissions, null when there is none). Used by
  /// cold-start reconciliation to decide whether a persisted native call
  /// card is real or stale.
  Future<Map<String, dynamic>?> getActiveCallOnce({
    required String userId,
  }) async {
    final res = await _cv.query('calls:activeCallForUser', {'userId': userId});
    if (res == null) return null;
    return (res as Map).cast<String, dynamic>();
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
