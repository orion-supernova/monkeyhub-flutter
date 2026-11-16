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
  _BananaPainter(this.pop, this.wave)
      : super(repaint: Listenable.merge([pop, wave]));

  final Animation<double> pop;
  final Animation<double> wave;

  // A half-peeled banana in the soft, outline-free style of a system emoji:
  // cream fruit standing out of the peel, three flaps (cream inside, yellow
  // lip), a glossy yellow body and a dark tip. Coordinates are in a unit box
  // that the drawing fills edge to edge (see [paint]'s fit transform).
  static const _yellowLight = Color(0xFFFFE36A);
  static const _yellow = Color(0xFFF9CF34);
  static const _yellowDeep = Color(0xFFE6AE1B);
  static const _creamLight = Color(0xFFFBF3DE);
  static const _cream = Color(0xFFEFE1BE);
  static const _creamDeep = Color(0xFFD9C597);
  static const _tip = Color(0xFF5E4122);

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width;
    final p = pop.value;
    final lift = p == 0 ? 0.0 : math.sin(math.pi * Curves.easeOut.transform(p));
    final wobble = p == 0 ? 0.0 : math.sin(p * math.pi * 5) * (1 - p) * 0.3;
    final w = wave.value;
    final waveAngle = w < 0.32 ? math.sin(w / 0.32 * math.pi * 2) * 0.16 : 0.0;

    canvas.save();
    // Motion, pivoting near the bottom of the fruit.
    canvas.translate(s * 0.5, s * 0.78 - s * 0.10 * lift);
    canvas.rotate(wobble + waveAngle);
    canvas.scale(1 + 0.26 * lift);
    canvas.translate(-s * 0.5, -s * 0.78);
    // Fit: the art spans x 0.10..0.79, y 0.00..0.77; centre it and fill.
    const k = 1.24;
    canvas.translate(s * 0.5, s * 0.5);
    canvas.scale(k);
    canvas.translate(-s * 0.452, -s * 0.385);

    Path path(List<List<double>> pts) {
      final out = Path()..moveTo(pts[0][0] * s, pts[0][1] * s);
      for (var i = 1; i < pts.length; i++) {
        final c = pts[i];
        out.cubicTo(c[0] * s, c[1] * s, c[2] * s, c[3] * s, c[4] * s, c[5] * s);
      }
      return out..close();
    }

    Paint fill(List<Color> colors, Alignment begin, Alignment end,
            [List<double>? stops]) =>
        Paint()
          ..isAntiAlias = true
          ..shader = LinearGradient(
            begin: begin,
            end: end,
            colors: colors,
            stops: stops,
          ).createShader(Offset.zero & size);

    Paint soft(Color c, double blur) => Paint()
      ..color = c
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, s * blur);

    // Fine fibres along a shape: thin, faint strokes clipped to it.
    void fibres(Path shape, List<List<double>> lines, Color c, double alpha) {
      canvas.save();
      canvas.clipPath(shape);
      for (var n = 0; n < lines.length; n++) {
        final l = lines[n];
        final line = Path()
          ..moveTo(l[0] * s, l[1] * s)
          ..quadraticBezierTo(l[2] * s, l[3] * s, l[4] * s, l[5] * s);
        // Uneven dashes, a different rhythm per line, so it reads as grain
        // rather than pinstripes.
        final pen = Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = s * (0.0028 + 0.0012 * (n % 3))
          ..strokeCap = StrokeCap.round
          ..color = c.withValues(alpha: alpha * (0.6 + 0.2 * (n % 3)))
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, s * 0.0028);
        for (final metric in line.computeMetrics()) {
          var at = metric.length * (0.04 * (n % 4));
          var k = n;
          while (at < metric.length) {
            final run = metric.length * (0.24 + 0.16 * ((k * 7) % 5) / 4);
            canvas.drawPath(metric.extractPath(at, at + run), pen);
            at += run + metric.length * (0.03 + 0.03 * ((k * 3) % 4) / 3);
            k++;
          }
        }
      }
      canvas.restore();
    }

    // 1. The flap at the back, arching over to the right.
    final backFlap = path([
      [0.385, 0.37],
      [0.42, 0.27, 0.50, 0.225, 0.565, 0.245],
      [0.665, 0.28, 0.735, 0.38, 0.755, 0.475],
      [0.757, 0.497, 0.735, 0.503, 0.72, 0.485],
      [0.665, 0.405, 0.585, 0.325, 0.505, 0.305],
      [0.455, 0.295, 0.425, 0.33, 0.405, 0.375],
    ]);
    // Its yellow lip shows along the underside.
    canvas.save();
    canvas.translate(s * 0.002, s * 0.008);
    canvas.drawPath(backFlap, Paint()..color = _yellowDeep);
    canvas.restore();
    canvas.drawPath(
      backFlap,
      fill([_creamLight, _cream, _creamDeep], Alignment.topLeft,
          Alignment.bottomRight, [0, 0.55, 1]),
    );
    fibres(backFlap, [
      [0.44, 0.31, 0.55, 0.24, 0.70, 0.40],
      [0.46, 0.33, 0.57, 0.27, 0.72, 0.45],
      [0.43, 0.29, 0.53, 0.22, 0.66, 0.30],
      [0.50, 0.32, 0.60, 0.30, 0.74, 0.47],
    ], _creamDeep, 0.32);
    // The fruit's shadow on the flap, where it leaves the stalk.
    canvas.save();
    canvas.clipPath(backFlap);
    canvas.drawCircle(
      Offset(s * 0.41, s * 0.36),
      s * 0.06,
      soft(const Color(0xFFB89A5E).withValues(alpha: 0.55), 0.03),
    );
    canvas.restore();

    // 2. The fruit, standing up out of the peel.
    final fruit = path([
      [0.228, 0.37],
      [0.208, 0.21, 0.215, 0.05, 0.29, 0.008],
      [0.35, -0.012, 0.378, 0.09, 0.392, 0.215],
      [0.402, 0.30, 0.398, 0.345, 0.385, 0.375],
    ]);
    canvas.drawPath(
      fruit,
      fill([_creamDeep, _creamLight, _cream, _creamDeep],
          Alignment.centerLeft, Alignment.centerRight, [0, 0.35, 0.7, 1]),
    );
    // A soft sheen down the fruit.
    canvas.drawLine(
      Offset(s * 0.275, s * 0.06),
      Offset(s * 0.262, s * 0.30),
      soft(Colors.white.withValues(alpha: 0.55), 0.012)
        ..strokeWidth = s * 0.03
        ..strokeCap = StrokeCap.round,
    );
    // The strings and grain of the fruit, lengthwise.
    fibres(fruit, [
      [0.245, 0.06, 0.232, 0.22, 0.240, 0.37],
      [0.300, 0.02, 0.300, 0.20, 0.300, 0.37],
      [0.330, 0.03, 0.338, 0.20, 0.336, 0.37],
      [0.360, 0.07, 0.372, 0.22, 0.368, 0.37],
      [0.318, 0.02, 0.322, 0.20, 0.318, 0.37],
    ], _creamDeep, 0.22);
    // Where the peel still grips the fruit: a soft contact shadow.
    canvas.save();
    canvas.clipPath(fruit);
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(s * 0.31, s * 0.375),
        width: s * 0.22,
        height: s * 0.07,
      ),
      soft(const Color(0xFFA88A4E).withValues(alpha: 0.6), 0.025),
    );
    canvas.restore();

    // 3. The body: the unpeeled half, curving down to the right.
    final body = path([
      [0.288, 0.37],
      [0.33, 0.355, 0.36, 0.375, 0.372, 0.405],
      [0.385, 0.365, 0.425, 0.33, 0.466, 0.348],
      // Inner edge: a bent tube on a gentle diagonal, not a half-moon.
      [0.50, 0.425, 0.56, 0.49, 0.63, 0.522],
      [0.69, 0.548, 0.74, 0.556, 0.786, 0.552],
      [0.806, 0.560, 0.806, 0.592, 0.786, 0.603],
      // Belly: a long, shallow arc.
      [0.70, 0.648, 0.585, 0.672, 0.485, 0.642],
      [0.385, 0.61, 0.31, 0.525, 0.288, 0.37],
    ]);
    canvas.drawPath(
      body,
      fill([_yellowLight, _yellow, _yellowDeep], const Alignment(-0.2, -1),
          const Alignment(0.2, 1), [0, 0.5, 1]),
    );
    // Gloss along the top of the curve, and shade along the belly.
    canvas.save();
    canvas.clipPath(body);
    final gloss = Path()
      ..moveTo(s * 0.345, s * 0.43)
      ..cubicTo(s * 0.40, s * 0.53, s * 0.55, s * 0.60, s * 0.75, s * 0.585);
    canvas.drawPath(
      gloss,
      soft(Colors.white.withValues(alpha: 0.5), 0.014)
        ..style = PaintingStyle.stroke
        ..strokeWidth = s * 0.035
        ..strokeCap = StrokeCap.round,
    );
    final belly = Path()
      ..moveTo(s * 0.30, s * 0.47)
      ..cubicTo(s * 0.36, s * 0.63, s * 0.58, s * 0.69, s * 0.795, s * 0.60);
    canvas.drawPath(
      belly,
      soft(_yellowDeep.withValues(alpha: 0.85), 0.02)
        ..style = PaintingStyle.stroke
        ..strokeWidth = s * 0.05,
    );
    // A faint ridge down the length, the edge a banana's faces meet on.
    final ridge = Path()
      ..moveTo(s * 0.34, s * 0.47)
      ..cubicTo(s * 0.40, s * 0.575, s * 0.56, s * 0.625, s * 0.775, s * 0.578);
    canvas.drawPath(
      ridge,
      soft(_yellowDeep.withValues(alpha: 0.35), 0.006)
        ..style = PaintingStyle.stroke
        ..strokeWidth = s * 0.012,
    );
    // Sugar spots: a ripe banana's freckles, small and uneven.
    const freckles = [
      [0.455, 0.585, 0.0055, 0.55],
      [0.505, 0.615, 0.0042, 0.45],
      [0.560, 0.640, 0.0062, 0.5],
      [0.600, 0.612, 0.0034, 0.4],
      [0.640, 0.650, 0.0048, 0.5],
      [0.690, 0.628, 0.0058, 0.45],
      [0.720, 0.603, 0.0030, 0.4],
      [0.420, 0.545, 0.0036, 0.4],
      [0.535, 0.588, 0.0028, 0.35],
      [0.665, 0.598, 0.0030, 0.35],
      [0.745, 0.625, 0.0040, 0.45],
      [0.385, 0.505, 0.0032, 0.35],
    ];
    for (var n = 0; n < freckles.length; n++) {
      final f = freckles[n];
      final c = Offset(f[0] * s, f[1] * s);
      final r = f[2] * s * (n.isEven ? 1.0 : 0.75);
      // A faint halo, then a crisp darker core, slightly off-centre.
      canvas.drawOval(
        Rect.fromCenter(center: c, width: r * 3.4, height: r * 2.2),
        soft(const Color(0xFF9A6A20).withValues(alpha: f[3] * 0.35), 0.004),
      );
      canvas.drawOval(
        Rect.fromCenter(
          center: c.translate(r * 0.2, 0),
          width: r * 1.9,
          height: r * 1.3,
        ),
        Paint()..color = const Color(0xFF5A3B17).withValues(alpha: f[3] + 0.15),
      );
    }
    canvas.restore();
    // The dark tip.
    canvas.drawPath(
      path([
        [0.786, 0.552],
        [0.802, 0.554, 0.811, 0.572, 0.805, 0.588],
        [0.801, 0.597, 0.795, 0.600, 0.789, 0.603],
        [0.795, 0.586, 0.793, 0.566, 0.786, 0.552],
      ]),
      fill([const Color(0xFF8A6235), _tip, const Color(0xFF3E2A14)],
          Alignment.topLeft, Alignment.bottomRight),
    );

    // 4. The flap at the front, hanging down the left. Last, so it casts a
    // soft shadow onto the body.
    final frontFlap = path([
      [0.30, 0.355],
      [0.235, 0.318, 0.13, 0.322, 0.112, 0.43],
      [0.118, 0.58, 0.18, 0.72, 0.248, 0.762],
      [0.296, 0.768, 0.312, 0.71, 0.302, 0.625],
      [0.292, 0.525, 0.302, 0.425, 0.33, 0.372],
    ]);
    canvas.save();
    canvas.clipPath(body);
    canvas.translate(s * 0.014, s * 0.004);
    canvas.drawPath(frontFlap, soft(_yellowDeep.withValues(alpha: 0.7), 0.012));
    canvas.restore();
    canvas.drawPath(
      frontFlap,
      fill([_creamLight, _cream, _creamDeep], Alignment.topCenter,
          Alignment.bottomCenter, [0, 0.5, 1]),
    );
    fibres(frontFlap, [
      [0.15, 0.40, 0.15, 0.58, 0.22, 0.74],
      [0.19, 0.38, 0.19, 0.57, 0.25, 0.75],
      [0.23, 0.37, 0.23, 0.56, 0.275, 0.74],
      [0.26, 0.37, 0.265, 0.55, 0.29, 0.70],
      [0.13, 0.45, 0.14, 0.60, 0.19, 0.70],
    ], _creamDeep, 0.32);
    // The flap folds back at the top: shade under the fold.
    canvas.save();
    canvas.clipPath(frontFlap);
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(s * 0.22, s * 0.37),
        width: s * 0.22,
        height: s * 0.06,
      ),
      soft(const Color(0xFFB89A5E).withValues(alpha: 0.45), 0.02),
    );
    canvas.restore();
    // The flap's inside curls away on the right: a soft shade there.
    canvas.save();
    canvas.clipPath(frontFlap);
    canvas.drawLine(
      Offset(s * 0.30, s * 0.38),
      Offset(s * 0.29, s * 0.70),
      soft(_creamDeep, 0.02)
        ..strokeWidth = s * 0.05
        ..strokeCap = StrokeCap.round,
    );
    canvas.restore();
    // A soft darker edge where the flap turns away from the light.
    canvas.save();
    canvas.clipPath(frontFlap);
    canvas.drawPath(
      frontFlap,
      soft(_creamDeep.withValues(alpha: 0.8), 0.01)
        ..style = PaintingStyle.stroke
        ..strokeWidth = s * 0.02,
    );
    canvas.restore();
    canvas.restore();
  }

  @override
  bool shouldRepaint(_BananaPainter old) => false;
}
