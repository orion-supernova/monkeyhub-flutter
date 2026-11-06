/// The swipe-up fork's gesture state machine. Pure Dart: no widgets, no
/// haptics, no animation. It is fed pointer positions and answers with what
/// changed ([ForkEvent]s); the controller turns those into springs and ticks.
///
/// Behaviour follows the reference prototype at the bottom of
/// docs/design/swipe-up-fork.html.
library;

import 'fork_options.dart';

/// Where the fork's thumb is.
enum ForkPhase {
  /// Nothing in progress.
  idle,

  /// Below the fork line: orb rising, ring filling.
  pull,

  /// Past the line: chips are out (or, with one option, the orb is armed).
  fork,
}

/// Which side an option sits on, in screen terms.
enum ForkSide { left, right }

/// Something the machine wants the outside world to react to.
enum ForkEvent {
  /// Crossed the fork line going up: notch haptic, bloom the chips.
  forked,

  /// Dropped under the un-fork line: collapse the chips.
  unforked,

  /// A side just armed (see [ForkMachine.armed]).
  armed,

  /// Left the armed side into the middle: soft tick.
  disarmed,

  /// Went straight from one armed side to the other.
  swapped,
}

/// How a gesture ended.
class ForkOutcome {
  const ForkOutcome.commit(this.option, this.side) : committed = true;
  const ForkOutcome.cancel()
      : committed = false,
        option = null,
        side = null;

  final bool committed;
  final ForkOption? option;
  final ForkSide? side;
}

class ForkMachine {
  ForkMachine({
    this.forkAt = 96,
    this.unforkAt = 72,
    this.armAt = 40,
    this.disarmAt = 22,
    this.flickVelocity = 600,
  });

  final double forkAt;
  final double unforkAt;
  final double armAt;
  final double disarmAt;

  /// Sideways speed (pt/s) past the line that arms a side on release.
  final double flickVelocity;

  ForkPhase phase = ForkPhase.idle;

  /// The options, captured at touch-down and fixed for the whole gesture.
  ForkOption? left;
  ForkOption? right;

  /// The armed side, or null in the middle (the cancel target).
  ForkSide? armed;

  /// Upward travel since touch-down, raw (not rubber-banded).
  double dy = 0;

  /// Sideways travel from the thumb's x at bloom. Zero before the fork.
  double dx = 0;
  double _bloomX = 0;

  bool get active => phase != ForkPhase.idle;

  /// Exactly one option: a single pull with no fork.
  bool get single => (left == null) != (right == null);

  /// Pull progress 0..1 up to the fork line.
  double get progress => (dy / forkAt).clamp(0.0, 1.0);

  /// Slide progress 0..1 toward [armAt], signed by side.
  double get slide => (dx.abs() / armAt).clamp(0.0, 1.0);

  /// Orb travel for [dy]: 1:1 up to the line, a rubber band past it.
  double get travel => rubber(dy);

  double rubber(double d) {
    if (d <= 0) return 0;
    return d < forkAt ? d : forkAt + (d - forkAt) * 0.35;
  }

  ForkOption? optionAt(ForkSide s) => s == ForkSide.left ? left : right;

  /// Starts a gesture with [options] (already placed on screen sides).
  void begin({ForkOption? left, ForkOption? right}) {
    this.left = left;
    this.right = right;
    phase = ForkPhase.pull;
    armed = null;
    dy = 0;
    dx = 0;
    _bloomX = 0;
  }

  /// Feeds the thumb: [up] is how far above the touch-down point it is
  /// (negative when below), [x] its horizontal position.
  List<ForkEvent> update(double up, double x) {
    if (phase == ForkPhase.idle) return const [];
    final events = <ForkEvent>[];
    dy = up;
    if (phase == ForkPhase.pull && up >= forkAt) {
      phase = ForkPhase.fork;
      _bloomX = x;
      dx = 0;
      events.add(ForkEvent.forked);
    } else if (phase == ForkPhase.fork && up < unforkAt) {
      phase = ForkPhase.pull;
      armed = null;
      dx = 0;
      events.add(ForkEvent.unforked);
    }
    if (phase == ForkPhase.fork && !single) {
      dx = x - _bloomX;
      final a = armed;
      if (a == null && dx.abs() >= armAt) {
        armed = dx < 0 ? ForkSide.left : ForkSide.right;
        events.add(ForkEvent.armed);
      } else if (a != null && dx.abs() < disarmAt) {
        armed = null;
        events.add(ForkEvent.disarmed);
      } else if (a == ForkSide.left && dx >= armAt) {
        armed = ForkSide.right;
        events.add(ForkEvent.swapped);
      } else if (a == ForkSide.right && dx <= -armAt) {
        armed = ForkSide.left;
        events.add(ForkEvent.swapped);
      }
    }
    return events;
  }

  /// The finger lifted at [vx] pt/s sideways. Resets the machine.
  ForkOutcome end(double vx) {
    final wasFork = phase == ForkPhase.fork;
    ForkSide? pick = armed;
    if (wasFork && pick == null && !single && vx.abs() > flickVelocity) {
      pick = vx < 0 ? ForkSide.left : ForkSide.right;
    }
    if (wasFork && single) pick = left != null ? ForkSide.left : ForkSide.right;
    final option = pick == null ? null : optionAt(pick);
    reset();
    return option == null
        ? const ForkOutcome.cancel()
        : ForkOutcome.commit(option, pick);
  }

  /// Abandons the gesture (second finger, app backgrounded).
  void reset() {
    phase = ForkPhase.idle;
    armed = null;
    dy = 0;
    dx = 0;
    _bloomX = 0;
  }
}
