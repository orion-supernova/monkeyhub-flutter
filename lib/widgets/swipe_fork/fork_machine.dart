/// The swipe-up gesture's state machine. Pure Dart: no widgets, no haptics, no
/// animation. It is fed pointer positions and answers with what changed
/// ([ForkEvent]s); the controller turns those into springs and ticks.
///
/// The picture is the chat list's row swipe turned on its side: capsules grow
/// up out of the composer's edge as the finger pulls.
///
///  * under [openAt]: letting go snaps closed;
///  * [openAt] to [commitAt]: letting go settles OPEN, capsules stay for a tap;
///  * past [commitAt]: the capsule under the finger's half is armed, sliding
///    sideways re-arms the other, letting go fires the armed one. Dropping
///    back under `commitAt - hysteresis` disarms.
library;

import 'fork_options.dart';

/// Where the gesture is.
enum ForkPhase {
  /// Nothing on screen.
  idle,

  /// Finger down, below the commit line. May be short of [ForkMachine.openAt].
  pull,

  /// Let go between open and commit: the capsules wait for a tap.
  open,

  /// Finger down past the commit line with a capsule armed.
  armed,

  /// Let go on an armed capsule, or tapped one: the action is running.
  committing,
}

/// Which side an option sits on, in screen terms.
enum ForkSide { left, right }

/// Something the machine wants the outside world to react to.
enum ForkEvent {
  /// Crossed the open line going up: notch haptic.
  opened,

  /// Dropped back under the open line (with a little hysteresis).
  unopened,

  /// A capsule just armed (see [ForkMachine.armedSide]).
  armed,

  /// Dropped under the commit line: nothing armed any more.
  disarmed,

  /// Went straight from one armed capsule to the other.
  swapped,
}

/// What lifting the finger (or a tap) meant.
enum ForkResult { cancel, settleOpen, commit }

class ForkOutcome {
  const ForkOutcome.commit(this.option, this.side) : result = ForkResult.commit;
  const ForkOutcome.settle()
      : result = ForkResult.settleOpen,
        option = null,
        side = null;
  const ForkOutcome.cancel()
      : result = ForkResult.cancel,
        option = null,
        side = null;

  final ForkResult result;
  final ForkOption? option;
  final ForkSide? side;

  bool get committed => result == ForkResult.commit;
  bool get settled => result == ForkResult.settleOpen;
}

class ForkMachine {
  ForkMachine({
    this.openAt = 56,
    this.commitAt = 120,
    this.hysteresis = 16,
    this.unopenHysteresis = 8,
    this.band = 0.35,
  });

  /// Pull (pt) that a release settles open.
  final double openAt;

  /// Pull (pt) that arms a capsule.
  final double commitAt;

  /// Dropping this far under [commitAt] disarms.
  final double hysteresis;

  /// Dropping this far under [openAt] un-opens (so the notch does not chatter).
  final double unopenHysteresis;

  /// How much of the finger a pull past [commitAt] still shows (rubber band).
  final double band;

  ForkPhase phase = ForkPhase.idle;

  /// The options, captured at touch-down and fixed for the whole gesture.
  ForkOption? left;
  ForkOption? right;

  /// The x that divides the screen into the left and right halves.
  double midX = 0;

  /// The armed capsule, or null.
  ForkSide? armedSide;

  /// Upward travel since touch-down, raw (not rubber-banded).
  double dy = 0;

  bool _reached = false;

  bool get active => phase != ForkPhase.idle;

  /// Whether the finger is still down.
  bool get holding => phase == ForkPhase.pull || phase == ForkPhase.armed;

  /// Exactly one option: one wide capsule.
  bool get single => (left == null) != (right == null);

  /// Past the open line (what a release now would keep open).
  bool get reached => _reached;

  /// Pull progress 0..1 up to the commit line.
  double get progress => (dy / commitAt).clamp(0.0, 1.0);

  /// How tall the capsules are for [dy]: 1:1 with the finger up to the commit
  /// line, a rubber band past it.
  double get reveal => rubber(dy);

  double rubber(double d) {
    if (d <= 0) return 0;
    return d < commitAt ? d : commitAt + (d - commitAt) * band;
  }

  ForkOption? optionAt(ForkSide s) => s == ForkSide.left ? left : right;

  /// The side whose capsule is under [x]: the only one, when there is one.
  ForkSide sideAt(double x) {
    if (single) return left != null ? ForkSide.left : ForkSide.right;
    return x < midX ? ForkSide.left : ForkSide.right;
  }

  /// Starts a gesture with [options] (already placed on screen sides), the
  /// screen split at [midX].
  void begin({ForkOption? left, ForkOption? right, double midX = 0}) {
    this.left = left;
    this.right = right;
    this.midX = midX;
    phase = ForkPhase.pull;
    armedSide = null;
    dy = 0;
    _reached = false;
  }

  /// Feeds the finger: [up] is how far above the touch-down point it is
  /// (negative when below), [x] its horizontal position.
  List<ForkEvent> update(double up, double x) {
    if (!holding) return const [];
    final events = <ForkEvent>[];
    dy = up;
    if (!_reached && up >= openAt) {
      _reached = true;
      events.add(ForkEvent.opened);
    } else if (_reached && up < openAt - unopenHysteresis) {
      _reached = false;
      events.add(ForkEvent.unopened);
    }
    if (phase == ForkPhase.pull && up >= commitAt) {
      phase = ForkPhase.armed;
      armedSide = sideAt(x);
      events.add(ForkEvent.armed);
    } else if (phase == ForkPhase.armed) {
      if (up < commitAt - hysteresis) {
        phase = ForkPhase.pull;
        armedSide = null;
        events.add(ForkEvent.disarmed);
      } else {
        final side = sideAt(x);
        if (side != armedSide) {
          armedSide = side;
          events.add(ForkEvent.swapped);
        }
      }
    }
    return events;
  }

  /// The finger lifted. Armed: fires that capsule. Past the open line: settles
  /// open. Otherwise closes.
  ForkOutcome end() {
    switch (phase) {
      case ForkPhase.armed:
        final side = armedSide!;
        final option = optionAt(side)!;
        phase = ForkPhase.committing;
        return ForkOutcome.commit(option, side);
      case ForkPhase.pull:
        if (dy >= openAt) {
          phase = ForkPhase.open;
          return const ForkOutcome.settle();
        }
        reset();
        return const ForkOutcome.cancel();
      case ForkPhase.idle:
      case ForkPhase.open:
      case ForkPhase.committing:
        return const ForkOutcome.cancel();
    }
  }

  /// A tap on the capsule at [side] while settled open.
  ForkOutcome tap(ForkSide side) {
    final option = phase == ForkPhase.open ? optionAt(side) : null;
    if (option == null) return const ForkOutcome.cancel();
    phase = ForkPhase.committing;
    armedSide = side;
    return ForkOutcome.commit(option, side);
  }

  /// Abandons the gesture or closes the settled capsules.
  void reset() {
    phase = ForkPhase.idle;
    armedSide = null;
    dy = 0;
    _reached = false;
  }
}
