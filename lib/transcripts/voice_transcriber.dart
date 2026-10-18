/// Voice notes, read: the one place that decides what "Show transcript" does.
///
/// ── The flow behind one tap ────────────────────────────────────────────────
///
///   tap ─► cached? ──yes──► open the slab, done
///            │ no
///            ▼
///        model on disk? ──no──► on cellular? ──yes──► ask once, in the slab
///            │ yes                  │ no
///            │                      ▼
///            │                  download (shared by every bubble that asked)
///            ▼                      │
///        queue ◄────────────────────┘
///            ▼
///        transcribe on device, one note at a time ─► cache ─► slab
///
/// Everything runs on the device. Nothing about a note — not the audio, not
/// the words — goes to the server, which is why the transcript is cached
/// locally rather than stored on the message: it would be the one piece of
/// a voice note the backend could read.
///
/// ── Why per-note handles ───────────────────────────────────────────────────
///
/// The same split as Sebastian's translations (see `translation_slab.dart`):
/// each bubble listens to the [TranscriptHandle] for its own note, so a
/// transcription's progress repaints one bubble, not the room.
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';

import '../companions/brain_download.dart';
import '../media/storage/network_kind.dart';
import '../media/storage/storage_kinds.dart';
import 'builtin_speech.dart';
import 'speech_engine.dart';
import 'transcript.dart';
import 'transcript_model.dart';

enum TranscriptPhase {
  /// Nobody has asked.
  idle,

  /// The model is missing and the phone is on cellular. The slab offers the
  /// download with its size rather than spending 181 MB of someone's plan on
  /// a tap that only said "show transcript".
  awaitingConsent,

  /// The model is downloading. Progress is on [VoiceTranscriber.download],
  /// shared, because there is one model however many bubbles want it.
  downloading,

  /// Queued behind another note, or being transcribed. [TranscriptHandle.progress]
  /// says which.
  transcribing,

  done,
  failed,
}

enum TranscriptFailure { network, storage, audio, engine }

class TranscriptHandle extends ChangeNotifier {
  TranscriptHandle._(this.storageId);

  final String storageId;

  TranscriptPhase _phase = TranscriptPhase.idle;
  TranscriptPhase get phase => _phase;

  Transcript? _transcript;
  Transcript? get transcript => _transcript;

  /// Whether the slab is showing. Separate from [phase] because the reader can
  /// fold a finished transcript away (and back) without redoing any work, and
  /// can fold away one still downloading without stopping it.
  bool _open = false;
  bool get open => _open;

  /// 0..1 through the engine, or null while queued behind another note.
  double? _progress;
  double? get progress => _progress;

  TranscriptFailure? _failure;
  TranscriptFailure? get failure => _failure;

  /// Whether the slab is showing the "better transcripts" offer under a
  /// built-in transcript.
  bool _offering = false;
  bool get offering => _offering;

  /// How to find this note's audio on disk. Kept so a retry, or the go-ahead
  /// on cellular, can resume without the bubble having to ask again.
  Future<String> Function()? _resolveAudio;

  /// Best guesses at the note's language, best first (see
  /// [VoiceLanguageHints]). Only the built-in recognizer needs them.
  List<String> _languages = const [];

  /// The reader asked for the downloaded model on this note — skip the cache
  /// and the built-in recognizer until it has run.
  bool _wantsModel = false;

  /// The built-in recognizer failed on this note once; a retry goes to the
  /// model instead of failing the same way again.
  bool _builtInFailed = false;

  void _set({
    TranscriptPhase? phase,
    Transcript? transcript,
    bool? open,
    double? progress,
    bool clearProgress = false,
    TranscriptFailure? failure,
  }) {
    if (phase != null) _phase = phase;
    if (transcript != null) _transcript = transcript;
    if (open != null) _open = open;
    if (progress != null || clearProgress) _progress = progress;
    _failure = failure;
    notifyListeners();
  }
}

class VoiceTranscriber {
  VoiceTranscriber._(this._engine, [this._builtIn]);

  static VoiceTranscriber instance = VoiceTranscriber._(_NoEngine());

