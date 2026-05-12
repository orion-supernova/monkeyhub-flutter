import 'package:flutter/foundation.dart';

import '../backend/chat_api.dart';
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
    await SessionStore.instance.saveSession(
      userId: res.userId,
      username: res.username,
      name: res.name,
    );
    try {
      await _api.updateStatus(userId: res.userId, status: 'online');
    } catch (_) {}
    notifyListeners();
  }

  Future<void> signIn({required String username, required String password}) async {
    final res = await _api.login(username: username, password: password);
    _session = Session(userId: res.userId, username: res.username, name: res.name);
    await SessionStore.instance.saveSession(
      userId: res.userId,
      username: res.username,
      name: res.name,
    );
    try {
      await _api.updateStatus(userId: res.userId, status: 'online');
    } catch (_) {}
    notifyListeners();
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
    }
    await SessionStore.instance.clearSession();
    _session = null;
    notifyListeners();
  }
}
