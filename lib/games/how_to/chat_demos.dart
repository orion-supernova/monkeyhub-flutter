import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import '../../models/daily_game.dart';
import '../../party_games/dice.dart';
import '../../theme/theme_preference.dart';
import '../../turn_games/board/board_kit.dart';
import '../../turn_games/board/checkers_board.dart';
import '../../turn_games/board/chess_board.dart';
import '../../turn_games/board/connect_four_board.dart';
import '../../turn_games/board/dots_board.dart';
import '../../turn_games/board/reversi_board.dart';
import '../../turn_games/board/seat_palette.dart';
import '../../turn_games/board/tic_tac_toe_board.dart';
import '../../turn_games/chess.dart';
import '../../turn_games/dots.dart';
import '../game_canvas.dart';
import '../game_rules.dart';
import '../queens_board_art.dart';
import 'demo_kit.dart';

// The chat games' demos, and the two play modes'. The board games are drawn
// by their real painters (the same ones the match screen uses), driven by a
// clock that follows the demo's loop instead of a ticker; the party games and
// the modes are drawn here, from the same parts (the real dice, the seat
// colours).

/// A board painter's clock for a move made at loop time [at]: its own
/// millisecond animations then play at true speed, and are finished once
/// [total] has passed.
BoardClock _since(DemoFrame f, double at, [double total = 1000]) {
  final ms = (f.t - at) * f.periodMs;
  if (ms <= 0) return const BoardClock(AlwaysStoppedAnimation(0), 1000);
  if (ms >= total) return const BoardClock(null, 0);
  return BoardClock(AlwaysStoppedAnimation(ms / total), total);
}

/// The most recent of [times] the loop has passed, or null.
int? _last(DemoFrame f, List<double> times) {
  int? last;
  for (var i = 0; i < times.length; i++) {
    if (f.t >= times[i]) last = i;
  }
  return last;
}

/// A centred square of [fraction] of the stage, and a way to paint into it.
class _Square {
  _Square(DemoFrame f, {double fraction = 0.86, double dy = 0})
    : side = f.side * fraction,
      origin = Offset(
        (f.size.width - f.side * fraction) / 2,
        (f.size.height - f.side * fraction) / 2 + dy * f.side,
      );

  final double side;
  final Offset origin;

  Size get size => Size.square(side);
  Offset get center => origin + Offset(side / 2, side / 2);

  void draw(Canvas canvas, CustomPainter painter) {
    canvas.save();
    canvas.translate(origin.dx, origin.dy);
    painter.paint(canvas, size);
    canvas.restore();
  }
}

TextPainter _label(
  DemoFrame f,
  String text,
  double size,
  Color color, {
  FontWeight weight = FontWeight.w700,
}) => TextPainter(
  text: TextSpan(
    text: text,
    style: f.theme.body.copyWith(
      fontSize: size,
      fontWeight: weight,
      color: color,
      height: 1,
      letterSpacing: 0,
      fontFeatures: const [FontFeature.tabularFigures()],
    ),
  ),
  textDirection: TextDirection.ltr,
)..layout();

void _text(Canvas canvas, TextPainter tp, Offset center) =>
    tp.paint(canvas, center - Offset(tp.width / 2, tp.height / 2));

/// A player: a coloured disc with a simple face, dimmed when [away].
void _avatar(
  Canvas canvas,
  DemoFrame f,
  Offset c,
  double r,
  int seat, {
  double away = 0,
  double ring = 0,
  Color? ringColor,
}) {
  final seats = SeatPalette(f.theme);
  final alpha = 1 - 0.65 * away;
  canvas.drawCircle(
    c,
    r,
    Paint()..color = seats.fill(seat).withValues(alpha: alpha),
  );
  final ink = seats.ink(seat).withValues(alpha: 0.9 * alpha);
  final eye = Paint()..color = ink;
  canvas.drawCircle(c + Offset(-r * 0.3, -r * 0.12), r * 0.11, eye);
  canvas.drawCircle(c + Offset(r * 0.3, -r * 0.12), r * 0.11, eye);
  canvas.drawArc(
    Rect.fromCircle(center: c + Offset(0, r * 0.08), radius: r * 0.36),
    0.35,
    math.pi - 0.7,
    false,
    Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = r * 0.1
      ..strokeCap = StrokeCap.round
      ..color = ink,
  );
  if (ring > 0) {
    canvas.drawArc(
      Rect.fromCircle(center: c, radius: r * 1.22),
      -math.pi / 2,
      math.pi * 2 * ring,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = r * 0.16
        ..strokeCap = StrokeCap.round
        ..color = ringColor ?? f.theme.success,
    );
  }
}

/// A small round badge with a tick, for "ready" and "done".
void _tick(Canvas canvas, Offset c, double r, Color color, double p) {
  if (p <= 0) return;
  final s = Curves.easeOutBack.transform(p.clamp(0.0, 1.0));
  canvas.drawCircle(c, r * s, Paint()..color = color);
  final path = Path()
    ..moveTo(c.dx - r * 0.45 * s, c.dy)
    ..lineTo(c.dx - r * 0.1 * s, c.dy + r * 0.35 * s)
    ..lineTo(c.dx + r * 0.5 * s, c.dy - r * 0.35 * s);
  canvas.drawPath(
    path,
    Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = r * 0.28
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..color = const Color(0xFFFFFFFF),
  );
}

/// A speech bubble with a couple of "words" in it (rounded bars).
void _bubble(
  Canvas canvas,
  Rect rect,
  Color fill,
  Color ink,
  double p, {
  int bars = 2,
  bool tailDown = true,
}) {
  if (p <= 0) return;
  final s = Curves.easeOutBack.transform(p.clamp(0.0, 1.0));
  canvas.save();
  final anchor = tailDown ? rect.bottomCenter : rect.topCenter;
  canvas.translate(anchor.dx, anchor.dy);
  canvas.scale(s);
  canvas.translate(-anchor.dx, -anchor.dy);
  final r = RRect.fromRectAndRadius(rect, Radius.circular(rect.height * 0.42));
  canvas.drawRRect(r, Paint()..color = fill);
  final tail = Path();
  if (tailDown) {
    tail
      ..moveTo(rect.center.dx - rect.height * 0.18, rect.bottom - 1)
      ..lineTo(rect.center.dx, rect.bottom + rect.height * 0.28)
      ..lineTo(rect.center.dx + rect.height * 0.18, rect.bottom - 1);
  } else {
    tail
      ..moveTo(rect.center.dx - rect.height * 0.18, rect.top + 1)
      ..lineTo(rect.center.dx, rect.top - rect.height * 0.28)
      ..lineTo(rect.center.dx + rect.height * 0.18, rect.top + 1);
  }
  canvas.drawPath(tail, Paint()..color = fill);
  final bar = Paint()..color = ink;
  final h = rect.height * 0.16;
  final inner = rect.deflate(rect.height * 0.28);
  for (var i = 0; i < bars; i++) {
    final w = inner.width * (i == bars - 1 ? 0.55 : 1);
    final y = bars == 1
        ? inner.center.dy
        : inner.top + inner.height * i / (bars - 1);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(inner.left, y - h / 2, w, h),
        Radius.circular(h / 2),
      ),
      bar,
    );
  }
  canvas.restore();
}

// ── Tic-tac-toe ─────────────────────────────────────────────────────────────

void _ttt(
  Canvas canvas,
  DemoFrame f,
  _Square b,
  List<int> start,
  List<(double, int, int)> moves, {
  List<int>? win,
}) {
  final cells = [...start];
  int? fresh;
  double freshAt = 0;
  for (final (t, cell, seat) in moves) {
    if (!f.at(t)) continue;
    cells[cell] = seat + 1;
    fresh = cell;
    freshAt = t;
  }
  final done = win != null && moves.every((m) => f.at(m.$1));
  b.draw(
    canvas,
    TicTacToePainter(
      cells: cells,
      seats: SeatPalette(f.theme, gameId: 'tictactoe'),
      ink: f.theme.ink,
      clock: _since(f, freshAt),
      fresh: fresh,
      winLine: done ? win : null,
    ),
  );
}

Offset _tttCell(_Square b, int i) =>
    b.origin + Offset((i % 3 + 0.5) * b.side / 3, (i ~/ 3 + 0.5) * b.side / 3);

/// You (X) and them (O) take turns; X gets the top row and it's struck out.
class TicTacToeRulesDemo extends HowToDemo {
  const TicTacToeRulesDemo();

  static const _moves = <(double, int, int)>[
    (0.1, 0, 0),
    (0.22, 4, 1),
    (0.34, 1, 0),
    (0.46, 6, 1),
    (0.58, 2, 0),
  ];

  @override
  void paint(Canvas canvas, DemoFrame f) {
    final b = _Square(f, fraction: 0.8);
    _ttt(canvas, f, b, List.filled(9, 0), _moves, win: const [0, 1, 2]);
    paintFinger(canvas, f, [
      for (final (t, cell, seat) in _moves)
        if (seat == 0) FingerKey(t, _tttCell(b, cell), tap: true),
    ]);
    paintSparkles(canvas, b.center, b.side * 0.45, f.seg(0.64, 0.9, Curves.linear), f.theme.accent);
  }
}

/// They have two in a row; you take the third square first.
class TicTacToeBlockDemo extends HowToDemo {
  const TicTacToeBlockDemo();

  @override
  void paint(Canvas canvas, DemoFrame f) {
    final b = _Square(f, fraction: 0.8);
    // O on 3 and 4, X on 0 and 8: O threatens 5.
    _ttt(canvas, f, b, const [1, 0, 0, 2, 2, 0, 0, 0, 1], const [(0.48, 5, 0)]);
    final warn = f.seg(0.08, 0.16) * (1 - f.seg(0.44, 0.5));
    final row = Rect.fromLTWH(b.origin.dx, b.origin.dy + b.side / 3, b.side, b.side / 3).deflate(4);
    paintSpotlight(canvas, row, f.theme.danger, warn, radius: 14);
    paintFinger(canvas, f, [FingerKey(0.48, _tttCell(b, 5), tap: true)]);
    paintSparkles(canvas, _tttCell(b, 5), b.side * 0.2, f.seg(0.5, 0.7), f.theme.accent);
  }
}

// ── Connect Four ────────────────────────────────────────────────────────────

class _C4 {
  _C4(DemoFrame f) {
    final w = f.side * 0.92;
    final h = w * 6 / 7;
    origin = Offset((f.size.width - w) / 2, (f.size.height - h) / 2 + f.side * 0.04);
    size = Size(w, h);
    g = ConnectFourGeometry(size, lane: false);
  }

  late final Offset origin;
  late final Size size;
  late final ConnectFourGeometry g;

  Offset hole(int row, int col) => origin + g.hole(row, col);
  Offset above(int col) => origin + Offset((col + 0.5) * g.cell, -g.cell * 0.55);

  void draw(Canvas canvas, CustomPainter p) {
    canvas.save();
    canvas.translate(origin.dx, origin.dy);
    p.paint(canvas, size);
    canvas.restore();
  }
}

