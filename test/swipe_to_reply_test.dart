import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monkeyhub/theme/basic_theme.dart';
import 'package:monkeyhub/theme/theme_scope.dart';
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
}
