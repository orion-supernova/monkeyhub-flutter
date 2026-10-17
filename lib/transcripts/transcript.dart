/// What a voice note said, as the speech model heard it.
///
/// Words rather than one string, because the slab reads along with the audio:
/// every word carries the stretch of the note it was spoken in, and the bubble
/// lights them up as playback passes over them, the way the waveform's bars
/// fill. A model that returns no timings still produces a [Transcript] — one
/// with no [words] — and the slab simply shows the text without following.
library;

import 'package:flutter/foundation.dart';

@immutable
class TranscriptWord {
  const TranscriptWord({
    required this.text,
    required this.start,
    required this.end,
  });

  /// Exactly as the model wrote it, leading space included. Concatenating
  /// every word reproduces [Transcript.text] — which is what lets CJK, where
  /// there are no spaces between words, render as one unbroken line instead
  /// of a row of separated glyphs.
  final String text;
  final Duration start;
  final Duration end;

  Map<String, Object?> toJson() => {
        't': text,
        's': start.inMilliseconds,
        'e': end.inMilliseconds,
      };

  static TranscriptWord? fromJson(Object? raw) {
    if (raw is! Map) return null;
    final t = raw['t'], s = raw['s'], e = raw['e'];
    if (t is! String || s is! int || e is! int) return null;
    return TranscriptWord(
      text: t,
      start: Duration(milliseconds: s),
      end: Duration(milliseconds: e),
    );
  }
}

/// Who heard it. Shown in the slab's credit line, because the two make
/// different mistakes: the built-in recognizer is told a language and holds to
/// it, so a note in another language comes back as confident nonsense, while
/// the downloaded model picks the language itself.
enum TranscriptSource {
  /// The OS's own on-device recognizer (Apple's SpeechTranscriber). No
  /// download, but it needs to be told the language.
  builtIn,

  /// The downloaded Whisper model.
  model;

  static TranscriptSource parse(Object? s) =>
      s == 'builtIn' ? TranscriptSource.builtIn : TranscriptSource.model;
}

@immutable
class Transcript {
  const Transcript({
    required this.text,
    this.language,
    this.words = const [],
    this.source = TranscriptSource.model,
    this.confidence,
  });

  final TranscriptSource source;

  /// The built-in recognizer's own confidence, 0..1, when it gives one.
  /// Measured: 0.92 to 0.99 in the right language, 0.11 to 0.18 in the wrong
  /// one, where it writes confident-looking nonsense rather than failing.
  final double? confidence;

  /// Probably the wrong language: nothing heard, or a confidence in the range
  /// only a wrong locale produces. Null confidence is not doubt — some
  /// locales report none at all.
  bool get doubtful =>
      source == TranscriptSource.builtIn &&
      (isEmpty || (confidence != null && confidence! < 0.5));

  /// The whole note, trimmed. Empty means the model heard no speech.
  final String text;

  /// ISO 639-1 code the model detected (`tr`, `sv`), or null when it could
  /// not say.
  final String? language;

  /// In spoken order. Empty when the engine gave no timings.
  final List<TranscriptWord> words;

  bool get isEmpty => text.trim().isEmpty;

  Map<String, Object?> toJson() => {
        'text': text,
        if (language != null) 'lang': language,
        if (words.isNotEmpty) 'words': [for (final w in words) w.toJson()],
        'src': source.name,
        if (confidence != null) 'c': confidence,
      };

  static Transcript? fromJson(Object? raw) {
    if (raw is! Map) return null;
    final text = raw['text'];
    if (text is! String) return null;
    final lang = raw['lang'];
    final rawWords = raw['words'];
    final words = <TranscriptWord>[
      if (rawWords is List)
        for (final w in rawWords)
          ?TranscriptWord.fromJson(w),
    ];
    return Transcript(
      text: text,
      language: lang is String ? lang : null,
      words: words,
      source: TranscriptSource.parse(raw['src']),
      confidence: raw['c'] is num ? (raw['c'] as num).toDouble() : null,
    );
  }
}

/// Which word playback is in, or -1 before the first one starts.
///
/// The LAST word that has started, not the one whose span contains [position]:
/// whisper's spans have gaps between them (breaths, pauses), and a highlight
/// that blinks off in every gap reads as flicker. Holding the previous word
/// until the next begins is what a reader's eye does anyway.
///
/// Binary search, because this runs on every position tick of every playing
/// bubble and a two-minute note is a few hundred words.
int spokenWordIndex(List<TranscriptWord> words, Duration position) {
  var lo = 0, hi = words.length - 1, found = -1;
  while (lo <= hi) {
    final mid = (lo + hi) >> 1;
    if (words[mid].start <= position) {
      found = mid;
      lo = mid + 1;
    } else {
      hi = mid - 1;
    }
  }
  return found;
}

/// Turns the engine's raw per-word segments into [TranscriptWord]s.
///
/// Whisper in word mode emits some things that are not words: empty segments,
/// a lone space, and bracketed non-speech tags like `[MUSIC]` or `(laughs)`
/// that [suppressNonSpeechTokens] does not always catch. Dropping them here
/// keeps them out of both the text and the karaoke.
List<TranscriptWord> cleanWords(
  Iterable<({String text, Duration start, Duration end})> raw,
) {
  final out = <TranscriptWord>[];
  for (final s in raw) {
    final t = s.text;
    if (t.trim().isEmpty) continue;
    if (_nonSpeech.hasMatch(t.trim())) continue;
    // Punctuation the model split into its own segment belongs to the word
    // before it — otherwise "merhaba ," highlights the comma as a word.
    if (out.isNotEmpty && _punctOnly.hasMatch(t)) {
      final prev = out.removeLast();
      out.add(TranscriptWord(text: prev.text + t.trim(), start: prev.start, end: s.end));
      continue;
    }
    out.add(TranscriptWord(text: t, start: s.start, end: s.end));
  }
  if (out.isNotEmpty) {
    // The first word's leading space would indent the slab by one character.
    final first = out.first;
    out[0] = TranscriptWord(
      text: first.text.trimLeft(),
      start: first.start,
      end: first.end,
    );
  }
  return out;
}

final _nonSpeech = RegExp(r'^[\[\(\*♪].*[\]\)\*♪]$');
final _punctOnly = RegExp(r'^\s*[.,!?;:…。、，！？،؟]+\s*$');
