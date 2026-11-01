import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import '../theme/motion.dart';

/// The chat chrome's motion vocabulary — the small, Telegram-grade moves every
/// control around a transcript makes. One file so the header's call buttons,
/// the scroll column, the pinned banner and the reply/edit cards all move in
/// the same handful of ways, instead of each inventing its own. See
/// `docs/design/chat-chrome-language.md` for where each one is used.
///
/// Every move is geometric (a nudge, a rock, a pop, a stroke drawing in),
/// never a colour flash, and every one snaps to rest under Reduce Motion
/// ([MotionScope.calm]).

/// The one-shot nudges a glyph makes when its control fires or its state
/// changes.
enum GlyphKick {
  /// Down and back: "go down" (the scroll-to-latest chevron).
  dip,

  /// Up and back: a pin pressed into the banner.
  lift,

  /// Down-right and back along a curve: "return to where you were".
  back,

  /// A damped side-to-side rock: a ringing handset, a fresh `@`.
  rock,

  /// A quick swell and settle: a camera's shutter, a tap that "takes".
  pop,
}

/// Plays a [GlyphKick] on [child] every time [trigger] changes.
///
/// Callers hold a counter (or any value that changes with the event) rather
/// than a controller, so a stateless control can kick by passing a new value.
/// The first build never kicks.
class KickGlyph extends StatefulWidget {
  const KickGlyph({
    super.key,
    required this.kick,
    required this.trigger,
    required this.child,
    this.amplitude = 1,
  });

  final GlyphKick kick;
  final Object? trigger;
  final Widget child;

  /// Scales the move. 1 is sized for a ~16–20pt glyph.
  final double amplitude;

  @override
  State<KickGlyph> createState() => _KickGlyphState();
}

class _KickGlyphState extends State<KickGlyph>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: _durationFor(widget.kick),
  );

  static Duration _durationFor(GlyphKick k) => switch (k) {
        GlyphKick.rock => const Duration(milliseconds: 560),
        GlyphKick.pop => const Duration(milliseconds: 380),
        _ => const Duration(milliseconds: 420),
      };

  @override
  void didUpdateWidget(KickGlyph old) {
    super.didUpdateWidget(old);
    if (old.kick != widget.kick) _c.duration = _durationFor(widget.kick);
    if (old.trigger == widget.trigger) return;
    if (MotionScope.of(context).calm) return;
    _c.forward(from: 0);
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: _c,
        child: widget.child,
        builder: (context, child) {
          final t = _c.value;
          if (t == 0 || t == 1) return child!;
          final a = widget.amplitude;
          // Out and home in one stroke, easing out of the push.
          final swing = math.sin(math.pi * Curves.easeOut.transform(t));
          switch (widget.kick) {
            case GlyphKick.dip:
              return Transform.translate(offset: Offset(0, 3.5 * a * swing), child: child);
            case GlyphKick.lift:
              return Transform.translate(offset: Offset(0, -3 * a * swing), child: child);
            case GlyphKick.back:
              return Transform.translate(
                offset: Offset(2 * a * swing, 2.5 * a * swing),
                child: Transform.rotate(angle: -0.18 * a * swing, child: child),
              );
            case GlyphKick.rock:
              // Three damped swings, like a handset ringing on a table.
              final angle = 0.32 * a * math.sin(t * math.pi * 6) * (1 - t);
              return Transform.rotate(angle: angle, child: child);
            case GlyphKick.pop:
              final s = 1 + 0.2 * a * swing;
              return Transform.scale(scale: s, child: child);
          }
        },
      );
}

/// Swaps [child] by sliding the old one out and the new one in vertically —
/// the pinned banner stepping to the next pin, a reply card retargeted to a
/// different message. [direction] 1 moves content up (the next item arrives
/// from below), -1 moves it down. Key [child] by what it shows.
class SlideSwap extends StatelessWidget {
  const SlideSwap({
    super.key,
    required this.child,
    this.direction = 1,
    this.alignment = Alignment.centerLeft,
  });

  final Widget child;
  final int direction;
  final AlignmentGeometry alignment;

