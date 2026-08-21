import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:monkeyhub/media/image_raster.dart';

/// A photographic-ish JPEG of the given size.
///
/// A flat fill would compress to almost nothing and prove nothing about the
/// quality setting, so this is a gradient under several thousand hard-edged
/// dots — high-frequency detail that JPEG has to actually work at.
Future<Uint8List> _photo(int w, int h) async {
  final recorder = ui.PictureRecorder();
  final rect = Rect.fromLTWH(0, 0, w.toDouble(), h.toDouble());
  final canvas = Canvas(recorder, rect);
  canvas.drawRect(
    rect,
    Paint()
      ..shader = ui.Gradient.linear(
        Offset.zero,
        Offset(w.toDouble(), h.toDouble()),
        const [Color(0xFF2E5C8A), Color(0xFFD98A3F), Color(0xFF1A1A1A)],
        const [0.0, 0.55, 1.0],
      ),
  );
  const salt = [13, 71, 199, 37, 251, 89, 157, 3];
  for (var i = 0; i < 1200; i++) {
    canvas.drawCircle(
      Offset(
        ((salt[i % 8] * (i + 7) * 31) % w).toDouble(),
        ((salt[(i + 3) % 8] * (i + 11) * 17) % h).toDouble(),
      ),
      2 + (i % 9).toDouble(),
      Paint()..color = Color(0xFF000000 | (i * 2654435761) & 0xFFFFFF),
    );
  }
  final picture = recorder.endRecording();
  final raster = await picture.toImage(w, h);
  picture.dispose();
  return (await rasterToJpegBytes(raster, quality: 90)).bytes;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('compressForSend', () {
    test('caps the longest edge and re-encodes as JPEG', () async {
      final source = await _photo(2400, 1800);
      final out = await compressForSend(source);

      expect(out.width, kSendPhotoMaxEdge);
      expect(out.height, 960, reason: 'aspect ratio preserved');
      expect(out.contentType, 'image/jpeg');
      // The whole point: substantially smaller than what it replaced.
      expect(out.bytes.length, lessThan(source.length ~/ 2));
      // And still a real, decodable image — not merely fewer bytes.
      expect(img.decodeJpg(out.bytes)?.width, kSendPhotoMaxEdge);
    });

    test('caps the LONGEST edge, so a tall photo stays tall', () async {
      final out = await compressForSend(await _photo(1500, 3000));
      expect(out.height, kSendPhotoMaxEdge);
      expect(out.width, 640);
    });

    test('never upscales a source already inside the cap', () async {
      final out = await compressForSend(await _photo(400, 300));
      expect(out.width, 400);
      expect(out.height, 300);
    });

    test('honours an explicit HD-sized cap and quality', () async {
      final source = await _photo(2400, 1800);
      final hd = await compressForSend(
        source,
        maxEdge: 4096,
        quality: kSendPhotoHdQuality,
      );
      expect(hd.width, 2400, reason: 'cap above the source is a no-op');
      final standard = await compressForSend(source);
      expect(hd.bytes.length, greaterThan(standard.bytes.length));
    });
  });
}