void _c4(
  Canvas canvas,
  DemoFrame f,
  _C4 b,
  Map<int, int> start,
  List<(double, int, int)> drops, {
  List<int>? win,
}) {
  final cells = List<int>.filled(42, 0);
  start.forEach((i, seat) => cells[i] = seat + 1);
  int? fresh;
  double at = 0;
  for (final (t, col, seat) in drops) {
    if (!f.at(t)) continue;
    var row = 5;
    while (row > 0 && cells[row * 7 + col] != 0) {
      row--;
    }
    cells[row * 7 + col] = seat + 1;
    fresh = row * 7 + col;
    at = t;
  }
  final done = win != null && drops.every((d) => f.at(d.$1));
  b.draw(
    canvas,
    ConnectFourPainter(
      cells: cells,
      seats: SeatPalette(f.theme, gameId: 'connectfour'),
      theme: f.theme,
      lane: false,
      clock: _since(f, at, 1200),
      fresh: fresh,
      winning: done ? win : null,
    ),
  );
}

/// Tap a column; the disc drops to the bottom. Twice more, one each.
class ConnectFourDropDemo extends HowToDemo {
  const ConnectFourDropDemo();

  static const _drops = <(double, int, int)>[
    (0.14, 3, 0),
    (0.4, 3, 1),
    (0.64, 4, 0),
  ];

  @override
  void paint(Canvas canvas, DemoFrame f) {
    final b = _C4(f);
    _c4(canvas, f, b, const {}, _drops);
    paintFinger(canvas, f, [
      FingerKey(0.14, b.above(3), tap: true),
      FingerKey(0.64, b.above(4), tap: true),
    ]);
  }
}

/// The fourth disc completes a diagonal; the four light up.
class ConnectFourWinDemo extends HowToDemo {
  const ConnectFourWinDemo();

  static const _start = {
    35: 0, //
    36: 1, 29: 0, //
    37: 1, 30: 1, 23: 0, //
    38: 0, 31: 1, 24: 1, //
    39: 1,
  };

  @override
  void paint(Canvas canvas, DemoFrame f) {
    final b = _C4(f);
    _c4(canvas, f, b, _start, const [(0.3, 3, 0)], win: const [35, 29, 23, 17]);
    paintFinger(canvas, f, [FingerKey(0.3, b.above(3), tap: true)]);
    paintSparkles(canvas, b.hole(2, 3), f.side * 0.3, f.seg(0.42, 0.66), f.theme.accent);
  }

  @override
  double get still => 0.7;
}

/// Tip: the middle column. Each hole glows by how many fours run through it,
/// the middle burns brightest, and that is where the disc goes.
class ConnectFourTipDemo extends HowToDemo {
  const ConnectFourTipDemo();

  /// Fours through each hole, row by row: the classic count, highest in the
  /// middle column.
  static const _fours = [
    3, 4, 5, 7, 5, 4, 3, //
    4, 6, 8, 10, 8, 6, 4, //
    5, 8, 11, 13, 11, 8, 5, //
    5, 8, 11, 13, 11, 8, 5, //
    4, 6, 8, 10, 8, 6, 4, //
    3, 4, 5, 7, 5, 4, 3, //
  ];

  @override
  void paint(Canvas canvas, DemoFrame f) {
    final b = _C4(f);
    _c4(canvas, f, b, const {}, const [(0.6, 3, 0)]);
    // The heat rises column by column from the edges in, so the eye ends on
    // the middle; it fades once the disc has gone there.
    final fade = 1 - f.seg(0.78, 0.9);
    final glow = Paint();
    for (var i = 0; i < 42; i++) {
      final col = i % 7;
      final edge = (col - 3).abs();
      final p = f.seg(0.06 + (3 - edge) * 0.07, 0.2 + (3 - edge) * 0.07);
      if (p <= 0) continue;
      final row = i ~/ 7;
      if (f.at(0.6) && row == 5 && col == 3) continue;
      glow.color = f.theme.accent.withValues(alpha: 0.75 * p * fade * _fours[i] / 13);
      canvas.drawCircle(b.hole(row, col), b.g.holeRadius * 0.86, glow);
    }
    final column = Rect.fromLTWH(
      b.origin.dx + 3 * b.g.cell,
      b.origin.dy,
      b.g.cell,
      b.g.cell * 6,
    ).inflate(2);
    paintSpotlight(canvas, column, f.theme.accent, f.seg(0.38, 0.46) * fade, radius: b.g.cell * 0.3);
    paintFinger(canvas, f, [FingerKey(0.6, b.above(3), tap: true)]);
    paintSparkles(canvas, b.hole(5, 3), f.side * 0.22, f.seg(0.66, 0.86), f.theme.accent);
  }

  @override
  double get still => 0.5;
}

// ── Checkers ────────────────────────────────────────────────────────────────

const _darkMan = 1;
const _darkKing = 2;
const _lightMan = 3;

/// Checkers on the real painter, dark at the bottom moving up.
void _checkers(
  Canvas canvas,
  DemoFrame f,
  _Square b, {
  required Map<int, int> before,
  required Map<int, int> after,
  required double moveAt,
  required List<int> path,
  required List<(int, int)> captured,
  required int piece,
  Set<int> capturers = const {},
  Set<int> targets = const {},
  double selectAt = -1,
}) {
  final moved = f.at(moveAt);
  final board = List<int>.filled(32, 0);
  (moved ? after : before).forEach((sq, p) => board[sq] = p);
  final selecting = !moved && selectAt >= 0 && f.at(selectAt);
  final hops = math.max(1, path.length - 1);
  b.draw(
    canvas,
    CheckersPainter(
      board: board,
      seats: SeatPalette(f.theme, gameId: 'checkers'),
      theme: f.theme,
      flipped: true,
      clock: _since(f, moveAt, 180.0 * hops + 120),
      anim: moved
          ? CheckersAnimation(piece: piece, path: path, captured: captured)
          : null,
      path: selecting ? [path.first] : const [],
      targets: selecting ? targets : const {},
      capturers: !moved ? capturers : const {},
      last: moved ? path : null,
    ),
  );
}

Offset _checkersAt(_Square b, int sq) =>
    b.origin + CheckersGeometry(b.size, flipped: true).center(sq);

/// Tap a man, see where it can go, tap one: it steps forward.
class CheckersMoveDemo extends HowToDemo {
  const CheckersMoveDemo();

  static const _pieces = {9: _darkMan, 10: _darkMan, 5: _darkMan, 21: _lightMan, 22: _lightMan, 26: _lightMan};

  @override
  void paint(Canvas canvas, DemoFrame f) {
    final b = _Square(f, fraction: 0.88);
    _checkers(
      canvas,
      f,
      b,
      before: _pieces,
      after: {..._pieces}
        ..remove(9)
        ..[14] = _darkMan,
      selectAt: 0.16,
      moveAt: 0.46,
      path: const [9, 14],
      captured: const [],
      piece: _darkMan,
      targets: const {13, 14},
    );
    paintFinger(canvas, f, [
      FingerKey(0.16, _checkersAt(b, 9), tap: true),
      FingerKey(0.46, _checkersAt(b, 14), tap: true),
    ]);
  }

  @override
  double get still => 0.35;
}

/// A capture is on, so it's ringed (you must take it); the man jumps.
class CheckersJumpDemo extends HowToDemo {
  const CheckersJumpDemo();

  static const _pieces = {13: _darkMan, 6: _darkMan, 17: _lightMan, 26: _lightMan, 27: _lightMan};

  @override
  void paint(Canvas canvas, DemoFrame f) {
    final b = _Square(f, fraction: 0.88);
    _checkers(
      canvas,
      f,
      b,
      before: _pieces,
      after: {..._pieces}
        ..remove(13)
        ..remove(17)
        ..[22] = _darkMan,
      capturers: const {13},
      selectAt: 0.3,
      moveAt: 0.52,
      path: const [13, 22],
      captured: const [(17, _lightMan)],
      piece: _darkMan,
      targets: const {22},
    );
    paintFinger(canvas, f, [
      FingerKey(0.3, _checkersAt(b, 13), tap: true),
      FingerKey(0.52, _checkersAt(b, 22), tap: true),
    ]);
  }

  @override
  double get still => 0.25;
}

/// One move, two jumps, two pieces gone.
class CheckersMultiDemo extends HowToDemo {
  const CheckersMultiDemo();

  static const _pieces = {9: _darkMan, 13: _lightMan, 21: _lightMan, 30: _lightMan};

  @override
  void paint(Canvas canvas, DemoFrame f) {
    final b = _Square(f, fraction: 0.88);
    _checkers(
      canvas,
      f,
      b,
      before: _pieces,
      after: {..._pieces}
        ..remove(9)
        ..remove(13)
        ..remove(21)
        ..[25] = _darkMan,
      capturers: const {9},
      selectAt: 0.2,
      moveAt: 0.42,
      path: const [9, 16, 25],
      captured: const [(13, _lightMan), (21, _lightMan)],
      piece: _darkMan,
      targets: const {16},
    );
    paintFinger(canvas, f, [
      FingerKey(0.2, _checkersAt(b, 9), tap: true),
      FingerKey(0.36, _checkersAt(b, 16)),
      FingerKey(0.42, _checkersAt(b, 25), tap: true),
    ]);
    paintSparkles(canvas, _checkersAt(b, 25), b.side * 0.2, f.seg(0.5, 0.7), f.theme.accent);
  }
}

/// A man reaches the far row and is crowned; then the king steps back.
class CheckersKingDemo extends HowToDemo {
  const CheckersKingDemo();

  static const _pieces = {25: _darkMan, 14: _lightMan, 10: _darkMan};

  @override
  void paint(Canvas canvas, DemoFrame f) {
    final b = _Square(f, fraction: 0.88);
    final second = f.at(0.62);
    final crowned = {..._pieces}
      ..remove(25)
      ..[29] = _darkKing;
    _checkers(
      canvas,
      f,
      b,
      before: second ? crowned : _pieces,
      after: second
          ? ({...crowned}
              ..remove(29)
              ..[24] = _darkKing)
          : crowned,
      moveAt: second ? 0.62 : 0.24,
      path: second ? const [29, 24] : const [25, 29],
      captured: const [],
      piece: second ? _darkKing : _darkMan,
    );
    paintFinger(canvas, f, [
      FingerKey(0.16, _checkersAt(b, 25), tap: true),
      FingerKey(0.24, _checkersAt(b, 29), tap: true),
      FingerKey(0.54, _checkersAt(b, 29), tap: true),
      FingerKey(0.62, _checkersAt(b, 24), tap: true),
    ]);
    paintSparkles(canvas, _checkersAt(b, 29), b.side * 0.22, f.seg(0.3, 0.52), const Color(0xFFFFC53D));
  }

  @override
  double get still => 0.45;
}

/// Tip: a rival man reaches your back row's doorstep and finds its crowning
/// square taken by a man who never left home.
class CheckersTipDemo extends HowToDemo {
  const CheckersTipDemo();

  // Dark's back row (0 to 3) all home, a light man two rows short of it on
  // the edge. From 4 its only way down is 0, and no dark man can jump it
  // there: the landing square would be off the board.
  static const _pieces = {
    0: _darkMan, 1: _darkMan, 2: _darkMan, 3: _darkMan, //
    14: _darkMan, 8: _lightMan, 26: _lightMan, 27: _lightMan,
  };

