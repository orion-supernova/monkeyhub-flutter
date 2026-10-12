import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monkeyhub/backend/games_api.dart';
import 'package:monkeyhub/data/feed_store.dart';
import 'package:monkeyhub/data/games_store.dart';
import 'package:monkeyhub/games/flow_board_art.dart';
import 'package:monkeyhub/games/game_canvas.dart';
import 'package:monkeyhub/games/game_rules.dart';
import 'package:monkeyhub/games/minesweeper_board_art.dart';
import 'package:monkeyhub/l10n/generated/app_localizations.dart';
import 'package:monkeyhub/models/daily_game.dart';
import 'package:monkeyhub/screens/games/flow_screen.dart';
import 'package:monkeyhub/screens/games/futoshiki_screen.dart';
import 'package:monkeyhub/screens/games/game_scaffold.dart';
import 'package:monkeyhub/screens/games/minesweeper_screen.dart';
import 'package:monkeyhub/theme/basic_theme.dart';
import 'package:monkeyhub/theme/theme_scope.dart';

import 'fakes/fake_games_api.dart';

/// The new boards played for real, through their screens: a mine costs time
/// and not the game, a pipe drawn across another cuts it only while the
/// finger is in the way, a hint lands a whole pipe, and a Futoshiki grid
/// typed in from the keypad submits itself.
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
    tmp = await Directory.systemTemp.createTemp('new_games_play');
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
    GameHint hint = const GameHint(index: -1, value: 0),
  }) async {
    api = FakeGamesApi(payload, hintAnswer: hint);
    GamesStore.instance.api = api;
    GamesStore.instance.clear();
    // Tall enough that the tools and keypad under the board are laid out.
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

  Future<void> done(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    FeedStore.instance.stop();
  }

  GameBoardSurface surface(WidgetTester tester) =>
      tester.widget<GameBoardSurface>(find.byType(GameBoardSurface));

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

  group('minesweeper', () {
    testWidgets('the opening is open, and a mine costs 30 s, not the game', (
      tester,
    ) async {
      await mount(tester, const MinesweeperScreen(userId: 'u1'));
      final board = GamesStore.instance.boards.minesweeper;
      final mines = minesweeperMines(board, day['dayKey'] as String);
      final cells = painter<MinesweeperBoardPainter>(tester).cells;
      // Opened before the first touch: the promised 0 and the patch around it.
      expect(cells[board.start], 0);
      expect(cells.where((v) => v >= 0 && v <= 8).length, greaterThan(1));

      // Walk onto a mine, then open every safe square.
      surface(tester).onTapCell!(mines.indexOf(1));
      await tester.pump(const Duration(milliseconds: 50));
      expect(
        painter<MinesweeperBoardPainter>(tester).cells[mines.indexOf(1)],
        minesweeperStruck,
      );
      for (var i = 0; i < mines.length; i++) {
        if (mines[i] == 0) surface(tester).onTapCell!(i);
      }
      await tester.pump(const Duration(seconds: 2));

      // One submit, one mistake, and at least the penalty on the clock.
      expect(api.submittedMistakes, [1]);
      expect(api.submitted.single, greaterThanOrEqualTo(30000));
      await done(tester);
    });

    testWidgets('a long press plants a flag and a tap leaves it alone', (
      tester,
    ) async {
      await mount(tester, const MinesweeperScreen(userId: 'u1'));
      final board = GamesStore.instance.boards.minesweeper;
      final mines = minesweeperMines(board, day['dayKey'] as String);
      final mine = mines.indexOf(1);
      surface(tester).onLongPressCell!(mine);
      await tester.pump(const Duration(milliseconds: 50));
      surface(tester).onTapCell!(mine);
      await tester.pump(const Duration(milliseconds: 50));
      expect(
        painter<MinesweeperBoardPainter>(tester).cells[mine],
        minesweeperFlagged,
      );
      expect(api.submittedMistakes, isEmpty);
      await tester.pump(const Duration(seconds: 1));
      await done(tester);
    });
  });

  group('flow', () {
    void draw(WidgetTester tester, List<int> cells) {
      final s = surface(tester);
      s.onDragStart!();
      for (final c in cells) {
        s.onDragTo!(c);
      }
      s.onDragEnd!();
    }

    testWidgets('drawing every pipe submits once, with no mistakes', (
      tester,
    ) async {
      await mount(tester, const FlowScreen(userId: 'u1'));
      final board = GamesStore.instance.boards.flow;
      final pipes = flowPipesOf(board, answerOf('flow'));
      // Odd pipes from their other end: either dot starts a pipe.
      for (var k = 0; k < pipes.length; k++) {
        draw(tester, k.isOdd ? pipes[k].reversed.toList() : pipes[k]);
        await tester.pump(const Duration(milliseconds: 30));
      }
      await tester.pump(const Duration(seconds: 2));
      expect(api.submittedMistakes, [0]);
      await done(tester);
    });

    testWidgets('crossing a pipe cuts it, and backing off puts it back', (
      tester,
    ) async {
      await mount(tester, const FlowScreen(userId: 'u1'));
      final board = GamesStore.instance.boards.flow;
      final pipes = flowPipesOf(board, answerOf('flow'));
      // The longest pipe, and a neighbour's dot right beside one of its
      // middle squares to cross it from.
      final k = List<int>.generate(pipes.length, (i) => i).reduce(
        (a, b) => pipes[a].length >= pipes[b].length ? a : b,
      );
      draw(tester, pipes[k]);
      await tester.pump(const Duration(milliseconds: 30));

      (int, int, int)? cross;
      for (var j = 0; j < board.endpoints.length && cross == null; j++) {
        if (j == k) continue;
        for (final dot in [board.endpoints[j].$1, board.endpoints[j].$2]) {
          for (final mid in pipes[k].sublist(1, pipes[k].length - 1)) {
            if (gridAdjacent(dot, mid, board.size)) {
              cross = (j, dot, mid);
              break;
            }
          }
          if (cross != null) break;
        }
      }
      expect(cross, isNotNull, reason: 'no dot beside the longest pipe');
      final (j, dot, mid) = cross!;

      final s = surface(tester);
      s.onDragStart!();
      s.onDragTo!(dot);
      s.onDragTo!(mid);
      await tester.pump(const Duration(milliseconds: 16));
      final cut = painter<FlowBoardPainter>(tester).pipes;
      expect(cut[j], [dot, mid]);
      expect(cut[k], isNot(contains(mid)));
      // Back off the square, in the same stroke: the crossed pipe is whole.
      s.onDragTo!(dot);
      await tester.pump(const Duration(milliseconds: 16));
      expect(painter<FlowBoardPainter>(tester).pipes[k], pipes[k]);
      s.onDragEnd!();
      await tester.pump(const Duration(seconds: 1));
      await done(tester);
    });

    testWidgets('a hint lays a whole pipe and cuts what is in its way', (
      tester,
    ) async {
      final board = FlowBoard.fromJson(
        (payload['flow'] as Map).cast<String, dynamic>(),
      );
      final pipes = flowPipesOf(board, answerOf('flow'));
      await mount(
        tester,
        const FlowScreen(userId: 'u1'),
        hint: GameHint(index: 0, value: 0, cells: pipes[0]),
      );
      tester
          .widgetList<GameTool>(find.byType(GameTool))
          .elementAt(2) // Undo, Clear, Hint, Give up.
          .onTap!();
      await tester.pump(const Duration(milliseconds: 50));
      expect(painter<FlowBoardPainter>(tester).pipes[0], pipes[0]);
      // Asked with the pipes end to end, which on an empty board is nothing.
      expect(api.hintBoards.single, isEmpty);
      await tester.pump(const Duration(seconds: 1));
      await done(tester);
    });
  });

  group('futoshiki', () {
    testWidgets('a grid typed in from the keypad submits itself', (
      tester,
    ) async {
      await mount(tester, const FutoshikiScreen(userId: 'u1'));
      final board = GamesStore.instance.boards.futoshiki;
      final answer = answerOf('futoshiki');
      for (var i = 0; i < answer.length; i++) {
        if (board.givens[i] != futoshikiEmpty) continue;
        surface(tester).onTapCell!(i);
        await tester.pump(const Duration(milliseconds: 16));
        await tester.tap(find.byKey(ValueKey('futoshiki_key_${answer[i]}')));
        await tester.pump(const Duration(milliseconds: 16));
      }
      await tester.pump(const Duration(seconds: 2));
      expect(api.submittedMistakes, [0]);
      await done(tester);
    });
  });
}
