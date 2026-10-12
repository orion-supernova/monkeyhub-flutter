import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';

import '../../theme/app_theme.dart';
import '../reversi.dart';
import '../turn_rules.dart';
import 'board_kit.dart';
import 'seat_palette.dart';

/// The placed disc settles in, then flips ripple outward from it, one ring of
/// squares every [_strideMs]. A flip is a coin turning over: it narrows to an
/// edge, changes colour out of sight, and widens again.
const double _placeMs = 150;
const double _firstFlipMs = 70;
const double _strideMs = 40;
const double _flipMs = 280;

/// Reversi on a felt that is lit by the theme rather than printed on it.
class ReversiBoardView extends BoardView {
  const ReversiBoardView({super.key, required super.props});

  @override
  State<ReversiBoardView> createState() => _ReversiBoardState();
}

class _ReversiBoardState extends BoardViewState<ReversiBoardView> {
  ReversiState? _s;
  int? _placed;

  /// Flipped cells mapped to their ring distance from [_placed].
  Map<int, int> _flips = const {};

  int? _press;

  @override
  void initState() {
    super.initState();
    _s = _decode(widget.props.state);
  }

  static ReversiState? _decode(String raw) {
    try {
      return reversiRules.decode(raw);
    } on FormatException {
      return null;
    }
  }

  @override
  void didUpdateWidget(ReversiBoardView old) {
    super.didUpdateWidget(old);
    if (old.props.state == widget.props.state) return;
    final before = _s;
    final next = _decode(widget.props.state);
    if (next == null) return;
    _s = next;
    _placed = null;
    _flips = const {};
    _press = null;
    if (before == null) return;
    int? placed;
    var placedCount = 0;
    final flipped = <int>[];
    for (var i = 0; i < 64; i++) {
      final a = before.cells[i];
      final b = next.cells[i];
      if (a == b) continue;
      if (a == 0) {
        placed = i;
        placedCount++;
      } else if (b != 0) {
        flipped.add(i);
      } else {
        placedCount = 99; // a disc vanished: not a move, a reset
      }
    }
    if (placedCount != 1 || placed == null) {
      play(0);
      return;
    }
    _placed = placed;
    var far = 0;
    final rings = <int, int>{};
    for (final i in flipped) {
      final d = math.max(((i >> 3) - (placed >> 3)).abs(), ((i & 7) - (placed & 7)).abs());
      rings[i] = d;
      far = math.max(far, d);
    }
    _flips = rings;
    play(flipped.isEmpty
        ? _placeMs
        : _firstFlipMs + _strideMs * (far - 1) + _flipMs);
  }

  int? _cellAt(Offset p) {
    final box = context.findRenderObject() as RenderBox?;
    if (box == null) return null;
    final side = math.min(box.size.width, box.size.height);
    if (p.dx < 0 || p.dy < 0 || p.dx >= side || p.dy >= side) return null;
    final cell = side / 8;
    return (p.dy ~/ cell) * 8 + (p.dx ~/ cell);
  }

  bool _legal(int cell) {
    final s = _s;
    if (s == null || !widget.props.canMoveFor(s.toMove)) return false;
    return reversiRules.legalMoves(s).contains(cell);
  }

  void _emit(int cell) {
    if (!_legal(cell)) return;
    BoardHaptics.land();
    widget.props.onMove!(reversiRules.encodeMove(cell));
  }

