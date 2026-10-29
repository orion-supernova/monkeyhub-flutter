import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage_platform_interface/flutter_secure_storage_platform_interface.dart';
import 'package:path_provider/path_provider.dart';

/// Secure storage for the Linux build: a private file, not the keyring.
///
/// On every other platform `flutter_secure_storage` sits on an OS store that
/// is simply there. On Linux it sits on the Secret Service over D-Bus, which
/// is only there on a desktop that runs one AND has it unlocked AND has a
/// default collection — and every way that falls short ended the same: the
/// session was gone on the next launch. A tiling WM or a minimal install with
/// no keyring daemon at all; KDE with KWallet's Secret Service off; GNOME
/// auto-login, where the login keyring stays locked; a profile with no default
/// collection, where libsecret writes into the in-memory `session` collection
/// that dies with the login. The plugin reads a locked or missing keyring as
/// "no items", `SessionStore` reads no items as signed out, and the device id
/// beside it was minted afresh every launch too, re-registering the device.
///
/// So the file is authoritative, and is the only thing written. It lives in
/// the app's XDG data folder with the folder at 0700 and the file at 0600 —
/// the same protection Telegram Desktop, Discord and Signal (without a
/// keyring) give their session, and readable only by the account that is
/// already able to run the app as you.
///
/// The keyring is read exactly once per install, to bring over what an older
/// build managed to store there, and never again. Reading it on every miss
/// would let a value the keyring kept but this file deleted — a signed-out
/// session — come back on the next launch, which is the resurrection
/// `SessionStore` exists to prevent.
class LinuxFileSecureStorage extends FlutterSecureStoragePlatform {
  LinuxFileSecureStorage({
    required FlutterSecureStoragePlatform keyring,
    Future<Directory> Function()? directory,
  })  : _keyring = keyring,
        _directory = directory ?? getApplicationSupportDirectory;

  /// The plugin's own implementation, kept only for the one-time import.
  final FlutterSecureStoragePlatform _keyring;
  final Future<Directory> Function() _directory;

  static const _fileName = 'secure_store.json';

  /// Set once the keyring has been imported, successfully or not. An import
  /// that failed (keyring locked, no daemon) is not retried: the values it
  /// would have found are the ones the app could already not read, and a
  /// retry on a later launch could restore a session that has since signed
  /// out here.
  static const _kImported = 'importedFromKeyring';

  /// Upper bound on the import. The plugin answers on the platform thread
  /// and a keyring that wants a password puts up a dialog; nobody should
  /// wait on a launch for that past this.
  static const _importTimeout = Duration(seconds: 5);

  Future<_Store>? _store;

  /// Writes are serialised so two in flight can never interleave their
  /// rename, which would let the older snapshot land last.
  Future<void> _chain = Future.value();

  /// Installs this as the process-wide implementation. A no-op anywhere but
  /// Linux.
  static void install() {
    if (defaultTargetPlatform != TargetPlatform.linux) return;
    final current = FlutterSecureStoragePlatform.instance;
    if (current is LinuxFileSecureStorage) return;
    FlutterSecureStoragePlatform.instance =
        LinuxFileSecureStorage(keyring: current);
  }

  Future<_Store> _open() => _store ??= _load().catchError((Object e) {
        // Not cached: a folder that could not be created this time (a full
        // disk, say) should be asked for again on the next call.
        _store = null;
        throw e;
      });

  Future<_Store> _load() async {
    final dir = await _directory();
    final file = File('${dir.path}/$_fileName');
    var items = <String, String>{};
    var imported = false;
    if (file.existsSync()) {
      try {
        final decoded = jsonDecode(await file.readAsString());
        if (decoded is Map<String, dynamic>) {
          final raw = decoded['items'];
          if (raw is Map) {
            items = {
              for (final e in raw.entries)
                if (e.value is String) e.key.toString(): e.value as String,
            };
          }
          imported = decoded[_kImported] == true;
        }
      } catch (e) {
        // A torn or hand-edited file is "nothing stored", not a launch that
        // dies before the login screen.
        debugPrint('LinuxFileSecureStorage: unreadable $_fileName ($e)');
      }
    }
    final store = _Store(file, items, imported: imported);
    if (!imported) {
      await _import(store);
      store.imported = true;
      await _persist(store);
    }
    return store;
  }

  /// Copies whatever the keyring holds into [store], keeping the file's own
  /// value wherever both have one. The Linux plugin keeps every key in one
  /// blob regardless of options, so a single `readAll` is the whole of it.
  Future<void> _import(_Store store) async {
    try {
      final old = await _keyring
          .readAll(options: const <String, String>{})
          .timeout(_importTimeout);
      for (final e in old.entries) {
        store.items.putIfAbsent(e.key, () => e.value);
      }
    } catch (e) {
      debugPrint('LinuxFileSecureStorage: keyring import skipped ($e)');
    }
  }

  Future<void> _persist(_Store store) {
    final next = _chain.then((_) => _writeFile(store));
    // The chain itself never fails, or one bad write would wedge every later
    // one behind it; the caller still sees its own error.
    _chain = next.catchError((_) {});
    return next;
  }

  Future<void> _writeFile(_Store store) async {
    final dir = store.file.parent;
    if (!dir.existsSync()) dir.createSync(recursive: true);
    await _chmod('700', dir.path);
    final tmp = File('${store.file.path}.tmp');
    // Created empty and narrowed BEFORE the secrets go in, so there is no
    // moment at which they sit in a file other accounts could read.
    await tmp.writeAsString('');
    await _chmod('600', tmp.path);
    await tmp.writeAsString(
      jsonEncode({
        'v': 1,
        _kImported: store.imported,
        'items': store.items,
      }),
      flush: true,
    );
    // Same folder, so the rename is atomic: a crash leaves the old file or
    // the new one, never half of either.
    await tmp.rename(store.file.path);
  }

  static Future<void> _chmod(String mode, String path) async {
    try {
      await Process.run('chmod', [mode, path]);
    } catch (_) {/* no chmod on PATH; the umask still applies */}
  }

  @override
  Future<String?> read({
    required String key,
    required Map<String, String> options,
  }) async =>
      (await _open()).items[key];

  @override
  Future<bool> containsKey({
    required String key,
    required Map<String, String> options,
  }) async =>
      (await _open()).items.containsKey(key);

  @override
  Future<Map<String, String>> readAll({
    required Map<String, String> options,
  }) async =>
      Map.of((await _open()).items);

  @override
  Future<void> write({
    required String key,
    required String value,
    required Map<String, String> options,
  }) async {
    final store = await _open();
    if (store.items[key] == value) return;
    store.items[key] = value;
    await _persist(store);
  }

  @override
  Future<void> delete({
    required String key,
    required Map<String, String> options,
  }) async {
    final store = await _open();
    if (store.items.remove(key) == null) return;
    await _persist(store);
  }

  @override
  Future<void> deleteAll({required Map<String, String> options}) async {
    final store = await _open();
    if (store.items.isEmpty) return;
    store.items.clear();
    await _persist(store);
  }
}

class _Store {
  _Store(this.file, this.items, {required this.imported});
  final File file;
  final Map<String, String> items;
  bool imported;
}
