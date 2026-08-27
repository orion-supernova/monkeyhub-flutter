import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/cupertino.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';

/// Wraps one of YOUR OWN chat bubbles with a "pull the receipts in" gesture.
///
/// The opposite hand to `swipe_to_reply.dart`, and deliberately a different
/// KIND of gesture. Reply is a spring: the bubble bends under the thumb, an
/// arrow arms, and the action fires at finger-lift. This one is a page. It
/// starts sliding in from the trailing edge as soon as the drag is recognised
/// and tracks the finger one-to-one from there — nothing waits for the lift to
/// *begin*, which is the whole point: the screen is something you are pulling,
/// not something you asked for. Releasing past [_kCommitFraction], or flicking
/// at all, carries it the rest of the way and lands it as a real route;
/// releasing short takes it away again and leaves no trace in the history.
///
/// The drag runs toward the START edge (left in LTR, right in RTL) — the
/// mirror of the reply pull, and the direction that matches the page coming
/// from the other side. That is what keeps the two gestures out of each
/// other's way on an outgoing bubble in both scripts. See
/// [_HorizontalDirectionalDragRecognizer].
///
/// ── Why the page is dragged in an overlay and pushed only at the end ───────
///
/// Because a route CANNOT be pushed mid-drag. [NavigatorState] cancels every
/// pointer it is tracking after any navigation — `_cancelActivePointers`,
/// carrying a `far from perfect` comment and a decade-old bug link — and a
/// cancelled pointer's later moves are dropped by [GestureBinding] outright,
/// because the hit-test path they would have been dispatched along is gone
/// with it. Push at drag start and the finger is dead on the very next frame,
/// with the page parked wherever the first update left it. Cupertino's back
/// gesture never hits this: the route it drives is already on the stack, so it
/// navigates at the END of the drag, not the start.
///
/// So the drag drives an [OverlayEntry] holding the identical
/// [CupertinoPageTransition] the route will use, and the route is pushed on
/// release, pre-wound to the fraction the finger left it at. The entry is
/// dropped in the same beat, so the two never render at once: the frame that
/// loses the preview is the frame that gains the route, at the same offset,
/// with the same geometry. A cancelled pull touches the navigator not at all.
class SwipeToReceipts extends StatefulWidget {
  const SwipeToReceipts({
    super.key,
    required this.child,
    required this.pageBuilder,
    this.enabled = true,
  });

  final Widget child;

  /// Builds the screen being dragged in. Called once per gesture — a cancelled
  /// drag builds it and throws it away, which is the price of having the real
  /// thing on screen before the user has committed to it.
  final WidgetBuilder pageBuilder;

  final bool enabled;

  @override
  State<SwipeToReceipts> createState() => _SwipeToReceiptsState();
}

/// How far in the page has to be when the finger lifts for the push to stand.
/// Well under half, because arriving should be easier than turning back — the
/// user reached for this, and the flick path below catches the rest.
const double _kCommitFraction = 0.26;

/// A flick at least this fast decides the gesture on its own, whatever
/// distance it covered. Fractions of the page's width per second, the same
/// unit (and the same number) Cupertino's back gesture uses.
const double _kMinFlingVelocity = 1.0;

/// Floor under a settle animation's speed, so a release at rest still snaps
/// home rather than crawling there.
const double _kSettleVelocity = 2.4;

