@TestOn('vm')
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:monkeyhub/companions/translation/language.dart';
import 'package:monkeyhub/companions/translation/translation_prompt.dart';

/// The gate between a model and a chat bubble.
///
/// `translation_prompt_test.dart` covers the REPAIR — what [sanitize] removes
/// from a raw generation. This covers the VERDICT: given something that
/// survived cleanup, is it a translation, or is it the model talking?
///
/// The distinction is the whole fix. The sanitiser can only strip shapes it
/// recognises, and it is deliberately conservative because an aggressive
/// stripper eats real translations. So there has to be a second question, asked
/// after cleanup and answered with a refusal rather than an edit — otherwise
/// anything the stripper has not seen before goes to a reader as though the
/// model had produced it on purpose.
///
/// Every string below is a shape a small instruct model really produces.
void main() {
  final turkish = languageForCode('tr')!;
  final english = languageForCode('en')!;
  final japanese = languageForCode('ja')!;

  TranslationRejection? verdict(
    String candidate, {
    String source = 'Good morning, how are you?',
    TranslationLanguage? target,
  }) =>
      TranslationPrompt.verify(
        candidate,
        source: source,
        target: target ?? turkish,
      );

  group('the failure everybody actually saw', () {
    /// The reported bug, verbatim in shape: a 0.6B reasoning model narrating
    /// its own task instead of doing it.
    ///
    /// None of the older checks could see this. It is fluent, it is
    /// well-formed, it carries no markup, it uses one writing system — and
    /// when the reader's language is English it is not even in the wrong
    /// language. It reached bubbles because nothing ever asked whether it was
    /// a translation.
    test('a reasoning trace with no tags around it is refused', () {
      for (final narration in [
        "Okay, I need to translate this into Turkish. Let me think about it.",
        'The user wants me to translate the message below.',
        "Let's see. The text says good morning, so in Turkish that would be…",
        'I should keep the emoji and translate the rest.',
        'First, I will identify the source language.',
      ]) {
        expect(
          verdict(narration, target: english),
          isNotNull,
          reason: 'reached a bubble before the contract existed: $narration',
        );
      }
    });

    /// The same narration, into a non-English target. Two independent checks
    /// should catch it, and the test asserts only that one of them did — which
    /// is the point of a contract rather than a single rule.
    test('and refused again when the target is not English', () {
      expect(
        verdict('Okay, the user wants me to translate this into Turkish.'),
        isNotNull,
      );
    });

    /// An answer in the wrong language with no narration at all. Fluent,
    /// preamble-free, and completely useless to the reader.
    test('a fluent answer in the wrong language is refused', () {
      expect(
        verdict(
          'Good morning, how are you doing today my friend?',
          target: turkish,
        ),
        TranslationRejection.wrongLanguage,
      );
    });
  });

  group('the channel-marker decode', () {
    /// Reported from a simulator, and the reason this group exists. The runtime
    /// emitted a harmony channel marker between EVERY token:
    ///
    ///     Okay<|channel|>thought,<|channel|>thought let<|channel|>thought's…
    ///
    /// Stripping only the brackets left the channel NAME glued to the words on
    /// both sides, and what reached the bubble was
    /// `,thought letthought's thought tacklethought this`.
    test('is stripped, brackets and channel name together', () {
      const raw = "Okay<|channel|>thought,<|channel|>thought let<|channel|>"
          "thought's<|channel|>thought tackle<|channel|>thought this";
      final clean = TranslationPrompt.sanitize(
        raw,
        source: 'Bunu çevir',
        target: english,
      );
      expect(clean, isNot(contains('thought')));
      expect(clean, isNot(contains('<|')));
    });

    /// The same marker in the three mangled forms one CPU run produced, none of
    /// them well formed.
    test('is stripped in every mangling seen so far', () {
      for (final raw in [
        '<|channel >thought Merhaba',
        '<| channel>thought Merhaba',
        'Merhaba<channel|>',
        '<|channel|>analysis Merhaba',
        '<|channel|>final Merhaba',
      ]) {
        final clean = TranslationPrompt.sanitize(
          raw,
          source: 'Hello',
          target: turkish,
        );
        expect(clean, 'Merhaba', reason: raw);
      }
    });

    /// The guard on the guard. `afterthought` and `rethought` end in the exact
    /// pattern the interleaved case is matched by, and a translation into
    /// English quietly losing its last word would be worse than the bug this
    /// fixes — so one occurrence is a word and only a repeat is a decoder.
    test('leaves English words that happen to end in it alone', () {
      for (final real in [
        'It was an afterthought, honestly.',
        'I rethought the whole plan yesterday afternoon.',
      ]) {
        expect(
          TranslationPrompt.sanitize(real, source: 'x', target: english),
          real,
        );
      }
    });

    /// …and still strips them when there are enough to be markup rather than
    /// vocabulary.
    test('but strips them once there are too many to be words', () {
      // Including the free-standing one in the middle: past the threshold the
      // stream is wreckage, and a bare `thought` in wreckage is residue too.
      final clean = TranslationPrompt.sanitize(
        "letthought's thought tacklethought this",
        source: 'x',
        target: english,
      );
      expect(clean, isNot(contains('thought')));
    });

    /// And whatever survives all of that is refused rather than rendered.
    test('residue that survives cleanup never reaches a bubble', () {
      expect(
        verdict(",thought letthought's thought tacklethought this",
            target: turkish),
        isNotNull,
      );
    });
  });

  group('accepts a real translation', () {
    /// The whole risk of a strict verdict: it refuses good answers, and a
    /// refusal is invisible — the reader sees "couldn't translate this one"
    /// and has no way to know a perfectly good translation was thrown away.
    test('an ordinary one', () {
      expect(verdict('Günaydın, nasılsın?'), isNull);
    });

    test('one carrying emoji, mentions and a URL', () {
      expect(
        verdict(
          'Günaydın @zeynep 👋 https://example.com adresine bak',
          source: 'Good morning @zeynep 👋 check https://example.com',
        ),
        isNull,
      );
    });

    test('a multi-line one', () {
      expect(
        verdict(
          'Birinci satır\nİkinci satır\nÜçüncü satır',
          source: 'First line\nSecond line\nThird line',
        ),
        isNull,
      );
    });

    /// Japanese writes in two scripts at once, and the script check must not
    /// read the second one as contamination.
    test('one in a script the source did not use', () {
      expect(
        verdict(
          '今日は友達と映画を見に行きました',
          source: 'I went to see a film with a friend today',
          target: japanese,
        ),
        isNull,
      );
    });

    /// Short text carries no reliable language signal, so the detector declines
    /// to answer and this must read that as "no opinion" rather than as
    /// disagreement.
    test('a short one the detector cannot place', () {
      expect(verdict('Tamam', source: 'Alright'), isNull);
    });

    /// Close relatives that share most of their function words. The detector's
    /// preference between them is noise, and acting on it would refuse correct
    /// translations into whichever of the pair it likes less.
    test('one in a language the detector confuses with its neighbour', () {
      final portuguese = languageForCode('pt')!;
      expect(
        verdict(
          'Bom dia, como está você hoje de manhã?',
          source: 'Good morning, how are you this morning?',
          target: portuguese,
        ),
        isNull,
        reason: 'Spanish and Portuguese are not distinguishable here, and '
            'refusing a good translation is worse than passing a poor one',
      );
    });

    /// A sentence that happens to contain a word the preamble list watches for.
    test('one containing a word the preamble check looks for', () {
      expect(
        verdict(
          'Sonuç olarak toplantıyı yarına aldık ve herkese haber verdim',
          source: 'In the end we moved the meeting to tomorrow and told '
              'everyone about it',
        ),
        isNull,
      );
    });
  });

  group('refuses what is not a translation', () {
    test('an announcement, wherever it sits', () {
      expect(verdict('Sure! Günaydın'), TranslationRejection.preamble);
      expect(verdict('Turkish: Günaydın'), TranslationRejection.preamble);
      expect(
        verdict('Günaydın, nasılsın?\nTranslation: Good morning'),
        TranslationRejection.preamble,
      );
    });

    test('nothing at all', () {
      expect(verdict(''), TranslationRejection.empty);
      expect(verdict('   \n '), TranslationRejection.empty);
    });

    test('markup that survived every stripper', () {
      expect(verdict('Merhaba <|foo'), TranslationRejection.markup);
    });

    /// The shape a bad accelerator produces: random tokens across writing
    /// systems nobody involved was using.
    test('token soup', () {
      expect(
        verdict(
          'bareshWAREmentsreshanh畔 antespunkertainment cursesantes代表性curity',
          target: english,
        ),
        TranslationRejection.tokenSoup,
      );
    });

    /// The few-shot turn shows the model two finished answers. A model that
    /// loses the thread hands one back, and for a short message nothing else
    /// here would notice.
    test('one of the prompt\'s own worked examples, handed back', () {
      expect(
        verdict('Merhaba, nasılsın?', source: 'Where did you park the car?'),
        TranslationRejection.echoedExample,
      );
    });

    /// …but not when the message really was that sentence. Somebody does say
    /// hello.
    test('unless the message really was the example', () {
      expect(
        verdict('Merhaba, nasılsın?', source: 'Hello, how are you?'),
        isNull,
      );
    });

    /// Truncation is the worst available failure, because a half-translation
    /// looks exactly like a complete short one.
    test('an answer wildly out of proportion to its source', () {
      const long =
          'We should probably move the meeting to Thursday afternoon because '
          'half the team is travelling on Wednesday and the room is booked.';
      expect(verdict('Perşembe.', source: long), TranslationRejection.length);
    });

    /// The opposite end: a model that answered the message instead of
    /// translating it.
    test('an answer far longer than its source', () {
      expect(
        verdict(
          'Günaydın! ' * 40,
          source: 'Good morning, how are you?',
        ),
        isNotNull,
      );
    });
  });

  group('length is not judged on text too short to judge', () {
    /// At twenty characters a ratio is noise, and a legitimately terse
    /// translation of a terse message must not be refused for being terse.
    test('a short message translating to a shorter one', () {
      expect(verdict('Tamamdır', source: 'Sounds good'), isNull);
    });
  });
}
