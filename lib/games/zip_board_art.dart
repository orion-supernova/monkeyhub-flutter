import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import '../models/daily_game.dart';
import '../theme/app_theme.dart';
import 'game_canvas.dart';

/// Paints a Zip board — the grid, the numbered dots, and the single continuous
/// line the player is drawing through it.
///
/// The line is the whole reason Zip is painted rather than built. It is one
/// stroke that runs through up to thirty-six cells and belongs to none of them;
/// there is no arrangement of per-cell widgets that produces a mitred corner
/// where it turns, and half-segments drawn into adjacent boxes leave a seam at
/// every cell boundary.
class ZipBoardPainter extends CustomPainter {
  ZipBoardPainter({
    required this.board,
    required this.theme,
    this.path = const [],
    this.win = 0,
    this.headPulse = 0,
  });

  final ZipBoard board;
  final AppTheme theme;

  /// Cells the line runs through, in order. Empty draws the bare board — the
  /// hub tile.
  final List<int> path;

  final double win;

  /// 0→1, loops while the line is unfinished. Breathes the head of the line so
  /// a half-drawn board still says "carry on from here" after you look away.
  final double headPulse;

  @override
  void paint(Canvas canvas, Size size) {
    final n = board.size;
    if (n == 0) return;
    final grid = GameGrid(side: math.min(size.width, size.height), n: n);
    final cell = grid.cell;
    final radius = Radius.circular(cell * 0.2);

    final visited = path.toSet();
    final fill = Paint()..style = PaintingStyle.fill;
    for (var i = 0; i < n * n; i++) {
      fill.color = visited.contains(i)
          ? theme.accent.withValues(alpha: 0.10)
          : theme.surfaceSunken;
      canvas.drawRRect(
        RRect.fromRectAndRadius(grid.rect(i).deflate(cell * 0.05), radius),
        fill,
      );
    }

    if (path.length > 1) {
      final line = Path()..moveTo(grid.center(path.first).dx, grid.center(path.first).dy);
      for (var i = 1; i < path.length; i++) {
        final c = grid.center(path[i]);
        line.lineTo(c.dx, c.dy);
      }
      // A soft wide pass under a solid narrow one. The halo is what keeps the
      // line legible where it runs alongside itself two cells apart, which on a
      // 6×6 Hamiltonian path is most of the board.
      canvas.drawPath(
        line,
        Paint()
          ..color = theme.accent.withValues(alpha: 0.22)
          ..strokeWidth = cell * 0.52
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round
          ..style = PaintingStyle.stroke,
      );
      canvas.drawPath(
        line,
        Paint()
          ..color = win > 0 ? theme.success : theme.accent
          ..strokeWidth = cell * 0.24
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round
          ..style = PaintingStyle.stroke,
      );
    }

    if (path.isNotEmpty && win == 0) {
      final head = grid.center(path.last);
      final t = math.sin(headPulse * math.pi * 2) * 0.5 + 0.5;
      canvas.drawCircle(
        head,
        cell * (0.16 + 0.07 * t),
        Paint()..color = theme.accent.withValues(alpha: 0.30 + 0.25 * t),
      );
    }

    final glyph = TextPainter(textDirection: TextDirection.ltr);
    for (var k = 0; k < board.checkpoints.length; k++) {
      final index = board.checkpoints[k];
      final center = grid.center(index);
      final reached = visited.contains(index);
      canvas.drawCircle(
        center,
        cell * 0.33,
        Paint()..color = reached ? theme.accent : theme.surfaceRaised,
      );
      canvas.drawCircle(
        center,
        cell * 0.33,
        Paint()
          ..color = reached ? theme.accent : theme.ink.withValues(alpha: 0.55)
          ..strokeWidth = math.max(1.2, cell * 0.045)
          ..style = PaintingStyle.stroke,
      );
      paintGlyph(
        canvas,
        glyph,
        center,
        '${k + 1}',
        TextStyle(
          // Digits, not words — the numbered dots are the one label on this
          // board and they read the same in all twelve languages.
          color: reached ? theme.accentInk : theme.ink,
          fontSize: cell * 0.36,
          fontWeight: FontWeight.w700,
          height: 1,
        ),
      );
    }
  }

  @override
  bool shouldRepaint(ZipBoardPainter old) =>
      old.board != board ||
      old.theme != theme ||
      old.path != path ||
      old.win != win ||
      old.headPulse != headPulse;
}
