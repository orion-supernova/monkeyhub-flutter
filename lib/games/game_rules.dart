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

import 'dart:math' as math;

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

// ── Flow ────────────────────────────────────────────────────────────────────

/// Whether [cells] is one pipe of colour [k]: a run of orthogonal steps from
/// one of its dots to the other, through no other colour's dot.
///
/// Either direction counts. A player drags from whichever dot is nearer their
/// thumb, and the board only flips a pipe round into the submission's order
/// ([flowSolution]) at the very end.
bool flowPipeComplete(FlowBoard board, int k, List<int> cells) {
  if (k < 0 || k >= board.endpoints.length || cells.length < 2) return false;
  final (a, b) = board.endpoints[k];
  final ends = {cells.first, cells.last};
  if (!ends.contains(a) || !ends.contains(b) || a == b) return false;
  for (var i = 0; i < cells.length; i++) {
    if (i > 0 && !gridAdjacent(cells[i - 1], cells[i], board.size)) {
      return false;
    }
    final dot = board.dotAt(cells[i]);
    if (dot >= 0 && dot != k) return false;
  }
  return cells.toSet().length == cells.length;
}

/// The pipes as the flat list `games:submit` takes — each colour's pipe from
/// its first dot to its second, concatenated in colour order — or null unless
/// every pipe is complete, no square is used twice and every square is used.
List<int>? flowSolution(FlowBoard board, List<List<int>> pipes) {
  final n = board.size;
  if (n == 0 || pipes.length != board.endpoints.length) return null;
  final out = <int>[];
  for (var k = 0; k < pipes.length; k++) {
    final pipe = pipes[k];
    if (!flowPipeComplete(board, k, pipe)) return null;
    out.addAll(pipe.first == board.endpoints[k].$1 ? pipe : pipe.reversed);
  }
  if (out.length != n * n || out.toSet().length != n * n) return null;
  return out;
}

/// Whether the board is finished. Mirrors `isSolved` in flow.ts.
bool flowSolved(FlowBoard board, List<List<int>> pipes) =>
    flowSolution(board, pipes) != null;

/// Cuts a flat submission-shaped list back into one pipe per colour.
///
/// The server's answer (a surrender) and a finished board's autosave are both
/// in that shape, and the boundaries are recoverable without a separator: pipe
/// k ends the moment it reaches its second dot. Anything that does not parse
/// cleanly comes back as empty pipes rather than half a board.
List<List<int>> flowPipesOf(FlowBoard board, List<int> flat) {
  final pipes = [for (final _ in board.endpoints) <int>[]];
  var at = 0;
  for (var k = 0; k < board.endpoints.length; k++) {
    final (a, b) = board.endpoints[k];
    if (at >= flat.length || flat[at] != a) {
      return [for (final _ in board.endpoints) <int>[]];
    }
    while (at < flat.length) {
      final cell = flat[at++];
      pipes[k].add(cell);
      if (cell == b) break;
    }
    if (pipes[k].last != b) return [for (final _ in board.endpoints) <int>[]];
  }
  return pipes;
}

// ── Futoshiki ───────────────────────────────────────────────────────────────

/// Which cells and which signs are currently contradicted.
class FutoshikiTrouble {
  const FutoshikiTrouble({required this.cells, required this.signs});

  /// Cells repeating a digit in their row or column, or on a broken sign.
  final Set<int> cells;

  /// Indices into [FutoshikiBoard.signs] whose two filled cells disagree.
  final Set<int> signs;

  bool get isEmpty => cells.isEmpty && signs.isEmpty;
}

/// Everything wrong with a partly filled Futoshiki grid.
///
/// Like Tango's, only what is ALREADY broken: a sign with an empty end has not
/// been violated, it has just not been decided yet.
FutoshikiTrouble futoshikiTrouble(FutoshikiBoard board, List<int> cells) {
  final n = board.size;
  if (n == 0 || cells.length != n * n) {
    return const FutoshikiTrouble(cells: <int>{}, signs: <int>{});
  }
  final bad = <int>{};
  for (var i = 0; i < cells.length; i++) {
    final v = cells[i];
    if (v == futoshikiEmpty) continue;
    for (var j = i + 1; j < cells.length; j++) {
      if (cells[j] != v) continue;
      if (i ~/ n == j ~/ n || i % n == j % n) {
        bad
          ..add(i)
          ..add(j);
      }
    }
  }
  final badSigns = <int>{};
  for (var s = 0; s < board.signs.length; s++) {
    final sign = board.signs[s];
    final a = cells[sign.a];
    final b = cells[sign.b];
    if (a == futoshikiEmpty || b == futoshikiEmpty) continue;
    if (sign.lt ? a >= b : a <= b) {
      badSigns.add(s);
      bad
        ..add(sign.a)
        ..add(sign.b);
    }
  }
  return FutoshikiTrouble(cells: bad, signs: badSigns);
}

