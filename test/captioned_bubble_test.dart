import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monkeyhub/backend/chat_api.dart';
import 'package:monkeyhub/backend/convex_client.dart';
import 'package:monkeyhub/data/settings_store.dart';
import 'package:monkeyhub/l10n/generated/app_localizations.dart';
import 'package:monkeyhub/models/chat_message.dart';
import 'package:monkeyhub/models/chat_user.dart';
import 'package:monkeyhub/models/enums.dart';
import 'package:monkeyhub/theme/basic_theme.dart';
import 'package:monkeyhub/theme/layout.dart';
import 'package:monkeyhub/theme/theme_scope.dart';
import 'package:monkeyhub/widgets/file_message.dart';
import 'package:monkeyhub/widgets/link_preview_card.dart';
import 'package:monkeyhub/widgets/message_bubble.dart';

/// What this pins: an attachment and its caption are ONE bubble, and a link in
/// that caption behaves like a link.
///
/// Both were wrong in the same message and in the same way. A photo or a
/// document with words attached rendered as a tile and then a SECOND rounded
/// container four points below it — which in this app is what two messages look
/// like, because two bubbles from the same person at the same second is two
/// messages. And `_captionBody` was built with `linkifyUrls: false`, so a URL
/// sent as a caption was the one place in the app where a URL was not a link:
/// not tappable, not foldable, and never previewed.
///
/// Together they are exactly what an App Store link shared through the iOS
/// share extension arrives as — the extension attaches the preview blob the
/// share sheet hands over and puts the URL in the caption — so it landed as a
/// mystery document with a dead URL in a bubble underneath it.
void main() {
  final api = ChatApi(ConvexBackend.instance);
  const url = 'https://apps.apple.com/tr/app/dandara-trials-of-fear/id1576164';

  ChatMessage doc({String content = ''}) => ChatMessage(
        id: 'm1',
        roomId: 'r',
        senderId: 'alice',
        senderName: 'alice',
        content: content,
        createdAt: DateTime(2026, 3, 1, 12, 4),
        type: MessageType.file,
        status: MessageStatus.sent,
        mediaStorageId: 'kg2abc',
        fileName: 'Dandara.epub',
        fileSize: 279129,
        mimeType: 'application/epub+zip',
      );

  ChatMessage photo({String content = ''}) => ChatMessage(
        id: 'm2',
        roomId: 'r',
        senderId: 'alice',
        senderName: 'alice',
        content: content,
        createdAt: DateTime(2026, 3, 1, 12, 4),
        type: MessageType.image,
        status: MessageStatus.sent,
        mediaStorageId: 'kg2img',
      );

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

  Widget bubble(ChatMessage m) => MessageBubble(
        message: m,
        now: DateTime(2026, 3, 1, 12, 4),
        currentUserId: 'bob',
        api: api,
        author: ChatUser(id: 'alice', username: 'alice', name: 'Alice'),
      );

  /// The innermost `Container` above [child] that actually paints a frame.
  ///
  /// "Same bubble" is the whole property under test, and this is the only way
  /// to state it that does not depend on how many undecorated layout boxes
  /// happen to sit in between.
  Widget? frameOf(WidgetTester tester, Finder child) {
    final frames = find
        .ancestor(
          of: child,
          matching: find.byWidgetPredicate(
            (w) => w is Container && w.decoration != null,
          ),
        )
        .evaluate();
    return frames.isEmpty ? null : frames.first.widget;
  }

  group('an attachment with a caption', () {
    testWidgets('puts the document and the words in the same frame',
        (tester) async {
      await tester.pumpWidget(host(bubble(doc(content: 'here you go'))));
      await tester.pump();

      final onDoc = frameOf(tester, find.byType(FileMessage));
      // `textContaining` + `findRichText`, and both halves are needed: a
      // caption goes through `LinkifiedText` and comes out as a `Text.rich`
      // that a plain `find.text` cannot see, and it ends in the
      // object-replacement character `stampSpacerSpan` reserves for the
      // timestamp — so an exact match never hits either.
      final onText =
          frameOf(tester, find.textContaining('here you go', findRichText: true));
      expect(onDoc, isNotNull);
      expect(onText, isNotNull);
      expect(
        identical(onDoc, onText),
        isTrue,
        reason: 'the caption is in a second bubble under the document again',
      );
    });

    testWidgets('puts the photo and the words in the same frame',
        (tester) async {
      await tester.pumpWidget(host(bubble(photo(content: 'from the roof'))));
      await tester.pump();

      final onText =
          frameOf(tester, find.textContaining('from the roof', findRichText: true));
      expect(onText, isNotNull);
      // The picture and its words end at the same edge: one frame, laid out
      // as one object. Before the fix the caption's box was 4pt lower and
      // hugged its own text, so the two right edges disagreed.
      final textFrame = find
          .ancestor(
            of: find.textContaining('from the roof', findRichText: true),
            matching: find.byWidgetPredicate(
              (w) => w is Container && w.decoration != null,
            ),
          )
          .first;
      final frameRect = tester.getRect(textFrame);
      final textRect =
          tester.getRect(find.textContaining('from the roof', findRichText: true));
      expect(frameRect.width, greaterThan(0));
      // The caption sits INSIDE the frame rather than in a box of its own
      // below it.
      expect(frameRect.contains(textRect.topLeft), isTrue);
      expect(frameRect.contains(textRect.bottomRight - const Offset(1, 1)),
          isTrue);
    });

    testWidgets('leaves a captionless attachment exactly as it was',
        (tester) async {
      await tester.pumpWidget(host(bubble(doc())));
      await tester.pump();

      expect(find.byType(FileMessage), findsOneWidget);
      expect(find.byType(LinkPreviewCard), findsNothing);
    });
  });

  group('a link in a caption', () {
    testWidgets('gets a preview card, inside the same bubble', (tester) async {
      await tester.pumpWidget(host(bubble(doc(content: url))));
      await tester.pump();

      expect(find.byType(LinkPreviewCard), findsOneWidget);
      final onDoc = frameOf(tester, find.byType(FileMessage));
      final onCard = frameOf(tester, find.byType(LinkPreviewCard));
      // Both asserted non-null first: `identical(null, null)` is true, and a
      // pair of nulls would make this pass on a bubble with no frame at all.
      expect(onDoc, isNotNull);
      expect(onCard, isNotNull);
      expect(identical(onDoc, onCard), isTrue,
          reason: 'the preview escaped the bubble the attachment is in');
    });

    testWidgets('a photo caption gets one too', (tester) async {
      await tester.pumpWidget(host(bubble(photo(content: 'look $url'))));
      await tester.pump();
      expect(find.byType(LinkPreviewCard), findsOneWidget);
    });

    testWidgets('a caption that is ONLY a link keeps the link visible',
        (tester) async {
      // `showLinkUrls` is off by default, and folding here would empty the
      // caption — leaving a padded row with nothing in it but the timestamp,
      // because a file's stamp is inline (see `messageStampsInline`). A text
      // message can drop its bubble and become the card; an attachment cannot.
      expect(SettingsStore.instance.showLinkUrls, isFalse);
      await tester.pumpWidget(host(bubble(doc(content: url))));
      await tester.pump();

      expect(
        find.textContaining('id1576164', findRichText: true),
        findsWidgets,
        reason: 'the only caption there was got folded away to nothing',
      );
    });

    testWidgets('a caption with words around the link folds the URL away',
        (tester) async {
      await tester.pumpWidget(
        host(bubble(doc(content: 'this one $url honestly'))),
      );
      await tester.pump();

      expect(find.textContaining('this one', findRichText: true), findsWidgets);
      // The card shows the DOMAIN, so the domain is not the thing to look for.
      // The app id only ever appears in the raw URL.
      expect(find.textContaining('id1576164', findRichText: true), findsNothing);
      expect(find.byType(LinkPreviewCard), findsOneWidget);
    });

    testWidgets('a caption with no link gets no card at all', (tester) async {
      await tester.pumpWidget(host(bubble(doc(content: 'no links here'))));
      await tester.pump();
      expect(find.byType(LinkPreviewCard), findsNothing);
    });

    testWidgets('never stacks more than two cards', (tester) async {
      await tester.pumpWidget(host(bubble(doc(
        content: 'a https://a.example b https://b.example c https://c.example',
      ))));
      await tester.pump();
      expect(find.byType(LinkPreviewCard), findsNWidgets(2));
    });
  });
}