  /// Installs the real engines. Called once at startup; a separate step so
  /// this file never imports the native plugins and tests never load them.
  static void install(SpeechEngine engine, {BuiltInSpeech? builtIn}) =>
      instance = VoiceTranscriber._(engine, builtIn);

  @visibleForTesting
  static VoiceTranscriber forTest(
    SpeechEngine engine, {
    BuiltInSpeech? builtIn,
    TranscriptModel model = TranscriptModel.current,
    Stream<DownloadProgress> Function(DownloadTarget)? download,
    bool Function()? onCellular,
    List<String> Function()? deviceLanguages,
  }) =>
      VoiceTranscriber._(engine, builtIn)
        .._model = model
        .._downloadFn = download ?? _defaultDownload
        .._onCellular = onCellular ?? _defaultOnCellular
        .._deviceLanguages = deviceLanguages ?? _defaultDeviceLanguages;

  final SpeechEngine _engine;

  /// Tried first when the model is not installed: no download, and on the
  /// platforms that have one it is good. Null where there is none.
  final BuiltInSpeech? _builtIn;

  List<String> Function() _deviceLanguages = _defaultDeviceLanguages;
  static List<String> _defaultDeviceLanguages() => [
        for (final l in PlatformDispatcher.instance.locales) l.toLanguageTag(),
      ];
  TranscriptModel _model = TranscriptModel.current;
  Stream<DownloadProgress> Function(DownloadTarget) _downloadFn = _defaultDownload;
  bool Function() _onCellular = _defaultOnCellular;

  static BrainDownload? _activeDownload;
  static Stream<DownloadProgress> _defaultDownload(DownloadTarget t) =>
      (_activeDownload = BrainDownload.target(t)).start();
  static bool _defaultOnCellular() =>
      NetworkKindMonitor.instance.current == NetKind.cellular;

  TranscriptModel get model => _model;

  /// Whether this platform can transcribe at all. The bubble shows no button
  /// when it cannot — a button that can only ever fail is worse than none.
  bool get supported => _engine.supported;

  /// The model download, while one is running. Null otherwise.
  final ValueNotifier<DownloadProgress?> download = ValueNotifier(null);

  /// Fires when the model is installed or removed, for the storage screens.
  final ValueNotifier<bool?> modelInstalled = ValueNotifier(null);

  final Map<String, TranscriptHandle> _handles = {};

  /// Set once the reader has said yes to a download on cellular. Per launch,
  /// not persisted: the question is about this download, not a policy.
  bool _cellularOk = false;

  /// The handle for one note, created on first ask. Already [TranscriptPhase.done]
  /// if the note was transcribed before, so the button can say so.
  TranscriptHandle handleFor(String storageId) {
    final existing = _handles[storageId];
    if (existing != null) return existing;
    final h = _handles[storageId] = TranscriptHandle._(storageId);
    final cached = _cache?[storageId];
    if (cached != null) h._set(phase: TranscriptPhase.done, transcript: cached);
    unawaited(_loadCache());
    return h;
  }

  /// What the button does.
  ///
  /// Toggles the slab. Opening it for the first time is also what starts the
  /// work; closing it never stops work in flight — a download half done when
  /// the reader folded the slab is still wanted the next time they open it.
  ///
  /// [languages] are guesses at the note's language, best first — see
  /// [VoiceLanguageHints]. The device's own languages are tried after them.
  Future<void> toggle(
    String storageId,
    Future<String> Function() resolveAudio, {
    List<String> languages = const [],
  }) async {
    final h = handleFor(storageId);
    h._resolveAudio = resolveAudio;
    h._languages = languages;
    switch (h.phase) {
      case TranscriptPhase.idle || TranscriptPhase.failed:
        h._set(open: true, phase: TranscriptPhase.transcribing, clearProgress: true);
        await _run(h);
      case TranscriptPhase.done ||
            TranscriptPhase.awaitingConsent ||
            TranscriptPhase.downloading ||
            TranscriptPhase.transcribing:
        h._offering = false;
        h._set(open: !h.open, failure: h.failure);
    }
  }

