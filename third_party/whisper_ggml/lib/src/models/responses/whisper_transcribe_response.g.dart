// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'whisper_transcribe_response.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_WhisperTranscribeResponse _$WhisperTranscribeResponseFromJson(
        Map<String, dynamic> json) =>
    _WhisperTranscribeResponse(
      type: json['@type'] as String,
      text: json['text'] as String,
      segments: (json['segments'] as List<dynamic>?)
          ?.map((e) =>
              WhisperTranscribeSegment.fromJson(e as Map<String, dynamic>))
          .toList(),
      language: json['language'] as String?,
      backend: json['backend'] as String?,
      gpuFallback: json['gpu_fallback'] as bool? ?? false,
    );

Map<String, dynamic> _$WhisperTranscribeResponseToJson(
        _WhisperTranscribeResponse instance) =>
    <String, dynamic>{
      '@type': instance.type,
      'text': instance.text,
      'segments': instance.segments,
      'language': instance.language,
      'backend': instance.backend,
      'gpu_fallback': instance.gpuFallback,
    };
