/// The one file in this app that knows what a companion actually runs on.
///
/// ── Why the seam is this narrow ────────────────────────────────────────────
///
/// Everything above here — the queue, the cache, the bubbles, the settings
/// screens — is written against [BrainGateway] and has never heard of
/// flutter_gemma, LiteRT-LM, sessions, or `.litertlm` files. That is not
/// architecture for its own sake. On-device inference is a young, fast-moving
/// part of the ecosystem: this app has already had to reject the MediaPipe
/// engine over a simulator-slice problem (see the pubspec note), and the
/// runtime under a companion is the single most likely thing in this feature
/// to be swapped. When it is, the diff should be this file.
///
/// The rule: `package:flutter_gemma` and `package:flutter_gemma_litertlm`
/// appear in this file and nowhere else in `lib/`.
library;

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_gemma/flutter_gemma.dart';
import 'package:flutter_gemma_litertlm/flutter_gemma_litertlm.dart';

import 'brain_spec.dart';

/// How far along an install is, in the two numbers a progress UI needs.
@immutable
class BrainInstallProgress {
  const BrainInstallProgress({required this.receivedBytes, required this.totalBytes});

  final int receivedBytes;
  final int totalBytes;

  double get fraction =>
      totalBytes <= 0 ? 0 : (receivedBytes / totalBytes).clamp(0.0, 1.0);
}

/// Thrown by [BrainGateway.install] when the caller cancelled. Distinct from a
/// failure because the UI treats them oppositely: a cancel returns the sheet to
/// its resting state without a word, a failure has something to say.
class BrainInstallCancelled implements Exception {
  const BrainInstallCancelled();
  @override
  String toString() => 'BrainInstallCancelled';
}

/// A loaded brain, ready to be asked something. Obtained from
/// [BrainGateway.open] and valid until [BrainGateway.unload].
///
/// Holds no context between calls: [generate] opens a fresh session every
/// time. For a translator that is not a limitation but the requirement —
/// message 40's translation must not be able to see message 39, both because
/// it would drift and because a chat transcript accumulating inside a language
/// model is the thing this whole feature exists to avoid.
class LoadedBrain {
  LoadedBrain._(this._model, this.spec);

  final InferenceModel _model;
  final BrainSpec spec;

  /// One-shot generation, streamed.
  ///
  /// Streamed rather than awaited whole for two reasons that both matter here.
  /// The interface one: a translated bubble that fills in word by word reads as
  /// work happening, where a spinner followed by a jump reads as a stall. The
  /// structural one: the FFI runtime hands back a chunk at a time, and awaiting
  /// the whole response means the UI isolate has nothing to do between the
  /// first token and the last. Consuming the stream lets every frame in
  /// between get drawn.
  ///
  /// [stopAt] is checked against the accumulated text after each chunk; when it
  /// returns true the stream is closed early. A 0.6B model told to translate
  /// one line will occasionally translate it and then keep going — offering an
  /// explanation, a second attempt, a bare `</think>`. Stopping the moment the
  /// answer is complete is worth more than any amount of prompt tuning, and it
  /// gives back the tokens too.
  Stream<String> generate(
    String prompt, {
    String? systemInstruction,
    double temperature = 0.2,
    int maxOutputTokens = 512,
    bool Function(String soFar)? stopAt,
  }) async* {
    final session = await _model.createSession(
      // Low but not zero. Greedy decoding on a small quantised model has a
      // specific failure this feature would hit constantly: it gets into a
      // repetition loop and emits the same clause until the token cap. A
      // little temperature is the cheapest way out of one.
      temperature: temperature,
      topK: 1,
      randomSeed: 1,
      systemInstruction: systemInstruction,
      // Qwen3 emits `<think>…</think>` before answering unless this is off.
      // Left off for every family: no companion task wants a reasoning trace,
      // and the ones that would are not shipping yet.
      enableThinking: false,
      // The GENERATED cap, not the context window — see
      // [BrainSpec.contextTokens] for why the two must not be confused.
      maxOutputTokens: maxOutputTokens,
    );
    var stoppedEarly = false;
    try {
      await session.addQueryChunk(Message.text(text: prompt, isUser: true));
      final buffer = StringBuffer();
      await for (final chunk in session.getResponseAsync()) {
        buffer.write(chunk);
        yield chunk;
        if (stopAt != null && stopAt(buffer.toString())) {
          stoppedEarly = true;
          break;
        }
      }
    } finally {
      // Breaking out of an `await for` cancels the subscription, which on the
      // LiteRT-LM FFI engine does reach native and stop it decoding. Asking
      // explicitly anyway: upstream is clear that this is engine-specific and
      // that a merely-abandoned stream keeps the accelerator busy generating
      // output nobody will read, which on a phone means the NEXT translation
      // starts late and the battery paid for both.
      if (stoppedEarly) {
        try {
          await session.stopGeneration();
        } catch (_) {}
      }
      // Always, including on the early break above and on an error mid-stream.
      // A session left open holds its KV cache — a few hundred megabytes on a
      // phone — and the next translation opens another one.
      try {
        await session.close();
      } catch (_) {}
    }
  }
}

