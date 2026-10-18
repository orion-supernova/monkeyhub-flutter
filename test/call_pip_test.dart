import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:monkeyhub/calls/call_models.dart';
import 'package:monkeyhub/calls/call_pip.dart';
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

void main() {
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
