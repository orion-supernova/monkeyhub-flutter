/// Guesses what language a message is in, without a model.
///
/// ── Why this exists at all, given there is an LLM right there ──────────────
///
/// This is the single largest performance lever in the whole feature, and it
/// is not close. Turning on "translate this room" in a 400-message transcript
/// where 380 messages are already in your language means 380 model runs at
/// roughly a second each, on a phone, to produce 380 copies of the text that
/// was already on screen. With this in front of the queue those 380 are
/// answered in well under a millisecond, in total, and the model is only ever
/// asked about the twenty that need it.
///
/// It is also what makes the *single-bubble* case feel instant: a message
/// already in your language resolves to "nothing to do" before the tap
/// animation has finished.
///
/// ── Its contract, which is deliberately weak ───────────────────────────────
///
/// [LanguageDetector.detect] returns a language only when it is fairly sure,
/// and null otherwise. Null means "translate it anyway" — the safe direction.
/// A false null costs one unnecessary model run; a false POSITIVE that matched
/// the target language would silently refuse to translate a message the user
/// asked about, which is a bug they cannot work around. Every threshold below
/// is set with that asymmetry in mind.
library;

/// Script blocks worth telling apart. Latin is one bucket because inside it
/// the script says nothing and the words have to.
///
/// Public because the detector is not the only thing that cares which writing
/// systems a string uses: `Sebastian` checks a finished translation for
/// scripts that appear in neither the source nor the target, which is the
/// cheapest possible test for "the model produced nonsense".
enum TextScript {
  latin,
  han,
  kana,
  hangul,
  cyrillic,
  arabic,
  hebrew,
  devanagari,
  thai,
  greek,

  /// Not a letter in any language we handle: punctuation, digits, whitespace,
  /// emoji, symbols. Never counted, never voted with.
  none,
}

abstract final class LanguageDetector {
  /// The base language tag (`tr`, `zh`, `pt`) [text] appears to be in, or null.
  ///
  /// Cheap enough to call on every message in a transcript: one pass over the
  /// runes, then — only for Latin text — one pass over the words.
  static String? detect(String text) {
    final cleaned = _strip(text);

    final counts = <TextScript, int>{};
    var letters = 0;
    // Sub-script tells that decide between languages sharing a block.
    // Collected in the same pass rather than by re-scanning.
    var hasKana = false;
    var hasUkrainian = false;
    var hasPersian = false;

    for (final r in cleaned.runes) {
      final script = _scriptOf(r);
      if (script == TextScript.none) continue;
      letters++;
      counts[script] = (counts[script] ?? 0) + 1;
      if (script == TextScript.kana) hasKana = true;
      // і ї є ґ — present in Ukrainian, absent from Russian.
      if (r == 0x0456 || r == 0x0457 || r == 0x0454 || r == 0x0491) {
        hasUkrainian = true;
      }
      // پ چ ژ گ — the four letters Persian adds to the Arabic alphabet.
      if (r == 0x067E || r == 0x0686 || r == 0x0698 || r == 0x06AF) {
        hasPersian = true;
      }
    }
    if (letters < _minLetters) return null;

    // Japanese is written in two scripts at once, so the vote has to be taken
    // over the pair or it cannot win. `今日は友達と映画を見に行きました` is
    // exactly half han and half kana: against a 60% floor, counted separately,
    // neither reaches it and a plainly Japanese sentence comes back unknown.
    //
    // Merging them costs nothing on the Chinese side, because the split below
    // is decided by [hasKana] rather than by these counts — Chinese never uses
    // kana at all.
    final kana = counts.remove(TextScript.kana);
    if (kana != null) {
      counts[TextScript.han] = (counts[TextScript.han] ?? 0) + kana;
    }

    // Which block owns the text. A message can carry a stray Latin word ("ok",
    // a brand name, a hashtag) without stopping being Japanese, so this is a
    // plurality with a floor rather than a unanimity.
    TextScript? dominant;
    var best = 0;
    counts.forEach((script, n) {
      if (n > best) {
        best = n;
        dominant = script;
      }
    });
    final winner = dominant;
    if (winner == null || best / letters < 0.6) return null;

    switch (winner) {
      // Any kana at all settles it, and it is the ONLY thing that does: the
      // counts were merged above, so this branch owns both languages.
      case TextScript.han:
        return hasKana ? 'ja' : 'zh';
      // Unreachable — kana was folded into han before the vote. Kept so the
      // switch stays exhaustive over the enum.
      case TextScript.kana:
        return 'ja';
      case TextScript.hangul:
        return 'ko';
      case TextScript.cyrillic:
        return hasUkrainian ? 'uk' : 'ru';
      case TextScript.arabic:
        return hasPersian ? 'fa' : 'ar';
      case TextScript.hebrew:
        return 'he';
      case TextScript.devanagari:
        return 'hi';
      case TextScript.thai:
        return 'th';
      case TextScript.greek:
        return 'el';
      case TextScript.latin:
        return _detectLatin(cleaned);
      case TextScript.none:
        return null;
    }
  }

