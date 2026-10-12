import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import '../models/daily_game.dart';
import '../theme/app_theme.dart';
import 'game_canvas.dart';
import 'game_rules.dart';

/// Paints a Star Battle board — the colour regions, the player's stars and
/// dots, and whatever is currently contradicting itself.
///
/// The regions are drawn by the same helpers as Queens ([paintRegionFills],
/// [paintRegionBorders]), on purpose: it is the same kind of board with a
/// different count, and a player who knows one should recognise the other at
/// a glance. What differs is the glyph — a star where Queens has a crown — and
/// the "not here" mark, a dot rather than a cross, which is the convention for
/// this puzzle and keeps twenty stars from drowning in sixty crosses.
///
/// Pass no [marks] and it draws today's regions alone, inert: the hub tile.
class StarBattleBoardPainter extends CustomPainter {
  StarBattleBoardPainter({
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

  final StarBattleBoard board;
  final AppTheme theme;
  final GamePalette palette;
  final List<StarMark> marks;

  /// Stars currently breaking a rule, and every star they clash with.
  final Set<int> conflicts;

  /// Squares no star could go in. Drawn as a fainter dot than the player's own.
  final Set<int> autoBlocked;

  final int? popCell;
  final double pop;
  final double win;

  @override
  void paint(Canvas canvas, Size size) {
    final n = board.size;
    if (n == 0) return;
    final grid = GameGrid(side: math.min(size.width, size.height), n: n);
    final cell = grid.cell;

    paintRegionFills(canvas, grid, board.regions, palette);
    if (win > 0) {
      final glow = Paint();
      for (var i = 0; i < n * n; i++) {
        final a = winSweepAt(i, n, win);
        if (a <= 0) continue;
        glow.color = theme.success.withValues(alpha: 0.55 * a);
        canvas.drawRect(grid.rect(i).deflate(0.2), glow);
      }
    }
    paintRegionBorders(canvas, grid, board.regions, theme);

    if (marks.isEmpty) return;

    final dot = Paint();
    final star = Paint()..style = PaintingStyle.fill;
    final outline = Paint()
      ..style = PaintingStyle.stroke
      ..strokeJoin = StrokeJoin.round
      ..strokeWidth = math.max(1, cell * 0.04);

    for (var i = 0; i < marks.length && i < n * n; i++) {
      final center = grid.center(i);
      final scale = i == popCell
          ? 1 + 0.32 * math.sin(pop.clamp(0.0, 1.0) * math.pi)
          : 1.0;
      switch (marks[i]) {
        case StarMark.dot:
          dot.color = theme.ink.withValues(alpha: 0.55);
          canvas.drawCircle(center, cell * 0.085 * scale, dot);
        case StarMark.none:
          // The derived dot. Much fainter than the player's own, for the
          // reason Queens gives: one is a note they made, the other is the
          // board doing arithmetic for them.
          if (autoBlocked.contains(i)) {
            dot.color = theme.ink.withValues(alpha: 0.2);
            canvas.drawCircle(center, cell * 0.06, dot);
          }
        case StarMark.star:
          final clashing = conflicts.contains(i);
          if (clashing) {
            canvas.drawCircle(
              center,
              cell * 0.40 * scale,
              Paint()..color = theme.danger.withValues(alpha: 0.28),
            );
          }
          star.color = clashing
              ? theme.danger
              : palette.regionInk(board.regions[i]);
          starGlyph.paint(canvas, center, cell, star, scale: scale);
          // A hairline in the background colour, so a star on a region of its
          // own hue still has an edge.
          outline.color = theme.background.withValues(alpha: 0.5);
          starGlyph.paint(canvas, center, cell, outline, scale: scale);
      }
    }
  }

  @override
  bool shouldRepaint(StarBattleBoardPainter old) =>
      old.board != board ||
      old.theme != theme ||
      old.marks != marks ||
      old.conflicts != conflicts ||
      old.autoBlocked != autoBlocked ||
      old.popCell != popCell ||
      old.pop != pop ||
      old.win != win;
}
