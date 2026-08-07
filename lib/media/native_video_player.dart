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

  /// kIsWeb is const, so the `&&` short-circuits before `Platform` (dart:io),
  /// which throws on web. Same guard `CaptureProtection` uses.
  static bool get supported => !kIsWeb && (Platform.isIOS || Platform.isAndroid);

  /// Presents the OS player over the app and resolves once it is on screen —
  /// NOT when the user closes it. The native surface owns its own dismissal
  /// from that point on; the caller's job is only to get out of the way.
  ///
  /// [secure] asks the platform to block screenshots and screen recording of
  /// the player (Android's FLAG_SECURE). It has no iOS equivalent, which is
  /// why callers there decline the handoff outright rather than pass `true` —
  /// see the note at the call site in `fullscreen_video_viewer.dart`.
  ///
  /// Returns false if the platform declined, the channel is missing (a build
  /// where the native half didn't land), or anything threw.
  static Future<bool> present({required String url, bool secure = false}) async {
    if (!supported) return false;
    try {
      final ok = await _channel.invokeMethod<bool>('present', {
        'url': url,
        'secure': secure,
      });
      return ok == true;
    } on MissingPluginException {
      return false;
    } catch (e) {
      debugPrint('NativeVideoPlayer.present failed: $e');
      return false;
    }
  }
}
