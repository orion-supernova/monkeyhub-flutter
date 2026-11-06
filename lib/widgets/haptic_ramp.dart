import 'dart:math' as math;

import 'package:flutter/animation.dart';
import 'package:flutter/services.dart';

import 'haptic_tick.dart';

/// A vibration that builds for as long as a hold is charging.
///
/// Flutter's haptics are single taps. There is no sustained vibration short of
/// a native plugin, and the old `HapticFeedback.vibrate()` is iOS's flat
/// half-second system buzz, which cannot follow a gesture that may be let go at
/// any moment. A run of taps close enough together reads as one continuous
/// rumble, though, on the Taptic Engine and on Android's vibrator alike. So
/// this fires taps along [progress]: sparse and soft as it leaves zero, closer
/// together and firmer toward the end, the way the hold ring fills.
///
/// Driven by the SAME animation the ring is, not a timer of its own. That is
/// what keeps the two in step and makes a let-go silent at once: the ring snaps
/// to zero, and so does this. It also inherits the ring's lead-in, so an
/// ordinary tap never buzzes, and a hold that is not animated at all (calm
/// motion) stays silent, just as the ring stays hidden.
///
/// The ramp stops just short of the end on purpose. The moment the hold
/// completes belongs to whoever owns the gesture, which lands one heavier impact
/// on top so "it went" feels different from "still going".
///
/// # Two-way mode
///
/// [HapticRamp.twoWay] is the same ramp for a gesture that can be pulled AND
/// released gradually (the swipe-up fork's pull, its sideways slide). Same
/// detent spacing, with these differences:
///
///  * A detent fires when crossed in EITHER direction. Strength follows the
///    detent's position, not the direction: the way back down plays each
///    detent at its own, lower, strength, so retreating feels like the tension
///    letting go.
///  * Strength is an intensity (0..1) from [minIntensity] to [maxIntensity],
///    played through [HapticTick] (or handed to [onTick]), not one of
///    [HapticFeedback]'s four steps.
///  * Still at most ONE tick per frame: when a frame crosses several detents
///    the strongest plays, once.
///  * A value of exactly 0 is a silent reset, as in one-way mode. Letting go
///    snaps the value to 0, and that must not play a tick.
///  * The [HapticTier] decides how much of this is allowed (see
///    [beginGesture]).
class HapticRamp {
  HapticRamp(this.progress, {this.taps = 12})
      : assert(taps > 0),
        twoWay = false,
        minIntensity = 0,
        maxIntensity = 1,
        onTick = null,
        _tier = null,
        _clockMs = null,
        _prev = progress.value {
    progress.addListener(_onProgress);
  }

  /// The two-way ramp: see the class comment. [minIntensity] and
  /// [maxIntensity] are the strengths of the first and last detent (the
  /// design's pull ramp is 0.15 to 0.75, the slide's 0.2 to 0.7).
  ///
  /// [onTick] replaces the default [HapticTick.play], for a caller that wants
  /// to mirror each tick (a debug meter, a visual pulse). [tier] pins the tier;
  /// leave it null to have [beginGesture] (or the first tick) decide.
  HapticRamp.twoWay(
    this.progress, {
    this.taps = 12,
    this.minIntensity = 0.15,
    this.maxIntensity = 0.75,
    this.onTick,
    HapticTier? tier,
    int Function()? clockMs,
  })  : assert(taps > 0),
        twoWay = true,
        _tier = tier,
        _clockMs = clockMs,
        _prev = progress.value {
    progress.addListener(_onProgress);
  }

  final Animation<double> progress;

  /// How many taps a full charge plays, not counting the owner's final one.
  final int taps;

  /// Whether detents fire when crossed in either direction.
  final bool twoWay;

  /// Intensity of the first and last detent in two-way mode.
  final double minIntensity;
  final double maxIntensity;

  /// Receives each two-way tick's intensity instead of [HapticTick.play].
  final void Function(double intensity)? onTick;

  /// Decided once per gesture; null until [beginGesture] or the first tick.
  HapticTier? _tier;

