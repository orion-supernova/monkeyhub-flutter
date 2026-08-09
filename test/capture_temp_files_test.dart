import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monkeyhub/composer/capture_permissions.dart';
import 'package:monkeyhub/composer/capture_recorder.dart';
import 'package:record/record.dart';

/// Temp-file discipline for composer recordings.
///
/// The microphone and the camera cannot be exercised here at all, but the thing
/// most likely to go wrong about them can: a recording writes a file, and every
/// way out of a recording has to delete it. There are four ways out — sent,
/// cancelled, failed, and the process dying — and only the first three can be
/// coded around. The fourth is what [CaptureTempFiles.sweep] is for, and a
/// sweeper nobody tests is a sweeper that quietly stops sweeping.
///
/// `path_provider` has no VM implementation, so its channel is mocked onto a
/// real directory. Everything below then exercises real files on real disk,
/// which is the only version of this test worth having: a fake filesystem would
/// pass just as happily against code that never deleted anything.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory root;

  setUp(() async {
    root = await Directory.systemTemp.createTemp('mh_capture_test');
    CaptureTempFiles.resetForTest();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      (call) async =>
          call.method == 'getTemporaryDirectory' ? root.path : null,
    );
  });

  tearDown(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      null,
    );
    CaptureTempFiles.resetForTest();
    if (await root.exists()) await root.delete(recursive: true);
  });

  group('CaptureTempFiles', () {
    test('hands out unique paths inside its own folder', () async {
      final a = await CaptureTempFiles.newPath('m4a');
      final b = await CaptureTempFiles.newPath('m4a');
      expect(a, isNot(b));
      expect(a, contains('mh_capture'));
      expect(a, endsWith('.m4a'));
      // The folder is created eagerly, so the recorder never has to.
      expect(Directory('${root.path}/mh_capture').existsSync(), isTrue);
    });

    test('delete removes the file and tolerates a path that is already gone',
        () async {
      final path = await CaptureTempFiles.newPath('m4a');
      await File(path).writeAsBytes(const [1, 2, 3]);
      expect(File(path).existsSync(), isTrue);

      await CaptureTempFiles.delete(path);
      expect(File(path).existsSync(), isFalse);

      // Twice, and with a null, because cleanup runs on failure paths where the
      // file may never have been created — a cleanup that can itself throw is
      // worse than a leaked file.
      await CaptureTempFiles.delete(path);
      await CaptureTempFiles.delete(null);
    });

    test('sweep removes orphans from a previous run and spares fresh files',
        () async {
      final stale = await CaptureTempFiles.newPath('mp4');
      final fresh = await CaptureTempFiles.newPath('mp4');
      await File(stale).writeAsBytes(const [1]);
      await File(fresh).writeAsBytes(const [1]);
      // Backdated well past the one-hour staleness window, which is how a file
      // left behind by a crash looks on the next launch.
      await File(stale)
          .setLastModified(DateTime.now().subtract(const Duration(days: 2)));

      CaptureTempFiles.resetForTest();
      await CaptureTempFiles.sweep();

      expect(File(stale).existsSync(), isFalse,
          reason: 'an orphan from a previous run must be reclaimed');
      expect(File(fresh).existsSync(), isTrue,
          reason: 'a sweep must never race a live recording');
    });

    test('sweep runs once per process', () async {
      await CaptureTempFiles.sweep();
      final stale = await CaptureTempFiles.newPath('mp4');
      await File(stale).writeAsBytes(const [1]);
      await File(stale)
          .setLastModified(DateTime.now().subtract(const Duration(days: 2)));

      // No reset: the second call is a no-op, which is what keeps a `newPath`
      // on a hot send path from re-walking the directory every time.
      await CaptureTempFiles.sweep();
      expect(File(stale).existsSync(), isTrue);
    });
  });

  group('VoiceCaptureRecorder', () {
    test('cancel deletes the file it was writing', () async {
      final port = _FakeRecorderPort();
      final rec = VoiceCaptureRecorder(recorder: port);
      await rec.start();
      final path = port.startedPath!;
      expect(File(path).existsSync(), isTrue);

      await rec.cancel();
      expect(File(path).existsSync(), isFalse);
      expect(port.cancelled, isTrue);
      await rec.dispose();
    });

    test('stop hands back the bytes and still deletes the file', () async {
      final port = _FakeRecorderPort(payload: Uint8List.fromList([9, 8, 7]));
      final rec = VoiceCaptureRecorder(recorder: port);
      await rec.start();
      final path = port.startedPath!;

      final outcome = await rec.stop();
      expect(outcome.bytes, [9, 8, 7]);
      expect(outcome.contentType, 'audio/mp4');
      expect(File(path).existsSync(), isFalse,
          reason: 'nothing downstream ever sees the path, so nothing else can '
              'delete it');
      await rec.dispose();
    });

    test('a zero-byte recording is a storage failure, not an empty message',
        () async {
      final port = _FakeRecorderPort(payload: Uint8List(0));
      final rec = VoiceCaptureRecorder(recorder: port);
      await rec.start();
      final path = port.startedPath!;

      await expectLater(
        rec.stop(),
        throwsA(isA<CaptureFailure>().having(
            (e) => e.kind, 'kind', CaptureFailureKind.storage)),
      );
      expect(File(path).existsSync(), isFalse);
      await rec.dispose();
    });

    test('a missing plugin is "unavailable", never "you denied the mic"',
        () async {
      // The distinction is the whole point: "denied" offers a Settings button,
      // and sending a user to Settings to fix a plugin that is not installed is
      // a dead end with a button on it.
      final port = _FakeRecorderPort(permissionThrows: true);
      final rec = VoiceCaptureRecorder(recorder: port);
      await expectLater(
        rec.start(),
        throwsA(isA<CaptureFailure>().having(
            (e) => e.kind, 'kind', CaptureFailureKind.unavailable)),
      );
      await rec.dispose();
    });

    test('a refused microphone reports the device it was refused for',
        () async {
      final port = _FakeRecorderPort(permitted: false);
      final rec = VoiceCaptureRecorder(recorder: port);
      await expectLater(
        rec.start(),
        throwsA(isA<CaptureFailure>()
            .having((e) => e.kind, 'kind', CaptureFailureKind.permission)
            .having((e) => e.device, 'device', CaptureDevice.microphone)),
      );
      await rec.dispose();
    });

    test('an unasked-for stop is reported as an interruption', () async {
      final port = _FakeRecorderPort();
      final rec = VoiceCaptureRecorder(recorder: port);
      var lost = 0;
      rec.onSessionLost = () => lost++;
      await rec.start();

      // What an incoming call looks like from here: the platform stops the
      // recorder and tells us through the state stream.
      port.emitState(RecordState.stop);
      await Future<void>.delayed(Duration.zero);
      expect(lost, 1);

      // Our own stop must NOT look like one, or every successful recording
      // would report itself as interrupted.
      await rec.stop();
      port.emitState(RecordState.stop);
      await Future<void>.delayed(Duration.zero);
      expect(lost, 1);
      await rec.dispose();
    });
  });
}

/// A recorder that writes a real file and nothing else.
class _FakeRecorderPort implements AudioRecorderPort {
  _FakeRecorderPort({
    this.permitted = true,
    this.permissionThrows = false,
    Uint8List? payload,
  }) : payload = payload ?? Uint8List.fromList([1, 2, 3, 4]);

  final bool permitted;
  final bool permissionThrows;
  final Uint8List payload;

  String? startedPath;
  bool cancelled = false;
  final _state = StreamController<RecordState>.broadcast();

  void emitState(RecordState s) => _state.add(s);

  @override
  Future<bool> hasPermission() async {
    if (permissionThrows) {
      throw MissingPluginException('no record implementation');
    }
    return permitted;
  }

  @override
  Future<void> start(RecordConfig config, {required String path}) async {
    startedPath = path;
    await File(path).writeAsBytes(payload);
  }

  @override
  Future<String?> stop() async => startedPath;

  @override
  Future<void> cancel() async => cancelled = true;

  @override
  Future<void> dispose() async => _state.close();

  @override
  Stream<Amplitude> onAmplitudeChanged(Duration interval) =>
      const Stream<Amplitude>.empty();

  @override
  Stream<RecordState> onStateChanged() => _state.stream;
}
