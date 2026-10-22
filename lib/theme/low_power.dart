import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../data/settings_store.dart';

/// Whether the phone is in Low Power Mode (iOS) or Battery Saver (Android).
///
/// When it is, the app stops decorating: [LowPowerCalm] turns on
/// `MediaQuery.disableAnimations` for the whole tree, which every
/// [MotionScope] and every `disableAnimationsOf` check already honours. The
/// user keeps the last word: an explicit Motion choice in Settings wins over
/// this, exactly as it wins over the OS Reduce Motion flag.
///
/// Neither OS pushes this change to Flutter, so it is read at launch and again
/// on every resume. Both toggles live in places that background the app
/// (Control Centre, the quick settings shade), so a resume is when it can have
/// changed.
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

  /// Re-reads the OS flag. Quiet on desktop and web, where there is no such
  /// channel, and on any failure: not knowing is "normal power".
  Future<void> refresh() async {
    if (kIsWeb || !(Platform.isIOS || Platform.isAndroid)) return;
    try {
      final info = await _device.invokeMapMethod<String, Object?>(
        'getBuildInfo',
      );
      value = info?['powerSaveMode'] == true;
    } catch (_) {}
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
