import 'dart:convert' show utf8;
import 'dart:ui' show Locale;

import 'package:emoji_picker_flutter/emoji_picker_flutter.dart';
import 'package:flutter/services.dart' show rootBundle;

import 'emoji_set_full.dart';

/// Languages with a keyword overlay under `assets/emoji/`.
///
/// Matched on [Locale.languageCode] alone, which is what folds `pt_BR` onto
/// `pt` — CLDR's `pt.xml` *is* Brazilian Portuguese. Kept as a set rather than
/// discovered from the asset manifest so an unsupported locale costs a lookup
/// instead of a failed bundle read (and its console noise) on every open.
/// `tool/generate_emoji_set.dart` owns the other half of this list;
/// `test/emoji_search_index_test.dart` pins the two together.
const emojiOverlayLanguages = <String>{
  'ar',
  'es',
  'fr',
  'hi',
  'ja',
  'ko',
  'pt',
  'sv',
  'tr',
  'zh',
};

/// Separates tokens inside a haystack. Never occurs in real text, so looking
/// for `\0foo` is exactly "some token starts with foo".
const String _tokenSeparator = '\u0000';

/// A locale-aware search index over [fullEmojiSet].
///
/// Exists because `EmojiPickerUtils.searchEmoji` cannot do this job:
///
///  1. It caches the flattened emoji list in a **singleton** the first time it
///     is called and never invalidates it, so whichever locale searched first
///     wins for the rest of the process — switching language would leave
///     search stuck on the old one.
///  2. It matches by `startsWith` on whole `Emoji.name` segments after a plain
///     `toLowerCase()`. That is fine for English and wrong nearly everywhere
///     else: Korean and Japanese names are multi-word single segments ("기쁨의
///     눈물을 흘리는 얼굴"), so typing 얼굴 matches nothing; Chinese and
///     Japanese have no word starts to prefix at all; and `toLowerCase()` maps
///     Turkish `I` to `i`, not `ı`, so a Turkish user typing KIRMIZI misses
///     kırmızı.
///
/// So the picker's search view calls this instead. See
/// `lib/widgets/reaction_picker_sheet.dart`.
///
/// **English always matches too.** The terms for a glyph are the localized
/// ones *plus* the English ones, deliberately and not as a fallback for gaps:
/// people reach for "fire" or "lol" regardless of what language their phone is
/// in, and every emoji name most of us know is English.
class EmojiSearchIndex {
  EmojiSearchIndex._(this._emoji, this._haystacks);

  /// One index per language, built once. Small enough (~1,900 strings) to keep
  /// for the life of the process and expensive enough not to rebuild per open.
  ///
  /// Finished indexes and in-flight builds are held apart on purpose. Caching
  /// the `Future` alone would be simpler but is not safe under `flutter_test`,
  /// which gives every `testWidgets` its own fake-async zone: a Future handed
  /// out in one test can never complete in the next. Handing out a fresh
  /// `Future.value` over a finished index has no such tie.
  static final Map<String, EmojiSearchIndex> _ready = {};
  static final Map<String, Future<EmojiSearchIndex>> _building = {};

  final List<Emoji> _emoji;

  /// Parallel to [_emoji]. Each entry is every search term for that glyph,
  /// folded, tokenised and joined as `\0token\0token\0…` — one string instead
  /// of a `Set<String>` per emoji, which turns matching into a `contains` on a
  /// contiguous buffer and keeps the whole index around half a megabyte.
  final List<String> _haystacks;

  /// The index for [locale], loading its overlay asset on first use.
  static Future<EmojiSearchIndex> forLocale(Locale locale) {
    final language = locale.languageCode.toLowerCase();
    final key = emojiOverlayLanguages.contains(language) ? language : 'en';

    final ready = _ready[key];
    if (ready != null) return Future<EmojiSearchIndex>.value(ready);

    return _building.putIfAbsent(key, () async {
      final index = await _build(key);
      _ready[key] = index;
      _building.remove(key);
      return index;
    });
  }

  /// Tokenising all 1,906 entries measures at roughly 140 ms under the JIT and
  /// well under half that AOT, once per language per launch. It runs in one
  /// turn on purpose. Two alternatives were tried and are worse:
  ///
  ///  * Slicing it across event-loop turns with `Future.delayed(Duration.zero)`
  ///    does hide the cost, but every `pumpAndSettle` in a widget test then has
  ///    to pump the picker through each turn — it took this file's tests from
  ///    5 s to 60 s. A rule of this codebase is that the suite stays fast.
  ///  * `compute()` takes it off the main isolate entirely but cannot be
  ///    awaited under `flutter_test`'s fake async, so the widget tests hang
  ///    rather than fail.
  ///
  /// `showReactionPicker` warms it as the sheet is opened, so what is left
  /// lands during the sheet's entry animation rather than under a keystroke.
  static Future<EmojiSearchIndex> _build(String language) async {
    final overlay = language == 'en'
        ? const <String, String>{}
        : await _loadOverlay(language);

    final emoji = <Emoji>[
      for (final category in fullEmojiSet) ...category.emoji,
    ];
    final haystacks = <String>[
      for (final e in emoji) _haystack(overlay[e.emoji], e.name),
    ];
    return EmojiSearchIndex._(emoji, haystacks);
  }

