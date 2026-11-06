import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/motion.dart';
import '../theme/theme_scope.dart';

/// A ring that fills clockwise from 12 o'clock: ONE painter for everything in
/// the app that is "this much of a time or a hold has passed".
///
/// It started inside `HoldRingButton` as the arc that sweeps around the send
/// button while a hold charges. The 10-second vanish countdown on a bubble and
/// the huddle bar are the same picture, so it lives here and each of them
/// draws it instead of carrying a copy.
///
/// Paints into whatever box it is given and adds nothing to layout beyond that
/// box (wrap in a [SizedBox], or in `Positioned.fill` over a button, as the
/// hold ring does). Colours are the caller's, taken from the theme.
///
/// Two ways to drive it:
///  * [ProgressRing.new] repaints when the widget is rebuilt with a new
///    [progress];
///  * [ProgressRing.animated] listens to an [Animation] and repaints only the
///    ring, with no widget rebuild per frame, which is what a countdown that
///    runs for a whole screen's worth of bubbles needs;
///  * [ProgressRing.spinner] is the themed, self-animating ring of the scan
///    and sign-in panels and the progress dialog: a quarter arc that spins
///    while [value] is null (still under calm motion), and an arc that eases
///    to [value] otherwise.
class ProgressRing extends StatelessWidget {
  const ProgressRing({
    super.key,
    required double this.progress,
    required this.color,
    this.trackColor,
    this.strokeWidth = 2,
    this.inset = 2,
    this.opacity = 1,
    this.fadeIn = false,
  }) : animation = null,
       _themed = false,
       _size = null,
       _spinColor = null;

  /// The themed ring: ink track, accent arc (or [color]), sized by [size].
  /// Spins when [value] is null, else eases to [value] (0..1).
  const ProgressRing.spinner({
    super.key,
    double? value,
    double size = 44,
    this.strokeWidth = 3,
    Color? color,
  }) : progress = value,
       animation = null,
       color = const Color(0x00000000),
       trackColor = null,
       inset = 0,
       opacity = 1,
       fadeIn = false,
       _themed = true,
       _size = size,
       _spinColor = color;

  /// Same ring, repainted from [animation] (0..1) every frame without
  /// rebuilding the widget.
  const ProgressRing.animated({
    super.key,
    required Animation<double> this.animation,
    required this.color,
    this.trackColor,
    this.strokeWidth = 2,
    this.inset = 2,
    this.opacity = 1,
    this.fadeIn = false,
  }) : progress = null,
       _themed = false,
       _size = null,
       _spinColor = null;

  final bool _themed;
  final double? _size;
  final Color? _spinColor;

  /// How far around, 0..1. Null when driven by [animation].
  final double? progress;
  final Animation<double>? animation;

  /// The arc.
  final Color color;

  /// A full circle drawn under the arc, or none. Drawn even at zero progress,
  /// so a countdown that has not started still shows where it will run.
  final Color? trackColor;

  final double strokeWidth;

  /// How far inside the box the stroke's centre line sits. The hold ring's 2
  /// keeps its 2px stroke just inside the button's edge.
  final double inset;

  /// Multiplies the arc's own alpha (the hold ring draws at 0.9).
  final double opacity;

  /// Fades the arc in over the first fifth of the sweep, so a press that
  /// registers a few milliseconds of progress does not flash a stub of arc.
  /// The hold ring wants it; a countdown that starts full does not.
  final bool fadeIn;

  @override
  Widget build(BuildContext context) {
    if (_themed) {
      return _SpinnerRing(
        value: progress,
        size: _size!,
        strokeWidth: strokeWidth,
        color: _spinColor,
      );
    }
    return _arc();
  }

  Widget _arc() => CustomPaint(
        painter: _ProgressRingPainter(
          progress: progress,
          animation: animation,
          color: color,
          trackColor: trackColor,
          strokeWidth: strokeWidth,
          inset: inset,
          opacity: opacity,
          fadeIn: fadeIn,
        ),
      );
}