  @override
  void paint(Canvas canvas, DemoFrame f) {
    final b = _Square(f, fraction: 0.88);
    _checkers(
      canvas,
      f,
      b,
      before: _pieces,
      after: {..._pieces}
        ..remove(8)
        ..[4] = _lightMan,
      moveAt: 0.2,
      path: const [8, 4],
      captured: const [],
      piece: _lightMan,
    );
    final geo = CheckersGeometry(b.size, flipped: true);
    Rect at(int sq) => geo.square(sq).shift(b.origin).deflate(2);
    // Where it wants to land: taken. Then the row that holds it.
    final blocked = f.seg(0.36, 0.44) * (1 - f.seg(0.58, 0.64));
    paintSpotlight(canvas, at(0), f.theme.danger, blocked, radius: 6);
    final home = at(0).expandToInclude(at(3)).inflate(2);
    paintSpotlight(canvas, home, f.theme.accent, f.seg(0.64, 0.72) * (1 - f.seg(0.88, 0.94)), radius: 8);
    paintSparkles(canvas, home.center, b.side * 0.3, f.seg(0.66, 0.88), f.theme.accent);
  }

  @override
  double get still => 0.42;
}

// ── Reversi ─────────────────────────────────────────────────────────────────

void _reversi(
  Canvas canvas,
  DemoFrame f,
  _Square b,
  Map<int, int> start, {
  required double at,
  required int placed,
  required Map<int, int> flips,
  List<int> hints = const [],
}) {
  final cells = List<int>.filled(64, 0);
  start.forEach((i, seat) => cells[i] = seat + 1);
  final done = f.at(at);
  if (done) {
    cells[placed] = 1;
    for (final i in flips.keys) {
      cells[i] = 1;
    }
  }
  b.draw(
    canvas,
    ReversiPainter(
      cells: cells,
      seats: SeatPalette(f.theme, gameId: 'reversi'),
      theme: f.theme,
      clock: _since(f, at, 900),
      hints: done ? const [] : hints,
      placed: done ? placed : null,
      flips: done ? flips : const {},
      last: done ? placed : null,
    ),
  );
}

Offset _cell8(_Square b, int i) =>
    b.origin + Offset((i % 8 + 0.5) * b.side / 8, (i ~/ 8 + 0.5) * b.side / 8);

/// The opening: legal squares show, black plays one, a white disc flips.
class ReversiTrapDemo extends HowToDemo {
  const ReversiTrapDemo();

  @override
  void paint(Canvas canvas, DemoFrame f) {
    final b = _Square(f, fraction: 0.88);
    _reversi(
      canvas,
      f,
      b,
      const {27: 1, 28: 0, 35: 0, 36: 1},
      at: 0.42,
      placed: 19,
      flips: const {27: 1},
      hints: f.at(0.1) ? const [19, 26, 37, 44] : const [],
    );
    paintFinger(canvas, f, [FingerKey(0.42, _cell8(b, 19), tap: true)]);
  }

  @override
  double get still => 0.3;
}

/// One disc traps lines in three directions at once.
class ReversiFlipDemo extends HowToDemo {
  const ReversiFlipDemo();

  @override
  void paint(Canvas canvas, DemoFrame f) {
    final b = _Square(f, fraction: 0.88);
    _reversi(
      canvas,
      f,
      b,
      const {29: 0, 42: 0, 44: 0, 27: 1, 28: 1, 34: 1, 35: 1},
      at: 0.3,
      placed: 26,
      flips: const {27: 1, 28: 2, 34: 1, 35: 1},
    );
    paintFinger(canvas, f, [FingerKey(0.3, _cell8(b, 26), tap: true)]);
    paintSparkles(canvas, _cell8(b, 26), b.side * 0.3, f.seg(0.4, 0.62), f.theme.accent);
  }
}

/// The board fills; the counts are totted up and the bigger pile wins.
class ReversiCountDemo extends HowToDemo {
  const ReversiCountDemo();

  static final _final = () {
    final rng = mulberry32(7);
    return [for (var i = 0; i < 64; i++) rng() < 0.58 ? 1 : 2];
  }();

  @override
  void paint(Canvas canvas, DemoFrame f) {
    final b = _Square(f, fraction: 0.8, dy: -0.05);
    final shown = (64 * f.seg(0.05, 0.5, Curves.linear)).round();
    final cells = [for (var i = 0; i < 64; i++) i < shown ? _final[i] : 0];
    b.draw(
      canvas,
      ReversiPainter(
        cells: cells,
        seats: SeatPalette(f.theme, gameId: 'reversi'),
        theme: f.theme,
        clock: const BoardClock(null, 0),
      ),
    );
    final black = cells.where((c) => c == 1).length;
    final white = cells.where((c) => c == 2).length;
    final y = b.origin.dy + b.side + f.side * 0.06;
    final seats = SeatPalette(f.theme, gameId: 'reversi');
    for (final (seat, n, x) in [(0, black, 0.32), (1, white, 0.68)]) {
      final c = Offset(f.size.width * x, y);
      canvas.drawCircle(c - Offset(f.side * 0.06, 0), f.side * 0.03, Paint()..color = seats.fill(seat));
      canvas.drawCircle(
        c - Offset(f.side * 0.06, 0),
        f.side * 0.03,
        Paint()
          ..style = PaintingStyle.stroke
          ..color = seats.rim(seat),
      );
      _text(canvas, _label(f, '$n', f.side * 0.06, f.theme.ink), c + Offset(f.side * 0.03, 0));
    }
    if (f.at(0.55)) {
      final win = f.seg(0.55, 0.65);
      paintSpotlight(
        canvas,
        Rect.fromCenter(center: Offset(f.size.width * 0.32, y), width: f.side * 0.24, height: f.side * 0.1),
        f.theme.success,
        win,
        radius: 999,
      );
      paintSparkles(canvas, Offset(f.size.width * 0.32, y), f.side * 0.16, f.seg(0.58, 0.8), f.theme.success, count: 6);
    }
  }
}

/// Tip: you take a corner, they flip the disc beside it straight back, and
/// the corner stays yours.
class ReversiTipDemo extends HowToDemo {
  const ReversiTipDemo();

  // Black (1) takes the corner a1 at 0, trapping white's 9 against 18; white
  // (2) answers on 8, trapping 9 against 10. Nothing can trap 0.
  static const _start = {9: 2, 10: 2, 18: 1, 27: 2, 28: 1, 35: 1, 36: 2};

  @override
  void paint(Canvas canvas, DemoFrame f) {
    final b = _Square(f, fraction: 0.88);
    const first = 0.22;
    const second = 0.5;
    final cells = List<int>.filled(64, 0);
    _start.forEach((i, v) => cells[i] = v);
    int? placed;
    var flips = const <int, int>{};
    var at = 0.0;
    if (f.at(first)) {
      cells[0] = 1;
      cells[9] = 1;
      placed = 0;
      flips = const {9: 1};
      at = first;
    }
    if (f.at(second)) {
      cells[8] = 2;
      cells[9] = 2;
      placed = 8;
      flips = const {9: 1};
      at = second;
    }
    b.draw(
      canvas,
      ReversiPainter(
        cells: cells,
        seats: SeatPalette(f.theme, gameId: 'reversi'),
        theme: f.theme,
        clock: _since(f, at, 900),
        placed: placed,
        flips: flips,
        last: placed,
      ),
    );
    paintFinger(canvas, f, [FingerKey(first, _cell8(b, 0), tap: true)]);
    final cell = b.side / 8;
    final corner = Rect.fromLTWH(b.origin.dx, b.origin.dy, cell, cell).deflate(2);
    paintSpotlight(canvas, corner, f.theme.success, f.seg(0.66, 0.74) * (1 - f.seg(0.88, 0.94)), radius: 8);
    paintSparkles(canvas, corner.center, b.side * 0.18, f.seg(0.68, 0.88), f.theme.success);
  }

  @override
  double get still => 0.72;
}

// ── Dots and Boxes ──────────────────────────────────────────────────────────

const _dr = 3;
const _dc = 3;
int _h(int r, int c) => r * _dc + c;
int _v(int r, int c) => (_dr + 1) * _dc + r * (_dc + 1) + c;
final _dotsGlyphs = DotsGlyphs();

List<int> _sidesOf(int box) {
  final r = box ~/ _dc;
  final c = box % _dc;
  return [_h(r, c), _h(r + 1, c), _v(r, c), _v(r, c + 1)];
}

/// Plays [moves] (time, line, seat) on a 3×3 board, scoring closed boxes.
void _dots(
  Canvas canvas,
  DemoFrame f,
  List<(int, int)> start,
  List<(double, int, int)> moves,
) {
  final lines = List<bool>.filled((_dr + 1) * _dc + _dr * (_dc + 1), false);
  final owners = List<int>.filled(_dr * _dc, -1);
  final scores = [0, 0];
  for (final (line, _) in start) {
    lines[line] = true;
  }
  int? fresh;
  int? freshSeat;
  var freshBoxes = <int>{};
  double at = 0;
  for (final (t, line, seat) in moves) {
    if (!f.at(t)) continue;
    lines[line] = true;
    fresh = line;
    freshSeat = seat;
    at = t;
    freshBoxes = {};
    for (var box = 0; box < owners.length; box++) {
      if (owners[box] < 0 && _sidesOf(box).every((l) => lines[l])) {
        owners[box] = seat;
        scores[seat]++;
        freshBoxes.add(box);
      }
    }
  }
  final b = _Square(f, fraction: 0.92);
  b.draw(
    canvas,
    DotsPainter(
      state: DotsState(
        rows: _dr,
        cols: _dc,
        lines: lines,
        owners: owners,
        toMove: 0,
        scores: scores,
      ),
      seats: SeatPalette(f.theme, gameId: 'dots'),
      theme: f.theme,
      labels: const ['A', 'B'],
      glyphs: _dotsGlyphs,
      clock: _since(f, at, 600),
      fresh: fresh,
      freshSeat: freshSeat,
      freshBoxes: freshBoxes,
      animateFresh: true,
    ),
  );
}

Offset _lineMid(DemoFrame f, int line) {
  final b = _Square(f, fraction: 0.92);
  final (a, c) = DotsLayout(b.size, _dr, _dc).line(line);
  return b.origin + Offset.lerp(a, c, 0.5)!;
}

/// Lines go down, one each.
class DotsLinesDemo extends HowToDemo {
  const DotsLinesDemo();

  static final _moves = <(double, int, int)>[
    (0.1, _h(0, 0), 0),
    (0.24, _v(1, 2), 1),
    (0.38, _h(2, 1), 0),
    (0.52, _v(0, 3), 1),
    (0.66, _h(3, 2), 0),
  ];

  @override
  void paint(Canvas canvas, DemoFrame f) {
    _dots(canvas, f, const [], _moves);
    paintFinger(canvas, f, [
      for (final (t, line, seat) in _moves)
        if (seat == 0) FingerKey(t, _lineMid(f, line), tap: true),
    ]);
  }
}

