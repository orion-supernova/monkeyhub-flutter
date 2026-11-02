import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monkeyhub/l10n/generated/app_localizations.dart';
import 'package:monkeyhub/theme/basic_theme.dart';
import 'package:monkeyhub/theme/theme_scope.dart';
import 'package:monkeyhub/widgets/message_hover_actions.dart';
import 'package:monkeyhub/widgets/swipe_to_reply.dart';

/// Two properties of the pull-to-reply gesture that are invisible from the
/// call site and were both wrong before:
///
///  * the reply arms the moment the finger lifts, not after the bubble has
///    finished sliding home — the composer and keyboard have to start moving
///    on the same beat as the threshold haptic, or the whole thing reads as
///    lag;
///  * the bubble always comes back to rest. It used to be strandable off to
///    the right forever, because the recognizer's leftward-bail swallowed the
///    PointerUp that is the only source of `onEnd`.
void main() {
  const childKey = Key('bubble');

  /// Hosted inside a ListView on purpose: the vertical drag recognizer keeps
  /// the gesture arena contested, which is what lets the horizontal
  /// recognizer's bail path run at all. Standalone, it wins the arena as the
  /// sole member and the interesting branch is never reached.
  Widget host({required VoidCallback onReply}) => MaterialApp(
    home: ThemeScope(
      controller: ThemeController(BasicTheme.midnight()),
      child: Scaffold(
        body: ListView(
          children: [
            SwipeToReply(
              onReplyTriggered: onReply,
              child: Container(
                key: childKey,
                height: 60,
                color: const Color(0xFF222222),
              ),
            ),
          ],
        ),
      ),
    ),
  );

  testWidgets('reply arms on release, before the bubble has slid home', (
    tester,
  ) async {
    var replies = 0;
    await tester.pumpWidget(host(onReply: () => replies++));

    final gesture = await tester.startGesture(
      tester.getCenter(find.byKey(childKey)),
    );
    await tester.pump();
    // Past the 64px threshold.
    await gesture.moveBy(const Offset(90, 0));
    await tester.pump();
    expect(replies, 0, reason: 'must not fire mid-drag');

    await gesture.up();
    // A single frame — nowhere near the 220ms snap-back.
    await tester.pump();
    expect(
      replies,
      1,
      reason: 'must fire on the release frame, not after the snap',
    );

    // And the bubble is still on its way home at that point.
    expect(tester.getTopLeft(find.byKey(childKey)).dx, greaterThan(0));

    await tester.pumpAndSettle();
    expect(tester.getTopLeft(find.byKey(childKey)).dx, 0);
    expect(replies, 1, reason: 'the snap-back must not fire a second reply');
  });

  testWidgets('a pull that stops short of the threshold arms nothing', (
    tester,
  ) async {
    var replies = 0;
    await tester.pumpWidget(host(onReply: () => replies++));

    final gesture = await tester.startGesture(
      tester.getCenter(find.byKey(childKey)),
    );
    await tester.pump();
    await gesture.moveBy(const Offset(40, 0));
    await tester.pump();
    await gesture.up();
    await tester.pumpAndSettle();

    expect(replies, 0);
    expect(tester.getTopLeft(find.byKey(childKey)).dx, 0);
  });

  testWidgets('a second finger landing mid-swipe cannot strand the bubble', (
    tester,
  ) async {
    // The regression. A fresh pointer resets the recognizer's leftward budget
    // while the accumulated drag persists, so the bail could fire with the
    // bubble already pulled far to the right. It then swallowed every
    // remaining event — including both PointerUps — leaving the bubble parked
    // off-centre with no snap-back pending and no way back.
    var replies = 0;
    await tester.pumpWidget(host(onReply: () => replies++));

    final centre = tester.getCenter(find.byKey(childKey));
    final a = await tester.startGesture(centre);
    await tester.pump();
    await a.moveBy(const Offset(100, 0));
    await tester.pump();
    expect(tester.getTopLeft(find.byKey(childKey)).dx, greaterThan(0));

    final b = await tester.startGesture(centre + const Offset(0, 10));
    await tester.pump();
    await b.moveBy(const Offset(-20, 0));
    await tester.pump();

    await b.up();
    await a.up();
    await tester.pumpAndSettle();

    expect(
      tester.getTopLeft(find.byKey(childKey)).dx,
      0,
      reason: 'the bubble must always return to rest',
    );
    expect(replies, lessThanOrEqualTo(1));
  });

  testWidgets('a net-leftward drag never arms a reply', (tester) async {
    var replies = 0;
    await tester.pumpWidget(host(onReply: () => replies++));

    final gesture = await tester.startGesture(
      tester.getCenter(find.byKey(childKey)),
    );
    await tester.pump();
    await gesture.moveBy(const Offset(-40, 0));
    await tester.pump();
    await gesture.up();
    await tester.pumpAndSettle();

    expect(replies, 0);
    expect(tester.getTopLeft(find.byKey(childKey)).dx, 0);
  });

  group('browser wheel swipe', () {
    setUp(() {
      SwipeToReply.wheelEnabled = true;
      SwipeToReply.resetWheelGesture();
    });
    tearDown(() => SwipeToReply.wheelEnabled = false);

    Widget two({required void Function(int) onReply}) => MaterialApp(
      home: ThemeScope(
        controller: ThemeController(BasicTheme.midnight()),
        child: Scaffold(
          body: ListView(
            children: [
              for (var i = 0; i < 2; i++)
                SwipeToReply(
                  onReplyTriggered: () => onReply(i),
                  child: Container(
                    key: Key('b$i'),
                    height: 60,
                    color: const Color(0xFF222222),
                  ),
                ),
            ],
          ),
        ),
      ),
    );

    testWidgets(
      'a vertical scroll never slides a bubble, even as a new one arrives '
      'under a pointer that has not moved',
      (tester) async {
        final replies = <int>[];
        await tester.pumpWidget(two(onReply: replies.add));
        final pointer = TestPointer(1, PointerDeviceKind.trackpad);
        final b0 = tester.getCenter(find.byKey(const Key('b0')));
        final b1 = tester.getCenter(find.byKey(const Key('b1')));

        // A real vertical scroll: big dy, a little sideways drift.
        await tester.sendEventToBinding(pointer.hover(b0));
        for (var i = 0; i < 4; i++) {
          await tester.sendEventToBinding(pointer.scroll(const Offset(3, 30)));
          await tester.pump(const Duration(milliseconds: 16));
        }
        // The list moves, a different bubble is under the pointer, and the
        // momentum tail is tiny and mostly noise, sideways-looking.
        await tester.sendEventToBinding(pointer.hover(b1));
        for (var i = 0; i < 6; i++) {
          await tester.sendEventToBinding(pointer.scroll(const Offset(5, 1)));
          await tester.pump(const Duration(milliseconds: 16));
        }

        for (final k in ['b0', 'b1']) {
          expect(
            tester.getCenter(find.byKey(Key(k))).dx,
            b0.dx,
            reason: '$k must stay put',
          );
        }
        expect(replies, isEmpty);
        await tester.pump(const Duration(seconds: 1));
      },
    );

    testWidgets('a clearly sideways swipe still replies', (tester) async {
      final replies = <int>[];
      await tester.pumpWidget(two(onReply: replies.add));
      final pointer = TestPointer(1, PointerDeviceKind.trackpad);
      await tester.sendEventToBinding(
        pointer.hover(tester.getCenter(find.byKey(const Key('b0')))),
      );
      for (var i = 0; i < 4; i++) {
        // Fingers right arrive as negative deltaX.
        await tester.sendEventToBinding(pointer.scroll(const Offset(-30, 1)));
        await tester.pump(const Duration(milliseconds: 16));
      }
      expect(replies, [0]);
      await tester.pump(const Duration(seconds: 1));
    });

    testWidgets(
      'the hover strip never shows at a mid-swipe position, and works again '
      'once the bubble is home',
      (tester) async {
        final hover = MessageHoverController();
        addTearDown(hover.dispose);
        // Theme above the app: the strip draws in the app's overlay.
        await tester.pumpWidget(ThemeScope(
          controller: ThemeController(BasicTheme.midnight()),
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: MessageHoverScope(
              controller: hover,
              child: Scaffold(
                body: ListView(
                  children: [
                    SwipeToReply(
                      onReplyTriggered: () {},
                      child: MessageHoverRegion(
                        target: MessageHoverTarget(
                          id: 'm',
                          isMine: false,
                          onReply: () {},
                        ),
                        child: Container(
                          key: const Key('m'),
                          width: 200,
                          height: 60,
                          color: const Color(0xFF222222),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ));
        final pointer = TestPointer(1, PointerDeviceKind.mouse);
        final at = tester.getCenter(find.byKey(const Key('m')));
        await tester.sendEventToBinding(pointer.hover(at));
        await tester.pump();
        // A swipe that starts inside the dwell and stays short of the commit.
        await tester.sendEventToBinding(pointer.scroll(const Offset(-20, 0)));
        await tester.pump(const Duration(milliseconds: 16));
        await tester.sendEventToBinding(pointer.scroll(const Offset(-20, 0)));
        await tester.pump(const Duration(milliseconds: 200));
        expect(hover.shownId, isNull, reason: 'measured mid-swipe');

        // Wheel goes quiet, the bubble springs home, the hold lifts.
        await tester.pump(const Duration(seconds: 1));
        expect(hover.shownId, isNull);
        await tester.sendEventToBinding(pointer.hover(const Offset(700, 500)));
        await tester.pump();
        await tester.sendEventToBinding(pointer.hover(at));
        await tester.pump(const Duration(milliseconds: 200));
        expect(hover.shownId, 'm');
        hover.dismiss();
        await tester.pump(const Duration(seconds: 1));
      },
    );
  });
}
