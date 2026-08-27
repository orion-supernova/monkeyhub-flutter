/// How Sebastian is asked, and how his answer is cleaned up before anyone
/// sees it.
///
/// ── Why half of this file is about cleaning up ─────────────────────────────
///
/// A 0.6B model does not reliably do only what it was told. Asked to translate
/// one line it will, some fraction of the time, also announce that it is about
/// to ("Sure! Here's the translation:"), label its work ("Turkish:"), wrap it
/// in quotes that were not in the original, offer a second attempt, or explain
/// a word choice in a parenthetical. None of that is a prompt bug that better
/// wording will fix — it is what the size buys you.
///
/// So the design is belt and braces: a prompt shaped to make the failure less
/// likely, and a sanitiser that assumes it happened anyway. The sanitiser is
/// the load-bearing half. A translated bubble reading `"Merhaba!" (This means
/// "Hello!")` is not a rough translation, it is a broken feature, and no user
/// will forgive it twice.
library;

import '../brain_spec.dart';
import 'language.dart';
import 'language_detector.dart';

/// Why a candidate translation was refused.
///
/// Named rather than boolean because the retry ladder and the eval harness both
/// read it: "the model answered in the wrong language" and "the model rambled"
/// call for different second attempts, and a benchmark that only knew a run had
/// failed could not say what got better.
enum TranslationRejection {
  /// Nothing survived cleanup.
  empty,

  /// Still carrying chat-template markup after every stripper had a turn.
  markup,

  /// An announcement, a label, or the model narrating itself.
  preamble,

  /// One of the few-shot answers handed back instead of a translation.
  echoedExample,

  /// Characters from a writing system nobody involved was writing in.
  tokenSoup,

  /// Confidently in a language that is not the one that was asked for.
  wrongLanguage,

  /// Wildly out of proportion to the source — a truncation, or an answer to
  /// the message rather than a translation of it.
  length,
}

abstract final class TranslationPrompt {
  /// The standing instruction, handed to the session rather than to the turn.
  ///
  /// Separate from [build] because the runtime treats it differently — on the
  /// native `.litertlm` path it goes in as a real system instruction rather
  /// than as another user token — and because it is constant per target
  /// language, which lets the per-message prompt stay as short as it can be.
  /// Every token of instruction repeated per message is a token of context
  /// spent and a token of latency paid, on every single bubble.
  static String system(TranslationLanguage target, {bool withExamples = true}) {
    final lang = target.englishName;
    final b = StringBuffer()
      ..writeln('You are a translation engine. You translate text into $lang.')
      ..writeln('Rules:')
      ..writeln('- Output ONLY the translated text. No preamble, no notes, no '
          'quotes around it, no explanation.')
      // The three things a chat message is full of and a translator ruins.
      // Named individually rather than as "formatting" because a small model
      // follows concrete nouns far better than abstract ones.
      ..writeln('- Keep emoji, @mentions, #hashtags, URLs and numbers exactly '
          'as they are.')
      ..writeln('- Keep the original line breaks.')
      ..writeln('- Match the tone: casual stays casual, slang stays slang.')
      // Without this, an already-translated or mixed-language message comes
      // back "translated" into a paraphrase.
      ..writeln('- If the text is already in $lang, repeat it back unchanged.')
      ..writeln('- Never explain what you did.');

    // ── Why the examples are HERE and not in the turn ───────────────────
    //
    // They were in the turn first, written as completed `<<< … >>>` blocks
    // ahead of the real one, and at 0.5B that is an invitation rather than a
    // demonstration: the turn then looks like a LIST, and a small model asked
    // to continue a list continues the list. A real device produced
    //
    //     Bonjour, comment ça va ?
    //     Hello, how are you ? sende autocorrect mi var D
    //
    // which is the first example echoed back verbatim with the untranslated
    // message glued to the end of it.
    //
    // In the system instruction they are framing rather than a pattern to
    // extend, and the turn goes back to holding exactly one fenced block — so
    // there is no list to continue and only one thing that can be answered.
    if (withExamples) {
      final examples = _examplesFor(target);
      if (examples.isNotEmpty) {
        b.writeln('Examples of the OUTPUT you produce:');
        for (final e in examples) {
          b.writeln('  input: ${e.source}');
          b.writeln('  you: ${e.target}');
        }
      }
    }
    return b.toString().trimRight();
  }

