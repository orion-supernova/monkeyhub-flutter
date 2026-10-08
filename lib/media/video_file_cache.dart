import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

import 'file_url_cache.dart';
import 'storage/data_usage_store.dart';
import 'storage/gallery_autosave.dart';
import 'storage/media_ledger.dart';
import 'storage/storage_kinds.dart';

/// The file is bigger than [VideoFileCache] is willing to hold on disk.
///
/// Its own type, and not an error, because it isn't one: the caller's response
/// is to stream the video straight off the network the way it always did. The
/// alternative — caching it anyway — would evict a dozen ordinary clips to
/// store one that is probably watched once.
class MediaTooLarge implements Exception {
  const MediaTooLarge(this.bytes);
  final int bytes;
  @override
  String toString() => 'media too large to cache ($bytes bytes)';
}

/// Keeps a playable local copy of a stored video, so watching one twice costs
/// one download.
///
/// Streaming a progressive MP4 over HTTP re-fetches it in full every single
/// time — there is no HTTP cache in front of `AVPlayer` or `ExoPlayer`, so the
/// second play of a clip you watched thirty seconds ago buffers exactly as long
/// as the first. Worse, seeking mid-clip issues a fresh range request and
/// rebuffers, which is precisely when the native scrubber invites you to seek.
/// A complete local file removes all of it: replays start on the first frame
/// and scrubbing is instant, offline included.
///
/// This is also the model every chat app converges on — media is *downloaded*
/// and then played, not streamed — which is why the cost lands where it does:
/// the first play now waits for the whole file instead of the first few
/// seconds. [_maxFileBytes] is the guard on that trade. Anything above it isn't
/// cached at all and the caller streams as before, so one enormous clip can't
/// turn a tap into a stall.
///
/// Shaped after [AudioFileCache] deliberately — same singleton, same `_pending`
/// map so N widgets sharing an id do one download, same `.part`-then-rename,
/// same FIFO sweep. It is a separate class rather than a shared generic one
/// because almost every constant differs by two orders of magnitude, and the
/// download here has to stream to disk rather than buffer a body in memory:
/// `http.Client.get` on a 40 MB video would hold 40 MB of `Uint8List` live
/// while writing it.
class VideoFileCache {
  VideoFileCache._();
  static final VideoFileCache instance = VideoFileCache._();

  static const _dirName = 'mh_video_v1';

  /// The folder under the app's cache directory, for the storage scan.
  static const dirName = _dirName;

  /// Total bytes kept. At the ~8 MB a compressed phone clip runs to, this is
  /// roughly the last thirty videos — well past "the ones I'm rewatching",
  /// which is all this needs to cover.
  static const _maxFileBytes = 48 * 1024 * 1024;

  /// Ceiling for the whole directory, enforced by [_sweep]. A backstop only:
  /// the size the user chose in Data and Storage is enforced across every
  /// cache by `StorageService`, and this just stops a runaway directory if
  /// that policy is "no limit".
  static const _maxBytes = 4 * 1024 * 1024 * 1024;

  /// Whole-download deadline. Generous because unlike a voice note this can
  /// legitimately be tens of megabytes on a bad connection — but still finite,
  /// so a socket that stops delivering can't hold the tap open forever.
  static const _timeout = Duration(minutes: 5);

  /// Concurrent downloads. Two, not the audio cache's three: these are orders
  /// of magnitude larger, and a second download stealing bandwidth from the
  /// video the user is actually waiting on is the whole failure mode.
  static const _maxConcurrent = 2;

  /// Convex storage ids are lowercase alphanumerics, but this becomes a path
  /// segment, so it is validated rather than trusted — a `../` in an id would
  /// otherwise write outside the cache directory.
  static final _safeId = RegExp(r'^[A-Za-z0-9_-]{1,64}$');

  final Map<String, String> _paths = {};

  /// In-flight downloads, so a tap that lands while the pager is already
  /// fetching the same clip joins that download instead of racing it onto the
  /// same path.
  final Map<String, Future<String>> _pending = {};

  final _waiting = <Completer<void>>[];
  int _active = 0;
  Directory? _dir;
  bool _indexed = false;
  bool _swept = false;

  /// Overrides the cache directory so tests never touch a platform channel.
  @visibleForTesting
  Directory? debugDir;

  /// The local copy of [storageId] if one is already on disk, else null.
  /// Never downloads and never throws.
  ///
  /// This is the fast path the viewer is built around: a hit means the OS
  /// player opens on a local file and there is no spinner at all. Async only
  /// because the first call has to find the cache directory — no network is
  /// involved, so a caller can await it before showing anything.
  Future<String?> lookup(String storageId) async {
    if (kIsWeb || !_safeId.hasMatch(storageId)) return null;
    try {
      final known = _paths[storageId];
      if (known != null) return File(known).existsSync() ? known : null;
      final dir = await _directory();
      await _index(dir);
      final found = _paths[storageId];
      if (found == null) return null;
      return File(found).existsSync() ? found : null;
    } catch (e) {
      debugPrint('VideoFileCache.lookup failed (treating as a miss): $e');
      return null;
    }
  }

