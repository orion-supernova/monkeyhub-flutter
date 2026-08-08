// Regenerates `lib/data/emoji_set_full.dart` — the emoji list the reaction
// picker renders.
//
//   dart run tool/generate_emoji_set.dart
//
// Why this exists: `emoji_picker_flutter` bundles its own `defaultEmojiSet`,
// but that list has been frozen at Unicode 14.0 (2021) since well before the
// version we depend on, so every glyph added in Unicode 15.0, 15.1 and 16.0 is
// simply absent from the picker even though the phone can render it. Rather
// than fork the package we generate a complete set here and hand it to
// `Config.emojiSet`.
//
// Sources (downloaded once, then cached under .dart_tool/):
//   * Unicode emoji-test.txt — the authoritative glyph list, RGI ordering, and
//     the group/subgroup split the category tabs are built from.
//   * CLDR annotations — display names and search keywords.
//
// The output is checked in; the app never touches the network for this.

import 'dart:convert';
import 'dart:io';

/// Unicode Emoji revision to build against.
const _emojiVersion = '16.0';

const _emojiTestUrl =
    'https://unicode.org/Public/emoji/$_emojiVersion/emoji-test.txt';
const _cldrAnnotationsUrl =
    'https://raw.githubusercontent.com/unicode-org/cldr/main/common/annotations/en.xml';
const _cldrDerivedAnnotationsUrl =
    'https://raw.githubusercontent.com/unicode-org/cldr/main/common/annotationsDerived/en.xml';

const _outputPath = 'lib/data/emoji_set_full.dart';
const _cacheDir = '.dart_tool/emoji_set_source';

/// Unicode group name -> the `Category` value the picker tabs use.
///
/// The package only has eight categories, so "People & Body" folds into
/// SMILEYS — which is also where the bundled set put it, so the tab layout
/// users already know is preserved. "Component" (bare skin-tone swatches and
/// hair modifiers) is not pickable on its own and is dropped.
const _categoryByGroup = <String, String>{
  'Smileys & Emotion': 'SMILEYS',
  'People & Body': 'SMILEYS',
  'Animals & Nature': 'ANIMALS',
  'Food & Drink': 'FOODS',
  'Travel & Places': 'TRAVEL',
  'Activities': 'ACTIVITIES',
  'Objects': 'OBJECTS',
  'Symbols': 'SYMBOLS',
  'Flags': 'FLAGS',
};

/// Emission order of the category tabs.
const _categoryOrder = <String>[
  'SMILEYS',
  'ANIMALS',
  'FOODS',
  'TRAVEL',
  'ACTIVITIES',
  'OBJECTS',
  'SYMBOLS',
  'FLAGS',
];

const _skinToneModifiers = <int>[0x1F3FB, 0x1F3FC, 0x1F3FD, 0x1F3FE, 0x1F3FF];
const _variationSelector16 = 0xFE0F;

class _ParsedEmoji {
  _ParsedEmoji(this.emoji, this.category, this.unicodeName);

  final String emoji;
  final String category;
  final String unicodeName;
  bool hasSkinTone = false;
}

Future<void> main(List<String> args) async {
  final emojiTest = await _source('emoji-test.txt', _emojiTestUrl);
  final annotations = await _source('cldr-en.xml', _cldrAnnotationsUrl);
  final derived = await _source('cldr-en-derived.xml', _cldrDerivedAnnotationsUrl);

  final entries = _parseEmojiTest(emojiTest);
  final names = <String, String>{};
  final keywords = <String, List<String>>{};
  for (final xml in [annotations, derived]) {
    _parseAnnotations(xml, names: names, keywords: keywords);
  }

  final buffer = _render(entries, names: names, keywords: keywords);
  File(_outputPath).writeAsStringSync(buffer);

  final toned = entries.where((e) => e.hasSkinTone).length;
  stdout.writeln('Wrote $_outputPath');
  stdout.writeln('  ${entries.length} emoji, $toned with skin tones');
  for (final category in _categoryOrder) {
    final n = entries.where((e) => e.category == category).length;
    stdout.writeln('  $category: $n');
  }
}

/// Reads a source file from the cache, downloading it the first time.
Future<String> _source(String filename, String url) async {
  final file = File('$_cacheDir/$filename');
  if (file.existsSync()) return file.readAsStringSync();

  stdout.writeln('Downloading $url');
  final client = HttpClient();
  try {
    final request = await client.getUrl(Uri.parse(url));
    final response = await request.close();
    if (response.statusCode != 200) {
      throw StateError('GET $url failed: HTTP ${response.statusCode}');
    }
    final body = await response.transform(utf8.decoder).join();
    file.parent.createSync(recursive: true);
    file.writeAsStringSync(body);
    return body;
  } finally {
    client.close();
  }
}

