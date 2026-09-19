import 'dart:math' as math;

import 'package:flutter/animation.dart';
import 'package:flutter/services.dart';

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
class HapticRamp {
  HapticRamp(this.progress, {this.taps = 12}) : assert(taps > 0) {
    progress.addListener(_onProgress);
  }

  final Animation<double> progress;

  /// How many taps a full charge plays, not counting the owner's final one.
  final int taps;

  /// The next tap still to play, so each one fires exactly once per hold.
  int _next = 0;

  void dispose() => progress.removeListener(_onProgress);

  /// Where along the hold tap [i] falls.
  ///
  /// The exponent below 1 is the ramp: the gaps shrink as the hold goes on.
  /// Over the send button's 270ms charge the first tap lands about 60ms in,
  /// and the gaps close from about 30ms to about 13ms, which is where separate
  /// taps blur into one buzz. At 60fps the last few play once a frame.
  double _at(int i) => math.pow((i + 1) / (taps + 1), 0.6).toDouble();

  void _onProgress() {
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
