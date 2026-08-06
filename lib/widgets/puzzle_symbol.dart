import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import '../models/puzzle.dart';

/// One of the six symbols in the daily puzzle's alphabet.
///
/// **Shape is the signal; colour is decoration.** Every symbol is a distinct
/// outline, so the puzzle is fully playable in greyscale and by anyone who
/// cannot separate the hues. That is not only an accessibility nicety here —
/// this app has thirteen theme variants, four of them light-surfaced, and one
/// (NeonNight) whose accent is pure `#FFFF00`. A colour-only alphabet would
/// need six hues that stay distinguishable against all of them, which is not a
/// solvable problem. Six shapes are the same everywhere.
///
/// The fill is the active theme's accent rotated around the hue wheel, so the
/// set reads as a family drawn from whatever palette is on rather than six
/// imported swatches sitting on top of it.
class PuzzleSymbol extends StatelessWidget {
  const PuzzleSymbol({
    super.key,
    required this.index,
    required this.size,
    required this.accent,
    this.muted = false,
  });

  /// 0..[kPuzzleSymbolCount] - 1.
  final int index;
  final double size;

  /// The theme's accent — the hue every symbol is derived from. Passed in
  /// rather than read from context because the painter below must not touch
  /// `BuildContext`, and this widget is built inside tight per-cell loops.
  final Color accent;

  /// Draws as an outline only. Used for the empty slots of a row not yet
  /// guessed, so the grid has structure before it has content.
  final bool muted;

  /// The fill for [index]: the accent, rotated evenly around the wheel.
  static Color colorFor(Color accent, int index) {
    final hsl = HSLColor.fromColor(accent);
    final rotated = (hsl.hue + (360.0 / kPuzzleSymbolCount) * index) % 360.0;
    // Floors on saturation and lightness so a near-grey accent (Graphite's is
    // #E5E5E5) still yields six separable tints rather than six greys, and so
    // no symbol goes so light it vanishes on the four light themes.
    return hsl
        .withHue(rotated)
        .withSaturation(math.max(hsl.saturation, 0.45))
        .withLightness(hsl.lightness.clamp(0.42, 0.68))
        .toColor();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _SymbolPainter(
          index: index % kPuzzleSymbolCount,
          color: colorFor(accent, index % kPuzzleSymbolCount),
          muted: muted,
        ),
      ),
    );
  }
}

class _SymbolPainter extends CustomPainter {
  _SymbolPainter({
    required this.index,
    required this.color,
    required this.muted,
  });

  final int index;
  final Color color;
  final bool muted;

  @override
  void paint(Canvas canvas, Size size) {
    final r = size.shortestSide / 2;
    final c = Offset(size.width / 2, size.height / 2);
    final paint = Paint()
      ..color = muted ? color.withValues(alpha: 0.28) : color
      ..style = muted ? PaintingStyle.stroke : PaintingStyle.fill
      ..strokeWidth = 1.4
      ..strokeJoin = StrokeJoin.round;

    switch (index) {
      case 0: // circle
        canvas.drawCircle(c, r * 0.82, paint);
      case 1: // triangle
        canvas.drawPath(_polygon(c, r * 0.94, 3, -math.pi / 2), paint);
      case 2: // square
        canvas.drawPath(_polygon(c, r * 0.92, 4, math.pi / 4), paint);
      case 3: // diamond
        canvas.drawPath(_polygon(c, r * 0.96, 4, 0), paint);
      case 4: // five-pointed star
        canvas.drawPath(_star(c, r * 0.98, r * 0.42, 5), paint);
      case 5: // hexagon
        canvas.drawPath(_polygon(c, r * 0.9, 6, math.pi / 6), paint);
    }
  }

  static Path _polygon(Offset c, double r, int sides, double rotation) {
    final p = Path();
    for (var i = 0; i < sides; i++) {
      final a = rotation + (math.pi * 2 / sides) * i;
      final o = Offset(c.dx + r * math.cos(a), c.dy + r * math.sin(a));
      i == 0 ? p.moveTo(o.dx, o.dy) : p.lineTo(o.dx, o.dy);
    }
    return p..close();
  }

  static Path _star(Offset c, double outer, double inner, int points) {
    final p = Path();
    for (var i = 0; i < points * 2; i++) {
      final r = i.isEven ? outer : inner;
      final a = -math.pi / 2 + (math.pi / points) * i;
      final o = Offset(c.dx + r * math.cos(a), c.dy + r * math.sin(a));
      i == 0 ? p.moveTo(o.dx, o.dy) : p.lineTo(o.dx, o.dy);
    }
    return p..close();
  }

  @override
  bool shouldRepaint(_SymbolPainter old) =>
      old.index != index || old.color != color || old.muted != muted;
}
