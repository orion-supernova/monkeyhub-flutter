import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:flutter/widgets.dart';

import '../../drop/drop_classifier.dart';
import '../../drop/drop_zone.dart';
import '../../theme/app_theme.dart';
import '../../theme/motion.dart';
import '../../theme/theme_scope.dart';

/// How long a zone takes to light up, and to give up again.
///
/// Asymmetric on purpose. Arriving is an answer to something the user just
/// did, so it is quick; leaving is a retraction, and a retraction that snaps
/// makes a pointer crossing two rows look like a strobe. The out is nearly
/// twice the in, which is enough to smear a fast traverse into one continuous
/// movement of light rather than a sequence of flashes.
const Duration _kGlowIn = Duration(milliseconds: 140);
const Duration _kGlowOut = Duration(milliseconds: 240);

/// One full rotation of the dashed ring.
const Duration _kMarch = Duration(milliseconds: 2600);

/// The lit state of a [DropZone], painted over its subtree.
///
/// Everything here is driven by [hover] rather than by a rebuild: the notifier
/// ticks with the pointer, and the only things that read it are this widget's
/// two `AnimatedBuilder`s and the painter underneath them. The zone's actual
/// content — a whole transcript, a chat row with an avatar and a preview — is
/// captured as `child` and never rebuilt for a drag at all.
class DropGlow extends StatefulWidget {
  const DropGlow({
    super.key,
    required this.hover,
    required this.child,
    this.borderRadius,
    this.inset = EdgeInsets.zero,
    this.lift = 0,
  });

  final ValueListenable<DropZoneHover?> hover;
  final Widget child;
  final BorderRadius? borderRadius;
  final EdgeInsets inset;
  final double lift;

  @override
  State<DropGlow> createState() => _DropGlowState();
}

class _DropGlowState extends State<DropGlow> with TickerProviderStateMixin {
  /// 0 → 1 as the zone lights up.
  late final AnimationController _presence;

  /// Free-running, and only while something is actually hovering: a repeating
  /// controller left running behind an idle window is a wake-up per frame for
  /// a widget nobody is looking at, on every chat row at once.
  late final AnimationController _march;

  /// Smoothed pointer position. The raw one jumps in whatever increments the
  /// platform coalesced its updates into, and a spotlight that teleports looks
  /// like a repaint bug rather than a light.
  Offset? _spot;
  DropTone _tone = DropTone.accept;

  /// Cached rather than read where it is used. [MotionScope.of] registers an
  /// inherited dependency, and [_onHover] runs from a notifier callback — a
  /// place with no build in progress, where taking a dependency is both
  /// illegal and useless.
  bool _calm = false;

  @override
  void initState() {
    super.initState();
    _presence = AnimationController(
      vsync: this,
      duration: _kGlowIn,
      reverseDuration: _kGlowOut,
    );
    _march = AnimationController(vsync: this, duration: _kMarch);
    widget.hover.addListener(_onHover);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final calm = MotionScope.of(context).calm;
    if (calm == _calm) return;
    _calm = calm;
    // Someone turning Reduce Motion on mid-drag is a real (if rare) case, and
    // the loop has to stop rather than wait for the next hover to notice.
    if (calm && _march.isAnimating) _march.stop();
  }

