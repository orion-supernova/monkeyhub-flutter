import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/theme_scope.dart';

/// Maps a 0..1 progress value onto the pulse's rise-and-fall arc.
///
/// Shared rather than re-derived, because two surfaces pulse the same message
/// — a bubble in the transcript, and one tile of an album — and a highlight
/// that blooms at a different rate depending on how the photograph happens to
/// be drawn is the same bug as no highlight at all.
double highlightPulseCurve(double t) =>
    math.sin(t.clamp(0.0, 1.0) * math.pi).clamp(0.0, 1.0);

/// One-shot accent halo pulse around a bubble. Drives off a 0..1 progress
/// value (typically a controller in 0..1 over ~1s) and maps it through
/// `sin(t*pi)` so the pulse blooms then settles in a single rise-fall arc.
class HighlightPulse extends StatelessWidget {
  const HighlightPulse({
    super.key,
    required this.t,
    required this.shape,
    required this.child,
  });
  final double t;

  /// The bubble's own outline, so the halo and the border pulse hug the tail
  /// instead of cutting across it.
  final ShapeBorder shape;

  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (t <= 0) return child;
    final theme = ThemeScope.of(context);
    final tCurve = highlightPulseCurve(t);
    return Stack(
      clipBehavior: Clip.none,
      children: [
        // Accent glow halo sitting behind the bubble.
        Positioned.fill(
          child: IgnorePointer(
            child: DecoratedBox(
              decoration: ShapeDecoration(
                shape: shape,
                shadows: [
                  BoxShadow(
                    color: theme.accent.withValues(alpha: 0.55 * tCurve),
                    blurRadius: 28 * tCurve,
                    spreadRadius: 4 * tCurve,
                  ),
                ],
              ),
            ),
          ),
        ),
        child,
        // Accent border pulse on top so the highlight reads even when the
        // halo is occluded by overlapping bubbles below in the stack.
        Positioned.fill(
          child: IgnorePointer(
            child: CustomPaint(
              painter: _PulseOutline(
                shape: shape,
                color: theme.accent.withValues(alpha: 0.55 * tCurve),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Strokes [shape]'s outline. A `ShapeDecoration` would paint the shape's own
/// [BorderSide] — which is the theme's hairline, not this pulse — so the
/// highlight draws its own stroke over the same path.
class _PulseOutline extends CustomPainter {
  const _PulseOutline({required this.shape, required this.color});

  final ShapeBorder shape;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawPath(
      shape.getOuterPath(Offset.zero & size),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = color,
    );
  }

  @override
  bool shouldRepaint(_PulseOutline old) =>
      old.shape != shape || old.color != color;
}
