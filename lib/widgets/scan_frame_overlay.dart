import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/motion.dart';

/// Four rounded corner brackets for a QR/camera viewfinder. Pure widget:
/// breathes (1.0 <-> 1.03) while [active] and snaps tighter when [detected]
/// flips to true. Under calm motion it is static (and tightened if detected).
class ScanFrameOverlay extends StatefulWidget {
  const ScanFrameOverlay({
    super.key,
    this.size = 240,
    this.color,
    this.active = true,
    this.detected = false,
    this.strokeWidth = 4,
    this.arm = 36,
    this.radius = 12,
  });

  final double size;
  final Color? color;
  final bool active;
  final bool detected;
  final double strokeWidth;
  final double arm;
  final double radius;

  @override
  State<ScanFrameOverlay> createState() => _ScanFrameOverlayState();
}

class _ScanFrameOverlayState extends State<ScanFrameOverlay>
    with TickerProviderStateMixin {
  late final AnimationController _breath = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1600),
  );
  late final AnimationController _snap = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 280),
  );

  void _sync() {
    final calm = MotionScope.of(context).calm;
    if (widget.active && !widget.detected && !calm) {
      if (!_breath.isAnimating) _breath.repeat(reverse: true);
    } else {
      _breath.stop();
      if (widget.detected || calm) _breath.value = 0;
    }
    if (widget.detected) {
      if (calm) {
        _snap.value = 1;
      } else if (_snap.value < 1 && !_snap.isAnimating) {
        _snap.forward();
      }
    } else {
      _snap.value = 0;
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _sync();
  }

  @override
  void didUpdateWidget(ScanFrameOverlay old) {
    super.didUpdateWidget(old);
    _sync();
  }

  @override
  void dispose() {
    _breath.dispose();
    _snap.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: widget.size,
      child: AnimatedBuilder(
        animation: Listenable.merge([_breath, _snap]),
        builder: (context, _) {
          final breathe = 1 + 0.03 * Curves.easeInOut.transform(_breath.value);
          final tighten = 1 - 0.07 * Curves.easeOutBack.transform(_snap.value);
          return Transform.scale(
            scale: breathe * tighten,
            child: CustomPaint(
              painter: _BracketPainter(
                color: widget.color ?? Colors.white,
                stroke: widget.strokeWidth,
                arm: widget.arm,
                radius: widget.radius,
              ),
            ),
          );
        },
      ),
    );
  }
}

class _BracketPainter extends CustomPainter {
  _BracketPainter({
    required this.color,
    required this.stroke,
    required this.arm,
    required this.radius,
  });

  final Color color;
  final double stroke;
  final double arm;
  final double radius;

  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round;
    final h = stroke / 2;
    final l = h, t = h, r = size.width - h, b = size.height - h;
    final rad = radius;
    final path = Path()
      // top-left
      ..moveTo(l, t + arm)
      ..lineTo(l, t + rad)
      ..arcTo(Rect.fromLTWH(l, t, rad * 2, rad * 2), math.pi, math.pi / 2, false)
      ..lineTo(l + arm, t)
      // top-right
      ..moveTo(r - arm, t)
      ..lineTo(r - rad, t)
      ..arcTo(Rect.fromLTWH(r - rad * 2, t, rad * 2, rad * 2), -math.pi / 2,
          math.pi / 2, false)
      ..lineTo(r, t + arm)
      // bottom-right
      ..moveTo(r, b - arm)
      ..lineTo(r, b - rad)
      ..arcTo(Rect.fromLTWH(r - rad * 2, b - rad * 2, rad * 2, rad * 2), 0,
          math.pi / 2, false)
      ..lineTo(r - arm, b)
      // bottom-left
      ..moveTo(l + arm, b)
      ..lineTo(l + rad, b)
      ..arcTo(Rect.fromLTWH(l, b - rad * 2, rad * 2, rad * 2), math.pi / 2,
          math.pi / 2, false)
      ..lineTo(l, b - arm);
    canvas.drawPath(path, p);
  }

  @override
  bool shouldRepaint(_BracketPainter o) =>
      o.color != color || o.stroke != stroke || o.arm != arm || o.radius != radius;
}
