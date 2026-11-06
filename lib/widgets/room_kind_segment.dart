import 'dart:math' as math;
import 'dart:ui' show PathMetric;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../keyboard/focusable_tap.dart';
import '../models/enums.dart';
import '../theme/motion.dart';
import '../theme/theme_preference.dart';
import '../theme/theme_scope.dart';
import 'ios_kit.dart';

/// Regular / Secret: a two-segment control whose thumb glides between the
/// options and whose glyphs say what each one is.
///
/// The regular glyph is a plain ring. The secret glyph is the same ring that
/// turns dotted while a padlock drops into it, driven by the same value that
/// moves the thumb, so choosing Secret reads as the ring locking itself. Both
/// halves are one [AnimationController]; nothing here animates a blur.
///
/// Controlled: [value] is the truth, [onChanged] reports a tap. Calm motion
/// (Reduce Motion, low power) jumps straight to the end state.
class RoomKindSegment extends StatefulWidget {
  const RoomKindSegment({
    super.key,
    required this.value,
    required this.onChanged,
    required this.regularLabel,
    required this.secretLabel,
  });

  /// Only [RoomType.regular] and [RoomType.secret] are offered.
  final RoomType value;
  final ValueChanged<RoomType> onChanged;
  final String regularLabel;
  final String secretLabel;

  @override
  State<RoomKindSegment> createState() => _RoomKindSegmentState();
}

class _RoomKindSegmentState extends State<RoomKindSegment>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    value: widget.value == RoomType.secret ? 1 : 0,
  );

  @override
  void didUpdateWidget(RoomKindSegment old) {
    super.didUpdateWidget(old);
    if (old.value == widget.value) return;
    final to = widget.value == RoomType.secret ? 1.0 : 0.0;
    if (MotionScope.of(context).calm) {
      _c.value = to;
    } else {
      _c.animateTo(
        to,
        duration: const Duration(milliseconds: 520),
        curve: Curves.linear,
      );
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  void _pick(RoomType t) {
    if (t == widget.value) return;
    HapticFeedback.selectionClick();
    widget.onChanged(t);
  }

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final violet = tileColor(theme, TileTone.purple);
    const height = 48.0;
    const inset = 3.0;
    return Container(
      height: height,
      decoration: BoxDecoration(
        color: quietFill(theme),
        borderRadius: BorderRadius.circular(height / 2),
      ),
      padding: const EdgeInsets.all(inset),
      child: LayoutBuilder(
        builder: (context, box) {
          final w = box.maxWidth / 2;
          return Stack(
            children: [
              // The thumb: eased with a small overshoot so it settles like a
              // spring rather than stopping dead.
              AnimatedBuilder(
                animation: _c,
                builder: (context, _) {
                  final p = Curves.easeOutBack.transform(_c.value);
                  return Positioned(
                    left: w * p,
                    top: 0,
                    bottom: 0,
                    width: w,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: Color.lerp(
                          theme.isLight ? Colors.white : theme.surfaceRaised,
                          violet,
                          _c.value * (theme.isLight ? 0.22 : 0.45),
                        ),
                        borderRadius: BorderRadius.circular(height / 2),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black
                                .withValues(alpha: theme.isLight ? 0.10 : 0.30),
                            blurRadius: 6,
                            offset: const Offset(0, 1),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
              Row(
                children: [
                  Expanded(
                    child: _Seg(
                      label: widget.regularLabel,
                      selected: widget.value == RoomType.regular,
                      onTap: () => _pick(RoomType.regular),
                      glyph: AnimatedBuilder(
                        animation: _c,
                        builder: (context, _) => _RingGlyph(
                          secrecy: 0,
                          fill: 1 - _c.value,
                          color: theme.ink,
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: _Seg(
                      label: widget.secretLabel,
                      selected: widget.value == RoomType.secret,
                      onTap: () => _pick(RoomType.secret),
                      glyph: AnimatedBuilder(
                        animation: _c,
                        builder: (context, _) => _RingGlyph(
                          secrecy: _c.value,
                          fill: 0,
                          color: theme.ink,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }
}

class _Seg extends StatelessWidget {
  const _Seg({
    required this.label,
    required this.selected,
    required this.onTap,
    required this.glyph,
  });
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final Widget glyph;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    return FocusableTap(
      onTap: onTap,
      semanticLabel: label,
      selected: selected,
      radius: 24,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Center(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              glyph,
              const SizedBox(width: 7),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.bodyEmph.copyWith(
                    fontSize: 15,
                    color: selected ? theme.ink : theme.inkSoft,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The ring glyph. [secrecy] 0 is a solid ring; at 1 the ring is dotted and a
/// padlock has dropped into it. [fill] grows a centre dot (the regular
/// segment's "this one" mark).
class _RingGlyph extends StatelessWidget {
  const _RingGlyph({
    required this.secrecy,
    required this.fill,
    required this.color,
  });
  final double secrecy;
  final double fill;
  final Color color;

  @override
  Widget build(BuildContext context) => CustomPaint(
        size: const Size.square(22),
        painter: RingGlyphPainter(secrecy: secrecy, fill: fill, color: color),
      );
}

/// Paints the ring-to-padlock morph. Public so a test can render it.
class RingGlyphPainter extends CustomPainter {
  const RingGlyphPainter({
    required this.secrecy,
    required this.fill,
    required this.color,
  });

  final double secrecy;
  final double fill;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.width * 0.40;
    final stroke = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8
      ..strokeCap = StrokeCap.round;

    // The ring, cut into dashes whose gaps open as secrecy rises.
    const dashes = 12;
    final span = 2 * math.pi / dashes;
    final filled = 1 - 0.55 * secrecy.clamp(0.0, 1.0);
    for (var i = 0; i < dashes; i++) {
      final a = i * span - math.pi / 2;
      canvas.drawArc(
        Rect.fromCircle(center: c, radius: r),
        a,
        span * filled,
        false,
        stroke,
      );
    }

    if (fill > 0.01) {
      canvas.drawCircle(
        c,
        r * 0.42 * Curves.easeOutBack.transform(fill.clamp(0.0, 1.0)),
        Paint()..color = color,
      );
    }

    final s = secrecy.clamp(0.0, 1.0);
    if (s > 0.01) {
      // The padlock drops in: the body scales up on an overshoot while the
      // shackle draws itself over it.
      final pop = Curves.easeOutBack.transform(((s - 0.15) / 0.85).clamp(0.0, 1.0));
      final bodyW = r * 0.95 * pop;
      final bodyH = r * 0.72 * pop;
      final top = c.dy - r * 0.02;
      final body = RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: Offset(c.dx, top + bodyH / 2),
          width: bodyW,
          height: bodyH,
        ),
        Radius.circular(1.6 * pop),
      );
      canvas.drawRRect(body, Paint()..color = color);
      final sh = Path()
        ..moveTo(c.dx - bodyW * 0.28, top)
        ..lineTo(c.dx - bodyW * 0.28, top - r * 0.22)
        ..arcToPoint(
          Offset(c.dx + bodyW * 0.28, top - r * 0.22),
          radius: Radius.circular(bodyW * 0.28),
        )
        ..lineTo(c.dx + bodyW * 0.28, top);
      final PathMetric m = sh.computeMetrics().first;
      canvas.drawPath(
        m.extractPath(0, m.length * s),
        stroke..strokeWidth = 1.6,
      );
    }
  }

  @override
  bool shouldRepaint(RingGlyphPainter old) =>
      old.secrecy != secrecy || old.fill != fill || old.color != color;
}
