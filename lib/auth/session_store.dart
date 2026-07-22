import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../models/family.dart';

/// Mirrors v02's `KeychainService`. Stores `userId` / `username` / `themeId`
/// in the platform secure store so sessions survive across reinstalls
/// (matches v02 behavior — Keychain is not cleared on uninstall).
class SessionStore {
  SessionStore._();
  static final SessionStore instance = SessionStore._();

  static const _kUserId = 'mh.userId';
  static const _kUsername = 'mh.username';
  static const _kName = 'mh.name';
  static const _kThemeId = 'mh.themeId';
  static const _kAccountType = 'mh.accountType';
  static const _kChildDevice = 'mh.isChildDevice';

  final _storage = const FlutterSecureStorage(
    iOptions: IOSOptions(accessibility: KeychainAccessibility.unlocked),
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  /// Sticky marker that this handset belongs to a child.
  ///
  /// This is what stands in for OS-level family detection, which no platform
  /// exposes portably — iOS gates it behind the Family Controls entitlement
  /// and Android's Family Link has no public API at all. Once a device has
  /// been paired as a child device the flag stays put, so the login screen
  /// offers only the pairing path on every later launch — even after the
  /// child signs out or the session is cleared.
  ///
  /// Cached in memory so `LoginScreen` can branch synchronously on first
  /// frame instead of flashing the adult form. Populated by [loadSession].
  bool _isChildDevice = false;
  bool get isChildDevice => _isChildDevice;

  Future<void> saveSession({
    required String userId,
    required String username,
    required String name,
    AccountType accountType = AccountType.adult,
  }) async {
    await _storage.write(key: _kUserId, value: userId);
    await _storage.write(key: _kUsername, value: username);
    await _storage.write(key: _kName, value: name);
    await _storage.write(key: _kAccountType, value: accountType.wire);
    if (accountType == AccountType.child) await markChildDevice();
  }

  Future<Session?> loadSession() async {
    // Read the marker first — the login screen needs it even when there is
    // no session left to restore.
    _isChildDevice = (await _storage.read(key: _kChildDevice)) == 'true';
    final id = await _storage.read(key: _kUserId);
    if (id == null || id.isEmpty) return null;
    final username = await _storage.read(key: _kUsername) ?? '';
    final name = await _storage.read(key: _kName) ?? username;
    final type = AccountTypeWire.parse(await _storage.read(key: _kAccountType));
    if (type == AccountType.child) _isChildDevice = true;
    return Session(
      userId: id,
      username: username,
      name: name,
      accountType: type,
    );
  }

  Future<void> markChildDevice() async {
    _isChildDevice = true;
    await _storage.write(key: _kChildDevice, value: 'true');
  }

  /// Deliberately NOT called by [clearSession] — a child signing out (which
  /// the UI doesn't offer, but a guardian unpairing does) must still land on
  /// the pairing screen rather than the adult login form. Only a guardian
  /// releasing the device should reach for this.
  Future<void> clearChildDevice() async {
    _isChildDevice = false;
    await _storage.delete(key: _kChildDevice);
  }

  Future<void> clearSession() async {
    await _storage.delete(key: _kUserId);
    await _storage.delete(key: _kUsername);
    await _storage.delete(key: _kName);
    await _storage.delete(key: _kAccountType);
  }

  Future<void> saveThemeId(String id) async =>
      _storage.write(key: _kThemeId, value: id);

  Future<String?> loadThemeId() async => _storage.read(key: _kThemeId);
}

class Session {
  Session({
    required this.userId,
    required this.username,
    required this.name,
    this.accountType = AccountType.adult,
  });
  final String userId;
  final String username;
  final String name;
  final AccountType accountType;

  bool get isChild => accountType == AccountType.child;
}
