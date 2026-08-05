import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb, debugPrint;
import 'package:flutter/services.dart' show MethodChannel;
import 'package:flutter_callkit_incoming/flutter_callkit_incoming.dart';

/// The two Android-only OS settings that decide whether a call actually reaches
/// the user, exposed as a read-and-fix surface rather than a prompt.
///
/// This class used to run all three of its checks from a post-frame callback in
/// `_bootstrap`, so a new Android user was interrupted three times before
/// sending a first message — a permission dialog, then two explain-dialogs that
/// each ejected them into a system settings page. iOS asked for none of it. The
/// prompts are gone; what they used to open is now reachable on demand from
/// Settings → NOTIFICATIONS.
///
/// The microphone check went with them and has no replacement here, because it
/// never needed one: [CallPermissions.ensure] already runs at every point of
/// use (`call_service.dart`, `group_call_service.dart`), so the pre-grant only
/// moved the identical dialog earlier and out of context — where Android 11+
/// turns a second dismissal into a permanent auto-deny. A permanently-denied
/// mic is handled where it surfaces, by `CallPermissions._explainRefusal`.
///
/// What is genuinely lost by not asking: nothing on stock Android, where the
/// high-priority FCM data pushes in `CallFcmService` already wake the app out
/// of Doze and App Standby — that tier exists precisely for this. The exemption
/// only buys protection against OEM power managers (MIUI, EMUI, ColorOS,
/// Funtouch) that ignore those rules, and it does not fully fix them either:
/// those skins gate autostart separately, behind a screen no intent can open.
/// So it is worth offering, and not worth spending onboarding on.
class AndroidCallReliability {
  AndroidCallReliability._();
  static final AndroidCallReliability instance = AndroidCallReliability._();

  static const MethodChannel _device = MethodChannel('monkeyhub/device');

  /// Whether any of this applies. Everything below is a no-op elsewhere, so
  /// callers can use this to decide whether to render the UI at all.
  static bool get supported => !kIsWeb && Platform.isAndroid;

  /// Android 14+ only grants USE_FULL_SCREEN_INTENT at install to apps Play
  /// classifies as calling apps. That covers this app on the Play track, so the
  /// expected answer here is `true` and the row stays quiet — a `false` in the
  /// field is worth reading as a Play Console declaration problem first, and a
  /// user problem second.
  Future<bool> fullScreenIntentAllowed() async {
    if (!supported) return true;
    try {
      return await FlutterCallkitIncoming.canUseFullScreenIntent();
    } catch (e) {
      // Unknown is reported as fine: a row that cannot read its own state has
      // nothing useful to tell the user, and "something may be wrong" on every
      // launch is the anxiety this whole change is removing.
      debugPrint('AndroidCallReliability: full-screen-intent check failed: $e');
      return true;
    }
  }

  Future<bool> batteryExempt() async {
    if (!supported) return true;
    try {
      return await _device.invokeMethod<bool>(
            'isIgnoringBatteryOptimizations',
          ) ??
          true;
    } catch (e) {
      debugPrint('AndroidCallReliability: battery check failed: $e');
      return true;
    }
  }

  /// Opens the system page. Both are best-effort: OEM builds hide or rename
  /// these screens, and the native side already falls back to the generic list
  /// (see MainActivity's `requestIgnoreBatteryOptimizations`).
  Future<void> openFullScreenIntentSettings() async {
    if (!supported) return;
    try {
      await FlutterCallkitIncoming.requestFullIntentPermission();
    } catch (e) {
      debugPrint('AndroidCallReliability: full-screen-intent open failed: $e');
    }
  }

  Future<void> openBatterySettings() async {
    if (!supported) return;
    try {
      await _device.invokeMethod('requestIgnoreBatteryOptimizations');
    } catch (e) {
      debugPrint('AndroidCallReliability: battery settings open failed: $e');
    }
  }
}
