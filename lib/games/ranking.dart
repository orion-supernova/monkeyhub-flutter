/// How every board in the app places people: one rule, one helper.
///
/// An exact tie SHARES the spot. Places are competition places ("1, 1, 3"),
/// medals follow the place (two golds, then a bronze), and a tie is judged on
/// what people can SEE on the row: whole seconds for a timed game (the clock
/// reads to the second, see `formatGameTime`), the guess count for the code.
/// Hidden data (milliseconds, finish time, user ids) never decides a place.
///
/// Inside a tie people are listed A to Z by display name ([compareNames]), so
/// the order holds still between refreshes without pretending one of them
/// placed higher.
library;

/// The competition place of each of [sorted] (best first), 1-based: a row
/// that [sameScore] says equals the one above it shares that row's place, and
/// the next different score skips the places the tie used ("1, 1, 3").
///
/// [sameScore] is only ever asked about neighbours, so [sorted] must already
/// hold equal scores together, which any sort by that score does.
List<int> rankedPlaces<T>(List<T> sorted, bool Function(T a, T b) sameScore) {
  final out = <int>[];
  for (var i = 0; i < sorted.length; i++) {
    out.add(i > 0 && sameScore(sorted[i - 1], sorted[i]) ? out[i - 1] : i + 1);
  }
  return out;
}

/// [sorted] with each row's place, ties listed by name.
///
/// Places come from [placeOf] when the data carries one for EVERY row (a
/// server that already ranked the board), else they are computed here with
/// [rankedPlaces] and [sameScore], so an older server still ranks correctly.
/// Then each tie is re-ordered A to Z by [nameOf]; rows that are not tied keep
/// the order they came in.
List<({T row, int place})> rankByPlace<T>(
  List<T> sorted, {
  required bool Function(T a, T b) sameScore,
  required String Function(T row) nameOf,
  int? Function(T row)? placeOf,
}) {
  final given = placeOf == null ? null : [for (final r in sorted) placeOf(r)];
  final places = given != null && given.every((p) => p != null && p > 0)
      ? given.cast<int>()
      : rankedPlaces(sorted, sameScore);
  final indexed = [
    for (var i = 0; i < sorted.length; i++)
      (i: i, row: sorted[i], place: places[i], key: foldName(nameOf(sorted[i]))),
  ];
  indexed.sort((a, b) {
    final byPlace = a.place.compareTo(b.place);
    if (byPlace != 0) return byPlace;
    final byName = a.key.compareTo(b.key);
    if (byName != 0) return byName;
    return a.i.compareTo(b.i);
  });
  return [for (final e in indexed) (row: e.row, place: e.place)];
}

/// Whether two timed results read the same on the board: both solved in the
/// same whole second, or both unsolved (each reads "gave up").
bool sameTimedScore({
  required bool aSolved,
  required int? aMs,
  required bool bSolved,
  required int? bMs,
}) {
  if (aSolved != bSolved) return false;
  if (!aSolved) return true;
  if (aMs == null || bMs == null) return aMs == bMs;
  return aMs ~/ 1000 == bMs ~/ 1000;
}

/// A to Z by display name, the way people read a name: case-insensitive,
/// accents folded ("Émile" sits with "Emile"), Turkish dotted and dotless I
/// both read as i.
int compareNames(String a, String b) => foldName(a).compareTo(foldName(b));

/// [name] reduced to what [compareNames] compares.
String foldName(String name) {
  final out = StringBuffer();
  for (final rune in name.runes) {
    // Combining marks (a decomposed accent) are dropped outright.
    if (rune >= 0x0300 && rune <= 0x036F) continue;
    final ch = String.fromCharCode(rune);
    final folded = _fold[ch];
    if (folded != null) {
      out.write(folded);
    } else {
      out.write(ch.toLowerCase());
    }
  }
  return out.toString();
}

/// Precomposed letters to their plain lowercase base. Turkish İ and ı are
/// here (not left to toLowerCase, which turns İ into "i" plus a combining
/// dot), and the usual Latin accents across the app's languages.
const Map<String, String> _fold = {
  'İ': 'i', 'ı': 'i', 'I': 'i',
  'À': 'a', 'Á': 'a', 'Â': 'a', 'Ã': 'a', 'Ä': 'a', 'Å': 'a', 'Ā': 'a',
  'Ă': 'a', 'Ą': 'a',
  'à': 'a', 'á': 'a', 'â': 'a', 'ã': 'a', 'ä': 'a', 'å': 'a', 'ā': 'a',
  'ă': 'a', 'ą': 'a',
  'Æ': 'ae', 'æ': 'ae',
  'Ç': 'c', 'Ć': 'c', 'Č': 'c', 'ç': 'c', 'ć': 'c', 'č': 'c',
  'Ď': 'd', 'Đ': 'd', 'ď': 'd', 'đ': 'd',
  'È': 'e', 'É': 'e', 'Ê': 'e', 'Ë': 'e', 'Ē': 'e', 'Ė': 'e', 'Ę': 'e',
  'Ě': 'e',
  'è': 'e', 'é': 'e', 'ê': 'e', 'ë': 'e', 'ē': 'e', 'ė': 'e', 'ę': 'e',
  'ě': 'e',
  'Ğ': 'g', 'ğ': 'g',
  'Ì': 'i', 'Í': 'i', 'Î': 'i', 'Ï': 'i', 'Ī': 'i', 'Į': 'i',
  'ì': 'i', 'í': 'i', 'î': 'i', 'ï': 'i', 'ī': 'i', 'į': 'i',
  'Ł': 'l', 'ł': 'l',
  'Ñ': 'n', 'Ń': 'n', 'Ň': 'n', 'ñ': 'n', 'ń': 'n', 'ň': 'n',
  'Ò': 'o', 'Ó': 'o', 'Ô': 'o', 'Õ': 'o', 'Ö': 'o', 'Ø': 'o', 'Ō': 'o',
  'Ő': 'o',
  'ò': 'o', 'ó': 'o', 'ô': 'o', 'õ': 'o', 'ö': 'o', 'ø': 'o', 'ō': 'o',
  'ő': 'o',
  'Œ': 'oe', 'œ': 'oe',
  'Ř': 'r', 'ř': 'r',
  'Ś': 's', 'Ş': 's', 'Š': 's', 'ś': 's', 'ş': 's', 'š': 's', 'ß': 'ss',
  'Ť': 't', 'Ţ': 't', 'ť': 't', 'ţ': 't',
  'Ù': 'u', 'Ú': 'u', 'Û': 'u', 'Ü': 'u', 'Ū': 'u', 'Ů': 'u', 'Ű': 'u',
  'ù': 'u', 'ú': 'u', 'û': 'u', 'ü': 'u', 'ū': 'u', 'ů': 'u', 'ű': 'u',
  'Ý': 'y', 'Ÿ': 'y', 'ý': 'y', 'ÿ': 'y',
  'Ź': 'z', 'Ż': 'z', 'Ž': 'z', 'ź': 'z', 'ż': 'z', 'ž': 'z',
};
