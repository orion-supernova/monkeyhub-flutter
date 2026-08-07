/// The daily games' rules, mirrored on the device.
///
/// The server is still the only authority on winning — `games:submit` validates
/// a finished board against the same generator it came from, and a solve is not
/// a solve until it says so. What lives here is the *feedback*: which cells are
/// currently fighting each other, whether the grid is full and consistent, and
/// which move the board should refuse.
///
/// It has to be on the device, because the alternative is a round trip per tap.
/// A logic grid that tells you a hundred milliseconds later that the crown you
/// just placed conflicts is a grid you stop trusting, and these are timed — a
/// player should never be waiting on a network to find out they contradicted
/// themselves.
///
/// Every function here is a mirror of one in `backend/convex/games/*.ts`, named
/// to match, and drifting from it is a real bug: the client would light a cell
/// red on a board the server is about to accept, or worse, sit there looking
/// complete while `submit` rejects it.
library;

import '../models/daily_game.dart';

// ── Queens ──────────────────────────────────────────────────────────────────

/// What a Queens cell is currently holding.
enum QueensMark {
  /// Untouched.
  none,

  /// The player's own "definitely not here" cross.
  blocked,

  /// A crown.
  crown,
}

/// The cells holding crowns that break a rule, plus every crown they clash
/// with.
///
/// Returns the whole clashing set rather than "the offending one", because
/// there is no offending one: two crowns in a column are equally wrong and
/// highlighting whichever was placed second would be an opinion, not a rule.
Set<int> queensConflicts(QueensBoard board, List<QueensMark> marks) {
  final n = board.size;
  final crowns = <int>[
    for (var i = 0; i < marks.length; i++)
      if (marks[i] == QueensMark.crown) i,
  ];
  final bad = <int>{};
  for (var a = 0; a < crowns.length; a++) {
    for (var b = a + 1; b < crowns.length; b++) {
      final x = crowns[a];
      final y = crowns[b];
      final sameRow = x ~/ n == y ~/ n;
      final sameCol = x % n == y % n;
      final sameRegion = board.regions[x] == board.regions[y];
      final touching =
          (x ~/ n - y ~/ n).abs() <= 1 && (x % n - y % n).abs() <= 1;
      if (sameRow || sameCol || sameRegion || touching) {
        bad
          ..add(x)
          ..add(y);
      }
    }
  }
  return bad;
}

/// Cells no crown could legally go in, given the crowns already placed.
///
/// Drives the auto-cross: placing a crown crosses out its row, its column, its
/// colour and the ring around it, which is bookkeeping the player would
/// otherwise do by hand sixty times a board. It is a *derived* view and never
/// written into the player's own marks — a crown they later remove must take
/// its crosses with it, and it cannot do that if they were baked in.
Set<int> queensBlocked(QueensBoard board, List<QueensMark> marks) {
  final n = board.size;
  final out = <int>{};
  for (var i = 0; i < marks.length; i++) {
    if (marks[i] != QueensMark.crown) continue;
    final row = i ~/ n;
    final col = i % n;
    final region = board.regions[i];
    for (var j = 0; j < n * n; j++) {
      if (j == i) continue;
      if (j ~/ n == row ||
          j % n == col ||
          board.regions[j] == region ||
          ((j ~/ n - row).abs() <= 1 && (j % n - col).abs() <= 1)) {
        out.add(j);
      }
    }
  }
  return out;
}

/// The crowns as a column per row, or null unless there is exactly one per row.
/// This is the shape `games:submit` expects.
List<int>? queensSolution(QueensBoard board, List<QueensMark> marks) {
  final n = board.size;
  // A board that has not arrived yet has no solution — without this guard an
  // empty grid reads as "zero rows, all of them satisfied" and auto-submits.
  if (n == 0 || marks.length != n * n) return null;
  final cols = List<int>.filled(n, -1);
  for (var i = 0; i < marks.length; i++) {
    if (marks[i] != QueensMark.crown) continue;
    final row = i ~/ n;
    if (cols[row] != -1) return null;
    cols[row] = i % n;
  }
  return cols.contains(-1) ? null : cols;
}

/// Whether the board is finished and legal. Mirrors `isSolved` in queens.ts.
bool queensSolved(QueensBoard board, List<QueensMark> marks) {
  final cols = queensSolution(board, marks);
  if (cols == null) return false;
  return queensConflicts(board, marks).isEmpty;
}

// ── Tango ───────────────────────────────────────────────────────────────────

/// Which cells and which operators are currently contradicted.
class TangoTrouble {
  const TangoTrouble({required this.cells, required this.signs});

  /// Cells taking part in a broken rule.
  final Set<int> cells;

  /// Indices into [TangoBoard.signs] whose two cells disagree with it.
  final Set<int> signs;

  bool get isEmpty => cells.isEmpty && signs.isEmpty;
}

