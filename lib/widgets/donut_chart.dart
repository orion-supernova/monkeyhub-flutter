import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/theme_scope.dart';

/// One slice of a [DonutChart]. [id] is what animates: a slice keeps its
/// identity across rebuilds, so a value that changes grows or shrinks in place
/// and one that goes to zero closes up rather than vanishing.
class DonutSegment {
  const DonutSegment({required this.id, required this.value, required this.color});
  final Object id;
  final double value;
  final Color color;
}

/// The ring at the top of Storage Usage and Data Usage.
///
/// Slices are separated by a hairline gap and carry their share as a label
/// on the ring when there is room for one. Every change animates: unticking a
/// category in the list below collapses its slice and the others close
/// around the hole, which is what makes the selection feel connected to the
/// chart. Tapping a slice lifts it outward and reports it through [onTap], so
/// the caller can say what it is in the middle.
///
/// While [calculating], an empty ring turns a soft arc around itself instead of
/// drawing a misleading zero.
class DonutChart extends StatefulWidget {
  const DonutChart({
    super.key,
    required this.segments,
    this.size = 196,
    this.thickness = 30,
    this.center,
    this.calculating = false,
    this.highlighted,
    this.onTap,
  });

  final List<DonutSegment> segments;
  final double size;
  final double thickness;
  final Widget? center;
  final bool calculating;

  /// The id of the lifted slice.
  final Object? highlighted;

  /// A slice was tapped (its id), or the empty middle (null).
  final ValueChanged<Object?>? onTap;

  @override
  State<DonutChart> createState() => _DonutChartState();
}

