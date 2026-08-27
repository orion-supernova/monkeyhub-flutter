import 'dart:math' as math;

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monkeyhub/backend/call_api.dart';
import 'package:monkeyhub/backend/convex_client.dart';
import 'package:monkeyhub/calls/call_service.dart';

/// The 1:1 in-call heartbeat cadence. Both peers start beating the instant
/// their PC connects and used to share one fixed `Timer.periodic` — phase-
/// locked for the whole call, so every beat was two writes to the same
/// `calls` row inside one OCC window and the backend retried one of them on
/// every cycle. These tests pin the replacement: each beat's delay is
/// interval + a fresh draw of up to jitter, chained by one-shot timers that a
/// cancel (here: dispose) drops.
class _FakeSubscription extends Fake implements Subscription {
  @override
  void cancel() {}
}

/// Only what [CallService.attach] touches plus the beat itself; anything
/// else the service reaches for is a test failure worth seeing.
class _RecordingApi extends Fake implements CallApi {
  int beats = 0;

  @override
  Future<String?> heartbeat({
    required String callId,
    required String userId,
  }) async {
    beats++;
    return 'ok';
  }

  @override
  Future<List<Map<String, dynamic>>> getIceConfig(String userId) async =>
      const [];

  @override
  Future<Subscription> subscribeActiveCall({
    required String userId,
    required void Function(Map<String, dynamic>? call) onCall,
    void Function(Object error)? onError,
  }) async =>
      _FakeSubscription();
}

CallService _newService(_RecordingApi api) {
  final service = CallService(api: api);
  service.attach(userId: 'me', displayName: 'Me');
  return service;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('CallService.heartbeatDelay', () {
    test('is exactly the interval when jitter is zero', () {
      final rng = math.Random(1);
      for (var i = 0; i < 100; i++) {
        expect(
          CallService.heartbeatDelay(
            const Duration(seconds: 20),
            Duration.zero,
            rng,
          ),
          const Duration(seconds: 20),
        );
      }
    });

    test('draws every beat from [interval, interval + jitter)', () {
      const interval = Duration(seconds: 20);
      const jitter = Duration(seconds: 4);
      final rng = math.Random(1);
      final seen = <Duration>{};
      for (var i = 0; i < 2000; i++) {
        final d = CallService.heartbeatDelay(interval, jitter, rng);
        expect(d, greaterThanOrEqualTo(interval));
        expect(d, lessThan(interval + jitter));
        seen.add(d);
      }
      // Actually jittered: a fixed delay is what phase-locks the peers.
      expect(seen.length, greaterThan(100));
    });
  });

  group('CallService heartbeat schedule', () {
    test('beats on the seeded interval + jitter schedule, one draw per beat',
        () {
      fakeAsync((async) {
        final api = _RecordingApi();
        final service = _newService(api)
          ..heartbeatInterval = const Duration(seconds: 1)
          ..heartbeatJitter = const Duration(milliseconds: 500)
          ..heartbeatRng = math.Random(7);
        // The same seed replayed here yields the delays the service drew.
        final replay = math.Random(7);
        Duration next() =>
            const Duration(seconds: 1) +
            Duration(milliseconds: replay.nextInt(500));

        service.debugStartHeartbeat('c1');
        var due = Duration.zero;
        for (var n = 1; n <= 5; n++) {
          final delay = next();
          async.elapse(delay - const Duration(milliseconds: 1));
          async.flushMicrotasks();
          expect(api.beats, n - 1, reason: 'beat $n fired early');
          async.elapse(const Duration(milliseconds: 1));
          async.flushMicrotasks();
          expect(api.beats, n, reason: 'beat $n did not fire on time');
          due += delay;
        }
        expect(async.elapsed, due);
        service.dispose();
      });
    });

    test('a fresh start replaces the chain instead of stacking beats', () {
      fakeAsync((async) {
        final api = _RecordingApi();
        final service = _newService(api)
          ..heartbeatInterval = const Duration(seconds: 1)
          ..heartbeatJitter = Duration.zero;

        service.debugStartHeartbeat('c1');
        async.elapse(const Duration(milliseconds: 600));
        // Reconnect: restarts against the same call.
        service.debugStartHeartbeat('c1');
        async.elapse(const Duration(milliseconds: 600));
        async.flushMicrotasks();
        // The first chain's 1s beat (due at 1.0s) must NOT have fired.
        expect(api.beats, 0);
        async.elapse(const Duration(milliseconds: 400));
        async.flushMicrotasks();
        expect(api.beats, 1);
        async.elapse(const Duration(seconds: 3));
        async.flushMicrotasks();
        // One beat per second from the restart, not two chains' worth.
        expect(api.beats, 4);
        service.dispose();
      });
    });

    test('dispose drops the chain', () {
      fakeAsync((async) {
        final api = _RecordingApi();
        final service = _newService(api)
          ..heartbeatInterval = const Duration(seconds: 1)
          ..heartbeatJitter = Duration.zero;

        service.debugStartHeartbeat('c1');
        async.elapse(const Duration(seconds: 2));
        async.flushMicrotasks();
        expect(api.beats, 2);
        service.dispose();
        async.elapse(const Duration(seconds: 10));
        async.flushMicrotasks();
        expect(api.beats, 2);
      });
    });
  });
}
