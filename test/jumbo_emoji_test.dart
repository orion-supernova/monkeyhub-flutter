import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
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
      expect(jumboEmojiRun('the quick brown fox ' * 20), isNull);
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

    // A real window size, because a bubble's max width is a fraction of it
    // and `MediaQueryData()` alone reports zero. At zero the transcript row
    // gives the bubble a tight zero width, and a RenderFlex that size skips
    // painting altogether — which is a bubble that measures but never draws,
    // and a test that cannot tell.
    Widget host(Widget child, {bool calm = false, double width = 500}) {
      return MediaQuery(
        data: MediaQueryData(
          size: const Size(800, 600),
          disableAnimations: calm,
        ),
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: ThemeScope(
            controller: ThemeController(BasicTheme.midnight()),
            child: Scaffold(
              body: Align(
                alignment: Alignment.topLeft,
                child: SizedBox(width: width, child: child),
              ),
            ),
          ),
        ),
      );
    }

    Widget bubble(ChatMessage m) => MessageBubble(
      message: m,
      now: DateTime(2026, 3, 1, 12, 0, 5),
      currentUserId: 'bob',
      api: api,
    );

    Widget ephemeral(ChatMessage m) => EphemeralMessageBubble(
      message: m,
      now: ValueNotifier(DateTime(2026, 3, 1, 12, 0, 5)),
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
      // A spoiler shimmers for as long as it is on screen, so this never
      // settles. A fixed span is plenty: the shape of the tree is decided on
      // the first frame.
      await tester.pump(const Duration(seconds: 1));
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

    testWidgets('a glyph the font draws whole is drawn at its natural size',
        (tester) async {
      await tester.pumpWidget(host(const JumboEmojiBubble(
        identity: 'whole-1',
        clusters: ['🎉'],
        isMine: false,
      )));
      await tester.pumpAndSettle();
      // The tightened line box at the one-glyph size, unscaled. The guard the
      // next test exercises has to cost the ordinary message nothing.
      final glyph = tester.getRect(find.text('🎉'));
      expect(glyph.height, closeTo(JumboEmojiBubble.glyphSize(1) * 1.12, 1));
    });

    testWidgets('a cluster the font cannot compose scales down to the bubble',
        (tester) async {
      // The test font composes nothing, so a ZWJ family is drawn as its
      // pieces side by side — several glyphs wide, which is exactly how a
      // platform whose emoji font predates the sequence draws it. That run is
      // wider than a narrow bubble, and it has to fit rather than overflow.
      await tester.pumpWidget(host(
        const JumboEmojiBubble(
          identity: 'pieces-1',
          clusters: ['👨‍👩‍👧‍👦'],
          isMine: false,
        ),
        width: 120,
      ));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      final box = tester.getRect(find.byType(JumboEmojiBubble));
      final glyph = tester.getRect(find.text('👨‍👩‍👧‍👦'));
      expect(glyph.left, greaterThanOrEqualTo(box.left - 0.01));
      expect(glyph.right, lessThanOrEqualTo(box.right + 0.01));
      // …and it is the glyph that gave way, not the bubble.
      expect(glyph.height, lessThan(50));
    });

    // Never `pumpAndSettle` past this point: a heart's beat never settles, so
    // it would run to the timeout rather than to a frame.

    testWidgets('a heart keeps beating long after it has arrived',
        (tester) async {
      await tester.pumpWidget(host(bubble(msg(id: 'beat-1', content: '❤️'))));
      // Well past the arrival, which is under two seconds all told.
      await tester.pump(const Duration(seconds: 10));
      expect(tester.binding.transientCallbackCount, greaterThan(0));
    });

    testWidgets('an emoji with no heart in it stops', (tester) async {
      await tester.pumpWidget(host(bubble(msg(id: 'still-1'))));
      await tester.pumpAndSettle();
      expect(tester.binding.transientCallbackCount, 0);
    });

    testWidgets('a calm heart never starts', (tester) async {
      await tester.pumpWidget(
          host(bubble(msg(id: 'calm-heart-1', content: '❤️')), calm: true));
      await tester.pump(const Duration(seconds: 3));
      expect(find.byType(JumboEmojiBubble), findsOneWidget);
      expect(tester.binding.transientCallbackCount, 0);
    });

    testWidgets('a beating heart re-rasterises nothing', (tester) async {
      await tester.pumpWidget(host(bubble(msg(id: 'perf-1', content: '❤️'))));
      // Past the arrival: from here on the only thing moving is the beat.
      await tester.pump(const Duration(seconds: 3));

      // The glyph has a boundary of its own — without it the transform above
      // would re-rasterise a 56pt colour glyph on every frame of the beat,
      // forever, which is the one thing about this feature that could
      // plausibly cost the transcript its frames.
      final boundary = tester.renderObject<RenderRepaintBoundary>(
        find
            .ancestor(
                of: find.text('❤️'), matching: find.byType(RepaintBoundary))
            .first,
      );
      boundary.debugResetMetrics();

      const frames = 72; // a shade over one full cycle at 60Hz
      for (var i = 0; i < frames; i++) {
        await tester.pump(const Duration(milliseconds: 16));
      }

      // Flutter's own definition of a boundary earning its keep: the child
      // never repainted at the same time as its parent. The parent's transform
      // changed on every beating frame and the paragraph under it did not.
      expect(boundary.debugSymmetricPaintCount, 0);
      // And through the rest between thumps the scale is snapped to exactly
      // one, so the matrix does not change and nothing is marked dirty at all
      // — most of a cycle costs nothing beyond the frame itself.
      expect(boundary.debugAsymmetricPaintCount, lessThan(frames * 0.6));
    });

    testWidgets('the burst leaves the glyph on a beat, not between two',
        (tester) async {
      await tester.pumpWidget(host(bubble(msg(id: 'sync-1', content: '❤️'))));
      // The pop runs 460ms and the burst starts the instant it ends. The
      // heartbeat is phased so its thump lands exactly there — which is only
      // observable as the glyph being *bigger* at that moment than it is
      // halfway through the following rest.
      await tester.pump(const Duration(milliseconds: 460));
      final onBeat = tester.getRect(find.text('❤️')).width;
      await tester.pump(const Duration(milliseconds: 575));
      final atRest = tester.getRect(find.text('❤️')).width;
      expect(onBeat, greaterThan(atRest * 1.05));
    });
  });
}
