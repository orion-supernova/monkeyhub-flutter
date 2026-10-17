import 'dart:math' as math;
import 'dart:ui' show lerpDouble;

import 'package:flutter/widgets.dart';

// Drawn line glyphs for the voice and video note recorder.
//
// Every glyph is drawn on a 24-unit grid with ~2 units of air, scaled to
// `size`, so a row of them sits at one optical size. The stroke is shared
// (see [captureGlyphStroke]) and every animation is geometry the caller
// drives with plain 0..1 doubles: a hinge, a fold, a draw-on, an overshoot,
// never a tint. Reduce Motion is the caller's: it passes the final values.

/// The line weight, in logical pixels, of every glyph at [size]: matched to
/// the semibold label beside it. It grows a little slower than the glyph, the
/// way SF Symbols thin out as they scale, so a 16pt glyph doesn't go spidery
/// and a 28pt one doesn't go heavy.
double captureGlyphStroke(double size) =>
    2.05 * math.pow(size / 20, 0.8).toDouble();

/// A 0..1 window of [t]: 0 before [from], 1 after [to], linear between.
double glyphSpan(double t, double from, double to) =>
    ((t - from) / (to - from)).clamp(0.0, 1.0);

/// The shared frame: scales the canvas to the 24-unit grid, centers it in a
/// non-square box, and hands [draw] a line paint at the shared weight and a
/// fill paint in the same ink.
abstract class GlyphGridPainter extends CustomPainter {
  const GlyphGridPainter(this.color, {super.repaint});

  final Color color;

  /// The ink both paints start in. [color] unless a painter animates it
  /// itself (a call control lerping dark onto its lit fill), reading it per
  /// paint so a tick never rebuilds the widget.
  Color get ink => color;

  void draw(Canvas canvas, Paint line, Paint fill);

  @override
  void paint(Canvas canvas, Size size) {
    final side = size.shortestSide;
    if (side <= 0) return;
    final s = side / 24;
    canvas.save();
    canvas.translate((size.width - side) / 2, (size.height - side) / 2);
    canvas.scale(s);
    final line = Paint()
      ..color = ink
      ..style = PaintingStyle.stroke
      ..strokeWidth = captureGlyphStroke(side) / s
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final fill = Paint()..color = ink;
    draw(canvas, line, fill);
    canvas.restore();
  }
}

/// The square box every glyph widget paints into.
class _Glyph extends StatelessWidget {
  const _Glyph({required this.size, required this.painter});

  final double size;
  final CustomPainter painter;

  @override
  Widget build(BuildContext context) =>
      CustomPaint(size: Size.square(size), painter: painter);
}

// ---------------------------------------------------------------------------
// Padlock

/// A padlock whose shackle seats as the recording locks. At [closed] 0 the
/// shackle is lifted, its right leg out of the body; toward 1 it drops and
/// the right leg slides into the body, and in the last stretch a keyhole
/// grows in the body's center. Values a little past 0..1 extrapolate, so a
/// spring can bounce the shackle.
class PadlockGlyph extends StatelessWidget {
  const PadlockGlyph({
    super.key,
    required this.closed,
    required this.color,
    this.size = 20,
  });

  final double closed;
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) => _Glyph(
        size: size,
        painter: _PadlockPainter(color: color, closed: closed),
      );
}

class _PadlockPainter extends GlyphGridPainter {
  const _PadlockPainter({required Color color, required this.closed})
      : super(color);

  final double closed;

  @override
  void draw(Canvas canvas, Paint line, Paint fill) {
    const bodyTop = 11.5;
    canvas.drawRRect(
      RRect.fromLTRBR(5, bodyTop, 19, 21.5, const Radius.circular(2.8)),
      line,
    );

    // The shackle lifts straight up; the left leg stays seated (it is the
    // hinge), the right one comes out and shortens to a stub.
    final c = closed;
    final lift = 2.6 * (1 - c);
    final arcY = 8.0 - lift;
    const r = 3.5;
    final rightEnd = lerpDouble(arcY + 1.4, bodyTop, c.clamp(0.0, 1.0))!;
    canvas.drawPath(
      Path()
        ..moveTo(12 - r, bodyTop)
        ..lineTo(12 - r, arcY)
        ..arcToPoint(Offset(12 + r, arcY), radius: const Radius.circular(r))
        ..lineTo(12 + r, rightEnd),
      line,
    );

    // The keyhole grows in as the shackle seats: a line that lengthens and
    // thickens from nothing, so it never pops.
    final k = glyphSpan(c, 0.6, 1);
    if (k > 0) {
      canvas.drawLine(
        Offset(12, 16.5 - 0.9 * k),
        Offset(12, 16.5 + 0.9 * k),
        Paint()
          ..color = color
          ..strokeWidth = line.strokeWidth * k
          ..strokeCap = StrokeCap.round,
      );
    }
  }

