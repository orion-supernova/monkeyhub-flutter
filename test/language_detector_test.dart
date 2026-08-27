@TestOn('vm')
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:monkeyhub/companions/translation/language_detector.dart';

/// The filter in front of the model, and the only reason room-wide translation
/// is affordable.
///
/// What is asserted here is the ASYMMETRY the detector is built around, not its
/// accuracy. A wrong `null` costs one unnecessary model run — a second of a
/// phone's attention, and the right answer still comes out. A wrong POSITIVE
/// that happens to name the reader's own language makes Sebastian silently
/// refuse to translate a message somebody asked about, with no way to force it.
///
/// So the tests come in two kinds:
///
///  * **Must be right** — text where a confident answer is required, because
///    the whole performance argument rests on it (a transcript already in the
///    reader's language must not reach the model).
///  * **Must not be confidently wrong** — short, mixed and ambiguous text,
///    where `null` is the correct answer and anything else is a bug.
void main() {
  group('script detection', () {
    // Each of these is decisive on the character set alone, which is what makes
    // them cheap: no word list is consulted at all.
    test('names the language from the script', () {
      expect(LanguageDetector.detect('это сообщение на русском языке'), 'ru');
      expect(LanguageDetector.detect('αυτό είναι ένα μήνυμα στα ελληνικά'), 'el');
      expect(LanguageDetector.detect('यह एक हिंदी संदेश है'), 'hi');
      expect(LanguageDetector.detect('นี่คือข้อความภาษาไทย'), 'th');
      expect(LanguageDetector.detect('זו הודעה בעברית'), 'he');
      expect(LanguageDetector.detect('이것은 한국어 메시지입니다'), 'ko');
    });

    /// The one case a plurality vote gets wrong on its own: Japanese prose is
    /// usually MORE han than kana, so counting alone calls it Chinese. Any kana
    /// at all has to settle it.
    test('kana beats a han plurality', () {
      expect(LanguageDetector.detect('今日は友達と映画を見に行きました'), 'ja');
      expect(LanguageDetector.detect('这是一条中文消息，今天天气很好'), 'zh');
    });

    /// Two pairs that share a block and are separated only by the letters one
    /// of them adds.
    test('separates languages that share a script', () {
      expect(LanguageDetector.detect('це повідомлення українською мовою'), 'uk');
      expect(LanguageDetector.detect('این یک پیام فارسی است که نوشته شده'), 'fa');
      expect(LanguageDetector.detect('هذه رسالة مكتوبة باللغة العربية'), 'ar');
    });
  });

  group('latin languages', () {
    test('names the language from its function words', () {
      expect(LanguageDetector.detect('this is a message that you can read'), 'en');
      expect(LanguageDetector.detect('das ist eine nachricht und ich lese sie nicht'), 'de');
      expect(LanguageDetector.detect('bu bir mesaj ve daha fazlası için bak'), 'tr');
      expect(LanguageDetector.detect('c\'est un message pour vous avec des mots'), 'fr');
    });

    /// The case function words cannot reach: one word, no stopwords, and the
    /// answer written entirely in its diacritics.
    test('falls back to letters a language does not share', () {
      expect(LanguageDetector.detect('Nasılsın bugün?'), 'tr');
    });
  });

  group('refuses to guess', () {
    /// Every one of these is a real chat message and every one of them would be
    /// a bug to answer. "no" alone is Spanish, Italian, English and Polish.
    test('returns null on text too short to carry a signal', () {
      expect(LanguageDetector.detect('ok'), isNull);
      expect(LanguageDetector.detect('no'), isNull);
      expect(LanguageDetector.detect('haha'), isNull);
      expect(LanguageDetector.detect('+1'), isNull);
    });

    /// Emoji are not letters in any language, and a bubble of them has nothing
    /// to translate. They must not clear the length floor by being characters.
    test('returns null on emoji and punctuation', () {
      expect(LanguageDetector.detect('😂😂😂😂😂😂😂😂😂😂'), isNull);
      expect(LanguageDetector.detect('!!!!!!!!!!!!'), isNull);
      expect(LanguageDetector.detect('...???...???'), isNull);
    });

    /// A URL is made of latin letters and would otherwise register as a
    /// confident English verdict on a message with no English in it.
    test('does not read a URL as language', () {
      expect(
        LanguageDetector.detect('https://example.com/some/very/long/path/here'),
        isNull,
      );
      expect(LanguageDetector.detect('@someone @someone_else @third.one'), isNull);
    });
  });

  group('isWorthTranslating', () {
    /// This is the gate that keeps the queue empty in a busy group room, where
    /// reactions-as-messages are a large fraction of the traffic. Each of these
    /// would otherwise cost a second of inference to be handed back unchanged.
    test('rejects what has no words in it', () {
      expect(LanguageDetector.isWorthTranslating('ok'), isFalse);
      expect(LanguageDetector.isWorthTranslating('👍'), isFalse);
      expect(LanguageDetector.isWorthTranslating('😂😂😂'), isFalse);
      expect(LanguageDetector.isWorthTranslating('+1'), isFalse);
      expect(LanguageDetector.isWorthTranslating('   '), isFalse);
      expect(LanguageDetector.isWorthTranslating('https://example.com'), isFalse);
    });

    test('accepts a real sentence', () {
      expect(LanguageDetector.isWorthTranslating('merhaba nasılsın'), isTrue);
      expect(LanguageDetector.isWorthTranslating('今日はいい天気ですね'), isTrue);
    });

    /// A short message in a non-latin script still has letters, and letters are
    /// what the floor counts — so it must not be discarded for being brief in a
    /// script that says more per character.
    test('counts letters, not characters', () {
      expect(LanguageDetector.isWorthTranslating('!!! ok !!! 😂'), isFalse);
      expect(LanguageDetector.isWorthTranslating('güzelmiş bu'), isTrue);
    });
  });
}
