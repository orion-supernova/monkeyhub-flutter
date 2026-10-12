import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import '../../theme/app_theme.dart';
import '../connect_four.dart';
import 'board_kit.dart';
import 'seat_palette.dart';

const int _cols = connectFourCols;
const int _rows = connectFourRows;

/// The settle after a disc lands: one small rebound, then rest.
const double _settleMs = 170;

/// After the last disc of a four lands, the four are ringed.
const double _winFadeMs = 280;

/// How long a disc takes to fall to [row] from the lane above the slab:
/// roughly the square root of the distance, as a real fall is, with a floor
/// so a disc landing in the top row still visibly drops.
double _fallMs(int row) => 95 + 150 * math.sqrt((row + 1) / _rows);

/// Where everything on a Connect Four board sits.
///
/// The playable board reserves a lane one cell tall above the slab for the
/// disc in hand to hover in, which makes it square; a thumbnail has no hand
/// and drops the lane, and is 7:6.
class ConnectFourGeometry {
  factory ConnectFourGeometry(Size size, {required bool lane}) {
    final rows = _rows + (lane ? 1 : 0);
    final cell = math.min(size.width / _cols, size.height / rows);
    return ConnectFourGeometry._(cell, lane ? cell : 0);
  }

  const ConnectFourGeometry._(this.cell, this.laneHeight);

  final double cell;
  final double laneHeight;

  Rect get slab => Rect.fromLTWH(0, laneHeight, cell * _cols, cell * _rows);

  Offset hole(int row, int col) =>
      Offset((col + 0.5) * cell, laneHeight + (row + 0.5) * cell);

  /// Where a disc in hand hovers over [col].
  Offset hover(int col) => Offset(
    (col + 0.5) * cell,
    laneHeight > 0 ? laneHeight * 0.5 : -cell * 0.5,
  );

  double get holeRadius => cell * 0.385;
  double get discRadius => cell * 0.37;

  int? columnAt(Offset p) {
    if (cell <= 0 || p.dx < 0 || p.dx >= cell * _cols) return null;
    return (p.dx / cell).floor().clamp(0, _cols - 1);
  }

  static double aspect({required bool lane}) => _cols / (_rows + (lane ? 1 : 0));
}

/// Connect Four: discs drop behind a slab with 42 holes.
class ConnectFourBoardView extends BoardView {
  const ConnectFourBoardView({super.key, required super.props});

  @override
  State<ConnectFourBoardView> createState() => _ConnectFourBoardState();
}

class _ConnectFourBoardState extends BoardViewState<ConnectFourBoardView> {
  ConnectFourState? _s;

  /// The cell index of the disc that is falling, if any.
  int? _fresh;

  /// The column a finger is over, while it is down.
  int? _hover;

  @override
  void initState() {
    super.initState();
    _s = _decode(widget.props.state);
  }

  static ConnectFourState? _decode(String raw) {
    try {
      return connectFourRules.decode(raw);
    } on FormatException {
      return null;
    }
  }

