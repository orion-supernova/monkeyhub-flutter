import 'package:flutter/cupertino.dart' show CupertinoPageTransition;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monkeyhub/theme/glass_page_transitions.dart';

Widget _app() => MaterialApp(
  theme: ThemeData(
    platform: TargetPlatform.iOS,
    pageTransitionsTheme: glassPageTransitionsTheme,
  ),
  home: Builder(
    builder: (context) => Scaffold(
      body: TextButton(
        onPressed: () => Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => const Scaffold(body: Text('second')),
          ),
        ),
        child: const Text('push'),
      ),
    ),
  ),
);

void main() {
  testWidgets('Reduce Motion fades the push, and the edge swipe still goes back', (
    tester,
  ) async {
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);

    await tester.pumpWidget(_app());
    await tester.tap(find.text('push'));
    await tester.pump();
    // With the OS flag on, Flutter itself squeezes the route controller's
    // duration to a twentieth, so "mid-push" is a few milliseconds in.
    await tester.pump(const Duration(milliseconds: 5));

    // Mid-push the new page is fading, not sliding.
    final fades = tester
        .widgetList<FadeTransition>(
          find.ancestor(
            of: find.text('second'),
            matching: find.byType(FadeTransition),
          ),
        )
        .map((f) => f.opacity.value);
    expect(fades.any((o) => o > 0.01 && o < 0.99), isTrue, reason: '$fades');
    // ...and in place: the Cupertino wrapper is only there for the swipe.
    expect(tester.getTopLeft(find.text('second')).dx, lessThan(1));
    await tester.pumpAndSettle();
    expect(find.text('second'), findsOneWidget);

    // The swipe from the left edge pops it.
    await tester.dragFrom(const Offset(2, 300), const Offset(500, 0));
    await tester.pumpAndSettle();
    expect(find.text('second'), findsNothing);
    expect(find.text('push'), findsOneWidget);
  });

  testWidgets('without Reduce Motion the push slides', (tester) async {
    await tester.pumpWidget(_app());
    await tester.tap(find.text('push'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(
      find.ancestor(
        of: find.text('second'),
        matching: find.byType(CupertinoPageTransition),
      ),
      findsOneWidget,
    );
    await tester.pumpAndSettle();
  });
}
