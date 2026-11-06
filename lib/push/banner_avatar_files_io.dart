import 'dart:async';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

/// Local copies of avatars for desktop banners.
///
/// A notification daemon and the Windows toast service both want a FILE, not a
/// URL, and neither shares the app's image cache. One download per URL, kept
/// in the temp directory under a hash of the URL (a new picture is a new
/// storage id, so a changed avatar is a new file and never a stale one).
class BannerAvatarFiles {
  BannerAvatarFiles._();
  static final BannerAvatarFiles instance = BannerAvatarFiles._();

  static const _maxBytes = 2 * 1024 * 1024;

  final Map<String, String> _paths = {};
  final Map<String, Future<String?>> _pending = {};
  Directory? _dir;

  /// The file for [url] if it is already on disk this session.
  String? peek(String url) => _paths[url];

  /// The file for [url], downloading it if needed. Gives up after [timeout]
  /// and returns null; the download carries on and serves the next banner.
  Future<String?> fetch(
    String url, {
    Duration timeout = const Duration(milliseconds: 800),
  }) {
    final hit = _paths[url];
    if (hit != null) return Future.value(hit);
    final job = _pending[url] ??= _download(url).whenComplete(() {
      _pending.remove(url);
    });
    return job.timeout(timeout, onTimeout: () => null);
  }

  Future<String?> _download(String url) async {
    try {
      final dir = _dir ??= await _ensureDir();
      final name = sha1.convert(url.codeUnits).toString();
      for (final ext in const ['png', 'jpg']) {
        final f = File('${dir.path}/$name.$ext');
        if (f.existsSync() && f.lengthSync() > 0) return _paths[url] = f.path;
      }
      final res =
          await http.get(Uri.parse(url)).timeout(const Duration(seconds: 15));
      final bytes = res.bodyBytes;
      if (res.statusCode != 200 || bytes.isEmpty || bytes.length > _maxBytes) {
        return null;
      }
      // The toast service and several daemons pick a decoder by extension.
      final png = bytes.length > 4 && bytes[0] == 0x89 && bytes[1] == 0x50;
      final file = File('${dir.path}/$name.${png ? 'png' : 'jpg'}');
      final tmp = File('${file.path}.part');
      await tmp.writeAsBytes(bytes, flush: true);
      await tmp.rename(file.path);
      return _paths[url] = file.path;
    } catch (e) {
      debugPrint('BannerAvatarFiles: $url: $e');
      return null;
    }
  }

  Future<Directory> _ensureDir() async {
    final root = await getTemporaryDirectory();
    return Directory('${root.path}/mh_banner_avatars').create(recursive: true);
  }
}
