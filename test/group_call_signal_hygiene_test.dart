import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:monkeyhub/backend/convex_client.dart';
import 'package:monkeyhub/backend/group_call_api.dart';
import 'package:monkeyhub/calls/call_models.dart';
import 'package:monkeyhub/calls/group_call_service.dart';
import 'fakes/fake_webrtc.dart';

// The fakes and helpers below are the ones test/group_call_renegotiation_test.dart
// builds a live mesh with, copied so this file can stand on its own.

class _FakeSubscription extends Fake implements Subscription {
  @override
  void cancel() {}
}

class _Sent {
  _Sent(this.to, this.kind, this.payload);
  final String to;
  final String kind;
  final Map<String, dynamic> payload;
}

class _FakeGroupApi extends Fake implements GroupCallApi {
  final List<_Sent> sent = [];
  void Function(List<Map<String, dynamic>> signals)? onSignals;
  void Function(Map<String, dynamic>? roster)? roster;

  List<String> kindsTo(String peer) =>
      [for (final s in sent) if (s.to == peer) s.kind];

  @override
  Future<({String type, String roomId})> join({
    required String groupCallId,
    required String userId,
    String? deviceId,
  }) async =>
      (type: 'audio', roomId: 'room1');

  @override
  Future<void> leave({
    required String groupCallId,
    required String userId,
  }) async {}

  @override
  Future<String?> heartbeat({
    required String groupCallId,
    required String userId,
  }) async =>
      'ok';

  @override
  Future<void> sendSignal({
    required String groupCallId,
    required String fromUserId,
    required String toUserId,
    required String kind,
    required String payload,
    String? fromDeviceId,
    String? targetDeviceId,
  }) async {
    targets.add(targetDeviceId);
    sent.add(_Sent(
      toUserId,
      kind,
      jsonDecode(payload) as Map<String, dynamic>,
    ));
  }

  @override
  Future<void> consumeSignals({
    required List<String> signalIds,
    required String userId,
  }) async {
    consumed.addAll(signalIds);
  }

  final List<String> consumed = [];
  final List<String?> targets = [];

  @override
  Future<Subscription> subscribeSignals({
    required String userId,
    String? deviceId,
    required void Function(List<Map<String, dynamic>> signals) onSignals,
    void Function(Object error)? onError,
  }) async {
    this.onSignals = onSignals;
    return _FakeSubscription();
  }

  @override
  Future<Subscription> subscribeRoster({
    required String groupCallId,
    required String userId,
    required void Function(Map<String, dynamic>? roster) onRoster,
    void Function(Object error)? onError,
  }) async {
    roster = onRoster;
    return _FakeSubscription();
  }

  @override
  Future<Subscription> subscribePendingInvite({
    required String userId,
    required void Function(Map<String, dynamic>? invite) onInvite,
    void Function(Object error)? onError,
  }) async =>
      _FakeSubscription();
}

int _sig = 0;

/// Lets the service's chained awaits — and the plugin's missing-channel
/// replies, which land on real timers — run to a rest.
Future<void> _pump() async {
  for (var i = 0; i < 4; i++) {
    await Future<void>.delayed(const Duration(milliseconds: 5));
  }
}

/// Delivers one signal from [from] the way the subscription would.
Future<void> _deliver(
  _FakeGroupApi api, {
  required String from,
  required String kind,
  Map<String, dynamic> payload = const {},
}) async {
  api.onSignals!([
    {
      '_id': 's${_sig++}',
      'kind': kind,
      'fromUserId': from,
      'groupCallId': 'gc1',
      'payload': jsonEncode(payload),
    },
  ]);
  await _pump();
}

Map<String, dynamic> _roster(List<String> joined) => {
      'groupCallId': 'gc1',
      'status': 'active',
      'roomName': 'crew',
      'participants': [
        for (final id in joined)
          {'userId': id, 'status': 'joined', 'name': id.toUpperCase()},
      ],
    };

