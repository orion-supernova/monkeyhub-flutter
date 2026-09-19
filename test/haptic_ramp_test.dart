import 'package:flutter/animation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monkeyhub/widgets/haptic_ramp.dart';

/// The send button's hold-to-schedule vibration, driven by hand.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late List<String> haptics;
  late AnimationController progress;
  late HapticRamp ramp;

  setUp(() {
    haptics = [];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'HapticFeedback.vibrate') {
        haptics.add('${call.arguments}'.replaceFirst('HapticFeedbackType.', ''));
      }
      return null;
    });
    progress = AnimationController(vsync: const TestVSync());
    ramp = HapticRamp(progress);
  });

  tearDown(() {
    ramp.dispose();
    progress.dispose();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null);
  });

  /// A charge in [steps] even frames, from just past zero to full.
  void charge({int steps = 60}) {
    for (var i = 1; i <= steps; i++) {
      progress.value = i / steps;
    }
  }

  test('a full charge plays every tap once, soft to firm', () {
    charge();
    expect(haptics, [
      ...List.filled(4, 'selectionClick'),
      ...List.filled(4, 'lightImpact'),
      ...List.filled(4, 'mediumImpact'),
    ]);
  });

  test('never plays the heavy impact — that beat is the owner\'s', () {
    charge();
    expect(haptics, isNot(contains('heavyImpact')));
  });

  test('a frame that skips several marks plays one tap, not a burst', () {
    progress.value = 0.9;
    expect(haptics, hasLength(1));
  });

  test('at rest it is silent', () {
    progress.value = 0;
    expect(haptics, isEmpty);
  });

  test('letting go re-arms it, so the next hold starts soft again', () {
    progress.value = 0.95;
    haptics.clear();

    progress.value = 0;
    charge();
    expect(haptics.first, 'selectionClick');
    expect(haptics, hasLength(12));
  });

  test('disposed, it stops listening', () {
    ramp.dispose();
    charge();
    expect(haptics, isEmpty);
  });
}
