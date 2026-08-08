import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monkeyhub/backend/chat_api.dart';
import 'package:monkeyhub/l10n/generated/app_localizations.dart';
import 'package:monkeyhub/models/chat_message.dart';
import 'package:monkeyhub/models/enums.dart';
import 'package:monkeyhub/screens/media_pager_screen.dart';
import 'package:monkeyhub/theme/basic_theme.dart';
import 'package:monkeyhub/theme/theme_scope.dart';
import 'package:monkeyhub/widgets/steady_hero.dart';
import 'package:monkeyhub/widgets/video_message.dart' show VideoPlayerSurface;

/// What this pins: **a video opens with the same flight a photo does.**
///
/// The shared-content grid flies a tapped photo into the pager and back out
/// again; a video used to cross-fade instead, because the page that owns a
/// player deliberately carried no hero — a `VideoPlayer` texture cannot be
/// flown between routes. The page being opened is by definition the one that
/// owns the player, so that rule removed the flight's destination exactly
/// where it was needed.
///
/// The fix flies the poster and hands over to the player on touchdown, which
/// makes the ordering the whole behaviour: a hero while the route is moving, a
/// player only once it has stopped, and the hero back again the moment it
/// starts leaving — or the pop has nothing to fly home.
class _FakeApi extends Fake implements ChatApi {
  @override
  Future<String?> getFileUrl(String storageId) async => null;
}

void main() {
  final api = _FakeApi();

  ChatMessage media(
    String id, {
    MessageType type = MessageType.video,
    String? poster = 'poster_1',
  }) => ChatMessage(
    id: id,
    roomId: 'r1',
    senderId: 'u1',
    senderName: 'ada',
    content: '',
    createdAt: DateTime(2026, 3, 1, 12),
    type: type,
    mediaStorageId: 'stor_$id',
    posterStorageId: poster,
  );

  // ThemeScope sits ABOVE the MaterialApp, exactly as `app.dart` builds it —
  // so a pushed route (and the overlay a hero flies in) is still inside it.
  // Nested under `home` instead, every route this test pushes would land
  // outside the scope and trip its assertion.
  Widget host(Widget home) => ThemeScope(
    controller: ThemeController(BasicTheme.midnight()),
    child: MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: home,
    ),
  );

  /// Opens the pager over an empty page and returns once the route is on
  /// screen but still moving.
  Future<void> openPager(
    WidgetTester tester, {
    required List<ChatMessage> items,
    int initialIndex = 0,
  }) async {
    late BuildContext ctx;
    await tester.pumpWidget(
      host(
        Builder(
          builder: (c) {
            ctx = c;
            return const SizedBox.expand();
          },
        ),
      ),
    );
    MediaPagerScreen.open(
      ctx,
      items: items,
      initialIndex: initialIndex,
      api: api,
    );
    await tester.pump();
    // A third of the way through the 200ms open — on screen, still in flight.
    await tester.pump(const Duration(milliseconds: 60));
  }

  /// The pager's own hero, not the grid tile's: both are alive during a
  /// flight, and only one of them is the thing under test.
  final pagerHero = find.descendant(
    of: find.byType(MediaPagerScreen),
    matching: find.byType(SteadyHero),
  );

  testWidgets('a video in flight is a poster, not a player', (tester) async {
    await openPager(tester, items: [media('m1')]);

    expect(
      pagerHero,
      findsOneWidget,
      reason: 'the page being opened is what the flight has to land on',
    );
    expect(
      find.byType(VideoPlayerSurface),
      findsNothing,
      reason: 'a video texture cannot be flown; the poster stands in for it',
    );
  });

  testWidgets('the player takes over once the route has landed', (
    tester,
  ) async {
    await openPager(tester, items: [media('m1')]);
    await tester.pump(const Duration(milliseconds: 200));
    // The route reaching `completed` is what flips the page over; the setState
    // that carries lands on the next frame.
    await tester.pump();

    expect(find.byType(VideoPlayerSurface), findsOneWidget);
  });

  testWidgets('closing puts the poster back so the pop has something to fly', (
    tester,
  ) async {
    await openPager(tester, items: [media('m1')]);
    await tester.pump(const Duration(milliseconds: 200));
    await tester.pump();
    expect(find.byType(VideoPlayerSurface), findsOneWidget);

    Navigator.of(tester.element(find.byType(MediaPagerScreen))).pop();
    // One frame: the route's status turns to `reverse` the instant it is
    // popped, and Flutter goes looking for flight candidates in the post-frame
    // callback of this very frame. A page that swapped back any later would
    // pop with no hero at all.
    await tester.pump();

    expect(pagerHero, findsOneWidget);
    expect(
      find.byType(VideoPlayerSurface),
      findsNothing,
      reason: 'a video still playing over a closing route is one you can hear',
    );

    await tester.pump(const Duration(milliseconds: 400));
  });

  testWidgets('only the page on screen may fly', (tester) async {
    // `PageView` builds its neighbours, and each carries the same tag its own
    // grid tile does — so without HeroMode, opening one photo launches three
    // flights and drags two thumbnails off the side of the screen.
    await openPager(
      tester,
      items: [media('m1'), media('m2'), media('m3')],
      initialIndex: 1,
    );

    final enabled = tester
        .widgetList<HeroMode>(
          find.descendant(
            of: find.byType(MediaPagerScreen),
            matching: find.byType(HeroMode),
          ),
        )
        .where((h) => h.enabled)
        .length;
    expect(enabled, 1);
  });
}
