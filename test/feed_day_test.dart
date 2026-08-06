import 'package:flutter_test/flutter_test.dart';
import 'package:monkeyhub/data/feed_day.dart';

/// Day-boundary arithmetic for the Feed board.
///
/// Pure unit tests with no Flutter binding — the whole reason `feed_day.dart`
/// takes an instant instead of calling `DateTime.now()` itself is so the year
/// boundary, the DST seams and the rollover can be checked in microseconds
/// rather than by waiting for midnight.
void main() {
  group('dayKeyOf', () {
    test('zero-pads so keys sort lexicographically', () {
      expect(dayKeyOf(DateTime(2026, 1, 2, 13, 5)), '2026-01-02');
      expect(dayKeyOf(DateTime(2026, 12, 31, 23, 59, 59)), '2026-12-31');
    });

    test('lexicographic order matches chronological order', () {
      // This is the property Convex relies on to range-scan the index without
      // a separate numeric column, so it is worth pinning rather than assuming.
      final keys = [
        dayKeyOf(DateTime(2026, 1, 9)),
        dayKeyOf(DateTime(2026, 1, 10)),
        dayKeyOf(DateTime(2026, 2, 1)),
        dayKeyOf(DateTime(2027, 1, 1)),
      ];
      final sorted = [...keys]..sort();
      expect(sorted, keys);
    });

    test('the last second of a day and the first of the next differ', () {
      expect(
        dayKeyOf(DateTime(2026, 3, 4, 23, 59, 59)),
        isNot(dayKeyOf(DateTime(2026, 3, 5, 0, 0, 0))),
      );
    });
  });

  group('nextMidnightAfter', () {
    test('lands exactly on midnight, never on the same day', () {
      final m = nextMidnightAfter(DateTime(2026, 5, 6, 14, 32, 11));
      expect(m, DateTime(2026, 5, 7));
      expect(m.hour, 0);
      expect(m.minute, 0);
      expect(m.second, 0);
    });

    test('rolls the month and the year', () {
      expect(nextMidnightAfter(DateTime(2026, 1, 31, 9)), DateTime(2026, 2, 1));
      expect(nextMidnightAfter(DateTime(2026, 12, 31, 9)), DateTime(2027, 1, 1));
    });

    test('handles a leap day', () {
      expect(nextMidnightAfter(DateTime(2028, 2, 28, 9)), DateTime(2028, 2, 29));
      expect(nextMidnightAfter(DateTime(2028, 2, 29, 9)), DateTime(2028, 3, 1));
    });

    test('one minute before midnight is one minute away, not a full day', () {
      final now = DateTime(2026, 5, 6, 23, 59);
      expect(nextMidnightAfter(now).difference(now), const Duration(minutes: 1));
    });
  });

  group('untilNextDay', () {
    test('never returns zero or a negative duration', () {
      // A zero-delay Timer that re-reads the same day would spin the CPU.
      for (final t in [
        DateTime(2026, 5, 6),
        DateTime(2026, 5, 6, 23, 59, 59, 999),
        DateTime(2026, 5, 6, 12),
      ]) {
        expect(untilNextDay(t), greaterThanOrEqualTo(const Duration(seconds: 1)));
      }
    });

    test('a fresh midnight waits very nearly a full day', () {
      final d = untilNextDay(DateTime(2026, 5, 6));
      expect(d.inHours, anyOf(23, 24, 25)); // 23/25 on DST transition days
    });
  });

  group('editionNumber', () {
    test('the epoch day is edition 1', () {
      expect(editionNumber(DateTime(2026, 1, 1, 0, 0)), 1);
      expect(editionNumber(DateTime(2026, 1, 1, 23, 59)), 1);
    });

    test('advances by exactly one per calendar day', () {
      expect(editionNumber(DateTime(2026, 1, 2)), 2);
      expect(editionNumber(DateTime(2026, 1, 31)), 31);
      expect(editionNumber(DateTime(2026, 2, 1)), 32);
    });

    test('is independent of the time of day', () {
      // The bug this guards: dividing raw microseconds by 24h makes the edition
      // flip mid-afternoon rather than at midnight.
      final day = DateTime(2026, 6, 15);
      final n = editionNumber(day);
      for (final hour in [0, 6, 12, 18, 23]) {
        expect(editionNumber(DateTime(2026, 6, 15, hour, 30)), n);
      }
    });

    test('survives a DST transition without drifting', () {
      // Whatever the local zone is, consecutive calendar days must differ by
      // exactly 1 across a whole year — a 23h or 25h day must not round away.
      var d = DateTime(2026, 1, 1);
      var prev = editionNumber(d);
      for (var i = 0; i < 365; i++) {
        d = DateTime(2026, 1, 1 + i + 1);
        final n = editionNumber(d);
        expect(n - prev, 1, reason: 'edition jumped at $d');
        prev = n;
      }
    });
  });

  group('sameDay', () {
    test('compares calendar days, not instants', () {
      expect(sameDay(DateTime(2026, 5, 6, 0, 0), DateTime(2026, 5, 6, 23, 59)), isTrue);
      expect(sameDay(DateTime(2026, 5, 6, 23, 59), DateTime(2026, 5, 7, 0, 0)), isFalse);
      expect(sameDay(DateTime(2026, 5, 6), DateTime(2027, 5, 6)), isFalse);
    });
  });
}
