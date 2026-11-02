import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart' show kIsWeb, visibleForTesting;
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';

import '../theme/theme_scope.dart';
import 'message_hover_actions.dart';

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

  /// Forgets the shared wheel-gesture state, for tests whose clock stamps every
  /// event the same instant and so never lets it expire on its own.
  @visibleForTesting
  static void resetWheelGesture() => _SwipeToReplyState._resetWheel();

  /// Browser wheel swipes only exist on web; a test flips this to exercise them.
  @visibleForTesting
  static bool wheelEnabled = kIsWeb;

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
    )
      ..addListener(() {
        // _snap.value runs 0..1; we map it back to a fading drag.
        setState(() => _drag = _startDrag * (1 - _snap.value));
      })
      ..addStatusListener((status) {
        // Home: the bubble is where a fresh hover will measure it.
        if (status == AnimationStatus.completed) _releaseHover();
      });
  }

  /// The desktop hover strip, held off while this bubble is out of place. See
  /// [MessageHoverController.hold].
  MessageHoverController? _heldHover;

  void _holdHover() {
    if (_heldHover != null) return;
    final c = MessageHoverScope.maybeOf(context);
    if (c == null) return;
    _heldHover = c..hold();
  }

  void _releaseHover() {
    _heldHover?.release();
    _heldHover = null;
  }

  double _startDrag = 0;

  @override
  void dispose() {
    _scrollIdle?.cancel();
    _releaseHover();
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
    _holdHover();
  }

  void _onUpdate(DragUpdateDetails d) {
    if (!_dragging) return;
    // Measured toward the end edge, so `_drag` counts up the same way in both
    // scripts and everything downstream of it stays direction-agnostic.
    _pull((d.primaryDelta ?? 0) * _sign);
  }

  /// Moves the pull by [dx] (already measured toward the end edge), firing the
  /// threshold haptic on the way across.
  void _pull(double dx) {
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

  // ── Browser trackpad ────────────────────────────────────────────────────
  // A two-finger swipe in a browser is a stream of wheel events, not a
  // pointer drag, so the recognizer never sees it and the browser takes it as
  // history navigation. Claiming the event through the resolver is what tells
  // the engine not to hand it back to the browser.

  Timer? _scrollIdle;
  // Set once a wheel pull has committed: the momentum tail that follows the
  // lift must not start a second pull.
  bool _scrollSpent = false;
  // The axis the current wheel gesture settled on, decided once from its first
  // few pixels and kept until the stream goes quiet. A vertical scroll always
  // carries a little sideways drift, and judging each event alone slid the
  // bubble under the user's finger on every scroll through the transcript.
  //
  // STATIC, because a gesture belongs to the finger and not to a bubble: as a
  // scroll carries the list past a stationary pointer, every bubble that
  // arrives under it would otherwise open its own probe in the middle of the
  // momentum tail, where the leftover deltas are tiny and mostly noise, and
  // judge them sideways.
  static bool? _gestureHorizontal;
  static double _probeX = 0;
  static double _probeY = 0;
  static Duration _lastWheel = Duration.zero;
  static const Duration _wheelGap = Duration(milliseconds: 150);

  static void _resetWheel() {
    _gestureHorizontal = null;
    _probeX = 0;
    _probeY = 0;
    _lastWheel = Duration.zero;
  }

  void _onSignal(PointerSignalEvent e) {
    if (e is! PointerScrollEvent) return;
    final d = e.scrollDelta;
    _scrollIdle?.cancel();
    _scrollIdle = Timer(_wheelGap, _endScroll);
    final since = e.timeStamp - _lastWheel;
    // A negative gap is a clock that restarted: a new gesture as well.
    if (since > _wheelGap || since.isNegative) {
      _gestureHorizontal = null;
      _probeX = 0;
      _probeY = 0;
    }
    _lastWheel = e.timeStamp;
    if (_gestureHorizontal == null) {
      _probeX += d.dx.abs();
      _probeY += d.dy.abs();
      if (_probeX + _probeY < 8) return;
      // Clearly sideways, not merely sideways-ish.
      _gestureHorizontal = _probeX > _probeY * 2.5;
    }
    if (_gestureHorizontal != true) return;
    GestureBinding.instance.pointerSignalResolver.register(e, (event) {
      final ev = event as PointerScrollEvent;
      if (_scrollSpent) return;
      if (!_dragging) {
        _dragging = true;
        _crossed = false;
        _snap.stop();
        _drag = 0;
        _holdHover();
      }
      // Fingers moving right arrive as a negative deltaX.
      // Capped per event: a fast flick arrives as one enormous delta, and the
      // pull would otherwise jump hundreds of pixels in a single frame before
      // the commit below even runs.
      _pull((-ev.scrollDelta.dx * _sign).clamp(-_kThreshold, _kThreshold * 1.25));
      if (_crossed) {
        // No lift event exists here, and the momentum tail would keep the pull
        // open for another second. Reaching the threshold is the commit.
        _scrollSpent = true;
        _crossed = false;
        _settle();
        widget.onReplyTriggered();
      }
    });
  }

  void _endScroll() {
    _scrollSpent = false;
    if (!mounted) return;
    _crossed = false;
    _settle();
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
    if (crossed) {
      // The threshold armed it; the lift is the commit, and is felt too.
      HapticFeedback.lightImpact();
      widget.onReplyTriggered();
    }
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
    // A phone-sized width at most: on a desktop window the full width made the
    // rubber band effectively linear and let a bubble travel most of the way
    // across the chat.
    final screenWidth = math.min(MediaQuery.sizeOf(context).width, 430.0);
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
            onPointerSignal: SwipeToReply.wheelEnabled ? _onSignal : null,
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
