import 'package:flutter/widgets.dart';

// The one place the app changes the case of a string.
//
// Many strings were authored in capitals for the old letter-spaced labels;
// the iOS design reads them in sentence case. Doing that in one place matters
// because Dart's own case mapping is not locale-aware: it turns Turkish
// "KAPALI" into "kapali" and "GİDEN" into "gi̇den" (a stray combining dot).

bool _turkic(String? languageCode) =>
    languageCode == 'tr' || languageCode == 'az';

String _lower(String x, String? languageCode) => _turkic(languageCode)
    ? x.replaceAll('I', 'ı').replaceAll('İ', 'i').toLowerCase()
    : x.replaceAll('İ', 'i').toLowerCase();

String _upper(String x, String? languageCode) => _turkic(languageCode)
    ? x.replaceAll('i', 'İ').replaceAll('ı', 'I').toUpperCase()
    : x.toUpperCase();

final _nonLetters = RegExp(r'[^\p{L}]', unicode: true);

/// A label authored in capitals, read in sentence case. Leaves anything
/// already mixed-case alone, and short all-caps words (OK, GIF, DM) as they
/// are. Lower-case labels get their first letter raised.
///
/// Under Turkish and Azerbaijani the dotted and dotless I pairs are mapped by
/// hand.
String sentenceCase(String s, {String? languageCode}) {
  if (s.isEmpty) return s;
  final first = s.characters.first;
  final rest = s.characters.skip(1).toString();
  if (s == _upper(s, languageCode)) {
    final letters = s.replaceAll(_nonLetters, '');
    if (letters.length <= 3) return s;
    return _upper(first, languageCode) + _lower(rest, languageCode);
  }
  // Mixed or lower case: raise the first letter only.
  return _upper(first, languageCode) + rest;
}

/// [sentenceCase] in the reader's language.
String sentenceCaseOf(BuildContext context, String s) => sentenceCase(
      s,
      languageCode: Localizations.maybeLocaleOf(context)?.languageCode,
    );

/// Word by word: every all-caps word is lowered and the first letter raised,
/// while a mixed-case word — a preset's own name, "iOS" — is left exactly as
/// written. For labels like "RESET TO {name}" where [sentenceCase] would
/// treat the interpolated name as part of a mixed-case string.
String sentenceCaps(String s, {String? languageCode}) {
  final words = s.split(' ').map((w) {
    final letters = w.replaceAll(_nonLetters, '');
    return letters.length > 1 && letters == _upper(letters, languageCode)
        ? _lower(w, languageCode)
        : w;
  }).join(' ');
  if (words.isEmpty) return words;
  return _upper(words.characters.first, languageCode) +
      words.characters.skip(1).toString();
}

/// [sentenceCaps] in the reader's language.
String sentenceCapsOf(BuildContext context, String s) => sentenceCaps(
      s,
      languageCode: Localizations.maybeLocaleOf(context)?.languageCode,
    );