/// The fourth side closes a box: it's yours, and you go again and close
/// another.
class DotsBoxDemo extends HowToDemo {
  const DotsBoxDemo();

  static final _start = [
    (_h(0, 0), 0),
    (_v(0, 0), 1),
    (_v(0, 1), 0),
    (_h(0, 1), 1),
    (_v(0, 2), 0),
    (_v(1, 0), 1),
  ];

  @override
  void paint(Canvas canvas, DemoFrame f) {
    _dots(canvas, f, _start, [(0.26, _h(1, 0), 0), (0.56, _h(1, 1), 0)]);
    paintFinger(canvas, f, [
      FingerKey(0.26, _lineMid(f, _h(1, 0)), tap: true),
      FingerKey(0.56, _lineMid(f, _h(1, 1)), tap: true),
    ]);
    final seat = SeatPalette(f.theme, gameId: 'dots').fill(0);
    paintFloatLabel(canvas, f, _lineMid(f, _h(1, 0)) - Offset(0, f.side * 0.2), '+1', f.seg(0.3, 0.6, Curves.linear), seat);
    paintFloatLabel(canvas, f, _lineMid(f, _h(1, 1)) - Offset(0, f.side * 0.2), '+1', f.seg(0.6, 0.9, Curves.linear), seat);
  }
}

/// Tip: drawing a box's third side; the next player takes it.
class DotsThirdSideDemo extends HowToDemo {
  const DotsThirdSideDemo();

  static final _start = [(_h(1, 1), 0), (_v(1, 1), 1)];

  @override
  void paint(Canvas canvas, DemoFrame f) {
    _dots(canvas, f, _start, [(0.2, _v(1, 2), 0), (0.56, _h(2, 1), 1)]);
    paintFinger(canvas, f, [FingerKey(0.2, _lineMid(f, _v(1, 2)), tap: true)]);
    final b = _Square(f, fraction: 0.92);
    final box = DotsLayout(b.size, _dr, _dc).box(4).shift(b.origin);
    paintSpotlight(canvas, box.deflate(4), f.theme.danger, f.seg(0.26, 0.32) * (1 - f.seg(0.5, 0.56)));
    final them = SeatPalette(f.theme, gameId: 'dots').fill(1);
    paintFloatLabel(canvas, f, box.center - Offset(0, f.side * 0.1), '+1', f.seg(0.6, 0.9, Curves.linear), them);
  }

  @override
  double get still => 0.4;
}

// ── Chess ───────────────────────────────────────────────────────────────────

ChessState _fen(String fen) => chessRules.decode('$fen|');

int _sq(String name) =>
    (8 - int.parse(name[1])) * 8 + name.codeUnitAt(0) - 'a'.codeUnitAt(0);

void _chess(
  Canvas canvas,
  DemoFrame f,
  _Square b, {
  required ChessState before,
  required ChessState after,
  required double moveAt,
  required int from,
  required int to,
  required int piece,
  (int, int)? captured,
  double selectAt = -1,
  Set<int> targets = const {},
}) {
  final moved = f.at(moveAt);
  final selecting = !moved && selectAt >= 0 && f.at(selectAt);
  b.draw(
    canvas,
    ChessPainter(
      state: moved ? after : before,
      theme: f.theme,
      dark: !f.theme.isLight,
      flipped: false,
      thumbnail: false,
      clock: _since(f, moveAt, 400),
      anim: moved
          ? ChessAnimation(
              slides: [(piece: piece, from: from, to: to)],
              captured: captured,
            )
          : null,
      selected: selecting ? from : null,
      targets: selecting ? targets : const {},
      last: moved ? (from, to) : null,
    ),
  );
}

Offset _chessAt(_Square b, int sq) =>
    b.origin + ChessGeometry(b.size, flipped: false).center(sq);

/// Tap the knight, its squares show, tap one.
class ChessMoveDemo extends HowToDemo {
  const ChessMoveDemo();

  static final _before = _fen('rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1');
  static final _after = _fen('rnbqkbnr/pppppppp/8/8/8/5N2/PPPPPPPP/RNBQKB1R b KQkq - 0 1');

  @override
  void paint(Canvas canvas, DemoFrame f) {
    final b = _Square(f, fraction: 0.88);
    _chess(
      canvas,
      f,
      b,
      before: _before,
      after: _after,
      selectAt: 0.16,
      moveAt: 0.46,
      from: _sq('g1'),
      to: _sq('f3'),
      piece: chessKnight,
      targets: {_sq('f3'), _sq('h3')},
    );
    paintFinger(canvas, f, [
      FingerKey(0.16, _chessAt(b, _sq('g1')), tap: true),
      FingerKey(0.46, _chessAt(b, _sq('f3')), tap: true),
    ]);
  }

  @override
  double get still => 0.35;
}

/// The knight lands on a pawn and takes it.
class ChessCaptureDemo extends HowToDemo {
  const ChessCaptureDemo();

  static final _before = _fen('rnbqkbnr/pppp1ppp/8/4p3/8/5N2/PPPPPPPP/RNBQKB1R w KQkq - 0 2');
  static final _after = _fen('rnbqkbnr/pppp1ppp/8/4N3/8/8/PPPPPPPP/RNBQKB1R b KQkq - 0 2');

  @override
  void paint(Canvas canvas, DemoFrame f) {
    final b = _Square(f, fraction: 0.88);
    _chess(
      canvas,
      f,
      b,
      before: _before,
      after: _after,
      selectAt: 0.16,
      moveAt: 0.46,
      from: _sq('f3'),
      to: _sq('e5'),
      piece: chessKnight,
      captured: (_sq('e5'), chessPawn | chessBlack),
      targets: {_sq('e5'), _sq('g5'), _sq('d4'), _sq('h4'), _sq('g1')},
    );
    paintFinger(canvas, f, [
      FingerKey(0.16, _chessAt(b, _sq('f3')), tap: true),
      FingerKey(0.46, _chessAt(b, _sq('e5')), tap: true),
    ]);
  }

  @override
  double get still => 0.35;
}

/// A pawn walks onto the last row and becomes a queen.
class ChessPromoteDemo extends HowToDemo {
  const ChessPromoteDemo();

  static final _before = _fen('7k/1P6/8/8/8/8/8/4K3 w - - 0 1');
  static final _queen = _fen('1Q5k/8/8/8/8/8/8/4K3 b - - 0 1');

  @override
  void paint(Canvas canvas, DemoFrame f) {
    final b = _Square(f, fraction: 0.88);
    _chess(
      canvas,
      f,
      b,
      before: _before,
      // Slides as a pawn, lands as the queen.
      after: _queen,
      selectAt: 0.14,
      moveAt: 0.32,
      from: _sq('b7'),
      to: _sq('b8'),
      piece: chessPawn,
      targets: {_sq('b8')},
    );
    paintFinger(canvas, f, [
      FingerKey(0.14, _chessAt(b, _sq('b7')), tap: true),
      FingerKey(0.32, _chessAt(b, _sq('b8')), tap: true),
    ]);
    paintSparkles(canvas, _chessAt(b, _sq('b8')), b.side * 0.24, f.seg(0.38, 0.62), const Color(0xFFFFC53D));
  }
}

/// Scholar's mate: the queen takes f7 and the king has nowhere to go.
class ChessMateDemo extends HowToDemo {
  const ChessMateDemo();

  static final _before = _fen('r1bqkb1r/pppp1ppp/2n2n2/4p2Q/2B1P3/8/PPPP1PPP/RNB1K1NR w KQkq - 0 4');
  static final _after = _fen('r1bqkb1r/pppp1Qpp/2n2n2/4p3/2B1P3/8/PPPP1PPP/RNB1K1NR b KQkq - 0 4');

  @override
  void paint(Canvas canvas, DemoFrame f) {
    final b = _Square(f, fraction: 0.88);
    _chess(
      canvas,
      f,
      b,
      before: _before,
      after: _after,
      moveAt: 0.3,
      from: _sq('h5'),
      to: _sq('f7'),
      piece: chessQueen,
      captured: (_sq('f7'), chessPawn | chessBlack),
    );
    paintFinger(canvas, f, [
      FingerKey(0.22, _chessAt(b, _sq('h5')), tap: true),
      FingerKey(0.3, _chessAt(b, _sq('f7')), tap: true),
    ]);
    final cell = b.side / 8;
    final king = Rect.fromCenter(center: _chessAt(b, _sq('e8')), width: cell, height: cell);
    final pulse = f.at(0.4) ? 0.6 + 0.4 * math.sin(f.t * math.pi * 12) : 0.0;
    paintSpotlight(canvas, king.deflate(1), f.theme.danger, pulse * (1 - f.seg(0.86, 0.92)), radius: 4);
  }

  @override
  double get still => 0.6;
}

/// Tip: your bishop is attacked. Spot it before you move, and move it.
class ChessTipDemo extends HowToDemo {
  const ChessTipDemo();

  // The Ruy Lopez after 3...a6: the pawn on a6 hits the bishop on b5.
  static final _before = _fen('r1bqkbnr/1ppp1ppp/p1n5/1B2p3/4P3/5N2/PPPP1PPP/RNBQK2R w KQkq - 0 4');
  static final _after = _fen('r1bqkbnr/1ppp1ppp/p1n5/4p3/B3P3/5N2/PPPP1PPP/RNBQK2R b KQkq - 0 4');

  @override
  void paint(Canvas canvas, DemoFrame f) {
    final b = _Square(f, fraction: 0.88);
    _chess(
      canvas,
      f,
      b,
      before: _before,
      after: _after,
      selectAt: 0.46,
      moveAt: 0.64,
      from: _sq('b5'),
      to: _sq('a4'),
      piece: chessBishop,
      targets: {_sq('a4'), _sq('c4'), _sq('d3'), _sq('e2'), _sq('f1'), _sq('a6'), _sq('c6')},
    );
    final cell = b.side / 8;
    Rect at(String sq) => Rect.fromCenter(center: _chessAt(b, _sq(sq)), width: cell, height: cell).deflate(1);
    // The threat: the pawn, the bishop, and the line between them.
    final threat = f.seg(0.16, 0.24) * (1 - f.seg(0.44, 0.5));
    if (threat > 0) {
      paintSpotlight(canvas, at('a6'), f.theme.danger, threat, radius: 4);
      paintSpotlight(canvas, at('b5'), f.theme.danger, threat, radius: 4);
      canvas.drawLine(
        _chessAt(b, _sq('a6')),
        _chessAt(b, _sq('b5')),
        Paint()
          ..strokeWidth = cell * 0.08
          ..strokeCap = StrokeCap.round
          ..color = f.theme.danger.withValues(alpha: 0.8 * threat),
      );
    }
    paintFinger(canvas, f, [
      // Reaching for a different piece, then thinking better of it.
      FingerKey(0.08, _chessAt(b, _sq('d2'))),
      FingerKey(0.3, _chessAt(b, _sq('d2'))),
      FingerKey(0.46, _chessAt(b, _sq('b5')), tap: true),
      FingerKey(0.64, _chessAt(b, _sq('a4')), tap: true),
    ]);
    paintSpotlight(canvas, at('a4'), f.theme.success, f.seg(0.7, 0.76) * (1 - f.seg(0.88, 0.94)), radius: 4);
  }

