// MONKEYHUB: covers the Dart half of the vendored patches (PATCHES.md).
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:whisper_ggml/src/whisper_decode.dart';
import 'package:whisper_ggml/whisper_ggml.dart';

Uint8List _wavHeader({int channels = 1, int rate = 16000, int bits = 16, bool listChunk = false}) {
  final BytesBuilder b = BytesBuilder();
  void u32(int v) => b.add((ByteData(4)..setUint32(0, v, Endian.little)).buffer.asUint8List());
  void u16(int v) => b.add((ByteData(2)..setUint16(0, v, Endian.little)).buffer.asUint8List());
  b.add('RIFF'.codeUnits);
  u32(0);
  b.add('WAVE'.codeUnits);
  if (listChunk) {
    b.add('LIST'.codeUnits);
    u32(3); // odd size: padded to 4
    b.add(<int>[1, 2, 3, 0]);
  }
  b.add('fmt '.codeUnits);
  u32(16);
  u16(1);
  u16(channels);
  u32(rate);
  u32(rate * channels * bits ~/ 8);
  u16(channels * bits ~/ 8);
  u16(bits);
  b.add('data'.codeUnits);
  u32(0);
  return b.toBytes();
}

void main() {
  test('PATCH 3: transcribe response carries the detected language', () {
    final WhisperTranscribeResponse r = WhisperTranscribeResponse.fromJson(<String, dynamic>{
      '@type': 'transcribe',
      'text': ' Merhaba',
      'language': 'tr',
      'segments': <dynamic>[
        <String, dynamic>{'from_ts': 1, 'to_ts': 58, 'text': ' Merhaba'},
      ],
    });
    expect(r.language, 'tr');
    expect(r.segments!.single.fromTs, const Duration(milliseconds: 10));
    expect(r.copyWith(language: 'en').language, 'en');
    expect(r, r.copyWith());
    expect(r == r.copyWith(language: 'en'), isFalse);
    expect(r.toJson()['language'], 'tr');

    final WhisperTranscribeResponse old = WhisperTranscribeResponse.fromJson(
      <String, dynamic>{'@type': 'transcribe', 'text': 'x'},
    );
    expect(old.language, isNull);
  });

  test('PATCH 10: backend and gpu_fallback are parsed', () {
    final WhisperTranscribeResponse r = WhisperTranscribeResponse.fromJson(<String, dynamic>{
      '@type': 'transcribe',
      'text': 'x',
      'backend': 'cpu',
      'gpu_fallback': true,
    });
    expect(r.backend, 'cpu');
    expect(r.gpuFallback, isTrue);
    expect(r.copyWith(backend: 'metal').backend, 'metal');
    expect(r.toJson()['gpu_fallback'], isTrue);
    final WhisperTranscribeResponse old =
        WhisperTranscribeResponse.fromJson(<String, dynamic>{'@type': 'transcribe', 'text': 'x'});
    expect(old.backend, isNull);
    expect(old.gpuFallback, isFalse);
  });

  test('PATCH 4: transcribe takes exactly one of model and modelPath', () async {
    final WhisperController c = WhisperController();
    await expectLater(c.transcribe(audioPath: 'a.m4a'), throwsArgumentError);
    await expectLater(
      c.transcribe(model: WhisperModel.tiny, modelPath: '/m.bin', audioPath: 'a.m4a'),
      throwsArgumentError,
    );
  });

  test('PATCH 5: threads default to 0 (native auto)', () {
    expect(const TranscribeRequest(audio: 'a.wav').threads, 0);
  });

  group('PATCH 2: readWavInfo', () {
    late Directory dir;
    setUp(() => dir = Directory.systemTemp.createTempSync('wg_'));
    tearDown(() => dir.deleteSync(recursive: true));

    test('reads fmt, skipping padded chunks', () async {
      final File f = File('${dir.path}/a.wav')..writeAsBytesSync(_wavHeader(channels: 2, rate: 44100, listChunk: true));
      final WavInfo? info = await readWavInfo(f.path);
      expect(info, isNotNull);
      expect(info!.channels, 2);
      expect(info.sampleRate, 44100);
      expect(info.isPcm16, isTrue);
    });

    test('non-WAV and missing files are null', () async {
      final File f = File('${dir.path}/a.m4a')..writeAsBytesSync(<int>[0, 0, 0, 0x18, 0x66, 0x74, 0x79, 0x70, 0, 0, 0, 0]);
      expect(await readWavInfo(f.path), isNull);
      expect(await readWavInfo('${dir.path}/missing.wav'), isNull);
    });

    test('16 kHz mono WAV is copied without touching native code', () async {
      final File f = File('${dir.path}/a.wav')..writeAsBytesSync(_wavHeader());
      await decodeToWav16k(f.path, '${dir.path}/b.wav');
      expect(File('${dir.path}/b.wav').readAsBytesSync(), f.readAsBytesSync());
    });

    test('same input and output path is rejected', () async {
      await expectLater(
        decodeToWav16k('/x.m4a', '/x.m4a'),
        throwsA(isA<WhisperDecodeException>().having((e) => e.code, 'code', WhisperDecodeException.invalidArguments)),
      );
    });
  });
}
