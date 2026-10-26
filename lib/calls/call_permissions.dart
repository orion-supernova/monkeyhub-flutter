import 'dart:io' show Platform;

import 'package:flutter/foundation.dart'
    show debugPrint, kIsWeb, visibleForTesting;
import 'package:flutter/services.dart';

import '../main.dart' show rootNavigatorKey;
import '../widgets/destructive_sheet.dart';
import 'call_models.dart';

/// Mic/camera grants, checked *before* a call is allowed to exist.
///
/// This is a crash guard, not a UX nicety. flutter_callkit_incoming 3.x starts a
/// foreground service typed `phoneCall|microphone[|camera]` on both
/// ACTION_CALL_START and ACTION_CALL_ACCEPT. On Android 14 (this app targets
/// SDK 34) an FGS typed `microphone` requires RECORD_AUDIO to already be
/// granted and `camera` requires CAMERA — and the plugin's `startForeground`
/// call is unguarded, so a missing grant throws SecurityException out of
/// `Service.onStartCommand` and kills the process. A Dart try/catch around
/// `startCall` cannot see it: different component, and it fires after the call
/// returned. See CallPermissions.kt for the native half.
///
/// The answer path is why grants must be held *before a call can ring*, not
/// merely before media is captured: the foreground service is started by the
/// plugin's own broadcast receiver the instant the user taps Accept on the
/// system UI, before any of our Dart runs. So the ring sites bake the current
/// grant state into `callingNotification.showNotification`, and this class is
/// what makes that state true in the common case.
///
/// Off Android everything here is a no-op that reports success: iOS gets its
/// permissions from Info.plist usage descriptions via `getUserMedia`, and has no
/// foreground-service concept to crash on.
class CallPermissions {
  CallPermissions._();

  static const MethodChannel _device = MethodChannel('monkeyhub/device');

  /// Forces the Android branch on a VM test host, where `Platform.isAndroid` is
  /// false and every method would otherwise short-circuit to "granted" and
  /// assert nothing. Null in production.
  @visibleForTesting
  static bool? debugForceApplies;

  /// Whether this platform needs (and can answer) a permission pre-flight.
  static bool get _applies =>
      debugForceApplies ?? (!kIsWeb && Platform.isAndroid);

  /// Pure check, no prompting and no UI. Used at ring time to decide whether
  /// the native call UI may safely bring up its foreground service.
  static Future<bool> granted(CallMediaKind kind) async {
    if (!_applies) return true;
    try {
      return await _device.invokeMethod<bool>(
            'hasCallPermissions',
            {'video': kind == CallMediaKind.video},
          ) ??
          false;
    } catch (e) {
      // An older build without the channel method, or no activity attached.
      // Report false: suppressing the foreground service costs us background
      // call survival, whereas a wrong `true` costs the whole process.
      debugPrint('CallPermissions.granted: $e');
      return false;
    }
  }

  /// Check, prompt once if needed, and re-check. Returns whether the call may
  /// proceed. On refusal this explains what happened and offers a route to
  /// Settings, so the caller can simply bail without any UI of its own.
  ///
  /// Safe to call on every attempt: when the grants are already held it is a
  /// single cheap channel round-trip and shows nothing.
  static Future<bool> ensure(CallMediaKind kind) async {
    if (!_applies) return true;
    final video = kind == CallMediaKind.video;
    if (await granted(kind)) return true;

    var ok = false;
    try {
      ok = await _device.invokeMethod<bool>(
            'requestCallPermissions',
            {'video': video},
          ) ??
          false;
    } catch (e) {
      debugPrint('CallPermissions.ensure: $e');
      ok = false;
    }
    if (ok) return true;

    // Denied — or a second request arrived while a dialog was already open. Ask
    // again cheaply before complaining, so the latter case doesn't produce a
    // spurious refusal sheet.
    if (await granted(kind)) return true;
    await _explainRefusal(video: video);
    return false;
  }

  /// Ask for the microphone once, proactively, with no refusal UI.
  ///
  /// Called post-login rather than lazily, because the *incoming* path cannot
  /// ask at the right moment: whether the native call UI may run its foreground
  /// service is decided when the call is shown, and the answer tap starts that
  /// service before any Dart of ours runs. Holding the grant in advance is what
  /// lets an incoming call keep its foreground service — and so survive being
  /// backgrounded — instead of ringing in the degraded, suppressed mode.
  ///
  /// Deliberately silent on refusal: this is speculative, so it must not nag.
  /// A user who declines here still gets the full explanation from [ensure] the
  /// first time they actually place a call. Camera is not requested — video is
  /// rarer, and asking for a permission the user has not reached for yet is how
  /// you train people to tap Deny.
  static Future<void> preGrantMicrophone() async {
    if (!_applies) return;
    if (await granted(CallMediaKind.audio)) return;
    try {
      await _device.invokeMethod<bool>(
        'requestCallPermissions',
        {'video': false},
      );
    } catch (e) {
      debugPrint('CallPermissions.preGrantMicrophone: $e');
    }
  }

  /// Android stops showing the system prompt after two denials, so the only
  /// honest next step is Settings. Reuses the app's standard confirm sheet
  /// rather than inventing a dialog.
  static Future<void> _explainRefusal({required bool video}) async {
    final context = rootNavigatorKey.currentContext;
    if (context == null) return;
    final go = await showConfirmSheet(
      context,
      headline: video ? 'Camera and microphone needed' : 'Microphone needed',
      body: video
          ? 'MonkeyHub needs your camera and microphone to place a video call. '
              'Turn them on in Settings and try again.'
          : 'MonkeyHub needs your microphone to place a call. Turn it on in '
              'Settings and try again.',
      confirmLabel: 'Open Settings',
      destructive: false,
    );
    if (!go) return;
    try {
      await _device.invokeMethod('openAppSettings');
    } catch (e) {
      debugPrint('CallPermissions.openAppSettings: $e');
    }
  }
}
