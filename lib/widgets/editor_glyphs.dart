import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import 'capture_glyphs.dart' show GlyphGridPainter, glyphSpan;

// Drawn line glyphs for the photo preview's tools: rotate, crop, undo and
// redo. Same 24-unit grid and stroke as `capture_glyphs.dart`, so they sit
// in one pill with the send switches at one optical weight, and the same
// rule: every animation is geometry driven by a plain 0..1 the caller owns.

/// Runs [builder] with a one-off 0..1 kick each time [trigger] changes, the
/// beat a tool plays as it acts (the frame turning, the arrow swinging back).
///
/// Idle at 0 between kicks, so a resting glyph costs no frames. Reduce Motion
/// gets no kick.
class GlyphKick extends StatefulWidget {
  const GlyphKick({
    super.key,
    required this.trigger,
    required this.builder,
    this.duration = const Duration(milliseconds: 460),
  });

  final int trigger;
  final Widget Function(BuildContext context, double kick) builder;
  final Duration duration;

  @override
  State<GlyphKick> createState() => _GlyphKickState();
}

class _GlyphKickState extends State<GlyphKick>
    with SingleTickerProviderStateMixin {
  late final AnimationController _kick = AnimationController(
    vsync: this,
    duration: widget.duration,
  );

  @override
  void didUpdateWidget(GlyphKick old) {
    super.didUpdateWidget(old);
    if (old.trigger != widget.trigger &&
        !MediaQuery.disableAnimationsOf(context)) {
      _kick.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _kick.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => RepaintBoundary(
        child: AnimatedBuilder(
          animation: _kick,
          builder: (context, _) {
            final k = _kick.value;
            // Snapped to exactly 0 at rest, so the painter's equality check
            // skips the repaint once the kick is over.
            return widget.builder(context, k >= 1 ? 0 : k);
          },
        ),
      );
}

class _Glyph extends StatelessWidget {
  const _Glyph({required this.size, required this.painter});

  final double size;
  final CustomPainter painter;

  @override
  Widget build(BuildContext context) =>
      CustomPaint(size: Size.square(size), painter: painter);
}

// ---------------------------------------------------------------------------
// Rotate

/// A square frame under a clockwise arrow: the photo turns a quarter right.
///
/// [kick] turns the frame a quarter with it, overshooting and settling, and
/// pushes the arrow's head on along its arc. The frame is square, so a whole
/// quarter turn lands exactly where it began: no snap at the end.
class RotateGlyph extends StatelessWidget {
  const RotateGlyph({
    super.key,
    required this.color,
    this.kick = 0,
    this.size = 22,
  });

  final Color color;
  final double kick;
  final double size;

  @override
  Widget build(BuildContext context) =>
      _Glyph(size: size, painter: _RotatePainter(color: color, kick: kick));
}

class _RotatePainter extends GlyphGridPainter {
  const _RotatePainter({required Color color, required this.kick})
      : super(color);

  final double kick;

  @override
  void draw(Canvas canvas, Paint line, Paint fill) {
    final turn = kick == 0 ? 0.0 : Curves.easeOutBack.transform(kick);
    final push = math.sin(math.pi * kick);

    // The frame, turning about its own centre.
    const frame = Rect.fromLTWH(3, 12.5, 9.5, 9.5);
    canvas.save();
    canvas.translate(frame.center.dx, frame.center.dy);
    canvas.rotate(math.pi / 2 * turn);
    canvas.translate(-frame.center.dx, -frame.center.dy);
    canvas.drawRRect(
      RRect.fromRectAndRadius(frame, const Radius.circular(2.2)),
      line,
    );
    canvas.restore();

    // The arrow wraps round the frame from well above its left corner, over
    // the top and down its right side, ending in a head pointing back in:
    // clear of the frame's top edge everywhere, so it can never read as a
    // padlock's shackle sitting on a body.
    const centre = Offset(11, 13);
    const radius = 9.0;
    const start = math.pi * 1.2;
    final sweep = math.pi * (0.92 + 0.1 * push);
    canvas.drawArc(
      Rect.fromCircle(center: centre, radius: radius),
      start,
      sweep,
      false,
      line,
    );
    final end = start + sweep;
    final tip = centre + Offset(math.cos(end), math.sin(end)) * radius;
    // Clockwise tangent at the tip, and the two barbs folded back off it.
    final dir = Offset(-math.sin(end), math.cos(end));
    const barb = 3.8;
    for (final a in const [0.62, -0.62]) {
      final back = Offset(
        -(dir.dx * math.cos(a) - dir.dy * math.sin(a)),
        -(dir.dx * math.sin(a) + dir.dy * math.cos(a)),
      );
      canvas.drawLine(tip, tip + back * barb, line);
    }
  }

  @override
  bool shouldRepaint(_RotatePainter old) =>
      old.color != color || old.kick != kick;
}

// ---------------------------------------------------------------------------
// Crop

/// Two interlocking corner brackets: the frame being cut. [kick] draws them
/// together once, the cut closing in on the picture.
class CropGlyph extends StatelessWidget {
  const CropGlyph({
    super.key,
    required this.color,
    this.kick = 0,
    this.size = 22,
  });

  final Color color;
  final double kick;
  final double size;

  @override
  Widget build(BuildContext context) =>
      _Glyph(size: size, painter: _CropPainter(color: color, kick: kick));
}

class _CropPainter extends GlyphGridPainter {
  const _CropPainter({required Color color, required this.kick})
      : super(color);

  final double kick;

  @override
  void draw(Canvas canvas, Paint line, Paint fill) {
    final pull = 1.6 * math.sin(math.pi * kick);
    // The bracket that holds the picture: down the left, along the bottom.
    canvas.drawPath(
      Path()
        ..moveTo(7 + pull, 2.8)
        ..lineTo(7 + pull, 17 - pull)
        ..lineTo(21.2, 17 - pull),
      line,
    );
    // Its partner, from the top across and down the right.
    canvas.drawPath(
      Path()
        ..moveTo(2.8, 7 + pull)
        ..lineTo(17 - pull, 7 + pull)
        ..lineTo(17 - pull, 21.2),
      line,
    );
  }

  @override
  bool shouldRepaint(_CropPainter old) =>
      old.color != color || old.kick != kick;
}

// ---------------------------------------------------------------------------
// Undo / redo

/// A U-turn arrow: back (undo) or, [redo], forward. [kick] swings the hook
/// the way it points and lets it spring back, a stroke being taken off or
/// put back.
class UndoGlyph extends StatelessWidget {
  const UndoGlyph({
    super.key,
    required this.color,
    this.redo = false,
    this.kick = 0,
    this.size = 22,
  });

  final Color color;
  final bool redo;
  final double kick;
  final double size;

  @override
  Widget build(BuildContext context) => _Glyph(
        size: size,
        painter: _UndoPainter(color: color, redo: redo, kick: kick),
      );
}

class _UndoPainter extends GlyphGridPainter {
  const _UndoPainter({
    required Color color,
    required this.redo,
    required this.kick,
  }) : super(color);

  final bool redo;
  final double kick;

  @override
  void draw(Canvas canvas, Paint line, Paint fill) {
    if (redo) {
      canvas.translate(24, 0);
      canvas.scale(-1, 1);
    }
    // Out fast, back on a damped wobble.
    final double out;
    if (kick == 0) {
      out = 0;
    } else if (kick < 0.3) {
      out = Curves.easeOut.transform(glyphSpan(kick, 0, 0.3));
    } else {
      final u = glyphSpan(kick, 0.3, 1);
      out = math.cos(u * math.pi * 1.5) * math.pow(1 - u, 1.4);
    }
    canvas.translate(-2.2 * out, 0);
    // The hook rocks back about its bend.
    const pivot = Offset(15, 13.5);
    canvas.translate(pivot.dx, pivot.dy);
    canvas.rotate(-0.22 * out);
    canvas.translate(-pivot.dx, -pivot.dy);

    canvas.drawPath(
      Path()
        ..moveTo(4.5, 9)
        ..lineTo(15, 9)
        ..arcToPoint(const Offset(15, 18.6), radius: const Radius.circular(4.8))
        ..lineTo(9.5, 18.6),
      line,
    );
    canvas.drawPath(
      Path()
        ..moveTo(8.4, 5.1)
        ..lineTo(4.5, 9)
        ..lineTo(8.4, 12.9),
      line,
    );
  }

  @override
  bool shouldRepaint(_UndoPainter old) =>
      old.color != color || old.redo != redo || old.kick != kick;
}