class _SwipeToReceiptsState extends State<SwipeToReceipts>
    with SingleTickerProviderStateMixin {
  /// The fraction of the page on screen, 0 (off the trailing edge) to 1.
  /// Driven by the finger, then by a fling.
  late final AnimationController _slide;

  /// The page as it is dragged, before there is a route to hold it.
  OverlayEntry? _peek;

  /// Held for the length of the gesture, so it survives this widget being
  /// disposed under the finger.
  NavigatorState? _nav;

  /// Whether [_nav] is still owed a `didStopUserGesture`. Exactly one, ever.
  bool _holdingGesture = false;

  /// The width the page travels across — the navigator's, not the display's.
  double _width = 1;

  /// Distance travelled toward the start edge since the drag was recognised,
  /// in logical pixels. Never negative: pulling back past the origin parks the
  /// page at the edge rather than pushing it off the other side.
  double _travelled = 0;

  bool _dragging = false;

  /// Whether letting go right now would keep the page. Latched, so the haptic
  /// fires on the crossing rather than on every frame past it.
  bool _armed = false;

  /// +1 when the start edge is to the RIGHT of the screen.
  double get _sign =>
      Directionality.of(context) == TextDirection.rtl ? 1.0 : -1.0;

  @override
  void initState() {
    super.initState();
    // Duration is unused while the finger is down — `value` is set directly —
    // and only shapes `fling`'s spring on the way home.
    _slide = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
  }

  @override
  void dispose() {
    // A row can go while the finger is still on it: scrolled past the list's
    // cache extent, or deleted under the thumb. The preview and the
    // navigator's user gesture both outlive this widget, and neither is this
    // widget's to leak — but there is no controller left to animate anything
    // home with, so the preview goes at once rather than gracefully.
    _dragging = false;
    _dropPeek();
    _releaseGesture();
    _slide.dispose();
    super.dispose();
  }

  void _releaseGesture() {
    if (!_holdingGesture) return;
    _holdingGesture = false;
    final nav = _nav;
    _nav = null;
    if (nav != null && nav.mounted) nav.didStopUserGesture();
  }

  void _dropPeek() {
    _peek?.remove();
    _peek = null;
  }

  void _onStart(DragStartDetails _) {
    if (!widget.enabled || _dragging) return;
    final nav = Navigator.of(context);
    // Two bubbles, two fingers, two previews — and a navigator whose
    // user-gesture count only ever comes back down once. One pull at a time,
    // and the one already holding the navigator wins.
    if (nav.userGestureInProgress) return;
    final overlay = Overlay.of(context);

    // The page slides across the NAVIGATOR, which in a two-pane desktop window
    // is the detail pane and not the display. Measuring the wrong one leaves
    // the finger and the page disagreeing by the width of the sidebar.
    final box = nav.context.findRenderObject();
    _width = box is RenderBox && box.hasSize && box.size.width > 0
        ? box.size.width
        : MediaQuery.sizeOf(context).width;

    _nav = nav;
    _dragging = true;
    _travelled = 0;
    _armed = false;
    _slide.value = 0;

    // Claimed for the whole gesture INCLUDING the settle, and read by
    // `CupertinoRouteTransitionMixin` as "this slide is being driven by hand,
    // do not curve it". A curve over a finger-driven value is exactly what
    // makes an interactive transition feel like it is arguing with the thumb,
    // and — once the route is pushed — it is also what would make the handover
    // jump: the preview and the route agree on where the page is only while
    // both are linear. Released at the far end, where linear and curved meet.
    _holdingGesture = true;
    nav.didStartUserGesture();

    // Built once and held, so the sixty rebuilds a drag causes are sixty
    // rebuilds of a transition and not sixty rebuilds of a screen.
    final page = Builder(builder: widget.pageBuilder);
    _peek = OverlayEntry(
      builder: (context) => IgnorePointer(
        // Nothing on a page that is still being dragged is meant to be
        // pressed, and a second finger reaching it would be pressing
        // something with no route under it.
        child: CupertinoPageTransition(
          primaryRouteAnimation: _slide,
          secondaryRouteAnimation: kAlwaysDismissedAnimation,
          linearTransition: true,
          child: page,
        ),
      ),
    );
    overlay.insert(_peek!);
  }

  void _onUpdate(DragUpdateDetails d) {
    if (!_dragging) return;
    _travelled = math.max(0, _travelled + (d.primaryDelta ?? 0) * _sign);
    _slide.value = (_travelled / _width).clamp(0.0, 1.0);
    final armed = _slide.value >= _kCommitFraction;
    if (armed == _armed) return;
    _armed = armed;
    // Only on the way IN. A pull that falls back below the line has already
    // said so on screen, and a second tick there reads as a malfunction.
    if (armed) HapticFeedback.selectionClick();
  }

  void _onEnd(DragEndDetails d) => _settle((d.primaryVelocity ?? 0) * _sign);

  void _onCancel() => _settle(0);

  /// The single path out of a drag, whichever way it ends.
  void _settle(double pixelsPerSecond) {
    if (!_dragging) return;
    _dragging = false;
    _armed = false;

    final v = pixelsPerSecond / _width;
    // A flick decides on its own; anything slower is decided by how far in the
    // page already is.
    final commit = v.abs() >= _kMinFlingVelocity
        ? v > 0
        : _slide.value >= _kCommitFraction;
    final speed = math.max(v.abs(), _kSettleVelocity);

    if (commit) {
      _land(speed);
    } else {
      _slide.fling(velocity: -speed);
      _slide.addStatusListener(_onWithdrawn);
    }
  }

  void _onWithdrawn(AnimationStatus status) {
    if (!status.isDismissed) return;
    _slide.removeStatusListener(_onWithdrawn);
    // Nothing was ever pushed, so a pull the user thought better of leaves the
    // history — and every route observer watching it — untouched.
    _dropPeek();
    _releaseGesture();
  }

  /// Hands the dragged page over to a real route and lets go of the preview in
  /// the same beat.
  void _land(double speed) {
    final nav = _nav;
    if (nav == null || !nav.mounted) {
      _dropPeek();
      _releaseGesture();
      return;
    }
    final route = MessageReceiptsRoute<void>(
      builder: widget.pageBuilder,
      startAt: _slide.value,
      flingVelocity: speed,
    );
    nav.push(route);
    // Dropped now, not on the next frame: both the push and this are marked
    // between frames, so the one frame that renders next has the route in it
    // and the preview out of it, at the same offset and under the same
    // transition. Holding the preview for a frame "to be safe" is what would
    // show a seam — two live copies of a screen whose images and animations
    // are at different points.
    _dropPeek();

    final controller = route.transitionController;
    if (controller == null) {
      _releaseGesture();
      return;
    }
    // `fling` leaves the controller running, so the listener below is what
    // normally ends the gesture. The terminal check is for the push that had
    // nowhere left to travel — a drag that reached the far edge before the
    // finger lifted — where no status change is coming and the navigator would
    // otherwise be left holding a gesture nobody is making.
    if (controller.isCompleted || controller.isDismissed) {
      _releaseGesture();
      return;
    }
    void arrived(AnimationStatus status) {
      if (!status.isCompleted && !status.isDismissed) return;
      controller.removeStatusListener(arrived);
      _releaseGesture();
    }

    controller.addStatusListener(arrived);
  }

  /// Safety net, for the same reason `SwipeToReply` carries one: [_onEnd] and
  /// [_onCancel] both rely on the gesture arena delivering a terminal
  /// callback, and a page left half-dragged with no animation pending is a
  /// dead end the user cannot get out of. The pointer sequence is the one
  /// thing we can always observe.
  ///
  /// Deferred to a microtask because [Listener] callbacks run BEFORE
  /// [GestureBinding] routes the same event to the recognisers — settling
  /// synchronously here would clear `_dragging` and no-op the real [_onEnd]
  /// away, throwing every committed pull back off the screen.
  void _onPointerRelease(PointerEvent _) {
    if (!_dragging) return;
    scheduleMicrotask(() {
      if (!mounted || !_dragging) return;
      _settle(0);
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.enabled) return widget.child;
    // No Transform and no reveal layer, deliberately: the bubble itself does
    // not move at all — what moves is a whole page over the top of it. So
    // there is nothing to paint here, and a transcript full of these pays for
    // one gesture detector per row and not one more repaint boundary.
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerUp: _onPointerRelease,
      onPointerCancel: _onPointerRelease,
      child: RawGestureDetector(
        behavior: HitTestBehavior.translucent,
        gestures: {
          _HorizontalDirectionalDragRecognizer:
              GestureRecognizerFactoryWithHandlers<
                  _HorizontalDirectionalDragRecognizer>(
            () => _HorizontalDirectionalDragRecognizer(),
            (instance) {
              instance
                ..sign = _sign
                // Same as the reply pull: claim from the pointer-down position
                // so a short horizontal motion beats the transcript's vertical
                // drag outright instead of arriving 18px late.
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
    );
  }
}

/// The route a dragged-in page lands on.
///
/// A [CupertinoPageRoute] for the three things that are all easy to get subtly
/// wrong by hand: the trailing-edge slide mirrors correctly under RTL, the
/// page carries the standard edge shadow, and the finished screen gets the
/// back-swipe for free. [SwipeToReceipts] renders the identical transition in
/// its preview, so the frame the route takes over is the frame the preview
/// leaves and neither moves.
class MessageReceiptsRoute<T> extends CupertinoPageRoute<T> {
  MessageReceiptsRoute({
    required super.builder,
    this.startAt = 0,
    this.flingVelocity = 0,
  });

  /// How far in the page already was when the finger let go of it. Zero for an
  /// ordinary push, which then behaves exactly like any other Cupertino one.
  final double startAt;

  /// The speed the finger left at, in fractions of the page per second.
  final double flingVelocity;

  /// The transition's controller, `@protected` on [TransitionRoute] for
  /// everyone who is not this route. Winding it by hand is what this subclass
  /// exists for.
  AnimationController? get transitionController => controller;

  /// The page underneath does NOT slide out under this one.
  ///
  /// Cupertino's parallax is a fine thing on a tapped push, and wrong here: the
  /// drag that brings this page in cannot move the transcript with it — a
  /// preview lives in the overlay, above every route — so the parallax could
  /// only start at the moment of release, jumping the room a fifth of a screen
  /// sideways on the frame the finger lifts. Refusing it outright is what
  /// makes the dragged half and the flung half look like one movement.
  @override
  bool canTransitionFrom(TransitionRoute<dynamic> previousRoute) => false;

  @override
  TickerFuture didPush() {
    final pushed = super.didPush();
    final c = controller;
    // `TransitionRoute.didPush` starts the entrance from zero. This one is
    // already most of the way in, and picks up at the speed it was let go at.
    if (c != null && startAt > 0) {
      c.value = startAt;
      c.fling(velocity: math.max(flingVelocity, _kSettleVelocity));
    }
    return pushed;
  }
}

/// Horizontal drag recognizer that bails out of the arena as soon as the
/// gesture commits to the wrong direction.
///
/// The twin of `swipe_to_reply.dart`'s recognizer, and they share an arena on
/// every outgoing bubble: reply pulls toward the end edge, receipts pull
/// toward the start edge, and each gives up within the first few pixels of the
/// other's direction. Bailing that early — well before either has travelled
/// far enough to claim the arena — is what stops one from blocking the other,
/// and what keeps both out of the way of the transcript's vertical scroll.
class _HorizontalDirectionalDragRecognizer
    extends HorizontalDragGestureRecognizer {
  /// Which way this recognizer wants to go: +1 rightward, -1 leftward. Set
  /// from [Directionality] on every build.
  double sign = -1;

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
    // `ready`; forwarding anything would assert inside `DragGestureRecognizer`.
    if (_bailed) return;
    // Only bail before winning. Afterwards our arena entry is gone and
    // `resolve(rejected)` is a documented no-op, so `rejectGesture` never runs
    // — bailing there would swallow the PointerUp that is the ONLY source of
    // `onEnd`, and the page would be left parked mid-screen.
    if (!_won && event is PointerMoveEvent) {
      _accum += event.delta.dx;
      if (_accum * sign < -8) {
        _bailed = true;
        resolve(GestureDisposition.rejected);
        return;
      }
    }
    super.handleEvent(event);
  }
}
