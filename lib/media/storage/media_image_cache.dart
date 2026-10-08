import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:path_provider/path_provider.dart';

import 'data_usage_store.dart';
import 'gallery_autosave.dart';
import 'media_ledger.dart';
import 'storage_kinds.dart';

/// A [FileService] that counts what it downloads and reports each finished
/// file.
///
/// The image cache's network layer is the only place every image byte passes
/// through, avatars and link previews included, so this is where photo data
/// usage is measured and where a newly cached photo is filed in the ledger.
class CountingFileService extends HttpFileService {
  CountingFileService({required this.kindFor, this.onDone});

  /// The usage kind of the file at a URL.
  final UsageKind Function(String url) kindFor;

  /// Called once a file has fully arrived, with its URL.
  final void Function(String url)? onDone;

  @override
  Future<FileServiceResponse> get(String url,
      {Map<String, String>? headers}) async {
    final inner = await super.get(url, headers: headers);
    return _CountingResponse(inner, url, this);
  }
}

class _CountingResponse implements FileServiceResponse {
  _CountingResponse(this._inner, this._url, this._service);

  final FileServiceResponse _inner;
  final String _url;
  final CountingFileService _service;

  @override
  Stream<List<int>> get content {
    final kind = _service.kindFor(_url);
    var pending = 0;
    // Recorded in slices rather than per chunk: a photo arrives in a few
    // hundred chunks and the store need not hear about each one.
    void drain() {
      if (pending == 0) return;
      DataUsageStore.instance.record(kind, received: pending);
      pending = 0;
    }

    return _inner.content.transform(
      StreamTransformer<List<int>, List<int>>.fromHandlers(
        handleData: (chunk, sink) {
          pending += chunk.length;
          if (pending > 256 * 1024) drain();
          sink.add(chunk);
        },
        handleError: (e, st, sink) {
          drain();
          sink.addError(e, st);
        },
        handleDone: (sink) {
          drain();
          sink.close();
          // The cache manager writes the file as the stream completes; the
          // callback looks it up a beat later.
          if (_inner.statusCode == 200) _service.onDone?.call(_url);
        },
      ),
    );
  }

  @override
  int? get contentLength => _inner.contentLength;
  @override
  int get statusCode => _inner.statusCode;
  @override
  DateTime get validTill => _inner.validTill;
  @override
  String? get eTag => _inner.eTag;
  @override
  String get fileExtension => _inner.fileExtension;
}

/// The disk store for every image the app fetches from its own storage:
/// photos, video posters, avatars, room covers and pack stickers.
///
/// Its own store rather than flutter_cache_manager's default one, whose
/// limits (200 files, 30 days) quietly decided what stayed cached. The
/// limits here are deliberately loose; what is kept is the user's call, made
/// in Data and Storage and carried out by `StorageService`.
class MediaImageCache {
  MediaImageCache._();

  static const storeKey = 'mh_images_v1';

  /// URL → storage id, learned from [bind] as each image resolves its URL.
  /// In memory only: it exists to file a download that is in flight now.
  static final Map<String, String> _idByUrl = {};

  static CacheManager? _manager;

  static CacheManager get manager => _manager ??= CacheManager(Config(
        storeKey,
        stalePeriod: const Duration(days: 365),
        maxNrOfCacheObjects: 50000,
        fileService: CountingFileService(
          kindFor: (url) {
            final id = _idByUrl[url];
            final kind = id == null ? null : MediaLedger.instance[id]?.kind;
            return UsageKind.of(kind ?? StorageKind.other);
          },
          onDone: _filed,
        ),
      ));

  /// Says that [url] serves [storageId], so a download of it can be filed.
  static void bind(String url, String storageId) {
    if (_idByUrl.length > 4000) _idByUrl.clear();
    _idByUrl[url] = storageId;
  }

  static void _filed(String url) {
    final id = _idByUrl[url] ?? url;
    final entry = MediaLedger.instance.markLocal(id, url: url);
    // The manager commits the file after the stream closes, so its name is
    // looked up a beat later; the ledger keeps it so the storage scan can
    // size every photo with a stat.
    final path = Future<void>.delayed(const Duration(milliseconds: 300))
        .then((_) => manager.getFileFromCache(url))
        .then((info) {
      final p = info?.file.path;
      if (p != null) {
        MediaLedger.instance
            .markLocal(id, url: url, file: p.split(Platform.pathSeparator).last);
      }
      return p;
    }).catchError((Object _) => null);
    if (entry.kind == StorageKind.photos) {
      unawaited(GalleryAutoSave.instance.offerPhoto(entry, () => path));
    } else {
      unawaited(path);
    }
  }

  /// Where this store keeps its files: flutter_cache_manager's default file
  /// system puts each store in its own folder under the temp directory.
  static Future<Directory?> directory() async {
    if (kIsWeb) return null;
    try {
      final d = Directory('${(await getTemporaryDirectory()).path}/$storeKey');
      return d.existsSync() ? d : null;
    } catch (_) {
      return null;
    }
  }

  /// Removes one image by the URL it was cached under.
  static Future<void> remove(String url) async {
    try {
      await manager.removeFile(url);
    } catch (e) {
      debugPrint('MediaImageCache.remove failed: $e');
    }
  }

  /// Size of the cached file for [url], or null when it is not on disk.
  static Future<({String path, int bytes})?> stat(String url) async {
    try {
      final info = await manager.getFileFromCache(url);
      if (info == null) return null;
      final f = info.file;
      if (!await f.exists()) return null;
      return (path: f.path, bytes: await f.length());
    } catch (_) {
      return null;
    }
  }

  static Future<void> clear() async {
    try {
      await manager.emptyCache();
    } catch (e) {
      debugPrint('MediaImageCache.clear failed: $e');
    }
  }

  @visibleForTesting
  static void debugUse(CacheManager m) => _manager = m;
}
