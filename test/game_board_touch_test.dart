import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monkeyhub/data/feed_store.dart';
import 'package:monkeyhub/data/games_store.dart';
import 'package:monkeyhub/games/game_canvas.dart';
import 'package:monkeyhub/games/game_play_controller.dart';
import 'package:monkeyhub/l10n/generated/app_localizations.dart';
import 'package:monkeyhub/models/daily_game.dart';
import 'package:monkeyhub/screens/games/queens_screen.dart';
import 'package:monkeyhub/screens/games/zip_screen.dart';
import 'package:monkeyhub/theme/basic_theme.dart';
import 'package:monkeyhub/theme/theme_scope.dart';

import 'fakes/fake_games_api.dart';

/// What a finger on a daily board means to the rest of the screen: the page
/// stops scrolling under it, and the clock starts with it — not when the
/// screen opened.
void main() {
  final fixtures =
      jsonDecode(File('test/fixtures/daily_games.json').readAsStringSync())
          as Map<String, dynamic>;
  final day = (fixtures['days'] as List).first as Map<String, dynamic>;
  final payload = <String, dynamic>{
    'dayKey': day['dayKey'],
    for (final game in ['queens', 'tango', 'zip', 'sudoku'])
      game: ((day[game] as Map)['board'] as Map).cast<String, dynamic>(),
  };

  late Directory tmp;

  setUpAll(() async {
    tmp = await Directory.systemTemp.createTemp('game_board_touch');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/path_provider'),
          (_) async => tmp.path,
        );
  });

  tearDownAll(() async {
    if (await tmp.exists()) await tmp.delete(recursive: true);
  });

  setUp(() {
    GamesStore.instance.api = FakeGamesApi(payload);
    GamesStore.instance.clear();
  });

  tearDown(GamesStore.instance.clear);

  Future<void> mount(WidgetTester tester, Widget screen) async {
    // A short phone, so the page under the board really can scroll.
    tester.view.physicalSize = const Size(1200, 2100);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    await tester.runAsync(() => GamesStore.instance.load('u1'));
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        home: ThemeScope(
          controller: ThemeController(BasicTheme.midnight()),
          child: screen,
        ),
      ),
    );
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
  }

  ScrollPosition page(WidgetTester tester) => tester
      .state<ScrollableState>(find.byType(Scrollable).first)
      .position;

  for (final entry in <String, Widget>{
    // Tap-only: never in the arena against the page before this.
    'queens': const QueensScreen(userId: 'u1'),
    'zip': const ZipScreen(userId: 'u1'),
  }.entries) {
    testWidgets('${entry.key}: a vertical swipe that starts on the board does '
        'not scroll the page', (tester) async {
      await mount(tester, entry.value);
      expect(page(tester).maxScrollExtent, greaterThan(0));

      final rect = tester.getRect(find.byType(GameBoardSurface));
      final start = rect.center;
      final gesture = await tester.startGesture(start);
      for (var i = 1; i <= 30; i++) {
        await gesture.moveTo(start - Offset(0, i * 8.0));
        await tester.pump();
      }
      await gesture.up();
      // Fixed pumps, not pumpAndSettle: Zip's line head breathes forever.
      await tester.pump(const Duration(seconds: 1));

      expect(page(tester).pixels, 0);

      // And the page still scrolls from anywhere else once the finger lifts.
      await tester.drag(find.text(entry.key == 'zip' ? 'Zip' : 'Queens').first,
          const Offset(0, -300));
      await tester.pump(const Duration(seconds: 1));
      expect(page(tester).pixels, greaterThan(0));

      await tester.pumpWidget(const SizedBox());
      FeedStore.instance.stop();
    });
  }

  test('the clock waits for the first touch', () async {
    await GamesStore.instance.load('u1');
    final play = GamePlayController(game: DailyGame.queens, userId: 'u1');
    addTearDown(() {
      play.dispose();
      FeedStore.instance.stop();
    });
    await play.begin();
    expect(play.ready, isTrue);

    await Future<void>.delayed(const Duration(milliseconds: 40));
    expect(play.started, isFalse);
    expect(play.elapsed, Duration.zero);

    // Pausing and resuming an untouched board does not start it either.
    play
      ..pause()
      ..resume();
    await Future<void>.delayed(const Duration(milliseconds: 20));
    expect(play.elapsed, Duration.zero);

    play.startClock();
    await Future<void>.delayed(const Duration(milliseconds: 40));
    expect(play.started, isTrue);
    expect(play.elapsed, greaterThan(Duration.zero));
  });
}
