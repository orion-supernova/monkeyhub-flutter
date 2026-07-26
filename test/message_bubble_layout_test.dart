import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monkeyhub/backend/chat_api.dart';
import 'package:monkeyhub/backend/convex_client.dart';
import 'package:monkeyhub/models/chat_message.dart';
import 'package:monkeyhub/models/chat_user.dart';
import 'package:monkeyhub/data/settings_store.dart';
import 'package:monkeyhub/models/enums.dart';
import 'package:monkeyhub/theme/app_theme.dart';
import 'package:monkeyhub/theme/basic_theme.dart';
import 'package:monkeyhub/theme/layout.dart';
import 'package:monkeyhub/theme/theme_scope.dart';
import 'package:monkeyhub/widgets/linkified_text.dart';
import 'package:monkeyhub/widgets/message_bubble.dart';
import 'package:monkeyhub/widgets/user_avatar.dart';

/// A run of messages is bracketed: the sender's name opens it, their face
/// closes it. Both ends are geometry the widget owns and the call site cannot
/// see, which is what these tests pin:
///
///  * the avatar aligns with the *bubble's* bottom edge, not with the bottom of
///    whatever hangs below it — the whole reason the reaction row sits outside
///    the bubble row;
///  * the name lines up with the bubble, not with the avatar column;
///  * a DM reclaims the avatar column entirely rather than reserving it empty.
///
/// Plus the transcript's vertical rhythm: every boundary of the same kind has to
/// measure the same, which is only true while each row owns the gap above it and
/// nothing below it. See [MessageGap].
void main() {
  final api = ChatApi(ConvexBackend.instance);

  ChatMessage msg(String content) => ChatMessage(
        id: 'm1',
        roomId: 'r',
        senderId: 'alice',
        senderName: 'alice',
        content: content,
        createdAt: DateTime(2026, 3, 1, 12),
        type: MessageType.text,
        status: MessageStatus.sent,
      );

  Widget host(Widget child) => MaterialApp(
        home: ThemeScope(
          controller: ThemeController(BasicTheme.midnight()),
          child: Scaffold(
            body: Align(
              alignment: Alignment.topLeft,
              child: SizedBox(width: 500, child: child),
            ),
          ),
        ),
      );

  Widget bubble({
    bool showAvatarSlot = true,
    bool showAvatar = true,
    bool avatarAtBottom = false,
    bool grouped = false,
    bool lastInRun = true,
    String? senderName,
    // Long enough to wrap, so a top-aligned avatar and a bottom-aligned one
    // are nowhere near each other.
    String content = 'the quick brown fox jumps over the lazy dog and then '
        'keeps going for several more lines so the bubble is tall',
  }) =>
      MessageBubble(
        message: msg(content),
        now: DateTime(2026, 3, 1, 12),
        currentUserId: 'bob',
        api: api,
        author: ChatUser(id: 'alice', username: 'alice', name: 'Alice'),
        showAvatarSlot: showAvatarSlot,
        showAvatar: showAvatar,
        avatarAtBottom: avatarAtBottom,
        grouped: grouped,
        lastInRun: lastInRun,
        senderName: senderName,
      );

  /// The decorated box that *is* the bubble — the nearest Container wrapping
  /// the message text.
  Rect bubbleRect(WidgetTester tester) => tester.getRect(
        find
            .ancestor(
              of: find.byType(LinkifiedText),
              matching: find.byType(Container),
            )
            .first,
      );

  /// The outline the bubble container actually paints.
  BubbleShape shapeOf(WidgetTester tester) {
    final container = tester.widget<Container>(
      find
          .ancestor(
            of: find.byType(LinkifiedText),
            matching: find.byType(Container),
          )
          .first,
    );
    return (container.decoration as ShapeDecoration).shape as BubbleShape;
  }

  testWidgets('only the row that closes a run wears the tail', (tester) async {
    await tester.pumpWidget(host(bubble(lastInRun: false)));
    expect(shapeOf(tester).tail, isFalse,
        reason: 'a run of five tails would be five times the noise');

    await tester.pumpWidget(host(bubble(grouped: true)));
    final closing = shapeOf(tester);
    expect(closing.tail, isTrue);
    expect(closing.isMine, isFalse, reason: 'alice is not the current user');
  });

  testWidgets('a run-closing avatar sits on the bubble\'s bottom edge',
      (tester) async {
    await tester.pumpWidget(host(bubble(avatarAtBottom: true)));

    final avatar = tester.getRect(find.byType(UserAvatar));
    final bubble_ = bubbleRect(tester);
    expect(avatar.bottom, moreOrLessEquals(bubble_.bottom, epsilon: 0.5),
        reason: 'not the bottom of the timestamp a line and a half below it');
    expect(avatar.height, 28);
  });

  testWidgets('a standalone message keeps its avatar at the top',
      (tester) async {
    await tester.pumpWidget(host(bubble()));

    final avatar = tester.getRect(find.byType(UserAvatar));
    expect(avatar.top, moreOrLessEquals(bubbleRect(tester).top, epsilon: 0.5));
  });

  testWidgets('mid-run rows hold the avatar space without drawing it',
      (tester) async {
    await tester.pumpWidget(host(bubble(showAvatar: false)));
    final withoutAvatar = bubbleRect(tester).left;
    expect(find.byType(UserAvatar), findsNothing);

    await tester.pumpWidget(host(bubble()));
    expect(bubbleRect(tester).left, withoutAvatar,
        reason: 'the left edge must not shift between rows of a run');
  });

  testWidgets('the name lines up with the bubble, not the avatar column',
      (tester) async {
    await tester.pumpWidget(host(bubble(senderName: 'Alice')));

    // As the person typed it — not the uppercased label treatment reply
    // indicators use.
    final name = find.text('Alice');
    expect(name, findsOneWidget);
    final nameRect = tester.getRect(name);
    final bubble_ = bubbleRect(tester);
    // The bubble's box reserves a strip on the sender's side for its tail, so
    // "lines up with the bubble" means with its body, not with that strip.
    final gutter =
        BasicTheme.midnight().bubbleTailGutter(SettingsStore.instance.bubbleStyle);
    expect(nameRect.left,
        moreOrLessEquals(bubble_.left + gutter + 4, epsilon: 0.5));
    expect(nameRect.bottom, lessThanOrEqualTo(bubble_.top));
  });

  testWidgets('no name renders when the caller passes none', (tester) async {
    await tester.pumpWidget(host(bubble()));
    expect(find.text('Alice'), findsNothing);
  });

  testWidgets('a DM reclaims the avatar column', (tester) async {
    await tester.pumpWidget(host(bubble(showAvatarSlot: false)));

    expect(find.byType(UserAvatar), findsNothing);
    expect(bubbleRect(tester).left, 0,
        reason: 'nothing left to reserve space for');
  });

  group('vertical rhythm', () {
    /// The decorated box of the i-th bubble in a stack of them.
    Rect nthBubble(WidgetTester tester, int i) => tester.getRect(
          find
              .ancestor(
                of: find.byType(LinkifiedText).at(i),
                matching: find.byType(Container),
              )
              .first,
        );

    List<double> gapsBetween(WidgetTester tester, int count) => [
          for (var i = 1; i < count; i++)
            nthBubble(tester, i).top - nthBubble(tester, i - 1).bottom,
        ];

    testWidgets('every gap inside a run is the same gap', (tester) async {
      await tester.pumpWidget(host(Column(children: [
        bubble(content: 'one'),
        bubble(content: 'two', grouped: true),
        bubble(content: 'three', grouped: true),
        bubble(content: 'four', grouped: true),
      ])));

      final gaps = gapsBetween(tester, 4);
      for (final g in gaps) {
        expect(g, moreOrLessEquals(MessageGap.withinRun, epsilon: 0.5),
            reason: 'measured $gaps — a reader can see an uneven ladder, and '
                'there is no reason for the first rung to differ');
      }
    });

    testWidgets('a new run opens with the wider gap, and only one of it',
        (tester) async {
      await tester.pumpWidget(host(Column(children: [
        bubble(content: 'one'),
        bubble(content: 'two', grouped: true),
        bubble(content: 'three'),
        bubble(content: 'four'),
      ])));

      final gaps = gapsBetween(tester, 4);
      expect(gaps[0], moreOrLessEquals(MessageGap.withinRun, epsilon: 0.5));
      expect(gaps[1], moreOrLessEquals(MessageGap.betweenRuns, epsilon: 0.5));
      expect(gaps[2], moreOrLessEquals(MessageGap.betweenRuns, epsilon: 0.5),
          reason: 'two run boundaries in a row must measure the same, which is '
              'exactly what summing two half-gaps got wrong');
    });
  });
}
