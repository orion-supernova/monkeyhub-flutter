/// Human-readable copy for the error codes the auth mutations throw.
///
/// SOURCE OF TRUTH IS THE BACKEND. Before editing a key here, grep it in
/// `backend/convex/auth.ts` and `backend/convex/childGuard.ts` — a key that
/// matches nothing is worse than a missing one, because it reads as handled
/// while the raw exception is what actually reaches the user.
///
/// That is not hypothetical: this map used to live inside `login_screen.dart`
/// and carried `WRONG_RECOVERY_KEY` and `NO_RECOVERY_KEY`, neither of which
/// the server has ever thrown — it throws a single `INVALID_RECOVERY_KEY` for
/// both cases. So *every* failed password reset fell through to the raw
/// exception fallback. Extracting the map out of the screen is what makes that
/// class of bug testable; see test/auth_error_map_test.dart.
///
/// There is no shared Dart↔TS constants mechanism in this repo (childGuard's
/// codes are already duplicated as literals on this side). Building one is the
/// real fix and is deliberately out of scope here.
library;

import '../l10n/generated/app_localizations.dart';

/// A function rather than a top-level const — the copy comes from
/// [AppLocalizations], which needs a resolved instance, not a BuildContext,
/// so this stays plain-Dart testable (see test/auth_error_map_test.dart).
Map<String, String> authErrorMessages(AppLocalizations l10n) => {
  // auth.signup
  'USERNAME_TAKEN': l10n.authErrorUsernameTaken,
  // systemAccount.ERR_USERNAME_RESERVED — thrown by all three signup paths for a
  // handle containing the brand. Distinct from USERNAME_TAKEN on purpose: "try
  // another name" is the same advice, but "already taken" invites the user to try
  // monkeyhub2, monkeyhub_official, monkeyhub__ … every one of which is refused
  // for the same reason they cannot see.
  'USERNAME_RESERVED': l10n.authErrorUsernameReserved,
  // systemAccount.ERR_DISPLAY_NAME_RESERVED — the same rule on the `name` field,
  // thrown by the three signup paths AND by users.updateProfile. A separate code
  // because it points at a different box on the screen.
  'DISPLAY_NAME_RESERVED': l10n.authErrorDisplayNameReserved,
  // auth.login
  'USER_NOT_FOUND': l10n.authErrorUserNotFound,
  'WRONG_PASSWORD': l10n.authErrorWrongPassword,
  // auth.resetPasswordWithRecoveryKey — ONE code covers "no such user",
  // "that's a child account", and "wrong phrase", so the copy must not imply
  // which. Reset is the only endpoint a stranger can probe with no credential.
  'INVALID_RECOVERY_KEY': l10n.authErrorInvalidRecoveryKey,
  // rateLimit.ERR_TOO_MANY. Naming the wait is what stops a locked-out user
  // from assuming the account is gone.
  'TOO_MANY_ATTEMPTS': l10n.authErrorTooManyAttempts,
  // childGuard.ERR_MUST_PAIR
  'CHILD_MUST_PAIR': l10n.authErrorChildMustPair,
  // childGuard.ERR_CODE_EXPIRED / ERR_CODE_INVALID
  'PAIRING_CODE_EXPIRED': l10n.authErrorPairingCodeExpired,
  'PAIRING_CODE_INVALID': l10n.authErrorPairingCodeInvalid,

  // deviceLogin.ts — QR / short-code sign-in. REQUEST_* comes from a scanned
  // QR, CODE_* from the typed fallback; both read the same to a user, since
  // neither can tell them which of the two they got wrong.
  'DEVICE_LOGIN_REQUEST_INVALID': l10n.authErrorDeviceLoginInvalid,
  'DEVICE_LOGIN_CODE_INVALID': l10n.authErrorDeviceLoginInvalid,
  'DEVICE_LOGIN_REQUEST_EXPIRED': l10n.authErrorDeviceLoginExpired,
  'DEVICE_LOGIN_CODE_EXPIRED': l10n.authErrorDeviceLoginExpired,
  // deviceLogin.ERR_REQUEST_DENIED — only reachable on the desktop side, and
  // only defensively: normally the status subscription reports 'denied'
  // before the desktop ever attempts an exchange.
  'DEVICE_LOGIN_DENIED': l10n.deviceLoginScreenDenied,

  // ── socialAuth.ts ──────────────────────────────────────────────────────
  // socialAuth.ERR_USE_SOCIAL. Thrown by auth.login when the account has no
  // password because it was created with a provider. Must NOT read like a
  // wrong password: the reset flow cannot help these accounts either, since
  // they have no recovery phrase.
  'USE_SOCIAL_SIGN_IN': l10n.authErrorUseSocialSignIn,
  // idToken.ERR_TOKEN_INVALID / ERR_NONCE_MISMATCH. Both are deliberately
  // opaque server-side, and both mean the same thing to a user: start over.
  'SOCIAL_TOKEN_INVALID': l10n.authErrorSocialTokenInvalid,
  'SOCIAL_NONCE_MISMATCH': l10n.authErrorSocialNonceMismatch,
  // idToken.ERR_MISCONFIG — ours, not theirs. Says so, so nobody wastes time
  // re-entering a password that was never the problem.
  'SOCIAL_MISCONFIG': l10n.authErrorSocialMisconfig,
  // socialAuth.ERR_LINKED_ELSEWHERE vs ERR_ALREADY_LINKED — different
  // remedies, so deliberately different copy.
  'SOCIAL_LINKED_TO_OTHER_ACCOUNT': l10n.authErrorSocialLinkedToOtherAccount,
  'SOCIAL_ALREADY_LINKED': l10n.authErrorSocialAlreadyLinked,
  'SOCIAL_NOT_LINKED': l10n.authErrorSocialNotLinked,
  // socialAuth.ERR_LAST_CREDENTIAL. There is no email in this app, so an
  // account with nothing left to sign in with is gone for good.
  'SOCIAL_LAST_CREDENTIAL': l10n.authErrorSocialLastCredential,
  // socialAuth.normaliseUsername — shared with users.applyUsernameChange, so
  // this now reaches the rename sheet as well as signup.
  'USERNAME_INVALID': l10n.authErrorUsernameInvalid,

  // ── users.applyUsernameChange ──────────────────────────────────────────
  // The thirty-day cooldown. Names the wait for the same reason
  // TOO_MANY_ATTEMPTS does — a refusal with no horizon reads as a bug.
  'USERNAME_CHANGED_RECENTLY': l10n.authErrorUsernameChangedRecently,
  // Only the maintainer can ever see this: their account is the address
  // problem reports are delivered to, resolved by handle rather than by id.
  'INBOX_HANDLE_LOCKED': l10n.authErrorInboxHandleLocked,
};

/// Maps a thrown backend error onto human copy.
///
/// Convex wraps thrown errors in a longer server-side string, so this matches
/// by substring rather than equality.
///
/// [fallback] is what to show when nothing matches. The adult login form passes
/// null, which surfaces a truncated raw exception — ugly, but it is the only
/// diagnostic an adult has when something genuinely unexpected happens. The
/// child pairing screen passes friendly copy instead, because showing a kid a
/// stack trace helps nobody.
///
/// [overrides] wins over [authErrorMessages] for codes whose right wording
/// depends on the screen. `USER_NOT_FOUND` is the live example: on the login
/// form it means "you typed a username nobody has", but on the pairing screen
/// no username was typed at all — it means the child's account was deleted.
String humanizeAuthError(
  Object e,
  AppLocalizations l10n, {
  String? fallback,
  Map<String, String>? overrides,
}) {
  final s = e.toString();
  if (overrides != null) {
    for (final entry in overrides.entries) {
      if (s.contains(entry.key)) return entry.value;
    }
  }
  for (final entry in authErrorMessages(l10n).entries) {
    if (s.contains(entry.key)) return entry.value;
  }
  if (fallback != null) return fallback;
  return s.length > 140 ? '${s.substring(0, 140)}…' : s;
}