  @override
  bool shouldRepaint(_PadlockPainter old) =>
      old.color != color || old.closed != closed;
}

// ---------------------------------------------------------------------------
// Trash

/// A trash can whose lid hinges open from its right end as [open] rises,
/// the left edge lifting like a flip lid. [gulp] is a one-shot swallow run
/// 0 → 1: the lid slams shut whatever [open] says, bounces once, and the can
/// squashes into the floor and stretches back. Leave [gulp] at 0 otherwise.
class TrashGlyph extends StatelessWidget {
  const TrashGlyph({
    super.key,
    required this.color,
    this.open = 0,
    this.gulp = 0,
    this.size = 20,
  });

  final Color color;
  final double open;
  final double gulp;
  final double size;

  @override
  Widget build(BuildContext context) => _Glyph(
        size: size,
        painter: _TrashPainter(color: color, open: open, gulp: gulp),
      );
}

class _TrashPainter extends GlyphGridPainter {
  const _TrashPainter({
    required Color color,
    required this.open,
    required this.gulp,
  }) : super(color);

  final double open;
  final double gulp;

  @override
  void draw(Canvas canvas, Paint line, Paint fill) {
    // The swallow: the lid slams in the first third (accelerating, it's
    // falling), then the can squashes and stretches back in a decaying
    // wobble, and the lid bounces once off the rim.
    final slam = Curves.easeIn.transform(glyphSpan(gulp, 0, 0.3));
    final u = glyphSpan(gulp, 0.3, 1);
    final wobble =
        gulp > 0.3 ? math.sin(2 * math.pi * u) * math.pow(1 - u, 1.6) : 0.0;
    final bounce =
        gulp > 0.3 ? 0.22 * math.max(0, -math.sin(2 * math.pi * u)) * (1 - u) : 0.0;
    final lid = open * (1 - slam) + bounce;

    // Squash and stretch anchored at the floor, volume roughly kept.
    canvas.save();
    canvas.translate(12, 21.5);
    canvas.scale(1 + 0.09 * wobble, 1 - 0.16 * wobble);
    canvas.translate(-12, -21.5);

    // The can: gently tapered, no rim of its own, the lid is its top.
    canvas.drawPath(
      Path()
        ..moveTo(6.2, 10)
        ..lineTo(7.1, 19.5)
        ..arcToPoint(
          const Offset(9.1, 21.5),
          radius: const Radius.circular(2),
          clockwise: false,
        )
        ..lineTo(14.9, 21.5)
        ..arcToPoint(
          const Offset(16.9, 19.5),
          radius: const Radius.circular(2),
          clockwise: false,
        )
        ..lineTo(17.8, 10),
      line,
    );
    // Two ribs, upright: leaning them with the taper reads as a letter.
    canvas.drawLine(const Offset(10, 13), const Offset(10, 18.5), line);
    canvas.drawLine(const Offset(14, 13), const Offset(14, 18.5), line);

    // The lid swings about a hinge over the can's right rim, its short tail
    // dipping past it like a real flip lid, and lifts clear as it goes: a
    // lid that stays on the rim reads as a strike-through at 20pt.
    const hinge = Offset(18.5, 7);
    canvas.save();
    canvas.translate(hinge.dx, hinge.dy - 2.0 * lid);
    canvas.rotate(-0.46 * lid);
    canvas.translate(-hinge.dx, -hinge.dy);
    canvas.drawLine(const Offset(4, 7), const Offset(20, 7), line);
    canvas.drawPath(
      Path()
        ..moveTo(9.5, 7)
        ..lineTo(9.5, 5.9)
        ..arcToPoint(const Offset(11, 4.4), radius: const Radius.circular(1.5))
        ..lineTo(13, 4.4)
        ..arcToPoint(const Offset(14.5, 5.9), radius: const Radius.circular(1.5))
        ..lineTo(14.5, 7),
      line,
    );
    canvas.restore();
    canvas.restore();
  }

  @override
  bool shouldRepaint(_TrashPainter old) =>
      old.color != color || old.open != open || old.gulp != gulp;
}

// ---------------------------------------------------------------------------
// Mic

/// A microphone: capsule, yoke and stem. [level] fills the capsule from the
/// bottom with solid ink, a live input meter (0 is empty). [filled] draws
/// the capsule solid, for a white glyph on the accent disc.
class MicGlyph extends StatelessWidget {
  const MicGlyph({
    super.key,
    required this.color,
    this.level = 0,
    this.filled = false,
    this.size = 20,
  });

  final Color color;
  final double level;
  final bool filled;
  final double size;

  @override
  Widget build(BuildContext context) => _Glyph(
        size: size,
        painter: _MicPainter(color: color, level: filled ? 1 : level),
      );
}

class _MicPainter extends GlyphGridPainter {
  const _MicPainter({required Color color, required this.level}) : super(color);

