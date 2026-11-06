import 'package:flutter_test/flutter_test.dart';
import 'package:monkeyhub/calls/call_quality_report.dart';
import 'package:monkeyhub/calls/call_stats_monitor.dart';

void main() {
  final t0 = DateTime(2026, 11, 6, 12);
  DateTime at(int seconds) => t0.add(Duration(seconds: seconds));

  test('good, fair and poor map to 0, 1 and 2', () {
    expect(qualityBucketValue(CallQuality.good), 0);
    expect(qualityBucketValue(CallQuality.fair), 1);
    expect(qualityBucketValue(CallQuality.poor), 2);
  });

  test('the worst snapshot of each 10 s window is the bucket', () {
    final r = CallQualityRecorder();
    // Window 0: good, fair, good (polls every 2 s).
    r.add(CallQuality.good, at(0));
    r.add(CallQuality.fair, at(2));
    r.add(CallQuality.good, at(4));
    // Window 1: all good.
    r.add(CallQuality.good, at(10));
    r.add(CallQuality.good, at(12));
    // Window 2: one poor.
    r.add(CallQuality.poor, at(21));
    expect(r.take(), [1, 0, 2]);
  });

  test('a stall repeats the last bucket so the strip tracks connected time', () {
    final r = CallQualityRecorder();
    r.add(CallQuality.fair, at(0));
    r.add(CallQuality.good, at(35)); // nothing between: windows 1 and 2 missing
    expect(r.take(), [1, 1, 1, 0]);
  });

  test('take hands the samples over once and starts clean', () {
    final r = CallQualityRecorder();
    r.add(CallQuality.good, at(0));
    expect(r.hasData, isTrue);
    expect(r.take(), [0]);
    expect(r.hasData, isFalse);
    expect(r.take(), isEmpty);
    // The next call starts its own clock.
    r.add(CallQuality.poor, at(500));
    expect(r.take(), [2]);
  });

  test('capped at 360 buckets (an hour of call)', () {
    final r = CallQualityRecorder();
    for (var s = 0; s < 3 * 3600; s += 2) {
      r.add(CallQuality.good, at(s));
    }
    expect(r.take(), hasLength(360));
  });

  test('a call with no snapshots reports nothing', () {
    expect(CallQualityRecorder().take(), isEmpty);
  });

  test('the report is fire and forget: a failing reporter never throws', () async {
    final calls = <List<int>>[];
    final saved = qualityReporter;
    addTearDown(() => qualityReporter = saved);
    qualityReporter = ({String? callId, String? groupCallId, required List<int> samples}) async {
      calls.add(samples);
      throw StateError('offline');
    };
    sendQualityReport(callId: 'c1', samples: const [0, 1]);
    sendQualityReport(callId: 'c1', samples: const []); // nothing to say
    sendQualityReport(samples: const [0]); // no call to say it about
    await Future<void>.delayed(Duration.zero);
    expect(calls, [
      [0, 1],
    ]);
  });
}
