/// Dots and Boxes, two to four seats — mirrored from
/// `backend/convex/turnGames/dots.ts`.
///
/// The grid is `rows` x `cols` boxes. Lines are numbered horizontals first,
/// row by row ((rows + 1) * cols of them), then verticals row by row
/// (rows * (cols + 1)); a move is that index, and its wire token is the
/// decimal string. Closing one or two boxes scores them and the mover goes
/// again. `test/turn_games/dots_test.dart` replays the server's own playouts.
library;

import 'turn_rules.dart';

// ── Geometry ────────────────────────────────────────────────────────────────

/// The board's incidence tables, built once per size. The bot asks "which
/// boxes does this line touch" at every node, so it is a lookup, not maths.
class DotsGeometry {
  DotsGeometry._(this.rows, this.cols)
    : lineCount = (rows + 1) * cols + rows * (cols + 1),
      boxSides = [],
      lineBoxes = [] {
    final h = (rows + 1) * cols;
    for (var r = 0; r < rows; r++) {
      for (var c = 0; c < cols; c++) {
        boxSides.add([
          r * cols + c,
          (r + 1) * cols + c,
          h + r * (cols + 1) + c,
          h + r * (cols + 1) + c + 1,
        ]);
      }
    }
    for (var line = 0; line < lineCount; line++) {
      final out = <int>[];
      if (line < h) {
        final r = line ~/ cols;
        final c = line % cols;
        if (r > 0) out.add((r - 1) * cols + c);
        if (r < rows) out.add(r * cols + c);
      } else {
        final v = line - h;
        final r = v ~/ (cols + 1);
        final c = v % (cols + 1);
        if (c > 0) out.add(r * cols + c - 1);
        if (c < cols) out.add(r * cols + c);
      }
      lineBoxes.add(out);
    }
  }

  static final Map<int, DotsGeometry> _cache = {};

  static DotsGeometry of(int rows, int cols) =>
      _cache.putIfAbsent(rows * 16 + cols, () => DotsGeometry._(rows, cols));

  final int rows;
  final int cols;
  final int lineCount;

  /// Per box, row-major: top, bottom, left, right line indices.
  final List<List<int>> boxSides;

  /// Per line: the one or two boxes it borders.
  final List<List<int>> lineBoxes;

  int get boxCount => rows * cols;
}

/// The default board, used by [DotsRules.initial] for every seat count.
const int dotsDefaultSize = 4;

/// The largest size [DotsRules.decode] accepts, as in the TS.
const int _maxSize = 8;

// ── State ───────────────────────────────────────────────────────────────────

/// A decoded position. Never mutated once built.
class DotsState {
  const DotsState({
    required this.rows,
    required this.cols,
    required this.lines,
    required this.owners,
    required this.toMove,
    required this.scores,
  });

  final int rows;
  final int cols;

  /// One flag per line, in line-index order.
  final List<bool> lines;

  /// One per box, row-major: the owning seat, or -1 while open.
  final List<int> owners;

  final int toMove;

  /// One per seat, which also fixes the seat count.
  final List<int> scores;

  int get seats => scores.length;

  DotsGeometry get geometry => DotsGeometry.of(rows, cols);

  int sidesDrawn(int box) {
    var n = 0;
    for (final l in geometry.boxSides[box]) {
      if (lines[l]) n++;
    }
    return n;
  }
}

// ── Rules ───────────────────────────────────────────────────────────────────

class DotsRules extends TurnRules<DotsState, int> {
  const DotsRules();

  @override
  String get id => 'dots';

  @override
  int get minSeats => 2;

  @override
  int get maxSeats => 4;

  @override
  DotsState initial(int seats) =>
      initialSized(seats, dotsDefaultSize, dotsDefaultSize);

  /// An empty [rows] x [cols] board. The size lives in the state so a 3 x 3
  /// option can ship later under the same game id.
  DotsState initialSized(int seats, int rows, int cols) {
    if (seats < minSeats || seats > maxSeats) {
      throw IllegalMove('seats $seats');
    }
    if (rows < 1 || cols < 1 || rows > _maxSize || cols > _maxSize) {
      throw IllegalMove('size ${rows}x$cols');
    }
    final g = DotsGeometry.of(rows, cols);
    return DotsState(
      rows: rows,
      cols: cols,
      lines: List.filled(g.lineCount, false),
      owners: List.filled(g.boxCount, -1),
      toMove: 0,
      scores: List.filled(seats, 0),
    );
  }

