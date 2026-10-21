import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:monkeyhub/backend/call_api.dart';
import 'package:monkeyhub/backend/convex_client.dart';
import 'package:monkeyhub/calls/call_models.dart';
import 'package:monkeyhub/calls/call_service.dart';
import 'package:monkeyhub/calls/screen_share.dart';

import 'fakes/fake_webrtc.dart';

/// The slot model on a pair — see group_call_renegotiation_test.dart for
/// the mesh. The caller is the offerer; the callee adds its track and asks.
/// Every new signal goes to the peer's DEVICE, the way `state` does, so a
/// sibling device of theirs never sees an offer for a call it is not on.
class _FakeSubscription extends Fake implements Subscription {
  @override
  void cancel() {}
}

class _Sent {
  _Sent(this.kind, this.payload, this.targetDeviceId);
  final String kind;
  final Map<String, dynamic> payload;
  final String? targetDeviceId;
}

class _FakeCallApi extends Fake implements CallApi {
  final List<_Sent> sent = [];
  List<String> get kinds => [for (final s in sent) s.kind];

  @override
  Future<String> initiateCall({
    required String callerId,
    required String calleeId,
    required String roomId,
    required String type,
    String? callerDeviceId,
  }) async =>
      'call-1';

  @override
  Future<String?> acceptCall({
    required String callId,
    required String userId,
    String? acceptingDeviceId,
  }) async =>
      'accepted';

  @override
  Future<String?> cancelCall({required String callId, required String userId}) async =>
      'cancelled';

  @override
  Future<String?> endCall({required String callId, required String userId}) async =>
      'ended';

