import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'file_url_cache.dart';
import 'storage/data_usage_store.dart';
import 'video_file_cache.dart';

/// A video's running time for videos whose message never said.
///
/// The length on a video tile comes from `mediaDurationMs`, which the
/// SENDER's device measures. Videos sent from web or desktop, from builds
/// before the field, and down a few forward and share paths have none, so
/// their tiles showed a bare play glyph beside ones with times, and the
/// gallery looked half broken.
///
/// The time is in the file's own header: an MP4 or QuickTime file carries it
/// in the `mvhd` box inside `moov`. This reads it from the copy on disk when
/// there is one, and otherwise asks the server for just the header bytes
/// (a ranged request of tens of kilobytes, never the video). `moov` sits at
/// the start of a streaming-optimised file and at the end of a camera's raw
/// one; both are handled. Answers are kept per device, keyed by storage id,
/// so each video is probed once.
class VideoDuration {
  VideoDuration._();
  static final VideoDuration instance = VideoDuration._();

  static const _prefsKey = 'mh.videoDurations.v1';
  static const _maxEntries = 2000;
  static const _maxConcurrent = 3;

  /// Bytes fetched per ranged read: enough for a typical `moov` header, or
  /// for the box headers that say where it is.
  static const _chunk = 64 * 1024;

  final Map<String, int> _ms = {};
  final Map<String, Future<int?>> _pending = {};
  final _waiting = <Completer<void>>[];
  int _active = 0;
  bool _loaded = false;
  Timer? _flush;

  /// The known running time, synchronously, for a first frame that already
  /// shows it.
  int? peek(String storageId) => _ms[storageId];

