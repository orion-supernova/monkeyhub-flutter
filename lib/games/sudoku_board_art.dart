import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import '../models/daily_game.dart';
import '../theme/app_theme.dart';
import 'game_canvas.dart';

/// Paints a Mini Sudoku board — the 2×3 boxes, the printed and entered digits,
/// pencil notes, and the highlight that follows the selected cell.
///
/// Painted, like the other three, so the heavy box rules can be drawn on the
/// boundaries between cells rather than as borders belonging to one side of
/// them. A per-cell border makes every internal box rule double-thick on one
/// edge and thin on the other, which reads as a rendering fault.
class SudokuBoardPainter extends CustomPainter {
  SudokuBoardPainter({
    required this.board,
    required this.theme,
    this.cells = const [],
    this.notes = const {},
    this.conflicts = const {},
    this.selected,
    this.popCell,
    this.pop = 1,
    this.win = 0,
  });

  final SudokuBoard board;
  final AppTheme theme;

  /// The player's grid. Empty draws the printed board alone — the hub tile.
  final List<int> cells;

  /// Pencil marks per cell. A player's working, never validated against
  /// anything: notes are a scratchpad and marking one "wrong" would be the
  /// board doing the deduction the player came here to do.
  final Map<int, Set<int>> notes;

  final Set<int> conflicts;
  final int? selected;
  final int? popCell;
  final double pop;
  final double win;

  @override
  void paint(Canvas canvas, Size size) {
    final n = board.size;
    if (n == 0) return;
    final grid = GameGrid(side: math.min(size.width, size.height), n: n);
    final cell = grid.cell;
    final given = board.givens;

    final selectedValue =
        selected != null && cells.length > selected! ? cells[selected!] : 0;

    final fill = Paint()..style = PaintingStyle.fill;
    for (var i = 0; i < n * n; i++) {
      final isGiven = given.length > i && given[i] != sudokuEmpty;
      final value = cells.length > i ? cells[i] : sudokuEmpty;
      final peer = selected != null && _peers(i, selected!, n);
      // Three levels of emphasis, in the order a player looks for them: the
      // cell they are on, every cell that constrains it, and every cell holding
      // the same digit. Highlighting peers is what turns scanning a 6×6 from a
      // chore into a glance.
      fill.color = conflicts.contains(i)
          ? theme.danger.withValues(alpha: 0.20)
          : i == selected
          ? theme.accent.withValues(alpha: 0.24)
          : selectedValue != sudokuEmpty && value == selectedValue
          ? theme.accent.withValues(alpha: 0.14)
          : peer
          ? theme.accent.withValues(alpha: 0.06)
          : isGiven
          ? theme.surfaceRaised
          : theme.surfaceSunken;
      canvas.drawRect(grid.rect(i).deflate(0.3), fill);

      if (win > 0) {
        final d = ((i ~/ n) + (i % n)) / (2 * (n - 1));
        final t = (win * 1.6 - d).clamp(0.0, 1.0);
        if (t > 0) {
          canvas.drawRect(
            grid.rect(i).deflate(0.3),
            Paint()
              ..color = theme.success.withValues(
                alpha: 0.5 * math.sin(t * math.pi).abs(),
              ),
          );
        }
      }
    }

    final hair = Paint()
      ..color = theme.ink.withValues(alpha: 0.16)
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;
    final rule = Paint()
      ..color = theme.ink.withValues(alpha: 0.62)
      ..strokeWidth = math.max(1.6, cell * 0.05)
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    for (var i = 0; i < n * n; i++) {
      final r = grid.rect(i);
      final row = i ~/ n;
      final col = i % n;
      if (col < n - 1) {
        final boxEdge = (col + 1) % SudokuBoard.boxCols == 0;
        canvas.drawLine(r.topRight, r.bottomRight, boxEdge ? rule : hair);
      }
      if (row < n - 1) {
        final boxEdge = (row + 1) % SudokuBoard.boxRows == 0;
        canvas.drawLine(r.bottomLeft, r.bottomRight, boxEdge ? rule : hair);
      }
    }
    canvas.drawRect(
      Rect.fromLTWH(0, 0, cell * n, cell * n).deflate(rule.strokeWidth / 2),
      rule,
    );

    final glyph = TextPainter(textDirection: TextDirection.ltr);
    for (var i = 0; i < n * n; i++) {
      final isGiven = given.length > i && given[i] != sudokuEmpty;
      final value = isGiven
          ? given[i]
          : (cells.length > i ? cells[i] : sudokuEmpty);

      if (value == sudokuEmpty) {
        final pencil = notes[i];
        if (pencil == null || pencil.isEmpty) continue;
        for (final v in pencil) {
          final slot = v - 1;
          final origin = grid.origin(i);
          paintGlyph(
            canvas,
            glyph,
            origin +
                Offset(
                  cell * (0.22 + 0.28 * (slot % 3)),
                  cell * (0.28 + 0.42 * (slot ~/ 3)),
                ),
            '$v',
            TextStyle(
              color: theme.inkMuted,
              fontSize: cell * 0.2,
              height: 1,
            ),
          );
        }
        continue;
      }

      final scale = i == popCell ? _popScale(pop) : 1.0;
      paintGlyph(
        canvas,
        glyph,
        grid.center(i),
        '$value',
        TextStyle(
          // Printed digits are heavier and in plain ink; the player's own are
          // the accent, so a finished grid still shows what it started as.
          color: conflicts.contains(i)
              ? theme.danger
              : isGiven
              ? theme.ink
              : theme.accent,
          fontSize: cell * 0.5 * scale,
          fontWeight: isGiven ? FontWeight.w700 : FontWeight.w500,
          height: 1,
        ),
      );
    }
  }

  /// Whether [a] constrains [b] — same row, column or box.
  bool _peers(int a, int b, int n) {
    if (a == b) return false;
    if (a ~/ n == b ~/ n || a % n == b % n) return true;
    int box(int i) =>
        (i ~/ n ~/ SudokuBoard.boxRows) * (n ~/ SudokuBoard.boxCols) +
        (i % n) ~/ SudokuBoard.boxCols;
    return box(a) == box(b);
  }

  double _popScale(double t) => 1 + 0.30 * math.sin(t.clamp(0.0, 1.0) * math.pi);

  @override
  bool shouldRepaint(SudokuBoardPainter old) =>
      old.board != board ||
      old.theme != theme ||
      old.cells != cells ||
      old.notes != notes ||
      old.conflicts != conflicts ||
      old.selected != selected ||
      old.popCell != popCell ||
      old.pop != pop ||
      old.win != win;
}
