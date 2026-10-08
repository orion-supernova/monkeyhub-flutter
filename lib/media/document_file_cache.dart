import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

import 'file_url_cache.dart';
import 'storage/data_usage_store.dart';
import 'storage/media_ledger.dart';
import 'storage/storage_kinds.dart';

/// Keeps received documents on disk, so opening one twice costs one download
/// and a file auto-download fetched opens instantly.
///
/// Before this every tap on a document re-fetched the whole thing into memory
/// and handed it to the share sheet. Shaped after [AudioFileCache] and
/// [VideoFileCache]: a singleton, one in-flight download per id, write to
/// `.part` then rename, files named by storage id so the storage screen can
/// tell which message each belongs to. The extension is the sender's, so a
/// path handed to a native previewer still says what the file is.
class DocumentFileCache {
  DocumentFileCache._();
  static final DocumentFileCache instance = DocumentFileCache._();

  /// The folder under the app's cache directory, for the storage scan.
  static const dirName = 'mh_files_v1';
  static const _timeout = Duration(minutes: 5);
  static final _safeId = RegExp(r'^[A-Za-z0-9_-]{1,64}$');
  static final _safeExt = RegExp(r'^\.[A-Za-z0-9]{1,8}$');

  final Map<String, Future<String>> _pending = {};
  Directory? _dir;

  @visibleForTesting
  Directory? debugDir;

  Future<Directory> _directory() async {
    final override = debugDir;
    if (override != null) return override;
    final cached = _dir;
    if (cached != null) return cached;
    // Library/Caches, for the reason the media caches give: re-downloadable
    // bytes have no business in an iCloud backup.
    final base = await getApplicationCacheDirectory();
    final dir = Directory('${base.path}/$dirName');
    if (!dir.existsSync()) await dir.create(recursive: true);
    return _dir = dir;
  }

  static String _extOf(String? fileName) {
    if (fileName == null) return '';
    final dot = fileName.lastIndexOf('.');
    if (dot < 0) return '';
    final ext = fileName.substring(dot);
    return _safeExt.hasMatch(ext) ? ext.toLowerCase() : '';
  }

  /// The local copy of [storageId], or null. Never downloads.
  Future<String?> lookup(String storageId) async {
    if (kIsWeb || !_safeId.hasMatch(storageId)) return null;
    try {
      final dir = await _directory();
      for (final e in dir.listSync()) {
        if (e is! File || e.path.endsWith('.part')) continue;
        if (idOf(e) == storageId) return e.path;
      }
    } catch (_) {}
    return null;
  }

  /// Path to a local copy of [storageId], downloading on a miss. Throws
  /// [FileTooLarge] past [maxBytes], [FileUnavailable] when there is no URL.
  Future<String> resolve(
    String storageId,
    Future<String?> Function() url, {
    String? fileName,
    int? maxBytes,
    void Function(int received, int? total)? onProgress,
  }) {
    if (kIsWeb) throw UnsupportedError('DocumentFileCache is native-only');
    if (!_safeId.hasMatch(storageId)) {
      return Future.error(ArgumentError.value(storageId, 'storageId', 'unsafe'));
    }
    final inFlight = _pending[storageId];
    if (inFlight != null) return inFlight;
    final future = () async {
      final hit = await lookup(storageId);
      if (hit != null) return hit;
      final path =
          await _download(storageId, url, fileName, maxBytes, onProgress);
      MediaLedger.instance.markLocal(storageId, fallbackKind: StorageKind.files);
      return path;
    }()
        .whenComplete(() {
      // Braces, not an arrow: see the same note in VideoFileCache.
      _pending.remove(storageId);
    });
    _pending[storageId] = future;
    return future;
  }

  Future<String> _download(
    String storageId,
    Future<String?> Function() url,
    String? fileName,
    int? maxBytes,
    void Function(int received, int? total)? onProgress,
  ) async {
    final remote = await url();
    if (remote == null || remote.isEmpty) throw const FileUnavailable();
    final dir = await _directory();
    final part = File('${dir.path}/$storageId.part');
    final client = http.Client();
    var received = 0;
    try {
      final resp = await client
          .send(http.Request('GET', Uri.parse(remote)))
          .timeout(_timeout);
      if (resp.statusCode != 200) throw const FileUnavailable();
      final total = resp.contentLength;
      if (maxBytes != null && total != null && total > maxBytes) {
        throw FileTooLarge(total);
      }
      final sink = part.openWrite();
      try {
        await for (final chunk in resp.stream) {
          received += chunk.length;
          if (maxBytes != null && received > maxBytes) {
            throw FileTooLarge(received);
          }
          sink.add(chunk);
          onProgress?.call(received, total);
        }
        await sink.flush();
      } finally {
        await sink.close();
      }
      final path = '${dir.path}/$storageId${_extOf(fileName)}';
      await part.rename(path);
      return path;
    } catch (_) {
      try {
        if (part.existsSync()) await part.delete();
      } catch (_) {}
      rethrow;
    } finally {
      DataUsageStore.instance.record(UsageKind.files, received: received);
      client.close();
    }
  }

  static String idOf(File f) {
    final name = f.uri.pathSegments.last;
    final dot = name.indexOf('.');
    return dot > 0 ? name.substring(0, dot) : name;
  }

  Future<void> evict(String storageId) async {
    final path = await lookup(storageId);
    if (path == null) return;
    try {
      await File(path).delete();
    } catch (_) {}
  }

  Future<void> clear() async {
    _pending.clear();
    if (kIsWeb) return;
    try {
      final dir = await _directory();
      if (dir.existsSync()) await dir.delete(recursive: true);
      _dir = null;
    } catch (e) {
      debugPrint('DocumentFileCache.clear failed: $e');
    }
  }
}

/// A document bigger than the caller was willing to fetch unasked.
class FileTooLarge implements Exception {
  const FileTooLarge(this.bytes);
  final int bytes;
  @override
  String toString() => 'file too large to auto-download ($bytes bytes)';
}
