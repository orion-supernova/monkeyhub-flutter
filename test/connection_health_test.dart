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

  /// Independent of [probeResult]: a rebuild can succeed onto a socket that
  /// still cannot reach the server, which is exactly the case the loop has to
  /// keep probing through.
  bool reconnectResult = true;
  Duration reconnectDelay = Duration.zero;

  int probeCalls = 0;
  int reconnectCalls = 0;

  /// Ordered log of every call. Some claims are about sequence, not counts —
  /// "rebuilt before it probed" is not the same as "rebuilt and probed".
  final List<String> calls = [];

  @override
  bool get isConnected => connected;

  @override
  Stream<bool> get connectionState => _ctrl.stream;

  @override
  Future<bool> probeConnection({
    Duration timeout = const Duration(seconds: 5),
  }) async {
    probeCalls++;
    calls.add('probe');
    if (probeDelay > Duration.zero) await Future<void>.delayed(probeDelay);
    return probeResult;
  }

  @override
  Future<bool> reconnect() async {
    reconnectCalls++;
    calls.add('reconnect');
    if (reconnectDelay > Duration.zero) {
      await Future<void>.delayed(reconnectDelay);
    }
    return reconnectResult;
  }

  /// Emit a socket-state event. Also updates [isConnected] so the two agree,
  /// except where a test deliberately wedges them apart.
  void emit(bool v) {
    connected = v;
    _ctrl.add(v);
  }

  Future<void> close() => _ctrl.close();
}

/// A wall clock the test moves by hand.
///
/// The background-gap and connectivity-throttle rules are stated in wall-clock
/// seconds because that is what they are actually about — how long the device
/// was asleep, how fast the OS emits interface changes. Waiting those out for
/// real would put minutes into a suite that runs in twenty seconds.
class FakeClock {
  DateTime _now = DateTime.utc(2026);
  DateTime call() => _now;
  void advance(Duration d) => _now = _now.add(d);
}

/// Real timers at ~100x speed, so the tests exercise the actual async paths.
/// Anything measured in wall-clock seconds goes through [FakeClock] instead.
/// No test may await more than 250ms of real time.
const _grace = Duration(milliseconds: 20);
const _stalled = Duration(milliseconds: 60);
const _probe = Duration(milliseconds: 5);

