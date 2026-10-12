/// Checkers — English draughts / American checkers — mirrored from
/// `backend/convex/turnGames/checkers.ts`.
///
/// Every rule and every ordering here is the TS module's, line for line: the
/// server decides, and a move drawn here that `matches:move` then refuses
/// snaps back under the player's finger. `test/turn_games/checkers_test.dart`
/// replays the server's own playouts to keep the two honest.
///
/// The board is the 32 dark squares in PDN order, dark (seat 0) on 1–12 moving
/// toward 32, so a move token is plain PDN: `11-15`, or `22x15x8` for a whole
/// multi-jump, which is always one move.
library;

import 'turn_rules.dart';

// ── Pieces ──────────────────────────────────────────────────────────────────

/// Square contents. Ints, not chars, because the bot reads the board millions
/// of times and a string compare per read is the search budget gone.
const int _empty = 0;
const int _darkMan = 1;
const int _darkKing = 2;
const int _lightMan = 3;
const int _lightKing = 4;

/// The wire char for each code, indexed by code.
const String _pieceChars = '.bBwW';

/// Base-32 square names for the repetition history, as the TS writes them.
const String _squareChars = '0123456789abcdefghijklmnopqrstuv';

/// Plies with no capture and no man move before the game is drawn.
const int checkersQuietLimit = 80;

int _sideOf(int p) => p == _empty ? -1 : (p <= _darkKing ? 0 : 1);

bool _isKing(int p) => p == _darkKing || p == _lightKing;

int _rowOf(int i) => i ~/ 4;

int _colOf(int i) {
  final r = i ~/ 4;
  final k = i % 4;
  return r.isEven ? 2 * k + 1 : 2 * k;
}

int _crownRow(int side) => side == 0 ? 7 : 0;

// ── Geometry ────────────────────────────────────────────────────────────────

/// Diagonal steps, ordered so neighbours come out in ascending square order —
/// the same order as `DIRS` in the TS, which is what fixes `legalMoves`.
const List<List<int>> _dirs = [
  [-1, -1],
  [-1, 1],
  [1, -1],
  [1, 1],
];

const List<int> _allDirs = [0, 1, 2, 3];
const List<int> _darkManDirs = [2, 3];
const List<int> _lightManDirs = [0, 1];

int _indexAt(int r, int c) {
  if (r < 0 || r > 7 || c < 0 || c > 7) return -1;
  if ((r + c).isEven) return -1;
  return r * 4 + (c >> 1);
}

/// `_step[i][d]` is the neighbour in direction d, -1 off the board.
final List<List<int>> _step = [
  for (var i = 0; i < 32; i++)
    [for (final d in _dirs) _indexAt(_rowOf(i) + d[0], _colOf(i) + d[1])],
];

/// `_jump[i][d]` is the landing square two steps away, or -1.
final List<List<int>> _jump = [
  for (var i = 0; i < 32; i++)
    [
      for (final d in _dirs)
        _indexAt(_rowOf(i) + 2 * d[0], _colOf(i) + 2 * d[1]),
    ],
];

List<int> _dirsFor(int p) {
  if (_isKing(p)) return _allDirs;
  return _sideOf(p) == 0 ? _darkManDirs : _lightManDirs;
}

// ── State and moves ─────────────────────────────────────────────────────────

/// A decoded position. Never mutated once built — [CheckersRules.apply]
/// trusts a move straight out of [CheckersRules.legalMoves] for the same
/// instance, which is only sound if the board cannot change underneath it.
class CheckersState {
  const CheckersState({
    required this.board,
    required this.turn,
    required this.quiet,
    required this.history,
  });

  /// 32 piece codes, index 0 is PDN square 1.
  final List<int> board;

  /// Seat to move: 0 dark, 1 light.
  final int turn;

  /// Plies since the last capture or man move.
  final int quiet;

  /// One kings-only key per position since the last irreversible move, the
  /// current one last. Between irreversible moves the men are frozen, so the
  /// king squares are the whole difference between two positions; see the TS
  /// for the full argument.
  final List<String> history;

  /// The wire char for square [i] (0-based), for the board painter.
  String pieceAt(int i) => _pieceChars[board[i]];
}

/// One move: the squares the piece lands on, start first, and what it jumps.
class CheckersMove {
  const CheckersMove(this.squares, this.captures) : _origin = null;

  const CheckersMove._from(this.squares, this.captures, this._origin);

  /// 0-based squares, the start square first and the final landing last.
  final List<int> squares;

