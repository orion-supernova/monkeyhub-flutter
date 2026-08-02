import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:monkeyhub/media/preview_luminance.dart';

/// The camera's light meter.
///
/// A selfie camera has no flash unit, so "auto" cannot be handed to the
/// platform the way it is on the back lens — the app fires the screen instead,
/// and has to decide for itself whether the room is dark. Nothing in
/// `CameraController` reads the scene and neither OS hands Flutter a lux value,
/// so this reads the preview frames.
///
/// Pure-function tests because the failure is quiet: a meter that is wrong by a
/// constant factor still returns a plausible number, and the only symptom is a
/// flash that fires in daylight or stays off in the dark.
void main() {
  /// A [width]×[height] frame where every pixel holds [value].
  ///
  /// [pad] is extra bytes on the end of each row. Capture buffers are commonly
  /// padded to an alignment boundary, and the padding is not picture — reading
  /// straight through the buffer would average it in.
  Uint8List frame({
    required int width,
    required int height,
    required int bytesPerPixel,
    required int value,
    int pad = 0,
  }) {
    final rowBytes = width * bytesPerPixel + pad;
    final bytes = Uint8List(rowBytes * height);
    for (var y = 0; y < height; y++) {
      for (var x = 0; x < width * bytesPerPixel; x++) {
        bytes[y * rowBytes + x] = value;
      }
    }
    return bytes;
  }

  group('luma plane (yuv420 plane 0)', () {
    test('a black frame meters 0 and a white one meters 1', () {
      expect(
        meanPreviewLuminance(
          bytes: frame(width: 64, height: 48, bytesPerPixel: 1, value: 0),
          width: 64,
          height: 48,
          bytesPerRow: 64,
          bytesPerPixel: 1,
        ),
        0,
      );
      expect(
        meanPreviewLuminance(
          bytes: frame(width: 64, height: 48, bytesPerPixel: 1, value: 255),
          width: 64,
          height: 48,
          bytesPerRow: 64,
          bytesPerPixel: 1,
        ),
        1,
      );
    });

    test('mid grey lands mid scale', () {
      final v = meanPreviewLuminance(
        bytes: frame(width: 64, height: 48, bytesPerPixel: 1, value: 128),
        width: 64,
        height: 48,
        bytesPerRow: 64,
        bytesPerPixel: 1,
      );
      expect(v, closeTo(0.502, 0.01));
    });

    test('row padding is not mistaken for picture', () {
      // The failure this guards: a padded buffer read straight through averages
      // in rows of zeros and reports a lit room as dark, so the flash fires in
      // daylight. Same white frame, 12 bytes of padding per row.
      final v = meanPreviewLuminance(
        bytes: frame(
          width: 64,
          height: 48,
          bytesPerPixel: 1,
          value: 255,
          pad: 12,
        ),
        width: 64,
        height: 48,
        bytesPerRow: 64 + 12,
        bytesPerPixel: 1,
      );
      expect(v, 1);
    });
  });

  group('packed BGRA (what iOS delivers)', () {
    test('the alpha byte is skipped, not averaged in', () {
      // Every colour byte 0, alpha 255. Read flat, that is a quarter-bright
      // frame; read as luminance it is black.
      final bytes = Uint8List(64 * 48 * 4);
      for (var i = 3; i < bytes.length; i += 4) {
        bytes[i] = 255;
      }
      expect(
        meanPreviewLuminance(
          bytes: bytes,
          width: 64,
          height: 48,
          bytesPerRow: 64 * 4,
          bytesPerPixel: 4,
        ),
        0,
      );
    });

    test('channels are weighted, so blue does not read as bright as green', () {
      Uint8List solid(int b, int g, int r) {
        final bytes = Uint8List(64 * 48 * 4);
        for (var i = 0; i < bytes.length; i += 4) {
          bytes[i] = b;
          bytes[i + 1] = g;
          bytes[i + 2] = r;
          bytes[i + 3] = 255;
        }
        return bytes;
      }

      double meter(Uint8List bytes) => meanPreviewLuminance(
        bytes: bytes,
        width: 64,
        height: 48,
        bytesPerRow: 64 * 4,
        bytesPerPixel: 4,
      );

      final blue = meter(solid(255, 0, 0));
      final green = meter(solid(0, 255, 0));
      final red = meter(solid(0, 0, 255));

      expect(blue, closeTo(0.114, 0.005));
      expect(green, closeTo(0.587, 0.005));
      expect(red, closeTo(0.299, 0.005));
      expect(green, greaterThan(red));
      expect(red, greaterThan(blue));
    });
  });

  group('malformed frames read as dark', () {
    // Dark is the safe way to be wrong: the cost is a flash nobody needed,
    // against a photograph nobody can see.
    test('empty, zero-sized, or incoherent input', () {
      expect(
        meanPreviewLuminance(
          bytes: Uint8List(0),
          width: 4,
          height: 4,
          bytesPerRow: 4,
          bytesPerPixel: 1,
        ),
        0,
      );
      expect(
        meanPreviewLuminance(
          bytes: Uint8List(16),
          width: 0,
          height: 4,
          bytesPerRow: 4,
          bytesPerPixel: 1,
        ),
        0,
      );
      // A stride narrower than one row of pixels cannot be right.
      expect(
        meanPreviewLuminance(
          bytes: Uint8List(64),
          width: 16,
          height: 4,
          bytesPerRow: 8,
          bytesPerPixel: 1,
        ),
        0,
      );
      // Neither a luma plane nor packed BGRA.
      expect(
        meanPreviewLuminance(
          bytes: Uint8List(64),
          width: 16,
          height: 4,
          bytesPerRow: 48,
          bytesPerPixel: 3,
        ),
        0,
      );
    });

    test('a buffer shorter than it claims stops rather than throwing', () {
      expect(
        () => meanPreviewLuminance(
          bytes: Uint8List(10),
          width: 64,
          height: 48,
          bytesPerRow: 64,
          bytesPerPixel: 1,
        ),
        returnsNormally,
      );
    });
  });

  test('the hysteresis band is a band, and both ends are plausible light', () {
    // Without a gap, a reading sitting on the threshold strobes the flash icon.
    expect(darkEnterLuminance, lessThan(darkExitLuminance));
    expect(darkEnterLuminance, greaterThan(0));
    expect(darkExitLuminance, lessThan(1));
  });
}
