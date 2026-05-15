import 'package:flutter/cupertino.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';

import '../theme/theme_scope.dart';

/// Wraps a chat bubble with a right-only "pull to reply" gesture.
///
/// The child translates horizontally with rubber-band resistance as the user
/// drags right. A small reply-arrow icon fades and scales in from the left
/// edge. Once the cumulative pull crosses [_kThreshold], a medium haptic
/// fires once and [onReplyTriggered] is invoked on release. Releasing before
/// threshold snaps back without triggering.
///
/// Right-only and universal across sender/receiver bubbles — matches the
/// dominant reply gesture pattern. The gesture ignores drags whose start
/// point lies within 24px of the screen-left edge so it doesn't fight the
/// iOS system back-swipe.
class SwipeToReply extends StatefulWidget {
  const SwipeToReply({
    super.key,
    required this.child,
    required this.onReplyTriggered,
    this.enabled = true,
  });

  final Widget child;
  final VoidCallback onReplyTriggered;
  final bool enabled;

  @override
  State<SwipeToReply> createState() => _SwipeToReplyState();
}

class _SwipeToReplyState extends State<SwipeToReply>
    with SingleTickerProviderStateMixin {
  static const double _kThreshold = 64.0;
  // After release we snap back via this controller (220ms easeOutCubic =
  // theme.motionFast). During the drag, we use _drag directly (animation
  // value disabled).
  late final AnimationController _snap;
  double _drag = 0;
  bool _crossed = false;
  bool _dragging = false;

  @override
  void initState() {
    super.initState();
    _snap = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 220),
    )..addListener(() {
        // _snap.value runs 0..1; we map it back to a fading drag.
        setState(() => _drag = _startDrag * (1 - _snap.value));
      });
  }

  double _startDrag = 0;

  @override
  void dispose() {
    _snap.dispose();
    super.dispose();
  }

  double _rubberBand(double pulled, double width) {
    // Soft cap: as the user pulls harder, the on-screen offset grows more
    // slowly. The 2.5x denominator gives a comfortable "elastic" feel
    // without ever exceeding ~width/3 in practice.
    if (pulled <= 0) return 0;
    return pulled * (1 - pulled / (width * 2.5)).clamp(0.0, 1.0);
  }

  void _onStart(DragStartDetails d) {
    // Avoid stealing the iOS edge-back gesture: ignore drags whose origin
    // is within the leftmost 24 logical px of the screen.
    if (d.globalPosition.dx < 24) {
      _dragging = false;
      return;
    }
    _dragging = true;
    _crossed = false;
    _snap.stop();
    _drag = 0;
  }

  void _onUpdate(DragUpdateDetails d) {
    if (!_dragging) return;
    final dx = d.primaryDelta ?? 0;
    final next = (_drag + dx).clamp(0.0, double.infinity);
    if (next == _drag) return;
    if (!_crossed && next >= _kThreshold) {
      _crossed = true;
      HapticFeedback.mediumImpact();
    } else if (_crossed && next < _kThreshold) {
      _crossed = false;
    }
    setState(() => _drag = next);
  }

  void _onEnd(DragEndDetails d) {
    if (!_dragging) return;
    _dragging = false;
    if (_crossed) {
      // Trigger AFTER the snap-back so the user sees the bubble slide home
      // before the reply card slides in — the staged feel reads as cause →
      // effect rather than a simultaneous jump.
      _startDrag = _drag;
      _snap.forward(from: 0).whenComplete(() {
        if (!mounted) return;
        widget.onReplyTriggered();
      });
    } else {
      _startDrag = _drag;
      _snap.forward(from: 0);
    }
  }

  void _onCancel() {
    if (!_dragging) return;
    _dragging = false;
    _startDrag = _drag;
    _snap.forward(from: 0);
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.enabled) return widget.child;
    final theme = ThemeScope.of(context);
    final screenWidth = MediaQuery.sizeOf(context).width;
    final displayedX = _rubberBand(_drag, screenWidth);
    final reveal = (_drag / _kThreshold).clamp(0.0, 1.0);

    return Stack(
      clipBehavior: Clip.none,
      children: [
        // Reveal arrow on the left edge — slides into view as the bubble
        // translates right. Sized to a comfortable thumb target so the user
        // perceives "this is the action" rather than a passive decoration.
        Positioned(
          left: 4,
          top: 0,
          bottom: 0,
          child: IgnorePointer(
            child: Center(
              child: Opacity(
                opacity: reveal,
                child: Transform.scale(
                  scale: 0.6 + 0.4 * reveal,
                  child: Container(
                    width: 36,
                    height: 36,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: theme.accentSoft,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: theme.accent.withValues(alpha: 0.5 * reveal),
                        width: 1,
                      ),
                    ),
                    child: Icon(
                      CupertinoIcons.arrowshape_turn_up_left,
                      size: 18,
                      color: theme.accent,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
        // The bubble itself, translated right by the rubber-banded distance.
        // Uses RawGestureDetector with a tuned recognizer so it competes
        // properly with the ListView's vertical drag (drag-start = down so
        // we win short horizontal motions outright).
        Transform.translate(
          offset: Offset(displayedX, 0),
          child: RawGestureDetector(
            behavior: HitTestBehavior.translucent,
            gestures: {
              _HorizontalRightDragRecognizer:
                  GestureRecognizerFactoryWithHandlers<
                      _HorizontalRightDragRecognizer>(
                () => _HorizontalRightDragRecognizer(),
                (instance) {
                  instance
                    ..dragStartBehavior = DragStartBehavior.down
                    ..onStart = _onStart
                    ..onUpdate = _onUpdate
                    ..onEnd = _onEnd
                    ..onCancel = _onCancel;
                },
              ),
            },
            child: widget.child,
          ),
        ),
      ],
    );
  }
}

/// Horizontal drag recognizer that rejects net-leftward gestures. Letting
/// the framework's standard [HorizontalDragGestureRecognizer] see leftward
/// drags would let them claim the arena, blocking valid right swipes that
/// started with a small jitter.
class _HorizontalRightDragRecognizer extends HorizontalDragGestureRecognizer {
  double _accum = 0;
  bool _bailed = false;

  @override
  void addAllowedPointer(PointerDownEvent event) {
    _accum = 0;
    _bailed = false;
    super.addAllowedPointer(event);
  }

  @override
  void handleEvent(PointerEvent event) {
    if (_bailed) return;
    if (event is PointerMoveEvent) {
      _accum += event.delta.dx;
      if (_accum < -8) {
        // Net-leftward motion — bail out so vertical scroll / other
        // gestures can claim the arena cleanly. `resolve(rejected)` resets
        // the underlying drag state to `ready`, so any follow-up event
        // would assert in `DragGestureRecognizer.handleEvent` — short-circuit
        // here to prevent that.
        _bailed = true;
        resolve(GestureDisposition.rejected);
        return;
      }
    }
    super.handleEvent(event);
  }
}