  /// How many letters of each writing system [text] uses.
  ///
  /// Exposed for [Sebastian]'s sanity check on a finished translation. Counts
  /// rather than a set, because the question there is not "does this contain a
  /// Chinese character" — a name or a quotation legitimately might — but "how
  /// much of this is in a script nobody involved was writing in".
  static Map<TextScript, int> scriptCounts(String text) {
    final counts = <TextScript, int>{};
    for (final r in _strip(text).runes) {
      final script = _scriptOf(r);
      if (script == TextScript.none) continue;
      counts[script] = (counts[script] ?? 0) + 1;
    }
    return counts;
  }

  /// The writing system [languageCode] is normally written in.
  ///
  /// Latin for anything unlisted, which is the safe default: it is the script
  /// this check never objects to, so an unknown language degrades to "no
  /// opinion" rather than to a false accusation.
  static TextScript scriptFor(String languageCode) => switch (languageCode) {
        'zh' => TextScript.han,
        'ja' => TextScript.kana,
        'ko' => TextScript.hangul,
        'ru' || 'uk' => TextScript.cyrillic,
        'ar' || 'fa' => TextScript.arabic,
        'he' => TextScript.hebrew,
        'hi' => TextScript.devanagari,
        'th' => TextScript.thai,
        'el' => TextScript.greek,
        _ => TextScript.latin,
      };

  /// Whether it is worth asking anyone about [text] at all.
  ///
  /// "ok", "😂😂😂", "+1", a bare URL, a lone emoji — a transcript is full of
  /// these and none of them has a translation. Filtering them here keeps them
  /// out of the queue entirely, which matters more than it sounds: in a group
  /// room they are a large fraction of all messages, and each one that reached
  /// the model would cost a second and hand back a copy of itself.
  ///
  /// Counts LETTERS rather than characters, which is what makes the emoji and
  /// "+1" cases fall out for free instead of needing a blocklist.
  static bool isWorthTranslating(String text) {
    final cleaned = _strip(text);
    var letters = 0;
    for (final r in cleaned.runes) {
      if (_scriptOf(r) != TextScript.none) {
        letters++;
        if (letters >= _minLetters) return true;
      }
    }
    return false;
  }

  /// Below this many letters no signal is trustworthy — "no" is Spanish,
  /// Italian, English and Polish at once, and "ok" is every language there is.
  static const int _minLetters = 8;

  /// Removes the two things that are made of letters but carry no language.
  ///
  /// Only these two. Punctuation, digits, emoji and symbols need no stripping
  /// because [_scriptOf] already reports them as [TextScript.none] and nothing
  /// counts them — which is both faster than a regex and impossible to get
  /// subtly wrong for some unicode block nobody thought of.
  static String _strip(String text) =>
      text.replaceAll(_url, ' ').replaceAll(_mention, ' ');

  static final RegExp _url =
      RegExp(r'\b(?:https?://|www\.)\S+', caseSensitive: false);
  static final RegExp _mention = RegExp(r'@[\w.\-]+');

  /// Splits Latin text into words. Keeps the apostrophe so French elisions
  /// ("c'est", "j'ai") survive as the single high-signal tokens they are.
  static final RegExp _wordBreak = RegExp(r"[^\p{L}']+", unicode: true);

  static TextScript _scriptOf(int r) {
    // Ordered by how often each range is hit in this app's traffic, so the
    // common case exits in one or two comparisons.
    if ((r >= 0x41 && r <= 0x5A) || (r >= 0x61 && r <= 0x7A)) {
      return TextScript.latin;
    }
    if (r < 0xC0) return TextScript.none; // digits, ASCII punctuation, whitespace
    if (r <= 0x24F) return TextScript.latin; // Latin-1 Supplement + Extended-A/B
    if (r >= 0x1E00 && r <= 0x1EFF) return TextScript.latin; // Vietnamese
    if (r >= 0x0400 && r <= 0x04FF) return TextScript.cyrillic;
    if (r >= 0x0600 && r <= 0x06FF) return TextScript.arabic;
    if (r >= 0x0590 && r <= 0x05FF) return TextScript.hebrew;
    if (r >= 0x0900 && r <= 0x097F) return TextScript.devanagari;
    if (r >= 0x0E00 && r <= 0x0E7F) return TextScript.thai;
    if (r >= 0x0370 && r <= 0x03FF) return TextScript.greek;
    if (r >= 0x3040 && r <= 0x30FF) return TextScript.kana;
    if (r >= 0xAC00 && r <= 0xD7A3) return TextScript.hangul;
    if (r >= 0x1100 && r <= 0x11FF) return TextScript.hangul; // Jamo
    if (r >= 0x4E00 && r <= 0x9FFF) return TextScript.han;
    if (r >= 0x3400 && r <= 0x4DBF) return TextScript.han; // Extension A
    return TextScript.none;
  }

