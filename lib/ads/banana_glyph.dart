import 'dart:math' as math;
import 'dart:ui' as ui;

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

  /// The art, recorded once per pixel size: the motion only moves it.
  static final _cache = <int, ui.Picture>{};

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width;
    final p = pop.value;
    final lift = p == 0 ? 0.0 : math.sin(math.pi * Curves.easeOut.transform(p));
    final wobble = p == 0 ? 0.0 : math.sin(p * math.pi * 5) * (1 - p) * 0.3;
    final w = wave.value;
    final waveAngle = w < 0.32 ? math.sin(w / 0.32 * math.pi * 2) * 0.16 : 0.0;

    final key = (s * 4).round();
    final art = _cache[key] ??= _BananaArt.record(s);

    canvas.save();
    canvas.translate(s * 0.5, s * 0.8 - s * 0.10 * lift);
    canvas.rotate(wobble + waveAngle);
    canvas.scale(1 + 0.26 * lift);
    canvas.translate(-s * 0.5, -s * 0.8);
    canvas.drawPicture(art);
    canvas.restore();
  }

  @override
  bool shouldRepaint(_BananaPainter old) => false;
}

/// One part of the banana: a cubic spine and a width along it. Every shape,
/// shade, grain line and spot is laid out from the spine, so the forms taper
/// and bend together.
class _Part {
  _Part(this.c, this.width);

  /// Cubic control points, unit box.
  final List<Offset> c;

  /// Width at t (unit box).
  final double Function(double t) width;

  Offset at(double t) {
    final u = 1 - t;
    return c[0] * (u * u * u) +
        c[1] * (3 * u * u * t) +
        c[2] * (3 * u * t * t) +
        c[3] * (t * t * t);
  }

  /// Unit normal, to the left of the direction of travel.
  Offset normal(double t) {
    final u = 1 - t;
    final d = (c[1] - c[0]) * (3 * u * u) +
        (c[2] - c[1]) * (6 * u * t) +
        (c[3] - c[2]) * (3 * t * t);
    final l = d.distance == 0 ? 1.0 : d.distance;
    return Offset(-d.dy / l, d.dx / l);
  }

  /// The outline at [scale] of the width, its centre moved [shift] widths
  /// along the normal, between [t0] and [t1], in pixels for side [s].
  Path outline(double s,
      {double scale = 1, double shift = 0, double t0 = 0, double t1 = 1}) {
    const n = 72;
    final left = <Offset>[];
    final right = <Offset>[];
    for (var i = 0; i <= n; i++) {
      final t = t0 + (t1 - t0) * i / n;
      final p = at(t);
      final nn = normal(t);
      final w = width(t);
      final mid = p + nn * (shift * w);
      left.add((mid + nn * (w * scale / 2)) * s);
      right.add((mid - nn * (w * scale / 2)) * s);
    }
    final path = Path()..moveTo(left.first.dx, left.first.dy);
    for (final q in left.skip(1)) {
      path.lineTo(q.dx, q.dy);
    }
    for (final q in right.reversed) {
      path.lineTo(q.dx, q.dy);
    }
    return path..close();
  }

  /// A line along the part, [f] widths off the spine.
  Path along(double s, double f, {double t0 = 0, double t1 = 1}) {
    const n = 48;
    final path = Path();
    for (var i = 0; i <= n; i++) {
      final t = t0 + (t1 - t0) * i / n;
      final q = (at(t) + normal(t) * (f * width(t))) * s;
      i == 0 ? path.moveTo(q.dx, q.dy) : path.lineTo(q.dx, q.dy);
    }
    return path;
  }

  /// +1 when the normal's side faces the light (upper left), else -1.
  double get lit {
    const light = Offset(-0.55, -0.83);
    final n = normal(0.5);
    return (n.dx * light.dx + n.dy * light.dy) >= 0 ? 1 : -1;
  }
}

/// A rounded end over the first or last [cap] of the length.
double _cap(double t, double cap) {
  if (t >= cap) return 1;
  final x = 1 - t / cap;
  return math.sqrt(math.max(0, 1 - x * x));
}

double _lerp(double a, double b, double t) => a + (b - a) * t;

class _Tone {
  const _Tone(this.dark, this.mid, this.light, this.shine);
  final Color dark;
  final Color mid;
  final Color light;
  final Color shine;
}

