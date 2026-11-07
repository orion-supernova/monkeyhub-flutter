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
    this.forkAt = 128,
    this.unforkAt = 100,
    this.armAt = 48,
    this.disarmAt = 26,
    this.flickVelocity = 600,
    this.dwellMs = 180,
    this.maxForkSpeed = 1400,
    this.halvesArmTravel = 24,
  });

  /// Full-screen halves only: sideways travel since bloom, toward a side,
  /// before that side can arm the first time.
  final double halvesArmTravel;

  /// Upward travel that opens the fork. Deliberately far: 128pt is most of a
  /// thumb stroke, so a stray bounce at the end of the list never gets there.
  final double forkAt;

  /// Dropping under this collapses it again (hysteresis under [forkAt]).
  final double unforkAt;

  /// Sideways travel that arms a side, and the smaller one that disarms it.
  /// Mutable so the full-screen style can use its own dead zone around the
  /// screen's middle.
  double armAt;
  double disarmAt;

  /// Sideways speed (pt/s) past the line that arms a side on release.
  final double flickVelocity;

  /// The fork only opens after the pull has lasted this long ...
  final int dwellMs;

  /// ... and while the finger is moving slower than this (pt/s). A quick
  /// upward flick races past the line without ever opening it; the fork opens
  /// when the finger slows or rests there. Both gates apply only when the
  /// caller supplies timestamps to [update].
  final double maxForkSpeed;

  ForkPhase phase = ForkPhase.idle;

  /// The options, captured at touch-down and fixed for the whole gesture.
  ForkOption? left;
  ForkOption? right;

  /// The armed side, or null in the middle (the cancel target).
  ForkSide? armed;

  /// Upward travel since touch-down, raw (not rubber-banded).
  double dy = 0;

  /// Sideways travel from the anchor: the thumb's x at bloom, or the fixed
  /// [anchorX] (the screen's middle) in the full-screen style. Zero before the
  /// fork.
  double dx = 0;
  double _bloomX = 0;
  double? _anchorX;

  // Dwell bookkeeping.
  int? _startMs;
  int? _lastMs;
  double _lastDy = 0;
  double _speed = 0;

  bool get active => phase != ForkPhase.idle;

  /// Exactly one option: a single pull with no fork.
  bool get single => (left == null) != (right == null);

  /// Pull progress 0..1 up to the fork line.
  double get progress => (dy / forkAt).clamp(0.0, 1.0);

  /// Slide progress 0..1 toward [armAt], signed by side.
  double get slide => (dx.abs() / armAt).clamp(0.0, 1.0);

  /// [dx] over [armAt], -1..1 (negative = left). Continuous, for the visuals.
  double get slideSigned => (dx / armAt).clamp(-1.0, 1.0);

  /// Smoothed upward speed of the finger, pt/s (0 without timestamps).
  double get speed => _speed;

  /// Orb travel for [dy]: 1:1 up to the line, a rubber band past it.
  double get travel => rubber(dy);

  double rubber(double d) {
    if (d <= 0) return 0;
    return d < forkAt ? d : forkAt + (d - forkAt) * 0.35;
  }

  ForkOption? optionAt(ForkSide s) => s == ForkSide.left ? left : right;

  /// Starts a gesture with [options] (already placed on screen sides). With
  /// [anchorX] the sides are measured from that x instead of the thumb's x at
  /// bloom (the full-screen halves).
  void begin({ForkOption? left, ForkOption? right, double? anchorX}) {
    this.left = left;
    this.right = right;
    phase = ForkPhase.pull;
    armed = null;
    dy = 0;
    dx = 0;
    _bloomX = 0;
    _anchorX = anchorX;
    _startMs = null;
    _lastMs = null;
    _lastDy = 0;
    _speed = 0;
  }

  bool _settled(int? ms) {
    if (ms == null) return true;
    final start = _startMs ?? ms;
    return ms - start >= dwellMs && _speed <= maxForkSpeed;
  }

  void _sample(double up, int? ms) {
    if (ms == null) return;
    _startMs ??= ms;
    final last = _lastMs;
    if (last != null) {
      final dt = ms - last;
      if (dt > 0) {
        // Exponential smoothing; a call with no movement pulls it to rest.
        final inst = ((up - _lastDy) / dt * 1000).abs();
        final k = dt >= 24 ? 0.6 : 0.35;
        _speed = _speed * (1 - k) + inst * k;
      } else {
        return;
      }
    }
    _lastMs = ms;
    _lastDy = up;
  }

  /// Feeds the thumb: [up] is how far above the touch-down point it is
  /// (negative when below), [x] its horizontal position, [ms] a monotonic
  /// clock. Safe to call again with unchanged values (the owner's timer does,
  /// so a finger held at the line opens the fork once the dwell is over).
  List<ForkEvent> update(double up, double x, {int? ms}) {
    if (phase == ForkPhase.idle) return const [];
    final events = <ForkEvent>[];
    _sample(up, ms);
    dy = up;
    if (phase == ForkPhase.pull && up >= forkAt && _settled(ms)) {
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
      dx = x - (_anchorX ?? _bloomX);
      final a = armed;
      // Full-screen halves measure the side from the screen's middle, so a
      // thumb already resting off-centre would arm the moment the fork opens
      // and a plain pull-and-release would commit it: the accidental opens
      // this threshold exists to stop. The first arm also needs a deliberate
      // move toward that side since bloom.
      final towardSide = _anchorX == null ||
          (x - _bloomX) * dx.sign >= halvesArmTravel;
      if (a == null && dx.abs() >= armAt && towardSide) {
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

  /// The finger lifted at [vx] pt/s sideways. Resets the machine. Lifting an
  /// idle machine (a double lift, a lift after a reset) is just a cancel.
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

  /// Abandons the gesture (second finger, app backgrounded, pointer cancel).
  void reset() {
    phase = ForkPhase.idle;
    armed = null;
    dy = 0;
    dx = 0;
    _bloomX = 0;
    _anchorX = null;
    _startMs = null;
    _lastMs = null;
    _lastDy = 0;
    _speed = 0;
  }
}
