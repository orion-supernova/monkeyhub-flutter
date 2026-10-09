import 'dart:typed_data';

import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monkeyhub/backend/chat_api.dart';
import 'package:monkeyhub/backend/convex_client.dart';
import 'package:monkeyhub/data/settings_store.dart';
import 'package:monkeyhub/models/chat_message.dart';
import 'package:monkeyhub/models/chat_user.dart';
import 'package:monkeyhub/models/enums.dart';
import 'package:monkeyhub/models/pending_upload.dart';
import 'package:monkeyhub/theme/app_theme.dart';
import 'package:monkeyhub/theme/basic_theme.dart';
import 'package:monkeyhub/theme/theme_scope.dart';
import 'package:monkeyhub/widgets/linkified_text.dart';
import 'package:monkeyhub/widgets/message_bubble.dart';
import 'package:monkeyhub/widgets/message_stamp.dart';
import 'package:monkeyhub/l10n/generated/app_localizations.dart';

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
  }) => ChatMessage(
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
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
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

  Widget bubble(
    ChatMessage m, {
    bool isMine = false,
    bool seenByOthers = false,
    bool deliveredToOthers = false,
    bool saved = false,
    bool pinned = false,
  }) => MessageBubble(
    message: m,
    now: DateTime(2026, 3, 1, 12, 4),
    currentUserId: isMine ? 'alice' : 'bob',
    api: api,
    seenByOthers: seenByOthers,
    deliveredToOthers: deliveredToOthers,
    saved: saved,
    pinned: pinned,
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

    expect(
      visibleStamp,
      findsOneWidget,
      reason: 'one painted stamp — inside the bubble, not also below it',
    );
    expect(stampText('12:04'), findsOneWidget);
    expect(
      find.byType(StampSpacer),
      findsOneWidget,
      reason: 'the paragraph reserves the room the stamp takes',
    );

    final stamp = tester.getRect(visibleStamp);
    final body = bubbleRect(tester);
    final gutter = theme.bubbleTailGutter(SettingsStore.instance.bubbleStyle);

    expect(stamp.bottom, lessThanOrEqualTo(body.bottom + 0.5));
    expect(stamp.top, greaterThanOrEqualTo(body.top - 0.5));
    // The bubble reserves a strip on the sender's side for its tail, and the
    // stamp has to stay out of it or the shape clips it.
    expect(
      stamp.right,
      lessThanOrEqualTo(body.right - gutter + 0.5),
      reason: 'the tail strip is not the stamp\'s to use',
    );
    expect(stamp.left, greaterThanOrEqualTo(body.left));
  });

  testWidgets('a one-word message keeps its stamp on its only line', (
    tester,
  ) async {
    await tester.pumpWidget(host(bubble(msg(content: 'ok'))));

    final body = bubbleRect(tester);
    // One line of body text plus its 10+10 padding. Every theme's body line box
    // is around 20pt, so a second line would blow well past this.
    expect(
      body.height,
      lessThan(46),
      reason: 'reserving room for the stamp must not cost the message a line',
    );

    final stamp = tester.getRect(visibleStamp);
    final text = tester.getRect(find.byType(LinkifiedText));
    expect(stamp.center.dy, greaterThan(text.top));
    expect(stamp.center.dy, lessThan(text.bottom));
  });

  testWidgets('a wrapping message keeps its stamp on the last line', (
    tester,
  ) async {
    await tester.pumpWidget(
      host(
        bubble(
          msg(
            content:
                'the quick brown fox jumps over the lazy dog and then keeps '
                'going for several more lines so the bubble is tall',
          ),
        ),
      ),
    );

    final stamp = tester.getRect(visibleStamp);
    final body = bubbleRect(tester);
    expect(stamp.bottom, lessThanOrEqualTo(body.bottom + 0.5));
    // Within a line and a half of the bottom, i.e. on the last line rather than
    // stranded up beside the first.
    expect(body.bottom - stamp.bottom, lessThan(30));
  });

  testWidgets('an ephemeral message counts down inside its bubble', (
    tester,
  ) async {
    final now = DateTime(2026, 3, 1, 12, 4);
    await tester.pumpWidget(
      host(
        EphemeralMessageBubble(
          message: msg(expiresAt: now.add(const Duration(seconds: 12))),
          now: ValueNotifier(now),
          currentUserId: 'bob',
          api: api,
          author: ChatUser(id: 'alice', username: 'alice', name: 'Alice'),
        ),
      ),
    );

    expect(visibleStamp, findsOneWidget);
    expect(
      stampText('12s'),
      findsOneWidget,
      reason: 'seconds while seconds matter',
    );
    expect(stampText('12:04'), findsOneWidget);
  });

  testWidgets('a pending message shows the clock, a sent one does not', (
    tester,
  ) async {
    await tester.pumpWidget(host(bubble(msg(status: MessageStatus.pending))));
    expect(
      find.descendant(of: visibleStamp, matching: find.byIcon(Icons.schedule)),
      findsOneWidget,
    );

    await tester.pumpWidget(host(bubble(msg())));
    expect(find.byIcon(Icons.schedule), findsNothing);
  });

  group('an attachment still going up', () {
    testWidgets('shows the upload glyph rather than the pending clock', (
      tester,
    ) async {
      await tester.pumpWidget(
        host(bubble(msg(status: MessageStatus.uploading))),
      );

      expect(
        find.descendant(
          of: visibleStamp,
          matching: find.byIcon(Icons.arrow_upward),
        ),
        findsOneWidget,
      );
      expect(find.byIcon(Icons.schedule), findsNothing);
    });

    testWidgets('is never marked seen, however far ahead the read cursor is', (
      tester,
    ) async {
      // `seenByOthers` is another member's read cursor measured against this
      // message's timestamp, and a cursor already past "now" makes it true for a
      // message created a moment ago. Left to fall through to the receipt
      // branches, an upload in flight would draw `done_all` — "seen" — on a
      // photo nobody has received yet.
      await tester.pumpWidget(
        host(
          bubble(
            msg(status: MessageStatus.uploading),
            isMine: true,
            seenByOthers: true,
          ),
        ),
      );

      expect(find.byIcon(Icons.done_all), findsNothing);
      expect(
        find.descendant(
          of: visibleStamp,
          matching: find.byIcon(Icons.arrow_upward),
        ),
        findsOneWidget,
      );
    });

    testWidgets('a sent message with the same cursor DOES read as seen', (
      tester,
    ) async {
      // The control for the test above: it must be pinning the uploading branch,
      // not a broken seen path.
      await tester.pumpWidget(
        host(bubble(msg(), isMine: true, seenByOthers: true)),
      );

      expect(
        find.descendant(
          of: visibleStamp,
          matching: find.byIcon(Icons.done_all),
        ),
        findsOneWidget,
      );
    });
  });

  group('the tick ladder', () {
    /// The single icon the stamp drew, or null if it drew none. The stamp emits
    /// at most one status glyph by construction — the branches are one `if`
    /// chain — so a list longer than one is itself the failure.
    Icon? glyph(WidgetTester tester) {
      final icons = tester
          .widgetList<Icon>(
            find.descendant(of: visibleStamp, matching: find.byType(Icon)),
          )
          .toList();
      expect(
        icons.length,
        lessThan(2),
        reason: 'the stamp says one thing about a message, not two',
      );
      return icons.isEmpty ? null : icons.first;
    }

    testWidgets('pending draws the clock and no tick', (tester) async {
      await tester.pumpWidget(
        host(bubble(msg(status: MessageStatus.pending), isMine: true)),
      );
      expect(glyph(tester)?.icon, Icons.schedule);
    });

    testWidgets('sent draws a single tick', (tester) async {
      await tester.pumpWidget(host(bubble(msg(), isMine: true)));

      expect(
        glyph(tester)?.icon,
        Icons.done,
        reason: 'on the server, on nobody else\'s phone yet',
      );
      expect(find.byIcon(Icons.done_all), findsNothing);
    });

    testWidgets('delivered draws a double tick', (tester) async {
      await tester.pumpWidget(
        host(bubble(msg(), isMine: true, deliveredToOthers: true)),
      );

      expect(glyph(tester)?.icon, Icons.done_all);
      expect(
        find.byIcon(Icons.done),
        findsNothing,
        reason: 'the second tick replaces the first, it does not join it',
      );
    });

    testWidgets('error draws the error affordance and no tick', (tester) async {
      await tester.pumpWidget(
        host(bubble(msg(status: MessageStatus.error), isMine: true)),
      );

      expect(glyph(tester)?.icon, Icons.error_outline);
      expect(find.byIcon(Icons.done), findsNothing);
      expect(find.byIcon(Icons.done_all), findsNothing);
    });

    testWidgets('seen keeps the double tick and lights it up', (tester) async {
      // The whole point of splitting sent from delivered is that the ladder
      // still has three rungs afterwards. Delivered and seen share a glyph and
      // are told apart by ink alone, so a regression that collapsed the two
      // would pass a shape-only check.
      await tester.pumpWidget(
        host(bubble(msg(), isMine: true, deliveredToOthers: true)),
      );
      final delivered = glyph(tester);

      await tester.pumpWidget(
        host(
          bubble(
            msg(),
            isMine: true,
            deliveredToOthers: true,
            seenByOthers: true,
          ),
        ),
      );
      final seen = glyph(tester);

      expect(delivered?.icon, Icons.done_all);
      expect(seen?.icon, Icons.done_all);
      expect(seen?.color, theme.accentInk, reason: 'seen is the loud ink');
      expect(
        delivered?.color,
        isNot(seen?.color),
        reason: 'delivered must not read as seen',
      );
    });

    testWidgets('someone else\'s message carries no ticks at all', (
      tester,
    ) async {
      // Receipts are news about your own messages. An incoming bubble that grew
      // a tick would be claiming something about the reader's own device.
      await tester.pumpWidget(
        host(bubble(msg(), deliveredToOthers: true, seenByOthers: true)),
      );

      expect(glyph(tester), isNull);
    });

    test('the rungs are ordered, and only outgoing messages have any', () {
      MessageReceipt? at({
        bool isMine = true,
        bool delivered = false,
        bool seen = false,
      }) => messageReceipt(
        isMine: isMine,
        deliveredToOthers: delivered,
        seenByOthers: seen,
      );

      expect(at(), MessageReceipt.sent);
      expect(at(delivered: true), MessageReceipt.delivered);
      expect(at(delivered: true, seen: true), MessageReceipt.seen);
      // Read implies delivered, so a read cursor ahead of a lagging delivery
      // one — an old row, or a recipient who shares reads but hides last-seen —
      // still lands on the top rung rather than falling back to one tick.
      expect(at(seen: true), MessageReceipt.seen);
      expect(at(isMine: false, delivered: true, seen: true), isNull);
    });
  });

  group('the pin a room-pinned message wears', () {
    Finder pin = find.descendant(
      of: visibleStamp,
      matching: find.byIcon(CupertinoIcons.pin_fill),
    );

    testWidgets('is absent on a message nobody pinned', (tester) async {
      await tester.pumpWidget(host(bubble(msg())));
      expect(pin, findsNothing);
    });

    testWidgets('appears in the stamp, ahead of the bookmark and the clock', (
      tester,
    ) async {
      await tester.pumpWidget(
        host(bubble(msg(), isMine: true, saved: true, pinned: true)),
      );

      expect(pin, findsOneWidget);
      final p = tester.getRect(pin).center.dx;
      final bookmark = tester
          .getRect(
            find.descendant(
              of: visibleStamp,
              matching: find.byIcon(CupertinoIcons.bookmark_fill),
            ),
          )
          .center
          .dx;
      final time = tester.getRect(stampText('12:04')).center.dx;
      expect(p, lessThan(bookmark));
      expect(bookmark, lessThan(time));
    });
  });

  group('the bookmark a saved message wears', () {
    /// The bookmark inside the painted stamp — never the twin's copy, and never
    /// the row's other glyphs.
    Finder mark = find.descendant(
      of: visibleStamp,
      matching: find.byIcon(CupertinoIcons.bookmark_fill),
    );

    testWidgets('is absent until this reader saves the message', (tester) async {
      // The default has to be false everywhere, because a bubble is also drawn
      // in previews and chrome that have no repository to ask.
      await tester.pumpWidget(host(bubble(msg())));
      expect(mark, findsNothing);
    });

    testWidgets('appears in the stamp, not as a second overlay', (tester) async {
      await tester.pumpWidget(host(bubble(msg(), saved: true)));

      expect(mark, findsOneWidget);
      final stamp = tester.getRect(visibleStamp);
      final glyph = tester.getRect(mark);
      expect(
        stamp.contains(glyph.center),
        isTrue,
        reason: 'a corner badge would need its own ink, inset and RTL answer',
      );
    });

    testWidgets('does not displace what the message says about delivery', (
      tester,
    ) async {
      // The status chain draws exactly one branch because those are one claim
      // about where the message got to. This is a different claim — what the
      // reader did — and both are true at once.
      await tester.pumpWidget(
        host(bubble(msg(), isMine: true, seenByOthers: true, saved: true)),
      );

      expect(mark, findsOneWidget);
      expect(
        find.descendant(of: visibleStamp, matching: find.byIcon(Icons.done_all)),
        findsOneWidget,
      );
    });

    testWidgets('leads the row, so it never competes with the tick', (
      tester,
    ) async {
      await tester.pumpWidget(
        host(bubble(msg(), isMine: true, seenByOthers: true, saved: true)),
      );

      final bookmark = tester.getRect(mark).center.dx;
      final time = tester.getRect(stampText('12:04')).center.dx;
      final tick = tester
          .getRect(
            find.descendant(
              of: visibleStamp,
              matching: find.byIcon(Icons.done_all),
            ),
          )
          .center
          .dx;
      expect(bookmark, lessThan(time));
      expect(time, lessThan(tick));
    });

    testWidgets('flips with the paragraph in RTL', (tester) async {
      // Nothing in the stamp resolves a direction by hand — it is a `Row`, so
      // "leading" becomes the visual right. This is the check that would catch
      // someone reaching for `left:`/`right:` in here later.
      await tester.pumpWidget(
        host(
          Directionality(
            textDirection: TextDirection.rtl,
            child: bubble(msg(), saved: true),
          ),
        ),
      );

      final bookmark = tester.getRect(mark).center.dx;
      final time = tester.getRect(stampText('12:04')).center.dx;
      expect(
        bookmark,
        greaterThan(time),
        reason: 'the head of the row is the right-hand end in RTL',
      );
    });

    testWidgets('rides the media lozenge rather than the picture', (
      tester,
    ) async {
      // A photo has no bubble to mark, which is exactly why the stamp already
      // carries its own dark lozenge there — the bookmark gets that for free
      // instead of needing a second frosted chip in another corner.
      await tester.pumpWidget(
        host(
          bubble(
            msg(content: '', type: MessageType.image, mediaStorageId: 's1'),
            saved: true,
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 300));

      expect(mark, findsOneWidget);
      expect(
        tester.getRect(visibleStamp).contains(tester.getRect(mark).center),
        isTrue,
      );
    });
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
        content: 'look at this https://example.com',
        type: MessageType.url,
      );
      expect(messageStampsInline(m, showLinkUrls: false), isTrue);
      expect(messageStampsInline(m, showLinkUrls: true), isTrue);
    });

    test('a photo takes the stamp on the picture, or in its caption', () {
      expect(
        messageStampsInline(
          msg(content: '', type: MessageType.image, mediaStorageId: 's1'),
          showLinkUrls: true,
        ),
        isTrue,
      );
      expect(
        messageStampsInline(
          msg(content: 'look', type: MessageType.image),
          showLinkUrls: true,
        ),
        isTrue,
        reason: 'the caption bubble can host it even with no picture',
      );
    });

    test('a photo that never arrived falls back to the row', () {
      // An error plate is no place for a frosted timestamp lozenge.
      expect(
        messageStampsInline(
          msg(content: '', type: MessageType.image),
          showLinkUrls: true,
        ),
        isFalse,
      );
    });

    test('an outgoing photo hosts its stamp before it has a storage id', () {
      // Otherwise a captionless photo starts life with an external timestamp row
      // and has the row taken away the instant the upload finishes — the bubble
      // grows a line and then loses it, while the user watches.
      final m = ChatMessage(
        id: 'tmp_1',
        roomId: 'r',
        senderId: 'alice',
        senderName: 'alice',
        content: '',
        createdAt: DateTime(2026, 3, 1, 12, 4),
        type: MessageType.image,
        status: MessageStatus.uploading,
        upload: PendingUpload(
          bytes: Uint8List.fromList(const [1, 2, 3]),
          contentType: 'image/jpeg',
        ),
      );
      addTearDown(m.upload!.dispose);

      expect(messageStampsInline(m, showLinkUrls: true), isTrue);
    });
  });

  testWidgets('the stamp spacer is fully transparent, not merely faint', (
    tester,
  ) async {
    // Load-bearing for the spoiler veil, not for the stamp. The spacer is the
    // one placeholder inside every message paragraph, and `RenderOpacity`
    // composites for ANY alpha above zero — which would flip every veiled
    // bubble onto `RenderVeiledText`'s hard-edged compositing fallback.
    await tester.pumpWidget(host(StampSpacer(
      stamp: MessageStamp(
        createdAt: DateTime(2026, 3, 1, 12, 4),
        status: MessageStatus.sent,
        tone: StampTone.onBubble,
      ),
    )));
    final opacity = tester.widget<Opacity>(find.descendant(
      of: find.byType(StampSpacer),
      matching: find.byType(Opacity),
    ));
    expect(opacity.opacity, 0);
    expect(
      tester.renderObject(find.byType(StampSpacer)).needsCompositing,
      isFalse,
    );
  });
}
