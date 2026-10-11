import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:monkeyhub/backend/call_api.dart';
import 'package:monkeyhub/backend/convex_client.dart';
import 'package:monkeyhub/backend/group_call_api.dart';
import 'package:monkeyhub/calls/call_media.dart';
import 'package:monkeyhub/calls/call_models.dart';
import 'package:monkeyhub/calls/call_service.dart';
import 'package:monkeyhub/calls/camera_health.dart';
import 'package:monkeyhub/calls/group_call_service.dart';
import 'package:monkeyhub/calls/native_call_handler.dart';
import 'package:monkeyhub/calls/screen_share.dart';

import 'fakes/fake_webrtc.dart';

/// The camera button tells the truth.
///
/// It read "on" while nothing was being captured: a second tap during the
/// camera's warm-up acquired a second camera (two capturers, the stream's
/// first track the orphan), a Darwin track taken out of its stream before
/// its stop never stopped its capture session, and nothing ever looked at
/// whether frames were coming out (iOS stops the camera in the background,
/// where a call answered from the lock screen acquires it). These pin the
/// serialized toggle, the release order, the frame watch and its policy.

class _FakeSubscription extends Fake implements Subscription {
  @override
  void cancel() {}
}

class _FakeCallApi extends Fake implements CallApi {
  final List<(String, Map<String, dynamic>)> sent = [];

  /// Holds every `state` send until completed: a slow or wedged backend.
  Completer<void>? stateGate;
  List<String> get kinds => [for (final s in sent) s.$1];
  Map<String, dynamic> get lastState =>
      sent.lastWhere((s) => s.$1 == 'state').$2;

  @override
  Future<String> initiateCall({
    required String callerId,
    required String calleeId,
    required String roomId,
    required String type,
  }) async =>
      'call-1';

  @override
  Future<String?> cancelCall({required String callId, required String userId}) async =>
      'cancelled';

  @override
  Future<String?> endCall({required String callId, required String userId}) async =>
      'ended';

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
    sent.add((kind, jsonDecode(payload) as Map<String, dynamic>));
    final g = stateGate;
    if (kind == 'state' && g != null) await g.future;
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

Future<void> _pump() async {
  for (var i = 0; i < 4; i++) {
    await Future<void>.delayed(const Duration(milliseconds: 5));
  }
}

/// Hands out camera tracks, each held at "warming up" until released, so a
/// test can tap while the camera is still coming on.
class _Cameras {
  final List<FakeMediaStreamTrack> made = [];
  Completer<void>? gate;

  Future<MediaStreamTrack> acquire(VideoQualityTier _) async {
    final g = gate;
    if (g != null) await g.future;
    final t = FakeMediaStreamTrack(kind: 'video', id: 'cam-${made.length}');
    made.add(t);
    return t;
  }
}

CallService _service(
  _FakeCallApi api,
  List<FakePeerConnection> pcs,
  _Cameras cams, {
  bool withCamera = false,
}) {
  final service = CallService(api: api)
    ..terminalNotifyTimeout = const Duration(milliseconds: 20)
    ..terminalNotifyRetryDelay = const Duration(milliseconds: 1)
    ..teardownUiHold = Duration.zero
    ..endNativeTimeout = const Duration(milliseconds: 20)
    ..cameraWatchLifecycle = false;
  service.getUserMediaFn = (kind, {tier = VideoQualityTier.auto}) async =>
      FakeMediaStream([
        FakeMediaStreamTrack(kind: 'audio'),
        if (withCamera && kind == CallMediaKind.video)
          FakeMediaStreamTrack(kind: 'video', id: 'cam-initial'),
      ], id: 'ls-me');
  service.createPcFn = (config, constraints) async {
    final pc = FakePeerConnection();
    pcs.add(pc);
    return pc;
  };
  service.ensurePermissionsFn = (_) async => true;
  service.getVideoTrackFn = cams.acquire;
  service.createLocalStreamFn = (label) async => FakeMediaStream([], id: label);
  service.attach(userId: 'me', displayName: 'Me', deviceId: 'my-phone');
  addTearDown(() async {
    if (service.inCall) await service.endCall();
    await _pump();
    service.dispose();
  });
  return service;
}

/// A call [svc] placed and the peer answered: the link is up and stable.
Future<FakePeerConnection> _answered(
  CallService svc,
  List<FakePeerConnection> pcs, {
  CallMediaKind kind = CallMediaKind.audio,
}) async {
  await svc.initiate(
    peerUserId: 'peer',
    peerName: 'Peer',
    roomId: 'room1',
    kind: kind,
  );
  await _pump();
  await svc.handleRemoteSignal({
    '_id': 'ans',
    'callId': svc.session!.callId,
    'fromUserId': 'peer',
    'fromDeviceId': 'peer-phone',
    'kind': 'answer',
    'payload': jsonEncode({'sdp': 'v=0', 'type': 'answer'}),
    'createdAt': DateTime.now().millisecondsSinceEpoch,
  });
  await _pump();
  return pcs.single;
}

StatsReport _report(String type, Map<String, dynamic> values) =>
    StatsReport('r-$type', type, 0, values);

/// Records what a release did to the stream, in order.
class _RecordingStream extends FakeMediaStream {
  _RecordingStream(super.tracks);
  final List<String> log = [];

