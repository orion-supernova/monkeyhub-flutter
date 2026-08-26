import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monkeyhub/backend/chat_api.dart';
import 'package:monkeyhub/backend/convex_client.dart';
import 'package:monkeyhub/models/chat_message.dart';
import 'package:monkeyhub/models/enums.dart';
import 'package:monkeyhub/models/message_formatting.dart';
import 'package:monkeyhub/theme/basic_theme.dart';
import 'package:monkeyhub/theme/theme_scope.dart';
import 'package:monkeyhub/widgets/jumbo_emoji.dart';
import 'package:monkeyhub/widgets/linkified_text.dart';
import 'package:monkeyhub/widgets/message_bubble.dart';
import 'package:monkeyhub/widgets/message_stamp.dart';
import 'package:monkeyhub/l10n/generated/app_localizations.dart';

/// A message that is nothing but emoji gives up its bubble and is drawn big.
///
/// Two halves, and the seam between them is where the bugs would be:
///
///  * [jumboEmojiRun] has to say yes to every shape an emoji actually arrives
///    in — ZWJ families, skin tones, flags, keycaps — and no to text that
///    merely *contains* one, because "🎉 nice" is a sentence;
///  * every part of the row that assumes there is a bubble has to agree with
///    it. The timestamp moves outside, the halo supplies its own outline, and
///    the two shapes that keep their bubble on purpose (formatted text, and an
///    ephemeral message whose frame is its only warning) still have one.
void main() {
  final api = ChatApi(ConvexBackend.instance);

  group('jumboEmojiRun', () {
    void yes(String text, int count, {String? why}) {
      test('${why ?? text} → $count', () {
        expect(jumboEmojiRun(text), hasLength(count));
      });
    }

    void no(String text, {String? why}) {
      test('${why ?? text} → null', () {
        expect(jumboEmojiRun(text), isNull);
      });
    }

    yes('🎉', 1);
    yes('❤️', 1, why: 'heart with variation selector');
    yes('❤', 1, why: 'bare heart, typed without the selector');
    yes('👍🏽', 1, why: 'skin-toned hand is one cluster');
    yes('👨‍👩‍👧‍👦', 1, why: 'ZWJ family is one cluster');
    yes('🏴󠁧󠁢󠁳󠁣󠁴󠁿', 1, why: 'tag-sequence flag is one cluster');
    yes('🇹🇷', 1, why: 'regional-indicator flag is one cluster');
    yes('1️⃣', 1, why: 'keycap');
    yes('😀😀😀', 3, why: 'at the ceiling');
    yes('  😀 😀  ', 2, why: 'whitespace between and around is dropped');
    yes('🎉❤️👍🏽', 3, why: 'mixed shapes');

    no('😀😀😀😀', why: 'one past the ceiling');
    no('hi 😀', why: 'text before');
    no('😀 nice', why: 'text after');
    no('', why: 'empty');
    no('   ', why: 'whitespace only');
    no('hello');
    no('©', why: 'text-default pictograph, no selector');
    no('™', why: 'text-default pictograph, no selector');
    no('1', why: 'a digit is not a keycap without the enclosing mark');
    no('.', why: 'punctuation');
    no('😀!', why: 'trailing punctuation');
    no('日', why: 'CJK is not pictographic');

    test('a long paragraph never reaches the segmenter', () {
      expect(jumboEmojiRun('😀' * 100), isNull);
    });
  });

  group('isHeartEmoji', () {
    test('every heart, and nothing else', () {
      for (final h in ['❤️', '💙', '🖤', '🤍', '💔', '💕', '♥️']) {
        expect(isHeartEmoji(h), isTrue, reason: h);
      }
      for (final other in ['😀', '👍', '🎉', '🔥']) {
        expect(isHeartEmoji(other), isFalse, reason: other);
      }
    });
  });

  group('in the transcript', () {
    ChatMessage msg({
      required String id,
      String content = '🎉',
      List<FormattingEntity> formatting = const [],
      DateTime? expiresAt,
    }) => ChatMessage(
      id: id,
      roomId: 'r',
      senderId: 'alice',
      senderName: 'alice',
      content: content,
      createdAt: DateTime(2026, 3, 1, 12),
      type: MessageType.text,
      status: MessageStatus.sent,
      formatting: formatting,
      expiresAt: expiresAt,
    );

    Widget host(Widget child, {bool calm = false}) => MediaQuery(
      data: MediaQueryData(disableAnimations: calm),
      child: MaterialApp(
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
      ),
    );

    Widget bubble(ChatMessage m) => MessageBubble(
      message: m,
      now: DateTime(2026, 3, 1, 12, 0, 5),
      currentUserId: 'bob',
      api: api,
    );

    Widget ephemeral(ChatMessage m) => EphemeralMessageBubble(
      message: m,
      now: DateTime(2026, 3, 1, 12, 0, 5),
      currentUserId: 'bob',
      api: api,
    );

    testWidgets('an emoji-only message loses its bubble and its inline stamp',
        (tester) async {
      await tester.pumpWidget(host(bubble(msg(id: 'jumbo-1'))));
      await tester.pumpAndSettle();
      expect(find.byType(JumboEmojiBubble), findsOneWidget);
      // The text pipeline is not merely bypassed for the glyph — it is not in
      // the tree at all, which is what says the bubble is gone with it.
      expect(find.byType(LinkifiedText), findsNothing);
      // …and the timestamp moved out to the row underneath, rather than
      // riding inside a bubble that no longer exists.
      final glyph = tester.getRect(find.byType(JumboEmojiBubble));
      final stamp = tester.getRect(find.byKey(kVisibleStampKey));
      expect(stamp.top, greaterThanOrEqualTo(glyph.bottom));
    });

    testWidgets('ordinary text keeps its bubble', (tester) async {
      await tester.pumpWidget(host(bubble(msg(id: 'plain-1', content: 'hey'))));
      await tester.pumpAndSettle();
      expect(find.byType(JumboEmojiBubble), findsNothing);
      expect(find.byType(LinkifiedText), findsOneWidget);
      // The stamp still rides inside the paragraph — the mirror of the
      // assertion above, so the two cases cannot both be passing by accident.
      final text = tester.getRect(find.byType(LinkifiedText));
      final stamp = tester.getRect(find.byKey(kVisibleStampKey));
      expect(stamp.top, lessThan(text.bottom));
    });

    testWidgets('four emoji is a sentence again', (tester) async {
      await tester
          .pumpWidget(host(bubble(msg(id: 'four-1', content: '🎉🎉🎉🎉'))));
      await tester.pumpAndSettle();
      expect(find.byType(JumboEmojiBubble), findsNothing);
      expect(find.byType(LinkifiedText), findsOneWidget);
    });

    testWidgets('formatted emoji keeps the text pipeline', (tester) async {
      await tester.pumpWidget(host(bubble(msg(
        id: 'spoiled-1',
        formatting: const [
          FormattingEntity(start: 0, end: 2, type: FormattingType.spoiler),
        ],
      ))));
      await tester.pumpAndSettle();
      expect(find.byType(JumboEmojiBubble), findsNothing);
      expect(find.byType(LinkifiedText), findsOneWidget);
    });

    testWidgets('an ephemeral emoji keeps the frame that warns about it',
        (tester) async {
      await tester.pumpWidget(host(ephemeral(msg(
        id: 'eph-1',
        expiresAt: DateTime(2026, 3, 1, 12, 5),
      ))));
      await tester.pumpAndSettle();
      expect(find.byType(JumboEmojiBubble), findsNothing);
      expect(find.byType(LinkifiedText), findsOneWidget);
    });

    testWidgets('the entrance is spent once per message, not once per row',
        (tester) async {
      final m = msg(id: 'once-1');
      await tester.pumpWidget(host(bubble(m)));
      await tester.pump();
      expect(tester.binding.transientCallbackCount, greaterThan(0),
          reason: 'the first sighting animates');
      await tester.pumpAndSettle();

      // Scrolled away and back: a fresh State, same message.
      await tester.pumpWidget(host(const SizedBox()));
      await tester.pumpWidget(host(bubble(m)));
      await tester.pump();
      expect(tester.binding.transientCallbackCount, 0,
          reason: 'the second sighting does not');
    });

    testWidgets('reduce motion skips the entrance outright', (tester) async {
      await tester.pumpWidget(host(bubble(msg(id: 'calm-1')), calm: true));
      await tester.pump();
      expect(find.byType(JumboEmojiBubble), findsOneWidget);
      expect(tester.binding.transientCallbackCount, 0);
    });
  });
}
