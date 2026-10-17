// ignore_for_file: invalid_annotation_target

import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:whisper_ggml/src/models/responses/whisper_transcribe_segment.dart';

part 'whisper_transcribe_response.freezed.dart';
part 'whisper_transcribe_response.g.dart';

/// Response model of whisper getVersion
@freezed
abstract class WhisperTranscribeResponse with _$WhisperTranscribeResponse {
  ///
  const factory WhisperTranscribeResponse({
    @JsonKey(name: '@type') required String type,
    required String text,
    @JsonKey(name: 'segments')
    required List<WhisperTranscribeSegment>? segments,

    /// MONKEYHUB PATCH 3: ISO 639-1 code of the language whisper decoded
    /// in. With `lang: 'auto'` this is the detected language (e.g. `tr`);
    /// otherwise it echoes the requested one. Null only if the native side
    /// could not name it.
    String? language,

    /// MONKEYHUB PATCH 10: `metal` or `cpu`, the backend that produced
    /// this result. Null only from a native library without the patch.
    String? backend,

    /// MONKEYHUB PATCH 10: the GPU run failed (typically: the app went to
    /// the background mid-transcription and iOS refused GPU work) and the
    /// result comes from the automatic CPU retry.
    @JsonKey(name: 'gpu_fallback') @Default(false) bool gpuFallback,
  }) = _WhisperTranscribeResponse;

  const WhisperTranscribeResponse._();

  /// Parse [json] to WhisperTranscribeResponse
  factory WhisperTranscribeResponse.fromJson(Map<String, dynamic> json) =>
      _$WhisperTranscribeResponseFromJson(json);
}
