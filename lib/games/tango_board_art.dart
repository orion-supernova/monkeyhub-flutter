import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import '../models/daily_game.dart';
import '../theme/app_theme.dart';
import 'game_canvas.dart';
import 'game_rules.dart';

/// Paints a Tango board — the grid, the printed and placed symbols, and the
/// `=` / `×` operators that sit on the edges *between* cells.
///
/// Those operators are the reason this is a painter. An operator belongs to a
/// boundary, not to either of the cells it joins, and a widget-per-cell layout
/// has nowhere to put it that does not either clip at the cell edge or need a
/// second overlay grid offset by half a cell.
class TangoBoardPainter extends CustomPainter {
  TangoBoardPainter({
    required this.board,
    required this.theme,
    this.cells = const [],
    this.trouble = const TangoTrouble(cells: {}, signs: {}),
    this.popCell,
    this.pop = 1,
    this.win = 0,
  });

  final TangoBoard board;
  final AppTheme theme;

  /// The player's grid. Empty renders the printed board alone — the hub tile.
  final List<int> cells;

  final TangoTrouble trouble;
  final int? popCell;
  final double pop;
  final double win;

  @override
  void paint(Canvas canvas, Size size) {
    final n = board.size;
    if (n == 0) return;
    final grid = GameGrid(side: math.min(size.width, size.height), n: n);
    final cell = grid.cell;
    final radius = Radius.circular(cell * 0.18);

    final fill = Paint()..style = PaintingStyle.fill;
    final given = board.givens;

    for (var i = 0; i < n * n; i++) {
      final isGiven = given.length > i && given[i] != tangoEmpty;
      final broken = trouble.cells.contains(i);
      // A printed cell is a different surface from an empty one, not just a
      // different glyph. Without that the board gives no hint which squares are
      // fixed until you tap one and it refuses to change.
      fill.color = broken
          ? theme.danger.withValues(alpha: 0.16)
          : isGiven
          ? theme.surfaceRaised
          : theme.surfaceSunken;
      canvas.drawRRect(
        RRect.fromRectAndRadius(grid.rect(i).deflate(cell * 0.045), radius),
        fill,
      );

      if (win > 0) {
        final d = ((i ~/ n) + (i % n)) / (2 * (n - 1));
        final t = (win * 1.6 - d).clamp(0.0, 1.0);
        if (t > 0) {
          canvas.drawRRect(
            RRect.fromRectAndRadius(grid.rect(i).deflate(cell * 0.045), radius),
            Paint()
              ..color = theme.success.withValues(
                alpha: 0.5 * math.sin(t * math.pi).abs(),
              ),
          );
        }
      }
    }

    final symbol = Paint()..style = PaintingStyle.fill;
    for (var i = 0; i < n * n; i++) {
      final isGiven = given.length > i && given[i] != tangoEmpty;
      final value = isGiven
          ? given[i]
          : (cells.length > i ? cells[i] : tangoEmpty);
      if (value == tangoEmpty) continue;

      final scale = i == popCell ? _popScale(pop) : 1.0;
      // Printed symbols sit at full ink; the player's own are a shade softer,
      // so a finished grid still reads as "these six were the board's".
      symbol.color = trouble.cells.contains(i)
          ? theme.danger
          : isGiven
          ? theme.ink
          : theme.accent;
      if (value == tangoSun) {
        paintSun(canvas, grid.center(i), cell * scale, symbol);
      } else {
        paintMoon(canvas, grid.center(i), cell * scale, symbol);
      }
    }

    for (var s = 0; s < board.signs.length; s++) {
      _paintSign(canvas, grid, board.signs[s], trouble.signs.contains(s));
    }
  }

  /// One operator, centred on the edge its two cells share.
  void _paintSign(Canvas canvas, GameGrid grid, TangoSign sign, bool broken) {
    final cell = grid.cell;
    final mid = Offset(
      (grid.center(sign.a).dx + grid.center(sign.b).dx) / 2,
      (grid.center(sign.a).dy + grid.center(sign.b).dy) / 2,
    );
    final r = cell * 0.19;

    canvas.drawCircle(
      mid,
      r,
      Paint()..color = broken ? theme.danger : theme.background,
    );
    canvas.drawCircle(
      mid,
      r,
      Paint()
        ..color = broken ? theme.danger : theme.ink.withValues(alpha: 0.7)
        ..strokeWidth = math.max(1, cell * 0.03)
        ..style = PaintingStyle.stroke,
    );

    final ink = Paint()
      ..color = broken ? theme.background : theme.ink
      ..strokeWidth = math.max(1.3, cell * 0.05)
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    final g = r * 0.52;
    if (sign.eq) {
      canvas.drawLine(mid + Offset(-g, -g * 0.55), mid + Offset(g, -g * 0.55), ink);
      canvas.drawLine(mid + Offset(-g, g * 0.55), mid + Offset(g, g * 0.55), ink);
    } else {
      canvas.drawLine(mid + Offset(-g, -g), mid + Offset(g, g), ink);
      canvas.drawLine(mid + Offset(g, -g), mid + Offset(-g, g), ink);
    }
  }

  double _popScale(double t) => 1 + 0.28 * math.sin(t.clamp(0.0, 1.0) * math.pi);

  @override
  bool shouldRepaint(TangoBoardPainter old) =>
      old.board != board ||
      old.theme != theme ||
      old.cells != cells ||
      old.trouble != trouble ||
      old.popCell != popCell ||
      old.pop != pop ||
      old.win != win;
}