  @override
  double get still => 0.3;
}

// ── Liar's Dice ─────────────────────────────────────────────────────────────

const _ldYou = [3, 1, 5, 3, 6];
const _ldThem = [
  [2, 3, 3, 4, 1],
  [5, 5, 2, 6, 3],
  [3, 6, 1, 2, 2],
];

/// The table: three rivals across the top, you at the bottom.
class _Table {
  _Table(this.f) : unit = f.side;

  final DemoFrame f;
  final double unit;

  double get die => unit * 0.085;
  double get gap => unit * 0.016;

  Offset seat(int i) => switch (i) {
    // 0 is you; 1..3 the rivals, left to right.
    0 => Offset(f.size.width / 2 - unit * 0.33, f.size.height - unit * 0.17),
    _ => Offset(f.size.width * (0.2 + 0.3 * (i - 1)), unit * 0.14),
  };

  /// Top-left of die [k] in a row of [n] for seat [i].
  Offset dieAt(int i, int k, int n) {
    if (i == 0) {
      final x0 = seat(0).dx + unit * 0.12;
      return Offset(x0 + k * (die * 1.25 + gap), seat(0).dy - die * 0.62);
    }
    // A rival's dice sit in a little 3 over 2 cluster under them, so three
    // rivals fit across the table at a size you can actually read.
    final small = die * 0.8;
    final s = seat(i);
    final row = k < 3 ? 0 : 1;
    final inRow = row == 0 ? math.min(n, 3) : n - 3;
    final idx = row == 0 ? k : k - 3;
    final w = inRow * small + (inRow - 1) * gap;
    return Offset(
      s.dx - w / 2 + idx * (small + gap),
      s.dy + unit * 0.08 + row * (small + gap),
    );
  }

  void avatars(Canvas canvas, {int? speaking, Set<int> out = const {}}) {
    for (var i = 0; i < 4; i++) {
      _avatar(
        canvas,
        f,
        seat(i),
        unit * (i == 0 ? 0.065 : 0.05),
        i,
        away: out.contains(i) ? 1 : 0,
        ring: speaking == i ? 1 : 0,
        ringColor: f.theme.accent,
      );
    }
  }

  void yours(Canvas canvas, List<int> faces, {Set<int> hits = const {}, double roll = 1, int keep = 5}) {
    final ink = DiceInk(f.theme);
    final paint = Paint();
    for (var k = 0; k < keep; k++) {
      final tumble = roll < 1;
      final face = tumble ? 1 + ((f.t * 40).floor() + k * 2) % 6 : faces[k];
      final at = dieAt(0, k, 5);
      canvas.save();
      if (tumble) {
        final c = at + Offset(die / 2, die / 2);
        canvas.translate(c.dx, c.dy);
        canvas.rotate(math.sin(f.t * 30 + k) * 0.25 * (1 - roll));
        canvas.translate(-c.dx, -c.dy);
      }
      paintDie(
        canvas,
        at,
        die * 1.25,
        face,
        hits.contains(k) ? DieTone.hit : DieTone.plain,
        ink,
        paint,
      );
      canvas.restore();
    }
  }

  void theirs(
    Canvas canvas, {
    double reveal = 0,
    Set<(int, int)> hits = const {},
    Map<int, int> keep = const {},
  }) {
    final ink = DiceInk(f.theme);
    final paint = Paint();
    for (var i = 1; i <= 3; i++) {
      final n = keep[i] ?? 5;
      for (var k = 0; k < n; k++) {
        final at = dieAt(i, k, n);
        final shown = reveal > (k * 0.12);
        paintDie(
          canvas,
          at,
          die * 0.8,
          shown ? _ldThem[i - 1][k] : 0,
          !shown
              ? DieTone.hidden
              : hits.contains((i, k))
              ? DieTone.hit
              : DieTone.miss,
          ink,
          paint,
        );
      }
    }
  }

  /// A bid, a quantity and a die face, in a bubble near [from].
  void bid(Canvas canvas, int from, int qty, int face, double p, {Offset nudge = Offset.zero, bool raised = false}) {
    if (p <= 0) return;
    final s = seat(from);
    final c = (from == 0
            ? s + Offset(0, -unit * 0.16)
            : s + Offset(0, unit * 0.35)) +
        nudge;
    final w = unit * 0.24;
    final h = unit * 0.11;
    final rect = Rect.fromCenter(center: c, width: w, height: h);
    final scale = Curves.easeOutBack.transform(p.clamp(0.0, 1.0));
    canvas.save();
    canvas.translate(c.dx, c.dy);
    canvas.scale(scale);
    canvas.translate(-c.dx, -c.dy);
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, Radius.circular(h / 2)),
      Paint()..color = raised ? f.theme.accent : f.theme.surfaceRaised,
    );
    final ink = raised ? f.theme.accentInk : f.theme.ink;
    _text(canvas, _label(f, '$qty×', h * 0.5, ink), Offset(rect.left + w * 0.3, c.dy));
    paintDie(canvas, Offset(rect.left + w * 0.56, c.dy - h * 0.32), h * 0.64, face, DieTone.plain, DiceInk(f.theme), Paint());
    canvas.restore();
  }
}

/// Your five dice tumble and land; everyone else's stay face down.
class LiarsSecretDemo extends HowToDemo {
  const LiarsSecretDemo();

  @override
  void paint(Canvas canvas, DemoFrame f) {
    final t = _Table(f);
    t.avatars(canvas);
    t.theirs(canvas);
    t.yours(canvas, _ldYou, roll: f.seg(0.06, 0.36, Curves.linear));
    // Your own dice, cupped from the others.
    final at = t.dieAt(0, 0, 5) - Offset(t.gap * 2, t.gap * 2);
    final cover = Rect.fromLTWH(at.dx, at.dy, (t.die * 1.25 + t.gap) * 5 + t.gap * 2, t.die * 1.25 + t.gap * 4);
    paintSpotlight(canvas, cover, f.theme.accent, f.seg(0.4, 0.5) * (1 - f.seg(0.85, 0.9)), radius: 12);
  }
}

/// A bid: "four 3s", about every die at the table.
class LiarsBidDemo extends HowToDemo {
  const LiarsBidDemo();

  @override
  void paint(Canvas canvas, DemoFrame f) {
    final t = _Table(f);
    t.avatars(canvas, speaking: 0);
    t.theirs(canvas);
    t.yours(canvas, _ldYou);
    // The whole table lights: the bid is about all of it.
    final all = Rect.fromLTWH(f.side * 0.04, f.side * 0.05, f.size.width - f.side * 0.08, f.size.height - f.side * 0.1);
    paintSpotlight(canvas, all, f.theme.accent, f.seg(0.42, 0.52) * (1 - f.seg(0.84, 0.9)) * 0.7, radius: 20);
    t.bid(canvas, 0, 4, 3, f.seg(0.2, 0.32, Curves.linear), nudge: Offset(f.side * 0.33, -f.side * 0.12));
  }
}

/// Wild 1s: your 3s light up, and so does your 1.
class LiarsWildDemo extends HowToDemo {
  const LiarsWildDemo();

  @override
  void paint(Canvas canvas, DemoFrame f) {
    final t = _Table(f);
    t.avatars(canvas);
    t.theirs(canvas);
    t.yours(canvas, _ldYou, hits: {
      if (f.at(0.2)) 0,
      if (f.at(0.28)) 3,
      if (f.at(0.5)) 1,
    });
    t.bid(canvas, 2, 4, 3, 1);
    paintSparkles(canvas, t.dieAt(0, 1, 5) + Offset(t.die * 0.6, t.die * 0.6), t.die * 1.4, f.seg(0.5, 0.7), const Color(0xFFFFC53D), count: 6);
    paintFloatLabel(canvas, f, t.dieAt(0, 1, 5) + Offset(t.die * 0.6, -t.die * 0.4), '= 3', f.seg(0.52, 0.86, Curves.linear), f.theme.accent);
  }
}

/// Bids climb: same count higher face, then more dice.
class LiarsRaiseDemo extends HowToDemo {
  const LiarsRaiseDemo();

  @override
  void paint(Canvas canvas, DemoFrame f) {
    final t = _Table(f);
    final who = _last(f, const [0.1, 0.36, 0.62]);
    t.avatars(canvas, speaking: who == null ? null : who + 1);
    t.theirs(canvas);
    t.yours(canvas, _ldYou);
    t.bid(canvas, 1, 4, 3, f.seg(0.1, 0.2, Curves.linear));
    t.bid(canvas, 2, 4, 5, f.seg(0.36, 0.46, Curves.linear), raised: who == 1);
    t.bid(canvas, 3, 5, 2, f.seg(0.62, 0.72, Curves.linear), raised: who == 2);
  }
}

/// "Liar!" Every die turns over; the 2s and wild 1s are counted.
class LiarsCallDemo extends HowToDemo {
  const LiarsCallDemo();

  static final _hits = <(int, int)>{
    for (var i = 1; i <= 3; i++)
      for (var k = 0; k < 5; k++)
        if (_ldThem[i - 1][k] == 2 || _ldThem[i - 1][k] == 1) (i, k),
  };

  @override
  void paint(Canvas canvas, DemoFrame f) {
    final t = _Table(f);
    t.avatars(canvas, speaking: 0);
    t.bid(canvas, 3, 5, 2, 1);
    final reveal = f.seg(0.3, 0.6, Curves.linear);
    t.theirs(canvas, reveal: reveal * 1.6, hits: f.at(0.62) ? _hits : const {});
    t.yours(canvas, _ldYou, hits: {if (f.at(0.62)) 1});
    // The call itself: a red badge from you.
    final p = f.seg(0.12, 0.22, Curves.linear);
    if (p > 0) {
      final c = t.seat(0) + Offset(0, -f.side * 0.15);
      canvas.drawCircle(c, f.side * 0.07 * Curves.easeOutBack.transform(p), Paint()..color = f.theme.danger);
      _text(canvas, _label(f, '!', f.side * 0.09 * p, const Color(0xFFFFFFFF), weight: FontWeight.w900), c);
    }
    // 7 matching dice ≥ 5: the bid holds.
    if (f.at(0.66)) {
      final c = Offset(f.size.width / 2, f.size.height * 0.52);
      final s = Curves.easeOutBack.transform(f.seg(0.66, 0.76, Curves.linear));
      canvas.drawCircle(c, f.side * 0.085 * s, Paint()..color = f.theme.accent);
      _text(canvas, _label(f, '7', f.side * 0.09 * s, f.theme.accentInk), c);
    }
  }

  @override
  double get still => 0.8;
}

/// Wrong call: one of your dice flies off.
class LiarsLoseDemo extends HowToDemo {
  const LiarsLoseDemo();

