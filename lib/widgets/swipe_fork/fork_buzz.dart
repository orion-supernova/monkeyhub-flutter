import 'dart:async';

import '../haptic_tick.dart';

/// A continuous vibration for as long as the fork's finger is down.
///
/// The old feel was a stepper: one tick each time progress crossed a detent,
/// so a finger that stopped moving went quiet. This is a short-period train of
/// light impacts instead, a few dozen milliseconds apart, which the Taptic
/// Engine and Android motors blend into one buzz. It runs off a timer, not off
/// pointer moves, so it carries on while the finger is held still, and it is
/// stopped the instant the gesture ends (release, cancel, commit, dispose).
///
/// No native code: each pulse is the existing `monkeyhub/haptics` `tick`
/// (see [HapticTick]), whose intensity is the one thing that changes with the
/// gesture. [intensity] is asked for on every pulse and returns 0..1.
class ForkBuzz {
  ForkBuzz({
    required this.intensity,
    required this.tier,
    void Function(double intensity)? play,
    bool? capable,
  })  : _play = play ?? ((i) => HapticTick.play(i, tier: tier)),
        _capable = capable ?? HapticTick.continuousCapable;

  /// The strength right now, 0..1. Below [floor] nothing is played.
  final double Function() intensity;
  final HapticTier tier;
  final void Function(double) _play;
  final bool _capable;

  /// Quieter than this is not worth a pulse.
  static const double floor = 0.04;

  // ───────── the gesture's curve ─────────
  //
  // A light Taptic impact (and Android's LOW_TICK primitive) below ~0.3 is
  // below what a thumb can feel. The old pull curve, 0.1 + 0.35·p², sat under
  // that line until ~80% of the pull, so the buzz seemed to arrive only when
  // the pull was almost full. The pull now STARTS at the perceptible floor and
  // rises linearly (intensity is perceived roughly logarithmically, so linear
  // already reads as a steady swell), and every level after the fork line is
  // above the pull's end, so crossing it never feels like a drop.

  /// Where the pull starts: the first point of travel is already felt.
  static const double pullStart = 0.3;

  /// Where the pull ends, at the fork line.
  static const double pullEnd = 0.7;

  /// The fork is open with one option: steady, above the pull's end.
  static const double singleLevel = 0.8;

  /// A side is armed: the strongest the buzz gets.
  static const double armedLevel = 0.95;

  /// The pull, [p] 0..1 up to the fork line.
  static double pullLevel(double p) =>
      pullStart + (pullEnd - pullStart) * p.clamp(0.0, 1.0);

  /// The fork is open and the finger slides toward a side, [slide] 0..1.
  static double slideLevel(double slide) =>
      pullEnd + (armedLevel - 0.1 - pullEnd) * slide.clamp(0.0, 1.0);

  /// Gap between pulses. A thinned motor needs 40ms+ between one-shots.
  static const int periodMs = 28;
  static const int thinnedPeriodMs = 44;

  Timer? _timer;

  bool get running => _timer != null;

  /// Whether this tier and platform can buzz at all. Landmarks-only, silent,
  /// and desktop gestures keep just their notches.
  bool get allowed =>
      _capable && (tier == HapticTier.full || tier == HapticTier.thinned);

  /// Starts the beat. [onPulse] runs on every beat, buzzing or not: the owner
  /// uses it as its "finger is held still" clock. Calling again restarts
  /// cleanly.
  void start({void Function()? onPulse}) {
    stop();
    HapticTick.prepare();
    final ms = tier == HapticTier.thinned ? thinnedPeriodMs : periodMs;
    final buzz = allowed;
    _timer = Timer.periodic(Duration(milliseconds: ms), (_) {
      onPulse?.call();
      if (!buzz) return;
      final i = intensity();
      if (i >= floor) _play(i.clamp(0.0, 1.0));
    });
  }

  /// Silences it at once. Safe to call any time, any number of times.
  void stop() {
    _timer?.cancel();
    _timer = null;
  }
}