/// Whether the grid is full and legal. Mirrors `isSolved` in futoshiki.ts.
bool futoshikiSolved(FutoshikiBoard board, List<int> cells) {
  final n = board.size;
  if (n == 0 || cells.length != n * n) return false;
  for (final v in cells) {
    if (v < 1 || v > n) return false;
  }
  for (var i = 0; i < cells.length; i++) {
    final given = board.givens.length > i ? board.givens[i] : futoshikiEmpty;
    if (given != futoshikiEmpty && given != cells[i]) return false;
  }
  return futoshikiTrouble(board, cells).isEmpty;
}

// ── Nonogram ────────────────────────────────────────────────────────────────

/// The run lengths of the filled squares in [line], in order. An empty line is
/// `[]`, matching the server's clues.
List<int> nonogramRuns(Iterable<int> line) {
  final out = <int>[];
  var run = 0;
  for (final v in line) {
    if (v == nonogramFilled) {
      run++;
    } else if (run > 0) {
      out.add(run);
      run = 0;
    }
  }
  if (run > 0) out.add(run);
  return out;
}

/// Whether some placement of [clue]'s runs agrees with [line] — every filled
/// square inside a run, no crossed square inside one.
///
/// This is what makes a nonogram mistake a fact rather than an opinion. The
/// device does not know the picture (and must not: it would be the answer), but
/// it can say for certain when a row has been shaded or crossed into a state
/// that NO arrangement of its clue fits, which is exactly when the player has
/// made a move the clue rules out. One pass of a small table, so it is cheap
/// enough to run on every line after every tap.
bool nonogramLineFits(List<int> clue, List<int> line) {
  final runs = [for (final r in clue) if (r > 0) r];
  final n = line.length;
  final m = runs.length;
  // fits[i][j]: runs j.. can be laid into cells i.. . Filled backwards.
  final fits = List.generate(n + 1, (_) => List<bool>.filled(m + 1, false));
  fits[n][m] = true;
  for (var i = n - 1; i >= 0; i--) {
    fits[i][m] = line[i] != nonogramFilled && fits[i + 1][m];
  }
  for (var j = m - 1; j >= 0; j--) {
    final len = runs[j];
    for (var i = n - 1; i >= 0; i--) {
      // Square i left out of every run.
      var ok = line[i] != nonogramFilled && fits[i + 1][j];
      // Run j starting on square i, with a gap (or the edge) after it.
      if (!ok && i + len <= n) {
        var clear = true;
        for (var k = i; k < i + len && clear; k++) {
          if (line[k] == nonogramCrossed) clear = false;
        }
        if (clear && (i + len == n || line[i + len] != nonogramFilled)) {
          // Past the run and the gap after it; a run that ends on the edge
          // has no gap, and only the last run may.
          ok = fits[math.min(i + len + 1, n)][j + 1];
        }
      }
      fits[i][j] = ok;
    }
  }
  return fits[0][0];
}

/// Rows and columns no arrangement of their clue fits any more.
class NonogramTrouble {
  const NonogramTrouble({required this.rows, required this.cols});

  final Set<int> rows;
  final Set<int> cols;

  bool get isEmpty => rows.isEmpty && cols.isEmpty;
}

List<int> _nonogramRow(List<int> cells, int n, int row) =>
    cells.sublist(row * n, row * n + n);

List<int> _nonogramCol(List<int> cells, int n, int col) => [
  for (var r = 0; r < n; r++) cells[r * n + col],
];

