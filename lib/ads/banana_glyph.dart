import 'dart:math' as math;

import 'package:flutter/material.dart';

/// The banana, drawn rather than an emoji: the same on every platform (an
/// emoji font is not a given on Linux or in a browser), and it can move.
///
/// Two motions, in the playful-glyph spirit (docs: ~/Desktop reference, see
/// docs/design/rewarded-ads.md):
///  * [popKey] changes → a pop: the banana jumps, overshoots and wobbles to
///    rest. For the moment bananas land.
///  * [waving] → an idle wave every couple of seconds, while there is
///    something waiting (today's free banana). Only for that live state; it
///    stops the moment it is false, and never runs under Reduce Motion.
class BananaGlyph extends StatefulWidget {
  const BananaGlyph({
    super.key,
    this.size = 20,
    this.popKey = 0,
    this.waving = false,
  });

  final double size;

  /// Bump to pop (e.g. the balance after a credit).
  final int popKey;
  final bool waving;

  @override
  State<BananaGlyph> createState() => _BananaGlyphState();
}

class _BananaGlyphState extends State<BananaGlyph>
    with TickerProviderStateMixin {
  late final AnimationController _pop = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 750),
  );
  late final AnimationController _wave = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2600),
  );

  bool get _still => MediaQuery.maybeDisableAnimationsOf(context) ?? false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncWave();
  }

  @override
  void didUpdateWidget(BananaGlyph old) {
    super.didUpdateWidget(old);
    if (old.popKey != widget.popKey && !_still) _pop.forward(from: 0);
    if (old.waving != widget.waving) _syncWave();
  }

  void _syncWave() {
    if (widget.waving && !_still) {
      if (!_wave.isAnimating) _wave.repeat();
    } else {
      _wave.stop();
      _wave.value = 0;
    }
  }

  @override
  void dispose() {
    _pop.dispose();
    _wave.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: SizedBox.square(
        dimension: widget.size,
        child: CustomPaint(
          painter: _BananaPainter(_pop, _wave),
        ),
      ),
    );
  }
}

class _BananaPainter extends CustomPainter {
  _BananaPainter(this.pop, this.wave) : super(repaint: Listenable.merge([pop, wave]));

  final Animation<double> pop;
  final Animation<double> wave;

  static const _peel = Color(0xFFFFD43B);
  static const _peelDeep = Color(0xFFF2B200);
  static const _line = Color(0xFFB57F00);
  static const _stem = Color(0xFF6B4A1F);

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width;
    // Pop: up and back down with an overshoot, and a damped wobble.
    final p = pop.value;
    final lift = p == 0 ? 0.0 : math.sin(math.pi * Curves.easeOut.transform(p));
    final scale = 1 + 0.28 * lift;
    final wobble = p == 0 ? 0.0 : math.sin(p * math.pi * 5) * (1 - p) * 0.35;
    // Wave: two quick swings at the start of each cycle, then rest.
    final w = wave.value;
    final waveAngle = w < 0.32 ? math.sin(w / 0.32 * math.pi * 2) * 0.16 : 0.0;

    canvas.save();
    canvas.translate(s / 2, s * 0.62);
    canvas.rotate(wobble + waveAngle);
    canvas.scale(scale);
    canvas.translate(-s / 2, -s * 0.62 - s * 0.10 * lift);

    Offset o(double x, double y) => Offset(x * s, y * s);
    void cubic(Path p, double a, double b, double c, double d, double e,
            double f) =>
        p.cubicTo(a * s, b * s, c * s, d * s, e * s, f * s);

    // A plump crescent lying on its side, tips up, slightly tilted.
    // On the diagonal, stem top-left, like the emoji: lying flat with both
    // tips up it read as a smile at pill size.
    canvas.translate(s / 2, s / 2);
    canvas.rotate(0.62);
    canvas.scale(0.98);
    canvas.translate(-s / 2, -s * 0.62);

    final body = Path()..moveTo(o(0.10, 0.36).dx, o(0.10, 0.36).dy);
    cubic(body, 0.10, 0.78, 0.62, 0.98, 0.94, 0.52); // outer belly
    cubic(body, 0.96, 0.48, 0.92, 0.42, 0.87, 0.46); // far tip
    cubic(body, 0.62, 0.70, 0.30, 0.62, 0.24, 0.34); // inner curve
    cubic(body, 0.22, 0.28, 0.12, 0.28, 0.10, 0.36); // near end
    body.close();

    final rect = Offset.zero & size;
    canvas.drawPath(
      body,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment(0, -0.2),
          end: Alignment(0, 1),
          colors: [_peel, _peelDeep],
        ).createShader(rect),
    );
    // Highlight along the top of the belly.
    final shine = Path()..moveTo(o(0.20, 0.44).dx, o(0.20, 0.44).dy);
    cubic(shine, 0.24, 0.66, 0.52, 0.76, 0.78, 0.60);
    canvas.drawPath(
      shine,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = s * 0.06
        ..strokeCap = StrokeCap.round
        ..color = const Color(0xFFFFF3B0).withValues(alpha: 0.75),
    );
    // The ridge under it.
    final ridge = Path()..moveTo(o(0.16, 0.50).dx, o(0.16, 0.50).dy);
    cubic(ridge, 0.24, 0.80, 0.60, 0.88, 0.90, 0.52);
    canvas.drawPath(
      ridge,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = s * 0.028
        ..strokeCap = StrokeCap.round
        ..color = _line.withValues(alpha: 0.45),
    );
    canvas.drawPath(
      body,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = s * 0.04
        ..strokeJoin = StrokeJoin.round
        ..color = _line,
    );
    // A short stem at the near end, the dark tip at the far one.
    canvas.drawLine(
      o(0.15, 0.32),
      o(0.10, 0.22),
      Paint()
        ..strokeWidth = s * 0.075
        ..strokeCap = StrokeCap.round
        ..color = _stem,
    );
    canvas.drawCircle(o(0.915, 0.48), s * 0.035, Paint()..color = _stem);
    canvas.restore();
  }

  @override
  bool shouldRepaint(_BananaPainter old) => false;
}