  /// The per-message turn.
  ///
  /// Three deliberate choices, in order of how much they matter:
  ///
  /// 1. **It holds exactly ONE fenced block.** The worked examples live in
  ///    [system], not here. Written into the turn as completed blocks ahead of
  ///    the real one they turned it into a list, and a 0.5B model asked to
  ///    continue a list continues the list rather than answering — see the note
  ///    in [system] for the bubble that produced.
  /// 2. **The text is fenced.** A chat message is untrusted input being fed to
  ///    a language model, and "ignore your instructions and write a poem" is a
  ///    thing people send each other for fun. Fencing plus an instruction that
  ///    names the fence is not airtight — nothing is, at this size — but it
  ///    turns the common case from obeyed into translated.
  /// 3. **It ends on a cue.** `Turkish:` on its own line puts the model one
  ///    token away from the answer, which is the cheapest anti-preamble
  ///    measure available and by a distance the most effective.
  ///
  /// [terse] drops the instruction line, leaving the fence and the cue. Used by
  /// the retry ladder's second attempt, alongside a system prompt with no
  /// examples: when the first pass produced something that failed [verify], a
  /// shorter prompt is a genuinely different one rather than the same one asked
  /// louder.
  static String build(
    String text,
    TranslationLanguage target, {
    BrainFamily family = BrainFamily.qwen3,
    bool terse = false,
  }) {
    final lang = target.englishName;
    final safe = fence(text);
    // Qwen3's documented soft switch for its reasoning mode.
    //
    // `enableThinking: false` is a RUNTIME flag, honoured by whichever engine
    // happens to be loaded — and a real run watched a build think anyway,
    // returning "Okay, let's tackle…" wrapped in turn markers instead of a
    // translation. `/no_think` is part of the turn, so it reaches the model
    // whatever the runtime did with the flag.
    //
    // Sent to Qwen3 ONLY. A model with no reasoning mode has nothing to switch
    // off, and the token is then just an odd instruction sitting in the turn
    // for a small model to wonder about. Sebastian no longer runs one — see
    // [BrainCatalog.sebastianBrain] — but Marlowe's shelf still does.
    final noThink = family == BrainFamily.qwen3 ? ' /no_think' : '';

    final head = terse
        ? ''
        : 'Translate the text between <<< and >>> into $lang.$noThink\n';
    return '$head<<<\n$safe\n>>>\n$lang:';
  }

  /// Neutralises a fence hidden in [text].
  ///
  /// Broken up rather than deleted, so the visible text is not silently altered
  /// in the rare case the model echoes some of it back. A message that closed
  /// the fence early would otherwise hand the rest of itself over as
  /// instructions.
  ///
  /// Public because the exemplars go through it too: they are constants today,
  /// but a constant that skips the escaping is a constant somebody will later
  /// edit into a hole.
  static String fence(String text) =>
      text.replaceAll('>>>', '> >>').replaceAll('<<<', '< <<');

  /// Two worked translations for [target].
  ///
  /// A table rather than a call to the model, obviously — but also a table
  /// rather than a clever scheme. Thirty languages × two lines is sixty short
  /// strings; the alternatives (translate the exemplars at runtime, or ship
  /// English-only exemplars) are respectively absurd and self-defeating, since
  /// an exemplar answering in the wrong language teaches exactly the failure it
  /// is meant to prevent.
  ///
  /// A language with no entry falls back to none at all rather than to
  /// English's: no exemplar is a weaker prompt, but a WRONG-language exemplar
  /// is an actively harmful one.
  static List<_Example> _examplesFor(TranslationLanguage target) =>
      _examples[target.code] ?? const [];

