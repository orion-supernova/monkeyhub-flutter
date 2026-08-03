import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monkeyhub/backend/chat_api.dart';
import 'package:monkeyhub/backend/convex_client.dart';
import 'package:monkeyhub/models/chat_message.dart';
import 'package:monkeyhub/models/chat_user.dart';
import 'package:monkeyhub/models/enums.dart';
import 'package:monkeyhub/theme/basic_theme.dart';
import 'package:monkeyhub/theme/layout.dart';
import 'package:monkeyhub/theme/theme_scope.dart';
import 'package:monkeyhub/widgets/file_message.dart';
import 'package:monkeyhub/widgets/message_bubble.dart';
import 'package:monkeyhub/widgets/message_stamp.dart';

/// A document bubble is the only bubble whose body is *chrome* rather than
/// text: a badge, a name, a size and a save control, with the timestamp
/// squeezed in beside all of it.
///
/// It shipped broken, and in a way only a layout test catches. `Row` hands a
/// non-flexible child UNBOUNDED width, so the document row took the `maxWidth`
/// it was given — a phone's `videoMaxWidth`, 280pt, wider than the entire
/// bubble body — and the stamp was laid out past the end of it. The timestamp
/// was simply not on screen, and the save control was clipped at the bubble's
/// edge. Everything here pins the fix: the row yields to the stamp, and both
/// stay inside the bubble at the narrowest width this app ships to.
void main() {
  final api = ChatApi(ConvexBackend.instance);

  ChatMessage doc({
    String name = 'The Long Book Title That Someone Actually Sent.epub',
    String? storageId = 'kg2abc',
    MessageStatus status = MessageStatus.sent,
  }) =>
      ChatMessage(
        id: 'm1',
        roomId: 'r',
        senderId: 'alice',
        senderName: 'alice',
        content: '',
        createdAt: DateTime(2026, 3, 1, 12, 4),
        type: MessageType.file,
        status: status,
        mediaStorageId: storageId,
        fileName: name,
        fileSize: 2 * 1024 * 1024,
        mimeType: 'application/epub+zip',
      );

  /// A phone-shaped chat pane: 390pt, which is what `ChatPane` publishes on the
  /// device most of these bubbles are read on.
  Widget host(Widget child) => MaterialApp(
        home: ThemeScope(
          controller: ThemeController(BasicTheme.midnight()),
          child: Scaffold(
            body: LayoutScope(
              windowClass: WindowClass.compact,
              width: 390,
              child: ChatMetricsScope(
                metrics: ChatMetrics.forPane(390, WindowClass.compact),
                child: Align(
                  alignment: Alignment.topLeft,
                  child: SizedBox(width: 390, child: child),
                ),
              ),
            ),
          ),
        ),
      );

  Widget bubble(ChatMessage m, {required bool isMine, bool seen = false}) =>
      MessageBubble(
        message: m,
        now: DateTime(2026, 3, 1, 12, 4),
        currentUserId: isMine ? 'alice' : 'bob',
        api: api,
        seenByOthers: seen,
        author: ChatUser(id: 'alice', username: 'alice', name: 'Alice'),
      );

  final visibleStamp = find.byKey(kVisibleStampKey);

  /// The whole bubble, tail gutter and padding included.
  Rect bubbleRect(WidgetTester tester) => tester.getRect(
        find
            .ancestor(
              of: find.byType(FileMessage),
              matching: find.byType(ConstrainedBox),
            )
            .last,
      );

  /// The document row itself — badge, name, size, save control.
  Rect rowRect(WidgetTester tester) =>
      tester.getRect(find.byType(FileMessage));

  for (final mine in [true, false]) {
    final who = mine ? 'outgoing' : 'incoming';

    testWidgets('$who document bubble shows its time inside the bubble',
        (tester) async {
      await tester.pumpWidget(host(bubble(doc(), isMine: mine, seen: mine)));
      expect(tester.takeException(), isNull,
          reason: 'the row must fit the bubble, not overflow it');

      expect(visibleStamp, findsOneWidget);
      expect(
        find.descendant(of: visibleStamp, matching: find.text('12:04')),
        findsOneWidget,
      );

      final stamp = tester.getRect(visibleStamp);
      final body = bubbleRect(tester);
      expect(stamp.right, lessThanOrEqualTo(body.right + 0.5),
          reason: 'the stamp is inside the bubble, not past the end of it');
      expect(stamp.left, greaterThanOrEqualTo(body.left - 0.5));
      expect(stamp.bottom, lessThanOrEqualTo(body.bottom + 0.5));
      // Beside the row, never over it: the two share one line and the row is
      // what gives up the width.
      expect(stamp.left, greaterThanOrEqualTo(rowRect(tester).right - 0.5));
    });

    testWidgets('$who document bubble keeps its save control on screen',
        (tester) async {
      await tester.pumpWidget(host(bubble(doc(), isMine: mine, seen: mine)));
      expect(tester.takeException(), isNull);

      final chip = tester.getRect(find.descendant(
        of: find.byType(FileMessage),
        matching: find.byType(Icon),
      ));
      expect(chip.right, lessThanOrEqualTo(rowRect(tester).right + 0.5));
      expect(chip.right, lessThanOrEqualTo(390));
    });

    testWidgets('$who document bubble stops at the bubble ceiling',
        (tester) async {
      await tester.pumpWidget(host(bubble(doc(), isMine: mine, seen: mine)));
      expect(tester.takeException(), isNull);
      // 390 * 0.72 — `ChatMetrics.compactBubbleFraction`.
      expect(bubbleRect(tester).width, lessThanOrEqualTo(280.8));
    });
  }

  testWidgets('a long name wraps rather than falling into an ellipsis',
      (tester) async {
    await tester.pumpWidget(host(bubble(doc(name: 'a.epub'), isMine: false)));
    final short = rowRect(tester).height;

    const long = 'The Long Book Title That Someone Actually Sent.epub';
    await tester.pumpWidget(host(bubble(doc(name: long), isMine: false)));
    expect(tester.takeException(), isNull);

    expect(rowRect(tester).height, greaterThan(short),
        reason: 'a name too long for one line takes another one');
    expect(
      tester.widget<Text>(find.text(long)).maxLines,
      greaterThan(1),
      reason: 'the name is the only thing this bubble says about itself',
    );
  });

  testWidgets('a wrapped name still leaves the stamp its corner',
      (tester) async {
    await tester.pumpWidget(host(bubble(doc(), isMine: true, seen: true)));
    expect(tester.takeException(), isNull);

    final stamp = tester.getRect(visibleStamp);
    final body = bubbleRect(tester);
    expect(stamp.right, lessThanOrEqualTo(body.right + 0.5));
    expect(stamp.bottom, lessThanOrEqualTo(body.bottom + 0.5));
    // It rides the bottom of a now-taller row, beside the size line.
    expect(stamp.bottom, greaterThan(body.top + 0.5 * body.height));
  });

  testWidgets('an unsent document dims its save control instead of losing it',
      (tester) async {
    await tester.pumpWidget(host(bubble(
      doc(storageId: null, status: MessageStatus.uploading),
      isMine: true,
    )));
    expect(tester.takeException(), isNull);

    // The extension badge stays legible while the row is inert — it is the one
    // label that says what the document actually is.
    expect(find.text('EPUB'), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(FileMessage),
        matching: find.byIcon(Icons.arrow_upward),
      ),
      findsNothing,
      reason: 'delivery state belongs to the stamp, not to the row',
    );
  });
}
