/// The OS's own speech recognizer, as the transcriber sees it.
///
/// A seam rather than calls into the plugin for the same reason as
/// [SpeechEngine]: the decision of WHICH recognizer runs is the part with bugs
/// in it, and it has to be testable without iOS.
library;

import 'transcript.dart';

enum BuiltInFailure { unavailable, unsupportedLanguage, audio, engine, cancelled }

class BuiltInSpeechException implements Exception {
  const BuiltInSpeechException(this.failure, [this.detail]);
  final BuiltInFailure failure;
  final String? detail;
  @override
  String toString() => 'BuiltInSpeechException($failure${detail == null ? '' : ': $detail'})';
}

abstract class BuiltInSpeech {
  /// The recognizer's locales for [preferred] (language codes or BCP-47
  /// tags, best first) that are ALREADY on the device, deduplicated, best
  /// first. Empty when there is no recognizer or none of them is installed.
  ///
  /// Installed only, never fetched: the OS's language files are 300 MB to
  /// 1.4 GB each (Turkish dictation measured about 1 GB), against 181 MB for
  /// the downloaded model that also picks the language by itself. Built-in
  /// is the right choice exactly when it costs nothing — when the reader
  /// already uses Siri or dictation in that language.
  Future<List<String>> readyLocales(List<String> preferred);

  /// Throws [BuiltInSpeechException]. The result's [Transcript.source] is
  /// [TranscriptSource.builtIn] and its [Transcript.confidence] is the
  /// recognizer's, when it gives one.
  Future<Transcript> transcribe(
    String audioPath,
    String locale, {
    void Function(double fraction)? onProgress,
  });
}
