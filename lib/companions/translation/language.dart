/// The languages Sebastian will translate into, and what to call them.
///
/// ── Why every name here is an autonym ──────────────────────────────────────
///
/// The obvious thing is to localise the language list: "Turkish" in an English
/// UI, "Türkisch" in a German one. This deliberately doesn't. Two reasons, the
/// second of which is the real one:
///
///  * Cost. Localised names would be 30 languages × 12 locales = 360 new ARB
///    entries, all of them restating what Unicode already knows.
///  * Correctness. The person scanning this list is looking for the language
///    THEY read, and the string most likely to catch their eye is that
///    language written in itself. Somebody hunting for Turkish finds "Türkçe"
///    faster than they find its name in a language they were not looking for.
///    This is why every OS language picker does the same thing.
///
/// So: autonyms, and the list stays a constant.
library;

/// One target language.
///
/// [code] is BCP-47 and is what gets persisted, matched against the app locale,
/// and — importantly — written into the prompt. [englishName] is not for
/// display: it is the string the model is actually told to translate into,
/// because "translate to Türkçe" is a worse instruction to a small model than
/// "translate to Turkish", and the model's training data overwhelmingly names
/// languages in English.
class TranslationLanguage {
  const TranslationLanguage(
    this.code,
    this.autonym,
    this.englishName,
    this.flag,
  );

  /// Persisted, and compared against `SettingsStore.localeCode` / the device
  /// locale. Bare language subtag — no region. A translator that distinguished
  /// pt-BR from pt-PT would be promising a nuance a 0.6B model cannot deliver.
  final String code;

  /// What the list shows. See the library note.
  final String autonym;

  /// What the PROMPT says. Never rendered.
  final String englishName;

  /// A flag, for scanning the list by eye.
  ///
  /// ── The honest caveat ─────────────────────────────────────────────────
  ///
  /// Flags are countries and these are languages, and the two do not line up.
  /// Spanish is not Spain to the nine in ten Spanish speakers who live
  /// somewhere else; Arabic is not Saudi Arabia; Portuguese is more Brazilian
  /// than Portuguese by a factor of twenty. Every choice below is a convention
  /// rather than a fact, and each one is arguably wrong to somebody.
  ///
  /// They are here anyway, for the reason every OS language picker has them:
  /// thirty rows of text are scanned letter by letter, and thirty rows with a
  /// glyph are scanned at a glance. The AUTONYM stays the label and does the
  /// actual identifying — the flag is a landmark beside it, never the only
  /// thing naming a language.
  ///
  /// One consequence worth knowing on iOS: flag emoji are regional-indicator
  /// PAIRS, which is the first thing to break when a simulator runtime has a
  /// font problem. A row of ?-boxes on a simulator is very unlikely to be this
  /// list being wrong.
  final String flag;
}

/// Sebastian's range.
///
/// Ordered by rough global reach rather than alphabetically, because the list
/// is scanned rather than looked up and the first screenful should be the
/// answer for most people. The app's own twelve UI locales are all present.
///
/// Bounded at thirty on purpose. Qwen3 has usable coverage of far more, but
/// "usable" degrades sharply outside its strongest languages at 0.6B, and a
/// picker that offers a language Sebastian will mangle is worse than one that
/// doesn't offer it. Every entry here is a language the family is genuinely
/// trained on.
const List<TranslationLanguage> kTranslationLanguages = [
  TranslationLanguage('en', 'English', 'English', '🇬🇧'),
  TranslationLanguage('zh', '中文', 'Chinese', '🇨🇳'),
  TranslationLanguage('hi', 'हिन्दी', 'Hindi', '🇮🇳'),
  TranslationLanguage('es', 'Español', 'Spanish', '🇪🇸'),
  TranslationLanguage('ar', 'العربية', 'Arabic', '🇸🇦'),
  TranslationLanguage('fr', 'Français', 'French', '🇫🇷'),
  TranslationLanguage('pt', 'Português', 'Portuguese', '🇵🇹'),
  TranslationLanguage('ru', 'Русский', 'Russian', '🇷🇺'),
  TranslationLanguage('de', 'Deutsch', 'German', '🇩🇪'),
  TranslationLanguage('ja', '日本語', 'Japanese', '🇯🇵'),
  TranslationLanguage('tr', 'Türkçe', 'Turkish', '🇹🇷'),
  TranslationLanguage('ko', '한국어', 'Korean', '🇰🇷'),
  TranslationLanguage('it', 'Italiano', 'Italian', '🇮🇹'),
  TranslationLanguage('id', 'Bahasa Indonesia', 'Indonesian', '🇮🇩'),
  TranslationLanguage('vi', 'Tiếng Việt', 'Vietnamese', '🇻🇳'),
  TranslationLanguage('pl', 'Polski', 'Polish', '🇵🇱'),
  TranslationLanguage('nl', 'Nederlands', 'Dutch', '🇳🇱'),
  TranslationLanguage('uk', 'Українська', 'Ukrainian', '🇺🇦'),
  TranslationLanguage('fa', 'فارسی', 'Persian', '🇮🇷'),
  TranslationLanguage('th', 'ไทย', 'Thai', '🇹🇭'),
  TranslationLanguage('sv', 'Svenska', 'Swedish', '🇸🇪'),
  TranslationLanguage('el', 'Ελληνικά', 'Greek', '🇬🇷'),
  TranslationLanguage('he', 'עברית', 'Hebrew', '🇮🇱'),
  TranslationLanguage('ro', 'Română', 'Romanian', '🇷🇴'),
  TranslationLanguage('cs', 'Čeština', 'Czech', '🇨🇿'),
  TranslationLanguage('hu', 'Magyar', 'Hungarian', '🇭🇺'),
  TranslationLanguage('da', 'Dansk', 'Danish', '🇩🇰'),
  TranslationLanguage('fi', 'Suomi', 'Finnish', '🇫🇮'),
  TranslationLanguage('no', 'Norsk', 'Norwegian', '🇳🇴'),
  TranslationLanguage('ms', 'Bahasa Melayu', 'Malay', '🇲🇾'),
];

final Map<String, TranslationLanguage> _byCode = {
  for (final l in kTranslationLanguages) l.code: l,
};

/// Resolves a language tag of any shape to one of [kTranslationLanguages].
///
/// Accepts `pt_BR`, `pt-BR`, `PT` and `pt` alike and answers `pt` for all four
/// — the app persists locales with an underscore and a region (see
/// `SettingsStore.localeCode`), device locales arrive with a hyphen, and
/// neither shape is what this table is keyed by.
///
/// Returns null for a language Sebastian does not cover, which callers treat as
/// "fall back to English" rather than as an error.
TranslationLanguage? languageForCode(String? tag) {
  if (tag == null || tag.isEmpty) return null;
  final base = tag.split(RegExp('[-_]')).first.toLowerCase();
  return _byCode[base];
}

/// The autonym for [code], or [code] itself when it isn't a language we know.
///
/// The fallback matters: a message detected as a language outside the picker
/// still wants to say what it was, and printing the bare tag is more honest
/// than printing nothing.
String autonymFor(String code) => _byCode[code]?.autonym ?? code;
