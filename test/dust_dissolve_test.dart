import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monkeyhub/widgets/dust_dissolve.dart';

/// The dissolve's life cycle, with the frames pumped by hand: it must reach
/// `onDone` in bounded time on every path, hide the child while it burns,
/// and give the child back when it is switched off.
void main() {
  Widget host(Widget child, {bool calm = false}) => MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(disableAnimations: calm),
          child: Scaffold(
            body: Align(
              alignment: Alignment.topLeft,
              child: SizedBox(width: 120, height: 120, child: child),
            ),
          ),
        ),
      );

  Widget subject({
    required bool active,
    required VoidCallback onDone,
    Widget? beneath,
  }) =>
      DustDissolve(
        active: active,
        shape: const CircleBorder(),
        onDone: onDone,
        beneath: beneath,
        child: const ColoredBox(
          key: ValueKey('child'),
          color: Color(0xFF3060F0),
        ),
      );

  Future<void> pumpFor(WidgetTester tester, Duration total) async {
    const step = Duration(milliseconds: 16);
    for (var t = Duration.zero; t < total; t += step) {
      await tester.pump(step);
    }
  }

  testWidgets('burns, hides the child, and calls onDone once', (tester) async {
    var done = 0;
    await tester.pumpWidget(host(subject(active: false, onDone: () => done++)));
    expect(find.byKey(const ValueKey('child')), findsOneWidget);

    await tester.pumpWidget(host(subject(
      active: true,
      onDone: () => done++,
      beneath: const Text('under'),
    )));
    // The frame that paints the child one last time, then the capture.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 16));
    expect(find.byKey(const ValueKey('child')), findsNothing);
    expect(find.text('under'), findsOneWidget);
    // The box keeps its size while the dust flies.
    expect(tester.getSize(find.byType(DustDissolve)), const Size(120, 120));
    expect(done, 0);

    await pumpFor(
      tester,
      DustDissolve.defaultDuration + const Duration(milliseconds: 100),
    );
    expect(done, 1);
    await pumpFor(tester, const Duration(milliseconds: 200));
    expect(done, 1);
  });

  testWidgets('reduced motion: a short fade, then onDone', (tester) async {
    var done = 0;
    await tester.pumpWidget(
      host(subject(active: true, onDone: () => done++), calm: true),
    );
    await tester.pump();
    await pumpFor(
      tester,
      DustDissolve.calmDuration + const Duration(milliseconds: 50),
    );
    expect(done, 1);
  });

  testWidgets('switched off mid-burn, the child comes back', (tester) async {
    var done = 0;
    await tester.pumpWidget(host(subject(active: true, onDone: () => done++)));
    await tester.pump();
    await pumpFor(tester, const Duration(milliseconds: 300));
    expect(find.byKey(const ValueKey('child')), findsNothing);

    await tester.pumpWidget(host(subject(active: false, onDone: () => done++)));
    await tester.pump();
    expect(find.byKey(const ValueKey('child')), findsOneWidget);
    await pumpFor(tester, DustDissolve.defaultDuration);
    expect(done, 0);
  });

  testWidgets('removed mid-burn: nothing left running', (tester) async {
    await tester.pumpWidget(host(subject(active: true, onDone: () {})));
    await tester.pump();
    await pumpFor(tester, const Duration(milliseconds: 200));
    await tester.pumpWidget(host(const SizedBox()));
    await pumpFor(tester, const Duration(milliseconds: 100));
    expect(tester.binding.hasScheduledFrame, isFalse);
  });
}
