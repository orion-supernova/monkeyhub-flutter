import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:monkeyhub/backend/call_api.dart';
import 'package:monkeyhub/backend/convex_client.dart';
import 'package:monkeyhub/calls/call_media.dart';
import 'package:monkeyhub/calls/call_models.dart';
import 'package:monkeyhub/calls/call_service.dart';

import 'fakes/fake_webrtc.dart';

/// Report #3 (2026-10-11), "speaker settings are kinda wrong": the speaker
/// flag is now kept on the side the sound really takes. A connected headset
/// beats a default speaker, a tap beats a headset, and a route the user
/// moves outside the app (CallKit, Control Center, plugging in) is adopted.

class _FakeSubscription extends Fake implements Subscription {
  @override
  void cancel() {}
}

class _FakeApi extends Fake implements CallApi {
  @override
  Future<Subscription> subscribeActiveCall({
    required String userId,
    required void Function(Map<String, dynamic>? call) onCall,
    void Function(Object error)? onError,
  }) async =>
      _FakeSubscription();

  @override
  Future<String?> getCallStatus({
    required String callId,
    required String userId,
  }) async =>
      'ringing';

  @override
  Future<void> markCallRinging({
    required String callId,
    required String userId,
  }) async {}

  @override
  Future<List<Map<String, dynamic>>> getIceConfig(String userId) async =>
      const [];
}

/// The native router, as far as Dart can see it: a headset, when connected,
/// wins over a speaker asked for with `headsetWins`.
class _FakeRouter {
  bool headset = false;
  final List<({bool speaker, bool headsetWins})> applies = [];
  /// The call each apply named, in order (see [applies]).
  final List<String?> callIds = [];
  Completer<void>? gate;

  Future<bool?> apply(
    CallMediaKind kind, {
    required bool speakerOn,
    required bool headsetWins,
    String? callId,
  }) async {
    applies.add((speaker: speakerOn, headsetWins: headsetWins));
    callIds.add(callId);
    final g = gate;
    if (g != null) await g.future;
    return speakerOn && !(headsetWins && headset);
  }
}

Map<String, dynamic> _invite(String callId, String type) => {
      '_id': 'invite-$callId',
      'callId': callId,
      'fromUserId': 'peer',
      'kind': 'invite',
      'payload': jsonEncode({'callerName': 'Zeynep', 'type': type}),
      'createdAt': DateTime.now().millisecondsSinceEpoch,
    };

CallAudioRoute _route(
  CallAudioRouteReason reason, {
  bool speaker = false,
  bool headset = false,
  String? output,
  bool echo = false,
}) =>
    CallAudioRoute(
      speaker: speaker,
      headset: headset,
      output: output ?? (speaker ? 'speaker' : headset ? 'bluetooth' : 'receiver'),
      reason: reason,
      echo: echo,
    );

/// A call with its media up (the stream seeded as if the accept had just
/// acquired it): only such a call owns the route. [mediaUp] false leaves it
/// ringing, with no audio of its own.
Future<(CallService, _FakeRouter)> _ringing(
  String type, {
  bool mediaUp = true,
}) async {
  final router = _FakeRouter();
  final service = CallService(api: _FakeApi())
    ..teardownUiHold = Duration.zero
    ..endNativeTimeout = const Duration(milliseconds: 20)
    ..applyCallAudioFn = router.apply;
  service.attach(userId: 'me', displayName: 'Me', deviceId: 'phone');
  await service.handleRemoteSignal(_invite('c1', type));
  if (mediaUp) {
    service.debugSetLocalStreamForTest(
      FakeMediaStream([FakeMediaStreamTrack(kind: 'audio')], id: 'ls'),
    );
  }
  return (service, router);
}

