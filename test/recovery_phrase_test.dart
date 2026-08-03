import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:monkeyhub/auth/recovery_phrase.dart';
import 'package:monkeyhub/auth/recovery_wordlist.dart';
import 'package:monkeyhub/backend/hashing.dart';

/// Plain `test()` — no `TestWidgetsFlutterBinding`, no asset bundle, no
/// network. That is deliberate and is why the wordlist is a compiled-in const
/// rather than an asset: this file is the tripwire protecting every account's
/// recovery phrase, so it must be the fastest and least flaky file in the
/// suite, not the slowest.
void main() {
  group('wordlist', () {
    test('has exactly 2048 entries', () {
      expect(kRecoveryWordlist.length, 2048);
    });

    test('every entry is 3-8 lowercase ASCII letters', () {
      final shape = RegExp(r'^[a-z]{3,8}$');
      final bad = kRecoveryWordlist.where((w) => !shape.hasMatch(w)).toList();
      expect(bad, isEmpty, reason: 'non-conforming words: $bad');
    });

    test('all entries are distinct', () {
      expect(kRecoveryWordlist.toSet().length, kRecoveryWordlist.length);
    });
  });

  group('generate', () {
    test('yields 12 words, all from the list', () {
      final p = RecoveryPhrase.generate();
      expect(p.words.length, 12);
      for (final w in p.words) {
        expect(kRecoveryWordlist, contains(w));
      }
    });

    test('canonical is the words joined by single spaces', () {
      final p = RecoveryPhrase.generate(random: Random(42));
      expect(p.canonical, p.words.join(' '));
      expect(p.canonical.split(' ').length, 12);
      expect(p.canonical.trim(), p.canonical);
    });

    // RNG sanity, not statistics — kept cheap so the suite stays fast.
    test('200 draws produce at least 190 distinct phrases', () {
      final seen = <String>{};
      for (var i = 0; i < 200; i++) {
        seen.add(RecoveryPhrase.generate().canonical);
      }
      expect(seen.length, greaterThanOrEqualTo(190));
    });
  });

  group('normalize', () {
    // The load-bearing assertion of this entire feature. If a generated phrase
    // does not survive a round trip through the reset screen's normalizer, the
    // account it belongs to is unrecoverable.
    test('round-trips every generated phrase', () {
      for (var i = 0; i < 500; i++) {
        final p = RecoveryPhrase.generate();
        expect(normalizeRecoveryPhrase(p.canonical), p.canonical);
      }
    });

    const phrase =
        'abandon ability able about above absent '
        'absorb abstract absurd abuse access accident';

    test('accepts and folds the shapes people actually save', () {
      final variants = <String, String>{
        'uppercase': phrase.toUpperCase(),
        'mixed case': 'Abandon ABILITY able About above AbSeNt '
            'absorb abstract absurd abuse access accident',
        'leading/trailing space': '   $phrase   ',
        'double spaces': phrase.replaceAll(' ', '  '),
        'newlines': phrase.replaceAll(' ', '\n'),
        'windows newlines': phrase.replaceAll(' ', '\r\n'),
        'non-breaking spaces': phrase.replaceAll(' ', ' '),
        'comma separated': phrase.replaceAll(' ', ', '),
        'hyphenated': phrase.replaceAll(' ', '-'),
        'trailing period': '$phrase.',
        'numbered list': '1. abandon 2. ability 3. able 4. about 5. above '
            '6. absent 7. absorb 8. abstract 9. absurd 10. abuse '
            '11. access 12. accident',
        // Turkish dotted capital İ (U+0130). Dart's locale-independent
        // toLowerCase maps it to plain 'i', which is the CORRECT fold — İ is
        // the Turkish capital of i. Accepting it is right. The dangerous
        // direction is dotless ı, covered in the rejection group below.
        'turkish dotted I': phrase.replaceFirst('ability', 'abİlity'),
      };
      variants.forEach((label, input) {
        expect(normalizeRecoveryPhrase(input), phrase, reason: label);
      });
    });

    test('rejects anything that is not 12 known words', () {
      final rejected = <String, String>{
        'eleven words': 'abandon ability able about above absent '
            'absorb abstract absurd abuse access',
        'thirteen words': '$phrase account',
        'unknown word': phrase.replaceFirst('abandon', 'hunter2'),
        'empty': '',
        'whitespace only': '   ',
        'punctuation only': '... ,,, ---',
        // Turkish dotless ı (U+0131) does NOT fold to i, so the token stays
        // outside the wordlist and is rejected loudly. This is the case that
        // matters: a silent fold here would hash to the wrong value and lock
        // the account. Loud rejection is recoverable; a wrong hash is not.
        'turkish dotless i': phrase.replaceFirst('ability', 'abılıty'),
        'accented': phrase.replaceFirst('able', 'ablé'),
        // A lost space makes one token, not two. Failing is correct.
        'run together': phrase.replaceFirst('abandon ability', 'abandonability'),
      };
      rejected.forEach((label, input) {
        expect(normalizeRecoveryPhrase(input), isNull, reason: label);
      });
    });

    // recoveryResetHashes depends on this returning null to fall back to the
    // legacy hash. If normalization ever started accepting freehand text,
    // every legacy account would quietly stop being able to reset.
    test('returns null for legacy freehand phrases', () {
      expect(normalizeRecoveryPhrase('my dog barney'), isNull);
      expect(normalizeRecoveryPhrase('correct horse battery staple'), isNull);
    });

    test('fromWords rebuilds a valid phrase and rejects an invalid one', () {
      expect(RecoveryPhrase.fromWords(phrase.split(' '))?.canonical, phrase);
      expect(RecoveryPhrase.fromWords(['hunter2']), isNull);
    });
  });

  group('hashing', () {
    const phrase =
        'abandon ability able about above absent '
        'absorb abstract absurd abuse access accident';

    // THE TRIPWIRE. This constant was computed once, from the canonical form
    // defined in recovery_phrase.dart. If anyone changes the separator, the
    // case rule, or the text encoding, this fails here rather than locking a
    // real person out of their account. Do not "fix" it by recomputing the
    // expected value — work out what changed and why.
    test('golden hash is stable', () {
      expect(
        recoveryPhraseHash(phrase),
        '68c6ab3eba220da70c0fc012ba5f1b6107a8b5a24a4a7b7354984d6e7aa2137b',
      );
    });

    test('recoveryPhraseHash and sha256Hash cannot diverge', () {
      final p = RecoveryPhrase.generate();
      expect(recoveryPhraseHash(p.canonical), sha256Hash(p.canonical));
    });
  });

  group('recoveryWordCount', () {
    test('counts tokens under the same split rule as normalize', () {
      expect(recoveryWordCount(''), 0);
      expect(recoveryWordCount('   '), 0);
      expect(recoveryWordCount('abandon'), 1);
      expect(recoveryWordCount('abandon  ability\nable'), 3);
      expect(recoveryWordCount('1. abandon 2. ability'), 2);
      expect(
        recoveryWordCount(RecoveryPhrase.generate().canonical),
        12,
      );
    });

    test('counts unknown words too, so the counter never misleads', () {
      // The counter reports shape, not validity — it must not double as a
      // "which word is wrong" oracle.
      expect(recoveryWordCount('hunter2 swordfish'), 2);
    });
  });
}
