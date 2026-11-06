import 'package:flutter/foundation.dart';

/// The ONE place that says whether the app may vibrate at all.
///
/// Fed by `SettingsStore` (the "Haptics" switch). Read by exactly two hooks:
/// `HapticMessenger` in `AppBinding`, which sees every `HapticFeedback.*` call
/// and the macOS trackpad path, and `HapticTick`, whose native-channel pulses
/// bypass that messenger. Call sites never check it themselves.
///
/// Starts enabled, so anything that fires before settings have loaded behaves
/// as it always did.
abstract final class Haptics {
  static bool enabled = true;

  /// Test seam: back to the default.
  @visibleForTesting
  static void resetForTest() => enabled = true;
}
