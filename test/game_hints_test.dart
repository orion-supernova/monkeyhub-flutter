import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monkeyhub/backend/games_api.dart';
import 'package:monkeyhub/data/feed_store.dart';
import 'package:monkeyhub/data/games_store.dart';
import 'package:monkeyhub/games/game_canvas.dart';
import 'package:monkeyhub/games/game_rules.dart';
import 'package:monkeyhub/games/hint_spotlight.dart';
import 'package:monkeyhub/games/nonogram_board_art.dart';
import 'package:monkeyhub/games/queens_board_art.dart';
import 'package:monkeyhub/games/sudoku_board_art.dart';
import 'package:monkeyhub/games/tango_board_art.dart';
import 'package:monkeyhub/l10n/generated/app_localizations.dart';
import 'package:monkeyhub/l10n/generated/app_localizations_en.dart';
import 'package:monkeyhub/models/daily_game.dart';
import 'package:monkeyhub/screens/games/game_scaffold.dart';
import 'package:monkeyhub/screens/games/nonogram_screen.dart';
import 'package:monkeyhub/screens/games/queens_screen.dart';
import 'package:monkeyhub/screens/games/starbattle_screen.dart';
import 'package:monkeyhub/screens/games/sudoku_screen.dart';
import 'package:monkeyhub/screens/games/tango_screen.dart';
import 'package:monkeyhub/theme/basic_theme.dart';
import 'package:monkeyhub/theme/theme_scope.dart';

import 'fakes/fake_games_api.dart';