  /// Parses `<emoji>TAB<term|term|…>` records. See the generator for the
  /// format and why it is not JSON.
  ///
  /// `load` + `utf8.decode`, not `loadString`: above 50 KB `loadString` hands
  /// the decode to `compute()`, and every overlay here is bigger than that.
  /// Same objection as in [_build] — the isolate costs more than the decode it
  /// saves, and it cannot be awaited under `flutter_test`'s fake async, which
  /// is how this was found: the widget tests hung instead of failing.
  static Future<Map<String, String>> _loadOverlay(String language) async {
    final bytes = await rootBundle.load('assets/emoji/keywords_$language.txt');
    final raw = utf8.decode(
      bytes.buffer.asUint8List(bytes.offsetInBytes, bytes.lengthInBytes),
    );
    final out = <String, String>{};
    for (final line in raw.split('\n')) {
      final tab = line.indexOf('\t');
      if (tab <= 0) continue; // Header comments and the trailing blank line.
      out[line.substring(0, tab)] = line.substring(tab + 1);
    }
    return out;
  }

  /// Folds and tokenises one glyph's term lists into a single haystack.
  ///
  /// The delimiters (` | ` in the English set, `|` in the overlay) need no
  /// special handling: `|` is a word boundary like any other punctuation, so
  /// the whole thing tokenises in one pass.
  static String _haystack(String? localized, String english) {
    final tokens = <String>{};
    if (localized != null) tokenizeEmojiSearchText(localized, tokens.add);
    tokenizeEmojiSearchText(english, tokens.add);
    if (tokens.isEmpty) return '';
    return '$_tokenSeparator${tokens.join(_tokenSeparator)}$_tokenSeparator';
  }

  /// Every emoji matching [query], in the grid's own (Unicode) order.
  ///
  /// A query is split into words; every word has to match, so "pink heart"
  /// narrows rather than widens. A word matches when some token starts with
  /// it, or — for CJK, where there are no word starts to aim at — when it
  /// appears anywhere in a token.
  List<Emoji> search(String query) {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return const [];

    // Built once per query, not once per emoji: this loop runs ~1,900 times
    // per keystroke and string interpolation inside it was most of its cost.
    final prefixNeedles = <String>[];
    final looseNeedles = <String?>[];
    tokenizeEmojiSearchText(trimmed, (word) {
      prefixNeedles.add('$_tokenSeparator$word');
      looseNeedles.add(_isSpaceless(word) ? word : null);
    });

    final out = <Emoji>[];
    for (var i = 0; i < _emoji.length; i++) {
      final emoji = _emoji[i];
      // Pasting a glyph in should find that glyph, even one whose name is in a
      // language we have no overlay for.
      if (emoji.emoji == trimmed) {
        out.add(emoji);
        continue;
      }
      if (prefixNeedles.isEmpty) continue;

      final haystack = _haystacks[i];
      var matched = true;
      for (var w = 0; w < prefixNeedles.length; w++) {
        if (haystack.contains(prefixNeedles[w])) continue;
        final loose = looseNeedles[w];
        if (loose != null && haystack.contains(loose)) continue;
        matched = false;
        break;
      }
      if (matched) out.add(emoji);
    }
    return out;
  }
}

/// Splits [text] into folded search tokens, calling [emit] for each.
///
/// Folding and splitting are one pass because they look at the same
/// characters, and this runs over every keyword of every emoji when an index
/// is built — a `RegExp` split with `\p{L}` cost about five times as much.
///
/// Word boundaries are "anything that is not an ASCII alphanumeric, a Latin
/// letter, or a letter in a script with no case", which is one rule for every
/// language instead of a per-locale punctuation table: it splits the space and
/// hyphen in "grinning face", the colon in "Bayrak: Türkiye", and the ideographic
/// comma in a Japanese annotation alike.
void tokenizeEmojiSearchText(String text, void Function(String token) emit) {
  final lower = text.toLowerCase();
  final token = <int>[];
  for (var i = 0; i < lower.length; i++) {
    final unit = lower.codeUnitAt(i);
    if (_isBoundary(unit)) {
      if (token.isNotEmpty) {
        emit(String.fromCharCodes(token));
        token.clear();
      }
      continue;
    }
    _foldUnit(unit, token);
  }
  if (token.isNotEmpty) emit(String.fromCharCodes(token));
}

