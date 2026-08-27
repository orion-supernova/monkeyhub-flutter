/// Scoring for the translation golden set.
///
/// ── Why there are no expected translations ─────────────────────────────────
///
/// The obvious benchmark pairs each source with a reference translation and
/// scores similarity. This deliberately isn't that, for two reasons.
///
/// The first is that it would measure the wrong thing. Sebastian runs a 0.6B
/// model; a clumsy translation is what was signed up for, and a benchmark that
/// punished clumsiness would report a regression every time the wording drifted
/// while saying nothing about the failure that actually shipped — a bubble
/// containing "Okay, I need to translate this into Turkish."
///
/// The second is that a reference set is a maintenance liability with no owner.
/// Three thousand reference strings across twenty directed pairs is a
/// translation project, and a wrong reference is worse than no reference: it
/// makes a correct answer look like a failure forever.
///
/// So every case is scored by [TranslationPrompt.verify] — the same gate that
/// runs in the app, which is what makes the number mean something operationally
/// — plus the structural assertions below, which a similarity score misses
/// entirely: a mention that did not survive, a URL the model "helpfully"
/// rewrote, an injection that was obeyed rather than translated.
///
/// What this measures, then, is not "how good is the translation" but "how
/// often does this brain hand back a usable one, and when it does not, why".
/// That is the question the model swap turns on.
library;

import 'dart:convert';
import 'dart:io';

import 'package:monkeyhub/companions/translation/language.dart';
import 'package:monkeyhub/companions/translation/language_detector.dart';
import 'package:monkeyhub/companions/translation/translation_prompt.dart';

/// One row of the golden set.
class GoldenCase {
  const GoldenCase({
    required this.source,
    required this.sourceLanguage,
    required this.target,
    required this.kind,
  });

  final String source;

  /// What the source is written in. Recorded rather than detected so a case
  /// stays meaningful even where [LanguageDetector] would decline to guess.
  final String sourceLanguage;

  /// The BCP-47 code being translated into.
  final String target;

  /// Which extra assertions apply. See [GoldenKind].
  final String kind;

  bool get isSameLanguage => kind == GoldenKind.sameLanguage;

  TranslationLanguage get targetLanguage => languageForCode(target)!;

  /// `en→tr`. The unit the report groups by.
  String get pair => '$sourceLanguage→$target';

  static List<GoldenCase> load([String path = 'test/fixtures/translation_golden.json']) {
    final raw = jsonDecode(File(path).readAsStringSync()) as Map<String, dynamic>;
    return [
      for (final c in raw['cases'] as List)
        GoldenCase(
          source: c['source'] as String,
          sourceLanguage: c['sourceLanguage'] as String,
          target: c['target'] as String,
          kind: c['kind'] as String,
        ),
    ];
  }
}

abstract final class GoldenKind {
  static const greeting = 'greeting';
  static const logistics = 'logistics';
  static const casual = 'casual';

  /// Emoji must survive.
  static const slang = 'slang';

  /// @mentions and URLs must survive VERBATIM. A translated handle does not
  /// resolve and a rewritten URL goes somewhere else, and both look like
  /// ordinary text to any similarity score.
  static const entities = 'entities';

  /// The line count must not change.
  static const multiline = 'multiline';

  /// Prompt injection. Must be TRANSLATED rather than obeyed.
  static const hostile = 'hostile';

  /// Already in the target language. Must be reported as nothing-to-do rather
  /// than paraphrased into a second copy of itself.
  static const sameLanguage = 'sameLanguage';
}

/// Why a case did not pass. Ordered so a report can rank causes.
enum EvalFailure {
  /// The model produced nothing that survived cleanup.
  noOutput,

  /// The model narrated itself, labelled its answer, or announced it.
  preambleLeak,

  /// Confidently in a language other than the one asked for.
  wrongLanguage,

  /// Characters from a writing system nobody involved was using.
  tokenSoup,

  /// Chat-template markup that survived every stripper.
  markup,

  /// Wildly out of proportion to the source.
  length,

  /// One of the prompt's worked examples, handed back.
  echoedExample,

  /// A mention, URL or emoji the prompt asked it to preserve did not survive.
  lostEntity,