/// Every line that has been shaded or crossed into a contradiction.
NonogramTrouble nonogramTrouble(NonogramBoard board, List<int> cells) {
  final n = board.size;
  if (n == 0 || cells.length != n * n) {
    return const NonogramTrouble(rows: <int>{}, cols: <int>{});
  }
  return NonogramTrouble(
    rows: {
      for (var r = 0; r < n && r < board.rows.length; r++)
        if (!nonogramLineFits(board.rows[r], _nonogramRow(cells, n, r))) r,
    },
    cols: {
      for (var c = 0; c < n && c < board.cols.length; c++)
        if (!nonogramLineFits(board.cols[c], _nonogramCol(cells, n, c))) c,
    },
  );
}

bool _sameRuns(List<int> clue, List<int> runs) {
  final want = [for (final r in clue) if (r > 0) r];
  if (want.length != runs.length) return false;
  for (var i = 0; i < want.length; i++) {
    if (want[i] != runs[i]) return false;
  }
  return true;
}

/// Lines whose shaded squares already read back their clue exactly — the ones
/// the board dims, so the eye goes to what is still open.
({Set<int> rows, Set<int> cols}) nonogramSatisfied(
  NonogramBoard board,
  List<int> cells,
) {
  final n = board.size;
  if (n == 0 || cells.length != n * n) return (rows: <int>{}, cols: <int>{});
  return (
    rows: {
      for (var r = 0; r < n && r < board.rows.length; r++)
        if (_sameRuns(board.rows[r], nonogramRuns(_nonogramRow(cells, n, r))))
          r,
    },
    cols: {
      for (var c = 0; c < n && c < board.cols.length; c++)
        if (_sameRuns(board.cols[c], nonogramRuns(_nonogramCol(cells, n, c))))
          c,
    },
  );
}

/// The grid as `games:submit` takes it: 1 for a shaded square, 0 for anything
/// else. A crossed square and an untouched one mean the same thing to a clue.
List<int> nonogramSolution(List<int> cells) => [
  for (final v in cells) v == nonogramFilled ? 1 : 0,
];

/// Whether every row and column reads back its clue. Mirrors `isSolved` in
/// nonogram.ts, which compares clues rather than cells.
bool nonogramSolved(NonogramBoard board, List<int> cells) {
  final n = board.size;
  if (n == 0 || cells.length != n * n) return false;
  if (board.rows.length != n || board.cols.length != n) return false;
  final done = nonogramSatisfied(board, cells);
  return done.rows.length == n && done.cols.length == n;
}

// ── Minesweeper ─────────────────────────────────────────────────────────────

const _mask32 = 0xFFFFFFFF;

/// `Math.imul`, as an unsigned 32-bit result.
///
/// In halves rather than as one multiply: a 32×32-bit product needs 64 bits,
/// and on the web a Dart int is a JavaScript double that keeps 53 of them. The
/// low and high halves each stay under 2^32, so the same code is exact on
/// every platform the app ships on.
int _imul(int a, int b) {
  a &= _mask32;
  b &= _mask32;
  final ah = (a >> 16) & 0xFFFF;
  final al = a & 0xFFFF;
  final bh = (b >> 16) & 0xFFFF;
  final bl = b & 0xFFFF;
  final high = ((ah * bl + al * bh) & 0xFFFF) << 16;
  return (al * bl + high) & _mask32;
}

/// FNV-1a over UTF-16 code units. Mirrors `fnv1a` in backend/convex/games/rng.ts.
int fnv1a(String s) {
  var h = 2166136261;
  for (var i = 0; i < s.length; i++) {
    h = (h ^ s.codeUnitAt(i)) & _mask32;
    h = _imul(h, 16777619);
  }
  return h & _mask32;
}

/// mulberry32. Mirrors `mulberry32` in backend/convex/games/rng.ts, bit for
/// bit: every step is masked to 32 bits where JavaScript's `>>> 0` and integer
/// coercions do it implicitly.
double Function() mulberry32(int seed) {
  var a = seed & _mask32;
  return () {
    a = (a + 0x6d2b79f5) & _mask32;
    var t = _imul(a ^ (a >> 15), 1 | a);
    t = ((t + _imul(t ^ (t >> 7), 61 | t)) & _mask32) ^ t;
    return ((t ^ (t >> 14)) & _mask32) / 4294967296;
  };
}

