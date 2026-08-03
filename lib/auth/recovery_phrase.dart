import 'dart:math';

import '../backend/hashing.dart';
import 'recovery_wordlist.dart';

/// A 12-word account recovery phrase.
///
/// Twelve independent draws from a 2048-word list is 12 × 11 = ~132 bits of
/// entropy from `Random.secure()`. That is far beyond brute force, which
/// matters more here than it looks: the backend stores an unsalted, uniterated
/// SHA-256 of this string and compares it with `!==`, so the phrase's own
/// entropy is the *only* thing making an offline attack infeasible. A phrase a
/// human invented would not be.
///
/// This is NOT BIP39. There is no checksum, no seed derivation, and no wallet
/// interoperability — only the wordlist is borrowed. Do not let the shape of it
/// tempt anyone into treating a phrase as a key: it derives nothing, and
/// nothing in this app is encrypted with it. It authorises exactly one action,
/// `auth.resetPasswordWithRecoveryKey`.
class RecoveryPhrase {
  const RecoveryPhrase._(this.words);

  /// Exactly 12 entries, all lowercase, all members of [kRecoveryWordlist].
  final List<String> words;

  /// Mints a fresh phrase. [random] exists so tests can seed it; production
  /// callers must never pass one — `Random.secure()` is the whole point.
  factory RecoveryPhrase.generate({Random? random}) {
    final r = random ?? Random.secure();
    return RecoveryPhrase._(
      List<String>.generate(
        12,
        (_) => kRecoveryWordlist[r.nextInt(kRecoveryWordlist.length)],
        growable: false,
      ),
    );
  }

  /// Rebuilds a phrase from words that are already known-good — used by tests
  /// and by nothing else. Returns null unless [words] is exactly 12 known
  /// words, so it cannot be used to smuggle an invalid phrase in.
  static RecoveryPhrase? fromWords(List<String> words) {
    final canonical = normalizeRecoveryPhrase(words.join(' '));
    if (canonical == null) return null;
    return RecoveryPhrase._(canonical.split(' '));
  }

  /// The ONE string that is ever hashed, displayed, or copied.
  ///
  /// There is deliberately no second rendering. A "pretty" form for the screen
  /// that differed from the hashed form — capitalised, comma-joined, numbered —
  /// is precisely how a phrase silently stops working: the user copies what
  /// they see, types it back, and it hashes to something else. What is shown
  /// IS what is hashed.
  String get canonical => words.join(' ');
}

/// Wordlist membership, built once. This set is the normalizer — see below.
final Set<String> _known = kRecoveryWordlist.toSet();

/// Splits on any run of characters that cannot appear inside a wordlist entry.
///
/// Deliberately aggressive: it absorbs multiple spaces, tabs, `\n`, `\r\n`,
/// non-breaking spaces (U+00A0), commas, hyphens, a trailing period, and
/// numbered lists (`1. abandon 2. ability`). Whatever shape someone saved
/// their phrase in, we want to read it back.
///
/// Two words can never merge into one, because any separator is by definition
/// at least one non-`[a-z]` character.
final RegExp _separators = RegExp(r'[^a-z]+');

/// Folds anything a human might type or paste into [RecoveryPhrase.canonical]
/// form, or returns null if the input is not 12 known words.
///
/// Returning null is also how a LEGACY freehand phrase is detected — accounts
/// created before this scheme have a hash of whatever the user typed, which is
/// almost never 12 wordlist entries. See [recoveryResetHashes].
///
/// The rule, in order, and why each step is what it is:
///
/// 1. **No Unicode normalization.** Dart has no built-in NFKC, and adding a
///    package for it would introduce a failure mode (two distinct inputs
///    folding to one output) worse than the problem it solves. Instead,
///    membership in the ASCII-only wordlist IS the normalizer: anything
///    carrying a combining mark, a curly quote, or a non-ASCII letter fails
///    step 5 and the phrase is rejected loudly rather than hashed wrongly.
///    Loud rejection is recoverable; a wrong hash is not.
/// 2. **`toLowerCase()`** — Dart's is the locale-*independent* simple Unicode
///    mapping. Both Turkish directions were checked and both are safe:
///    `I` and `İ` (U+0130) both fold to plain `i`, which is the correct fold;
///    dotless `ı` (U+0131) folds to itself, is not in the wordlist, and is
///    therefore rejected loudly rather than mis-hashed. Loud rejection is
///    recoverable; a wrong hash is not. Locked down by
///    test/recovery_phrase_test.dart.
/// 3. **Split on [_separators]**, dropping empties.
/// 4. **Exactly 12 tokens**, else null. A phrase missing a space
///    (`abandonability`) is one token and is rejected — failing is correct,
///    guessing is not.
/// 5. **Every token in the wordlist**, else null.
/// 6. **Canonical = tokens joined by a single U+0020**, lowercase, no trailing
///    whitespace of any kind.
///
/// The canonical string is therefore pure ASCII, which is what makes the utf8
/// encoding in [sha256Hash] byte-unambiguous — no BOM, no encoding drift, ever.
/// That is why step 1 is a correctness property and not fussiness.
String? normalizeRecoveryPhrase(String input) {
  final tokens = input
      .toLowerCase()
      .split(_separators)
      .where((t) => t.isNotEmpty)
      .toList(growable: false);
  if (tokens.length != 12) return null;
  for (final t in tokens) {
    if (!_known.contains(t)) return null;
  }
  return tokens.join(' ');
}

/// Hashes an already-canonical phrase. Callers that hold a [RecoveryPhrase]
/// should pass `phrase.canonical`; callers holding raw user input must go
/// through [recoveryResetHashes] instead.
String recoveryPhraseHash(String canonical) => sha256Hash(canonical);

/// The two candidate hashes the reset call sends, so that both new and legacy
/// phrases keep working forever.
///
/// Accounts created before the 12-word scheme stored `sha256(input.trim())` of
/// a freehand string. The server cannot upgrade those itself — it never sees
/// plaintext — so it accepts either shape, and the client always offers both:
///
/// | input                                  | matches via |
/// |----------------------------------------|-------------|
/// | new phrase, odd case/spacing/newlines  | primary     |
/// | new phrase pasted exactly as displayed | either      |
/// | legacy freehand ("My dog Barney")      | legacy      |
/// | legacy that is 12 list words, recased  | legacy      |
///
/// Row two is why [legacy] is sent unconditionally and permanently rather than
/// being sunset: our display form IS the canonical form, so an exact paste
/// satisfies both slots. Even if [normalizeRecoveryPhrase] were to develop a
/// bug, an exact paste would still get the user back into their account.
({String primary, String legacy}) recoveryResetHashes(String raw) {
  final legacy = sha256Hash(raw.trim());
  final canonical = normalizeRecoveryPhrase(raw);
  return (
    primary: canonical != null ? sha256Hash(canonical) : legacy,
    legacy: legacy,
  );
}

/// How many wordlist entries [input] currently contains, for the live
/// `n/12 words` counter on the reset screen.
///
/// Counts tokens, not valid words: telling someone which word is wrong turns a
/// help affordance into an oracle, and the count alone removes almost all of
/// the "I typed it right and it says wrong" confusion on its own.
int recoveryWordCount(String input) => input
    .toLowerCase()
    .split(_separators)
    .where((t) => t.isNotEmpty)
    .length;