  @override
  int toMove(DotsState state) => state.toMove;

  @override
  List<int> legalMoves(DotsState state) => [
    for (var i = 0; i < state.lines.length; i++)
      if (!state.lines[i]) i,
  ];

  @override
  DotsState apply(DotsState state, int move) {
    if (move < 0 || move >= state.lines.length || state.lines[move]) {
      throw IllegalMove('$move');
    }
    final lines = List<bool>.of(state.lines);
    lines[move] = true;
    final owners = List<int>.of(state.owners);
    final scores = List<int>.of(state.scores);
    final g = state.geometry;
    var closed = 0;
    for (final box in g.lineBoxes[move]) {
      if (g.boxSides[box].every((l) => lines[l])) {
        owners[box] = state.toMove;
        closed++;
      }
    }
    scores[state.toMove] += closed;
    return DotsState(
      rows: state.rows,
      cols: state.cols,
      lines: lines,
      owners: owners,
      toMove: closed > 0 ? state.toMove : (state.toMove + 1) % scores.length,
      scores: scores,
    );
  }

  @override
  TurnOutcome? outcome(DotsState state) {
    if (state.lines.contains(false)) return null;
    var best = state.scores[0];
    for (final s in state.scores) {
      if (s > best) best = s;
    }
    final leaders = state.scores.where((s) => s == best).length;
    if (leaders > 1) return const TurnOutcome(winner: null, reason: 'tie');
    return TurnOutcome(
      winner: state.scores.indexOf(best),
      reason: 'most-boxes',
    );
  }

  @override
  String encode(DotsState s) {
    final lines = s.lines.map((l) => l ? '1' : '0').join();
    final owners = s.owners.map((o) => o < 0 ? '.' : '$o').join();
    return '${s.rows}x${s.cols}|$lines|$owners|${s.toMove}|'
        '${s.scores.join(',')}';
  }

  @override
  DotsState decode(String raw) {
    Never bad() => throw FormatException('BAD_STATE', raw);
    final parts = raw.split('|');
    if (parts.length != 5) bad();
    final m = RegExp(r'^([1-9])x([1-9])$').firstMatch(parts[0]);
    if (m == null) bad();
    final rows = int.parse(m.group(1)!);
    final cols = int.parse(m.group(2)!);
    if (rows > _maxSize || cols > _maxSize) bad();
    final g = DotsGeometry.of(rows, cols);
    final l = parts[1];
    if (!RegExp(r'^[01]*$').hasMatch(l) || l.length != g.lineCount) bad();
    final scoreParts = parts[4].split(',');
    final seats = scoreParts.length;
    if (seats < 2 || seats > 4) bad();
    final o = parts[2];
    if (!RegExp(r'^[.0-3]*$').hasMatch(o) || o.length != g.boxCount) bad();
    final t = parts[3];
    if (!RegExp(r'^[0-3]$').hasMatch(t) || int.parse(t) >= seats) bad();
    final scores = <int>[];
    for (final x in scoreParts) {
      if (!RegExp(r'^(0|[1-9][0-9]*)$').hasMatch(x)) bad();
      scores.add(int.parse(x));
    }
    final state = DotsState(
      rows: rows,
      cols: cols,
      lines: [for (var i = 0; i < l.length; i++) l[i] == '1'],
      owners: [
        for (var i = 0; i < o.length; i++) o[i] == '.' ? -1 : int.parse(o[i]),
      ],
      toMove: int.parse(t),
      scores: scores,
    );
    // A box is owned exactly when it is closed, and scores are owner counts.
    final counted = List.filled(seats, 0);
    for (var b = 0; b < g.boxCount; b++) {
      final owner = state.owners[b];
      if (owner >= seats) bad();
      if ((owner >= 0) != (state.sidesDrawn(b) == 4)) bad();
      if (owner >= 0) counted[owner]++;
    }
    for (var i = 0; i < seats; i++) {
      if (counted[i] != scores[i]) bad();
    }
    return state;
  }

  @override
  String encodeMove(int move) => '$move';

  @override
  int decodeMove(String raw) {
    if (!RegExp(r'^(0|[1-9][0-9]*)$').hasMatch(raw)) {
      throw FormatException('BAD_MOVE', raw);
    }
    return int.parse(raw);
  }
}

const dotsRules = DotsRules();

// ── Evaluator ───────────────────────────────────────────────────────────────

