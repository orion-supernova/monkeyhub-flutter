import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monkeyhub/l10n/generated/app_localizations.dart';
import 'package:monkeyhub/models/message_capabilities.dart';
import 'package:monkeyhub/theme/basic_theme.dart';
import 'package:monkeyhub/theme/interaction.dart';
import 'package:monkeyhub/theme/theme_scope.dart';
import 'package:monkeyhub/widgets/hold_scrub.dart';
import 'package:monkeyhub/widgets/message_action_menu.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// What this pins: the long-press grammar from `hold_scrub.dart`.
///
///  * The menu's layout never flips: pill above the preview, list below,
///    wherever the bubble was pressed. Only the preview moves or shrinks.
///  * The finger that opened the menu can slide across the quick reactions
///    and release to react.
///  * Releasing anywhere else, a ROW included, picks nothing and leaves the
///    menu open for tapping. Rows always need a tap.
void main() {
  group('holdMenuPlacement', () {
    const bandTop = 71.0, bandBottom = 806.0, pill = 50.0, gap = 8.0;

    HoldMenuPlacement place(Rect pressed, {double menu = 350}) =>
        holdMenuPlacement(
          pressed: pressed,
          bandTop: bandTop,
          bandBottom: bandBottom,
          pillHeight: pill,
          wantedMenuHeight: menu,
        );

    void expectSkeleton(HoldMenuPlacement p, Rect pressed) {
      final previewH = pressed.height * p.previewScale;
      expect(p.pillTop, greaterThanOrEqualTo(bandTop - 0.001));
      expect(p.pillTop + pill + gap, closeTo(p.previewTop, 0.001));
      expect(p.previewTop + previewH + gap, closeTo(p.menuTop, 0.001));
      expect(p.menuTop + p.menuHeight, lessThanOrEqualTo(bandBottom + 0.001));
    }

    test('pill above, list below, at every height on the screen', () {
      for (final y in [60.0, 120.0, 300.0, 500.0, 700.0, 760.0, 800.0]) {
        final pressed = Rect.fromLTWH(20, y, 220, 44);
        final p = place(pressed);
        expectSkeleton(p, pressed);
        expect(p.previewScale, 1, reason: 'a short bubble never shrinks');
      }
    });

    test('a bubble with room stays exactly where it was pressed', () {
      final pressed = Rect.fromLTWH(20, 300, 220, 44);
      expect(place(pressed).liftDy, 0);
    });

    test('a bubble near the composer glides up instead of the menu flipping',
        () {
      final pressed = Rect.fromLTWH(20, 760, 220, 44);
      final p = place(pressed);
      expect(p.liftDy, lessThan(0));
      expect(p.menuTop, greaterThan(p.previewTop));
    });

    test('a tall bubble shrinks to fit between the pill and the list', () {
      final pressed = Rect.fromLTWH(20, 200, 260, 600);
      final p = place(pressed);
      expectSkeleton(p, pressed);
      expect(p.previewScale, lessThan(1));
      expect(p.menuHeight, 350, reason: 'the list keeps its full height');
    });

    test('a band too short for everything scrolls the list, not the order',
        () {
      final pressed = Rect.fromLTWH(20, 200, 220, 100);
      final p = holdMenuPlacement(
        pressed: pressed,
        bandTop: 50,
        bandBottom: 450,
        pillHeight: pill,
        wantedMenuHeight: 500,
      );
      expect(p.menuHeight, lessThan(500));
      expect(p.previewScale * pressed.height, closeTo(64, 0.001));
      expect(p.pillTop, closeTo(50, 0.001));
      expect(p.menuTop + p.menuHeight, closeTo(450 - 0.0, 0.001));
    });

    test('maxScale still caps media that would fit', () {
      final pressed = Rect.fromLTWH(20, 200, 220, 200);
      final p = holdMenuPlacement(
        pressed: pressed,
        bandTop: bandTop,
        bandBottom: bandBottom,
        pillHeight: pill,
        wantedMenuHeight: 200,
        maxScale: 0.5,
      );
      expect(p.previewScale, 0.5);
    });
  });

  group('the held finger', () {
    final caps = MessageCapabilities.none.copyWith(
      canReact: true,
      canReply: true,
      canCopy: true,
      canForward: true,
    );

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      HoldScrub.reset();
    });

    Future<void> settle(WidgetTester tester) async {
      for (var i = 0; i < 200; i++) {
        await tester.pump(const Duration(milliseconds: 16));
        if (!tester.binding.hasScheduledFrame) return;
      }
      fail('never settled');
    }

    /// A bubble wired the way `message_bubble.dart`'s detector is: the
    /// recognizer opens the menu and forwards the rest of the hold.
    Future<List<MessageActionResult?>> pumpBubble(WidgetTester tester,
        {List<String>? reacted}) async {
      final results = <MessageActionResult?>[];
      final anchor = GlobalKey();
      tester.view.physicalSize = const Size(393, 852);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(ThemeScope(
        controller: ThemeController(BasicTheme.midnight()),
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: Builder(
              builder: (context) => Align(
                alignment: const Alignment(-1, 0.2),
                child: RawGestureDetector(
                  key: const ValueKey('bubble'),
                  behavior: HitTestBehavior.opaque,
                  gestures: {
                    LongPressGestureRecognizer: GestureRecognizerFactoryWithHandlers<
                        LongPressGestureRecognizer>(
                      () => LongPressGestureRecognizer(
                          duration: kActionMenuLongPress),
                      (r) => r
                        ..onLongPress = () async {
                          results.add(await showMessageActionMenu(
                            context: context,
                            anchorKey: anchor,
                            bubbleBuilder: (_) =>
                                const ColoredBox(color: Colors.blue),
                            isMine: false,
                            capabilities: caps,
                            onReact: reacted == null
                                ? null
                                : (e, _) {
                                    reacted.add(e);
                                    return true;
                                  },
                          ));
                        }
                        ..onLongPressStart = ((_) => HoldScrub.start())
                        ..onLongPressMoveUpdate = ((d) => HoldScrub.move(
                            d.globalPosition, d.offsetFromOrigin))
                        ..onLongPressEnd =
                            ((d) => HoldScrub.end(d.globalPosition)),
                    ),
                  },
                  child: SizedBox(key: anchor, width: 220, height: 50),
                ),
              ),
            ),
          ),
        ),
      ));
      return results;
    }

    Future<TestGesture> hold(WidgetTester tester) async {
      final g = await tester.startGesture(
        tester.getCenter(find.byKey(const ValueKey('bubble'))),
      );
      await tester.pump(kActionMenuLongPress + const Duration(milliseconds: 20));
      await settle(tester);
      return g;
    }

    Finder pillEmoji(String e) => find.text(e).first;

    testWidgets('slide onto an emoji and release: that reaction', (tester) async {
      final results = await pumpBubble(tester);
      final g = await hold(tester);
      await g.moveTo(tester.getCenter(pillEmoji('😂')));
      await tester.pump();
      for (var i = 0; i < 20; i++) {
        await tester.pump(const Duration(milliseconds: 16));
      }
      // Magnified IN PLACE: one glyph, still in its slot (never a hole with a
      // copy floating above it), and grown.
      expect(find.text('😂'), findsOneWidget);
      final grown = tester
          .widgetList<Transform>(find.ancestor(
              of: find.text('😂'), matching: find.byType(Transform)))
          .map((t) => t.transform.storage[0])
          .reduce((a, b) => a > b ? a : b);
      expect(grown, greaterThan(1.3), reason: 'swollen under the finger');
      await g.up();
      await settle(tester);
      expect(results, hasLength(1));
      expect(results.single?.emoji, '😂');
    });

    testWidgets('a pick is applied the moment it is made, not after the close',
        (tester) async {
      final reacted = <String>[];
      final results = await pumpBubble(tester, reacted: reacted);
      final g = await hold(tester);
      await g.moveTo(tester.getCenter(pillEmoji('😂')));
      await tester.pump();
      await g.up();
      // One frame in: the menu is still on screen, the reaction is made.
      await tester.pump();
      expect(reacted, ['😂']);
      expect(results, isEmpty, reason: 'the overlay has not closed yet');
      await settle(tester);
      expect(results.single?.emoji, '😂');
      expect(results.single?.applied, isTrue);
    });

    testWidgets('sliding never leaves a hole or shrinks a glyph below rest',
        (tester) async {
      await pumpBubble(tester);
      final g = await hold(tester);
      double scaleOf(String e) => tester
          .widgetList<Transform>(find.ancestor(
              of: find.text(e), matching: find.byType(Transform)))
          .map((t) => t.transform.storage[0])
          .reduce((a, b) => a * b);
      for (final e in ['👍', '😂', '🔥', '❤️']) {
        await g.moveTo(tester.getCenter(pillEmoji(e)));
        for (var i = 0; i < 25; i++) {
          await tester.pump(const Duration(milliseconds: 16));
          for (final q in ['👍', '❤️', '😂', '😮', '😢', '🔥']) {
            expect(find.text(q), findsOneWidget, reason: '$q slot is never empty');
            expect(scaleOf(q), greaterThanOrEqualTo(0.999),
                reason: '$q never below its resting size');
          }
        }
      }
      await g.up();
      await settle(tester);
    });

    testWidgets('scrubbing follows the finger across the pill', (tester) async {
      final results = await pumpBubble(tester);
      final g = await hold(tester);
      final a = tester.getCenter(pillEmoji('👍'));
      final b = tester.getCenter(pillEmoji('🔥'));
      await g.moveTo(a);
      await tester.pump();
      // Drifting 30pt above the pill still scrubs: the band is generous.
      await g.moveTo(Offset(b.dx, b.dy - 30));
      await tester.pump();
      await g.up();
      await settle(tester);
      expect(results.single?.emoji, '🔥');
    });

    testWidgets('gliding between emoji runs every jelly frame without throwing',
        (tester) async {
      // Regression: the glyph swap chained an Interval onto a jelly-curved
      // animation, which runs past 1; every overshoot frame asserted on a
      // device. Frames are pumped one by one so each overshoot is reached.
      await pumpBubble(tester);
      final g = await hold(tester);
      for (final e in ['👍', '😂', '🔥', '❤️']) {
        await g.moveTo(tester.getCenter(pillEmoji(e)));
        for (var i = 0; i < 40; i++) {
          await tester.pump(const Duration(milliseconds: 16));
          expect(tester.takeException(), isNull);
        }
      }
      await g.moveTo(const Offset(380, 830));
      for (var i = 0; i < 40; i++) {
        await tester.pump(const Duration(milliseconds: 16));
        expect(tester.takeException(), isNull);
      }
      await g.up();
      await settle(tester);
    });

    testWidgets('release on a row picks nothing; the row still needs a tap',
        (tester) async {
      final results = await pumpBubble(tester);
      final g = await hold(tester);
      await g.moveTo(tester.getCenter(find.text('Forward')));
      await tester.pump();
      await g.up();
      await settle(tester);
      expect(results, isEmpty, reason: 'a release never runs an action');
      expect(find.text('Forward'), findsOneWidget, reason: 'menu stays open');

      await tester.tap(find.text('Copy'));
      await settle(tester);
      expect(results.single?.action, MessageAction.copy);
    });

    testWidgets('release without moving leaves the menu open', (tester) async {
      final results = await pumpBubble(tester);
      final g = await hold(tester);
      await g.up();
      await settle(tester);
      expect(results, isEmpty);
      expect(find.text('Reply'), findsOneWidget);
    });

    testWidgets('sliding off the pill cancels and says so', (tester) async {
      final results = await pumpBubble(tester);
      final g = await hold(tester);
      await g.moveTo(tester.getCenter(pillEmoji('❤️')));
      await tester.pump();
      await g.moveTo(const Offset(380, 830));
      // Real frames: the magnifier runs on springs ticked per frame.
      for (var i = 0; i < 30; i++) {
        await tester.pump(const Duration(milliseconds: 16));
      }
      expect(find.text('Release to cancel'), findsOneWidget);
      expect(find.text('❤️'), findsOneWidget, reason: 'magnifier gone');
      await g.up();
      await settle(tester);
      expect(results, isEmpty);
      expect(find.text('Release to cancel'), findsNothing);
      expect(find.text('Reply'), findsOneWidget, reason: 'menu stays open');
    });
  });
}
