import 'dart:convert';
import 'dart:ffi';
import 'dart:isolate';

import 'package:ffi/ffi.dart';
import 'package:flutter/foundation.dart';
import 'package:universal_io/io.dart';
import 'package:whisper_ggml/src/models/whisper_model.dart';

import 'models/requests/release_model_request.dart';
import 'models/requests/transcribe_request.dart';
import 'models/requests/transcribe_request_dto.dart';
import 'models/requests/version_request.dart';
import 'models/responses/whisper_transcribe_response.dart';
import 'models/responses/whisper_version_response.dart';
import 'models/whisper_dto.dart';
import 'whisper_decode.dart';
import 'whisper_native.dart';

export 'models/_models.dart';
// MONKEYHUB PATCH 1: whisper_audio_convert.dart (ffmpeg_kit) is gone;
// decodeToWav16k replaces it.
export 'whisper_decode.dart' show decodeToWav16k, WhisperDecodeException;
// MONKEYHUB PATCH 10: Metal controls.
export 'whisper_gpu.dart';

/// MONKEYHUB PATCH 6: thrown by [Whisper.transcribe] when
/// [Whisper.cancelTranscription] stopped it.
class WhisperCancelledException implements Exception {
  ///
  const WhisperCancelledException();

  @override
  String toString() => 'WhisperCancelledException';
}

/// MONKEYHUB PATCH 6: request body for [Whisper.cancelTranscription].
class _CancelTranscriptionRequest implements WhisperRequestDto {
  const _CancelTranscriptionRequest();

  @override
  String get specialType => 'cancelTranscription';

  @override
  String toRequestString() => json.encode({'@type': specialType});
}

/// Native request type
typedef WReqNative = Pointer<Utf8> Function(Pointer<Utf8> body);

/// Entry point
class Whisper {
  /// [model] is required
  /// [modelDir] is path where downloaded model will be stored.
  /// Default to library directory
  const Whisper({required this.model, this.modelDir});

  /// model used for transcription
  final WhisperModel model;

  /// override of model storage path
  final String? modelDir;

  Future<Map<String, dynamic>> _request({
    required WhisperRequestDto whisperRequest,
  }) async {
    return Isolate.run(() async {
      final Pointer<Utf8> data =
          whisperRequest.toRequestString().toNativeUtf8();
      final Pointer<Utf8> res = openWhisperLibrary()
          .lookupFunction<WReqNative, WReqNative>('request')
          .call(data);

      final Map<String, dynamic> result =
          json.decode(res.toDartString()) as Map<String, dynamic>;

      malloc.free(data);
      // Native responses are malloc'd specifically so this free is valid.
      malloc.free(res);
      return result;
    });
  }

  /// Transcribe audio file to text
  ///
  /// MONKEYHUB PATCH 2: any audio the OS decodes is accepted (see
  /// [decodeToWav16k]). Unless the input already is a 16 kHz 16-bit WAV,
  /// it is decoded to a temporary `<audio>.16k.wav` next to it, which is
  /// deleted afterwards. Decode failures throw [WhisperDecodeException];
  /// a [cancelTranscription] throws [WhisperCancelledException].
  ///
  /// [onProgress] is invoked with whisper.cpp's transcription progress
  /// (0–100, coarse steps) while inference runs.
  Future<WhisperTranscribeResponse> transcribe({
    required TranscribeRequest transcribeRequest,
    required String modelPath,
    void Function(int percent)? onProgress,
  }) async {
    // A listener callable may be invoked from whisper's worker thread;
    // it delivers to this isolate. Kept open until the request finishes.
    final NativeCallable<Void Function(Int32)>? progressCallable =
        onProgress == null
            ? null
            : NativeCallable<Void Function(Int32)>.listener(onProgress);
    String? tempWav;
    try {
      final String audio = transcribeRequest.audio;
      // main.cpp reads 16 kHz 16-bit PCM WAV (mono or stereo) only.
      final WavInfo? wav = await readWavInfo(audio);
      final bool readable = wav != null &&
          wav.isPcm16 &&
          wav.sampleRate == 16000 &&
          (wav.channels == 1 || wav.channels == 2);
      if (!readable) {
        tempWav = '$audio.16k.wav';
        await decodeToWav16k(audio, tempWav);
      }

      final TranscribeRequest req = transcribeRequest.copyWith(
        audio: tempWav ?? audio,
      );

      final Map<String, dynamic> result = await _request(
        whisperRequest: TranscribeRequestDto.fromTranscribeRequest(
          req,
          modelPath,
          progressCallbackAddress: progressCallable?.nativeFunction.address,
        ),
      );

      if (result['cancelled'] == true) {
        throw const WhisperCancelledException();
      }
      if (result['text'] == null) {
        throw Exception(result['message']);
      }
      return WhisperTranscribeResponse.fromJson(result);
    } catch (e) {
      debugPrint(e.toString());
      rethrow;
    } finally {
      progressCallable?.close();
      if (tempWav != null) {
        try {
          await File(tempWav).delete();
        } on FileSystemException {
          // Decode failed before creating it.
        }
      }
    }
  }

  /// MONKEYHUB PATCH 6: stop every transcription in flight; each throws
  /// [WhisperCancelledException]. Takes effect within one ggml graph node
  /// (milliseconds). Transcriptions started after this call are not
  /// affected, and live sessions never are.
  Future<void> cancelTranscription() async {
    await _request(whisperRequest: const _CancelTranscriptionRequest());
  }

  /// Free the model parked in native memory by a transcription with
  /// `keepModelLoaded: true`. Safe to call when nothing is parked.
  ///
  /// A transcription still in flight keeps its model until it completes;
  /// one that was started with `keepModelLoaded: true` parks the model
  /// again when it finishes.
  Future<void> releaseModel() async {
    final Map<String, dynamic> result = await _request(
      whisperRequest: const ReleaseModelRequest(),
    );
    if (result['@type'] == 'error') {
      throw Exception(result['message']);
    }
  }

  /// Get whisper version
  Future<String?> getVersion() async {
    final Map<String, dynamic> result = await _request(
      whisperRequest: const VersionRequest(),
    );

    final WhisperVersionResponse response = WhisperVersionResponse.fromJson(
      result,
    );
    return response.message;
  }
}