  @override
  void paint(Canvas canvas, DemoFrame f) {
    final t = _Table(f);
    t.avatars(canvas);
    t.theirs(canvas);
    final gone = f.seg(0.3, 0.55);
    t.yours(canvas, _ldYou, keep: 4);
    if (gone < 1) {
      final at = t.dieAt(0, 4, 5) + Offset(gone * f.side * 0.1, -gone * f.side * 0.25);
      canvas.saveLayer(null, Paint()..color = Color.fromRGBO(0, 0, 0, 1 - gone));
      paintDie(canvas, at, t.die * 1.25, _ldYou[4], DieTone.plain, DiceInk(f.theme), Paint());
      canvas.restore();
    }
    paintFloatLabel(canvas, f, t.dieAt(0, 4, 5) + Offset(t.die, -t.die), '-1', f.seg(0.32, 0.8, Curves.linear), f.theme.danger);
  }

  @override
  double get still => 0.6;
}

/// Rivals run dry one by one; the last one holding dice wins.
class LiarsWinDemo extends HowToDemo {
  const LiarsWinDemo();

  @override
  void paint(Canvas canvas, DemoFrame f) {
    final t = _Table(f);
    final out = {
      if (f.at(0.25)) 1,
      if (f.at(0.45)) 3,
      if (f.at(0.65)) 2,
    };
    t.avatars(canvas, out: out);
    t.theirs(canvas, keep: {
      1: f.at(0.25) ? 0 : 1,
      2: f.at(0.65) ? 0 : (f.at(0.45) ? 1 : 2),
      3: f.at(0.45) ? 0 : 1,
    });
    t.yours(canvas, _ldYou, keep: 2);
    if (f.at(0.7)) {
      final c = t.seat(0) - Offset(0, f.side * 0.11);
      final p = Curves.easeOutBack.transform(f.seg(0.7, 0.8, Curves.linear));
      paintCrown(canvas, c, f.side * 0.11 * p, Paint()..color = const Color(0xFFFFC53D));
      paintSparkles(canvas, t.seat(0), f.side * 0.2, f.seg(0.72, 0.92), const Color(0xFFFFC53D));
    }
  }
}

/// Tip: thinking about 3s, count your own first (two 3s and a wild 1), then
/// reckon on about a third of the hidden dice: about 5 of 15. Bid near 8.
class LiarsTipDemo extends HowToDemo {
  const LiarsTipDemo();

  /// Five of the fifteen hidden dice, spread round the table: "about a
  /// third", not a peek at which ones.
  static const _third = <(int, int)>{(1, 1), (1, 4), (2, 2), (3, 0), (3, 3)};

  @override
  void paint(Canvas canvas, DemoFrame f) {
    final t = _Table(f);
    t.avatars(canvas, speaking: 0);
    t.theirs(canvas);
    t.yours(canvas, _ldYou, hits: {
      if (f.at(0.12)) 0,
      if (f.at(0.18)) 3,
      if (f.at(0.24)) 1,
    });
    // The count floats up over your row, where the three hits are.
    final row = t.dieAt(0, 2, 5) + Offset(t.die * 0.62, -t.die * 0.2);
    paintFloatLabel(canvas, f, row, '3', f.seg(0.26, 0.5, Curves.linear), f.theme.accent);
    // Then the hidden ones, a third of them, lighting up one at a time in the
    // die's own shape: still face down, just counted.
    var k = 0;
    final small = t.die * 0.8;
    final lit = Paint();
    for (final (i, d) in _third) {
      final p = f.seg(0.4 + k * 0.05, 0.46 + k * 0.05) * (1 - f.seg(0.88, 0.94));
      k++;
      if (p <= 0) continue;
      lit.color = f.theme.accent.withValues(alpha: 0.9 * p);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          t.dieAt(i, d, 5) & Size.square(small),
          Radius.circular(small * 0.24),
        ),
        lit,
      );
    }
    paintFloatLabel(canvas, f, Offset(f.size.width / 2, f.size.height * 0.46), '≈ 5', f.seg(0.64, 0.86, Curves.linear), f.theme.accent);
    // 3 of yours plus about 5: a bid near 8 is a fair one.
    t.bid(canvas, 0, 8, 3, f.seg(0.72, 0.8, Curves.linear), nudge: Offset(f.side * 0.33, -f.side * 0.12), raised: true);
  }

  @override
  double get still => 0.8;
}

// ── Imposter ────────────────────────────────────────────────────────────────

const _impSeats = 4;
const _imposter = 2;

Offset _impSeat(DemoFrame f, int i) =>
    Offset(f.size.width * (0.14 + 0.24 * i), f.size.height - f.side * 0.14);

/// A player's card above them: face down, or flipped to the word (a sun,
/// standing in for any word) or, for the imposter, a "?".
void _impCard(Canvas canvas, DemoFrame f, int i, double flip, {bool lift = false}) {
  final c = _impSeat(f, i) - Offset(0, f.side * (lift ? 0.42 : 0.36));
  final w = f.side * 0.18;
  final h = w * 1.35;
  final e = Curves.easeInOutCubic.transform(flip.clamp(0.0, 1.0));
  final sx = math.cos(math.pi * e).abs();
  final front = e >= 0.5;
  canvas.save();
  canvas.translate(c.dx, c.dy);
  canvas.scale(math.max(sx, 0.04), 1);
  final rect = Rect.fromCenter(center: Offset.zero, width: w, height: h);
  final rr = RRect.fromRectAndRadius(rect, Radius.circular(w * 0.16));
  canvas.drawRRect(
    rr.shift(Offset(0, w * 0.04)),
    Paint()..color = const Color(0xFF000000).withValues(alpha: 0.12),
  );
  if (!front) {
    canvas.drawRRect(rr, Paint()..color = f.theme.accent);
    canvas.drawRRect(
      rr.deflate(w * 0.08),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = w * 0.03
        ..color = f.theme.accentInk.withValues(alpha: 0.4),
    );
  } else if (i == _imposter) {
    canvas.drawRRect(rr, Paint()..color = f.theme.danger);
    _text(canvas, _label(f, '?', w * 0.7, const Color(0xFFFFFFFF), weight: FontWeight.w900), Offset.zero);
  } else {
    canvas.drawRRect(rr, Paint()..color = f.theme.surfaceRaised);
    paintSun(canvas, Offset(0, -h * 0.08), w * 0.95, Paint()..color = const Color(0xFFF5B400));
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: Offset(0, h * 0.3), width: w * 0.6, height: w * 0.08),
        Radius.circular(w * 0.04),
      ),
      Paint()..color = f.theme.ink.withValues(alpha: 0.3),
    );
  }
  canvas.restore();
}

/// Cards deal and flip: three suns, one "?".
class ImposterWordDemo extends HowToDemo {
  const ImposterWordDemo();

  @override
  void paint(Canvas canvas, DemoFrame f) {
    for (var i = 0; i < _impSeats; i++) {
      _avatar(canvas, f, _impSeat(f, i), f.side * 0.07, i);
      _impCard(canvas, f, i, f.seg(0.16 + i * 0.1, 0.34 + i * 0.1), lift: i == _imposter && f.at(0.62));
    }
    final pulse = f.at(0.62) ? 0.5 + 0.5 * math.sin(f.t * math.pi * 10) : 0.0;
    final c = _impSeat(f, _imposter) - Offset(0, f.side * 0.42);
    paintSpotlight(
      canvas,
      Rect.fromCenter(center: c, width: f.side * 0.22, height: f.side * 0.3),
      f.theme.danger,
      pulse * (1 - f.seg(0.86, 0.92)),
      radius: 12,
    );
  }

  @override
  double get still => 0.7;
}

/// Clue bubbles pop up one player at a time.
class ImposterClueDemo extends HowToDemo {
  const ImposterClueDemo();

  @override
  void paint(Canvas canvas, DemoFrame f) {
    final turn = _last(f, const [0.08, 0.28, 0.48, 0.68]);
    for (var i = 0; i < _impSeats; i++) {
      _avatar(canvas, f, _impSeat(f, i), f.side * 0.07, i, ring: turn == i ? 1 : 0, ringColor: f.theme.accent);
      final at = 0.08 + i * 0.2;
      final c = _impSeat(f, i) - Offset(0, f.side * (0.3 + (i.isEven ? 0 : 0.14)));
      _bubble(
        canvas,
        Rect.fromCenter(center: c, width: f.side * 0.22, height: f.side * 0.11),
        f.theme.surfaceRaised,
        f.theme.ink.withValues(alpha: 0.35),
        f.seg(at, at + 0.08, Curves.linear),
        bars: i == _imposter ? 1 : 2,
      );
    }
  }
}

/// Voice mode: each player in turn talks (sound waves), then taps Done.
class ImposterVoiceDemo extends HowToDemo {
  const ImposterVoiceDemo();

  @override
  void paint(Canvas canvas, DemoFrame f) {
    for (var i = 0; i < _impSeats; i++) {
      final at = 0.08 + i * 0.2;
      final talking = f.at(at) && !f.at(at + 0.16);
      final c = _impSeat(f, i);
      _avatar(canvas, f, c, f.side * 0.07, i, ring: talking ? 1 : 0, ringColor: f.theme.success);
      if (talking) {
        final wave = Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = f.side * 0.012
          ..strokeCap = StrokeCap.round;
        for (var k = 0; k < 3; k++) {
          final p = ((f.t - at) * 6 + k / 3) % 1;
          wave.color = f.theme.success.withValues(alpha: 1 - p);
          canvas.drawArc(
            Rect.fromCircle(center: c - Offset(0, f.side * 0.1), radius: f.side * (0.05 + 0.09 * p)),
            -math.pi * 0.8,
            math.pi * 0.6,
            false,
            wave,
          );
        }
      }
      _tick(canvas, c + Offset(f.side * 0.055, -f.side * 0.055), f.side * 0.028, f.theme.success,
          f.seg(at + 0.14, at + 0.2, Curves.linear));
    }
  }
}

/// Votes fly to one player; their count climbs to 3.
class ImposterVoteDemo extends HowToDemo {
  const ImposterVoteDemo();

  @override
  void paint(Canvas canvas, DemoFrame f) {
    final target = _impSeat(f, _imposter);
    var votes = 0;
    for (var i = 0; i < _impSeats; i++) {
      _avatar(canvas, f, _impSeat(f, i), f.side * 0.07, i);
      if (i == _imposter) continue;
      final at = 0.14 + votes * 0.16;
      final p = f.seg(at, at + 0.14);
      if (p > 0 && p < 1) {
        final from = _impSeat(f, i) - Offset(0, f.side * 0.1);
        final to = target - Offset(0, f.side * 0.12);
        final mid = Offset.lerp(from, to, 0.5)! - Offset(0, f.side * 0.22);
        final q = Offset.lerp(Offset.lerp(from, mid, p)!, Offset.lerp(mid, to, p)!, p)!;
        canvas.drawCircle(q, f.side * 0.022, Paint()..color = SeatPalette(f.theme).fill(i));
      }
      if (p >= 1) votes++;
    }
    if (votes > 0) {
      final c = target - Offset(0, f.side * 0.2);
      canvas.drawCircle(c, f.side * 0.055, Paint()..color = f.theme.danger);
      _text(canvas, _label(f, '$votes', f.side * 0.065, const Color(0xFFFFFFFF)), c);
    }
  }

  @override
  double get still => 0.75;
}