  int? _lastCell() {
    final raw = widget.props.lastMove;
    if (raw == null) return _placed;
    try {
      final v = reversiRules.decodeMove(raw);
      return v >= 0 && v < 64 ? v : null;
    } on IllegalMove {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = _s;
    if (s == null) return const SizedBox.shrink();
    final p = widget.props;
    final l10n = boardL10n(context);
    final canMove = p.canMoveFor(s.toMove);
    final names = [l10n.boardEmpty, l10n.boardBlack, l10n.boardWhite];
    return boardSurface(
      props: p,
      painter: ReversiPainter(
        cells: s.cells,
        seats: p.seats,
        theme: p.theme,
        hints: canMove ? s.moves : const [],
        hintSeat: s.toMove,
        placed: _placed,
        flips: _flips,
        last: p.thumbnail ? null : _lastCell(),
        press: _press,
        clock: clock,
      ),
      semantics: BoardSemanticsPainter(
        version: '${p.state}|$canMove',
        nodes: (size) {
          final cell = math.min(size.width, size.height) / 8;
          return [
            for (var i = 0; i < 64; i++)
              boardNode(
                Rect.fromLTWH((i & 7) * cell, (i >> 3) * cell, cell, cell),
                '${cellName(l10n, i >> 3, i & 7)}, ${names[s.cells[i]]}'
                '${_legal(i) ? ', ${l10n.boardLegalMove}' : ''}',
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

/// Felt, grid, the cached grid path and the two disc shaders, per size.
class _ReversiArt {
  _ReversiArt(Size size) : side = math.min(size.width, size.height) {
    final cell = side / 8;
    for (var i = 1; i < 8; i++) {
      grid
        ..moveTo(i * cell, 0)
        ..lineTo(i * cell, side)
        ..moveTo(0, i * cell)
        ..lineTo(side, i * cell);
    }
    radius = cell * 0.41;
    light = discLight(radius, highlight: 0.34, shade: 0.16);
    shadow = discShadow(radius, alpha: 0.38);
  }

  final double side;
  final Path grid = Path();
  late final double radius;
  late final ui.Shader light;
  late final ui.Shader shadow;
}

final _art = SizeCache<_ReversiArt>(_ReversiArt.new);

/// Paints the felt, the discs and their flips, the legal-move hints.
class ReversiPainter extends CustomPainter {
  ReversiPainter({
    required this.cells,
    required this.seats,
    required this.theme,
    required this.clock,
    this.hints = const [],
    this.hintSeat = 0,
    this.placed,
    this.flips = const {},
    this.last,
    this.press,
  }) : super(repaint: clock.animation);

  final List<int> cells;
  final SeatPalette seats;
  final AppTheme theme;
  final BoardClock clock;

  /// Legal cells for the side to move, shown only when the viewer may play.
  final List<int> hints;
  final int hintSeat;
  final int? placed;
  final Map<int, int> flips;

  /// The last move's cell, marked with a small dot.
  final int? last;
  final int? press;

  @override
  void paint(Canvas canvas, Size size) {
    final side = math.min(size.width, size.height);
    if (side <= 0) return;
    final art = _art.of(Size.square(side));
    final cell = side / 8;
    final dark = seats.dark;

    final felt = HSLColor.fromAHSL(1, 150, dark ? 0.26 : 0.34, dark ? 0.20 : 0.34).toColor();
    final board = RRect.fromRectAndRadius(Offset.zero & Size.square(side), Radius.circular(side * 0.035));
    canvas.save();
    canvas.clipRRect(board);
    canvas.drawRect(Offset.zero & Size.square(side), Paint()..color = felt);
    canvas.drawPath(
      art.grid,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = math.max(1, side * 0.0035)
        ..color = const Color(0xFF000000).withValues(alpha: 0.28),
    );
    final star = Paint()..color = const Color(0xFF000000).withValues(alpha: 0.42);
    for (final (r, c) in const [(2, 2), (2, 6), (6, 2), (6, 6)]) {
      canvas.drawCircle(Offset(c * cell, r * cell), math.max(1.6, side * 0.009), star);
    }

    final hint = Paint();
    for (final i in hints) {
      if (cells[i] != 0) continue;
      hint.color = seats.fill(hintSeat).withValues(alpha: i == press ? 0.55 : 0.3);
      canvas.drawCircle(_center(i, cell), i == press ? art.radius : cell * 0.13, hint);
    }

    final fill = Paint();
    final light = Paint()..shader = art.light;
    final shadow = Paint()..shader = art.shadow;
    final edge = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(0.75, art.radius * 0.05)
      ..color = const Color(0xFF000000).withValues(alpha: 0.22);

    for (var i = 0; i < 64; i++) {
      final v = cells[i];
      if (v == 0) continue;
      var seat = v - 1;
      var scaleX = 1.0;
      var scale = 1.0;
      var lift = 0.0;
      if (i == placed) {
        final t = easeOutCubic(clock.phase(0, _placeMs));
        scale = 0.82 + 0.18 * t;
        if (t <= 0) continue;
      } else {
        final ring = flips[i];
        if (ring != null) {
          final t = clock.phase(_firstFlipMs + _strideMs * (ring - 1), _flipMs);
          // Narrow to an edge, swap faces out of sight, widen again.
          final e = easeInOutCubic(t);
          scaleX = math.cos(math.pi * e).abs();
          if (e < 0.5) seat = 1 - seat;
          lift = math.sin(math.pi * e) * art.radius * 0.14;
        }
      }
      canvas.save();
      canvas.translate((i % 8 + 0.5) * cell, (i ~/ 8 + 0.5) * cell - lift);
      if (scale != 1) canvas.scale(scale);
      canvas.drawCircle(Offset(0, lift), art.radius, shadow);
      if (scaleX != 1) canvas.scale(math.max(scaleX, 0.04), 1);
      fill.color = seats.fill(seat);
      canvas.drawCircle(Offset.zero, art.radius, fill);
      canvas.drawCircle(Offset.zero, art.radius, light);
      canvas.drawCircle(Offset.zero, art.radius, edge);
      canvas.restore();
    }

    final mark = last;
    if (mark != null && cells[mark] != 0) {
      canvas.drawCircle(
        _center(mark, cell),
        math.max(1.8, art.radius * 0.16),
        Paint()..color = theme.danger,
      );
    }
    canvas.restore();
  }

  static Offset _center(int i, double cell) =>
      Offset((i % 8 + 0.5) * cell, (i ~/ 8 + 0.5) * cell);

  @override
  bool shouldRepaint(ReversiPainter old) =>
      old.cells != cells ||
      old.seats != seats ||
      old.theme != theme ||
      old.hints != hints ||
      old.hintSeat != hintSeat ||
      old.placed != placed ||
      old.flips != flips ||
      old.last != last ||
      old.press != press ||
      old.clock.animation != clock.animation ||
      old.clock.totalMs != clock.totalMs;
}
