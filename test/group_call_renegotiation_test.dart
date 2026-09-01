import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:monkeyhub/backend/convex_client.dart';
import 'package:monkeyhub/backend/group_call_api.dart';
import 'package:monkeyhub/calls/call_models.dart';
import 'package:monkeyhub/calls/group_call_service.dart';
import 'package:monkeyhub/calls/screen_share.dart';

import 'fakes/fake_webrtc.dart';

/// A camera coming on in a voice call, and a screen joining any call.
///
/// Neither was possible: a voice call had no video section and no way to add
/// one, and a screen was a second video track a link that assumed one could
/// not tell from the first. These pin the slot model in `renegotiation.dart`
/// on the mesh: only the designated offerer offers, the answering side adds
/// its track and ASKS, rounds are serialised per link and numbered, and the
/// peer's two streams are told apart by the ids its `state` names.
///
/// Real async rather than `fakeAsync`: the plugin's missing channels answer
/// on real timers once a binding is up, and `_ensureLink` waits on one
/// (`preferH264Codec`) before it offers.
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

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  // The share flow talks to the platform through this seam; nothing here
  // needs an Android service or a real capture.
  ScreenShare.invokeFn = (m, [a]) async => null;

  group('the offerer', () {
    test('offers a video section on a voice call, and the draw channel',
        () async {
      final api = _FakeGroupApi();
      final pcs = <FakePeerConnection>[];
      final a = _service(api, 'a', pcs);
      final pc = await _linked(a, api, pcs);

      expect(pc.offerConstraints.single!['offerToReceiveVideo'], isTrue);
      // Our state — with the ids that tell our streams apart — goes BEFORE
      // the offer that carries them.
      expect(api.kindsTo('b'), ['state', 'offer']);
      expect(api.sent.first.payload['camStreamId'], 'ls-a');
      // The channel the drawings ride rides the first offer.
      expect(pc.dataChannels.map((c) => c.label), ['draw']);
    });

    test('brings a camera on with one re-offer, serialised and numbered',
        () async {
      final api = _FakeGroupApi();
      final pcs = <FakePeerConnection>[];
      final a = _service(api, 'a', pcs);
      final pc = await _linked(a, api, pcs);
      await _deliver(api, from: 'b', kind: 'answer',
          payload: {'sdp': 'v=0', 'type': 'answer'});
      expect(pc.signalingState, RTCSignalingState.RTCSignalingStateStable);
      expect(a.hasAnyVideo, isFalse);

      await a.toggleVideo();
      await _pump();

      expect(a.localVideoOff, isFalse);
      expect(a.localCamActive, isTrue);
      expect(a.hasAnyVideo, isTrue);
      expect(pc.addedTracks.map((t) => t.id), contains('cam-a'));
      expect(api.kindsTo('b').sublist(2), ['state', 'reoffer']);
      // Rounds are numbered across the link's life: the first offer was
      // round 1, so the camera's is 2.
      final camRound = api.sent.last.payload['seq'] as int;
      expect(camRound, 2);
      expect(pc.localDescriptions.last.type, 'offer');

      // A screen while the camera's offer is still out: queued, not sent.
      await a.startScreenShare();
      await _pump();
      expect(a.localScreenSharing, isTrue);
      expect(api.kindsTo('b').where((k) => k == 'reoffer'), hasLength(1));
      // ...but its state went out at once, naming the screen's stream.
      expect(api.sent.last.kind, 'state');
      expect(api.sent.last.payload['screenSharing'], isTrue);
      expect(api.sent.last.payload['screenStreamId'], 'screen-a');

      // The answer to the camera round lets the screen round go.
      await _deliver(api, from: 'b', kind: 'reanswer',
          payload: {'sdp': 'v=0', 'type': 'answer', 'seq': camRound});
      expect(api.sent.last.kind, 'reoffer');
      expect(api.sent.last.payload['seq'], camRound + 1);
      expect(pc.addedTracks.map((t) => t.id), contains('scr-a'));

      // A stale answer — to the round the screen superseded — is dropped.
      final applied = pc.remoteDescriptions.length;
      await _deliver(api, from: 'b', kind: 'reanswer',
          payload: {'sdp': 'v=0', 'type': 'answer', 'seq': camRound});
      expect(pc.remoteDescriptions, hasLength(applied));
      await _deliver(api, from: 'b', kind: 'reanswer',
          payload: {'sdp': 'v=0', 'type': 'answer', 'seq': camRound + 1});
      expect(pc.remoteDescriptions, hasLength(applied + 1));
      expect(pc.signalingState, RTCSignalingState.RTCSignalingStateStable);
    });

    test('switches a slot with replaceTrack once it exists', () async {
      final api = _FakeGroupApi();
      final pcs = <FakePeerConnection>[];
      final a = _service(api, 'a', pcs);
      final pc = await _linked(a, api, pcs);
      await _deliver(api, from: 'b', kind: 'answer',
          payload: {'sdp': 'v=0', 'type': 'answer'});
      await a.toggleVideo();
      await _pump();
      final camRound = api.sent.last.payload['seq'] as int;
      await _deliver(api, from: 'b', kind: 'reanswer',
          payload: {'sdp': 'v=0', 'type': 'answer', 'seq': camRound});
      final camSender = pc.fakeTransceivers
          .firstWhere((t) => t.sender.track?.id == 'cam-a')
          .sender;
      final offers = pc.localDescriptions.length;

      // Off: the sender is emptied, the camera released, no signaling.
      await a.toggleVideo();
      await _pump();
      expect(a.localVideoOff, isTrue);
      expect(camSender.replaced, [null]);
      expect(a.localStream!.getVideoTracks(), isEmpty);
      expect(pc.localDescriptions, hasLength(offers));
      expect(api.sent.last.kind, 'state');
      expect(api.sent.last.payload['videoOff'], isTrue);

      // On again: a fresh track into the same sender, still no offer.
      await a.toggleVideo();
      await _pump();
      expect(a.localVideoOff, isFalse);
      expect(camSender.replaced, hasLength(2));
      expect(camSender.replaced.last?.id, 'cam-a');
      expect(pc.localDescriptions, hasLength(offers));

      // The peer asks for room: an offerer honours it with recv sections.
      await _deliver(api, from: 'b', kind: 'renegotiate',
          payload: {'videoSlots': 2});
      expect(pc.localDescriptions, hasLength(offers + 1));
      expect(
        pc.fakeTransceivers.where((t) => t.kind == 'video').length,
        greaterThanOrEqualTo(2),
      );
    });
  });

  group('the answerer', () {
    test('adds its screen and asks for a round, then answers the re-offer',
        () async {
      final api = _FakeGroupApi();
      final pcs = <FakePeerConnection>[];
      final b = _service(api, 'b', pcs);
      final pc = await _linked(b, api, pcs);
      // No offer from the higher id — only its state.
      expect(api.kindsTo('a'), ['state']);
      await _deliver(api, from: 'a', kind: 'offer',
          payload: {'sdp': 'v=0', 'type': 'offer', 'mediaKind': 'audio'});
      expect(api.kindsTo('a'), ['state', 'answer']);

      await b.startScreenShare();
      await _pump();
      expect(b.localScreenSharing, isTrue);
      // The track is on the link already; the offerer is asked to make
      // room for it.
      expect(pc.addedTracks.map((t) => t.id), contains('scr-b'));
      expect(api.kindsTo('a').sublist(2), ['state', 'renegotiate']);
      expect(api.sent.last.payload['videoSlots'], 1);
      expect(pc.localDescriptions.last.type, 'answer');

      await _deliver(api, from: 'a', kind: 'reoffer',
          payload: {'sdp': 'v=0', 'type': 'offer', 'seq': 7});
      expect(api.sent.last.kind, 'reanswer');
      expect(api.sent.last.payload['seq'], 7);
      expect(pc.remoteDescriptions.last.type, 'offer');
      expect(pc.localDescriptions.last.type, 'answer');
    });
  });

  group("the peer's streams", () {
    test('are told apart by the ids its state names', () async {
      final api = _FakeGroupApi();
      final pcs = <FakePeerConnection>[];
      final a = _service(api, 'a', pcs);
      final pc = await _linked(a, api, pcs);
      final peer = a.peers['b']!;

      // The camera stream lands before any state: the one with audio in
      // it is taken for the camera.
      final cam = FakeMediaStream(
        [FakeMediaStreamTrack(kind: 'audio', id: 'b-mic')],
        id: 'ls-b',
      );
      pc.onTrack!(RTCTrackEvent(
        streams: [cam],
        track: cam.getAudioTracks().single,
      ));
      expect(peer.remoteStream?.id, 'ls-b');
      expect(peer.screenStream, isNull);
      expect(a.hasAnyVideo, isFalse);

      // A video track in that stream, with videoOff false: video is on.
      await _deliver(api, from: 'b', kind: 'state', payload: {
        'audioMuted': false,
        'videoOff': false,
        'camStreamId': 'ls-b',
        'ts': 1,
      });
      await cam.addTrack(FakeMediaStreamTrack(kind: 'video', id: 'b-cam'));
      final tick = peer.remoteStreamTick;
      pc.onTrack!(RTCTrackEvent(
        streams: [cam],
        track: cam.getVideoTracks().single,
      ));
      expect(peer.remoteStreamTick, tick + 1);
      expect(a.hasAnyVideo, isTrue);

      // The screen: named first, then it arrives, and it is filed as the
      // screen rather than clobbering the camera.
      await _deliver(api, from: 'b', kind: 'state', payload: {
        'audioMuted': false,
        'videoOff': false,
        'screenSharing': true,
        'camStreamId': 'ls-b',
        'screenStreamId': 'screen-b',
        'ts': 2,
      });
      final screen = FakeMediaStream(
        [FakeMediaStreamTrack(kind: 'video', id: 'b-scr')],
        id: 'screen-b',
      );
      pc.onTrack!(RTCTrackEvent(
        streams: [screen],
        track: screen.getVideoTracks().single,
      ));
      expect(peer.remoteStream?.id, 'ls-b');
      expect(peer.screenStream?.id, 'screen-b');
      expect(peer.screenStreamTick, 1);
      expect(a.presentingPeer?.userId, 'b');

      // Share over: the stream is let go on the flag alone.
      await _deliver(api, from: 'b', kind: 'state', payload: {
        'audioMuted': false,
        'videoOff': false,
        'screenSharing': false,
        'camStreamId': 'ls-b',
        'screenStreamId': 'screen-b',
        'ts': 3,
      });
      expect(peer.screenStream, isNull);
      expect(a.presentingPeer, isNull);
      expect(peer.remoteStream?.id, 'ls-b');
    });

    test('a screen that arrives before its state is sorted when it lands',
        () async {
      final api = _FakeGroupApi();
      final pcs = <FakePeerConnection>[];
      final a = _service(api, 'a', pcs);
      final pc = await _linked(a, api, pcs);
      final peer = a.peers['b']!;
      final cam = FakeMediaStream(
        [FakeMediaStreamTrack(kind: 'audio', id: 'b-mic')],
        id: 'ls-b',
      );
      final screen = FakeMediaStream(
        [FakeMediaStreamTrack(kind: 'video', id: 'b-scr')],
        id: 'screen-b',
      );
      pc.onTrack!(RTCTrackEvent(
        streams: [cam],
        track: cam.getAudioTracks().single,
      ));
      pc.onTrack!(RTCTrackEvent(
        streams: [screen],
        track: screen.getVideoTracks().single,
      ));
      // Unnamed, the audio-bearing stream is the camera and the other
      // waits in the pool.
      expect(peer.remoteStream?.id, 'ls-b');
      expect(peer.screenStream, isNull);
      await _deliver(api, from: 'b', kind: 'state', payload: {
        'screenSharing': true,
        'camStreamId': 'ls-b',
        'screenStreamId': 'screen-b',
        'ts': 1,
      });
      expect(peer.screenStream?.id, 'screen-b');
      expect(peer.remoteStream?.id, 'ls-b');
    });

    test('a screen that ended is never mistaken for a camera', () async {
      final api = _FakeGroupApi();
      final pcs = <FakePeerConnection>[];
      final a = _service(api, 'a', pcs);
      final pc = await _linked(a, api, pcs);
      final peer = a.peers['b']!;
      // A peer with no camera stream at all — only its screen ever landed.
      await _deliver(api, from: 'b', kind: 'state', payload: {
        'screenSharing': true,
        'screenStreamId': 'screen-b',
        'ts': 1,
      });
      final screen = FakeMediaStream(
        [FakeMediaStreamTrack(kind: 'video', id: 'b-scr')],
        id: 'screen-b',
      );
      pc.onTrack!(RTCTrackEvent(
        streams: [screen],
        track: screen.getVideoTracks().single,
      ));
      expect(a.hasAnyVideo, isTrue);
      await _deliver(api, from: 'b', kind: 'state', payload: {
        'screenSharing': false,
        'ts': 2,
      });
      // The stream is still in the pool with a video track in it; the
      // fallback must not promote it to the camera.
      expect(peer.screenStream, isNull);
      expect(peer.remoteStream, isNull);
      expect(a.hasAnyVideo, isFalse);
    });
  });

  test('leaving releases the screen and the camera with the mic', () async {
    final api = _FakeGroupApi();
    final pcs = <FakePeerConnection>[];
    final a = _service(api, 'a', pcs);
    await _linked(a, api, pcs);
    await a.toggleVideo();
    await _pump();
    await a.startScreenShare();
    await _pump();
    final ls = a.localStream! as FakeMediaStream;
    final ss = a.screenStream! as FakeMediaStream;
    final cam = ls.getVideoTracks().single as FakeMediaStreamTrack;
    final scr = ss.getVideoTracks().single as FakeMediaStreamTrack;

    await a.leaveCall();
    await _pump();
    expect(a.inCall, isFalse);
    expect(a.localScreenSharing, isFalse);
    expect(ls.micReleased, isTrue);
    expect(cam.stopped, isTrue);
    expect(scr.stopped, isTrue);
    expect(ss.disposed, isTrue);
    expect(a.screenStream, isNull);
  });
}
