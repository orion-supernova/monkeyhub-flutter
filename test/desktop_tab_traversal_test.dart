import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monkeyhub/keyboard/desktop_tab_traversal.dart';

/// What this pins: Tab out of a text field is reported HANDLED on desktop.
///
/// The failure it guards is invisible to a focus assertion, because focus moves
/// either way. On macOS `NextFocusAction` reports `skipRemainingHandlers` when
/// the node it moved away from is a text field — the framework tells the engine
/// nobody wanted the key, AppKit's `insertTab:` runs, and a tab character lands
/// in the field focus just arrived in. So the assertion here is on the *return
/// value* of the key press, not on where focus ended up.
///
/// The unwrapped case is the control: the same tree without the wrapper fails
/// the same assertion, which is what shows the bug is Flutter's and not ours.
void main() {
  Widget form({required bool wrapped}) {
    return MaterialApp(
      builder: (context, child) =>
          wrapped ? DesktopTabTraversal(child: child!) : child!,
      home: Scaffold(
        body: Column(
          children: [
            TextField(controller: TextEditingController(), autofocus: true),
            TextField(controller: TextEditingController()),
            ElevatedButton(onPressed: () {}, child: const Text('go')),
          ],
        ),
      ),
    );
  }

  /// The override has to be cleared inside the test body: `tearDown` runs after
  /// the binding's own "no debug variable was left set" check, so resetting
  /// there fails every test regardless of what it asserted.
  Future<void> on(TargetPlatform platform, Future<void> Function() body) async {
    debugDefaultTargetPlatformOverride = platform;
    try {
      await body();
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  }

  testWidgets('macOS: unwrapped, tab out of a field escapes to the engine', (
    tester,
  ) async {
    await on(TargetPlatform.macOS, () async {
      await tester.pumpWidget(form(wrapped: false));
      await tester.pumpAndSettle();

      expect(await tester.sendKeyEvent(LogicalKeyboardKey.tab), isFalse);
    });
  });

  testWidgets('macOS: wrapped, every tab is handled by the framework', (
    tester,
  ) async {
    await on(TargetPlatform.macOS, () async {
      await tester.pumpWidget(form(wrapped: true));
      await tester.pumpAndSettle();

      for (var i = 0; i < 4; i++) {
        expect(
          await tester.sendKeyEvent(LogicalKeyboardKey.tab),
          isTrue,
          reason: 'tab #$i escaped to the engine',
        );
        await tester.pumpAndSettle();
      }
    });
  });

  testWidgets('macOS: shift+tab is handled too', (tester) async {
    await on(TargetPlatform.macOS, () async {
      await tester.pumpWidget(form(wrapped: true));
      await tester.pumpAndSettle();

      await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
      expect(await tester.sendKeyEvent(LogicalKeyboardKey.tab), isTrue);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
    });
  });

  testWidgets('macOS: focus still advances field to field', (tester) async {
    await on(TargetPlatform.macOS, () async {
      await tester.pumpWidget(form(wrapped: true));
      await tester.pumpAndSettle();
      final first = primaryFocus;

      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pumpAndSettle();

      expect(primaryFocus, isNot(first));
    });
  });

  testWidgets('macOS: a modified tab is left alone', (tester) async {
    await on(TargetPlatform.macOS, () async {
      await tester.pumpWidget(form(wrapped: true));
      await tester.pumpAndSettle();

      await tester.sendKeyDownEvent(LogicalKeyboardKey.metaLeft);
      expect(await tester.sendKeyEvent(LogicalKeyboardKey.tab), isFalse);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.metaLeft);
    });
  });

  // The shape `MentionKeyboardNav` uses: a non-focusable `Focus` sitting
  // directly on the field, which claims Tab to accept the armed mention rather
  // than let traversal walk out of a composer still being typed in. The app-wide
  // binding is far above it, so the composer must keep winning — if this fails,
  // Tab in a composer stops picking a name.
  testWidgets('macOS: a handler nearer the field still wins', (tester) async {
    await on(TargetPlatform.macOS, () async {
      var claimed = 0;
      await tester.pumpWidget(
        MaterialApp(
          builder: (context, child) => DesktopTabTraversal(child: child!),
          home: Scaffold(
            body: Focus(
              canRequestFocus: false,
              skipTraversal: true,
              onKeyEvent: (node, event) {
                if (event is KeyDownEvent &&
                    event.logicalKey == LogicalKeyboardKey.tab) {
                  claimed++;
                  return KeyEventResult.handled;
                }
                return KeyEventResult.ignored;
              },
              child: TextField(
                controller: TextEditingController(),
                autofocus: true,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final before = primaryFocus;

      expect(await tester.sendKeyEvent(LogicalKeyboardKey.tab), isTrue);
      await tester.pumpAndSettle();

      expect(claimed, 1);
      expect(primaryFocus, before, reason: 'traversal must not have run');
    });
  });

  // The wrapper is inert here — iOS already reports the key handled, which is
  // why the same screen behaves correctly when the iOS build runs on a Mac.
  testWidgets('iOS: tab was never broken', (tester) async {
    await on(TargetPlatform.iOS, () async {
      await tester.pumpWidget(form(wrapped: false));
      await tester.pumpAndSettle();

      expect(await tester.sendKeyEvent(LogicalKeyboardKey.tab), isTrue);
    });
  });
}
