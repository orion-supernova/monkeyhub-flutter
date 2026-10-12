/// Reversi — the Dart mirror of `backend/convex/turnGames/reversi.ts`.
///
/// 8×8, seat 0 is black and opens from the standard crossed centre. The wire
/// state is the 64 cells row-major (`B`, `W`, `.`), a slash, the seat to move,
/// and a trailing `p` when the OTHER seat just had to pass. A move is the cell
/// index and must flip at least one disc. Both mirrors replay
/// `test/fixtures/turn_games/reversi.json`.
///
/// Passes are never moves: when the side due next has nothing legal but the
/// side that just moved does, [ReversiRules.apply] hands the turn back and sets
/// [ReversiState.passed] so the UI can say who was skipped. When neither side
/// can move the game is over and most discs wins.
library;

import 'dart:typed_data';

import 'turn_rules.dart';

/// A position. [cells] holds 0 for empty, else seat + 1 (1 black, 2 white).
///
/// [moves] are [toMove]'s legal cells, ascending, worked out once when the
/// state is built: [ReversiRules.apply] has to find them anyway to decide on a
/// pass, and the search then reads legal moves and game-over for free. It is
/// empty exactly when the game is over.
class ReversiState {
  const ReversiState(this.cells, this.toMove, this.passed, this.moves);

  final Uint8List cells;
  final int toMove;

  /// The seat that is not [toMove] had no move and was skipped to get here.
  final bool passed;
  final List<int> moves;

  /// The skipped seat, if there was one.
  int? get passedSeat => passed ? 1 - toMove : null;

  bool get isOver => moves.isEmpty;
}

const _marks = ['.', 'B', 'W'];

const _dr = [-1, -1, -1, 0, 0, 1, 1, 1];
const _dc = [-1, 0, 1, -1, 1, -1, 0, 1];

/// Flips [seat] would make by playing [cell], written into [out] when given.
/// Returns how many; zero means the move is illegal.
int _flips(Uint8List cells, int seat, int cell, [List<int>? out]) {
  if (cells[cell] != 0) return 0;
  final mine = seat + 1;
  final theirs = 2 - seat;
  final r0 = cell >> 3;
  final c0 = cell & 7;
  var total = 0;
  for (var d = 0; d < 8; d++) {
    var r = r0 + _dr[d];
    var c = c0 + _dc[d];
    var run = 0;
    while (r >= 0 && r < 8 && c >= 0 && c < 8 && cells[r * 8 + c] == theirs) {
      run++;
      r += _dr[d];
      c += _dc[d];
    }
    if (run == 0 || r < 0 || r >= 8 || c < 0 || c >= 8) continue;
    if (cells[r * 8 + c] != mine) continue;
    total += run;
    if (out != null) {
      for (var k = 1; k <= run; k++) {
        out.add((r0 + k * _dr[d]) * 8 + c0 + k * _dc[d]);
      }
    }
  }
  return total;
}

/// Every cell [seat] could play on [cells], ascending.
List<int> reversiMovesFor(Uint8List cells, int seat) => [
  for (var i = 0; i < 64; i++)
    if (_flips(cells, seat, i) > 0) i,
];

class ReversiRules extends TurnRules<ReversiState, int> {
  const ReversiRules();

  @override
  String get id => 'reversi';
  @override
  int get minSeats => 2;
  @override
  int get maxSeats => 2;

  @override
  ReversiState initial(int seats) {
    final cells = Uint8List(64);
    cells[27] = 2;
    cells[28] = 1;
    cells[35] = 1;
    cells[36] = 2;
    return ReversiState(cells, 0, false, reversiMovesFor(cells, 0));
  }

  @override
  int toMove(ReversiState state) => state.toMove;

  @override
  List<int> legalMoves(ReversiState state) => state.moves;

  /// `[black, white]` disc counts.
  List<int> discCounts(ReversiState state) {
    var b = 0;
    var w = 0;
    for (final v in state.cells) {
      if (v == 1) b++;
      if (v == 2) w++;
    }
    return [b, w];
  }

  @override
  TurnOutcome? outcome(ReversiState state) {
    if (!state.isOver) return null;
    final [b, w] = discCounts(state);
    return TurnOutcome(
      winner: b == w
          ? null
          : b > w
          ? 0
          : 1,
      reason: 'discs',
    );
  }

  @override
  ReversiState apply(ReversiState state, int move) {
    if (move < 0 || move >= 64) throw IllegalMove('cell $move');
    final flips = <int>[];
    if (_flips(state.cells, state.toMove, move, flips) == 0) {
      throw IllegalMove('cell $move');
    }
    final cells = Uint8List.fromList(state.cells);
    final mine = state.toMove + 1;
    cells[move] = mine;
    for (final i in flips) {
      cells[i] = mine;
    }
    final other = 1 - state.toMove;
    final theirMoves = reversiMovesFor(cells, other);
    if (theirMoves.isNotEmpty) {
      return ReversiState(cells, other, false, theirMoves);
    }
    final myMoves = reversiMovesFor(cells, state.toMove);
    if (myMoves.isNotEmpty) {
      return ReversiState(cells, state.toMove, true, myMoves);
    }
    // Neither side can move: over. The turn passes as usual, as in the TS.
    return ReversiState(cells, other, false, const []);
  }

  @override
  String encode(ReversiState state) =>
      '${state.cells.map((v) => _marks[v]).join()}/${state.toMove}'
      '${state.passed ? 'p' : ''}';

