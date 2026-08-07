/// Shared drawing kit for the four daily-game boards.
///
/// All four are painted rather than built out of widgets, and that is a
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

import 'package:flutter/widgets.dart';

import '../theme/app_theme.dart';

/// Where the cells of an `n`×`n` board are, inside a square of [side].
///
/// One object rather than arithmetic sprinkled through four painters and four
/// hit-tests. The hit-test in particular has to agree with the paint to the
/// pixel: a board that lights the cell above the one your finger is on is
/// unusable in a way no amount of visual polish recovers from.
class GameGrid {
  GameGrid({required this.side, required this.n, this.inset = 0});

  /// Length of the square the board is drawn into.
  final double side;

  /// Cells per row and per column.
  final int n;

  /// Padding inside [side], so a board can leave room for a border or a glow
  /// without every caller adjusting its own coordinates.
  final double inset;

  double get cell => (side - inset * 2) / n;

  Offset origin(int index) => Offset(
    inset + (index % n) * cell,
    inset + (index ~/ n) * cell,
  );

  Rect rect(int index) => origin(index) & Size(cell, cell);

  Offset center(int index) =>
      origin(index) + Offset(cell / 2, cell / 2);

  /// The cell under [point], or null if it is outside the board.
  ///
  /// Clamped rather than rounded: a finger a hair past the last column is
  /// obviously aiming at the last column, and returning null there makes the
  /// edge of every board feel dead.
  int? hit(Offset point) {
    if (cell <= 0) return null;
    final col = ((point.dx - inset) / cell).floor();
    final row = ((point.dy - inset) / cell).floor();
    if (col < 0 || row < 0 || col >= n || row >= n) return null;
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
class GameBoardSurface extends StatelessWidget {
  const GameBoardSurface({
    super.key,
    required this.painter,
    required this.n,
    this.onTapCell,
    this.onDragStart,
    this.onDragTo,
    this.onDragEnd,
  });

  final CustomPainter painter;

  /// Cells per side. Zero renders nothing — the board has not arrived yet.
  final int n;

  final void Function(int index)? onTapCell;

  /// Called once when a drag begins, before the first [onDragTo]. Zip uses it
  /// to mark where the stroke started so one gesture is one undo step.
  final VoidCallback? onDragStart;

  /// Called for every cell a drag passes over, including the one it starts on.
  final void Function(int index)? onDragTo;

  final VoidCallback? onDragEnd;

  @override
  Widget build(BuildContext context) {
    if (n == 0) return const SizedBox.shrink();
    return LayoutBuilder(
      builder: (context, constraints) {
        final side = constraints.biggest.shortestSide;
        final grid = GameGrid(side: side, n: n);
        void drag(Offset at) {
          final cell = grid.hit(at);
          if (cell != null) onDragTo?.call(cell);
        }

        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapUp: onTapCell == null
              ? null
              : (details) {
                  final cell = grid.hit(details.localPosition);
                  if (cell != null) onTapCell!(cell);
                },
          onPanStart: onDragTo == null
              ? null
              : (d) {
                  onDragStart?.call();
                  drag(d.localPosition);
                },
          onPanUpdate: onDragTo == null ? null : (d) => drag(d.localPosition),
          onPanEnd: onDragEnd == null ? null : (_) => onDragEnd!(),
          child: CustomPaint(painter: painter, size: Size.square(side)),
        );
      },
    );
  }
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

  static const _hues = <double>[8, 34, 58, 104, 168, 200, 258, 322];

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
