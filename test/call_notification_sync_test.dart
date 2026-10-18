import 'package:flutter_test/flutter_test.dart';
import 'package:monkeyhub/calls/call_models.dart';
import 'package:monkeyhub/calls/call_notification_sync.dart';

CallSession _session({
  CallStatus status = CallStatus.active,
  bool muted = false,
  String callId = 'c1',
}) =>
    CallSession(
      callId: callId,
      roomId: 'r',
      peerUserId: 'p',
      peerName: 'Ada',
      mediaKind: CallMediaKind.audio,
      isCaller: true,
      status: status,
      localMuted: muted,
    );

void main() {
  group('callNotificationStateFor', () {
    test('no session, no state', () {
      expect(
        callNotificationStateFor(session: null, localCamActive: false),
        isNull,
      );
    });

    test('a ringing incoming card and a finished call have none', () {
      for (final st in [
        CallStatus.incomingRinging,
        CallStatus.ended,
        CallStatus.failed,
        CallStatus.handedOff,
        CallStatus.idle,
      ]) {
        expect(
          callNotificationStateFor(
            session: _session(status: st),
            localCamActive: false,
          ),
          isNull,
          reason: st.name,
        );
      }
    });

    test('dialling is not connected; active is', () {
      final dialling = callNotificationStateFor(
        session: _session(status: CallStatus.outgoingRinging),
        localCamActive: false,
      )!;
      expect(dialling.connected, isFalse);
      final live = callNotificationStateFor(
        session: _session(muted: true),
        localCamActive: true,
      )!;
      expect(live.connected, isTrue);
      expect(live.muted, isTrue);
      expect(live.camera, isTrue);
    });
  });

  group('callNotificationOps', () {
    const a = CallNotificationState(
      callId: 'c1',
      connected: true,
      muted: false,
      camera: false,
    );

    List<String> methods(
      CallNotificationState? p,
      CallNotificationState? n,
    ) =>
        callNotificationOps(p, n, mute: 'Mute', unmute: 'Unmute')
            .map((e) => e.$1)
            .toList();

    test('a new call posts its mute state', () {
      final ops = callNotificationOps(null, a, mute: 'Mute', unmute: 'Unmute');
      expect(ops.map((e) => e.$1), ['setMuted']);
      expect(ops.single.$2, {
        'callId': 'c1',
        'muted': false,
        'mute': 'Mute',
        'unmute': 'Unmute',
        'connected': true,
      });
    });

    test('nothing changed, nothing sent', () {
      expect(methods(a, a), isEmpty);
    });

    test('a mute flip re-posts', () {
      const muted = CallNotificationState(
        callId: 'c1',
        connected: true,
        muted: true,
        camera: false,
      );
      expect(methods(a, muted), ['setMuted']);
    });

    test('the camera coming on widens the service once', () {
      const cam = CallNotificationState(
        callId: 'c1',
        connected: true,
        muted: false,
        camera: true,
      );
      expect(methods(a, cam), ['ensureCamera']);
      expect(methods(cam, cam), isEmpty);
      // Off again: the service keeps the type; nothing to send.
      expect(methods(cam, a), isEmpty);
    });

    test('a video call starts widened', () {
      const cam = CallNotificationState(
        callId: 'c2',
        connected: false,
        muted: false,
        camera: true,
      );
      expect(methods(null, cam), ['setMuted', 'ensureCamera']);
    });

    test('the end clears, and only once', () {
      expect(methods(a, null), ['clear']);
      expect(methods(null, null), isEmpty);
    });
  });
}
