import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';

import '../theme/theme_scope.dart';

/// Wraps a chat bubble with a right-only "pull to reply" gesture.
///
/// The child translates horizontally with rubber-band resistance as the user
/// drags right. A small reply-arrow icon fades and scales in from the left
/// edge. Once the cumulative pull crosses [_kThreshold], a medium haptic
/// fires once; [onReplyTriggered] is then invoked the instant the finger
/// lifts, while the bubble springs home in parallel. Releasing before
/// threshold snaps back without triggering.
///
/// Universal across sender/receiver bubbles — matches the dominant reply
/// gesture pattern. The pull runs toward the END edge: right under LTR, left
/// under RTL, where the whole layout is mirrored and a rightward pull would
/// read backwards. `swipe_to_receipts.dart` takes the START edge, which is how
/// the two share a bubble without sharing a direction in either script.
///
/// The gesture ignores drags whose start point lies within 24px of the edge
/// the platform's own back-swipe comes from, so it doesn't fight it.
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

  /// Which way the pull runs: +1 toward the right, -1 toward the left. The end
  /// edge in this script, which is the direction a reply is dragged.
  double get _sign =>
      Directionality.of(context) == TextDirection.rtl ? -1.0 : 1.0;

  void _onStart(DragStartDetails d) {
    // Avoid stealing the platform edge-back gesture: ignore drags whose origin
    // is within 24 logical px of the edge it starts from — the left of the
    // screen under LTR, the right under RTL, where the system mirrors it too.
    final fromLeft = d.globalPosition.dx;
    final edge = _sign > 0
        ? fromLeft
        : MediaQuery.sizeOf(context).width - fromLeft;
    if (edge < 24) {
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
    // Measured toward the end edge, so `_drag` counts up the same way in both
    // scripts and everything downstream of it stays direction-agnostic.
    final dx = (d.primaryDelta ?? 0) * _sign;
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

  /// The single path back to rest. Returns whether this call was the one that
  /// ended an in-flight drag (so only the real end fires the reply).
  bool _settle() {
    if (!_dragging) return false;
    _dragging = false;
    _startDrag = _drag;
    _snap.forward(from: 0);
    return true;
  }

  void _onEnd(DragEndDetails d) {
    final crossed = _crossed;
    _crossed = false;
    if (!_settle()) return;
    // Fire at finger-lift, not after the snap-back. The medium haptic at the
    // threshold already told the user the gesture committed, so the composer
    // has to start moving on that same beat — waiting for the bubble to slide
    // home first reads as lag, not as cause → effect. The snap runs in
    // parallel with the reply card and keyboard.
    if (crossed) widget.onReplyTriggered();
  }

  void _onCancel() {
    _crossed = false;
    _settle();
  }

  /// Safety net. [_onEnd]/[_onCancel] depend on the gesture arena delivering a
  /// terminal callback; if that ever fails to arrive the bubble would stay
  /// parked off-centre with no animation pending and no way to recover. The
  /// pointer sequence itself is the one thing we can always observe, so we
  /// settle from it too. GestureBinding reuses the down-event hit test for the
  /// rest of the sequence, so this fires even when the finger drifts off the
  /// bubble before lifting.
  ///
  /// Deferred to a microtask because the render tree's [Listener] callbacks are
  /// dispatched *before* [GestureBinding] routes the same event to the
  /// recognizers — settling synchronously here would clear `_dragging` and make
  /// the real [_onEnd] no-op away the reply. By the time the microtask runs the
  /// whole dispatch (including the arena sweep) is done, so this only ever
  /// catches the case where nothing else settled.
  void _onPointerRelease(PointerEvent _) {
    if (!_dragging) return;
    scheduleMicrotask(() {
      if (!mounted) return;
      _crossed = false;
      _settle();
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.enabled) return widget.child;
    final theme = ThemeScope.of(context);
    final direction = Directionality.of(context);
    final sign = direction == TextDirection.rtl ? -1.0 : 1.0;
    final screenWidth = MediaQuery.sizeOf(context).width;
    final displayedX = _rubberBand(_drag, screenWidth) * sign;
    final reveal = (_drag / _kThreshold).clamp(0.0, 1.0);

    return Stack(
      clipBehavior: Clip.none,
      children: [
        // Reveal arrow on the start edge — slides into view as the bubble
        // translates away from it. Sized to a comfortable thumb target so the
        // user perceives "this is the action" rather than a passive decoration.
        Positioned.directional(
          textDirection: direction,
          start: 4,
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
                      direction == TextDirection.rtl
                          ? CupertinoIcons.arrowshape_turn_up_right
                          : CupertinoIcons.arrowshape_turn_up_left,
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
          child: Listener(
            behavior: HitTestBehavior.translucent,
            onPointerUp: _onPointerRelease,
            onPointerCancel: _onPointerRelease,
            child: RawGestureDetector(
            behavior: HitTestBehavior.translucent,
            gestures: {
              _HorizontalRightDragRecognizer:
                  GestureRecognizerFactoryWithHandlers<
                      _HorizontalRightDragRecognizer>(
                () => _HorizontalRightDragRecognizer(),
                (instance) {
                  instance
                    ..sign = sign
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
        ),
      ],
    );
  }
}

/// Horizontal drag recognizer that rejects gestures running net-AGAINST the
/// reply pull. Letting the framework's standard
/// [HorizontalDragGestureRecognizer] see those would let them claim the arena,
/// blocking valid reply swipes that started with a small jitter — and, since
/// `swipe_to_receipts.dart` puts its own recognizer in the same arena on an
/// outgoing bubble, blocking the receipts pull outright.
class _HorizontalRightDragRecognizer extends HorizontalDragGestureRecognizer {
  /// Which way the reply pull runs: +1 rightward (LTR), -1 leftward (RTL).
  double sign = 1;

  double _accum = 0;
  bool _bailed = false;
  bool _won = false;

  @override
  void addAllowedPointer(PointerDownEvent event) {
    _accum = 0;
    _bailed = false;
    _won = false;
    super.addAllowedPointer(event);
  }

  @override
  void acceptGesture(int pointer) {
    _won = true;
    super.acceptGesture(pointer);
  }

  @override
  void handleEvent(PointerEvent event) {
    // Once bailed the arena really did reject us and the drag state is back to
    // `ready`; forwarding anything would assert in `DragGestureRecognizer`.
    if (_bailed) return;
    // Only bail before we've won the arena. Afterwards our arena entry is gone
    // and `resolve(rejected)` is a documented no-op ("This arena has already
    // resolved"), so `rejectGesture` never runs — bailing there would swallow
    // the PointerUp that is the *only* source of `onEnd`, leaving the bubble
    // parked off-screen forever with no snap-back pending.
    if (!_won && event is PointerMoveEvent) {
      _accum += event.delta.dx;
      if (_accum * sign < -8) {
        // Net motion against the pull — bail out so vertical scroll, the
        // receipts pull, or another gesture can claim the arena cleanly.
        _bailed = true;
        resolve(GestureDisposition.rejected);
        return;
      }
    }
    super.handleEvent(event);
  }
}
