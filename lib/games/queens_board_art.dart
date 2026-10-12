import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import '../models/daily_game.dart';
import '../theme/app_theme.dart';
import 'game_canvas.dart';
import 'game_rules.dart';

/// Paints a Queens board — the colour regions, the player's crowns and
/// crosses, and whatever is currently contradicting itself.
///
/// Also paints the hub's tile: pass no [marks] and it draws today's real
/// regions, inert. The tiles are the actual boards, which is why the hub looks
/// different every morning instead of showing four fixed icons.
class QueensBoardPainter extends CustomPainter {
  QueensBoardPainter({
    required this.board,
    required this.theme,
    required this.palette,
    this.marks = const [],
    this.conflicts = const {},
    this.autoBlocked = const {},
    this.popCell,
    this.pop = 1,
    this.win = 0,
  });

  final QueensBoard board;
  final AppTheme theme;
  final GamePalette palette;
  final List<QueensMark> marks;

  /// Crowns currently breaking a rule, and every crown they clash with.
  final Set<int> conflicts;

  /// Cells no crown could go in. Drawn as a faint cross — the bookkeeping a
  /// player would otherwise do sixty times a board by hand.
  final Set<int> autoBlocked;

  /// The cell that just changed, and how far through its pop it is. One cell
  /// rather than a controller per cell: a placement is a single event and
  /// sixty-four tickers to animate one of them is not a trade worth making.
  final int? popCell;
  final double pop;

  /// 0 → 1 once the board is solved, sweeping across the grid.
  final double win;

  @override
  void paint(Canvas canvas, Size size) {
    final n = board.size;
    if (n == 0) return;
    final grid = GameGrid(side: math.min(size.width, size.height), n: n);
    final cell = grid.cell;

    // Regions first, as flat fills. Borders come after every fill so a region's
    // outline is never half-covered by the neighbour painted next.
    paintRegionFills(canvas, grid, board.regions, palette);

    if (win > 0) {
      // A diagonal sweep, so the win reads as travelling across the board
      // rather than every cell lighting at once. Distance is normalised by the
      // longest diagonal so the last cell finishes exactly at win == 1.
      final glow = Paint()..style = PaintingStyle.fill;
      for (var i = 0; i < n * n; i++) {
        final d = ((i ~/ n) + (i % n)) / (2 * (n - 1));
        final t = (win * 1.6 - d).clamp(0.0, 1.0);
        if (t <= 0) continue;
        glow.color = theme.success.withValues(
          alpha: 0.55 * math.sin(t * math.pi).abs(),
        );
        canvas.drawRect(grid.rect(i).deflate(0.2), glow);
      }
    }

    // Cell separators inside a region, then the region outlines on top.
    // Shared with Star Battle, which draws its regions exactly this way.
    paintRegionBorders(canvas, grid, board.regions, theme);

    if (marks.isEmpty) return;

    final crossPaint = Paint()
      ..strokeWidth = math.max(1.4, cell * 0.06)
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    final crownPaint = Paint()..style = PaintingStyle.fill;

    for (var i = 0; i < marks.length && i < n * n; i++) {
      final center = grid.center(i);
      final scale = i == popCell ? _popScale(pop) : 1.0;

      if (marks[i] == QueensMark.blocked) {
        crossPaint.color = theme.ink.withValues(alpha: 0.55);
        paintCross(canvas, center, cell * scale, crossPaint);
        continue;
      }
      if (marks[i] == QueensMark.none) {
        // The derived cross. Deliberately much fainter than the player's own —
        // one is a note they made and the other is the board doing arithmetic
        // for them, and confusing the two would let the board's guess look like
        // their own reasoning.
        if (autoBlocked.contains(i)) {
          crossPaint.color = theme.ink.withValues(alpha: 0.16);
          paintCross(canvas, center, cell * 0.7, crossPaint);
        }
        continue;
      }

      final clashing = conflicts.contains(i);
      if (clashing) {
        canvas.drawCircle(
          center,
          cell * 0.40 * scale,
          Paint()..color = theme.danger.withValues(alpha: 0.28),
        );
      }
      crownPaint.color = clashing
          ? theme.danger
          : palette.regionInk(board.regions[i]);
      paintCrown(canvas, center, cell * scale, crownPaint);
    }
  }

  /// Overshoot on placement — a crown lands rather than appears.
  double _popScale(double t) => 1 + 0.32 * math.sin(t.clamp(0.0, 1.0) * math.pi);

  @override
  bool shouldRepaint(QueensBoardPainter old) =>
      old.board != board ||
      old.theme != theme ||
      old.marks != marks ||
      old.conflicts != conflicts ||
      old.autoBlocked != autoBlocked ||
      old.popCell != popCell ||
      old.pop != pop ||
      old.win != win;
}
