import 'dart:math' as math;

import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart';
import 'package:flutter/physics.dart' show SpringDescription, SpringSimulation;
import 'package:flutter/semantics.dart' show CustomSemanticsAction;
import 'package:flutter/services.dart';

import '../../calls/widgets/call_chrome.dart' show kCallAcceptGreen;
import '../../theme/motion.dart';
import '../../theme/theme_scope.dart';

/// A call row you can throw sideways: toward the end edge for a voice call
/// back, toward the start edge for a video call back (right and left in LTR).
///
/// It follows the reply swipe's rules (`swipe_to_reply.dart`): the row
/// travels with rubber-band resistance, a haptic detent lands the moment the
/// pull is far enough to count ("armed"), and nothing happens until the finger
/// lets go. Release armed and the call starts while the row springs home with
/// a little overshoot; release early and it just returns.
///
/// Rows never stay open (unlike `ChatRowSwipe`'s buttons): the gesture is a
/// shortcut, and the tap and the hold menu remain the explicit routes. Both
/// actions are also exposed as screen-reader custom actions.
class CallSwipeRow extends StatefulWidget {
  const CallSwipeRow({
    super.key,
    required this.child,
    required this.onVoice,
    required this.onVideo,
    required this.voiceLabel,
    required this.videoLabel,
  });

  final Widget child;
  final VoidCallback onVoice;
  final VoidCallback onVideo;
  final String voiceLabel;
  final String videoLabel;

  /// How far the row must travel to arm.
  static const double armAt = 76;

  @override
  State<CallSwipeRow> createState() => _CallSwipeRowState();
}

class _CallSwipeRowState extends State<CallSwipeRow>
    with SingleTickerProviderStateMixin {
  late final AnimationController _settle = AnimationController.unbounded(
    vsync: this,
  )..addListener(_onSettle);

  /// Finger travel, unclamped; [_dx] is what the row shows.
  double _pull = 0;
  double _dx = 0;
  bool _armed = false;
  bool _dragging = false;

  double get _sign =>
      Directionality.of(context) == TextDirection.rtl ? -1.0 : 1.0;

  void _onSettle() {
    setState(() => _dx = _settle.value);
  }

  @override
  void dispose() {
    _settle.dispose();
    super.dispose();
  }

  /// Resistance past the arm point, so the row never runs away from the
  /// finger but keeps moving.
  static double _band(double pull) {
    final a = pull.abs();
    const arm = CallSwipeRow.armAt;
    if (a <= arm) return pull;
    return pull.sign * (arm + (a - arm) * 0.32);
  }

  void _onStart(DragStartDetails d) {
    _settle.stop();
    _dragging = true;
    _pull = _dx;
  }

  void _onUpdate(DragUpdateDetails d) {
    if (!_dragging) return;
    _pull += d.primaryDelta ?? 0;
    final next = _band(_pull);
    final armed = next.abs() >= CallSwipeRow.armAt - 0.5;
    if (armed && !_armed) {
      HapticFeedback.mediumImpact();
    } else if (!armed && _armed) {
      HapticFeedback.selectionClick();
    }
    _armed = armed;
    setState(() => _dx = next);
  }

  void _onEnd(DragEndDetails d) {
    if (!_dragging) return;
    _dragging = false;
    final commit = _armed;
    final eff = _dx * _sign;
    _armed = false;
    _springHome(velocity: d.primaryVelocity ?? 0, bouncy: commit);
    if (commit) {
      HapticFeedback.lightImpact();
      // After the release, never before: the call screen takes over the
      // window, and the row should already be on its way home.
      if (eff > 0) {
        widget.onVoice();
      } else {
        widget.onVideo();
      }
    }
  }

  void _springHome({required double velocity, required bool bouncy}) {
    if (_dx == 0) return;
    if (MotionScope.of(context).calm) {
      _settle.stop();
      setState(() => _dx = 0);
      return;
    }
    _settle.value = _dx;
    // A committed throw rebounds like jelly; a cancelled one is just
    // critically damped.
    final spring = SpringDescription(
      mass: 1,
      stiffness: 420,
      damping: bouncy ? 15 : 36,
    );
    _settle
        .animateWith(SpringSimulation(spring, _dx, 0, velocity))
        .then((_) {
      if (!mounted) return;
      _settle.stop();
      setState(() => _dx = 0);
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final sign = _sign;
    final eff = _dx * sign;
    final progress = (eff.abs() / CallSwipeRow.armAt).clamp(0.0, 1.0);
    final voice = eff > 0;
    final disc = voice ? kCallAcceptGreen : theme.accent;
    final glyph = voice ? CupertinoIcons.phone_fill : CupertinoIcons.videocam_fill;
    final onInk = voice ? Colors.white : theme.accentInk;
    return Semantics(
      customSemanticsActions: {
        CustomSemanticsAction(label: widget.voiceLabel): widget.onVoice,
        CustomSemanticsAction(label: widget.videoLabel): widget.onVideo,
      },
      child: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onHorizontalDragStart: _onStart,
        onHorizontalDragUpdate: _onUpdate,
        onHorizontalDragEnd: _onEnd,
        onHorizontalDragCancel: () {
          if (!_dragging) return;
          _dragging = false;
          _armed = false;
          _springHome(velocity: 0, bouncy: false);
        },
        child: Stack(
          children: [
            if (_dx != 0)
              Positioned.fill(
                child: IgnorePointer(
                  child: Align(
                    // The disc sits on the side the row left uncovered.
                    alignment: _dx > 0
                        ? AlignmentDirectional.centerStart
                        : AlignmentDirectional.centerEnd,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 22),
                      child: Opacity(
                        opacity: math.min(1, progress * 1.4),
                        child: Transform.scale(
                          scale: 0.4 + 0.6 * progress,
                          child: TweenAnimationBuilder<double>(
                            tween: Tween(end: _armed ? 1.18 : 1.0),
                            duration: const Duration(milliseconds: 260),
                            curve: Curves.elasticOut,
                            builder: (_, pop, child) =>
                                Transform.scale(scale: pop, child: child),
                            child: Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                color: disc.withValues(
                                  alpha: _armed ? 1 : 0.55,
                                ),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(glyph, size: 20, color: onInk),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            Transform.translate(offset: Offset(_dx, 0), child: widget.child),
          ],
        ),
      ),
    );
  }
}
