/// Shared drawing kit for the daily-game boards.
///
/// All of them are painted rather than built out of widgets, and that is a
/// deliberate choice rather than a shortcut. A 6×6 grid is thirty-six widgets
/// before you count the sixty edges Tango prints operators on, the region
/// borders Queens needs drawn *between* cells rather than around them, and the
/// single continuous stroke Zip is. Two of those four are simply not
/// expressible as a box per cell — a region outline belongs to the boundary
/// between two cells and a path belongs to no cell at all — and the other two
/// would rebuild the whole grid on every tap.
///
/// One painter per board also means the hub can render the *real* board, small
/// and inert, from the same code that draws the playable one. The tiles on the
/// hub are today's actual puzzles, not four generic icons.
library;

import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';

import '../theme/app_theme.dart';

/// Where the cells of an `n`×`n` board are, inside a square of [side].
///
/// One object rather than arithmetic sprinkled through four painters and four
/// hit-tests. The hit-test in particular has to agree with the paint to the
/// pixel: a board that lights the cell above the one your finger is on is
/// unusable in a way no amount of visual polish recovers from.
class GameGrid {
  GameGrid({required this.side, required this.n, this.inset = 0, this.lead = 0});

  /// Length of the square the board is drawn into.
  final double side;

  /// Cells per row and per column.
  final int n;

  /// Padding inside [side], so a board can leave room for a border or a glow
  /// without every caller adjusting its own coordinates.
  final double inset;

  /// Extra room on the LEFT and TOP only, for a board that prints something
  /// beside its rows and above its columns — Nonogram's clues. The cells fill
  /// what is left, still square, flush with the right and bottom edges.
  final double lead;

  double get cell => (side - inset * 2 - lead) / n;

  Offset origin(int index) => Offset(
    inset + lead + (index % n) * cell,
    inset + lead + (index ~/ n) * cell,
  );

  Rect rect(int index) => origin(index) & Size(cell, cell);

  Offset center(int index) =>
      origin(index) + Offset(cell / 2, cell / 2);

  /// The cell under [point], or null if it is outside the board.
  ///
  /// [slack] widens the board by that many pixels on every side and folds
  /// whatever lands in the margin back onto the edge cell beside it — a finger
  /// that has slid a hair past the last column is obviously still aiming at
  /// the last column, and going dead there makes the edge of a board feel
  /// broken mid-stroke. Zero, the default, is the strict reading a tap wants:
  /// the gesture surface is wider than the square it paints, and a tap in the
  /// gutter beside the board is a tap on nothing.
  int? hit(Offset point, {double slack = 0}) {
    if (cell <= 0) return null;
    final x = point.dx - inset - lead;
    final y = point.dy - inset - lead;
    final span = cell * n;
    if (x < -slack || y < -slack || x >= span + slack || y >= span + slack) {
      return null;
    }
    final col = (x / cell).floor().clamp(0, n - 1);
    final row = (y / cell).floor().clamp(0, n - 1);
    return row * n + col;
  }
}

/// A painted board plus the gestures that reach it.
///
/// One gesture detector over the whole grid rather than a hit target per cell.
/// The geometry that decides where a cell is *drawn* is then, by construction,
/// the geometry that decides what a finger *landed on* — which is the only way
/// to be sure a board never lights the square above the one being touched. It
/// also makes Zip possible at all: a drag that crosses thirty cells is one
/// gesture, and per-cell detectors would each claim their own slice of it.
class GameBoardSurface extends StatefulWidget {
  const GameBoardSurface({
    super.key,
    required this.painter,
    required this.n,
    this.onTapCell,
    this.onLongPressCell,
    this.onDragStart,
    this.onDragTo,
    this.onDragEnd,
    this.claimsDrag = true,
    this.leadFraction = 0,
  });

  final CustomPainter painter;

  /// Cells per side. Zero renders nothing — the board has not arrived yet.
  final int n;

  final void Function(int index)? onTapCell;

  /// A press held on one cell. Minesweeper's flag: the gesture every phone
  /// minesweeper uses, so a player never has to reach for a mode switch
  /// between two taps.
  final void Function(int index)? onLongPressCell;

