import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Two things the daily games nudge cannot be caught getting wrong at runtime.
///
/// Both are backend TypeScript that no Dart test can execute and no `tsc` run
/// can judge, and both fail the same way: silently, for a subset of users,
/// discovered days later by somebody saying "I never get those". So they are
/// asserted against the source the way `daily_nudge_copy_test.dart` asserts the
/// copy table — a read of the file, not a mirror of the logic.
void main() {
  late String crons;
  late String nudge;

  setUpAll(() {
    File f(String path) {
      final file = File(path);
      expect(file.existsSync(), isTrue, reason: 'missing $path');
      return file;
    }

    crons = f('backend/convex/crons.ts').readAsStringSync();
    nudge = f('backend/convex/dailyNudge.ts').readAsStringSync();
  });

  /// The `crons.*(...)` call that schedules the nudge, whichever kind it is.
  String scheduleCall() {
    final at = crons.indexOf('"dailyNudge.run"');
    expect(at, greaterThan(-1), reason: 'the nudge is no longer scheduled');
    final open = crons.lastIndexOf('crons.', at);
    final close = crons.indexOf(');', at);
    expect(close, greaterThan(open));
    return crons.substring(open, close);
  }

  test('the nudge is scheduled on the wall clock, not on an interval', () {
    // `crons.interval` measures from the END of the previous run, so the ticks
    // slide later by however long each one took. A tick is snapped to the
    // nearest quarter hour to decide WHICH TIME ZONE it serves, so a schedule
    // that drifts past the halfway mark skips a quarter outright — and the zone
    // that quarter addresses hears nothing at all that day. There is no error,
    // no log and no failing test to say so; the only symptom is one country
    // going quiet.
    final call = scheduleCall();
    expect(
      call.contains('crons.interval'),
      isFalse,
      reason: 'crons.interval drifts — the nudge needs a wall-clock schedule',
    );
    expect(
      call.contains('"0,15,30,45 * * * *"'),
      isTrue,
      reason: 'every one of the 96 daily ticks must fire, exactly once',
    );
  });

  test('devices that never reported a zone are still an audience', () {
    // `tzOffsetMinutes` is absent on every row an app build older than the
    // feature writes, and `by_tz_offset` cannot return a row that is missing
    // the field. Without a bucket that probes for it, those devices are not
    // late — they are unreachable forever, while holding live push tokens.
    expect(
      nudge.contains('tzOffsetMinutes ?? undefined'),
      isTrue,
      reason: 'the audience query no longer probes the zone-less bucket',
    );
    expect(
      nudge.contains('NUDGE_FALLBACK_TZ_OFFSET'),
      isTrue,
      reason: 'the zone-less bucket has no offset to be sent at',
    );
  });

  test('a zone that missed its tick is swept up by the next ones', () {
    // A zone maps to exactly one of the 96 ticks, so a single throw used to
    // cost it the whole day with the next attempt 24 hours out.
    expect(
      nudge.contains('CATCH_UP_TICKS'),
      isTrue,
      reason: 'a missed tick is a lost day without a catch-up window',
    );
  });
}
