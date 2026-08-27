@TestOn('vm')
library;

import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monkeyhub/backend/chat_api.dart';
import 'package:monkeyhub/backend/convex_client.dart';
import 'package:monkeyhub/l10n/generated/app_localizations.dart';
import 'package:monkeyhub/models/chat_message.dart';
import 'package:monkeyhub/models/enums.dart';
import 'package:monkeyhub/screens/media_pager_screen.dart';
import 'package:monkeyhub/screens/fullscreen_image_viewer.dart'
    show thumbnailDecodeWidth;
import 'package:monkeyhub/theme/basic_theme.dart';
import 'package:monkeyhub/theme/theme_scope.dart';
import 'package:monkeyhub/widgets/highlight_pulse.dart';
import 'package:monkeyhub/widgets/message_bubble.dart';
import 'package:monkeyhub/widgets/message_stamp.dart';
import 'package:monkeyhub/widgets/room_gallery_scope.dart';
import 'package:monkeyhub/widgets/photo_mosaic.dart';
import 'package:monkeyhub/widgets/remote_image.dart';
import 'package:monkeyhub/widgets/steady_hero.dart';

/// A photograph in an album has to fly, and a jump to one has to land ON it.
///
/// Both used to fail silently, which is the whole reason for pinning them here.
/// A `Hero` whose tag matches nothing in the other route does not throw — it
/// cross-fades, and a cross-fade is exactly what "no flight" looks like. A
/// highlight aimed at a message no row claims does not throw either; it simply
/// pulses nothing. Neither leaves a mark anywhere a test could trip over by
/// accident, so every assertion below is deliberate.
void main() {
  final api = ChatApi(ConvexBackend.instance);
  final now = DateTime(2026, 3, 1, 12);

  ChatMessage photo(String id) => ChatMessage(
        id: id,
        roomId: 'r',
        senderId: 'alice',
        senderName: 'alice',
        content: '',
        createdAt: now,
        type: MessageType.image,
        mediaStorageId: 'blob_$id',
        mediaWidth: 800,
        mediaHeight: 600,
      );

  List<ChatMessage> album(int n) => [for (var i = 0; i < n; i++) photo('m$i')];

  const width = 260.0;
  final radius = BorderRadius.circular(18);

  Widget host(Widget child) => ThemeScope(
        controller: ThemeController(BasicTheme.midnight()),
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          // Loose constraints, deliberately. A `SizedBox(width: 500)` here
          // would hand the block a TIGHT 500 and its own `SizedBox(width:
          // 260)` cannot shrink below an enforced minimum — so every tile
          // would be measured at a width the app never draws it at.
          home: Scaffold(
            body: Align(alignment: Alignment.topLeft, child: child),
          ),
        ),
      );

  Widget mosaic(
    List<ChatMessage> photos, {
    void Function(ChatMessage m, int decodeWidth)? onOpen,
    String? highlightedPhotoId,
    double highlightT = 0,
  }) =>
      PhotoMosaic(
        photos: photos,
        api: api,
        width: width,
        radius: radius,
        currentUserId: 'bob',
        onOpen: (m, {required sourceDecodeWidth}) =>
            onOpen?.call(m, sourceDecodeWidth),
        highlightedPhotoId: highlightedPhotoId,
        highlightT: highlightT,
      );

  /// The mark a pulsing tile paints on its photograph — an accent wash under an
  /// accent stroke. A bubble's halo is a shadow outside the shape; a tile has
  /// no outside to put one in.
  final tileMark = find.byWidgetPredicate(
    (w) =>
        w is DecoratedBox &&
        w.decoration is BoxDecoration &&
        (w.decoration as BoxDecoration).border != null,
  );

  group('a tile is something a flight can reach', () {
    testWidgets('every photograph of a block carries its own album tag', (
      tester,
    ) async {
      final photos = album(5);
      await tester.pumpWidget(host(mosaic(photos)));

      final tags = tester
          .widgetList<SteadyHero>(find.byType(SteadyHero))
          .map((h) => h.tag)
          .toList();
      expect(tags, [for (final p in photos) mosaicHeroTag(p)]);
      // And emphatically NOT the lone-bubble tag. The gallery is handed
      // messages, not widgets, so it rebuilds one of these two strings from
      // scratch; the wrong one matches no hero and every open cross-fades.
      expect(tags, isNot(contains(bubbleMediaHeroTag(photos.first))));
    });

    testWidgets('and a shuttle, so the crop animates instead of cutting', (
      tester,
    ) async {
      await tester.pumpWidget(host(mosaic(album(4))));

      final heroes = tester.widgetList<SteadyHero>(find.byType(SteadyHero));
      expect(heroes, hasLength(4));
      for (final hero in heroes) {
        expect(
          hero.flightShuttleBuilder,
          isNotNull,
          reason: 'without one the flight paints the DESTINATION — a `contain` '
              'image on a full screen — so a square-cropped tile letterboxes '
              'itself at the small end and snaps to its crop on landing',
        );
      }
    });

    testWidgets('the decode a tap reports is the one the tile is painting', (
      tester,
    ) async {
      // The gallery flies this decode and lands on it. An approximation is a
      // different `ImageCache` entry, which misses, which is a shimmer.
      final photos = album(5);
      final reported = <String, int>{};
      await tester.pumpWidget(host(mosaic(
        photos,
        onOpen: (m, w) => reported[m.id] = w,
      )));

      final context = tester.element(find.byType(PhotoMosaic));
      for (var i = 0; i < photos.length; i++) {
        await tester.tap(find.byType(SteadyHero).at(i));
        expect(
          reported[photos[i].id],
          thumbnailDecodeWidth(context, mosaicTileSide(5, width, i)),
          reason: 'tile $i of 5',
        );
      }
    });
  });

  group('tile geometry', () {
    for (final n in [2, 3, 4, 5, 6, 7, 8, 9, 10]) {
      testWidgets('$n photographs: the sides agree with the layout', (
        tester,
      ) async {
        await tester.pumpWidget(host(mosaic(album(n))));
        for (var i = 0; i < n; i++) {
          expect(
            tester.getSize(find.byType(SteadyHero).at(i)).width,
            closeTo(mosaicTileSide(n, width, i), 0.01),
            reason: 'tile $i of $n — the decode hint has to be the width the '
                'tile is really painted at, or the flight looks it up in the '
                'ImageCache under a key nothing ever wrote',
          );
        }
      });
    }

    test("only the block's own corners are rounded", () {
      BorderRadius r(int n, int i) => mosaicTileRadius(n, radius, i);
      final round = radius.topLeft;

      // Two across: one row, so the pair take two corners each.
      expect(r(2, 0), BorderRadius.only(topLeft: round, bottomLeft: round));
      expect(r(2, 1), BorderRadius.only(topRight: round, bottomRight: round));

      // Three is featured: the big one owns the whole leading edge.
      expect(r(3, 0), BorderRadius.only(topLeft: round, bottomLeft: round));
      expect(r(3, 1), BorderRadius.only(topRight: round));
      expect(r(3, 2), BorderRadius.only(bottomRight: round));

      // Four is two rows of two: one corner each, and nothing else.
      expect(r(4, 0), BorderRadius.only(topLeft: round));
      expect(r(4, 1), BorderRadius.only(topRight: round));
      expect(r(4, 2), BorderRadius.only(bottomLeft: round));
      expect(r(4, 3), BorderRadius.only(bottomRight: round));

      // Five is a row of two over a row of three; the middle of the bottom row
      // touches no edge of the block at all.
      expect(r(5, 2), BorderRadius.only(bottomLeft: round));
      expect(r(5, 3), BorderRadius.zero);
      expect(r(5, 4), BorderRadius.only(bottomRight: round));

      // Ten is the cap, and most of it is interior.
      expect(r(10, 0), BorderRadius.only(topLeft: round));
      expect(r(10, 9), BorderRadius.only(bottomRight: round));
      for (final i in [2, 3, 5, 6, 8]) {
        expect(r(10, i), BorderRadius.zero, reason: 'tile $i of 10 is interior');
      }
    });

    test('the plan a block is drawn with accounts for every photograph', () {
      for (var n = 2; n <= 10; n++) {
        if (mosaicFeatured(n)) continue;
        expect(mosaicRowPlan(n).fold<int>(0, (a, b) => a + b), n);
      }
    });
  });

  group('a jump lands on the picture, not the block', () {
    testWidgets('the named tile is marked and the others are not', (
      tester,
    ) async {
      await tester.pumpWidget(host(mosaic(
        album(5),
        highlightedPhotoId: 'm2',
        // Mid-arc, where the pulse is at its loudest.
        highlightT: 0.5,
      )));

      // One tile carries the mark. "Somewhere in this block" is the bug the
      // trip existed to answer.
      expect(tileMark, findsOneWidget);
      expect(
        tester.getRect(tileMark).center,
        tester.getRect(find.byType(SteadyHero).at(2)).center,
        reason: 'the mark belongs to m2, which is the third tile',
      );
    });

    testWidgets('nothing is marked when the block is not the target', (
      tester,
    ) async {
      await tester.pumpWidget(host(mosaic(album(5), highlightT: 0.5)));
      expect(tileMark, findsNothing);
    });

    testWidgets('the block stands down while one of its tiles is lit', (
      tester,
    ) async {
      final photos = album(5);
      Widget bubble({String? albumHighlightId}) => MessageBubble(
            message: photos.last,
            now: now,
            currentUserId: 'bob',
            api: api,
            album: photos,
            highlightT: 0.5,
            albumHighlightId: albumHighlightId,
            albumHighlightT: 0.5,
          );

      await tester.pumpWidget(host(bubble(albumHighlightId: 'm2')));
      expect(
        tester.widget<HighlightPulse>(find.byType(HighlightPulse)).t,
        0,
        reason: 'ringing the block AND the tile inside it is two answers to '
            'one question',
      );

      await tester.pumpWidget(host(bubble()));
      expect(
        tester.widget<HighlightPulse>(find.byType(HighlightPulse)).t,
        0.5,
        reason: 'a row that is its own target still pulses as a whole',
      );
    });
  });

  testWidgets('a tapped tile really flies — end to end, through the gallery', (
    tester,
  ) async {
    // The claim the rest of this file only approaches one piece at a time.
    // What made it fail was one line in the room screen handing the gallery
    // `bubbleMediaHeroTag` for every photograph, album or not: a tag no tile in
    // the transcript wears. Nothing throws on a tag that matches nothing —
    // Flutter cross-fades — so this pins the observable consequence instead.
    final photos = album(4);
    late BuildContext ctx;
    await tester.pumpWidget(host(
      Builder(builder: (c) {
        ctx = c;
        return RoomGalleryScope(
          openGallery: (m, {required sourceDecodeWidth}) =>
              MediaPagerScreen.open(
            ctx,
            items: photos,
            initialIndex: photos.indexOf(m),
            api: api,
            heroTagFor: mosaicHeroTag,
            sourceDecodeWidth: sourceDecodeWidth,
          ),
          child: MessageBubble(
            message: photos.last,
            now: now,
            currentUserId: 'bob',
            api: api,
            album: photos,
          ),
        );
      }),
    ));

    final tile = tester.getSize(find.byType(SteadyHero).first);
    await tester.tap(find.byType(SteadyHero).first);
    await tester.pump();
    // Halfway through the 200ms open: the picture is in the air.
    await tester.pump(const Duration(milliseconds: 100));

    // The tile's slot is held open and emptied — a flight is under way and this
    // photograph is the thing in it.
    expect(
      find.descendant(
        of: find.byType(PhotoMosaic),
        matching: find.byType(Opacity),
      ),
      findsWidgets,
      reason: 'SteadyHero holds the slot at Opacity(0) for the length of a '
          'flight; no flight, no placeholder',
    );

    // And something is being drawn at neither end's size, which is only true of
    // a shuttle mid-crossing.
    final page = tester.getSize(find.byType(MediaPagerScreen));
    final sizes = tester
        .widgetList<RemoteImage>(find.byType(RemoteImage))
        .map((w) => tester.getSize(find.byWidget(w)).width)
        .toList();
    expect(
      sizes.any((w) => w > tile.width + 1 && w < page.width - 1),
      isTrue,
      reason: 'a cross-fade paints the picture at the destination size from '
          'the first frame; a flight paints it in between',
    );
  });

  testWidgets('the stamp gets out of the way while a picture is away', (
    tester,
  ) async {
    // The stamp sits in the block's bottom-trailing corner, which is a TILE's
    // corner — the very tile most likely to be the one that just flew. Left
    // where it was, it hangs in the air over the hole.
    final photos = album(4);
    final trip = Completer<void>();
    await tester.pumpWidget(host(
      RoomGalleryScope(
        openGallery: (m, {required sourceDecodeWidth}) => trip.future,
        child: MessageBubble(
          message: photos.last,
          now: now,
          currentUserId: 'bob',
          api: api,
          album: photos,
        ),
      ),
    ));

    expect(find.byType(MessageStamp), findsOneWidget);

    await tester.tap(find.byType(SteadyHero).last);
    await tester.pump();
    expect(
      find.byType(MessageStamp),
      findsNothing,
      reason: 'the picture under it is mid-flight',
    );

    trip.complete();
    await tester.pump();
    expect(find.byType(MessageStamp), findsOneWidget);
  });

  group('what the source has to keep doing', () {
    late String roomScreen;

    setUpAll(() {
      roomScreen = File('lib/screens/room_screen.dart').readAsStringSync();
    });

    /// The body of [signature], with comment lines dropped — prose explaining
    /// why a call is absent necessarily names that call. Same carve-out
    /// `room_content_jump_test.dart` makes.
    String bodyOf(String signature) {
      final start = roomScreen.indexOf(signature);
      expect(start, isNonNegative, reason: '$signature was renamed or removed');
      final end = roomScreen.indexOf('\n  }\n', start);
      expect(end, isNonNegative, reason: 'could not bound $signature');
      return roomScreen
          .substring(start, end)
          .split('\n')
          .where((l) => !l.trimLeft().startsWith('//'))
          .join('\n');
    }

    test('the gallery is told which of the two tags a photo wears', () {
      final body = bodyOf('Object _transcriptHeroTag(');
      expect(body, contains('mosaicHeroTag'));
      expect(body, contains('bubbleMediaHeroTag'));
      expect(
        bodyOf('Future<void> _openGallery('),
        contains('heroTagFor: _transcriptHeroTag'),
        reason: 'handing it bubbleMediaHeroTag flat is what made every album '
            'photo open as a cross-fade',
      );
    });

    test('SHOW IN CHAT travels after the pager has gone, not during', () {
      final body = bodyOf('Future<void> _openGallery(');
      final opened = body.indexOf('onShowInChat:');
      // Bounded at the callback's own closing brace: the travelling itself
      // lives further down the same method, and an unbounded slice would read
      // it as proof of the very thing this forbids.
      final callback = body.substring(opened, body.indexOf('\n      },', opened));
      expect(
        callback.contains('_jumpToMessage'),
        isFalse,
        reason: 'scrolling on the frame the pager starts its exit leaves the '
            'Hero flying home to a rect that has already moved',
      );
      expect(body, contains('travelTo'));
      expect(body, contains('await _jumpToMessage('));
    });

    test('a trip to where you already are pushes no back pill', () {
      expect(
        bodyOf('Future<void> _jumpToMessage('),
        contains('messageId == from.id'),
        reason: 'SHOW IN CHAT without swiping travels to the photo the gallery '
            'was opened from, and the pill would point at itself',
      );
    });

    test('the transcript is kept under the picture the reader swiped to', () {
      expect(
        bodyOf('Future<void> _openGallery('),
        contains('onPageChanged: _alignTranscriptTo'),
      );
      final align = bodyOf('Future<void> _alignTranscriptTo(');
      expect(
        align,
        contains('settle: Duration.zero'),
        reason: 'nobody can see this happen — the gallery is over it',
      );
      expect(
        align,
        contains('_aligning'),
        reason: 'a fast swipe fires one of these per page, and two snapToIndex '
            'walks at once fight over the same controller',
      );
    });

    test('an album member resolves to the row that draws it', () {
      expect(
        bodyOf('BuildContext? _rowContextOf('),
        contains('_rowOwner'),
        reason: "_dateTracks is keyed by the ROW's message, so a lookup under "
            "the third picture's id finds no render box",
      );
    });
  });
}
