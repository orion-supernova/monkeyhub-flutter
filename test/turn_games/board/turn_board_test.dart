import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monkeyhub/theme/basic_theme.dart';
import 'package:monkeyhub/theme/theme_scope.dart';
import 'package:monkeyhub/turn_games/board/checkers_board.dart';
import 'package:monkeyhub/turn_games/board/connect_four_board.dart';
import 'package:monkeyhub/turn_games/board/dots_board.dart';
import 'package:monkeyhub/turn_games/board/turn_board.dart';
import 'package:monkeyhub/turn_games/connect_four.dart';
import 'package:monkeyhub/turn_games/dots.dart';
import 'package:monkeyhub/turn_games/reversi.dart';

/// TurnBoard, mounted for real: taps and drags go through the gesture arena
/// to the rules engine, and only a legal token may come out the other side.
void main() {
  const side = 300.0;

  Widget host(Widget board) => MaterialApp(
    home: ThemeScope(
      controller: ThemeController(BasicTheme.midnight()),
      child: Center(child: SizedBox(width: side, child: board)),
    ),
  );

  /// Mounts [gameId] at [state] and returns the list onMove writes into.
  Future<List<String>> mount(
    WidgetTester tester,
    String gameId,
    String state, {
    int? mySeat = 0,
    bool enabled = true,
    bool thumbnail = false,
  }) async {
    final moves = <String>[];
    await tester.pumpWidget(
      host(
        TurnBoard(
          gameId: gameId,
          state: state,
          mySeat: mySeat,
          enabled: enabled,
          thumbnail: thumbnail,
          onMove: moves.add,
        ),
      ),
    );
    await tester.pumpAndSettle();
    return moves;
  }

  Offset origin(WidgetTester tester) => tester.getTopLeft(find.byType(TurnBoard));
  Size boardSize(WidgetTester tester) => tester.getSize(find.byType(TurnBoard));

  group('tic-tac-toe', () {
    Offset cellAt(WidgetTester tester, int i) =>
        origin(tester) + Offset((i % 3 + 0.5) * side / 3, (i ~/ 3 + 0.5) * side / 3);

    testWidgets('a tap on an empty cell emits that cell', (tester) async {
      final moves = await mount(tester, 'tictactoe', '........./0');
      await tester.tapAt(cellAt(tester, 4));
      expect(moves, ['4']);
    });

    testWidgets('an occupied cell, a disabled board or the wrong seat emit nothing', (
      tester,
    ) async {
      var moves = await mount(tester, 'tictactoe', 'X......../1', mySeat: 1);
      await tester.tapAt(cellAt(tester, 0));
      expect(moves, isEmpty);
      await tester.tapAt(cellAt(tester, 8));
      expect(moves, ['8']);

      moves = await mount(tester, 'tictactoe', 'X......../1', mySeat: 1, enabled: false);
      await tester.tapAt(cellAt(tester, 8));
      expect(moves, isEmpty);

      // Enabled, but the position says the other seat is to move.
      moves = await mount(tester, 'tictactoe', 'X......../1', mySeat: 0);
      await tester.tapAt(cellAt(tester, 8));
      expect(moves, isEmpty);
    });

    testWidgets('a finished game takes no moves', (tester) async {
      final moves = await mount(tester, 'tictactoe', 'XXXOO..../1', mySeat: 1);
      await tester.tapAt(cellAt(tester, 8));
      expect(moves, isEmpty);
    });

    testWidgets('each cell has a label, and legal ones activate', (tester) async {
      final handle = tester.ensureSemantics();
      final moves = await mount(tester, 'tictactoe', 'X......../1', mySeat: 1);
      expect(find.semantics.byLabel('Row 1, column 1, X'), findsOne);
      expect(find.semantics.byLabel('Row 3, column 3, empty'), findsOne);
      tester.semantics.tap(find.semantics.byLabel('Row 3, column 3, empty'));
      expect(moves, ['8']);
      handle.dispose();
    });

    testWidgets('a new mark animates and settles without throwing', (tester) async {
      final moves = <String>[];
      Widget board(String s) => host(
        TurnBoard(gameId: 'tictactoe', state: s, mySeat: 0, enabled: true, onMove: moves.add),
      );
      await tester.pumpWidget(board('........./0'));
      await tester.pumpWidget(board('X......../1'));
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pumpWidget(board('XXXOO..../1'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  });

  group('connect four', () {
    final empty = connectFourRules.encode(connectFourRules.initial(2));

    Offset columnAt(WidgetTester tester, int col, {double row = 3}) {
      final g = ConnectFourGeometry(boardSize(tester), lane: true);
      return origin(tester) + g.hole(row.floor(), col);
    }

    testWidgets('a tap drops into the column', (tester) async {
      final moves = await mount(tester, 'connectfour', empty);
      await tester.tapAt(columnAt(tester, 3));
      expect(moves, ['3']);
    });

    testWidgets('a horizontal drag carries the disc and drops on release', (
      tester,
    ) async {
      final moves = await mount(tester, 'connectfour', empty);
      final g = ConnectFourGeometry(boardSize(tester), lane: true);
      final gesture = await tester.startGesture(columnAt(tester, 1));
      await tester.pump(const Duration(milliseconds: 150));
      for (var i = 1; i <= 8; i++) {
        await gesture.moveBy(Offset(g.cell * 0.5, 0));
        await tester.pump(const Duration(milliseconds: 16));
      }
      expect(moves, isEmpty, reason: 'nothing drops while the finger is down');
      await gesture.up();
      await tester.pumpAndSettle();
      expect(moves, ['5']);
    });

    testWidgets('a full column takes nothing', (tester) async {
      var s = connectFourRules.initial(2);
      for (var i = 0; i < 6; i++) {
        s = connectFourRules.apply(s, 0);
      }
      final moves = await mount(tester, 'connectfour', connectFourRules.encode(s));
      await tester.tapAt(columnAt(tester, 0));
      expect(moves, isEmpty);
      await tester.tapAt(columnAt(tester, 1));
      expect(moves, ['1']);
    });
  });

  group('reversi', () {
    final start = reversiRules.encode(reversiRules.initial(2));

    Offset cellAt(WidgetTester tester, int i) =>
        origin(tester) + Offset((i % 8 + 0.5) * side / 8, (i ~/ 8 + 0.5) * side / 8);

    testWidgets('only a legal cell emits', (tester) async {
      final moves = await mount(tester, 'reversi', start);
      await tester.tapAt(cellAt(tester, 0));
      await tester.tapAt(cellAt(tester, 27));
      expect(moves, isEmpty);
      await tester.tapAt(cellAt(tester, 19));
      expect(moves, ['19']);
    });

    testWidgets('flips cascade and settle', (tester) async {
      Widget board(String s) => host(TurnBoard(gameId: 'reversi', state: s, mySeat: 1));
      await tester.pumpWidget(board(start));
      final next = reversiRules.apply(reversiRules.initial(2), 19);
      await tester.pumpWidget(board(reversiRules.encode(next)));
      await tester.pump(const Duration(milliseconds: 120));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  });

  group('checkers', () {
    const start = 'bbbbbbbbbbbb........wwwwwwwwwwww|0|0|';

    Offset squareAt(WidgetTester tester, int pdn, {bool flipped = true}) =>
        origin(tester) +
        CheckersGeometry(boardSize(tester), flipped: flipped).center(pdn - 1);

    /// Dark man on 1, light men on 6 and 15: the only move is the double
    /// jump 1x10x19.
    String doubleJump() {
      final b = List.filled(32, '.');
      b[0] = 'b';
      b[5] = 'w';
      b[14] = 'w';
      return '${b.join()}|0|0|';
    }

    testWidgets('select, then land: a step emits its PDN token', (tester) async {
      final moves = await mount(tester, 'checkers', start);
      await tester.tapAt(squareAt(tester, 11));
      expect(moves, isEmpty);
      await tester.tapAt(squareAt(tester, 15));
      expect(moves, ['11-15']);
    });

    testWidgets('a multi-jump is assembled tap by tap into one token', (
      tester,
    ) async {
      final moves = await mount(tester, 'checkers', doubleJump());
      await tester.tapAt(squareAt(tester, 1));
      await tester.tapAt(squareAt(tester, 10));
      expect(moves, isEmpty, reason: 'the jump is not over at 10');
      await tester.tapAt(squareAt(tester, 19));
      expect(moves, ['1x10x19']);
    });

    testWidgets('a tap on the final landing of the only route completes it', (
      tester,
    ) async {
      final moves = await mount(tester, 'checkers', doubleJump());
      await tester.tapAt(squareAt(tester, 1));
      await tester.tapAt(squareAt(tester, 19));
      expect(moves, ['1x10x19']);
    });

    testWidgets('illegal targets and a disabled board emit nothing', (tester) async {
      var moves = await mount(tester, 'checkers', start);
      await tester.tapAt(squareAt(tester, 11));
      await tester.tapAt(squareAt(tester, 20));
      await tester.tapAt(squareAt(tester, 1));
      await tester.tapAt(squareAt(tester, 5));
      expect(moves, isEmpty);

      moves = await mount(tester, 'checkers', start, enabled: false);
      await tester.tapAt(squareAt(tester, 11));
      await tester.tapAt(squareAt(tester, 15));
      expect(moves, isEmpty);
    });

    testWidgets('the light player sees the board unrotated', (tester) async {
      final moves = await mount(tester, 'checkers', start.replaceFirst('|0|', '|1|'), mySeat: 1);
      await tester.tapAt(squareAt(tester, 22, flipped: false));
      await tester.tapAt(squareAt(tester, 18, flipped: false));
      expect(moves, ['22-18']);
    });

    testWidgets('a jump animates along its route and settles', (tester) async {
      Widget board(String s, String? last) => host(
        TurnBoard(gameId: 'checkers', state: s, lastMove: last, mySeat: 1),
      );
      await tester.pumpWidget(board(doubleJump(), null));
      final after = List.filled(32, '.');
      after[18] = 'b';
      await tester.pumpWidget(board('${after.join()}|1|0|', '1x10x19'));
      await tester.pump(const Duration(milliseconds: 200));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  });

  group('dots', () {
    final start = dotsRules.encode(dotsRules.initial(2));

    DotsLayout layout(WidgetTester tester) => DotsLayout(boardSize(tester), 4, 4);

    testWidgets('a tap near an edge draws it', (tester) async {
      final moves = await mount(tester, 'dots', start);
      final l = layout(tester);
      // A little off the midpoint of the top-left horizontal.
      await tester.tapAt(origin(tester) + Offset.lerp(l.dot(0, 0), l.dot(0, 1), 0.4)! + Offset(0, l.cell * 0.15));
      expect(moves, ['0']);
    });

    testWidgets('the middle of a box is near no edge', (tester) async {
      final moves = await mount(tester, 'dots', start);
      final l = layout(tester);
      await tester.tapAt(origin(tester) + l.box(5).center);
      expect(moves, isEmpty);
    });

    testWidgets('a drawn edge cannot be drawn again; a disabled board draws nothing', (
      tester,
    ) async {
      final s = dotsRules.apply(dotsRules.initial(2), 0);
      var moves = await mount(tester, 'dots', dotsRules.encode(s), mySeat: 1);
      final l = layout(tester);
      final mid = Offset.lerp(l.dot(0, 0), l.dot(0, 1), 0.5)!;
      await tester.tapAt(origin(tester) + mid);
      expect(moves, isEmpty);

      moves = await mount(tester, 'dots', start, enabled: false);
      await tester.tapAt(origin(tester) + mid);
      expect(moves, isEmpty);
    });

    testWidgets('a vertical edge by its index', (tester) async {
      final moves = await mount(tester, 'dots', start);
      final l = layout(tester);
      // Vertical lines start after the 20 horizontals: row 1, column 2 is
      // 20 + 1 * 5 + 2.
      await tester.tapAt(origin(tester) + Offset.lerp(l.dot(1, 2), l.dot(2, 2), 0.5)!);
      expect(moves, ['27']);
    });
  });

  testWidgets('a thumbnail has no gesture detectors and emits nothing', (
    tester,
  ) async {
    final states = {
      'tictactoe': 'X...O..../0',
      'connectfour': connectFourRules.encode(connectFourRules.apply(connectFourRules.initial(2), 3)),
      'reversi': reversiRules.encode(reversiRules.initial(2)),
      'checkers': 'bbbbbbbbbbbb........wwwwwwwwwwww|0|0|',
      'dots': dotsRules.encode(dotsRules.initial(2)),
    };
    for (final e in states.entries) {
      final moves = await mount(tester, e.key, e.value, thumbnail: true);
      final board = find.byType(TurnBoard);
      expect(find.descendant(of: board, matching: find.byType(GestureDetector)), findsNothing);
      expect(find.descendant(of: board, matching: find.byType(RawGestureDetector)), findsNothing);
      await tester.tapAt(tester.getCenter(board));
      expect(moves, isEmpty, reason: e.key);
    }
  });

  testWidgets('an undecodable state renders nothing rather than throwing', (
    tester,
  ) async {
    await mount(tester, 'reversi', 'nonsense');
    await mount(tester, 'nosuchgame', 'X........./0');
    expect(tester.takeException(), isNull);
  });

  test('Connect Four is square when playable and 7:6 as a thumbnail', () {
    expect(TurnBoard.aspectRatioOf('connectfour', ''), 1);
    expect(TurnBoard.aspectRatioOf('connectfour', '', thumbnail: true), closeTo(7 / 6, 1e-9));
    expect(TurnBoard.aspectRatioOf('dots', '3x5|'), greaterThan(1));
  });
}