/// [tokenizeEmojiSearchText]'s folding, without the splitting. Exposed so a
/// test can pin the equivalences the matcher depends on.
String foldEmojiSearchText(String text) {
  final lower = text.toLowerCase();
  final out = <int>[];
  for (var i = 0; i < lower.length; i++) {
    _foldUnit(lower.codeUnitAt(i), out);
  }
  return String.fromCharCodes(out);
}

/// Case- and diacritic-insensitive normalisation of one UTF-16 code unit,
/// applied to both sides of every comparison so the two can never disagree.
///
/// Beyond the lowercasing the caller already did, it handles one thing per
/// script family that would otherwise silently fail to match:
///
///  * **Latin** — strips diacritics, so "turkiye" finds Türkiye and "cafe"
///    finds café. Includes the Turkish pairs `ı/i` and `İ/i`: Dart lowercases
///    `I` to `i` and `İ` to `i` + U+0307 regardless of locale, so without this
///    a Turkish user's KIRMIZI and the keyword kırmızı never meet.
///  * **Arabic** — drops the harakat and tatweel that are optional in typed
///    input, and normalises the alef/ya/teh-marbuta variants writers disagree
///    about.
///  * **Japanese** — maps katakana onto hiragana, so a query typed before IME
///    conversion still reaches a katakana keyword.
///  * **Full-width Latin** — CJK IMEs emit U+FF21-style letters; nobody means
///    a different word by them.
///
/// Devanagari and Hangul need none of this (no case, and CLDR's keywords carry
/// the marks their speakers type), so they fall through untouched — as does
/// every unlisted script, which is also what keeps this cheap: a Chinese or
/// Korean keyword never reaches a lookup table at all.
void _foldUnit(int unit, List<int> out) {
  // Everything below U+00C0 that survived the boundary check is a bare ASCII
  // letter or digit. Checked first because it is the overwhelming majority of
  // characters in the index.
  if (unit < 0x00C0) {
    out.add(unit);
    return;
  }
  if (unit < 0x0250) {
    final multi = _multiFolds[unit];
    if (multi != null) {
      out.addAll(multi);
      return;
    }
    out.add(_singleFolds[unit] ?? unit);
    return;
  }
  if (unit >= 0x0300 && unit <= 0x036F) return; // Latin combining diacritics.
  if (unit >= 0x0600 && unit <= 0x06FF) {
    if (_isArabicDroppedMark(unit)) return;
    out.add(_singleFolds[unit] ?? unit);
    return;
  }
  if (unit >= 0x30A1 && unit <= 0x30F6) {
    out.add(unit - 0x60); // Katakana -> hiragana.
    return;
  }
  if (unit >= 0xFF01 && unit <= 0xFF5E) {
    out.add(unit - 0xFEE0); // Full-width -> ASCII.
    return;
  }
  out.add(unit);
}

/// True for code units that separate words in any script we ship.
///
/// A ladder over the ASCII table — where all but a handful of real boundaries
/// are — before the non-ASCII punctuation blocks, because this is called once
/// per character of the whole index and the first four comparisons answer it
/// for nearly all of them.
///
/// Runs *before* [_foldUnit], so full-width punctuation has to be resolved
/// here rather than left to the fold: `！` is a boundary for the same reason
/// `!` is.
bool _isBoundary(int unit) {
  if (unit < 0x30) return true; // Controls, space, !"#$%&'()*+,-./
  if (unit <= 0x39) return false; // 0-9
  if (unit < 0x41) return true; // :;<=>?@
  if (unit <= 0x5A) return false; // A-Z
  if (unit < 0x61) return true; // [\]^_`
  if (unit <= 0x7A) return false; // a-z
  if (unit < 0xC0) return true; // {|}~, DEL, Latin-1 punctuation and symbols
  if (unit == 0x00D7 || unit == 0x00F7) return true; // × ÷
  if (unit >= 0x0964 && unit <= 0x0965) return true; // Devanagari danda
  if (unit == 0x200D || unit == 0xFE0F) return true; // ZWJ, variation selector
  if (unit >= 0x2000 && unit <= 0x206F) return true; // General punctuation
  if (unit >= 0x3000 && unit <= 0x303F) return true; // CJK punctuation, 、。「」
  if (unit >= 0xFE30 && unit <= 0xFE4F) return true; // CJK compatibility forms
  if (unit >= 0xFF01 && unit <= 0xFF5E) return _isBoundary(unit - 0xFEE0);
  if (unit >= 0xFF61 && unit <= 0xFF65) return true; // Half-width 。「」、・
  return false;
}