  Future<void> load() async {
    if (_loaded) return;
    _loaded = true;
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_prefsKey);
      if (raw == null) return;
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return;
      decoded.forEach((k, v) {
        if (k is String && v is int && v > 0) _ms[k] = v;
      });
    } catch (e) {
      debugPrint('VideoDuration.load failed (continuing cold): $e');
    }
  }

  /// Finds the running time of [storageId]. Null when the file is not an MP4
  /// family container or the header could not be read.
  Future<int?> resolve(String storageId, Future<String?> Function() url) {
    final known = _ms[storageId];
    if (known != null) return SynchronousFuture(known);
    if (kIsWeb) return Future.value();
    return _pending[storageId] ??= _probe(storageId, url).whenComplete(() {
      // Braces, not an arrow: see the same note in VideoFileCache.
      _pending.remove(storageId);
    });
  }

  /// Records a time learned elsewhere (a player that opened the file).
  void remember(String storageId, int ms) {
    if (ms <= 0 || _ms[storageId] == ms) return;
    _ms[storageId] = ms;
    _schedule();
  }

  Future<int?> _probe(String id, Future<String?> Function() url) async {
    await load();
    await _acquire();
    try {
      int? ms;
      final local = await VideoFileCache.instance.lookup(id);
      if (local != null) {
        ms = await _fromFile(File(local));
      } else {
        final remote = await url();
        if (remote != null) ms = await _fromUrl(Uri.parse(remote));
      }
      if (ms != null && ms > 0) remember(id, ms);
      return ms;
    } catch (e) {
      debugPrint('VideoDuration probe $id failed: $e');
      return null;
    } finally {
      _release();
    }
  }

  Future<int?> _fromFile(File f) async {
    final raf = await f.open();
    try {
      final length = await raf.length();
      Future<Uint8List> read(int at, int n) async {
        await raf.setPosition(at);
        return raf.read(n);
      }

      return await _walk(length, read);
    } finally {
      await raf.close();
    }
  }

  Future<int?> _fromUrl(Uri uri) async {
    final client = http.Client();
    try {
      int? total;
      Future<Uint8List> read(int at, int n) async {
        final req = http.Request('GET', uri)
          ..headers['range'] = 'bytes=$at-${at + n - 1}';
        final resp =
            await client.send(req).timeout(const Duration(seconds: 15));
        if (resp.statusCode == 206) {
          final range = resp.headers['content-range'];
          final slash = range?.lastIndexOf('/') ?? -1;
          if (slash > 0) total ??= int.tryParse(range!.substring(slash + 1));
          final body = await resp.stream.toBytes();
          DataUsageStore.instance
              .record(UsageKind.videos, received: body.length);
          return body;
        }
        if (resp.statusCode != 200) return Uint8List(0);
        // A server that ignores Range sends the whole file. Read only as far
        // as asked and hang up: a header probe must never become a download.
        total ??= resp.contentLength;
        final want = at + n;
        final got = BytesBuilder(copy: false);
        await for (final chunk in resp.stream) {
          got.add(chunk);
          if (got.length >= want) break;
        }
        final bytes = got.takeBytes();
        DataUsageStore.instance
            .record(UsageKind.videos, received: bytes.length);
        final endAt = want.clamp(0, bytes.length);
        return at >= endAt ? Uint8List(0) : bytes.sublist(at, endAt);
      }

      // The first read also tells us the file's length.
      final head = await read(0, _chunk);
      final length = total ?? head.length;
      return await _walk(length, (at, n) async {
        if (at + n <= head.length) return head.sublist(at, at + n);
        return read(at, n);
      });
    } finally {
      client.close();
    }
  }

  /// Walks the top-level boxes to `moov`, then reads `mvhd` inside it.
  static Future<int?> _walk(
    int length,
    Future<Uint8List> Function(int at, int n) read,
  ) async {
    var at = 0;
    for (var guard = 0; guard < 64 && at + 8 <= length; guard++) {
      final h = await read(at, 16);
      if (h.length < 8) return null;
      final b = ByteData.sublistView(h);
      var size = b.getUint32(0);
      final type = String.fromCharCodes(h.sublist(4, 8));
      var header = 8;
      if (size == 1 && h.length >= 16) {
        size = b.getUint64(8);
        header = 16;
      } else if (size == 0) {
        size = length - at;
      }
      if (size < header) return null;
      if (type == 'moov') {
        // mvhd is the first child in every file seen in practice; read
        // enough of moov to find it wherever it is among the first few.
        final body = await read(at + header, (size - header).clamp(0, _chunk));
        return _mvhd(body);
      }
      at += size;
    }
    return null;
  }

  static int? _mvhd(Uint8List moov) {
    var at = 0;
    while (at + 8 <= moov.length) {
      final b = ByteData.sublistView(moov);
      final size = b.getUint32(at);
      final type = String.fromCharCodes(moov.sublist(at + 4, at + 8));
      if (size < 8) return null;
      if (type == 'mvhd') {
        final version = moov[at + 8];
        final int timescale;
        final int duration;
        if (version == 1) {
          if (at + 40 > moov.length) return null;
          timescale = b.getUint32(at + 28);
          duration = b.getUint64(at + 32);
        } else {
          if (at + 28 > moov.length) return null;
          timescale = b.getUint32(at + 20);
          duration = b.getUint32(at + 24);
        }
        if (timescale <= 0) return null;
        return (duration * 1000 / timescale).round();
      }
      at += size;
    }
    return null;
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

  void _schedule() {
    _flush?.cancel();
    _flush = Timer(const Duration(seconds: 2), () async {
      try {
        if (_ms.length > _maxEntries) {
          final keep = _ms.entries.skip(_ms.length - _maxEntries ~/ 2).toList();
          _ms
            ..clear()
            ..addEntries(keep);
        }
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(_prefsKey, jsonEncode(_ms));
      } catch (e) {
        debugPrint('VideoDuration flush failed: $e');
      }
    });
  }

  @visibleForTesting
  static int? debugParseMvhd(Uint8List moovBody) => _mvhd(moovBody);

  @visibleForTesting
  static Future<int?> debugWalk(Uint8List file) => _walk(
        file.length,
        (at, n) async => file.sublist(at, (at + n).clamp(0, file.length)),
      );
}

/// Duration lookups for widgets: the message's own value when it has one,
/// else whatever [VideoDuration] knows or can find.
int? knownVideoDuration(String? storageId, int? fromMessage) {
  if (fromMessage != null && fromMessage > 0) return fromMessage;
  if (storageId == null) return null;
  return VideoDuration.instance.peek(storageId);
}

/// Resolves the URL for a probe through the shared URL cache.
Future<String?> Function() videoUrlFor(
  String storageId,
  Future<String?> Function(String) getFileUrl,
) =>
    () => FileUrlCache.instance.resolve(storageId, () => getFileUrl(storageId));
