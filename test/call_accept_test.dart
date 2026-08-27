import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:monkeyhub/backend/call_api.dart';
import 'package:monkeyhub/backend/convex_client.dart';
import 'package:monkeyhub/calls/call_models.dart';
import 'package:monkeyhub/calls/call_service.dart';

import 'fakes/fake_webrtc.dart';

/// The "rings but can't answer" regression suite. Every test pins one of the
/// accept-path fixes: backend claim ordered BEFORE the media/SDP work (so a
/// late-in-ring tap doesn't miss the 30s window), a lost accept race tearing
/// down LOCALLY instead of ending the winner's row, and the clock-skew stale
/// gate never dropping a signal for a call the user already accepted natively.
/// The WebRTC boundary is faked through `getUserMediaFn`/`createPcFn`; the
/// backend through a recording [_FakeAcceptApi].

class _FakeSubscription extends Fake implements Subscription {
  @override
  void cancel() {}
}

class _FakeAcceptApi extends Fake implements CallApi {
  /// Ordered log of backend calls the accept path makes, so a test can prove
  /// `acceptCall` runs before the `answer` signal (and that a lost race never
  /// fires `end`).
  final List<String> events = [];

  /// What `acceptCall` returns — 'accepted' (default) or 'not-ringing'.
  String acceptDisposition = 'accepted';

  @override
  Future<String?> acceptCall({
    required String callId,
    required String userId,
    String? acceptingDeviceId,
  }) async {
    events.add('accept');
    return acceptDisposition;
  }

  @override
  Future<void> sendCallSignal({
    required String callId,
    required String fromUserId,
    required String toUserId,
    required String kind,
    required String payload,
    String? fromDeviceId,
    String? targetDeviceId,
  }) async {
    events.add('signal:$kind');
  }

  @override
  Future<String?> endCall({required String callId, required String userId}) async {
    events.add('end');
    return 'ended';
  }

  @override
  Future<String?> cancelCall(
      {required String callId, required String userId}) async {
    events.add('cancel');
    return 'cancelled';
  }

  @override
  Future<String?> rejectCall({
    required String callId,
    required String userId,
    String? acceptingDeviceId,
  }) async {
    events.add('reject');
    return 'rejected';
  }

  @override
  Future<List<Map<String, dynamic>>> getIceConfig(String userId) async =>
      const [];

  @override
  Future<Subscription> subscribeActiveCall({
    required String userId,
    required void Function(Map<String, dynamic>? call) onCall,
    void Function(Object error)? onError,
  }) async =>
      _FakeSubscription();
}

Future<void> _pump([int rounds = 12]) async {
  for (var i = 0; i < rounds; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

CallService _newService(_FakeAcceptApi api) {
  final service = CallService(api: api)
    ..teardownUiHold = Duration.zero
    ..endNativeTimeout = const Duration(milliseconds: 20);
  service.attach(userId: 'me', displayName: 'Me', deviceId: 'dev1');
  service.getUserMediaFn = (kind, {tier = VideoQualityTier.auto}) async =>
      FakeMediaStream([FakeMediaStreamTrack(kind: 'audio')]);
  service.createPcFn = (config, constraints) async => FakePeerConnection();
  return service;
}

Map<String, dynamic> _offer(String callId, {int? createdAt}) => {
      '_id': 'offer-$callId',
      'callId': callId,
      'fromUserId': 'peer',
      'kind': 'offer',
      'payload': jsonEncode({
        'sdp': 'v=0 fake',
        'type': 'offer',
        'mediaKind': 'audio',
      }),
      'createdAt': createdAt ?? DateTime.now().millisecondsSinceEpoch,
    };

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('CallService.acceptIncoming', () {
    test('claims the call on the backend BEFORE sending the answer', () async {
      final api = _FakeAcceptApi();
      final service = _newService(api);
      addTearDown(service.dispose);

      // Offer arrives → session hydrates with a live PC, status ringing.
      await service.handleRemoteSignal(_offer('call1'));
      await _pump();
      expect(service.session?.status, CallStatus.incomingRinging);

      await service.acceptIncoming();
      await _pump();

      // The backend claim is first, the answer signal second — the whole point
      // of the reorder, so a tap late in the 30s ring window can't miss it.
      expect(api.events, ['accept', 'signal:answer']);
      expect(service.session?.status, CallStatus.connecting);
    });

    test(
        "a lost accept race ('not-ringing') tears down locally and never "
        'ends the backend row', () async {
      final api = _FakeAcceptApi()..acceptDisposition = 'not-ringing';
      final service = _newService(api);
      addTearDown(service.dispose);

      await service.handleRemoteSignal(_offer('call1'));
      await _pump();
      expect(service.session?.status, CallStatus.incomingRinging);

      await service.acceptIncoming();
      await _pump();

      // Only the accept mutation ran. Crucially NO 'end' — a sibling device
      // that just won the accept flipped the row to `active`, and a stray
      // `end` here would hang up its live call.
      expect(api.events, ['accept']);
      expect(api.events, isNot(contains('end')));
      // Local teardown still happened — the session is gone, no zombie.
      expect(service.session, isNull);
    });

    test('is re-entrancy safe — a second concurrent accept is a no-op',
        () async {
      final api = _FakeAcceptApi();
      final service = _newService(api);
      addTearDown(service.dispose);

      await service.handleRemoteSignal(_offer('call1'));
      await _pump();

      // Fire two accepts without awaiting the first — the CallKit-event +
      // resume-replay double-fire. Exactly one must reach the backend.
      final a = service.acceptIncoming();
      final b = service.acceptIncoming();
      await Future.wait([a, b]);
      await _pump();

      expect(api.events.where((e) => e == 'accept').length, 1);
      expect(service.session?.status, CallStatus.connecting);
    });
  });

  group('CallService stale-signal gate', () {
    test('drops a stale session-creating offer when nothing is latched',
        () async {
      final api = _FakeAcceptApi();
      final service = _newService(api);
      addTearDown(service.dispose);

      // 60s old, well past the 45s freshness window, no accept latched.
      final stale = DateTime.now().millisecondsSinceEpoch - 60 * 1000;
      await service.handleRemoteSignal(_offer('call1', createdAt: stale));
      await _pump();

      expect(service.session, isNull, reason: 'stale offer must be dropped');
    });

    test(
        'hydrates a stale offer when the user already accepted it natively '
        '(clock-skew bypass)', () async {
      final api = _FakeAcceptApi();
      final service = _newService(api);
      addTearDown(service.dispose);

      // The exact clock-skew case: the device clock is minutes ahead, so the
      // server-stamped offer looks "stale", but the user tapped Accept on the
      // native CallKit/ConnectionService card — the latch proves the call is
      // real and the offer must hydrate instead of being dropped.
      service.markAcceptedNatively(callId: 'call1');
      final stale = DateTime.now().millisecondsSinceEpoch - 5 * 60 * 1000;
      await service.handleRemoteSignal(_offer('call1', createdAt: stale));
      await _pump();

      // Session exists (hydrated), and the latched accept auto-fired through
      // to the backend — the call connects instead of ringing forever.
      expect(service.session, isNotNull);
      expect(api.events, contains('accept'));
    });
  });
}
