import 'package:flutter/cupertino.dart';
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
import 'package:monkeyhub/widgets/reply_indicator.dart';

/// The compact reply marker: what you get when the quoted parent is the bubble
/// directly above.
///
/// Three shapes were wrong before this one. Drawing nothing made replying to
/// the newest message — one swipe, the commonest action there is — look like it
/// had done nothing. Drawing the full quote card put a second copy of the bubble
/// above it on screen. Drawing a name chip welded to your own margin named
/// someone whose bubble was at the *other* margin, with nothing in between
/// saying so.
///
/// What was missing was never information — it was a line. So this draws one,
/// and these pin that it goes where it should and says nothing it shouldn't.
void main() {
  final api = ChatApi(ConvexBackend.instance);

  const kParentText = 'biz de simdi ciktik';
  const kParentName = 'sidika';

  // A phone-ish transcript width, and the avatar gutter an incoming row gives
  // up (_AvatarSlot._size 28 + 8).
  const w = 360.0;
  const h = 44.0;
  const gutter = 36.0;

  group('routing', () {
    test(
      'crosses the transcript when the two bubbles sit on opposite sides',
      () {
        // The case that motivated the whole design: their bubble left, mine
        // right, and previously nothing at all connecting the two.
        final p = replyTetherPath(
          width: w,
          height: h,
          isMine: true,
          parentIsMine: false,
          parentGutter: gutter,
        );
        expect(p.start.dx, lessThan(w / 3), reason: 'leaves from their margin');
        expect(p.end.dx, greaterThan(w * 2 / 3), reason: 'arrives at mine');
        expect(
          p.radius,
          greaterThan(0),
          reason: 'a run this long gets both of its turns rounded',
        );
        expect(p.start.dy, 0);
        expect(p.end.dy, h);
      },
    );

    test('collapses to a straight drop when both sit on the same side', () {
      final p = replyTetherPath(
        width: w,
        height: h,
        isMine: true,
        parentIsMine: true,
        parentGutter: 0,
      );
      expect(p.start.dx, p.end.dx);
      expect(
        p.radius,
        0,
        reason:
            'no run means no corners — two zero-radius turns drawn on '
            'top of each other is not the same picture',
      );
    });

    test(
      'starts under the parent bubble, not a whole avatar column left of it',
      () {
        // Our row is outgoing so it reserves no avatar column; theirs is incoming
        // so it does. Without the inset the anchor dot floats in the gutter.
        final withSlot = replyTetherPath(
          width: w,
          height: h,
          isMine: true,
          parentIsMine: false,
          parentGutter: gutter,
        );
        final inDm = replyTetherPath(
          width: w,
          height: h,
          isMine: true,
          parentIsMine: false,
          parentGutter: 0,
        );
        expect(withSlot.start.dx - inDm.start.dx, gutter);
      },
    );

    test('the gutter is ignored when both rows reserve the same columns', () {
      // Both incoming: our slot and the parent's start at the same x, so the
      // avatar column is already accounted for by the layout above us and
      // applying it again would push the anchor a column too far in.
      final p = replyTetherPath(
        width: w,
        height: h,
        isMine: false,
        parentIsMine: false,
        parentGutter: gutter,
      );
      expect(
        p.start.dx,
        p.end.dx,
        reason: 'same margin, same origin — the straight-drop case',
      );
    });

    test('the elbow stays inside the block, whichever way it routes', () {
      for (final isMine in [true, false]) {
        for (final parentIsMine in [true, false]) {
          final p = replyTetherPath(
            width: w,
            height: h,
            isMine: isMine,
            parentIsMine: parentIsMine,
            parentGutter: gutter,
          );
          expect(
            p.elbow.dx,
            inInclusiveRange(0, w),
            reason:
                'the branch button is centred here and would hang off '
                'the row otherwise (mine=$isMine, parent=$parentIsMine)',
          );
          expect(p.elbow, isA<Offset>());
        }
      }
    });
  });

  group('the widget', () {
    ChatMessage reply({bool parentDeleted = false}) => ChatMessage(
      id: 'child',
      roomId: 'r',
      senderId: 'me',
      senderName: 'me',
      // Short on purpose: the test font draws every glyph as a square of
      // the font size, so a real sentence fills the row and the alignment
      // assertion below could not tell a hugging bubble from a stretched
      // one.
      content: 'ok',
      createdAt: DateTime(2026, 3, 1, 12),
      type: MessageType.text,
      status: MessageStatus.sent,
      replyToId: 'parent',
      rootId: 'parent',
      replyToPreview: ReplyPreview(
        senderId: 'alice',
        senderName: kParentName,
        contentPreview: parentDeleted ? '__DELETED__' : kParentText,
        type: MessageType.text,
      ),
    );

    Widget host(Widget child) => MaterialApp(
      home: ThemeScope(
        controller: ThemeController(BasicTheme.midnight()),
        child: Scaffold(
          body: Align(
            alignment: Alignment.topLeft,
            child: SizedBox(width: w, child: child),
          ),
        ),
      ),
    );

    Widget bubble({
      bool parentDeleted = false,
      VoidCallback? onViewThread,
      void Function(String parentId)? onReplyIndicatorTap,
    }) => MessageBubble(
      message: reply(parentDeleted: parentDeleted),
      now: DateTime(2026, 3, 1, 12),
      currentUserId: 'me',
      api: api,
      author: ChatUser(id: 'me', username: 'me', name: 'Me'),
      parentAuthor: ChatUser(
        id: 'alice',
        username: kParentName,
        name: 'Sidika',
      ),
      replyMarker: ReplyMarker.compact,
      onViewThread: onViewThread,
      onReplyIndicatorTap: onReplyIndicatorTap,
    );

    testWidgets('says nothing at all — no quoted text, and no name either', (
      t,
    ) async {
      await t.pumpWidget(host(bubble(onViewThread: () {})));

      expect(find.byType(ReplyTether), findsOneWidget);
      // The duplicate-cell bug: the parent's body must never be restated.
      expect(find.textContaining(kParentText), findsNothing);
      // And neither must their name — their bubble is one row up, beside their
      // own avatar and their own sender label. Repeating it is noise.
      expect(
        find.textContaining(kParentName, findRichText: true),
        findsNothing,
      );
      expect(find.textContaining('SIDIKA'), findsNothing);
    });

    testWidgets('spans the row without dragging the bubble across it', (
      t,
    ) async {
      await t.pumpWidget(host(bubble(onViewThread: () {})));

      // The tether has to reach the far margin to connect two bubbles on
      // opposite sides, so it is full width where the chip before it hugged.
      expect(t.getSize(find.byType(ReplyTether)).width, w);

      // Which means the bubble's alignment now rests on the marker Column's
      // crossAxisAlignment rather than on free space in the row above it. It
      // must still be a right-aligned bubble, not a full-width slab.
      final bubbleRect = t.getRect(
        find
            .ancestor(
              of: find.byType(LinkifiedText),
              matching: find.byType(Container),
            )
            .first,
      );
      expect(bubbleRect.width, lessThan(w));
      expect(bubbleRect.right, closeTo(w, 0.5));
    });

    testWidgets('keeps the name in the accessibility tree', (t) async {
      final handle = t.ensureSemantics();
      await t.pumpWidget(host(bubble(onViewThread: () {})));
      // Leaving the screen is a visual decision, not a reason to strip it from
      // a screen reader.
      expect(find.bySemanticsLabel('in reply to $kParentName'), findsOneWidget);
      handle.dispose();
    });

    testWidgets('offers the branch button only where a thread can be opened', (
      t,
    ) async {
      await t.pumpWidget(host(bubble(onViewThread: () {})));
      expect(find.byIcon(CupertinoIcons.arrow_branch), findsOneWidget);

      // Inside the thread overlay onViewThread is null — no thread within a
      // thread — and a removed parent has no thread worth opening either.
      await t.pumpWidget(host(bubble()));
      expect(find.byIcon(CupertinoIcons.arrow_branch), findsNothing);

      await t.pumpWidget(
        host(bubble(parentDeleted: true, onViewThread: () {})),
      );
      expect(find.byIcon(CupertinoIcons.arrow_branch), findsNothing);
    });

    testWidgets('the line and the branch are two different doors', (t) async {
      String? jumpedTo;
      var openedThread = 0;
      await t.pumpWidget(
        host(
          bubble(
            onViewThread: () => openedThread++,
            onReplyIndicatorTap: (id) => jumpedTo = id,
          ),
        ),
      );

      // On the connector's own band — which starts at the parent's margin, a
      // little in from the row edge — and clear of the button at the middle.
      final band = t.getRect(find.byType(ReplyTether));
      await t.tapAt(Offset(band.left + 60, band.center.dy));
      await t.pump();
      expect(jumpedTo, 'parent');
      expect(openedThread, 0, reason: 'the line must not open the thread');

      await t.tap(find.byIcon(CupertinoIcons.arrow_branch));
      await t.pump();
      expect(openedThread, 1);
      expect(jumpedTo, 'parent', reason: 'and the branch must not re-jump');
    });

    testWidgets('measures the same with and without the branch button', (
      t,
    ) async {
      await t.pumpWidget(host(bubble(onViewThread: () {})));
      final withButton = t.getSize(find.byType(ReplyTether)).height;

      await t.pumpWidget(host(bubble()));
      final without = t.getSize(find.byType(ReplyTether)).height;

      // The action menu force-sizes its lifted preview into the rect it
      // measured off the live row. A marker that changed height with the
      // nullability of a callback would overflow that rect in the thread
      // overlay — the same bug class this area has already produced twice.
      expect(without, withButton);
      expect(withButton, h);
    });
  });
}
