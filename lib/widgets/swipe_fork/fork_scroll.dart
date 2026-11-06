import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';

import '../swipe_fork.dart';

/// Turns the transcript's own drag into the fork's pull.
///
/// The fork is not a gesture of its own, it is what the newest end of the list
/// does with a finger that keeps going. So there is no recognizer in the arena
/// to steal a scroll: the list's physics hands every user drag offset to
/// [userOffset] first. While the list can still scroll, the offset passes
/// through untouched. From the moment the list hits its bottom edge, the finger
/// travel beyond it is the pull (measured from that point), and the physics is
/// told to apply nothing, so the content moves exactly once, through
/// [ForkLift], whether the platform bounces (iOS) or clamps (Android).
///
/// Only a finger drag reaches here: a fling coasting to the bottom is a
/// ballistic simulation, never a user offset, so it cannot arm the fork.
/// Pulling back down past the start gives the rest of that same drag back to
/// the list.
class ForkPull {
  ForkPull(this._c);

  final SwipeForkController _c;

  int? _primary;
  final Set<int> _down = {};
  Offset _pos = Offset.zero;
  VelocityTracker? _velocity;

  /// The gates said no (or a second finger came): nothing more this drag.
  bool _dead = false;
  bool _pulling = false;
  bool _suppress = false;
  double _pull = 0;
  Offset _downPos = Offset.zero;
  bool _firstSeen = false;
  double _slop = 0;

  /// Points past the list's end, while the fork owns the drag.
  double get distance => _pulling ? _pull : 0;
  bool get pulling => _pulling;

  /// The drag that just ended was (partly) the fork's: the list must not
  /// coast or bounce on its own velocity.
  bool get suppressBallistic => _suppress;

  // ───────── pointers (a passive Listener: it never joins the arena) ─────────

  void pointerDown(PointerDownEvent e) {
    _down.add(e.pointer);
    if (_primary != null) {
      // A second finger: no commit, whatever state we are in.
      _dead = true;
      _abort();
      return;
    }
    _primary = e.pointer;
    _pos = e.position;
    _downPos = e.position;
    _firstSeen = false;
    _slop = 0;
    _dead = false;
    _pulling = false;
    _suppress = false;
    _pull = 0;
    _velocity = VelocityTracker.withKind(e.kind)
      ..addPosition(e.timeStamp, e.position);
  }

  void pointerMove(PointerMoveEvent e) {
    if (e.pointer != _primary) return;
    _pos = e.position;
    _velocity?.addPosition(e.timeStamp, e.position);
    // Sideways (and the finger's height) between two list offsets.
    if (_pulling) _c.move(_pull, _pos);
  }

  void pointerUp(PointerUpEvent e) {
    _lift(e.pointer, cancel: false);
  }

  void pointerCancel(PointerCancelEvent e) {
    _lift(e.pointer, cancel: true);
  }

  void _lift(int pointer, {required bool cancel}) {
    _down.remove(pointer);
    if (pointer != _primary) return;
    final vx = _velocity?.getVelocity().pixelsPerSecond.dx ?? 0;
    final was = _pulling;
    _pulling = false;
    _pull = 0;
    _velocity = null;
    if (_down.isEmpty) _primary = null;
    if (!was) return;
    if (cancel || _dead) {
      _c.cancelGesture();
    } else {
      _c.release(vx);
    }
  }

  void _abort() {
    if (!_pulling) return;
    _pulling = false;
    _pull = 0;
    _c.cancelGesture();
  }

  /// The app left the foreground, or the host went away.
  void reset() {
    _dead = true;
    _abort();
  }

  // ───────── the list's offsets ─────────

  /// Looks at one drag step of the transcript. [offset] is in the units of
  /// `ScrollPhysics.applyPhysicsToUserOffset`: positive moves the list toward
  /// its start, which for the reversed transcript is toward the newest message.
  /// Returns what the list may still apply.
  double userOffset(ScrollMetrics m, double offset) {
    if (m.axisDirection != AxisDirection.up || offset == 0) return offset;
    if (!_firstSeen) {
      // The list eats its touch slop before its first step; a drag that sets
      // off toward the newest message counts it, so the pull measures the
      // finger's whole travel past the end (as the old recognizer did).
      _firstSeen = true;
      if (offset > 0) _slop = (_downPos.dy - _pos.dy - offset).clamp(0.0, 30.0);
    }
    if (_pulling) {
      final next = _pull + offset;
      if (next > 0) {
        _pull = next;
        _c.move(_pull, _pos);
        return 0;
      }
      // Back down past where it began: the rest of this drag is the list's.
      _pulling = false;
      _pull = 0;
      _suppress = false;
      _c.cancelGesture();
      return next;
    }
    if (_dead || offset < 0 || _primary == null) return offset;
    // How much list is left before the edge. An already-overscrolled list is
    // somebody else's bounce; the fork only starts from the edge itself.
    final room = m.pixels - m.minScrollExtent;
    if (room < -0.5) return offset;
    final spare = room < 0.5 ? 0.0 : room;
    if (offset <= spare) return offset;
    if (_c.busy) return offset;
    if (!_c.prepare(_pos)) {
      _dead = true;
      return offset;
    }
    _c.start();
    _pulling = true;
    _suppress = true;
    _pull = offset - spare + _slop;
    _slop = 0;
    _c.move(_pull, _pos);
    return spare;
  }
}

/// The transcript's physics with [ForkPull] in front of it. Mounted by
/// [SwipeForkGesture] over whatever the platform would have used, so bounce or
/// clamp, fling and friction all stay exactly as they were.
class ForkScrollPhysics extends ScrollPhysics {
  const ForkScrollPhysics({required this.controller, super.parent});

  final SwipeForkController controller;

  @override
  ForkScrollPhysics applyTo(ScrollPhysics? ancestor) =>
      ForkScrollPhysics(controller: controller, parent: buildParent(ancestor));

  bool _transcript(ScrollMetrics m) => m.axisDirection == AxisDirection.up;

  /// A short transcript still takes the drag: the pull works in a room with
  /// two messages in it.
  @override
  bool shouldAcceptUserOffset(ScrollMetrics position) =>
      _transcript(position) || super.shouldAcceptUserOffset(position);

  @override
  double applyPhysicsToUserOffset(ScrollMetrics position, double offset) {
    final rest = controller.pull.userOffset(position, offset);
    // The platform physics asserts on an empty step; the fork took it all.
    return rest == 0 ? 0 : super.applyPhysicsToUserOffset(position, rest);
  }

  @override
  Simulation? createBallisticSimulation(
      ScrollMetrics position, double velocity) {
    if (_transcript(position) && controller.pull.suppressBallistic) return null;
    return super.createBallisticSimulation(position, velocity);
  }
}
