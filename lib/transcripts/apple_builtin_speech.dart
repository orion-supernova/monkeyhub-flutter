/// [BuiltInSpeech] on Apple's SpeechAnalyzer (iOS/macOS 26+), through the
/// local `apple_speech` plugin. Measured on macOS 27 (2026-10-17): about 40x
/// real time with word timings, no permission prompt, and it holds to the
/// locale it is given, so picking that locale is this file's real job.
library;

import 'package:apple_speech/apple_speech.dart';

import 'builtin_speech.dart';
import 'transcript.dart';

class AppleBuiltInSpeech implements BuiltInSpeech {
  /// Languages sent to the downloaded model even when Apple has them.
  ///
  /// Hindi: the new engine writes it in Latin letters ("kya hum aaj shaam
  /// cafe mein") and dictation mixes scripts and drops words. Whisper writes
  /// Devanagari.
  static const _avoid = {'hi'};

  @override
  Future<List<String>> readyLocales(List<String> preferred) async {
    if (!await AppleSpeech.isAvailable()) return const [];
    final installed = {
      for (final l in await AppleSpeech.installedLocales()) _norm(l),
    };
    if (installed.isEmpty) return const [];
    final out = <String>[];
    for (final p in preferred) {
      if (_avoid.contains(_base(p))) continue;
      final locale = await AppleSpeech.bestLocale([p]);
      if (locale == null || out.contains(locale)) continue;
      if (installed.contains(_norm(locale))) out.add(locale);
    }
    return out;
  }

  @override
  Future<Transcript> transcribe(
    String audioPath,
    String locale, {
    void Function(double fraction)? onProgress,
  }) async {
    try {
      final r = await AppleSpeech.transcribe(audioPath, locale, onProgress: onProgress);
      final words = [
        for (final w in r.words)
          TranscriptWord(
            text: w.text,
            start: Duration(milliseconds: w.startMs),
            end: Duration(milliseconds: w.endMs),
          ),
      ];
      return Transcript(
        text: r.text.trim(),
        language: _base(r.locale),
        words: words,
        source: TranscriptSource.builtIn,
        confidence: r.confidence,
      );
    } on AppleSpeechException catch (e) {
      throw BuiltInSpeechException(
        switch (e.error) {
          AppleSpeechError.unavailable => BuiltInFailure.unavailable,
          AppleSpeechError.unsupportedLocale => BuiltInFailure.unsupportedLanguage,
          AppleSpeechError.decode => BuiltInFailure.audio,
          AppleSpeechError.cancelled => BuiltInFailure.cancelled,
          AppleSpeechError.assetsFailed ||
          AppleSpeechError.permissionDenied ||
          AppleSpeechError.failed =>
            BuiltInFailure.engine,
        },
        e.message,
      );
    }
  }

  static String _base(String tag) => tag.split(RegExp('[-_]')).first.toLowerCase();
  static String _norm(String tag) => tag.replaceAll('_', '-').toLowerCase();
}