  /// How much of the square is given to a clue gutter on the left and top, as
  /// a fraction of its side — see [GameGrid.lead]. Zero for every board but
  /// Nonogram, and the painter must be handed the same figure so the cells it
  /// draws are the cells a finger lands on.
  final double leadFraction;

  /// Called once when a drag begins, before the first [onDragTo]. Zip uses it
  /// to mark where the stroke started so one gesture is one undo step.
  final VoidCallback? onDragStart;

  /// Called for every cell a drag passes over, including the one it starts on.
  final void Function(int index)? onDragTo;

  final VoidCallback? onDragEnd;

  /// Whether a drag that starts on the board belongs to the board — see
  /// [_BoardPanGestureRecognizer]. False hands drags straight back to the
  /// scroll view, which is what a finished or paused board wants: there is
  /// nothing left to draw, and a square of dead scroll in the middle of the
  /// page is worse than nothing.
  ///
  /// Ignored when [onDragTo] is null; a tap-only board never enters the arena
  /// against the page in the first place.
  final bool claimsDrag;

  @override
  State<GameBoardSurface> createState() => _GameBoardSurfaceState();
}

class _GameBoardSurfaceState extends State<GameBoardSurface> {
  /// Where the finger was at the last sample and which cell that sample landed
  /// in — between them, the two things needed to fill in the cells a fast drag
  /// skated over. Both null between gestures.
  Offset? _previous;
  int? _entered;

  void _startDrag(GameGrid grid, Offset at) {
    _previous = null;
    _entered = null;
    widget.onDragStart?.call();
    _extend(grid, at);
  }

  void _endDrag() {
    _previous = null;
    _entered = null;
    widget.onDragEnd?.call();
  }

  /// Walks the board from the previous sample to [at], handing every cell the
  /// line crosses to [GameBoardSurface.onDragTo] in order.
  ///
  /// A pointer reports where it *is*, not where it has *been*, and at the speed
  /// a finger actually moves the gap between two reports is several cells wide.
  /// A board that only looked at the endpoints would ask Zip to jump three
  /// squares at once — which the rules refuse, so the line stops following the
  /// finger and the drag reads as broken. Sampling the segment at a third of a
  /// cell is fine enough that no cell is stepped over.
  void _extend(GameGrid grid, Offset at) {
    final slack = grid.cell;
    if (grid.hit(at, slack: slack) == null) {
      // The finger has wandered clear of the board. Drop the trail rather than
      // drawing the shortcut it would cut coming back in on the far side.
      _previous = null;
      return;
    }
    final from = _previous ?? at;
    _previous = at;
    final steps = ((at - from).distance / (grid.cell / 3)).ceil().clamp(1, 120);
    for (var i = 1; i <= steps; i++) {
      _enter(grid, Offset.lerp(from, at, i / steps)!, slack);
    }
  }

  void _enter(GameGrid grid, Offset point, double slack) {
    final cell = grid.hit(point, slack: slack);
    if (cell == null || cell == _entered) return;
    final previous = _entered;
    _entered = cell;
    if (previous != null) {
      // Two samples either side of a lattice corner land on cells that touch
      // only at that corner, and a line Zip will accept never moves
      // diagonally. Offer both ways round the corner: they are diagonal to
      // *each other*, so at most one of them can be taken, and the board is
      // then adjacent to whichever was.
      final dRow = cell ~/ grid.n - previous ~/ grid.n;
      final dCol = cell % grid.n - previous % grid.n;
      if (dRow.abs() == 1 && dCol.abs() == 1) {
        widget.onDragTo!(previous + dCol);
        widget.onDragTo!(previous + dRow * grid.n);
      }
    }
    widget.onDragTo!(cell);
  }

