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
import 'package:monkeyhub/widgets/reply_indicator.dart';
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
    GlobalKey? bubbleKey,
    bool showAvatarSlot = true,
    bool showAvatar = true,
    bool avatarAtBottom = false,
    bool grouped = false,
    bool lastInRun = true,
    String? senderName,
    // Long enough to wrap, so a top-aligned avatar and a bottom-aligned one
    // are nowhere near each other.
    String content =
        'the quick brown fox jumps over the lazy dog and then '
        'keeps going for several more lines so the bubble is tall',
  }) => MessageBubble(
    bubbleKey: bubbleKey,
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
    expect(
      shapeOf(tester).tail,
      isFalse,
      reason: 'a run of five tails would be five times the noise',
    );

    await tester.pumpWidget(host(bubble(grouped: true)));
    final closing = shapeOf(tester);
    expect(closing.tail, isTrue);
    expect(closing.isMine, isFalse, reason: 'alice is not the current user');
  });

  testWidgets('a run-closing avatar sits on the bubble\'s bottom edge', (
    tester,
  ) async {
    await tester.pumpWidget(host(bubble(avatarAtBottom: true)));

    final avatar = tester.getRect(find.byType(UserAvatar));
    final bubble_ = bubbleRect(tester);
    expect(
      avatar.bottom,
      moreOrLessEquals(bubble_.bottom, epsilon: 0.5),
      reason: 'not the bottom of the timestamp a line and a half below it',
    );
    expect(avatar.height, 28);
  });

  testWidgets('a standalone message keeps its avatar at the top', (
    tester,
  ) async {
    await tester.pumpWidget(host(bubble()));

    final avatar = tester.getRect(find.byType(UserAvatar));
    expect(avatar.top, moreOrLessEquals(bubbleRect(tester).top, epsilon: 0.5));
  });

  testWidgets('mid-run rows hold the avatar space without drawing it', (
    tester,
  ) async {
    await tester.pumpWidget(host(bubble(showAvatar: false)));
    final withoutAvatar = bubbleRect(tester).left;
    expect(find.byType(UserAvatar), findsNothing);

    await tester.pumpWidget(host(bubble()));
    expect(
      bubbleRect(tester).left,
      withoutAvatar,
      reason: 'the left edge must not shift between rows of a run',
    );
  });

  testWidgets('the name lines up with the bubble, not the avatar column', (
    tester,
  ) async {
    await tester.pumpWidget(host(bubble(senderName: 'Alice')));

    // As the person typed it — not the uppercased label treatment reply
    // indicators use.
    final name = find.text('Alice');
    expect(name, findsOneWidget);
    final nameRect = tester.getRect(name);
    final bubble_ = bubbleRect(tester);
    // The bubble's box reserves a strip on the sender's side for its tail, so
    // "lines up with the bubble" means with its body, not with that strip.
    final gutter = BasicTheme.midnight().bubbleTailGutter(
      SettingsStore.instance.bubbleStyle,
    );
    expect(
      nameRect.left,
      moreOrLessEquals(bubble_.left + gutter + 4, epsilon: 0.5),
    );
    expect(nameRect.bottom, lessThanOrEqualTo(bubble_.top));
  });

  testWidgets('no name renders when the caller passes none', (tester) async {
    await tester.pumpWidget(host(bubble()));
    expect(find.text('Alice'), findsNothing);
  });

  testWidgets('a DM reclaims the avatar column', (tester) async {
    await tester.pumpWidget(host(bubble(showAvatarSlot: false)));

    expect(find.byType(UserAvatar), findsNothing);
    expect(
      bubbleRect(tester).left,
      0,
      reason: 'nothing left to reserve space for',
    );
  });

  // The thread overlay decides tap-to-dismiss by asking whether the tap landed
  // inside this box: on the message, nothing happens; beside it, the thread
  // closes. That only works while the box is the bubble and not the row.
  testWidgets('bubbleKey measures the message, not the row it sits in', (
    tester,
  ) async {
    final key = GlobalKey();
    await tester.pumpWidget(host(bubble(bubbleKey: key, content: 'hi')));

    final keyed = tester.getRect(find.byKey(key));
    final painted = bubbleRect(tester);
    expect(
      keyed.contains(painted.center),
      isTrue,
      reason: 'a tap in the middle of the bubble is a tap on the message',
    );
    expect(
      keyed.right,
      lessThan(400),
      reason:
          'a short message in a 500px row leaves most of the row empty, '
          'and all of that empty space has to stay dismissable',
    );
    expect(
      keyed.contains(const Offset(480, 10)),
      isFalse,
      reason: 'the far gutter is background',
    );
  });

  testWidgets('a reply tether stays outside the measured box', (tester) async {
    // The tether crosses the transcript to reach the bubble it quotes, so it
    // is routinely several times the width of the message hanging off it.
    // Measuring the pair together turned that reach into a dead strip beside
    // short replies, where taps landed on nothing and dismissed nothing.
    final key = GlobalKey();
    await tester.pumpWidget(
      host(
        MessageBubble(
          bubbleKey: key,
          message: ChatMessage(
            id: 'm1',
            roomId: 'r',
            senderId: 'alice',
            senderName: 'alice',
            content: 'ok',
            createdAt: DateTime(2026, 3, 1, 12),
            type: MessageType.text,
            status: MessageStatus.sent,
            replyToId: 'parent',
            rootId: 'parent',
            replyToPreview: const ReplyPreview(
              senderId: 'bob',
              senderName: 'bob',
              contentPreview: 'a much longer parent message to reach across',
              type: MessageType.text,
            ),
          ),
          now: DateTime(2026, 3, 1, 12),
          currentUserId: 'bob',
          api: api,
          author: ChatUser(id: 'alice', username: 'alice', name: 'Alice'),
          replyMarker: ReplyMarker.compact,
        ),
      ),
    );

    final keyed = tester.getRect(find.byKey(key));
    final painted = bubbleRect(tester);
    expect(
      tester.getRect(find.byType(ReplyTether)).width,
      greaterThan(painted.width),
      reason: 'a tether no wider than the bubble would prove nothing here',
    );
    expect(
      keyed.width,
      lessThan(painted.width + 12),
      reason: 'the box is the bubble; the tether above it is not part of it',
    );
    expect(
      keyed.top,
      greaterThanOrEqualTo(painted.top - 12),
      reason: 'and it does not reach up over the tether either',
    );
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
      await tester.pumpWidget(
        host(
          Column(
            children: [
              bubble(content: 'one'),
              bubble(content: 'two', grouped: true),
              bubble(content: 'three', grouped: true),
              bubble(content: 'four', grouped: true),
            ],
          ),
        ),
      );

      final gaps = gapsBetween(tester, 4);
      for (final g in gaps) {
        expect(
          g,
          moreOrLessEquals(MessageGap.withinRun, epsilon: 0.5),
          reason:
              'measured $gaps — a reader can see an uneven ladder, and '
              'there is no reason for the first rung to differ',
        );
      }
    });

    testWidgets('a new run opens with the wider gap, and only one of it', (
      tester,
    ) async {
      await tester.pumpWidget(
        host(
          Column(
            children: [
              bubble(content: 'one'),
              bubble(content: 'two', grouped: true),
              bubble(content: 'three'),
              bubble(content: 'four'),
            ],
          ),
        ),
      );

      final gaps = gapsBetween(tester, 4);
      expect(gaps[0], moreOrLessEquals(MessageGap.withinRun, epsilon: 0.5));
      expect(gaps[1], moreOrLessEquals(MessageGap.betweenRuns, epsilon: 0.5));
      expect(
        gaps[2],
        moreOrLessEquals(MessageGap.betweenRuns, epsilon: 0.5),
        reason:
            'two run boundaries in a row must measure the same, which is '
            'exactly what summing two half-gaps got wrong',
      );
    });
  });
}
