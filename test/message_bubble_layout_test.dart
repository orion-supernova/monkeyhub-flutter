import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monkeyhub/backend/chat_api.dart';
import 'package:monkeyhub/backend/convex_client.dart';
import 'package:monkeyhub/models/chat_message.dart';
import 'package:monkeyhub/models/chat_user.dart';
import 'package:monkeyhub/models/enums.dart';
import 'package:monkeyhub/theme/basic_theme.dart';
import 'package:monkeyhub/theme/theme_scope.dart';
import 'package:monkeyhub/widgets/linkified_text.dart';
import 'package:monkeyhub/widgets/message_bubble.dart';
import 'package:monkeyhub/widgets/user_avatar.dart';

/// A run of messages is bracketed: the sender's name opens it, their face
/// closes it. Both ends are geometry the widget owns and the call site cannot
/// see, which is what these tests pin:
///
///  * the avatar aligns with the *bubble's* bottom edge, not the timestamp's —
///    the whole reason reactions and the meta row sit outside the bubble row;
///  * the name lines up with the bubble, not with the avatar column;
///  * a DM reclaims the avatar column entirely rather than reserving it empty.
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
    expect(nameRect.left, moreOrLessEquals(bubble_.left + 4, epsilon: 0.5));
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
}