  /// 0-based squares of the jumped pieces, in jump order. Empty for a step.
  final List<int> captures;

  /// The state this move was generated for, when it came from `legalMoves`.
  final CheckersState? _origin;

  bool get isCapture => captures.isNotEmpty;
  int get from => squares.first;
  int get to => squares.last;

  /// PDN: `11-15`, or `22x15x8`.
  String get token =>
      squares.map((s) => '${s + 1}').join(isCapture ? 'x' : '-');

  @override
  bool operator ==(Object other) =>
      other is CheckersMove && other.token == token;

  @override
  int get hashCode => token.hashCode;

  @override
  String toString() => token;
}

// ── Move generation ─────────────────────────────────────────────────────────

void _jumpsFrom(
  List<int> board,
  int from,
  CheckersState? origin,
  List<CheckersMove> out,
) {
  final piece = board[from];
  final side = _sideOf(piece);
  final dirs = _dirsFor(piece);
  final king = _isKing(piece);
  final squares = <int>[from];
  final captures = <int>[];
  final work = List<int>.of(board);
  // The jumper's own square is free mid-move; the jumped stay as obstacles.
  work[from] = _empty;

  void walk(int at) {
    var extended = false;
    for (final d in dirs) {
      final land = _jump[at][d];
      if (land < 0 || work[land] != _empty) continue;
      final mid = _step[at][d];
      if (_sideOf(work[mid]) != 1 - side) continue;
      if (captures.contains(mid)) continue;
      extended = true;
      squares.add(land);
      captures.add(mid);
      // Crowning ends the move, even with another jump on offer.
      if (!king && _rowOf(land) == _crownRow(side)) {
        out.add(
          CheckersMove._from(List.of(squares), List.of(captures), origin),
        );
      } else {
        walk(land);
      }
      squares.removeLast();
      captures.removeLast();
    }
    if (!extended && captures.isNotEmpty) {
      out.add(CheckersMove._from(List.of(squares), List.of(captures), origin));
    }
  }

  walk(from);
}

/// Legal moves for [side] on [board], whoever is really to move — the
/// evaluator asks for the side not on move to measure its mobility.
List<CheckersMove> _movesFor(
  List<int> board,
  int side, [
  CheckersState? origin,
]) {
  final jumps = <CheckersMove>[];
  for (var i = 0; i < 32; i++) {
    if (_sideOf(board[i]) == side) _jumpsFrom(board, i, origin, jumps);
  }
  if (jumps.isNotEmpty) return jumps;
  final steps = <CheckersMove>[];
  for (var i = 0; i < 32; i++) {
    if (_sideOf(board[i]) != side) continue;
    for (final d in _dirsFor(board[i])) {
      final to = _step[i][d];
      if (to >= 0 && board[to] == _empty) {
        steps.add(CheckersMove._from([i, to], const [], origin));
      }
    }
  }
  return steps;
}

String _kingKey(List<int> board) {
  final dark = StringBuffer();
  final light = StringBuffer();
  for (var i = 0; i < 32; i++) {
    if (board[i] == _darkKing) dark.write(_squareChars[i]);
    if (board[i] == _lightKing) light.write(_squareChars[i]);
  }
  return '$dark$light';
}

int _repetitions(CheckersState s) {
  final h = s.history;
  final last = h.length - 1;
  var n = 0;
  // Same side to move means same parity of index.
  for (var i = last; i >= 0; i -= 2) {
    if (h[i] == h[last]) n++;
  }
  return n;
}

// ── Rules ───────────────────────────────────────────────────────────────────

class CheckersRules extends TurnRules<CheckersState, CheckersMove> {
  const CheckersRules();

  @override
  String get id => 'checkers';

  @override
  int get minSeats => 2;

  @override
  int get maxSeats => 2;

  @override
  CheckersState initial(int seats) {
    if (seats != 2) throw const IllegalMove('checkers is two seats');
    final board = [
      for (var i = 0; i < 32; i++)
        i < 12 ? _darkMan : (i >= 20 ? _lightMan : _empty),
    ];
    return CheckersState(
      board: board,
      turn: 0,
      quiet: 0,
      history: [_kingKey(board)],
    );
  }

  @override
  int toMove(CheckersState state) => state.turn;

  @override
  List<CheckersMove> legalMoves(CheckersState state) {
    if (outcome(state) != null) return const [];
    return _movesFor(state.board, state.turn, state);
  }