class _BananaArt {
  static const _cream = _Tone(
    Color(0xFFD5BE90),
    Color(0xFFE9D8B2),
    Color(0xFFF6ECD4),
    Color(0xFFFFFCF2),
  );
  static const _flesh = _Tone(
    Color(0xFFDCC99C),
    Color(0xFFEFE3C2),
    Color(0xFFFAF3E1),
    Color(0xFFFFFFFF),
  );
  static const _skin = _Tone(
    Color(0xFFD4930F),
    Color(0xFFF0BB22),
    Color(0xFFF9D746),
    Color(0xFFFFF2A8),
  );
  static const _skinEdge = Color(0xFFE6AC1A);

  static final _backFlap = _Part(
    const [
      Offset(0.37, 0.445),
      Offset(0.455, 0.235),
      Offset(0.66, 0.235),
      Offset(0.752, 0.495),
    ],
    // A strip of peel: wide where it leaves the fruit, tapering to a point.
    (t) => _lerp(0.105, 0.034, math.pow(t, 1.2).toDouble()) * _cap(1 - t, 0.11),
  );
  static final _fruit = _Part(
    const [
      Offset(0.312, 0.47),
      Offset(0.305, 0.30),
      Offset(0.288, 0.13),
      Offset(0.309, 0.012),
    ],
    (t) => _lerp(0.158, 0.132, t) * _cap(1 - t, 0.26),
  );
  static final _body = _Part(
    const [
      Offset(0.300, 0.372),
      Offset(0.33, 0.56),
      Offset(0.50, 0.625),
      Offset(0.705, 0.585),
    ],
    // Rounded at the top too: that end is the peel's cup around the fruit.
    (t) =>
        _lerp(0.19, 0.06, math.pow(t, 1.5).toDouble()) *
        _cap(t, 0.09) *
        _cap(1 - t, 0.05),
  );
  static final _frontFlap = _Part(
    const [
      Offset(0.318, 0.405),
      Offset(0.18, 0.385),
      Offset(0.150, 0.62),
      Offset(0.205, 0.785),
    ],
    // Widest just after it leaves the fruit, then tapering to a point.
    (t) =>
        _lerp(0.165, 0.04, math.pow(t, 1.3).toDouble()) *
        _cap(t, 0.13) *
        _cap(1 - t, 0.11) *
        (0.92 + 0.16 * math.sin(math.pi * math.min(1, t * 1.6))),
  );

  static ui.Picture record(double s) {
    final rec = ui.PictureRecorder();
    final canvas = Canvas(rec);
    // Fit: the art spans x 0.12..0.76, y 0.01..0.79.
    const k = 1.2;
    canvas.translate(s * 0.5, s * 0.5);
    canvas.scale(k);
    canvas.translate(-s * 0.44, -s * 0.40);
    _paint(canvas, s);
    return rec.endRecording();
  }

  static Paint _soft(Color c, double blur, double s) => Paint()
    ..color = c
    ..maskFilter = blur <= 0 ? null : MaskFilter.blur(BlurStyle.normal, s * blur);

  /// Fills [part] as a rounded form: dark at the silhouette, lighter toward
  /// the lit side, a soft shine, and a gentle occlusion line at the edge.
  static void _shade(Canvas canvas, double s, _Part part, _Tone tone,
      {double t0 = 0, double t1 = 1}) {
    final lit = part.lit;
    final base = part.outline(s, t0: t0, t1: t1);
    canvas.drawPath(base, Paint()..color = tone.dark);
    canvas.save();
    canvas.clipPath(base);
    canvas.drawPath(part.outline(s, scale: 0.86, shift: 0.03 * lit),
        _soft(tone.mid, 0.014, s));
    canvas.drawPath(part.outline(s, scale: 0.58, shift: 0.11 * lit),
        _soft(tone.light, 0.016, s));
    canvas.drawPath(
        part.outline(s,
            scale: 0.20,
            shift: 0.22 * lit,
            t0: t0 + (t1 - t0) * 0.08,
            t1: t0 + (t1 - t0) * 0.86),
        _soft(tone.shine.withValues(alpha: 0.85), 0.010, s));
    canvas.drawPath(
      base,
      _soft(tone.dark.withValues(alpha: 0.7), 0.008, s)
        ..style = PaintingStyle.stroke
        ..strokeWidth = s * 0.014,
    );
    canvas.restore();
  }

