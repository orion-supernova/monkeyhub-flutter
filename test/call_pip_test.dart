import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:monkeyhub/calls/call_models.dart';
import 'package:monkeyhub/calls/call_pip.dart';
import 'package:monkeyhub/calls/call_service.dart';
import 'package:monkeyhub/calls/group_call_service.dart';

import 'fakes/fake_webrtc.dart';

CallSession _session({
  CallStatus status = CallStatus.active,
  PeerMediaState peer = const PeerMediaState(),
}) =>
    CallSession(
      callId: 'c1',
      roomId: 'r1',
      peerUserId: 'u2',
      peerName: 'Ada',
      mediaKind: CallMediaKind.video,
      isCaller: true,
      status: status,
      peerState: peer,
    );

FakeMediaStream _video(String id) =>
    FakeMediaStream([FakeMediaStreamTrack(kind: 'video', id: id)]);

/// Just what `CallPip._sync` reads off a 1:1 call.
class _Call extends ChangeNotifier implements CallService {
  _Call(this.session, this.remoteStream);

  @override
  final CallSession? session;
  @override
  final MediaStream? remoteStream;
  @override
  bool localScreenSharing = false;

  @override
  bool get inCall => true;
  @override
  bool get localCamActive => true;
  @override
  MediaStream? get remoteScreenStream => null;

  void changed() => notifyListeners();

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Group extends ChangeNotifier implements GroupCallService {
  @override
  bool get inCall => false;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('CallPip while presenting', () {
    late List<MethodCall> sent;

    setUp(() {
      sent = [];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(const MethodChannel('monkeyhub/call_pip'), (c) async {
        sent.add(c);
        return null;
      });
    });

    tearDown(() {
      CallPip.instance.debugReset();
      CallPip.instance.supportedOverride = false;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(const MethodChannel('monkeyhub/call_pip'), null);
    });

    Future<_Call> start({required bool feedsBoard}) async {
      final pip = CallPip.instance
        ..supportedOverride = true
        ..presentingFeedsBoardOverride = feedsBoard;
      final call = _Call(_session(), _video('v1'));
      pip.attach(call: call, group: _Group());
      call
        ..localScreenSharing = true
        ..changed();
      await Future<void>.delayed(Duration.zero);
      return call;
    }

    test("iOS: the board still hears the peer's picture", () async {
      await start(feedsBoard: true);
      // No in-app window over the shared screen...
      expect(CallPip.instance.spec.value, isNull);
      // ...but the native side keeps the peer, for the board between drawings.
      expect(sent.map((c) => c.method), ['arm']);
      expect((sent.single.arguments as Map)['trackId'], 'v1');
    });

    test('elsewhere: presenting disarms the call window', () async {
      await start(feedsBoard: false);
      expect(CallPip.instance.spec.value, isNull);
      expect(sent.map((c) => c.method), ['arm', 'disarm']);
    });
  });

  group('pipSpecForCall', () {
    test('a live video call shows the peer', () {
      final spec = pipSpecForCall(
        session: _session(),
        localCamActive: true,
        localScreenSharing: false,
        remoteStream: _video('v1'),
        remoteScreenStream: null,
      );
      expect(spec, isNotNull);
      expect(spec!.trackId, 'v1');
      expect(spec.videoOff, isFalse);
      expect(spec.title, 'Ada');
      expect(spec.toArgs()['fit'], isFalse);
    });

    test('our camera alone still arms it, on the name card', () {
      // iOS only runs the camera in the background under a video-call PiP,
      // so a peer with their camera off must still get ours.
      final spec = pipSpecForCall(
        session: _session(peer: const PeerMediaState(videoOff: true)),
        localCamActive: true,
        localScreenSharing: false,
        remoteStream: _video('v1'),
        remoteScreenStream: null,
      );
      expect(spec, isNotNull);
      expect(spec!.toArgs()['videoOff'], isTrue);
    });

    test('a voice call has no window', () {
      final spec = pipSpecForCall(
        session: _session(peer: const PeerMediaState(videoOff: true)),
        localCamActive: false,
        localScreenSharing: false,
        remoteStream: FakeMediaStream([FakeMediaStreamTrack(kind: 'audio')]),
        remoteScreenStream: null,
      );
      expect(spec, isNull);
    });

    test('nothing before the call is connected', () {
      for (final status in [
        CallStatus.outgoingRinging,
        CallStatus.incomingRinging,
        CallStatus.connecting,
        CallStatus.ended,
      ]) {
        expect(
          pipSpecForCall(
            session: _session(status: status),
            localCamActive: true,
            localScreenSharing: false,
            remoteStream: _video('v1'),
            remoteScreenStream: null,
          ),
          isNull,
          reason: status.name,
        );
      }
    });

    test('presenting hands PiP to the drawing board', () {
      expect(
        pipSpecForCall(
          session: _session(),
          localCamActive: true,
          localScreenSharing: true,
          remoteStream: _video('v1'),
          remoteScreenStream: null,
        ),
        isNull,
      );
    });

    test("the peer's shared screen wins, shown whole", () {
      final spec = pipSpecForCall(
        session: _session(peer: const PeerMediaState(screenSharing: true)),
        localCamActive: false,
        localScreenSharing: false,
        remoteStream: _video('cam'),
        remoteScreenStream: _video('screen'),
      );
      expect(spec!.trackId, 'screen');
      expect(spec.toArgs()['fit'], isTrue);
    });

    test('same picture, same signature: no native chatter', () {
      CallPipSpec? make() => pipSpecForCall(
            session: _session(),
            localCamActive: true,
            localScreenSharing: false,
            remoteStream: _video('v1'),
            remoteScreenStream: null,
          );
      expect(make()!.signature, make()!.signature);
    });
  });

  group('PeerMediaState.videoPaused', () {
    test('round-trips, and is absent while false', () {
      const paused = PeerMediaState(videoOff: true, videoPaused: true);
      expect(PeerMediaState.fromJson(paused.toJson()).videoPaused, isTrue);
      expect(const PeerMediaState().toJson().containsKey('videoPaused'), isFalse);
    });

    test('an older payload reads as not paused', () {
      final s = PeerMediaState.fromJson({'videoOff': true});
      expect(s.videoOff, isTrue);
      expect(s.videoPaused, isFalse);
    });
  });

  group('pipSpecForGroup', () {
    GroupPeer peer(String name, {MediaStream? cam, bool videoOff = false}) {
      final p = GroupPeer(userId: name, name: name)
        ..remoteStream = cam
        ..mediaState = PeerMediaState(videoOff: videoOff);
      return p;
    }

    test('first face with a picture', () {
      final spec = pipSpecForGroup(
        inCall: true,
        localCamActive: false,
        localScreenSharing: false,
        peers: [peer('A', videoOff: true), peer('B', cam: _video('b'))],
        roomName: 'Room',
      );
      expect(spec!.title, 'B');
      expect(spec.trackId, 'b');
    });

    test('no faces but our camera: the room card', () {
      final spec = pipSpecForGroup(
        inCall: true,
        localCamActive: true,
        localScreenSharing: false,
        peers: [peer('A', videoOff: true)],
        roomName: 'Room',
      );
      expect(spec!.title, 'Room');
      expect(spec.toArgs()['videoOff'], isTrue);
    });

    test('a voice group call has no window', () {
      expect(
        pipSpecForGroup(
          inCall: true,
          localCamActive: false,
          localScreenSharing: false,
          peers: [peer('A', videoOff: true)],
          roomName: 'Room',
        ),
        isNull,
      );
    });
  });
}
