import 'package:flutter_test/flutter_test.dart';
import 'package:monkeyhub/calls/call_recovery.dart';
import 'package:monkeyhub/calls/call_stats_monitor.dart';

void main() {
  group('nextRestartDelay', () {
    test('escalates 0s → 4s → 10s then exhausts', () {
      expect(nextRestartDelay(0), Duration.zero);
      expect(nextRestartDelay(1), const Duration(seconds: 4));
      expect(nextRestartDelay(2), const Duration(seconds: 10));
      expect(nextRestartDelay(3), isNull);
      expect(nextRestartDelay(7), isNull);
    });
  });

  group('shouldAbandonRestart', () {
    final t0 = DateTime(2026, 1, 1, 12, 0, 0);

    test('keeps trying inside the outage budget', () {
      expect(
        shouldAbandonRestart(
          outageStart: t0,
          now: t0.add(const Duration(seconds: 10)),
          attemptsSoFar: 1,
        ),
        isFalse,
      );
    });

    test('gives up past 30s outage', () {
      expect(
        shouldAbandonRestart(
          outageStart: t0,
          now: t0.add(const Duration(seconds: 31)),
          attemptsSoFar: 1,
        ),
        isTrue,
      );
    });

    test('gives up after 3 attempts regardless of clock', () {
      expect(
        shouldAbandonRestart(
          outageStart: t0,
          now: t0.add(const Duration(seconds: 1)),
          attemptsSoFar: 3,
        ),
        isTrue,
      );
    });

    test('null outageStart only limits by attempts', () {
      expect(
        shouldAbandonRestart(outageStart: null, now: t0, attemptsSoFar: 0),
        isFalse,
      );
    });
  });

  group('winsGlare', () {
    test('deterministic and asymmetric for any pair', () {
      const a = 'user_aaa';
      const b = 'user_bbb';
      expect(winsGlare(myUserId: a, peerUserId: b),
          isNot(winsGlare(myUserId: b, peerUserId: a)));
      // Stable across repeated evaluation.
      expect(winsGlare(myUserId: a, peerUserId: b),
          winsGlare(myUserId: a, peerUserId: b));
    });
  });

  group('classifyQuality', () {
    test('good on healthy stats', () {
      expect(
        classifyQuality(
            rttMs: 80, lossPercent: 0.5, videoFps: 30, limitationReason: 'none'),
        CallQuality.good,
      );
    });

    test('fair when the encoder reports a limitation', () {
      expect(
        classifyQuality(
            rttMs: 80,
            lossPercent: 0.5,
            videoFps: 24,
            limitationReason: 'bandwidth'),
        CallQuality.fair,
      );
    });

    test('fair on elevated rtt or loss', () {
      expect(classifyQuality(rttMs: 300), CallQuality.fair);
      expect(classifyQuality(lossPercent: 5), CallQuality.fair);
    });

    test('poor on heavy rtt, loss, or collapsed fps', () {
      expect(classifyQuality(rttMs: 500), CallQuality.poor);
      expect(classifyQuality(lossPercent: 12), CallQuality.poor);
      expect(classifyQuality(videoFps: 5), CallQuality.poor);
    });

    test('missing stats default to good (no false alarms)', () {
      expect(classifyQuality(), CallQuality.good);
    });
  });
}
