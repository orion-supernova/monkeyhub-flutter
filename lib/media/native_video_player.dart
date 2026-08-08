import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Hands a video URL to the operating system's own player — `AVPlayerViewController`
/// on iOS, a full-screen ExoPlayer activity on Android.
///
/// The point is the controls, not the decoder. Flutter's `video_player` gives
/// a texture and nothing else, so everything above it (scrub bar, skip, speed,
/// AirPlay/Cast, Picture-in-Picture, the system volume HUD, VoiceOver labels,
/// the transport controls on the lock screen) has to be re-invented in Dart —
/// and whatever gets re-invented is a worse, unfamiliar copy of the player the
/// user already knows from Photos. Handing off gets all of it for free and in
/// the user's own language.
///
/// This is a best-effort path by design: every call site keeps its Flutter
/// player as the fallback, and [present] answers `false` — never throws —
/// whenever the platform can't take the video.
class NativeVideoPlayer {
  NativeVideoPlayer._();

  static const _channel = MethodChannel('monkeyhub/video');

  /// Forces [supported] either way, so the handoff decision can be exercised
  /// under `flutter test` — which reports neither iOS nor Android, and would
  /// otherwise send every test down the unsupported branch. Null asks the
  /// platform, which is what every non-test caller gets.
  @visibleForTesting
  static bool? debugSupportedOverride;

  /// kIsWeb is const, so the `&&` short-circuits before `Platform` (dart:io),
  /// which throws on web. Same guard `CaptureProtection` uses.
  static bool get supported =>
      debugSupportedOverride ??
      (!kIsWeb && (Platform.isIOS || Platform.isAndroid));

  /// Presents the OS player over the app and resolves once it is on screen —
  /// NOT when the user closes it. The native surface owns its own dismissal
  /// from that point on; the caller's job is only to get out of the way.
  ///
  /// [secure] asks the platform to keep the video away from a screen recording,
  /// and the two platforms honour it by different means because only one of
  /// them can prevent capture at all. Android sets FLAG_SECURE and the frames
  /// simply never reach the recording. iOS has no such flag, so it does what
  /// the Flutter `CaptureShield` does: watches `UIScreen.isCaptured` and covers
  /// the player while a recording or AirPlay mirror is live. Detection instead
  /// of prevention — weaker, and the same weakness the Dart shield already has.
  ///
  /// [shieldTitle] and [shieldBody] are that cover's copy. They are passed down
  /// rather than written in Swift because the strings live in the app's
  /// localizations, in twelve languages; the native side has no access to them
  /// and hardcoding English would be the one screen that stops translating.
  /// Only iOS reads them, and only when [secure] is set.
  ///
  /// Returns false if the platform declined, the channel is missing (a build
  /// where the native half didn't land), or anything threw.
  static Future<bool> present({
    required String url,
    bool secure = false,
    String? shieldTitle,
    String? shieldBody,
  }) async {
    if (!supported) return false;
    try {
      final ok = await _channel.invokeMethod<bool>('present', {
        'url': url,
        'secure': secure,
        'shieldTitle': shieldTitle,
        'shieldBody': shieldBody,
      });
      return ok == true;
    } on MissingPluginException {
      // Worth a line rather than a silent false: this is the one failure that
      // looks exactly like a design decision from the outside. The Dart half
      // shipped, the native half didn't, and the fallback player that appears
      // is indistinguishable from the fallback we choose on purpose. Nine
      // times in ten it means the running binary predates the channel — a hot
      // restart, or a build that didn't recompile the platform side.
      debugPrint(
        'NativeVideoPlayer: no monkeyhub/video channel in this build — '
        'falling back to the Flutter player. Rebuild the native app.',
      );
      return false;
    } catch (e) {
      debugPrint('NativeVideoPlayer.present failed: $e');
      return false;
    }
  }
}