  @override
  Widget build(BuildContext context) {
    if (widget.n == 0) return const SizedBox.shrink();
    return LayoutBuilder(
      builder: (context, constraints) {
        final side = constraints.biggest.shortestSide;
        final grid = GameGrid(
          side: side,
          n: widget.n,
          lead: side * widget.leadFraction,
        );
        final draggable = widget.onDragTo != null && widget.claimsDrag;

        return RawGestureDetector(
          behavior: HitTestBehavior.opaque,
          gestures: <Type, GestureRecognizerFactory>{
            if (widget.onTapCell != null)
              TapGestureRecognizer:
                  GestureRecognizerFactoryWithHandlers<TapGestureRecognizer>(
                    () => TapGestureRecognizer(debugOwner: this),
                    (recognizer) => recognizer.onTapUp = (details) {
                      final cell = grid.hit(details.localPosition);
                      if (cell != null) widget.onTapCell!(cell);
                    },
                  ),
            if (widget.onLongPressCell != null)
              LongPressGestureRecognizer:
                  GestureRecognizerFactoryWithHandlers<
                    LongPressGestureRecognizer
                  >(
                    () => LongPressGestureRecognizer(debugOwner: this),
                    (recognizer) => recognizer.onLongPressStart = (details) {
                      final cell = grid.hit(details.localPosition);
                      if (cell != null) widget.onLongPressCell!(cell);
                    },
                  ),
            if (draggable)
              _BoardPanGestureRecognizer:
                  GestureRecognizerFactoryWithHandlers<
                    _BoardPanGestureRecognizer
                  >(
                    () => _BoardPanGestureRecognizer(debugOwner: this),
                    (recognizer) {
                      recognizer
                        // The first cell is the one under the finger when it
                        // landed, not the one it had drifted to by the pixel
                        // the arena was settled in.
                        ..dragStartBehavior = DragStartBehavior.down
                        ..onStart = (d) {
                          _startDrag(grid, d.localPosition);
                        }
                        ..onUpdate = (d) {
                          _extend(grid, d.localPosition);
                        }
                        ..onEnd = (_) {
                          _endDrag();
                        }
                        ..onCancel = _endDrag;
                    },
                  ),
          },
          child: CustomPaint(painter: widget.painter, size: Size.square(side)),
        );
      },
    );
  }
}

/// A pan that claims the gesture on the first pixel of movement.
///
/// The board sits inside the game screen's scroll view, and the stock
/// [PanGestureRecognizer] only claims a drag once it has travelled [kPanSlop] —
/// twice the [kTouchSlop] at which the enclosing [Scrollable] claims a vertical
/// one. Left at those numbers the arithmetic is fatal for Zip: a stroke drawn
/// *downward* never starts at all, because the page wins it at 18 pixels and
/// scrolls instead, and a stroke drawn sideways only starts once the finger has
/// crossed most of a cell. "The board is hard to draw on" is that subtraction,
/// not the game.
///
/// So on the one board that is drawn rather than tapped, a drag that begins on
/// the board belongs to the board. The page keeps every other inch of itself —
/// header, tools, standings — to scroll by, and a board with nothing left to
/// draw hands drags back entirely (see [GameBoardSurface.claimsDrag]).
///
/// Trackpads are the exception: a two-finger scroll over the board is somebody
/// reading the page, never somebody drawing on it, so those keep the stock slop
/// and lose the arena to the scroll view as before.
class _BoardPanGestureRecognizer extends PanGestureRecognizer {
  _BoardPanGestureRecognizer({super.debugOwner});

  @override
  bool hasSufficientGlobalDistanceToAccept(
    PointerDeviceKind pointerDeviceKind,
    double? deviceTouchSlop,
  ) {
    if (pointerDeviceKind == PointerDeviceKind.trackpad) {
      return super.hasSufficientGlobalDistanceToAccept(
        pointerDeviceKind,
        deviceTouchSlop,
      );
    }
    return true;
  }

  @override
  String get debugDescription => 'board pan';
}

/// Colours for Queens' colour regions.
///
/// Fixed hues rather than rotations of the theme accent. Eight rotations of one
/// accent are eight versions of the same colour, and the entire game is telling
/// two regions apart at a glance — a Cyberpunk board where six of the eight are
/// shades of cyan is not a hard puzzle, it is an unreadable one.
///
/// What DOES follow the theme is the lightness: the same hues are laid down
/// pale on a light background and deep on a dark one, so they read as a set
/// that belongs to whichever theme is on rather than eight stickers on top
/// of it.
class GamePalette {
  GamePalette(AppTheme theme)
    : _dark = theme.background.computeLuminance() < 0.4;

  final bool _dark;

  /// The first eight are Queens' eight regions and Flow's pipes. The last two
  /// exist for Star Battle's ten regions, which otherwise repeated the first
  /// two hues on a board where telling regions apart is the whole game; they
  /// sit in the widest gaps left on the wheel (between green and teal, and
  /// between purple and pink), and appending them leaves every board drawn
  /// with eight colours exactly as it was.
  static const _hues = <double>[8, 34, 58, 104, 168, 200, 258, 322, 136, 290];

