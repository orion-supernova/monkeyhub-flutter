/// Connect Four — the Dart mirror of `backend/convex/turnGames/connectFour.ts`.
///
/// 7 columns by 6 rows, seat 0 (`X`) opens. The wire state is the 42 cells
/// row-major with row 0 at the TOP, a slash and the seat to move. A move is
/// the column, `0`..`6`. A full board with no four is a draw. Both mirrors
/// replay `test/fixtures/turn_games/connectfour.json`.
///
/// Plain arrays, not 64-bit bitboards: on Flutter web Dart's bitwise operators
/// are 32-bit, and a bitboard that silently loses its top rows there would be
/// a much worse bug than a slower search.
library;

import 'dart:typed_data';

import 'turn_rules.dart';

const connectFourCols = 7;
const connectFourRows = 6;
const _n = connectFourCols * connectFourRows;

/// A position. [cells] holds 0 for empty, else seat + 1, row 0 at the top.
///
/// [result] is worked out once by [ConnectFourRules.apply] (or `decode`) so the
/// search never rescans the board for an outcome: -1 while the game goes on,
/// else the winning seat, or 2 for a draw.
class ConnectFourState {
  const ConnectFourState(this.cells, this.toMove, this.result);

  final Uint8List cells;
  final int toMove;
  final int result;
}

/// Every window of four cells — 69 of them — rows, columns, both diagonals.
final List<List<int>> connectFourWindows = _buildWindows();

List<List<int>> _buildWindows() {
  const dirs = [
    [0, 1],
    [1, 0],
    [1, 1],
    [1, -1],
  ];
  final out = <List<int>>[];
  for (var r = 0; r < connectFourRows; r++) {
    for (var c = 0; c < connectFourCols; c++) {
      for (final d in dirs) {
        final er = r + 3 * d[0];
        final ec = c + 3 * d[1];
        if (er < 0 || er >= connectFourRows || ec < 0) continue;
        if (ec >= connectFourCols) continue;
        out.add([
          for (var k = 0; k < 4; k++)
            (r + k * d[0]) * connectFourCols + c + k * d[1],
        ]);
      }
    }
  }
  return out;
}

const _marks = ['.', 'X', 'O'];

/// The mark that owns a four anywhere on [cells], or 0. Same scan order as the
/// TS `fourOwner`.
int _fourOwner(Uint8List cells) {
  for (final w in connectFourWindows) {
    final m = cells[w[0]];
    if (m != 0 && cells[w[1]] == m && cells[w[2]] == m && cells[w[3]] == m) {
      return m;
    }
  }
  return 0;
}

/// Whether the disc just dropped on [cell] completes a four. Only lines
/// through it can be new, so this is four short walks, not a board scan.
bool _completesFour(Uint8List cells, int cell) {
  final m = cells[cell];
  final r0 = cell ~/ connectFourCols;
  final c0 = cell % connectFourCols;
  const dirs = [
    [0, 1],
    [1, 0],
    [1, 1],
    [1, -1],
  ];
  for (final d in dirs) {
    var run = 1;
    for (final s in const [1, -1]) {
      var r = r0 + s * d[0];
      var c = c0 + s * d[1];
      while (r >= 0 &&
          r < connectFourRows &&
          c >= 0 &&
          c < connectFourCols &&
          cells[r * connectFourCols + c] == m) {
        run++;
        r += s * d[0];
        c += s * d[1];
      }
    }
    if (run >= 4) return true;
  }
  return false;
}

class ConnectFourRules extends TurnRules<ConnectFourState, int> {
  const ConnectFourRules();

  @override
  String get id => 'connectfour';
  @override
  int get minSeats => 2;
  @override
  int get maxSeats => 2;

  @override
  ConnectFourState initial(int seats) => ConnectFourState(Uint8List(_n), 0, -1);

  @override
  int toMove(ConnectFourState state) => state.toMove;

  /// Every cell that is part of a four, ascending, for the UI to light up.
  List<int> winningCells(ConnectFourState state) {
    final hit = <int>{};
    for (final w in connectFourWindows) {
      final m = state.cells[w[0]];
      if (m != 0 && w.every((i) => state.cells[i] == m)) hit.addAll(w);
    }
    return hit.toList()..sort();
  }

  @override
  TurnOutcome? outcome(ConnectFourState state) => switch (state.result) {
    -1 => null,
    2 => const TurnOutcome(winner: null, reason: 'full'),
    final w => TurnOutcome(winner: w, reason: 'four'),
  };

  @override
  List<int> legalMoves(ConnectFourState state) {
    if (state.result != -1) return const [];
    return [
      for (var c = 0; c < connectFourCols; c++)
        if (state.cells[c] == 0) c,
    ];
  }

