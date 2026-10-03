import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monkeyhub/theme/basic_theme.dart';
import 'package:monkeyhub/theme/theme_scope.dart';
import 'package:monkeyhub/widgets/ios_kit.dart';
import 'package:monkeyhub/widgets/liquid_glass.dart';

void main() {
  // The crash from the field: a screen closes while a finger is still down
  // on one of its buttons; the recognizer fires onTapCancel from inside the
  // unmount and the button's setState threw "widget tree was locked".
  //
  // Smoke test only: under flutter_test this sequence does not reproduce the
  // locked-tree assertion even without TeardownSafe (verified), so it guards
  // against the press widgets throwing on mid-press teardown in general, not
  // against that exact regression.
  Widget host(Widget? child) => ThemeScope(
        controller: ThemeController(BasicTheme.midnight()),
        child: MaterialApp(
          home: Scaffold(body: Center(child: child ?? const SizedBox())),
        ),
      );

  for (final entry in <String, Widget>{
    'LiquidGlass': LiquidGlass(
      size: const Size(40, 40),
      onTap: () {},
      child: const Text('x'),
    ),
    'GroupedRow': GroupedRow(title: 'x', onTap: () {}),
    'SpringPress': SpringPress(onTap: () {}, child: const Text('x')),
  }.entries) {
    testWidgets('${entry.key} survives being torn down mid-press',
        (tester) async {
      await tester.pumpWidget(host(entry.value));
      final gesture = await tester.startGesture(tester.getCenter(find.text('x')));
      await tester.pump(const Duration(milliseconds: 150)); // past kPressTimeout: tap down is sent
      await tester.pumpWidget(host(null)); // the screen goes away
      expect(tester.takeException(), isNull);
      await gesture.up();
      await tester.pump();
      expect(tester.takeException(), isNull);
    });
  }
}
