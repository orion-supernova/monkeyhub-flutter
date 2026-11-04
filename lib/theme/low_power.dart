import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../data/settings_store.dart';

/// Whether the phone is in Low Power Mode (iOS) or Battery Saver (Android), or
/// its battery is low ([kLowBatteryPercent] or less, not charging).
///
/// When it is, the app stops decorating: [LowPowerCalm] turns on
/// `MediaQuery.disableAnimations` for the whole tree, which every
/// [MotionScope] and every `disableAnimationsOf` check already honours. The
/// user keeps the last word: an explicit Motion choice in Settings wins over
/// this, exactly as it wins over the OS Reduce Motion flag.
///
/// Both OSes announce every change to the power mode and the battery, and
/// `monkeyhub/power` passes each one on, so this follows them as they happen.
/// [refresh] still reads it directly at launch and on every resume, in case the
/// stream is not up yet or missed something while the app was suspended.
class LowPowerMode extends ValueNotifier<bool> {
  LowPowerMode._() : super(false);

  static final LowPowerMode instance = LowPowerMode._();

  /// Whether the app should be calm for power right now: the user's
  /// [PowerSaving] choice, with Automatic following the phone.
  ///
  /// An explicit Motion choice outranks it: someone who pinned Full motion
  /// gets it, power saving or not (and Calm needs no help from here).
  static bool get active =>
      SettingsStore.instance.motionLevel == null &&
      switch (SettingsStore.instance.powerSaving) {
        PowerSaving.on => true,
        PowerSaving.off => false,
        PowerSaving.auto => instance.value,
      };

  static const MethodChannel _device = MethodChannel('monkeyhub/device');

  /// Battery level at which the app saves power by itself, whatever the
  /// phone's own mode. iOS only OFFERS Low Power Mode here, and Battery
  /// Saver's automatic threshold is often off, so waiting for the phone would
  /// mean most people running full motion down to empty.
  static const kLowBatteryPercent = 20;

  /// Whether the OS power saving mode is on, as opposed to the app saving
  /// power only because the battery is low. Says which, so the toast can.
  bool get osPowerSave => _osPowerSave;
  bool _osPowerSave = false;

  /// Whether the battery is at [kLowBatteryPercent] or less and not charging.
  bool get lowBattery => _lowBattery;
  bool _lowBattery = false;

  static const EventChannel _changes = EventChannel('monkeyhub/power');

  /// The native stream of changes, listened to from the first [refresh] for
  /// the life of the app.
  StreamSubscription<dynamic>? _watch;

  /// Re-reads the OS flag and the battery. Quiet on desktop and web, where
  /// there is no such channel, and on any failure: not knowing is "normal
  /// power".
  Future<void> refresh() async {
    if (kIsWeb || !(Platform.isIOS || Platform.isAndroid)) return;
    _watch ??= _changes.receiveBroadcastStream().listen(
      (event) {
        if (event is Map) apply(event.cast<String, Object?>());
      },
      // An older native build without the channel: launch and resume reads
      // still cover it.
      onError: (Object _) {},
    );
    try {
      final info = await _device.invokeMapMethod<String, Object?>(
        'getBuildInfo',
      );
      if (info != null) apply(info);
    } catch (_) {}
  }

  /// Reads `getBuildInfo`'s answer. At [kLowBatteryPercent] exactly it is
  /// already on; plugging in turns it off, since the battery is now filling.
  @visibleForTesting
  void apply(Map<String, Object?> info) {
    _osPowerSave = info['powerSaveMode'] == true;
    final level = info['batteryLevel'];
    _lowBattery = level is int &&
        level <= kLowBatteryPercent &&
        info['charging'] != true;
    value = _osPowerSave || _lowBattery;
  }
}

/// Calms [child]'s motion while the phone is saving power; see [LowPowerMode].
class LowPowerCalm extends StatelessWidget {
  const LowPowerCalm({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: Listenable.merge([LowPowerMode.instance, SettingsStore.instance]),
    builder: (context, _) => LowPowerMode.active
        ? MediaQuery(
            data: MediaQuery.of(context).copyWith(disableAnimations: true),
            child: child,
          )
        : child,
  );
}