  @override
  ConnectFourState apply(ConnectFourState state, int move) {
    if (state.result != -1) throw const IllegalMove('game over');
    if (move < 0 || move >= connectFourCols || state.cells[move] != 0) {
      throw IllegalMove('column $move');
    }
    final cells = Uint8List.fromList(state.cells);
    var r = connectFourRows - 1;
    while (cells[r * connectFourCols + move] != 0) {
      r--;
    }
    final cell = r * connectFourCols + move;
    cells[cell] = state.toMove + 1;
    var result = -1;
    if (_completesFour(cells, cell)) {
      result = state.toMove;
    } else if (r == 0 && !cells.sublist(0, connectFourCols).contains(0)) {
      // The top row fills last, so it alone says whether the board is full.
      result = 2;
    }
    return ConnectFourState(cells, 1 - state.toMove, result);
  }

  @override
  String encode(ConnectFourState state) =>
      '${state.cells.map((v) => _marks[v]).join()}/${state.toMove}';

  @override
  ConnectFourState decode(String raw) {
    if (raw.length != _n + 2 || !RegExp(r'^[XO.]+/[01]$').hasMatch(raw)) {
      throw FormatException('BAD_STATE', raw);
    }
    final cells = Uint8List(_n);
    for (var i = 0; i < _n; i++) {
      cells[i] = _marks.indexOf(raw[i]);
    }
    final turn = raw.codeUnitAt(_n + 1) - 0x30;
    var x = 0;
    var o = 0;
    for (var i = 0; i < _n; i++) {
      if (cells[i] == 1) x++;
      if (cells[i] == 2) o++;
      // Nothing floats: a disc's cell below must be filled too.
      if (cells[i] != 0 && i + connectFourCols < _n) {
        if (cells[i + connectFourCols] == 0) {
          throw FormatException('BAD_STATE', raw);
        }
      }
    }
    if (x != o + turn) throw FormatException('BAD_STATE', raw);
    // Only the side that just moved can own a four.
    final owner = _fourOwner(cells);
    if (owner != 0) {
      if (owner != 2 - turn) throw FormatException('BAD_STATE', raw);
      final other = turn + 1;
      for (final w in connectFourWindows) {
        if (w.every((i) => cells[i] == other)) {
          throw FormatException('BAD_STATE', raw);
        }
      }
    }
    final result = owner != 0
        ? owner - 1
        : !cells.sublist(0, connectFourCols).contains(0)
        ? 2
        : -1;
    return ConnectFourState(cells, turn, result);
  }

  @override
  String encodeMove(int move) => '$move';

  /// Strict: only the tokens [encodeMove] writes, so `"03"` is not `3`.
  @override
  int decodeMove(String raw) {
    final v = int.tryParse(raw);
    if (v == null || '$v' != raw) throw IllegalMove(raw);
    return v;
  }
}

const connectFourRules = ConnectFourRules();

/// The classic window heuristic, from [seat]'s side.
///
/// Every window of four that only one side has discs in is a potential line:
/// three of mine and a gap scores 5, two scores 2. The opponent's windows
/// count the same, negated and weighted ×1.2, because a shallow search that
/// rates its own threats as highly as the other side's walks into forced
/// losses. A disc in the centre column is worth 3: it sits in more windows
/// than any other, which is the whole of Connect Four's opening theory.
class ConnectFourEvaluator extends TurnEvaluator<ConnectFourState, int> {
  const ConnectFourEvaluator();

  @override
  double evaluate(ConnectFourState state, int seat) {
    final me = seat + 1;
    final c = state.cells;
    var score = 0.0;
    for (final w in connectFourWindows) {
      var mine = 0;
      var theirs = 0;
      for (final i in w) {
        final v = c[i];
        if (v == me) {
          mine++;
        } else if (v != 0) {
          theirs++;
        }
      }
      if (theirs == 0) {
        if (mine == 3) score += 5;
        if (mine == 2) score += 2;
      } else if (mine == 0) {
        if (theirs == 3) score -= 6;
        if (theirs == 2) score -= 2.4;
      }
    }
    for (var r = 0; r < connectFourRows; r++) {
      final v = c[r * connectFourCols + 3];
      if (v == me) {
        score += 3;
      } else if (v != 0) {
        score -= 3;
      }
    }
    return score;
  }

  static const _rank = [6, 4, 2, 0, 1, 3, 5];

  /// Centre first, then outwards, left before right.
  @override
  List<int> order(ConnectFourState state, List<int> moves) =>
      [...moves]..sort((a, b) => _rank[a].compareTo(_rank[b]));
}

const connectFourEvaluator = ConnectFourEvaluator();