  @override
  Widget build(BuildContext context) {
    final calm = MotionScope.of(context).calm;
    return ClipRect(
      child: AnimatedSwitcher(
        duration: calm ? Duration.zero : const Duration(milliseconds: 260),
        switchInCurve: Curves.easeOutCubic,
        switchOutCurve: Curves.easeInCubic,
        layoutBuilder: (current, previous) => Stack(
          alignment: alignment,
          children: [...previous, ?current],
        ),
        transitionBuilder: (child, animation) {
          final incoming = child.key == this.child.key;
          final from = (incoming ? 0.6 : -0.6) * direction;
          return FadeTransition(
            opacity: animation,
            child: SlideTransition(
              position: animation.drive(
                Tween(begin: Offset(0, incoming ? from : -from), end: Offset.zero),
              ),
              child: child,
            ),
          );
        },
        child: child,
      ),
    );
  }
}

/// The one rail every "this is about another message" surface wears — the
/// quote inside a bubble, the reply and edit cards over the composer, the
/// pinned banner's position marker. A rounded bar rather than a hard 3px
/// rectangle, so it reads as a drawn line like the rest of the chrome.
///
/// Draws itself in from the middle when it first appears ([animateIn]).
class ContextRail extends StatefulWidget {
  const ContextRail({
    super.key,
    required this.color,
    this.width = 3,
    this.animateIn = false,
  });

  final Color color;
  final double width;
  final bool animateIn;

  @override
  State<ContextRail> createState() => _ContextRailState();
}

class _ContextRailState extends State<ContextRail>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 320),
    value: widget.animateIn ? 0 : 1,
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_c.value < 1 && !_c.isAnimating) {
      if (MotionScope.of(context).calm) {
        _c.value = 1;
      } else {
        _c.forward();
      }
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => SizedBox(
        width: widget.width,
        child: CustomPaint(
          painter: _RailPainter(
            color: widget.color,
            progress: _c.drive(CurveTween(curve: Curves.easeOutCubic)),
          ),
        ),
      );
}

class _RailPainter extends CustomPainter {
  _RailPainter({required this.color, required this.progress})
      : super(repaint: progress);

  final Color color;
  final Animation<double> progress;

  @override
  void paint(Canvas canvas, Size size) {
    final p = progress.value;
    if (p <= 0) return;
    final h = size.height * p;
    final top = (size.height - h) / 2;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(0, top, size.width, h),
        Radius.circular(size.width / 2),
      ),
      Paint()..color = color,
    );
  }

  @override
  bool shouldRepaint(_RailPainter old) =>
      old.color != color || old.progress != progress;
}

/// A drawn close glyph: two round-capped strokes that draw themselves in,
/// one after the other, when the glyph first appears. Replaces the font ×
/// on the composer's context cards.
class DrawnCloseGlyph extends StatefulWidget {
  const DrawnCloseGlyph({
    super.key,
    required this.color,
    this.size = 12,
    this.stroke = 1.8,
  });

  final Color color;
  final double size;
  final double stroke;

  @override
  State<DrawnCloseGlyph> createState() => _DrawnCloseGlyphState();
}

class _DrawnCloseGlyphState extends State<DrawnCloseGlyph>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 360),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_c.value == 0 && !_c.isAnimating) {
      if (MotionScope.of(context).calm) {
        _c.value = 1;
      } else {
        _c.forward();
      }
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => RepaintBoundary(
        child: CustomPaint(
          size: Size.square(widget.size),
          painter: _ClosePainter(
            color: widget.color,
            stroke: widget.stroke,
            progress: _c,
          ),
        ),
      );
}

class _ClosePainter extends CustomPainter {
  _ClosePainter({
    required this.color,
    required this.stroke,
    required this.progress,
  }) : super(repaint: progress);

  final Color color;
  final double stroke;
  final Animation<double> progress;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    final t = progress.value;
    final a = Curves.easeOutCubic.transform((t / 0.6).clamp(0.0, 1.0));
    final b = Curves.easeOutCubic.transform(((t - 0.35) / 0.65).clamp(0.0, 1.0));
    final w = size.width;
    if (a > 0) {
      canvas.drawLine(Offset.zero, Offset(w * a, w * a), paint);
    }
    if (b > 0) {
      canvas.drawLine(Offset(w, 0), Offset(w - w * b, w * b), paint);
    }
  }

  @override
  bool shouldRepaint(_ClosePainter old) =>
      old.color != color || old.stroke != stroke || old.progress != progress;
}