  @override
  Future<String?> rejectCall({
    required String callId,
    required String userId,
    String? acceptingDeviceId,
  }) async =>
      'rejected';

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
    sent.add(_Sent(
      kind,
      jsonDecode(payload) as Map<String, dynamic>,
      targetDeviceId,
    ));
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

int _sig = 0;

Map<String, dynamic> _signal(
  String callId,
  String kind,
  Map<String, dynamic> payload, {
  String fromDeviceId = 'peer-phone',
}) =>
    {
      '_id': 's${_sig++}',
      'callId': callId,
      'fromUserId': 'peer',
      'fromDeviceId': fromDeviceId,
      'kind': kind,
      'payload': jsonEncode(payload),
      'createdAt': DateTime.now().millisecondsSinceEpoch,
    };

Future<void> _pump() async {
  for (var i = 0; i < 4; i++) {
    await Future<void>.delayed(const Duration(milliseconds: 5));
  }
}

CallService _service(_FakeCallApi api, List<FakePeerConnection> pcs) {
  final service = CallService(api: api)
    ..terminalNotifyTimeout = const Duration(milliseconds: 20)
    ..terminalNotifyRetryDelay = const Duration(milliseconds: 1)
    ..teardownUiHold = Duration.zero
    ..endNativeTimeout = const Duration(milliseconds: 20);
  service.getUserMediaFn = (kind, {tier = VideoQualityTier.auto}) async =>
      FakeMediaStream([FakeMediaStreamTrack(kind: 'audio')], id: 'ls-me');
  service.createPcFn = (config, constraints) async {
    final pc = FakePeerConnection();
    pcs.add(pc);
    return pc;
  };
  service.ensurePermissionsFn = (_) async => true;
  service.getVideoTrackFn = (_) async =>
      FakeMediaStreamTrack(kind: 'video', id: 'cam-me');
  service.createLocalStreamFn = (label) async => FakeMediaStream([], id: label);
  service.getDisplayMediaFn = ({source}) async =>
      FakeMediaStream([FakeMediaStreamTrack(kind: 'video', id: 'scr-me')]);
  service.attach(userId: 'me', displayName: 'Me', deviceId: 'my-phone');
  addTearDown(() async {
    if (service.inCall) await service.endCall();
    await _pump();
    service.dispose();
  });
  return service;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  ScreenShare.invokeFn = (m, [a]) async => null;

  test('the caller brings a camera on in a voice call with one re-offer',
      () async {
    final api = _FakeCallApi();
    final pcs = <FakePeerConnection>[];
    final svc = _service(api, pcs);
    await svc.initiate(
      peerUserId: 'peer',
      peerName: 'Peer',
      roomId: 'room1',
      kind: CallMediaKind.audio,
    );
    await _pump();
    final pc = pcs.single;
    final callId = svc.session!.callId;
    // A voice call still offers a video section, and the draw channel.
    expect(pc.offerConstraints.single!['offerToReceiveVideo'], isTrue);
    expect(pc.dataChannels.map((c) => c.label), ['draw']);
    expect(api.kinds, ['offer']);

    await svc.handleRemoteSignal(
      _signal(callId, 'answer', {'sdp': 'v=0', 'type': 'answer'}),
    );
    await _pump();
    expect(pc.signalingState, RTCSignalingState.RTCSignalingStateStable);
    expect(svc.hasAnyVideo, isFalse);

    await svc.toggleVideo();
    await _pump();
    expect(svc.localCamActive, isTrue);
    expect(svc.session!.localVideoOff, isFalse);
    expect(svc.hasAnyVideo, isTrue);
    expect(api.kinds.sublist(1), ['state', 'reoffer']);
    // Addressed to the device on the call, like every other live signal.
    expect(api.sent.last.targetDeviceId, 'peer-phone');
    final round = api.sent.last.payload['seq'] as int;
    expect(pc.addedTracks.map((t) => t.id), contains('cam-me'));

    await svc.handleRemoteSignal(_signal(
      callId,
      'reanswer',
      {'sdp': 'v=0', 'type': 'answer', 'seq': round},
    ));
    await _pump();
    expect(pc.remoteDescriptions.last.type, 'answer');
    expect(pc.signalingState, RTCSignalingState.RTCSignalingStateStable);

    // Off: the slot is emptied, the camera released, nothing renegotiated.
    final camSender = pc.fakeTransceivers
        .firstWhere((t) => t.sender.track?.id == 'cam-me')
        .sender;
    final offers = pc.localDescriptions.length;
    await svc.toggleVideo();
    await _pump();
    expect(svc.session!.localVideoOff, isTrue);
    expect(camSender.replaced, [null]);
    expect(svc.localStream!.getVideoTracks(), isEmpty);
    expect(pc.localDescriptions, hasLength(offers));
  });

  test('the callee adds its screen and asks the caller for a round', () async {
    final api = _FakeCallApi();
    final pcs = <FakePeerConnection>[];
    final svc = _service(api, pcs);
    await svc.handleRemoteSignal(_signal('call-9', 'invite', {
      'callerName': 'Peer',
      'type': 'audio',
      'roomId': 'room1',
    }));
    await svc.handleRemoteSignal(_signal('call-9', 'offer', {
      'sdp': 'v=0',
      'type': 'offer',
      'mediaKind': 'audio',
    }));
    await _pump();
    expect(svc.session?.status, CallStatus.incomingRinging);
    await svc.acceptIncoming();
    await _pump();
    expect(api.kinds, contains('answer'));
    final pc = pcs.single;

    await svc.startScreenShare();
    await _pump();
    expect(svc.localScreenSharing, isTrue);
    expect(svc.session!.localScreenSharing, isTrue);
    expect(pc.addedTracks.map((t) => t.id), contains('scr-me'));
    final after = api.kinds.indexOf('answer') + 1;
    expect(api.kinds.sublist(after), ['state', 'renegotiate']);
    expect(api.sent[after].payload['screenSharing'], isTrue);
    expect(api.sent[after].payload['screenStreamId'], 'screen-me');
    expect(api.sent.last.payload['videoSlots'], 1);

    await svc.handleRemoteSignal(_signal(
      'call-9',
      'reoffer',
      {'sdp': 'v=0', 'type': 'offer', 'seq': 3},
    ));
    await _pump();
    expect(api.sent.last.kind, 'reanswer');
    expect(api.sent.last.payload['seq'], 3);
    expect(pc.localDescriptions.last.type, 'answer');

    await svc.stopScreenShare();
    await _pump();
    expect(svc.localScreenSharing, isFalse);
    expect(api.sent.last.kind, 'state');
    expect(api.sent.last.payload['screenSharing'], isFalse);
  });

  test("the peer's screen is filed apart from its camera", () async {
    final api = _FakeCallApi();
    final pcs = <FakePeerConnection>[];
    final svc = _service(api, pcs);
    await svc.initiate(
      peerUserId: 'peer',
      peerName: 'Peer',
      roomId: 'room1',
      kind: CallMediaKind.audio,
    );
    await _pump();
    final pc = pcs.single;
    final callId = svc.session!.callId;
    final cam = FakeMediaStream(
      [FakeMediaStreamTrack(kind: 'audio', id: 'p-mic')],
      id: 'ls-peer',
    );
    pc.onTrack!(RTCTrackEvent(streams: [cam], track: cam.getAudioTracks().single));
    expect(svc.remoteStream?.id, 'ls-peer');
    expect(svc.remoteScreenStream, isNull);

    await svc.handleRemoteSignal(_signal(callId, 'state', {
      'screenSharing': true,
      'camStreamId': 'ls-peer',
      'screenStreamId': 'screen-peer',
      'ts': 1,
    }));
    final screen = FakeMediaStream(
      [FakeMediaStreamTrack(kind: 'video', id: 'p-scr')],
      id: 'screen-peer',
    );
    final tick = svc.remoteScreenStreamTick;
    pc.onTrack!(RTCTrackEvent(
      streams: [screen],
      track: screen.getVideoTracks().single,
    ));
    expect(svc.remoteStream?.id, 'ls-peer');
    expect(svc.remoteScreenStream?.id, 'screen-peer');
    expect(svc.remoteScreenStreamTick, tick + 1);
    expect(svc.hasAnyVideo, isTrue);

    await svc.handleRemoteSignal(_signal(callId, 'state', {
      'screenSharing': false,
      'camStreamId': 'ls-peer',
      'ts': 2,
    }));
    expect(svc.remoteScreenStream, isNull);
    expect(svc.hasAnyVideo, isFalse);
  });
}
