import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monkeyhub/widgets/progress_ring.dart';

/// The shared ring, checked by what it paints rather than by pixels.
void main() {
  Widget host(Widget ring) => Directionality(
        textDirection: TextDirection.ltr,
        child: Center(child: SizedBox(width: 60, height: 60, child: ring)),
      );

  /// The ring's painter, for matchers on `paints`.
  Finder ringPaint() => find.descendant(
        of: find.byType(ProgressRing),
        matching: find.byType(CustomPaint),
      );

  testWidgets('paints an arc sweeping progress * 360 from 12 o\'clock', (t) async {
    await t.pumpWidget(host(
      const ProgressRing(progress: 0.25, color: Color(0xFFFFFFFF)),
    ));
    expect(
      ringPaint(),
      paints
        ..arc(
          startAngle: -1.5707963267948966,
          sweepAngle: 0.25 * 6.283185307179586,
          useCenter: false,
        ),
    );
  });

  testWidgets('zero progress paints no arc, but still its track', (t) async {
    await t.pumpWidget(host(const ProgressRing(
      progress: 0,
      color: Color(0xFFFFFFFF),
      trackColor: Color(0x33FFFFFF),
    )));
    expect(ringPaint(), paintsExactlyCountTimes(#drawOval, 1));
    expect(ringPaint(), paintsExactlyCountTimes(#drawArc, 0));
  });

  testWidgets('fadeIn ramps the alpha over the first fifth of the sweep', (t) async {
    await t.pumpWidget(host(const ProgressRing(
      progress: 0.1,
      color: Color(0xFFFFFFFF),
      opacity: 0.9,
      fadeIn: true,
    )));
    // 0.1 * 5 = 0.5 of the way in, times the 0.9 opacity.
    expect(
      ringPaint(),
      paints..arc(color: const Color(0xFFFFFFFF).withValues(alpha: 0.45)),
    );
  });

  testWidgets('animated repaints from the animation with no rebuild', (t) async {
    final c = AnimationController(vsync: t, value: 0.5);
    addTearDown(c.dispose);
    var builds = 0;
    await t.pumpWidget(host(Builder(builder: (_) {
      builds++;
      return ProgressRing.animated(animation: c, color: const Color(0xFFFFFFFF));
    })));
    expect(ringPaint(), paints..arc(sweepAngle: 0.5 * 6.283185307179586));
    c.value = 1;
    await t.pump();
    expect(ringPaint(), paints..arc(sweepAngle: 6.283185307179586));
    expect(builds, 1);
  });
}