  final double level;

  @override
  void draw(Canvas canvas, Paint line, Paint fill) {
    final capsule =
        RRect.fromLTRBR(8.5, 2.5, 15.5, 14, const Radius.circular(3.5));
    final l = level.clamp(0.0, 1.0);
    if (l > 0) {
      // The meter: a flat surface rising inside the capsule, clipped to it.
      canvas.save();
      canvas.clipRRect(capsule);
      canvas.drawRect(
        Rect.fromLTRB(8.5, 14 - 11.5 * l, 15.5, 14),
        fill,
      );
      canvas.restore();
    }
    canvas.drawRRect(capsule, line);
    canvas.drawPath(
      Path()
        ..moveTo(5.5, 10.5)
        ..arcToPoint(
          const Offset(18.5, 10.5),
          radius: const Radius.circular(6.5),
          clockwise: false,
        ),
      line,
    );
    canvas.drawLine(const Offset(12, 17), const Offset(12, 21.5), line);
  }

  @override
  bool shouldRepaint(_MicPainter old) =>
      old.color != color || old.level != level;
}

// ---------------------------------------------------------------------------
// Video note

/// The video-note mode glyph: a camcorder, body and lens wedge, as SF's
/// `video`. A camcorder rather than a round "note" shape because it has to
/// read as *video* beside the mic at a glance, and a lone circle reads as
/// record or stop. [filled] draws it solid for the accent disc.
class VideoNoteGlyph extends StatelessWidget {
  const VideoNoteGlyph({
    super.key,
    required this.color,
    this.filled = false,
    this.size = 20,
  });

  final Color color;
  final bool filled;
  final double size;

  @override
  Widget build(BuildContext context) => _Glyph(
        size: size,
        painter: _VideoNotePainter(color: color, filled: filled),
      );
}

class _VideoNotePainter extends GlyphGridPainter {
  const _VideoNotePainter({required Color color, required this.filled})
      : super(color);

  final bool filled;

  @override
  void draw(Canvas canvas, Paint line, Paint fill) {
    final body = RRect.fromLTRBR(3, 7, 15.5, 17, const Radius.circular(3));
    final lens = Path()
      ..moveTo(17.8, 10.4)
      ..lineTo(21, 8.4)
      ..lineTo(21, 15.6)
      ..lineTo(17.8, 13.6)
      ..close();
    if (filled) {
      canvas.drawRRect(body, fill);
      canvas.drawPath(lens, fill);
    }
    canvas.drawRRect(body, line);
    canvas.drawPath(lens, line);
  }

  @override
  bool shouldRepaint(_VideoNotePainter old) =>
      old.color != color || old.filled != filled;
}

// ---------------------------------------------------------------------------
// Send

/// An upward arrow. [t] morphs it in: the shaft draws up from the floor,
/// then the head unfolds from the tip like an umbrella, opening a touch past
/// 45° and settling. At 1 it is a plain arrow.
class SendArrowGlyph extends StatelessWidget {
  const SendArrowGlyph({
    super.key,
    required this.color,
    this.t = 1,
    this.size = 20,
  });

  final Color color;
  final double t;
  final double size;

  @override
  Widget build(BuildContext context) => _Glyph(
        size: size,
        painter: _SendArrowPainter(color: color, t: t),
      );
}

class _SendArrowPainter extends GlyphGridPainter {
  const _SendArrowPainter({required Color color, required this.t})
      : super(color);

  final double t;

  @override
  void draw(Canvas canvas, Paint line, Paint fill) {
    if (t <= 0) return;
    const floor = 20.5;
    const tip = 4.0;
    final top = lerpDouble(
      floor,
      tip,
      Curves.easeOutCubic.transform(glyphSpan(t, 0, 0.6)),
    )!;
    canvas.drawLine(Offset(12, floor), Offset(12, top), line);
    _arrowHead(canvas, line, Offset(12, top), glyphSpan(t, 0.3, 1), floor - top);
  }

  @override
  bool shouldRepaint(_SendArrowPainter old) =>
      old.color != color || old.t != t;
}

/// The arrowhead at [tip], unfolding over [open] 0..1 from folded flat down
/// the shaft to 45° (overshooting on the way), arms no longer than [room].
void _arrowHead(Canvas canvas, Paint line, Offset tip, double open, double room) {
  if (open <= 0) return;
  final a = (math.pi / 4) * Curves.easeOutBack.transform(open);
  final arm = math.min(7.4, room);
  final dx = math.sin(a) * arm;
  final dy = math.cos(a) * arm;
  canvas.drawPath(
    Path()
      ..moveTo(tip.dx - dx, tip.dy + dy)
      ..lineTo(tip.dx, tip.dy)
      ..lineTo(tip.dx + dx, tip.dy + dy),
    line,
  );
}

