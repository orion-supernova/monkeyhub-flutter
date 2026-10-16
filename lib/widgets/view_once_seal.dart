import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'capture_glyphs.dart' show ViewOnceGlyph;

/// The view-once seal: a ring around a "1", filled while the media can still
/// be opened and struck through once it can't.
///
/// One primitive for every sealed shape — the photo tile, the voice pill and
/// the video-note disc all wear this, so "this plays once" reads the same in a
/// transcript whatever kind of message it is on. The numeral is the same one
/// the camera editor's arm control and the fullscreen viewer's badge draw.
class ViewOnceSeal extends StatelessWidget {
  const ViewOnceSeal({
    super.key,
    required this.color,
    required this.struck,
    this.size = 44,
  });

  final Color color;

  /// Spent: nothing left to open here.
  final bool struck;

  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _ViewOnceSealPainter(color: color, struck: struck),
        child: Center(
          child: Text(
            '1',
            style: TextStyle(
              color: color,
              // 18 at the photo tile's 44pt, and in proportion everywhere else.
              fontSize: size * 18 / 44,
              fontWeight: FontWeight.w700,
              height: 1,
              decoration: TextDecoration.none,
            ),
          ),
        ),
      ),
    );
  }
}

/// The small "1" a sealed voice message or video note wears on its play
/// button's bottom-trailing corner — Telegram's view-once mark.
///
/// The composer's own [ViewOnceGlyph], in its armed state (`on: 1`: a solid
/// ring with the "1" knocked out), so the mark the recipient sees is the one
/// the sender switched on. Solid rather than the dashed `on: 0`: at sixteen
/// points a dashed ring breaks up into dots over a busy disc.
///
/// [ring] is a cut-out in the colour behind the button, so the badge reads as
/// sitting on top of it rather than as a blot on its edge.
class ViewOnceCornerBadge extends StatelessWidget {
  const ViewOnceCornerBadge({
    super.key,
    required this.color,
    required this.knockout,
    this.ring,
    this.size = 18,
  });

  final Color color;
  final Color knockout;
  final Color? ring;
  final double size;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: SizedBox(
        width: size,
        height: size,
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (ring != null)
              DecoratedBox(
                decoration: BoxDecoration(color: ring, shape: BoxShape.circle),
              ),
            Center(
              child: ViewOnceGlyph(
                color: color,
                knockout: knockout,
                on: 1,
                size: size,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ViewOnceSealPainter extends CustomPainter {
  const _ViewOnceSealPainter({required this.color, required this.struck});

  final Color color;
  final bool struck;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = math.min(size.width, size.height) / 2 - 1;
    if (!struck) {
      // A disc behind the numeral, so a live seal reads as a wax stamp rather
      // than an outline waiting to be filled in.
      canvas.drawCircle(
        c,
        r,
        Paint()
          ..style = PaintingStyle.fill
          ..isAntiAlias = true
          ..color = color.withValues(alpha: 0.12),
      );
    }
    final p = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4
      ..isAntiAlias = true
      ..color = color;
    canvas.drawCircle(c, r, p);
    if (!struck) return;
    // Trailing-to-leading slash, the same direction a "no" symbol reads. Held
    // back from full strength: spent is a state, not an error.
    final d = r * 0.72;
    canvas.drawLine(
      Offset(c.dx - d, c.dy + d),
      Offset(c.dx + d, c.dy - d),
      p
        ..strokeWidth = 1.3
        ..color = color.withValues(alpha: 0.7),
    );
  }

  @override
  bool shouldRepaint(_ViewOnceSealPainter old) =>
      old.color != color || old.struck != struck;
}
