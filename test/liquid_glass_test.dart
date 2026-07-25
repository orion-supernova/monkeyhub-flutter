import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monkeyhub/theme/basic_theme.dart';
import 'package:monkeyhub/theme/theme_scope.dart';
import 'package:monkeyhub/widgets/liquid_glass.dart';

/// LiquidGlass is the shared chrome surface for the compact chat style — the
/// header title capsule, the composer field and the round buttons all sit
/// inside one. Its internal Stack sizes to the content child, so
/// whether that child expands decides whether a capsule hugs its label or
/// paints a full-width slab. Getting that wrong is not subtle and it has
/// regressed once already (the header capsule grew a defensive IntrinsicWidth),
/// hence these tests.
void main() {
  Widget host(Widget child, {double width = 800}) => MaterialApp(
        home: ThemeScope(
          controller: ThemeController(BasicTheme.midnight()),
          child: Scaffold(
            body: Center(
              child: SizedBox(width: width, child: Center(child: child)),
            ),
          ),
        ),
      );

  testWidgets('without an explicit size the glass hugs its child',
      (tester) async {
    await tester.pumpWidget(host(
      const LiquidGlass(
        shape: LiquidGlassShape.capsule,
        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        child: SizedBox(width: 100, height: 20),
      ),
    ));

    // 100 of child + 12 padding either side. NOT the 800 on offer.
    expect(tester.getSize(find.byType(LiquidGlass)).width, 124);
  });

  testWidgets('a hugging glass still lets a flexible child ellipsize at the '
      'width on offer', (tester) async {
    await tester.pumpWidget(host(
      LiquidGlass(
        shape: LiquidGlassShape.capsule,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: Text('x' * 4000, maxLines: 1, overflow: TextOverflow.ellipsis),
            ),
          ],
        ),
      ),
      width: 300,
    ));

    // Clamped by the parent rather than overflowing it.
    expect(tester.getSize(find.byType(LiquidGlass)).width, lessThanOrEqualTo(300));
    expect(tester.takeException(), isNull);
  });

  testWidgets('an explicit size still pins the box and centres the child',
      (tester) async {
    await tester.pumpWidget(host(
      const LiquidGlass(
        shape: LiquidGlassShape.circle,
        size: Size(44, 44),
        child: SizedBox(width: 18, height: 18),
      ),
    ));

    expect(tester.getSize(find.byType(LiquidGlass)), const Size(44, 44));
    final glass = tester.getCenter(find.byType(LiquidGlass));
    final icon = tester.getCenter(find.byType(SizedBox).last);
    expect(icon.dx, closeTo(glass.dx, 0.01));
    expect(icon.dy, closeTo(glass.dy, 0.01));
  });

  testWidgets('a tightly constrained glass still fills — the composer field',
      (tester) async {
    await tester.pumpWidget(host(
      const Row(
        children: [
          Expanded(
            child: LiquidGlass(
              shape: LiquidGlassShape.rounded,
              child: SizedBox(height: 40),
            ),
          ),
        ],
      ),
    ));

    expect(tester.getSize(find.byType(LiquidGlass)).width, 800);
  });
}
