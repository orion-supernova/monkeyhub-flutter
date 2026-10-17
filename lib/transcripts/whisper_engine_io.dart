/// [SpeechEngine] on whisper.cpp, through the vendored `whisper_ggml`
/// (see third_party/whisper_ggml/PATCHES.md for what was changed and why —
/// no ffmpeg, OS audio decoders, a caller-chosen model path, and the detected
/// language in the response).
library;

import 'package:flutter/widgets.dart';
import 'package:whisper_ggml/whisper_ggml.dart';

import 'speech_engine.dart';
import 'transcript.dart';

SpeechEngine? createWhisperEngine() => _WhisperEngine();

class _WhisperEngine implements SpeechEngine {
  _WhisperEngine() {
    // iOS kills an app that submits GPU work from the background. New
    // transcriptions go to the CPU the moment the app stops being in front;
    // one already on the GPU reruns on the CPU natively (see the vendored
    // PATCHES.md, patch 10). A flag store, safe on the UI isolate.
    _lifecycle = AppLifecycleListener(
      onStateChange: (s) => setWhisperGpuAllowed(s == AppLifecycleState.resumed),
    );
  }

  // Lives as long as the engine, which is the life of the app.
  // ignore: unused_field
  late final AppLifecycleListener _lifecycle;

  // The model enum is unused when a path is given; any value will do.
  static const _whisper = Whisper(model: WhisperModel.small);

  bool _warmed = false;

  @override
  Future<void> prewarm() async {
    if (_warmed) return;
    _warmed = true;
    try {
      await prewarmWhisperGpu();
    } catch (_) {}
  }

  @override
  bool get supported => true;

  @override
  Future<Transcript> transcribe({
    required String audioPath,
    required String modelPath,
    void Function(double fraction)? onProgress,
  }) async {
    try {
      final r = await _whisper.transcribe(
        modelPath: modelPath,
        onProgress: onProgress == null ? null : (p) => onProgress(p / 100),
        transcribeRequest: TranscribeRequest(
          audio: audioPath,
          language: 'auto',
          splitOnWord: true,
          // Silence and room noise are where Whisper invents text ("Thank
          // you for watching"). Suppressing non-speech tokens and giving each
          // window no earlier text to lean on are the two cheap guards.
          suppressNonSpeechTokens: true,
          maxContext: 0,
          // A conversation is usually several notes in a row; reloading
          // 181 MB of weights for each is most of the wait. The transcriber
          // releases it after a minute idle.
          keepModelLoaded: true,
        ),
      );
      debugPrint('Whisper: ${r.backend ?? 'cpu'}'
          '${r.gpuFallback ? ' (fell back from GPU)' : ''}, language ${r.language}');
      final words = cleanWords([
        for (final s in r.segments ?? const <WhisperTranscribeSegment>[])
          (text: s.text, start: s.fromTs, end: s.toTs),
      ]);
      return Transcript(
        text: words.isEmpty ? _clean(r.text) : words.map((w) => w.text).join(),
        language: r.language,
        words: words,
      );
    } on WhisperDecodeException catch (e) {
      throw SpeechException(SpeechFailure.decode, '${e.code}: ${e.message}');
    } on SpeechException {
      rethrow;
    } catch (e) {
      throw SpeechException(SpeechFailure.engine, e.toString());
    }
  }

  @override
  Future<void> release() async {
    try {
      await _whisper.releaseModel();
    } catch (_) {}
  }

  static String _clean(String text) => text.trim();
}
