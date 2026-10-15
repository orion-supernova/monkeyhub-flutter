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

  /// The argument the session token travels in.
  ///
  /// NOT `token`: `voipTokens.setVoipToken`, `setApnsToken` and `setFcmToken`
  /// each already have an argument by that name carrying the PUSH token, and
  /// the first version of this overwrote it — storing the session token as the
  /// device's push credential and killing notifications on every device,
  /// silently, because the call still succeeded. `functions.ts` throws at
  /// module load if any function declares this name.
  static const String identityArg = 'sessionToken';

  /// Backend functions that are reachable with no session, and therefore must
  /// NOT be sent a session-token argument.
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

  /// Backend functions that are a session's own teardown, and may therefore be
  /// sent the token of the session that has just ended.
  ///
  /// Signing out clears the local session FIRST (see
  /// `SessionStore.outgoingToken` for why), so by the time these two run there
  /// is no live token to attach and both were being rejected with
  /// `SESSION_UNKNOWN` — leaving the server session live and the device's push
  /// row in place, which is how a handset parked on the login screen kept
  /// receiving notifications for the account it had signed out of.
  ///
  /// A named list rather than a per-call-site judgement, for the same reason
  /// [tokenless] is one, and a SHORT one on purpose: an outgoing token is a
  /// credential the app is in the middle of revoking, and nothing outside this
  /// set has any business acting with it.
  static const Set<String> farewell = {
    'auth:logout',
    'voipTokens:clearDeviceToken',
  };

  /// Error codes `sessionCore.requireSession` throws.
  static const _unknown = 'SESSION_UNKNOWN';
  static const _revoked = 'SESSION_REVOKED';

  /// A moderator banned this account (`moderation.suspendAccount`). A loss
  /// like the two above, plus a reason the login screen has to give.
  static const _suspended = 'ACCOUNT_SUSPENDED';

  /// Set when the last loss was a ban, so the login screen the user lands on
  /// can say why instead of looking like an ordinary sign-out. Read-and-clear
  /// through [takeSuspendedNotice].
  bool _suspendedNotice = false;

  /// Whether the user was just signed out by a ban. Clears the flag.
  bool takeSuspendedNotice() {
    final v = _suspendedNotice;
    _suspendedNotice = false;
    return v;
  }


  /// Installed by `app.dart`. Called at most once per lost session — see
  /// [noteError]'s latch.
  VoidCallback? onSessionLost;

  bool _lost = false;

  /// Whether [name] should carry a token.
  bool requiresToken(String name) => !tokenless.contains(name);

  /// Whether [name] may fall back to the token of the session that just ended.
  /// See [farewell].
  bool acceptsOutgoingToken(String name) => farewell.contains(name);

  /// The token [name] travels with: the live one, or — for the two calls that
  /// ARE a session's teardown, and run after it has been cleared — the one the
  /// session left behind.
  ///
  /// Null means the call goes out with no credential, which the server answers
  /// with `SESSION_UNKNOWN`. That is the honest outcome for an ordinary call
  /// made while signed out, and the sign-out loop depends on it; it is only
  /// wrong for [farewell], where it silently stranded a device's push row.
  ///
  /// Takes both tokens rather than reading `SessionStore`, so the rule can be
  /// stated and tested in one place instead of inside `ConvexBackend`.
  String? attachedToken(
    String name, {
    required String? live,
    required String? outgoing,
  }) => live ?? (acceptsOutgoingToken(name) ? outgoing : null);

  /// Whether [error] means this device's session is gone.
  ///
  /// Matches on the message because Convex surfaces a thrown `Error` as text;
  /// the same shape `humanizeAuthError` already relies on for every other
  /// backend error code in this app.
  static bool isSessionLoss(Object error) {
    final text = error.toString();
    return text.contains(_unknown) ||
        text.contains(_revoked) ||
        text.contains(_suspended);
  }

  /// Report a failed call, together with the token it actually went out under
  /// ([carried]) and the one this device holds now ([live]).
  ///
  /// Latched because a dead session fails EVERY in-flight subscription and
  /// request at once — a chat list, a presence heartbeat and three room
  /// subscriptions can all land in the same frame, and signing out five times
  /// would fight the navigator and could strand the user mid-transition.
  ///
  /// THE TWO TOKENS ARE NOT BOOKKEEPING. A subscription freezes its arguments,
  /// session token included, at the moment it is bound, and goes on
  /// re-delivering whatever the server last answered — so a subscription that
  /// outlives its session reports `SESSION_REVOKED` forever. The latch hides
  /// that while signed out, and [reset] at the next sign-in is precisely what
  /// un-hides it: the first stale delivery after a successful sign-in used to
  /// tear the BRAND NEW session down, which on screen was a sign-in that
  /// flickered and bounced straight back to the login form. Whether it
  /// happened had nothing to do with which button was pressed — Apple, Google
  /// and password all bounce — only with whether some earlier session in the
  /// same app run had been revoked.
  ///
  /// So a loss only counts when the call that reported it presented the
  /// credential this device is signed in with now. Anything else is news about
  /// a session that has already ended, and there is nothing left to sign out
  /// of. Cancelling the subscription is still the right thing and is done
  /// where it is owned (see `GroupCallService.detach`); this is the rule that
  /// makes the next service to forget a harmless bug rather than one that
  /// makes signing in impossible.
  /// Both are `required` and nullable, exactly like [attachedToken]'s pair:
  /// null is a real answer (a call that went out with no credential), and a
  /// caller that has not thought about which token it presented cannot supply
  /// one by accident.
  void noteError(
    Object error, {
    required String? carried,
    required String? live,
  }) {
    if (_lost || !isSessionLoss(error)) return;
    if (carried != live) return;
    _lost = true;
    if (error.toString().contains(_suspended)) _suspendedNotice = true;
    debugPrint('[session] server rejected our token — signing out');
    onSessionLost?.call();
  }

  /// Re-arm after a successful sign-in, so a later loss is noticed again.
  void reset() => _lost = false;
}
