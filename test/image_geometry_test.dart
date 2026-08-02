import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monkeyhub/media/media_aspect_cache.dart';
import 'package:monkeyhub/theme/layout.dart';
import 'package:monkeyhub/widgets/remote_image.dart';

/// Pins the three pieces of arithmetic behind "a picture is shown at the shape
/// it actually is".
///
/// All of it used to be wrong in the same direction: a photo was decoded into a
/// square, painted in a square, and then shown at its real ratio the moment you
/// opened it — so a thumbnail was a distorted crop and every open and close
/// changed the picture's shape twice.
void main() {
  group('decodeSizeFor', () {
    // The bug, stated as a test: `ResizeImage`'s default policy resizes to
    // *exactly* the width and height it is given, so asking for both is asking
    // for a squashed bitmap. There is no box shape for which that is correct.
    test('never constrains both axes at once', () {
      for (final box in const [Size(92, 92), Size(240, 360), Size(360, 240)]) {
        final decode = decodeSizeFor(
          width: box.width,
          height: box.height,
          dpr: 3,
          screen: const Size(393, 852),
        );
        expect(
          decode.width == null || decode.height == null,
          isTrue,
          reason: 'both axes constrained for $box — the decode would distort',
        );
      }
    });

    test('a square box decodes on width, in device pixels', () {
      final decode = decodeSizeFor(
        width: 92,
        height: 92,
        dpr: 3,
        screen: const Size(393, 852),
      );
      // Width, not height: it has to agree with `thumbnailDecodeWidth`, or the
      // viewer's warm backdrop is a different ImageCache entry and always
      // misses.
      expect(decode.width, 276);
      expect(decode.height, isNull);
    });

    test('a height-only box decodes on height', () {
      final decode = decodeSizeFor(
        width: null,
        height: 50,
        dpr: 2,
        screen: const Size(393, 852),
      );
      expect(decode.width, isNull);
      expect(decode.height, 100);
    });

    test('an unsized box caps at the screen\'s longest edge', () {
      final decode = decodeSizeFor(
        width: null,
        height: null,
        dpr: 3,
        screen: const Size(393, 852),
      );
      expect(decode.width, (852 * 3).round());
      expect(decode.height, isNull);
    });

    test('rounds up to at least one pixel', () {
      final decode = decodeSizeFor(
        width: 0.1,
        height: null,
        dpr: 1,
        screen: const Size(393, 852),
      );
      expect(decode.width, 1);
    });
  });

  group('mediaTileHeight', () {
    const w = 240.0;

    test('an unknown ratio stands on a square', () {
      expect(ChatMetrics.mediaTileHeight(w, null), w);
    });

    test('an ordinary photo keeps its own ratio exactly', () {
      // 3:4 portrait and 4:3 landscape both sit inside the clamp, so nothing is
      // cropped and the tile *is* the photograph.
      expect(ChatMetrics.mediaTileHeight(w, 3 / 4), closeTo(320, 0.001));
      expect(ChatMetrics.mediaTileHeight(w, 4 / 3), closeTo(180, 0.001));
    });

    test('a phone screenshot stops at the tall clamp', () {
      // 9:16 would be 427 tall — a column that pushes the conversation around
      // it off screen. Capped, and the overshoot is what `cover` crops.
      expect(
        ChatMetrics.mediaTileHeight(w, 9 / 16),
        w * ChatMetrics.mediaMaxHeightFactor,
      );
    });

    test('a panorama stops at the short clamp', () {
      expect(
        ChatMetrics.mediaTileHeight(w, 4.0),
        w * ChatMetrics.mediaMinHeightFactor,
      );
    });

    test(
      'a nonsense ratio falls back to the square rather than collapsing',
      () {
        for (final bad in [0.0, -2.0, double.nan, double.infinity]) {
          expect(ChatMetrics.mediaTileHeight(w, bad), w, reason: 'aspect $bad');
        }
      },
    );
  });

  group('MediaAspectCache', () {
    setUp(() {
      MediaAspectCache.instance.debugPersist = false;
    });

    tearDown(() async {
      await MediaAspectCache.instance.clear();
    });

    test('a remembered ratio reads back synchronously', () {
      // Synchronous is the whole point: it is read during layout, so an answer
      // one frame later is an answer that arrives after the reflow it exists to
      // prevent.
      MediaAspectCache.instance.remember('img1', 0.75);
      expect(MediaAspectCache.instance.peek('img1'), 0.75);
      expect(MediaAspectCache.instance.peek('never-seen'), isNull);
    });

    test('refuses a ratio that would poison later launches', () {
      for (final bad in [0.0, -1.0, double.nan, 1000.0, 0.0001]) {
        MediaAspectCache.instance.remember('bad', bad);
        expect(MediaAspectCache.instance.peek('bad'), isNull, reason: '$bad');
      }
    });

    test('resolve measures once and serves the rest from memory', () async {
      var measurements = 0;
      Future<double?> measure() async {
        measurements++;
        return 1.5;
      }

      expect(await MediaAspectCache.instance.resolve('img2', measure), 1.5);
      expect(await MediaAspectCache.instance.resolve('img2', measure), 1.5);
      expect(measurements, 1);
    });

    test('concurrent resolves of one id share a single measurement', () async {
      var measurements = 0;
      final gate = Completer<double?>();
      Future<double?> measure() {
        measurements++;
        return gate.future;
      }

      final a = MediaAspectCache.instance.resolve('img3', measure);
      final b = MediaAspectCache.instance.resolve('img3', measure);
      gate.complete(2.0);
      expect(await a, 2.0);
      expect(await b, 2.0);
      expect(measurements, 1);
    });

    test(
      'a failed measurement is not cached, so the next one retries',
      () async {
        var measurements = 0;
        Future<double?> measure() async {
          measurements++;
          return measurements == 1 ? null : 1.25;
        }

        expect(
          await MediaAspectCache.instance.resolve('img4', measure),
          isNull,
        );
        expect(MediaAspectCache.instance.peek('img4'), isNull);
        expect(await MediaAspectCache.instance.resolve('img4', measure), 1.25);
        expect(measurements, 2);
      },
    );
  });
}
