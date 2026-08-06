import 'package:flutter_test/flutter_test.dart';
import 'package:monkeyhub/diagnostics/redactor.dart';

/// The ship gate for the whole diagnostics feature.
///
/// A diagnostics log leaves the device through a share sheet, into whatever
/// chat app the user picks. In an app whose selling points include ephemeral
/// rooms, view-once media and screenshot blocking, a log that carries message
/// content out is not a bug in a debug tool — it is a hole straight through the
/// product. These tests are what make "no sentinel, no ship" checkable rather
/// than aspirational.
void main() {
  const sentinel = 'MONKEYHUB_SENTINEL_PHRASE';

  group('layer 1 — per-function policy', () {
    test('an unknown function defaults to keysOnly, never full', () {
      // The single most important assertion here. Somebody will add a Convex
      // function next month and not think about this file; the default has to
      // be safe on their behalf.
      expect(Redactor.policyFor('somethingAddedNextMonth:doThing'),
          ArgPolicy.keysOnly);

      final out = Redactor.args('somethingAddedNextMonth:doThing', {
        'roomId': 'r123',
        'secretish': sentinel,
      });
      expect(out, isNot(contains(sentinel)));
      expect(out, contains('roomId'), reason: 'keys survive, values do not');
    });

    test('credential-equivalent calls drop their args entirely', () {
      for (final fn in [
        'auth:login',
        'auth:signup',
        'auth:setRecoveryKey',
        'rooms:join',
        'family:createChildAccount',
      ]) {
        expect(Redactor.policyFor(fn), ArgPolicy.drop, reason: fn);
        final out = Redactor.args(fn, {
          'username': 'ahmet',
          'passwordHash': sentinel,
        });
        expect(out, isNot(contains(sentinel)), reason: fn);
        expect(out, isNot(contains('ahmet')), reason: fn);
      }
    });

    test('message history is dropped from RESULTS, not just args', () {
      // The trap this exists for: `messages:list` takes an innocuous roomId and
      // returns the entire conversation.
      final result = Redactor.result('messages:list', [
        {'id': 'm1', 'content': sentinel},
        {'id': 'm2', 'content': 'another private thing'},
      ]);
      expect(result, isNot(contains(sentinel)));
      expect(result, isNot(contains('another private thing')));
    });

    test('the explicitly-allowed calls keep their values', () {
      final out = Redactor.args('users:heartbeat', {'userId': 'u_42'});
      expect(out, contains('u_42'),
          reason: 'heartbeat timing/identity is the presence-churn evidence');
    });
  });

  group('layer 2 — key denylist', () {
    test('denied keys are masked at any depth, even under a full policy', () {
      final out = Redactor.args('users:heartbeat', {
        'userId': 'u_42',
        'nested': {
          'deeper': [
            {'content': sentinel},
          ],
        },
      });
      expect(out, isNot(contains(sentinel)));
    });

    test('masking is shape-preserving, not a flat asterisk run', () {
      // "the send failed because content was <str:0>" is a diagnosis.
      // "content was ***" is not, and that difference is the whole point.
      final out = Redactor.args('users:heartbeat', {
        'userId': 'u1',
        'content': 'hello there',
      })!;
      expect(out, contains('<str:11>'));
      expect(out, isNot(contains('hello there')));
    });

    test('lists of denied values do not leak through the list branch', () {
      final out = Redactor.args('users:heartbeat', {
        'userId': 'u1',
        'message': [sentinel, sentinel],
      });
      expect(out, isNot(contains(sentinel)));
    });
  });

  group('layer 3 — value-shaped backstop', () {
    test('a JWT under an innocuous key is still caught', () {
      const jwt =
          'eyJhbGciOiJIUzI1NiJ9.eyJzdWIiOiIxMjM0NTY3ODkwIn0.dBjftJeZ4CVPmB92K27uhbUJU1p1r_wW1gFWFOEjXk';
      final out = Redactor.args('users:heartbeat', {'someField': jwt});
      expect(out, isNot(contains('eyJhbGciOiJIUzI1NiJ9')));
      expect(out, contains('redacted'));
    });

    test('bearer headers and long opaque blobs are scrubbed from free text', () {
      final line = Redactor.text('sending Authorization: Bearer abc.def.ghi now');
      expect(line, isNot(contains('abc.def.ghi')));

      final opaque = Redactor.text('token=${'a' * 64} done');
      expect(opaque, isNot(contains('a' * 64)));
    });

    test('ordinary log lines survive intact', () {
      // Over-scrubbing would make the captured debugPrints useless, which is
      // most of the value of the console capture.
      const line = 'ConnectionHealth: phase online -> reconnecting (attempt 3)';
      expect(Redactor.text(line), line);
    });
  });

  group('policy coverage', () {
    test('every sensitive namespace call in use has an explicit policy', () {
      // Hard-coded from the real call sites in lib/backend/chat_api.dart. If
      // someone adds an auth/family/files/token function and wires it up
      // without deciding its policy, this fails instead of shipping a leak.
      const mustBeExplicit = [
        'auth:signup',
        'auth:login',
        'auth:setRecoveryKey',
        'auth:resetPasswordWithRecoveryKey',
        'socialAuth:signInWithApple',
        'socialAuth:signInWithGoogle',
        'family:createChildAccount',
        'family:createPairingCode',
        'family:redeemPairingCode',
        'family:releaseDeviceByCode',
        'family:releaseDeviceByGuardianPassword',
        'files:getFileUrl',
        'files:generateUploadUrl',
        'voipTokens:registerDevice',
        'voipTokens:setVoipToken',
        'voipTokens:setFcmToken',
        'messages:send',
        'messages:list',
      ];
      for (final fn in mustBeExplicit) {
        expect(
          Redactor.policyFor(fn),
          ArgPolicy.drop,
          reason: '$fn must be explicitly dropped, not left to the default',
        );
      }
    });

    test('no call in a sensitive namespace is granted full', () {
      for (final fn in [
        'auth:login',
        'socialAuth:linkGoogle',
        'family:createChildAccount',
        'files:getFileUrl',
        'voipTokens:setFcmToken',
      ]) {
        expect(Redactor.policyFor(fn), isNot(ArgPolicy.full), reason: fn);
        expect(
          Redactor.sensitivePrefixes.any(fn.startsWith),
          isTrue,
          reason: '$fn should be covered by a sensitive prefix',
        );
      }
    });
  });

  group('robustness', () {
    test('empty args produce nothing rather than an empty object', () {
      expect(Redactor.args('anything:atAll', const {}), isNull);
    });

    test('deeply nested input terminates instead of recursing forever', () {
      Map<String, dynamic> nest(int n) =>
          n == 0 ? {'end': 1} : {'k': nest(n - 1)};
      expect(
        () => Redactor.args('users:heartbeat', nest(50)),
        returnsNormally,
      );
    });

    test('a long list is summarised rather than walked element by element', () {
      final out = Redactor.args('users:heartbeat', {
        'items': List.generate(500, (i) => {'content': sentinel}),
      })!;
      expect(out, isNot(contains(sentinel)));
      expect(out, contains('list:500'));
    });
  });
}
