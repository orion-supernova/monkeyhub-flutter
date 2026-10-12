/// The party games' picture, for the start sheet's tiles and the banner's
/// list: where a turn game shows its opening board, a party game has no board
/// to show, so it shows what it is about. Two dice mid-roll, a fan of cards
/// with one that is not like the others, three racers nearing a line.
///
/// Drawn from the same parts the tables use (the real dice painter, the seat
/// colours), so the tile looks like the game it opens.
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../theme/theme_preference.dart';
import '../theme/theme_scope.dart';
import '../turn_games/board/seat_palette.dart';
import 'dice.dart';

class PartyGameArt extends StatelessWidget {
  const PartyGameArt({super.key, required this.game});

  final String game;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final palette = SeatPalette(theme);
    final (wash, art) = switch (game) {
      'liarsdice' => (palette.wash(0), _dice),
      'imposter' => (palette.wash(4), _cards),
      'race' => (palette.wash(1), _race),
      _ => (theme.ink.withValues(alpha: 0.05), _blank),
    };
    return ColoredBox(
      color: Color.alphaBlend(wash, theme.ink.withValues(alpha: 0.03)),
      child: LayoutBuilder(
        builder: (context, box) => art(theme, palette, box.biggest.shortestSide),
      ),
    );
  }

  static Widget _blank(AppTheme theme, SeatPalette palette, double side) =>
      const SizedBox.expand();

  static Widget _dice(AppTheme theme, SeatPalette palette, double side) {
    final d = side * 0.34;
    return Stack(
      alignment: Alignment.center,
      children: [
        Transform.translate(
          offset: Offset(-d * 0.42, d * 0.12),
          child: Transform.rotate(angle: -0.26, child: DieFace(face: 5, size: d)),
        ),
        Transform.translate(
          offset: Offset(d * 0.5, -d * 0.18),
          child: Transform.rotate(angle: 0.2, child: DieFace(face: 3, size: d)),
        ),
      ],
    );
  }

  static Widget _cards(AppTheme theme, SeatPalette palette, double side) {
    final w = side * 0.30;
    final h = w * 1.36;
    Widget card(Color fill, {Widget? child}) => Container(
      width: w,
      height: h,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: fill,
        borderRadius: BorderRadius.circular(w * 0.16),
        border: Border.all(color: Colors.black.withValues(alpha: 0.08)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.12),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: child,
    );
    final face = theme.isLight ? Colors.white : const Color(0xFFF4F1EA);
    return Stack(
      alignment: Alignment.center,
      children: [
        Transform.translate(
          offset: Offset(-w * 0.62, h * 0.06),
          child: Transform.rotate(angle: -0.32, child: card(palette.fill(1))),
        ),
        Transform.translate(
          offset: Offset(w * 0.62, h * 0.06),
          child: Transform.rotate(angle: 0.32, child: card(palette.fill(3))),
        ),
        card(
          face,
          child: Text(
            '?',
            style: TextStyle(
              fontSize: w * 0.72,
              height: 1,
              fontWeight: FontWeight.w900,
              color: theme.danger,
            ),
          ),
        ),
      ],
    );
  }

  static Widget _race(AppTheme theme, SeatPalette palette, double side) =>
      CustomPaint(
        size: Size.square(side),
        painter: _RacePainter(
          fills: [palette.fill(0), palette.fill(1), palette.fill(2)],
          track: theme.ink.withValues(alpha: 0.10),
          line: theme.ink.withValues(alpha: 0.55),
        ),
      );
}

/// Three lanes, three bars at different lengths, a chequered line on the
/// right.
class _RacePainter extends CustomPainter {
  _RacePainter({required this.fills, required this.track, required this.line});

  final List<Color> fills;
  final Color track;
  final Color line;

  static const _lengths = [0.86, 0.62, 0.74];

  @override
  void paint(Canvas canvas, Size size) {
    final s = math.min(size.width, size.height);
    final left = s * 0.16;
    final right = s * 0.80;
    final h = s * 0.085;
    final p = Paint();
    for (var i = 0; i < 3; i++) {
      final y = s * (0.34 + i * 0.16);
      final r = Radius.circular(h / 2);
      p.color = track;
      canvas.drawRRect(
        RRect.fromLTRBR(left, y - h / 2, right, y + h / 2, r),
        p,
      );
      final end = left + (right - left) * _lengths[i];
      p.color = fills[i];
      canvas.drawRRect(RRect.fromLTRBR(left, y - h / 2, end, y + h / 2, r), p);
      canvas.drawCircle(Offset(end, y), h * 0.95, p);
    }
    // The finish line: a chequered strip.
    final cell = s * 0.04;
    final x = right + s * 0.05;
    for (var k = 0; k < 12; k++) {
      final top = s * 0.24 + k * cell;
      p.color = line;
      canvas.drawRect(
        Rect.fromLTWH(x + (k.isEven ? 0 : cell), top, cell, cell),
        p,
      );
    }
  }

  @override
  bool shouldRepaint(_RacePainter old) =>
      old.track != track ||
      old.line != line ||
      old.fills[0] != fills[0] ||
      old.fills[1] != fills[1] ||
      old.fills[2] != fills[2];
}
