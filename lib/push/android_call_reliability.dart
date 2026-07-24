import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_callkit_incoming/flutter_callkit_incoming.dart';

import '../data/settings_store.dart';
import '../main.dart' show rootNavigatorKey;

/// Two Android-only, once-per-install prompts that make killed-app incoming
/// calls actually ring on real devices:
///
///  1. Full-screen-intent access (Android 14+). Without it the incoming-call
///     screen degrades to a small heads-up notification when the phone is
///     locked — easy to miss a call.
///  2. Battery-optimization exemption. OEM power managers (Xiaomi, Samsung,
///     Oppo…) defer or drop even priority-high FCM for "optimized" apps,
///     which is the classic "sometimes rings, sometimes doesn't".
///
/// Both open a system settings page, so each is preceded by a short
/// explanatory dialog and asked at most once (flags in [SettingsStore]);
/// declining is always recoverable via system settings.
class AndroidCallReliability {
  AndroidCallReliability._();
  static final AndroidCallReliability instance = AndroidCallReliability._();

  static const MethodChannel _device = MethodChannel('monkeyhub/device');

  bool _ranThisSession = false;

  /// Fire-and-forget after login, once the navigator is mounted.
  Future<void> ensure() async {
    if (kIsWeb || !Platform.isAndroid || _ranThisSession) return;
    // Don't latch the session flag while the navigator isn't ready — the
    // _onAuthChange path can land here a frame before the root navigator
    // mounts, and burning the attempt would skip the prompts entirely.
    if (rootNavigatorKey.currentContext == null) return;
    _ranThisSession = true;
    await _ensureFullScreenIntent();
    await _ensureBatteryExemption();
  }

  Future<void> _ensureFullScreenIntent() async {
    final store = SettingsStore.instance;
    if (store.fullScreenIntentPrompted) return;
    try {
      final allowed = await FlutterCallkitIncoming.canUseFullScreenIntent();
      if (allowed) return;
      final go = await _explain(
        title: 'Show calls on the lock screen',
        body: 'To ring like a real phone call when your screen is off, '
            'MonkeyHub needs "full-screen notifications" turned on. '
            'The next screen takes you straight to the switch.',
      );
      // null = dialog never shown (navigator gone) — keep the one-shot
      // unburned so a future launch can still ask.
      if (go == null) return;
      await store.markFullScreenIntentPrompted();
      if (go) await FlutterCallkitIncoming.requestFullIntentPermission();
    } catch (e) {
      debugPrint('AndroidCallReliability: full-screen-intent check failed: $e');
    }
  }

  Future<void> _ensureBatteryExemption() async {
    final store = SettingsStore.instance;
    if (store.batteryOptPrompted) return;
    try {
      final exempt =
          await _device.invokeMethod<bool>('isIgnoringBatteryOptimizations') ??
              true;
      if (exempt) return;
      final go = await _explain(
        title: 'Never miss a call',
        body: 'Some phones pause apps in the background to save battery, '
            'which can silence incoming calls. Allow MonkeyHub to run '
            'unrestricted so calls always come through.',
      );
      if (go == null) return;
      await store.markBatteryOptPrompted();
      if (go) await _device.invokeMethod('requestIgnoreBatteryOptimizations');
    } catch (e) {
      debugPrint('AndroidCallReliability: battery check failed: $e');
    }
  }

  /// Small pre-prompt so the jump into system settings isn't jarring.
  /// Returns null when the dialog could not be shown (navigator not ready) —
  /// callers must NOT mark the one-shot flag in that case. false = declined.
  Future<bool?> _explain({required String title, required String body}) async {
    final context = rootNavigatorKey.currentContext;
    if (context == null) return null;
    final answer = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(body),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Not now'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Continue'),
          ),
        ],
      ),
    );
    // Dialog dismissed without a choice (tap outside / back) counts as a
    // decline — it WAS shown, so the one-shot is spent.
    return answer ?? false;
  }
}