  /// Opens or closes the "better transcripts" offer under a built-in
  /// transcript.
  void setOffering(String storageId, bool on) {
    final h = _handles[storageId];
    if (h == null || h._offering == on) return;
    h._offering = on;
    h._set(failure: h.failure);
  }

  /// The reader took the offer: fetch the model (asking first on cellular,
  /// as always) and transcribe this note again with it. Every note after
  /// this one uses the model, because it is installed.
  Future<void> upgrade(String storageId) async {
    final h = _handles[storageId];
    if (h == null || h._resolveAudio == null) return;
    h._offering = false;
    h._wantsModel = true;
    h._set(open: true, phase: TranscriptPhase.transcribing, clearProgress: true);
    await _run(h);
  }

  /// The go-ahead from the slab's cellular prompt.
  Future<void> allowCellular(String storageId) async {
    _cellularOk = true;
    final waiting = [
      for (final h in _handles.values)
        if (h.phase == TranscriptPhase.awaitingConsent) h,
    ];
    // The one the reader tapped first, so its slab is the first to move.
    waiting.sort((a, b) => a.storageId == storageId ? -1 : (b.storageId == storageId ? 1 : 0));
    for (final h in waiting) {
      h._set(phase: TranscriptPhase.transcribing, clearProgress: true);
    }
    await Future.wait([for (final h in waiting) _run(h)]);
  }

  Future<void> retry(String storageId) async {
    final h = _handles[storageId];
    if (h == null || h._resolveAudio == null) return;
    h._set(open: true, phase: TranscriptPhase.transcribing, clearProgress: true);
    await _run(h);
  }

  /// Stops the model download and throws away what it had. Every note that
  /// was waiting on it goes back to rest with its slab folded.
  void cancelDownload() {
    // The downloader first, so it knows this is a cancel (discard the
    // partial) and not a consumer walking away (keep it — see
    // [BrainDownload.start]).
    _activeDownload?.cancel();
    unawaited(_downloadSub?.cancel());
    _downloadSub = null;
    final done = _downloadDone;
    if (done != null && !done.isCompleted) {
      done.completeError(const DownloadCancelled());
    }
  }

  StreamSubscription<DownloadProgress>? _downloadSub;
  Completer<void>? _downloadDone;

  Future<void> _run(TranscriptHandle h) async {
    await _loadCache();
    final cached = _cache![h.storageId];
    if (cached != null && !h._wantsModel) {
      h._set(phase: TranscriptPhase.done, transcript: cached);
      return;
    }

    final installed = await TranscriptStore.instance.isInstalled(_model);
    // The model, once installed, is the reader's choice — it is only ever
    // there because they downloaded it. Until then the OS's recognizer goes
    // first: nothing to download, and nothing to ask.
    if (!installed && !h._wantsModel && !h._builtInFailed) {
      if (await _tryBuiltIn(h)) return;
    }

    if (!installed) {
      if (_modelFuture == null && _onCellular() && !_cellularOk) {
        h._set(phase: TranscriptPhase.awaitingConsent);
        return;
      }
      h._set(phase: TranscriptPhase.downloading);
      try {
        await (_modelFuture ??= _downloadModel());
      } on DownloadCancelled {
        h._wantsModel = false;
        // An upgrade called off keeps the transcript it was replacing.
        if (h.transcript != null) {
          h._set(phase: TranscriptPhase.done);
        } else {
          h._set(phase: TranscriptPhase.idle, open: false);
        }
        return;
      } on DownloadException catch (e) {
        h._set(
          phase: TranscriptPhase.failed,
          failure: e.failure == DownloadFailure.storage
              ? TranscriptFailure.storage
              : TranscriptFailure.network,
        );
        return;
      } catch (_) {
        h._set(phase: TranscriptPhase.failed, failure: TranscriptFailure.network);
        return;
      }
      h._set(phase: TranscriptPhase.transcribing, clearProgress: true);
    }

    final job = _tail.then((_) => _transcribe(h));
    _tail = job.catchError((_) {});
    await job;
  }