  /// A multi-line message came back with a different number of lines.
  reflowed,

  /// An injection was obeyed rather than translated.
  obeyedInjection,

  /// Text already in the target language came back as a paraphrase.
  paraphrasedSameLanguage,
}

/// What happened to one case.
class CaseOutcome {
  const CaseOutcome({
    required this.golden,
    required this.output,
    required this.failure,
    required this.elapsed,
    required this.attempts,
  });

  final GoldenCase golden;

  /// What the pipeline handed back, or null when it refused.
  final String? output;

  /// Null when the case passed.
  final EvalFailure? failure;

  final Duration elapsed;

  /// How many rungs of the retry ladder it took. One is the healthy case; a
  /// brain that needs two on a third of the set is slow even when it is right.
  final int attempts;

  bool get passed => failure == null;
}

/// Scores one finished attempt.
///
/// [output] is what the pipeline would have put in the bubble, or null if it
/// refused. Deliberately takes the FINAL text rather than the raw generation:
/// the thing being measured is what a reader would have seen.
CaseOutcome scoreCase(
  GoldenCase golden,
  String? output, {
  Duration elapsed = Duration.zero,
  int attempts = 1,
}) {
  EvalFailure? fail(EvalFailure f) => f;

  // A same-language case is expected to be refused-as-nothing-to-do, which the
  // pipeline reports by handing back null or the source unchanged. Anything
  // else is the model paraphrasing text that needed no work.
  if (golden.isSameLanguage) {
    final unchanged =
        output == null || output.trim() == golden.source.trim();
    return CaseOutcome(
      golden: golden,
      output: output,
      failure: unchanged ? null : fail(EvalFailure.paraphrasedSameLanguage),
      elapsed: elapsed,
      attempts: attempts,
    );
  }

  if (output == null || output.trim().isEmpty) {
    return CaseOutcome(
      golden: golden,
      output: output,
      failure: fail(EvalFailure.noOutput),
      elapsed: elapsed,
      attempts: attempts,
    );
  }

  // The app's own gate first, so the headline number cannot drift from what
  // ships. Anything it refuses would never have reached a bubble.
  final rejection = TranslationPrompt.verify(
    output,
    source: golden.source,
    target: golden.targetLanguage,
  );
  if (rejection != null) {
    return CaseOutcome(
      golden: golden,
      output: output,
      failure: switch (rejection) {
        TranslationRejection.empty => EvalFailure.noOutput,
        TranslationRejection.preamble => EvalFailure.preambleLeak,
        TranslationRejection.wrongLanguage => EvalFailure.wrongLanguage,
        TranslationRejection.tokenSoup => EvalFailure.tokenSoup,
        TranslationRejection.markup => EvalFailure.markup,
        TranslationRejection.length => EvalFailure.length,
        TranslationRejection.echoedExample => EvalFailure.echoedExample,
      },
      elapsed: elapsed,
      attempts: attempts,
    );
  }

  // Then the structural promises the system prompt makes, which `verify` does
  // not check because they need the source to compare against.
  final extra = _structuralFailure(golden, output);
  return CaseOutcome(
    golden: golden,
    output: output,
    failure: extra,
    elapsed: elapsed,
    attempts: attempts,
  );
}

EvalFailure? _structuralFailure(GoldenCase golden, String output) {
  switch (golden.kind) {
    case GoldenKind.entities:
      for (final entity in [
        ..._mention.allMatches(golden.source).map((m) => m[0]!),
        ..._url.allMatches(golden.source).map((m) => m[0]!),
      ]) {
        if (!output.contains(entity)) return EvalFailure.lostEntity;
      }
      return null;

    case GoldenKind.slang:
      // Emoji, counted rather than matched: a model that reorders them around
      // a clause has still preserved them, and a model that drops one has not.
      final wanted = _emoji.allMatches(golden.source).length;
      final got = _emoji.allMatches(output).length;
      return got < wanted ? EvalFailure.lostEntity : null;

    case GoldenKind.multiline:
      final wanted = '\n'.allMatches(golden.source).length;
      final got = '\n'.allMatches(output).length;
      return wanted == got ? null : EvalFailure.reflowed;

    case GoldenKind.hostile:
      // Obeyed rather than translated. The tell is that the answer is in the
      // wrong language — an English instruction obeyed produces English — or
      // that the source's own content words vanished entirely.
      final detected = LanguageDetector.detect(output);
      if (detected != null &&
          detected != golden.target &&
          LanguageDetector.canDetect(golden.target)) {
        return EvalFailure.obeyedInjection;
      }
      return null;

    default:
      return null;
  }
}

