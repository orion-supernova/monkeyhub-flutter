import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import '../tic_tac_toe.dart';
import 'board_kit.dart';
import 'seat_palette.dart';

/// Timings, in milliseconds. The newest mark draws on, then a win strikes
/// through: two beats, so the line reads as a consequence of the mark.
const double _markMs = 220;
const double _strikeMs = 300;

/// Tic-tac-toe: four hairlines and two shapes.
class TicTacToeBoardView extends BoardView {
  const TicTacToeBoardView({super.key, required super.props});

  @override
  State<TicTacToeBoardView> createState() => _TicTacToeBoardState();
}

class _TicTacToeBoardState extends BoardViewState<TicTacToeBoardView> {
  TicTacToeState? _s;

  /// The cell whose mark is drawing on, if any.
  int? _fresh;

  /// The cell under a finger that has not lifted yet.
  int? _press;

  @override
  void initState() {
    super.initState();
    _s = _decode(widget.props.state);
  }

  static TicTacToeState? _decode(String raw) {
    try {
      return ticTacToeRules.decode(raw);
    } on FormatException {
      return null;
    }
  }

  @override
  void didUpdateWidget(TicTacToeBoardView old) {
    super.didUpdateWidget(old);
    if (old.props.state == widget.props.state) return;
    final before = _s;
    final next = _decode(widget.props.state);
    if (next == null) return;
    _s = next;
    _press = null;
    _fresh = null;
    if (before == null) return;
    // Exactly one new mark is a move; anything else (a rematch, a resync)
    // just appears.
    int? added;
    var changes = 0;
    for (var i = 0; i < 9; i++) {
      if (before.cells[i] != next.cells[i]) {
        changes++;
        if (before.cells[i] == 0) added = i;
      }
    }
    if (changes != 1 || added == null) {
      play(0);
      return;
    }
    _fresh = added;
    final won = ticTacToeRules.winningLine(next) != null;
    play(_markMs + (won && widget.props.winLine ? _strikeMs : 0));
  }

  int? _cellAt(Offset p) {
    final box = context.findRenderObject() as RenderBox?;
    if (box == null) return null;
    final side = math.min(box.size.width, box.size.height);
    if (p.dx < 0 || p.dy < 0 || p.dx >= side || p.dy >= side) return null;
    final cell = side / 3;
    return (p.dy ~/ cell) * 3 + (p.dx ~/ cell);
  }

  bool _legal(int cell) {
    final s = _s;
    if (s == null || !widget.props.canMoveFor(s.toMove)) return false;
    return ticTacToeRules.legalMoves(s).contains(cell);
  }

  void _emit(int cell) {
    if (!_legal(cell)) return;
    BoardHaptics.land();
    widget.props.onMove!(ticTacToeRules.encodeMove(cell));
  }

  @override
  Widget build(BuildContext context) {
    final s = _s;
    if (s == null) return const SizedBox.shrink();
    final p = widget.props;
    final l10n = boardL10n(context);
    final line = p.winLine ? ticTacToeRules.winningLine(s) : null;
    final painter = TicTacToePainter(
      cells: s.cells,
      seats: p.seats,
      ink: p.theme.ink,
      fresh: _fresh,
      winLine: line,
      press: _press,
      pressSeat: p.mySeat ?? s.toMove,
      clock: clock,
      // A thumbnail has no mark drawing on to say which was last: a move
      // bubble's board marks it instead.
      marked: p.thumbnail ? int.tryParse(p.lastMove ?? '') : null,
    );
    final canMove = p.canMoveFor(s.toMove);
    return boardSurface(
      props: p,
      painter: painter,
      semantics: BoardSemanticsPainter(
        version: '${p.state}|$canMove',
        nodes: (size) {
          final cell = math.min(size.width, size.height) / 3;
          return [
            for (var i = 0; i < 9; i++)
              boardNode(
                Rect.fromLTWH((i % 3) * cell, (i ~/ 3) * cell, cell, cell),
                '${cellName(l10n, i ~/ 3, i % 3)}, '
                '${[l10n.boardEmpty, 'X', 'O'][s.cells[i]]}',
                onTap: _legal(i) ? () => _emit(i) : null,
              ),
          ];
        },
      ),
      gestures: canMove
          ? (child) => GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTapDown: (d) {
                final c = _cellAt(d.localPosition);
                setState(() => _press = c != null && _legal(c) ? c : null);
              },
              onTapCancel: () => setState(() => _press = null),
              onTapUp: (d) {
                final c = _cellAt(d.localPosition);
                setState(() => _press = null);
                if (c != null) _emit(c);
              },
              child: child,
            )
          : null,
    );
  }
}

