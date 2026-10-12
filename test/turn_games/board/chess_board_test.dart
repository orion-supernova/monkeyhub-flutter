import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monkeyhub/theme/basic_theme.dart';
import 'package:monkeyhub/theme/theme_scope.dart';
import 'package:monkeyhub/turn_games/board/chess_board.dart';
import 'package:monkeyhub/turn_games/board/turn_board.dart';
import 'package:monkeyhub/turn_games/chess.dart';

/// The chess board through TurnBoard, mounted for real: taps, drags and the
/// promotion picker go through the gesture arena to the rules of record, and
/// only a legal UCI token may come out.
void main() {
  const side = 320.0;
  final start = chessRules.encode(chessRules.initial(2));

  Widget host(Widget board) => MaterialApp(
    home: ThemeScope(
      controller: ThemeController(BasicTheme.midnight()),
      child: Center(child: SizedBox(width: side, child: board)),
    ),
  );

  Future<List<String>> mount(
    WidgetTester tester,
    String state, {
    int? mySeat = 0,
    bool enabled = true,
    bool thumbnail = false,
  }) async {
    final moves = <String>[];
    await tester.pumpWidget(
      host(
        TurnBoard(
          gameId: 'chess',
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

  /// The screen centre of square [name] (`e4`), as the board draws it.
  Offset at(WidgetTester tester, String name, {bool flipped = false}) {
    final board = find.byType(TurnBoard);
    final g = ChessGeometry(tester.getSize(board), flipped: flipped);
    final sq = (8 - int.parse(name[1])) * 8 + name.codeUnitAt(0) - 0x61;
    return tester.getTopLeft(board) + g.center(sq);
  }

  Future<void> tapSquares(WidgetTester tester, List<String> names, {bool flipped = false}) async {
    for (final n in names) {
      await tester.tapAt(at(tester, n, flipped: flipped));
      await tester.pump();
    }
  }

  testWidgets('select, then land: a tap move emits its UCI token', (tester) async {
    final moves = await mount(tester, start);
    await tapSquares(tester, ['e2']);
    expect(moves, isEmpty);
    await tapSquares(tester, ['e4']);
    expect(moves, ['e2e4']);
  });

  testWidgets('a tap on another own piece moves the selection; an illegal square does nothing', (
    tester,
  ) async {
    final moves = await mount(tester, start);
    // e5 is no move for e2 and holds nothing of white's: the selection
    // goes. g4 likewise for the knight.
    await tapSquares(tester, ['e2', 'e5', 'g1', 'g4', 'f3']);
    expect(moves, isEmpty);
    // A second own piece takes the selection over without a move.
    await tapSquares(tester, ['e2', 'g1', 'f3']);
    expect(moves, ['g1f3']);
  });

  testWidgets('a drag carries the piece and drops it on release', (tester) async {
    final moves = await mount(tester, start);
    final gesture = await tester.startGesture(at(tester, 'd2'));
    await tester.pump();
    final to = at(tester, 'd4');
    final from = at(tester, 'd2');
    for (var i = 1; i <= 6; i++) {
      await gesture.moveTo(Offset.lerp(from, to, i / 6)!);
      await tester.pump(const Duration(milliseconds: 16));
    }
    expect(moves, isEmpty, reason: 'nothing moves while the finger is down');
    await gesture.up();
    await tester.pumpAndSettle();
    expect(moves, ['d2d4']);
  });

  group('promotion', () {
    const pawnOnE7 = '8/4P3/8/8/8/8/k7/4K3 w - - 0 1|';

    testWidgets('the picker opens over the board, and the queen emits e7e8q', (tester) async {
      final moves = await mount(tester, pawnOnE7);
      await tapSquares(tester, ['e7', 'e8']);
      expect(moves, isEmpty, reason: 'waits for the piece');
      for (final p in 'qnrb'.split('')) {
        expect(find.byKey(ValueKey('chess-promotion-$p')), findsOne);
      }
      await tester.tap(find.byKey(const ValueKey('chess-promotion-q')));
      await tester.pumpAndSettle();
      expect(moves, ['e7e8q']);
      expect(find.byKey(const ValueKey('chess-promotion-q')), findsNothing);
    });

    testWidgets('under-promotion to a knight', (tester) async {
      final moves = await mount(tester, pawnOnE7);
      await tapSquares(tester, ['e7', 'e8']);
      await tester.tap(find.byKey(const ValueKey('chess-promotion-n')));
      await tester.pumpAndSettle();
      expect(moves, ['e7e8n']);
    });

    testWidgets('a tap outside the picker cancels it and emits nothing', (tester) async {
      final moves = await mount(tester, pawnOnE7);
      await tapSquares(tester, ['e7', 'e8']);
      await tester.tapAt(at(tester, 'a1'));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('chess-promotion-q')), findsNothing);
      expect(moves, isEmpty);
    });
  });

  testWidgets('castling is the king moving two squares, either side of the board', (tester) async {
    var moves = await mount(tester, '4k3/8/8/8/8/8/8/R3K2R w KQ - 0 1|');
    await tapSquares(tester, ['e1', 'g1']);
    expect(moves, ['e1g1']);

    // Black, from black's side of the board: long castling.
    moves = await mount(tester, 'r3k3/8/8/8/8/8/8/4K3 b q - 0 1|', mySeat: 1);
    await tapSquares(tester, ['e8', 'c8'], flipped: true);
    expect(moves, ['e8c8']);
  });

  testWidgets('a disabled board, the wrong seat or a finished game emits nothing', (tester) async {
    var moves = await mount(tester, start, enabled: false);
    await tapSquares(tester, ['e2', 'e4']);
    expect(moves, isEmpty);

    moves = await mount(tester, start, mySeat: 1);
    await tapSquares(tester, ['e2', 'e4'], flipped: true);
    expect(moves, isEmpty);

    var s = chessRules.initial(2);
    for (final m in ['f2f3', 'e7e5', 'g2g4', 'd8h4']) {
      s = chessRules.apply(s, chessRules.decodeMove(m));
    }
    moves = await mount(tester, chessRules.encode(s));
    await tapSquares(tester, ['a2', 'a3']);
    expect(moves, isEmpty);
  });

  testWidgets('a thumbnail has no gestures and emits nothing', (tester) async {
    final moves = await mount(tester, start, thumbnail: true);
    final board = find.byType(TurnBoard);
    expect(find.descendant(of: board, matching: find.byType(GestureDetector)), findsNothing);
    expect(find.descendant(of: board, matching: find.byType(RawGestureDetector)), findsNothing);
    await tapSquares(tester, ['e2', 'e4']);
    expect(moves, isEmpty);
  });

  testWidgets('each square has a label, and legal ones activate', (tester) async {
    final handle = tester.ensureSemantics();
    final moves = await mount(tester, start);
    expect(find.semantics.byLabel('e2, pawn, white'), findsOne);
    expect(find.semantics.byLabel('e8, king, black'), findsOne);
    tester.semantics.tap(find.semantics.byLabel('e2, pawn, white'));
    await tester.pump();
    tester.semantics.tap(find.semantics.byLabel(RegExp(r'^e4, .*, ')));
    expect(moves, ['e2e4']);
    handle.dispose();
  });

  testWidgets('a move slides, a capture fades, and both settle', (tester) async {
    Widget board(String s, String? last) =>
        host(TurnBoard(gameId: 'chess', state: s, lastMove: last, mySeat: 1));
    var s = chessRules.initial(2);
    for (final m in ['e2e4', 'd7d5']) {
      s = chessRules.apply(s, chessRules.decodeMove(m));
    }
    await tester.pumpWidget(board(chessRules.encode(s), 'd7d5'));
    s = chessRules.apply(s, chessRules.decodeMove('e4d5'));
    await tester.pumpWidget(board(chessRules.encode(s), 'e4d5'));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pumpAndSettle();
    // Castling slides two pieces.
    final castle = chessRules.decode('4k3/8/8/8/8/8/8/4K2R w K - 0 1|');
    await tester.pumpWidget(board(chessRules.encode(castle), null));
    await tester.pumpWidget(
      board(chessRules.encode(chessRules.apply(castle, chessRules.decodeMove('e1g1'))), 'e1g1'),
    );
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  test('the board is square', () {
    expect(TurnBoard.aspectRatioOf('chess', start), 1);
    expect(TurnBoard.aspectRatioOf('chess', start, thumbnail: true), 1);
  });
}
