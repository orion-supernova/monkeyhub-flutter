@TestOn('vm')
library;

import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:monkeyhub/companions/brain_download.dart';
import 'package:monkeyhub/transcripts/builtin_speech.dart';
import 'package:monkeyhub/transcripts/speech_engine.dart';
import 'package:monkeyhub/transcripts/transcript.dart';
import 'package:monkeyhub/transcripts/transcript_model.dart';
import 'package:monkeyhub/transcripts/voice_transcriber.dart';

/// The state machine behind "Show transcript": download once, queue, cache,
/// and every phase the slab can be in. The engine and the download are fakes;
/// what is under test is what the transcriber does with them.
void main() {
  late Directory tmp;
  const model = TranscriptModel.test(fileName: 'm.bin', sizeBytes: 8);

  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('voice_transcriber_test');
    TranscriptStore.instance.debugDir = tmp;
  });

  tearDown(() async {
    TranscriptStore.instance.debugDir = null;
    if (await tmp.exists()) await tmp.delete(recursive: true);
  });

  Future<void> install() async {
    final f = await TranscriptStore.instance.modelFile(model);
    await f.parent.create(recursive: true);
    await f.writeAsBytes(List.filled(model.sizeBytes, 1));
  }

  /// A download that writes the model when [release] completes.
  ({Stream<DownloadProgress> Function(DownloadTarget) fn, Completer<void> release, int Function() starts})
      gatedDownload() {
    final release = Completer<void>();
    var starts = 0;
    Stream<DownloadProgress> fn(DownloadTarget t) async* {
      starts++;
      yield DownloadProgress(received: 4, total: t.sizeBytes);
      await release.future;
      final f = await t.file();
      await f.parent.create(recursive: true);
      await f.writeAsBytes(List.filled(t.sizeBytes, 1));
      yield DownloadProgress(received: t.sizeBytes, total: t.sizeBytes);
    }

    return (fn: fn, release: release, starts: () => starts);
  }

  Future<String> audio() async => '/notes/a.m4a';

  test('installed model: one tap transcribes, opens, and caches to disk', () async {
    await install();
    final engine = _FakeEngine();
    final t = VoiceTranscriber.forTest(engine, model: model, onCellular: () => false);

    await t.toggle('note1', audio);
    final h = t.handleFor('note1');
    expect(h.phase, TranscriptPhase.done);
    expect(h.open, isTrue);
    expect(h.transcript!.text, 'merhaba dünya');
    expect(engine.calls, ['/notes/a.m4a']);

    // A fresh process finds it on disk and never runs the engine.
    await t.flushForTest();
    final engine2 = _FakeEngine();
    final t2 = VoiceTranscriber.forTest(engine2, model: model, onCellular: () => false);
    await t2.toggle('note1', audio);
    expect(t2.handleFor('note1').transcript!.text, 'merhaba dünya');
    expect(engine2.calls, isEmpty);
  });

  test('tapping a finished transcript folds and unfolds it without rework', () async {
    await install();
    final engine = _FakeEngine();
    final t = VoiceTranscriber.forTest(engine, model: model, onCellular: () => false);
    await t.toggle('n', audio);
    await t.toggle('n', audio);
    expect(t.handleFor('n').open, isFalse);
    await t.toggle('n', audio);
    expect(t.handleFor('n').open, isTrue);
    expect(engine.calls, hasLength(1));
  });

  test('missing model on Wi-Fi: one shared download, then both notes transcribe', () async {
    final dl = gatedDownload();
    final engine = _FakeEngine();
    final t = VoiceTranscriber.forTest(engine,
        model: model, download: dl.fn, onCellular: () => false);

    final a = t.toggle('a', audio);
    final b = t.toggle('b', audio);
    await pumpEventQueue();
    expect(t.handleFor('a').phase, TranscriptPhase.downloading);
    expect(t.handleFor('b').phase, TranscriptPhase.downloading);
    expect(t.download.value?.received, 4);
    expect(dl.starts(), 1);

    dl.release.complete();
    await Future.wait([a, b]);
    expect(t.handleFor('a').phase, TranscriptPhase.done);
    expect(t.handleFor('b').phase, TranscriptPhase.done);
    expect(t.download.value, isNull);
    expect(engine.calls, hasLength(2));
  });

  test('missing model on cellular asks first, then downloads on the go-ahead', () async {
    final dl = gatedDownload();
    final t = VoiceTranscriber.forTest(_FakeEngine(),
        model: model, download: dl.fn, onCellular: () => true);

    await t.toggle('a', audio);
    expect(t.handleFor('a').phase, TranscriptPhase.awaitingConsent);
    expect(t.handleFor('a').open, isTrue);
    expect(dl.starts(), 0);

    final go = t.allowCellular('a');
    await pumpEventQueue();
    expect(t.handleFor('a').phase, TranscriptPhase.downloading);
    dl.release.complete();
    await go;
    expect(t.handleFor('a').phase, TranscriptPhase.done);
  });

  test('cancelling the download folds every waiting note back to rest', () async {
    final dl = gatedDownload();
    final t = VoiceTranscriber.forTest(_FakeEngine(),
        model: model, download: dl.fn, onCellular: () => false);
    final a = t.toggle('a', audio);
    await pumpEventQueue();
    t.cancelDownload();
    await a;
    final h = t.handleFor('a');
    expect(h.phase, TranscriptPhase.idle);
    expect(h.open, isFalse);
    expect(t.download.value, isNull);
  });

  test('an undecodable note fails as audio, and retry recovers', () async {
    await install();
    final engine = _FakeEngine()..failNext = const SpeechException(SpeechFailure.decode);
    final t = VoiceTranscriber.forTest(engine, model: model, onCellular: () => false);
    await t.toggle('n', audio);
    expect(t.handleFor('n').phase, TranscriptPhase.failed);
    expect(t.handleFor('n').failure, TranscriptFailure.audio);

    await t.retry('n');
    expect(t.handleFor('n').phase, TranscriptPhase.done);
  });

  test('notes are transcribed one at a time', () async {
    await install();
    final engine = _FakeEngine()..gate = Completer<void>();
    final t = VoiceTranscriber.forTest(engine, model: model, onCellular: () => false);
    final a = t.toggle('a', audio);
    final b = t.toggle('b', audio);
    await pumpEventQueue();
    expect(engine.running, 1);
    engine.gate!.complete();
    await Future.wait([a, b]);
    expect(engine.maxRunning, 1);
    expect(engine.calls, hasLength(2));
  });

  test('forgetAll removes the model and the transcripts', () async {
    await install();
    final t = VoiceTranscriber.forTest(_FakeEngine(), model: model, onCellular: () => false);
    await t.toggle('n', audio);
    await t.flushForTest();
    await t.forgetAll();
    expect(await TranscriptStore.instance.isInstalled(model), isFalse);
    expect(await (await TranscriptStore.instance.cacheFile()).exists(), isFalse);
    expect(t.handleFor('n').phase, TranscriptPhase.idle);
  });

  /// Bartleby's screen: the download started from Settings rather than from
  /// a bubble.
  group('installModel', () {
    Future<void> settle(bool Function() done) async {
      for (var i = 0; i < 100 && !done(); i++) {
        await Future<void>.delayed(Duration.zero);
      }
    }

    test('a yes on cellular counts for the bubbles, and a waiting one carries on', () async {
      final engine = _FakeEngine();
      final g = gatedDownload();
      final t = VoiceTranscriber.forTest(engine, model: model, download: g.fn, onCellular: () => true);

      await t.toggle('n1', audio);
      final h = t.handleFor('n1');
      expect(h.phase, TranscriptPhase.awaitingConsent);
      expect(t.downloadNeedsCellularConsent, isTrue);

      final result = t.installModel(cellularOk: true);
      expect(t.downloadNeedsCellularConsent, isFalse);
      g.release.complete();
      expect(await result, isNull);
      expect(t.modelInstalled.value, isTrue);
      expect(await t.refreshModelInstalled(), isTrue);

      await settle(() => h.phase == TranscriptPhase.done);
      expect(h.phase, TranscriptPhase.done);
      expect(engine.calls, ['/notes/a.m4a']);
      expect(g.starts(), 1);
    });

    test('joins a download a bubble already started', () async {
      final g = gatedDownload();
      final t = VoiceTranscriber.forTest(_FakeEngine(), model: model, download: g.fn, onCellular: () => false);
      final tap = t.toggle('n1', audio);
      await settle(() => t.download.value != null);
      final result = t.installModel();
      g.release.complete();
      expect(await result, isNull);
      await tap;
      expect(g.starts(), 1);
      expect(t.handleFor('n1').phase, TranscriptPhase.done);
    });

    test('a full disk is reported as storage', () async {
      Stream<DownloadProgress> full(DownloadTarget t) async* {
        throw const DownloadException(DownloadFailure.storage);
      }

      final t = VoiceTranscriber.forTest(_FakeEngine(), model: model, download: full, onCellular: () => false);
      expect(await t.installModel(), TranscriptFailure.storage);
      expect(t.download.value, isNull);
    });
  });

  test('builtInLanguages asks the OS what it already has, and is empty without one', () async {
    final withApple = VoiceTranscriber.forTest(_FakeEngine(), builtIn: _FakeBuiltIn(), model: model);
    expect(withApple.hasBuiltIn, isTrue);
    expect(await withApple.builtInLanguages(['en', 'tr', 'de']), ['en-US', 'tr-TR']);

    final without = VoiceTranscriber.forTest(_FakeEngine(), model: model);
    expect(without.hasBuiltIn, isFalse);
    expect(await without.builtInLanguages(['en']), isEmpty);
  });

  group('built-in recognizer first', () {
    test('no model: the built-in one transcribes, told the hinted language first', () async {
      final dl = gatedDownload();
      final b = _FakeBuiltIn();
      final engine = _FakeEngine();
      final t = VoiceTranscriber.forTest(engine,
          builtIn: b, model: model, download: dl.fn, onCellular: () => false,
          deviceLanguages: () => ['en-US']);
      await t.toggle('n', audio, languages: ['tr', 'sv']);
      final h = t.handleFor('n');
      expect(h.phase, TranscriptPhase.done);
      expect(h.transcript!.source, TranscriptSource.builtIn);
      expect(b.asked.first, ['tr', 'sv', 'en-US']);
      // Confident in the first, so the others are never tried.
      expect(b.transcribedIn, ['tr-TR']);
      expect(dl.starts(), 0);
      expect(engine.calls, isEmpty);
    });

    test('a language the built-in one lacks goes to the model', () async {
      await install();
      final b = _FakeBuiltIn()..installed = {};
      final engine = _FakeEngine();
      final t = VoiceTranscriber.forTest(engine,
          builtIn: b, model: model, onCellular: () => false, deviceLanguages: () => []);
      // Model installed here, so the model is used regardless; covered below
      // for the not-installed case.
      await t.toggle('n', audio, languages: ['hi']);
      expect(t.handleFor('n').transcript!.source, TranscriptSource.model);
    });

    test('no locale and no model: falls through to the model download', () async {
      final dl = gatedDownload();
      final b = _FakeBuiltIn()..installed = {};
      final t = VoiceTranscriber.forTest(_FakeEngine(),
          builtIn: b, model: model, download: dl.fn, onCellular: () => false,
          deviceLanguages: () => []);
      final run = t.toggle('n', audio, languages: ['hi']);
      await pumpEventQueue();
      expect(t.handleFor('n').phase, TranscriptPhase.downloading);
      dl.release.complete();
      await run;
      expect(t.handleFor('n').transcript!.source, TranscriptSource.model);
    });

    test('wrong-language confidence moves on to the next installed language', () async {
      final b = _FakeBuiltIn()..confidence = {'en-US': 0.14};
      final t = VoiceTranscriber.forTest(_FakeEngine(),
          builtIn: b, model: model, onCellular: () => false, deviceLanguages: () => ['tr-TR']);
      await t.toggle('n', audio, languages: ['en']);
      final h = t.handleFor('n');
      expect(b.transcribedIn, ['en-US', 'tr-TR']);
      expect(h.transcript!.language, 'tr');
      expect(h.offering, isFalse);
    });

    test('unsure in every language: keeps the best and opens the offer', () async {
      final b = _FakeBuiltIn()..confidence = {'en-US': 0.14, 'tr-TR': 0.2};
      final t = VoiceTranscriber.forTest(_FakeEngine(),
          builtIn: b, model: model, onCellular: () => false, deviceLanguages: () => ['tr']);
      await t.toggle('n', audio, languages: ['en']);
      final h = t.handleFor('n');
      expect(h.phase, TranscriptPhase.done);
      expect(h.transcript!.language, 'tr');
      expect(h.transcript!.doubtful, isTrue);
      expect(h.offering, isTrue);
    });

    test('no confidence at all is not doubt', () async {
      final b = _FakeBuiltIn()..confidence = {'tr-TR': null};
      final t = VoiceTranscriber.forTest(_FakeEngine(),
          builtIn: b, model: model, onCellular: () => false, deviceLanguages: () => []);
      await t.toggle('n', audio, languages: ['tr']);
      expect(b.transcribedIn, ['tr-TR']);
      expect(t.handleFor('n').offering, isFalse);
    });

    test('once the model is installed it wins over the built-in one', () async {
      await install();
      final b = _FakeBuiltIn();
      final t = VoiceTranscriber.forTest(_FakeEngine(),
          builtIn: b, model: model, onCellular: () => false);
      await t.toggle('n', audio, languages: ['tr']);
      expect(t.handleFor('n').transcript!.source, TranscriptSource.model);
      expect(b.transcribedIn, isEmpty);
    });

    test('upgrade replaces a built-in transcript with the model, keeping it visible meanwhile', () async {
      final dl = gatedDownload();
      final t = VoiceTranscriber.forTest(_FakeEngine(),
          builtIn: _FakeBuiltIn(), model: model, download: dl.fn, onCellular: () => false);
      await t.toggle('n', audio, languages: ['tr']);
      final h = t.handleFor('n');
      t.setOffering('n', true);
      expect(h.offering, isTrue);

      final up = t.upgrade('n');
      await pumpEventQueue();
      expect(h.offering, isFalse);
      expect(h.phase, TranscriptPhase.downloading);
      expect(h.transcript!.source, TranscriptSource.builtIn);

      dl.release.complete();
      await up;
      expect(h.phase, TranscriptPhase.done);
      expect(h.transcript!.source, TranscriptSource.model);

      // And the cache now holds the model's version.
      await t.flushForTest();
      final t2 = VoiceTranscriber.forTest(_FakeEngine(),
          builtIn: _FakeBuiltIn(), model: model, onCellular: () => false);
      await t2.toggle('n', audio);
      expect(t2.handleFor('n').transcript!.source, TranscriptSource.model);
    });

    test('cancelling an upgrade keeps the built-in transcript', () async {
      final dl = gatedDownload();
      final t = VoiceTranscriber.forTest(_FakeEngine(),
          builtIn: _FakeBuiltIn(), model: model, download: dl.fn, onCellular: () => false);
      await t.toggle('n', audio, languages: ['tr']);
      final up = t.upgrade('n');
      await pumpEventQueue();
      t.cancelDownload();
      await up;
      final h = t.handleFor('n');
      expect(h.phase, TranscriptPhase.done);
      expect(h.open, isTrue);
      expect(h.transcript!.source, TranscriptSource.builtIn);
    });

    test('a built-in engine failure retries on the model', () async {
      await install();
      await TranscriptStore.instance.deleteModel(model);
      final dl = gatedDownload()..release.complete();
      final b = _FakeBuiltIn()..fail = const BuiltInSpeechException(BuiltInFailure.engine);
      final t = VoiceTranscriber.forTest(_FakeEngine(),
          builtIn: b, model: model, download: dl.fn, onCellular: () => false);
      await t.toggle('n', audio, languages: ['tr']);
      expect(t.handleFor('n').phase, TranscriptPhase.failed);
      await t.retry('n');
      expect(t.handleFor('n').transcript!.source, TranscriptSource.model);
    });
  });

  group('words', () {
    const words = [
      TranscriptWord(text: 'one', start: Duration(milliseconds: 0), end: Duration(milliseconds: 300)),
      TranscriptWord(text: ' two', start: Duration(milliseconds: 500), end: Duration(milliseconds: 800)),
      TranscriptWord(text: ' three', start: Duration(milliseconds: 1200), end: Duration(milliseconds: 1500)),
    ];

    test('spoken index holds the last started word through gaps', () {
      expect(spokenWordIndex(words, Duration.zero), 0);
      expect(spokenWordIndex(words, const Duration(milliseconds: 400)), 0);
      expect(spokenWordIndex(words, const Duration(milliseconds: 1000)), 1);
      expect(spokenWordIndex(words, const Duration(seconds: 9)), 2);
      expect(spokenWordIndex(const [], Duration.zero), -1);
    });

    test('cleanWords drops non-speech, glues punctuation, trims the first space', () {
      Duration ms(int v) => Duration(milliseconds: v);
      final out = cleanWords([
        (text: ' Merhaba', start: ms(0), end: ms(300)),
        (text: ',', start: ms(300), end: ms(350)),
        (text: ' [MUSIC]', start: ms(400), end: ms(900)),
        (text: ' ', start: ms(900), end: ms(950)),
        (text: ' nasılsın', start: ms(1000), end: ms(1400)),
        (text: '?', start: ms(1400), end: ms(1450)),
      ]);
      expect(out.map((w) => w.text).join(), 'Merhaba, nasılsın?');
      expect(out, hasLength(2));
      expect(out[1].end, ms(1450));
    });

    test('a transcript survives JSON', () {
      const t = Transcript(text: 'one two three', language: 'en', words: words);
      final back = Transcript.fromJson(t.toJson())!;
      expect(back.text, t.text);
      expect(back.language, 'en');
      expect(back.words.map((w) => w.text), words.map((w) => w.text));
      expect(back.words[2].start, words[2].start);
    });
  });
}

