import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show debugPrint, visibleForTesting;

/// The per-user override of the `monkeyhub` icon-theme entry, which is how a
/// chosen app icon reaches the Linux dock and launcher.
///
/// GNOME, KDE and every other shell draw a running app's dock entry and the
/// launcher from the `.desktop` file's `Icon=monkeyhub`, resolved through the
/// icon theme, not from anything the window sets. The tarball and the AUR
/// package install that icon system-wide (`/usr/share/icons/hicolor/512x512`),
/// so the override goes where the spec ranks it above the system copy:
/// `$XDG_DATA_HOME/icons/hicolor/<size>/apps/monkeyhub.png`. It also survives
/// the app quitting, which is the point: the dock keeps the chosen icon.
///
/// Choosing the original icon deletes the override and the system copy shows
/// again. Nothing here ever writes outside the user's own data directory.
class LinuxLauncherIcon {
  LinuxLauncherIcon({String? dataHome, String? stateHome})
      : dataHome = dataHome ?? _defaultDataHome(),
        stateHome = stateHome ?? _defaultStateHome();

  final String dataHome;
  final String stateHome;

  /// Sizes written. 512 matches what the app ships; 256 makes the override win
  /// for the mid-size lookups too (the theme picks the closest size across
  /// both directories, so a lone 512 would lose to a system 256 or 128).
  static const sizes = <int>[256, 512];

  static const iconName = 'monkeyhub';

  static String _home() => Platform.environment['HOME'] ?? '';

  static String _defaultDataHome() {
    final x = Platform.environment['XDG_DATA_HOME'];
    return (x != null && x.startsWith('/')) ? x : '${_home()}/.local/share';
  }

  static String _defaultStateHome() {
    final x = Platform.environment['XDG_STATE_HOME'];
    return (x != null && x.startsWith('/')) ? x : '${_home()}/.local/state';
  }

  String get _hicolor => '$dataHome/icons/hicolor';

  /// Where the override for [size] lives.
  String pathFor(int size) => '$_hicolor/${size}x$size/apps/$iconName.png';

  File get _marker => File('$stateHome/monkeyhub/launcher_icon_name');

  /// The icon name the override files currently hold, or null for none.
  Future<String?> installedName() async {
    try {
      if (!await _marker.exists()) return null;
      final name = (await _marker.readAsString()).trim();
      if (name.isEmpty) return null;
      for (final s in sizes) {
        if (!await File(pathFor(s)).exists()) return null;
      }
      return name;
    } catch (_) {
      return null;
    }
  }

  /// The installed 512 px PNG, for re-applying at launch without re-rendering.
  Future<Uint8List?> installedPng() async {
    try {
      return await File(pathFor(512)).readAsBytes();
    } catch (_) {
      return null;
    }
  }

  /// Writes [pngBySize] (size -> PNG bytes) as the override for [name].
  Future<bool> install(String name, Map<int, Uint8List> pngBySize) async {
    try {
      for (final entry in pngBySize.entries) {
        final target = File(pathFor(entry.key));
        await target.parent.create(recursive: true);
        // Written beside, then renamed over: a dock reading mid-write sees the
        // old icon or the new one, never half a PNG.
        final tmp = File('${target.path}.tmp');
        await tmp.writeAsBytes(entry.value, flush: true);
        await tmp.rename(target.path);
      }
      await _marker.parent.create(recursive: true);
      await _marker.writeAsString(name, flush: true);
      await _refreshThemeCache();
      return true;
    } catch (e) {
      debugPrint('[launcher_icon] linux install failed: $e');
      return false;
    }
  }

  /// Removes the override so the system icon shows again. Idempotent.
  Future<void> remove() async {
    var removed = false;
    try {
      for (final s in sizes) {
        final f = File(pathFor(s));
        if (await f.exists()) {
          await f.delete();
          removed = true;
        }
      }
      if (await _marker.exists()) await _marker.delete();
    } catch (e) {
      debugPrint('[launcher_icon] linux remove failed: $e');
    }
    if (removed) await _refreshThemeCache();
  }

  /// Nudges whatever caches the user's icon theme. Best effort: a missing
  /// `touch` or `gtk-update-icon-cache` just means the dock picks the change
  /// up on its next rescan.
  Future<void> _refreshThemeCache() async {
    try {
      final cache = File('$_hicolor/icon-theme.cache');
      // A cache older than the directory is ignored by GTK, so bumping the
      // directory's mtime is what invalidates it. Touching is enough; the
      // user's hicolor has no index.theme of its own to rebuild a cache from.
      await _run(['touch', _hicolor]);
      for (final s in sizes) {
        await _run(['touch', '$_hicolor/${s}x$s']);
      }
      if (await cache.exists() && await File('$_hicolor/index.theme').exists()) {
        await _run(['gtk-update-icon-cache', '-f', '-t', _hicolor]);
      } else if (await cache.exists()) {
        // A stale cache with no index to rebuild it from would pin the old
        // icon; GTK falls back to scanning the directory without it.
        await cache.delete();
      }
    } catch (e) {
      debugPrint('[launcher_icon] linux cache refresh failed: $e');
    }
  }

  @visibleForTesting
  static Future<ProcessResult> Function(List<String> argv) runner = (argv) =>
      Process.run(argv.first, argv.skip(1).toList()).timeout(
        const Duration(seconds: 5),
      );

  Future<void> _run(List<String> argv) async {
    try {
      await runner(argv);
    } catch (_) {}
  }
}
