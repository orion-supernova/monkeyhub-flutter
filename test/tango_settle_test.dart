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
import 'package:monkeyhub/models/daily_game.dart';
import 'package:monkeyhub/screens/games/tango_screen.dart';
import 'package:monkeyhub/theme/basic_theme.dart';
import 'package:monkeyhub/theme/theme_scope.dart';

import 'fakes/fake_games_api.dart';

/// A moon is two taps, and the first of them is always a sun. Tango only
/// judges a square once the player has moved on from it, so passing through
/// the wrong symbol on the way to the right one is never a mistake — and
/// settling on the wrong one still is.
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
  final answer = ((day['tango'] as Map)['answer'] as List).cast<int>();

  late Directory tmp;
  late FakeGamesApi api;

  setUpAll(() async {
    tmp = await Directory.systemTemp.createTemp('tango_settle');
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
          child: const TangoScreen(userId: 'u1'),
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

  testWidgets('cycling through a sun to reach a moon is never a mistake', (
    tester,
  ) async {
    await mount(tester);
    final givens = GamesStore.instance.boards.tango.givens;
    // Every open square, played the way a person plays it: one tap for a sun,
    // two quick taps for a moon, straight on to the next square.
    for (var i = 0; i < answer.length; i++) {
      if (givens[i] != tangoEmpty) continue;
      tap(tester, i);
      await tester.pump(const Duration(milliseconds: 120));
      if (answer[i] == tangoMoon) {
        tap(tester, i);
        await tester.pump(const Duration(milliseconds: 120));
      }
    }
    await tester.pump(const Duration(seconds: 2));

    expect(api.submittedMistakes, [0]);
    await done(tester);
  });

  testWidgets('settling on the wrong symbol is still counted, once', (
    tester,
  ) async {
    await mount(tester);
    final givens = GamesStore.instance.boards.tango.givens;
    final open = [
      for (var i = 0; i < answer.length; i++)
        if (givens[i] == tangoEmpty) i,
    ];
    // Fill everything correctly but one moon square, then put a sun there and
    // leave it: on a full row that always breaks a count. (A sun square would
    // not do — cycling to a wrong moon passes through the right sun, which
    // finishes the board on the spot.)
    final last = open.lastWhere((i) => answer[i] == tangoMoon);
    for (final i in open) {
      if (i == last) continue;
      tap(tester, i);
      if (answer[i] == tangoMoon) tap(tester, i);
      await tester.pump(const Duration(milliseconds: 50));
    }
    tap(tester, last);
    // Long enough to settle, twice over: still only one mistake.
    await tester.pump(const Duration(seconds: 1));
    await tester.pump(const Duration(seconds: 1));
    // Then fix it, which finishes the board and reports the tally.
    tap(tester, last);
    await tester.pump(const Duration(seconds: 2));

    expect(api.submittedMistakes, [1]);
    await done(tester);
  });
}
