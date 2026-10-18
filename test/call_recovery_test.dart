import 'package:flutter_test/flutter_test.dart';
import 'package:monkeyhub/calls/call_recovery.dart';
import 'package:monkeyhub/calls/call_stats_monitor.dart';

void main() {
  group('nextRestartDelay', () {
    test('escalates 0s → 4s → 6s, then 8s forever', () {
      expect(nextRestartDelay(0), Duration.zero);
      expect(nextRestartDelay(1), const Duration(seconds: 4));
      expect(nextRestartDelay(2), const Duration(seconds: 6));
      expect(nextRestartDelay(3), const Duration(seconds: 8));
      // Never exhausts: the outage budget ends recovery, not a count.
      expect(nextRestartDelay(40), const Duration(seconds: 8));
    });
  });

  group('restartStillSettling', () {
    final t0 = DateTime(2026, 1, 1, 12);

    test('a restart whose checks are running is left alone', () {
      expect(
        restartStillSettling(
          linkConnecting: true,
          lastRestartAt: t0,
          now: t0.add(const Duration(seconds: 3)),
        ),
        isTrue,
      );
    });

    test('but not forever, and not when the link is simply down', () {
      expect(
        restartStillSettling(
          linkConnecting: true,
          lastRestartAt: t0,
          now: t0.add(kRestartSettle + const Duration(milliseconds: 1)),
        ),
        isFalse,
      );
      expect(
        restartStillSettling(
          linkConnecting: false,
          lastRestartAt: t0,
          now: t0.add(const Duration(seconds: 1)),
        ),
        isFalse,
      );
      expect(
        restartStillSettling(
          linkConnecting: true,
          lastRestartAt: null,
          now: t0,
        ),
        isFalse,
      );
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

    test('attempt count alone no longer ends a call', () {
      // The Wi-Fi → cellular bug: three attempts were spent into a signaling
      // socket that was itself being rebuilt, and the call was torn down a
      // second or two after the network was usable again.
      expect(
        shouldAbandonRestart(
          outageStart: t0,
          now: t0.add(const Duration(seconds: 1)),
          attemptsSoFar: 3,
        ),
        isFalse,
      );
    });

    test('time with the signaling transport down does not count', () {
      // 50s outage, 25s of it with our own socket down: only 25s of it was
      // time a restart could have been delivered in.
      expect(
        shouldAbandonRestart(
          outageStart: t0,
          now: t0.add(const Duration(seconds: 50)),
          attemptsSoFar: 6,
          signalingDown: const Duration(seconds: 25),
        ),
        isFalse,
      );
      expect(
        shouldAbandonRestart(
          outageStart: t0,
          now: t0.add(const Duration(seconds: 50)),
          attemptsSoFar: 6,
          signalingDown: const Duration(seconds: 15),
        ),
        isTrue,
      );
    });

    test('a peer heard from recently holds the call open', () {
      final now = t0.add(const Duration(seconds: 40));
      expect(
        shouldAbandonRestart(
          outageStart: t0,
          now: now,
          attemptsSoFar: 5,
          lastPeerSignal: now.subtract(const Duration(seconds: 5)),
        ),
        isFalse,
      );
      // Heard from before the outage began: that proves nothing about now.
      expect(
        shouldAbandonRestart(
          outageStart: t0,
          now: now,
          attemptsSoFar: 5,
          lastPeerSignal: t0.subtract(const Duration(seconds: 1)),
        ),
        isTrue,
      );
    });

    test('the hard ceiling wins over every excuse', () {
      final now = t0.add(kHardCallOutage + const Duration(seconds: 1));
      expect(
        shouldAbandonRestart(
          outageStart: t0,
          now: now,
          attemptsSoFar: 1,
          signalingDown: kHardCallOutage,
          lastPeerSignal: now,
        ),
        isTrue,
      );
    });

    test('no outage clock means nothing to abandon', () {
      expect(
        shouldAbandonRestart(outageStart: null, now: t0, attemptsSoFar: 9),
        isFalse,
      );
    });
  });

  group('winsGlare', () {
    test('deterministic and asymmetric for any pair', () {
      const a = 'user_aaa';
      const b = 'user_bbb';
      expect(
        winsGlare(myUserId: a, peerUserId: b),
        isNot(winsGlare(myUserId: b, peerUserId: a)),
      );
      // Stable across repeated evaluation.
      expect(
        winsGlare(myUserId: a, peerUserId: b),
        winsGlare(myUserId: a, peerUserId: b),
      );
    });
  });

  group('classifyQuality', () {
    test('good on healthy stats', () {
      expect(
        classifyQuality(
          rttMs: 80,
          lossPercent: 0.5,
          videoFps: 30,
          limitationReason: 'none',
        ),
        CallQuality.good,
      );
    });

    test('fair when the encoder reports a limitation', () {
      expect(
        classifyQuality(
          rttMs: 80,
          lossPercent: 0.5,
          videoFps: 24,
          limitationReason: 'bandwidth',
        ),
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
