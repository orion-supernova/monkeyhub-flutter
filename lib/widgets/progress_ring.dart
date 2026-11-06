import 'dart:math' as math;

import 'package:flutter/widgets.dart';

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
///    runs for a whole screen's worth of bubbles needs.
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
  }) : animation = null;

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
  }) : progress = null;

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
  Widget build(BuildContext context) => CustomPaint(
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