/// The mic folding into the send arrow, for the moment a recording locks.
/// Over [t] 0 → 1 the capsule narrows and stretches into the shaft, the
/// yoke closes up into the stem, and the arrowhead unfolds at the top.
class MicSendMorphGlyph extends StatelessWidget {
  const MicSendMorphGlyph({
    super.key,
    required this.color,
    required this.t,
    this.filled = false,
    this.size = 20,
  });

  final Color color;
  final double t;

  /// The capsule drawn solid, as [MicGlyph.filled], for the accent disc.
  final bool filled;
  final double size;

  @override
  Widget build(BuildContext context) => _Glyph(
        size: size,
        painter: _MicSendMorphPainter(color: color, t: t, filled: filled),
      );
}

class _MicSendMorphPainter extends GlyphGridPainter {
  const _MicSendMorphPainter({
    required Color color,
    required this.t,
    required this.filled,
  }) : super(color);

  final double t;
  final bool filled;

  @override
  void draw(Canvas canvas, Paint line, Paint fill) {
    // The capsule thins into the shaft, reaching from the arrow's tip down
    // to the floor.
    final e = Curves.easeInOutCubic.transform(glyphSpan(t, 0, 0.5));
    final half = 3.5 * (1 - e);
    final capsule = RRect.fromLTRBR(
      12 - half,
      lerpDouble(2.5, 4, e)!,
      12 + half,
      lerpDouble(14, 20.5, e)!,
      Radius.circular(half),
    );
    if (filled && half > 0) canvas.drawRRect(capsule, fill);
    canvas.drawRRect(capsule, line);

    // The yoke shrinks into the stem as a cup, keeping its U: folding its
    // arms down instead makes a V under the stem, a down arrow.
    final y = Curves.easeOutCubic.transform(glyphSpan(t, 0, 0.3));
    if (y < 1) {
      final r = 6.5 * (1 - y);
      canvas.drawArc(
        Rect.fromCircle(center: Offset(12, 17 - r), radius: r),
        0,
        math.pi,
        false,
        line,
      );
    }
    final stemTop = lerpDouble(17, 20.5, e)!;
    final stemBottom = lerpDouble(21.5, 20.5, e)!;
    if (stemBottom > stemTop) {
      canvas.drawLine(Offset(12, stemTop), Offset(12, stemBottom), line);
    }
    // The head opens early, so the glyph reads as up from the first frames.
    _arrowHead(canvas, line, Offset(12, capsule.top), glyphSpan(t, 0.12, 0.9), 7.4);
  }

  @override
  bool shouldRepaint(_MicSendMorphPainter old) =>
      old.color != color || old.t != t || old.filled != filled;
}

// ---------------------------------------------------------------------------
// Transport

/// Pause: two solid rounded bars, as SF's `pause.fill`.
class PauseGlyph extends StatelessWidget {
  const PauseGlyph({super.key, required this.color, this.size = 20});

  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) =>
      _Glyph(size: size, painter: _PausePainter(color));
}

class _PausePainter extends GlyphGridPainter {
  const _PausePainter(super.color);

  @override
  void draw(Canvas canvas, Paint line, Paint fill) {
    const r = Radius.circular(1.4);
    canvas.drawRRect(RRect.fromLTRBR(6.9, 5.5, 10.3, 18.5, r), fill);
    canvas.drawRRect(RRect.fromLTRBR(13.7, 5.5, 17.1, 18.5, r), fill);
  }

  @override
  bool shouldRepaint(_PausePainter old) => old.color != color;
}

/// Stop: a solid rounded square, as SF's `stop.fill`.
class StopGlyph extends StatelessWidget {
  const StopGlyph({super.key, required this.color, this.size = 20});

  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) =>
      _Glyph(size: size, painter: _StopPainter(color));
}

class _StopPainter extends GlyphGridPainter {
  const _StopPainter(super.color);

  @override
  void draw(Canvas canvas, Paint line, Paint fill) {
    canvas.drawRRect(
      RRect.fromLTRBR(6, 6, 18, 18, const Radius.circular(3)),
      fill,
    );
  }

  @override
  bool shouldRepaint(_StopPainter old) => old.color != color;
}

// ---------------------------------------------------------------------------
// Flip camera

/// A camera with two arcing arrows chasing each other inside it, as SF's
/// `arrow.triangle.2.circlepath.camera`. [spin] turns the arrows: 0 → 1 is a
/// half turn, which lands on the same picture, so a one-shot spin per flip
/// never jumps.
class FlipCameraGlyph extends StatelessWidget {
  const FlipCameraGlyph({
    super.key,
    required this.color,
    this.spin = 0,
    this.size = 20,
  });

  final Color color;
  final double spin;
  final double size;

  @override
  Widget build(BuildContext context) => _Glyph(
        size: size,
        painter: _FlipCameraPainter(color: color, spin: spin),
      );
}