  /// Fills [part] as a thin strip of peel, not a tube: an even cream face,
  /// shade gathering toward the base and along the edge turned from the
  /// light, a soft dip down the middle where the peel is concave.
  static void _flat(Canvas canvas, double s, _Part part, _Tone tone) {
    final lit = part.lit;
    final base = part.outline(s);
    canvas.drawPath(base, Paint()..color = tone.mid);
    canvas.save();
    canvas.clipPath(base);
    // The lit half, a touch lighter.
    canvas.drawPath(part.outline(s, scale: 0.6, shift: 0.22 * lit),
        _soft(tone.light, 0.02, s));
    // The concave dip down the middle.
    canvas.drawPath(part.outline(s, scale: 0.18, shift: -0.04 * lit, t0: 0.1, t1: 0.85),
        _soft(tone.dark.withValues(alpha: 0.35), 0.014, s));
    // The edge turned away from the light.
    canvas.drawPath(part.outline(s, scale: 0.3, shift: -0.38 * lit),
        _soft(tone.dark.withValues(alpha: 0.7), 0.014, s));
    // Shade where it leaves the fruit.
    canvas.drawPath(part.outline(s, t0: 0, t1: 0.22, scale: 1.1),
        _soft(tone.dark.withValues(alpha: 0.55), 0.03, s));
    // A thin bright lip on the lit edge: the light catching the peel's edge.
    canvas.drawPath(part.outline(s, scale: 0.08, shift: 0.46 * lit, t0: 0.12, t1: 0.9),
        _soft(tone.shine.withValues(alpha: 0.8), 0.004, s));
    canvas.restore();
  }

