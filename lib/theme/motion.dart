import 'package:flutter/widgets.dart';

import '../data/settings_store.dart';

/// The app's resolved motion budget for one build.
///
/// This app had no reduce-motion path at all before the Feed board —
/// `MediaQuery.disableAnimations` appeared only in diagnostics telemetry. The
/// board is the first surface heavy enough to need one, so this establishes the
/// convention rather than following it. Three deliberate properties:
///
///  * **The user can override the OS in both directions.** Someone who enabled
///    Reduce Motion for a different app can still ask for the full board, and
///    someone the OS thinks is fine can still calm it. That is why
///    [SettingsStore.motionLevel] is nullable rather than a bool — see its doc.
///  * **Calm is a code path, not a shorter duration.** [d] collapses to
///    [Duration.zero] and callers are expected to check [calm] and simply *not
///    build* looping tickers, particle painters or parallax listeners. A
///    120ms version of a parallax field still moves the screen and still costs
///    the frames; it does not honour the request.
///  * **It never gates functional motion.** Scroll physics, sheet dismissal and
///    anything a gesture drives directly stay exactly as they are. Reduce Motion
///    means "stop decorating", not "stop responding".
@immutable
class MotionScope {
  const MotionScope._(this.calm);

  /// Whether decorative motion should be suppressed for this build.
  final bool calm;

  /// Resolves the stored override against the OS accessibility flag.
  ///
  /// Registers a dependency on `MediaQuery.disableAnimations`, so flipping the
  /// system setting rebuilds subscribers without any listener of our own. The
  /// [SettingsStore] half is read without listening on purpose: every screen
  /// that owns a motion preference already rebuilds on its `notifyListeners`,
  /// and adding a second path would double-rebuild the whole tree on an
  /// unrelated settings change.
  factory MotionScope.of(BuildContext context) {
    final override = SettingsStore.instance.motionLevel;
    if (override != null) return MotionScope._(override == MotionLevel.calm);
    return MotionScope._(MediaQuery.disableAnimationsOf(context));
  }

  /// Test seam. Prefer [MotionScope.of] in widgets.
  @visibleForTesting
  const MotionScope.forTest({required this.calm});

  /// [full] normally; zero under calm motion.
  ///
  /// Safe to hand straight to any implicit animation: Flutter treats a zero
  /// duration as "jump to the end value", which is exactly the intent.
  Duration d(Duration full) => calm ? Duration.zero : full;

  /// [full] normally; [Curves.linear] under calm motion.
  ///
  /// The curve still has to be *valid* even at zero duration, and several
  /// themes ship an overshooting `motionCurve` — feeding `easeOutBack` to a
  /// zero-duration opacity animation would still assert on the out-of-range
  /// value. Linear cannot.
  Curve c(Curve full) => calm ? Curves.linear : full;

  /// Staggered-entrance offset for item [i], in the house pattern where the
  /// stagger lives in the DURATION rather than in a delay.
  ///
  /// Collapses to a single zero duration under calm motion, so a 30-item list
  /// does not spend 30 × stride milliseconds arriving instantly in sequence.
  Duration stagger(Duration base, int i, {int strideMs = 60}) =>
      calm ? Duration.zero : base + Duration(milliseconds: i * strideMs);

  @override
  bool operator ==(Object other) =>
      other is MotionScope && other.calm == calm;

  @override
  int get hashCode => calm.hashCode;
}
