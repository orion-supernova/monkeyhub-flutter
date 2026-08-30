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
import 'package:monkeyhub/widgets/message_bubble.dart';

/// How a message in a Chamber of Secrets room leaves the screen.
///
/// The dissolve had four separate things wrong with it, and all four are the
/// kind that only show up in motion:
///
///  * **It ran for 18% of the lifetime.** In a room set to ten minutes that is
///    a hundred and eight seconds of a bubble sitting there blurred and half
///    transparent — not an animation, just how old messages looked, and long
///    enough that a message still on screen was one you could no longer read.
///  * **It opened with a flash.** Every theme's `ephemeralSignature` paints at
///    FULL strength when handed a progress of zero — forty scatter dots, or a
///    full-alpha gradient — so mounting it at the top of the dissolve snapped a
///    coloured wash onto the bubble in a single frame.
///  * **It moved in steps.** The clock behind it ticks at 5Hz, which is right
///    for a countdown and four frames a tick short of enough for a blur.
///  * **It never finished.** The fade stopped at 15% opacity and the row was
///    then dropped from the list.
///
/// Each test below is one of those.
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

  Widget host(ChatMessage message, ValueNotifier<DateTime> clock) => MaterialApp(
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
            ),
          ),
        ),
      ),
    ),
  );

  /// The bubble's own fade — the [Opacity] immediately inside the one
  /// [ImageFiltered] an ephemeral bubble builds.
  double bubbleOpacity(WidgetTester tester) => tester
      .widget<Opacity>(
        find
            .descendant(
              of: find.byType(ImageFiltered),
              matching: find.byType(Opacity),
            )
            .first,
      )
      .opacity;

  /// Whether the blur layer is doing anything at all.
  bool blurred(WidgetTester tester) =>
      tester.widget<ImageFiltered>(find.byType(ImageFiltered)).enabled;

  /// Settle the smoothing tween onto whatever the clock currently says.
  Future<void> land(WidgetTester tester) async {
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
  }

  testWidgets('a long-lived message is untouched until its last seconds', (
    tester,
  ) async {
    // Ten minutes of life. Under the old rule the dissolve owned the last 108
    // seconds of it; it now owns the last six, and a minute out nothing has
    // started.
    final message = msg(const Duration(minutes: 10));
    final clock = ValueNotifier(born.add(const Duration(minutes: 9)));
    addTearDown(clock.dispose);

    await tester.pumpWidget(host(message, clock));
    await land(tester);

    expect(bubbleOpacity(tester), 1.0, reason: 'nothing has begun a minute out');
    expect(blurred(tester), isFalse, reason: 'and nothing is being blurred');

    // Thirty seconds out — still well inside the old 108-second window, still
    // untouched under the new six-second one.
    clock.value = born.add(const Duration(minutes: 9, seconds: 30));
    await land(tester);
    expect(bubbleOpacity(tester), 1.0);
    expect(blurred(tester), isFalse);
  });

  testWidgets('a short-lived one still gets a proportionate dissolve', (
    tester,
  ) async {
    // Twenty seconds of life. Six would be nearly a third of it, so the
    // fraction wins and the window is 3.6s — the message is untouched at five
    // seconds out and under way at two.
    final message = msg(const Duration(seconds: 20));
    final clock = ValueNotifier(born.add(const Duration(seconds: 15)));
    addTearDown(clock.dispose);

    await tester.pumpWidget(host(message, clock));
    await land(tester);
    expect(bubbleOpacity(tester), 1.0, reason: 'five seconds out is not yet');

    clock.value = born.add(const Duration(seconds: 18));
    await land(tester);
    expect(bubbleOpacity(tester), lessThan(1.0), reason: 'two seconds out is');
  });

  testWidgets('it opens without a flash', (tester) async {
    final message = msg(const Duration(minutes: 10));
    final clock = ValueNotifier(born.add(const Duration(minutes: 10)));
    addTearDown(clock.dispose);

    await tester.pumpWidget(host(message, clock));
    // A hair into the six-second window.
    clock.value = born.add(
      const Duration(minutes: 9, seconds: 54, milliseconds: 100),
    );
    await land(tester);

    expect(find.byKey(ephemeralSignatureKey), findsOneWidget,
        reason: 'the wash is up');
    // ...and it has to ARRIVE. The painters have no entrance of their own:
    // handed a progress of zero they paint at full strength, which is what
    // made this snap on in a single frame.
    expect(
      tester.widget<Opacity>(find.byKey(ephemeralSignatureKey)).opacity,
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
    // dissolve. It only escaped notice while the wash was a single-frame
    // flash; once it stays up, the shape has to be right.
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

  testWidgets('it moves between the clock\'s ticks, not with them', (
    tester,
  ) async {
    final message = msg(const Duration(minutes: 10));
    final clock = ValueNotifier(born.add(const Duration(minutes: 9, seconds: 55)));
    addTearDown(clock.dispose);

    await tester.pumpWidget(host(message, clock));
    await land(tester);
    final before = bubbleOpacity(tester);

    // One 5Hz tick of the transcript's clock. Without the smoothing tween the
    // bubble would jump to its new value on the very next frame and sit there
    // for 200ms; with it, the frames in between are all different.
    clock.value = born.add(const Duration(minutes: 9, seconds: 55, milliseconds: 200));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 16));
    final oneFrameLater = bubbleOpacity(tester);
    await tester.pump(const Duration(milliseconds: 100));
    final midway = bubbleOpacity(tester);

    expect(oneFrameLater, lessThan(before), reason: 'it is moving');
    expect(midway, lessThan(oneFrameLater), reason: 'and it keeps moving');
  });

  testWidgets('it finishes — the row is invisible before it is removed', (
    tester,
  ) async {
    final message = msg(const Duration(minutes: 10));
    final clock = ValueNotifier(born.add(const Duration(minutes: 10)));
    addTearDown(clock.dispose);

    await tester.pumpWidget(host(message, clock));
    await land(tester);

    expect(
      bubbleOpacity(tester),
      0.0,
      reason: 'the old fade stopped at 15% and the row was then yanked out',
    );
  });
}