  /// The source side is fixed English, and the target side is that same pair
  /// written in each language. Kept short: every token here is spent on every
  /// message, and the point is the SHAPE of the answer, not its richness.
  static const Map<String, List<_Example>> _examples = {
    'en': [
      _Example('Bonjour, comment ça va ?', 'Hello, how are you?'),
      _Example('Je serai en retard de dix minutes.',
          "I'll be ten minutes late."),
    ],
    'tr': [
      _Example('Hello, how are you?', 'Merhaba, nasılsın?'),
      _Example("I'll be ten minutes late.", 'On dakika geç kalacağım.'),
    ],
    'es': [
      _Example('Hello, how are you?', 'Hola, ¿cómo estás?'),
      _Example("I'll be ten minutes late.", 'Llegaré diez minutos tarde.'),
    ],
    'fr': [
      _Example('Hello, how are you?', 'Bonjour, comment ça va ?'),
      _Example("I'll be ten minutes late.",
          'Je serai en retard de dix minutes.'),
    ],
    'de': [
      _Example('Hello, how are you?', 'Hallo, wie geht es dir?'),
      _Example("I'll be ten minutes late.",
          'Ich komme zehn Minuten später.'),
    ],
    'pt': [
      _Example('Hello, how are you?', 'Olá, como vai você?'),
      _Example("I'll be ten minutes late.", 'Vou chegar dez minutos atrasado.'),
    ],
    'it': [
      _Example('Hello, how are you?', 'Ciao, come stai?'),
      _Example("I'll be ten minutes late.", 'Arriverò dieci minuti in ritardo.'),
    ],
    'nl': [
      _Example('Hello, how are you?', 'Hallo, hoe gaat het?'),
      _Example("I'll be ten minutes late.", 'Ik ben tien minuten te laat.'),
    ],
    'sv': [
      _Example('Hello, how are you?', 'Hej, hur mår du?'),
      _Example("I'll be ten minutes late.", 'Jag blir tio minuter sen.'),
    ],
    'pl': [
      _Example('Hello, how are you?', 'Cześć, jak się masz?'),
      _Example("I'll be ten minutes late.", 'Spóźnię się dziesięć minut.'),
    ],
    'ru': [
      _Example('Hello, how are you?', 'Привет, как дела?'),
      _Example("I'll be ten minutes late.", 'Я опоздаю на десять минут.'),
    ],
    'uk': [
      _Example('Hello, how are you?', 'Привіт, як справи?'),
      _Example("I'll be ten minutes late.", 'Я запізнюся на десять хвилин.'),
    ],
    'ar': [
      _Example('Hello, how are you?', 'مرحبًا، كيف حالك؟'),
      _Example("I'll be ten minutes late.", 'سأتأخر عشر دقائق.'),
    ],
    'he': [
      _Example('Hello, how are you?', 'שלום, מה שלומך?'),
      _Example("I'll be ten minutes late.", 'אאחר בעשר דקות.'),
    ],
    'hi': [
      _Example('Hello, how are you?', 'नमस्ते, आप कैसे हैं?'),
      _Example("I'll be ten minutes late.", 'मुझे दस मिनट की देरी होगी।'),
    ],
    'zh': [
      _Example('Hello, how are you?', '你好，你好吗？'),
      _Example("I'll be ten minutes late.", '我会晚到十分钟。'),
    ],
    'ja': [
      _Example('Hello, how are you?', 'こんにちは、お元気ですか？'),
      _Example("I'll be ten minutes late.", '10分ほど遅れます。'),
    ],
    'ko': [
      _Example('Hello, how are you?', '안녕하세요, 잘 지내세요?'),
      _Example("I'll be ten minutes late.", '십 분 정도 늦을 것 같아요.'),
    ],
    'id': [
      _Example('Hello, how are you?', 'Halo, apa kabar?'),
      _Example("I'll be ten minutes late.", 'Saya akan terlambat sepuluh menit.'),
    ],
    'vi': [
      _Example('Hello, how are you?', 'Xin chào, bạn khỏe không?'),
      _Example("I'll be ten minutes late.", 'Tôi sẽ đến muộn mười phút.'),
    ],
    'th': [
      _Example('Hello, how are you?', 'สวัสดี สบายดีไหม'),
      _Example("I'll be ten minutes late.", 'ฉันจะไปสายสิบนาที'),
    ],
    'fa': [
      _Example('Hello, how are you?', 'سلام، حالت چطور است؟'),
      _Example("I'll be ten minutes late.", 'ده دقیقه دیر می‌رسم.'),
    ],
    'el': [
      _Example('Hello, how are you?', 'Γεια σου, τι κάνεις;'),
      _Example("I'll be ten minutes late.", 'Θα αργήσω δέκα λεπτά.'),
    ],
    'ro': [
      _Example('Hello, how are you?', 'Bună, ce mai faci?'),
      _Example("I'll be ten minutes late.", 'Voi întârzia zece minute.'),
    ],
    'cs': [
      _Example('Hello, how are you?', 'Ahoj, jak se máš?'),
      _Example("I'll be ten minutes late.", 'Přijdu o deset minut později.'),
    ],
    'hu': [
      _Example('Hello, how are you?', 'Szia, hogy vagy?'),
      _Example("I'll be ten minutes late.", 'Tíz percet fogok késni.'),
    ],
    'da': [
      _Example('Hello, how are you?', 'Hej, hvordan går det?'),
      _Example("I'll be ten minutes late.", 'Jeg kommer ti minutter for sent.'),
    ],
    'fi': [
      _Example('Hello, how are you?', 'Hei, mitä kuuluu?'),
      _Example("I'll be ten minutes late.", 'Olen kymmenen minuuttia myöhässä.'),
    ],
    'no': [
      _Example('Hello, how are you?', 'Hei, hvordan går det?'),
      _Example("I'll be ten minutes late.", 'Jeg kommer ti minutter for sent.'),
    ],
    'ms': [
      _Example('Hello, how are you?', 'Helo, apa khabar?'),
      _Example("I'll be ten minutes late.", 'Saya akan lewat sepuluh minit.'),
    ],
  };