  @override
  void didUpdateWidget(DropGlow oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.hover, widget.hover)) {
      oldWidget.hover.removeListener(_onHover);
      widget.hover.addListener(_onHover);
      _onHover();
    }
  }

  @override
  void dispose() {
    widget.hover.removeListener(_onHover);
    _march.dispose();
    _presence.dispose();
    super.dispose();
  }

  void _onHover() {
    final hover = widget.hover.value;
    if (hover == null) {
      _presence.reverse();
      if (_march.isAnimating) _march.stop();
      return;
    }
    _spot = hover.local;
    _tone = hover.tone;
    _presence.forward();
    if (!_march.isAnimating && !_calm) _march.repeat();
  }

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    // Calm motion keeps the ring and drops the march and the lift. The zone
    // still has to be identifiable — this is functional feedback, not
    // decoration — but nothing loops and nothing moves under the content.
    final calm = _calm;
    return AnimatedBuilder(
      animation: _presence,
      builder: (context, child) {
        final t = Curves.easeOut.transform(_presence.value);
        if (t == 0) return child!;
        return Stack(
          fit: StackFit.passthrough,
          children: [
            if (widget.lift != 0 && !calm)
              Transform.translate(
                offset: Offset(0, -widget.lift * t),
                child: child,
              )
            else
              child!,
            Positioned.fill(
              child: IgnorePointer(
                child: RepaintBoundary(
                  child: AnimatedBuilder(
                    animation: _march,
                    builder: (context, _) => CustomPaint(
                      painter: _DropGlowPainter(
                        t: t,
                        phase: calm ? 0 : _march.value,
                        spot: _spot,
                        tone: _tone,
                        theme: theme,
                        radius: widget.borderRadius ??
                            BorderRadius.circular(theme.radiusLg),
                        inset: widget.inset,
                        marching: !calm,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
      child: widget.child,
    );
  }
}

/// The colour a tone speaks in.
///
/// Two colours for three tones, matching what `AppToast` already does with the
/// same three-way split: a caution is a NOTICE, and painting notices in the
/// same red as refusals is how red stops meaning anything. What separates
/// accept from caution is the words in the chip and the glyph beside them, not
/// a third hue nobody's palette has.
Color dropToneColor(AppTheme theme, DropTone tone) =>
    tone == DropTone.refuse ? theme.danger : theme.accent;

class _DropGlowPainter extends CustomPainter {
  _DropGlowPainter({
    required this.t,
    required this.phase,
    required this.spot,
    required this.tone,
    required this.theme,
    required this.radius,
    required this.inset,
    required this.marching,
  });

  final double t;
  final double phase;
  final Offset? spot;
  final DropTone tone;
  final AppTheme theme;
  final BorderRadius radius;
  final EdgeInsets inset;
  final bool marching;

  /// Dash geometry, in logical pixels. A long dash and a short gap read as a
  /// frame that happens to be moving; an even split reads as a barber's pole.
  static const double _dash = 15;
  static const double _gap = 9;

  @override
  void paint(Canvas canvas, Size size) {
    final bounds = inset.deflateRect(Offset.zero & size);
    if (bounds.isEmpty) return;
    final accent = dropToneColor(theme, tone);
    final rrect = radius.toRRect(bounds);

    // 1. The wash. Barely there — its job is to separate the target from its
    // neighbours, not to tint the content, and at any more than this a
    // transcript full of photographs visibly changes colour.
    canvas.drawRRect(
      rrect,
      Paint()..color = accent.withValues(alpha: 0.055 * t),
    );

    // 2. The spotlight: the light is UNDER the cursor, which is the thing that
    // makes a big zone feel aimed rather than merely switched on.
    final at = spot;
    if (at != null) {
      final reach = math.min(size.shortestSide * 0.9, 420.0);
      canvas.save();
      canvas.clipRRect(rrect);
      canvas.drawCircle(
        at,
        reach,
        Paint()
          ..shader = ui.Gradient.radial(at, reach, [
            accent.withValues(alpha: 0.17 * t),
            accent.withValues(alpha: 0.05 * t),
            accent.withValues(alpha: 0),
          ], const [
            0,
            0.45,
            1,
          ]),
      );
      canvas.restore();
    }

    // 3. The ring. Drawn twice: a wide blurred pass for the bloom, then the
    // dashes on top. The bloom is what stops a 2pt stroke from disappearing
    // over a photograph.
    final ringPath = Path()..addRRect(rrect.deflate(1));
    canvas.drawPath(
      ringPath,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 7
        ..color = accent.withValues(alpha: 0.16 * t)
        ..maskFilter = const ui.MaskFilter.blur(ui.BlurStyle.normal, 7),
    );
    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round
      ..color = accent.withValues(alpha: 0.92 * t);
    if (marching) {
      canvas.drawPath(_dashed(ringPath, phase), stroke);
    } else {
      canvas.drawPath(ringPath, stroke);
    }

    // 4. Corner brackets, which arrive a beat after the ring and are what
    // makes the frame read as a TARGET rather than as a border. They grow from
    // the corners outward, so the zone appears to close around the cursor.
    _brackets(canvas, bounds, accent, t);
  }

  /// Extracts [_dash]/[_gap] segments from [source], offset by [phase] of one
  /// full dash cycle.
  ///
  /// `computeMetrics` rather than a `PathEffect` because Flutter has no dash
  /// effect, and rather than hand-walking the rounded corners because the
  /// arithmetic for a dash that straddles a corner arc is exactly what
  /// `extractPath` already does correctly.
  static Path _dashed(Path source, double phase) {
    final out = Path();
    final cycle = _dash + _gap;
    for (final metric in source.computeMetrics()) {
      final length = metric.length;
      if (length <= 0) continue;
      var distance = -(phase * cycle);
      while (distance < length) {
        final start = math.max(distance, 0.0);
        final end = math.min(distance + _dash, length);
        if (end > start) out.addPath(metric.extractPath(start, end), Offset.zero);
        distance += cycle;
      }
    }
    return out;
  }

  void _brackets(Canvas canvas, Rect bounds, Color accent, double t) {
    // Delayed against the ring: nothing happens for the first third of the
    // fade, then the brackets run out to full length over the rest of it.
    final g = (((t - 0.35) / 0.65).clamp(0.0, 1.0));
    if (g == 0) return;
    final reach = 22.0 * Curves.easeOutCubic.transform(g);
    final inset = 9.0;
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round
      ..color = accent.withValues(alpha: 0.95 * t);
    final l = bounds.left + inset;
    final r = bounds.right - inset;
    final tp = bounds.top + inset;
    final b = bounds.bottom - inset;
    final path = Path()
      ..moveTo(l, tp + reach)
      ..lineTo(l, tp)
      ..lineTo(l + reach, tp)
      ..moveTo(r - reach, tp)
      ..lineTo(r, tp)
      ..lineTo(r, tp + reach)
      ..moveTo(r, b - reach)
      ..lineTo(r, b)
      ..lineTo(r - reach, b)
      ..moveTo(l + reach, b)
      ..lineTo(l, b)
      ..lineTo(l, b - reach);
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_DropGlowPainter old) =>
      old.t != t ||
      old.phase != phase ||
      old.spot != spot ||
      old.tone != tone ||
      old.radius != radius ||
      old.inset != inset ||
      old.marching != marching ||
      !identical(old.theme, theme);
}