  @override
  CheckersState apply(CheckersState state, CheckersMove move) {
    var path = move;
    // A move straight out of legalMoves(state) is already known good; the
    // bot plays only those, and re-deriving them per node halves its speed.
    if (!identical(move._origin, state)) {
      if (outcome(state) != null) throw const IllegalMove('game over');
      final token = move.token;
      final match = _movesFor(state.board, state.turn)
          .where((m) => m.token == token);
      if (match.isEmpty) throw IllegalMove(token);
      path = match.first;
    }
    final board = List<int>.of(state.board);
    var piece = board[path.from];
    board[path.from] = _empty;
    for (final c in path.captures) {
      board[c] = _empty;
    }
    final wasMan = !_isKing(piece);
    if (wasMan && _rowOf(path.to) == _crownRow(state.turn)) {
      piece = piece == _darkMan ? _darkKing : _lightKing;
    }
    board[path.to] = piece;
    final key = _kingKey(board);
    final irreversible = wasMan || path.isCapture;
    return CheckersState(
      board: board,
      turn: 1 - state.turn,
      quiet: irreversible ? 0 : state.quiet + 1,
      history: irreversible ? [key] : [...state.history, key],
    );
  }

  @override
  TurnOutcome? outcome(CheckersState state) {
    if (_movesFor(state.board, state.turn).isEmpty) {
      return TurnOutcome(winner: 1 - state.turn, reason: 'no-moves');
    }
    if (_repetitions(state) >= 3) {
      return const TurnOutcome(winner: null, reason: 'repetition');
    }
    if (state.quiet >= checkersQuietLimit) {
      return const TurnOutcome(winner: null, reason: 'move-limit');
    }
    return null;
  }

  @override
  String encode(CheckersState state) {
    final board = state.board.map((p) => _pieceChars[p]).join();
    return '$board|${state.turn}|${state.quiet}|${state.history.join()}';
  }

  @override
  CheckersState decode(String raw) {
    Never bad() => throw FormatException('BAD_STATE', raw);
    final parts = raw.split('|');
    if (parts.length != 4) bad();
    final b = parts[0];
    final t = parts[1];
    final q = parts[2];
    final h = parts[3];
    if (!RegExp(r'^[.bBwW]{32}$').hasMatch(b)) bad();
    if (t != '0' && t != '1') bad();
    if (!RegExp(r'^(0|[1-9][0-9]?)$').hasMatch(q)) bad();
    final quiet = int.parse(q);
    if (quiet > checkersQuietLimit) bad();
    final board = [for (var i = 0; i < 32; i++) _pieceChars.indexOf(b[i])];
    for (var i = 0; i < 4; i++) {
      if (board[i] == _lightMan) bad();
    }
    for (var i = 28; i < 32; i++) {
      if (board[i] == _darkMan) bad();
    }
    final key = _kingKey(board);
    final k = key.length;
    final history = <String>[];
    if (k == 0) {
      if (quiet != 0 || h.isNotEmpty) bad();
      history.add('');
    } else {
      if (h.length != (quiet + 1) * k) bad();
      final darkKings = board.where((p) => p == _darkKing).length;
      for (var i = 0; i < h.length; i += k) {
        final entry = h.substring(i, i + k);
        // Each half must be strictly ascending squares, as _kingKey writes.
        for (var j = 0; j < k; j++) {
          final v = _squareChars.indexOf(entry[j]);
          if (v < 0) bad();
          if (j != 0 && j != darkKings) {
            if (_squareChars.indexOf(entry[j - 1]) >= v) bad();
          }
        }
        history.add(entry);
      }
      if (history.last != key) bad();
    }
    return CheckersState(
      board: board,
      turn: int.parse(t),
      quiet: quiet,
      history: history,
    );
  }

  @override
  String encodeMove(CheckersMove move) => move.token;

  @override
  CheckersMove decodeMove(String raw) {
    final capture = raw.contains('x');
    final parts = raw.split(capture ? 'x' : '-');
    if (parts.length < 2 || (!capture && parts.length != 2)) {
      throw FormatException('BAD_MOVE', raw);
    }
    final squares = <int>[];
    for (final p in parts) {
      if (!RegExp(r'^[1-9][0-9]?$').hasMatch(p)) {
        throw FormatException('BAD_MOVE', raw);
      }
      final s = int.parse(p);
      if (s > 32) throw FormatException('BAD_MOVE', raw);
      squares.add(s - 1);
    }
    // The jumped squares are implied by the landings; a token whose hops are
    // not two-square diagonals will simply never match a legal move.
    final captures = <int>[];
    if (capture) {
      for (var i = 0; i + 1 < squares.length; i++) {
        final a = squares[i];
        final b = squares[i + 1];
        final r = (_rowOf(a) + _rowOf(b)) ~/ 2;
        final c = (_colOf(a) + _colOf(b)) ~/ 2;
        captures.add(_indexAt(r, c));
      }
    }
    return CheckersMove(squares, captures);
  }
}

