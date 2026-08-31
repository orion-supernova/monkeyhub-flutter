import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monkeyhub/backend/chat_api.dart';
import 'package:monkeyhub/backend/convex_client.dart';
import 'package:monkeyhub/l10n/generated/app_localizations.dart';
import 'package:monkeyhub/models/chat_message.dart';
import 'package:monkeyhub/models/chat_user.dart';
import 'package:monkeyhub/models/enums.dart';
import 'package:monkeyhub/theme/basic_theme.dart';
import 'package:monkeyhub/theme/theme_scope.dart';
import 'package:monkeyhub/widgets/highlight_pulse.dart';
import 'package:monkeyhub/widgets/message_bubble.dart';
import 'package:monkeyhub/widgets/message_departures.dart';

/// How a message in a Chamber of Secrets room leaves the screen.
///
/// It used to fade and blur to nothing over its last six seconds, reaching
/// invisibility exactly as the row was dropped — which meant that at the one
/// moment an exit could happen, there was nothing on screen for it to happen
/// to. Now the bubble stays at full strength; the theme's signature builds
/// over it as a warning for its last three seconds; and at expiry the bubble
/// asks the departures ledger to raster it and blow it apart (see
/// `DepartingRow`). Each test below pins one of those.
void main() {
  final api = ChatApi(ConvexBackend.instance);

  final born = DateTime(2026, 3, 1, 12);

  /// A message with [life] between its creation and its expiry.
  ChatMessage msg(Duration life) => ChatMessage(
    id: 'm1',
    roomId: 'r',
    senderId: 'alice',
    senderName: 'alice',
    content: 'this one is going',
    createdAt: born,
    expiresAt: born.add(life),
    type: MessageType.text,
    status: MessageStatus.sent,
  );

  Widget host(
    ChatMessage message,
    ValueNotifier<DateTime> clock, {
    MessageDepartures? departures,
  }) => MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: ThemeScope(
      controller: ThemeController(BasicTheme.midnight()),
      child: Scaffold(
        body: Align(
          alignment: Alignment.topLeft,
          child: SizedBox(
            width: 500,
            child: EphemeralMessageBubble(
              message: message,
              now: clock,
              currentUserId: 'bob',
              api: api,
              author: ChatUser(id: 'alice', username: 'alice', name: 'Alice'),
              useHero: false,
              departures: departures,
              rowKey: departures == null ? null : 'm1',
            ),
          ),
        ),
      ),
    ),
  );

  /// The wash's own entrance ramp.
  double washOpacity(WidgetTester tester) =>
      tester.widget<Opacity>(find.byKey(ephemeralSignatureKey)).opacity;

  /// Settle the smoothing tween onto whatever the clock currently says.
  Future<void> land(WidgetTester tester) async {
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
  }

  /// The bubble is drawn as it always is: no blur layer anywhere, and no
  /// opacity between the row and the bubble's halo.
  void expectUntouched(WidgetTester tester) {
    expect(find.byType(ImageFiltered), findsNothing,
        reason: 'nothing is ever blurred');
    expect(
      find.ancestor(
        of: find.byType(HighlightPulse),
        matching: find.byType(Opacity),
      ),
      findsNothing,
      reason: 'and nothing fades the bubble',
    );
    expect(find.byType(HighlightPulse), findsOneWidget);
  }

  testWidgets('a long-lived message is untouched until its last seconds', (
    tester,
  ) async {
    final message = msg(const Duration(minutes: 10));
    final clock = ValueNotifier(born.add(const Duration(minutes: 9)));
    addTearDown(clock.dispose);

    await tester.pumpWidget(host(message, clock));
    await land(tester);
    expectUntouched(tester);
    expect(find.byKey(ephemeralSignatureKey), findsNothing,
        reason: 'no wash a minute out');

    clock.value = born.add(const Duration(minutes: 9, seconds: 30));
    await land(tester);
    expectUntouched(tester);
    expect(find.byKey(ephemeralSignatureKey), findsNothing,
        reason: 'nor thirty seconds out');
  });

  testWidgets('a short-lived one still gets a proportionate wash', (
    tester,
  ) async {
    // Twenty seconds of life. Three seconds is under the 18% ceiling, so
    // the window is the full three — untouched at five seconds out and
    // under way at two.
    final message = msg(const Duration(seconds: 20));
    final clock = ValueNotifier(born.add(const Duration(seconds: 15)));
    addTearDown(clock.dispose);

    await tester.pumpWidget(host(message, clock));
    await land(tester);
    expect(find.byKey(ephemeralSignatureKey), findsNothing,
        reason: 'five seconds out is not yet');

    clock.value = born.add(const Duration(seconds: 18));
    await land(tester);
    expect(find.byKey(ephemeralSignatureKey), findsOneWidget,
        reason: 'two seconds out is');
    expectUntouched(tester);
  });

  testWidgets('it opens without a flash', (tester) async {
    final message = msg(const Duration(minutes: 10));
    final clock = ValueNotifier(born.add(const Duration(minutes: 10)));
    addTearDown(clock.dispose);

    await tester.pumpWidget(host(message, clock));
    // A hair into the three-second window.
    clock.value = born.add(
      const Duration(minutes: 9, seconds: 57, milliseconds: 50),
    );
    await land(tester);

    expect(find.byKey(ephemeralSignatureKey), findsOneWidget,
        reason: 'the wash is up');
    // ...and it has to ARRIVE. The painters have no entrance of their own:
    // handed a progress of zero they paint at full strength, which is what
    // made this snap on in a single frame.
    expect(
      washOpacity(tester),
      lessThan(0.35),
      reason: 'the themed wash must ramp in, not snap on at full strength',
    );
  });

  testWidgets('the wash is cut to the bubble, not to its bounding box', (
    tester,
  ) async {
    // Every theme's signature fills the rect it is handed, and a
    // `Positioned.fill` hands it the bubble's bounding BOX. Unclipped, the
    // wash painted square corners outside a rounded bubble and a hard edge
    // across its tail — a rectangle drawn around the message for the whole
    // window.
    final message = msg(const Duration(minutes: 10));
    final clock = ValueNotifier(born.add(const Duration(minutes: 9, seconds: 58)));
    addTearDown(clock.dispose);

    await tester.pumpWidget(host(message, clock));
    await land(tester);

    final clip = find.ancestor(
      of: find.byKey(ephemeralSignatureKey),
      matching: find.byType(ClipPath),
    );
    expect(clip, findsOneWidget, reason: 'the wash is clipped at all');
    expect(
      tester.widget<ClipPath>(clip).clipper,
      isA<ShapeBorderClipper>(),
      reason: 'and clipped to a shape, not to a plain rect',
    );
  });

  testWidgets('the wash moves between the clock\'s ticks, not with them', (
    tester,
  ) async {
    final message = msg(const Duration(minutes: 10));
    final clock = ValueNotifier(
      born.add(const Duration(minutes: 9, seconds: 57, milliseconds: 100)),
    );
    addTearDown(clock.dispose);

    await tester.pumpWidget(host(message, clock));
    await land(tester);
    final before = washOpacity(tester);

    // One 5Hz tick of the transcript's clock. Without the smoothing tween the
    // wash would jump to its new value on the very next frame and sit there
    // for 200ms; with it, the frames in between are all different.
    clock.value = born.add(
      const Duration(minutes: 9, seconds: 57, milliseconds: 300),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 16));
    final oneFrameLater = washOpacity(tester);
    await tester.pump(const Duration(milliseconds: 100));
    final midway = washOpacity(tester);

    expect(oneFrameLater, greaterThan(before), reason: 'it is moving');
    expect(midway, greaterThan(oneFrameLater), reason: 'and it keeps moving');
  });

  testWidgets('the bubble is fully visible right up to expiry', (
    tester,
  ) async {
    final message = msg(const Duration(minutes: 10));
    final clock = ValueNotifier(
      born.add(const Duration(minutes: 9, seconds: 59, milliseconds: 500)),
    );
    addTearDown(clock.dispose);

    await tester.pumpWidget(host(message, clock));
    await land(tester);

    expect(find.byKey(ephemeralSignatureKey), findsOneWidget);
    expect(washOpacity(tester), 1.0, reason: 'the warning is at full strength');
    expectUntouched(tester);
    expect(
      find.ancestor(
        of: find.byType(HighlightPulse),
        matching: find.byType(Transform),
      ),
      findsNothing,
      reason: 'and nothing lifts or shrinks it off the glass',
    );
  });

  testWidgets('at expiry the bubble asks the ledger to depart', (
    tester,
  ) async {
    var changes = 0;
    final ledger = MessageDepartures(onChanged: () => changes++);
    addTearDown(ledger.dispose);
    final message = msg(const Duration(minutes: 10));
    final clock = ValueNotifier(born.add(const Duration(minutes: 9, seconds: 59)));
    addTearDown(clock.dispose);

    await tester.pumpWidget(host(message, clock, departures: ledger));
    await land(tester);
    expect(ledger.isDeparting('m1'), isFalse, reason: 'a second early is not yet');
    expect(find.byType(RepaintBoundary), findsWidgets,
        reason: 'but the raster boundary is already in place');

    clock.value = born.add(const Duration(minutes: 10));
    // The bubble asks during its build; the raster is taken at the end of
    // that same frame, so one pump is the whole exchange.
    await tester.pump();
    expect(ledger.isDeparting('m1'), isTrue);
    expect(changes, 1);
    final cap = ledger.captureFor('m1')!;
    expect(cap.image, isNotNull, reason: 'the bubble was rastered');
    expect(cap.isMine, isFalse);
    expect(cap.bubbleSize.width, greaterThan(0));
    expect(cap.outline.contains(cap.bubbleSize.center(Offset.zero)), isTrue);

    // The ticks that follow change nothing.
    clock.value = born.add(const Duration(minutes: 10, milliseconds: 400));
    await land(tester);
    expect(changes, 1);
  });
}
