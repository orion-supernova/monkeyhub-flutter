import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monkeyhub/theme/basic_theme.dart';
import 'package:monkeyhub/theme/theme_scope.dart';
import 'package:monkeyhub/widgets/count_badge.dart';

/// The badge on the nav bar's *selected* tab sits on the accent-filled pill,
/// not on a plain surface — and a tint that reads fine against a surface has
/// almost nothing to separate it from a background made of the same accent.
void main() {
  final theme = BasicTheme.midnight();

  Future<Color> badgeFill(WidgetTester tester, {required bool onAccent}) async {
    await tester.pumpWidget(
      ThemeScope(
        controller: ThemeController(BasicTheme.midnight()),
        child: MaterialApp(
          home: Scaffold(
            body: Center(child: CountBadge(count: 3, onAccent: onAccent)),
          ),
        ),
      ),
    );
    final box = tester.widget<Container>(
      find
          .descendant(
            of: find.byType(CountBadge),
            matching: find.byType(Container),
          )
          .first,
    );
    return (box.decoration! as BoxDecoration).color!;
  }

  testWidgets('on an accent surface the badge fills solid', (tester) async {
    final fill = await badgeFill(tester, onAccent: true);
    expect(
      fill.a,
      1.0,
      reason: 'a translucent wash disappears into the selected pill',
    );
    expect(fill.r, theme.accent.r);
  });

  testWidgets('off an accent surface it stays a quiet tint', (tester) async {
    final fill = await badgeFill(tester, onAccent: false);
    expect(
      fill.a,
      lessThan(0.3),
      reason: 'in a room list it has to sit beside a dozen others',
    );
  });
}
