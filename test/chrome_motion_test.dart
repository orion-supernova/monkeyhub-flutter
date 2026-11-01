import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monkeyhub/widgets/chrome_motion.dart';

/// The chat chrome's motion kit: kicks fire on a change and never on the
/// first build, and every move comes to rest (a move that never settles hangs
/// `pumpAndSettle` and burns frames in a real room).
void main() {
  Widget host(Object trigger, {GlyphKick kick = GlyphKick.dip}) => Directionality(
        textDirection: TextDirection.ltr,
        child: Center(
          child: KickGlyph(
            kick: kick,
            trigger: trigger,
            child: const SizedBox(width: 10, height: 10),
          ),
        ),
      );

  Transform? moving(WidgetTester tester) {
    final t = find.descendant(
      of: find.byType(KickGlyph),
      matching: find.byType(Transform),
    );
    return t.evaluate().isEmpty ? null : tester.widget<Transform>(t.first);
  }

  testWidgets('the first build never kicks', (tester) async {
    await tester.pumpWidget(host(0));
    await tester.pump(const Duration(milliseconds: 100));
    expect(moving(tester), isNull);
  });

  for (final kick in GlyphKick.values) {
    testWidgets('$kick moves on a change, then comes home', (tester) async {
      await tester.pumpWidget(host(0, kick: kick));
      await tester.pumpWidget(host(1, kick: kick));
      await tester.pump(const Duration(milliseconds: 120));
      expect(moving(tester), isNotNull);
      await tester.pumpAndSettle();
      expect(moving(tester), isNull);
    });
  }

  testWidgets('the rail and the close glyph draw in and settle', (tester) async {
    await tester.pumpWidget(const Directionality(
      textDirection: TextDirection.ltr,
      child: Row(children: [
        SizedBox(height: 30, child: ContextRail(color: Colors.blue, animateIn: true)),
        DrawnCloseGlyph(color: Colors.white),
      ]),
    ));
    await tester.pumpAndSettle();
  });

  testWidgets('SlideSwap swaps keyed content and settles', (tester) async {
    Widget swap(String text) => Directionality(
          textDirection: TextDirection.ltr,
          child: SlideSwap(child: Text(text, key: ValueKey(text))),
        );
    await tester.pumpWidget(swap('a'));
    await tester.pumpWidget(swap('b'));
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('a'), findsOneWidget);
    expect(find.text('b'), findsOneWidget);
    await tester.pumpAndSettle();
    expect(find.text('a'), findsNothing);
  });
}
