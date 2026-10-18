import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../keyboard/focusable_tap.dart';
import '../l10n/generated/app_localizations.dart';
import '../theme/motion.dart';
import '../theme/theme_scope.dart';
import 'ios_kit.dart';

/// Add or take back your own reaction with [emoji]: the control under every
/// who-reacted list (chat messages, moment comments), since tapping a
/// reaction chip opens that list rather than toggling.
///
/// One capsule for both states, no accent fill: the glyph carries it. Off, a
/// line "+" and the label in accent invite you in; on, the "+" turns a
/// quarter and its crossbar folds away into a "−", and the ink dims. Adding
/// also bursts a ring of rays off the emoji and pops it; taking back sinks it.
/// The motion follows the reaction itself rather than the tap, so a refused
/// add (over the per-person cap) never celebrates.
class ReactToggle extends StatefulWidget {
  const ReactToggle({
    super.key,
    required this.emoji,
    required this.mine,
    required this.onTap,
  });

  final String emoji;
  final bool mine;
  final VoidCallback onTap;

  @override
  State<ReactToggle> createState() => _ReactToggleState();
}

class _ReactToggleState extends State<ReactToggle>
    with TickerProviderStateMixin {
  /// 1 yours, 0 not: the "+" to "−" fold and the ink.
  late final AnimationController _state = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 280),
    value: widget.mine ? 1 : 0,
  );

  /// The one-off celebration when yours lands.
  late final AnimationController _burst = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 520),
  );

  /// The one-off sink when yours is taken back.
  late final AnimationController _drop = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 360),
  );

  bool _calm = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _calm = MotionScope.of(context).calm;
  }

  @override
  void didUpdateWidget(ReactToggle old) {
    super.didUpdateWidget(old);
    if (old.mine == widget.mine) return;
    // A filter change can flip [mine] too, and that is not something you
    // did: it switches state without a kick.
    if (_calm || old.emoji != widget.emoji) {
      _state.value = widget.mine ? 1 : 0;
      return;
    }
    _state.animateTo(widget.mine ? 1 : 0, curve: Curves.easeOutCubic);
    if (widget.mine) {
      HapticFeedback.lightImpact();
      _burst.forward(from: 0);
    } else {
      _drop.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _state.dispose();
    _burst.dispose();
    _drop.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final motion = MotionScope.of(context);
    final l10n = AppLocalizations.of(context);
    final label = widget.mine
        ? l10n.reactionDetailsSheetRemoveYours
        : l10n.reactionDetailsSheetAddYours;

    final emoji = AnimatedBuilder(
      animation: Listenable.merge([_burst, _drop]),
      child: AnimatedSwitcher(
        // A new filter swaps the emoji with a small pop rather than a cut.
        duration: motion.d(theme.motionFast),
        switchInCurve: motion.c(Curves.easeOutBack),
        transitionBuilder: (child, anim) => FadeTransition(
          opacity: anim,
          child: ScaleTransition(scale: anim, child: child),
        ),
        child: Text(
          widget.emoji,
          key: ValueKey(widget.emoji),
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 20, height: 1.15),
        ),
      ),
      builder: (context, child) {
        final b = _burst.value;
        final d = _drop.value;
        final pop = b == 0 ? 0.0 : math.sin(math.pi * Curves.easeOut.transform(b));
        final sink = d == 0 ? 0.0 : math.sin(math.pi * d);
        return Transform.translate(
          offset: Offset(0, 3 * sink - 2 * pop),
          child: Transform.rotate(
            angle: -0.18 * pop,
            child: Transform.scale(
              scale: 1 + 0.38 * pop - 0.14 * sink,
              child: child,
            ),
          ),
        );
      },
    );

    return SpringPress(
      onTap: widget.onTap,
      haptic: true,
      semanticLabel: '$label ${widget.emoji}',
      focusShape: FocusRingShape.capsule,
      child: AnimatedBuilder(
        animation: _state,
        builder: (context, _) {
          final ink =
              Color.lerp(theme.accent, theme.inkSoft, _state.value)!;
          return Container(
            height: 48,
            decoration: BoxDecoration(
              color: quietFill(theme),
              borderRadius: BorderRadius.circular(999),
            ),
            alignment: Alignment.center,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                RepaintBoundary(
                  child: CustomPaint(
                    size: const Size(14, 14),
                    painter: _PlusMinusPainter(ink: ink, state: _state),
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  width: 30,
                  height: 30,
                  child: CustomPaint(
                    // Over the emoji, so the rays read as thrown off it.
                    foregroundPainter: _BurstPainter(
                      color: theme.accent,
                      burst: _burst,
                    ),
                    child: Center(child: emoji),
                  ),
                ),
                const SizedBox(width: 8),
                AnimatedSize(
                  duration: motion.d(theme.motionFast),
                  curve: theme.motionCurve,
                  child: AnimatedSwitcher(
                    duration: motion.d(theme.motionFast),
                    switchInCurve: motion.c(theme.motionEntrance),
                    transitionBuilder: (child, anim) => FadeTransition(
                      opacity: anim,
                      child: SlideTransition(
                        position: Tween(
                          begin: const Offset(0, 0.35),
                          end: Offset.zero,
                        ).animate(anim),
                        child: child,
                      ),
                    ),
                    child: Text(
                      label,
                      key: ValueKey(widget.mine),
                      style: theme.bodyEmph.copyWith(color: ink),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

/// A line "+" that becomes a "−". The whole glyph turns a quarter, which lays
/// its upright bar flat as the minus, while the crossbar shrinks to nothing
/// about its centre: one glyph folding, not two icons swapping.
class _PlusMinusPainter extends CustomPainter {
  _PlusMinusPainter({required this.ink, required this.state})
      : super(repaint: state);

  final Color ink;
  final Animation<double> state;

  @override
  void paint(Canvas canvas, Size size) {
    final t = state.value;
    final c = size.center(Offset.zero);
    final half = size.shortestSide / 2 - 1;
    final stroke = Paint()
      ..color = ink
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.9
      ..strokeCap = StrokeCap.round;
    canvas
      ..save()
      ..translate(c.dx, c.dy)
      ..rotate(t * math.pi / 2);
    canvas.drawLine(Offset(0, -half), Offset(0, half), stroke);
    final bar = half * (1 - t);
    if (bar > 0.2) {
      canvas.drawLine(Offset(-bar, 0), Offset(bar, 0), stroke);
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_PlusMinusPainter old) => old.ink != ink;
}

/// Eight short line rays thrown off the emoji as yours lands, alternating
/// long and short, flying out and shrinking as they fade.
class _BurstPainter extends CustomPainter {
  _BurstPainter({required this.color, required this.burst})
      : super(repaint: burst);

  final Color color;
  final Animation<double> burst;

  @override
  void paint(Canvas canvas, Size size) {
    final t = burst.value;
    if (t == 0 || t == 1) return;
    final e = Curves.easeOutCubic.transform(t);
    final c = size.center(Offset.zero);
    final stroke = Paint()
      ..color = color.withValues(alpha: color.a * (1 - t))
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.9
      ..strokeCap = StrokeCap.round;
    for (var i = 0; i < 8; i++) {
      final a = math.pi / 8 + i * math.pi / 4;
      final dir = Offset(math.cos(a), math.sin(a));
      final inner = 12 + 8 * e;
      final len = (i.isEven ? 6.0 : 3.5) * (1 - e);
      if (len < 0.3) continue;
      canvas.drawLine(c + dir * inner, c + dir * (inner + len), stroke);
    }
  }

  @override
  bool shouldRepaint(_BurstPainter old) => old.color != color;
}