const checkersRules = CheckersRules();

// ── Evaluator ───────────────────────────────────────────────────────────────

/// Squares (0-based) of the middle of the board, where a piece controls the
/// most diagonals: rows 2–5, columns 2–5.
const Set<int> _centre = {9, 10, 13, 14, 17, 18, 21, 22};

/// A classic hand-tuned draughts evaluation, in centi-men.
///
/// Material dominates (man 100, king 150), then the positional terms that
/// separate a weak club player from a beginner: advance men toward the crown,
/// keep the back row as a guard against the enemy crowning, hold the centre,
/// and keep options open. In a won endgame the kings are pulled toward the
/// enemy — without that a king-up position just shuffles until the 40-move
/// rule draws it.
class CheckersEvaluator extends TurnEvaluator<CheckersState, CheckersMove> {
  const CheckersEvaluator();

  static const double man = 100;
  static const double king = 150;
  static const double advance = 3;
  static const double backGuard = 10;
  static const double centre = 5;
  static const double mobility = 2;
  static const double chase = 4;

  /// Total pieces at or under which a material lead starts the king chase.
  static const int endgamePieces = 8;

  @override
  double evaluate(CheckersState state, int seat) {
    final result = checkersRules.outcome(state);
    if (result != null) {
      if (result.winner == null) return 0;
      return result.winner == seat
          ? TurnEvaluator.winScore
          : -TurnEvaluator.winScore;
    }
    final score = [0.0, 0.0];
    final material = [0.0, 0.0];
    var pieces = 0;
    final b = state.board;
    for (var i = 0; i < 32; i++) {
      final p = b[i];
      if (p == _empty) continue;
      pieces++;
      final side = _sideOf(p);
      final r = _rowOf(i);
      if (_isKing(p)) {
        material[side] += king;
      } else {
        material[side] += man;
        // Rows advanced from the man's own back row.
        score[side] += advance * (side == 0 ? r : 7 - r);
        if (r == (side == 0 ? 0 : 7)) score[side] += backGuard;
      }
      if (_centre.contains(i)) score[side] += centre;
    }
    for (var side = 0; side < 2; side++) {
      score[side] += material[side];
      score[side] += mobility * _movesFor(b, side).length;
    }
    if (pieces <= endgamePieces) {
      for (var side = 0; side < 2; side++) {
        if (material[side] <= material[1 - side]) continue;
        // Each king earns more the closer it stands to its nearest target.
        for (var i = 0; i < 32; i++) {
          if (!_isKing(b[i]) || _sideOf(b[i]) != side) continue;
          var nearest = 7;
          for (var j = 0; j < 32; j++) {
            if (_sideOf(b[j]) != 1 - side) continue;
            final dr = (_rowOf(i) - _rowOf(j)).abs();
            final dc = (_colOf(i) - _colOf(j)).abs();
            final d = dr > dc ? dr : dc;
            if (d < nearest) nearest = d;
          }
          score[side] += chase * (7 - nearest);
        }
      }
    }
    return score[seat] - score[1 - seat];
  }

  /// Captures are all-or-nothing (they are forced), so the useful order is
  /// longer jumps first, then crowning steps; everything else keeps the
  /// generator's order, which `sort` would not promise, hence the index key.
  @override
  List<CheckersMove> order(CheckersState state, List<CheckersMove> moves) {
    int rank(CheckersMove m) {
      if (m.isCapture) return 100 + m.captures.length;
      final p = state.board[m.from];
      if (!_isKing(p) && _rowOf(m.to) == _crownRow(_sideOf(p))) return 50;
      return 0;
    }

    final indexed = [for (var i = 0; i < moves.length; i++) i];
    final ranks = [for (final m in moves) rank(m)];
    indexed.sort((a, b) {
      final byRank = ranks[b].compareTo(ranks[a]);
      return byRank != 0 ? byRank : a.compareTo(b);
    });
    return [for (final i in indexed) moves[i]];
  }
}

const checkersEvaluator = CheckersEvaluator();
