import 'package:flutter/cupertino.dart';
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
import 'package:monkeyhub/widgets/message_action_menu.dart';
import 'package:monkeyhub/widgets/message_bubble.dart';
import 'package:monkeyhub/widgets/message_stamp.dart';
import 'package:monkeyhub/l10n/generated/app_localizations.dart';

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

  /// Exactly the shape `problemReports.submit` inserts for its log attachment:
  /// empty `content` (see the fix on that mutation — it used to duplicate
  /// `fileName` into `content`, which rendered as a second bubble holding
  /// nothing but the name again) and `mimeType: 'text/plain'`.
  ChatMessage reportLogDoc({String? storageId = 'kg2abc'}) => ChatMessage(
        id: 'm1',
        roomId: 'r',
        senderId: 'monkeyhub-log',
        senderName: 'MonkeyHub Log',
        content: '',
        createdAt: DateTime(2026, 3, 1, 12, 4),
        type: MessageType.file,
        status: MessageStatus.sent,
        mediaStorageId: storageId,
        fileName: 'monkeyhub-report-2026-03-01T12-04-00.txt',
        fileSize: 4096,
        mimeType: 'text/plain',
      );

  /// A phone-shaped chat pane: 390pt, which is what `ChatPane` publishes on the
  /// device most of these bubbles are read on.
  Widget host(Widget child) => MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
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

  testWidgets('a long name costs the transcript no extra lines',
      (tester) async {
    await tester.pumpWidget(host(bubble(doc(name: 'a.epub'), isMine: false)));
    final short = rowRect(tester).height;

    const long = 'The Long Book Title That Someone Actually Sent.epub';
    await tester.pumpWidget(host(bubble(doc(name: long), isMine: false)));
    expect(tester.takeException(), isNull);

    // A document sits in a run of other messages and keeps a message's
    // rhythm: however long the name, the row is the same height. Letting it
    // wrap turned one filename into a six-line bubble.
    expect(rowRect(tester).height, short);
    expect(tester.widget<Text>(find.text(long)).maxLines, 1);
  });

  // The other half of the bargain above: the row gives up the name, so the
  // long-press menu has to print it in full. Without this the ellipsis is not
  // a trade, it is just a loss.
  testWidgets('long-press prints the whole name and offers to copy it',
      (tester) async {
    const long = 'The Long Book Title That Someone Actually Sent.epub';
    final anchor = GlobalKey();
    MessageActionResult? picked;

    // ThemeScope above MaterialApp, exactly as the app wires it: the menu
    // inserts into the ROOT overlay, so a scope nested inside `home` is not an
    // ancestor of the thing that has to read it.
    await tester.pumpWidget(ThemeScope(
      controller: ThemeController(BasicTheme.midnight()),
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: Center(
            child: Builder(
              builder: (ctx) => GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () async {
                  picked = await showMessageActionMenu(
                    context: ctx,
                    anchorKey: anchor,
                    bubbleBuilder: (_) =>
                        const SizedBox(width: 200, height: 60),
                    isMine: false,
                    canCopy: false,
                    fileName: long,
                  );
                },
                child: SizedBox(key: anchor, width: 200, height: 60),
              ),
            ),
          ),
        ),
      ),
    ));

    await tester.tap(find.byKey(anchor), warnIfMissed: false);
    await tester.pumpAndSettle();

    expect(find.text(long), findsOneWidget,
        reason: 'the whole name, over as many lines as it takes');
    expect(
      tester.widget<Text>(find.text(long)).maxLines,
      isNull,
      reason: 'nothing clamps it a second time',
    );

    await tester.tap(find.text('COPY NAME'));
    await tester.pumpAndSettle();
    expect(picked?.action, MessageAction.copyName);
  });

  testWidgets('a message with no document gets no name header',
      (tester) async {
    final anchor = GlobalKey();
    // ThemeScope above MaterialApp, exactly as the app wires it: the menu
    // inserts into the ROOT overlay, so a scope nested inside `home` is not an
    // ancestor of the thing that has to read it.
    await tester.pumpWidget(ThemeScope(
      controller: ThemeController(BasicTheme.midnight()),
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: Center(
            child: Builder(
              builder: (ctx) => GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => showMessageActionMenu(
                  context: ctx,
                  anchorKey: anchor,
                  bubbleBuilder: (_) => const SizedBox(width: 200, height: 60),
                  isMine: false,
                  canCopy: true,
                ),
                child: SizedBox(key: anchor, width: 200, height: 60),
              ),
            ),
          ),
        ),
      ),
    ));

    await tester.tap(find.byKey(anchor), warnIfMissed: false);
    await tester.pumpAndSettle();
    expect(find.text('COPY NAME'), findsNothing);
    expect(find.text('COPY'), findsOneWidget);
  });

  // The menu is the tallest thing this app puts on screen, and the filename
  // header made it taller. With a keyboard up it had nowhere to go: it was laid
  // out against the full screen height and ran straight under the keyboard,
  // taking the destructive rows with it.
  testWidgets('the menu stays clear of the keyboard', (tester) async {
    const keyboard = 336.0;
    final anchor = GlobalKey();
    MessageActionResult? picked;

    // Set on the VIEW, not via a wrapping MediaQuery: the Scaffold would strip
    // a bottom inset out of its body's MediaQuery before the call site could
    // read it, which is exactly the trap the production code fell into.
    tester.view
      ..physicalSize = const Size(390, 700)
      ..devicePixelRatio = 1.0
      ..viewInsets = const FakeViewPadding(bottom: keyboard);
    addTearDown(tester.view.reset);

    await tester.pumpWidget(ThemeScope(
      controller: ThemeController(BasicTheme.midnight()),
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: Align(
            alignment: Alignment.topLeft,
            child: Builder(
              builder: (ctx) => GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () async => picked = await showMessageActionMenu(
                  context: ctx,
                  anchorKey: anchor,
                  bubbleBuilder: (_) => const SizedBox(width: 200, height: 60),
                  isMine: false,
                  canCopy: false,
                  canReply: true,
                  canForward: true,
                  canPin: true,
                  canSelect: true,
                  fileName:
                      'The Long Book Title That Someone Actually Sent.epub',
                ),
                child: SizedBox(key: anchor, width: 200, height: 60),
              ),
            ),
          ),
        ),
      ),
    ));

    await tester.tap(find.byKey(anchor), warnIfMissed: false);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);

    const bandBottom = 700 - keyboard;

    // The menu box itself sits entirely in the band left over above the
    // keyboard. This is the thing that was wrong: it was placed against the
    // full 700 and ran under it.
    final list = tester.getRect(find.byType(SingleChildScrollView));
    expect(list.bottom, lessThanOrEqualTo(bandBottom + 0.5));
    expect(list.top, greaterThanOrEqualTo(0));

    // And the reaction pill is still a thing you can hit. Clamping the two
    // separately put the menu straight on top of it — both were individually
    // inside the band, both got pushed to the same end of it, and the quick
    // reactions became unreachable.
    for (final emoji in ['👍', '🔥']) {
      final e = tester.getRect(find.text(emoji));
      expect(e.bottom, lessThanOrEqualTo(list.top + 0.5),
          reason: '$emoji is underneath the action list');
      expect(e.top, greaterThanOrEqualTo(0));
    }

    // Too tall to show at once, so it scrolls — with a thumb saying so, and
    // REPORT, the last row and the first casualty, comes into the band when you
    // reach for it.
    expect(find.byType(RawScrollbar), findsOneWidget);
    expect(tester.getRect(find.text('REPLY')).bottom,
        lessThanOrEqualTo(bandBottom + 0.5));
    await tester.drag(find.byType(SingleChildScrollView), const Offset(0, -400));
    await tester.pumpAndSettle();
    final report = tester.getRect(find.text('REPORT'));
    expect(report.bottom, lessThanOrEqualTo(bandBottom + 0.5));
    expect(report.top, greaterThanOrEqualTo(list.top - 0.5));

    // Geometry is necessary but not sufficient — the pill has to actually take
    // the tap, not sit under the menu's hit area.
    await tester.tap(find.text('\u{1F44D}'));
    await tester.pumpAndSettle();
    expect(picked?.emoji, '\u{1F44D}');
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

  // Pins the report-attachment fix: `problemReports.submit` used to put the
  // file's own name into `content` "so the tile isn't unlabelled" — but the
  // tile already draws its label from `fileName`, so that just doubled the
  // name into a second bubble underneath. The name must appear exactly once.
  testWidgets('a report log attachment does not double its name into a caption',
      (tester) async {
    await tester.pumpWidget(host(bubble(reportLogDoc(), isMine: false)));
    expect(tester.takeException(), isNull);
    expect(find.text('monkeyhub-report-2026-03-01T12-04-00.txt'), findsOneWidget);
  });

  testWidgets('a plain-text attachment offers to view, not just save',
      (tester) async {
    await tester.pumpWidget(host(bubble(reportLogDoc(), isMine: false)));
    expect(tester.takeException(), isNull);

    // The chip promises what the tap will do — an arrow here on a file that
    // opens a viewer, not a download, would be the wrong affordance.
    expect(
      find.descendant(of: find.byType(FileMessage), matching: find.byIcon(CupertinoIcons.eye)),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byType(FileMessage),
        matching: find.byIcon(CupertinoIcons.arrow_down),
      ),
      findsNothing,
    );

    final l10n = AppLocalizations.of(tester.element(find.byType(FileMessage)));
    final semantics = tester.widget<Semantics>(
      find.descendant(
        of: find.byType(FileMessage),
        matching: find.byWidgetPredicate(
          (w) => w is Semantics && w.properties.label != null,
        ),
      ),
    );
    expect(
      semantics.properties.label,
      l10n.fileMessageViewSemanticLabel('monkeyhub-report-2026-03-01T12-04-00.txt'),
    );
  });

  // An ordinary document (an .epub, same as every other test in this file)
  // must keep tapping straight to a download — the viewer is scoped to plain
  // text only, not every attachment.
  testWidgets('a non-text attachment keeps its download affordance', (tester) async {
    await tester.pumpWidget(host(bubble(doc(), isMine: false)));
    expect(tester.takeException(), isNull);
    expect(
      find.descendant(
        of: find.byType(FileMessage),
        matching: find.byIcon(CupertinoIcons.arrow_down),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(of: find.byType(FileMessage), matching: find.byIcon(CupertinoIcons.eye)),
      findsNothing,
    );
  });
}
