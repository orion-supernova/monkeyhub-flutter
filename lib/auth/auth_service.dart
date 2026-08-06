import 'dart:async';

import 'package:flutter/foundation.dart';

import '../backend/chat_api.dart';
import '../data/cache_store.dart';
import '../models/family.dart';
import '../push/device_identity.dart';
import 'session_store.dart';
import 'social_sign_in.dart';
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

  /// Creates an account. [recoveryKeyHash] is required — a recovery phrase is
  /// no longer optional, because an account without one is unrecoverable.
  /// The caller hashes it; the plaintext never reaches this layer.
  Future<void> signUp({
    required String username,
    required String name,
    required String password,
    required String recoveryKeyHash,
  }) async {
    final res = await _api.signup(
      username: username,
      name: name,
      password: password,
      recoveryKeyHash: recoveryKeyHash,
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

  /// Signs in — or reports that we need a username first — with Apple/Google.
  ///
  /// Returns null once the session is live. Returns the outcome when the backend
  /// asked for a username, in which case the caller shows the username step and
  /// finishes with [completeSocialSignUp] using the SAME credential.
  ///
  /// Social accounts are adults only, and not by choice: Apple refuses Sign in
  /// with Apple to under-13 Child Accounts outright, and Google says the same
  /// for child-directed apps. Children keep pairing codes.
  Future<SocialSignInOutcome?> signInWithProvider(
    SocialCredential credential,
  ) async {
    final outcome = await _api.socialSignIn(credential);
    if (outcome.needsUsername) return outcome;
    _adoptSession(outcome.result!);
    return null;
  }

  /// Second half of a first-time social sign-up.
  Future<void> completeSocialSignUp({
    required SocialCredential credential,
    required String username,
    String? name,
  }) async {
    final res = await _api.completeSocialSignUp(
      credential: credential,
      username: username,
      name: name,
    );
    _adoptSession(res);
  }

  /// Shared tail of every social entry point. Mirrors [signIn] exactly,
  /// including the notify-before-persist ordering and why.
  void _adoptSession(AuthResult res) {
    _session = Session(userId: res.userId, username: res.username, name: res.name);
    notifyListeners();
    _persistSession(res);
  }

  /// Signs in to an existing account and attaches the provider to it, so the
  /// next tap of that button goes straight in.
  ///
  /// The "I already have an account" branch of the username step.
  Future<void> linkSocialToExistingAccount({
    required SocialCredential credential,
    required String username,
    required String password,
  }) async {
    final res = await _api.linkSocialToExistingAccount(
      credential: credential,
      username: username,
      password: password,
    );
    _adoptSession(res);
  }

  /// Attaches a provider to the signed-in account, from Profile. The password
  /// is what proves ownership — see `chat_api.linkSocialIdentity`.
  Future<void> linkSocialIdentity({
    required String password,
    required SocialCredential credential,
  }) async {
    final s = _session;
    if (s == null || s.isChild) return;
    await _api.linkSocialIdentity(
      userId: s.userId,
      password: password,
      credential: credential,
    );
  }

  Future<void> unlinkSocialIdentity({
    required String password,
    required SocialProvider provider,
  }) async {
    final s = _session;
    if (s == null || s.isChild) return;
    await _api.unlinkSocialIdentity(
      userId: s.userId,
      password: password,
      provider: provider,
    );
  }

  Future<List<SocialProvider>> linkedProviders() async {
    final s = _session;
    if (s == null) return const [];
    return _api.linkedProviders(userId: s.userId);
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

  /// True when a reset just succeeded and the phrase should be retired.
  ///
  /// A phrase that has been *entered* is spent: by definition of "I forgot my
  /// password" it may have just been typed on a borrowed laptop or into a
  /// browser that autofilled it into history. Rotating costs the user nothing —
  /// they are already in an account-maintenance frame of mind and the new
  /// password is in hand.
  ///
  /// Deliberately NOT persisted. If the app dies before the rotation happens
  /// the account still has a working (old) phrase — nothing is broken, it just
  /// didn't rotate, and the next launch's recovery gate is the backstop.
  bool _needsPhraseRotation = false;
  bool get needsPhraseRotation => _needsPhraseRotation;

  /// The password set during the reset, held only long enough to hand to the
  /// rotation gate so it needn't ask for it again. Consumed exactly once.
  String? _pendingRotationPassword;
  String? consumePendingRotationPassword() {
    final p = _pendingRotationPassword;
    _pendingRotationPassword = null;
    return p;
  }

  /// Resets the password using a recovery phrase. On success, signs the user
  /// in immediately (mirrors the Convex `resetPasswordWithRecoveryKey` return
  /// shape, which is identical to login).
  ///
  /// Does NOT push the rotation gate itself: the sign-in below flips
  /// `isSignedIn`, which makes `_AppHome` swap LoginScreen out for HomeShell
  /// and dispose the very context that would be pushing. The flag is picked up
  /// by `RecoveryGate` from the app shell instead.
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
    _needsPhraseRotation = true;
    _pendingRotationPassword = newPassword;
    _session = Session(userId: res.userId, username: res.username, name: res.name);
    notifyListeners();
    _persistSession(res);
  }

  /// Sets or replaces this account's recovery phrase. [recoveryKeyHash] is
  /// already hashed; [password] proves the caller owns the account, because
  /// planting a phrase on someone else's account would be a takeover.
  Future<void> setRecoveryKey({
    required String password,
    required String recoveryKeyHash,
  }) async {
    final s = _session;
    // Backstop only — the UI never offers this to a child, and the backend
    // rejects it outright. Children have no password and no reset path.
    if (s == null || s.isChild) return;
    await _api.setRecoveryKey(
      userId: s.userId,
      password: password,
      recoveryKeyHash: recoveryKeyHash,
    );
    _needsPhraseRotation = false;
    _pendingRotationPassword = null;
  }

  /// Children cannot sign themselves out — that's the whole point of a
  /// supervised device. The UI hides the button; this is the backstop so a
  /// stray call site can't strand a child on the login screen.
  /// Signing out is LOCAL-FIRST, and deliberately so.
  ///
  /// This used to run three awaits before touching any local state, and the
  /// caller (`ProfileScreen._signOut`) holds a `_busy` latch across the whole
  /// future — so the button sat spinning, un-retryable, for as long as the
  /// slowest of them took. On web that was the reported "can't log out":
  ///
  ///  * `auth:logout` is a network mutation. During the reconnect churn that
  ///    the web client used to produce, a mutation sent on a socket that was
  ///    about to be replaced could only fail by timeout — the full 15s
  ///    `operationTimeout`, with the tap already swallowed.
  ///  * `SocialSignIn.forgetProviders()` calls into the Google plugin. That
  ///    plugin is initialised lazily by the sign-in path, so on a restored
  ///    session it has never run — and `googleAvailable` is keyed on the
  ///    server client id being configured, not on the platform, so web calls it
  ///    anyway. Its try/catch stops a throw, but nothing stopped a hang.
  ///
  /// None of that work is load-bearing for signing out. The server does not
  /// need our permission to end a session, and the provider SDK only affects
  /// what the NEXT sign-in looks like. So the local teardown happens first and
  /// unconditionally, and the remote half is fired off behind it.
  ///
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

    // The one step still awaited: it is the only one whose failure is felt
    // later, because a session left in secure storage is restored on the next
    // launch and the person is silently signed back in. Bounded so a wedged
    // storage plugin degrades to "signed out until relaunch" rather than to a
    // button that never comes back.
    try {
      await SessionStore.instance.clearSession().timeout(_localSignOutTimeout);
    } catch (e) {
      debugPrint('[auth] signOut: clearing the stored session failed: $e');
    }

    _session = null;
    // A pending rotation belongs to the account that just left. Carrying it
    // into the next sign-in would gate the wrong person, with a password that
    // isn't theirs.
    _needsPhraseRotation = false;
    _pendingRotationPassword = null;
    notifyListeners();

    // Best-effort, and off the critical path. Neither can hold the UI now.
    unawaited(_afterSignOut(s.userId));
  }

  /// How long the local half of [signOut] may take before we give up on it and
  /// sign out anyway.
  static const _localSignOutTimeout = Duration(seconds: 5);

  /// Server-side session teardown and provider forgetting, neither of which the
  /// user should ever wait on. Failures are logged, not surfaced: by the time
  /// this runs the person is already signed out of this device.
  Future<void> _afterSignOut(String userId) async {
    try {
      await _api.logout(userId: userId);
    } catch (e) {
      debugPrint('[auth] signOut: auth:logout failed: $e');
    }
    // Otherwise the provider SDK silently reuses the last account and the next
    // "Sign in with Google" tap lands straight back in the account they just
    // left, with no chooser — which reads as sign-out being broken.
    try {
      await SocialSignIn.forgetProviders().timeout(_localSignOutTimeout);
    } catch (e) {
      debugPrint('[auth] signOut: forgetProviders failed: $e');
    }
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