/// The mine map (0/1 per cell, row-major) behind [board]'s masked layout.
///
/// The board ships its mines XORed with a keystream seeded by the day, so the
/// answer is not sitting in plain sight in a network log. The device has to
/// know the layout anyway — every tap is answered instantly, without a round
/// trip — so this is the documented decode from `encodeMines` in
/// minesweeper.ts, run once per board. A malformed string decodes to no mines
/// at all, exactly as the server's does.
List<int> minesweeperMines(MinesweeperBoard board, String dayKey) {
  final total = board.size * board.size;
  final out = List<int>.filled(total, 0);
  final bytes = (total + 7) ~/ 8;
  final hex = board.mines;
  if (total == 0 ||
      hex.length != bytes * 2 ||
      !RegExp(r'^[0-9a-f]+$').hasMatch(hex)) {
    return out;
  }
  final rand = mulberry32(fnv1a('$dayKey:minesweeper-mask:0'));
  for (var k = 0; k < bytes; k++) {
    final key = (rand() * 256).floor();
    final byte = int.parse(hex.substring(2 * k, 2 * k + 2), radix: 16) ^ key;
    for (var b = 0; b < 8; b++) {
      final i = k * 8 + b;
      if (i < total) out[i] = (byte >> b) & 1;
    }
  }
  return out;
}

/// The up-to-eight squares around [cell].
List<int> minesweeperNeighbours(int cell, int n) {
  final row = cell ~/ n;
  final col = cell % n;
  return [
    for (var dr = -1; dr <= 1; dr++)
      for (var dc = -1; dc <= 1; dc++)
        if ((dr != 0 || dc != 0) &&
            row + dr >= 0 &&
            row + dr < n &&
            col + dc >= 0 &&
            col + dc < n)
          (row + dr) * n + col + dc,
  ];
}

/// Mines touching each square.
List<int> minesweeperNumbers(List<int> mines, int n) => [
  for (var i = 0; i < mines.length; i++)
    minesweeperNeighbours(i, n).fold(0, (sum, j) => sum + mines[j]),
];

/// Every square a reveal of [cell] opens: the square itself and, when it is a
/// 0, the whole blank patch around it and that patch's numbered rim — the
/// flood every minesweeper does, because tapping out a field of zeros one by
/// one is bookkeeping, not deduction. Flags stop the flood: a flag is the
/// player's word, and the board does not overrule it.
List<int> minesweeperFlood(
  List<int> cells,
  List<int> mines,
  List<int> numbers,
  int n,
  int cell,
) {
  final out = <int>[];
  final seen = <int>{cell};
  final queue = [cell];
  while (queue.isNotEmpty) {
    final i = queue.removeLast();
    if (mines[i] == 1) continue;
    if (cells[i] == minesweeperFlagged && i != cell) continue;
    out.add(i);
    if (numbers[i] != 0) continue;
    for (final j in minesweeperNeighbours(i, n)) {
      if (seen.add(j) && cells[j] == minesweeperHidden) queue.add(j);
    }
  }
  return out;
}

/// Whether every square that is not a mine is open. The submission is then the
/// mine map itself, which is what `isSolved` in minesweeper.ts compares.
bool minesweeperCleared(List<int> cells, List<int> mines) {
  if (cells.isEmpty || cells.length != mines.length) return false;
  for (var i = 0; i < cells.length; i++) {
    if (mines[i] == 1) continue;
    if (cells[i] < 0 || cells[i] > 8) return false;
  }
  return true;
}

// ── Star Battle ─────────────────────────────────────────────────────────────

/// What a Star Battle cell is holding. The same three states as Queens'
/// [QueensMark], in the same tap order, so the two boards play alike.
enum StarMark {
  /// Untouched.
  none,

  /// The player's "no star here" dot.
  dot,

  /// A star.
  star,
}