class _FlipCameraPainter extends GlyphGridPainter {
  const _FlipCameraPainter({required Color color, required this.spin})
      : super(color);

  final double spin;

  @override
  void draw(Canvas canvas, Paint line, Paint fill) {
    // Body with the viewfinder hump, one path so the joins stay round.
    const l = 3.0, r = 21.0, t = 7.4, b = 19.8, k = 3.0;
    canvas.drawPath(
      Path()
        ..moveTo(l + k, t)
        ..lineTo(8.2, t)
        ..lineTo(9.4, 4.9)
        ..lineTo(14.6, 4.9)
        ..lineTo(15.8, t)
        ..lineTo(r - k, t)
        ..arcToPoint(const Offset(r, t + k), radius: const Radius.circular(k))
        ..lineTo(r, b - k)
        ..arcToPoint(const Offset(r - k, b), radius: const Radius.circular(k))
        ..lineTo(l + k, b)
        ..arcToPoint(const Offset(l, b - k), radius: const Radius.circular(k))
        ..lineTo(l, t + k)
        ..arcToPoint(const Offset(l + k, t), radius: const Radius.circular(k))
        ..close(),
      line,
    );

    // The arrows: a lighter line so they don't clot inside the body, each
    // an arc with a solid head at its leading end.
    const centre = Offset(12, 13.6);
    const radius = 3.9;
    final thin = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = line.strokeWidth * 0.72
      ..strokeCap = StrokeCap.round;
    canvas.save();
    canvas.translate(centre.dx, centre.dy);
    canvas.rotate(math.pi * spin);
    for (var i = 0; i < 2; i++) {
      final start = -math.pi * 0.95 + i * math.pi;
      const sweep = math.pi * 0.5;
      canvas.drawArc(
        Rect.fromCircle(center: Offset.zero, radius: radius),
        start,
        sweep,
        false,
        thin,
      );
      // The head: a small triangle on the tangent at the arc's end.
      final end = start + sweep;
      final at = Offset(math.cos(end), math.sin(end)) * radius;
      final along = Offset(-math.sin(end), math.cos(end));
      final out = Offset(math.cos(end), math.sin(end));
      const h = 2.3;
      canvas.drawPath(
        Path()
          ..moveTo(at.dx + along.dx * h, at.dy + along.dy * h)
          ..lineTo(at.dx + out.dx * h * 0.8, at.dy + out.dy * h * 0.8)
          ..lineTo(at.dx - out.dx * h * 0.8, at.dy - out.dy * h * 0.8)
          ..close(),
        fill,
      );
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_FlipCameraPainter old) =>
      old.color != color || old.spin != spin;
}

// ---------------------------------------------------------------------------
// Chevron

/// A line chevron pointing [direction]: ‹ for "slide to cancel" (left), ^
/// for "slide up to lock" (up).
class ChevronGlyph extends StatelessWidget {
  const ChevronGlyph({
    super.key,
    required this.direction,
    required this.color,
    this.size = 20,
  });

  final AxisDirection direction;
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) => _Glyph(
        size: size,
        painter: _ChevronPainter(color: color, direction: direction),
      );
}

class _ChevronPainter extends GlyphGridPainter {
  const _ChevronPainter({required Color color, required this.direction})
      : super(color);

  final AxisDirection direction;

  @override
  void draw(Canvas canvas, Paint line, Paint fill) {
    // Drawn pointing left, then turned.
    final quarter = switch (direction) {
      AxisDirection.left => 0,
      AxisDirection.up => 1,
      AxisDirection.right => 2,
      AxisDirection.down => 3,
    };
    canvas.translate(12, 12);
    canvas.rotate(quarter * math.pi / 2);
    canvas.drawPath(
      Path()
        ..moveTo(3.4, -7.6)
        ..lineTo(-3.8, 0)
        ..lineTo(3.4, 7.6),
      line,
    );
  }

  @override
  bool shouldRepaint(_ChevronPainter old) =>
      old.color != color || old.direction != direction;
}

// ---------------------------------------------------------------------------
// Play once

/// The play-once toggle: a "1" in a ring. Off ([on] 0), the ring is dashed,
/// an unsealed promise; turning on closes the dashes into a solid ring and
/// floods it with [color], knocking the "1" out in [knockout]. Values past 1
/// overshoot the flood a touch, so a spring can pop it.
class ViewOnceGlyph extends StatelessWidget {
  const ViewOnceGlyph({
    super.key,
    required this.color,
    required this.knockout,
    this.on = 0,
    this.size = 20,
  });

  final Color color;

  /// The "1" once the ring is flooded: whatever is behind the glyph.
  final Color knockout;
  final double on;
  final double size;

  @override
  Widget build(BuildContext context) =>
      _Glyph(size: size, painter: _ViewOncePainter(color, knockout, on));
}

class _ViewOncePainter extends GlyphGridPainter {
  const _ViewOncePainter(super.color, this.knockout, this.on);

