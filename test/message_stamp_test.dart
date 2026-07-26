import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monkeyhub/backend/chat_api.dart';
import 'package:monkeyhub/backend/convex_client.dart';
import 'package:monkeyhub/data/settings_store.dart';
import 'package:monkeyhub/models/chat_message.dart';
import 'package:monkeyhub/models/chat_user.dart';
import 'package:monkeyhub/models/enums.dart';
import 'package:monkeyhub/theme/app_theme.dart';
import 'package:monkeyhub/theme/basic_theme.dart';
import 'package:monkeyhub/theme/theme_scope.dart';
import 'package:monkeyhub/widgets/linkified_text.dart';
import 'package:monkeyhub/widgets/message_bubble.dart';
import 'package:monkeyhub/widgets/message_stamp.dart';

/// The timestamp used to be a row below the bubble, costing every message a
/// line of vertical space to show four characters. It now rides inside the
/// bubble, trailing the last word. Two things about that are geometry the widget
/// owns and no call site can see, which is what these pin:
///
///  * the stamp lands inside the bubble's *body* — clear of the tail gutter, and
///    never clipped by the bubble's own shape;
///  * reserving room for it does not cost the message a line: a one-word
///    message still renders as one line.
///
/// The third property — that a full last line wraps rather than running under
/// the stamp — is true by construction rather than by arithmetic: the room is
/// reserved by an invisible copy of the same widget, appended to the paragraph
/// as its last span. There is no number to get wrong, so there is nothing here
/// to pin beyond the containment checks below.
void main() {
  final api = ChatApi(ConvexBackend.instance);
  final theme = BasicTheme.midnight();

  ChatMessage msg({
    String content = 'hey',
    MessageType type = MessageType.text,
    MessageStatus status = MessageStatus.sent,
    String? mediaStorageId,
    DateTime? expiresAt,
  }) =>
      ChatMessage(
        id: 'm1',
        roomId: 'r',
        senderId: 'alice',
        senderName: 'alice',
        content: content,
        createdAt: DateTime(2026, 3, 1, 12, 4),
        type: type,
        status: status,
        mediaStorageId: mediaStorageId,
        expiresAt: expiresAt,
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

  Widget bubble(ChatMessage m, {bool isMine = false}) => MessageBubble(
        message: m,
        now: DateTime(2026, 3, 1, 12, 4),
        currentUserId: isMine ? 'alice' : 'bob',
        api: api,
        author: ChatUser(id: 'alice', username: 'alice', name: 'Alice'),
      );

  Rect bubbleRect(WidgetTester tester) => tester.getRect(
        find
            .ancestor(
              of: find.byType(LinkifiedText),
              matching: find.byType(Container),
            )
            .first,
      );

  /// The stamp that is actually painted. A bare type finder would also catch the
  /// invisible twin reserving room for it inside the paragraph.
  final visibleStamp = find.byKey(kVisibleStampKey);

  /// Text inside the painted stamp, ignoring the twin's identical copy.
  Finder stampText(String text) =>
      find.descendant(of: visibleStamp, matching: find.text(text));

  testWidgets('the timestamp rides inside the bubble', (tester) async {
    await tester.pumpWidget(host(bubble(msg())));

    expect(visibleStamp, findsOneWidget,
        reason: 'one painted stamp — inside the bubble, not also below it');
    expect(stampText('12:04'), findsOneWidget);
    expect(find.byType(StampSpacer), findsOneWidget,
        reason: 'the paragraph reserves the room the stamp takes');

    final stamp = tester.getRect(visibleStamp);
    final body = bubbleRect(tester);
    final gutter = theme.bubbleTailGutter(SettingsStore.instance.bubbleStyle);

    expect(stamp.bottom, lessThanOrEqualTo(body.bottom + 0.5));
    expect(stamp.top, greaterThanOrEqualTo(body.top - 0.5));
    // The bubble reserves a strip on the sender's side for its tail, and the
    // stamp has to stay out of it or the shape clips it.
    expect(stamp.right, lessThanOrEqualTo(body.right - gutter + 0.5),
        reason: 'the tail strip is not the stamp\'s to use');
    expect(stamp.left, greaterThanOrEqualTo(body.left));
  });

  testWidgets('a one-word message keeps its stamp on its only line',
      (tester) async {
    await tester.pumpWidget(host(bubble(msg(content: 'ok'))));

    final body = bubbleRect(tester);
    // One line of body text plus its 10+10 padding. Every theme's body line box
    // is around 20pt, so a second line would blow well past this.
    expect(body.height, lessThan(46),
        reason: 'reserving room for the stamp must not cost the message a line');

    final stamp = tester.getRect(visibleStamp);
    final text = tester.getRect(find.byType(LinkifiedText));
    expect(stamp.center.dy, greaterThan(text.top));
    expect(stamp.center.dy, lessThan(text.bottom));
  });

  testWidgets('a wrapping message keeps its stamp on the last line',
      (tester) async {
    await tester.pumpWidget(host(bubble(msg(
      content: 'the quick brown fox jumps over the lazy dog and then keeps '
          'going for several more lines so the bubble is tall',
    ))));

    final stamp = tester.getRect(visibleStamp);
    final body = bubbleRect(tester);
    expect(stamp.bottom, lessThanOrEqualTo(body.bottom + 0.5));
    // Within a line and a half of the bottom, i.e. on the last line rather than
    // stranded up beside the first.
    expect(body.bottom - stamp.bottom, lessThan(30));
  });

  testWidgets('an ephemeral message counts down inside its bubble',
      (tester) async {
    final now = DateTime(2026, 3, 1, 12, 4);
    await tester.pumpWidget(host(EphemeralMessageBubble(
      message: msg(expiresAt: now.add(const Duration(seconds: 12))),
      now: now,
      currentUserId: 'bob',
      api: api,
      author: ChatUser(id: 'alice', username: 'alice', name: 'Alice'),
    )));

    expect(visibleStamp, findsOneWidget);
    expect(stampText('12s'), findsOneWidget,
        reason: 'seconds while seconds matter');
    expect(stampText('12:04'), findsOneWidget);
  });

  testWidgets('a pending message shows the clock, a sent one does not',
      (tester) async {
    await tester.pumpWidget(host(bubble(msg(status: MessageStatus.pending))));
    expect(
      find.descendant(of: visibleStamp, matching: find.byIcon(Icons.schedule)),
      findsOneWidget,
    );

    await tester.pumpWidget(host(bubble(msg())));
    expect(find.byIcon(Icons.schedule), findsNothing);
  });

  group('messageStampsInline', () {
    test('plain text carries its own stamp', () {
      expect(messageStampsInline(msg(), showLinkUrls: true), isTrue);
      expect(messageStampsInline(msg(), showLinkUrls: false), isTrue);
    });

    test('a URL-only message with URLs hidden falls back to the row', () {
      final m = msg(content: 'https://example.com', type: MessageType.url);
      // The preview card IS the bubble in this mode — there is no surface of
      // ours to put a stamp on.
      expect(messageStampsInline(m, showLinkUrls: false), isFalse);
      // Showing the URL puts text back in a real bubble.
      expect(messageStampsInline(m, showLinkUrls: true), isTrue);
    });

    test('a URL with text alongside keeps its stamp inline', () {
      final m = msg(
          content: 'look at this https://example.com', type: MessageType.url);
      expect(messageStampsInline(m, showLinkUrls: false), isTrue);
      expect(messageStampsInline(m, showLinkUrls: true), isTrue);
    });

    test('a photo takes the stamp on the picture, or in its caption', () {
      expect(
        messageStampsInline(
            msg(content: '', type: MessageType.image, mediaStorageId: 's1'),
            showLinkUrls: true),
        isTrue,
      );
      expect(
        messageStampsInline(
            msg(content: 'look', type: MessageType.image), showLinkUrls: true),
        isTrue,
        reason: 'the caption bubble can host it even with no picture',
      );
    });

    test('a photo that never arrived falls back to the row', () {
      // An error plate is no place for a frosted timestamp lozenge.
      expect(
        messageStampsInline(msg(content: '', type: MessageType.image),
            showLinkUrls: true),
        isFalse,
      );
    });
  });
}
