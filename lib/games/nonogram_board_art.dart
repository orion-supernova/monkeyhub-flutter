import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import '../models/daily_game.dart';
import '../theme/app_theme.dart';
import 'game_canvas.dart';
import 'game_rules.dart';

/// How much of a Nonogram's square goes to its clue gutter, as a fraction of
/// the side. Shared by the painter and the gesture surface so the cells a
/// finger lands on are the cells that are drawn.
///
/// Sized to the longest clue on today's board rather than fixed: a board whose
/// longest line reads `3 2` wastes a third of the screen on a gutter built for
/// `1 1 1 1 1`, and the cells are what the player is actually aiming at.
double nonogramLeadFraction(NonogramBoard board) {
  if (board.isEmpty) return 0;
  var longest = 1;
  for (final line in [...board.rows, ...board.cols]) {
    longest = math.max(longest, line.length);
  }
  final gutter = (longest * 0.62 + 0.5).clamp(2.0, 4.0);
  return gutter / (board.size + gutter);
}

/// Paints a Nonogram — the clue gutter along the top and left, the grid with a
/// heavier rule every five lines, and the player's shaded and crossed squares.
///
/// Two things carry most of the feel. Lines whose shading already reads back
/// their clue go quiet, so the eye is pulled to what is still open; and a line
/// the player has shaded into a contradiction has its clue turned red, which
/// is the only kind of "wrong" the board can know without knowing the picture.
///
/// Pass no [cells] and it draws today's clues over an empty grid: the hub's
/// tile. At tile size the digits would be a smudge, so there each clue is
/// drawn as a row of short bars, one per run, as long as the run.
class NonogramBoardPainter extends CustomPainter {
  NonogramBoardPainter({
    required this.board,
    required this.theme,
    this.cells = const [],
    this.trouble = const NonogramTrouble(rows: {}, cols: {}),
    this.satisfiedRows = const {},
    this.satisfiedCols = const {},
    this.focus,
    this.popCell,
    this.pop = 1,
    this.win = 0,
  });

  final NonogramBoard board;
  final AppTheme theme;

  /// [nonogramFilled], [nonogramCrossed] or [nonogramUnknown] per square.
  final List<int> cells;

  /// Lines no arrangement of their clue fits any more.
  final NonogramTrouble trouble;

  /// Lines whose shading reads back their clue exactly.
  final Set<int> satisfiedRows;
  final Set<int> satisfiedCols;

  /// The square last touched. Its row and column clues are lit, which is
  /// what the eye is checking against while the finger is on the grid.
  final int? focus;

  final int? popCell;
  final double pop;
  final double win;

  static final _rules = PathCache();
  static final _labels = GlyphTextCache();
  static final _crosses = GlyphCache((side) {
    final r = side * 0.16;
    return Path()
      ..moveTo(-r, -r)
      ..lineTo(r, r)
      ..moveTo(r, -r)
      ..lineTo(-r, r);
  });