  final Color knockout;
  final double on;

  @override
  void draw(Canvas canvas, Paint line, Paint fill) {
    final t = on.clamp(0.0, 1.2);
    final closed = t.clamp(0.0, 1.0);
    const c = Offset(12, 12);
    const r = 9.0;
    // Eight dashes whose gaps close as it turns on.
    const dashes = 8;
    final gap = 0.42 * (1 - closed);
    final sweep = 2 * math.pi / dashes;
    final rect = Rect.fromCircle(center: c, radius: r);
    for (var i = 0; i < dashes; i++) {
      final start = -math.pi / 2 + sweep * i + sweep * gap / 2;
      canvas.drawArc(rect, start, sweep * (1 - gap), false, line);
    }
    // The flood, from the centre out.
    if (closed > 0) {
      canvas.drawCircle(c, (r + line.strokeWidth / 2) * math.min(1.0, t), fill..color = color.withValues(alpha: color.a * closed));
    }
    final one = Paint()
      ..color = Color.lerp(color, knockout, Curves.easeOut.transform(closed))!
      ..style = PaintingStyle.stroke
      ..strokeWidth = line.strokeWidth * 0.95
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    canvas.drawPath(
      Path()
        ..moveTo(9.9, 9.2)
        ..lineTo(12.3, 7.4)
        ..lineTo(12.3, 16.6),
      one,
    );
  }

  @override
  bool shouldRepaint(_ViewOncePainter old) =>
      old.color != color || old.knockout != knockout || old.on != on;
}

/// A solid flame for the play-once tooltip, alive: [flicker] is a phase the
/// caller advances, and the tip leans and stretches with it while an inner
/// core (drawn in [core], usually the colour behind the flame, so it reads as
/// a cut-out) dances on its own rhythm. [ignite] 0..1 grows it from a spark:
/// it shoots up stretched and settles.
class FlameGlyph extends StatelessWidget {
  const FlameGlyph({
    super.key,
    required this.color,
    this.core,
    this.flicker = 0,
    this.ignite = 1,
    this.size = 20,
  });

  final Color color;
  final Color? core;
  final double flicker;
  final double ignite;
  final double size;

  @override
  Widget build(BuildContext context) =>
      _Glyph(size: size, painter: _FlamePainter(color, core, flicker, ignite));
}

class _FlamePainter extends GlyphGridPainter {
  const _FlamePainter(super.color, this.core, this.flicker, this.ignite);

  final Color? core;
  final double flicker;
  final double ignite;

  Path _flame(double cx, double base, double width, double height, double lean, double curl) {
    final tip = Offset(cx + lean, base - height);
    final w = width / 2;
    return Path()
      ..moveTo(tip.dx, tip.dy)
      ..cubicTo(cx + w * 0.35 + lean * 0.6, base - height * 0.66, cx + w, base - height * 0.55, cx + w, base - height * 0.3)
      ..cubicTo(cx + w, base - height * 0.08, cx + w * 0.55, base, cx, base)
      ..cubicTo(cx - w * 0.55, base, cx - w, base - height * 0.08, cx - w, base - height * 0.3)
      ..cubicTo(cx - w, base - height * 0.5, cx - w * 0.7 + curl, base - height * 0.62, cx - w * 0.45 + curl, base - height * 0.74)
      ..cubicTo(cx - w * 0.3, base - height * 0.6, cx - w * 0.12, base - height * 0.56, cx, base - height * 0.58)
      ..cubicTo(cx - w * 0.08, base - height * 0.75, tip.dx - 0.4, tip.dy + height * 0.12, tip.dx, tip.dy)
      ..close();
  }