  /// The built-in path. True when it handled the note (finished, or failed
  /// in a way the model would not fix); false to fall through to the model:
  /// no recognizer, or none of the likely languages is on the device.
  Future<bool> _tryBuiltIn(TranscriptHandle h) async {
    final b = _builtIn;
    if (b == null) return false;
    List<String> locales;
    try {
      locales = await b.readyLocales([...h._languages, ..._deviceLanguages()]);
    } catch (e) {
      debugPrint('VoiceTranscriber: built-in unavailable: $e');
      return false;
    }
    if (locales.isEmpty) return false;
    final job = _tail.then((_) => _transcribeBuiltIn(h, b, locales.take(_maxTries).toList()));
    _tail = job.catchError((_) {});
    await job;
    return true;
  }

  /// How many languages to try on one note. Each pass is about 0.3 s for a
  /// 5 s note; three covers "the sender's, the reader's, the phone's".
  static const int _maxTries = 3;

  /// Tries [locales] in order and keeps the first confident result, or the
  /// most confident of them. The recognizer cannot tell what language it is
  /// hearing, but it is reliably UNSURE in the wrong one, and that is enough.
  Future<void> _transcribeBuiltIn(TranscriptHandle h, BuiltInSpeech b, List<String> locales) async {
    final resolve = h._resolveAudio;
    if (resolve == null) return;
    String audio;
    try {
      audio = await resolve();
    } catch (_) {
      h._set(phase: TranscriptPhase.failed, failure: TranscriptFailure.audio);
      return;
    }
    h._set(progress: 0);
    Transcript? best;
    try {
      for (final (i, locale) in locales.indexed) {
        final t = await b.transcribe(
          audio,
          locale,
          onProgress: (f) => h._set(progress: ((i + f) / locales.length).clamp(0.0, 1.0)),
        );
        if (best == null || _score(t) > _score(best)) best = t;
        if (!t.doubtful) break;
      }
    } on BuiltInSpeechException catch (e) {
      debugPrint('VoiceTranscriber: built-in failed on ${h.storageId}: $e');
      if (best == null) {
        // A note the OS could not decode, the model's decoder will not read
        // either. Anything else, the retry goes to the model.
        if (e.failure != BuiltInFailure.audio) h._builtInFailed = true;
        h._set(
          phase: TranscriptPhase.failed,
          failure: e.failure == BuiltInFailure.audio
              ? TranscriptFailure.audio
              : TranscriptFailure.engine,
          clearProgress: true,
        );
        return;
      }
    } catch (e) {
      debugPrint('VoiceTranscriber: built-in failed on ${h.storageId}: $e');
      if (best == null) {
        h._builtInFailed = true;
        h._set(phase: TranscriptPhase.failed, failure: TranscriptFailure.engine, clearProgress: true);
        return;
      }
    }
    final t = best!;
    _remember(h.storageId, t);
    // Wrong language, most likely: say so where the reader is looking, with
    // the fix one tap away, rather than presenting nonsense as a transcript.
    if (t.doubtful) h._offering = true;
    h._set(phase: TranscriptPhase.done, transcript: t, clearProgress: true);
  }

  static double _score(Transcript t) =>
      t.isEmpty ? -1 : (t.confidence ?? 0.75);

  Future<void>? _modelFuture;

  Future<void> _downloadModel() async {
    final done = _downloadDone = Completer<void>();
    download.value = DownloadProgress(received: 0, total: _model.sizeBytes);
    _downloadSub = _downloadFn(_model.target).listen(
      (p) => download.value = p,
      onError: (Object e, StackTrace st) {
        if (!done.isCompleted) done.completeError(e, st);
      },
      onDone: () {
        if (!done.isCompleted) done.complete();
      },
      cancelOnError: true,
    );
    try {
      await done.future;
      modelInstalled.value = true;
      // In front right now, by definition — the reader just watched it land.
      unawaited(_engine.prewarm());
    } finally {
      download.value = null;
      _modelFuture = null;
      _activeDownload = null;
      _downloadSub = null;
      _downloadDone = null;
    }
  }

