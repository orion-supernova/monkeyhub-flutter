import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monkeyhub/backend/chat_api.dart';
import 'package:monkeyhub/media/file_url_cache.dart';
import 'package:monkeyhub/media/storage/media_image_cache.dart';
import 'package:monkeyhub/theme/basic_theme.dart';
import 'package:monkeyhub/theme/theme_scope.dart';
import 'package:monkeyhub/widgets/remote_image.dart';

/// A 1×1 PNG: the smallest thing the engine will really decode.
final _png = Uint8List.fromList(const [
  0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00, 0x00, 0x00, 0x0D,
  0x49, 0x48, 0x44, 0x52, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01,
  0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4, 0x89, 0x00, 0x00, 0x00,
  0x0D, 0x49, 0x44, 0x41, 0x54, 0x78, 0x9C, 0x63, 0xF8, 0xCF, 0xC0, 0xF0,
  0x1F, 0x00, 0x05, 0x00, 0x01, 0xFF, 0x89, 0x99, 0x3D, 0x1D, 0x00, 0x00,
  0x00, 0x00, 0x49, 0x45, 0x4E, 0x44, 0xAE, 0x42, 0x60, 0x82,
]);

/// The disk store, reduced to what matters here: one file per URL that stays
/// until somebody removes it. Starts out holding a download that was cut off.
class _Disk extends Fake implements CacheManager {
  final fs = MemoryCacheSystem();
  final Map<String, Uint8List> files = {};
  final List<String> removed = [];
  int downloads = 0;

  @override
  Stream<FileResponse> getFileStream(String url,
      {String? key, Map<String, String>? headers, bool withProgress = false}) async* {
    var bytes = files[url];
    if (bytes == null) {
      downloads++;
      bytes = files[url] = _png;
    }
    final file = await fs.createFile('$downloads-${bytes.length}');
    await file.writeAsBytes(bytes);
    yield FileInfo(file, FileSource.Cache, DateTime(2100), url);
  }

  @override
  Future<void> removeFile(String key) async {
    removed.add(key);
    files.remove(key);
  }
}

class _Api extends Fake implements ChatApi {
  int lookups = 0;
  @override
  Future<String?> getFileUrl(String storageId) async {
    lookups++;
    return 'https://h/api/storage/$storageId';
  }
}

void main() {
  setUp(() => FileUrlCache.instance.debugPersist = false);

  testWidgets('a corrupt cached copy is thrown away and fetched again',
      (tester) async {
    final disk = _Disk();
    const url = 'https://h/api/storage/avatar';
    // Half a JPEG, as a dropped connection leaves it.
    disk.files[url] = Uint8List.fromList(List.filled(64, 0xFF));
    MediaImageCache.debugUse(disk);
    final api = _Api();

    await tester.pumpWidget(ThemeScope(
      controller: ThemeController(BasicTheme.midnight()),
      child: MaterialApp(
        home: RemoteImage(storageId: 'avatar', api: api, width: 40, height: 40),
      ),
    ));

    // Decoding happens off the fake clock.
    for (var i = 0; i < 20; i++) {
      await tester.runAsync(() => Future<void>.delayed(
          const Duration(milliseconds: 20)));
      await tester.pump();
    }

    expect(disk.removed, [url], reason: 'the bad copy must leave the disk');
    expect(disk.downloads, 1, reason: 'and a fresh one must come down');
    expect(api.lookups, 2, reason: 'the URL is asked for again too');
    expect(find.byIcon(Icons.broken_image_outlined), findsNothing);
  });
}