  @override
  void draw(Canvas canvas, Paint line, Paint fill) {
    final p = flicker * 2 * math.pi;
    final g = Curves.easeOutBack.transform(ignite.clamp(0.0, 1.0));
    // Lit, it stretches tall and thin before it settles to its shape.
    final stretch = 1 + 0.35 * (1 - ignite.clamp(0.0, 1.0));
    final lean = 1.3 * math.sin(p) + 0.5 * math.sin(p * 2.7 + 1.1);
    final breathe = 0.9 * math.sin(p * 1.9 + 0.6);
    final curl = 0.6 * math.sin(p * 1.4 + 2.0);
    canvas.save();
    canvas.translate(12, 21.4);
    canvas.scale(g / math.sqrt(stretch), g * stretch);
    canvas.translate(-12, -21.4);
    canvas.drawPath(_flame(12, 21.4, 12.6 + 0.5 * math.sin(p * 2.3), 18.6 + breathe, lean, curl), fill);
    final c = core;
    if (c != null) {
      // The heart of it: smaller, lower, on its own faster beat.
      final q = p * 1.7 + 0.9;
      canvas.drawPath(
        _flame(12 + 0.3 * math.sin(q), 20.2, 5.6 + 0.6 * math.sin(q * 1.3), 8.2 + 1.1 * math.sin(q), 0.9 * math.sin(q * 0.8), 0.3 * math.sin(q)),
        Paint()..color = c,
      );
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_FlamePainter old) =>
      old.color != color || old.core != core || old.flicker != flicker || old.ignite != ignite;
}

// ---------------------------------------------------------------------------
// Send toggles: spoiler, HD, pen

/// [path] drawn on from its start up to [t] of its length. 1 is the whole
/// path, 0 nothing.
Path _traced(Path path, double t) {
  if (t >= 1) return path;
  final out = Path();
  if (t <= 0) return out;
  for (final m in path.computeMetrics()) {
    out.addPath(m.extractPath(0, m.length * t), Offset.zero);
  }
  return out;
}

/// The spoiler toggle: an eye. Off ([on] 0) it is open, pupil and all: they
/// will see it. Turning on closes it, the upper lid folding down onto the
/// lower one and the pupil shrinking away, lashes drop under the shut lid,
/// and dust rises over it: a few specks and one sparkle. [burst] is a
/// one-off kick run 0 → 1 as it turns on: the dust puffs out and settles.
class SpoilerGlyph extends StatelessWidget {
  const SpoilerGlyph({
    super.key,
    required this.color,
    this.on = 0,
    this.burst = 0,
    this.size = 20,
  });

  final Color color;
  final double on;
  final double burst;
  final double size;

  @override
  Widget build(BuildContext context) =>
      _Glyph(size: size, painter: _SpoilerPainter(color, on, burst));
}

class _SpoilerPainter extends GlyphGridPainter {
  const _SpoilerPainter(super.color, this.on, this.burst);

  final double on;
  final double burst;

  @override
  void draw(Canvas canvas, Paint line, Paint fill) {
    final t = on.clamp(0.0, 1.0);
    final shut = Curves.easeInOut.transform(t);
    // The eye settles lower as it shuts, making room for the dust above.
    final dy = 3.2 * shut;
    const left = 2.6;
    const right = 21.4;
    final mid = 12.0 + dy;
    // Lower lid, and the upper lid folding down onto it.
    final lowerY = 19.0 + dy * 0.6;
    final upperY = lerpDouble(4.6, lowerY - 0.4, shut)!;
    canvas.drawPath(
      Path()
        ..moveTo(left, mid)
        ..quadraticBezierTo(12, upperY, right, mid),
      line,
    );
    canvas.drawPath(
      Path()
        ..moveTo(left, mid)
        ..quadraticBezierTo(12, lowerY, right, mid),
      line,
    );
    // The pupil, gone by the time the lid meets it.
    final pupil = 3.3 * (1 - glyphSpan(t, 0, 0.6));
    if (pupil > 0.05) canvas.drawCircle(Offset(12, mid), pupil, line);
    // Lashes, under the shut lid: points on the lid's own curve, dropping.
    final lash = glyphSpan(t, 0.55, 1);
    if (lash > 0) {
      final lashPaint = Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = line.strokeWidth * 0.8
        ..strokeCap = StrokeCap.round;
      for (final u in const [0.27, 0.5, 0.73]) {
        // On the quadratic from (left, mid) via (12, lowerY) to (right, mid).
        final a = 1 - u;
        final x = a * a * left + 2 * a * u * 12 + u * u * right;
        final y = a * a * mid + 2 * a * u * lowerY + u * u * mid;
        final lean = (u - 0.5) * 1.6;
        canvas.drawLine(
          Offset(x, y + 0.6),
          Offset(x + lean * lash, y + 0.6 + 2.4 * lash),
          lashPaint,
        );
      }
    }
    // The dust: it rises with the lid and puffs out on the kick.
    final dust = Curves.easeOutBack.transform(glyphSpan(t, 0.3, 1));
    if (dust <= 0) return;
    final puff = burst <= 0
        ? 0.0
        : math.sin(math.pi * Curves.easeOut.transform(burst.clamp(0.0, 1.0)));
    const centre = Offset(12, 10);
    const specks = [
      (Offset(5.2, 7.4), 1.15),
      (Offset(9.6, 3.6), 0.95),
      (Offset(14.4, 6.6), 1.2),
      (Offset(7.6, 11.2), 0.8),
    ];
    for (final (p, r) in specks) {
      final out = p + (p - centre) * (0.35 * puff);
      final lifted = Offset(out.dx, out.dy + 3 * (1 - dust));
      canvas.drawCircle(lifted, r * dust, fill..color = color);
    }
    // One sparkle: a four-point star, the dust's light.
    final s = Offset(18.6, 4.8) + const Offset(1.2, -1.2) * puff;
    final arm = 3.0 * dust * (1 + 0.25 * puff);
    final star = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = line.strokeWidth * 0.75
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(s.translate(0, -arm), s.translate(0, arm), star);
    canvas.drawLine(s.translate(-arm * 0.8, 0), s.translate(arm * 0.8, 0), star);
  }