/// The accused flips: it IS the imposter. A last guess bubble; it's wrong,
/// and the crew lights up.
class ImposterGuessDemo extends HowToDemo {
  const ImposterGuessDemo();

  @override
  void paint(Canvas canvas, DemoFrame f) {
    for (var i = 0; i < _impSeats; i++) {
      _avatar(canvas, f, _impSeat(f, i), f.side * 0.07, i, ring: i != _imposter && f.at(0.72) ? 1 : 0);
    }
    _impCard(canvas, f, _imposter, f.seg(0.1, 0.3));
    final c = _impSeat(f, _imposter) + Offset(f.side * 0.2, -f.side * 0.36);
    _bubble(
      canvas,
      Rect.fromCenter(center: c, width: f.side * 0.24, height: f.side * 0.11),
      f.theme.surfaceRaised,
      f.theme.ink.withValues(alpha: 0.35),
      f.seg(0.38, 0.46, Curves.linear),
      bars: 1,
    );
    if (f.at(0.58)) {
      // Wrong: a red cross over the guess.
      final p = f.seg(0.58, 0.66);
      final x = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = f.side * 0.018
        ..strokeCap = StrokeCap.round
        ..color = f.theme.danger;
      final d = f.side * 0.05 * p;
      canvas.drawLine(c + Offset(-d, -d), c + Offset(d, d), x);
      canvas.drawLine(c + Offset(d, -d), c + Offset(-d, d), x);
    }
    for (var i = 0; i < _impSeats; i++) {
      if (i == _imposter) continue;
      paintSparkles(canvas, _impSeat(f, i), f.side * 0.12, f.seg(0.72 + i * 0.03, 0.9 + i * 0.02), f.theme.success, count: 6);
    }
  }
}

// ── Puzzle Race ─────────────────────────────────────────────────────────────

const _raceBoard = QueensBoard(
  size: 4,
  regions: [0, 0, 1, 1, 0, 2, 2, 1, 3, 3, 2, 1, 3, 3, 2, 2],
);
const _raceCrowns = [1, 7, 8, 14];

void _raceLane(Canvas canvas, DemoFrame f, int i, double progress, {double appear = 1, int? place}) {
  if (appear <= 0) return;
  final top = f.side * (0.12 + 0.27 * i);
  final h = f.side * 0.22;
  final x = f.side * 0.06;
  canvas.saveLayer(null, Paint()..color = Color.fromRGBO(0, 0, 0, appear.clamp(0.0, 1.0)));
  // Their copy of the board, as far along as they are.
  final crowns = (_raceCrowns.length * progress).floor();
  canvas.save();
  canvas.translate(x + f.side * 0.12, top);
  QueensBoardPainter(
    board: _raceBoard,
    theme: f.theme,
    palette: f.palette,
    marks: [
      for (var c = 0; c < 16; c++)
        _raceCrowns.take(crowns).contains(c) ? QueensMark.crown : QueensMark.none,
    ],
    win: progress >= 1 ? 1 : 0,
  ).paint(canvas, Size.square(h));
  canvas.restore();
  _avatar(canvas, f, Offset(x + f.side * 0.045, top + h / 2), f.side * 0.045, i);
  // The progress bar everyone sees.
  final barL = x + f.side * 0.12 + h + f.side * 0.05;
  final barR = f.size.width - f.side * 0.08;
  final bar = Rect.fromLTRB(barL, top + h / 2 - f.side * 0.018, barR, top + h / 2 + f.side * 0.018);
  canvas.drawRRect(
    RRect.fromRectAndRadius(bar, Radius.circular(bar.height / 2)),
    Paint()..color = f.theme.ink.withValues(alpha: 0.1),
  );
  canvas.drawRRect(
    RRect.fromRectAndRadius(
      Rect.fromLTWH(bar.left, bar.top, bar.width * progress.clamp(0.0, 1.0), bar.height),
      Radius.circular(bar.height / 2),
    ),
    Paint()..color = SeatPalette(f.theme).fill(i),
  );
  if (place != null) {
    final c = Offset(barR - f.side * 0.03, bar.center.dy - f.side * 0.07);
    canvas.drawCircle(c, f.side * 0.04, Paint()..color = const Color(0xFFFFC53D));
    _text(canvas, _label(f, '$place', f.side * 0.045, const Color(0xFF1C1C1E)), c);
  }
  canvas.restore();
}

/// The same board deals out to three players.
class RaceSameDemo extends HowToDemo {
  const RaceSameDemo();

  @override
  void paint(Canvas canvas, DemoFrame f) {
    for (var i = 0; i < 3; i++) {
      _raceLane(canvas, f, i, 0, appear: f.seg(0.1 + i * 0.08, 0.24 + i * 0.08));
    }
  }
}

/// Bars race; boards fill at different speeds.
class RaceProgressDemo extends HowToDemo {
  const RaceProgressDemo();

  @override
  void paint(Canvas canvas, DemoFrame f) {
    const speed = [0.95, 0.7, 0.82];
    for (var i = 0; i < 3; i++) {
      _raceLane(canvas, f, i, f.seg(0.1, 0.9, Curves.easeInOut) * speed[i]);
    }
  }
}

/// One player finishes first and takes the 1.
class RaceFinishDemo extends HowToDemo {
  const RaceFinishDemo();

  @override
  void paint(Canvas canvas, DemoFrame f) {
    const speed = [1.0, 0.82, 0.9];
    for (var i = 0; i < 3; i++) {
      final p = f.seg(0.05, 0.5, Curves.easeOut) * speed[i];
      _raceLane(canvas, f, i, p, place: i == 0 && f.at(0.5) ? 1 : null);
    }
    paintSparkles(canvas, Offset(f.size.width * 0.8, f.side * 0.2), f.side * 0.2, f.seg(0.5, 0.75), const Color(0xFFFFC53D));
    // The race clock, top right.
    final secs = (600 - 600 * f.seg(0.0, 0.94, Curves.linear) * 0.4).round();
    _text(
      canvas,
      _label(f, '${secs ~/ 60}:${(secs % 60).toString().padLeft(2, '0')}', f.side * 0.05, f.theme.inkSoft, weight: FontWeight.w600),
      Offset(f.size.width - f.side * 0.12, f.side * 0.05),
    );
  }
}

// ── Play modes ──────────────────────────────────────────────────────────────

Path _bolt(Offset c, double s) => Path()
  ..moveTo(c.dx + s * 0.12, c.dy - s * 0.5)
  ..lineTo(c.dx - s * 0.3, c.dy + s * 0.06)
  ..lineTo(c.dx - s * 0.02, c.dy + s * 0.06)
  ..lineTo(c.dx - s * 0.12, c.dy + s * 0.5)
  ..lineTo(c.dx + s * 0.3, c.dy - s * 0.06)
  ..lineTo(c.dx + s * 0.02, c.dy - s * 0.06)
  ..close();

/// A small board in the middle of a mode demo, drawn by the tic-tac-toe
/// painter: the game being played.
void _miniBoard(Canvas canvas, DemoFrame f, Offset c, double side, List<int> cells, {int? ghost, double dim = 0}) {
  canvas.save();
  canvas.translate(c.dx - side / 2, c.dy - side / 2);
  canvas.drawRRect(
    RRect.fromRectAndRadius(Offset.zero & Size.square(side), Radius.circular(side * 0.14)),
    Paint()..color = f.theme.surfaceRaised,
  );
  canvas.translate(side * 0.08, side * 0.08);
  TicTacToePainter(
    cells: cells,
    seats: SeatPalette(f.theme, gameId: 'tictactoe'),
    ink: f.theme.ink,
    clock: const BoardClock(null, 0),
    press: ghost,
  ).paint(canvas, Size.square(side * 0.84));
  canvas.restore();
  if (dim > 0) {
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromCenter(center: c, width: side, height: side), Radius.circular(side * 0.14)),
      Paint()..color = f.theme.background.withValues(alpha: 0.6 * dim),
    );
  }
}

/// Everyone taps ready; the bolt flashes and the board appears.
class LiveReadyDemo extends HowToDemo {
  const LiveReadyDemo({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, DemoFrame f) {
    final y = f.size.height * 0.72;
    for (var i = 0; i < 3; i++) {
      final c = Offset(f.size.width * (0.25 + 0.25 * i), y);
      _avatar(canvas, f, c, f.side * 0.075, i);
      _tick(canvas, c + Offset(f.side * 0.06, f.side * 0.055), f.side * 0.03, f.theme.success, f.seg(0.12 + i * 0.12, 0.2 + i * 0.12, Curves.linear));
    }
    final go = f.seg(0.5, 0.6, Curves.linear);
    final c = Offset(f.size.width / 2, f.size.height * 0.32);
    if (go > 0) {
      final s = Curves.easeOutBack.transform(go);
      canvas.drawCircle(c, f.side * 0.13 * s, Paint()..color = color);
      canvas.drawPath(_bolt(c, f.side * 0.15 * s), Paint()..color = const Color(0xFFFFFFFF));
      paintSparkles(canvas, c, f.side * 0.26, f.seg(0.52, 0.8), color);
    }
  }
}

/// Mid-game, one player leaves: grey, the board pauses, a two-minute ring
/// runs down, and they come back in time.
class LivePauseDemo extends HowToDemo {
  const LivePauseDemo({required this.color});

  final Color color;

  @override
  Duration get period => const Duration(milliseconds: 5200);

  @override
  void paint(Canvas canvas, DemoFrame f) {
    final away = f.seg(0.14, 0.2) * (1 - f.seg(0.72, 0.78));
    final paused = away;
    final board = Offset(f.size.width / 2, f.size.height * 0.38);
    _miniBoard(canvas, f, board, f.side * 0.42, const [1, 0, 2, 0, 1, 0, 0, 2, 0], dim: paused);
    if (paused > 0) {
      // The pause badge, and the grace clock around it.
      final r = f.side * 0.08;
      canvas.drawCircle(board, r * paused, Paint()..color = color);
      final bar = Paint()..color = const Color(0xFFFFFFFF);
      canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromCenter(center: board - Offset(r * 0.25, 0), width: r * 0.22, height: r * 0.8 * paused), Radius.circular(r * 0.1)), bar);
      canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromCenter(center: board + Offset(r * 0.25, 0), width: r * 0.22, height: r * 0.8 * paused), Radius.circular(r * 0.1)), bar);
      final left = 1 - f.seg(0.2, 0.72, Curves.linear) * 0.6;
      canvas.drawArc(
        Rect.fromCircle(center: board, radius: f.side * 0.25),
        -math.pi / 2,
        math.pi * 2 * left,
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = f.side * 0.02
          ..strokeCap = StrokeCap.round
          ..color = color.withValues(alpha: paused),
      );
      final secs = (120 * left).round();
      _text(
        canvas,
        _label(f, '${secs ~/ 60}:${(secs % 60).toString().padLeft(2, '0')}', f.side * 0.055, f.theme.ink.withValues(alpha: paused)),
        board + Offset(0, f.side * 0.31),
      );
    }
    final y = f.size.height * 0.86;
    _avatar(canvas, f, Offset(f.size.width * 0.3, y), f.side * 0.065, 0);
    _avatar(canvas, f, Offset(f.size.width * 0.7, y), f.side * 0.065, 1, away: away);
    if (f.at(0.74)) {
      _tick(canvas, Offset(f.size.width * 0.7 + f.side * 0.05, y + f.side * 0.05), f.side * 0.028, f.theme.success, f.seg(0.74, 0.82, Curves.linear) * (1 - f.seg(0.9, 0.94)));
    }
  }
}