/// Everything wrong with a partially-filled Tango grid.
///
/// Only ever reports what is *already* broken, never what is about to be: a
/// half-filled row holding two suns has not violated the three-per-line rule,
/// and colouring it as an error would be telling the player they are wrong for
/// having started.
TangoTrouble tangoTrouble(TangoBoard board, List<int> cells) {
  final n = board.size;
  // Nothing to be wrong about before the board arrives, and every loop below
  // indexes `cells` by a position the grid says exists.
  if (n == 0 || cells.length != n * n) {
    return const TangoTrouble(cells: <int>{}, signs: <int>{});
  }
  final bad = <int>{};
  final badSigns = <int>{};
  final perLine = n ~/ 2;

  for (var line = 0; line < n; line++) {
    final rowCount = <int, List<int>>{};
    final colCount = <int, List<int>>{};
    for (var k = 0; k < n; k++) {
      final ri = line * n + k;
      final ci = k * n + line;
      if (cells[ri] != tangoEmpty) rowCount.putIfAbsent(cells[ri], () => []).add(ri);
      if (cells[ci] != tangoEmpty) colCount.putIfAbsent(cells[ci], () => []).add(ci);

      // Three in a row, in both axes. Reported the moment the third lands
      // rather than at the end, because that is the move to undo.
      if (k >= 2) {
        final a = cells[line * n + k - 2];
        if (a != tangoEmpty &&
            a == cells[line * n + k - 1] &&
            a == cells[line * n + k]) {
          bad.addAll([line * n + k - 2, line * n + k - 1, line * n + k]);
        }
        final b = cells[(k - 2) * n + line];
        if (b != tangoEmpty &&
            b == cells[(k - 1) * n + line] &&
            b == cells[k * n + line]) {
          bad.addAll([(k - 2) * n + line, (k - 1) * n + line, k * n + line]);
        }
      }
    }
    for (final group in [...rowCount.values, ...colCount.values]) {
      if (group.length > perLine) bad.addAll(group);
    }
  }

  for (var s = 0; s < board.signs.length; s++) {
    final sign = board.signs[s];
    final a = cells[sign.a];
    final b = cells[sign.b];
    if (a == tangoEmpty || b == tangoEmpty) continue;
    if (sign.eq ? a != b : a == b) {
      badSigns.add(s);
      bad
        ..add(sign.a)
        ..add(sign.b);
    }
  }

  return TangoTrouble(cells: bad, signs: badSigns);
}

/// Whether the grid is full and legal. Mirrors `isSolved` in tango.ts.
bool tangoSolved(TangoBoard board, List<int> cells) {
  if (board.size == 0 || cells.length != board.size * board.size) return false;
  if (cells.contains(tangoEmpty)) return false;
  return tangoTrouble(board, cells).isEmpty;
}

// ── Mini Sudoku ─────────────────────────────────────────────────────────────

/// Cells holding a digit that repeats in their row, column or box.
Set<int> sudokuConflicts(SudokuBoard board, List<int> cells) {
  final n = board.size;
  if (n == 0 || cells.length != n * n) return const {};
  final bad = <int>{};
  for (var i = 0; i < cells.length; i++) {
    final v = cells[i];
    if (v == sudokuEmpty) continue;
    for (var j = i + 1; j < cells.length; j++) {
      if (cells[j] != v) continue;
      final sameRow = i ~/ n == j ~/ n;
      final sameCol = i % n == j % n;
      final sameBox =
          _boxOf(i, n) == _boxOf(j, n);
      if (sameRow || sameCol || sameBox) {
        bad
          ..add(i)
          ..add(j);
      }
    }
  }
  return bad;
}

int _boxOf(int index, int n) {
  final row = index ~/ n;
  final col = index % n;
  return (row ~/ SudokuBoard.boxRows) * (n ~/ SudokuBoard.boxCols) +
      col ~/ SudokuBoard.boxCols;
}

/// Whether the grid is full and legal. Mirrors `isSolved` in sudoku.ts.
bool sudokuSolved(SudokuBoard board, List<int> cells) {
  if (board.size == 0 || cells.length != board.size * board.size) return false;
  if (cells.contains(sudokuEmpty)) return false;
  return sudokuConflicts(board, cells).isEmpty;
}

// ── Zip ─────────────────────────────────────────────────────────────────────

/// Whether [a] and [b] share an edge on an [n]×[n] grid.
bool gridAdjacent(int a, int b, int n) {
  final dr = (a ~/ n - b ~/ n).abs();
  final dc = (a % n - b % n).abs();
  return dr + dc == 1;
}

/// Whether the line may be extended onto [cell].
///
/// The order rule is enforced here rather than reported afterwards, and that is
/// a deliberate difference from the other three games. Queens and Tango are
/// about noticing a contradiction — showing it is the game. Zip is one
/// continuous gesture, and letting a finger slide through ⑤ before ④ only to
/// paint the line red behind it makes the drag feel broken. So the line simply
/// does not follow.
bool zipCanEnter(ZipBoard board, List<int> path, int cell) {
  if (board.checkpoints.isEmpty) return false;
  if (path.contains(cell)) return false;
  if (path.isNotEmpty && !gridAdjacent(path.last, cell, board.size)) return false;
  if (path.isEmpty) return cell == board.checkpoints.first;
  final next = board.checkpoints.indexOf(cell);
  if (next < 0) return true;
  // Stepping onto a numbered dot is only legal if every lower number is behind
  // you — which, since dots are only ever entered in order, means exactly the
  // one after the last dot the line has already passed through.
  var reached = 0;
  for (final c in board.checkpoints) {
    if (path.contains(c)) reached++;
  }
  return next == reached;
}

/// Whether the line finishes the board. Mirrors `isSolved` in zip.ts.
bool zipSolved(ZipBoard board, List<int> path) {
  final total = board.size * board.size;
  if (total == 0 || path.length != total) return false;
  if (path.toSet().length != total) return false;
  for (var i = 1; i < path.length; i++) {
    if (!gridAdjacent(path[i - 1], path[i], board.size)) return false;
  }
  final order = board.checkpoints.map(path.indexOf).toList();
  if (order.first != 0 || order.last != total - 1) return false;
  for (var i = 1; i < order.length; i++) {
    if (order[i] <= order[i - 1]) return false;
  }
  return true;
}
