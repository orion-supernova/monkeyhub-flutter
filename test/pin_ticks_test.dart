import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:monkeyhub/widgets/pinned_banner.dart';

/// Geometry of the segmented marker down the pin banner's left edge, pulled out
/// of the painter so it can be checked without a canvas.
///
/// What this pins:
///
///  * the segments fill the marker exactly — an off-by-one in the gap maths
///    leaves the last segment hanging past the bottom, which only shows up at
///    particular pin counts;
///  * past five pins it stops trying to draw one segment each. At the 50-pin
///    cap the segments would be thinner than the gaps and the marker would read
///    as a smear;
///  * an out-of-range `activeIndex` clamps. A pinned message can expire between
///    subscription frames, so the cursor is briefly allowed to be stale — it
///    must not throw.
void main() {
  const size = Size(2, 26);

  group('segmented, up to five pins', () {
    test('one pin fills the whole marker', () {
      final r = pinTickRects(count: 1, activeIndex: 0, size: size);
      expect(r, hasLength(1));
      expect(r.single.top, 0);
      expect(r.single.height, closeTo(26, 0.001));
    });

    for (final count in [2, 3, 4, 5]) {
      test('$count pins tile the marker exactly', () {
        final r = pinTickRects(count: count, activeIndex: 0, size: size);
        expect(r, hasLength(count));
        expect(r.first.top, 0);
        // Last segment ends flush with the bottom.
        expect(r.last.bottom, closeTo(26, 0.001));
        // Every segment is the same height...
        for (final rect in r) {
          expect(rect.height, closeTo(r.first.height, 0.001));
        }
        // ...and the gaps between them are uniform.
        for (var i = 1; i < r.length; i++) {
          expect(r[i].top - r[i - 1].bottom, closeTo(2, 0.001));
        }
      });
    }

    test('segments are ordered top to bottom', () {
      final r = pinTickRects(count: 4, activeIndex: 2, size: size);
      for (var i = 1; i < r.length; i++) {
        expect(r[i].top, greaterThan(r[i - 1].top));
      }
    });
  });

  group('proportional thumb, beyond five pins', () {
    test('collapses to a track plus a thumb', () {
      final r = pinTickRects(count: 12, activeIndex: 0, size: size);
      expect(r, hasLength(2));
      // Track spans everything.
      expect(r[0].top, 0);
      expect(r[0].height, closeTo(26, 0.001));
    });

    test('the thumb travels down as the cursor advances', () {
      final first = pinTickRects(count: 12, activeIndex: 0, size: size)[1];
      final mid = pinTickRects(count: 12, activeIndex: 5, size: size)[1];
      final last = pinTickRects(count: 12, activeIndex: 11, size: size)[1];
      expect(first.top, 0);
      expect(mid.top, greaterThan(first.top));
      expect(last.top, greaterThan(mid.top));
      // And never overruns the track.
      expect(last.bottom, lessThanOrEqualTo(26.001));
    });

    test('the thumb keeps a floor at the 50-pin cap', () {
      final thumb = pinTickRects(count: 50, activeIndex: 25, size: size)[1];
      expect(thumb.height, greaterThanOrEqualTo(6));
    });
  });

  group('degenerate input', () {
    test('no pins draws nothing', () {
      expect(pinTickRects(count: 0, activeIndex: 0, size: size), isEmpty);
      expect(pinTickRects(count: -1, activeIndex: 0, size: size), isEmpty);
    });

    test('an index past the end clamps instead of throwing', () {
      final r = pinTickRects(count: 3, activeIndex: 9, size: size);
      expect(r, hasLength(3));
    });

    test('a negative index clamps instead of throwing', () {
      final r = pinTickRects(count: 3, activeIndex: -4, size: size);
      expect(r, hasLength(3));
    });
  });
}
