import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monkeyhub/keyboard/dismiss_keyboard_on_tap.dart';

/// The auth forms had no way to put the soft keyboard away: nothing else on
/// those screens takes focus, and `TextField`'s own `onTapOutside` only
/// unfocuses on desktop — the one platform that has no soft keyboard.
///
/// The interesting assertions are the two that keep the wrapper from being a
/// blunt instrument: it must not swallow taps meant for a control underneath
/// it, and it must stay out of the way on desktop, where clearing focus on
/// every stray background click would break Enter-to-submit.

Widget _host(Widget child) => MaterialApp(
      // MaterialApp rather than a bare Directionality: TextField wants a
      // Material ancestor and MaterialLocalizations, and the app-under-test
      // always has both.
      home: Scaffold(body: child),
    );

void main() {
  testWidgets('a tap on the background drops focus', (tester) async {
    final focus = FocusNode();
    addTearDown(focus.dispose);

    await tester.pumpWidget(_host(
      DismissKeyboardOnTap(
        child: Column(
          children: [
            SizedBox(height: 200, child: TextField(focusNode: focus)),
            const Expanded(child: SizedBox.expand(key: Key('background'))),
          ],
        ),
      ),
    ));

    focus.requestFocus();
    await tester.pump();
    expect(focus.hasFocus, isTrue);

    // warnIfMissed because the background deliberately isn't hit-testable —
    // "a tap on nothing" is the case under test, and the only thing that can
    // claim it is the wrapper.
    await tester.tap(find.byKey(const Key('background')), warnIfMissed: false);
    await tester.pump();
    expect(focus.hasFocus, isFalse);
  });

  testWidgets('a control under the wrapper still gets its tap', (tester) async {
    var taps = 0;
    final focus = FocusNode();
    addTearDown(focus.dispose);

    await tester.pumpWidget(_host(
      DismissKeyboardOnTap(
        child: Column(
          children: [
            SizedBox(height: 200, child: TextField(focusNode: focus)),
            GestureDetector(
              key: const Key('button'),
              // The app's buttons all paint a background, which is what makes
              // them hit-testable; a bare SizedBox would not be.
              behavior: HitTestBehavior.opaque,
              onTap: () => taps++,
              child: const SizedBox(height: 60, width: 200),
            ),
          ],
        ),
      ),
    ));

    focus.requestFocus();
    await tester.pump();

    await tester.tap(find.byKey(const Key('button')));
    await tester.pump();
    expect(taps, 1);
    // And the field KEEPS focus: the button's own recognizer wins the arena,
    // so a tap that lands on a control is not also a dismiss. That is the
    // point of translucent rather than opaque — this widget only ever claims
    // taps nothing else wanted.
    expect(focus.hasFocus, isTrue);
  });

  testWidgets('desktop is left alone entirely', (tester) async {
    // Not asserted through focus: on desktop `TextField`'s own onTapOutside
    // already unfocuses, so a focus check would pass whether or not this
    // widget did anything. What matters is that it adds no recognizer of its
    // own to compete with desktop click handling.
    // Cleared inside the body, not in a tearDown: the framework asserts the
    // override is unset by the time the body returns.
    debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
    try {
      await tester.pumpWidget(_host(
        const DismissKeyboardOnTap(child: SizedBox.expand(key: Key('body'))),
      ));

      expect(
        find.descendant(
          of: find.byType(DismissKeyboardOnTap),
          matching: find.byType(GestureDetector),
        ),
        findsNothing,
      );
      expect(find.byKey(const Key('body')), findsOneWidget);
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });
}
