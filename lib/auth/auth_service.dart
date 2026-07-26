import 'package:flutter/foundation.dart';

import '../backend/chat_api.dart';
import '../data/cache_store.dart';
import '../models/family.dart';
import '../push/device_identity.dart';
import 'session_store.dart';
export 'session_store.dart' show Session;

/// AuthService = ConvexAuthService from v02. Wraps the Convex auth mutations
/// and keeps the local session in sync with secure storage.
class AuthService extends ChangeNotifier {
  AuthService(this._api);
  final ChatApi _api;

  Session? _session;
  Session? get session => _session;
  bool get isSignedIn => _session != null;

  /// True when the signed-in account is supervised. Read by the UI to hide
  /// Sign Out, lock the visibility screen, and gate Discover.
  bool get isChild => _session?.isChild ?? false;

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

  /// Signs in a child device by redeeming a guardian-issued pairing code.
  /// This is the ONLY way into a child account — `auth.login` refuses them —
  /// so the six digits and this call are the whole authentication story.
  ///
  /// Marks the handset as a child device on success, which is what makes
  /// every later launch open straight into the pairing screen.
  Future<void> redeemPairingCode(String code) async {
    final deviceId = await DeviceIdentity.ensure();
    final res = await _api.redeemPairingCode(
      code: code.trim(),
      deviceId: deviceId,
      platform: DeviceIdentity.platformTag(),
      deviceName: await DeviceIdentity.displayName(),
    );
    _session = Session(
      userId: res.userId,
      username: res.username,
      name: res.name,
      accountType: AccountType.child,
    );
    notifyListeners();
    _persistSession(res, accountType: AccountType.child);
  }

  void _persistSession(
    AuthResult res, {
    AccountType accountType = AccountType.adult,
  }) {
    SessionStore.instance
        .saveSession(
          userId: res.userId,
          username: res.username,
          name: res.name,
          accountType: accountType,
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

  /// Children cannot sign themselves out — that's the whole point of a
  /// supervised device. The UI hides the button; this is the backstop so a
  /// stray call site can't strand a child on the login screen.
  Future<void> signOut() async {
    final s = _session;
    if (s == null) return;
    if (s.isChild) {
      debugPrint('[auth] signOut ignored — child accounts stay signed in');
      return;
    }
    try {
      await _api.logout(userId: s.userId);
    } catch (_) {}
    await SessionStore.instance.clearSession();
    _session = null;
    notifyListeners();
  }

  /// Hands this handset back, using a release code a guardian minted on their
  /// own device. Throws on a bad or expired code — nothing local is touched
  /// unless the server accepted it.
  Future<void> releaseChildDeviceWithCode(String code) async {
    final deviceId = await DeviceIdentity.ensure();
    await _api.releaseDeviceByCode(code: code, deviceId: deviceId);
    await releaseChildDevice();
  }

  /// Same, with a guardian's own username and password. This is the path that
  /// works on a single phone: pairing a child signs the adult out, so there is
  /// no adult session left anywhere to mint a code from.
  Future<void> releaseChildDeviceWithPassword({
    required String guardianUsername,
    required String password,
  }) async {
    final s = _session;
    if (s == null) return;
    final deviceId = await DeviceIdentity.ensure();
    await _api.releaseDeviceByGuardianPassword(
      childId: s.userId,
      guardianUsername: guardianUsername,
      password: password,
      deviceId: deviceId,
    );
    await releaseChildDevice();
  }

  /// Unpairs a child device, from the child's own handset. A guardian does
  /// this in person, having proved themselves via one of the two calls above —
  /// this is the local half and assumes that already happened.
  ///
  /// Clears the sticky child marker as well as the session, which is what
  /// makes the phone open on the adult login form afterwards rather than
  /// straight back onto the pairing screen.
  Future<void> releaseChildDevice() async {
    final s = _session;
    if (s != null) {
      try {
        await _api.logout(userId: s.userId);
      } catch (_) {}
    }
    await SessionStore.instance.clearSession();
    await SessionStore.instance.clearChildDevice();
    _session = null;
    notifyListeners();
  }

  /// Reconciles the locally cached account type with server truth, which
  /// arrives on the live `FamilyContext` subscription (see `app.dart`).
  ///
  /// Account type is persisted at sign-in and would otherwise never change on
  /// this handset — but a guardian can graduate a child from *their* phone, and
  /// the child's phone has to notice. Until it does, that phone keeps the whole
  /// supervised UI: no sign out, read-only visibility, and a "hand this phone
  /// back" button that can no longer work, since graduation deletes the
  /// guardianship and every release code the release screen needs.
  ///
  /// Only ever called with what the server said, so it goes both ways — but in
  /// practice only child → adult happens, since pairing mints a fresh session.
  Future<void> applyAccountType(AccountType type) async {
    final s = _session;
    if (s == null || s.accountType == type) return;
    debugPrint('[auth] account type ${s.accountType.wire} → ${type.wire}');
    _session = Session(
      userId: s.userId,
      username: s.username,
      name: s.name,
      accountType: type,
    );
    notifyListeners();
    await SessionStore.instance.saveSession(
      userId: s.userId,
      username: s.username,
      name: s.name,
      accountType: type,
    );
    // Not a child device any more. Dropping the sticky marker is what makes a
    // later sign-out land on the ordinary login form instead of bouncing to
    // the pairing screen — the graduated account now has a real password.
    if (type != AccountType.child) {
      await SessionStore.instance.clearChildDevice();
    }
  }

  Future<void> deleteAccount() async {
    final s = _session;
    // A child deleting their own account would be an escape hatch out of
    // supervision. The backend rejects it too.
    if (s != null && s.isChild) return;
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
