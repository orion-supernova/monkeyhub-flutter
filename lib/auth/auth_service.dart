import 'package:flutter/foundation.dart';

import '../backend/chat_api.dart';
import '../data/cache_store.dart';
import 'session_store.dart';

/// AuthService = ConvexAuthService from v02. Wraps the Convex auth mutations
/// and keeps the local session in sync with secure storage.
class AuthService extends ChangeNotifier {
  AuthService(this._api);
  final ChatApi _api;

  Session? _session;
  Session? get session => _session;
  bool get isSignedIn => _session != null;

  Future<void> restore() async {
    _session = await SessionStore.instance.loadSession();
    notifyListeners();
  }

  Future<void> signUp({
    required String username,
    required String name,
    required String password,
    String? email,
    String? recoveryKey,
  }) async {
    final res = await _api.signup(
      username: username,
      name: name,
      password: password,
      email: email,
      recoveryKey: recoveryKey,
    );
    _session = Session(userId: res.userId, username: res.username, name: res.name);
    // Update the UI first. Persisting to flutter_secure_storage occasionally
    // stalls (first-use after install, keychain accessibility quirks, etc.)
    // and we don't want that to keep the LoginScreen → HomeShell swap from
    // happening. If persistence fails the user is still signed in for this
    // session; they'll just need to sign in again next launch.
    notifyListeners();
    _persistSession(res);
  }

  Future<void> signIn({required String username, required String password}) async {
    debugPrint('[auth] signIn: calling _api.login');
    final res = await _api.login(username: username, password: password);
    debugPrint('[auth] signIn: login returned, userId=${res.userId}');
    _session = Session(userId: res.userId, username: res.username, name: res.name);
    debugPrint('[auth] signIn: about to notifyListeners (hasListeners=$hasListeners, isSignedIn=$isSignedIn)');
    notifyListeners();
    debugPrint('[auth] signIn: notifyListeners returned');
    _persistSession(res);
    debugPrint('[auth] signIn: _persistSession scheduled, returning');
  }

  void _persistSession(AuthResult res) {
    SessionStore.instance
        .saveSession(
          userId: res.userId,
          username: res.username,
          name: res.name,
        )
        .catchError((_) {/* see signIn docs */});
  }

  /// Resets the password using a recovery phrase. On success, signs the user
  /// in immediately (mirrors the Convex `resetPasswordWithRecoveryKey` return
  /// shape, which is identical to login).
  Future<void> resetPasswordWithRecoveryKey({
    required String username,
    required String recoveryKey,
    required String newPassword,
  }) async {
    final res = await _api.resetPassword(
      username: username,
      recoveryKey: recoveryKey,
      newPassword: newPassword,
    );
    _session = Session(userId: res.userId, username: res.username, name: res.name);
    notifyListeners();
    _persistSession(res);
  }

  Future<void> signOut() async {
    final s = _session;
    if (s != null) {
      try {
        await _api.logout(userId: s.userId);
      } catch (_) {}
    }
    await SessionStore.instance.clearSession();
    _session = null;
    notifyListeners();
  }

  Future<void> deleteAccount() async {
    final s = _session;
    if (s != null) {
      await _api.deleteAccount(userId: s.userId);
      // Account is gone — no reason to keep cached rooms/messages around.
      await CacheStore.instance.clearFor(s.userId);
    }
    await SessionStore.instance.clearSession();
    _session = null;
    notifyListeners();
  }
}