/// Paints the grid, the marks, a win strike and the pressed ghost.
class TicTacToePainter extends CustomPainter {
  TicTacToePainter({
    required this.cells,
    required this.seats,
    required this.ink,
    required this.clock,
    this.fresh,
    this.winLine,
    this.press,
    this.pressSeat = 0,
    this.marked,
  }) : super(repaint: clock.animation);

  final List<int> cells;
  final SeatPalette seats;
  final Color ink;
  final BoardClock clock;
  final int? fresh;
  final List<int>? winLine;
  final int? press;
  final int pressSeat;

  /// The last move's cell, washed in its mark's colour.
  final int? marked;

  @override
  void paint(Canvas canvas, Size size) {
    final side = math.min(size.width, size.height);
    final cell = side / 3;

    final m = marked;
    if (m != null && m >= 0 && m < 9 && cells[m] != 0) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH((m % 3) * cell, (m ~/ 3) * cell, cell, cell)
              .deflate(cell * 0.08),
          Radius.circular(cell * 0.18),
        ),
        Paint()..color = seats.wash(cells[m] - 1),
      );
    }

    // The grid: four interior lines, no frame. A frame turns the board into a
    // box on the card; four lines alone are the game everyone draws on paper.
    final grid = Paint()
      ..color = ink.withValues(alpha: 0.16)
      ..strokeWidth = math.max(1.5, side * 0.016)
      ..strokeCap = StrokeCap.round;
    final a = side * 0.04;
    final b = side * 0.96;
    for (var i = 1; i < 3; i++) {
      final o = cell * i;
      canvas.drawLine(Offset(o, a), Offset(o, b), grid);
      canvas.drawLine(Offset(a, o), Offset(b, o), grid);
    }

    final markT = easeOutCubic(clock.phase(0, _markMs));
    final strikeT = easeInOutCubic(clock.phase(_markMs * 0.85, _strikeMs));
    final line = winLine;
    final mark = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = cell * 0.11
      ..strokeCap = StrokeCap.round;

    for (var i = 0; i < 9; i++) {
      final v = cells[i];
      if (v == 0) continue;
      final inLine = line != null && line.contains(i);
      // The rest of the board steps back while the winning three are struck.
      final alpha = line == null || inLine ? 1.0 : 1 - 0.65 * strikeT;
      mark.color = seats.fill(v - 1).withValues(alpha: alpha);
      _mark(canvas, v - 1, _center(i, cell), cell, i == fresh ? markT : 1, mark);
    }

    if (press != null && cells[press!] == 0) {
      mark.color = seats.ghost(pressSeat);
      _mark(canvas, pressSeat, _center(press!, cell), cell, 1, mark);
    }

    if (line != null && strikeT > 0) {
      final from = _center(line.first, cell);
      final to = _center(line.last, cell);
      final dir = (to - from) / (to - from).distance;
      final start = from - dir * (cell * 0.34);
      final end = to + dir * (cell * 0.34);
      final strike = Paint()
        ..color = seats.fill(cells[line.first] - 1)
        ..strokeWidth = cell * 0.085
        ..strokeCap = StrokeCap.round;
      canvas.drawLine(start, Offset.lerp(start, end, strikeT)!, strike);
    }
  }

  static Offset _center(int i, double cell) =>
      Offset((i % 3 + 0.5) * cell, (i ~/ 3 + 0.5) * cell);

  /// X is two strokes, the second following the first; O is one ring drawn
  /// clockwise from twelve. Partial strokes are lerped endpoints and an arc
  /// sweep rather than `PathMetric.extractPath`: the same picture, without
  /// allocating a path per frame.
  static void _mark(
    Canvas canvas,
    int seat,
    Offset c,
    double cell,
    double t,
    Paint paint,
  ) {
    if (t <= 0) return;
    if (seat == 0) {
      final r = cell * 0.22;
      final t1 = (t * 2).clamp(0.0, 1.0);
      final t2 = (t * 2 - 1).clamp(0.0, 1.0);
      final a = c + Offset(-r, -r);
      canvas.drawLine(a, Offset.lerp(a, c + Offset(r, r), t1)!, paint);
      if (t2 > 0) {
        final b = c + Offset(r, -r);
        canvas.drawLine(b, Offset.lerp(b, c + Offset(-r, r), t2)!, paint);
      }
    } else {
      final r = cell * 0.235;
      if (t >= 1) {
        canvas.drawCircle(c, r, paint);
      } else {
        canvas.drawArc(
          Rect.fromCircle(center: c, radius: r),
          -math.pi / 2,
          math.pi * 2 * t,
          false,
          paint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(TicTacToePainter old) =>
      old.cells != cells ||
      old.seats != seats ||
      old.ink != ink ||
      old.fresh != fresh ||
      old.winLine != winLine ||
      old.press != press ||
      old.pressSeat != pressSeat ||
      old.marked != marked ||
      old.clock.animation != clock.animation ||
      old.clock.totalMs != clock.totalMs;
}