  @override
  void paint(Canvas canvas, Size size) {
    final n = board.size;
    if (n == 0) return;
    final side = math.min(size.width, size.height);
    final lead = side * nonogramLeadFraction(board);
    final grid = GameGrid(side: side, n: n, lead: lead);
    final cell = grid.cell;
    final span = cell * n;
    final gridRect = Rect.fromLTWH(lead, lead, span, span);

    // The two gutters, on a faint wash of their own so the clues read as a
    // frame around the picture rather than text floating beside it.
    final gutter = Paint()..color = theme.ink.withValues(alpha: 0.045);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(lead, 0, span, lead - cell * 0.12),
        Radius.circular(cell * 0.25),
      ),
      gutter,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(0, lead, lead - cell * 0.12, span),
        Radius.circular(cell * 0.25),
      ),
      gutter,
    );

    final focusRow = focus == null ? -1 : focus! ~/ n;
    final focusCol = focus == null ? -1 : focus! % n;
    final lit = Paint()..color = theme.accent.withValues(alpha: 0.12);
    if (focusRow >= 0) {
      canvas.drawRect(
        Rect.fromLTWH(0, lead + focusRow * cell, lead - cell * 0.12, cell),
        lit,
      );
      canvas.drawRect(
        Rect.fromLTWH(lead + focusCol * cell, 0, cell, lead - cell * 0.12),
        lit,
      );
    }

    // Squares.
    canvas.drawRect(gridRect, Paint()..color = theme.surfaceSunken);
    final ink = Paint()..color = theme.ink.withValues(alpha: 0.88);
    final cross = Paint()
      ..color = theme.inkMuted.withValues(alpha: 0.7)
      ..strokeWidth = math.max(1.1, cell * 0.06)
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    // Every shaded square in one path and every cross in another, so a full
    // board is two draw calls rather than a hundred. The square that just
    // changed is drawn on its own, at its pop scale.
    final shaded = Path();
    final crosses = Path();
    final crossShape = _crosses.at(cell);
    for (var i = 0; i < n * n && i < cells.length; i++) {
      final v = cells[i];
      if (v == nonogramUnknown) continue;
      final scale = i == popCell
          ? 1 + 0.22 * math.sin(pop.clamp(0.0, 1.0) * math.pi)
          : 1.0;
      if (v == nonogramFilled) {
        final box = RRect.fromRectAndRadius(
          Rect.fromCenter(
            center: grid.center(i),
            width: cell * 0.86 * scale,
            height: cell * 0.86 * scale,
          ),
          Radius.circular(cell * 0.14),
        );
        if (scale == 1) {
          shaded.addRRect(box);
        } else {
          canvas.drawRRect(box, ink);
        }
      } else if (v == nonogramCrossed) {
        if (scale == 1) {
          crosses.addPath(crossShape, grid.center(i));
        } else {
          _crosses.paint(canvas, grid.center(i), cell, cross, scale: scale);
        }
      }
    }
    canvas.drawPath(shaded, ink);
    canvas.drawPath(crosses, cross);

    if (win > 0) {
      final glow = Paint();
      for (var i = 0; i < n * n; i++) {
        final a = winSweepAt(i, n, win);
        if (a <= 0) continue;
        glow.color = theme.success.withValues(alpha: 0.45 * a);
        canvas.drawRect(grid.rect(i), glow);
      }
    }

    // Rules: a hairline between every square, a heavier one every five, and
    // the outline. One cached path per weight and size.
    final key = (n, (cell * 4).round(), (lead * 4).round());
    final hairs = _rules.at(('hair', key), () {
      final path = Path();
      for (var k = 1; k < n; k++) {
        if (k % 5 == 0) continue;
        path
          ..moveTo(lead + k * cell, lead)
          ..lineTo(lead + k * cell, lead + span)
          ..moveTo(lead, lead + k * cell)
          ..lineTo(lead + span, lead + k * cell);
      }
      return path;
    });
    final fives = _rules.at(('five', key), () {
      final path = Path();
      for (var k = 5; k < n; k += 5) {
        // Carried out into the gutters, so a clue's place in its group of
        // five reads without counting back from the edge.
        path
          ..moveTo(lead + k * cell, lead * 0.18)
          ..lineTo(lead + k * cell, lead + span)
          ..moveTo(lead * 0.18, lead + k * cell)
          ..lineTo(lead + span, lead + k * cell);
      }
      return path;
    });
    canvas.drawPath(
      hairs,
      Paint()
        ..color = theme.ink.withValues(alpha: 0.12)
        ..strokeWidth = 1
        ..style = PaintingStyle.stroke,
    );
    final heavy = Paint()
      ..color = theme.ink.withValues(alpha: 0.42)
      ..strokeWidth = math.max(1.4, cell * 0.05)
      ..style = PaintingStyle.stroke;
    canvas.drawPath(fives, heavy);
    canvas.drawRect(gridRect.deflate(heavy.strokeWidth / 2), heavy);

    _paintClues(canvas, grid, lead, focusRow, focusCol);
  }

  void _paintClues(
    Canvas canvas,
    GameGrid grid,
    double lead,
    int focusRow,
    int focusCol,
  ) {
    final n = board.size;
    final cell = grid.cell;
    final tiny = cell < 18;
    final step = cell * 0.6;

    Color tone(bool bad, bool done, bool focused) => bad
        ? theme.danger
        : done
        ? theme.inkMuted.withValues(alpha: 0.45)
        : focused
        ? theme.accent
        : theme.ink;

    TextStyle style(Color color) => theme.body.copyWith(
      letterSpacing: 0,
      color: color,
      // Rounded so a board drawn at one size reuses one set of laid-out
      // digits rather than a fresh set per fractional pixel.
      fontSize: (cell * 0.46 * 2).roundToDouble() / 2,
      fontWeight: FontWeight.w600,
      height: 1,
      fontFeatures: const [FontFeature.tabularFigures()],
    );

    // Rows: right-aligned against the grid, read left to right.
    for (var r = 0; r < n && r < board.rows.length; r++) {
      final runs = board.rows[r].isEmpty ? const [0] : board.rows[r];
      final color = tone(
        trouble.rows.contains(r),
        satisfiedRows.contains(r),
        r == focusRow,
      );
      final cy = lead + (r + 0.5) * cell;
      if (tiny) {
        _bars(canvas, runs, Offset(lead - cell * 0.4, cy), cell, color, true);
        continue;
      }
      for (var k = 0; k < runs.length; k++) {
        final x = lead - cell * 0.42 - (runs.length - 1 - k) * step;
        _labels.paint(canvas, Offset(x, cy), '${runs[k]}', style(color));
      }
    }

    // Columns: bottom-aligned against the grid, read top to bottom.
    for (var c = 0; c < n && c < board.cols.length; c++) {
      final runs = board.cols[c].isEmpty ? const [0] : board.cols[c];
      final color = tone(
        trouble.cols.contains(c),
        satisfiedCols.contains(c),
        c == focusCol,
      );
      final cx = lead + (c + 0.5) * cell;
      if (tiny) {
        _bars(canvas, runs, Offset(cx, lead - cell * 0.4), cell, color, false);
        continue;
      }
      for (var k = 0; k < runs.length; k++) {
        final y = lead - cell * 0.42 - (runs.length - 1 - k) * step;
        _labels.paint(canvas, Offset(cx, y), '${runs[k]}', style(color));
      }
    }
  }

  /// A clue at tile size: one bar per run, its length the run's, laid back
  /// from [end] toward the edge of the board.
  void _bars(
    Canvas canvas,
    List<int> runs,
    Offset end,
    double cell,
    Color color,
    bool horizontal,
  ) {
    final paint = Paint()..color = color.withValues(alpha: color.a * 0.8);
    final thick = cell * 0.34;
    var at = 0.0;
    for (var k = runs.length - 1; k >= 0; k--) {
      final len = runs[k] == 0 ? thick : cell * (0.22 + 0.12 * runs[k]);
      final rect = horizontal
          ? Rect.fromLTWH(end.dx - at - len, end.dy - thick / 2, len, thick)
          : Rect.fromLTWH(end.dx - thick / 2, end.dy - at - len, thick, len);
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, Radius.circular(thick / 2)),
        paint,
      );
      at += len + cell * 0.18;
    }
  }

  @override
  bool shouldRepaint(NonogramBoardPainter old) =>
      old.board != board ||
      old.theme != theme ||
      old.cells != cells ||
      old.trouble != trouble ||
      old.satisfiedRows != satisfiedRows ||
      old.satisfiedCols != satisfiedCols ||
      old.focus != focus ||
      old.popCell != popCell ||
      old.pop != pop ||
      old.win != win;
}