/// Parses emoji-test.txt into the pickable, fully-qualified base emoji.
///
/// Skin-tone variants are not emitted as their own grid entries — the picker
/// derives them at runtime from the base glyph — but they are what tells us
/// which bases *support* tones, so they are read and then folded away.
List<_ParsedEmoji> _parseEmojiTest(String content) {
  final line = RegExp(r'^([0-9A-Fa-f ]+?)\s*;\s*(\S+)\s*#\s(\S+)\sE\S+\s(.+)$');

  var group = '';
  final ordered = <_ParsedEmoji>[];
  final byEmoji = <String, _ParsedEmoji>{};
  final fullyQualified = <String>{};
  final tonedSequences = <List<int>>[];

  for (final raw in const LineSplitter().convert(content)) {
    if (raw.startsWith('# group:')) {
      group = raw.substring('# group:'.length).trim();
      continue;
    }
    if (raw.isEmpty || raw.startsWith('#')) continue;

    final match = line.firstMatch(raw);
    if (match == null) continue;
    if (match.group(2) != 'fully-qualified') continue;

    final codePoints = match
        .group(1)!
        .trim()
        .split(RegExp(r'\s+'))
        .map((hex) => int.parse(hex, radix: 16))
        .toList();
    final emoji = String.fromCharCodes(codePoints);
    fullyQualified.add(emoji);

    if (codePoints.any(_skinToneModifiers.contains)) {
      tonedSequences.add(codePoints);
      continue;
    }

    final category = _categoryByGroup[group];
    if (category == null) continue; // Component group.

    final parsed = _ParsedEmoji(emoji, category, match.group(4)!.trim());
    ordered.add(parsed);
    byEmoji[emoji] = parsed;
  }

  _markSkinTones(tonedSequences, byEmoji, fullyQualified);
  return ordered;
}

/// Flags the bases whose skin tones the picker can actually produce.
///
/// The package builds a toned glyph by splicing the modifier in after the
/// first code point (`EmojiPickerUtils.applySkinTone`). For most emoji that is
/// exactly right, but for a base that carries a U+FE0F presentation selector —
/// 🕵️, ⛹️, 🏋️ and friends — it yields `<base> FE0F <tone>`, where Unicode
/// wants the selector dropped: `<base> <tone>`. Rather than offer a tone
/// dialog that emits sequences no font has a glyph for, we only set the flag
/// when the spliced result is a real RGI sequence for every one of the five
/// tones. The affected emoji still render fine, they just open no tone dialog.
void _markSkinTones(
  List<List<int>> tonedSequences,
  Map<String, _ParsedEmoji> byEmoji,
  Set<String> fullyQualified,
) {
  final candidates = <String>{};
  for (final sequence in tonedSequences) {
    final stripped = sequence.where((cp) => !_skinToneModifiers.contains(cp));
    candidates.add(String.fromCharCodes(stripped));
  }

  for (final base in candidates) {
    final parsed = byEmoji[base];
    if (parsed == null) continue; // Multi-tone sequence with no plain base.
    final renderable = _skinToneModifiers.every(
      (tone) => fullyQualified.contains(_applySkinTone(base, tone)),
    );
    if (renderable) parsed.hasSkinTone = true;
  }
}

/// Mirrors `EmojiPickerUtils.applySkinTone` so we can check its output.
String _applySkinTone(String emoji, int tone) {
  final units = emoji.codeUnits;
  final head = units.take(2);
  final tail = units.length >= 2 ? units.skip(2) : const <int>[];
  return String.fromCharCodes([...head, ...String.fromCharCode(tone).codeUnits, ...tail]);
}

/// Pulls display names (`type="tts"`) and search keywords out of a CLDR
/// annotations file. CLDR strips U+FE0F from its `cp` attributes, so keys are
/// normalised the same way on both sides.
void _parseAnnotations(
  String xml, {
  required Map<String, String> names,
  required Map<String, List<String>> keywords,
}) {
  final annotation = RegExp(
    r'<annotation cp="([^"]+)"(\s+type="tts")?\s*>([^<]*)</annotation>',
  );

  for (final match in annotation.allMatches(xml)) {
    final key = _unescapeXml(match.group(1)!);
    final value = _unescapeXml(match.group(3)!).trim();
    if (value.isEmpty) continue;

    if (match.group(2) != null) {
      names[key] = value;
    } else {
      keywords[key] = value
          .split('|')
          .map((keyword) => keyword.trim())
          .where((keyword) => keyword.isNotEmpty)
          .toList();
    }
  }
}

String _unescapeXml(String value) => value
    .replaceAll('&lt;', '<')
    .replaceAll('&gt;', '>')
    .replaceAll('&quot;', '"')
    .replaceAll('&apos;', "'")
    .replaceAll('&amp;', '&');

