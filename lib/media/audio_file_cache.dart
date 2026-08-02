import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

import 'blob_url.dart';
import 'file_url_cache.dart';

/// Keeps a playable local copy of a stored audio file.
///
/// Voice notes rendered "audio failed" for everyone, and the reason was never
/// the bytes. Convex serves storage from an extension-less URL —
/// `<site>/api/storage/<uuid>` — and the recorder's uploads were stamped
/// `audio/m4a`, which is registered nowhere. So `just_audio.setUrl` handed iOS
/// an `AVURLAsset` with no path extension AND a content type AVFoundation's
/// MIME→UTI table doesn't know, and asset loading simply never completed.
/// Compounding it, `package:record` writes the `moov` index last, which is the
/// worst possible layout for progressive HTTP.
///
/// A stored file's contentType is fixed at upload and cannot be patched, so
/// every note sent before the fix is stamped wrong forever. Downloading the
/// bytes and writing them to `<id>.m4a` fixes all three at once: the OS infers
/// the container from the extension, the served MIME stops mattering, and a
/// complete local file makes atom order irrelevant. It also buys offline
/// playback, which streaming never had.
///
/// Shaped after [FileUrlCache] and `MediaAspectCache` — one singleton, a
/// `_pending` map so N widgets sharing an id do one download, a bounded store.
/// Unlike those two nothing is persisted to `SharedPreferences` and there is no
/// `peek`: audio is never on the first frame, so there is no synchronous read
/// worth optimising for, and the filesystem is already the persistence layer.
class AudioFileCache {
  AudioFileCache._();
  static final AudioFileCache instance = AudioFileCache._();

  static const _dirName = 'mh_audio_v1';

  /// Total bytes kept. A 10s AAC-LC note at 96 kbps is ~30 KB, so this holds
  /// several hundred — far more than anyone scrolls back through.
  static const _maxBytes = 24 * 1024 * 1024;

  /// Whole-download ceiling. Not an inactivity watchdog: a voice note is small
  /// and there is nothing useful to do with a partial one, so a flat deadline
  /// is the honest limit.
  static const _timeout = Duration(seconds: 30);

  /// Concurrent downloads. A room full of voice notes mounts every visible
  /// player at once, and letting twenty sockets race makes the one the user
  /// actually tapped the slowest of the twenty.
  static const _maxConcurrent = 3;

  /// Convex storage ids are lowercase alphanumerics, but this value becomes a
  /// path segment, so it is validated rather than trusted — a `../` in an id
  /// would otherwise write outside the cache directory.
  static final _safeId = RegExp(r'^[A-Za-z0-9_-]{1,64}$');

  final Map<String, String> _paths = {};

  /// In-flight downloads, so the note and the reply preview quoting it share
  /// one fetch instead of racing each other onto the same path.
  final Map<String, Future<String>> _pending = {};

  final _waiting = <Completer<void>>[];
  int _active = 0;
  Directory? _dir;
  bool _indexed = false;
  bool _swept = false;

  /// Overrides the cache directory so tests never touch a platform channel.
  @visibleForTesting
  Directory? debugDir;

  /// Path to a local, correctly-named copy of [storageId], downloading it on a
  /// miss via the URL that [url] resolves.
  ///
  /// Takes a URL resolver rather than a `ChatApi` so this has no opinion on
  /// where a URL comes from and is testable against a local server, matching
  /// [FileUrlCache.resolve].
  ///
  /// Throws [FileUnavailable] when the backend has no URL for the id, and
  /// [UnsupportedError] on web — there is no filesystem there, so callers use
  /// [webPlayableUrl] instead.
  Future<String> resolve(
    String storageId,
    Future<String?> Function() url, {
    http.Client? client,
  }) {
    if (kIsWeb) {
      throw UnsupportedError('AudioFileCache is native-only; use webPlayableUrl');
    }
    if (!_safeId.hasMatch(storageId)) {
      return Future.error(ArgumentError.value(storageId, 'storageId', 'unsafe'));
    }

    final known = _paths[storageId];
    if (known != null) return Future.value(known);

    final inFlight = _pending[storageId];
    if (inFlight != null) return inFlight;

    final future = _download(storageId, url, client).then((path) {
      _paths[storageId] = path;
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
      // trap is documented in FileUrlCache; it keeps coming back.
      _pending.remove(storageId);
    });

    _pending[storageId] = future;
    return future;
  }

