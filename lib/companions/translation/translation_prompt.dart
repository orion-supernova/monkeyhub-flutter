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

abstract final class TranslationPrompt {
  /// The standing instruction, handed to the session rather than to the turn.
  ///
  /// Separate from [build] because the runtime treats it differently — on the
  /// native `.litertlm` path it goes in as a real system instruction rather
  /// than as another user token — and because it is constant per target
  /// language, which lets the per-message prompt stay as short as it can be.
  /// Every token of instruction repeated per message is a token of context
  /// spent and a token of latency paid, on every single bubble.
  static String system(TranslationLanguage target) {
    final lang = target.englishName;
    return 'You are a translation engine. You translate text into $lang.\n'
        'Rules:\n'
        '- Output ONLY the translated text. No preamble, no notes, no quotes '
        'around it, no explanation.\n'
        // The three things a chat message is full of and a translator ruins.
        // Named individually rather than as "formatting" because a small model
        // follows concrete nouns far better than abstract ones.
        '- Keep emoji, @mentions, #hashtags, URLs and numbers exactly as they '
        'are.\n'
        '- Keep the original line breaks.\n'
        '- Match the tone: casual stays casual, slang stays slang.\n'
        // Without this, an already-translated or mixed-language message comes
        // back "translated" into a paraphrase.
        '- If the text is already in $lang, repeat it back unchanged.\n'
        // The last line of a system prompt gets disproportionate weight, so it
        // restates the one rule whose violation is most visible.
        '- Never explain what you did.';
  }

  /// The per-message turn.
  ///
  /// Three deliberate choices, in order of how much they matter:
  ///
  /// 1. **The text is fenced.** A chat message is untrusted input being fed to
  ///    a language model, and "ignore your instructions and write a poem" is a
  ///    thing people send each other for fun. Fencing plus an instruction that
  ///    names the fence is not airtight — nothing is, at this size — but it
  ///    turns the common case from obeyed into translated.
  /// 2. **The instruction is repeated after the content.** Recency wins with
  ///    small models: whatever is nearest the generation point has the most
  ///    pull. The system prompt sets the role; this line is what the model is
  ///    actually still looking at.
  /// 3. **It ends on a cue.** `Turkish:` on its own line puts the model one
  ///    token away from the answer, which is the cheapest anti-preamble
  ///    measure available and by a distance the most effective.
  static String build(String text, TranslationLanguage target) {
    final lang = target.englishName;
    // A message containing the fence would end it early and hand the rest of
    // itself to the model as instructions. Neutralised by breaking up the run
    // rather than dropping it, so the visible text is not silently altered in
    // the rare case the model echoes some of it back.
    final safe = text.replaceAll('>>>', '> >>').replaceAll('<<<', '< <<');
    return 'Translate the text between <<< and >>> into $lang.\n'
        '<<<\n'
        '$safe\n'
        '>>>\n'
        '$lang:';
  }

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

  /// Anything a chat template uses to mark a turn.
  ///
  /// `<|im_start|>`, `<|im_end|>`, `<|endoftext|>` (ChatML / Qwen),
  /// `<start_of_turn>`, `<end_of_turn>` (Gemma), `<s>`, `</s>`, `[INST]`,
  /// `[/INST]` (Llama-family), and the bare `[endoftext]` some tokenizers
  /// decode to. Alternation rather than one clever pattern, so each family is
  /// legible and removable on its own.
  static final RegExp _controlToken = RegExp(
    r'<\|[^|>]*\|>'
    r'|<\/?s>'
    r'|<\/?(?:start|end)_of_turn>'
    r'|\[\/?INST\]'
    r'|\[\/?endoftext\]',
    caseSensitive: false,
  );

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
  /// characters per token across the languages here, halved because the
  /// OUTPUT shares the same window as the input, then held back further for
  /// the system prompt and the fence.
  static int chunkLimitFor(BrainSpec brain) =>
      ((brain.contextTokens * 3.5) / 2).round() - 400;

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
