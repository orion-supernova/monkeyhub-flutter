import 'dart:math' as math;

/// A retargetable damped spring, integrated a frame at a time.
///
/// Flutter already ships [SpringSimulation], but a simulation is a *closed
/// form from fixed initial conditions*: to aim it somewhere else you throw it
/// away and build another one, and the new one starts from the old one's
/// position with whatever velocity you remembered to copy across. That is
/// exactly the case this class exists for — a nav indicator is retargeted
/// mid-flight all the time (tap another tab while it is still travelling, drag
/// it under a finger that never stops moving), and every retarget that drops
/// the velocity reads as a stutter.
///
/// So: no simulation objects, no controllers. One mutable value, one velocity,
/// one target you may move whenever you like. [tick] it once per frame with the
/// real elapsed time and read [value].
///
/// Tuned in *designer* units rather than physics ones. [response] is roughly
/// how long the spring takes to cover the distance (the period of the
/// undamped oscillation, in seconds) and [ratio] is the damping ratio: 1.0 is
/// critically damped (fast, no overshoot), below 1.0 overshoots and settles
/// back, and around 0.7–0.8 is the gentle single overshoot that reads as
/// "fluid" rather than "springy". These are the same two numbers SwiftUI's
/// `Spring(response:dampingRatio:)` takes, so a value copied off an Apple
/// design note lands here unchanged.
class Spring {
  Spring({required double response, required double ratio, double value = 0})
    : assert(response > 0),
      assert(ratio > 0),
      _response = response,
      _ratio = ratio,
      _value = value,
      _target = value;

  double _response;
  double _ratio;
  double _value;
  double _target;

  /// Current position. Only [tick], [retarget] and [snap] move it.
  double get value => _value;

  /// Where [value] is heading.
  double get target => _target;

  /// Signed units per second. Exposed because motion that reacts to its own
  /// speed — a pill that stretches along its direction of travel — needs it,
  /// and re-deriving it from successive values loses a frame.
  double get velocity => _velocity;
  double _velocity = 0;

  /// Aim somewhere new *without* disturbing [value] or [velocity], optionally
  /// swapping the tuning at the same time.
  ///
  /// Changing the tuning mid-flight is the point of the optional arguments: the
  /// same spring tracks a finger with a stiff, near-critical setting and then
  /// settles onto a segment with a looser, overshooting one, and the handover
  /// is seamless because the state carries over.
  void retarget(double target, {double? response, double? ratio}) {
    assert(response == null || response > 0);
    assert(ratio == null || ratio > 0);
    _target = target;
    if (response != null) _response = response;
    if (ratio != null) _ratio = ratio;
  }

  /// Teleport: no motion, no velocity. For the first layout, and for
  /// reduce-motion, where the end state is the only state.
  void snap(double target) {
    _target = target;
    _value = target;
    _velocity = 0;
  }

  /// Whether [tick] would still do anything visible.
  ///
  /// A damped spring approaches its target asymptotically and never formally
  /// arrives, so "at rest" is a tolerance. These are tuned for values measured
  /// in *segment indices* and in 0..1 scale amounts — a few thousandths of
  /// either is well under a pixel.
  bool get atRest => (_target - _value).abs() < 0.002 && _velocity.abs() < 0.02;

  /// Advance by [dt] seconds.
  ///
  /// Sub-stepped at a fixed interval rather than integrating [dt] in one go.
  /// Semi-implicit Euler is only conditionally stable — a stiff spring plus a
  /// long frame diverges instead of settling — and long frames are not
  /// hypothetical: a jank spike gives one, and `pumpAndSettle` gives 100ms
  /// every frame, which would otherwise make every widget test of a spring
  /// explode rather than settle.
  void tick(double dt) {
    if (atRest) {
      _value = _target;
      _velocity = 0;
      return;
    }
    final omega = 2 * math.pi / _response;
    final stiffness = omega * omega;
    final damping = 2 * _ratio * omega;
    // Beyond this, catching up is pointless: the app was not on screen, or the
    // frame was so late that arriving instantly is the honest result.
    var remaining = math.min(dt, 0.25);
    const step = 1 / 480;
    while (remaining > 0) {
      final h = remaining < step ? remaining : step;
      final acceleration = stiffness * (_target - _value) - damping * _velocity;
      _velocity += acceleration * h;
      _value += _velocity * h;
      remaining -= h;
    }
    if (atRest) {
      _value = _target;
      _velocity = 0;
    }
  }
}
