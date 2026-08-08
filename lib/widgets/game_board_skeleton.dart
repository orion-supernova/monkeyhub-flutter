import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../theme/theme_scope.dart';

/// The square a game tile shows while today's board is still in flight.
///
/// What it replaces was a flat [AppTheme.surfaceSunken] rectangle, which on the
/// midnight palette is `#070B11` — a black square. One of those is ambiguous;
/// four of them side by side, which is exactly what the Feed band shows on a
/// cold start, read as a section that failed rather than one that is loading.
/// Nothing about the old placeholder distinguished the two, and the band has no
/// error state of its own to fall back to.
///
/// One per tile rather than a spinner over the row. The four boards happen to
/// arrive in a single payload today, but a tile that carries its own loading
/// state is the one that survives them arriving separately — and a spinner
/// centred over four squares says nothing about which of them is coming.
///
/// The grid is drawn at a fixed cell count rather than the real board's: the
/// point is to be board-shaped, and the sizes are not known until the payload
/// that would end this state lands.
class GameBoardSkeleton extends StatefulWidget {
  const GameBoardSkeleton({super.key, required this.radius, this.cells = 6});

  final double radius;
  final int cells;

  @override
  State<GameBoardSkeleton> createState() => _GameBoardSkeletonState();
}

class _GameBoardSkeletonState extends State<GameBoardSkeleton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _sweep;

  @override
  void initState() {
    super.initState();
    _sweep = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat();
  }

  @override
  void dispose() {
    _sweep.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    // Lifted off the sunken colour rather than sitting on it. A skeleton has to
    // be visible against the tile it is inside, and surfaceSunken against
    // surface is nearly no contrast at all on the dark palettes.
    final base = Color.alphaBlend(
      theme.surfaceSunken.withValues(alpha: 0.55),
      theme.surface,
    );
    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: _sweep,
        builder: (_, _) => CustomPaint(
          painter: _SkeletonPainter(
            t: _sweep.value,
            radius: widget.radius,
            cells: widget.cells,
            base: base,
            line: theme.divider.withValues(alpha: 0.55),
            highlight: Color.alphaBlend(
              theme.surfaceRaised.withValues(alpha: 0.9),
              base,
            ),
          ),
          size: Size.infinite,
        ),
      ),
    );
  }
}

class _SkeletonPainter extends CustomPainter {
  _SkeletonPainter({
    required this.t,
    required this.radius,
    required this.cells,
    required this.base,
    required this.line,
    required this.highlight,
  });

  /// Sweep position, 0 → 1 across one pass.
  final double t;
  final double radius;
  final int cells;
  final Color base;
  final Color line;
  final Color highlight;

  @override
  void paint(Canvas canvas, Size size) {
    final rrect = RRect.fromRectAndRadius(
      Offset.zero & size,
      Radius.circular(radius),
    );
    canvas.save();
    canvas.clipRRect(rrect);
    canvas.drawRect(Offset.zero & size, Paint()..color = base);

    final stepX = size.width / cells;
    final stepY = size.height / cells;
    final grid = Paint()
      ..color = line
      ..strokeWidth = 1;
    for (var i = 1; i < cells; i++) {
      canvas.drawLine(
        Offset(stepX * i, 0),
        Offset(stepX * i, size.height),
        grid,
      );
      canvas.drawLine(Offset(0, stepY * i), Offset(size.width, stepY * i), grid);
    }

    // A band wider than the tile, travelling far enough either side that it is
    // fully off the square at both ends of the pass — a sweep that pops into
    // existence mid-tile reads as a flicker rather than a pass.
    final band = size.width * 0.7;
    final centre = -band + t * (size.width + band * 2);
    final rect = Rect.fromLTRB(centre - band, 0, centre + band, size.height);
    canvas.drawRect(
      Offset.zero & size,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            highlight.withValues(alpha: 0),
            highlight,
            highlight.withValues(alpha: 0),
          ],
        ).createShader(rect),
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(_SkeletonPainter old) =>
      old.t != t ||
      old.radius != radius ||
      old.cells != cells ||
      old.base != base ||
      old.line != line ||
      old.highlight != highlight;
}