  /// The fill for region [index].
  Color region(int index) {
    final hue = _hues[index % _hues.length];
    return HSLColor.fromAHSL(
      1,
      hue,
      _dark ? 0.42 : 0.60,
      _dark ? 0.30 : 0.80,
    ).toColor();
  }

  /// A stronger version of [region], for a border or a filled crown.
  Color regionInk(int index) {
    final hue = _hues[index % _hues.length];
    return HSLColor.fromAHSL(
      1,
      hue,
      _dark ? 0.55 : 0.70,
      _dark ? 0.62 : 0.42,
    ).toColor();
  }
}

/// Lays down a colour-region board's flat fills — Queens and Star Battle.
///
/// Split from [paintRegionBorders] rather than one call because a win sweep
/// goes between the two: over the colours, under the outlines, so the regions
/// stay legible while the board lights up.
void paintRegionFills(
  Canvas canvas,
  GameGrid grid,
  List<int> regions,
  GamePalette palette,
) {
  final n = grid.n;
  final fill = Paint()..style = PaintingStyle.fill;
  for (var i = 0; i < n * n && i < regions.length; i++) {
    fill.color = palette.region(regions[i]);
    canvas.drawRect(grid.rect(i).deflate(0.2), fill);
  }
}

/// The hairlines inside each region and the heavy outlines between them.
///
/// Drawn as edges between cells rather than a box per cell, because a box per
/// cell doubles every internal line and makes a region look gridded rather
/// than whole.
void paintRegionBorders(
  Canvas canvas,
  GameGrid grid,
  List<int> regions,
  AppTheme theme,
) {
  final n = grid.n;
  final cell = grid.cell;
  if (regions.length < n * n) return;
  final hair = Paint()
    ..color = theme.ink.withValues(alpha: 0.13)
    ..strokeWidth = 1
    ..style = PaintingStyle.stroke;
  final edge = Paint()
    ..color = theme.ink.withValues(alpha: 0.62)
    ..strokeWidth = math.max(1.6, cell * 0.055)
    ..strokeCap = StrokeCap.round
    ..style = PaintingStyle.stroke;

  for (var i = 0; i < n * n; i++) {
    final r = grid.rect(i);
    final col = i % n;
    final row = i ~/ n;
    if (col < n - 1) {
      final same = regions[i] == regions[i + 1];
      canvas.drawLine(r.topRight, r.bottomRight, same ? hair : edge);
    }
    if (row < n - 1) {
      final same = regions[i] == regions[i + n];
      canvas.drawLine(r.bottomLeft, r.bottomRight, same ? hair : edge);
    }
  }
  canvas.drawRect(
    Rect.fromLTWH(0, 0, cell * n, cell * n).deflate(edge.strokeWidth / 2),
    edge,
  );
}

/// A glyph path built once per size and reused for every cell that shows it.
///
/// Thirty stars or twelve flags on a board are the same outline at the same
/// size, so rebuilding it per cell per frame is pure allocation. Keyed by the
/// rounded size; cleared rather than evicted, because a board only ever
/// shows a handful of sizes (the screen, the tile, the info sheet).
class GlyphCache {
  GlyphCache(this.build);

  /// Builds the outline centred on the origin for a cell [side] across.
  final Path Function(double side) build;

  final _paths = <int, Path>{};

  Path at(double side) {
    final key = (side * 4).round();
    final hit = _paths[key];
    if (hit != null) return hit;
    if (_paths.length >= 8) _paths.clear();
    return _paths[key] = build(side);
  }

  /// Draws the cached outline centred on [center], scaled by [scale].
  void paint(
    Canvas canvas,
    Offset center,
    double side,
    Paint paint, {
    double scale = 1,
  }) {
    canvas.save();
    canvas.translate(center.dx, center.dy);
    if (scale != 1) canvas.scale(scale);
    canvas.drawPath(at(side), paint);
    canvas.restore();
  }
}