  /// Path to a local copy of [storageId], downloading it on a miss via the URL
  /// that [url] resolves. [onProgress] receives bytes-so-far and the total when
  /// the server declared one.
  ///
  /// Takes a URL resolver rather than a `ChatApi` so this has no opinion on
  /// where a URL comes from and is testable against a local server, matching
  /// [FileUrlCache.resolve] and [AudioFileCache.resolve].
  ///
  /// Throws [FileUnavailable] when the backend has no URL for the id,
  /// [MediaTooLarge] when the file exceeds [_maxFileBytes] (stream it instead),
  /// and [UnsupportedError] on web, which has no filesystem.
  Future<String> resolve(
    String storageId,
    Future<String?> Function() url, {
    void Function(int received, int? total)? onProgress,
    http.Client? client,
    int? maxBytes,
  }) {
    if (kIsWeb) {
      throw UnsupportedError('VideoFileCache is native-only');
    }
    if (!_safeId.hasMatch(storageId)) {
      return Future.error(ArgumentError.value(storageId, 'storageId', 'unsafe'));
    }

    final known = _paths[storageId];
    if (known != null) return Future.value(known);

    final inFlight = _pending[storageId];
    if (inFlight != null) return inFlight;

    final future =
        _download(storageId, url, onProgress, client, maxBytes).then((path) {
      _paths[storageId] = path;
      final entry = MediaLedger.instance
          .markLocal(storageId, fallbackKind: StorageKind.videos);
      unawaited(GalleryAutoSave.instance.offerVideo(entry, path));
      if (!_swept) {
        _swept = true;
        unawaited(_sweep());
      }
      return path;
    }).whenComplete(() {
      // Braces, not an arrow. `Map.remove` returns the removed value — here a
      // `Future<String>?`, and specifically *this* future — and `whenComplete`
      // waits on any Future its callback returns. An arrow body would make the
      // future await itself, so every cache miss would hang forever. The same
      // trap is documented in FileUrlCache and AudioFileCache; it keeps
      // coming back.
      _pending.remove(storageId);
    });

    _pending[storageId] = future;
    return future;
  }

  /// Forgets the local copy so the next [resolve] re-downloads. For a file a
  /// player rejected — truncated, or purged from `Library/Caches` between the
  /// lookup and the load.
  Future<void> evict(String storageId) async {
    if (kIsWeb) return;
    final path = _paths.remove(storageId);
    if (path == null) return;
    try {
      final f = File(path);
      if (f.existsSync()) await f.delete();
    } catch (_) {/* it's a cache; a stuck file costs one re-download */}
  }

  /// Drops every cached file. Sign-out — see `lib/app.dart`.
  Future<void> clear() async {
    _paths.clear();
    _pending.clear();
    _indexed = false;
    _swept = false;
    if (kIsWeb) return;
    try {
      final dir = await _directory();
      if (dir.existsSync()) await dir.delete(recursive: true);
      _dir = null;
    } catch (e) {
      debugPrint('VideoFileCache.clear failed: $e');
    }
  }

  // ---------------------------------------------------------------- internals

  Future<Directory> _directory() async {
    final override = debugDir;
    if (override != null) return override;
    final cached = _dir;
    if (cached != null) return cached;
    // Library/Caches, not Documents: these bytes are re-downloadable, and
    // Documents is iCloud-backed on iOS, so a few hundred megabytes of video
    // would land in the user's backup. Same reasoning as AudioFileCache, and
    // it matters far more at this size.
    final base = await getApplicationCacheDirectory();
    final dir = Directory('${base.path}/$_dirName');
    if (!dir.existsSync()) await dir.create(recursive: true);
    _dir = dir;
    return dir;
  }

  /// Repopulates [_paths] from what's already on disk, so a warm cache survives
  /// a restart without a hop in `main()`.
  Future<void> _index(Directory dir) async {
    if (_indexed) return;
    _indexed = true;
    try {
      for (final e in dir.listSync()) {
        if (e is! File) continue;
        final name = e.uri.pathSegments.last;
        // A `.part` is a download that never finished — killed by an app
        // suspension, or by the process dying. Sweep it rather than adopting
        // it, or the retry path would keep finding a truncated file that the
        // player accepts and then fails on.
        if (name.endsWith('.part')) {
          try {
            e.deleteSync();
          } catch (_) {}
          continue;
        }
        final dot = name.lastIndexOf('.');
        if (dot <= 0) continue;
        _paths[name.substring(0, dot)] = e.path;
      }
    } catch (e) {
      debugPrint('VideoFileCache index failed (continuing cold): $e');
    }
  }

