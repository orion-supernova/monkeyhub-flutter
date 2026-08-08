import 'package:flutter_test/flutter_test.dart';
import 'package:monkeyhub/auth/auth_errors.dart';
import 'package:monkeyhub/l10n/generated/app_localizations_en.dart';

/// Regresses the bug that started the recovery-flow rewrite.
///
/// The login screen used to carry a private map with `WRONG_RECOVERY_KEY` and
/// `NO_RECOVERY_KEY` in it. The backend has never thrown either — it throws a
/// single `INVALID_RECOVERY_KEY` — so every failed password reset fell through
/// to the raw-exception fallback and showed the user a truncated stack trace
/// where friendly copy was intended. Nothing caught it because the map was
/// private to a widget. That is the entire reason it now lives in its own file.
void main() {
  final l10n = AppLocalizationsEn();
  final messages = authErrorMessages(l10n);

  /// The shape Convex errors actually arrive in: the code is embedded in a
  /// longer server-side string, never on its own. Matching must be substring.
  String thrown(String code) => Exception(
        '[CONVEX M(auth:resetPasswordWithRecoveryKey)] Server Error: '
        'Uncaught Error: $code at handler (../convex/auth.ts:88:12)',
      ).toString();

  group('the bug that started this', () {
    test('INVALID_RECOVERY_KEY gets friendly copy, not a stack trace', () {
      final msg = humanizeAuthError(thrown('INVALID_RECOVERY_KEY'), l10n);

      expect(msg, messages['INVALID_RECOVERY_KEY']);
      expect(msg, isNot(contains('CONVEX')));
      expect(msg, isNot(contains('auth.ts')));
      expect(msg, isNot(endsWith('…')),
          reason: 'the ellipsis means it hit the raw-exception fallback');
    });

    test('the dead keys are gone', () {
      // Keeping a key the backend never throws is worse than having none: it
      // reads as handled while the raw exception is what reaches the user.
      expect(messages.containsKey('WRONG_RECOVERY_KEY'), isFalse);
      expect(messages.containsKey('NO_RECOVERY_KEY'), isFalse);
    });
  });

  group('coverage of what the backend actually throws', () {
    // Mirrors backend/convex/auth.ts, rateLimit.ts, childGuard.ts:37-50,
    // socialAuth.ts, idToken.ts and systemAccount.ts. Update BOTH sides
    // together — there is no shared Dart↔TS constants mechanism in this repo.
    const backendCodes = <String>{
      'USERNAME_TAKEN',
      // systemAccount.ERR_USERNAME_RESERVED, thrown by all three signup paths
      // (auth.signup, socialAuth.completeSocialSignUp,
      // family.createChildAccount) for a handle that reads as the brand.
      'USERNAME_RESERVED',
      // systemAccount.ERR_DISPLAY_NAME_RESERVED — same rule on `name`, thrown by
      // those three AND by users.updateProfile.
      'DISPLAY_NAME_RESERVED',
      'USER_NOT_FOUND',
      'WRONG_PASSWORD',
      'INVALID_RECOVERY_KEY',
      'TOO_MANY_ATTEMPTS',
      'CHILD_MUST_PAIR',
      'PAIRING_CODE_EXPIRED',
      'PAIRING_CODE_INVALID',
      // socialAuth.ts
      'USE_SOCIAL_SIGN_IN',
      'SOCIAL_ALREADY_LINKED',
      'SOCIAL_LINKED_TO_OTHER_ACCOUNT',
      'SOCIAL_NOT_LINKED',
      'SOCIAL_LAST_CREDENTIAL',
      'USERNAME_INVALID',
      // idToken.ts
      'SOCIAL_TOKEN_INVALID',
      'SOCIAL_NONCE_MISMATCH',
      'SOCIAL_MISCONFIG',
    };

    test('every mapped key is one the backend throws', () {
      expect(messages.keys.toSet().difference(backendCodes), isEmpty);
    });

    test('every backend code has copy', () {
      expect(backendCodes.difference(messages.keys.toSet()), isEmpty);
    });

    test('each one humanizes rather than leaking the exception', () {
      for (final code in backendCodes) {
        final msg = humanizeAuthError(thrown(code), l10n);
        expect(msg, messages[code], reason: code);
      }
    });

    test('no code is a substring of another', () {
      // Matching is by substring, so a key contained in another key would make
      // the map order-dependent: whichever came first in insertion order would
      // swallow the other and show the wrong copy. Harmless until the
      // `SOCIAL_*` family arrived — `SOCIAL_NOT_LINKED` and
      // `SOCIAL_ALREADY_LINKED` are exactly the shape that would collide if
      // either were ever shortened to `SOCIAL_LINKED`.
      for (final a in messages.keys) {
        for (final b in messages.keys) {
          if (a == b) continue;
          expect(b.contains(a), isFalse, reason: '"$a" is inside "$b"');
        }
      }
    });

    test('no copy names the code itself', () {
      for (final entry in messages.entries) {
        expect(entry.value, isNot(contains(entry.key)), reason: entry.key);
      }
    });
  });

  group('reset must stay non-enumerable', () {
    test('the recovery copy does not reveal which of the three cases it was',
        () {
      // The server answers INVALID_RECOVERY_KEY for "no such user", "that's a
      // child account", and "wrong phrase" alike. Copy that named any of them
      // would hand back the distinction the backend went out of its way to
      // hide — the child case especially, which would make reset an "is this
      // username a kid?" oracle.
      final copy = messages['INVALID_RECOVERY_KEY']!.toLowerCase();
      for (final leak in ['no account', 'doesn\'t exist', 'kid', 'child']) {
        expect(copy, isNot(contains(leak)), reason: leak);
      }
    });
  });

  group('fallback', () {
    test('unknown errors truncate rather than dump, when no fallback given',
        () {
      final long = 'X' * 500;
      final msg = humanizeAuthError(Exception(long), l10n);

      expect(msg.length, lessThanOrEqualTo(141));
      expect(msg, endsWith('…'));
    });

    test('a supplied fallback wins — the child screen never sees a trace', () {
      final msg = humanizeAuthError(
        Exception('something nobody mapped'),
        l10n,
        fallback: 'Something went wrong. Try again.',
      );

      expect(msg, 'Something went wrong. Try again.');
    });

    test('overrides beat the shared map', () {
      // USER_NOT_FOUND means something different on the pairing screen, where
      // no username was ever typed.
      final msg = humanizeAuthError(
        thrown('USER_NOT_FOUND'),
        l10n,
        overrides: const {'USER_NOT_FOUND': 'That account isn\'t there.'},
      );

      expect(msg, 'That account isn\'t there.');
    });

    test('a known code still wins over the fallback', () {
      final msg = humanizeAuthError(
        thrown('WRONG_PASSWORD'),
        l10n,
        fallback: 'Something went wrong. Try again.',
      );

      expect(msg, messages['WRONG_PASSWORD']);
    });
  });
}
