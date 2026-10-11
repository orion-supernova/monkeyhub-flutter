@TestOn('vm')
library;

import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monkeyhub/backend/chat_api.dart';
import 'package:monkeyhub/backend/convex_client.dart';
import 'package:monkeyhub/l10n/generated/app_localizations.dart';
import 'package:monkeyhub/models/chat_message.dart';
import 'package:monkeyhub/models/enums.dart';
import 'package:monkeyhub/theme/basic_theme.dart';
import 'package:monkeyhub/theme/theme_scope.dart';
import 'package:monkeyhub/widgets/photo_deck.dart';
import 'package:monkeyhub/widgets/photo_mosaic.dart' show MosaicTile;

/// An album dealt as cards: a swipe toward the peeking edge deals the next
/// card, the other way takes the last one back, both wrap, and a tap always
/// opens the card that is in front. The front card is read back through what
/// a tap opens, which is the only thing about it a reader can act on.
void main() {
  final api = ChatApi(ConvexBackend.instance);

  ChatMessage photo(String id, {bool video = false}) => ChatMessage(
        id: id,
        roomId: 'r',
        senderId: 'alice',
        senderName: 'alice',
        content: '',
        createdAt: DateTime(2026, 3, 1),
        type: video ? MessageType.video : MessageType.image,
      );

  late List<String> opened;
  final deck = GlobalKey();

  Future<void> pump(WidgetTester tester, int n,
      {String? highlight, bool Function(int i)? video}) async {
    opened = [];
    await tester.pumpWidget(ThemeScope(
      controller: ThemeController(BasicTheme.midnight()),
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: Center(
            child: PhotoDeck(
              key: deck,
              photos: [
                for (var i = 0; i < n; i++)
                  photo('m$i', video: video?.call(i) ?? false),
              ],
              api: api,
              width: 260,
              radius: BorderRadius.circular(18),
              currentUserId: 'bob',
              highlightedPhotoId: highlight,
              onOpen: (m, {required sourceDecodeWidth}) => opened.add(m.id),
            ),
          ),
        ),
      ),
    ));
  }

  Future<String> front(WidgetTester tester) async {
    final box = tester.getRect(find.byKey(deck));
    // The front card is flush with the trailing edge; its middle is clear of
    // every peeking edge.
    await tester.tapAt(Offset(box.right - 60, box.center.dy));
    await tester.pumpAndSettle();
    return opened.removeLast();
  }

  Future<void> swipe(WidgetTester tester, double dx) async {
    await tester.drag(find.byKey(deck), Offset(dx, 0));
    await tester.pumpAndSettle();
  }

  testWidgets('a hand opens on its first photograph', (tester) async {
    await pump(tester, 4);
    expect(await front(tester), 'm0');
  });

  testWidgets('swiping left deals the next card, and stops at the last',
      (tester) async {
    await pump(tester, 3);
    await swipe(tester, -200);
    expect(await front(tester), 'm1');
    await swipe(tester, -200);
    await swipe(tester, -200);
    expect(await front(tester), 'm2');
  });

  testWidgets('swiping right goes back, and stops at the first',
      (tester) async {
    await pump(tester, 5);
    await swipe(tester, 200);
    expect(await front(tester), 'm0');
    await swipe(tester, -200);
    expect(await front(tester), 'm1');
    await swipe(tester, 200);
    expect(await front(tester), 'm0');
  });

  testWidgets('a nudge springs back without dealing', (tester) async {
    await pump(tester, 4);
    await swipe(tester, -30);
    expect(await front(tester), 'm0');
  });

  testWidgets('a jump to a photograph deals it to the front', (tester) async {
    await pump(tester, 4, highlight: 'm2');
    expect(await front(tester), 'm2');
  });

  testWidgets('a swipe moves the cards without rebuilding them', (tester) async {
    await pump(tester, 4);
    MosaicTile tile(String id) => tester.widget<MosaicTile>(find.byWidgetPredicate(
        (w) => w is MosaicTile && w.message.id == id));
    final before = tile('m0');
    final g = await tester.startGesture(tester.getCenter(find.byKey(deck)));
    for (var i = 0; i < 10; i++) {
      await g.moveBy(const Offset(-8, 0));
      await tester.pump(const Duration(milliseconds: 16));
      expect(identical(tile('m0'), before), isTrue,
          reason: 'a card face rebuilt on frame $i of a drag');
    }
    await g.up();
    await tester.pumpAndSettle();
  });

  testWidgets('pulled past the first card, the hand gives and comes back',
      (tester) async {
    await pump(tester, 5);
    final tile = find.byWidgetPredicate(
        (w) => w is MosaicTile && w.message.id == 'm0');
    final rest = tester.getRect(tile);
    final g = await tester.startGesture(tester.getCenter(find.byKey(deck)));
    await g.moveBy(const Offset(20, 0));
    await g.moveBy(const Offset(80, 0));
    await tester.pump(const Duration(milliseconds: 16));
    final pulled = tester.getRect(tile).left - rest.left;
    // Gives, but less than the finger moved.
    expect(pulled, greaterThan(4));
    expect(pulled, lessThan(60));
    await g.up();
    await tester.pumpAndSettle();
    expect(tester.getRect(tile), rest);
    expect(await front(tester), 'm0');
  });

  testWidgets('a swipe back brings the previous card round from behind',
      (tester) async {
    await pump(tester, 5, highlight: 'm2');
    final box = tester.getRect(find.byKey(deck));
    final g = await tester.startGesture(tester.getCenter(find.byKey(deck)));
    await g.moveBy(const Offset(20, 0));
    await g.moveBy(const Offset(30, 0));
    await tester.pump(const Duration(milliseconds: 16));
    // Only the card going back out to the right leaves the deck's bounds;
    // the previous one comes round the other side.
    for (final id in ['m1', 'm3', 'm4']) {
      final tile = find.byWidgetPredicate(
          (w) => w is MosaicTile && w.message.id == id);
      expect(tester.getRect(tile).right, lessThanOrEqualTo(box.right + 0.5),
          reason: '$id hangs out past the deck mid-swipe');
    }
    await g.moveBy(const Offset(150, 0));
    await g.up();
    await tester.pumpAndSettle();
    expect(await front(tester), 'm1');
  });

  testWidgets('the last card offers the way back to the first',
      (tester) async {
    await pump(tester, 3);
    final back = find.byIcon(CupertinoIcons.arrow_counterclockwise);
    expect(back, findsNothing);
    await swipe(tester, -200);
    await swipe(tester, -200);
    expect(await front(tester), 'm2');
    await tester.tap(back);
    await tester.pumpAndSettle();
    expect(await front(tester), 'm0');
    expect(back, findsNothing);
  });

  testWidgets('one long slow swipe runs through several cards in order',
      (tester) async {
    await pump(tester, 5);
    // 2.2 cards of travel (a card is 0.8 of the card's width), slowly enough
    // that letting go coasts nowhere.
    final step = PhotoDeck.cardWidth(260, 5) * 0.8;
    await tester.timedDrag(find.byKey(deck), Offset(-step * 2.2 - 20, 0),
        const Duration(seconds: 2));
    await tester.pumpAndSettle();
    expect(await front(tester), 'm2');
  });

  testWidgets('a video card carries a play button, a photo does not',
      (tester) async {
    await pump(tester, 3, video: (i) => i == 1);
    final play = find.byIcon(CupertinoIcons.play_fill);
    expect(play, findsOneWidget);
    expect(
        find.ancestor(
            of: play,
            matching: find.byWidgetPredicate(
                (w) => w is MosaicTile && w.message.id == 'm1')),
        findsOneWidget);
  });

  testWidgets('five or more count instead of drawing dots', (tester) async {
    await pump(tester, 4);
    expect(find.text('1 / 4'), findsNothing);
    await pump(tester, 5);
    expect(find.text('1 / 5'), findsOneWidget);
    await swipe(tester, -200);
    expect(find.text('2 / 5'), findsOneWidget);
  });
}