/// Two seated players and three watchers; one watcher asks for a seat, a
/// player says yes, and they swap.
class LiveWatchDemo extends HowToDemo {
  const LiveWatchDemo({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, DemoFrame f) {
    final board = Offset(f.size.width / 2, f.size.height * 0.32);
    _miniBoard(canvas, f, board, f.side * 0.36, const [1, 0, 2, 0, 1, 0, 0, 0, 0]);
    final seatY = f.size.height * 0.62;
    final watchY = f.size.height * 0.86;
    final swap = f.seg(0.58, 0.76);
    final seat1 = Offset(f.size.width * 0.68, seatY);
    final watcher = Offset(f.size.width * 0.5, watchY);
    _avatar(canvas, f, Offset(f.size.width * 0.32, seatY), f.side * 0.065, 0);
    // The player who gives up the seat and the watcher who takes it trade
    // places.
    _avatar(canvas, f, Offset.lerp(seat1, watcher, swap)!, f.side * (0.065 - 0.02 * swap), 1);
    for (var i = 0; i < 3; i++) {
      final c = Offset(f.size.width * (0.3 + 0.2 * i), watchY);
      if (i == 1) {
        _avatar(canvas, f, Offset.lerp(c, seat1, swap)!, f.side * (0.045 + 0.02 * swap), 4);
      } else {
        _avatar(canvas, f, c, f.side * 0.045, 2 + i, away: 0.3);
      }
    }
    // The ask, and the yes.
    final ask = f.seg(0.16, 0.24, Curves.linear) * (1 - f.seg(0.56, 0.6));
    _bubble(
      canvas,
      Rect.fromCenter(center: watcher - Offset(0, f.side * 0.13), width: f.side * 0.16, height: f.side * 0.08),
      color,
      const Color(0xCCFFFFFF),
      ask,
      bars: 1,
    );
    _tick(canvas, seat1 + Offset(f.side * 0.06, -f.side * 0.06), f.side * 0.03, f.theme.success, f.seg(0.4, 0.48, Curves.linear) * (1 - f.seg(0.56, 0.6)));
    paintSparkles(canvas, seat1, f.side * 0.14, f.seg(0.76, 0.92), color, count: 6);
  }
}

/// Stage a move, tap Send: the board slides away and the move lands in the
/// chat as a bubble.
class TurnsSendDemo extends HowToDemo {
  const TurnsSendDemo({required this.color});

  final Color color;

  @override
  Duration get period => const Duration(milliseconds: 4800);

  @override
  void paint(Canvas canvas, DemoFrame f) {
    final w = f.size.width;
    final h = f.size.height;
    // The chat behind: two old messages.
    _bubble(canvas, Rect.fromLTWH(w * 0.08, h * 0.08, w * 0.42, h * 0.1), f.theme.surfaceRaised, f.theme.ink.withValues(alpha: 0.25), 1, bars: 1, tailDown: true);
    _bubble(canvas, Rect.fromLTWH(w * 0.5, h * 0.22, w * 0.4, h * 0.1), color.withValues(alpha: 0.85), const Color(0xAAFFFFFF), 1, bars: 1, tailDown: true);

    // The game sheet, sliding off once sent.
    final away = f.seg(0.52, 0.66, Curves.easeInCubic);
    final sheetTop = h * 0.36 + away * h * 0.7;
    canvas.save();
    canvas.clipRect(Offset.zero & f.size);
    final sheet = RRect.fromRectAndCorners(
      Rect.fromLTWH(w * 0.04, sheetTop, w * 0.92, h * 0.66),
      topLeft: Radius.circular(f.side * 0.06),
      topRight: Radius.circular(f.side * 0.06),
    );
    canvas.drawRRect(sheet, Paint()..color = f.theme.surface);
    final boardC = Offset(w / 2, sheetTop + h * 0.2);
    final staged = f.at(0.14);
    _miniBoard(canvas, f, boardC, f.side * 0.3, [1, 0, 2, 0, staged ? 1 : 0, 0, 0, 2, 0]);
    // Send move.
    final btn = Rect.fromCenter(center: Offset(w / 2, sheetTop + h * 0.46), width: w * 0.5, height: h * 0.1);
    final ready = f.seg(0.16, 0.24, Curves.linear);
    canvas.drawRRect(
      RRect.fromRectAndRadius(btn, Radius.circular(btn.height / 2)),
      Paint()..color = Color.lerp(f.theme.ink.withValues(alpha: 0.12), color, ready)!,
    );
    // A paper plane on the button.
    final pc = btn.center;
    final s = btn.height * 0.4;
    canvas.drawPath(
      Path()
        ..moveTo(pc.dx - s, pc.dy - s * 0.1)
        ..lineTo(pc.dx + s, pc.dy - s * 0.7)
        ..lineTo(pc.dx + s * 0.25, pc.dy + s * 0.75)
        ..lineTo(pc.dx - s * 0.05, pc.dy + s * 0.1)
        ..close(),
      Paint()..color = const Color(0xFFFFFFFF).withValues(alpha: 0.4 + 0.6 * ready),
    );
    canvas.restore();
    paintFinger(canvas, f, [
      FingerKey(0.14, boardC, tap: true),
      FingerKey(0.42, Offset(w / 2, h * 0.36 + h * 0.46), tap: true),
    ]);

    // The new bubble: your move, posted.
    final land = f.seg(0.6, 0.72);
    if (land > 0) {
      final rect = Rect.fromLTWH(w * 0.46, h * 0.38 + (1 - land) * h * 0.2, w * 0.46, h * 0.36);
      canvas.saveLayer(null, Paint()..color = Color.fromRGBO(0, 0, 0, land));
      canvas.drawRRect(RRect.fromRectAndRadius(rect, Radius.circular(f.side * 0.05)), Paint()..color = color);
      _miniBoard(canvas, f, rect.center, rect.height * 0.78, const [1, 0, 2, 0, 1, 0, 0, 2, 0]);
      canvas.restore();
      paintSparkles(canvas, rect.center, f.side * 0.24, f.seg(0.7, 0.9), color, count: 6);
    }
  }
}

/// The two-day clock: it runs down, a bell rings at the reminder, and the
/// nudge button lights up and is tapped.
class TurnsClockDemo extends HowToDemo {
  const TurnsClockDemo({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, DemoFrame f) {
    final c = Offset(f.size.width * 0.36, f.size.height * 0.46);
    final r = f.side * 0.24;
    final used = f.seg(0.06, 0.6, Curves.linear) * (20 / 48);
    canvas.drawCircle(
      c,
      r,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = f.side * 0.035
        ..color = f.theme.ink.withValues(alpha: 0.08),
    );
    canvas.drawArc(
      Rect.fromCircle(center: c, radius: r),
      -math.pi / 2 + math.pi * 2 * used,
      math.pi * 2 * (1 - used),
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = f.side * 0.035
        ..strokeCap = StrokeCap.round
        ..color = color,
    );
    final hours = (48 - 48 * used).round();
    _text(canvas, _label(f, '$hours', f.side * 0.13, f.theme.ink), c);

    // The reminder bell, ringing as the clock passes 20 hours in.
    final ring = f.seg(0.6, 0.66, Curves.linear) * (1 - f.seg(0.86, 0.9));
    final bellC = Offset(f.size.width * 0.78, f.size.height * 0.3);
    if (ring > 0) {
      canvas.save();
      canvas.translate(bellC.dx, bellC.dy);
      canvas.rotate(math.sin(f.t * 90) * 0.35 * ring);
      final b = f.side * 0.08;
      final bell = Path()
        ..moveTo(-b, b * 0.6)
        ..quadraticBezierTo(-b * 0.85, -b * 0.9, 0, -b)
        ..quadraticBezierTo(b * 0.85, -b * 0.9, b, b * 0.6)
        ..close();
      canvas.drawPath(bell, Paint()..color = const Color(0xFFF5B400).withValues(alpha: ring));
      canvas.drawCircle(Offset(0, b * 0.8), b * 0.22, Paint()..color = const Color(0xFFF5B400).withValues(alpha: ring));
      canvas.restore();
    }

    // Nudge: a capsule that you tap.
    final nudgeC = Offset(f.size.width * 0.78, f.size.height * 0.66);
    final nudge = RRect.fromRectAndRadius(
      Rect.fromCenter(center: nudgeC, width: f.side * 0.26, height: f.side * 0.11),
      Radius.circular(f.side * 0.055),
    );
    final pressed = f.at(0.74);
    canvas.drawRRect(nudge, Paint()..color = pressed ? f.theme.success : color.withValues(alpha: 0.9));
    if (pressed) {
      _tick(canvas, nudgeC, f.side * 0.035, f.theme.success, 1);
    } else {
      // A little waving hand stand-in: three motion arcs.
      for (var k = 0; k < 2; k++) {
        canvas.drawArc(
          Rect.fromCircle(center: nudgeC, radius: f.side * (0.02 + k * 0.02)),
          -0.8,
          1.6,
          false,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = f.side * 0.01
            ..strokeCap = StrokeCap.round
            ..color = const Color(0xFFFFFFFF),
        );
      }
    }
    paintFinger(canvas, f, [FingerKey(0.74, nudgeC, tap: true)]);
  }
}

/// Out of time: the ring empties and goes red, and the game is lost.
class TurnsTimeoutDemo extends HowToDemo {
  const TurnsTimeoutDemo({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, DemoFrame f) {
    final c = Offset(f.size.width / 2, f.size.height * 0.46);
    final r = f.side * 0.26;
    final left = 1 - f.seg(0.06, 0.5, Curves.easeIn);
    final out = f.at(0.5);
    canvas.drawCircle(
      c,
      r,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = f.side * 0.035
        ..color = (out ? f.theme.danger : f.theme.ink).withValues(alpha: out ? 0.3 : 0.08),
    );
    if (left > 0) {
      canvas.drawArc(
        Rect.fromCircle(center: c, radius: r),
        -math.pi / 2 + math.pi * 2 * (1 - left),
        math.pi * 2 * left,
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = f.side * 0.035
          ..strokeCap = StrokeCap.round
          ..color = left < 0.2 ? f.theme.danger : color,
      );
    }
    if (!out) {
      _text(canvas, _label(f, '${(48 * left).round()}', f.side * 0.13, f.theme.ink), c);
    } else {
      final p = Curves.easeOutBack.transform(f.seg(0.5, 0.6, Curves.linear));
      final x = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = f.side * 0.04
        ..strokeCap = StrokeCap.round
        ..color = f.theme.danger;
      final d = f.side * 0.08 * p;
      canvas.drawLine(c + Offset(-d, -d), c + Offset(d, d), x);
      canvas.drawLine(c + Offset(d, -d), c + Offset(-d, d), x);
    }
  }

  @override
  double get still => 0.7;
}