class _DonutChartState extends State<DonutChart> with TickerProviderStateMixin {
  late final AnimationController _morph = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 560),
  );
  late final AnimationController _spin = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  );

  /// Values at the start and end of the current morph, by id, and the colour
  /// and order every id last had (a slice leaving keeps its colour while it
  /// closes).
  Map<Object, double> _from = {};
  Map<Object, double> _to = {};
  final Map<Object, Color> _colors = {};
  final List<Object> _order = [];

  @override
  void initState() {
    super.initState();
    _absorb(widget.segments);
    // The first appearance sweeps open from nothing.
    _from = {for (final id in _order) id: 0};
    _morph.forward(from: 0);
    _syncSpin();
  }

  @override
  void didUpdateWidget(DonutChart old) {
    super.didUpdateWidget(old);
    if (!_same(old.segments, widget.segments)) {
      final now = _current();
      _absorb(widget.segments);
      _from = now;
      _morph.forward(from: 0);
    }
    _syncSpin();
  }

  void _syncSpin() {
    final spinning = widget.calculating && _total(_to) <= 0;
    if (spinning && !_spin.isAnimating) _spin.repeat();
    if (!spinning && _spin.isAnimating) _spin.stop();
  }

  static bool _same(List<DonutSegment> a, List<DonutSegment> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i].id != b[i].id ||
          a[i].value != b[i].value ||
          a[i].color != b[i].color) {
        return false;
      }
    }
    return true;
  }

  void _absorb(List<DonutSegment> segs) {
    _to = {for (final id in _order) id: 0};
    for (final s in segs) {
      if (!_order.contains(s.id)) _order.add(s.id);
      _colors[s.id] = s.color;
      _to[s.id] = math.max(0, s.value);
    }
  }

  Map<Object, double> _current() {
    final t = Curves.easeOutCubic.transform(_morph.value);
    return {
      for (final id in _order)
        id: (_from[id] ?? 0) + ((_to[id] ?? 0) - (_from[id] ?? 0)) * t,
    };
  }

  static double _total(Map<Object, double> m) =>
      m.values.fold(0.0, (a, b) => a + b);

  /// What a full turn of the ring is worth this frame.
  ///
  /// Normally the live total: slices always fill the ring and only their
  /// shares move. But a morph to or from nothing has to be measured against
  /// the side that has something, or the ring cannot empty: one slice is
  /// 100% of a shrinking total on every frame, sits there full, and then
  /// vanishes in one frame when the total reaches zero. Against the fixed
  /// side it sweeps shut, and opens the same way.
  double _scale(Map<Object, double> now) {
    final from = _total(_from);
    final to = _total(_to);
    if (to <= 0) return from;
    if (from <= 0) return to;
    return _total(now);
  }

  @override
  void dispose() {
    _morph.dispose();
    _spin.dispose();
    super.dispose();
  }

  void _onTapUp(TapUpDetails d) {
    final onTap = widget.onTap;
    if (onTap == null) return;
    final c = Offset(widget.size / 2, widget.size / 2);
    final v = d.localPosition - c;
    final r = v.distance;
    final outer = widget.size / 2;
    if (r < outer - widget.thickness - 8 || r > outer + 6) {
      onTap(null);
      return;
    }
    final values = _current();
    final total = _scale(values);
    if (total <= 0) return;
    // Clockwise from twelve o'clock, matching the painter.
    var a = math.atan2(v.dy, v.dx) + math.pi / 2;
    if (a < 0) a += math.pi * 2;
    var acc = 0.0;
    for (final id in _order) {
      final sweep = (values[id] ?? 0) / total * math.pi * 2;
      if (a >= acc && a < acc + sweep) {
        HapticFeedback.selectionClick();
        onTap(id);
        return;
      }
      acc += sweep;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    return GestureDetector(
      onTapUp: _onTapUp,
      child: SizedBox.square(
        dimension: widget.size,
        child: Stack(
          alignment: Alignment.center,
          children: [
            Positioned.fill(
              child: AnimatedBuilder(
                animation: Listenable.merge([_morph, _spin]),
                builder: (context, _) => CustomPaint(
                  painter: _DonutPainter(
                    values: _current(),
                    scale: _scale(_current()),
                    order: _order,
                    colors: _colors,
                    thickness: widget.thickness,
                    track: theme.ink.withValues(alpha: 0.07),
                    spin: _spin.isAnimating ? _spin.value : null,
                    spinColor: theme.accent,
                    highlighted: widget.highlighted,
                    labelStyle: theme.bodyEmph.copyWith(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                      shadows: const [
                        Shadow(color: Color(0x40000000), blurRadius: 2),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            if (widget.center != null)
              Padding(
                padding: EdgeInsets.all(widget.thickness + 10),
                child: widget.center,
              ),
          ],
        ),
      ),
    );
  }
}

class _DonutPainter extends CustomPainter {
  _DonutPainter({
    required this.values,
    required this.scale,
    required this.order,
    required this.colors,
    required this.thickness,
    required this.track,
    required this.spin,
    required this.spinColor,
    required this.highlighted,
    required this.labelStyle,
  });

  final Map<Object, double> values;

  /// A full turn's worth. See `_DonutChartState._scale`.
  final double scale;
  final List<Object> order;
  final Map<Object, Color> colors;
  final double thickness;
  final Color track;
  final double? spin;
  final Color spinColor;
  final Object? highlighted;
  final TextStyle labelStyle;

  /// Gap between slices, in radians at the ring's midline.
  static const _gap = 0.035;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final lift = 5.0;
    final r = size.shortestSide / 2 - thickness / 2 - lift;
    final rect = Rect.fromCircle(center: c, radius: r);
    final total = scale;

    final base = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = thickness
      ..color = track;
    canvas.drawCircle(c, r, base);

    final s = spin;
    if (s != null) {
      final p = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = thickness
        ..strokeCap = StrokeCap.round
        ..shader = SweepGradient(
          colors: [spinColor.withValues(alpha: 0), spinColor.withValues(alpha: 0.55)],
          transform: GradientRotation(s * math.pi * 2 - math.pi / 2),
        ).createShader(rect);
      canvas.drawArc(rect, s * math.pi * 2 - math.pi / 2, math.pi * 1.2, false, p);
      return;
    }
    if (total <= 0) return;

    final live = order.where((id) => (values[id] ?? 0) > 0).length;
    // Shares are of what is there now, whatever the ring is scaled to.
    final now = values.values.fold(0.0, (a, b) => a + b);
    var start = -math.pi / 2;
    for (final id in order) {
      final v = values[id] ?? 0;
      if (v <= 0) continue;
      final sweep = v / total * math.pi * 2;
      // A lone slice is a full ring with no seam to cut.
      final gap = live > 1 ? math.min(_gap, sweep * 0.4) : 0.0;
      final mid = start + sweep / 2;
      final isLifted = id == highlighted;
      final centre = isLifted
          ? c + Offset(math.cos(mid), math.sin(mid)) * lift
          : c;
      final paint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = isLifted ? thickness + 4 : thickness
        ..color = colors[id] ?? spinColor;
      canvas.drawArc(Rect.fromCircle(center: centre, radius: r),
          start + gap / 2, math.max(0.0, sweep - gap), false, paint);

      final share = now <= 0 ? 0.0 : v / now;
      if (share >= 0.045) {
        final pct = share * 100;
        final text = pct >= 9.95 ? '${pct.round()}%' : '${pct.toStringAsFixed(1)}%';
        final tp = TextPainter(
          text: TextSpan(text: text, style: labelStyle),
          textDirection: TextDirection.ltr,
        )..layout();
        // Only where the label fits along the slice's own arc.
        if (tp.width < sweep * r - 6) {
          final at = centre + Offset(math.cos(mid), math.sin(mid)) * r;
          tp.paint(canvas, at - Offset(tp.width / 2, tp.height / 2));
        }
      }
      start += sweep;
    }
  }

  @override
  bool shouldRepaint(_DonutPainter old) => true;
}