  /// One note at a time. The engine holds a few hundred megabytes while it
  /// works, and two of them at once on a phone is how an app gets killed.
  Future<void> _tail = Future.value();

  Timer? _releaseTimer;

  Future<void> _transcribe(TranscriptHandle h) async {
    _releaseTimer?.cancel();
    final resolve = h._resolveAudio;
    if (resolve == null) return;
    String audio;
    try {
      audio = await resolve();
    } catch (_) {
      h._set(phase: TranscriptPhase.failed, failure: TranscriptFailure.audio);
      return;
    }
    h._set(progress: 0);
    try {
      final modelFile = await TranscriptStore.instance.modelFile(_model);
      final t = await _engine.transcribe(
        audioPath: audio,
        modelPath: modelFile.path,
        onProgress: (f) => h._set(progress: f.clamp(0.0, 1.0)),
      );
      _remember(h.storageId, t);
      h._wantsModel = false;
      h._set(phase: TranscriptPhase.done, transcript: t, clearProgress: true);
    } on SpeechException catch (e) {
      debugPrint('VoiceTranscriber: ${h.storageId} failed: $e');
      h._set(
        phase: TranscriptPhase.failed,
        failure: e.failure == SpeechFailure.decode
            ? TranscriptFailure.audio
            : TranscriptFailure.engine,
        clearProgress: true,
      );
    } catch (e) {
      debugPrint('VoiceTranscriber: ${h.storageId} failed: $e');
      h._set(
        phase: TranscriptPhase.failed,
        failure: TranscriptFailure.engine,
        clearProgress: true,
      );
    } finally {
      // Kept loaded for a burst of taps down a conversation — loading the
      // weights is the slow part — and let go once the reader stops.
      _releaseTimer = Timer(const Duration(seconds: 60), () {
        unawaited(_engine.release());
      });
    }
  }

  // ───────────────────────────── the model ─────────────────────────────

  Future<bool> isModelInstalled() => TranscriptStore.instance.isInstalled(_model);

  /// Re-reads the disk into [modelInstalled], for the screens that show it.
  Future<bool> refreshModelInstalled() async {
    final on = await isModelInstalled();
    modelInstalled.value = on;
    return on;
  }

  /// What [modelInstalled] knows right now, without waiting. The first read
  /// starts a check and answers null; listeners hear the real answer.
  bool? get modelInstalledNow {
    final v = modelInstalled.value;
    if (v == null) unawaited(refreshModelInstalled());
    return v;
  }

  /// Whether the OS has a recognizer this transcriber can try first.
  bool get hasBuiltIn => _builtIn != null;

  /// Of [candidates] (language codes or tags), the ones the OS recognizer
  /// already has on the device, as its locale tags, best first. Empty where
  /// there is no recognizer. Nothing is downloaded to answer this.
  Future<List<String>> builtInLanguages(List<String> candidates) async {
    final b = _builtIn;
    if (b == null) return const [];
    try {
      return await b.readyLocales(candidates);
    } catch (e) {
      debugPrint('VoiceTranscriber: built-in languages unavailable: $e');
      return const [];
    }
  }

  /// Whether a download started now would run on cellular data and nobody has
  /// said yes to that yet this launch.
  bool get downloadNeedsCellularConsent => _onCellular() && !_cellularOk;

  /// Downloads the model from Bartleby's screen rather than from a bubble.
  ///
  /// Joins a download a bubble already started instead of starting a second.
  /// [cellularOk] is the reader's yes from that screen; it counts for the
  /// bubbles too, so none of them asks again this launch. Returns null once
  /// the model is on disk (or the download was cancelled), else why not.
  Future<TranscriptFailure?> installModel({bool cellularOk = false}) async {
    if (cellularOk) _cellularOk = true;
    try {
      await (_modelFuture ??= _downloadModel());
      // A bubble left asking about cellular has its answer now: the model
      // is here. Carry on with it rather than leave it asking.
      for (final h in _handles.values) {
        if (h.phase == TranscriptPhase.awaitingConsent) {
          h._set(phase: TranscriptPhase.transcribing, clearProgress: true);
          unawaited(_run(h));
        }
      }
      return null;
    } on DownloadCancelled {
      return null;
    } on DownloadException catch (e) {
      return e.failure == DownloadFailure.storage
          ? TranscriptFailure.storage
          : TranscriptFailure.network;
    } catch (_) {
      return TranscriptFailure.network;
    }
  }

