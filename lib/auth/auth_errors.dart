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

const Map<String, String> kAuthErrorMessages = {
  // auth.signup
  'USERNAME_TAKEN': 'That username is already taken.',
  // auth.login
  'USER_NOT_FOUND': 'No account with that username.',
  'WRONG_PASSWORD': 'Wrong password.',
  // auth.resetPasswordWithRecoveryKey — ONE code covers "no such user",
  // "that's a child account", and "wrong phrase", so the copy must not imply
  // which. Reset is the only endpoint a stranger can probe with no credential.
  'INVALID_RECOVERY_KEY': 'That username and recovery phrase don\'t match.',
  // rateLimit.ERR_TOO_MANY. Naming the wait is what stops a locked-out user
  // from assuming the account is gone.
  'TOO_MANY_ATTEMPTS': 'Too many tries. Wait 15 minutes and try again.',
  // childGuard.ERR_MUST_PAIR
  'CHILD_MUST_PAIR':
      'That\'s a kid\'s account — ask a grown-up for a pairing code.',
  // childGuard.ERR_CODE_EXPIRED / ERR_CODE_INVALID
  'PAIRING_CODE_EXPIRED': 'That code has run out. Ask for a new one.',
  'PAIRING_CODE_INVALID':
      'That code didn\'t work. It may have been used already.',
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
/// [overrides] wins over [kAuthErrorMessages] for codes whose right wording
/// depends on the screen. `USER_NOT_FOUND` is the live example: on the login
/// form it means "you typed a username nobody has", but on the pairing screen
/// no username was typed at all — it means the child's account was deleted.
String humanizeAuthError(
  Object e, {
  String? fallback,
  Map<String, String>? overrides,
}) {
  final s = e.toString();
  if (overrides != null) {
    for (final entry in overrides.entries) {
      if (s.contains(entry.key)) return entry.value;
    }
  }
  for (final entry in kAuthErrorMessages.entries) {
    if (s.contains(entry.key)) return entry.value;
  }
  if (fallback != null) return fallback;
  return s.length > 140 ? '${s.substring(0, 140)}…' : s;
}
