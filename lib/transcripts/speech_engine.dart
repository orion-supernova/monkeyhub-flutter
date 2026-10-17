/// The seam between voice transcripts and whatever turns audio into words.
///
/// An interface for one reason: [VoiceTranscriber]'s state machine — download,
/// queue, cache, the slab's phases — is the part with bugs in it, and it has
/// to be testable without a 190 MB model and a native library.
library;

import 'transcript.dart';

/// Why an engine could not produce a transcript.
enum SpeechFailure {
  /// The audio could not be decoded to PCM (a format the OS decoder refuses,
  /// or on Linux no decoder installed at all).
  decode,

  /// The model loaded and ran and something still went wrong.
  engine,
}

class SpeechException implements Exception {
  const SpeechException(this.failure, [this.detail]);
  final SpeechFailure failure;
  final String? detail;
  @override
  String toString() => 'SpeechException($failure${detail == null ? '' : ': $detail'})';
}

abstract class SpeechEngine {
  /// Whether this platform can run the engine at all. False on web.
  bool get supported;

  /// Transcribes the audio file at [audioPath] with the model at [modelPath],
  /// detecting the language. [onProgress] gets 0..1, coarsely.
  ///
  /// Throws [SpeechException].
  Future<Transcript> transcribe({
    required String audioPath,
    required String modelPath,
    void Function(double fraction)? onProgress,
  });

  /// Frees the model's memory. Safe to call when nothing is loaded.
  Future<void> release();

  /// One-time setup worth doing while the app is in front — on Apple, the
  /// GPU shader compile (about 10 s the first time after an install or OS
  /// update, then cached by the OS). A no-op where there is nothing to warm.
  Future<void> prewarm() async {}
}
