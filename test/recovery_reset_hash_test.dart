import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:monkeyhub/auth/recovery_phrase.dart';
import 'package:monkeyhub/backend/hashing.dart';

/// Pins the backwards-compatibility contract between the client and
/// `auth.resetPasswordWithRecoveryKey`.
///
/// Accounts created before the 12-word scheme stored `sha256(input.trim())` of
/// a freehand string. The server can never upgrade those on its own — it never
/// sees plaintext — so the client sends two candidate hashes and the server
/// accepts either, permanently. If this file goes red, some population of real
/// users has quietly lost the ability to reset their password.
void main() {
  group('new 12-word phrases', () {
    test('a phrase pasted exactly as displayed satisfies BOTH slots', () {
      // This is a genuinely valuable safety property, not an accident: the
      // form we display IS the canonical form, and trimming it returns itself.
      // So even if normalizeRecoveryPhrase developed a bug, an exact paste
      // would still get the user back into their account. It is why the legacy
      // slot is kept permanently rather than sunset.
      final p = RecoveryPhrase.generate(random: Random(7));
      final h = recoveryResetHashes(p.canonical);

      expect(h.primary, recoveryPhraseHash(p.canonical));
      expect(h.legacy, recoveryPhraseHash(p.canonical));
    });

    test('mangled case, spacing and newlines still hash canonically', () {
      final p = RecoveryPhrase.generate(random: Random(11));
      final expected = recoveryPhraseHash(p.canonical);

      final mangled = <String, String>{
        'uppercase': p.canonical.toUpperCase(),
        'padded': '  ${p.canonical}  ',
        'double spaced': p.canonical.replaceAll(' ', '   '),
        'newline separated': p.canonical.replaceAll(' ', '\n'),
        'comma separated': p.canonical.replaceAll(' ', ', '),
      };

      mangled.forEach((label, raw) {
        expect(recoveryResetHashes(raw).primary, expected, reason: label);
      });
    });
  });

  group('legacy freehand phrases', () {
    test('fall back to the raw trimmed hash in both slots', () {
      const raw = 'My dog Barney';
      final h = recoveryResetHashes(raw);

      expect(h.legacy, sha256Hash('My dog Barney'));
      // normalizeRecoveryPhrase returns null here, so primary has nothing
      // canonical to offer and mirrors the legacy hash rather than sending a
      // hash of something the user never typed.
      expect(h.primary, h.legacy);
    });

    test('are matched on the trimmed string, preserving inner case', () {
      final h = recoveryResetHashes('   Correct Horse   ');
      expect(h.legacy, sha256Hash('Correct Horse'));
    });

    test('twelve list words in the wrong case still reach the legacy slot',
        () {
      // The awkward middle case: normalization succeeds, so `primary` is the
      // canonical hash and will NOT match a legacy row — the legacy slot is
      // the only thing that gets this user in.
      const raw = 'Abandon Ability Able About Above Absent '
          'Absorb Abstract Absurd Abuse Access Accident';
      final h = recoveryResetHashes(raw);

      expect(h.primary, recoveryPhraseHash(raw.toLowerCase()));
      expect(h.legacy, sha256Hash(raw));
      expect(h.primary, isNot(h.legacy));
    });
  });

  group('invariants', () {
    test('legacy is never empty, for any input', () {
      // We must never send fewer than the two relevant candidates — dropping
      // one silently halves who can reset.
      for (final raw in <String>[
        '',
        '   ',
        'hunter2',
        'my dog barney',
        RecoveryPhrase.generate().canonical,
        '1. abandon 2. ability',
      ]) {
        final h = recoveryResetHashes(raw);
        expect(h.legacy, isNotEmpty, reason: 'legacy for "$raw"');
        expect(h.primary, isNotEmpty, reason: 'primary for "$raw"');
      }
    });

    test('is deterministic', () {
      final p = RecoveryPhrase.generate(random: Random(3));
      final a = recoveryResetHashes(p.canonical);
      final b = recoveryResetHashes(p.canonical);
      expect(a.primary, b.primary);
      expect(a.legacy, b.legacy);
    });
  });
}