  /// Removes the model. Transcripts already made are kept.
  Future<int> removeModel() async {
    cancelDownload();
    await _engine.release();
    final freed = await TranscriptStore.instance.deleteModel(_model);
    modelInstalled.value = false;
    return freed;
  }

  /// Clear Cache: the model, every transcript, and every open slab.
  Future<void> forgetAll() async {
    await removeModel();
    _saveTimer?.cancel();
    _cache?.clear();
    try {
      final f = await TranscriptStore.instance.cacheFile();
      if (await f.exists()) await f.delete();
    } catch (_) {}
    for (final h in _handles.values) {
      if (h.phase == TranscriptPhase.done || h.phase == TranscriptPhase.failed) {
        h._transcript = null;
        h._set(phase: TranscriptPhase.idle, open: false);
      }
    }
  }

  // ───────────────────────────── the cache ─────────────────────────────

  /// Insertion-ordered (a Dart map literal is), most recently used last. A few hundred bytes a note; capped so a year of
  /// voice notes cannot grow it without bound.
  static const int _cacheCap = 500;

  Map<String, Transcript>? _cache;
  Future<void>? _cacheLoad;
  Timer? _saveTimer;

  Future<void> _loadCache() => _cacheLoad ??= () async {
        final map = <String, Transcript>{};
        try {
          final f = await TranscriptStore.instance.cacheFile();
          if (await f.exists()) {
            final raw = jsonDecode(await f.readAsString());
            if (raw is Map) {
              for (final e in raw.entries) {
                final t = Transcript.fromJson(e.value);
                if (e.key is String && t != null) map[e.key as String] = t;
              }
            }
          }
        } catch (e) {
          debugPrint('VoiceTranscriber: cache unreadable, starting empty: $e');
        }
        _cache = map;
        // First time anything here is touched this launch. If the model is
        // on disk, have the engine ready before the reader taps.
        if (await TranscriptStore.instance.isInstalled(_model)) {
          unawaited(_engine.prewarm());
        }
        // Handles made before the cache arrived learn what it knew.
        for (final h in _handles.values) {
          final t = map[h.storageId];
          if (t != null && h.phase == TranscriptPhase.idle) {
            h._set(phase: TranscriptPhase.done, transcript: t);
          }
        }
      }();

  void _remember(String storageId, Transcript t) {
    final cache = _cache!;
    cache.remove(storageId);
    cache[storageId] = t;
    while (cache.length > _cacheCap) {
      cache.remove(cache.keys.first);
    }
    _saveTimer?.cancel();
    _saveTimer = Timer(const Duration(milliseconds: 400), _save);
  }

  Future<void> _save() async {
    final cache = _cache;
    if (cache == null) return;
    try {
      final f = await TranscriptStore.instance.cacheFile();
      await f.parent.create(recursive: true);
      final tmp = File('${f.path}.tmp');
      await tmp.writeAsString(jsonEncode({
        for (final e in cache.entries) e.key: e.value.toJson(),
      }));
      await tmp.rename(f.path);
    } catch (e) {
      debugPrint('VoiceTranscriber: could not save transcripts: $e');
    }
  }

  @visibleForTesting
  Future<void> flushForTest() async {
    _saveTimer?.cancel();
    await _save();
  }
}

/// Until [VoiceTranscriber.install] runs — and forever on web.
class _NoEngine implements SpeechEngine {
  @override
  bool get supported => false;

  @override
  Future<Transcript> transcribe({
    required String audioPath,
    required String modelPath,
    void Function(double fraction)? onProgress,
  }) =>
      throw const SpeechException(SpeechFailure.engine, 'no engine on this platform');

  @override
  Future<void> release() async {}

  @override
  Future<void> prewarm() async {}
}
