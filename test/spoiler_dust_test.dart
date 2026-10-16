import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monkeyhub/widgets/dust/spoiler_dust.dart';

/// The ambient spoiler's cost contract: it ticks only while it is meant to
/// move, and leaves nothing running behind it.
void main() {
  Widget host({bool calm = false, bool ticking = true, bool show = true}) =>
      MediaQuery(
        data: MediaQueryData(disableAnimations: calm),
        child: TickerMode(
          enabled: ticking,
          child: Center(
            child: SizedBox(
              width: 120,
              height: 120,
              child: show ? const SpoilerDust(oval: true) : null,
            ),
          ),
        ),
      );

  testWidgets('moves: frames keep coming', (tester) async {
    await tester.pumpWidget(host());
    await tester.pump(const Duration(milliseconds: 16));
    expect(tester.binding.hasScheduledFrame, isTrue);
    await tester.pumpWidget(host(show: false));
    await tester.pump(const Duration(milliseconds: 16));
    expect(tester.binding.hasScheduledFrame, isFalse);
  });

  testWidgets('reduced motion: one still speckle, no ticker', (tester) async {
    await tester.pumpWidget(host(calm: true));
    await tester.pump(const Duration(milliseconds: 16));
    expect(tester.binding.hasScheduledFrame, isFalse);
    expect(find.byType(SpoilerDust), findsOneWidget);
  });

  testWidgets('covered (TickerMode off): no frames', (tester) async {
    await tester.pumpWidget(host(ticking: false));
    await tester.pump(const Duration(milliseconds: 16));
    expect(tester.binding.hasScheduledFrame, isFalse);
  });
}