  @override
  bool shouldRepaint(_SpoilerPainter old) =>
      old.color != color || old.on != on || old.burst != burst;
}

/// The HD toggle: the letters, drawn. Turning on traces a badge frame round
/// them, starting at the top-left corner, and [kick] (a one-off 0 → 1)
/// swells the badge once as the frame closes. Off, the frame is gone and
/// the caller dims the ink.
class HdGlyph extends StatelessWidget {
  const HdGlyph({
    super.key,
    required this.color,
    this.on = 0,
    this.kick = 0,
    this.size = 20,
  });

  final Color color;
  final double on;
  final double kick;
  final double size;

  @override
  Widget build(BuildContext context) =>
      _Glyph(size: size, painter: _HdPainter(color, on, kick));
}

class _HdPainter extends GlyphGridPainter {
  const _HdPainter(super.color, this.on, this.kick);

  final double on;
  final double kick;

  @override
  void draw(Canvas canvas, Paint line, Paint fill) {
    final swell = kick <= 0
        ? 0.0
        : math.sin(math.pi * Curves.easeOut.transform(kick.clamp(0.0, 1.0)));
    canvas.translate(12, 12);
    canvas.scale(1 + 0.14 * swell);
    canvas.translate(-12, -12);
    // The letters sit a size in from the frame, so a traced badge has air.
    canvas.save();
    canvas.translate(12, 12);
    canvas.scale(0.84);
    canvas.translate(-12.4, -12);
    final letters = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = line.strokeWidth * 0.9
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    canvas.drawPath(
      Path()
        ..moveTo(6.2, 8.2)
        ..lineTo(6.2, 15.8)
        ..moveTo(11.0, 8.2)
        ..lineTo(11.0, 15.8)
        ..moveTo(6.2, 12)
        ..lineTo(11.0, 12)
        ..moveTo(13.8, 8.2)
        ..lineTo(15.4, 8.2)
        ..cubicTo(19.6, 8.2, 19.6, 15.8, 15.4, 15.8)
        ..lineTo(13.8, 15.8)
        ..close(),
      letters,
    );
    canvas.restore();
    final t = Curves.easeOut.transform(on.clamp(0.0, 1.0));
    if (t <= 0) return;
    final frame = Path()
      ..addRRect(RRect.fromLTRBR(2.4, 4.6, 21.6, 19.4, const Radius.circular(4)));
    canvas.drawPath(_traced(frame, t), line);
  }

  @override
  bool shouldRepaint(_HdPainter old) =>
      old.color != color || old.on != on || old.kick != kick;
}

/// The pen toggle: a pencil. Turning it on lifts the pencil and draws a
/// squiggle under its tip, the stroke it is about to make; off, the line
/// is gone and the pencil rests.
class PenGlyph extends StatelessWidget {
  const PenGlyph({
    super.key,
    required this.color,
    this.on = 0,
    this.size = 20,
  });

  final Color color;
  final double on;
  final double size;

  @override
  Widget build(BuildContext context) =>
      _Glyph(size: size, painter: _PenPainter(color, on));
}

class _PenPainter extends GlyphGridPainter {
  const _PenPainter(super.color, this.on);

  final double on;

  @override
  void draw(Canvas canvas, Paint line, Paint fill) {
    final t = on.clamp(0.0, 1.0);
    final lift = Curves.easeOutBack.transform(t);
    canvas.save();
    canvas.translate(1.2 * lift, -3.0 * lift);
    // The pencil along the diagonal: body, ferrule line, tip.
    const tip = Offset(4.6, 19.4);
    const back = Offset(19.4, 4.6);
    const across = Offset(1.9, 1.9);
    final body = Path()
      ..moveTo(tip.dx, tip.dy)
      ..lineTo(8.2 - 0.6, 13.0 - 0.6)
      ..lineTo(back.dx - across.dx, back.dy - across.dy)
      ..lineTo(back.dx + across.dx, back.dy + across.dy)
      ..lineTo(11.0 + 0.6, 16.4 + 0.6)
      ..close();
    canvas.drawPath(body, line);
    canvas.drawLine(const Offset(15.6, 5.4), const Offset(18.6, 8.4), line);
    canvas.restore();
    if (t <= 0) return;
    final squiggle = Path()
      ..moveTo(3.2, 21.2)
      ..cubicTo(6.2, 18.6, 8.4, 23.4, 11.4, 20.9)
      ..cubicTo(13.6, 19.1, 15.6, 22.6, 18.2, 20.6);
    canvas.drawPath(_traced(squiggle, Curves.easeOut.transform(t)), line);
  }

  @override
  bool shouldRepaint(_PenPainter old) => old.color != color || old.on != on;
}
