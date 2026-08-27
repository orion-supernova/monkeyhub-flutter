@TestOn('vm')
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:monkeyhub/companions/translation/language.dart';

import 'support/translation_eval.dart';

/// The benchmark's own arithmetic.
///
/// A harness nobody has checked is worse than no harness: it produces a number
/// that looks like evidence, and a model swap decided on a miscounted pass rate
/// is a 328 MB download shipped to everyone for nothing. So the scorer is
/// tested against hand-written outputs whose verdict is not in doubt, and the
/// fixture is checked for the shape the scorer assumes.
void main() {
  final golden = GoldenCase.load();

  group('the fixture', () {
    test('is big enough and broad enough to mean something', () {
      expect(golden.length, greaterThanOrEqualTo(100));
      final pairs = golden.map((c) => c.pair).toSet();
      expect(pairs.length, greaterThanOrEqualTo(16));
    });

    /// Every target has to be a language the app actually offers, or the case
    /// is measuring something Sebastian will never be asked to do.
    test('only names languages Sebastian offers', () {
      final offered = {for (final l in kTranslationLanguages) l.code};
      for (final c in golden) {
        expect(offered, contains(c.target), reason: c.source);
        expect(offered, contains(c.sourceLanguage), reason: c.source);
      }
    });

    /// The four writing systems that have historically broken something: Latin,
    /// Han, Arabic and Cyrillic. A set that was all-Latin would have passed
    /// every version of this pipeline, including the broken ones.
    test('spans the scripts that have broken things before', () {
      final targets = golden.map((c) => c.target).toSet();
      expect(targets, containsAll(['tr', 'zh', 'ja', 'ar', 'ru']));
    });

    test('every kind it declares is one the scorer handles', () {
      const known = {
        GoldenKind.greeting,
        GoldenKind.logistics,
        GoldenKind.casual,
        GoldenKind.slang,
        GoldenKind.entities,
        GoldenKind.multiline,
        GoldenKind.hostile,
        GoldenKind.sameLanguage,
      };
      for (final c in golden) {
        expect(known, contains(c.kind), reason: c.source);
      }
    });
  });

  group('scoring one case', () {
    const plain = GoldenCase(
      source: 'Good morning, how are you?',
      sourceLanguage: 'en',
      target: 'tr',
      kind: GoldenKind.greeting,
    );

    test('a good translation passes', () {
      expect(scoreCase(plain, 'Günaydın, nasılsın?').passed, isTrue);
    });

    test('a refusal is counted as no output, not as a pass', () {
      final o = scoreCase(plain, null);
      expect(o.passed, isFalse);
      expect(o.failure, EvalFailure.noOutput);
    });

    /// The headline metric. It has to come out of the scorer under exactly the
    /// name the report prints, or the number and the label drift apart.
    test('a preamble is counted as a preamble leak', () {
      final o = scoreCase(plain, 'Sure! Here is the translation: Günaydın');
      expect(o.failure, EvalFailure.preambleLeak);
      expect(EvalReport('x', [o]).preambleLeakRate, 1.0);
    });

    test('an untranslated answer is counted as the wrong language', () {
      final o = scoreCase(
        plain,
        'Good morning, how are you doing today my friend?',
      );
      expect(o.failure, EvalFailure.wrongLanguage);
    });
  });

  group('the structural checks a similarity score would miss', () {
    const withEntities = GoldenCase(
      source: 'check https://example.com/a?b=1 and tell @ada',
      sourceLanguage: 'en',
      target: 'tr',
      kind: GoldenKind.entities,
    );

    test('a dropped mention fails even though the prose is fine', () {
      final o = scoreCase(
        withEntities,
        'https://example.com/a?b=1 adresine bak ve söyle',
      );
      expect(o.failure, EvalFailure.lostEntity);
    });

    test('a rewritten URL fails', () {
      final o = scoreCase(
        withEntities,
        'https://example.com/a adresine bak ve @ada ya söyle',
      );
      expect(o.failure, EvalFailure.lostEntity);
    });

    test('both surviving passes', () {
      final o = scoreCase(
        withEntities,
        'https://example.com/a?b=1 adresine bak ve @ada ya söyle',
      );
      expect(o.passed, isTrue);
    });

    const withEmoji = GoldenCase(
      source: "that's 🔥🔥 sending me 💀",
      sourceLanguage: 'en',
      target: 'tr',
      kind: GoldenKind.slang,
    );

    test('a swallowed emoji fails', () {
      expect(scoreCase(withEmoji, 'bu 🔥 beni bitiriyor').failure,
          EvalFailure.lostEntity);
    });

    test('emoji that survive in a different order pass', () {
      expect(scoreCase(withEmoji, 'beni bitiriyor 💀 bu 🔥🔥').passed, isTrue);
    });

    const multiline = GoldenCase(
      source: 'Shopping list:\n- milk\n- bread',
      sourceLanguage: 'en',
      target: 'tr',
      kind: GoldenKind.multiline,
    );

    test('a message flattened onto one line fails', () {
      expect(scoreCase(multiline, 'Alışveriş listesi: süt, ekmek').failure,
          EvalFailure.reflowed);
    });

    test('the same line count passes', () {
      expect(
        scoreCase(multiline, 'Alışveriş listesi:\n- süt\n- ekmek').passed,
        isTrue,
      );
    });

    const sameLanguage = GoldenCase(
      source: 'Good morning, how are you today?',
      sourceLanguage: 'en',
      target: 'en',
      kind: GoldenKind.sameLanguage,
    );

    test('text already in the target passes when nothing is done to it', () {
      expect(scoreCase(sameLanguage, null).passed, isTrue);
      expect(
        scoreCase(sameLanguage, 'Good morning, how are you today?').passed,
        isTrue,
      );
    });

    test('and fails when the model paraphrases it anyway', () {
      expect(
        scoreCase(sameLanguage, 'Good morning! How are you doing today?')
            .failure,
        EvalFailure.paraphrasedSameLanguage,
      );
    });
  });

  group('the report', () {
    const c = GoldenCase(
      source: 'Good morning, how are you?',
      sourceLanguage: 'en',
      target: 'tr',
      kind: GoldenKind.greeting,
    );

    test('counts a pass rate and a first-try rate separately', () {
      final report = EvalReport('brain', [
        scoreCase(c, 'Günaydın, nasılsın?'),
        scoreCase(c, 'Günaydın, nasılsın?', attempts: 2),
        scoreCase(c, null),
        scoreCase(c, null),
      ]);
      expect(report.passRate, 0.5);
      expect(
        report.firstTryRate,
        0.25,
        reason: 'a brain that is only right after a resample is half as fast '
            'as its latency suggests, and the report has to say so',
      );
    });

    test('prints every headline number', () {
      final text = EvalReport('brain', [scoreCase(c, 'Günaydın')]).format();
      for (final label in [
        'pass rate',
        'first-try rate',
        'preamble leak',
        'wrong language',
        'mean latency',
        'by pair',
      ]) {
        expect(text, contains(label));
      }
    });

    test('an empty run reports zero rather than dividing by it', () {
      final empty = EvalReport('brain', const []);
      expect(empty.passRate, 0);
      expect(empty.meanLatency, Duration.zero);
      expect(empty.format(), contains('cases            0'));
    });
  });
}
