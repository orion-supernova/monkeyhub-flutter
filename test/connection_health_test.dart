import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:monkeyhub/backend/connection_health.dart';

/// Scriptable stand-in for [ConvexBackend]. `probeResult` is the ground truth
/// the state machine is supposed to trust over [connectionState].
class FakeProbe implements ConnectionProbe {
  final _ctrl = StreamController<bool>.broadcast();

  bool connected = true;
  bool probeResult = true;
  Duration probeDelay = Duration.zero;

  int probeCalls = 0;
  int reconnectCalls = 0;

  @override
  bool get isConnected => connected;

  @override
  Stream<bool> get connectionState => _ctrl.stream;

  @override
  Future<bool> probeConnection({
    Duration timeout = const Duration(seconds: 5),
  }) async {
    probeCalls++;
    if (probeDelay > Duration.zero) await Future<void>.delayed(probeDelay);
    return probeResult;
  }

  @override
  Future<bool> reconnect() async {
    reconnectCalls++;
    return probeResult;
  }

  /// Emit a socket-state event. Also updates [isConnected] so the two agree,
  /// except where a test deliberately wedges them apart.
  void emit(bool v) {
    connected = v;
    _ctrl.add(v);
  }

  Future<void> close() => _ctrl.close();
}

/// Real timers at ~100x speed, so the tests exercise the actual async paths.
const _grace = Duration(milliseconds: 20);
const _stalled = Duration(milliseconds: 60);
const _probe = Duration(milliseconds: 5);