/// A connected run of open boxes, as the endgame sees it.
class _Component {
  _Component(this.size, this.isLoop);

  final int size;
  final bool isLoop;
}

/// Open boxes grouped by the undrawn lines between them.
///
/// [include] picks the boxes that take part. A component is a loop when every
/// box in it has exactly two sides drawn and none of its undrawn lines is on
/// the border. Anything else — including a junction box with three or four
/// lines still open — is scored as one chain of its total size: an
/// approximation (opening a junction splits it), but a conservative one.
List<_Component> _components(
  DotsState s,
  List<int> sides,
  bool Function(int box) include,
) {
  final g = s.geometry;
  final seen = List.filled(g.boxCount, false);
  final out = <_Component>[];
  for (var start = 0; start < g.boxCount; start++) {
    if (seen[start] || !include(start)) continue;
    var size = 0;
    var allTwo = true;
    var ground = false;
    final stack = [start];
    seen[start] = true;
    while (stack.isNotEmpty) {
      final box = stack.removeLast();
      size++;
      if (sides[box] != 2) allTwo = false;
      for (final line in g.boxSides[box]) {
        if (s.lines[line]) continue;
        final touching = g.lineBoxes[line];
        if (touching.length == 1) ground = true;
        for (final other in touching) {
          if (other == box || seen[other]) continue;
          if (!include(other)) {
            ground = true;
            continue;
          }
          seen[other] = true;
          stack.add(other);
        }
      }
    }
    out.add(_Component(size, allTwo && !ground));
  }
  return out;
}

/// Loops negative, chains positive: one int names a component's kind.
int _kindKey(_Component c) => c.isLoop ? -c.size : c.size;

/// Memoised net score for the player who must open one of [comps] next, in a
/// position with no safe line and nothing to take, under the standard
/// simple-endgame play: the controller keeps control through every long
/// chain (giving back 2) and loop (giving back 4) when that pays, and takes
/// short chains outright.
final Map<String, int> _endgameCache = {};

int _endgameValue(List<_Component> unsorted) {
  if (unsorted.isEmpty) return 0;
  // Sorted so equal components sit together and the key is canonical.
  final comps = List.of(unsorted)
    ..sort((a, b) => _kindKey(a).compareTo(_kindKey(b)));
  final key = comps.map(_kindKey).join(',');
  final hit = _endgameCache[key];
  if (hit != null) return hit;
  int? best;
  int? last;
  for (var i = 0; i < comps.length; i++) {
    final c = comps[i];
    // Identical components are interchangeable; open one of each kind.
    final kind = _kindKey(c);
    if (kind == last) continue;
    final rest = [...comps.sublist(0, i), ...comps.sublist(i + 1)];
    final v = _endgameValue(rest);
    final n = c.size;
    final int takeAll = n + v;
    final int opener;
    if (c.isLoop) {
      opener = -(takeAll > n - 8 - v ? takeAll : n - 8 - v);
    } else if (n >= 3) {
      opener = -(takeAll > n - 4 - v ? takeAll : n - 4 - v);
    } else {
      opener = -takeAll;
    }
    if (best == null || opener > best) best = opener;
    last = kind;
  }
  if (_endgameCache.length > 50000) _endgameCache.clear();
  return _endgameCache[key] = best!;
}

/// Dots and Boxes evaluation, tuned for two players, in centi-boxes.
///
/// The score difference dominates (x100). On top of it:
///   - boxes the side to move can take right now, chased through the chain
///     they open — which is what makes handing over a third side cost what it
///     really costs, not a flat penalty;
///   - once no safe line is left, the chain endgame is valued exactly under
///     simple control play (long chains >= 3, loops) rather than guessed;
///   - before that, the long-chain rule: seat 0 wants dots + long chains even.
class DotsEvaluator extends TurnEvaluator<DotsState, int> {
  const DotsEvaluator();

  static const double box = 100;
  static const double parity = 40;

