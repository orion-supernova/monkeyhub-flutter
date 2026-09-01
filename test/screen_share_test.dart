import 'package:flutter_test/flutter_test.dart';
import 'package:monkeyhub/calls/screen_share.dart';
import 'package:monkeyhub/privacy/capture_protection.dart';

import 'fakes/fake_webrtc.dart';

/// The platform side of a share, off the platform.
///
/// The Android sequence — consent, then a typed foreground service, then the
/// capture — is what Android 14 checks; the FLAG_SECURE suspension is what
/// keeps our own outgoing picture from being black. Neither can be seen from
/// a test on a Mac, so the seams record what would have been asked.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('capture protection is lifted for the share and restored after', () {
    final cp = CaptureProtection.instance;
    cp.setUserEnabled(true);
    expect(cp.active, isTrue);
    cp.suspend();
    expect(cp.active, isFalse);
    expect(cp.suspended, isTrue);
    expect(cp.userEnabled, isTrue, reason: 'the preference is untouched');
    cp.resume();
    expect(cp.active, isTrue);
    cp.setUserEnabled(false);
  });

  test('a scope still counts as protection, and as a warning', () async {
    final cp = CaptureProtection.instance;
    await cp.pushScope();
    expect(cp.scopeActive, isTrue);
    expect(cp.active, isTrue);
    cp.suspend();
    expect(cp.active, isFalse);
    expect(cp.scopeActive, isTrue, reason: 'the room is still ephemeral');
    cp.resume();
    await cp.popScope();
    expect(cp.scopeActive, isFalse);
  });

  test('capture asks for the picked desktop source at a screen frame rate',
      () async {
    Map<String, dynamic>? asked;
    ScreenShare.getDisplayMediaFn = (c) async {
      asked = c;
      return FakeMediaStream([FakeMediaStreamTrack(kind: 'video')]);
    };
    await ScreenShare.capture(
      source: const ScreenShareSource(id: 'win-7', name: 'Notes', isWindow: true),
    );
    final video = asked!['video'] as Map<String, dynamic>;
    expect(video['deviceId'], {'exact': 'win-7'});
    expect((video['mandatory'] as Map)['frameRate'], 15.0);
    expect(asked!['audio'], isFalse);
  });

  test('prepare suspends protection and release restores it', () async {
    final calls = <String>[];
    ScreenShare.invokeFn = (m, [a]) async {
      calls.add(m);
      return null;
    };
    final cp = CaptureProtection.instance;
    cp.setUserEnabled(true);
    await ScreenShare.prepare(
      notificationTitle: 't',
      notificationBody: 'b',
      notificationStop: 's',
    );
    expect(cp.active, isFalse);
    await ScreenShare.release();
    expect(cp.active, isTrue);
    // Off Android nothing is asked of the platform for the share itself.
    expect(calls.where((c) => c == 'start' || c == 'stop'), isEmpty);
    cp.setUserEnabled(false);
  });
}
