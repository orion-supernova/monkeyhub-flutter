/// Voice-message transcription with Apple's built-in on-device recognizer
/// (SpeechAnalyzer, iOS 26 / macOS 26 and later).
///
/// Two Apple engines sit behind one API: SpeechTranscriber (the new long-form
/// model) where it covers the locale, and DictationTranscriber (the keyboard
/// dictation model) for the rest, e.g. Turkish, Swedish and Arabic, which
/// SpeechTranscriber lacks as of OS 27. [AppleSpeechResult.engine] says which
/// one ran.
///
/// On every other platform, and on older Apple OSes, the API reports
/// unavailable and never throws from the query methods.
library apple_speech;

import 'dart:async';

import 'package:flutter/services.dart';

class AppleSpeechWord {
  /// The word with its leading whitespace (none on the first word), so
  /// joining every word's text reproduces [AppleSpeechResult.text] exactly.
  /// In scripts without spaces (Chinese, Japanese) a word is one recognizer
  /// unit, usually a single character.
  final String text;
  final int startMs;
  final int endMs;

  /// 0..1 from the recognizer, null when it reported none.
  final double? confidence;

  const AppleSpeechWord({
    required this.text,
    required this.startMs,
    required this.endMs,
    this.confidence,
  });

  @override
  String toString() => 'AppleSpeechWord("$text", $startMs-$endMs)';
}

class AppleSpeechResult {
  final String text;

  /// The BCP-47 locale that actually ran ("tr-TR"), after resolving the one
  /// passed in ("tr").
  final String locale;
  final List<AppleSpeechWord> words;

  /// Character-weighted mean word confidence, null when [words] is empty.
  /// Measured on macOS 27 with clean speech: the right language scores about
  /// 0.9, a wrong one under 0.3 (or the text comes back empty).
  final double? confidence;

  /// "speech" (SpeechTranscriber) or "dictation" (DictationTranscriber).
  final String engine;

  const AppleSpeechResult({
    required this.text,
    required this.locale,
    required this.words,
    this.confidence,
    this.engine = 'speech',
  });

  @override
  String toString() => 'AppleSpeechResult($locale/$engine, "$text")';
}

enum AppleSpeechError {
  unavailable,
  unsupportedLocale,
  assetsFailed,
  decode,
  permissionDenied,
  cancelled,
  failed,
}

class AppleSpeechException implements Exception {
  final AppleSpeechError error;
  final String? message;

  const AppleSpeechException(this.error, [this.message]);

  @override
  String toString() => 'AppleSpeechException(${error.name}'
      '${message == null ? '' : ': $message'})';
}

abstract final class AppleSpeech {
  static const MethodChannel _channel = MethodChannel('monkeyhub/apple_speech');

  /// The channel, for tests that mock the platform side.
  static MethodChannel get channel => _channel;

  static final Map<int, void Function(double)> _progress = {};
  static int _nextId = 1;
  static bool _handlerSet = false;

  static void _ensureHandler() {
    if (_handlerSet) return;
    _handlerSet = true;
    _channel.setMethodCallHandler((call) async {
      if (call.method != 'progress') return null;
      final args = call.arguments as Map;
      final id = args['id'] as int;
      final fraction = (args['fraction'] as num).toDouble();
      _progress[id]?.call(fraction.clamp(0.0, 1.0));
      return null;
    });
  }

  /// OS >= 26 and an Apple engine usable on this device. False elsewhere,
  /// never throws.
  static Future<bool> isAvailable() async {
    try {
      return await _channel.invokeMethod<bool>('isAvailable') ?? false;
    } catch (_) {
      return false;
    }
  }

  /// BCP-47 identifiers ("tr-TR", "en-US"), the union of both engines.
  static Future<List<String>> supportedLocales() =>
      _stringList('supportedLocales');

  /// Locales whose model is already on the device.
  static Future<List<String>> installedLocales() =>
      _stringList('installedLocales');

