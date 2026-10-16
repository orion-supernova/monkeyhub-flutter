import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';

import 'blob_url.dart';

/// A view-once voice message or video note, staged for a platform player for
/// exactly as long as it plays.
///
/// A photo can be drawn from memory ([Image.memory]); `just_audio` and
/// `video_player` cannot be handed bytes. They want a source. The options were:
///
///  * **A `StreamAudioSource`** serving the bytes from memory. On iOS, Android
///    and macOS that is implemented as a cleartext HTTP proxy on localhost,
///    which this app has never enabled (no `usesCleartextTraffic` or network
///    security config, no ATS exception) and which `video_player` has no
///    equivalent of anyway. It would fail on Android outright.
///  * **A temp file**, which is what this is on native: written to a folder of
///    its own under the OS temp directory — never the persistent media caches
///    (`AudioFileCache`, `VideoFileCache`, `FileUrlCache`), which outlive the
///    burn by design — and deleted the moment the player is released: when the
///    note ends, when the bubble or the focus goes away, or when the app leaves
///    the foreground. Not deleted straight after load: AVFoundation and
///    ExoPlayer both re-open the file mid-playback (buffering, seeking a codec
///    back to a keyframe), and a file pulled from under them stalls the one
///    look there is.
///  * **On the web** there is no filesystem, so it is an object URL over the
///    in-memory bytes ([BlobUrl]), revoked on release — the memory option the
///    native platforms cannot have.
///
/// A crash mid-playback is the one exit no code path sees, so [sweep] empties
/// the folder of anything not currently playing; the room screen calls it on
/// open, and every [stage] calls it too.
class ViewOnceMedia {
  ViewOnceMedia._(this.source, this.isFile, this._release);

  /// A local path when [isFile], otherwise a URL a player can open.
  final String source;
  final bool isFile;
  final Future<void> Function() _release;
  bool _released = false;

  /// Replaces [stage] in widget tests, where there is no temp directory to
  /// write to and no player to read from it.
  @visibleForTesting
  static Future<ViewOnceMedia> Function(
    Uint8List bytes, {
    required String contentType,
    required String extension,
  })? debugStageOverride;

  /// A stand-in for tests: a source that names nothing and releases into
  /// [onRelease].
  @visibleForTesting
  static ViewOnceMedia fake(String source, {VoidCallback? onRelease}) =>
      ViewOnceMedia._(source, false, () async => onRelease?.call());

  static const _folder = 'mh_view_once';

  /// The paths a live player holds right now — the only files [sweep] spares.
  static final Set<String> _live = {};

  static Future<Directory>? _dir;

  static Future<Directory> _directory() {
    return _dir ??= () async {
      final base = await getTemporaryDirectory();
      final dir = Directory('${base.path}/$_folder');
      if (!await dir.exists()) await dir.create(recursive: true);
      return dir;
    }();
  }

  /// Puts [bytes] where a player can open them. The caller drops its own
  /// reference to the bytes straight after; this keeps none.
  static Future<ViewOnceMedia> stage(
    Uint8List bytes, {
    required String contentType,
    required String extension,
  }) async {
    final override = debugStageOverride;
    if (override != null) {
      return override(bytes, contentType: contentType, extension: extension);
    }
    if (kIsWeb) {
      final url = BlobUrl.create(bytes, contentType);
      if (url == null) throw StateError('view-once: no object URL');
      return ViewOnceMedia._(url, false, () async => BlobUrl.revoke(url));
    }
    await sweep();
    final dir = await _directory();
    final stamp = DateTime.now().microsecondsSinceEpoch;
    final path = '${dir.path}/vo_$stamp.$extension';
    _live.add(path);
    try {
      await File(path).writeAsBytes(bytes, flush: true);
    } catch (_) {
      _live.remove(path);
      await _delete(path);
      rethrow;
    }
    return ViewOnceMedia._(path, true, () async {
      _live.remove(path);
      await _delete(path);
    });
  }

  /// Gives the copy up. Idempotent: the bubble, the focus and a lifecycle
  /// change can all reach for it in the same frame.
  Future<void> release() async {
    if (_released) return;
    _released = true;
    await _release();
  }

  /// Deletes every staged file no player is holding. Never throws: a cleanup
  /// that can fail the playback it is cleaning up after is worse than a file
  /// left for the next sweep.
  static Future<void> sweep() async {
    if (kIsWeb) return;
    try {
      final dir = await _directory();
      await for (final f in dir.list()) {
        if (f is File && !_live.contains(f.path)) await _delete(f.path);
      }
    } catch (e) {
      debugPrint('ViewOnceMedia.sweep: $e');
    }
  }

  static Future<void> _delete(String path) async {
    try {
      final f = File(path);
      if (await f.exists()) await f.delete();
    } catch (e) {
      debugPrint('ViewOnceMedia: could not delete $path: $e');
    }
  }
}

/// The most a play-once video note's poster may weigh. The server refuses
/// anything over about 2 KB for an armed send, so this stays clear of it.
const int kViewOnceMicroPosterMaxBytes = 1800;

/// The longest side of a play-once video note's poster, in pixels.
const int kViewOnceMicroPosterSide = 16;

/// Shrinks a video note's poster to a [kViewOnceMicroPosterSide]-pixel JPEG for
/// a play-once send, or null when it cannot be made small enough.
///
/// A full poster of a play-once note is exactly what must not leak — it is
/// the sender's face, fetchable by anyone who learns its id. Sixteen pixels is
/// not a face, only the colours of one: enough for the sealed circle to look
/// like a note that is there, drawn blurred, the way Telegram seals one.
/// Off the UI thread, because the decode is of a full-size frame.
Future<Uint8List?> viewOnceMicroPoster(Uint8List? poster) async {
  if (poster == null || poster.isEmpty) return null;
  try {
    return await compute(_shrinkPoster, poster);
  } catch (e) {
    debugPrint('viewOnceMicroPoster: $e');
    return null;
  }
}

Uint8List? _shrinkPoster(Uint8List poster) {
  final decoded = img.decodeImage(poster);
  if (decoded == null) return null;
  final wide = decoded.width >= decoded.height;
  final small = img.copyResize(
    decoded,
    width: wide ? kViewOnceMicroPosterSide : null,
    height: wide ? null : kViewOnceMicroPosterSide,
    interpolation: img.Interpolation.average,
  );
  // Stepping the quality down is belt and braces: sixteen pixels at 60 is a
  // few hundred bytes, but a JPEG header is not nothing.
  for (final q in const [60, 40, 20]) {
    final out = img.encodeJpg(small, quality: q);
    if (out.length <= kViewOnceMicroPosterMaxBytes) return out;
  }
  return null;
}
