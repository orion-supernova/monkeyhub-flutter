import 'package:flutter_test/flutter_test.dart';
import 'package:monkeyhub/auth/auth_errors.dart';

/// Regresses the bug that started the recovery-flow rewrite.
///
/// The login screen used to carry a private map with `WRONG_RECOVERY_KEY` and
/// `NO_RECOVERY_KEY` in it. The backend has never thrown either — it throws a
/// single `INVALID_RECOVERY_KEY` — so every failed password reset fell through
/// to the raw-exception fallback and showed the user a truncated stack trace
/// where friendly copy was intended. Nothing caught it because the map was
/// private to a widget. That is the entire reason it now lives in its own file.
void main() {
  /// The shape Convex errors actually arrive in: the code is embedded in a
  /// longer server-side string, never on its own. Matching must be substring.
  String thrown(String code) => Exception(
        '[CONVEX M(auth:resetPasswordWithRecoveryKey)] Server Error: '
        'Uncaught Error: $code at handler (../convex/auth.ts:88:12)',
      ).toString();

  group('the bug that started this', () {
    test('INVALID_RECOVERY_KEY gets friendly copy, not a stack trace', () {
      final msg = humanizeAuthError(thrown('INVALID_RECOVERY_KEY'));

      expect(msg, kAuthErrorMessages['INVALID_RECOVERY_KEY']);
      expect(msg, isNot(contains('CONVEX')));
      expect(msg, isNot(contains('auth.ts')));
      expect(msg, isNot(endsWith('…')),
          reason: 'the ellipsis means it hit the raw-exception fallback');
    });

    test('the dead keys are gone', () {
      // Keeping a key the backend never throws is worse than having none: it
      // reads as handled while the raw exception is what reaches the user.
      expect(kAuthErrorMessages.containsKey('WRONG_RECOVERY_KEY'), isFalse);
      expect(kAuthErrorMessages.containsKey('NO_RECOVERY_KEY'), isFalse);
    });
  });

  group('coverage of what the backend actually throws', () {
    // Mirrors backend/convex/auth.ts, rateLimit.ts and childGuard.ts:37-50.
    // Update BOTH sides together — there is no shared Dart↔TS constants
    // mechanism in this repo.
    const backendCodes = <String>{
      'USERNAME_TAKEN',
      'USER_NOT_FOUND',
      'WRONG_PASSWORD',
      'INVALID_RECOVERY_KEY',
      'TOO_MANY_ATTEMPTS',
      'CHILD_MUST_PAIR',
      'PAIRING_CODE_EXPIRED',
      'PAIRING_CODE_INVALID',
    };

    test('every mapped key is one the backend throws', () {
      expect(kAuthErrorMessages.keys.toSet().difference(backendCodes), isEmpty);
    });

    test('every backend code has copy', () {
      expect(backendCodes.difference(kAuthErrorMessages.keys.toSet()), isEmpty);
    });

    test('each one humanizes rather than leaking the exception', () {
      for (final code in backendCodes) {
        final msg = humanizeAuthError(thrown(code));
        expect(msg, kAuthErrorMessages[code], reason: code);
      }
    });

    test('no copy names the code itself', () {
      for (final entry in kAuthErrorMessages.entries) {
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
      final copy = kAuthErrorMessages['INVALID_RECOVERY_KEY']!.toLowerCase();
      for (final leak in ['no account', 'doesn\'t exist', 'kid', 'child']) {
        expect(copy, isNot(contains(leak)), reason: leak);
      }
    });
  });

  group('fallback', () {
    test('unknown errors truncate rather than dump, when no fallback given',
        () {
      final long = 'X' * 500;
      final msg = humanizeAuthError(Exception(long));

      expect(msg.length, lessThanOrEqualTo(141));
      expect(msg, endsWith('…'));
    });

    test('a supplied fallback wins — the child screen never sees a trace', () {
      final msg = humanizeAuthError(
        Exception('something nobody mapped'),
        fallback: 'Something went wrong. Try again.',
      );

      expect(msg, 'Something went wrong. Try again.');
    });

    test('overrides beat the shared map', () {
      // USER_NOT_FOUND means something different on the pairing screen, where
      // no username was ever typed.
      final msg = humanizeAuthError(
        thrown('USER_NOT_FOUND'),
        overrides: const {'USER_NOT_FOUND': 'That account isn\'t there.'},
      );

      expect(msg, 'That account isn\'t there.');
    });

    test('a known code still wins over the fallback', () {
      final msg = humanizeAuthError(
        thrown('WRONG_PASSWORD'),
        fallback: 'Something went wrong. Try again.',
      );

      expect(msg, kAuthErrorMessages['WRONG_PASSWORD']);
    });
  });
}