  @override
  ReversiState decode(String raw) {
    if (!RegExp(r'^[BW.]{64}/[01]p?$').hasMatch(raw)) {
      throw FormatException('BAD_STATE', raw);
    }
    final cells = Uint8List(64);
    for (var i = 0; i < 64; i++) {
      cells[i] = _marks.indexOf(raw[i]);
    }
    final toMove = raw.codeUnitAt(65) - 0x30;
    final passed = raw.length == 67;
    // The four centre squares start filled and discs are never removed.
    for (final i in const [27, 28, 35, 36]) {
      if (cells[i] == 0) throw FormatException('BAD_STATE', raw);
    }
    final moves = reversiMovesFor(cells, toMove);
    final other = reversiMovesFor(cells, 1 - toMove).isNotEmpty;
    // apply would have passed for a stuck mover, and only flags a pass that
    // really happened (and never on a finished game).
    if (moves.isEmpty && other) throw FormatException('BAD_STATE', raw);
    if (passed && (other || moves.isEmpty)) {
      throw FormatException('BAD_STATE', raw);
    }
    return ReversiState(cells, toMove, passed, moves);
  }

  @override
  String encodeMove(int move) => '$move';

  /// Strict: only the tokens [encodeMove] writes, so `"019"` is not `19`.
  @override
  int decodeMove(String raw) {
    final v = int.tryParse(raw);
    if (v == null || '$v' != raw) throw IllegalMove(raw);
    return v;
  }
}

const reversiRules = ReversiRules();

/// Square weights: corners +100 (never flippable), X-squares −50 and C-squares
/// −20 (they hand the neighbouring corner over), other edges +10.
const reversiWeights = <int>[
  100, -20, 10, 10, 10, 10, -20, 100, //
  -20, -50, 0, 0, 0, 0, -50, -20, //
  10, 0, 0, 0, 0, 0, 0, 10, //
  10, 0, 0, 0, 0, 0, 0, 10, //
  10, 0, 0, 0, 0, 0, 0, 10, //
  10, 0, 0, 0, 0, 0, 0, 10, //
  -20, -50, 0, 0, 0, 0, -50, -20, //
  100, -20, 10, 10, 10, 10, -20, 100, //
];

/// Every cell, heaviest weight first: the static move order for both
/// evaluators. Corners first is most of what makes alpha-beta prune here.
final List<int> _byWeight = [for (var i = 0; i < 64; i++) i]
  ..sort((a, b) {
    final d = reversiWeights[b] - reversiWeights[a];
    return d != 0 ? d : a - b;
  });

List<int> _orderByWeight(List<int> moves) {
  if (moves.length < 2) return moves;
  final set = List<bool>.filled(64, false);
  for (final m in moves) {
    set[m] = true;
  }
  return [
    for (final c in _byWeight)
      if (set[c]) c,
  ];
}

/// The medium bot's view: the weight matrix and nothing else.
class ReversiPositionalEvaluator extends TurnEvaluator<ReversiState, int> {
  const ReversiPositionalEvaluator();

  @override
  double evaluate(ReversiState state, int seat) {
    final me = seat + 1;
    var score = 0;
    for (var i = 0; i < 64; i++) {
      final v = state.cells[i];
      if (v == me) {
        score += reversiWeights[i];
      } else if (v != 0) {
        score -= reversiWeights[i];
      }
    }
    return score.toDouble();
  }

  @override
  List<int> order(ReversiState state, List<int> moves) =>
      _orderByWeight(moves);
}

const reversiPositionalEvaluator = ReversiPositionalEvaluator();

/// The hard bot's view: positional weights, mobility and corners.
///
/// The X- and C-square penalties only make sense while their corner is open —
/// once anyone owns the corner, the square next to it is no longer a gift —
/// so they are dropped then. Mobility (my moves minus theirs) is what stops
/// the classic beginner's mistake of grabbing discs in the middlegame, and
/// corners get a bonus on top of their weight because nothing else on the
/// board is permanent.
class ReversiEvaluator extends TurnEvaluator<ReversiState, int> {
  const ReversiEvaluator();

  static const _corners = [0, 7, 56, 63];

  /// Each corner's X-square, then its C-squares.
  static const _guards = [
    [9, 1, 8],
    [14, 6, 15],
    [49, 57, 48],
    [54, 62, 55],
  ];

  @override
  double evaluate(ReversiState state, int seat) {
    final me = seat + 1;
    final c = state.cells;
    var score = 0.0;
    for (var i = 0; i < 64; i++) {
      final v = c[i];
      if (v == me) {
        score += reversiWeights[i];
      } else if (v != 0) {
        score -= reversiWeights[i];
      }
    }
    for (var k = 0; k < 4; k++) {
      final corner = c[_corners[k]];
      if (corner == 0) continue;
      score += corner == me ? 30 : -30;
      // The corner is taken: undo its neighbours' penalties.
      for (final g in _guards[k]) {
        final v = c[g];
        if (v == 0) continue;
        final w = reversiWeights[g].toDouble();
        score += v == me ? -w : w;
      }
    }
    final moverMoves = state.moves.length;
    final otherMoves = reversiMovesFor(c, 1 - state.toMove).length;
    final mobility = state.toMove == seat
        ? moverMoves - otherMoves
        : otherMoves - moverMoves;
    return score + 8 * mobility;
  }

  @override
  List<int> order(ReversiState state, List<int> moves) =>
      _orderByWeight(moves);
}

const reversiEvaluator = ReversiEvaluator();

/// Empty squares left, for the bot's exact-endgame switch.
int reversiEmpties(ReversiState state) {
  var n = 0;
  for (final v in state.cells) {
    if (v == 0) n++;
  }
  return n;
}
