import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monkeyhub/calls/widgets/call_chrome.dart';

/// Once a voice call is up the aura follows the peer's voice instead of a
/// clock: frames while they talk, none while the line is quiet. The steady
/// pulse before this redrew the screen (and the tray's backdrop blur) every
/// frame for the whole call.
void main() {
  Widget rings(ValueNotifier<double> level, {bool animate = false}) =>
      Directionality(
        textDirection: TextDirection.ltr,
        child: Center(
          child: PulseRings(
            accent: Colors.blue,
            diameter: 100,
            animate: animate,
            voiceLevel: level,
            child: const SizedBox(width: 100, height: 100),
          ),
        ),
      );

  testWidgets('a quiet line schedules no frames', (tester) async {
    final level = ValueNotifier<double>(0);
    addTearDown(level.dispose);
    await tester.pumpWidget(rings(level));
    await tester.pump();
    expect(tester.binding.hasScheduledFrame, isFalse);
  });

  testWidgets('a word swells the aura, and it settles when the voice ends',
      (tester) async {
    final level = ValueNotifier<double>(0);
    addTearDown(level.dispose);
    await tester.pumpWidget(rings(level));

    level.value = 0.4;
    await tester.pump();
    expect(tester.binding.hasScheduledFrame, isTrue);
    // While they talk the blobs drift: a live state, so it keeps drawing.
    await tester.pump(const Duration(seconds: 1));
    expect(tester.binding.hasScheduledFrame, isTrue);
    // Silence: it eases out and stops asking for frames, not a loop.
    level.value = 0;
    await tester.pumpAndSettle();
    expect(tester.binding.hasScheduledFrame, isFalse);
  });

  testWidgets('a line\'s hiss draws no aura and schedules no frames',
      (tester) async {
    final level = ValueNotifier<double>(0);
    addTearDown(level.dispose);
    await tester.pumpWidget(rings(level));
    level.value = 0.015;
    await tester.pumpAndSettle();
    expect(tester.binding.hasScheduledFrame, isFalse);
  });

  testWidgets('switching from the waiting pulse to voice mode stops the clock',
      (tester) async {
    final level = ValueNotifier<double>(0);
    addTearDown(level.dispose);
    await tester.pumpWidget(rings(level, animate: true));
    await tester.pump(const Duration(milliseconds: 100));
    expect(tester.binding.hasScheduledFrame, isTrue);

    await tester.pumpWidget(rings(level));
    await tester.pump();
    expect(tester.binding.hasScheduledFrame, isFalse);
  });
}
