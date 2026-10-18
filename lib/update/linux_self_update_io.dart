import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';

import 'version_compare.dart';

/// The tarball build's in-place updater: fetch the current tarball, check it
/// against the hash deploy.sh recorded, swap the install folder, relaunch.
///
/// Only for a copy the user unpacked somewhere they own. The AUR package lives
/// in `/opt/monkeyhub`, which belongs to pacman; replacing it from under the
/// package manager would leave pacman's file list describing a different
/// build. [supported] is false there (the folder's parent isn't writable), and
/// the caller falls back to the download page, whose Linux card has the
/// `yay -S monkeyhub-bin` line.
///
/// The swap is two renames inside one parent folder, so it is atomic per step
/// and needs no extra disk beyond the download: the running process keeps its
/// mapped files after its folder is renamed, and exits immediately after.
class LinuxSelfUpdate {
  const LinuxSelfUpdate._();

  /// Mirrors HOSTING_URL in deploy.sh, which writes `artifacts.json` there
  /// on every Linux upload (`dl_manifest_put`).
  static const _downloads = 'https://monkeyhub.walhallaa.com/downloads';

  static const _staging = '.monkeyhub-update';
  static const _previous = '.previous';

  /// The folder holding the running binary, `/proc/self/exe` resolved —
  /// through the `/usr/bin` symlink too, which is how Flutter itself finds
  /// `data/` and `lib/`.
  static Directory? _installDir() {
    try {
      return File(
        File('/proc/self/exe').resolveSymbolicLinksSync(),
      ).parent;
    } catch (_) {
      return null;
    }
  }

  /// Whether this install can replace itself: Linux, and a parent folder we
  /// may create and rename entries in. Probed by actually writing, because
  /// mode bits don't account for read-only mounts or ACLs.
  static bool get supported {
    if (defaultTargetPlatform != TargetPlatform.linux) return false;
    final dir = _installDir();
    if (dir == null) return false;
    final probe = File('${dir.parent.path}/.monkeyhub-write-probe-$pid');
    try {
      probe.writeAsStringSync('');
      probe.deleteSync();
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Downloads, verifies and installs the current build, then relaunches into
  /// it. Never returns on success (the process exits). False on any failure,
  /// with the old install left exactly where it was.
  static Future<bool> run({void Function(double progress)? onProgress}) async {
    if (!supported) return false;
    final install = _installDir()!;
    final parent = install.parent.path;
    final staging = Directory('$parent/$_staging');
    try {
      final current = (await PackageInfo.fromPlatform()).version;
      final entry = await _manifestEntry();
      if (entry == null) return false;
      if (compareVersions(entry.version, current) <= 0) return false;

      if (staging.existsSync()) staging.deleteSync(recursive: true);
      staging.createSync();
      final tarball = File('${staging.path}/update.tar.gz');
      final digest = await _download(
        Uri.parse('$_downloads/${Uri.encodeComponent(entry.file)}'),
        tarball,
        onProgress,
      );
      if (digest != entry.sha256) {
        debugPrint('LINUX UPDATE: checksum mismatch, refusing ${entry.file}');
        return false;
      }

      final tar = await Process.run(
        'tar',
        ['-xzf', tarball.path, '-C', staging.path],
      );
      if (tar.exitCode != 0) {
        debugPrint('LINUX UPDATE: tar failed: ${tar.stderr}');
        return false;
      }
      // The tarball's single top-level folder (desktop.yml stages it as
      // `monkeyhub/`), holding a binary named like the running one.
      final unpacked = Directory('${staging.path}/monkeyhub');
      final exeName =
          File('/proc/self/exe').resolveSymbolicLinksSync().split('/').last;
      final newExe = File('${unpacked.path}/$exeName');
      if (!newExe.existsSync()) {
        debugPrint('LINUX UPDATE: no $exeName in the tarball');
        return false;
      }

      final previous = Directory('${install.path}$_previous');
      if (previous.existsSync()) previous.deleteSync(recursive: true);
      install.renameSync(previous.path);
      try {
        unpacked.renameSync(install.path);
      } catch (e) {
        // Put the old build back before reporting; a half-swapped install is
        // the one outcome worse than not updating.
        previous.renameSync(install.path);
        rethrow;
      }

      await Process.start(
        '${install.path}/$exeName',
        const [],
        mode: ProcessStartMode.detached,
      );
      exit(0);
    } catch (e) {
      debugPrint('LINUX UPDATE failed: $e');
      return false;
    }
  }

  /// Clears what a previous update left behind: the replaced build and any
  /// half-finished download. Called once per launch, which is the first moment
  /// the old folder is no longer in use.
  static void sweep() {
    if (defaultTargetPlatform != TargetPlatform.linux) return;
    final install = _installDir();
    if (install == null) return;
    for (final path in [
      '${install.path}$_previous',
      '${install.parent.path}/$_staging',
    ]) {
      try {
        final d = Directory(path);
        if (d.existsSync()) d.deleteSync(recursive: true);
      } catch (_) {
        // Not ours to delete (another user's install) or already gone.
      }
    }
  }

  static Future<({String file, String version, String sha256})?>
      _manifestEntry() async {
    final client = HttpClient()..connectionTimeout = const Duration(seconds: 15);
    try {
      final req = await client.getUrl(Uri.parse('$_downloads/artifacts.json'));
      final res = await req.close();
      if (res.statusCode != 200) return null;
      final body = await res.transform(utf8.decoder).join();
      final linux = (jsonDecode(body) as Map<String, dynamic>)['linux'];
      if (linux is! Map) return null;
      final file = linux['file'], version = linux['version'], sha = linux['sha256'];
      // No hash, no install: a tarball we can't verify is not something to
      // replace a working app with. Older manifest rows predate the field and
      // fall back to the download page until the next Linux deploy.
      if (file is! String || version is! String || sha is! String) return null;
      if (file.contains('/') || file.contains('..')) return null;
      return (file: file, version: version, sha256: sha.toLowerCase());
    } finally {
      client.close(force: true);
    }
  }

  /// Streams [uri] into [out], reporting progress, and returns the SHA-256 of
  /// what was written.
  static Future<String> _download(
    Uri uri,
    File out,
    void Function(double progress)? onProgress,
  ) async {
    final client = HttpClient()..connectionTimeout = const Duration(seconds: 15);
    try {
      final res = await (await client.getUrl(uri)).close();
      if (res.statusCode != 200) {
        throw HttpException('HTTP ${res.statusCode}', uri: uri);
      }
      final total = res.contentLength;
      final sink = out.openWrite();
      final hash = _DigestSink();
      final hasher = sha256.startChunkedConversion(hash);
      var received = 0;
      await for (final chunk in res) {
        sink.add(chunk);
        hasher.add(chunk);
        received += chunk.length;
        if (total > 0) onProgress?.call(received / total);
      }
      await sink.close();
      hasher.close();
      return hash.value.toString();
    } finally {
      client.close(force: true);
    }
  }
}

class _DigestSink implements Sink<Digest> {
  late Digest value;

  @override
  void add(Digest data) => value = data;

  @override
  void close() {}
}
