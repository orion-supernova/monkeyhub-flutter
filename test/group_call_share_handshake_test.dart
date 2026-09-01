import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:monkeyhub/backend/convex_client.dart';
import 'package:monkeyhub/backend/group_call_api.dart';
import 'package:monkeyhub/calls/call_models.dart';
import 'package:monkeyhub/calls/group_call_service.dart';
import 'package:monkeyhub/calls/screen_share.dart';
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
  }) async {}

  @override
  Future<Subscription> subscribeSignals({
    required String userId,
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

/// [me] on the call with the other one, link built.
Future<FakePeerConnection> _linked(
  GroupCallService service,
  _FakeGroupApi api,
  List<FakePeerConnection> pcs,
) async {
  await service.joinCall('gc1');
  await _pump();
  api.roster!(_roster(['a', 'b']));
  await _pump();
  expect(pcs, hasLength(1));
  return pcs.single;
}


// What a share does between the system picker appearing and the platform
// saying the broadcast is on the air (iOS — see
// ScreenShare.needsStartHandshake), and when the platform ends it from
// outside the app. Before the handshake a share was announced the moment
// the picker was presented: every peer went to a black stage while the
// presenter read a countdown, and stayed there if the sheet was dismissed;
// and a broadcast ended from the status bar left the app "sharing" forever.

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    ScreenShare.startHandshakeOverride = true;
  });
  tearDown(() {
    ScreenShare.startHandshakeOverride = null;
    ScreenShare.cancelStartWait();
    ScreenShare.onPlatformStop = null;
  });

  Future<GroupCallService> onCall(
    _FakeGroupApi api,
    List<FakePeerConnection> pcs,
  ) async {
    final a = _service(api, 'a', pcs);
    await _linked(a, api, pcs);
    await _deliver(api, from: 'b', kind: 'answer',
        payload: {'sdp': 'v=0', 'type': 'answer'});
    return a;
  }

  group('the broadcast handshake', () {
    test('nobody hears about a share until the broadcast has started',
        () async {
      final api = _FakeGroupApi();
      final pcs = <FakePeerConnection>[];
      final a = await onCall(api, pcs)
        ..startHandshakeTimeout = const Duration(seconds: 5);
      final pc = pcs.single;
      final before = api.sent.length;

      final share = a.startScreenShare();
      await _pump();
      expect(a.screenSharePending, isTrue);
      expect(a.localScreenSharing, isFalse);
      expect(api.sent.length, before, reason: 'not a word to the peer yet');
      expect(pc.addedTracks.map((t) => t.id), isNot(contains('scr-a')));

      ScreenShare.reportPlatformStart();
      await share;
      await _pump();
      expect(a.screenSharePending, isFalse);
      expect(a.localScreenSharing, isTrue);
      expect(api.kindsTo('b').skip(before).toList(), ['state', 'reoffer']);
      expect(api.sent[before].payload['screenSharing'], isTrue);
      expect(pc.addedTracks.map((t) => t.id), contains('scr-a'));
    });

    test('a broadcast that never starts is rolled back without a word',
        () async {
      final api = _FakeGroupApi();
      final pcs = <FakePeerConnection>[];
      final a = await onCall(api, pcs)
        ..startHandshakeTimeout = const Duration(milliseconds: 60);
      final track = FakeMediaStreamTrack(kind: 'video', id: 'scr-a');
      final captured = FakeMediaStream([track]);
      a.getDisplayMediaFn = ({source}) async => captured;
      final before = api.sent.length;

      await a.startScreenShare();
      await _pump();
      expect(a.screenSharePending, isFalse);
      expect(a.localScreenSharing, isFalse);
      expect(api.sent.length, before);
      expect(track.stopped, isTrue);
      expect(captured.disposed, isTrue);
      expect(pcs.single.addedTracks.map((t) => t.id),
          isNot(contains('scr-a')));
    });

    test('leaving the call ends the wait and releases the capture',
        () async {
      final api = _FakeGroupApi();
      final pcs = <FakePeerConnection>[];
      final a = await onCall(api, pcs)
        ..startHandshakeTimeout = const Duration(seconds: 5);
      final track = FakeMediaStreamTrack(kind: 'video', id: 'scr-a');
      a.getDisplayMediaFn = ({source}) async => FakeMediaStream([track]);

      final share = a.startScreenShare();
      await _pump();
      expect(a.screenSharePending, isTrue);

      await a.leaveCall();
      await share;
      await _pump();
      expect(a.screenSharePending, isFalse);
      expect(a.localScreenSharing, isFalse);
      expect(track.stopped, isTrue);
    });

    test('a second tap while the first share is still pending is ignored',
        () async {
      final api = _FakeGroupApi();
      final pcs = <FakePeerConnection>[];
      final a = await onCall(api, pcs)
        ..startHandshakeTimeout = const Duration(seconds: 5);
      var captures = 0;
      a.getDisplayMediaFn = ({source}) async {
        captures++;
        return FakeMediaStream(
            [FakeMediaStreamTrack(kind: 'video', id: 'scr-a')]);
      };
      final first = a.startScreenShare();
      await _pump();
      await a.startScreenShare();
      expect(captures, 1);
      ScreenShare.reportPlatformStart();
      await first;
      expect(a.localScreenSharing, isTrue);
    });
  });

  group('the platform ending the share', () {
    test('a broadcast stopped from outside the app ends the share',
        () async {
      ScreenShare.startHandshakeOverride = false;
      final api = _FakeGroupApi();
      final pcs = <FakePeerConnection>[];
      final a = await onCall(api, pcs);

      await a.startScreenShare();
      await _pump();
      expect(a.localScreenSharing, isTrue);

      ScreenShare.reportPlatformStop();
      await _pump();
      expect(a.localScreenSharing, isFalse);
      expect(api.sent.last.kind, 'state');
      expect(api.sent.last.payload['screenSharing'], isFalse);
    });
  });
}