/// A service for [me] on a voice call, with the platform seams pointed at
/// fakes and one [FakePeerConnection] per link handed back through [pcs].
GroupCallService _service(
  _FakeGroupApi api,
  String me,
  List<FakePeerConnection> pcs,
) {
  final service = GroupCallService(api: api)
    ..leaveNotifyTimeout = const Duration(milliseconds: 20)
    ..nativeCardsEnabled = false;
  service.getUserMediaFn = (kind, {tier = VideoQualityTier.auto}) async =>
      FakeMediaStream([FakeMediaStreamTrack(kind: 'audio')], id: 'ls-$me');
  service.createPcFn = (config, constraints) async {
    final pc = FakePeerConnection();
    pcs.add(pc);
    return pc;
  };
  service.ensurePermissionsFn = (_) async => true;
  service.getVideoTrackFn = (_) async =>
      FakeMediaStreamTrack(kind: 'video', id: 'cam-$me');
  service.createLocalStreamFn = (label) async => FakeMediaStream([], id: label);
  service.getDisplayMediaFn = ({source}) async =>
      FakeMediaStream([FakeMediaStreamTrack(kind: 'video', id: 'scr-$me')]);
  service.attach(userId: me, deviceId: 'dev-$me');
  addTearDown(() async {
    if (service.inCall) await service.leaveCall();
    service.dispose();
  });
  return service;
}