  /// Grain along [part]: fine, broken, uneven lines, and a speckle of noise.
  static void _grain(Canvas canvas, double s, _Part part, Color c,
      {required int seed, double alpha = 0.22, int lines = 9, int specks = 70}) {
    final base = part.outline(s);
    final rnd = math.Random(seed);
    canvas.save();
    canvas.clipPath(base);
    for (var i = 0; i < lines; i++) {
      final f = -0.4 + 0.8 * (i + rnd.nextDouble() * 0.6) / lines;
      final line = part.along(s, f, t0: 0.02, t1: 0.97);
      final pen = Paint()
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeWidth = s * (0.0022 + rnd.nextDouble() * 0.0025)
        ..color = c.withValues(alpha: alpha * (0.5 + rnd.nextDouble() * 0.6))
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, s * 0.0022);
      for (final m in line.computeMetrics()) {
        var at = m.length * rnd.nextDouble() * 0.1;
        while (at < m.length) {
          final run = m.length * (0.18 + rnd.nextDouble() * 0.35);
          canvas.drawPath(m.extractPath(at, at + run), pen);
          at += run + m.length * (0.02 + rnd.nextDouble() * 0.06);
        }
      }
    }
    for (var i = 0; i < specks; i++) {
      final t = rnd.nextDouble();
      final f = (rnd.nextDouble() - 0.5) * 0.9;
      final q = (part.at(t) + part.normal(t) * (f * part.width(t))) * s;
      canvas.drawCircle(
        q,
        s * (0.0012 + rnd.nextDouble() * 0.0022),
        Paint()..color = c.withValues(alpha: 0.10 + rnd.nextDouble() * 0.14),
      );
    }
    canvas.restore();
  }

  /// The tip of a flap curls toward us and shows its yellow skin: the last
  /// stretch is shaded as skin, with a soft crease where it turns.
  static void _curl(Canvas canvas, double s, _Part part, double from) {
    // A sliver, not a cap: the skin shows along the shaded edge only, and
    // widens toward the very tip, as a curled edge does.
    final lit = part.lit;
    final sliver = Path();
    const n = 24;
    final inner = <Offset>[];
    final outer = <Offset>[];
    for (var i = 0; i <= n; i++) {
      final t = from + (1 - from) * i / n;
      final k = i / n;
      final w = part.width(t);
      final nn = part.normal(t);
      final edge = part.at(t) - nn * (lit * w / 2);
      outer.add(edge * s);
      inner.add((edge + nn * (lit * w * (0.08 + 0.42 * k * k))) * s);
    }
    sliver.moveTo(outer.first.dx, outer.first.dy);
    for (final q in outer.skip(1)) {
      sliver.lineTo(q.dx, q.dy);
    }
    for (final q in inner.reversed) {
      sliver.lineTo(q.dx, q.dy);
    }
    sliver.close();
    final base = part.outline(s);
    canvas.save();
    canvas.clipPath(base);
    // Its shadow on the cream first, then the skin itself.
    canvas.drawPath(
      sliver,
      _soft(const Color(0xFF8E6A22).withValues(alpha: 0.4), 0.01, s),
    );
    canvas.drawPath(
      sliver,
      Paint()
        ..shader = LinearGradient(
          colors: [_skin.light, _skin.mid, _skin.dark],
          stops: const [0, 0.55, 1],
        ).createShader(sliver.getBounds()),
    );
    canvas.restore();
  }

  /// A cast shadow of [shape] (shifted by [d]) falling only on [onto].
  static void _cast(Canvas canvas, double s, Path shape, Path onto, Offset d,
      Color c, double blur) {
    canvas.save();
    canvas.clipPath(onto);
    canvas.translate(d.dx * s, d.dy * s);
    canvas.drawPath(shape, _soft(c, blur, s));
    canvas.restore();
  }

  static void _paint(Canvas canvas, double s) {
    final back = _backFlap.outline(s);
    final fruit = _fruit.outline(s);
    final body = _body.outline(s);
    final front = _frontFlap.outline(s);

    // 1. Back flap: the yellow skin peeks under its lower edge (the peel's
    // thickness), the cream inside faces us.
    canvas.drawPath(
      _backFlap.outline(s, shift: -0.14 * _backFlap.lit, scale: 1.0),
      Paint()..color = _skinEdge,
    );
    _flat(canvas, s, _backFlap, _cream);
    _grain(canvas, s, _backFlap, _cream.dark, seed: 3, lines: 6, specks: 40);
    _curl(canvas, s, _backFlap, 0.86);
    // Where it leaves the fruit, it sits in the fruit's shade.
    canvas.save();
    canvas.clipPath(back);
    canvas.drawCircle(Offset(s * 0.415, s * 0.36), s * 0.075,
        _soft(const Color(0xFF9C7F4A).withValues(alpha: 0.55), 0.03, s));
    canvas.restore();

    // 2. The fruit.
    _shade(canvas, s, _fruit, _flesh);
    _grain(canvas, s, _fruit, _flesh.dark, seed: 7, alpha: 0.28, lines: 11, specks: 60);
    // A little translucence at the top, and the peel's grip at the bottom.
    canvas.save();
    canvas.clipPath(fruit);
    canvas.drawCircle(Offset(s * 0.30, s * 0.05), s * 0.05,
        _soft(Colors.white.withValues(alpha: 0.45), 0.03, s));
    // Light passing through the fruit: a warm glow just inside its edge.
    canvas.drawPath(
      fruit,
      _soft(const Color(0xFFFFF6DC).withValues(alpha: 0.75), 0.008, s)
        ..style = PaintingStyle.stroke
        ..strokeWidth = s * 0.012,
    );
    canvas.restore();

    // 3. The body, still in its skin.
    _cast(canvas, s, body, fruit, const Offset(0, -0.012),
        const Color(0xFF8E7444).withValues(alpha: 0.55), 0.02);
    _shade(canvas, s, _body, _skin);
    _grain(canvas, s, _body, _skin.dark, seed: 11, alpha: 0.18, lines: 5, specks: 30);
    // A banana is faceted: faint ridges where its faces meet.
    for (final (f, c) in [
      (0.22 * _body.lit, const Color(0xFFFFF0A0)),
      (-0.18 * _body.lit, const Color(0xFFC98A0C)),
    ]) {
      canvas.drawPath(
        _body.along(s, f, t0: 0.08, t1: 0.92),
        _soft(c.withValues(alpha: 0.45), 0.004, s)
          ..style = PaintingStyle.stroke
          ..strokeWidth = s * 0.006,
      );
    }
    // Sugar spots: clustered toward the underside and the tip, uneven.
    canvas.save();
    canvas.clipPath(body);
    final rnd = math.Random(21);
    for (var i = 0; i < 18; i++) {
      final t = 0.2 + rnd.nextDouble() * 0.7;
      final f = -0.05 * _body.lit + (rnd.nextDouble() - 0.35) * 0.75;
      final q = (_body.at(t) + _body.normal(t) * (f * _body.width(t))) * s;
      final r = s * (0.002 + math.pow(rnd.nextDouble(), 2.6) * 0.0065);
      final a = 0.35 + rnd.nextDouble() * 0.45;
      canvas.drawOval(
        Rect.fromCenter(center: q, width: r * 3.2, height: r * 2.2),
        _soft(const Color(0xFFA06A12).withValues(alpha: a * 0.35), 0.005, s),
      );
      canvas.drawOval(
        Rect.fromCenter(center: q, width: r * 1.8, height: r * 1.3),
        Paint()..color = const Color(0xFF4E3212).withValues(alpha: a),
      );
    }
    canvas.restore();
    // The cup's rim: the cut edge of the peel shows its pale inside.
    final rim = _body.outline(s, t0: 0, t1: 0.03);
    canvas.drawPath(rim, Paint()..color = _cream.light);
    canvas.drawPath(
      rim,
      _soft(_cream.dark.withValues(alpha: 0.6), 0.004, s)
        ..style = PaintingStyle.stroke
        ..strokeWidth = s * 0.006,
    );
    // The stalk end: a graded brown cap.
    final tip = _body.outline(s, t0: 0.955, t1: 1.0, scale: 1.04);
    canvas.drawPath(
      tip,
      Paint()
        ..shader = const LinearGradient(
          colors: [Color(0xFF8C6232), Color(0xFF4A3016), Color(0xFF2E1D0C)],
        ).createShader(tip.getBounds()),
    );

    // Loose strings: two of the fruit's fibres come away and drape over
    // the cup's rim onto the skin.
    // Only where it can be seen: at pill size a strand is a stray line.
    for (final st in s < 48
        ? const <List<double>>[]
        : const [
            [0.356, 0.325, 0.405, 0.375, 0.392, 0.455],
          ]) {
      final path = Path()
        ..moveTo(st[0] * s, st[1] * s)
        ..quadraticBezierTo(st[2] * s, st[3] * s, st[4] * s, st[5] * s);
      // Shadow first, where it lies on the skin.
      canvas.save();
      canvas.clipPath(body);
      canvas.translate(s * 0.006, s * 0.006);
      canvas.drawPath(
        path,
        _soft(const Color(0xFF9A6A0E).withValues(alpha: 0.5), 0.004, s)
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round
          ..strokeWidth = s * 0.008,
      );
      canvas.restore();
      canvas.drawPath(
        path,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round
          ..strokeWidth = s * 0.0072
          ..color = _flesh.dark.withValues(alpha: 0.85),
      );
      canvas.drawPath(
        path,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round
          ..strokeWidth = s * 0.0038
          ..color = _flesh.light.withValues(alpha: 0.9),
      );
    }

    // 4. Front flap: skin along its outer edge, a shadow onto the body.
    _cast(canvas, s, front, body, const Offset(0.022, 0.006),
        const Color(0xFF9A6A0E).withValues(alpha: 0.6), 0.018);
    // Only on the fruit that shows: its base is under the body.
    final fruitShown = Path.combine(PathOperation.difference, fruit, body);
    _cast(canvas, s, front, fruitShown, const Offset(0.02, -0.004),
        const Color(0xFF8E7444).withValues(alpha: 0.45), 0.016);
    _flat(canvas, s, _frontFlap, _cream);
    _grain(canvas, s, _frontFlap, _cream.dark, seed: 5, lines: 8, specks: 50);
    // The fold at its top, where it bends away from the fruit.
    canvas.save();
    canvas.clipPath(front);
    canvas.drawOval(
      Rect.fromCenter(
          center: Offset(s * 0.255, s * 0.37), width: s * 0.2, height: s * 0.06),
      _soft(const Color(0xFF9C7F4A).withValues(alpha: 0.5), 0.022, s),
    );
    canvas.restore();
    _curl(canvas, s, _frontFlap, 0.88);
  }
}