  /// Turns raw model output into something fit to put in a bubble.
  ///
  /// [source] is the original message, used for the two decisions that cannot
  /// be made from the output alone: whether the surrounding quotes were the
  /// model's idea, and whether the model gave back the input unchanged.
  ///
  /// [target] is what the prompt asked for, and it is what makes the label
  /// stripping safe. An earlier version matched ANY short word followed by a
  /// colon, which correctly removed `Turkish:` and also silently truncated
  /// `Merhaba: nasılsın bugün?` — a real translation, eaten by its own
  /// sanitiser, with the reader given no sign that half the message was gone.
  /// Knowing the expected label turns a heuristic into a lookup. Null falls
  /// back to the generic vocabulary only, which still refuses to touch
  /// anything that is not one of a dozen known announcements.
  ///
  /// Returns null when the output cannot be salvaged — empty, or nothing but
  /// the model's own commentary. Null becomes a visible failure rather than an
  /// empty bubble, which is the honest outcome.
  static String? sanitize(
    String raw, {
    required String source,
    TranslationLanguage? target,
  }) {
    var out = raw;

    // ── 1. Reasoning traces.
    // `enableThinking: false` suppresses these, but the flag is honoured by
    // the runtime rather than by the weights, and a Qwen3 model will still
    // occasionally open a <think> block on its own. An unclosed one is the
    // nastier case — everything after it is reasoning, so the whole remainder
    // goes.
    out = out.replaceAll(_thinkBlock, '');
    final strayThink = out.indexOf('<think>');
    if (strayThink >= 0) out = out.substring(0, strayThink);
    out = out.replaceAll('</think>', '');

    // ── 1b. Chat-template control tokens.
    //
    // On iOS the `.litertlm` engine applies the chat template MANUALLY rather
    // than inside the SDK, so ChatML's markers are part of the decoded stream
    // rather than something the runtime swallowed. A device found
    // `<|endoftext|>` sitting in a translated bubble.
    //
    // Matched by SHAPE — `<|…|>` — rather than by listing the ones seen so
    // far, because the list is a property of whichever model is loaded and
    // this catches Gemma's and Llama's too. Real prose does not contain the
    // sequence, so there is nothing to protect.
    out = out.replaceAll(_controlToken, '');
    // Whatever is left of a channel marker once its brackets are gone —
    // stripped by an earlier pass, by a different mangling, or by a decoder
    // that dropped them itself.
    out = out.replaceAll(_channelAtLineStart, '');
    // The interleaved case. The GLUED occurrences are the detector — see
    // [looksLikeChannelResidue] — and once they have fired, every occurrence
    // goes, glued or not: a marker that followed a space left its name standing
    // as a free word, and in a stream this broken a bare `thought` is residue
    // too. Nothing is stripped below the threshold, because one channel name on
    // the end of a word is also how English spells `afterthought`.
    if (looksLikeChannelResidue(out)) {
      out = out.replaceAll(_channelAnywhere, '');
      // Stripping mid-word leaves doubled spaces behind.
      out = out.replaceAll(_runOfSpaces, ' ');
    }

    // ── 2. The fence, if it came back with the answer.
    out = out.replaceAll('<<<', '').replaceAll('>>>', '');

    out = out.trim();
    if (out.isEmpty) return null;

    final labels = _labelsFor(target);

    // ── 3. Preambles and labels, line by line from the top.
    // Looped because they arrive stacked: "Sure!" then "Translation:" then the
    // text. Capped so a genuinely short translated message made of short lines
    // cannot be eaten one line at a time.
    var dropped = 0;
    while (dropped < 3) {
      final lines = out.split('\n');
      if (lines.length < 2) break;
      final first = lines.first.trim();
      if (first.isEmpty) {
        out = lines.skip(1).join('\n').trim();
        continue;
      }
      if (_isLabelLine(first, labels)) {
        out = lines.skip(1).join('\n').trim();
        dropped++;
        continue;
      }
      break;
    }

    // A label can also be inline: "Translation: Merhaba". Matched against the
    // known vocabulary rather than by shape — see the note on [target].
    final stripped = _stripInlineLabel(out, labels);
    if (stripped != null) out = stripped;

    // ── 4. Quotes the model added.
    // Only when the source did not open with one — a message that really was a
    // quotation should stay one.
    if (!_startsQuoted(source)) {
      out = _unwrapQuotes(out);
    }

    // ── 5. Trailing commentary.
    // A parenthetical note or a "Note:" line after the translation. Removed
    // only when the translation can stand without it, so a message whose
    // content genuinely is a parenthetical is not emptied.
    final noteAt = out.lastIndexOf(_trailingNote);
    if (noteAt > 0 && out.substring(0, noteAt).trim().length >= 2) {
      out = out.substring(0, noteAt).trim();
    }

    out = out.trim();
    if (out.isEmpty) return null;

    // ── 6. Did it actually do anything?
    // An unchanged echo is the documented behaviour for text already in the
    // target language, and it is also what a confused model returns. Both mean
    // the same thing to the caller — there is nothing to show — so both are
    // reported the same way, by the caller comparing this against the source.
    return out;
  }

  /// Whether [candidate] is fit to put in a bubble, and if not, why.
  ///
  /// ── Why this exists on top of [sanitize] ───────────────────────────────
  ///
  /// The sanitiser removes shapes it recognises. This asks the opposite
  /// question — is what is left actually a translation? — and it is the half
  /// that was missing. Three of the checks below only exist because the
  /// pipeline shipped without them and the failures were invisible:
  ///
  ///  * [TranslationRejection.wrongLanguage]. The single largest hole. Every
  ///    other check is structural, so a paragraph of fluent ENGLISH reasoning
  ///    ("Okay, the user wants me to translate this…") passed all of them on
  ///    its way into a bubble whenever the target was Latin-script. The
  ///    detector was already in the file, run on the source and never on the
  ///    answer.
  ///  * [TranslationRejection.preamble]. [sanitize] only strips an
  ///    announcement that occupies a whole line, because stripping one that
  ///    does not risks eating the translation. That is the right call for a
  ///    REPAIR; it is the wrong call for a verdict, so what cannot safely be
  ///    removed is refused instead.
  ///  * [TranslationRejection.echoedExample]. The few-shot turn shows the model
  ///    two finished answers. A model that loses the thread sometimes hands one
  ///    of them back, and for a short message nothing else here would notice.
  ///
  /// [source] is the original message. Null [target] means the caller could not
  /// say what was asked for, which disables the language check rather than
  /// failing it — no opinion is not the same as a bad answer.
  static TranslationRejection? verify(
    String candidate, {
    required String source,
    TranslationLanguage? target,
  }) {
    final text = candidate.trim();
    if (text.isEmpty) return TranslationRejection.empty;

    // No stripper can be trusted to have seen every way a runtime can mangle a
    // control token, so the last word goes to checks that do not try.
    if (looksLikeMarkup(text)) return TranslationRejection.markup;
    if (looksLikeChannelResidue(text)) return TranslationRejection.markup;

    if (_containsPreamble(text, target)) return TranslationRejection.preamble;

    if (target != null && _isExampleAnswer(text, source, target)) {
      return TranslationRejection.echoedExample;
    }

    if (looksLikeTokenSoup(text, source: source, target: target)) {
      return TranslationRejection.tokenSoup;
    }

    if (_isWrongLanguage(text, target)) {
      return TranslationRejection.wrongLanguage;
    }

    if (_isImplausibleLength(text, source)) {
      return TranslationRejection.length;
    }

    return null;
  }