  /// The best supported locale for the first of [preferred] (BCP-47 or
  /// language codes like "tr", "sv") that has one; null if none.
  ///
  /// An exact region wins ("pt-PT", "en-GB"); a bare language picks the
  /// device's region if supported, else the language's main region
  /// (en -> en-US, sv -> sv-SE, pt -> pt-BR, es -> es-ES); a missing region
  /// falls back within the language (en-SE -> en-US), except Chinese.
  static Future<String?> bestLocale(List<String> preferred) async {
    try {
      return await _channel.invokeMethod<String>(
        'bestLocale',
        {'preferred': preferred},
      );
    } catch (_) {
      return null;
    }
  }

  /// "speech" or "dictation": the engine that would serve [locale], or null
  /// when unsupported or unavailable.
  static Future<String?> engineFor(String locale) async {
    try {
      return await _channel.invokeMethod<String>('engineFor', {'locale': locale});
    } catch (_) {
      return null;
    }
  }

  /// Ensures the on-device assets for [locale] are installed (and reserved),
  /// reporting 0..1. Completes immediately when already installed. Throws
  /// AppleSpeechException(assetsFailed / unsupportedLocale).
  static Future<void> ensureAssets(
    String locale, {
    void Function(double fraction)? onProgress,
  }) async {
    await _withProgress(onProgress, (id) {
      return _channel.invokeMethod<void>(
        'ensureAssets',
        {'locale': locale, if (id != null) 'id': id},
      );
    });
  }

  /// Whether authorization is needed and granted. SpeechAnalyzer needs no
  /// speech-recognition permission (verified on macOS 27), so this never
  /// prompts: true whenever [isAvailable] is.
  static Future<bool> ensurePermission() async {
    try {
      return await _channel.invokeMethod<bool>('ensurePermission') ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Transcribes the audio file at [path] (AAC .m4a, wav, aiff, caf...) in
  /// [locale]. Word timings come from audioTimeRange. Installs the locale's
  /// assets first if missing (without progress; call [ensureAssets] first to
  /// show it). Throws AppleSpeechException.
  static Future<AppleSpeechResult> transcribe(
    String path,
    String locale, {
    void Function(double fraction)? onProgress,
  }) async {
    final raw = await _withProgress(onProgress, (id) {
      return _channel.invokeMethod<Map<Object?, Object?>>(
        'transcribe',
        {'path': path, 'locale': locale, if (id != null) 'id': id},
      );
    });
    if (raw == null) {
      throw const AppleSpeechException(AppleSpeechError.failed, 'no result');
    }
    final words = <AppleSpeechWord>[
      for (final w in (raw['words'] as List? ?? const []).cast<Map>())
        AppleSpeechWord(
          text: w['text'] as String,
          startMs: (w['startMs'] as num).toInt(),
          endMs: (w['endMs'] as num).toInt(),
          confidence: (w['confidence'] as num?)?.toDouble(),
        ),
    ];
    return AppleSpeechResult(
      text: raw['text'] as String? ?? '',
      locale: raw['locale'] as String? ?? locale,
      words: words,
      confidence: (raw['confidence'] as num?)?.toDouble(),
      engine: raw['engine'] as String? ?? 'speech',
    );
  }

  /// Cancels any transcription in flight; it throws
  /// AppleSpeechException(cancelled).
  static Future<void> cancel() async {
    try {
      await _channel.invokeMethod<void>('cancel');
    } catch (_) {}
  }

  static Future<List<String>> _stringList(String method) async {
    try {
      final list = await _channel.invokeMethod<List<Object?>>(method);
      return list?.whereType<String>().toList() ?? const [];
    } catch (_) {
      return const [];
    }
  }

  static Future<T?> _withProgress<T>(
    void Function(double)? onProgress,
    Future<T?> Function(int? id) body,
  ) async {
    int? id;
    if (onProgress != null) {
      _ensureHandler();
      id = _nextId++;
      _progress[id] = onProgress;
    }
    try {
      return await body(id);
    } on MissingPluginException {
      throw const AppleSpeechException(AppleSpeechError.unavailable);
    } on PlatformException catch (e) {
      throw AppleSpeechException(_errorFor(e.code), e.message);
    } finally {
      if (id != null) _progress.remove(id);
    }
  }

  static AppleSpeechError _errorFor(String code) {
    for (final e in AppleSpeechError.values) {
      if (e.name == code) return e;
    }
    return AppleSpeechError.failed;
  }
}