  Future<String> _download(
    String storageId,
    Future<String?> Function() url,
    void Function(int received, int? total)? onProgress,
    http.Client? client,
    int? maxBytes,
  ) async {
    final cap = maxBytes == null || maxBytes > _maxFileBytes
        ? _maxFileBytes
        : maxBytes;
    final dir = await _directory();
    await _index(dir);

    final known = _paths[storageId];
    if (known != null && File(known).existsSync()) return known;

    final remote = await url();
    if (remote == null || remote.isEmpty) throw const FileUnavailable();

    await _acquire();
    final owned = client == null;
    final c = client ?? http.Client();
    final part = File('${dir.path}/$storageId.part');
    try {
      final resp = await c
          .send(http.Request('GET', Uri.parse(remote)))
          .timeout(_timeout);
      if (resp.statusCode != 200) {
        throw HttpException('status ${resp.statusCode}', uri: Uri.parse(remote));
      }
      final total = resp.contentLength;
      // Checked before a single byte is written: the point is to hand the
      // caller back to streaming without having spent the download twice.
      if (total != null && total > cap) throw MediaTooLarge(total);

      // Streamed to a sink rather than collected into `bodyBytes`. A video is
      // the one media type here where buffering the whole response in memory
      // to then write it out is a real cost — 40 MB of Uint8List live on a
      // phone, on top of whatever the transcript is already holding.
      final sink = part.openWrite();
      var received = 0;
      final usage =
          UsageKind.of(MediaLedger.instance[storageId]?.kind ?? StorageKind.videos);
      try {
        await for (final chunk in resp.stream) {
          received += chunk.length;
          // Also enforced mid-stream: a chunked response declares no length,
          // so this is the only ceiling that exists for one.
          if (received > cap) throw MediaTooLarge(received);
          sink.add(chunk);
          onProgress?.call(received, total);
        }
        await sink.flush();
      } finally {
        await sink.close();
        // Whatever arrived was paid for, finished or not.
        DataUsageStore.instance.record(usage, received: received);
      }

      final path = '${dir.path}/$storageId${await _extensionFor(part)}';
      // Rename only once the stream has completed. A download killed by app
      // suspension would otherwise leave a truncated file that the player
      // accepts and then fails on, permanently, with no way out for the user.
      // Rename within one directory is atomic on both APFS and ext4.
      await part.rename(path);
      return path;
    } catch (_) {
      // Never leave a partial behind for `_index` to trip over on next launch.
      try {
        if (part.existsSync()) await part.delete();
      } catch (_) {}
      rethrow;
    } finally {
      if (owned) c.close();
      _release();
    }
  }

  /// The extension the OS needs to recognise these bytes, read from the
  /// container's own magic rather than the served content type.
  ///
  /// Convex serves storage from an extension-less URL and the stored
  /// contentType is fixed at upload and cannot be patched — the exact pair of
  /// facts that made every voice note fail to play until [AudioFileCache]
  /// stopped trusting them. Giving the file a real extension is what lets
  /// AVFoundation infer the container at all.
  static Future<String> _extensionFor(File f) async {
    try {
      final head = await f.openRead(0, 12).expand((c) => c).toList();
      if (head.length >= 12) {
        final b = Uint8List.fromList(head);
        String at(int i, int n) => String.fromCharCodes(b.sublist(i, i + n));
        if (at(4, 4) == 'ftyp') {
          // `qt  ` is the QuickTime brand; everything else in practice here is
          // an MP4 family brand (isom/mp42/M4V ), which .mp4 covers.
          return at(8, 4) == 'qt  ' ? '.mov' : '.mp4';
        }
        if (b[0] == 0x1a && b[1] == 0x45 && b[2] == 0xdf && b[3] == 0xa3) {
          return '.webm';
        }
      }
    } catch (e) {
      debugPrint('VideoFileCache sniff failed, assuming mp4: $e');
    }
    // What both mobile recorders produce, and what the uploader transcodes to.
    return '.mp4';
  }

  Future<void> _acquire() {
    if (_active < _maxConcurrent) {
      _active++;
      return Future.value();
    }
    final c = Completer<void>();
    _waiting.add(c);
    return c.future;
  }

  void _release() {
    if (_waiting.isNotEmpty) {
      _waiting.removeAt(0).complete();
      return;
    }
    _active--;
  }

  /// Trims the directory to [_maxBytes], oldest first. Runs once per process,
  /// on the first miss.
  ///
  /// Files here are written once and never rewritten, so mtime order is FIFO
  /// rather than true LRU — a clip rewatched daily is evicted at the same age
  /// as one never opened again. Acceptable at this cap, and the cost of being
  /// wrong is one re-download.
  Future<void> _sweep() async {
    try {
      final dir = await _directory();
      if (!dir.existsSync()) return;
      final files = dir.listSync().whereType<File>().toList();
      var total = 0;
      for (final f in files) {
        total += f.statSync().size;
      }
      if (total <= _maxBytes) return;
      files.sort((a, b) => a.statSync().modified.compareTo(b.statSync().modified));
      for (final f in files) {
        if (total <= _maxBytes) break;
        final size = f.statSync().size;
        final name = f.uri.pathSegments.last;
        final dot = name.lastIndexOf('.');
        try {
          f.deleteSync();
          total -= size;
          if (dot > 0) _paths.remove(name.substring(0, dot));
        } catch (_) {/* skip and keep going */}
      }
    } catch (e) {
      debugPrint('VideoFileCache sweep failed: $e');
    }
  }

  @visibleForTesting
  void debugReset() {
    _paths.clear();
    _pending.clear();
    _waiting.clear();
    _active = 0;
    _dir = null;
    _indexed = false;
    _swept = false;
  }
}