  @override
  void didUpdateWidget(ConnectFourBoardView old) {
    super.didUpdateWidget(old);
    if (old.props.state == widget.props.state) return;
    final before = _s;
    final next = _decode(widget.props.state);
    if (next == null) return;
    _s = next;
    _fresh = null;
    _hover = null;
    if (before == null) return;
    int? added;
    var changes = 0;
    for (var i = 0; i < next.cells.length; i++) {
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
    final fall = _fallMs(added ~/ _cols);
    final won = next.result == 0 || next.result == 1;
    play(fall + _settleMs + (won && widget.props.winLine ? _winFadeMs : 0));
    // The landing is felt only for the viewer's own disc: a buzz when the
    // other player's move arrives would be a notification nobody asked for.
    final seat = next.cells[added] - 1;
    if (widget.props.mySeat == seat) at(fall, BoardHaptics.land);
  }

  ConnectFourGeometry _geometry() {
    final box = context.findRenderObject() as RenderBox?;
    return ConnectFourGeometry(box?.size ?? Size.zero, lane: true);
  }

  bool _legal(int col) {
    final s = _s;
    if (s == null || !widget.props.canMoveFor(s.toMove)) return false;
    return connectFourRules.legalMoves(s).contains(col);
  }

  void _hoverAt(Offset p) {
    final col = _geometry().columnAt(p);
    final next = col != null && _legal(col) ? col : null;
    if (next == _hover) return;
    if (next != null && _hover != null) BoardHaptics.tick();
    setState(() => _hover = next);
  }

  void _drop() {
    final col = _hover;
    setState(() => _hover = null);
    if (col != null) _emit(col);
  }

  void _emit(int col) {
    if (!_legal(col)) return;
    widget.props.onMove!(connectFourRules.encodeMove(col));
  }

  @override
  Widget build(BuildContext context) {
    final s = _s;
    if (s == null) return const SizedBox.shrink();
    final p = widget.props;
    final l10n = boardL10n(context);
    final won = s.result == 0 || s.result == 1;
    final canMove = p.canMoveFor(s.toMove);
    final painter = ConnectFourPainter(
      cells: s.cells,
      seats: p.seats,
      theme: p.theme,
      lane: !p.thumbnail,
      fresh: _fresh,
      winning: won && p.winLine ? connectFourRules.winningCells(s) : null,
      hover: _hover,
      hoverSeat: p.mySeat ?? s.toMove,
      highContrast: p.highContrast,
      clock: clock,
    );
    return boardSurface(
      props: p,
      painter: painter,
      semantics: BoardSemanticsPainter(
        version: '${p.state}|$canMove',
        nodes: (size) {
          final g = ConnectFourGeometry(size, lane: true);
          return [
            for (var c = 0; c < _cols; c++)
              boardNode(
                Rect.fromLTWH(c * g.cell, 0, g.cell, g.laneHeight + g.slab.height),
                l10n.boardColumnFilled(c + 1, _fill(s, c), _rows),
                onTap: _legal(c) ? () => _emit(c) : null,
              ),
          ];
        },
      ),
      gestures: canMove
          ? (child) => GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTapDown: (d) => _hoverAt(d.localPosition),
              onTapUp: (d) {
                _hoverAt(d.localPosition);
                _drop();
              },
              onTapCancel: () {
                // A horizontal drag that wins the arena cancels the tap; the
                // drag carries the hover on from here.
              },
              onHorizontalDragStart: (d) => _hoverAt(d.localPosition),
              onHorizontalDragUpdate: (d) => _hoverAt(d.localPosition),
              onHorizontalDragEnd: (_) => _drop(),
              onHorizontalDragCancel: () => setState(() => _hover = null),
              child: child,
            )
          : null,
    );
  }

  static int _fill(ConnectFourState s, int col) {
    var n = 0;
    for (var r = 0; r < _rows; r++) {
      if (s.cells[r * _cols + col] != 0) n++;
    }
    return n;
  }
}

/// The slab: a rounded plate with 42 even-odd holes, cached per size so the
/// path is built once rather than every frame a disc is falling.
final _slabs = SizeCache<(Path, Path)>((size) {
  // The key is the geometry's own extent: square with the lane, 7:6 without.
  final lane = size.height > size.width * _rows / _cols + 0.5;
  final g = ConnectFourGeometry(size, lane: lane);
  final slab = g.slab;
  final plate = Path()
    ..fillType = PathFillType.evenOdd
    ..addRRect(RRect.fromRectAndRadius(slab, Radius.circular(g.cell * 0.26)));
  final rims = Path();
  for (var r = 0; r < _rows; r++) {
    for (var c = 0; c < _cols; c++) {
      final hole = Rect.fromCircle(center: g.hole(r, c), radius: g.holeRadius);
      plate.addOval(hole);
      rims.addOval(hole);
    }
  }
  return (plate, rims);
});

/// Paints the well, the discs, the slab over them, and the disc in hand.
class ConnectFourPainter extends CustomPainter {
  ConnectFourPainter({
    required this.cells,
    required this.seats,
    required this.theme,
    required this.lane,
    required this.clock,
    this.fresh,
    this.winning,
    this.hover,
    this.hoverSeat = 0,
    this.highContrast = false,
  }) : super(repaint: clock.animation);

  final List<int> cells;
  final SeatPalette seats;
  final AppTheme theme;
  final bool lane;
  final BoardClock clock;
  final int? fresh;
  final List<int>? winning;
  final int? hover;
  final int hoverSeat;
  final bool highContrast;

  /// The slab's colour: a deep, theme-lit azure, the toy's blue. Neither
  /// seat is azure in this game (coral and amber), so the slab never reads
  /// as a third player.
  Color _slabColor(bool dark) =>
      HSLColor.fromAHSL(1, 214, dark ? 0.46 : 0.62, dark ? 0.36 : 0.50).toColor();

