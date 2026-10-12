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
import 'package:monkeyhub/games/nonogram_board_art.dart';
import 'package:monkeyhub/screens/games/game_scaffold.dart';
import 'package:monkeyhub/screens/games/nonogram_screen.dart';
import 'package:monkeyhub/theme/basic_theme.dart';
import 'package:monkeyhub/theme/theme_scope.dart';

import 'fakes/fake_games_api.dart';

/// A cross is two taps, and the first of them always shades the square.
/// Nonogram only judges squares once the player has moved on from them, so
/// shading a blank on the way to crossing it is never a mistake, and a shade
/// that leaves a line with no way to fit its clue still is, once.
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
    ])
      game: ((day[game] as Map)['board'] as Map).cast<String, dynamic>(),
  };
  final answer = ((day['nonogram'] as Map)['answer'] as List).cast<int>();

  late Directory tmp;
  late FakeGamesApi api;

  setUpAll(() async {
    tmp = await Directory.systemTemp.createTemp('nonogram_settle');
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
          child: const NonogramScreen(userId: 'u1'),
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

  testWidgets('shading a blank on the way to crossing it is never a mistake', (
    tester,
  ) async {
    await mount(tester);
    // Every blank crossed first, two quick taps each — the first of which
    // shades a square the picture leaves empty — then every shaded square.
    // Frames only every row: a hundred squares of rebuilds is time spent on
    // the test, not on the rule.
    for (var i = 0; i < answer.length; i++) {
      if (answer[i] == 0) {
        tap(tester, i);
        tap(tester, i);
      }
      if (i % 10 == 9) await tester.pump(const Duration(milliseconds: 60));
    }
    for (var i = 0; i < answer.length; i++) {
      if (answer[i] == 1) tap(tester, i);
      if (i % 10 == 9) await tester.pump(const Duration(milliseconds: 60));
    }
    await tester.pump(const Duration(seconds: 2));

    expect(api.submittedMistakes, [0]);
    await done(tester);
  });

  testWidgets('a shade that breaks its row is counted, once', (tester) async {
    await mount(tester);
    final n = GamesStore.instance.boards.nonogram.size;
    // A row with at least one blank: decide all of it but one blank, so
    // shading that blank leaves the row no way to read back its clue.
    final row = List<int>.generate(n, (r) => r).firstWhere(
      (r) => answer.sublist(r * n, r * n + n).contains(0),
    );
    final blanks = [
      for (var c = 0; c < n; c++)
        if (answer[row * n + c] == 0) row * n + c,
    ];
    final wrong = blanks.last;
    for (var c = 0; c < n; c++) {
      final i = row * n + c;
      if (i == wrong) continue;
      tap(tester, i);
      if (answer[i] == 0) tap(tester, i);
      await tester.pump(const Duration(milliseconds: 50));
    }
    tap(tester, wrong);
    await tester.pump(const Duration(seconds: 1));
    await tester.pump(const Duration(seconds: 1));
    // Crossed instead, then the rest of the picture.
    tap(tester, wrong);
    await tester.pump(const Duration(milliseconds: 50));
    for (var i = 0; i < answer.length; i++) {
      if (i ~/ n != row && answer[i] == 1) tap(tester, i);
      if (i % 10 == 9) await tester.pump(const Duration(milliseconds: 50));
    }
    await tester.pump(const Duration(seconds: 2));

    expect(api.submittedMistakes, [1]);
    await done(tester);
  });

  testWidgets('a drag paints a run in one stroke, and one undo takes it back', (
    tester,
  ) async {
    // Tall enough that the tool row under the board is laid out too.
    tester.view.physicalSize = const Size(1200, 2600);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    await mount(tester);
    List<int> cells() => (tester
            .widget<CustomPaint>(
              find.descendant(
                of: find.byType(GameBoardSurface),
                matching: find.byType(CustomPaint),
              ),
            )
            .painter! as NonogramBoardPainter)
        .cells;

    final surface = tester.widget<GameBoardSurface>(
      find.byType(GameBoardSurface),
    );
    surface.onDragStart!();
    for (final i in [0, 1, 2, 3]) {
      surface.onDragTo!(i);
    }
    surface.onDragEnd!();
    await tester.pump(const Duration(milliseconds: 50));
    expect(cells().sublist(0, 4), everyElement(nonogramFilled));

    // One stroke, one undo step.
    tester
        .widgetList<GameTool>(find.byType(GameTool))
        .first // Undo leads the tool row.
        .onTap!();
    await tester.pump(const Duration(milliseconds: 50));
    expect(cells().sublist(0, 4), everyElement(nonogramUnknown));
    await tester.pump(const Duration(seconds: 2));
    await done(tester);
  });
}