/// Install, load, unload, delete. The whole runtime surface.
class BrainGateway {
  BrainGateway._();
  static final BrainGateway instance = BrainGateway._();

  Future<void>? _init;
  LoadedBrain? _loaded;

  /// Whether this build can run a companion at all.
  ///
  /// Native only. Web is excluded deliberately rather than by omission:
  /// `.litertlm` on web is an upstream early preview that runs through
  /// `@litert-lm/core` fetched from a CDN, which needs a `<script>` handshake
  /// in `web/index.html` and — the disqualifying part — would make the private,
  /// on-device companion depend on a third-party CDN at runtime. When that
  /// stops being true this is the line to change.
  bool get isSupported => !kIsWeb;

  /// Idempotent, and safe to call from several places at once — the future is
  /// memoised, so the second caller awaits the first call rather than starting
  /// a second registration.
  Future<void> ensureInitialized() {
    return _init ??= () async {
      // Never `verbose`, in any build. That level logs prompts and model
      // output, which for this feature means printing the contents of
      // people's messages to logcat/syslog. Release is silent regardless of
      // what is set here, but debug builds run on real handsets too.
      FlutterGemma.logLevel = kDebugMode ? GemmaLogLevel.info : GemmaLogLevel.none;
      await FlutterGemma.initialize(
        // Exactly one engine. Registering MediaPipe alongside it is what the
        // upstream docs suggest for apps carrying both formats; this app
        // carries one on purpose (pubspec).
        inferenceEngines: [LiteRtLmEngine()],
      );
    }();
  }

  /// Whether [spec]'s weights are already on disk.
  Future<bool> isInstalled(BrainSpec spec) async {
    if (!isSupported) return false;
    await ensureInitialized();
    try {
      return await FlutterGemma.isModelInstalled(spec.fileName);
    } catch (_) {
      return false;
    }
  }

  /// Downloads [spec], reporting bytes as they land.
  ///
  /// Progress arrives from the plugin as a percentage; it is multiplied back
  /// out against [BrainSpec.sizeBytes] here so the UI can say "104 MB of
  /// 328 MB" as well as draw an arc. That is the right trade: the byte count
  /// is the number a person can sanity-check against their storage, and a
  /// percentage derived from a size we already know exactly loses nothing.
  ///
  /// Throws [BrainInstallCancelled] if [cancel] fires, and rethrows anything
  /// else — a 403 on a repo that turned out to be gated, a disk-full, a dead
  /// network — for [BrainManager] to classify.
  Stream<BrainInstallProgress> install(
    BrainSpec spec, {
    required Future<void> cancel,
  }) {
    final controller = StreamController<BrainInstallProgress>();
    final token = CancelToken();
    // Fire-and-forget: cancellation races the install, and whichever lands
    // first wins. `unawaited` rather than a stored subscription because the
    // future completes at most once and the token ignores a second cancel.
    unawaited(cancel.then((_) => token.cancel('User cancelled')).catchError((_) {}));

    () async {
      try {
        await ensureInitialized();
        await FlutterGemma.installModel(
          modelType: _modelType(spec.family),
          // Never defaults to `.task` here. The default IS `.task`, and an
          // omitted argument would route a `.litertlm` file to MediaPipe —
          // which this app does not even build — and fail at load time, after
          // the download.
          fileType: ModelFileType.litertlm,
        )
            .fromNetwork(spec.url)
            .withProgress((percent) {
              if (controller.isClosed) return;
              controller.add(BrainInstallProgress(
                receivedBytes: (spec.sizeBytes * (percent / 100)).round(),
                totalBytes: spec.sizeBytes,
              ));
            })
            .withCancelToken(token)
            .install();
        if (!controller.isClosed) {
          controller.add(BrainInstallProgress(
            receivedBytes: spec.sizeBytes,
            totalBytes: spec.sizeBytes,
          ));
        }
      } catch (e) {
        if (!controller.isClosed) {
          controller.addError(
            token.isCancelled || CancelToken.isCancel(e)
                ? const BrainInstallCancelled()
                : e,
          );
        }
      } finally {
        await controller.close();
      }
    }();

    return controller.stream;
  }