  /// Inside the Latin block the script is silent, so the words have to speak.
  ///
  /// Two signals, added rather than ranked. Function words are the strong one —
  /// they are the most frequent tokens in any language and they barely overlap
  /// between the ones that matter here. Distinctive letters are the tiebreak,
  /// and they are what rescues the short message: "Nasılsın?" is one word and
  /// no stopword, but `ı` and `ş` do not occur together in anything but
  /// Turkish.
  static String? _detectLatin(String cleaned) {
    final lower = cleaned.toLowerCase();
    final scores = <String, double>{};

    for (final word in lower.split(_wordBreak)) {
      if (word.isEmpty) continue;
      final langs = _functionWords[word];
      if (langs == null) continue;
      // Split evenly between the languages that share the word, so "que"
      // (Spanish, Portuguese, French) contributes real but weak evidence to
      // each rather than a full point to all three.
      final share = 1.0 / langs.length;
      for (final l in langs) {
        scores[l] = (scores[l] ?? 0) + share;
      }
    }

    for (final entry in _letterTells.entries) {
      final hits = _countOf(lower, entry.key);
      if (hits == 0) continue;
      // Scored by how OFTEN the letter appears, not merely whether it does.
      //
      // A single exotic letter is weak evidence — it could be a name, a
      // borrowed word, or somebody's keyboard. Two or three of the same one is
      // a language. "Nasılsın bugün?" is the case that forces this: one word,
      // no function words at all, and the entire signal is that `ı` occurs
      // twice. A presence-only score left it under the floor and returned
      // null on a sentence no human would hesitate over.
      //
      // Capped at three so a long message cannot let one letter outvote every
      // other signal in the scorer.
      scores[entry.value] =
          (scores[entry.value] ?? 0) + (hits > 3 ? 3 : hits) * 0.8;
    }

    if (scores.isEmpty) return null;

    var bestLang = '';
    var bestScore = 0.0;
    var runnerUp = 0.0;
    scores.forEach((lang, score) {
      if (score > bestScore) {
        runnerUp = bestScore;
        bestScore = score;
        bestLang = lang;
      } else if (score > runnerUp) {
        runnerUp = score;
      }
    });

    // Two gates, and the second does most of the work. The absolute floor
    // stops a single shared word deciding anything; the margin stops a
    // near-tie between two Romance languages resolving by rounding error.
    // Either failing means null, which means "translate it" — the cheap
    // mistake, per the note at the top of this file.
    if (bestScore < 1.5) return null;
    if (bestScore - runnerUp < 0.6) return null;
    return bestLang;
  }

  /// How many times [needle] occurs in [haystack]. Both are already lowercase.
  static int _countOf(String haystack, String needle) {
    var n = 0;
    var i = haystack.indexOf(needle);
    while (i != -1) {
      n++;
      i = haystack.indexOf(needle, i + needle.length);
    }
    return n;
  }

  /// Letters that essentially pin a language on sight.
  ///
  /// Each is chosen to be absent from the OTHER languages in this table, not
  /// merely present in its own — `ç` is French, Portuguese and Turkish at once,
  /// so it is not here; `ğ` is Turkish and nothing else, so it is.
  static const Map<String, String> _letterTells = {
    'ğ': 'tr',
    'ı': 'tr',
    'ş': 'tr',
    'ñ': 'es',
    '¿': 'es',
    'ã': 'pt',
    'õ': 'pt',
    'ß': 'de',
    'ł': 'pl',
    'ż': 'pl',
    'ę': 'pl',
    'ř': 'cs',
    'ů': 'cs',
    'ě': 'cs',
    'ő': 'hu',
    'ű': 'hu',
    'ș': 'ro',
    'ț': 'ro',
    'ơ': 'vi',
    'ư': 'vi',
    'ệ': 'vi',
    'ạ': 'vi',
    'ø': 'no',
    'å': 'sv',
    'æ': 'da',
  };