void main() {
  late FakeProbe probe;
  late ConnectionHealth health;
  late FakeClock clock;
  late StreamController<bool> connectivity;
  late int resubscribes;
  var active = true;

  ConnectionHealth build({
    List<Duration> backoff = const [Duration(milliseconds: 10)],
    int rebuildAfterAttempt = 2,
    int maxStalledRearms = 2,
    bool watchConnectivity = false,
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
      rebuildAfterAttempt: rebuildAfterAttempt,
      rebuildTimeout: _probe,
      maxStalledRearms: maxStalledRearms,
      // Scaled with the rest of the clocks. In production this is 750ms; here
      // it is the floor no wake may cut off a 10ms backoff rung.
      minLoopInterval: const Duration(milliseconds: 10),
      offlineGrace: const Duration(milliseconds: 6),
      now: clock.call,
      connectivity: connectivity.stream,
      // Connectivity() needs a platform channel; the injected stream stands in
      // where a test drives interface changes on purpose.
      watchConnectivity: watchConnectivity,
    );
  }

  Future<void> settle(Duration d) => Future<void>.delayed(d);

  /// Wait for the phase to ARRIVE at [want], polling rather than sleeping a
  /// fixed span.
  ///
  /// The clocks here run at ~100x, which makes a grace window 20ms wide — tight
  /// enough that a loaded machine can slip past a fixed `settle` and fail on
  /// scheduling jitter rather than on behaviour. Polling is faster in the
  /// common case and does not lie in the uncommon one. Use a plain `expect` for
  /// the opposite claim (a phase that must NOT have been reached yet); this
  /// helper can only prove arrival.
  Future<void> expectPhase(
    ConnectionPhase want, {
    Duration budget = const Duration(milliseconds: 500),
    String? reason,
  }) async {
    final deadline = DateTime.now().add(budget);
    while (health.phase != want && DateTime.now().isBefore(deadline)) {
      await settle(const Duration(milliseconds: 5));
    }
    expect(health.phase, want, reason: reason);
  }

  group('ConnectionHealth', () {
    setUp(() {
      probe = FakeProbe();
      clock = FakeClock();
      connectivity = StreamController<bool>.broadcast();
      resubscribes = 0;
      active = true;
    });

    tearDown(() async {
      health.dispose();
      await probe.close();
      await connectivity.close();
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

        await expectPhase(ConnectionPhase.reconnecting);

        await expectPhase(ConnectionPhase.stalled);
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

    // The socket-state stream is a hint, and on native it is a NOISY one: the
    // Rust client toggles `connecting` on every lap of its own reconnect and
    // replays the query set when it returns, so those laps change nothing the
    // user could observe — except that they used to raise a banner. This is the
    // iPhone symptom: "reconnecting…" more or less permanently, over a session
    // whose messages were arriving fine.
    //
    // A blip that outlasts the grace window must still show nothing, as long as
    // probes keep round-tripping. Only a FAILED probe may start the clocks.
    test(
      'a long socket blip shows nothing while probes still round-trip',
      () async {
        probe.probeResult = true;
        // Long enough that the old "arm on attempt start" behaviour would have
        // escalated all the way to stalled before this probe even returned.
        probe.probeDelay = _stalled * 2;
        build().start();

        probe.emit(false);
        await settle(_grace * 2);
        expect(
          health.phase,
          ConnectionPhase.online,
          reason: 'no probe has failed, so there is nothing to report yet',
        );

        await settle(_stalled * 3);
        expect(health.phase, ConnectionPhase.online);
      },
    );

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
        greaterThan(0),
        reason:
            'a socket that never answers is the case a rebuild exists for — on '
            'native it is the ONLY way to close one, since convex-rs notices a '
            'silent socket solely via a 30s monotonic timer that does not run '
            'while the device sleeps.',
      );
      expect(
        probe.reconnectCalls,
        lessThan(probe.probeCalls),
        reason:
            'but it is an escalation, not the loop. A rebuild throws away a '
            'query set that has to be re-registered; a merely slow server must '
            'not get one per attempt.',
      );
      expect(health.phase, ConnectionPhase.stalled);
      expect(resubscribes, 0);
    });

    test('recovers on a later attempt once the network comes back', () async {
      probe.probeResult = false;
      build().start();

      probe.emit(false);
      await expectPhase(ConnectionPhase.stalled);

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
        await expectPhase(ConnectionPhase.reconnecting);
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
      await expectPhase(ConnectionPhase.reconnecting);
    });

    // Defect: clearing the phase was reachable only from a probe, so a
    // heartbeat could round-trip successfully every 30s while the banner sat
    // on "reconnecting…" indefinitely.
    test('a successful round-trip clears a stale banner', () async {
      probe.probeResult = false;
      build().start();

      probe.emit(false);
      await expectPhase(ConnectionPhase.reconnecting);

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
      await expectPhase(ConnectionPhase.reconnecting);
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
      await expectPhase(ConnectionPhase.reconnecting);

      probe.emit(true);
      await settle(_grace * 2);

      expect(
        health.phase,
        isNot(ConnectionPhase.online),
        reason: 'nothing round-tripped, so nothing is verified',
      );
      expect(resubscribes, 0);
    });

    test(
      'sustained socket flapping neither resubscribes nor resets the UI',
      () async {
        probe.probeResult = false;
        probe.reconnectResult = false;
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
          isNot(ConnectionPhase.online),
          reason: 'one continuous outage, not five short ones',
        );

        // Each edge is evidence of progress, so the alarm gets pushed back — but
        // only [maxStalledRearms] times. Past that the flapping is the outage,
        // and a connection that is genuinely broken has to say so.
        await settle(_stalled * 4);
        expect(
          health.phase,
          ConnectionPhase.stalled,
          reason: 'the alarm cannot be deferred forever by flapping',
        );
        expect(resubscribes, 0);
      },
    );

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
        reason:
            'a new attempt started, so the banner must not blink to the dot',
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

      expect(
        probe.probeCalls,
        initialCalls,
        reason:
            'fresh probe <1.5s old must not be interrupted by automatic resume retry',
      );
    });

    test(
      'stalled phase automatic background retries do not toggle isRetrying unless manual',
      () async {
        probe.probeResult = false;
        probe.probeDelay = const Duration(milliseconds: 10);
        build(backoff: const [Duration(milliseconds: 50)]).start();

        probe.emit(false);
        await expectPhase(ConnectionPhase.stalled);

        // Settle past next background attempt
        await settle(const Duration(milliseconds: 80));
        // Background retry during stalled should not set isRetrying to true
        expect(
          health.isRetrying,
          isFalse,
          reason:
              'automatic background retry during stalled phase stays steady on tap-to-retry',
        );

        // Manual retry sets isRetrying to true
        unawaited(health.retryNow(manual: true));
        expect(
          health.isRetrying,
          isTrue,
          reason: 'manual tap sets isRetrying true so spinner displays',
        );
        await settle(const Duration(milliseconds: 30));
      },
    );

    // ───────── rebuilding the socket ─────────
    //
    // The reported bug: a phone unlocked after minutes away sat on
    // "reconnecting…", escalated to "can't reach server · tap to retry", and
    // took twenty to thirty seconds to clear — while the same app on a fresh
    // launch connected instantly. The socket was open and dead (NAT binding
    // expired, or the interface changed while asleep) and nothing could close
    // it: convex-rs notices only via a 30s inactivity check on a MONOTONIC
    // clock, which does not advance during sleep and so effectively restarts at
    // resume, and every probe meanwhile parks on the dead socket for its full
    // timeout. These tests pin the way out.

    test('a long background gap rebuilds the socket before probing', () async {
      build().start();

      health.setForeground(false);
      clock.advance(const Duration(minutes: 5));
      health.setForeground(true);
      await settle(const Duration(milliseconds: 30));

      expect(
        probe.calls.first,
        'reconnect',
        reason:
            'the length of the gap is already the answer — spending a probe '
            'timeout confirming it is the delay users report',
      );
      expect(health.phase, ConnectionPhase.online);
      expect(resubscribes, 1, reason: 'a fresh socket needs its subs put back');
    });

    test('a short background gap does not rebuild', () async {
      build().start();

      health.setForeground(false);
      clock.advance(const Duration(seconds: 2));
      health.setForeground(true);
      await settle(const Duration(milliseconds: 30));

      expect(
        probe.reconnectCalls,
        0,
        reason:
            'an app-switcher peek leaves a working socket; tearing it down '
            'would cost a handshake and every subscription for nothing',
      );
      expect(probe.probeCalls, greaterThan(0));
      expect(health.phase, ConnectionPhase.online);
    });

    test(
      'the rebuild escalation waits for rebuildAfterAttempt failures',
      () async {
        probe.probeResult = false;
        probe.reconnectResult = false;
        build(backoff: const [Duration(milliseconds: 10)]).start();

        probe.emit(false);
        // Two attempts in: still probing only.
        await settle(const Duration(milliseconds: 25));
        expect(
          probe.calls.take(2),
          everyElement('probe'),
          reason: 'a merely slow server must not lose its socket on one miss',
        );

        await settle(const Duration(milliseconds: 120));
        expect(probe.reconnectCalls, greaterThan(0));
      },
    );

    test(
      'a rebuild is re-probed at once and does not reset the backoff',
      () async {
        probe.probeResult = false;
        build(
          backoff: const [
            Duration(milliseconds: 10),
            Duration(milliseconds: 10),
            Duration(seconds: 30),
          ],
        ).start();

        probe.emit(false);
        await settle(const Duration(milliseconds: 60));

        final i = probe.calls.indexOf('reconnect');
        expect(i, greaterThanOrEqualTo(0));
        expect(
          probe.calls[i + 1],
          'probe',
          reason:
              'the point of a rebuild is the probe that rides the new socket',
        );

        // The ladder measures how long the outage has lasted, which a rebuild
        // does not shorten. Resetting it left an offline phone oscillating on the
        // first two rungs instead of settling at one attempt per 15s.
        final settled = probe.probeCalls;
        await settle(const Duration(milliseconds: 80));
        expect(probe.probeCalls, settled, reason: 'parked on the 30s rung');
      },
    );

    test('a connected edge no longer cancels an in-flight probe', () async {
      probe.probeResult = false;
      probe.probeDelay = const Duration(milliseconds: 60);
      build(backoff: const [Duration(seconds: 30)]).start();

      probe.emit(false);
      await settle(const Duration(milliseconds: 15));
      expect(probe.probeCalls, 1);

      // The socket comes back mid-probe. That probe is registered in the very
      // query set convex-rs resends on reconnect, so it is about to resolve —
      // and convex-rs emits this edge on every lap of its own backoff, so
      // killing the probe on it meant edges arriving faster than a probe could
      // resolve spun the loop forever without ever getting an answer.
      probe.probeResult = true;
      probe.emit(true);
      await settle(const Duration(milliseconds: 80));

      expect(
        probe.probeCalls,
        1,
        reason: 'the edge said "wait for it", not "start over"',
      );
      expect(health.phase, ConnectionPhase.online);
      expect(resubscribes, 1);
    });

    test('an interrupt storm cannot spin the loop', () async {
      probe.probeResult = false;
      probe.reconnectResult = false;
      build(backoff: const [Duration(milliseconds: 10)]).start();

      probe.emit(false);
      for (var i = 0; i < 50; i++) {
        probe.emit(false);
        probe.emit(true);
      }
      await settle(const Duration(milliseconds: 100));

      expect(
        probe.probeCalls,
        lessThan(15),
        reason: 'a busy loop here issues a fresh server query per lap',
      );
    });

    test(
      'connectivity storms produce at most one retry per throttle window',
      () async {
        probe.probeResult = false;
        build(
          backoff: const [Duration(seconds: 30)],
          watchConnectivity: true,
        ).start();

        probe.emit(false);
        await settle(const Duration(milliseconds: 30));
        final before = probe.probeCalls;

        // Both platforms emit a burst of interface transitions per unlock.
        for (var i = 0; i < 8; i++) {
          connectivity.add(true);
        }
        await settle(const Duration(milliseconds: 30));

        expect(
          probe.probeCalls - before,
          lessThanOrEqualTo(1),
          reason: 'unthrottled, each one killed the probe the last one started',
        );
      },
    );

    test('tap-to-retry during a verify starts a fresh probe', () async {
      probe.probeResult = false;
      probe.probeDelay = const Duration(milliseconds: 120);
      build().start();

      // Not healing — the socket claims to be fine.
      unawaited(health.retryNow(manual: true));
      await settle(const Duration(milliseconds: 20));
      expect(probe.probeCalls, 1);

      // The user taps again. This used to bail on the banner's own spinner
      // flag, so the tap did nothing at all for a full probe timeout — on the
      // one control whose entire purpose is to make something happen.
      clock.advance(const Duration(seconds: 5)); // past the interrupt debounce
      unawaited(health.retryNow(manual: true));
      await settle(const Duration(milliseconds: 20));

      expect(probe.probeCalls, 2);
      await settle(const Duration(milliseconds: 150));
    });

    // A probe that outlives the episode that started it. The heartbeat can
    // succeed mid-probe and take us online, so by the time the probe reports
    // failure it is stale news — and acting on it used to poison everything
    // after: `_armUiTimers` latched `_uiTimersArmed` with `_disarmUiTimers`
    // already run, so the timers it created were dead on arrival and the latch
    // then suppressed the *next* outage's banner entirely.
    test('a probe that reports after we are already online cannot mute the '
        'next outage', () async {
      probe.probeResult = false;
      probe.probeDelay = const Duration(milliseconds: 60);
      build(backoff: const [Duration(milliseconds: 10)]).start();

      probe.emit(false);
      await settle(const Duration(milliseconds: 15));
      expect(probe.probeCalls, 1, reason: 'still in flight');

      // The heartbeat gets through while the probe is still parked.
      health.noteRoundTrip(ok: true);
      expect(health.phase, ConnectionPhase.online);
      // Let the stale probe land and do whatever it is going to do.
      await settle(const Duration(milliseconds: 80));

      // Now a real outage.
      probe.probeDelay = Duration.zero;
      probe.reconnectResult = false;
      probe.emit(false);
      await settle(_grace * 3);

      expect(
        health.phase,
        isNot(ConnectionPhase.online),
        reason: 'the banner must still arm after a stale probe landed',
      );
    });

    test(
      'a tap during the uninterruptible floor is honoured, not dropped',
      () async {
        probe.probeResult = false;
        // One long rung, so a dropped wake is unmistakable: without the fix the
        // next probe is 30s away.
        build(backoff: const [Duration(seconds: 30)]).start();

        probe.emit(false);
        await settle(const Duration(milliseconds: 20));
        final before = probe.probeCalls;
        expect(before, greaterThan(0));

        // The floor is only 10ms here, so land the tap inside it: fire it in the
        // same turn the probe fails.
        health.retryNow(manual: true);
        await settle(const Duration(milliseconds: 60));

        expect(
          probe.probeCalls,
          greaterThan(before),
          reason:
              'the floor bounds how OFTEN we retry; it must not discard the '
              'request, or the banner spins "retrying…" with nothing in flight',
        );
      },
    );

    // ───────── the one input that is not a hint ─────────

    test(
      'losing the interface shows the banner without waiting for a probe',
      () async {
        probe.probeResult = false;
        probe.probeDelay = const Duration(seconds: 30); // never reports
        build(watchConnectivity: true).start();

        connectivity.add(false);

        // The probe is still parked and will be for another 30s. Nothing else in
        // this class could raise a banner before then, which is the ~9.5s (real
        // clock) blind spot this exists to close.
        await expectPhase(
          ConnectionPhase.reconnecting,
          reason: 'the radio being off is not something a probe can clarify',
        );
        expect(
          probe.probeCalls,
          lessThanOrEqualTo(1),
          reason: 'no extra probing — we already know the answer',
        );
      },
    );

    test('a momentary interface flap does not flash the banner', () async {
      probe.probeResult = true;
      build(watchConnectivity: true).start();

      // Both platforms flick through `none` while handing off Wi-Fi→cellular.
      connectivity.add(false);
      await settle(const Duration(milliseconds: 2));
      connectivity.add(true);
      await settle(const Duration(milliseconds: 40));

      expect(
        health.phase,
        ConnectionPhase.online,
        reason: 'a handoff is not an outage',
      );
    });

    test(
      'the banner clears once the interface returns and a probe lands',
      () async {
        probe.probeResult = false;
        build(watchConnectivity: true).start();

        connectivity.add(false);
        await expectPhase(ConnectionPhase.reconnecting);

        probe.probeResult = true;
        clock.advance(const Duration(seconds: 10)); // past the retry throttle
        connectivity.add(true);

        await expectPhase(ConnectionPhase.online);
        expect(resubscribes, 1);
      },
    );

    test(
      'an automatic retry during a verify defers instead of piling on',
      () async {
        probe.probeResult = false;
        probe.probeDelay = const Duration(milliseconds: 100);
        build().start();

        unawaited(health.retryNow(manual: true));
        await settle(const Duration(milliseconds: 20));
        expect(probe.probeCalls, 1);

        clock.advance(const Duration(seconds: 5));
        await health.retryNow(manual: false);
        await settle(const Duration(milliseconds: 20));

        expect(
          probe.probeCalls,
          1,
          reason:
              'an OS nudge has no more to say than the probe already running',
        );
        await settle(const Duration(milliseconds: 120));
      },
    );
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
