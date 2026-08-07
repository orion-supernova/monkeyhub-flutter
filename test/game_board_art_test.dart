import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monkeyhub/games/game_canvas.dart';
import 'package:monkeyhub/games/queens_board_art.dart';
import 'package:monkeyhub/games/sudoku_board_art.dart';
import 'package:monkeyhub/games/tango_board_art.dart';
import 'package:monkeyhub/games/zip_board_art.dart';
import 'package:monkeyhub/games/game_rules.dart';
import 'package:monkeyhub/l10n/generated/app_localizations.dart';
import 'package:monkeyhub/models/daily_game.dart';
import 'package:monkeyhub/theme/basic_theme.dart';
import 'package:monkeyhub/theme/theme_scope.dart';
import 'package:monkeyhub/widgets/game_tile.dart';
import 'package:monkeyhub/widgets/games_strip.dart';

/// The painted daily-game boards, and the tiles that reuse them.
///
/// Two things are worth pinning here, and neither is "does it look right".
///
/// The first is that the hit-test agrees with the paint. Every board is one
/// `CustomPaint` under one gesture detector, so the arithmetic that decides
/// where a cell is drawn is the same arithmetic that decides what a finger
/// landed on — and if that ever stops being true, every board in the app lights
/// the wrong square and no other test would notice.
///
/// The second is that the painters survive being handed a board they were not
/// expecting: an empty one before the day's puzzles arrive, and a tile-sized
/// one nine pixels across. A painter that throws takes the whole Feed down with
/// it, because the games band renders on the board everyone opens first.
void main() {
  final fixtures =
      jsonDecode(File('test/fixtures/daily_games.json').readAsStringSync())
          as Map<String, dynamic>;
  final day = (fixtures['days'] as List).first as Map<String, dynamic>;

  Map<String, dynamic> boardOf(String game) =>
      ((day[game] as Map)['board'] as Map).cast<String, dynamic>();

  final boards = DailyBoards.fromJson({
    'dayKey': day['dayKey'],
    'queens': boardOf('queens'),
    'tango': boardOf('tango'),
    'zip': boardOf('zip'),
    'sudoku': boardOf('sudoku'),
  });

  final theme = BasicTheme.midnight();

  /// Runs a painter for real, at [side] pixels, and fails if it throws.
  void paint(CustomPainter painter, double side) {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    painter.paint(canvas, Size.square(side));
    recorder.endRecording().dispose();
  }

  group('GameGrid', () {
    test('a point inside a cell maps back to that cell', () {
      final grid = GameGrid(side: 360, n: 6);
      expect(grid.cell, 60);
      for (var i = 0; i < 36; i++) {
        // Dead centre, and then a hair inside each corner: the whole cell has
        // to belong to the cell, or the edges of every board feel dead.
        expect(grid.hit(grid.center(i)), i);
        expect(grid.hit(grid.rect(i).topLeft + const Offset(0.5, 0.5)), i);
        expect(
          grid.hit(grid.rect(i).bottomRight - const Offset(0.5, 0.5)),
          i,
        );
      }
    });

    test('a point outside the board maps to nothing', () {
      final grid = GameGrid(side: 360, n: 6);
      expect(grid.hit(const Offset(-1, 10)), isNull);
      expect(grid.hit(const Offset(10, -1)), isNull);
      expect(grid.hit(const Offset(361, 10)), isNull);
      expect(grid.hit(const Offset(10, 361)), isNull);
    });

    test('a board with no width hits nothing rather than dividing by zero', () {
      expect(GameGrid(side: 0, n: 6).hit(Offset.zero), isNull);
    });
  });

  group('the painters survive every board they can be handed', () {
    final palette = GamePalette(theme);

    for (final side in <double>[9, 44, 360]) {
      test('a real board at ${side.toInt()}px', () {
        paint(
          QueensBoardPainter(
            board: boards.queens,
            theme: theme,
            palette: palette,
            marks: List<QueensMark>.filled(64, QueensMark.crown),
            conflicts: const {0, 9},
            autoBlocked: const {1, 2, 3},
            popCell: 0,
            pop: 0.5,
            win: 0.5,
          ),
          side,
        );
        paint(
          TangoBoardPainter(
            board: boards.tango,
            theme: theme,
            cells: List<int>.filled(36, tangoMoon),
            trouble: const TangoTrouble(cells: <int>{0, 1}, signs: <int>{0}),
            popCell: 3,
            pop: 0.5,
            win: 0.5,
          ),
          side,
        );
        paint(
          ZipBoardPainter(
            board: boards.zip,
            theme: theme,
            path: List<int>.generate(36, (i) => i),
            win: 0.5,
            headPulse: 0.5,
          ),
          side,
        );
        paint(
          SudokuBoardPainter(
            board: boards.sudoku,
            theme: theme,
            cells: List<int>.generate(36, (i) => (i % 6) + 1),
            notes: const {0: {1, 2, 3, 4, 5, 6}},
            conflicts: const {0, 1},
            selected: 7,
            popCell: 7,
            pop: 0.5,
            win: 0.5,
          ),
          side,
        );
      });
    }

    test('an empty board, which is what the hub shows before they arrive', () {
      paint(
        QueensBoardPainter(
          board: QueensBoard.empty,
          theme: theme,
          palette: palette,
        ),
        120,
      );
      paint(TangoBoardPainter(board: TangoBoard.empty, theme: theme), 120);
      paint(ZipBoardPainter(board: ZipBoard.empty, theme: theme), 120);
      paint(SudokuBoardPainter(board: SudokuBoard.empty, theme: theme), 120);
    });

    test('a board with no player state at all — the hub tiles', () {
      paint(
        QueensBoardPainter(
          board: boards.queens,
          theme: theme,
          palette: palette,
        ),
        72,
      );
      paint(TangoBoardPainter(board: boards.tango, theme: theme), 72);
      paint(ZipBoardPainter(board: boards.zip, theme: theme), 72);
      paint(SudokuBoardPainter(board: boards.sudoku, theme: theme), 72);
    });
  });

  group('GameBoardSurface', () {
    Widget host({
      required int n,
      required void Function(int) onTapCell,
      void Function(int)? onDragTo,
    }) => MaterialApp(
      home: ThemeScope(
        controller: ThemeController(BasicTheme.midnight()),
        child: Scaffold(
          body: Center(
            child: SizedBox(
              width: 360,
              height: 360,
              child: GameBoardSurface(
                n: n,
                onTapCell: onTapCell,
                onDragTo: onDragTo,
                painter: ZipBoardPainter(board: boards.zip, theme: theme),
              ),
            ),
          ),
        ),
      ),
    );

    testWidgets('a tap reports the cell under the finger', (tester) async {
      final tapped = <int>[];
      await tester.pumpWidget(host(n: 6, onTapCell: tapped.add));

      final board = tester.getTopLeft(find.byType(GameBoardSurface));
      // Row 2, column 3 of a 6x6 board drawn 360 wide: cells are 60 across.
      await tester.tapAt(board + const Offset(60 * 3 + 30, 60 * 2 + 30));
      await tester.pump();

      expect(tapped, [2 * 6 + 3]);
    });

    testWidgets('a drag reports every cell it crosses', (tester) async {
      final dragged = <int>[];
      await tester.pumpWidget(
        host(n: 6, onTapCell: (_) {}, onDragTo: dragged.add),
      );

      final board = tester.getTopLeft(find.byType(GameBoardSurface));
      final gesture = await tester.startGesture(board + const Offset(30, 30));
      // The first move only has to clear the touch slop, and it deliberately
      // stays inside the starting cell: the pan is not recognised until the
      // slop is crossed, so a bigger first step would have Zip's line begin one
      // square along from where the finger went down.
      await gesture.moveBy(const Offset(20, 0));
      await gesture.moveBy(const Offset(40, 0));
      await gesture.moveBy(const Offset(60, 0));
      await gesture.up();
      await tester.pump();

      // Zip is drawn with one continuous stroke, so the gesture has to be
      // sampled the whole way rather than only where it started and stopped.
      expect(dragged, containsAllInOrder([0, 1, 2]));
    });

    testWidgets('a board that has not arrived renders nothing', (tester) async {
      await tester.pumpWidget(host(n: 0, onTapCell: (_) {}));
      // Scoped to the surface: Material draws `CustomPaint`s of its own, and an
      // unscoped finder would pass here whatever the board did.
      expect(
        find.descendant(
          of: find.byType(GameBoardSurface),
          matching: find.byType(CustomPaint),
        ),
        findsNothing,
      );
    });
  });

  group('the hub and Feed tiles', () {
    Widget host(Widget child) => MaterialApp(
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      home: ThemeScope(
        controller: ThemeController(BasicTheme.midnight()),
        child: Scaffold(body: Center(child: child)),
      ),
    );

    testWidgets('an unplayed tile says so rather than showing 0:00', (
      tester,
    ) async {
      await tester.pumpWidget(
        host(
          GameTile(
            game: DailyGame.queens,
            boards: boards,
            width: 160,
            onTap: () {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('queens'), findsOneWidget);
      expect(find.text('not played'), findsOneWidget);
      expect(find.text('0:00'), findsNothing);
    });

    testWidgets('a solved tile shows the time and the rank', (tester) async {
      await tester.pumpWidget(
        host(
          GameTile(
            game: DailyGame.tango,
            boards: boards,
            width: 160,
            rank: 2,
            result: const GameResult(
              game: DailyGame.tango,
              solved: true,
              gaveUp: false,
              finished: true,
              durationMs: 101000,
            ),
            onTap: () {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('1:41'), findsOneWidget);
      expect(find.text('#2'), findsOneWidget);
    });

    testWidgets('the Feed band shows all four and reports which was tapped', (
      tester,
    ) async {
      DailyGame? opened;
      await tester.pumpWidget(
        host(
          SizedBox(
            width: 340,
            child: GamesStrip(
              boards: boards,
              results: const {},
              onOpen: (game) => opened = game,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      for (final name in ['queens', 'tango', 'zip', 'mini sudoku']) {
        expect(find.text(name), findsOneWidget, reason: name);
      }
      await tester.tap(find.text('zip'));
      await tester.pump();
      expect(opened, DailyGame.zip);
    });
  });
}
