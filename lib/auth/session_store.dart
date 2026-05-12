import 'package:flutter_secure_storage/flutter_secure_storage.dart';

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

  final _storage = const FlutterSecureStorage(
    iOptions: IOSOptions(accessibility: KeychainAccessibility.unlocked),
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  Future<void> saveSession({
    required String userId,
    required String username,
    required String name,
  }) async {
    await _storage.write(key: _kUserId, value: userId);
    await _storage.write(key: _kUsername, value: username);
    await _storage.write(key: _kName, value: name);
  }

  Future<Session?> loadSession() async {
    final id = await _storage.read(key: _kUserId);
    if (id == null || id.isEmpty) return null;
    final username = await _storage.read(key: _kUsername) ?? '';
    final name = await _storage.read(key: _kName) ?? username;
    return Session(userId: id, username: username, name: name);
  }

  Future<void> clearSession() async {
    await _storage.delete(key: _kUserId);
    await _storage.delete(key: _kUsername);
    await _storage.delete(key: _kName);
  }

  Future<void> saveThemeId(String id) async =>
      _storage.write(key: _kThemeId, value: id);

  Future<String?> loadThemeId() async => _storage.read(key: _kThemeId);
}

class Session {
  Session({required this.userId, required this.username, required this.name});
  final String userId;
  final String username;
  final String name;
}
