import 'package:flutter/services.dart';

/// Every native platform channel the app shares between Dart files, declared
/// ONCE. Two files that each wrote `MethodChannel('monkeyhub/device')` were
/// two chances to typo a name and no way to see who else spoke on it.
///
/// A [MethodChannel] is a thin name wrapper, so referencing the same
/// constant from several files is free. What is NOT shared is the incoming
/// handler: a channel has exactly one `setMethodCallHandler` owner (the last
/// writer wins), so the owner is named next to each channel below. Everything
/// else may only `invokeMethod`.
///
/// Method names and arguments live with the file that calls them; this file
/// only owns the channel names.
abstract final class Channels {
  /// Device facts and OS permissions: call/capture permission prompts,
  /// Android call reliability, device identity, low-power mode, the device
  /// report and storage stats.
  static const device = MethodChannel('monkeyhub/device');

  /// CallKit / ConnectionService / PushKit bridge and call audio routing.
  /// Incoming handler owner: `PushManager` (PushKit token and cancel events).
  static const voip = MethodChannel('monkeyhub/voip');

  /// Haptic engine access (iOS recording haptics, macOS bridge, tick pulses).
  static const haptics = MethodChannel('monkeyhub/haptics');

  /// Store / installer introspection (release channel, Apple store lookup).
  static const installer = MethodChannel('monkeyhub/installer');

  /// The detached call window on desktop (audio device list and window state).
  static const callWindow = MethodChannel('monkeyhub/call_window');

  /// Linux native window chrome and notifier bridge. Incoming handler owner: `LinuxAppChrome`.
  static const window = MethodChannel('monkeyhub/window');

  /// Share-sheet targets and the share extension's intake. Incoming handler owner: `ShareIntake`.
  static const share = MethodChannel('monkeyhub/share');
}