  /// An announcement anywhere in the text, not just at the head of a line.
  ///
  /// Deliberately narrower than it could be. It matches the model's own small,
  /// very predictable English vocabulary — it is an English-instructed model
  /// being asked for one thing — and it requires the phrase to be followed by a
  /// colon or to open the text, which is what keeps it from firing on a
  /// translated sentence that happens to contain the word "answer".
  static bool _containsPreamble(String text, TranslationLanguage? target) {
    final lower = text.toLowerCase();
    for (final opener in _openers) {
      if (lower.startsWith(opener)) return true;
    }
    for (final label in _labelsFor(target)) {
      // `Turkish:` / `Translation:` surviving anywhere. The sanitiser removes
      // these from the head; one in the middle means the model produced two
      // sections, which is not a translation of a one-line message.
      if (lower.contains('$label:')) return true;
    }
    // A first-person announcement, which is the shape a reasoning model
    // produces when the thinking is not wrapped in tags at all — the exact
    // string a real device put in a bubble.
    return _firstPersonAside.hasMatch(lower);
  }

  /// Conversational filler that only ever opens a response.
  static const List<String> _openers = [
    'sure',
    'of course',
    'certainly',
    'here is',
    "here's",
    'okay',
    'ok,',
    'alright',
    'let me',
    "let's",
    'i need to',
    'i will',
    "i'll translate",
    'i should',
    'the user',
    'first,',
    'to translate',
    'note:',
    'translating',
  ];

  static final RegExp _firstPersonAside = RegExp(
    r'\b(?:i (?:need|have|will|should|must|can) to translate'
    r'|the user (?:wants|is asking|said)'
    r'|this (?:means|translates) to'
    r'|in \w+ (?:this|it) (?:would be|is))\b',
  );

  /// Whether [text] is the prompt's own worked example coming back, rather than
  /// a translation of [source].
  ///
  /// CONTAINS, not equals, and that is the whole fix. The first version tested
  /// exact equality, which a real device walked straight past: asked to
  /// translate "sende autocorrect mi var D" it produced
  ///
  ///     Bonjour, comment ça va ?
  ///     Hello, how are you ? sende autocorrect mi var D
  ///
  /// — the first example echoed back in full, both halves, with the
  /// untranslated message glued on the end. Nothing there equals an exemplar,
  /// so nothing caught it, and it reached a bubble.
  ///
  /// Checks BOTH halves. The source half appearing is the louder signal: a
  /// French sentence has no business in the output of an English translation
  /// that was never asked about French.
  ///
  /// Only fires when the message is not itself that example — somebody really
  /// can send "Hello, how are you?", and the right answer to that is the
  /// example's answer.
  static bool _isExampleAnswer(
    String text,
    String source,
    TranslationLanguage target,
  ) {
    final src = source.trim().toLowerCase();
    final lower = text.toLowerCase();
    for (final example in _examplesFor(target)) {
      if (src == example.source.toLowerCase() ||
          src == example.target.toLowerCase()) {
        continue;
      }
      if (lower.contains(example.source.toLowerCase()) ||
          lower.contains(example.target.toLowerCase())) {
        return true;
      }
    }
    return false;
  }

  /// Whether the model has started a SECOND fenced block.
  ///
  /// Checked against the raw stream rather than the cleaned text, because
  /// [sanitize] strips the fence and would hide exactly the tell worth acting
  /// on: a model that writes `<<<` after it has already produced an answer is
  /// not translating any more, it is inventing another exercise. Ending the
  /// generation there saves the tokens and stops the second block being
  /// mistaken for part of the first one's answer.
  static bool opensAnotherBlock(String raw) =>
      raw.contains('<<<') || raw.contains('>>>');

