import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monkeyhub/composer/capture_compose.dart';
import 'package:monkeyhub/composer/capture_recorder.dart';
import 'package:record/record.dart';

/// Pause/resume segments and the compose step that joins them.
///
/// The native join cannot run on a VM host, but everything around it can, and
/// that is where the regressions would hide: the never-paused take must not
/// start paying for a native pass, every exit must leave the temp folder
/// clean, and a host with no native side must say "unavailable" while leaving
/// the segments for a retry. The channel is mocked; the files are real.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  const compose = MethodChannel('monkeyhub/media_compose');

  late Directory root;

  setUp(() async {
    root = await Directory.systemTemp.createTemp('mh_compose_test');
    CaptureTempFiles.resetForTest();
    messenger.setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      (call) async =>
          call.method == 'getTemporaryDirectory' ? root.path : null,
    );
  });

  tearDown(() async {
    messenger.setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      null,
    );
    messenger.setMockMethodCallHandler(compose, null);
    CaptureTempFiles.resetForTest();
    if (await root.exists()) await root.delete(recursive: true);
  });

  Future<CaptureSegment> segment(int ms, {List<int>? bytes}) async {
    final path = await CaptureTempFiles.newPath('m4a');
    await File(path).writeAsBytes(bytes ?? const [1, 2, 3]);
    return CaptureSegment(
      path: path,
      duration: Duration(milliseconds: ms),
      contentType: 'audio/mp4',
    );
  }

  group('waveform', () {
    CaptureSegment withLevels(List<double> levels) => CaptureSegment(
          path: '',
          duration: Duration.zero,
          contentType: 'audio/mp4',
          levels: levels,
        );

    test('downsamples to peaks, across segment boundaries', () {
      final w = waveform([
        withLevels([0.1, 0.9, 0.2]),
        withLevels([0.3, 0.4, 0.5]),
      ], 3);
      expect(w, [0.9, 0.3, 0.5]);
    });

    test('stretches when there are fewer samples than bars', () {
      expect(waveform([withLevels([0.2, 0.8])], 4), [0.2, 0.2, 0.8, 0.8]);
    });

    test('always answers the asked-for bar count', () {
      expect(waveform(const [], 5), List<double>.filled(5, 0));
      expect(waveform([withLevels(List.filled(37, 0.5))], 11), hasLength(11));
      expect(waveform([withLevels([0.5])], 0), isEmpty);
    });
  });

  group('filmstripTimes', () {
    test('spreads frames over the joined timeline by duration', () {
      final segs = [
        const CaptureSegment(
            path: 'a', duration: Duration(seconds: 1), contentType: 'v'),
        const CaptureSegment(
            path: 'b', duration: Duration(seconds: 3), contentType: 'v'),
      ];
      final t = filmstripTimes(segs, 4);
      // Slice centres at 0.5, 1.5, 2.5, 3.5 s of a 4 s timeline.
      expect([for (final x in t) x.segment], [0, 1, 1, 1]);
      expect([for (final x in t) x.at.inMilliseconds], [500, 500, 1500, 2500]);
    });

    test('is empty for nothing to show', () {
      expect(filmstripTimes(const [], 8), isEmpty);
    });

    test('fillGaps keeps the count, borrowing the nearest frame', () {
      expect(fillGaps<int>([null, 1, null, null, 2]), [1, 1, 1, 2, 2]);
      expect(fillGaps<int>([null, null]), isEmpty);
    });
  });

  group('planCompose', () {
    const one = [
      CaptureSegment(path: 'a', duration: Duration(seconds: 4), contentType: 'x'),
    ];

    test('a single untrimmed take needs no native pass', () {
      expect(planCompose(one).native, isFalse);
      // Handles dragged back to the edges are no trim at all.
      expect(
        planCompose(one,
                trimStart: Duration.zero,
                trimEnd: const Duration(milliseconds: 3980))
            .native,
        isFalse,
      );
    });

    test('a trim or a second segment does', () {
      final p = planCompose(one, trimStart: const Duration(seconds: 1));
      expect(p.native, isTrue);
      expect(p.startMs, 1000);
      expect(p.endMs, isNull);
      expect(planCompose([...one, ...one]).native, isTrue);
    });

    test('a trim that leaves nothing is "too short", silently', () {
      expect(
        () => planCompose(one,
            trimStart: const Duration(seconds: 3),
            trimEnd: const Duration(seconds: 2)),
        throwsA(isA<CaptureFailure>()
            .having((e) => e.kind, 'kind', CaptureFailureKind.tooShort)),
      );
      expect(() => planCompose(const []), throwsA(isA<CaptureFailure>()));
    });
  });

  group('composeCapture', () {
    test('fast path: reads the bytes, never calls native, deletes the file',
        () async {
      var calls = 0;
      messenger.setMockMethodCallHandler(compose, (call) async {
        calls++;
        return null;
      });
      final s = await segment(2500, bytes: [7, 7, 7]);
      final out = await composeCapture(segments: [s], video: false);
      expect(calls, 0);
      expect(out.bytes, [7, 7, 7]);
      expect(out.duration, const Duration(milliseconds: 2500));
      expect(out.contentType, 'audio/mp4');
      expect(File(s.path).existsSync(), isFalse);
    });

    test('joins through native, takes its duration, cleans everything up',
        () async {
      MethodCall? seen;
      messenger.setMockMethodCallHandler(compose, (call) async {
        seen = call;
        final args = call.arguments as Map;
        await File(args['outPath'] as String).writeAsBytes(const [4, 2]);
        return {'durationMs': 3210};
      });
      final a = await segment(1000);
      final b = await segment(2500);
      final out = await composeCapture(
        segments: [a, b],
        video: false,
        trimEnd: const Duration(milliseconds: 3000),
      );
      final args = seen!.arguments as Map;
      expect(seen!.method, 'compose');
      expect(args['paths'], [a.path, b.path]);
      expect(args['startMs'], isNull);
      expect(args['endMs'], 3000);
      expect(args['video'], isFalse);
      expect(out.bytes, [4, 2]);
      expect(out.duration, const Duration(milliseconds: 3210));
      // Segments and the intermediate are all gone.
      expect(Directory('${root.path}/mh_capture').listSync(), isEmpty);
    });

    test('no native side is "unavailable", and the segments survive it',
        () async {
      // No mock handler: what a desktop build looks like.
      final a = await segment(1000);
      final b = await segment(1000);
      await expectLater(
        composeCapture(segments: [a, b], video: false),
        throwsA(isA<CaptureFailure>()
            .having((e) => e.kind, 'kind', CaptureFailureKind.unavailable)),
      );
      expect(File(a.path).existsSync(), isTrue);
      expect(File(b.path).existsSync(), isTrue);
      // Only the segments: the intermediate did not outlive the failure.
      expect(Directory('${root.path}/mh_capture').listSync(), hasLength(2));

      await discardSegments([a, b]);
      expect(Directory('${root.path}/mh_capture').listSync(), isEmpty);
    });

    test('a native failure is "unknown" and leaves no intermediate', () async {
      messenger.setMockMethodCallHandler(compose, (call) async {
        throw PlatformException(code: 'compose_failed');
      });
      final a = await segment(1000);
      await expectLater(
        composeCapture(
            segments: [a],
            video: true,
            trimStart: const Duration(milliseconds: 300)),
        throwsA(isA<CaptureFailure>()
            .having((e) => e.kind, 'kind', CaptureFailureKind.unknown)),
      );
      expect(Directory('${root.path}/mh_capture').listSync(), hasLength(1));
    });
  });

  group('VoiceCaptureRecorder segments', () {
    test('stopSegment keeps the file, carries its levels, and resume starts '
        'a new file', () async {
      final port = _FakePort();
      final rec = VoiceCaptureRecorder(recorder: port);

      await rec.start();
      port.amp(-45); // 0.0
      port.amp(0); // 1.0
      await Future<void>.delayed(Duration.zero);
      final first = await rec.stopSegment();
      expect(File(first.path).existsSync(), isTrue,
          reason: 'the caller owns a segment file now');
      expect(first.levels, [0.0, 1.0]);
      expect(first.contentType, 'audio/mp4');

      await rec.start();
      port.amp(-22.5);
      await Future<void>.delayed(Duration.zero);
      final second = await rec.stopSegment();
      expect(second.path, isNot(first.path));
      expect(second.levels, [0.5],
          reason: 'levels are per segment, not cumulative');

      final out =
          await composeCapture(segments: [first], video: false);
      expect(out.bytes, isNotEmpty);
      await discardSegments([second]);
      await rec.dispose();
      expect(Directory('${root.path}/mh_capture').listSync(), isEmpty);
    });

    test('our own stopSegment is not reported as an interruption', () async {
      final port = _FakePort();
      final rec = VoiceCaptureRecorder(recorder: port);
      var lost = 0;
      rec.onSessionLost = () => lost++;
      await rec.start();
      final s = await rec.stopSegment();
      port.state.add(RecordState.stop);
      await Future<void>.delayed(Duration.zero);
      expect(lost, 0);
      await discardSegments([s]);
      await rec.dispose();
    });

    test('stopSegment with nothing recording is an interruption', () async {
      final rec = VoiceCaptureRecorder(recorder: _FakePort());
      await expectLater(
        rec.stopSegment(),
        throwsA(isA<CaptureFailure>()
            .having((e) => e.kind, 'kind', CaptureFailureKind.interrupted)),
      );
      await rec.dispose();
    });

    test('an empty segment is a storage failure and is deleted', () async {
      final port = _FakePort(payload: const []);
      final rec = VoiceCaptureRecorder(recorder: port);
      await rec.start();
      final path = port.path!;
      await expectLater(
        rec.stopSegment(),
        throwsA(isA<CaptureFailure>()
            .having((e) => e.kind, 'kind', CaptureFailureKind.storage)),
      );
      expect(File(path).existsSync(), isFalse);
      await rec.dispose();
    });
  });
}

/// Writes a real file per start, and lets the test drive the meter.
class _FakePort implements AudioRecorderPort {
  _FakePort({this.payload = const [1, 2, 3]});

  final List<int> payload;
  String? path;
  final state = StreamController<RecordState>.broadcast();
  StreamController<Amplitude>? _amp;

  void amp(double dbfs) => _amp?.add(Amplitude(current: dbfs, max: 0));

  @override
  Future<bool> hasPermission() async => true;

  @override
  Future<void> start(RecordConfig config, {required String path}) async {
    this.path = path;
    await File(path).writeAsBytes(payload);
  }

  @override
  Future<String?> stop() async => path;

  @override
  Future<void> cancel() async {}

  @override
  Future<void> dispose() async {
    await state.close();
    await _amp?.close();
  }

  @override
  Stream<Amplitude> onAmplitudeChanged(Duration interval) {
    // A fresh stream per start, as the plugin gives: the recorder cancels its
    // subscription at every segment boundary.
    _amp = StreamController<Amplitude>();
    return _amp!.stream;
  }

  @override
  Stream<RecordState> onStateChanged() => state.stream;
}