  @override
  Future<void> addTrack(MediaStreamTrack track, {bool addToNative = true}) async {
    log.add('add ${track.id}');
    await super.addTrack(track, addToNative: addToNative);
  }

  @override
  Future<void> removeTrack(MediaStreamTrack track,
      {bool removeFromNative = true}) async {
    log.add('remove ${track.id} native=$removeFromNative');
    await super.removeTrack(track, removeFromNative: removeFromNative);
  }

  @override
  Future<void> dispose() async {
    log.add('dispose');
    await super.dispose();
  }
}

/// A stream that will not take a camera: the plugin throwing on addTrack.
class _RefusingStream extends FakeMediaStream {
  _RefusingStream(super.tracks);

  @override
  Future<void> addTrack(MediaStreamTrack track, {bool addToNative = true}) async {
    if (track.kind == 'video') throw StateError('addTrack refused');
    await super.addTrack(track, addToNative: addToNative);
  }
}

class _LoggingTrack extends FakeMediaStreamTrack {
  _LoggingTrack(this.log) : super(kind: 'video', id: 'cam');
  final List<String> log;

  @override
  Future<void> stop() async {
    log.add('stop');
    await super.stop();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  ScreenShare.invokeFn = (m, [a]) async => null;

  group('frames', () {
    test('the capturer count wins, the encoder count stands in', () {
      expect(
        cameraFramesFrom([
          _report('media-source', {'kind': 'video', 'frames': 120}),
          _report('outbound-rtp', {'kind': 'video', 'framesEncoded': 90}),
        ]),
        120,
      );
      expect(
        cameraFramesFrom([
          _report('outbound-rtp', {'kind': 'video', 'framesEncoded': 90}),
        ]),
        90,
      );
      expect(
        cameraFramesFrom([
          _report('media-source', {'kind': 'audio', 'audioLevel': 0.2}),
        ]),
        isNull,
      );
    });

    test('a flat count is a stall only after two flat samples', () {
      final d = CameraStallDetector();
      expect(d.sample(10), CameraHealth.unknown); // first: a baseline
      expect(d.sample(10), CameraHealth.unknown);
      expect(d.sample(10), CameraHealth.stalled);
      expect(d.sample(40), CameraHealth.capturing);
      // A count that went backwards is a new camera: start over.
      expect(d.sample(3), CameraHealth.unknown);
      expect(d.sample(3), CameraHealth.unknown);
      // Can't tell is never a stall, and keeps the baseline.
      expect(d.sample(null), CameraHealth.unknown);
      expect(d.sample(3), CameraHealth.stalled);
    });

    test('coming back to the foreground judges the camera within a second',
        () async {
      final verdicts = <CameraHealth>[];
      final watch = CameraWatch(
        readFrames: () async => 50,
        onVerdict: verdicts.add,
        interval: const Duration(hours: 1),
        resumeWindow: const Duration(milliseconds: 10),
        listenToLifecycle: false,
      )..start();
      addTearDown(watch.stop);
      watch.resumed();
      await Future<void>.delayed(const Duration(milliseconds: 40));
      expect(verdicts, [CameraHealth.stalled]);
    });
  });

  group('release order', () {
    test('Darwin stops the track while it is still in the stream', () async {
      final log = <String>[];
      final t = _LoggingTrack(log);
      final s = _RecordingStream([t]);
      s.log.clear();
      await releaseCameraTrack(s, t, darwin: true);
      // The native stream still holds it when trackDispose looks, which is
      // the only way the plugin stops the capture session.
      expect(s.log, ['remove cam native=false']);
      expect(log, ['stop']);
      expect(s.getVideoTracks(), isEmpty);
    });

    test('Android edits the native stream, then stops', () async {
      final log = <String>[];
      final t = _LoggingTrack(log);
      final s = _RecordingStream([t]);
      await releaseCameraTrack(s, t, darwin: false);
      expect(s.log, ['remove cam native=true']);
      expect(t.stopped, isTrue);
    });

    test('a camera that never joined the call is parked, then stopped',
        () async {
      final log = <String>[];
      final t = _LoggingTrack(log);
      late _RecordingStream parked;
      await discardCameraTrack(
        t,
        darwin: true,
        createStream: (_) async => parked = _RecordingStream([]),
      );
      expect(parked.log, ['add cam', 'dispose']);
      expect(t.stopped, isTrue);
    });
  });

  group('1:1 toggle', () {
    test('a second tap while the camera warms up never makes a second camera',
        () async {
      final api = _FakeCallApi();
      final pcs = <FakePeerConnection>[];
      final cams = _Cameras();
      final svc = _service(api, pcs, cams);
      await _answered(svc, pcs);

      cams.gate = Completer<void>();
      final on = svc.toggleVideo();
      // The button answers on the tap.
      expect(svc.cameraButtonOn, isTrue);
      expect(svc.localCamActive, isFalse);
      await _pump();
      final off = svc.toggleVideo();
      expect(svc.cameraButtonOn, isFalse);
      cams.gate!.complete();
      await Future.wait([on, off]);
      await _pump();

      expect(cams.made, hasLength(1));
      expect(cams.made.single.stopped, isTrue);
      expect(svc.localStream!.getVideoTracks(), isEmpty);
      expect(svc.localCamActive, isFalse);
      expect(svc.cameraButtonOn, isFalse);
      expect(svc.session!.localVideoOff, isTrue);
      expect(api.lastState['videoOff'], isTrue);

      // And a third tap brings exactly one camera back.
      cams.gate = null;
      await svc.toggleVideo();
      await _pump();
      expect(cams.made, hasLength(2));
      expect(svc.localStream!.getVideoTracks().single.id, 'cam-1');
      expect(svc.cameraButtonOn, isTrue);
      expect(api.lastState['videoOff'], isFalse);
    });

    test('a failed camera leaves the button off, not on', () async {
      final api = _FakeCallApi();
      final pcs = <FakePeerConnection>[];
      final svc = _service(api, pcs, _Cameras());
      await _answered(svc, pcs);
      svc.getVideoTrackFn = (_) async => throw StateError('camera busy');
      await svc.toggleVideo();
      await _pump();
      expect(svc.cameraButtonOn, isFalse);
      expect(svc.session!.localVideoOff, isTrue);
    });

    test('a video call releases its camera on off and acquires one on on',
        () async {
      final api = _FakeCallApi();
      final pcs = <FakePeerConnection>[];
      final cams = _Cameras();
      final svc = _service(api, pcs, cams, withCamera: true);
      final pc = await _answered(svc, pcs, kind: CallMediaKind.video);
      final initial = svc.localStream!.getVideoTracks().single
          as FakeMediaStreamTrack;
      expect(svc.cameraButtonOn, isTrue);
      final sender = pc.fakeTransceivers
          .firstWhere((t) => t.sender.track?.id == 'cam-initial')
          .sender;

      await svc.toggleVideo();
      await _pump();
      // Off is off: the camera released, not a disabled track still running.
      expect(initial.stopped, isTrue);
      expect(sender.replaced, [null]);
      expect(svc.localCamActive, isFalse);

      await svc.toggleVideo();
      await _pump();
      expect(cams.made, hasLength(1));
      expect(sender.replaced.last?.id, 'cam-0');
      expect(svc.localCamActive, isTrue);
    });

    test('a video call that got no camera says the camera is off', () async {
      final api = _FakeCallApi();
      final pcs = <FakePeerConnection>[];
      final svc = _service(api, pcs, _Cameras());
      await _answered(svc, pcs, kind: CallMediaKind.video);
      expect(svc.session!.localVideoOff, isTrue);
      expect(svc.cameraButtonOn, isFalse);
    });
  });

  group('1:1 privacy and robustness', () {
    test('camera off empties the slot on the tap, not after the state '
        'signal has been through the backend', () async {
      final api = _FakeCallApi();
      final pcs = <FakePeerConnection>[];
      final svc = _service(api, pcs, _Cameras(), withCamera: true);
      final pc = await _answered(svc, pcs, kind: CallMediaKind.video);
      final initial = svc.localStream!.getVideoTracks().single
          as FakeMediaStreamTrack;
      final sender = pc.fakeTransceivers
          .firstWhere((t) => t.sender.track?.id == 'cam-initial')
          .sender;

      api.stateGate = Completer<void>();
      final off = svc.toggleVideo();
      await _pump();
      // The backend has not answered, and nothing goes out any more.
      expect(sender.replaced, [null]);
      expect(initial.stopped, isTrue);
      expect(svc.localCamActive, isFalse);
      expect(api.lastState['videoOff'], isTrue);
      await off; // the tap's work never waits on the network either
      api.stateGate!.complete();
    });

    test('a hanging state send never holds the next camera tap', () async {
      final api = _FakeCallApi();
      final pcs = <FakePeerConnection>[];
      final cams = _Cameras();
      final svc = _service(api, pcs, cams, withCamera: true);
      final pc = await _answered(svc, pcs, kind: CallMediaKind.video);
      final sender = pc.fakeTransceivers
          .firstWhere((t) => t.sender.track?.id == 'cam-initial')
          .sender;
      api.stateGate = Completer<void>();
      await svc.toggleVideo();
      await svc.toggleVideo();
      await _pump();
      expect(sender.replaced.last?.id, 'cam-0');
      expect(svc.localCamActive, isTrue);
      api.stateGate!.complete();
    });

    test('a camera the stream refused is stopped, not leaked', () async {
      final api = _FakeCallApi();
      final pcs = <FakePeerConnection>[];
      final cams = _Cameras();
      final svc = _service(api, pcs, cams);
      svc.getUserMediaFn = (kind, {tier = VideoQualityTier.auto}) async =>
          _RefusingStream([FakeMediaStreamTrack(kind: 'audio')]);
      await _answered(svc, pcs);
      await svc.toggleVideo();
      await _pump();
      expect(cams.made, hasLength(1));
      expect(cams.made.single.stopped, isTrue);
      expect(svc.cameraButtonOn, isFalse);
      expect(svc.localCamActive, isFalse);
    });

    test('a camera step left hanging by the last call never blocks the '
        'next call\'s camera', () async {
      final api = _FakeCallApi();
      final pcs = <FakePeerConnection>[];
      final cams = _Cameras();
      final svc = _service(api, pcs, cams);
      await _answered(svc, pcs);
      final stuck = Completer<void>();
      cams.gate = stuck;
      unawaited(svc.toggleVideo()); // the camera never comes up
      await _pump();
      await svc.endCall();
      await _pump();

      cams.gate = null;
      await svc.initiate(
        peerUserId: 'peer',
        peerName: 'Peer',
        roomId: 'room1',
        kind: CallMediaKind.audio,
      );
      await _pump();
      await svc.toggleVideo();
      await _pump();
      expect(svc.localCamActive, isTrue);
      expect(cams.made, hasLength(1));
      final live = cams.made.single;

      // The old step wakes up into a call that is not its own: its camera
      // is stopped and this call's is left alone, button included.
      stuck.complete();
      await _pump();
      expect(cams.made, hasLength(2));
      expect(cams.made.last.stopped, isTrue);
      expect(live.stopped, isFalse);
      expect(svc.localStream!.getVideoTracks().single.id, live.id);
      expect(svc.cameraButtonOn, isTrue);
    });

    test('the frame watch reads nothing while the link is down', () async {
      final api = _FakeCallApi();
      final pcs = <FakePeerConnection>[];
      final svc = _service(api, pcs, _Cameras());
      final pc = await _answered(svc, pcs);
      await svc.toggleVideo();
      await _pump();
      pc.stats = [
        _report('media-source', {'kind': 'video', 'frames': 120}),
      ];
      // A blip: an encoder starved by the network is not a dead camera.
      pc.iceState = RTCIceConnectionState.RTCIceConnectionStateDisconnected;
      expect(await svc.debugReadCamFrames(), isNull);
      pc.iceState = RTCIceConnectionState.RTCIceConnectionStateConnected;
      expect(await svc.debugReadCamFrames(), 120);
      pc.iceState = RTCIceConnectionState.RTCIceConnectionStateCompleted;
      expect(await svc.debugReadCamFrames(), 120);
    });
  });

  group('1:1 camera health', () {
    test('a camera stalled in the background is paused for the peer',
        () async {
      final api = _FakeCallApi();
      final pcs = <FakePeerConnection>[];
      final cams = _Cameras();
      final svc = _service(api, pcs, cams);
      await _answered(svc, pcs);
      await svc.toggleVideo();
      await _pump();
      svc.appInForegroundFn = () => false;

      svc.debugCameraVerdict(CameraHealth.stalled);
      await _pump();
      expect(svc.cameraSuspended, isTrue);
      expect(api.lastState['videoOff'], isTrue);
      // The user's choice stands; nothing restarts in the background.
      expect(svc.cameraButtonOn, isTrue);
      expect(cams.made, hasLength(1));

      svc.debugCameraVerdict(CameraHealth.capturing);
      await _pump();
      expect(svc.cameraSuspended, isFalse);
      expect(api.lastState['videoOff'], isFalse);
    });

    test('a stall in the foreground restarts the camera, then gives up',
        () async {
      final api = _FakeCallApi();
      final pcs = <FakePeerConnection>[];
      final cams = _Cameras();
      final svc = _service(api, pcs, cams);
      final pc = await _answered(svc, pcs);
      await svc.toggleVideo();
      await _pump();
      svc.appInForegroundFn = () => true;
      final sender = pc.fakeTransceivers
          .firstWhere((t) => t.sender.track?.id == 'cam-0')
          .sender;

      svc.debugCameraVerdict(CameraHealth.stalled);
      await _pump();
      // A fresh camera on the same slot, the dead one released.
      expect(cams.made, hasLength(2));
      expect(cams.made.first.stopped, isTrue);
      expect(sender.track?.id, 'cam-1');
      expect(svc.localStream!.getVideoTracks().single.id, 'cam-1');
      expect(svc.cameraButtonOn, isTrue);

      for (var i = 1; i < kMaxCameraRestarts; i++) {
        svc.debugCameraVerdict(CameraHealth.stalled);
        await _pump();
      }
      expect(cams.made, hasLength(1 + kMaxCameraRestarts));
      // Still nothing: the button stops promising a picture.
      svc.debugCameraVerdict(CameraHealth.stalled);
      await _pump();
      expect(svc.cameraButtonOn, isFalse);
      expect(svc.session!.localVideoOff, isTrue);
      expect(svc.cameraSuspended, isFalse);
      expect(svc.localStream!.getVideoTracks(), isEmpty);
      expect(api.lastState['videoOff'], isTrue);
    });
  });

  group('group toggle', () {
    test('a second tap while the camera warms up never makes a second camera',
        () async {
      final api = _FakeGroupApi();
      final cams = _Cameras();
      final svc = GroupCallService(api: api)
        ..leaveNotifyTimeout = const Duration(milliseconds: 20)
        ..nativeCardsEnabled = false
        ..cameraWatchLifecycle = false;
      svc.getUserMediaFn = (kind, {tier = VideoQualityTier.auto}) async =>
          FakeMediaStream([FakeMediaStreamTrack(kind: 'audio')], id: 'ls-a');
      svc.createPcFn = (config, constraints) async => FakePeerConnection();
      svc.ensurePermissionsFn = (_) async => true;
      svc.getVideoTrackFn = cams.acquire;
      svc.createLocalStreamFn = (label) async => FakeMediaStream([], id: label);
      svc.attach(userId: 'a', deviceId: 'dev-a');
      addTearDown(() async {
        if (svc.inCall) await svc.leaveCall();
        svc.dispose();
      });
      await svc.joinCall('gc1');
      await _pump();
      api.roster!({
        'groupCallId': 'gc1',
        'status': 'active',
        'roomName': 'crew',
        'participants': [
          for (final id in ['a', 'b'])
            {'userId': id, 'status': 'joined', 'name': id.toUpperCase()},
        ],
      });
      await _pump();

      cams.gate = Completer<void>();
      final on = svc.toggleVideo();
      expect(svc.cameraButtonOn, isTrue);
      await _pump();
      final off = svc.toggleVideo();
      expect(svc.cameraButtonOn, isFalse);
      cams.gate!.complete();
      await Future.wait([on, off]);
      await _pump();
      expect(cams.made, hasLength(1));
      expect(cams.made.single.stopped, isTrue);
      expect(svc.localCamActive, isFalse);
      expect(svc.localVideoOff, isTrue);

      cams.gate = null;
      await svc.toggleVideo();
      await _pump();
      svc.appInForegroundFn = () => false;
      svc.debugCameraVerdict(CameraHealth.stalled);
      await _pump();
      expect(svc.cameraSuspended, isTrue);
      expect(api.states.last['videoOff'], isTrue);
      expect(svc.cameraButtonOn, isTrue);
    });

    test('camera off empties every slot on the tap, not after a state '
        'signal per peer', () async {
      final api = _FakeGroupApi()..type = 'video';
      final pcs = <FakePeerConnection>[];
      final svc = await _groupWithPeer(api, pcs, _Cameras(),
          others: ['b', 'c']);
      expect(svc.localCamActive, isTrue);
      final senders = [
        for (final pc in pcs)
          pc.fakeTransceivers
              .firstWhere((t) => t.sender.track?.id == 'cam-initial')
              .sender,
      ];
      expect(senders, hasLength(2));
      final initial = svc.localStream!.getVideoTracks().single
          as FakeMediaStreamTrack;

      api.stateGate = Completer<void>();
      await svc.toggleVideo();
      await _pump();
      for (final sender in senders) {
        expect(sender.replaced, [null]);
      }
      expect(initial.stopped, isTrue);
      expect(svc.localCamActive, isFalse);
      api.stateGate!.complete();
      await _pump();
      expect(api.states.last['videoOff'], isTrue);
    });
  });

  group('the Android route has one owner', () {
    late bool Function() savedProbe;
    setUp(() {
      savedProbe = NativeCallHandler.groupCallActiveProbe;
      androidSetSpeakerphoneOn = (_) async {};
      androidSetSpeakerphoneButPreferHeadset = () async {};
      androidCallWindowSink = (_) async {};
    });
    tearDown(() {
      NativeCallHandler.groupCallActiveProbe = savedProbe;
      resetAndroidCallRoute();
    });

    test('a 1:1 torn down during a group call leaves the group\'s route',
        () async {
      final api = _FakeCallApi();
      final pcs = <FakePeerConnection>[];
      final svc = _service(api, pcs, _Cameras());
      // The group call set the route; a 1:1 rings beside it and is missed.
      await applyAndroidCallRoute(speakerOn: true, video: true);
      NativeCallHandler.groupCallActiveProbe = () => true;
      await _answered(svc, pcs);
      await svc.endCall();
      await _pump();
      expect(debugAndroidCallRoute, isNotNull);

      // With no group call, the 1:1's end does give it back.
      NativeCallHandler.groupCallActiveProbe = () => false;
      pcs.clear();
      await _answered(svc, pcs);
      await svc.endCall();
      await _pump();
      expect(debugAndroidCallRoute, isNull);
    });
  });

  group('group audio across link changes', () {
    setUp(() {
      debugReleasePeerConnectionsOverride = true;
      releasePeerConnectionDelay = const Duration(milliseconds: 1);
    });
    tearDown(() async {
      await flushPeerConnectionReleases();
      debugReleasePeerConnectionsOverride = null;
      releasePeerConnectionDelay = const Duration(milliseconds: 600);
    });

    // Android's AudioSwitch leaves call mode when the plugin's last peer
    // connection is disposed: the only peer leaving must not do that to a
    // phone still in the call.
    test('the last link is parked while the call goes on, released when '
        'another link exists or on leave', () async {
      final api = _FakeGroupApi();
      final pcs = <FakePeerConnection>[];
      final svc = await _groupWithPeer(api, pcs, _Cameras());
      expect(pcs, hasLength(1));

      _roster(api, ['a']); // b leaves; we are alone in the call
      await _pump();
      expect(svc.debugParkedPeerConnections, 1);
      expect(debugPendingPeerConnectionReleases, 0);

      _roster(api, ['a', 'c']); // c joins: a live link again
      await _pump();
      expect(pcs, hasLength(2));
      expect(svc.debugParkedPeerConnections, 0);

      _roster(api, ['a']);
      await _pump();
      expect(svc.debugParkedPeerConnections, 1);
      await svc.leaveCall();
      expect(svc.debugParkedPeerConnections, 0);
      await flushPeerConnectionReleases();
      expect(debugPendingPeerConnectionReleases, 0);
    });

    test('a new call\'s mic comes up only after the last call\'s '
        'connection is disposed', () async {
      releasePeerConnectionDelay = const Duration(seconds: 30);
      final old1 = FakePeerConnection();
      releasePeerConnection(old1);
      final api = _FakeCallApi();
      final pcs = <FakePeerConnection>[];
      final svc = _service(api, pcs, _Cameras());
      final inner = svc.getUserMediaFn;
      bool? disposedAtMic;
      svc.getUserMediaFn = (kind, {tier = VideoQualityTier.auto}) {
        disposedAtMic = old1.closed;
        return inner(kind, tier: tier);
      };
      await _answered(svc, pcs);
      expect(disposedAtMic, isTrue);

      // The group join takes the same care.
      final old2 = FakePeerConnection();
      releasePeerConnection(old2);
      final gApi = _FakeGroupApi();
      final g = await _groupWithPeer(gApi, <FakePeerConnection>[], _Cameras());
      expect(g.inCall, isTrue);
      expect(old2.closed, isTrue);
      expect(debugPendingPeerConnectionReleases, 0);
    });

    test('a link that comes up re-asserts the route', () async {
      final api = _FakeGroupApi();
      final pcs = <FakePeerConnection>[];
      final applies = <bool>[];
      final svc = GroupCallService(api: api)
        ..leaveNotifyTimeout = const Duration(milliseconds: 20)
        ..nativeCardsEnabled = false
        ..cameraWatchLifecycle = false;
      svc.applyCallAudioFn = (kind,
          {required speakerOn, required headsetWins, callId}) async {
        applies.add(speakerOn);
        return speakerOn;
      };
      svc.getUserMediaFn = (kind, {tier = VideoQualityTier.auto}) async =>
          FakeMediaStream([FakeMediaStreamTrack(kind: 'audio')], id: 'ls-a');
      svc.createPcFn = (config, constraints) async {
        final pc = FakePeerConnection();
        pcs.add(pc);
        return pc;
      };
      svc.attach(userId: 'a', deviceId: 'dev-a');
      addTearDown(() async {
        if (svc.inCall) await svc.leaveCall();
        svc.dispose();
      });
      await svc.joinCall('gc1');
      await _pump();
      _roster(api, ['a', 'b']);
      await _pump();
      final before = applies.length;
      pcs.single.onConnectionState!(
          RTCPeerConnectionState.RTCPeerConnectionStateConnected);
      await _pump();
      expect(applies.length, before + 1);
      // A repeat of the same link's "connected" is not a new link.
      pcs.single.onConnectionState!(
          RTCPeerConnectionState.RTCPeerConnectionStateConnected);
      await _pump();
      expect(applies.length, before + 1);
    });
  });
}

/// A group call joined as 'a', with 'b' in it. [pcs] collects every link.
Future<GroupCallService> _groupWithPeer(
  _FakeGroupApi api,
  List<FakePeerConnection> pcs,
  _Cameras cams, {
  List<String> others = const ['b'],
}) async {
  final svc = GroupCallService(api: api)
    ..leaveNotifyTimeout = const Duration(milliseconds: 20)
    ..nativeCardsEnabled = false
    ..cameraWatchLifecycle = false;
  svc.getUserMediaFn = (kind, {tier = VideoQualityTier.auto}) async =>
      FakeMediaStream([
        FakeMediaStreamTrack(kind: 'audio'),
        if (kind == CallMediaKind.video)
          FakeMediaStreamTrack(kind: 'video', id: 'cam-initial'),
      ], id: 'ls-a');
  svc.createPcFn = (config, constraints) async {
    final pc = FakePeerConnection();
    pcs.add(pc);
    return pc;
  };
  svc.ensurePermissionsFn = (_) async => true;
  svc.getVideoTrackFn = cams.acquire;
  svc.createLocalStreamFn = (label) async => FakeMediaStream([], id: label);
  svc.attach(userId: 'a', deviceId: 'dev-a');
  addTearDown(() async {
    if (svc.inCall) await svc.leaveCall();
    svc.dispose();
  });
  await svc.joinCall('gc1');
  await _pump();
  _roster(api, ['a', ...others]);
  await _pump();
  return svc;
}

void _roster(_FakeGroupApi api, List<String> ids) => api.roster!({
      'groupCallId': 'gc1',
      'status': 'active',
      'roomName': 'crew',
      'participants': [
        for (final id in ids)
          {'userId': id, 'status': 'joined', 'name': id.toUpperCase()},
      ],
    });

class _FakeGroupApi extends Fake implements GroupCallApi {
  final List<Map<String, dynamic>> states = [];
  void Function(Map<String, dynamic>? roster)? roster;
  String type = 'audio';

  /// Holds every `state` send until completed.
  Completer<void>? stateGate;

  @override
  Future<({String type, String roomId})> join({
    required String groupCallId,
    required String userId,
    String? deviceId,
  }) async =>
      (type: type, roomId: 'room1');

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
    if (kind == 'state') {
      states.add(jsonDecode(payload) as Map<String, dynamic>);
      final g = stateGate;
      if (g != null) await g.future;
    }
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
  }) async =>
      _FakeSubscription();

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
