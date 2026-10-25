import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/gestures.dart' show PointerDeviceKind;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monkeyhub/theme/theme_scope.dart';
import 'package:monkeyhub/widgets/action_buttons.dart';
import 'package:monkeyhub/widgets/glass_buttons.dart';

void main() {
  Widget app(Widget child, {bool calm = false}) => ThemeScope(
        controller: ThemeController(ThemeController.byId('basic')),
        child: MediaQuery(
          data: MediaQueryData(disableAnimations: calm),
          child: MaterialApp(
            home: Scaffold(body: Center(child: child)),
          ),
        ),
      );

  /// The press scale of the nearest SpringPress transform above [of].
  double scaleOf(WidgetTester tester, Finder of) {
    final t = tester.widget<Transform>(
      find.ancestor(of: of, matching: find.byType(Transform)),
    );
    return t.transform.storage[0];
  }

  final icon = find.byIcon(CupertinoIcons.ellipsis);

  testWidgets('a glass icon button blooms while pressed and settles to 1', (
    tester,
  ) async {
    await tester.pumpWidget(
      app(GlassIconButton(icon: CupertinoIcons.ellipsis, onTap: () {})),
    );
    expect(scaleOf(tester, icon), 1);
    final g = await tester.startGesture(
      tester.getCenter(icon),
      kind: PointerDeviceKind.touch,
    );
    await tester.pump(); // the ticker's first frame only starts its clock
    await tester.pump(const Duration(milliseconds: 200));
    expect(scaleOf(tester, icon), closeTo(1.06, 0.005));
    await g.up();
    // Underdamped: the return rings slightly through 1.
    var min = 2.0;
    for (var i = 0; i < 40; i++) {
      await tester.pump(const Duration(milliseconds: 16));
      min = scaleOf(tester, icon) < min ? scaleOf(tester, icon) : min;
    }
    await tester.pumpAndSettle();
    expect(scaleOf(tester, icon), 1);
    expect(min, lessThan(1.0), reason: 'underdamped: rings through 1');
  });

  testWidgets('a big capsule still dips', (tester) async {
    await tester.pumpWidget(
      app(SheetActionButton(label: 'Continue', onTap: () {})),
    );
    final label = find.text('Continue');
    final g = await tester.startGesture(
      tester.getCenter(label),
      kind: PointerDeviceKind.touch,
    );
    await tester.pump(); // the ticker's first frame only starts its clock
    await tester.pump(const Duration(milliseconds: 200));
    expect(scaleOf(tester, label), closeTo(0.97, 0.005));
    await g.up();
    await tester.pumpAndSettle();
    expect(scaleOf(tester, label), 1);
  });

  testWidgets('calm motion never scales', (tester) async {
    await tester.pumpWidget(
      app(
        GlassIconButton(icon: CupertinoIcons.ellipsis, onTap: () {}),
        calm: true,
      ),
    );
    final g = await tester.startGesture(
      tester.getCenter(icon),
      kind: PointerDeviceKind.touch,
    );
    await tester.pump(); // the ticker's first frame only starts its clock
    await tester.pump(const Duration(milliseconds: 200));
    expect(scaleOf(tester, icon), 1);
    await g.up();
    await tester.pumpAndSettle();
    expect(scaleOf(tester, icon), 1);
  });
}
