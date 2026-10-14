import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monkeyhub/data/feed_store.dart';
import 'package:monkeyhub/data/games_store.dart';
import 'package:monkeyhub/games/game_canvas.dart';
import 'package:monkeyhub/l10n/generated/app_localizations.dart';
import 'package:monkeyhub/screens/games/starbattle_screen.dart';
import 'package:monkeyhub/theme/basic_theme.dart';
import 'package:monkeyhub/theme/theme_scope.dart';

import 'fakes/fake_games_api.dart';

/// A star is two taps, the first of them a dot, and the third tap takes it
/// away again. Star Battle only judges a square once the player has moved on
/// from it, so tapping straight through a star on the way back to empty is
/// never a mistake, and settling on a star that breaks a rule still is, once.
void main() {
  final fixtures =
      jsonDecode(File('test/fixtures/daily_games.json').readAsStringSync())
          as Map<String, dynamic>;
  final day = (fixtures['days'] as List).first as Map<String, dynamic>;
  final payload = <String, dynamic>{
    'dayKey': day['dayKey'],
    for (final game in [
      'queens',
      'tango',
      'zip',
      'sudoku',
      'flow',
      'futoshiki',
      'nonogram',
      'minesweeper',
      'starbattle',
      'patches',
    ])
      game: ((day[game] as Map)['board'] as Map).cast<String, dynamic>(),
  };
  final answer = ((day['starbattle'] as Map)['answer'] as List).cast<int>();

  late Directory tmp;
  late FakeGamesApi api;

  setUpAll(() async {
    tmp = await Directory.systemTemp.createTemp('starbattle_settle');
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
    api = FakeGamesApi(payload);
    GamesStore.instance.api = api;
    GamesStore.instance.clear();
  });

  tearDown(GamesStore.instance.clear);

  Future<void> mount(WidgetTester tester) async {
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
          child: const StarBattleScreen(userId: 'u1'),
        ),
      ),
    );
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
  }

  void tap(WidgetTester tester, int cell) => tester
      .widget<GameBoardSurface>(find.byType(GameBoardSurface))
      .onTapCell!(cell);

  Future<void> done(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    FeedStore.instance.stop();
  }

  testWidgets('tapping through a star, or a dot to a star, is never a mistake', (
    tester,
  ) async {
    await mount(tester);
    final n = GamesStore.instance.boards.starbattle.size;
    final stars = [
      for (var i = 0; i < answer.length; i++)
        if (answer[i] == 1) i,
    ];
    // A square that would clash with the first star, cycled all the way
    // round: dot, star, empty, quickly, the way a player clears a square.
    final first = stars.first;
    final clash = first % n == 0 ? first + 1 : first - 1;
    tap(tester, first);
    await tester.pump(const Duration(milliseconds: 80));
    tap(tester, first);
    await tester.pump(const Duration(milliseconds: 80));
    for (var k = 0; k < 3; k++) {
      tap(tester, clash);
      await tester.pump(const Duration(milliseconds: 120));
    }
    // Then every other star, two taps each, straight on to the next.
    for (final i in stars.skip(1)) {
      tap(tester, i);
      await tester.pump(const Duration(milliseconds: 120));
      tap(tester, i);
      await tester.pump(const Duration(milliseconds: 120));
    }
    await tester.pump(const Duration(seconds: 2));

    expect(api.submittedMistakes, [0]);
    await done(tester);
  });

  testWidgets('settling on a star that breaks a rule is counted, once', (
    tester,
  ) async {
    await mount(tester);
    final n = GamesStore.instance.boards.starbattle.size;
    final stars = [
      for (var i = 0; i < answer.length; i++)
        if (answer[i] == 1) i,
    ];
    final first = stars.first;
    final clash = first % n == 0 ? first + 1 : first - 1;
    tap(tester, first);
    tap(tester, first);
    await tester.pump(const Duration(milliseconds: 50));
    // A touching star, left there: long enough to settle, twice over.
    tap(tester, clash);
    tap(tester, clash);
    await tester.pump(const Duration(seconds: 1));
    await tester.pump(const Duration(seconds: 1));
    // Taken away, and the rest of the board finished.
    tap(tester, clash);
    await tester.pump(const Duration(milliseconds: 50));
    for (final i in stars.skip(1)) {
      tap(tester, i);
      tap(tester, i);
      await tester.pump(const Duration(milliseconds: 50));
    }
    await tester.pump(const Duration(seconds: 2));

    expect(api.submittedMistakes, [1]);
    await done(tester);
  });
}