  @override
  void paint(Canvas canvas, Size size) {
    final g = ConnectFourGeometry(size, lane: lane);
    if (g.cell <= 0) return;
    // Key the cache by the size the geometry actually uses, so a board laid
    // out a fraction of a pixel off square still hits.
    final key = Size(g.cell * _cols, g.laneHeight + g.cell * _rows);
    final (plate, rims) = _slabs.of(key);
    final dark = seats.dark;

    // The well behind the holes: the slab's own blue, deep in shadow, so an
    // empty hole is a recess in the plate rather than a window onto
    // whatever the card is drawn over.
    final slabColor = _slabColor(dark);
    final slabHsl = HSLColor.fromColor(slabColor);
    final well = Paint()
      ..color = slabHsl.withLightness(slabHsl.lightness * (dark ? 0.42 : 0.55)).toColor();
    canvas.drawRRect(
      RRect.fromRectAndRadius(g.slab.deflate(g.cell * 0.06), Radius.circular(g.cell * 0.2)),
      well,
    );

    final ms = clock.ms;
    final fall = fresh == null ? 0.0 : _fallMs(fresh! ~/ _cols);
    final win = winning;
    final fade = win == null ? 0.0 : clock.phase(fall + _settleMs * 0.6, _winFadeMs);

    final disc = Paint();
    final rim = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = g.discRadius * 0.14;
    for (var i = 0; i < cells.length; i++) {
      final v = cells[i];
      if (v == 0) continue;
      final row = i ~/ _cols;
      final col = i % _cols;
      var at = g.hole(row, col);
      if (i == fresh && ms != double.infinity) {
        at = _falling(g, row, col, ms, fall);
      }
      // Losing discs keep their colour: dimmed, they let the well through and
      // turn amber to olive. The rings on the four carry the result.
      _disc(canvas, g, at, v - 1, 1, disc, rim);
    }

    // The ghost of the landing spot, under the slab like a real disc.
    final h = hover;
    if (h != null) {
      var r = _rows - 1;
      while (r >= 0 && cells[r * _cols + h] != 0) {
        r--;
      }
      if (r >= 0) {
        canvas.drawCircle(g.hole(r, h), g.discRadius, Paint()..color = seats.ghost(hoverSeat));
      }
    }

    canvas.drawPath(plate, Paint()..color = slabColor);
    // A hairline lip inside each hole: the slab has thickness.
    canvas.drawPath(
      rims,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = math.max(1, g.cell * 0.035)
        ..color = const Color(0xFF000000).withValues(alpha: 0.18),
    );

    // The winning four get a ring on top of the slab, so the line reads even
    // where the slab half-covers a disc.
    if (win != null && fade > 0) {
      final ring = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = math.max(1.5, g.cell * 0.06);
      for (final i in win) {
        ring.color = seats.ink(cells[i] - 1).withValues(alpha: 0.9 * fade);
        canvas.drawCircle(g.hole(i ~/ _cols, i % _cols), g.discRadius * 0.62, ring);
      }
    }

    // The disc in hand, over the lane.
    if (h != null && lane) {
      _disc(canvas, g, g.hover(h), hoverSeat, 1, disc, rim);
    }
  }

  /// A falling disc's centre: an ease-in drop from the lane, then one small
  /// rebound that settles. Deliberately not `bounceOut` — a disc that bounces
  /// three times is a rubber ball, not a counter in a slot.
  Offset _falling(ConnectFourGeometry g, int row, int col, double ms, double fall) {
    final end = g.hole(row, col);
    final start = g.hover(col);
    if (ms < fall) {
      final t = easeInQuad((ms / fall).clamp(0.0, 1.0));
      return Offset(end.dx, start.dy + (end.dy - start.dy) * t);
    }
    final u = ((ms - fall) / _settleMs).clamp(0.0, 1.0);
    final lift = g.cell * 0.07 * math.sin(math.pi * u) * (1 - u * 0.4);
    return Offset(end.dx, end.dy - lift);
  }

  void _disc(
    Canvas canvas,
    ConnectFourGeometry g,
    Offset at,
    int seat,
    double alpha,
    Paint disc,
    Paint rim,
  ) {
    final r = g.discRadius;
    disc.color = seats.fill(seat).withValues(alpha: alpha);
    canvas.drawCircle(at, r, disc);
    // An inner groove, as the plastic counters have: depth without a shader.
    rim.color = seats.rim(seat).withValues(alpha: 0.55 * alpha);
    canvas.drawCircle(at, r * 0.72, rim);
    if (highContrast && seat == 1) {
      disc.color = seats.ink(seat).withValues(alpha: alpha);
      canvas.drawCircle(at, r * 0.2, disc);
    }
  }

  @override
  bool shouldRepaint(ConnectFourPainter old) =>
      old.cells != cells ||
      old.seats != seats ||
      old.theme != theme ||
      old.lane != lane ||
      old.fresh != fresh ||
      old.winning != winning ||
      old.hover != hover ||
      old.hoverSeat != hoverSeat ||
      old.highContrast != highContrast ||
      old.clock.animation != clock.animation ||
      old.clock.totalMs != clock.totalMs;
}
