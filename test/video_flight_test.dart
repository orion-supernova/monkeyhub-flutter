import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monkeyhub/backend/chat_api.dart';
import 'package:monkeyhub/l10n/generated/app_localizations.dart';
import 'package:monkeyhub/media/native_video_player.dart';
import 'package:monkeyhub/models/chat_message.dart';
import 'package:monkeyhub/models/enums.dart';
import 'package:monkeyhub/screens/fullscreen_video_viewer.dart';
import 'package:monkeyhub/screens/media_pager_screen.dart';
import 'package:monkeyhub/theme/basic_theme.dart';
import 'package:monkeyhub/theme/theme_scope.dart';
import 'package:monkeyhub/widgets/steady_hero.dart';
import 'package:monkeyhub/widgets/video_message.dart'
    show VideoMessage, VideoPlayerSurface;

/// What this pins: **a video is watched in the OS player, and its poster flies
/// there.**
///
/// Three bugs met around one widget. The shared-content gallery mounted a
/// Flutter `VideoPlayerSurface` inline, so the one screen in the app that shows
/// nothing but media was the one screen where a video played worst — none of
/// the scrubbing, speed, AirPlay, Picture-in-Picture or lock-screen controls a
/// tap in the transcript already gets for free from `AVPlayerViewController`.
/// Because a `VideoPlayer` texture cannot be flown between routes, the page
/// that owned it carried no hero — and that is the page being opened, so a
/// video was also the one thing there that arrived with no flight. And a video
/// bubble in the transcript had never had one either.
///
/// The shape that fixes all three: nothing in Flutter plays the video, a poster
/// is what flies, and the poster hands over to the real thing on touchdown —
/// invisibly, because the real thing draws that same poster letterboxed into
/// the same box.
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
  // Nested under `home` instead, every route these tests push would land
  // outside the scope and trip its assertion.
  Widget host(Widget home) => ThemeScope(
    controller: ThemeController(BasicTheme.midnight()),
    child: MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: home,
    ),
  );

  /// Pumps an empty page and hands back a context to push routes from.
  Future<BuildContext> stage(WidgetTester tester) async {
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
    return ctx;
  }

  /// The handoff decision is a platform question, and `flutter test` reports
  /// neither iOS nor Android — so without this every case below would take the
  /// unsupported branch and the OS player would never be reached.
  setUp(() => NativeVideoPlayer.debugSupportedOverride = true);
  tearDown(() => NativeVideoPlayer.debugSupportedOverride = null);

  group('the gallery', () {
    /// The pager's own hero, not the grid tile's: both are alive during a
    /// flight, and only one of them is the thing under test.
    final pagerHero = find.descendant(
      of: find.byType(MediaPagerScreen),
      matching: find.byType(SteadyHero),
    );

    Future<void> openPager(
      WidgetTester tester, {
      required List<ChatMessage> items,
      int initialIndex = 0,
    }) async {
      final ctx = await stage(tester);
      MediaPagerScreen.open(
        ctx,
        items: items,
        initialIndex: initialIndex,
        api: api,
      );
      await tester.pump();
      // A third of the way through the 200ms open — on screen, still moving.
      await tester.pump(const Duration(milliseconds: 60));
    }

    testWidgets('never mounts a player of its own', (tester) async {
      await openPager(tester, items: [media('m1')]);
      await tester.pump(const Duration(milliseconds: 400));

      expect(
        find.descendant(
          of: find.byType(MediaPagerScreen),
          matching: find.byType(VideoPlayerSurface),
        ),
        findsNothing,
        reason: 'the OS player owns playback; this page owns a poster',
      );
    });

    testWidgets('keeps a poster to fly, before and after landing', (
      tester,
    ) async {
      await openPager(tester, items: [media('m1')]);
      expect(
        pagerHero,
        findsOneWidget,
        reason: 'the page being opened is what the flight has to land on',
      );

      await tester.pump(const Duration(milliseconds: 400));
      expect(
        pagerHero,
        findsOneWidget,
        reason: 'and it is still there for the pop to fly home',
      );
    });

    testWidgets('a video reached by swiping waits to be asked', (tester) async {
      await openPager(
        tester,
        items: [media('p1', type: MessageType.image), media('m2')],
      );
      await tester.pump(const Duration(milliseconds: 400));

      await tester.drag(find.byType(PageView), const Offset(-600, 0));
      await tester.pump(const Duration(milliseconds: 600));
      await tester.pump();

      expect(
        find.byType(FullscreenVideoViewer),
        findsNothing,
        reason: 'a fullscreen player shoved up on every swipe past a video '
            'would make the gallery unswipeable',
      );
      // Scoped to the page, not the whole route: the thumbnail rail marks the
      // video with the same glyph so you can pick it out of forty photographs,
      // which is a second (correct) play glyph on screen.
      expect(
        find.descendant(
          of: find.byType(PageView),
          matching: find.byIcon(CupertinoIcons.play_fill),
        ),
        findsOneWidget,
      );
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
  });

  group('the viewer', () {
    final viewerHero = find.descendant(
      of: find.byType(FullscreenVideoViewer),
      matching: find.byType(SteadyHero),
    );

    Future<void> open(WidgetTester tester, {Object? heroTag}) async {
      final ctx = await stage(tester);
      FullscreenVideoViewer.open(
        ctx,
        storageId: 'stor_m1',
        api: api,
        posterStorageId: 'poster_1',
        heroTag: heroTag,
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 60));
    }

    testWidgets('flies the poster in, then gets out of its own way', (
      tester,
    ) async {
      await open(tester, heroTag: 'msg-video-m1');
      expect(
        viewerHero,
        findsOneWidget,
        reason: 'the still is what a texture cannot be: flyable',
      );

      await tester.pump(const Duration(milliseconds: 400));
      await tester.pump();
      expect(
        viewerHero,
        findsNothing,
        reason: 'the hero has done its job; what is under it is the real thing',
      );
    });

    testWidgets('no tag, no hero — and no half-installed flight either', (
      tester,
    ) async {
      await open(tester);
      expect(viewerHero, findsNothing);
      await tester.pump(const Duration(milliseconds: 400));
    });

    // Not covered here: that a successful handoff pops this route, which is
    // what makes closing the OS player one gesture rather than two. Reaching it
    // means driving the real resolve — the cache lookup, the download, the
    // platform channel — and a test that stubs all three would be asserting on
    // its own stubs. The behaviour it depends on is `_handoff`'s `maybePop`,
    // which predates any of this.
  });

  group('the transcript', () {
    testWidgets('a video bubble has a poster that can fly', (tester) async {
      await tester.pumpWidget(
        host(
          Scaffold(
            body: Center(
              child: VideoMessage(
                api: api,
                storageId: 'stor_m1',
                isMine: false,
                posterStorageId: 'poster_1',
                heroTag: 'msg-video-m1',
                onOpen: () {},
              ),
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.byType(SteadyHero), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(SteadyHero),
          matching: find.byIcon(CupertinoIcons.play_fill),
        ),
        findsNothing,
        reason: 'the play glyph belongs to the tile, not to the video — '
            'dragging it across the screen would promise the player has one too',
      );
    });

    testWidgets('a copy of the bubble carries no tag to collide with', (
      tester,
    ) async {
      // Two heroes sharing a tag on routes that both join a flight is an
      // assertion, not a graceful degrade — which is what `useHero: false` is
      // for at every call site that renders a second copy of a bubble.
      await tester.pumpWidget(
        host(
          Scaffold(
            body: Center(
              child: VideoMessage(
                api: api,
                storageId: 'stor_m1',
                isMine: false,
                posterStorageId: 'poster_1',
                onOpen: () {},
              ),
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.byType(SteadyHero), findsNothing);
    });
  });
}