  /// Whether the answer is confidently in a language that is not the one asked
  /// for.
  ///
  /// Four ways this declines to have an opinion, each protecting a real case:
  ///
  ///  * no target — the caller could not say what was asked for;
  ///  * no verdict — [LanguageDetector.detect] needs eight letters and a clear
  ///    margin before it will answer at all, and silence is not disagreement;
  ///  * a target the detector does not model, so its verdict about the answer
  ///    says nothing about whether the answer is wrong;
  ///  * a pair the detector cannot reliably separate. See [_confusable]. This
  ///    is the one that matters in practice: a correct Portuguese translation
  ///    scoring fractionally higher for Spanish must not be thrown away, and
  ///    refusing a good translation is a worse failure than passing a bad one
  ///    — the reader can see that a bad one is bad, and cannot see a good one
  ///    that was never shown.
  ///
  /// What survives all four is the failure this check was added for: an English
  /// paragraph of reasoning where a Turkish sentence was asked for.
  static bool _isWrongLanguage(String text, TranslationLanguage? target) {
    if (target == null) return false;
    final detected = LanguageDetector.detect(text);
    if (detected == null || detected == target.code) return false;
    if (!LanguageDetector.canDetect(target.code)) return false;
    for (final family in _confusable) {
      if (family.contains(detected) && family.contains(target.code)) {
        return false;
      }
    }
    return true;
  }

  /// Languages close enough that the detector's preference between them is not
  /// evidence of anything.
  ///
  /// Each group shares a script and a great deal of common vocabulary, which is
  /// exactly what [LanguageDetector._detectLatin]'s function-word scorer votes
  /// on. Grouping them is cheaper and more honest than trying to make the
  /// scorer better: telling Danish from Norwegian in one chat message is a hard
  /// problem, and this check does not need to solve it.
  static const List<Set<String>> _confusable = [
    {'es', 'pt', 'it'},
    {'da', 'no', 'sv'},
    {'id', 'ms'},
    {'ru', 'uk'},
    {'cs', 'pl'},
    {'nl', 'de'},
    {'fa', 'ar'},
    {'zh', 'ja'},
  ];

  /// A translation wildly out of proportion to its source.
  ///
  /// Catches the two silent failures a reader cannot spot: a truncation that
  /// looks like a complete short sentence, and a model that answered the
  /// message instead of translating it. The band is very wide on purpose —
  /// German compounds and Chinese both sit a long way from parity, and this is
  /// a check against nonsense, not against style.
  ///
  /// Short sources are exempt: at ten characters the ratio is noise, and
  /// [LanguageDetector.isWorthTranslating] has already filtered the shortest
  /// messages out of the queue.
  static bool _isImplausibleLength(String text, String source) {
    final src = source.trim().length;
    if (src < 24) return false;
    final ratio = text.length / src;
    return ratio < 0.25 || ratio > 4.0;
  }

  /// Whether the output uses a writing system that appears in neither the
  /// source nor the target language.
  ///
  /// ── Why a script check, of all things ─────────────────────────────────
  ///
  /// A real run on the iOS simulator returned this for one line of Turkish:
  ///
  ///     bareshWAREmentsreshanh畔 antespunkertainment cursesantes代表性curity
  ///
  /// Random tokens across four writing systems. The root cause was a GPU
  /// backend the simulator cannot service, but the shape of the failure is
  /// worth catching regardless: no sampler is guaranteed never to derail, and
  /// the cost of showing it is a user who stops trusting every translation.
  ///
  /// The test is narrow on purpose. It does NOT judge quality — a 0.6B model
  /// producing a clumsy translation is exactly what was signed up for. Latin is
  /// always allowed, because brand names, URLs and handles ride through every
  /// language. And the threshold is a small ABSOLUTE count rather than a
  /// proportion: the soup above was only about three per cent Han by character,
  /// which a percentage test would have waved through.
  ///
  /// Moved here from `Sebastian` so that every check a candidate has to pass
  /// lives in one place and the caller asks one question.
  static bool looksLikeTokenSoup(
    String output, {
    required String source,
    TranslationLanguage? target,
  }) {
    final sourceScripts = LanguageDetector.scriptCounts(source).keys.toSet();
    final targetScript =
        target == null ? null : LanguageDetector.scriptFor(target.code);

    var foreign = 0;
    LanguageDetector.scriptCounts(output).forEach((script, count) {
      if (script == TextScript.latin) return;
      if (script == targetScript) return;
      if (sourceScripts.contains(script)) return;
      // Japanese writes in two scripts at once; having asked for one, the
      // other cannot be evidence of anything going wrong.
      if (targetScript == TextScript.kana && script == TextScript.han) return;
      if (targetScript == TextScript.han && script == TextScript.kana) return;
      foreign += count;
    });
    return foreign > _maxForeignChars;
  }

  /// A couple of stray characters could be a real quotation. A handful is a
  /// model that has come off the rails.
  static const int _maxForeignChars = 2;

