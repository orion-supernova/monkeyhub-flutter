import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// One account a fresh install can continue as, read from the platform
/// account's synced credential store. [key] is a backend continue key
/// (`continueKeys.ts`); [userId] and [name] are known on Apple platforms
/// only, where the item is ours to shape.
class ContinueAccount {
  const ContinueAccount({
    required this.username,
    required this.key,
    this.userId,
    this.name,
  });
  final String username;
  final String key;
  final String? userId;
  final String? name;
}

/// How a [ContinueStore.save] ended. Only [unavailable] is worth retrying.
enum ContinueSave { saved, declined, unavailable }

/// "Continue as @name" on another device of the same Apple / Google account.
///
/// Where the key lives:
///  * iOS / macOS: one synchronizable keychain item, so iCloud Keychain carries
///    it to every device of the Apple ID. Silent both ways; the app draws its
///    own "Continue as" prompt.
///  * Android: a password credential in Google Password Manager, through
///    `ContinueCredentialBridge.kt`. The system draws both prompts: "Save
///    password?" when stored, and the "Sign in as" sheet when read, which is
///    itself the continue question.
///  * Everywhere else: nothing. Web, Windows and Linux have no synced store
///    the app can reach, so they keep the QR / password paths.
class ContinueStore {
  ContinueStore._();
  static final ContinueStore instance = ContinueStore._();

  static const _kItem = 'mh.continue';
  static const _channel = MethodChannel('monkeyhub/continue_credential');

  // NOT `_this_device` accessibility: device-bound items never sync.
  static const _apple = FlutterSecureStorage(
    iOptions: IOSOptions(
      synchronizable: true,
      accessibility: KeychainAccessibility.first_unlock,
    ),
    mOptions: MacOsOptions(
      synchronizable: true,
      accessibility: KeychainAccessibility.first_unlock,
    ),
  );

  bool get _isApple =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.iOS ||
          defaultTargetPlatform == TargetPlatform.macOS);

  bool get _isAndroid =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  /// Whether this platform can carry a key to the account's other devices.
  bool get supported => _isApple || _isAndroid;

  /// Most accounts the Apple item remembers: siblings sharing one Apple ID.
  static const maxAccounts = 5;

  Future<List<ContinueAccount>> _readApple() async {
    final raw = await _apple.read(key: _kItem);
    if (raw == null) return const [];
    final list = (jsonDecode(raw) as Map)['accounts'] as List? ?? const [];
    return [
      for (final e in list.cast<Map>())
        if (e['username'] is String && e['key'] is String)
          ContinueAccount(
            username: e['username'] as String,
            key: e['key'] as String,
            userId: e['userId'] as String?,
            name: e['name'] as String?,
          ),
    ];
  }

  Future<void> _writeApple(List<ContinueAccount> accounts) async {
    if (accounts.isEmpty) {
      await _apple.delete(key: _kItem);
      return;
    }
    await _apple.write(
      key: _kItem,
      value: jsonEncode({
        'accounts': [
          for (final a in accounts)
            {
              'userId': a.userId,
              'username': a.username,
              'name': a.name,
              'key': a.key,
            },
        ],
      }),
    );
  }

  /// Accounts this device can continue as.
  ///
  /// Apple: every remembered account, silently; the caller asks the person.
  /// Android: shows the system "Sign in as" sheet, so call it only while the
  /// sign-in screen is up. What comes back is the one the person PICKED (the
  /// sheet was the question), or nothing when they dismissed it.
  Future<List<ContinueAccount>> find() async {
    try {
      if (_isApple) return await _readApple();
      if (_isAndroid) {
        final res = await _channel.invokeMapMethod<String, dynamic>('get');
        final username = res?['username'] as String?;
        final key = res?['key'] as String?;
        if (username == null || key == null) return const [];
        return [ContinueAccount(username: username, key: key)];
      }
    } catch (e) {
      debugPrint('[continue] find failed: $e');
    }
    return const [];
  }

  /// Whether the Apple item already holds a key for [userId], without UI. A
  /// signed-in device skips minting when it does.
  Future<bool> hasApple(String userId) async {
    if (!_isApple) return false;
    try {
      return (await _readApple()).any((a) => a.userId == userId);
    } catch (_) {
      return false;
    }
  }

  /// Stores [account], replacing any older key for the same account.
  Future<ContinueSave> save(ContinueAccount account) async {
    try {
      if (_isApple) {
        final rest = (await _readApple())
            .where((a) =>
                a.userId != account.userId && a.username != account.username)
            .toList();
        await _writeApple([account, ...rest].take(maxAccounts).toList());
        return ContinueSave.saved;
      }
      if (_isAndroid) {
        final r = await _channel.invokeMethod<String>('save', {
          'username': account.username,
          'key': account.key,
        });
        return switch (r) {
          'saved' => ContinueSave.saved,
          'declined' => ContinueSave.declined,
          _ => ContinueSave.unavailable,
        };
      }
    } catch (e) {
      debugPrint('[continue] save failed: $e');
    }
    return ContinueSave.unavailable;
  }

  /// Forgets one account on every device of the Apple ID: a refused key, or a
  /// child phone handed back. Android has no API to delete a saved password;
  /// a dead key there is refused by the backend and replaced by the next save.
  Future<void> remove({String? userId, required String username}) async {
    if (!_isApple) return;
    try {
      await _writeApple((await _readApple())
          .where((a) =>
              !(a.username == username ||
                  (userId != null && a.userId == userId)))
          .toList());
    } catch (_) {}
  }
}