class _ProgressRingPainter extends CustomPainter {
  _ProgressRingPainter({
    required this.progress,
    required this.animation,
    required this.color,
    required this.trackColor,
    required this.strokeWidth,
    required this.inset,
    required this.opacity,
    required this.fadeIn,
  }) : super(repaint: animation);

  final double? progress;
  final Animation<double>? animation;
  final Color color;
  final Color? trackColor;
  final double strokeWidth;
  final double inset;
  final double opacity;
  final bool fadeIn;

  double get _value => (animation?.value ?? progress ?? 0).clamp(0.0, 1.0);

  @override
  void paint(Canvas canvas, Size size) {
    final rect = (Offset.zero & size).deflate(inset);
    final track = trackColor;
    if (track != null) {
      canvas.drawOval(
        rect,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = strokeWidth
          ..color = track,
      );
    }
    final value = _value;
    if (value <= 0) return;
    final alpha = (fadeIn ? (value * 5).clamp(0.0, 1.0) : 1.0) * opacity;
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..color = color.withValues(alpha: alpha);
    canvas.drawArc(
      rect,
      -math.pi / 2, // 12 o'clock
      value * math.pi * 2,
      false,
      paint,
    );
  }

  @override
  bool shouldRepaint(_ProgressRingPainter old) =>
      old.progress != progress ||
      old.animation != animation ||
      old.color != color ||
      old.trackColor != trackColor ||
      old.strokeWidth != strokeWidth ||
      old.inset != inset ||
      old.opacity != opacity ||
      old.fadeIn != fadeIn;
}

/// The themed spinner behind [ProgressRing.spinner].
class _SpinnerRing extends StatefulWidget {
  const _SpinnerRing({
    required this.value,
    required this.size,
    required this.strokeWidth,
    required this.color,
  });

  final double? value;
  final double size;
  final double strokeWidth;
  final Color? color;

  @override
  State<_SpinnerRing> createState() => _SpinnerRingState();
}

class _SpinnerRingState extends State<_SpinnerRing>
    with SingleTickerProviderStateMixin {
  late final AnimationController _spin = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1000),
  );

  void _sync(bool calm) {
    if (widget.value == null && !calm) {
      if (!_spin.isAnimating) _spin.repeat();
    } else {
      _spin.stop();
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _sync(MotionScope.of(context).calm);
  }

  @override
  void didUpdateWidget(_SpinnerRing old) {
    super.didUpdateWidget(old);
    _sync(MotionScope.of(context).calm);
  }

  @override
  void dispose() {
    _spin.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final color = widget.color ?? theme.accent;
    final track = theme.ink.withValues(alpha: 0.14);
    final calm = MotionScope.of(context).calm;
    final v = widget.value;
    Widget paint(double sweep, double rotation) => CustomPaint(
          size: Size.square(widget.size),
          painter: _RingPainter(
            sweep: sweep,
            rotation: rotation,
            color: color,
            track: track,
            stroke: widget.strokeWidth,
          ),
        );
    if (v == null) {
      return AnimatedBuilder(
        animation: _spin,
        builder: (_, _) => paint(0.28, _spin.value * 2 * math.pi),
      );
    }
    return TweenAnimationBuilder<double>(
      tween: Tween(end: v),
      duration: calm ? Duration.zero : const Duration(milliseconds: 350),
      curve: Curves.easeOutCubic,
      builder: (_, value, _) => paint(value, 0),
    );
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter({
    required this.sweep,
    required this.rotation,
    required this.color,
    required this.track,
    required this.stroke,
  });

  final double sweep;
  final double rotation;
  final Color color;
  final Color track;
  final double stroke;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = (Offset.zero & size).deflate(stroke / 2);
    final p = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(rect, 0, 2 * math.pi, false, p..color = track);
    if (sweep > 0) {
      canvas.drawArc(
        rect,
        -math.pi / 2 + rotation,
        2 * math.pi * sweep.clamp(0.0, 1.0),
        false,
        p..color = color,
      );
    }
  }

  @override
  bool shouldRepaint(_RingPainter o) =>
      o.sweep != sweep ||
      o.rotation != rotation ||
      o.color != color ||
      o.track != track ||
      o.stroke != stroke;
}