  @override
  double evaluate(DotsState state, int seat) {
    final result = dotsRules.outcome(state);
    if (result != null) {
      if (result.winner == null) return 0;
      return result.winner == seat
          ? TurnEvaluator.winScore
          : -TurnEvaluator.winScore;
    }
    var opp = -1;
    for (var i = 0; i < state.seats; i++) {
      if (i != seat && (opp < 0 || state.scores[i] > state.scores[opp])) {
        opp = i;
      }
    }
    final diff = state.scores[seat] - state.scores[opp];
    final sign = state.toMove == seat ? 1 : -1;
    final g = state.geometry;

    // Greedily take everything the mover can, on a scratch copy.
    final lines = List<bool>.of(state.lines);
    final sides = [for (var b = 0; b < g.boxCount; b++) state.sidesDrawn(b)];
    final open = [for (final o in state.owners) o < 0];
    var taken = 0;
    final queue = [
      for (var b = 0; b < g.boxCount; b++)
        if (open[b] && sides[b] == 3) b,
    ];
    while (queue.isNotEmpty) {
      final b = queue.removeLast();
      if (!open[b] || sides[b] != 3) continue;
      final line = g.boxSides[b].firstWhere((l) => !lines[l]);
      lines[line] = true;
      for (final other in g.lineBoxes[line]) {
        sides[other]++;
        if (sides[other] == 4) {
          open[other] = false;
          taken++;
        } else if (sides[other] == 3) {
          queue.add(other);
        }
      }
    }
    final after = DotsState(
      rows: state.rows,
      cols: state.cols,
      lines: lines,
      owners: [for (var b = 0; b < g.boxCount; b++) open[b] ? -1 : 0],
      toMove: state.toMove,
      scores: state.scores,
    );

    var safe = false;
    var remaining = false;
    for (var l = 0; l < lines.length && !safe; l++) {
      if (lines[l]) continue;
      remaining = true;
      if (g.lineBoxes[l].every((b) => sides[b] < 2)) safe = true;
    }
    if (!remaining) return (diff + sign * taken) * box;

    if (state.seats == 2 && !safe) {
      final v = _endgameValue(_components(after, sides, (b) => open[b]));
      // Having taken a long run, the mover may instead hand the last two
      // back and keep control.
      final keep = taken >= 3 ? taken - 4 - v : taken + v;
      final moverNet = taken + v > keep ? taken + v : keep;
      return (diff + sign * moverNet) * box;
    }

    var score = (diff + sign * taken) * box;
    if (state.seats == 2) {
      final longChains = _components(
        after,
        sides,
        (b) => open[b] && sides[b] == 2,
      ).where((c) => !c.isLoop && c.size >= 3).length;
      final dots = (state.rows + 1) * (state.cols + 1);
      final favoured = (dots + longChains).isEven ? 0 : 1;
      score += favoured == seat ? parity : -parity;
    }
    return score;
  }

  /// Box-closing lines first (doubles before singles), then safe lines, then
  /// sacrifices, smallest chain handed over first. Ties keep line order.
  @override
  List<int> order(DotsState state, List<int> moves) {
    final g = state.geometry;
    final sides = [for (var b = 0; b < g.boxCount; b++) state.sidesDrawn(b)];
    final open = [for (final o in state.owners) o < 0];
    // Chain sizes over boxes already at two sides, which is what a third
    // side would open up.
    final chainOf = List.filled(g.boxCount, -1);
    final chainSize = <int>[];
    for (var start = 0; start < g.boxCount; start++) {
      if (chainOf[start] >= 0 || !open[start] || sides[start] != 2) continue;
      final id = chainSize.length;
      var size = 0;
      final stack = [start];
      chainOf[start] = id;
      while (stack.isNotEmpty) {
        final b = stack.removeLast();
        size++;
        for (final line in g.boxSides[b]) {
          if (state.lines[line]) continue;
          for (final other in g.lineBoxes[line]) {
            if (chainOf[other] >= 0 || !open[other] || sides[other] != 2) {
              continue;
            }
            chainOf[other] = id;
            stack.add(other);
          }
        }
      }
      chainSize.add(size);
    }

    int rank(int line) {
      var closes = 0;
      var given = 0;
      final chains = <int>{};
      for (final b in g.lineBoxes[line]) {
        if (sides[b] == 3) closes++;
        if (sides[b] == 2 && chainOf[b] >= 0 && chains.add(chainOf[b])) {
          given += chainSize[chainOf[b]];
        }
      }
      if (closes > 0) return 1000 + closes;
      if (given == 0) return 500;
      return -given;
    }

    final ranks = [for (final m in moves) rank(m)];
    final indexed = [for (var i = 0; i < moves.length; i++) i];
    indexed.sort((a, b) {
      final byRank = ranks[b].compareTo(ranks[a]);
      return byRank != 0 ? byRank : a.compareTo(b);
    });
    return [for (final i in indexed) moves[i]];
  }
}

const dotsEvaluator = DotsEvaluator();
