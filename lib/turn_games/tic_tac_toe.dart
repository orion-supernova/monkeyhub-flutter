/// Tic-tac-toe — the Dart mirror of `backend/convex/turnGames/ticTacToe.ts`.
///
/// Seat 0 is X and opens. The wire state is the nine cells row-major (`X`,
/// `O`, `.`), a slash and the seat to move: `"X.O....../1"`. A move is the cell
/// index, `0`..`8` (`"0"`..`"8"` on the wire). Both mirrors replay
/// `test/fixtures/turn_games/tictactoe.json`.
library;

import 'dart:typed_data';

import 'turn_rules.dart';

/// A position. [cells] holds 0 for empty, else seat + 1 (1 = X, 2 = O).
class TicTacToeState {
  const TicTacToeState(this.cells, this.toMove);

  final Uint8List cells;
  final int toMove;
}

/// Every three-in-a-row: rows, then columns, then diagonals.
const ticTacToeLines = <List<int>>[
  [0, 1, 2],
  [3, 4, 5],
  [6, 7, 8],
  [0, 3, 6],
  [1, 4, 7],
  [2, 5, 8],
  [0, 4, 8],
  [2, 4, 6],
];

const _marks = ['.', 'X', 'O'];

class TicTacToeRules extends TurnRules<TicTacToeState, int> {
  const TicTacToeRules();

  @override
  String get id => 'tictactoe';
  @override
  int get minSeats => 2;
  @override
  int get maxSeats => 2;

  @override
  TicTacToeState initial(int seats) => TicTacToeState(Uint8List(9), 0);

  @override
  int toMove(TicTacToeState state) => state.toMove;

  /// The first completed line, for the UI to strike through.
  List<int>? winningLine(TicTacToeState state) {
    final c = state.cells;
    for (final l in ticTacToeLines) {
      final m = c[l[0]];
      if (m != 0 && m == c[l[1]] && m == c[l[2]]) return l;
    }
    return null;
  }

  @override
  TurnOutcome? outcome(TicTacToeState state) {
    final line = winningLine(state);
    if (line != null) {
      return TurnOutcome(winner: state.cells[line[0]] - 1, reason: 'line');
    }
    if (!state.cells.contains(0)) {
      return const TurnOutcome(winner: null, reason: 'full');
    }
    return null;
  }

  @override
  List<int> legalMoves(TicTacToeState state) {
    if (outcome(state) != null) return const [];
    return [
      for (var i = 0; i < 9; i++)
        if (state.cells[i] == 0) i,
    ];
  }

  @override
  TicTacToeState apply(TicTacToeState state, int move) {
    if (move < 0 || move > 8 || state.cells[move] != 0) {
      throw IllegalMove('cell $move');
    }
    if (outcome(state) != null) throw const IllegalMove('game over');
    final cells = Uint8List.fromList(state.cells);
    cells[move] = state.toMove + 1;
    return TicTacToeState(cells, 1 - state.toMove);
  }

  @override
  String encode(TicTacToeState state) =>
      '${state.cells.map((v) => _marks[v]).join()}/${state.toMove}';

  @override
  TicTacToeState decode(String raw) {
    if (!RegExp(r'^[XO.]{9}/[01]$').hasMatch(raw)) {
      throw FormatException('BAD_STATE', raw);
    }
    final cells = Uint8List(9);
    var x = 0;
    var o = 0;
    for (var i = 0; i < 9; i++) {
      final v = _marks.indexOf(raw[i]);
      cells[i] = v;
      if (v == 1) x++;
      if (v == 2) o++;
    }
    final turn = raw.codeUnitAt(10) - 0x30;
    // X opens, so X is level with O (X to move) or one ahead (O to move).
    if (x != o + turn) throw FormatException('BAD_STATE', raw);
    // Play stops at the first line, so only the side that just moved owns one.
    var xLine = false;
    var oLine = false;
    for (final l in ticTacToeLines) {
      final m = cells[l[0]];
      if (m != 0 && m == cells[l[1]] && m == cells[l[2]]) {
        if (m == 1) xLine = true;
        if (m == 2) oLine = true;
      }
    }
    if (xLine && (oLine || turn != 1)) throw FormatException('BAD_STATE', raw);
    if (oLine && turn != 0) throw FormatException('BAD_STATE', raw);
    return TicTacToeState(cells, turn);
  }

  @override
  String encodeMove(int move) => '$move';

  /// Strict: only the tokens [encodeMove] writes, so `"04"` is not `4`.
  @override
  int decodeMove(String raw) {
    final v = int.tryParse(raw);
    if (v == null || '$v' != raw) throw IllegalMove(raw);
    return v;
  }
}

const ticTacToeRules = TicTacToeRules();

/// Open lines, squared: a line holding only my marks scores +n², only theirs
/// −n². Small enough to be noise next to a win, but it is what makes the
/// centre (four lines) beat a corner (three) beat an edge (two) on a shallow
/// search, which is all the easy and medium bots lean on.
class TicTacToeEvaluator extends TurnEvaluator<TicTacToeState, int> {
  const TicTacToeEvaluator();

  @override
  double evaluate(TicTacToeState state, int seat) {
    final me = seat + 1;
    final c = state.cells;
    var score = 0;
    for (final l in ticTacToeLines) {
      var mine = 0;
      var theirs = 0;
      for (final i in l) {
        if (c[i] == me) {
          mine++;
        } else if (c[i] != 0) {
          theirs++;
        }
      }
      if (theirs == 0) score += mine * mine;
      if (mine == 0) score -= theirs * theirs;
    }
    return score.toDouble();
  }

  static const _rank = [1, 2, 1, 2, 0, 2, 1, 2, 1];

  /// Centre, then corners, then edges.
  @override
  List<int> order(TicTacToeState state, List<int> moves) =>
      [...moves]..sort((a, b) => _rank[a].compareTo(_rank[b]));
}

const ticTacToeEvaluator = TicTacToeEvaluator();
