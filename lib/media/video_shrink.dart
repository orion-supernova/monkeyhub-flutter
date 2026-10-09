import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'file_meta.dart';

/// Re-encodes a video that is over [kMaxFileUploadBytes] until it fits.
///
/// Native on both sides (`VideoShrink.swift` on iOS and macOS, `VideoShrink.kt`
/// on Android) because the OS encoders are the only ones that are fast, use
/// the hardware and keep rotation and audio right. Nothing on web, where there
/// is no filesystem to encode from.
class VideoShrink {
  const VideoShrink._();

  static const _channel = MethodChannel('monkeyhub/video_shrink');

  static bool get supported =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.iOS ||
          defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.macOS);

  /// The path of a new MP4 at or under [capBytes], or null when the clip is
  /// too long to fit at any watchable quality or will not encode. The caller
  /// deletes the file it gets back.
  static Future<String?> shrink(
    String inputPath, {
    int capBytes = kMaxFileUploadBytes,
  }) async {
    if (!supported) return null;
    try {
      final out = await _channel.invokeMethod<String>('shrink', {
        'input': inputPath,
        'capBytes': capBytes,
      });
      if (out == null) return null;
      // Trust the file, not the answer: a cap the native side misread would
      // otherwise turn into the 48 MB dead-end bubble this exists to avoid.
      final size = await File(out).length();
      if (size <= 0 || size > capBytes) {
        try {
          await File(out).delete();
        } catch (_) {}
        return null;
      }
      return out;
    } catch (e) {
      debugPrint('[video_shrink] $e');
      return null;
    }
  }
}

/// What a video's size means for sending it.
enum VideoFate {
  /// At or under the cap: sent as it is.
  asIs,

  /// Over the cap, on a platform that can re-encode: compressed to fit, after
  /// the sender has been told it will look worse.
  shrink,

  /// Over the cap with nothing to re-encode it: refused.
  refuse,
}

/// The one rule every way of putting a video in a chat follows. Per video,
/// never per batch: five 5 MB clips are five clips under the cap.
VideoFate videoFateFor(
  int bytes, {
  bool canShrink = true,
  int capBytes = kMaxFileUploadBytes,
}) {
  if (bytes <= capBytes) return VideoFate.asIs;
  return canShrink ? VideoFate.shrink : VideoFate.refuse;
}

/// The content type for a video file, from its name. The send paths used to
/// label every pick `video/mp4`, whatever its container; a `.mov` is QuickTime.
String videoContentTypeFor(String path) {
  final lower = path.toLowerCase();
  if (lower.endsWith('.mov') || lower.endsWith('.qt')) return 'video/quicktime';
  if (lower.endsWith('.webm')) return 'video/webm';
  if (lower.endsWith('.m4v')) return 'video/x-m4v';
  return 'video/mp4';
}
