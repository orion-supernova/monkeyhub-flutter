import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:monkeyhub/auth/session_guard.dart';

/// The auth boundary, pinned from both sides.
///
/// The backend authenticates by default: a module opts in by importing its
/// builders from `functions.ts`, and an individual function opts back OUT by
/// using `publicQuery`/`publicMutation`/`publicAction`. That list — the entire
/// unauthenticated surface of the backend — is security-critical and one import
/// line away from growing by accident, so it is asserted here rather than left
/// to review.
///
/// The client half has to agree exactly. Convex rejects arguments a function
/// did not declare, so sending `token` to a `public*` function does not merely
/// waste bytes — it fails the call outright, and it fails it on the login
/// screen, where the user has no way to recover. The two failure directions:
///
///   * backend public, client not listed → the client attaches a token,
///     Convex rejects the undeclared arg, and sign-in is impossible;
///   * backend authed, client listed     → the client omits the token, the
///     server answers SESSION_UNKNOWN, and the app signs itself out in a loop.
///
/// Both are caught below, which is why this reads the real files instead of
/// restating the list.
///
/// Cross-language pinning like this is an established habit in this suite —
/// `share_handoff_test.dart` holds Swift, Kotlin and two entitlements files to
/// the same standard.
void main() {
  final convexDir = Directory('backend/convex');

  /// `module:function` for every `public*` builder in the backend.
  Set<String> declaredPublic() {
    final out = <String>{};
    final pattern = RegExp(
      r'export\s+const\s+(\w+)\s*=\s*public(?:Query|Mutation|Action)\(',
    );
    for (final entity in convexDir.listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.ts')) continue;
      if (entity.path.contains('/_generated/')) continue;
      final module = entity.uri.pathSegments.last.replaceAll('.ts', '');
      for (final m in pattern.allMatches(entity.readAsStringSync())) {
        out.add('$module:${m.group(1)}');
      }
    }
    return out;
  }

  test('the backend directory is where this test thinks it is', () {
    expect(
      convexDir.existsSync(),
      isTrue,
      reason: 'run from the repo root; this test reads backend/convex/*.ts',
    );
    expect(declaredPublic(), isNotEmpty);
  });

  test('client and backend agree on the unauthenticated surface', () {
    final backend = declaredPublic();
    final client = SessionGuard.tokenless;

    expect(
      backend.difference(client),
      isEmpty,
      reason:
          'These are public on the backend but the client will attach a token '
          'to them. Convex rejects undeclared args, so each one is a call that '
          'cannot succeed. Add them to SessionGuard.tokenless.',
    );
    expect(
      client.difference(backend),
      isEmpty,
      reason:
          'The client omits a token for these, but the backend now requires '
          'one. Each is a guaranteed SESSION_UNKNOWN and a sign-out loop. '
          'Remove them from SessionGuard.tokenless.',
    );
  });

  test('the unauthenticated surface has not quietly grown', () {
    // Every entry is a decision, and they all reduce to the same principle:
    // a session cannot be a precondition for the thing that creates one.
    // Changing this set is a security change — say so in the commit message.
    expect(declaredPublic(), {
      // Minting.
      'auth:login',
      'auth:signup',
      'socialAuth:signIn',
      'socialAuth:completeSignUp',
      'socialAuth:linkExistingAccount',
      // Recovering an account that by definition cannot sign in.
      'auth:resetPasswordWithRecoveryKey',
      // The device-login handshake — the signed-OUT desktop's three calls.
      'deviceLogin:createLoginRequest',
      'deviceLogin:getDeviceLoginRequestStatus',
      'deviceLogin:exchangeDeviceLoginRequest',
      // A child's handset has no session until the code is redeemed.
      'family:redeemPairingCode',
      // Questions the login screen itself asks.
      'users:isUsernameAvailable',
      'serverDirectory:current',
      'releases:latest',
    });
  });

  test('no module still imports the raw builders', () {
    // A file left on `./_generated/server` for its query/mutation/action is a
    // file whose every function is unauthenticated — the exact regression this
    // whole migration exists to prevent, and one that produces no error.
    final offenders = <String>[];
    final raw = RegExp(
      r'import\s*\{([^}]*)\}\s*from\s*"\./_generated/server"',
    );
    for (final entity in convexDir.listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.ts')) continue;
      if (entity.path.contains('/_generated/')) continue;
      final name = entity.uri.pathSegments.last;
      // `functions.ts` is the one file that legitimately imports them: it is
      // what wraps them.
      if (name == 'functions.ts') continue;
      for (final m in raw.allMatches(entity.readAsStringSync())) {
        final names = m
            .group(1)!
            .split(',')
            .map((s) => s.trim())
            .where((s) => s.isNotEmpty);
        for (final n in names) {
          if (n == 'query' || n == 'mutation' || n == 'action') {
            offenders.add('$name imports raw `$n`');
          }
        }
      }
    }
    expect(offenders, isEmpty);
  });

  test('a session loss is recognised from the error the server throws', () {
    // The two codes `sessionCore.requireSession` throws. Matched on the
    // message because Convex surfaces a thrown Error as text.
    expect(SessionGuard.isSessionLoss(Exception('SESSION_UNKNOWN')), isTrue);
    expect(SessionGuard.isSessionLoss(Exception('SESSION_REVOKED')), isTrue);
    expect(SessionGuard.isSessionLoss(Exception('WRONG_PASSWORD')), isFalse);
  });

  test('the sign-out fires once, however many calls fail together', () {
    // A dead session fails every in-flight subscription and request at once.
    // Signing out five times would fight the navigator.
    final guard = SessionGuard.instance;
    guard.reset();
    var fired = 0;
    guard.onSessionLost = () => fired++;
    for (var i = 0; i < 5; i++) {
      guard.noteError(Exception('SESSION_REVOKED'));
    }
    expect(fired, 1);

    // ...and re-arms after a fresh sign-in, or a later revocation is missed.
    guard.reset();
    guard.noteError(Exception('SESSION_REVOKED'));
    expect(fired, 2);
    guard.onSessionLost = null;
    guard.reset();
  });
}
