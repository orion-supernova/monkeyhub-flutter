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
      expect(
        probe.reconnectCalls,
        0,
        reason:
            'reconnect() is web-only. On native convex_flutter implements it '
            'as the same health-check query the probe just ran — it cannot '
            'reach the socket — so calling it tripled the load, healed '
            'nothing, and blocked this loop for up to 30s an attempt.',
      );
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

    // Defect: the grace/stalled clocks were armed by _beginHealing and kept
    // running through the park, so a signed-out app escalated to
    // "reconnecting…" and then "can't reach server" on elapsed time alone —
    // with zero probes behind it. That is what put a permanent, untappable
    // banner over the login screen.
    test('a parked loop never claims an outage it has not observed', () async {
      active = false;
      probe.probeResult = false;
      build().start();

      probe.emit(false);
      // Well past stalledAfter: without evidence, neither clock may fire.
      await settle(_stalled * 3);

      expect(probe.probeCalls, 0, reason: 'signed out — nothing to probe');
      expect(
        health.phase,
        ConnectionPhase.online,
        reason: 'no probe ran, so there is no outage to report',
      );
    });

    test('the banner returns once a parked loop resumes probing', () async {
      active = false;
      probe.probeResult = false;
      build().start();

      probe.emit(false);
      await settle(_stalled * 2);
      expect(health.phase, ConnectionPhase.online);

      // Session appears: probing resumes, so the clocks re-arm and a genuine
      // outage is back on screen within the grace window.
      active = true;
      unawaited(health.retryNow());
      await settle(_grace * 3);
      expect(health.phase, ConnectionPhase.reconnecting);
    });

    // Defect: clearing the phase was reachable only from a probe, so a
    // heartbeat could round-trip successfully every 30s while the banner sat
    // on "reconnecting…" indefinitely.
    test('a successful round-trip clears a stale banner', () async {
      probe.probeResult = false;
      build().start();

      probe.emit(false);
      await settle(_grace * 3);
      expect(health.phase, ConnectionPhase.reconnecting);

      health.noteRoundTrip(ok: true);
      expect(health.phase, ConnectionPhase.online);
      expect(resubscribes, 1, reason: 'a verified reconnect re-registers subs');
    });

    test('reconciling on a round-trip fires exactly one reconnect', () async {
      probe.probeResult = false;
      build().start();

      probe.emit(false);
      await settle(_grace * 3);

      // The heartbeat reconciles while the loop still has a probe in flight;
      // that probe must not produce a second reconnect edge.
      probe.probeResult = true;
      health.noteRoundTrip(ok: true);
      await settle(_grace * 4);

      expect(resubscribes, 1);
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

    // Defect: this is what a "stuck reconnect" actually looked like. The native
    // client's state enum has only `connected` and `connecting`, and it toggles
    // between them on every lap of the Rust client's own reconnect backoff.
    // Trusting the rising edge meant each lap marked us online, hid the banner,
    // then immediately re-entered healing — so the banner cycled "reconnecting…"
    // → "can't reach server · tap to retry" → gone → repeat, and fired a full
    // 8-subscription resubscribe every pass at a server already too slow.
    test('a connected event alone never marks us online', () async {
      probe.probeResult = false;
      build().start();

      probe.emit(false);
      await settle(_grace * 2);
      expect(health.phase, ConnectionPhase.reconnecting);

      probe.emit(true);
      await settle(_grace * 2);

      expect(
        health.phase,
        isNot(ConnectionPhase.online),
        reason: 'nothing round-tripped, so nothing is verified',
      );
      expect(resubscribes, 0);
    });

    test('sustained socket flapping neither resubscribes nor resets the UI', () async {
      probe.probeResult = false;
      build().start();

      for (var i = 0; i < 5; i++) {
        probe.emit(false);
        probe.emit(true);
        await settle(const Duration(milliseconds: 12));
      }
      await settle(const Duration(milliseconds: 40));

      expect(resubscribes, 0, reason: 'no probe ever succeeded');
      expect(
        health.phase,
        ConnectionPhase.stalled,
        reason: 'one continuous outage, not five short ones',
      );
    });

    // Defect: "tap to retry" was dead. retryNow only completed the backoff
    // sleeper, which is null while a probe is in flight — and a probe occupies
    // most of the cycle — so the tap did nothing and the banner just sat there.
    test('tap-to-retry abandons an attempt already in flight', () async {
      probe.probeResult = false;
      probe.probeDelay = const Duration(milliseconds: 150);
      build(backoff: const [Duration(seconds: 30)]).start();

      probe.emit(false);
      await settle(const Duration(milliseconds: 20));
      expect(health.isRetrying, isTrue);
      final before = probe.probeCalls;

      // Network is back, but the in-flight probe won't report for another
      // ~130ms. The tap must not wait it out.
      probe.probeDelay = Duration.zero;
      probe.probeResult = true;
      await health.retryNow();
      await settle(const Duration(milliseconds: 30));

      expect(probe.probeCalls, greaterThan(before));
      expect(health.phase, ConnectionPhase.online);
      expect(resubscribes, 1);
    });

    test('an interrupted attempt keeps the spinner up', () async {
      probe.probeResult = false;
      probe.probeDelay = const Duration(milliseconds: 150);
      build(backoff: const [Duration(seconds: 30)]).start();

      probe.emit(false);
      await settle(const Duration(milliseconds: 20));

      await health.retryNow();
      await settle(const Duration(milliseconds: 10));

      expect(
        health.isRetrying,
        isTrue,
        reason: 'a new attempt started, so the banner must not blink to the dot',
      );
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

    test('non-manual retryNow debounces rapid interruptions within 1.5s', () async {
      probe.probeResult = false;
      probe.probeDelay = const Duration(milliseconds: 100);
      build(backoff: const [Duration(seconds: 30)]).start();

      probe.emit(false);
      await settle(const Duration(milliseconds: 15));
      expect(health.isRetrying, isTrue);
      final initialCalls = probe.probeCalls;

      // Automated non-manual retry (e.g. from resume) within 1.5s window does not interrupt
      await health.retryNow(manual: false);
      await settle(const Duration(milliseconds: 20));

      expect(probe.probeCalls, initialCalls, reason: 'fresh probe <1.5s old must not be interrupted by automatic resume retry');
    });

    test('stalled phase automatic background retries do not toggle isRetrying unless manual', () async {
      probe.probeResult = false;
      probe.probeDelay = const Duration(milliseconds: 10);
      build(backoff: const [Duration(milliseconds: 50)]).start();

      probe.emit(false);
      await settle(_stalled * 2);
      expect(health.phase, ConnectionPhase.stalled);

      // Settle past next background attempt
      await settle(const Duration(milliseconds: 80));
      // Background retry during stalled should not set isRetrying to true
      expect(health.isRetrying, isFalse, reason: 'automatic background retry during stalled phase stays steady on tap-to-retry');

      // Manual retry sets isRetrying to true
      unawaited(health.retryNow(manual: true));
      expect(health.isRetrying, isTrue, reason: 'manual tap sets isRetrying true so spinner displays');
      await settle(const Duration(milliseconds: 30));
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
