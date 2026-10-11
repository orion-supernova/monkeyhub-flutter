import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:monkeyhub/calls/call_media.dart';

/// Records what the Android branch of applyCallAudio asks flutter_webrtc and
/// the call window for, in order.
class _Calls {
  final List<String> log = [];
  final List<({bool keepScreenOn, bool proximity})> window = [];

  void install() {
    androidSetSpeakerphoneOn = (enable) async => log.add('speaker($enable)');
    androidSetSpeakerphoneButPreferHeadset =
        () async => log.add('speakerUnlessHeadset');
    androidCallWindowSink = (state) async => window.add(state);
  }
}

class _FakePc extends Fake implements RTCPeerConnection {
  int disposed = 0;

  @override
  Future<void> dispose() async => disposed++;
}

/// A dispose that takes as long as the test says.
class _SlowPc extends Fake implements RTCPeerConnection {
  _SlowPc(this.done);
  final Future<void> done;
  bool started = false;

  @override
  Future<void> dispose() {
    started = true;
    return done;
  }
}

void main() {
  late _Calls calls;

  setUp(() {
    resetAndroidCallRoute();
    calls = _Calls()..install();
  });

  tearDown(() {
    resetAndroidCallRoute();
    debugReleasePeerConnectionsOverride = null;
    releasePeerConnectionDelay = const Duration(milliseconds: 600);
  });

  group('androidCallRouteFor', () {
    test('speaker off is the earpiece (headset first), whatever came before', () {
      for (final previous in [null, ...AndroidCallRoute.values]) {
        expect(
          androidCallRouteFor(speakerOn: false, previous: previous),
          AndroidCallRoute.earpiece,
        );
      }
    });

    test('a video call starts on the speaker unless a headset is in', () {
      expect(
        androidCallRouteFor(speakerOn: true, previous: null),
        AndroidCallRoute.speakerUnlessHeadset,
      );
    });

    test('a re-assert of the default stays the default', () {
      expect(
        androidCallRouteFor(
          speakerOn: true,
          previous: AndroidCallRoute.speakerUnlessHeadset,
        ),
        AndroidCallRoute.speakerUnlessHeadset,
      );
    });

    test('switching from the earpiece to the speaker forces it, and it stays forced', () {
      final forced = androidCallRouteFor(
        speakerOn: true,
        previous: AndroidCallRoute.earpiece,
      );
      expect(forced, AndroidCallRoute.forceSpeaker);
      expect(
        androidCallRouteFor(speakerOn: true, previous: forced),
        AndroidCallRoute.forceSpeaker,
      );
    });

    test('a known default never forces: the camera coming on keeps the earbuds', () {
      // Earpiece -> speaker is what the camera coming on looks like; the
      // service says it is a default (headsetWins), so a headset still wins.
      expect(
        androidCallRouteFor(
          speakerOn: true,
          previous: AndroidCallRoute.earpiece,
          headsetWins: true,
        ),
        AndroidCallRoute.speakerUnlessHeadset,
      );
    });

    test('a known tap forces the speaker even from the video default', () {
      expect(
        androidCallRouteFor(
          speakerOn: true,
          previous: AndroidCallRoute.speakerUnlessHeadset,
          headsetWins: false,
        ),
        AndroidCallRoute.forceSpeaker,
      );
      expect(
        androidCallRouteFor(
          speakerOn: false,
          previous: AndroidCallRoute.forceSpeaker,
          headsetWins: false,
        ),
        AndroidCallRoute.earpiece,
      );
    });
  });

  group('applyAndroidCallRoute', () {
    test('voice call: earpiece, screen on, proximity on', () async {
      await applyAndroidCallRoute(speakerOn: false);
      expect(calls.log, ['speaker(false)']);
      expect(calls.window, [(keepScreenOn: true, proximity: true)]);
    });

    test('video call: first ask reorders to speaker, then lets a headset win', () async {
      await applyAndroidCallRoute(speakerOn: true, video: true);
      expect(calls.log, ['speaker(true)', 'speakerUnlessHeadset']);
      expect(calls.window, [(keepScreenOn: true, proximity: false)]);
    });

    test('a mid-call re-assert never hops through the speaker', () async {
      await applyAndroidCallRoute(speakerOn: true, video: true);
      calls.log.clear();
      await applyAndroidCallRoute(speakerOn: true, video: true);
      expect(calls.log, ['speakerUnlessHeadset']);
      // Nothing changed for the screen either, so no platform hop.
      expect(calls.window.length, 1);
    });

    test('the user toggling earpiece then speaker forces the loudspeaker', () async {
      await applyAndroidCallRoute(speakerOn: true, video: true);
      await applyAndroidCallRoute(speakerOn: false, video: true);
      calls.log.clear();
      await applyAndroidCallRoute(speakerOn: true, video: true);
      await applyAndroidCallRoute(speakerOn: true, video: true);
      expect(calls.log, ['speaker(true)', 'speaker(true)']);
      expect(debugAndroidCallRoute, AndroidCallRoute.forceSpeaker);
    });

    test('a voice call on the speaker drops the proximity sensor', () async {
      await applyAndroidCallRoute(speakerOn: false);
      await applyAndroidCallRoute(speakerOn: true);
      expect(calls.window, [
        (keepScreenOn: true, proximity: true),
        (keepScreenOn: true, proximity: false),
      ]);
    });

    test('a failing platform call is swallowed', () async {
      androidSetSpeakerphoneOn = (_) async => throw Exception('no channel');
      await applyAndroidCallRoute(speakerOn: false);
      expect(debugAndroidCallRoute, AndroidCallRoute.earpiece);
    });
  });

  group('resetAndroidCallRoute', () {
    test('gives the screen back and starts the next call from its default', () async {
      await applyAndroidCallRoute(speakerOn: false);
      await applyAndroidCallRoute(speakerOn: true);
      expect(debugAndroidCallRoute, AndroidCallRoute.forceSpeaker);
      resetAndroidCallRoute();
      await pumpEventQueue();
      expect(debugAndroidCallRoute, isNull);
      expect(calls.window.last, (keepScreenOn: false, proximity: false));
      calls.log.clear();
      await applyAndroidCallRoute(speakerOn: true, video: true);
      expect(calls.log, ['speaker(true)', 'speakerUnlessHeadset']);
    });

    test('with no call up it touches nothing', () async {
      resetAndroidCallRoute();
      await pumpEventQueue();
      expect(calls.window, isEmpty);
    });
  });

  group('releasePeerConnection', () {
    test('disposes on Android, after the screen has had its moment', () async {
      debugReleasePeerConnectionsOverride = true;
      releasePeerConnectionDelay = const Duration(milliseconds: 20);
      final pc = _FakePc();
      releasePeerConnection(pc);
      expect(pc.disposed, 0);
      await Future<void>.delayed(const Duration(milliseconds: 60));
      expect(pc.disposed, 1);
    });

    test('never on iOS, where dispose would deactivate the CallKit session', () async {
      debugReleasePeerConnectionsOverride = false;
      releasePeerConnectionDelay = Duration.zero;
      final pc = _FakePc();
      releasePeerConnection(pc);
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(pc.disposed, 0);
    });

    // AudioSwitch stops when the plugin's last peer connection is disposed.
    // A new call that brought its mic up inside the old one's 600 ms wait
    // had that stop land under it, mid-call. The flush puts the stop first.
    test('a flush disposes the waiting connections now, once', () async {
      debugReleasePeerConnectionsOverride = true;
      releasePeerConnectionDelay = const Duration(milliseconds: 40);
      final a = _FakePc();
      final b = _FakePc();
      releasePeerConnection(a);
      releasePeerConnection(b);
      releasePeerConnection(a); // released twice is still one dispose
      expect(debugPendingPeerConnectionReleases, 2);
      await flushPeerConnectionReleases();
      expect(a.disposed, 1);
      expect(b.disposed, 1);
      expect(debugPendingPeerConnectionReleases, 0);
      // The delayed dispose it replaced never runs a second one.
      await Future<void>.delayed(const Duration(milliseconds: 80));
      expect(a.disposed, 1);
      expect(b.disposed, 1);
    });

    test('a flush waits for a dispose already under way', () async {
      debugReleasePeerConnectionsOverride = true;
      releasePeerConnectionDelay = Duration.zero;
      final gate = Completer<void>();
      final pc = _SlowPc(gate.future);
      releasePeerConnection(pc);
      await Future<void>.delayed(const Duration(milliseconds: 5));
      expect(pc.started, isTrue);
      var flushed = false;
      unawaited(flushPeerConnectionReleases().then((_) => flushed = true));
      await Future<void>.delayed(const Duration(milliseconds: 5));
      expect(flushed, isFalse);
      gate.complete();
      await Future<void>.delayed(const Duration(milliseconds: 5));
      expect(flushed, isTrue);
      expect(debugPendingPeerConnectionReleases, 0);
    });

    test('with nothing waiting a flush costs nothing', () async {
      await flushPeerConnectionReleases();
      expect(debugPendingPeerConnectionReleases, 0);
    });
  });
}