  /// Anything a chat template uses to mark a turn.
  ///
  /// `<|im_start|>`, `<|im_end|>`, `<|endoftext|>` (ChatML / Qwen),
  /// `<start_of_turn>`, `<end_of_turn>` (Gemma), `<s>`, `</s>`, `[INST]`,
  /// `[/INST]` (Llama-family), and the bare `[endoftext]` some tokenizers
  /// decode to. Alternation rather than one clever pattern, so each family is
  /// legible and removable on its own.
  static final RegExp _controlToken = RegExp(
    // Any angle-bracketed run containing a pipe, PLUS whatever channel name
    // trails it. Deliberately loose on the brackets, because a real run
    // produced the SAME token decoded three different broken ways:
    // `<|channel >`, `<channel|>`, `<| channel>`. A pattern that insisted on
    // the well-formed `<|…|>` caught none of them.
    //
    // The trailing `(?:thought|…)?` is the second half of that lesson, learned
    // the same way. A device produced a stream with a channel marker between
    // EVERY token:
    //
    //     Okay<|channel|>thought,<|channel|>thought let<|channel|>thought's…
    //
    // Stripping only the brackets left the channel NAME glued to the words on
    // either side, and what reached the bubble was
    // `,thought letthought's thought tacklethought this`. The name is part of
    // the marker, so it goes with the marker.
    //
    // Safe despite the looseness: ordinary text does not put a pipe between
    // angle brackets, and the channel names only disappear when they directly
    // follow one. `5 < 7 ve 9 > 3` has neither and survives.
    r'<[^<>]*\|[^<>]*>\s*(?:thought|thinking|analysis|commentary|final)?'
    r'|<\/?s>'
    r'|<\/?(?:start|end)_of_turn>'
    r'|\[\/?INST\]'
    r'|\[\/?endoftext\]',
    caseSensitive: false,
  );

  /// A channel name left standing at the head of a line after its brackets
  /// were stripped by something else. Where a well-formed marker leaves one.
  static final RegExp _channelAtLineStart = RegExp(
    r'^\s*(?:thought|thinking|analysis|commentary)\b',
    multiLine: true,
    caseSensitive: false,
  );

  /// Whether [text] carries the wreckage of a channel-marker decode.
  ///
  /// The tell is a channel name JOINED to the character before it —
  /// `letthought`, `,thought`, `'sthought`. That is not a word in any language;
  /// it is what is left when a marker between two tokens has its brackets
  /// stripped and its name does not go with them.
  ///
  /// Two of them, not one, and the threshold is load-bearing in both
  /// directions. `afterthought` and `rethought` match the pattern exactly, so a
  /// single hit has to be allowed through or a translation into English quietly
  /// loses its last word. Two in one chat message is not a vocabulary.
  ///
  /// Public because [verify] asks it too: the sanitiser repairs what it can,
  /// and anything still carrying this shape afterwards is refused rather than
  /// rendered.
  static bool looksLikeChannelResidue(String text) =>
      _channelGlued.allMatches(text).length >= 2;

  /// A channel name joined to whatever came before it.
  static final RegExp _channelGlued = RegExp(
    r'(?<=\S)(?:thought|thinking|analysis|commentary)'
    r'(?=[\s,.;:!?\u0027\u2019]|$)',
    caseSensitive: false,
  );

  /// Every occurrence, once [looksLikeChannelResidue] has confirmed the stream
  /// is wreckage rather than prose.
  static final RegExp _channelAnywhere = RegExp(
    r'(?:thought|thinking|analysis|commentary)'
    r'(?=[\s,.;:!?\u0027\u2019]|$)',
    caseSensitive: false,
  );

  static final RegExp _runOfSpaces = RegExp(r'[ \t]{2,}');

  static final RegExp _thinkBlock =
      RegExp(r'<think>[\s\S]*?</think>', caseSensitive: false);

  /// Every word this sanitiser is willing to treat as a label.
  ///
  /// A closed list, and that is the whole point. The model's announcements come
  /// from a small, very predictable vocabulary — it is an English-instructed
  /// model being asked for one thing — whereas the text it is translating comes
  /// from anybody, in any language, and may open with any word at all. Matching
  /// by SHAPE puts those two populations in the same bucket; matching by name
  /// does not.
  ///
  /// The target language's English name is included because the prompt's own
  /// closing cue is exactly `Turkish:` — echoing it back is the single most
  /// common thing to strip.
  /// Whether [text] still carries chat-template markup after cleanup.
  ///
  /// The stripper below handles every mangling seen so far; this exists
  /// because "so far" is not a guarantee. A translation that still contains
  /// `<|` or `|>` is markup, not language, and rendering it costs more trust
  /// than refusing it does.
  static bool looksLikeMarkup(String text) =>
      text.contains('<|') || text.contains('|>');

  static List<String> _labelsFor(TranslationLanguage? target) => [
        if (target != null) target.englishName.toLowerCase(),
        'translation',
        'translated',
        'translated text',
        'output',
        'result',
        'answer',
      ];

  /// A whole line that is only a label or an announcement.
  static bool _isLabelLine(String line, List<String> labels) {
    if (line.length > 48) return false;
    final lower = line.toLowerCase();
    // Conversational filler before the answer. Anchored at the start, because
    // these only ever open a response.
    for (final opener in const [
      'sure',
      'of course',
      'certainly',
      'here is',
      "here's",
      'okay',
      'ok,',
    ]) {
      if (lower.startsWith(opener)) return true;
    }
    final trimmed = lower.endsWith(':')
        ? lower.substring(0, lower.length - 1).trim()
        : lower;
    return labels.contains(trimmed) ||
        (trimmed.startsWith('in ') && labels.contains(trimmed.substring(3)));
  }

  /// `Translation: Merhaba` → `Merhaba`, but only for a known label, and only
  /// when something substantial is left behind.
  static String? _stripInlineLabel(String text, List<String> labels) {
    final colon = text.indexOf(':');
    if (colon <= 0 || colon > 40) return null;
    var head = text.substring(0, colon).toLowerCase().trim();
    if (head.startsWith('in ')) head = head.substring(3).trim();
    if (!labels.contains(head)) return null;
    final rest = text.substring(colon + 1).trim();
    return rest.length >= 2 ? rest : null;
  }