// The signal path's hygiene, pinned against the ways a group share could
// reach the presenter's own screen and never the peer's:
//
//   * a round nobody answered (a restart offer that failed after begin(),
//     an answer lost) used to hold every later round hostage — no camera,
//     no screen, ever again on that link;
//   * a signal addressed to another device of the same user used to be
//     dropped AND consumed by whichever device saw it first;
//   * a share announced by `state` whose stream never landed had nothing
//     left to ask for it.

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<GroupCallService> onCall(
    _FakeGroupApi api,
    String me,
    List<FakePeerConnection> pcs,
  ) async {
    final svc = _service(api, me, pcs);
    await svc.joinCall('gc1');
    await _pump();
    api.roster!(_roster(['a', 'b']));
    await _pump();
    return svc;
  }

  group('a round nobody answered', () {
    test('does not starve the next one', () async {
      final api = _FakeGroupApi();
      final pcs = <FakePeerConnection>[];
      final a = await onCall(api, 'a', pcs);
      // The initial offer is out; pretend its answer never came and time
      // has passed.
      final neg = a.peers['b']!.negotiation;
      expect(neg.inFlight, isTrue);
      neg.since = DateTime.now().subtract(const Duration(seconds: 30));
      expect(neg.stuck, isTrue);

      await a.toggleVideo();
      await _pump();
      expect(api.kindsTo('b'), contains('reoffer'));
      expect(neg.inFlight, isTrue);
      expect(neg.stuck, isFalse, reason: 'a fresh round, freshly timed');
    });

    test('a round that is merely young still queues behind itself',
        () async {
      final api = _FakeGroupApi();
      final pcs = <FakePeerConnection>[];
      final a = await onCall(api, 'a', pcs);
      await a.toggleVideo();
      await _pump();
      expect(api.kindsTo('b').where((k) => k == 'reoffer'), isEmpty);
      expect(a.peers['b']!.negotiation.dirty, isTrue);
    });
  });

  group('signals that are not this device\'s', () {
    test('one addressed to a sibling device is neither handled nor consumed',
        () async {
      final api = _FakeGroupApi();
      final pcs = <FakePeerConnection>[];
      final a = await onCall(api, 'a', pcs);
      api.onSignals!([
        {
          '_id': 'sib-1',
          'kind': 'state',
          'fromUserId': 'b',
          'groupCallId': 'gc1',
          'targetDeviceId': 'dev-a-laptop',
          'payload': jsonEncode({'screenSharing': true, 'ts': 1}),
        },
      ]);
      await _pump();
      expect(a.peers['b']!.mediaState.screenSharing, isFalse);
      expect(api.consumed, isNot(contains('sib-1')));
    });

    test('one for a call this device is not in is left for the device that is',
        () async {
      final api = _FakeGroupApi();
      final pcs = <FakePeerConnection>[];
      final a = _service(api, 'a', pcs);
      api.onSignals!([
        {
          '_id': 'other-call-1',
          'kind': 'state',
          'fromUserId': 'b',
          'groupCallId': 'gc-elsewhere',
          'payload': jsonEncode({'screenSharing': true, 'ts': 1}),
        },
      ]);
      await _pump();
      expect(api.consumed, isEmpty);
      expect(a.inCall, isFalse);
    });

    test('ours are addressed to the device the roster names', () async {
      final api = _FakeGroupApi();
      final pcs = <FakePeerConnection>[];
      final a = _service(api, 'a', pcs);
      await a.joinCall('gc1');
      await _pump();
      api.roster!({
        'groupCallId': 'gc1',
        'status': 'active',
        'roomName': 'crew',
        'participants': [
          {'userId': 'a', 'status': 'joined', 'name': 'A'},
          {'userId': 'b', 'status': 'joined', 'name': 'B', 'deviceId': 'dev-b'},
        ],
      });
      await _pump();
      expect(api.sent, isNotEmpty);
      expect(api.targets.toSet(), {'dev-b'});
    });
  });

  group('a share announced but never delivered', () {
    test('is asked for again by the offerer', () async {
      final api = _FakeGroupApi();
      final pcs = <FakePeerConnection>[];
      final a = await onCall(api, 'a', pcs)
        ..screenWatchdogDelay = const Duration(milliseconds: 40);
      await _deliver(api, from: 'b', kind: 'answer',
          payload: {'sdp': 'v=0', 'type': 'answer'});
      final before = api.kindsTo('b').length;
      await _deliver(api, from: 'b', kind: 'state',
          payload: {'screenSharing': true, 'screenStreamId': 'never', 'ts': 5});
      expect(a.peers['b']!.mediaState.screenSharing, isTrue);
      expect(a.peers['b']!.screenStream, isNull);
      await Future<void>.delayed(const Duration(milliseconds: 120));
      await _pump();
      expect(api.kindsTo('b').skip(before), contains('reoffer'));
    });

    test('is asked for again by the answerer', () async {
      final api = _FakeGroupApi();
      final pcs = <FakePeerConnection>[];
      final b = await onCall(api, 'b', pcs)
        ..screenWatchdogDelay = const Duration(milliseconds: 40);
      await _deliver(api, from: 'a', kind: 'offer',
          payload: {'sdp': 'v=0', 'type': 'offer', 'mediaKind': 'audio'});
      expect(b.peers['a']!.pc, isNotNull);
      final before = api.kindsTo('a').length;
      await _deliver(api, from: 'a', kind: 'state',
          payload: {'screenSharing': true, 'screenStreamId': 'never', 'ts': 5});
      await Future<void>.delayed(const Duration(milliseconds: 120));
      await _pump();
      expect(api.kindsTo('a').skip(before), contains('renegotiate'));
    });

    test('is not asked for once the screen has landed', () async {
      final api = _FakeGroupApi();
      final pcs = <FakePeerConnection>[];
      final a = await onCall(api, 'a', pcs)
        ..screenWatchdogDelay = const Duration(milliseconds: 40);
      await _deliver(api, from: 'b', kind: 'answer',
          payload: {'sdp': 'v=0', 'type': 'answer'});
      final screen = FakeMediaStream(
        [FakeMediaStreamTrack(kind: 'video', id: 'b-scr')],
        id: 'scr-b',
      );
      pcs.single.onTrack!(RTCTrackEvent(
        receiver: null,
        streams: [screen],
        track: screen.getVideoTracks().single,
      ));
      await _pump();
      final before = api.kindsTo('b').length;
      await _deliver(api, from: 'b', kind: 'state',
          payload: {'screenSharing': true, 'screenStreamId': 'scr-b', 'ts': 5});
      expect(a.peers['b']!.screenStream, isNotNull);
      await Future<void>.delayed(const Duration(milliseconds: 120));
      await _pump();
      expect(api.kindsTo('b').skip(before), isEmpty);
    });
  });
}