Future<void> _settle() => Future<void>.delayed(Duration.zero);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('decideCallAudioRoute', () {
    test('a headset connecting takes the sound from the speaker', () {
      final d = decideCallAudioRoute(
        speakerOn: true,
        cameraOn: true,
        route: _route(CallAudioRouteReason.newDevice,
            speaker: true, headset: true),
      );
      expect(d.speakerOn, isFalse);
      expect(d.userChosen, isFalse);
      expect(d.resync, isTrue);
    });

    test('unplugging in a video call goes to the speaker, in a voice call '
        'stays on the earpiece', () {
      final video = decideCallAudioRoute(
        speakerOn: false,
        cameraOn: true,
        route: _route(CallAudioRouteReason.oldDevice),
      );
      expect(video.speakerOn, isTrue);
      expect(video.resync, isTrue);

      final voice = decideCallAudioRoute(
        speakerOn: false,
        cameraOn: false,
        route: _route(CallAudioRouteReason.oldDevice),
      );
      expect(voice.speakerOn, isNull);
      expect(voice.resync, isFalse);
    });

    test('a device dropping while on the speaker, or with another headset '
        'left, changes nothing', () {
      for (final (speakerOn, headset) in [(true, false), (false, true)]) {
        final d = decideCallAudioRoute(
          speakerOn: speakerOn,
          cameraOn: false,
          route: _route(CallAudioRouteReason.oldDevice,
              speaker: speakerOn, headset: headset),
        );
        expect(d.speakerOn, isNull);
        expect(d.resync, isFalse);
      }
    });

    test('the CallKit / Control Center speaker button is adopted as a choice',
        () {
      final d = decideCallAudioRoute(
        speakerOn: false,
        cameraOn: false,
        route: _route(CallAudioRouteReason.override, speaker: true),
      );
      expect(d.speakerOn, isTrue);
      expect(d.userChosen, isTrue);
    });

    test('an echo of our own write, or a foreign category rewrite, is undone, '
        'never adopted', () {
      for (final r in [
        _route(CallAudioRouteReason.override, speaker: false, echo: true),
        _route(CallAudioRouteReason.category, speaker: false),
      ]) {
        final d = decideCallAudioRoute(
          speakerOn: true,
          cameraOn: true,
          route: r,
        );
        expect(d.speakerOn, isNull, reason: '$r');
        expect(d.resync, isTrue, reason: '$r');
      }
    });

    test('a route that matches, or no route at all, changes nothing', () {
      for (final r in [
        _route(CallAudioRouteReason.category, speaker: true),
        _route(CallAudioRouteReason.override, speaker: false, output: 'none'),
        _route(CallAudioRouteReason.other, speaker: false),
      ]) {
        final d = decideCallAudioRoute(
          speakerOn: true,
          cameraOn: true,
          route: r,
        );
        expect(d.speakerOn, isNull, reason: '$r');
        expect(d.resync, isFalse, reason: '$r');
      }
    });

    test('parses the native map', () {
      final r = CallAudioRoute.fromMap(const {
        'speaker': true,
        'headset': true,
        'output': 'speaker',
        'reason': 'override',
        'echo': true,
      });
      expect(r.speaker, isTrue);
      expect(r.headset, isTrue);
      expect(r.reason, CallAudioRouteReason.override);
      expect(r.echo, isTrue);
      expect(
        CallAudioRoute.fromMap(const {'reason': 'wakeFromSleep'}).reason,
        CallAudioRouteReason.other,
      );
    });
  });

  group('CallService speaker follows the real route', () {
    test('a video call with AirPods in stays on the AirPods, and the button '
        'says so', () async {
      final (service, router) = await _ringing('video');
      addTearDown(service.dispose);
      router.headset = true;
      expect(service.session?.speakerOn, isTrue);

      // Any reassert: the default speaker loses to the headset.
      service.handleCallAudioRoute(
          _route(CallAudioRouteReason.category, headset: true));
      await _settle();
      expect(router.applies.last, (speaker: true, headsetWins: true));
      expect(service.session?.speakerOn, isFalse);
    });

    test('a tap reaches the speaker over AirPods and keeps it through '
        'reasserts', () async {
      final (service, router) = await _ringing('audio');
      addTearDown(service.dispose);
      router.headset = true;

      await service.toggleSpeaker();
      expect(router.applies.last, (speaker: true, headsetWins: false));
      expect(service.session?.speakerOn, isTrue);

      // A foreign rewrite dropped the override: put it back, still as the
      // user's choice.
      service.handleCallAudioRoute(
          _route(CallAudioRouteReason.category, headset: true));
      await _settle();
      expect(router.applies.last, (speaker: true, headsetWins: false));
      expect(service.session?.speakerOn, isTrue);
    });

    test('the system speaker button flips the in-app one', () async {
      final (service, router) = await _ringing('audio');
      addTearDown(service.dispose);
      expect(service.session?.speakerOn, isFalse);

      service.handleCallAudioRoute(
          _route(CallAudioRouteReason.override, speaker: true));
      await _settle();
      expect(service.session?.speakerOn, isTrue);
      expect(router.applies.last, (speaker: true, headsetWins: false));

      service.handleCallAudioRoute(
          _route(CallAudioRouteReason.override, speaker: false));
      await _settle();
      expect(service.session?.speakerOn, isFalse);
    });

    test('plugging in a headset moves a speaker call onto it', () async {
      final (service, router) = await _ringing('video');
      addTearDown(service.dispose);
      router.headset = true;

      service.handleCallAudioRoute(_route(CallAudioRouteReason.newDevice,
          speaker: true, headset: true));
      await _settle();
      expect(service.session?.speakerOn, isFalse);
      expect(router.applies.last, (speaker: false, headsetWins: true));
    });

    test('a call still ringing leaves the route alone: a group call holding '
        'the session owns it', () async {
      final (service, router) = await _ringing('video', mediaUp: false);
      addTearDown(service.dispose);
      final before = router.applies.length;
      for (final r in [
        _route(CallAudioRouteReason.category, headset: true),
        _route(CallAudioRouteReason.override, speaker: false),
        _route(CallAudioRouteReason.newDevice, speaker: true, headset: true),
      ]) {
        service.handleCallAudioRoute(r);
        await _settle();
      }
      // No resync of this call's default against the group's route, and
      // the button keeps the ring's default.
      expect(router.applies.length, before);
      expect(service.session?.speakerOn, isTrue);
    });

    test('a report while our own write is in flight is ignored', () async {
      final (service, router) = await _ringing('audio');
      addTearDown(service.dispose);
      router.gate = Completer<void>();

      final tap = service.toggleSpeaker();
      expect(service.session?.speakerOn, isTrue);
      // The route from before the write lands mid-write: it must not undo
      // the tap.
      service.handleCallAudioRoute(
          _route(CallAudioRouteReason.override, speaker: false));
      router.gate!.complete();
      router.gate = null;
      await tap;
      expect(service.session?.speakerOn, isTrue);
      expect(router.applies, hasLength(1));
    });

    test('an output that refuses the override cannot ping-pong', () async {
      final (service, router) = await _ringing('video');
      addTearDown(service.dispose);
      for (var i = 0; i < 6; i++) {
        service.handleCallAudioRoute(_route(CallAudioRouteReason.override,
            speaker: false, output: 'car', echo: true));
        await _settle();
      }
      expect(router.applies.length, 2);
      expect(service.session?.speakerOn, isTrue);
    });

    test('every apply names its call, so iOS can tell an earlier call\'s '
        'teardown belt from this call\'s end', () async {
      final (service, router) = await _ringing('audio');
      addTearDown(service.dispose);
      await service.toggleSpeaker();
      service.handleCallAudioRoute(
          _route(CallAudioRouteReason.category, speaker: false));
      await _settle();
      expect(router.callIds, isNotEmpty);
      expect(router.callIds, everyElement('c1'));
    });
  });
}