/// How lit cell [index] is, 0..1, [win] of the way through a board's win
/// sweep: a diagonal wave from the top-left, normalised so the last cell
/// finishes exactly as [win] reaches 1. The same wave every board plays.
double winSweepAt(int index, int n, double win) {
  if (win <= 0 || n < 2) return 0;
  final d = ((index ~/ n) + (index % n)) / (2 * (n - 1));
  final t = (win * 1.6 - d).clamp(0.0, 1.0);
  return t <= 0 ? 0 : math.sin(t * math.pi).abs();
}

/// Static geometry a painter would otherwise rebuild every frame — the cell
/// backdrop of a whole grid, its rule lines — built once per board size.
///
/// A board repaints on every tap and every frame of a pop or a win sweep, and
/// the grid under it never moves. Keyed by whatever describes the geometry
/// (cells per side and pixel size, usually); cleared rather than evicted,
/// since a board is only ever drawn at a handful of sizes.
class PathCache {
  final _paths = <Object, Path>{};

  Path at(Object key, Path Function() build) {
    final hit = _paths[key];
    if (hit != null) return hit;
    if (_paths.length >= 12) _paths.clear();
    return _paths[key] = build();
  }
}

/// Star Battle's star: five points, the inner radius at the golden ratio of
/// the outer one, which is what makes a star look like a star rather than a
/// spiky blob. Built once per size by [starGlyph].
Path _starPath(double side) {
  final outer = side * 0.36;
  final inner = outer * 0.42;
  final path = Path();
  for (var k = 0; k < 10; k++) {
    final r = k.isEven ? outer : inner;
    final a = -math.pi / 2 + k * math.pi / 5;
    // Nudged down a touch: a star's visual centre is below its geometric one.
    final p = Offset(math.cos(a) * r, math.sin(a) * r + side * 0.025);
    if (k == 0) {
      path.moveTo(p.dx, p.dy);
    } else {
      path.lineTo(p.dx, p.dy);
    }
  }
  return path..close();
}

/// The shared star outline. See [GlyphCache].
final starGlyph = GlyphCache(_starPath);

/// Minesweeper's flag: a pennant on a pole with a small foot, one path so it
/// fills in a single draw.
Path _flagPath(double side) {
  final h = side * 0.56;
  final top = -h / 2;
  final pole = side * 0.055;
  final x = -side * 0.12;
  return Path()
    // Pole.
    ..addRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(x, top, pole, h),
        Radius.circular(pole / 2),
      ),
    )
    // Pennant.
    ..moveTo(x + pole * 0.5, top)
    ..lineTo(x + side * 0.34, top + h * 0.22)
    ..lineTo(x + pole * 0.5, top + h * 0.46)
    ..close()
    // Foot.
    ..addRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: Offset(x + pole / 2, top + h - pole * 0.4),
          width: side * 0.3,
          height: pole * 1.3,
        ),
        Radius.circular(pole),
      ),
    );
}

/// The shared flag outline. See [GlyphCache].
final flagGlyph = GlyphCache(_flagPath);

/// Minesweeper's mine: a round body with eight short spikes and a highlight
/// cut out of it, so it reads as a mine and not as a dot even on the hub tile.
Path _minePath(double side) {
  final r = side * 0.2;
  final body = Path()..addOval(Rect.fromCircle(center: Offset.zero, radius: r));
  final spikes = Path();
  final w = side * 0.06;
  for (var k = 0; k < 4; k++) {
    final a = k * math.pi / 4;
    final d = Offset(math.cos(a), math.sin(a)) * (r * 1.5);
    spikes.addPath(
      Path()
        ..addRRect(
          RRect.fromRectAndRadius(
            Rect.fromCenter(center: Offset.zero, width: d.distance * 2, height: w),
            Radius.circular(w / 2),
          ),
        ),
      Offset.zero,
      matrix4: (Matrix4.identity()..rotateZ(a)).storage,
    );
  }
  final shine = Path()
    ..addOval(
      Rect.fromCircle(center: Offset(-r * 0.38, -r * 0.38), radius: r * 0.24),
    );
  return Path.combine(
    PathOperation.difference,
    Path.combine(PathOperation.union, body, spikes),
    shine,
  );
}

/// The shared mine outline. See [GlyphCache].
final mineGlyph = GlyphCache(_minePath);

