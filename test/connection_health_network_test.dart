import 'dart:async';
import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:monkeyhub/backend/connection_health.dart';
import 'package:monkeyhub/backend/signaling_status.dart';

/// Network-change handling: the Wi-Fi ↔ cellular handover.
///
/// A socket is bound to the interface it was opened on; when that interface
/// goes, the socket is dead whether or not anything says so. These pin the
/// response — rebuild on sight, once per settled change, never on noise.
class _Probe implements ConnectionProbe {
  final _ctrl = StreamController<bool>.broadcast();
  bool connected = true;
  bool probeResult = true;
  final List<String> calls = [];

  @override
  bool get isConnected => connected;

  @override
  Stream<bool> get connectionState => _ctrl.stream;

  @override
  Future<bool> probeConnection({Duration timeout = Duration.zero}) async {
    calls.add('probe');
    return probeResult;
  }

  @override
  Future<bool> reconnect() async {
    calls.add('reconnect');
    return true;
  }

  Future<void> close() => _ctrl.close();
}

const _settleNet = Duration(milliseconds: 15);

void main() {
  late _Probe probe;
  late StreamController<Set<String>> ifaces;
  late SignalingStatus signaling;
  late ConnectionHealth health;
  var inCall = false;

  ConnectionHealth build() => health = ConnectionHealth(
    backend: probe,
    onReconnected: () async {},
    isActive: () => true,
    graceDelay: const Duration(milliseconds: 20),
    stalledAfter: const Duration(milliseconds: 60),
    firstProbeTimeout: const Duration(milliseconds: 5),
    probeTimeout: const Duration(milliseconds: 5),
    backoff: const [Duration(milliseconds: 10)],
    rebuildTimeout: const Duration(milliseconds: 5),
    minLoopInterval: const Duration(milliseconds: 10),
    offlineGrace: const Duration(milliseconds: 6),
    networkSettle: _settleNet,
    healInBackground: () => inCall,
    signaling: signaling,
    interfaces: ifaces.stream,
  );

  Future<void> settle([Duration d = const Duration(milliseconds: 40)]) =>
      Future<void>.delayed(d);

  setUp(() {
    probe = _Probe();
    ifaces = StreamController<Set<String>>.broadcast();
    signaling = SignalingStatus();
    inCall = false;
  });

  tearDown(() async {
    health.dispose();
    await probe.close();
    await ifaces.close();
  });

  /// Starts the monitor on Wi-Fi and forgets the baseline's own nudge.
  Future<void> startOnWifi() async {
    build().start();
    ifaces.add({'wifi'});
    await settle();
    probe.calls.clear();
  }

  test('Wi-Fi → cellular rebuilds the transport before probing', () async {
    await startOnWifi();

    ifaces.add({'mobile'});
    await settle();

    expect(
      probe.calls.take(2),
      ['reconnect', 'probe'],
      reason: 'a probe on a socket bound to the departed Wi-Fi can only '
          'time out — that wait was ~37s of dead signaling mid-call',
    );
    expect(probe.calls.where((c) => c == 'reconnect'), hasLength(1));
    expect(signaling.networkEpoch, 1);
    expect(health.phase, ConnectionPhase.online);
  });

  test('cellular → Wi-Fi rebuilds too', () async {
    build().start();
    ifaces.add({'mobile'});
    await settle();
    probe.calls.clear();

    ifaces.add({'wifi'});
    await settle();

    expect(probe.calls.first, 'reconnect');
    expect(signaling.networkEpoch, 1);
  });

  test('a handover burst settles into exactly one rebuild', () async {
    await startOnWifi();

    ifaces.add({'none'});
    ifaces.add({'wifi', 'mobile'});
    ifaces.add({'mobile'});
    await settle(const Duration(milliseconds: 60));

    expect(probe.calls.where((c) => c == 'reconnect'), hasLength(1));
    expect(signaling.networkEpoch, 1);
  });

  test('the same network again never rebuilds', () async {
    await startOnWifi();

    // An unlock's burst, and a flicker through `none` back to the same Wi-Fi.
    ifaces.add({'wifi'});
    ifaces.add({'wifi'});
    ifaces.add({'none'});
    await settle(const Duration(milliseconds: 2));
    ifaces.add({'wifi'});
    await settle(const Duration(milliseconds: 60));

    expect(probe.calls, isNot(contains('reconnect')));
    expect(signaling.networkEpoch, 0);
  });

  test('an interface merely appearing does not rebuild', () async {
    await startOnWifi();

    // Cellular coming up beside a working Wi-Fi leaves the Wi-Fi socket alive.
    ifaces.add({'wifi', 'mobile'});
    await settle(const Duration(milliseconds: 60));

    expect(probe.calls, isNot(contains('reconnect')));
    expect(signaling.networkEpoch, 0);
  });

  test('a VPN dropping counts as the network moving', () async {
    build().start();
    ifaces.add({'wifi', 'vpn'});
    await settle();
    probe.calls.clear();

    ifaces.add({'wifi'});
    await settle();

    expect(probe.calls.first, 'reconnect');
  });

  group('in the background', () {
    test('recovery parks without a call', () async {
      await startOnWifi();
      health.setForeground(false);

      ifaces.add({'mobile'});
      await settle();

      expect(probe.calls, isEmpty, reason: 'nothing to heal for while parked');
      // Still recorded, so the call services hear about it if one starts.
      expect(signaling.networkEpoch, 1);

      // And the rebuild is owed, not forgotten: it runs on return.
      health.setForeground(true);
      await settle();
      expect(probe.calls.first, 'reconnect');
    });

    test('recovery keeps running during a call', () async {
      await startOnWifi();
      inCall = true;
      health.setForeground(false);

      ifaces.add({'mobile'});
      await settle();

      expect(
        probe.calls.take(2),
        ['reconnect', 'probe'],
        reason: 'a call with the screen off must still be able to send its '
            'own ICE restart',
      );
    });
  });

  group('SignalingStatus', () {
    test('a healing episode is down until a probe says otherwise', () async {
      probe.probeResult = false;
      build().start();
      ifaces.add({'wifi'});
      await settle();
      expect(signaling.isDown, isTrue);
      final edges = signaling.upEdges;

      probe.probeResult = true;
      await health.retryNow();
      await settle();

      expect(signaling.isDown, isFalse);
      expect(signaling.upEdges, edges + 1);
    });
  });

  group('jittered', () {
    test('stays inside ±fraction and actually varies', () {
      final rng = math.Random(7);
      const base = Duration(seconds: 10);
      final seen = <int>{};
      for (var i = 0; i < 200; i++) {
        final d = ConnectionHealth.jittered(base, 0.2, rng);
        expect(d.inMilliseconds, inInclusiveRange(8000, 12000));
        seen.add(d.inMilliseconds);
      }
      expect(seen.length, greaterThan(50));
    });

    test('zero fraction is the identity', () {
      expect(
        ConnectionHealth.jittered(
          const Duration(seconds: 4),
          0,
          math.Random(1),
        ),
        const Duration(seconds: 4),
      );
    });
  });
}
