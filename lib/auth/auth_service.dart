import 'dart:async';

import 'package:flutter/foundation.dart';

import '../backend/chat_api.dart';
import '../data/cache_store.dart';
import '../diagnostics/diag_log.dart';
import '../models/family.dart';
import '../push/device_identity.dart';
import '../push/push_manager.dart';
import 'session_guard.dart';
import 'session_store.dart';
import 'social_sign_in.dart';
export 'session_store.dart' show Session;

/// AuthService = ConvexAuthService from v02. Wraps the Convex auth mutations
/// and keeps the local session in sync with secure storage.
class AuthService extends ChangeNotifier {
  AuthService(this._api);
  final ChatApi _api;

  /// The backend this service talks to.
  ///
  /// Exposed for the sign-in screens, which are handed an [AuthService] and
  /// nothing else, but need the plain API for the username availability check —
  /// a read that has no business going through the auth layer. Threading a
  /// second constructor argument down through `app.dart` and the pushed social
  /// screen to say the same thing would be more wiring for less clarity.
  ChatApi get api => _api;

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
    // Persist BEFORE notifying, so "signed in" can never mean "signed in but
    // not on disk". The old order was the reverse, to keep a slow keychain
    // from delaying the LoginScreen → HomeShell swap, and the trade it made
    // was stated as "they'll just need to sign in again next launch". That
    // turned out to be the optimistic reading: the previous session was still
    // in the keychain, so the next launch did not ask anyone to sign in — it
    // restored the OLD account, which is the bug this whole change exists for.
    // A write that fails now throws out of here and the sign-in reports it.
    await _persistSession(res);
    _session = Session(userId: res.userId, username: res.username, name: res.name);
    notifyListeners();
  }

  Future<void> signIn({required String username, required String password}) async {
    debugPrint('[auth] signIn: calling _api.login');
    final res = await _api.login(username: username, password: password);
    debugPrint('[auth] signIn: login returned, userId=${res.userId}');
    await _persistSession(res);
    _session = Session(userId: res.userId, username: res.username, name: res.name);
    notifyListeners();
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
    await _adoptSession(outcome.result!);
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
    await _adoptSession(res);
  }

  /// Shared tail of every social entry point. Mirrors [signIn] exactly,
  /// including the persist-before-notify ordering and why.
  Future<void> _adoptSession(AuthResult res) async {
    await _persistSession(res);
    _session = Session(userId: res.userId, username: res.username, name: res.name);
    notifyListeners();
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
    await _adoptSession(res);
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

  /// Adopts the session produced by a successful desktop/web device-login
  /// (QR or short-code) sign-in, from `DeviceLoginScreen`. Shares
  /// `_adoptSession` with every other entry point — social sign-in, pairing
  /// — so nothing downstream of `isSignedIn` flipping can tell which one
  /// this was.
  Future<void> completeDeviceLogin(AuthResult res) async {
    await _adoptSession(res);
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
    await _persistSession(res, accountType: AccountType.child);
    _session = Session(
      userId: res.userId,
      username: res.username,
      name: res.name,
      accountType: AccountType.child,
    );
    notifyListeners();
  }

  Future<void> _persistSession(
    AuthResult res, {
    AccountType accountType = AccountType.adult,
  }) async {
    // Re-arm the loss detector. Without this a device that was signed out
    // remotely and then signed back in would never notice a SECOND revocation,
    // because the latch that stops one dead session firing five sign-outs
    // would still be closed from the first.
    SessionGuard.instance.reset();
    // AWAITED, and no longer swallowing. This used to be fire-and-forget with
    // an empty `catchError`, on the reasoning that a keychain hiccup should not
    // block a sign-in — but the sign-in it did not block was one whose session
    // never reached disk. The app then ran on an in-memory session that the
    // next cold start could not restore, and restored the PREVIOUS one
    // instead. A credential that failed to persist is a failed sign-in, and
    // saying so is the only version of this that cannot lie.
    await SessionStore.instance.saveSession(
      userId: res.userId,
      username: res.username,
      name: res.name,
      token: res.token,
      accountType: accountType,
    );
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
    await _persistSession(res);
    _needsPhraseRotation = true;
    _pendingRotationPassword = newPassword;
    _session = Session(userId: res.userId, username: res.username, name: res.name);
    notifyListeners();
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

  /// The server rejected this device's token: the session is revoked, or the
  /// account is gone.
  ///
  /// Distinct from [signOut] in three ways that matter:
  ///
  ///  * **It applies to child devices too.** A child cannot CHOOSE to sign
  ///    out, but a guardian who unpaired the handset has already decided, and
  ///    leaving it on a dead session would strand it on a screen where nothing
  ///    works and no button helps.
  ///  * **It does not call `auth:logout`.** There is no session left to tear
  ///    down, and the call would be rejected for the very reason we are here.
  ///  * **It cannot fail into staying signed in.** Storage errors are logged
  ///    and the in-memory session is dropped regardless, because the
  ///    alternative is an app that keeps showing a signed-in shell whose every
  ///    request 401s.
  Future<void> forceSignOut() async {
    if (_session == null) return;
    debugPrint('[auth] session lost — returning to the login screen');
    try {
      await SessionStore.instance.clearSession().timeout(_localSignOutTimeout);
    } catch (e) {
      debugPrint('[auth] forceSignOut: clearing stored session failed: $e');
    }
    _session = null;
    _needsPhraseRotation = false;
    _pendingRotationPassword = null;
    // Same reasoning as in [_afterSignOut], and needed separately because this
    // path does not go through it — a revoked session leaves the same staged
    // message text behind as a chosen sign-out does.
    unawaited(PushManager.instance.clearPushInbox());
    notifyListeners();
  }

  /// How long the local half of [signOut] may take before we give up on it and
  /// sign out anyway.
  static const _localSignOutTimeout = Duration(seconds: 5);

  /// Server-side session teardown and provider forgetting, neither of which the
  /// user should ever wait on. Failures are logged, not surfaced: by the time
  /// this runs the person is already signed out of this device.
  Future<void> _afterSignOut(String userId) async {
    // Ahead of the network calls: it is a local delete, and what it drops is
    // message text belonging to the account that has just left. The native
    // handlers stage a push under no user id at all — they cannot know one —
    // so emptying the box on the way out IS the account boundary. It holds
    // because a push can only ever have arrived for the session that was live
    // when it did, and ending that session is exactly what runs this.
    await PushManager.instance.clearPushInbox();
    try {
      await _api.logout(userId: userId);
    } catch (e, st) {
      debugPrint('[auth] signOut: auth:logout failed: $e');
      // Same rule as `PushManager.logout`: a session loss here means the push
      // teardown won the race and already revoked this device, and anything
      // else means the account is still signed in on a server that never
      // heard about it. Only the second is worth waking someone for.
      if (!SessionGuard.isSessionLoss(e)) {
        DiagLog.error('auth logout', e, stack: st);
      }
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

  /// Changes the handle on a password account, and adopts the result locally.
  ///
  /// Returns the handle the server settled on, so a caller can show it back.
  Future<String> changeUsername({
    required String password,
    required String username,
  }) async {
    final s = _session;
    if (s == null) throw StateError('not signed in');
    final next = await _api.changeUsername(
      userId: s.userId,
      password: password,
      username: username,
    );
    await _adoptUsername(next);
    return next;
  }

  /// The same for an Apple/Google-only account, proved with a credential the
  /// caller has just obtained from the native sheet.
  Future<String> changeUsernameWithProvider({
    required SocialCredential credential,
    required String username,
  }) async {
    final s = _session;
    if (s == null) throw StateError('not signed in');
    final next = await _api.changeUsernameWithIdentity(
      userId: s.userId,
      credential: credential,
      username: username,
    );
    await _adoptUsername(next);
    return next;
  }

  /// Rewrites the handle everywhere this layer keeps one.
  ///
  /// The keychain write is the load-bearing half, and the reason is cold start:
  /// `SessionStore` is what the chat list and settings headers read BEFORE the
  /// first `getProfile` lands, so skipping it leaves the app greeting the user
  /// by a name they no longer have every time they relaunch — and, far worse,
  /// leaves the last handle they signed in with disagreeing with the one that
  /// now works.
  ///
  /// Shaped exactly like [applyAccountType]: rebuild, notify, then persist. The
  /// notify comes first for the same reason it does there — a stalled keychain
  /// write (a real thing on first use after install) must not hold up the UI.
  Future<void> _adoptUsername(String username) async {
    final s = _session;
    if (s == null || s.username == username) return;
    debugPrint('[auth] username ${s.username} → $username');
    _session = Session(
      userId: s.userId,
      username: username,
      name: s.name,
      accountType: s.accountType,
    );
    notifyListeners();
    await SessionStore.instance.saveSession(
      userId: s.userId,
      username: username,
      name: s.name,
      accountType: s.accountType,
    );
  }

  Future<void> deleteAccount() async {
    final s = _session;
    // A child deleting their own account would be an escape hatch out of
    // supervision. The backend rejects it too.
    if (s != null && s.isChild) return;
    try {
      if (s != null) await _api.deleteAccount(userId: s.userId);
    } finally {
      // In the `finally`, and that placement is the fix. The delete mutation
      // commits on the server before the response makes it back, so a socket
      // that dies in between used to leave the account purged and this device
      // still holding its session — signed in, forever, to an account that no
      // longer exists. Tearing down locally regardless is right in both
      // directions: if the server did delete, this matches it; if it did not,
      // the worst case is a sign-out.
      if (s != null) {
        // Account is gone — no reason to keep cached rooms/messages around.
        try {
          await CacheStore.instance.clearFor(s.userId);
        } catch (e) {
          debugPrint('[auth] deleteAccount: clearing the cache failed: $e');
        }
      }
      try {
        await SessionStore.instance.clearSession().timeout(_localSignOutTimeout);
      } catch (e) {
        debugPrint('[auth] deleteAccount: clearing the stored session failed: $e');
      }
      // Everything [signOut] does that this used to skip. Without the first,
      // the next "Sign in with Google" tap silently reuses the provider
      // account that was just deleted; without the second, staged push text
      // from the dead account survives into the next one.
      unawaited(SocialSignIn.forgetProviders());
      unawaited(PushManager.instance.clearPushInbox());
      SessionGuard.instance.reset();
      _session = null;
      notifyListeners();
    }
  }

  /// Our own profile came back missing — so either this account is gone, or
  /// the userId we asked with is not ours.
  ///
  /// Both are possible and they want opposite outcomes, which is why this
  /// asks the server instead of deciding. A deleted account must sign out; a
  /// device whose keychain userId drifted from its token must be REPAIRED, and
  /// signing that one out would be a regression — it works perfectly, it is
  /// only mislabelled.
  ///
  /// [reconcile] separates them without needing to know which it is looking
  /// at. If the account is gone, `whoami` throws `SESSION_REVOKED` and
  /// `ConvexBackend` hands that to [SessionGuard] — the sign-out happens on
  /// the server's word, with its latch, rather than on our inference. If the
  /// id was merely stale, the answer comes back and repairs it.
  void onSelfProfileMissing() {
    if (_session == null) return;
    debugPrint('[auth] own profile came back empty — asking who we are');
    unawaited(reconcile());
  }

  /// Ask the server who this device's token actually belongs to, and adopt the
  /// answer.
  ///
  /// The keychain says who we are at launch and nothing has ever checked it.
  /// That was survivable while the two could not disagree — but they could:
  /// the session used to be five separate keychain items written in sequence,
  /// so a half-finished write left one account's token beside another's name,
  /// and the app then ran as the first while displaying the second. Storing
  /// the session as one item stops NEW divergence; this repairs the installs
  /// that already have it.
  ///
  /// Deliberately quiet. A network failure means "ask again next launch", not
  /// "sign out" — the token is not in question, only the name attached to it.
  /// A dead session is different, and takes the usual route: `requireSession`
  /// throws, `ConvexBackend` hands it to [SessionGuard], and that signs out.
  Future<void> reconcile() async {
    final s = _session;
    if (s == null) return;
    final Session? truth;
    try {
      truth = await _api.whoami();
    } catch (e) {
      debugPrint('[auth] reconcile: whoami failed: $e');
      return;
    }
    if (truth == null) return;
    if (truth.userId == s.userId &&
        truth.username == s.username &&
        truth.name == s.name &&
        truth.accountType == s.accountType) {
      return;
    }
    debugPrint(
      '[auth] reconcile: keychain said ${s.username}, token says '
      '${truth.username} — adopting the server',
    );
    // Token unchanged: `saveSession` keeps the stored one when passed null,
    // and it is the token that was right all along.
    await SessionStore.instance.saveSession(
      userId: truth.userId,
      username: truth.username,
      name: truth.name,
      accountType: truth.accountType,
    );
    _session = truth;
    notifyListeners();
  }
}
