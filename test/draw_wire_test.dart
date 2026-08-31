import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:monkeyhub/calls/draw/draw_wire.dart';

/// The stroke wire format: what goes in comes out, and what is broken
/// stops the decoder rather than throwing it.
void main() {
  Float32List pts(List<double> xy) => Float32List.fromList(xy);

  test('a mixed batch round-trips', () {
    final ops = <DrawOp>[
      StrokeBegin(
          strokeId: 7, argb: 0xFF3366CC, width: 0.01, points: pts([0.1, 0.2])),
      StrokeAppend(strokeId: 7, points: pts([0.3, 0.4, 0.5, 0.6])),
      const StrokeEnd(strokeId: 7),
      const DrawClear(),
      StrokeBegin(strokeId: 8, argb: 0x80FFFFFF, width: 0.5, points: pts([])),
    ];
    final out = decodeDrawBatch(encodeDrawBatch(ops));
    expect(out.length, ops.length);
    final b = out[0] as StrokeBegin;
    expect(b.strokeId, 7);
    expect(b.argb, 0xFF3366CC);
    expect(b.width, closeTo(0.01, 1e-6));
    expect(b.points, [closeTo(0.1, 1e-6), closeTo(0.2, 1e-6)]);
    final a = out[1] as StrokeAppend;
    expect(a.strokeId, 7);
    expect(a.points.length, 4);
    expect(a.points[3], closeTo(0.6, 1e-6));
    expect((out[2] as StrokeEnd).strokeId, 7);
    expect(out[3], isA<DrawClear>());
    final b2 = out[4] as StrokeBegin;
    expect(b2.argb, 0x80FFFFFF);
    expect(b2.points, isEmpty);
  });

  test('truncated bytes decode to the parsed prefix, never throw', () {
    final ops = <DrawOp>[
      const StrokeEnd(strokeId: 1),
      StrokeAppend(strokeId: 1, points: pts([0.1, 0.1, 0.2, 0.2])),
      const StrokeEnd(strokeId: 2),
    ];
    final bytes = encodeDrawBatch(ops);
    // Cut inside the append's points.
    final cut = Uint8List.sublistView(bytes, 0, 2 + 5 + 1 + 4 + 2 + 5);
    final out = decodeDrawBatch(cut);
    expect(out.length, 1);
    expect(out.first, isA<StrokeEnd>());
    // Garbage is an empty batch.
    expect(decodeDrawBatch(Uint8List.fromList([9, 9, 9])), isEmpty);
    expect(decodeDrawBatch(Uint8List(0)), isEmpty);
    // An unknown op stops the frame after the good ops.
    final withUnknown = Uint8List.fromList([1, 2, 0x03, 5, 0, 0, 0, 0x7F]);
    final partial = decodeDrawBatch(withUnknown);
    expect(partial.length, 1);
    expect((partial.first as StrokeEnd).strokeId, 5);
  });

  test('an append longer than a u16 is split across ops', () {
    final n = kDrawMaxPointsPerOp + 10;
    final big = Float32List(n * 2);
    for (var i = 0; i < n; i++) {
      big[2 * i] = i / n;
      big[2 * i + 1] = 1 - i / n;
    }
    final out = decodeDrawBatch(
        encodeDrawBatch([StrokeAppend(strokeId: 3, points: big)]));
    expect(out.length, 2);
    final first = out[0] as StrokeAppend;
    final second = out[1] as StrokeAppend;
    expect(first.points.length ~/ 2, kDrawMaxPointsPerOp);
    expect(second.points.length ~/ 2, 10);
    expect(second.points[0], closeTo(kDrawMaxPointsPerOp / n, 1e-6));

    // A begin splits into a begin plus appends, keeping its header.
    final out2 = decodeDrawBatch(encodeDrawBatch([
      StrokeBegin(strokeId: 4, argb: 0xFF000000, width: 0.02, points: big),
    ]));
    expect(out2.length, 2);
    expect(out2[0], isA<StrokeBegin>());
    expect((out2[0] as StrokeBegin).points.length ~/ 2, kDrawMaxPointsPerOp);
    expect(out2[1], isA<StrokeAppend>());
  });

  test('more ops than a frame holds become several frames', () {
    final ops = [for (var i = 0; i < 300; i++) StrokeEnd(strokeId: i)];
    final out = decodeDrawBatch(encodeDrawBatch(ops));
    expect(out.length, 300);
    expect((out.last as StrokeEnd).strokeId, 299);
  });
}
