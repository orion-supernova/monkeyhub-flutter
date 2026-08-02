import 'dart:typed_data';

import 'package:flutter/foundation.dart' show debugPrint, kIsWeb;
import 'package:video_thumbnail/video_thumbnail.dart';

/// A still frame from an outgoing video, so the shared-content grid can show
/// the video instead of a play glyph.
///
/// **Android and iOS only.** The plugin wraps `MediaMetadataRetriever` and
/// `AVAssetImageGenerator`; neither exists on web or desktop, and there is no
/// pure-Dart fallback — decoding an arbitrary container in Dart is not a thing
/// this app is going to do. So a video sent from a browser gets no poster, and
/// neither does anything in history. That is permanent rather than a migration
/// state, which is why `MediaGridTile` draws its glyph as a designed
/// representation of a video rather than as a loading placeholder.
class VideoPoster {
  const VideoPoster._();

  /// Longest edge of the generated poster, in pixels.
  ///
  /// A grid tile is ~120pt, so even at 3× this has room to spare — and the
  /// poster is a second blob uploaded on the sender's connection before their
  /// video can go, so every kilobyte is time they spend watching a spinner.
  static const _maxEdge = 640;

  /// JPEG quality. Low enough to stay small, high enough that a 120pt tile
  /// shows no artefacts.
  static const _quality = 70;

  /// Extracts a poster from the video at [path], or null when it cannot.
  ///
  /// [path] must be a real filesystem path. **Never call this with an
  /// `XFile.path` on web**: there it is a `blob:` URL with no filesystem
  /// behind it — the same trap `UploadService` documents for `uploadXFile` —
  /// and the plugin is not there to receive it anyway. `video_poster_gate_test`
  /// pins that every call site is `!kIsWeb`.
  ///
  /// Returns null rather than throwing on every failure path. A poster is an
  /// enhancement to a send that must happen regardless: a codec the retriever
  /// cannot open, a permission quirk, a video whose first frame is not yet
  /// decodable — none of those are reasons to refuse to send the video.
  static Future<Uint8List?> extract(String path) async {
    if (kIsWeb) return null;
    if (path.isEmpty) return null;
    try {
      final bytes = await VideoThumbnail.thumbnailData(
        video: path,
        imageFormat: ImageFormat.JPEG,
        maxWidth: _maxEdge,
        // Frame zero is black on a surprising number of videos — anything that
        // fades in, and most screen recordings. A little way in is far more
        // likely to be a frame worth showing, and costs nothing extra since
        // the retriever seeks either way.
        timeMs: 500,
        quality: _quality,
      );
      if (bytes == null || bytes.isEmpty) return null;
      return bytes;
    } catch (e) {
      // Includes MissingPluginException on any platform where this was reached
      // by mistake, which is the one failure mode worth being loud about in a
      // debug build and silent about in a release one.
      debugPrint('poster extraction failed: $e');
      return null;
    }
  }
}
