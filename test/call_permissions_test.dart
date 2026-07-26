@TestOn('vm')
library;

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monkeyhub/calls/call_models.dart';
import 'package:monkeyhub/calls/call_permissions.dart';

/// Guards the gate that stands between a call and a process kill.
///
/// flutter_callkit_incoming 3.x starts a foreground service typed
/// `phoneCall|microphone[|camera]` on both call-start and call-accept. On
/// Android 14 that throws SecurityException out of `Service.onStartCommand` —
/// killing the app — unless RECORD_AUDIO (and CAMERA, for video) are already
/// granted. So "did we ask before letting a call exist?" is a correctness
/// property, not a UX one, and these tests pin it.
///
/// [CallPermissions.debugForceApplies] is what makes the Android branch
/// reachable here: on a VM host `Platform.isAndroid` is false and every method
/// would short-circuit to "granted" and assert nothing.
void main() {
  const channel = MethodChannel('monkeyhub/device');

  late List<MethodCall> calls;
  // Keyed by the `video` argument, so a test can grant audio and deny camera.
  late bool audioGranted;
  late bool cameraGranted;
  late bool grantOnRequest;

  void install() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      final video = (call.arguments as Map?)?['video'] == true;
      switch (call.method) {
        case 'hasCallPermissions':
          return video ? audioGranted && cameraGranted : audioGranted;
        case 'requestCallPermissions':
          if (grantOnRequest) {
            audioGranted = true;
            if (video) cameraGranted = true;
          }
          return grantOnRequest;
        case 'openAppSettings':
          return true;
      }
      return null;
    });
  }

  setUp(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    CallPermissions.debugForceApplies = true;
    calls = [];
    audioGranted = false;
    cameraGranted = false;
    grantOnRequest = false;
    install();
  });

  tearDown(() {
    CallPermissions.debugForceApplies = null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  group('granted', () {
    test('an audio call does not require the camera', () async {
      audioGranted = true;
      cameraGranted = false;

      expect(await CallPermissions.granted(CallMediaKind.audio), isTrue);
      expect(
        calls.single.arguments,
        {'video': false},
        reason: 'asking for camera on a voice call trains users to tap Deny',
      );
    });

    test('a video call requires the camera too', () async {
      audioGranted = true;
      cameraGranted = false;

      expect(await CallPermissions.granted(CallMediaKind.video), isFalse);

      cameraGranted = true;
      expect(await CallPermissions.granted(CallMediaKind.video), isTrue);
    });

    // The value feeds callingNotification.showNotification. Guessing "true"
    // wrong costs the whole process; guessing "false" wrong costs one call's
    // foreground service. So an unreachable channel must report false.
    test('an unreachable channel reports false, never true', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
        throw MissingPluginException('no such method');
      });

      expect(await CallPermissions.granted(CallMediaKind.audio), isFalse);
    });
  });

  group('ensure', () {
    test('already granted asks for nothing', () async {
      audioGranted = true;

      expect(await CallPermissions.ensure(CallMediaKind.audio), isTrue);
      expect(
        calls.map((c) => c.method),
        ['hasCallPermissions'],
        reason: 'no prompt when the grant is already held',
      );
    });

    test('prompts once and proceeds when the user allows', () async {
      grantOnRequest = true;

      expect(await CallPermissions.ensure(CallMediaKind.audio), isTrue);
      expect(
        calls.map((c) => c.method),
        containsAllInOrder(['hasCallPermissions', 'requestCallPermissions']),
      );
      expect(
        calls.where((c) => c.method == 'requestCallPermissions').length,
        1,
      );
    });

    // The call must be refused rather than started degraded — a voice call
    // without a microphone is not a call, and starting one would also hand the
    // foreground service a type it has no grant for.
    test('a denial refuses the call', () async {
      grantOnRequest = false;

      expect(await CallPermissions.ensure(CallMediaKind.audio), isFalse);
    });

    test('a video call asks for both permissions at once', () async {
      grantOnRequest = true;

      expect(await CallPermissions.ensure(CallMediaKind.video), isTrue);
      final request =
          calls.firstWhere((c) => c.method == 'requestCallPermissions');
      expect(request.arguments, {'video': true});
    });
  });

  group('preGrantMicrophone', () {
    test('never asks for the camera', () async {
      grantOnRequest = true;

      await CallPermissions.preGrantMicrophone();

      final request =
          calls.firstWhere((c) => c.method == 'requestCallPermissions');
      expect(request.arguments, {'video': false});
    });

    test('stays silent when the microphone is already granted', () async {
      audioGranted = true;

      await CallPermissions.preGrantMicrophone();

      expect(calls.map((c) => c.method), ['hasCallPermissions']);
    });
  });

  test('off Android everything is permitted and nothing is asked', () async {
    CallPermissions.debugForceApplies = false;

    expect(await CallPermissions.granted(CallMediaKind.video), isTrue);
    expect(await CallPermissions.ensure(CallMediaKind.video), isTrue);
    await CallPermissions.preGrantMicrophone();
    expect(calls, isEmpty);
  });
}