void main() {
  late FakeProbe probe;
  late ConnectionHealth health;
  late int resubscribes;
  var active = true;

  ConnectionHealth build({
    List<Duration> backoff = const [Duration(milliseconds: 10)],
  }) {
    return health = ConnectionHealth(
      backend: probe,
      onReconnected: () async => resubscribes++,
      isActive: () => active,
      graceDelay: _grace,
      stalledAfter: _stalled,
      firstProbeTimeout: _probe,
      probeTimeout: _probe,
      backoff: backoff,
      // Connectivity() needs a platform channel; the loop is what we're testing.
      watchConnectivity: false,
    );
  }

  Future<void> settle(Duration d) => Future<void>.delayed(d);

  group('ConnectionHealth', () {
    setUp(() {
      probe = FakeProbe();
      resubscribes = 0;
      active = true;
    });

    tearDown(() async {
      health.dispose();
      await probe.close();
    });

    test(
      'escalates online → reconnecting → stalled while the socket stays down',
      () async {
        probe.probeResult = false;
        build().start();

        probe.emit(false);
        expect(
          health.phase,
          ConnectionPhase.online,
          reason: 'grace window suppresses UI for short blips',
        );

        await settle(_grace * 2);
        expect(health.phase, ConnectionPhase.reconnecting);

        await settle(_stalled);
        expect(health.phase, ConnectionPhase.stalled);
      },
    );

    test('a blip shorter than the grace window never shows a banner', () async {
      probe.probeResult = true;
      build().start();

      probe.emit(false);
      probe.emit(true);
      await settle(_grace * 2);

      expect(health.phase, ConnectionPhase.online);
    });

    // Defect: the banner used to hide itself on a successful probe without
    // telling anyone, so subscriptions stayed dead behind a healthy-looking UI.
    test(
      'a probe success counts as a reconnect even if the stream never says so',
      () async {
        probe.probeResult = true;
        build().start();

        // Stream wedges at "disconnected" and never re-emits true.
        probe.emit(false);
        await settle(_grace * 3);

        expect(health.phase, ConnectionPhase.online);
        expect(resubscribes, 1, reason: 'subscriptions must be re-registered');
      },
    );

    // Defect: the resume heal probed once and gave up, so a probe issued before
    // the radio was ready left the app wedged on "reconnecting…" forever.
    test('keeps retrying indefinitely and never gives up', () async {
      probe.probeResult = false;
      build().start();

      probe.emit(false);
      await settle(const Duration(milliseconds: 250));

      expect(
        probe.probeCalls,
        greaterThan(4),
        reason: 'the loop must keep attempting, not stop after one',
      );
      expect(probe.reconnectCalls, greaterThan(1));
      expect(health.phase, ConnectionPhase.stalled);
      expect(resubscribes, 0);
    });

    test('recovers on a later attempt once the network comes back', () async {
      probe.probeResult = false;
      build().start();

      probe.emit(false);
      await settle(const Duration(milliseconds: 80));
      expect(health.phase, ConnectionPhase.stalled);

      // Radio finally up. No new stream event — only the loop notices.
      probe.probeResult = true;
      await settle(const Duration(milliseconds: 60));

      expect(health.phase, ConnectionPhase.online);
      expect(resubscribes, 1);
    });

    test('retryNow skips the pending backoff wait', () async {
      probe.probeResult = false;
      build(backoff: const [Duration(seconds: 30)]).start();

      probe.emit(false);
      await settle(const Duration(milliseconds: 40));
      final before = probe.probeCalls;
      expect(before, greaterThan(0));

      // Without the wake, the next attempt would be 30s away.
      await health.retryNow();
      await settle(const Duration(milliseconds: 20));

      expect(probe.probeCalls, greaterThan(before));
    });

    test(
      'retryNow verifies a socket that merely claims to be connected',
      () async {
        probe.probeResult = false;
        build().start();

        // No stream event at all — the frozen-socket case.
        expect(health.phase, ConnectionPhase.online);
        await health.retryNow();
        await settle(_grace * 2);

        expect(health.phase, ConnectionPhase.reconnecting);
      },
    );

    test(
      'parks in the background and probes immediately on foreground',
      () async {
        probe.probeResult = false;
        build().start();

        health.setForeground(false);
        probe.emit(false);
        await settle(const Duration(milliseconds: 60));
        expect(probe.probeCalls, 0, reason: 'a suspended app must not poll');

        health.setForeground(true);
        await settle(const Duration(milliseconds: 30));
        expect(probe.probeCalls, greaterThan(0));
      },
    );

    test('parks while signed out, resumes when a session appears', () async {
      active = false;
      probe.probeResult = false;
      build().start();

      probe.emit(false);
      await settle(const Duration(milliseconds: 60));
      expect(probe.probeCalls, 0);

      active = true;
      await health.retryNow();
      await settle(const Duration(milliseconds: 30));
      expect(probe.probeCalls, greaterThan(0));
    });

    // Defect: a socket frozen while still reporting `connected` had no detector
    // at all while the app stayed foreground — no stream event, no resume event.
    test('consecutive failed round-trips reveal a frozen socket', () async {
      probe.probeResult = false;
      build().start();

      health.noteRoundTrip(ok: false);
      await settle(_grace * 2);
      expect(
        health.phase,
        ConnectionPhase.online,
        reason: 'one failure is not enough evidence',
      );

      health.noteRoundTrip(ok: false);
      await settle(_grace * 2);
      expect(health.phase, ConnectionPhase.reconnecting);
    });

    test('a successful round-trip resets the failure streak', () async {
      probe.probeResult = false;
      build().start();

      health.noteRoundTrip(ok: false);
      health.noteRoundTrip(ok: true);
      health.noteRoundTrip(ok: false);
      await settle(_grace * 2);

      expect(health.phase, ConnectionPhase.online);
    });

    test('isRetrying tracks an in-flight attempt so the UI can spin', () async {
      probe.probeResult = false;
      probe.probeDelay = const Duration(milliseconds: 40);
      build().start();

      probe.emit(false);
      await settle(const Duration(milliseconds: 15));
      expect(health.isRetrying, isTrue);

      probe.probeResult = true;
      await settle(const Duration(milliseconds: 200));
      expect(health.isRetrying, isFalse);
    });

    test('disposing stops the loop', () async {
      probe.probeResult = false;
      build().start();

      probe.emit(false);
      await settle(const Duration(milliseconds: 40));
      health.dispose();
      final after = probe.probeCalls;

      await settle(const Duration(milliseconds: 80));
      expect(probe.probeCalls, after);
    });
  });

  // Defect: overlapping resubscribes used to be dropped outright. When the
  // dropped one was the real reconnect, its subscriptions were never
  // re-registered and the app went quiet until a restart.
  group('CoalescingJob', () {
    test('collapses overlapping requests into exactly one re-run', () async {
      var runs = 0;
      final gate = Completer<void>();
      final job = CoalescingJob(() async {
        runs++;
        if (runs == 1) await gate.future;
      });

      final first = job.call();
      expect(job.isRunning, isTrue);

      // Three requests arrive mid-flight; they must produce one re-run, not
      // three, and must not be discarded.
      unawaited(job.call());
      unawaited(job.call());
      unawaited(job.call());
      expect(runs, 1);

      gate.complete();
      await first;

      expect(runs, 2);
      expect(job.isRunning, isFalse);
    });

    test('runs once when nothing overlaps', () async {
      var runs = 0;
      final job = CoalescingJob(() async => runs++);
      await job.call();
      await job.call();
      expect(runs, 2);
    });

    test('a throwing run still clears the running flag and re-runs', () async {
      var runs = 0;
      final gate = Completer<void>();
      final job = CoalescingJob(() async {
        runs++;
        if (runs == 1) {
          await gate.future;
          throw StateError('resubscribe failed');
        }
      });

      final first = job.call();
      unawaited(job.call());
      gate.complete();

      await expectLater(first, throwsStateError);
      // The queued request must still have run despite the failure above.
      expect(runs, 2);
      expect(job.isRunning, isFalse);
    });
  });
}