  /// Forgets the local copy so the next [resolve] re-downloads.
  ///
  /// Called when a player rejects the file — truncated, or purged from
  /// `Library/Caches` between the resolve and the load — and from the retry
  /// affordance in `AudioMessage`.
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
      debugPrint('AudioFileCache.clear failed: $e');
    }
  }

  // ---------------------------------------------------------------- internals

  Future<Directory> _directory() async {
    final override = debugDir;
    if (override != null) return override;
    final cached = _dir;
    if (cached != null) return cached;
    // Library/Caches, not Documents (which CacheStore uses): these bytes are
    // re-downloadable, and Documents is iCloud-backed on iOS, so caching there
    // would grow the user's backup with what the server already holds. Not
    // getTemporaryDirectory either — that is purged far more aggressively.
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
        // A `.part` is a download that never finished; sweep it rather than
        // adopting it, or the retry path would keep finding a truncated file.
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
      debugPrint('AudioFileCache index failed (continuing cold): $e');
    }
  }

  Future<String> _download(
    String storageId,
    Future<String?> Function() url,
    http.Client? client,
  ) async {
    final dir = await _directory();
    await _index(dir);

    final known = _paths[storageId];
    if (known != null && File(known).existsSync()) return known;

    final remote = await url();
    if (remote == null || remote.isEmpty) throw const FileUnavailable();

    await _acquire();
    final owned = client == null;
    final c = client ?? http.Client();
    try {
      final resp = await c.get(Uri.parse(remote)).timeout(_timeout);
      if (resp.statusCode != 200) {
        throw HttpException('status ${resp.statusCode}', uri: Uri.parse(remote));
      }
      final bytes = resp.bodyBytes;
      if (bytes.length < 12) {
        throw const FormatException('audio body too short to identify');
      }

      final path = '${dir.path}/$storageId${_extensionFor(bytes)}';
      // Write to `.part` and rename. A download killed by app suspension would
      // otherwise leave a truncated file that setFilePath accepts and then
      // fails on, permanently, with no way for the user out. Rename within one
      // directory is atomic on both APFS and ext4.
      final part = File('$path.part');
      await part.writeAsBytes(bytes, flush: true);
      await part.rename(path);
      return path;
    } finally {
      if (owned) c.close();
      _release();
    }
  }

  /// The extension the OS needs to recognise these bytes, read from the
  /// container's own magic rather than from the served content type — which is
  /// the thing that was wrong in the first place, and which this whole class
  /// exists to stop trusting.
  ///
  /// Defaults to `.m4a` because that is what the recorder produces; the other
  /// cases are here so a future `record_web` opus upload doesn't get relabelled
  /// into a second version of this same bug.
  static String _extensionFor(Uint8List b) {
    String at(int i, int n) => String.fromCharCodes(b.sublist(i, i + n));
    if (at(4, 4) == 'ftyp') return '.m4a';
    if (at(0, 4) == 'OggS') return '.ogg';
    if (at(0, 4) == 'RIFF') return '.wav';
    if (at(0, 4) == '\x1a\x45\xdf\xa3') return '.webm';
    if (at(0, 3) == 'ID3' || (b[0] == 0xFF && (b[1] & 0xE0) == 0xE0)) return '.mp3';
    return '.m4a';
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
  /// rather than true LRU — a note played every day is evicted at the same age
  /// as one never played again. Acceptable: at ~30 KB a note, 24 MB is several
  /// hundred of them and nobody reaches the cap.
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
      debugPrint('AudioFileCache sweep failed: $e');
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

/// A blob URL for [remoteUrl]'s bytes, retyped so the browser recognises them.
///
/// The web has no filesystem and no path extension to lean on, so the fix there
/// is the other half of the same idea as [AudioFileCache]: fetch the bytes,
/// wrap them in a Blob carrying a MIME the browser knows, and hand
/// `just_audio_web` an object URL — it assigns straight to `element.src`.
///
/// Returns null when the bytes can't be fetched, most likely a CORS refusal
/// from the storage host, which an `<img>` or a bare `<audio src>` would never
/// have hit. The caller then falls back to the raw URL, which is what shipped
/// before and which Chrome and Firefox sniff correctly anyway.
Future<String?> webPlayableUrl(String remoteUrl, {http.Client? client}) async {
  final owned = client == null;
  final c = client ?? http.Client();
  try {
    final resp = await c
        .get(Uri.parse(remoteUrl))
        .timeout(const Duration(seconds: 30));
    if (resp.statusCode != 200) return null;
    return BlobUrl.create(resp.bodyBytes, 'audio/mp4');
  } catch (e) {
    debugPrint('webPlayableUrl fell back to the plain URL: $e');
    return null;
  } finally {
    if (owned) c.close();
  }
}

void revokeWebPlayableUrl(String objectUrl) => BlobUrl.revoke(objectUrl);