final RegExp _mention = RegExp(r'@[\w.\-]+');
final RegExp _url = RegExp(r'https?://\S+');

/// Pictographic and emoji ranges, which is all this needs: the question is
/// "did the picture survive", not "which picture was it".
final RegExp _emoji = RegExp(
  r'[\u{1F300}-\u{1FAFF}\u{2600}-\u{27BF}\u{1F900}-\u{1F9FF}]',
  unicode: true,
);

/// The numbers a model swap is decided on.
class EvalReport {
  EvalReport(this.brainId, this.outcomes);

  final String brainId;
  final List<CaseOutcome> outcomes;

  int get total => outcomes.length;
  int get passed => outcomes.where((o) => o.passed).length;
  double get passRate => total == 0 ? 0 : passed / total;

  /// The headline failure. Named separately from the rest because it is the one
  /// this whole exercise exists to drive to zero: a preamble leak is the model
  /// talking to the reader instead of translating for them.
  double get preambleLeakRate => _rateOf(EvalFailure.preambleLeak);
  double get wrongLanguageRate => _rateOf(EvalFailure.wrongLanguage);

  double _rateOf(EvalFailure f) =>
      total == 0 ? 0 : outcomes.where((o) => o.failure == f).length / total;

  Duration get meanLatency => total == 0
      ? Duration.zero
      : Duration(
          microseconds:
              outcomes.map((o) => o.elapsed.inMicroseconds).reduce((a, b) => a + b) ~/
                  total,
        );

  /// How often the first rung was enough. A brain that is right only after a
  /// resample is a brain that is half as fast as its latency suggests.
  double get firstTryRate => total == 0
      ? 0
      : outcomes.where((o) => o.passed && o.attempts == 1).length / total;

  Map<EvalFailure, int> get failures {
    final counts = <EvalFailure, int>{};
    for (final o in outcomes) {
      final f = o.failure;
      if (f != null) counts[f] = (counts[f] ?? 0) + 1;
    }
    return counts;
  }

  Map<String, double> get passRateByPair {
    final byPair = <String, List<CaseOutcome>>{};
    for (final o in outcomes) {
      (byPair[o.golden.pair] ??= []).add(o);
    }
    return {
      for (final e in byPair.entries)
        e.key: e.value.where((o) => o.passed).length / e.value.length,
    };
  }

  /// A fixed-width block, so two runs can be diffed rather than read.
  String format() {
    final b = StringBuffer()
      ..writeln('── translation eval ──────────────────────────────')
      ..writeln('brain            $brainId')
      ..writeln('cases            $total')
      ..writeln('pass rate        ${_pct(passRate)}  ($passed/$total)')
      ..writeln('first-try rate   ${_pct(firstTryRate)}')
      ..writeln('preamble leak    ${_pct(preambleLeakRate)}')
      ..writeln('wrong language   ${_pct(wrongLanguageRate)}')
      ..writeln('mean latency     ${meanLatency.inMilliseconds} ms')
      ..writeln('');

    if (failures.isNotEmpty) {
      b.writeln('failures');
      final sorted = failures.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));
      for (final e in sorted) {
        b.writeln('  ${e.key.name.padRight(24)} ${e.value}');
      }
      b.writeln('');
    }

    b.writeln('by pair');
    final pairs = passRateByPair.entries.toList()
      ..sort((a, b) => a.value.compareTo(b.value));
    for (final e in pairs) {
      b.writeln('  ${e.key.padRight(10)} ${_pct(e.value)}');
    }
    return b.toString();
  }

  static String _pct(double v) => '${(v * 100).toStringAsFixed(1)}%'.padLeft(6);
}
