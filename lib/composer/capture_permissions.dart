import 'dart:io' show Platform;

import 'package:flutter/foundation.dart'
    show debugPrint, kIsWeb, visibleForTesting;
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

/// What a microphone or camera grant is currently worth.
///
/// Four states rather than a bool because the three refusals need three
/// different answers, and collapsing them is how a permission flow becomes a
/// dead end:
///
///  * [denied] — the user said no once. Asking again is legitimate, and on
///    both platforms the system will show its own prompt.
///  * [deniedForever] — the system will no longer prompt (Android after two
///    refusals, iOS after any refusal). Asking again is a silent no-op, so the
///    only honest next step is a route to Settings.
///  * [restricted] — a policy the user cannot change from here at all: iOS
///    Screen Time / MDM, an Android work profile. Offering Settings would send
///    them somewhere with no switch on it, so this says so instead.
enum CaptureGrant { granted, denied, deniedForever, restricted }

/// Which device a grant is about.
enum CaptureDevice { microphone, camera }

/// Microphone and camera grants for composer capture.
///
/// Deliberately NOT `permission_handler`. This app has no such dependency and
/// adding one for two permissions would pull in a plugin that touches every
/// platform manifest; the two capture plugins already report grant state,
/// and Android's own answer is already reachable over the `monkeyhub/device`
/// channel that [CallPermissions] uses. What is missing there is only the
/// deep-link on iOS, and `url_launcher` — already a direct dependency — opens
/// `app-settings:` without a line of native code.
///
/// The channel methods are named `hasCallPermissions` / `requestCallPermissions`
/// for historical reasons: they check RECORD_AUDIO and, with `video: true`,
/// CAMERA. Nothing about them is call-specific — see `CallPermissions.kt`. They
/// are reused rather than duplicated because a second native permission path
/// is a second thing to keep in step with `targetSdk`.
class CapturePermissions {
  CapturePermissions._();

  static const MethodChannel _device = MethodChannel('monkeyhub/device');

  /// Forces the Android branch on a VM test host, where `Platform.isAndroid` is
  /// false and every method would short-circuit. Null in production. Mirrors
  /// `CallPermissions.debugForceApplies`, which exists for the same reason.
  @visibleForTesting
  static bool? debugForceAndroid;

  static bool get _isAndroid =>
      debugForceAndroid ?? (!kIsWeb && Platform.isAndroid);

  /// Pure check, no prompting. Android only — everywhere else the answer is
  /// only knowable by trying, so this optimistically reports granted and the
  /// capture attempt itself produces the real answer.
  static Future<bool> granted(CaptureDevice device) async {
    if (!_isAndroid) return true;
    try {
      return await _device.invokeMethod<bool>(
            'hasCallPermissions',
            {'video': device == CaptureDevice.camera},
          ) ??
          false;
    } catch (e) {
      debugPrint('CapturePermissions.granted: $e');
      // Optimistic on a channel failure: the capture plugin will ask for
      // itself, and a false here would refuse a user who has the grant.
      return true;
    }
  }

  /// Check, prompt if needed, re-check. Android only, for the same reason
  /// [granted] is.
  ///
  /// Returns [CaptureGrant.granted] everywhere else without doing anything:
  /// on iOS the first `AVCaptureSession` or `AVAudioRecorder` touch raises the
  /// system sheet itself, and its refusal comes back as a plugin error the
  /// caller already has to handle. Pre-empting it here would show a second
  /// prompt for the same thing.
  static Future<CaptureGrant> request(CaptureDevice device) async {
    if (!_isAndroid) return CaptureGrant.granted;
    if (await granted(device)) return CaptureGrant.granted;

    var ok = false;
    try {
      ok = await _device.invokeMethod<bool>(
            'requestCallPermissions',
            {'video': device == CaptureDevice.camera},
          ) ??
          false;
    } catch (e) {
      debugPrint('CapturePermissions.request: $e');
    }
    if (ok) return CaptureGrant.granted;
    // A second request arriving while a dialog was open comes back false
    // without a dialog ever being shown, so re-check cheaply before calling it
    // a refusal — the same guard `CallPermissions.ensure` makes.
    if (await granted(device)) return CaptureGrant.granted;
    // Android's channel cannot tell "denied" from "denied and don't ask again"
    // without a `shouldShowRequestPermissionRationale` round-trip this app has
    // no method for. Reporting the harsher of the two is the safe read: it
    // offers Settings, which works in both cases, where reporting the softer
    // one would offer a retry that silently does nothing.
    return CaptureGrant.deniedForever;
  }

  /// Translates a `CameraException` code into a grant.
  ///
  /// The camera plugin reports microphone refusals under `Audio*` codes when
  /// the controller was built with `enableAudio: true`, which is exactly the
  /// video-note case — so a video note refused for the mic and a video note
  /// refused for the lens arrive here as different strings and must not be
  /// flattened into one message.
  static CaptureGrant? grantForCameraCode(String code) => switch (code) {
        'CameraAccessDenied' || 'AudioAccessDenied' => CaptureGrant.denied,
        'CameraAccessDeniedWithoutPrompt' ||
        'AudioAccessDeniedWithoutPrompt' =>
          CaptureGrant.deniedForever,
        'CameraAccessRestricted' ||
        'AudioAccessRestricted' =>
          CaptureGrant.restricted,
        _ => null,
      };

  /// Opens this app's page in the system settings.
  ///
  /// Two routes because there is no one call that works on both: Android goes
  /// through the existing `monkeyhub/device` channel, and iOS opens the
  /// `app-settings:` URL, which is what `UIApplication.openSettingsURLString`
  /// resolves to. Doing iOS in Dart rather than adding a Swift method keeps the
  /// whole feature analyzable — a native method cannot be checked by
  /// `flutter analyze` and would only fail on a device.
  static Future<bool> openSettings() async {
    if (_isAndroid) {
      try {
        return await _device.invokeMethod<bool>('openAppSettings') ?? false;
      } catch (e) {
        debugPrint('CapturePermissions.openSettings: $e');
        return false;
      }
    }
    if (kIsWeb) return false;
    try {
      // No `canLaunchUrl` first: on iOS that consults
      // `LSApplicationQueriesSchemes` for non-http schemes and answers false
      // for anything unlisted, which would refuse a URL that opens fine.
      return await launchUrl(Uri.parse('app-settings:'));
    } catch (e) {
      debugPrint('CapturePermissions.openSettings: $e');
      return false;
    }
  }
}
