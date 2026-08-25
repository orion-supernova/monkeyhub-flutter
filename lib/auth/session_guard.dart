import 'package:flutter/foundation.dart';

/// The client half of the session boundary.
///
/// Two jobs, both of which have to live somewhere every backend call passes
/// through — which is why this is a tiny singleton rather than something the
/// call sites reach for:
///
///  1. **Attach the token.** `ConvexBackend` adds `token` to the args of every
///     request except the handful the backend deliberately serves without a
///     session. That mirrors `functions.ts`: authenticated by default, and the
///     exceptions are a named list rather than a judgement made per call site.
///
///  2. **React when the server says the session is gone.** A revoked or
///     unknown token means this device is no longer signed in — someone hit
///     "remove all other devices", or the account was deleted. The app cannot
///     keep pretending: [onSessionLost] tears the session down and drops the
///     user on the login screen.
///
/// ## Why the exception list is here and not at the call sites
///
/// Convex rejects arguments a function did not declare, so sending `token` to
/// `auth:login` is not merely useless — it fails the call outright, and it
/// fails it on the login screen, where the user has no way to recover. The
/// list therefore has to be exactly right, and "exactly right" is a property
/// of the pair, not of either side alone. `session_boundary_test.dart` reads
/// the backend's `public*` builders and asserts the two agree in BOTH
/// directions: a backend function that stops being public and a client entry
/// that stops being listed each fail the suite.
class SessionGuard {
  SessionGuard._();
  static final SessionGuard instance = SessionGuard._();

  /// Backend functions that are reachable with no session, and therefore must
  /// NOT be sent a `token` argument.
  ///
  /// Every entry is a decision, and they all reduce to the same principle: a
  /// session cannot be a precondition for the thing that creates one.
  static const Set<String> tokenless = {
    // Minting.
    'auth:login',
    'auth:signup',
    'socialAuth:signIn',
    'socialAuth:completeSignUp',
    'socialAuth:linkExistingAccount',
    // Recovering an account that by definition cannot sign in.
    'auth:resetPasswordWithRecoveryKey',
    // The device-login handshake — the signed-OUT desktop's three calls. The
    // phone's `peek`/`respond` are absent on purpose: that side is signed in.
    'deviceLogin:createLoginRequest',
    'deviceLogin:getDeviceLoginRequestStatus',
    'deviceLogin:exchangeDeviceLoginRequest',
    // A child's handset has no session until the code is redeemed.
    'family:redeemPairingCode',
    // Questions the login screen itself asks.
    'users:isUsernameAvailable',
    'serverDirectory:current',
    'releases:latest',
  };

  /// Error codes `sessionCore.requireSession` throws.
  static const _unknown = 'SESSION_UNKNOWN';
  static const _revoked = 'SESSION_REVOKED';

  /// Installed by `app.dart`. Called at most once per lost session — see
  /// [noteError]'s latch.
  VoidCallback? onSessionLost;

  bool _lost = false;

  /// Whether [name] should carry a token.
  bool requiresToken(String name) => !tokenless.contains(name);

  /// Whether [error] means this device's session is gone.
  ///
  /// Matches on the message because Convex surfaces a thrown `Error` as text;
  /// the same shape `humanizeAuthError` already relies on for every other
  /// backend error code in this app.
  static bool isSessionLoss(Object error) {
    final text = error.toString();
    return text.contains(_unknown) || text.contains(_revoked);
  }

  /// Report a failed call. Fires [onSessionLost] exactly once.
  ///
  /// Latched because a dead session fails EVERY in-flight subscription and
  /// request at once — a chat list, a presence heartbeat and three room
  /// subscriptions can all land in the same frame, and signing out five times
  /// would fight the navigator and could strand the user mid-transition.
  void noteError(Object error) {
    if (_lost || !isSessionLoss(error)) return;
    _lost = true;
    debugPrint('[session] server rejected our token — signing out');
    onSessionLost?.call();
  }

  /// Re-arm after a successful sign-in, so a later loss is noticed again.
  void reset() => _lost = false;
}
