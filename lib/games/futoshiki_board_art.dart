import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import '../models/daily_game.dart';
import '../theme/app_theme.dart';
import 'game_canvas.dart';
import 'game_rules.dart';

/// Paints a Futoshiki board — the 5×5 cells, printed and entered digits,
/// pencil notes, the selection highlight, and a chevron on every edge that
/// carries a `<` or `>`.
///
/// The chevrons are why this is a painter. A sign belongs to the boundary
/// between two cells, not to either of them, and it has to point: at the
/// smaller of the two, sideways or up and down. Cells are inset from their
/// square so every chevron sits in a clear gutter rather than on top of a
/// digit.
class FutoshikiBoardPainter extends CustomPainter {
  FutoshikiBoardPainter({
    required this.board,
    required this.theme,
    this.cells = const [],
    this.notes = const {},
    this.trouble = const FutoshikiTrouble(cells: {}, signs: {}),
    this.selected,
    this.popCell,
    this.pop = 1,
    this.win = 0,
  });

  final FutoshikiBoard board;
  final AppTheme theme;

  /// The player's grid. Empty draws the printed board alone — the hub tile.
  final List<int> cells;

  /// Pencil marks per cell. Never validated, for the reason Sudoku gives.
  final Map<int, Set<int>> notes;

  final FutoshikiTrouble trouble;
  final int? selected;
  final int? popCell;
  final double pop;
  final double win;

  static final _chevrons = GlyphCache(_chevron);
  static final _labels = GlyphTextCache();

  /// A `<`, centred on the origin, vertex on the left. Rotated per sign.
  static Path _chevron(double side) {
    final w = side * 0.085;
    final h = side * 0.15;
    return Path()
      ..moveTo(w, -h)
      ..lineTo(-w, 0)
      ..lineTo(w, h);
  }

  @override
  void paint(Canvas canvas, Size size) {
    final n = board.size;
    if (n == 0) return;
    final grid = GameGrid(side: math.min(size.width, size.height), n: n);
    final cell = grid.cell;
    final given = board.givens;
    final gap = cell * 0.13;
    final radius = Radius.circular(cell * 0.16);

    final selectedValue =
        selected != null && cells.length > selected! ? cells[selected!] : 0;

    final fill = Paint()..style = PaintingStyle.fill;
    for (var i = 0; i < n * n; i++) {
      final isGiven = given.length > i && given[i] != futoshikiEmpty;
      final value = isGiven
          ? given[i]
          : (cells.length > i ? cells[i] : futoshikiEmpty);
      final peer = selected != null &&
          i != selected &&
          (i ~/ n == selected! ~/ n || i % n == selected! % n);
      // The same three levels of emphasis as Sudoku: the square you are on,
      // the squares it is constrained by, and every square holding its digit.
      fill.color = trouble.cells.contains(i)
          ? theme.danger.withValues(alpha: 0.18)
          : i == selected
          ? theme.accent.withValues(alpha: 0.26)
          : selectedValue != futoshikiEmpty && value == selectedValue
          ? theme.accent.withValues(alpha: 0.14)
          : peer
          ? theme.accent.withValues(alpha: 0.07)
          : isGiven
          ? theme.surfaceRaised
          : theme.surfaceSunken;
      final box = RRect.fromRectAndRadius(grid.rect(i).deflate(gap), radius);
      canvas.drawRRect(box, fill);
      final glow = winSweepAt(i, n, win);
      if (glow > 0) {
        canvas.drawRRect(
          box,
          Paint()..color = theme.success.withValues(alpha: 0.5 * glow),
        );
      }
    }

    final ink = Paint()
      ..strokeWidth = math.max(1.6, cell * 0.045)
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;
    for (var s = 0; s < board.signs.length; s++) {
      final sign = board.signs[s];
      final mid = Offset(
        (grid.center(sign.a).dx + grid.center(sign.b).dx) / 2,
        (grid.center(sign.a).dy + grid.center(sign.b).dy) / 2,
      );
      // The vertex points at the smaller cell. `a` is always the left or top
      // one, so `a < b` points left (or up) and `a > b` right (or down).
      final angle =
          (sign.horizontal ? 0.0 : math.pi / 2) + (sign.lt ? 0 : math.pi);
      ink.color = trouble.signs.contains(s)
          ? theme.danger
          : theme.ink.withValues(alpha: 0.72);
      canvas.save();
      canvas.translate(mid.dx, mid.dy);
      canvas.rotate(angle);
      canvas.drawPath(_chevrons.at(cell), ink);
      canvas.restore();
    }

    final glyph = TextPainter(textDirection: TextDirection.ltr);
    for (var i = 0; i < n * n; i++) {
      final isGiven = given.length > i && given[i] != futoshikiEmpty;
      final value = isGiven
          ? given[i]
          : (cells.length > i ? cells[i] : futoshikiEmpty);

      if (value == futoshikiEmpty) {
        final pencil = notes[i];
        if (pencil == null || pencil.isEmpty) continue;
        final box = grid.rect(i).deflate(gap);
        for (final v in pencil) {
          final slot = v - 1;
          _labels.paint(
            canvas,
            box.topLeft +
                Offset(
                  box.width * (0.22 + 0.28 * (slot % 3)),
                  box.height * (0.28 + 0.44 * (slot ~/ 3)),
                ),
            '$v',
            theme.body.copyWith(
              letterSpacing: 0,
              color: theme.inkMuted,
              fontSize: _half(cell * 0.18),
              height: 1,
            ),
          );
        }
        continue;
      }

      final scale = i == popCell
          ? 1 + 0.30 * math.sin(pop.clamp(0.0, 1.0) * math.pi)
          : 1.0;
      final style = theme.body.copyWith(
        letterSpacing: 0,
        color: trouble.cells.contains(i)
            ? theme.danger
            : isGiven
            ? theme.ink
            : theme.accent,
        fontSize: scale == 1 ? _half(cell * 0.44) : cell * 0.44 * scale,
        fontWeight: isGiven ? FontWeight.w700 : FontWeight.w500,
        height: 1,
      );
      // The one square popping is laid out fresh each frame; every other
      // digit comes out of the cache.
      if (scale == 1) {
        _labels.paint(canvas, grid.center(i), '$value', style);
      } else {
        paintGlyph(canvas, glyph, grid.center(i), '$value', style);
      }
    }
  }

  @override
  bool shouldRepaint(FutoshikiBoardPainter old) =>
      old.board != board ||
      old.theme != theme ||
      old.cells != cells ||
      old.notes != notes ||
      old.trouble != trouble ||
      old.selected != selected ||
      old.popCell != popCell ||
      old.pop != pop ||
      old.win != win;
}

/// Rounds a font size to the half pixel, so the cached labels of a board drawn
/// at one size are reused rather than re-laid out per fractional pixel.
double _half(double size) => (size * 2).roundToDouble() / 2;