/// CLDR keys have no presentation selectors.
String _annotationKey(String emoji) =>
    String.fromCharCodes(emoji.codeUnits.where((u) => u != _variationSelector16));

String _render(
  List<_ParsedEmoji> entries, {
  required Map<String, String> names,
  required Map<String, List<String>> keywords,
}) {
  final out = StringBuffer()
    ..writeln('// GENERATED FILE — DO NOT EDIT BY HAND.')
    ..writeln('//')
    ..writeln('// Regenerate with: dart run tool/generate_emoji_set.dart')
    ..writeln('// Source: Unicode Emoji $_emojiVersion + CLDR annotations (en).')
    ..writeln('//')
    ..writeln('// Replaces the emoji_picker_flutter bundled set, which stopped')
    ..writeln('// at Unicode 14.0 and therefore omits every glyph added since.')
    ..writeln('')
    ..writeln('// ignore_for_file: lines_longer_than_80_chars')
    ..writeln('')
    ..writeln("import 'package:emoji_picker_flutter/emoji_picker_flutter.dart';")
    ..writeln('')
    ..writeln('/// Every RGI emoji, grouped into the picker\'s category tabs.')
    ..writeln('///')
    ..writeln('/// Ordering is Unicode\'s own, so the grid reads the way the')
    ..writeln('/// system keyboard does.')
    ..writeln('const List<CategoryEmoji> fullEmojiSet = [');

  for (final category in _categoryOrder) {
    out.writeln('  CategoryEmoji(Category.$category, [');
    for (final entry in entries.where((e) => e.category == category)) {
      final key = _annotationKey(entry.emoji);
      final name = _titleCase(names[key] ?? entry.unicodeName);
      final searchTerms = <String>[
        name,
        ..._qualifiers(name),
        ...?keywords[key],
      ];

      final seen = <String>{};
      final deduped = <String>[];
      for (final term in searchTerms) {
        for (final variant in {term, _asciiFold(term)}) {
          final normalised = variant.toLowerCase();
          if (normalised.isEmpty || !seen.add(normalised)) continue;
          deduped.add(variant);
        }
      }

      final label = _escapeDart(deduped.join(' | '));
      final tone = entry.hasSkinTone ? ', hasSkinTone: true' : '';
      out.writeln("    Emoji('${_escapeDart(entry.emoji)}', '$label'$tone),");
    }
    out.writeln('  ]),');
  }

  out.writeln('];');
  return out.toString();
}

/// Extra keywords hiding behind a CLDR name's colon.
///
/// Search is a prefix match per keyword, so "Flag: Türkiye" as a single term is
/// only reachable by typing "flag" — all 270 flags collapse onto one useless
/// result set and no country is findable by its own name. Same shape for
/// "Family: Man, Woman, Boy", where each member is worth searching.
List<String> _qualifiers(String name) {
  final colon = name.indexOf(': ');
  if (colon < 0) return const [];
  final suffix = name.substring(colon + 2).trim();
  if (suffix.isEmpty) return const [];
  final parts = suffix.split(',').map((p) => p.trim()).where((p) => p.isNotEmpty);
  return [suffix, ...parts.where((p) => p != suffix)];
}

/// A diacritic-free twin for any keyword that has one, so "turkiye" finds
/// Türkiye and "curacao" finds Curaçao. Nobody reaches for the option key
/// mid-search.
String _asciiFold(String value) {
  const folded = {
    'à': 'a', 'á': 'a', 'â': 'a', 'ã': 'a', 'ä': 'a', 'å': 'a', 'æ': 'ae',
    'ç': 'c', 'è': 'e', 'é': 'e', 'ê': 'e', 'ë': 'e', 'ì': 'i', 'í': 'i',
    'î': 'i', 'ï': 'i', 'ñ': 'n', 'ò': 'o', 'ó': 'o', 'ô': 'o', 'õ': 'o',
    'ö': 'o', 'ø': 'o', 'ù': 'u', 'ú': 'u', 'û': 'u', 'ü': 'u', 'ý': 'y',
    'ÿ': 'y', 'ß': 'ss', 'đ': 'd', 'ł': 'l', 'š': 's', 'ž': 'z', 'č': 'c',
  };
  final out = StringBuffer();
  for (final rune in value.runes) {
    final char = String.fromCharCode(rune);
    final lower = char.toLowerCase();
    final swap = folded[lower];
    if (swap == null) {
      out.write(char);
    } else {
      out.write(char == lower ? swap : swap.toUpperCase());
    }
  }
  return out.toString();
}

String _titleCase(String value) => value
    .split(' ')
    .map((word) => word.isEmpty ? word : word[0].toUpperCase() + word.substring(1))
    .join(' ');

String _escapeDart(String value) =>
    value.replaceAll(r'\', r'\\').replaceAll("'", r"\'").replaceAll(r'$', r'\$');
