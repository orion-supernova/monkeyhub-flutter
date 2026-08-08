import 'package:emoji_picker_flutter/emoji_picker_flutter.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monkeyhub/data/emoji_set_full.dart';

/// What this pins: the reaction picker shows every emoji an iPhone can render.
///
/// `emoji_picker_flutter` bundles a `defaultEmojiSet` frozen at Unicode 14.0
/// (2021) — still frozen there in the latest release. The picker used it, so
/// ~290 glyphs the phone renders perfectly were simply not offered: 🫨 and 🩷
/// from Unicode 15.0, 🐦‍🔥 and ⛓️‍💥 from 15.1, 🫩 from 16.0. Nobody notices a
/// missing emoji until they go looking for that one emoji, which is exactly
/// the kind of gap that survives review.
///
/// `lib/data/emoji_set_full.dart` is generated (tool/generate_emoji_set.dart)
/// from Unicode's own emoji-test.txt, so the failure mode this guards against
/// is a regeneration that silently drops or mangles entries — the file is
/// 1,900 lines nobody diffs by eye.
void main() {
  final all = [for (final category in fullEmojiSet) ...category.emoji];

  /// Presentation selectors are noise when comparing two sources: CLDR strips
  /// U+FE0F, emoji-test.txt keeps it, and the bundled set is inconsistent.
  String bare(String emoji) =>
      String.fromCharCodes(emoji.codeUnits.where((u) => u != 0xFE0F)).trim();

  test('nothing the bundled set offered has gone missing', () {
    final ours = all.map((e) => bare(e.emoji)).toSet();
    final theirs = [for (final c in defaultEmojiSet) ...c.emoji];

    final dropped = theirs
        .map((e) => bare(e.emoji))
        .where((e) => e.isNotEmpty && !ours.contains(e))
        .toList();

    expect(dropped, isEmpty, reason: 'dropped vs the package set: $dropped');
  });

  test('covers the three Unicode releases the bundled set predates', () {
    // One representative per release, plus the couple that motivated the fix.
    const expected = <String, String>{
      '🫨': 'shaking face (15.0)',
      '🩷': 'pink heart (15.0)',
      '🫷': 'leftwards pushing hand (15.0)',
      '🪿': 'goose (15.0)',
      '🛜': 'wireless (15.0)',
      '🐦‍🔥': 'phoenix (15.1)',
      '🍋‍🟩': 'lime (15.1)',
      '🙂‍↔️': 'head shaking horizontally (15.1)',
      '⛓️‍💥': 'broken chain (15.1)',
      '🫩': 'face with bags under eyes (16.0)',
      '🪾': 'leafless tree (16.0)',
      '🫆': 'fingerprint (16.0)',
      '🇨🇶': 'flag: Sark (16.0)',
    };

    final ours = all.map((e) => bare(e.emoji)).toSet();
    final missing = [
      for (final entry in expected.entries)
        if (!ours.contains(bare(entry.key))) '${entry.key} ${entry.value}',
    ];
    expect(missing, isEmpty, reason: 'not in the picker: $missing');
  });

  test('no emoji appears in two categories', () {
    final seen = <String>{};
    final duplicates = [
      for (final e in all)
        if (!seen.add(e.emoji)) e.emoji,
    ];
    expect(duplicates, isEmpty);
  });

  test('every category tab has something in it', () {
    // RECENT is injected by the picker at runtime and must not be baked in, or
    // the recents tab renders a frozen list.
    expect(fullEmojiSet.map((c) => c.category), isNot(contains(Category.RECENT)));
    expect(fullEmojiSet, hasLength(8));
    for (final category in fullEmojiSet) {
      expect(category.emoji, isNotEmpty, reason: '${category.category} is empty');
    }
  });

  test('every emoji is named', () {
    // The name doubles as the keyword list (`Emoji.keywords` splits it on
    // ' | '), so an empty one means that glyph is reachable by scrolling only.
    expect(all.where((e) => e.name.trim().isEmpty), isEmpty);
  });

  test('search finds emoji by everyday words', () async {
    // Search was unreachable in this sheet until now — the package only opens
    // it from the bottom action bar, which was disabled — so nothing had ever
    // exercised the keyword data. These are the CLDR keywords, not the Unicode
    // names: 'lol' and 'crying' are how people actually look for 😂.
    final utils = EmojiPickerUtils();
    Future<List<String>> search(String query) async => (await utils.searchEmoji(
          query,
          fullEmojiSet,
          checkPlatformCompatibility: false,
        ))
            .map((e) => e.emoji)
            .toList();

    expect(await search('lol'), contains('😂'));
    expect(await search('hole'), contains('🕳️'));
    expect(await search('phoenix'), contains('🐦‍🔥'));
    expect(await search('shaking'), contains('🫨'));
    expect(await search('pink heart'), contains('🩷'));
    expect(await search('türkiye'), contains('🇹🇷'));
  });

  test('skin tones are only offered where the picker can build them', () {
    // `EmojiPickerUtils.applySkinTone` splices the modifier in after the first
    // code point and re-appends the rest verbatim. For a base that carries a
    // presentation selector — 🕵️, ⛹️, 🏋️ — that yields `<base> <tone> FE0F`,
    // and a U+FE0F directly after a modifier is not a sequence any font has a
    // glyph for: iOS draws the base followed by a loose skin-tone swatch. The
    // generator therefore only sets the flag when the splice lands somewhere
    // valid, and this pins that rule so a regeneration cannot quietly reopen
    // a tone dialog full of broken glyphs.
    final utils = EmojiPickerUtils();
    final broken = <String>[];
    for (final emoji in all.where((e) => e.hasSkinTone)) {
      final toned = utils.applySkinTone(emoji, SkinTone.medium).emoji;
      final modifier = toned.indexOf(SkinTone.medium);
      expect(modifier, greaterThan(0), reason: 'no tone applied to ${emoji.emoji}');
      final after = modifier + SkinTone.medium.length;
      if (after < toned.length && toned.codeUnitAt(after) == 0xFE0F) {
        broken.add(emoji.emoji);
      }
    }
    expect(broken, isEmpty, reason: 'tone splice lands before a U+FE0F: $broken');
  });
}