/// Stars that break a rule — a third in a row, column or region, or two
/// touching, corners included — plus every star they clash with.
Set<int> starBattleConflicts(StarBattleBoard board, List<StarMark> marks) {
  final n = board.size;
  if (n == 0 || marks.length != n * n) return const {};
  final stars = [
    for (var i = 0; i < marks.length; i++)
      if (marks[i] == StarMark.star) i,
  ];
  final bad = <int>{};
  final byRow = <int, List<int>>{};
  final byCol = <int, List<int>>{};
  final byRegion = <int, List<int>>{};
  for (final s in stars) {
    byRow.putIfAbsent(s ~/ n, () => []).add(s);
    byCol.putIfAbsent(s % n, () => []).add(s);
    byRegion.putIfAbsent(board.regions[s], () => []).add(s);
  }
  for (final group in [...byRow.values, ...byCol.values, ...byRegion.values]) {
    if (group.length > StarBattleBoard.stars) bad.addAll(group);
  }
  for (var a = 0; a < stars.length; a++) {
    for (var b = a + 1; b < stars.length; b++) {
      final x = stars[a];
      final y = stars[b];
      if ((x ~/ n - y ~/ n).abs() <= 1 && (x % n - y % n).abs() <= 1) {
        bad
          ..add(x)
          ..add(y);
      }
    }
  }
  return bad;
}

/// Squares no star could go in given the stars already placed: the ring
/// around each star, and the rest of any row, column or region that already
/// holds its two. Derived, never written into the player's marks, for the
/// reason [queensBlocked] gives.
Set<int> starBattleBlocked(StarBattleBoard board, List<StarMark> marks) {
  final n = board.size;
  if (n == 0 || marks.length != n * n) return const {};
  final rows = List<int>.filled(n, 0);
  final cols = List<int>.filled(n, 0);
  final regions = List<int>.filled(n, 0);
  final out = <int>{};
  for (var i = 0; i < marks.length; i++) {
    if (marks[i] != StarMark.star) continue;
    rows[i ~/ n]++;
    cols[i % n]++;
    if (board.regions[i] < n) regions[board.regions[i]]++;
    out.addAll(minesweeperNeighbours(i, n));
  }
  for (var i = 0; i < marks.length; i++) {
    if (rows[i ~/ n] >= StarBattleBoard.stars ||
        cols[i % n] >= StarBattleBoard.stars ||
        (board.regions[i] < n &&
            regions[board.regions[i]] >= StarBattleBoard.stars)) {
      out.add(i);
    }
  }
  out.removeWhere((i) => marks[i] == StarMark.star);
  return out;
}

/// The board as `games:submit` takes it: 1 for a star, 0 for anything else.
List<int> starBattleSolution(List<StarMark> marks) => [
  for (final m in marks) m == StarMark.star ? 1 : 0,
];

/// Whether the board is finished and legal. Mirrors `isSolved` in
/// starbattle.ts.
bool starBattleSolved(StarBattleBoard board, List<StarMark> marks) {
  final n = board.size;
  if (n == 0 || marks.length != n * n) return false;
  final rows = List<int>.filled(n, 0);
  final cols = List<int>.filled(n, 0);
  final regions = List<int>.filled(n, 0);
  for (var i = 0; i < marks.length; i++) {
    if (marks[i] != StarMark.star) continue;
    rows[i ~/ n]++;
    cols[i % n]++;
    final r = board.regions[i];
    if (r < 0 || r >= n) return false;
    regions[r]++;
  }
  for (var k = 0; k < n; k++) {
    if (rows[k] != StarBattleBoard.stars ||
        cols[k] != StarBattleBoard.stars ||
        regions[k] != StarBattleBoard.stars) {
      return false;
    }
  }
  return starBattleConflicts(board, marks).isEmpty;
}

// ── Patches ─────────────────────────────────────────────────────────────────

/// A patch: a rectangle by its inclusive corners.
class PatchRect {
  const PatchRect(this.top, this.left, this.bottom, this.right);

  /// The rectangle with [a] and [b] at opposite corners, in either order —
  /// what a drag from one square to another spans.
  factory PatchRect.span(int a, int b, int n) => PatchRect(
    math.min(a ~/ n, b ~/ n),
    math.min(a % n, b % n),
    math.max(a ~/ n, b ~/ n),
    math.max(a % n, b % n),
  );

  final int top;
  final int left;
  final int bottom;
  final int right;

  int get rows => bottom - top + 1;
  int get cols => right - left + 1;
  int get area => rows * cols;

  bool contains(int cell, int n) {
    final r = cell ~/ n;
    final c = cell % n;
    return r >= top && r <= bottom && c >= left && c <= right;
  }

  bool overlaps(PatchRect o) =>
      top <= o.bottom && o.top <= bottom && left <= o.right && o.left <= right;

  /// The squares inside, row-major.
  Iterable<int> cells(int n) sync* {
    for (var r = top; r <= bottom; r++) {
      for (var c = left; c <= right; c++) {
        yield r * n + c;
      }
    }
  }