  /// Where the progress was on the previous frame, for crossing detection.
  double _prev;

  /// A clock for the thinned tier's minimum gap; [_clockMs] is a test seam.
  final Stopwatch _clock = Stopwatch()..start();
  final int Function()? _clockMs;
  int _lastTickMs = -1;

  int _nowMs() => _clockMs?.call() ?? _clock.elapsedMilliseconds;

  /// The tier this gesture plays at.
  HapticTier get tier => _tier ??= HapticTick.current();

  /// Call on touch-down in two-way mode: decides the [HapticTier] for this
  /// gesture ONCE (so nothing is re-checked per tick) and warms the haptic
  /// generator so the first tick has no lag. Pass [tier] to pin it.
  void beginGesture({HapticTier? tier}) {
    _tier = tier ?? HapticTick.current();
    _prev = progress.value;
    _lastTickMs = -1;
    HapticTick.prepare();
  }

  /// How many detents the current tier plays.
  int get detents => tier == HapticTier.thinned ? HapticTick.thinnedDetents : taps;

  /// Where along the ramp detent [i] of [n] falls: `((i+1)/(n+1))^0.6`.
  static double detentAt(int i, int n) =>
      math.pow((i + 1) / (n + 1), 0.6).toDouble();

  /// The intensity of detent [i] of [n] in two-way mode.
  double intensityOf(int i, int n) =>
      n <= 1 ? maxIntensity : minIntensity + (maxIntensity - minIntensity) * (i / (n - 1));

  /// The next tap still to play, so each one fires exactly once per hold.
  int _next = 0;

  void dispose() => progress.removeListener(_onProgress);

  /// Where along the hold tap [i] falls.
  ///
  /// The exponent below 1 is the ramp: the gaps shrink as the hold goes on.
  /// Over the send button's 270ms charge the first tap lands about 60ms in,
  /// and the gaps close from about 30ms to about 13ms, which is where separate
  /// taps blur into one buzz. At 60fps the last few play once a frame.
  double _at(int i) => detentAt(i, taps);

  void _onProgress() {
    if (twoWay) {
      _onTwoWay();
      return;
    }
    final value = progress.value;
    if (value == 0) {
      _next = 0;
      return;
    }
    // One tap per frame at most, even when a slow frame skips past several
    // marks. Two in the same frame land as one, only harder.
    if (_next >= taps || value < _at(_next)) return;
    while (_next < taps && value >= _at(_next)) {
      _next++;
    }
    _tap(_next / taps);
  }

  void _onTwoWay() {
    final value = progress.value;
    final prev = _prev;
    _prev = value;
    // Letting go snaps to zero: a silent reset, never a tick on the way down.
    if (value == 0 || value == prev) return;
    final tier = this.tier;
    if (tier == HapticTier.silent || tier == HapticTier.landmarks) return;
    final n = detents;
    final lo = math.min(prev, value);
    final hi = math.max(prev, value);
    // The strongest detent this frame crossed, in either direction: positions
    // ascend, so scanning down finds it first.
    var strongest = -1;
    for (var i = n - 1; i >= 0; i--) {
      final at = detentAt(i, n);
      if (at > lo && at <= hi) {
        strongest = i;
        break;
      }
    }
    if (strongest < 0) return;
    final now = _nowMs();
    if (tier == HapticTier.thinned &&
        _lastTickMs >= 0 &&
        now - _lastTickMs < HapticTick.thinnedGapMs) {
      return;
    }
    _lastTickMs = now;
    final intensity = intensityOf(strongest, n);
    final sink = onTick;
    if (sink != null) {
      sink(intensity);
    } else {
      HapticTick.play(intensity, tier: tier);
    }
  }

  /// Soft to firm across the charge. Nothing here reaches `heavyImpact`,
  /// which is the owner's to play when the hold completes.
  static void _tap(double through) {
    if (through <= 1 / 3) {
      HapticFeedback.selectionClick();
    } else if (through <= 2 / 3) {
      HapticFeedback.lightImpact();
    } else {
      HapticFeedback.mediumImpact();
    }
  }
}
