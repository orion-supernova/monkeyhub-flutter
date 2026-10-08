import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

/// A JSON document in Application Support, written behind a debounce.
///
/// For state that changes often and is cheap to lose a few seconds of: the
/// media ledger and the data usage counters. The keychain that holds settings
/// is the wrong home for either; they churn on every download.
///
/// Application Support rather than Caches: this is the index OF the cache, and
/// the OS purging it would orphan every file it describes. Rather than
/// Documents: nothing here belongs in an iCloud backup.
class JsonFile {
  JsonFile(this.name, {this.debounce = const Duration(seconds: 2)});

  final String name;
  final Duration debounce;

  /// Overrides the directory so tests never touch a platform channel.
  @visibleForTesting
  Directory? debugDir;

  Timer? _timer;
  Object? Function()? _pendingSnapshot;
  Future<void> _writing = Future.value();

  Future<File?> _file() async {
    if (kIsWeb) return null;
    final dir = debugDir ?? await getApplicationSupportDirectory();
    if (!dir.existsSync()) await dir.create(recursive: true);
    return File('${dir.path}/$name');
  }

  /// The stored document, or null when there is none or it is unreadable.
  Future<Object?> read() async {
    try {
      final f = await _file();
      if (f == null || !f.existsSync()) return null;
      return jsonDecode(await f.readAsString());
    } catch (e) {
      debugPrint('JsonFile($name) read failed, starting empty: $e');
      return null;
    }
  }

  /// Writes what [snapshot] returns, once things have been quiet for
  /// [debounce]. Taking a closure rather than a value means a burst of a
  /// hundred changes serialises once, at the end.
  void schedule(Object? Function() snapshot) {
    _pendingSnapshot = snapshot;
    _timer?.cancel();
    _timer = Timer(debounce, flush);
  }

  /// Writes now. Through a temp file and a rename, so a kill mid-write leaves
  /// the previous document rather than half of a new one.
  Future<void> flush() {
    _timer?.cancel();
    _timer = null;
    final snap = _pendingSnapshot;
    _pendingSnapshot = null;
    if (snap == null) return _writing;
    return _writing = _writing.then((_) async {
      try {
        final f = await _file();
        if (f == null) return;
        final tmp = File('${f.path}.tmp');
        await tmp.writeAsString(jsonEncode(snap()), flush: true);
        await tmp.rename(f.path);
      } catch (e) {
        debugPrint('JsonFile($name) write failed: $e');
      }
    });
  }

  Future<void> delete() async {
    _timer?.cancel();
    _timer = null;
    _pendingSnapshot = null;
    await _writing;
    try {
      final f = await _file();
      if (f != null && f.existsSync()) await f.delete();
    } catch (_) {}
  }
}
