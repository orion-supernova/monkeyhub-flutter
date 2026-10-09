import 'package:flutter_test/flutter_test.dart';
import 'package:monkeyhub/widgets/pinned_banner.dart';

/// Tapping the pin banner jumps to a pin and then advances to the next one, so
/// a room's pins cycle. The cursor that does it lives in the room screen and is
/// read back as `cursor % pins.length` at build time, never through a repo
/// listener.
///
/// What this pins: the list SHRINKS underneath the cursor. A pinned message in
/// a Chamber of Secrets room self-destructs on its own schedule, and its pin
/// row goes with it — so between one subscription frame and the next, a cursor
/// of 4 can be pointing into a list of 2. That has to clamp, not throw.
void main() {
  group('nextPinCursor', () {
    test('advances through the list', () {
      expect(nextPinCursor(0, 3), 1);
      expect(nextPinCursor(1, 3), 2);
    });

    test('wraps at the end', () {
      expect(nextPinCursor(2, 3), 0);
    });

    test('a single pin stays put', () {
      expect(nextPinCursor(0, 1), 0);
    });

    test('an empty list yields 0 rather than dividing by zero', () {
      expect(nextPinCursor(0, 0), 0);
      expect(nextPinCursor(7, 0), 0);
    });

    test('a negative length yields 0', () {
      expect(nextPinCursor(2, -1), 0);
    });

    test('a cursor past the end still lands in range', () {
      // The room screen clamps on read, but the advance must not make it worse.
      expect(nextPinCursor(9, 3), inInclusiveRange(0, 2));
    });
  });

  group('the build-time clamp', () {
    // Mirrors what the room screen does: `_pinCursor % pins.length`.
    int active(int cursor, int length) => length <= 0 ? 0 : cursor % length;

    test('a stale cursor lands in range after the list shrinks', () {
      // Four pins, reader is on the last one, two messages then expire.
      expect(active(3, 2), inInclusiveRange(0, 1));
    });

    test('shrinking to a single pin is in range', () {
      expect(active(3, 1), 0);
    });

    test('shrinking to nothing does not divide by zero', () {
      expect(active(3, 0), 0);
    });
  });

  group('pinIndexForCursor', () {
    test('a fresh cursor shows the newest pin, not the oldest', () {
      // Chronological list: index 2 is the latest.
      expect(pinIndexForCursor(0, 3), 2);
    });

    test('advancing walks back into the past, then wraps to the newest', () {
      var c = 0;
      final seen = <int>[];
      for (var n = 0; n < 4; n++) {
        seen.add(pinIndexForCursor(c, 3));
        c = nextPinCursor(c, 3);
      }
      expect(seen, [2, 1, 0, 2]);
    });

    test('a stale cursor lands in range after the list shrinks', () {
      expect(pinIndexForCursor(3, 2), inInclusiveRange(0, 1));
    });

    test('an empty list yields 0', () {
      expect(pinIndexForCursor(3, 0), 0);
    });

    test('pinCursorForIndex is its inverse', () {
      for (var i = 0; i < 4; i++) {
        expect(pinIndexForCursor(pinCursorForIndex(i, 4), 4), i);
      }
    });
  });
}
