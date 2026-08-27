import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monkeyhub/theme/basic_theme.dart';
import 'package:monkeyhub/theme/theme_scope.dart';
import 'package:monkeyhub/widgets/swipe_to_receipts.dart';
import 'package:monkeyhub/widgets/swipe_to_reply.dart';

/// The four things about the receipts pull that cannot be seen from its call
/// site, and that a page-transition-driven-by-a-finger gets wrong if anything
/// in the chain is off by one:
///
///  * the page starts moving DURING the drag and tracks the finger one to one
///    — this is the whole difference from the reply pull, which does nothing
///    until the finger lifts;
///  * a release short of the commit distance takes the page away again, hands
///    the navigator back, and leaves NOTHING on the history — the preview it
///    was dragging is an overlay, not a route;
///  * a release past it lands the page on a real route;
///  * the two pulls share one bubble and one gesture arena without either
///    stealing the other's direction.
void main() {
  const bubbleKey = Key('bubble');
  const pageKey = Key('receipts');

  /// A ListView, on purpose and for the same reason `swipe_to_reply_test` uses
  /// one: the transcript's vertical drag recognizer keeps the arena contested,
  /// which is the only condition under which the directional bail runs at all.
  Widget host({
    required VoidCallback onReply,
    bool enabled = true,
    TextDirection direction = TextDirection.ltr,
  }) =>
      MaterialApp(
        // Directionality inside `home` rather than a locale on the app: the
        // gestures read it from their own context, and a real locale would
        // drag the whole localization stack into a gesture test.
        home: Directionality(
          textDirection: direction,
          child: ThemeScope(
          controller: ThemeController(BasicTheme.midnight()),
            child: Scaffold(
              body: ListView(
                children: [
                  SwipeToReceipts(
                    enabled: enabled,
                    pageBuilder: (_) => const ColoredBox(
                      key: pageKey,
                      color: Color(0xFF101010),
                      child: SizedBox.expand(),
                    ),
                    child: SwipeToReply(
                      onReplyTriggered: onReply,
                      child: Container(
                        key: bubbleKey,
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
      );

  /// How far in the page is, as a fraction of the window: 0 fully off the
  /// trailing edge, 1 arrived.
  double shown(WidgetTester tester) {
    final width = tester.view.physicalSize.width / tester.view.devicePixelRatio;
    final left = tester.getTopLeft(find.byKey(pageKey)).dx;
    return (width - left) / width;
  }

  testWidgets('the page tracks the finger while the drag is still running', (
    tester,
  ) async {
    await tester.pumpWidget(host(onReply: () {}));
    final width = tester.view.physicalSize.width / tester.view.devicePixelRatio;

    final gesture = await tester.startGesture(
      tester.getCenter(find.byKey(bubbleKey)),
    );
    await tester.pump();
    expect(find.byKey(pageKey), findsNothing, reason: 'nothing pushed on down');

    await gesture.moveBy(const Offset(-120, 0));
    await tester.pump();

    expect(find.byKey(pageKey), findsOneWidget,
        reason: 'the page is on screen mid-drag, before any release');
    // One to one: 120px of finger is 120px of page, not a curve's idea of it.
    expect(shown(tester), closeTo(120 / width, 0.01));

    await gesture.moveBy(const Offset(-80, 0));
    await tester.pump();
    expect(shown(tester), closeTo(200 / width, 0.01));

    // Leave the test with nothing in flight.
    await gesture.up();
    await tester.pumpAndSettle();
  });

  testWidgets('a release short of the commit distance takes the page away', (
    tester,
  ) async {
    await tester.pumpWidget(host(onReply: () {}));

    final gesture = await tester.startGesture(
      tester.getCenter(find.byKey(bubbleKey)),
    );
    await tester.pump();
    // 60px of an 800px window is well under the 26% commit fraction, and slow
    // enough that the fling path can't claim it either.
    await gesture.moveBy(const Offset(-60, 0));
    await tester.pump(const Duration(milliseconds: 300));
    await gesture.moveBy(Offset.zero);
    await tester.pump(const Duration(milliseconds: 300));
    await gesture.up();
    await tester.pumpAndSettle();

    expect(find.byKey(pageKey), findsNothing);
    expect(find.byKey(bubbleKey), findsOneWidget);
    final nav = tester.state<NavigatorState>(find.byType(Navigator).first);
    // The navigator has to be handed back, or every later gesture in the app
    // silently no-ops against a user gesture that never ended.
    expect(nav.userGestureInProgress, isFalse);
    // And nothing was ever pushed, so the history — and every observer
    // watching it — never saw the pull at all.
    expect(nav.canPop(), isFalse);
  });

  testWidgets('a release past the commit distance keeps the page', (
    tester,
  ) async {
    await tester.pumpWidget(host(onReply: () {}));

    final gesture = await tester.startGesture(
      tester.getCenter(find.byKey(bubbleKey)),
    );
    await tester.pump();
    await gesture.moveBy(const Offset(-320, 0)); // 40% of 800
    await tester.pump(const Duration(milliseconds: 300));
    await gesture.moveBy(Offset.zero);
    await tester.pump(const Duration(milliseconds: 300));
    await gesture.up();
    await tester.pumpAndSettle();

    expect(find.byKey(pageKey), findsOneWidget);
    expect(shown(tester), closeTo(1, 0.001));
    final nav = tester.state<NavigatorState>(find.byType(Navigator).first);
    expect(nav.userGestureInProgress, isFalse);
    // A real route, not the overlay preview: the back button, the edge-swipe
    // and anything pushed from the screen all depend on this.
    expect(nav.canPop(), isTrue);
    // And exactly one — a preview left behind would sit on top of it forever.
    expect(find.byKey(pageKey), findsOneWidget);
  });

  testWidgets('the handover leaves exactly one copy of the page', (
    tester,
  ) async {
    await tester.pumpWidget(host(onReply: () {}));

    final gesture = await tester.startGesture(
      tester.getCenter(find.byKey(bubbleKey)),
    );
    await tester.pump();
    await gesture.moveBy(const Offset(-320, 0));
    await tester.pump();
    expect(find.byKey(pageKey), findsOneWidget, reason: 'preview only');
    await gesture.up();
    // The very frame the route arrives on is the frame the preview leaves.
    await tester.pump();
    expect(find.byKey(pageKey), findsOneWidget, reason: 'route only');
    await tester.pumpAndSettle();
    expect(find.byKey(pageKey), findsOneWidget);
  });

  testWidgets('the reply pull is untouched and pushes nothing', (tester) async {
    var replies = 0;
    await tester.pumpWidget(host(onReply: () => replies++));

    final gesture = await tester.startGesture(
      tester.getCenter(find.byKey(bubbleKey)),
    );
    await tester.pump();
    await gesture.moveBy(const Offset(90, 0));
    await tester.pump();
    expect(find.byKey(pageKey), findsNothing,
        reason: 'a rightward pull belongs to reply, not to receipts');

    await gesture.up();
    await tester.pumpAndSettle();
    expect(replies, 1);
    expect(find.byKey(pageKey), findsNothing);
  });

  testWidgets('a leftward pull arms no reply', (tester) async {
    var replies = 0;
    await tester.pumpWidget(host(onReply: () => replies++));

    final gesture = await tester.startGesture(
      tester.getCenter(find.byKey(bubbleKey)),
    );
    await tester.pump();
    await gesture.moveBy(const Offset(-320, 0));
    await tester.pump();
    await gesture.up();
    await tester.pumpAndSettle();

    expect(replies, 0);
    expect(find.byKey(pageKey), findsOneWidget);
  });

  testWidgets('disabled bubbles pull nothing in', (tester) async {
    await tester.pumpWidget(host(onReply: () {}, enabled: false));

    final gesture = await tester.startGesture(
      tester.getCenter(find.byKey(bubbleKey)),
    );
    await tester.pump();
    await gesture.moveBy(const Offset(-320, 0));
    await tester.pump();
    await gesture.up();
    await tester.pumpAndSettle();

    expect(find.byKey(pageKey), findsNothing);
  });

  testWidgets('under RTL both pulls mirror and stay out of each other\'s way', (
    tester,
  ) async {
    // The layout is mirrored, so the trailing edge the page comes from is the
    // LEFT one and both gestures have to turn around with it. If they don't,
    // the two collide on an outgoing bubble: whichever wins takes both.
    var replies = 0;
    await tester.pumpWidget(host(
      onReply: () => replies++,
      direction: TextDirection.rtl,
    ));

    final rightward = await tester.startGesture(
      tester.getCenter(find.byKey(bubbleKey)),
    );
    await tester.pump();
    await rightward.moveBy(const Offset(320, 0));
    await tester.pump();
    expect(find.byKey(pageKey), findsOneWidget,
        reason: 'in RTL the receipts pull runs rightward');
    expect(replies, 0, reason: 'and it is not a reply');
    await rightward.up();
    await tester.pumpAndSettle();
    await tester.state<NavigatorState>(find.byType(Navigator).first).maybePop();
    await tester.pumpAndSettle();

    final leftward = await tester.startGesture(
      tester.getCenter(find.byKey(bubbleKey)),
    );
    await tester.pump();
    await leftward.moveBy(const Offset(-90, 0));
    await tester.pump();
    await leftward.up();
    await tester.pumpAndSettle();
    expect(replies, 1, reason: 'in RTL the reply pull runs leftward');
    expect(find.byKey(pageKey), findsNothing);
  });
}