/// Draws a crown at [center], sized to [side]. Queens' one and only glyph.
///
/// A path rather than an icon font: the board is a `CustomPainter`, and
/// `TextPainter`-ing an icon per cell costs a shaped-text layout sixty-four
/// times per frame to draw eight of them.
void paintCrown(Canvas canvas, Offset center, double side, Paint paint) {
  final w = side * 0.62;
  final h = side * 0.48;
  final left = center.dx - w / 2;
  final top = center.dy - h / 2;
  final path = Path()
    ..moveTo(left, top + h)
    ..lineTo(left, top + h * 0.16)
    ..lineTo(left + w * 0.25, top + h * 0.62)
    ..lineTo(left + w * 0.5, top)
    ..lineTo(left + w * 0.75, top + h * 0.62)
    ..lineTo(left + w, top + h * 0.16)
    ..lineTo(left + w, top + h)
    ..close();
  canvas.drawPath(path, paint);
}

/// Draws the player's "not here" cross at [center].
void paintCross(Canvas canvas, Offset center, double side, Paint paint) {
  final r = side * 0.17;
  canvas.drawLine(
    center + Offset(-r, -r),
    center + Offset(r, r),
    paint,
  );
  canvas.drawLine(
    center + Offset(r, -r),
    center + Offset(-r, r),
    paint,
  );
}

/// Draws Tango's sun — a disc with rays.
void paintSun(Canvas canvas, Offset center, double side, Paint paint) {
  final r = side * 0.19;
  canvas.drawCircle(center, r, paint);
  final stroke = Paint()
    ..color = paint.color
    ..strokeWidth = math.max(1.2, side * 0.05)
    ..strokeCap = StrokeCap.round
    ..style = PaintingStyle.stroke;
  for (var i = 0; i < 8; i++) {
    final a = i * math.pi / 4;
    final d = Offset(math.cos(a), math.sin(a));
    canvas.drawLine(center + d * (r * 1.45), center + d * (r * 1.95), stroke);
  }
}

/// Draws Tango's moon — a disc with a bite taken out of it.
///
/// Even-odd on two overlapping circles rather than an arc, so the crescent
/// keeps a true circular inner edge at every size the board is drawn at,
/// including the hub tile where a cell is nine pixels across.
void paintMoon(Canvas canvas, Offset center, double side, Paint paint) {
  final r = side * 0.26;
  final path = Path()
    ..fillType = PathFillType.evenOdd
    ..addOval(Rect.fromCircle(center: center, radius: r))
    ..addOval(
      Rect.fromCircle(center: center + Offset(r * 0.62, -r * 0.3), radius: r),
    );
  canvas.drawPath(path, paint);
}

/// Laid-out labels, kept across frames: a board's digits are the same few
/// strings in the same few colours every time it repaints.
///
/// Shaping text is the most expensive thing a board painter does — a
/// Nonogram's forty clue numbers cost more to lay out than everything else on
/// the board costs to draw — and none of it changes between two frames of a
/// pop or a win sweep. Keyed by the text and its style; cleared rather than
/// evicted once it holds more than a board's worth.
class GlyphTextCache {
  final _laid = <(String, TextStyle), TextPainter>{};

  /// Paints [text] in [style], centred on [center].
  void paint(Canvas canvas, Offset center, String text, TextStyle style) {
    final key = (text, style);
    var painter = _laid[key];
    if (painter == null) {
      if (_laid.length >= 160) {
        for (final p in _laid.values) {
          p.dispose();
        }
        _laid.clear();
      }
      painter = TextPainter(
        text: TextSpan(text: text, style: style),
        textDirection: TextDirection.ltr,
      )..layout();
      _laid[key] = painter;
    }
    painter.paint(
      canvas,
      center - Offset(painter.width / 2, painter.height / 2),
    );
  }
}

/// Lays out one short string centred at [center]. Used for Sudoku's digits and
/// Zip's checkpoint numbers.
///
/// Takes a [TextPainter] the caller owns so a board can reuse one across all
/// thirty-six cells instead of allocating a layout engine per digit.
void paintGlyph(
  Canvas canvas,
  TextPainter painter,
  Offset center,
  String text,
  TextStyle style,
) {
  painter
    ..text = TextSpan(text: text, style: style)
    ..layout();
  painter.paint(
    canvas,
    center - Offset(painter.width / 2, painter.height / 2),
  );
}