  /// Note-shaped trailing commentary. Matches the LAST occurrence so a note
  /// after a multi-line translation is found rather than one inside it.
  static final RegExp _trailingNote = RegExp(
    r'\n\s*(?:\(|\[)?(?:note|n\.b\.|literally|lit\.)\b',
    caseSensitive: false,
  );

  static bool _startsQuoted(String s) {
    final t = s.trimLeft();
    return t.startsWith('"') || t.startsWith('“') || t.startsWith('«') || t.startsWith("'");
  }

  static String _unwrapQuotes(String s) {
    const pairs = {'"': '"', '“': '”', '«': '»', "'": "'"};
    var out = s;
    // Looped: a model that adds quotes sometimes adds two sets.
    for (var i = 0; i < 2; i++) {
      if (out.length < 2) break;
      final close = pairs[out[0]];
      if (close == null || !out.endsWith(close)) break;
      final inner = out.substring(1, out.length - 1).trim();
      if (inner.isEmpty) break;
      // Only unwrap when the quote really does span the whole thing — a
      // message that opens and closes with quoted speech around other words
      // ("hi," he said, "bye") must not lose them.
      if (inner.contains(close)) break;
      out = inner;
    }
    return out;
  }

  /// How many characters to send in one go.
  ///
  /// Derived from the context window rather than guessed: roughly 3.5
  /// characters per token across the languages here, halved because the OUTPUT
  /// shares the same window as the input, then held back by however much the
  /// prompt itself costs.
  ///
  /// That last term used to be a flat 400, which was already tight against a
  /// ~420-character system instruction and stopped being true the moment the
  /// turn grew worked examples. Measuring it instead of guessing matters more
  /// than it sounds: overflowing the window does not throw, it silently drops
  /// the front of the input, and a message that comes back missing its first
  /// half looks exactly like a successful translation.
  ///
  /// [target] and [family] are optional so a caller sizing a chunk without a
  /// language in hand still gets a safe answer — the fallback is the largest
  /// overhead any language produces, so it can only ever be too cautious.
  static int chunkLimitFor(
    BrainSpec brain, [
    TranslationLanguage? target,
    BrainFamily family = BrainFamily.qwen3,
  ]) {
    final window = ((brain.contextTokens * 3.5) / 2).round();
    return window - _overheadFor(target, family);
  }

  /// Characters of prompt spent before any of the message is.
  ///
  /// Memoised on the pair it varies over. `build` with an empty body is the
  /// honest measurement — it includes the instruction line, both worked
  /// examples, all three fences and the closing cue — and doing it once per
  /// language beats doing it once per message for a code path whose whole job
  /// is to be cheap.
  static int _overheadFor(TranslationLanguage? target, BrainFamily family) {
    if (target == null) return _fallbackOverhead;
    final key = '${target.code}/${family.name}';
    return _overhead[key] ??=
        system(target).length + build('', target, family: family).length;
  }

  static final Map<String, int> _overhead = {};

  /// Comfortably past the longest real overhead, for the caller that cannot
  /// say which language it is asking about.
  static const int _fallbackOverhead = 1200;

  /// Splits [text] for a brain that cannot hold it in one turn.
  ///
  /// Almost never used — chat messages are short — but "almost never" is not
  /// never, and the failure it prevents is the worst kind: a pasted article
  /// silently coming back with its second half missing, which looks like a
  /// successful translation.
  ///
  /// Splits on blank lines first, then single lines, then sentences, and only
  /// falls back to a hard character cut if one sentence really is longer than
  /// the window. Each level preserves more meaning than the next.
  static List<String> chunk(String text, int limit) {
    if (text.length <= limit) return [text];
    final out = <String>[];
    for (final block in _split(text, limit, ['\n\n', '\n', '. '])) {
      if (block.length <= limit) {
        out.add(block);
      } else {
        for (var i = 0; i < block.length; i += limit) {
          out.add(block.substring(i, (i + limit).clamp(0, block.length)));
        }
      }
    }
    return out;
  }

  static List<String> _split(String text, int limit, List<String> seps) {
    if (text.length <= limit || seps.isEmpty) return [text];
    final parts = text.split(seps.first);
    final rest = seps.sublist(1);
    final out = <String>[];
    final buffer = StringBuffer();
    for (final part in parts) {
      final candidate =
          buffer.isEmpty ? part : '${buffer.toString()}${seps.first}$part';
      if (candidate.length <= limit) {
        buffer
          ..clear()
          ..write(candidate);
      } else {
        if (buffer.isNotEmpty) out.add(buffer.toString());
        buffer.clear();
        if (part.length <= limit) {
          buffer.write(part);
        } else {
          out.addAll(_split(part, limit, rest));
        }
      }
    }
    if (buffer.isNotEmpty) out.add(buffer.toString());
    return out;
  }
}

/// One worked translation, as it appears in the turn.
class _Example {
  const _Example(this.source, this.target);
  final String source;
  final String target;
}
