import 'dart:io';
import 'dart:ui' show Locale;

import 'package:flutter_test/flutter_test.dart';
import 'package:monkeyhub/data/emoji_search_index.dart';

/// What this pins: emoji search matches the language the app is in.
///
/// The picker's search used to run `EmojiPickerUtils.searchEmoji` over
/// `fullEmojiSet`, whose `Emoji.name` is generated from the **English** CLDR
/// annotations — so a Turkish user typing "kalp" or a Spanish one typing
/// "corazón" got nothing, in an app that ships in twelve languages. The
/// package could not be configured out of this either: it flattens the emoji
/// set into a process-wide singleton cache on the first search and never
/// invalidates it, so even a per-locale set would have frozen search to
/// whichever language searched first.
///
/// The terms below are hardcoded on purpose. Deriving them from the same CLDR
/// data the index reads would pass no matter how broken the matcher is; these
/// are words a speaker of the language would actually type.
void main() {
  // rootBundle needs a binding; the index reads its overlays as assets.
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<List<String>> search(String tag, String query) async {
    final parts = tag.split('_');
    final locale =
        parts.length == 1 ? Locale(parts.first) : Locale(parts.first, parts[1]);
    final index = await EmojiSearchIndex.forLocale(locale);
    return index.search(query).map((e) => e.emoji).toList();
  }

  group('finds an emoji by its own language', () {
    // One per script family, because the failure modes differ: Latin breaks on
    // diacritics and case, Arabic on optional vowel marks, CJK on there being
    // no word boundary to prefix-match against.
    const cases = <String, Map<String, String>>{
      'tr': {'kalp': '❤️', 'gülen': '😀', 'kırmızı': '❤️'},
      'es': {'corazón': '❤️', 'llorando': '😂', 'fuego': '🔥'},
      'fr': {'coeur': '❤️', 'feu': '🔥'},
      'pt': {'coração': '❤️', 'fogo': '🔥'},
      'sv': {'hjärta': '❤️', 'eld': '🔥'},
      'de': {'heart': '❤️'}, // No overlay — English still works.
      'ja': {'笑': '😂', 'ハート': '❤️'},
      'zh': {'心': '❤️', '哭': '😂'},
      'ko': {'하트': '❤️', '눈물': '😂'},
      'ar': {'قلب': '❤️', 'ضحك': '😂'},
      'hi': {'दिल': '❤️', 'आग': '🔥'},
    };

    for (final locale in cases.entries) {
      test(locale.key, () async {
        for (final probe in locale.value.entries) {
          expect(
            await search(locale.key, probe.key),
            contains(probe.value),
            reason: '"${probe.key}" should find ${probe.value} in ${locale.key}',
          );
        }
      });
    }
  });

  test('English still matches in every locale', () async {
    // Not a fallback for gaps — a deliberate second set of terms. Half the
    // emoji anyone can name, they can only name in English, and people paste
    // ":fire:"-style words into non-English apps constantly.
    for (final language in [...emojiOverlayLanguages, 'en', 'de']) {
      expect(
        await search(language, 'fire'),
        contains('🔥'),
        reason: '"fire" stopped finding 🔥 under $language',
      );
      expect(await search(language, 'phoenix'), contains('🐦‍🔥'));
    }
  });

  test('pt_BR reads the pt overlay', () async {
    // CLDR's pt.xml *is* Brazilian Portuguese, so there is no pt_BR file to
    // ship; the fold onto languageCode is what makes that work.
    expect(
      await search('pt', 'coração'),
      await search('pt_BR', 'coração'),
    );
    expect(await search('pt_BR', 'coração'), contains('❤️'));
  });

  test('diacritics and Turkish case do not have to be typed exactly', () async {
    // Dart's toLowerCase() is locale-independent: it maps I to i, never to ı.
    // A Turkish user with caps lock on, or one who cannot be bothered with
    // the option key, still has to find the emoji.
    expect(await search('tr', 'KIRMIZI'), contains('❤️'));
    expect(await search('tr', 'kirmizi'), contains('❤️'));
    expect(await search('tr', 'GÜLEN'), contains('😀'));
    expect(await search('es', 'corazon'), contains('❤️'));
    expect(await search('sv', 'hjarta'), contains('❤️'));
    expect(await search('en', 'turkiye'), contains('🇹🇷'));
    expect(await search('tr', 'türkiye'), contains('🇹🇷'));
  });

  test('a multi-word query narrows instead of widening', () async {
    final both = await search('tr', 'kırmızı kalp');
    final justHeart = await search('tr', 'kalp');
    expect(both, contains('❤️'));
    expect(both.length, lessThan(justHeart.length));
  });

  test('pasting a glyph finds that glyph', () async {
    expect(await search('ja', '🫩'), contains('🫩'));
  });

  test('an empty or punctuation-only query matches nothing', () async {
    expect(await search('tr', ''), isEmpty);
    expect(await search('tr', '   '), isEmpty);
    expect(await search('tr', '...'), isEmpty);
  });

  test('the overlay languages match the files on disk', () {
    // Two lists have to agree — this one and `_overlayLanguages` in
    // tool/generate_emoji_set.dart. A language in the set with no file loads
    // nothing and silently degrades to English; a file with no entry in the
    // set is dead weight in the bundle.
    final onDisk = Directory('assets/emoji')
        .listSync()
        .whereType<File>()
        .map((f) => f.uri.pathSegments.last)
        .where((name) => name.endsWith('.txt'))
        .map((name) => name.substring('keywords_'.length, name.length - 4))
        .toSet();
    expect(onDisk, emojiOverlayLanguages);
  });

  test('folding is symmetric across the scripts we ship', () {
    // Applied to both the index and the query, so any pair that folds equal
    // will match and any pair that does not, will not.
    expect(foldEmojiSearchText('KIRMIZI'), foldEmojiSearchText('kırmızı'));
    expect(foldEmojiSearchText('İSTANBUL'), foldEmojiSearchText('istanbul'));
    expect(foldEmojiSearchText('Coração'), foldEmojiSearchText('coracao'));
    expect(foldEmojiSearchText('HJÄRTA'), foldEmojiSearchText('hjarta'));
    expect(foldEmojiSearchText('ハート'), foldEmojiSearchText('はーと'));
    expect(foldEmojiSearchText('قَلْب'), foldEmojiSearchText('قلب'));
    // Devanagari is left alone — the matras are the word.
    expect(foldEmojiSearchText('दिल'), 'दिल');
  });
}