/// Arabic marks that carry no distinction worth searching on: the harakat,
/// which typists omit, and the tatweel, which is pure justification.
bool _isArabicDroppedMark(int unit) =>
    (unit >= 0x0610 && unit <= 0x061A) ||
    (unit >= 0x064B && unit <= 0x065F) ||
    unit == 0x0640 ||
    unit == 0x0670 ||
    (unit >= 0x06D6 && unit <= 0x06ED);

/// True when [token] is written in a script that does not separate words with
/// spaces, so a fragment of a word is a normal thing to type.
bool _isSpaceless(String token) {
  for (var i = 0; i < token.length; i++) {
    final unit = token.codeUnitAt(i);
    if (unit >= 0x3040 && unit <= 0x30FF) return true; // Hiragana + katakana
    if (unit >= 0x3400 && unit <= 0x4DBF) return true; // CJK Ext A
    if (unit >= 0x4E00 && unit <= 0x9FFF) return true; // CJK Unified
    if (unit >= 0xF900 && unit <= 0xFAFF) return true; // CJK Compatibility
    if (unit >= 0xD840 && unit <= 0xD87F) return true; // CJK Ext B-F lead unit
  }
  return false;
}

/// One-to-one folds: lowercase Latin letters with diacritics onto their bare
/// forms, and the Arabic letters whose written form varies without changing
/// the word. Only lowercase Latin keys — the callers lowercase first.
const Map<int, int> _singleFolds = <int, int>{
  0x00E0: 0x61, 0x00E1: 0x61, 0x00E2: 0x61, 0x00E3: 0x61, // à á â ã
  0x00E4: 0x61, 0x00E5: 0x61, 0x0101: 0x61, 0x0103: 0x61, // ä å ā ă
  0x0105: 0x61, // ą
  0x00E7: 0x63, 0x0107: 0x63, 0x0109: 0x63, 0x010D: 0x63, // ç ć ĉ č
  0x00F0: 0x64, 0x010F: 0x64, 0x0111: 0x64, // ð ď đ
  0x00E8: 0x65, 0x00E9: 0x65, 0x00EA: 0x65, 0x00EB: 0x65, // è é ê ë
  0x0113: 0x65, 0x0115: 0x65, 0x0117: 0x65, 0x0119: 0x65, // ē ĕ ė ę
  0x011B: 0x65, // ě
  0x011F: 0x67, 0x0121: 0x67, 0x0123: 0x67, // ğ ġ ģ
  0x0125: 0x68, // ĥ
  0x00EC: 0x69, 0x00ED: 0x69, 0x00EE: 0x69, 0x00EF: 0x69, // ì í î ï
  0x012B: 0x69, 0x012F: 0x69, 0x0131: 0x69, // ī į ı
  0x0135: 0x6A, // ĵ
  0x0142: 0x6C, // ł
  0x00F1: 0x6E, 0x0144: 0x6E, 0x0148: 0x6E, // ñ ń ň
  0x00F2: 0x6F, 0x00F3: 0x6F, 0x00F4: 0x6F, 0x00F5: 0x6F, // ò ó ô õ
  0x00F6: 0x6F, 0x00F8: 0x6F, 0x014D: 0x6F, 0x0151: 0x6F, // ö ø ō ő
  0x0159: 0x72, // ř
  0x015B: 0x73, 0x015D: 0x73, 0x015F: 0x73, 0x0161: 0x73, // ś ŝ ş š
  0x0163: 0x74, 0x0165: 0x74, // ţ ť
  0x00F9: 0x75, 0x00FA: 0x75, 0x00FB: 0x75, 0x00FC: 0x75, // ù ú û ü
  0x016B: 0x75, 0x016D: 0x75, 0x016F: 0x75, 0x0171: 0x75, // ū ŭ ů ű
  0x00FD: 0x79, 0x00FF: 0x79, 0x0177: 0x79, // ý ÿ ŷ
  0x017A: 0x7A, 0x017C: 0x7A, 0x017E: 0x7A, // ź ż ž
  0x0622: 0x0627, // آ -> ا
  0x0623: 0x0627, // أ -> ا
  0x0625: 0x0627, // إ -> ا
  0x0671: 0x0627, // ٱ -> ا
  0x0624: 0x0648, // ؤ -> و
  0x0626: 0x064A, // ئ -> ي
  0x0649: 0x064A, // ى -> ي
  0x0629: 0x0647, // ة -> ه
};

/// The few letters that fold to more than one character.
const Map<int, List<int>> _multiFolds = <int, List<int>>{
  0x00E6: [0x61, 0x65], // æ -> ae
  0x0153: [0x6F, 0x65], // œ -> oe
  0x00DF: [0x73, 0x73], // ß -> ss
};
