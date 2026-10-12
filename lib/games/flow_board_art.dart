import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import '../models/daily_game.dart';
import '../theme/app_theme.dart';
import 'game_canvas.dart';

/// Paints a Flow board — the grid, a numbered dot pair per colour, and the
/// pipes the player has drawn between them.
///
/// Painted, like Zip, because a pipe is one stroke that belongs to no cell: a
/// per-cell widget layout cannot give it a round corner where it turns, and
/// half-segments drawn into neighbouring boxes leave a seam at every boundary.
///
/// Every dot carries its colour's number as well as its colour. Six or seven
/// hues on a phone screen is exactly where colour-blind players lose two of
/// them, and "join the 4s" works for everyone where "join the greens" does not.
///
/// Pass no [pipes] and it draws today's dots alone, inert: the hub's tile.
class FlowBoardPainter extends CustomPainter {
  FlowBoardPainter({
    required this.board,
    required this.theme,
    required this.palette,
    this.pipes = const [],
    this.active,
    this.win = 0,
  });

  final FlowBoard board;
  final AppTheme theme;
  final GamePalette palette;

  /// One list of cells per colour, in the order the player drew it. Empty, or
  /// shorter than the colour count, for colours not started.
  final List<List<int>> pipes;

  /// The colour under the player's finger, drawn a touch heavier so the pipe
  /// being laid reads as the one in hand.
  final int? active;

  final double win;

  static final _backdrop = PathCache();
  static final _labels = GlyphTextCache();

  @override
  void paint(Canvas canvas, Size size) {
    final n = board.size;
    if (n == 0) return;
    final grid = GameGrid(side: math.min(size.width, size.height), n: n);
    final cell = grid.cell;

    // The empty grid, one path for all forty-nine squares.
    final backdrop = _backdrop.at((n, (cell * 4).round()), () {
      final path = Path();
      for (var i = 0; i < n * n; i++) {
        path.addRRect(
          RRect.fromRectAndRadius(
            grid.rect(i).deflate(cell * 0.05),
            Radius.circular(cell * 0.2),
          ),
        );
      }
      return path;
    });
    canvas.drawPath(backdrop, Paint()..color = theme.surfaceSunken);

    // A wash of each pipe's colour over the squares it fills, so a finished
    // board reads as regions of colour and an unfilled square stands out as
    // the one still missing.
    final wash = Paint()..style = PaintingStyle.fill;
    for (var k = 0; k < pipes.length; k++) {
      wash.color = palette.region(k).withValues(alpha: 0.55);
      for (final c in pipes[k]) {
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            grid.rect(c).deflate(cell * 0.05),
            Radius.circular(cell * 0.2),
          ),
          wash,
        );
      }
    }

    if (win > 0) {
      final glow = Paint();
      for (var i = 0; i < n * n; i++) {
        final a = winSweepAt(i, n, win);
        if (a <= 0) continue;
        glow.color = theme.success.withValues(alpha: 0.45 * a);
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            grid.rect(i).deflate(cell * 0.05),
            Radius.circular(cell * 0.2),
          ),
          glow,
        );
      }
    }

    final stroke = Paint()
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;
    for (var k = 0; k < pipes.length; k++) {
      final pipe = pipes[k];
      if (pipe.length < 2) continue;
      final line = Path()
        ..moveTo(grid.center(pipe.first).dx, grid.center(pipe.first).dy);
      for (var i = 1; i < pipe.length; i++) {
        final c = grid.center(pipe[i]);
        line.lineTo(c.dx, c.dy);
      }
      stroke
        ..color = palette.regionInk(k)
        ..strokeWidth = cell * (k == active ? 0.38 : 0.32);
      canvas.drawPath(line, stroke);
    }

    final ring = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(1.2, cell * 0.05);
    for (var k = 0; k < board.endpoints.length; k++) {
      final ink = palette.regionInk(k);
      // Dark digits on a light dot and light on a dark one, decided by the
      // dot itself: the same hue is pale on one theme and deep on another.
      final digit = ink.computeLuminance() > 0.35
          ? const Color(0xE6000000)
          : const Color(0xFFFFFFFF);
      final (a, b) = board.endpoints[k];
      for (final c in [a, b]) {
        final center = grid.center(c);
        canvas.drawCircle(center, cell * 0.36, Paint()..color = ink);
        ring.color = theme.background.withValues(alpha: 0.35);
        canvas.drawCircle(center, cell * 0.36, ring);
        _labels.paint(
          canvas,
          center,
          '${k + 1}',
          theme.body.copyWith(
            letterSpacing: 0,
            color: digit,
            fontSize: _half(cell * 0.38),
            fontWeight: FontWeight.w700,
            height: 1,
          ),
        );
      }
    }
  }

  @override
  bool shouldRepaint(FlowBoardPainter old) =>
      old.board != board ||
      old.theme != theme ||
      old.pipes != pipes ||
      old.active != active ||
      old.win != win;
}

/// Rounds a font size to the half pixel, so the cached labels of a board drawn
/// at one size are reused rather than re-laid out per fractional pixel.
double _half(double size) => (size * 2).roundToDouble() / 2;
