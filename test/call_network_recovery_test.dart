import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:monkeyhub/backend/call_api.dart';
import 'package:monkeyhub/backend/convex_client.dart';
import 'package:monkeyhub/backend/signaling_status.dart';
import 'package:monkeyhub/calls/call_models.dart';
import 'package:monkeyhub/calls/call_recovery.dart';
import 'package:monkeyhub/calls/call_service.dart';
import 'package:monkeyhub/calls/screen_share.dart';

import 'fakes/fake_webrtc.dart';

/// 1:1 call recovery across a network change (Wi-Fi ↔ cellular).
///
/// The restart has to ride a signaling socket that is being rebuilt at the
/// same moment, so these pin: a restart goes out on the network change itself,
/// another the moment signaling is verified back, and a late answer to a
/// superseded restart offer is never applied.
class _FakeSubscription extends Fake implements Subscription {
  @override
  void cancel() {}
}

class _Sent {
  _Sent(this.kind, this.payload);
  final String kind;
  final Map<String, dynamic> payload;
}

class _FakeCallApi extends Fake implements CallApi {
  final List<_Sent> sent = [];
  List<String> get kinds => [for (final s in sent) s.kind];
  Iterable<_Sent> of(String kind) => sent.where((s) => s.kind == kind);

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
    sent.add(_Sent(kind, jsonDecode(payload) as Map<String, dynamic>));
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
  Map<String, dynamic> payload,
) =>
    {
      '_id': 'n${_sig++}',
      'callId': callId,
      'fromUserId': 'peer',
      'fromDeviceId': 'peer-phone',
      'kind': kind,
      'payload': jsonEncode(payload),
      'createdAt': DateTime.now().millisecondsSinceEpoch,
    };

Future<void> _pump() async {
  for (var i = 0; i < 4; i++) {
    await Future<void>.delayed(const Duration(milliseconds: 5));
  }
}

CallService _service(
  _FakeCallApi api,
  List<FakePeerConnection> pcs,
  List<Map<String, dynamic>> configs,
  SignalingStatus signaling,
) {
  final service = CallService(api: api, signaling: signaling)
    ..terminalNotifyTimeout = const Duration(milliseconds: 20)
    ..terminalNotifyRetryDelay = const Duration(milliseconds: 1)
    ..teardownUiHold = Duration.zero
    ..endNativeTimeout = const Duration(milliseconds: 20);
  service.getUserMediaFn = (kind, {tier = VideoQualityTier.auto}) async =>
      FakeMediaStream([FakeMediaStreamTrack(kind: 'audio')], id: 'ls-me');
  service.createPcFn = (config, constraints) async {
    configs.add(config);
    final pc = FakePeerConnection();
    pcs.add(pc);
    return pc;
  };
  service.ensurePermissionsFn = (_) async => true;
  service.createLocalStreamFn = (label) async => FakeMediaStream([], id: label);
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

  late _FakeCallApi api;
  late List<FakePeerConnection> pcs;
  late List<Map<String, dynamic>> configs;
  late SignalingStatus signaling;

  setUp(() {
    api = _FakeCallApi();
    pcs = [];
    configs = [];
    signaling = SignalingStatus();
  });

  /// An outgoing voice call, answered, as the caller (the restarter).
  Future<CallService> callerInCall() async {
    final svc = _service(api, pcs, configs, signaling);
    await svc.initiate(
      peerUserId: 'peer',
      peerName: 'Peer',
      roomId: 'room1',
      kind: CallMediaKind.audio,
    );
    await _pump();
    await svc.handleRemoteSignal(
      _signal(svc.session!.callId, 'answer', {'sdp': 'v=0', 'type': 'answer'}),
    );
    await _pump();
    return svc;
  }

  test('peer connections keep gathering across network changes', () async {
    await callerInCall();
    expect(configs.single['continualGatheringPolicy'], kIceGatheringPolicy);
    expect(kIceGatheringPolicy, 'gather_continually');
  });

  test('a network change restarts ICE at once, without a "reconnecting" chip',
      () async {
    final svc = await callerInCall();

    signaling.noteNetworkChanged();
    await _pump();

    final restart = api.of('restart-offer');
    expect(restart, hasLength(1));
    expect(restart.single.payload['seq'], isA<int>());
    expect(pcs.single.offerConstraints.last, {'iceRestart': true});
    expect(
      svc.session!.reconnecting,
      isFalse,
      reason: 'the link may be fine (cellular → Wi-Fi); ICE says so if not',
    );
  });

  test('signaling coming back restarts a reconnecting call immediately',
      () async {
    final svc = await callerInCall();
    final pc = pcs.single;

    // The link drops: the restart waits out its 2s debounce.
    pc.onConnectionState!(
      RTCPeerConnectionState.RTCPeerConnectionStateDisconnected,
    );
    await _pump();
    expect(svc.session!.reconnecting, isTrue);
    expect(api.of('restart-offer'), isEmpty);

    // Our own socket was down and is verified back: go now, not later.
    signaling.markDown();
    signaling.markUp();
    await _pump();

    expect(api.of('restart-offer'), hasLength(1));
  });

  test('a late answer to a superseded restart offer is dropped', () async {
    final svc = await callerInCall();
    final pc = pcs.single;
    final callId = svc.session!.callId;

    signaling.noteNetworkChanged();
    await _pump();
    signaling.noteNetworkChanged();
    await _pump();
    final offers = api.of('restart-offer').toList();
    expect(offers, hasLength(2));
    final stale = offers.first.payload['seq'] as int;
    final current = offers.last.payload['seq'] as int;
    expect(current, greaterThan(stale));

    final applied = pc.remoteDescriptions.length;
    await svc.handleRemoteSignal(_signal(callId, 'restart-answer', {
      'sdp': 'v=0 old-ufrag',
      'type': 'answer',
      'seq': stale,
    }));
    await _pump();
    expect(pc.remoteDescriptions, hasLength(applied));
    expect(
      pc.signalingState,
      RTCSignalingState.RTCSignalingStateHaveLocalOffer,
      reason: 'the current round is still waiting for its own answer',
    );

    await svc.handleRemoteSignal(_signal(callId, 'restart-answer', {
      'sdp': 'v=0 new-ufrag',
      'type': 'answer',
      'seq': current,
    }));
    await _pump();
    expect(pc.remoteDescriptions.last.sdp, 'v=0 new-ufrag');
    expect(pc.signalingState, RTCSignalingState.RTCSignalingStateStable);
  });

  test('an untagged restart answer (older peer build) still applies', () async {
    final svc = await callerInCall();
    final pc = pcs.single;

    signaling.noteNetworkChanged();
    await _pump();
    await svc.handleRemoteSignal(_signal(svc.session!.callId, 'restart-answer', {
      'sdp': 'v=0 legacy',
      'type': 'answer',
    }));
    await _pump();
    expect(pc.remoteDescriptions.last.sdp, 'v=0 legacy');
  });

  test('the callee asks for a restart on a network change, and echoes seq',
      () async {
    final svc = _service(api, pcs, configs, signaling);
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
    await svc.acceptIncoming();
    await _pump();

    signaling.noteNetworkChanged();
    await _pump();
    expect(api.of('restart-request'), hasLength(1));

    await svc.handleRemoteSignal(_signal('call-9', 'restart-offer', {
      'sdp': 'v=0 restart',
      'type': 'offer',
      'seq': 7,
    }));
    await _pump();
    expect(api.sent.last.kind, 'restart-answer');
    expect(api.sent.last.payload['seq'], 7);
  });
}