class _FakeEngine implements SpeechEngine {
  final calls = <String>[];
  SpeechException? failNext;
  Completer<void>? gate;
  int running = 0, maxRunning = 0;

  @override
  bool get supported => true;

  @override
  Future<Transcript> transcribe({
    required String audioPath,
    required String modelPath,
    void Function(double fraction)? onProgress,
  }) async {
    running++;
    if (running > maxRunning) maxRunning = running;
    try {
      calls.add(audioPath);
      final g = gate;
      if (g != null) await g.future;
      final f = failNext;
      if (f != null) {
        failNext = null;
        throw f;
      }
      onProgress?.call(0.5);
      return const Transcript(text: 'merhaba dünya', language: 'tr');
    } finally {
      running--;
    }
  }

  @override
  Future<void> release() async {}

  @override
  Future<void> prewarm() async {}
}

class _FakeBuiltIn implements BuiltInSpeech {
  /// Installed locales by base language.
  Map<String, String> installed = {'tr': 'tr-TR', 'sv': 'sv-SE', 'en': 'en-US'};

  /// Confidence per locale; missing means 0.97.
  Map<String, double?> confidence = {};
  BuiltInSpeechException? fail;
  final asked = <List<String>>[];
  final transcribedIn = <String>[];

  @override
  Future<List<String>> readyLocales(List<String> preferred) async {
    asked.add(preferred);
    final out = <String>[];
    for (final p in preferred) {
      final l = installed[p.split(RegExp('[-_]')).first];
      if (l != null && !out.contains(l)) out.add(l);
    }
    return out;
  }

  @override
  Future<Transcript> transcribe(String audioPath, String locale,
      {void Function(double fraction)? onProgress}) async {
    final f = fail;
    if (f != null) {
      fail = null;
      throw f;
    }
    transcribedIn.add(locale);
    return Transcript(
      text: 'merhaba',
      language: locale.split('-').first,
      source: TranscriptSource.builtIn,
      confidence: confidence.containsKey(locale) ? confidence[locale] : 0.97,
    );
  }
}