  @override
  bool operator ==(Object other) =>
      other is PatchRect &&
      other.top == top &&
      other.left == left &&
      other.bottom == bottom &&
      other.right == right;

  @override
  int get hashCode => Object.hash(top, left, bottom, right);
}

/// Why a rectangle cannot be a patch.
enum PatchTrouble {
  /// No clue inside it.
  noClue,

  /// More than one clue inside it.
  twoClues,

  /// One clue, but the wrong proportions for it.
  shape,

  /// One clue, but the wrong number of squares for it.
  area,
}

/// What [rect] would be on [board]: the clue it holds (-1 for none or
/// several) and what is wrong with it, null when it is a legal patch for that
/// clue. The rules `isSolved` in patches.ts checks, one patch at a time.
({int clue, PatchTrouble? trouble}) patchJudge(PatchesBoard board, PatchRect rect) {
  var clue = -1;
  for (var k = 0; k < board.clues.length; k++) {
    if (!rect.contains(board.clues[k].cell, board.size)) continue;
    if (clue >= 0) return (clue: -1, trouble: PatchTrouble.twoClues);
    clue = k;
  }
  if (clue < 0) return (clue: -1, trouble: PatchTrouble.noClue);
  final c = board.clues[clue];
  if (c.area > 0 && rect.area != c.area) {
    return (clue: clue, trouble: PatchTrouble.area);
  }
  if (!c.shape.allows(rect.rows, rect.cols)) {
    return (clue: clue, trouble: PatchTrouble.shape);
  }
  return (clue: clue, trouble: null);
}

/// The clue index covering each square, -1 where no patch is down: the
/// autosave, and — once every square is covered — the submission.
List<int> patchesLabels(PatchesBoard board, List<PatchRect?> patches) {
  final n = board.size;
  final out = List<int>.filled(n * n, -1);
  for (var k = 0; k < patches.length; k++) {
    final rect = patches[k];
    if (rect == null) continue;
    for (final c in rect.cells(n)) {
      out[c] = k;
    }
  }
  return out;
}

/// The inverse of [patchesLabels]. Each clue's squares are kept only if they
/// form a legal patch for it that no earlier clue's patch overlaps — a stale
/// save on a changed board then comes back with fewer patches, never with an
/// illegal one.
List<PatchRect?> patchesFromLabels(PatchesBoard board, List<int> labels) {
  final n = board.size;
  final out = List<PatchRect?>.filled(board.clues.length, null);
  if (labels.length != n * n) return out;
  for (var k = 0; k < board.clues.length; k++) {
    var top = n, left = n, bottom = -1, right = -1, count = 0;
    for (var i = 0; i < labels.length; i++) {
      if (labels[i] != k) continue;
      count++;
      top = math.min(top, i ~/ n);
      bottom = math.max(bottom, i ~/ n);
      left = math.min(left, i % n);
      right = math.max(right, i % n);
    }
    if (count == 0) continue;
    final rect = PatchRect(top, left, bottom, right);
    if (rect.area != count) continue;
    final judged = patchJudge(board, rect);
    if (judged.clue != k || judged.trouble != null) continue;
    if (out.any((o) => o != null && o.overlaps(rect))) continue;
    out[k] = rect;
  }
  return out;
}

/// The submission if every clue has a legal patch and together they cover
/// the board, else null. Patches never overlap on the board (placing one lifts
/// whatever it lands on), so full coverage is a square count.
List<int>? patchesSolution(PatchesBoard board, List<PatchRect?> patches) {
  final n = board.size;
  if (n == 0 || patches.length != board.clues.length) return null;
  var covered = 0;
  for (var k = 0; k < patches.length; k++) {
    final rect = patches[k];
    if (rect == null) return null;
    final judged = patchJudge(board, rect);
    if (judged.clue != k || judged.trouble != null) return null;
    covered += rect.area;
  }
  if (covered != n * n) return null;
  final labels = patchesLabels(board, patches);
  return labels.contains(-1) ? null : labels;
}

/// Whether the board is cut completely and legally. Mirrors `isSolved` in
/// patches.ts.
bool patchesSolved(PatchesBoard board, List<PatchRect?> patches) =>
    patchesSolution(board, patches) != null;