/// The explained hint, as the screens play it: a mistake is cleared and
/// ringed, a step is placed and explained, the board is asked about with every
/// mark the player made, and the spotlight stays until the player moves.
/// (Which hint the server picks is tested in backend/convex/games/hints.test.ts.)
void main() {
  final fixtures =
      jsonDecode(File('test/fixtures/daily_games.json').readAsStringSync())
          as Map<String, dynamic>;
  final day = (fixtures['days'] as List).first as Map<String, dynamic>;
  final payload = <String, dynamic>{
    'dayKey': day['dayKey'],
    for (final game in DailyGame.values)
      game.wire: ((day[game.wire] as Map)['board'] as Map)
          .cast<String, dynamic>(),
  };
  List<int> answerOf(String game) =>
      ((day[game] as Map)['answer'] as List).cast<int>();

  late Directory tmp;
  late FakeGamesApi api;

  setUpAll(() async {
    tmp = await Directory.systemTemp.createTemp('game_hints');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/path_provider'),
          (_) async => tmp.path,
        );
  });

  tearDownAll(() async {
    if (await tmp.exists()) await tmp.delete(recursive: true);
  });

  tearDown(GamesStore.instance.clear);

  Future<void> mount(
    WidgetTester tester,
    Widget screen, {
    required GameHint hint,
    Map<DailyGame, List<int>> progress = const {},
  }) async {
    api = FakeGamesApi(payload, hintAnswer: hint, progress: progress);
    GamesStore.instance.api = api;
    GamesStore.instance.clear();
    tester.view.physicalSize = const Size(1200, 2800);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
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

  Future<void> askHint(WidgetTester tester) async {
    tester
        .widgetList<GameTool>(find.byType(GameTool))
        .firstWhere((t) => t.label == 'Hint')
        .onTap!();
    await tester.pump(const Duration(milliseconds: 50));
  }

  Future<void> done(WidgetTester tester) async {
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpWidget(const SizedBox());
    FeedStore.instance.stop();
  }

  BoardHint? spot(WidgetTester tester) =>
      tester.widget<HintSpotlight>(find.byType(HintSpotlight)).hint;

  T painter<T>(WidgetTester tester) =>
      tester
              .widget<CustomPaint>(
                find.descendant(
                  of: find.byType(GameBoardSurface),
                  matching: find.byType(CustomPaint),
                ),
              )
              .painter!
          as T;

  final copy = HintCopy(AppLocalizationsEn());

  group('queens', () {
    final answer = answerOf('queens');
    const n = 8;

    testWidgets('a wrong crown is cleared, ringed red and explained', (
      tester,
    ) async {
      // Row 0's crown one square off, and a cross the player made.
      final wrongAt = answer[0] == 0 ? 1 : 0;
      final saved = List<int>.filled(n * n, 0)
        ..[wrongAt] = QueensMark.crown.index
        ..[n * 7 + 7] = QueensMark.blocked.index;
      await mount(
        tester,
        const QueensScreen(userId: 'u1'),
        progress: {DailyGame.queens: saved},
        hint: GameHint(
          index: 0,
          value: answer[0],
          kind: GameHintKind.wrong,
          cell: wrongAt,
          answer: 0,
          reason: 'wrong',
          area: [wrongAt],
        ),
      );
      await askHint(tester);

      // Asked with every mark, crosses included, not a column per row.
      expect(api.hintBoards.single, saved);
      expect(painter<QueensBoardPainter>(tester).marks[wrongAt], QueensMark.none);
      expect(spot(tester)!.wrong, isTrue);
      expect(spot(tester)!.target, {wrongAt});
      expect(find.text(copy.gameHintWrong), findsOneWidget);
      expect(find.text(copy.gameHintWrongLast), findsOneWidget);

      // The player's next move puts it away.
      tester.widget<GameBoardSurface>(find.byType(GameBoardSurface)).onTapCell!(
        n * 7,
      );
      await tester.pump(const Duration(milliseconds: 16));
      await tester.pump(const Duration(milliseconds: 600));
      expect(spot(tester), isNull);
      expect(find.text(copy.gameHintWrong), findsNothing);
      await done(tester);
    });

    testWidgets('a forced crown lands with its reason and its region lit', (
      tester,
    ) async {
      final cell = 7 * n + answer[7];
      await mount(
        tester,
        const QueensScreen(userId: 'u1'),
        hint: GameHint(
          index: 7,
          value: answer[7],
          kind: GameHintKind.step,
          cell: cell,
          answer: 1,
          reason: 'queens.region',
          area: [cell, cell - 1],
          cause: const [3],
        ),
      );
      await askHint(tester);
      expect(painter<QueensBoardPainter>(tester).marks[cell], QueensMark.crown);
      expect(spot(tester)!.area, {cell, cell - 1});
      expect(spot(tester)!.cause, {3});
      expect(find.text(copy.gameHintQueensRegion), findsOneWidget);
      // The banner taps away on its own, once it has opened.
      await tester.pump(const Duration(milliseconds: 600));
      await tester.tap(find.text(copy.gameHintQueensRegion));
      await tester.pump(const Duration(milliseconds: 400));
      expect(spot(tester), isNull);
      await done(tester);
    });

    testWidgets('a confinement step crosses squares out, no crown', (
      tester,
    ) async {
      final out = [
        for (var c = 0; c < n; c++)
          if (c != answer[2]) 2 * n + c,
      ].take(3).toList();
      await mount(
        tester,
        const QueensScreen(userId: 'u1'),
        hint: GameHint(
          index: 2,
          value: answer[2],
          kind: GameHintKind.step,
          cell: out.first,
          answer: 0,
          cells: out,
          reason: 'queens.regionInRow',
        ),
      );
      await askHint(tester);
      final marks = painter<QueensBoardPainter>(tester).marks;
      for (final c in out) {
        expect(marks[c], QueensMark.blocked);
      }
      expect(marks.where((m) => m == QueensMark.crown), isEmpty);
      expect(spot(tester)!.target, out.toSet());
      await done(tester);
    });

    testWidgets('a server from before explained hints still lands a crown', (
      tester,
    ) async {
      await mount(
        tester,
        const QueensScreen(userId: 'u1'),
        hint: GameHint(index: 3, value: answer[3]),
      );
      await askHint(tester);
      final cell = 3 * n + answer[3];
      expect(painter<QueensBoardPainter>(tester).marks[cell], QueensMark.crown);
      expect(spot(tester)!.target, {cell});
      expect(find.text(copy.gameHintReveal), findsOneWidget);
      await done(tester);
    });
  });

  testWidgets('sudoku: a step is placed in its own square, digit named', (
    tester,
  ) async {
    final board = SudokuBoard.fromJson(
      (payload['sudoku'] as Map).cast<String, dynamic>(),
    );
    final answer = answerOf('sudoku');
    final cell = board.givens.indexOf(sudokuEmpty);
    await mount(
      tester,
      const SudokuScreen(userId: 'u1'),
      hint: GameHint(
        index: cell,
        value: answer[cell],
        kind: GameHintKind.step,
        cell: cell,
        answer: answer[cell],
        reason: 'latin.box',
        digit: answer[cell],
      ),
    );
    await askHint(tester);
    expect(painter<SudokuBoardPainter>(tester).cells[cell], answer[cell]);
    expect(find.text(copy.gameHintLatinBox(answer[cell])), findsOneWidget);
    await done(tester);
  });

  testWidgets('tango: a wrong square goes back to blank', (tester) async {
    final board = TangoBoard.fromJson(
      (payload['tango'] as Map).cast<String, dynamic>(),
    );
    final answer = answerOf('tango');
    final cell = board.givens.indexOf(tangoEmpty);
    final saved = List<int>.filled(36, tangoEmpty)..[cell] = 1 - answer[cell];
    await mount(
      tester,
      const TangoScreen(userId: 'u1'),
      progress: {DailyGame.tango: saved},
      hint: GameHint(
        index: cell,
        value: answer[cell],
        kind: GameHintKind.wrong,
        cell: cell,
        answer: answer[cell],
        reason: 'wrong',
        more: 2,
      ),
    );
    await askHint(tester);
    expect(painter<TangoBoardPainter>(tester).cells[cell], tangoEmpty);
    expect(find.text(copy.gameHintWrongMore), findsOneWidget);
    await done(tester);
  });

  testWidgets('nonogram: a forced fill, its line and clue lit', (tester) async {
    final row = List<int>.generate(10, (k) => 20 + k);
    await mount(
      tester,
      const NonogramScreen(userId: 'u1'),
      hint: GameHint(
        index: 21,
        value: 1,
        kind: GameHintKind.step,
        cell: 21,
        answer: 1,
        reason: 'nonogram.rowFill',
        area: row,
      ),
    );
    await askHint(tester);
    expect(painter<NonogramBoardPainter>(tester).cells[21], nonogramFilled);
    final layer = tester.widget<HintSpotlight>(find.byType(HintSpotlight));
    expect(layer.leadFraction, greaterThan(0));
    expect(layer.hint!.area, row.toSet());
    expect(find.text(copy.gameHintNonogramRowFill), findsOneWidget);
    await done(tester);
  });

  testWidgets('star battle: dots are sent, so a dot on a star can be caught', (
    tester,
  ) async {
    final saved = List<int>.filled(100, 0)
      ..[0] = StarMark.star.index
      ..[5] = StarMark.dot.index;
    await mount(
      tester,
      const StarBattleScreen(userId: 'u1'),
      progress: {DailyGame.starbattle: saved},
      hint: const GameHint(
        index: 5,
        value: 1,
        kind: GameHintKind.wrong,
        cell: 5,
        answer: 1,
        reason: 'wrong',
      ),
    );
    await askHint(tester);
    final sent = api.hintBoards.single;
    expect(sent[0], 1);
    expect(sent[5], 2);
    expect(spot(tester)!.target, {5});
    await done(tester);
  });

  group('hintMessage', () {
    final l10n = AppLocalizationsEn();
    test('a mistake says whether there is more to fix', () {
      const one = GameHint(index: 0, value: 0, kind: GameHintKind.wrong);
      const more = GameHint(
        index: 0,
        value: 0,
        kind: GameHintKind.wrong,
        more: 1,
      );
      expect(hintMessage(l10n, one), (copy.gameHintWrong, copy.gameHintWrongLast));
      expect(hintMessage(l10n, more).$2, copy.gameHintWrongMore);
    });

    test('an unknown reason, or none, falls back to the honest reveal', () {
      expect(
        hintMessage(l10n, const GameHint(index: 0, value: 0, reason: 'x.y')).$1,
        copy.gameHintReveal,
      );
      expect(
        hintMessage(l10n, const GameHint(index: 0, value: 0)).$1,
        copy.gameHintReveal,
      );
    });

    test('every reason the server sends has its own sentence', () {
      const reasons = [
        'queens.region', 'queens.row', 'queens.col', 'queens.regionInRow',
        'queens.regionInCol', 'queens.rowInRegion', 'queens.colInRegion',
        'stars.region', 'stars.row', 'stars.col', 'tango.equal',
        'tango.cross', 'tango.pair', 'tango.sandwich', 'tango.rowSuns',
        'tango.rowMoons', 'tango.colSuns', 'tango.colMoons', 'latin.box',
        'latin.row', 'latin.col', 'latin.only', 'latin.onlyLines',
        'latin.onlySigns', 'nonogram.rowFill', 'nonogram.rowCross',
        'nonogram.colFill', 'nonogram.colCross', 'mines.start', 'mines.safe',
        'mines.flag', 'mines.proofSafe', 'mines.proofMine', 'flow.pipe',
      ];
      final seen = <String>{};
      for (final r in reasons) {
        final line = hintMessage(
          l10n,
          GameHint(index: 0, value: 0, reason: r, digit: 4),
        ).$1;
        expect(line, isNot(copy.gameHintReveal), reason: r);
        expect(line.contains('—'), isFalse, reason: r);
        seen.add(line);
      }
      expect(seen, hasLength(reasons.length));
    });
  });
}
