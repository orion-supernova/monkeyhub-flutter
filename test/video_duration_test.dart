import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:monkeyhub/media/video_duration.dart';

Uint8List _box(String type, List<int> body) {
  final b = BytesBuilder();
  final size = ByteData(4)..setUint32(0, body.length + 8);
  b
    ..add(size.buffer.asUint8List())
    ..add(type.codeUnits)
    ..add(body);
  return b.toBytes();
}

/// An `mvhd` box: version 0 with 32-bit fields, or version 1 with 64-bit.
Uint8List _mvhd({required int timescale, required int duration, int v = 0}) {
  final d = ByteData(v == 1 ? 32 : 20);
  d.setUint8(0, v);
  if (v == 1) {
    // flags(3) creation(8) modification(8) timescale(4) duration(8)
    d.setUint32(20, timescale);
    d.setUint64(24, duration);
  } else {
    // flags(3) creation(4) modification(4) timescale(4) duration(4)
    d.setUint32(12, timescale);
    d.setUint32(16, duration);
  }
  return _box('mvhd', d.buffer.asUint8List());
}

Uint8List _file(List<Uint8List> boxes) {
  final b = BytesBuilder();
  for (final x in boxes) {
    b.add(x);
  }
  return b.toBytes();
}

void main() {
  final ftyp = _box('ftyp', 'isom0000'.codeUnits);
  final mdat = _box('mdat', List.filled(5000, 1));

  test('reads the length when moov comes first (streaming layout)', () async {
    final f = _file([
      ftyp,
      _box('moov', _mvhd(timescale: 600, duration: 6000)),
      mdat,
    ]);
    expect(await VideoDuration.debugWalk(f), 10000);
  });

  test('reads the length when moov comes after the media (camera layout)',
      () async {
    final f = _file([
      ftyp,
      mdat,
      _box('moov', _mvhd(timescale: 1000, duration: 42500)),
    ]);
    expect(await VideoDuration.debugWalk(f), 42500);
  });

  test('reads a version 1 mvhd', () async {
    final f = _file([
      ftyp,
      _box('moov', _mvhd(timescale: 90000, duration: 90000 * 75, v: 1)),
    ]);
    expect(await VideoDuration.debugWalk(f), 75000);
  });

  test('answers null for something that is not an MP4', () async {
    expect(await VideoDuration.debugWalk(Uint8List.fromList([1, 2, 3, 4])),
        isNull);
  });
}