  /// Loads [spec] and returns something that can be asked a question.
  ///
  /// One brain is resident at a time, and asking for a different one unloads
  /// the current one first. That is a hard constraint rather than a policy:
  /// two int4 models resident at once is well over a gigabyte of RSS on a
  /// device that is also holding a chat transcript and its images, and the
  /// platform's answer to that is to kill the app.
  ///
  /// Returns null when the brain isn't installed, rather than throwing — "not
  /// installed" is the ordinary first-run state and every caller has a
  /// perfectly good thing to do about it (offer the install sheet).
  Future<LoadedBrain?> open(BrainSpec spec) async {
    if (!isSupported) return null;
    await ensureInitialized();

    final current = _loaded;
    if (current != null && current.spec.id == spec.id) return current;
    if (current != null) await unload();

    if (!await isInstalled(spec)) return null;

    try {
      // Re-running the install builder is how the active model gets switched:
      // upstream documents `install()` as idempotent — already-installed
      // weights skip the download and the spec is simply made active. Doing it
      // this way rather than hand-constructing an `InferenceModelSpec` for
      // `setActiveModel` keeps one code path responsible for how a spec is
      // shaped, so the two can't disagree about a file name.
      await FlutterGemma.installModel(
        modelType: _modelType(spec.family),
        fileType: ModelFileType.litertlm,
      ).fromNetwork(spec.url).install();

      final model = await FlutterGemma.getActiveModel(
        maxTokens: spec.contextTokens,
      );
      final loaded = LoadedBrain._(model, spec);
      _loaded = loaded;
      return loaded;
    } catch (e) {
      debugPrint('BrainGateway.open(${spec.id}) failed: $e');
      _loaded = null;
      return null;
    }
  }

  /// The currently resident brain, if any. Read by the settings screen so it
  /// can say whether a companion is warm without loading one to find out.
  BrainSpec? get residentBrain => _loaded?.spec;

  /// Drops the weights. Called when a companion is switched off, when the last
  /// room using one closes, and before loading a different brain.
  Future<void> unload() async {
    final loaded = _loaded;
    _loaded = null;
    if (loaded == null) return;
    try {
      await loaded._model.close();
    } catch (e) {
      debugPrint('BrainGateway.unload failed: $e');
    }
  }

  /// Deletes [spec]'s weights from disk. Unloads first when it is the resident
  /// one — deleting the file under a live mmap is how you get a crash that
  /// looks like a hardware fault.
  Future<void> uninstall(BrainSpec spec) async {
    if (!isSupported) return;
    await ensureInitialized();
    if (_loaded?.spec.id == spec.id) await unload();
    try {
      await FlutterGemma.uninstallModel(spec.fileName);
    } catch (e) {
      debugPrint('BrainGateway.uninstall(${spec.id}) failed: $e');
    }
  }

  /// Which chat template the runtime should apply. The mapping lives here and
  /// not on [BrainFamily] so the enum stays free of plugin types.
  ModelType _modelType(BrainFamily family) => switch (family) {
        BrainFamily.qwen3 => ModelType.qwen3,
        BrainFamily.gemma => ModelType.gemma4,
      };
}