  /// The most frequent function words per language, inverted to word → owners.
  ///
  /// Inverted rather than stored per-language because detection is a loop over
  /// the message's words, and this shape makes that loop one map lookup per
  /// word instead of one set-membership test per word per language. Across a
  /// twenty-language table that is the difference between a detector you can
  /// afford to run on every message and one you cannot.
  ///
  /// A word appears exactly ONCE as a key, listing every language that claims
  /// it — a const map literal with a repeated key does not compile, which is
  /// a pleasant way for the table to enforce its own invariant.
  static const Map<String, List<String>> _functionWords = {
    // ── English
    'the': ['en'],
    'and': ['en'],
    'you': ['en'],
    'that': ['en'],
    'have': ['en'],
    'this': ['en'],
    'with': ['en'],
    'what': ['en'],
    'just': ['en'],
    'about': ['en'],
    'because': ['en'],
    'they': ['en'],
    // ── Romance
    'que': ['es', 'pt', 'fr'],
    'los': ['es'],
    'una': ['es', 'it'],
    'pero': ['es'],
    'porque': ['es'],
    'muy': ['es'],
    'esto': ['es'],
    'para': ['es', 'pt'],
    'con': ['es', 'it'],
    'está': ['es', 'pt'],
    'não': ['pt'],
    'você': ['pt'],
    'uma': ['pt'],
    'isso': ['pt'],
    'como': ['pt', 'es'],
    'mas': ['pt'],
    'mais': ['pt', 'fr'],
    'les': ['fr'],
    'des': ['fr'],
    'une': ['fr'],
    'est': ['fr'],
    'pas': ['fr'],
    'pour': ['fr'],
    'vous': ['fr'],
    "c'est": ['fr'],
    'avec': ['fr'],
    'je': ['fr'],
    'che': ['it'],
    'non': ['it'],
    'sono': ['it'],
    'anche': ['it'],
    'della': ['it'],
    'come': ['it'],
    'più': ['it'],
    'però': ['it'],
    'este': ['ro'],
    'care': ['ro'],
    'pentru': ['ro'],
    'sunt': ['ro'],
    // ── Germanic
    'der': ['de'],
    'die': ['de'],
    'das': ['de'],
    'und': ['de'],
    'ich': ['de'],
    'nicht': ['de'],
    'ist': ['de'],
    'auch': ['de'],
    'aber': ['de'],
    'noch': ['de'],
    'het': ['nl'],
    'een': ['nl'],
    'niet': ['nl'],
    'zijn': ['nl'],
    'maar': ['nl'],
    'ook': ['nl'],
    'voor': ['nl'],
    'dat': ['nl'],
    // ── Nordic. Heavy mutual overlap, so these lean on _letterTells (å/ø/æ)
    // for the final call and only narrow the field here.
    'och': ['sv'],
    'inte': ['sv'],
    'som': ['sv', 'da', 'no'],
    'ikke': ['da', 'no'],
    'jeg': ['da', 'no'],
    'men': ['sv', 'da', 'no'],
    'det': ['sv', 'da', 'no'],
    'til': ['da', 'no'],
    'että': ['fi'],
    'olen': ['fi'],
    'mutta': ['fi'],
    'niin': ['fi'],
    // ── Slavic
    'nie': ['pl'],
    'jest': ['pl'],
    'się': ['pl'],
    'tak': ['pl'],
    'jak': ['pl'],
    'tylko': ['pl'],
    'ale': ['pl', 'cs'],
    'jsem': ['cs'],
    'jsou': ['cs'],
    'této': ['cs'],
    // ── Turkish
    'için': ['tr'],
    'daha': ['tr'],
    'çok': ['tr'],
    'bir': ['tr'],
    'ama': ['tr'],
    'gibi': ['tr'],
    'değil': ['tr'],
    'olarak': ['tr'],
    // ── Hungarian
    'hogy': ['hu'],
    'nem': ['hu'],
    'egy': ['hu'],
    'csak': ['hu'],
    // ── Malay / Indonesian. Near-identical function words, so they share
    // every entry and are separated — when they are at all — by nothing here.
    // That is deliberate: mistaking one for the other costs a translation the
    // user would have found acceptable either way.
    'yang': ['id', 'ms'],
    'tidak': ['id', 'ms'],
    'dengan': ['id', 'ms'],
    'untuk': ['id', 'ms'],
    'saya': ['id', 'ms'],
    'ini': ['id', 'ms'],
    'adalah': ['id', 'ms'],
    'sudah': ['id', 'ms'],
    // ── Vietnamese
    'không': ['vi'],
    'được': ['vi'],
    'những': ['vi'],
    'người': ['vi'],
    'nhưng': ['vi'],
    'của': ['vi'],
  };
}
