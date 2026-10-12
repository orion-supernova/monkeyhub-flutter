import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import '../models/daily_game.dart';
import '../theme/app_theme.dart';
import 'game_canvas.dart';

/// Paints a Minesweeper field — raised squares still to open, flat ones with
/// their numbers, flags, and any mine the player walked onto.
///
/// The numbers keep the classic hues (1 blue, 2 green, 3 red, and so on).
/// Thirty years of the desktop game taught everybody to read a 3 before they
/// read the digit, and on a board that is mostly numbers that head start is
/// most of what makes a field scan quickly. They are lifted for dark themes so
/// a navy 4 does not vanish into a navy background.
///
/// Pass no [cells] and it draws today's field unopened, with the opening
/// square marked: the hub's tile, which gives away nothing about where the
/// mines are.
class MinesweeperBoardPainter extends CustomPainter {
  MinesweeperBoardPainter({
    required this.board,
    required this.theme,
    this.cells = const [],
    this.mines = const [],
    this.showMines = false,
    this.popCell,
    this.pop = 1,
    this.win = 0,
  });

  final MinesweeperBoard board;
  final AppTheme theme;

  /// [minesweeperHidden], 0..8 revealed, [minesweeperFlagged] or
  /// [minesweeperStruck] per square.
  final List<int> cells;

  /// The decoded layout, only consulted when [showMines] is on — a finished
  /// board shows where everything was.
  final List<int> mines;
  final bool showMines;

  final int? popCell;
  final double pop;
  final double win;

  static final _tiles = PathCache();
  static final _labels = GlyphTextCache();

  bool get _dark => theme.background.computeLuminance() < 0.4;

  Color _number(int v) {
    const light = <Color>[
      Color(0xFF1F5FD6), // 1
      Color(0xFF1E8A3A), // 2
      Color(0xFFD12F2F), // 3
      Color(0xFF2B2D8F), // 4
      Color(0xFF8E2424), // 5
      Color(0xFF178A8A), // 6
      Color(0xFF3A3A3C), // 7
      Color(0xFF7C7C80), // 8
    ];
    const dark = <Color>[
      Color(0xFF6EA8FF),
      Color(0xFF5FD38A),
      Color(0xFFFF6B6B),
      Color(0xFFA9A2FF),
      Color(0xFFFF9C7A),
      Color(0xFF55D6D2),
      Color(0xFFE5E5EA),
      Color(0xFFAEAEB2),
    ];
    return (_dark ? dark : light)[(v - 1).clamp(0, 7)];
  }

  @override
  void paint(Canvas canvas, Size size) {
    final n = board.size;
    if (n == 0) return;
    final grid = GameGrid(side: math.min(size.width, size.height), n: n);
    final cell = grid.cell;
    final radius = Radius.circular(cell * 0.18);

    // The field starts as one cached path of raised squares; opened ones are
    // drawn flat over it.
    final field = _tiles.at((n, (cell * 4).round()), () {
      final path = Path();
      for (var i = 0; i < n * n; i++) {
        path.addRRect(
          RRect.fromRectAndRadius(grid.rect(i).deflate(cell * 0.05), radius),
        );
      }
      return path;
    });
    // Closed squares carry weight and a lit edge, so they read as tiles still
    // to be lifted; opened ones sink almost flat into the board. The two
    // states have to separate at a glance, in both themes, or the field reads
    // as one grey sheet with numbers on it.
    final raised = theme.ink.withValues(alpha: _dark ? 0.22 : 0.17);
    canvas.drawPath(field, Paint()..color = theme.background);
    canvas.drawPath(field, Paint()..color = raised);
    canvas.drawPath(
      field,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = math.max(1, cell * 0.03)
        ..color = const Color(0xFFFFFFFF).withValues(alpha: _dark ? 0.08 : 0.5),
    );

    final open = Paint()
      ..color = Color.alphaBlend(
        theme.ink.withValues(alpha: _dark ? 0.05 : 0.035),
        theme.background,
      );
    final glyph = TextPainter(textDirection: TextDirection.ltr);
    final flagPaint = Paint()..color = theme.danger;
    final minePaint = Paint()..color = theme.ink;

    for (var i = 0; i < n * n; i++) {
      final v = cells.length > i ? cells[i] : minesweeperHidden;
      final box = RRect.fromRectAndRadius(
        grid.rect(i).deflate(cell * 0.05),
        radius,
      );
      final center = grid.center(i);
      final scale = i == popCell
          ? 1 + 0.25 * math.sin(pop.clamp(0.0, 1.0) * math.pi)
          : 1.0;

      if (v >= 0 && v <= 8) {
        canvas.drawRRect(box, open);
        final glow = winSweepAt(i, n, win);
        if (glow > 0) {
          canvas.drawRRect(
            box,
            Paint()..color = theme.success.withValues(alpha: 0.4 * glow),
          );
        }
        if (v > 0) {
          final style = theme.body.copyWith(
            letterSpacing: 0,
            color: _number(v),
            fontSize: scale == 1 ? _half(cell * 0.5) : cell * 0.5 * scale,
            fontWeight: FontWeight.w700,
            height: 1,
          );
          if (scale == 1) {
            _labels.paint(canvas, center, '$v', style);
          } else {
            paintGlyph(canvas, glyph, center, '$v', style);
          }
        }
        continue;
      }

      if (v == minesweeperStruck) {
        canvas.drawRRect(
          box,
          Paint()..color = theme.danger.withValues(alpha: 0.28),
        );
        mineGlyph.paint(canvas, center, cell, Paint()..color = theme.danger,
            scale: scale);
        continue;
      }

      final isMine = showMines && mines.length > i && mines[i] == 1;
      if (v == minesweeperFlagged) {
        flagGlyph.paint(canvas, center, cell, flagPaint, scale: scale);
        continue;
      }
      if (isMine) {
        minePaint.color = theme.ink.withValues(alpha: 0.7);
        mineGlyph.paint(canvas, center, cell, minePaint);
        continue;
      }
      if (cells.isEmpty && i == board.start) {
        // The tile's one hint of where to begin: the square the screen opens
        // for the player, marked rather than opened, so the tile shows no
        // numbers that would hint at today's layout.
        canvas.drawCircle(
          center,
          cell * 0.13,
          Paint()..color = theme.accent,
        );
      }
    }
  }

  @override
  bool shouldRepaint(MinesweeperBoardPainter old) =>
      old.board != board ||
      old.theme != theme ||
      old.cells != cells ||
      old.mines != mines ||
      old.showMines != showMines ||
      old.popCell != popCell ||
      old.pop != pop ||
      old.win != win;
}

/// Rounds a font size to the half pixel, so the cached labels of a board drawn
/// at one size are reused rather than re-laid out per fractional pixel.
double _half(double size) => (size * 2).roundToDouble() / 2;
