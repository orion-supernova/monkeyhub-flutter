import 'dart:async';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monkeyhub/models/location_share.dart';
import 'package:monkeyhub/services/live_location_publisher.dart';
import 'package:monkeyhub/services/location_service.dart';

/// The publisher is the one piece of this feature that spends battery, so what
/// it is pinned on is what it *refuses* to do: publish faster than the ceiling,
/// keep publishing past the deadline, keep publishing after the server says the
/// share is over, and — the subtle one — pass off a cached position as a
/// current one on a heartbeat.
///
/// No GPS anywhere. [_FakeLocationService] hands out whatever the test feeds it,
/// and time is `fake_async`, so the whole file runs in microseconds.
class _FakeLocationService extends LocationService {
  _FakeLocationService();

  final StreamController<LocationFix> controller =
      StreamController<LocationFix>.broadcast();

  /// What the next [currentFix] returns — i.e. what a heartbeat measures.
  LocationFix? nextFix;

  int currentFixCalls = 0;

  @override
  Stream<LocationFix> fixStream({double distanceFilterMeters = 25}) =>
      controller.stream;

  @override
  Future<LocationFix?> currentFix({Duration timeout = const Duration(seconds: 15)}) async {
    currentFixCalls++;
    return nextFix;
  }
}

void main() {
  final t0 = DateTime.utc(2026, 8, 9, 14, 0);

  LocationFix fix(double lat, double lng, {DateTime? at}) => LocationFix(
        latitude: lat,
        longitude: lng,
        accuracyM: 10,
        timestamp: at ?? t0,
      );

  test('the first fix is treated as already published', () {
    fakeAsync((async) {
      final svc = _FakeLocationService();
      var now = t0;
      final pub = LiveLocationPublisher(service: svc, clock: () => now);
      final sent = <LocationFix>[];

      pub.start(
        messageId: 'm1',
        roomId: 'r1',
        expiresAt: t0.add(const Duration(hours: 1)),
        firstFix: fix(41, 29),
        publish: (f) async {
          sent.add(f);
          return true;
        },
      );
      async.flushMicrotasks();

      // `messages:send` already wrote this exact position onto the row, so
      // re-sending it would be a redundant write on the very first tick.
      expect(sent, isEmpty);
      expect(pub.isRunning, isTrue);
      expect(pub.activeMessageId, 'm1');
      pub.stop();
      async.flushMicrotasks();
    });
  });

  test('a second fix inside the interval ceiling is dropped', () {
    fakeAsync((async) {
      final svc = _FakeLocationService();
      var now = t0;
      final pub = LiveLocationPublisher(service: svc, clock: () => now);
      final sent = <LocationFix>[];

      pub.start(
        messageId: 'm1',
        roomId: 'r1',
        expiresAt: t0.add(const Duration(hours: 1)),
        firstFix: fix(41, 29),
        publish: (f) async {
          sent.add(f);
          return true;
        },
      );
      async.flushMicrotasks();

      // The OS filter is a DISTANCE, so at speed it fires roughly once a
      // second. Without the ceiling a drive would be hundreds of writes to one
      // message row.
      now = t0.add(const Duration(seconds: 2));
      svc.controller.add(fix(41.001, 29));
      async.flushMicrotasks();
      expect(sent, isEmpty, reason: '2s < kLiveMinPublishInterval');

      now = t0.add(kLiveMinPublishInterval + const Duration(seconds: 1));
      svc.controller.add(fix(41.002, 29));
      async.flushMicrotasks();
      expect(sent, hasLength(1));

      pub.stop();
      async.flushMicrotasks();
    });
  });

  test('it stops itself at the deadline without being told', () {
    fakeAsync((async) {
      final svc = _FakeLocationService();
      var now = t0;
      final pub = LiveLocationPublisher(service: svc, clock: () => now);
      final sent = <LocationFix>[];

      pub.start(
        messageId: 'm1',
        roomId: 'r1',
        expiresAt: t0.add(const Duration(minutes: 15)),
        firstFix: fix(41, 29),
        publish: (f) async {
          sent.add(f);
          return true;
        },
      );
      async.flushMicrotasks();

      now = t0.add(const Duration(minutes: 15));
      svc.controller.add(fix(41.01, 29));
      async.flushMicrotasks();

      expect(sent, isEmpty, reason: 'a fix at the deadline is not published');
      expect(pub.isRunning, isFalse, reason: 'and the publisher shuts down');
    });
  });

  test('a server "no" shuts the publisher down rather than retrying', () {
    fakeAsync((async) {
      final svc = _FakeLocationService();
      var now = t0;
      final pub = LiveLocationPublisher(service: svc, clock: () => now);
      var attempts = 0;

      pub.start(
        messageId: 'm1',
        roomId: 'r1',
        expiresAt: t0.add(const Duration(hours: 8)),
        firstFix: fix(41, 29),
        // The share ended somewhere else — stopped from the user's other
        // device, or expired server-side. This false is how that reaches this
        // object, with nothing polling for it.
        publish: (_) async {
          attempts++;
          return false;
        },
      );
      async.flushMicrotasks();

      now = t0.add(const Duration(minutes: 1));
      svc.controller.add(fix(41.01, 29));
      async.flushMicrotasks();
      expect(attempts, 1);
      expect(pub.isRunning, isFalse);

      // And nothing more is attempted, because the stream subscription is gone.
      now = t0.add(const Duration(minutes: 2));
      svc.controller.add(fix(41.02, 29));
      async.flushMicrotasks();
      expect(attempts, 1);
    });
  });

  test('the heartbeat measures again instead of re-sending the cached fix', () {
    fakeAsync((async) {
      final svc = _FakeLocationService();
      var now = t0;
      final pub = LiveLocationPublisher(service: svc, clock: () => now);
      final sent = <LocationFix>[];

      pub.start(
        messageId: 'm1',
        roomId: 'r1',
        expiresAt: t0.add(const Duration(hours: 1)),
        firstFix: fix(41, 29),
        publish: (f) async {
          sent.add(f);
          return true;
        },
      );
      async.flushMicrotasks();

      // A stationary phone produces no stream events at all — that is what the
      // distance filter is for — so this is the only thing keeping the share
      // from looking dead. It must publish a NEW reading: re-sending the cached
      // one with a fresh timestamp would tell every viewer "this is where they
      // are now" on the strength of an hour-old measurement.
      svc.nextFix = fix(41.5, 29.5, at: t0.add(kLiveHeartbeat));
      now = t0.add(kLiveHeartbeat);
      async.elapse(kLiveHeartbeat);
      async.flushMicrotasks();

      expect(svc.currentFixCalls, 1);
      expect(sent, hasLength(1));
      expect(sent.single.latitude, 41.5);

      pub.stop();
      async.flushMicrotasks();
    });
  });

  test('a heartbeat that cannot get a fix publishes nothing', () {
    fakeAsync((async) {
      final svc = _FakeLocationService()..nextFix = null;
      var now = t0;
      final pub = LiveLocationPublisher(service: svc, clock: () => now);
      final sent = <LocationFix>[];

      pub.start(
        messageId: 'm1',
        roomId: 'r1',
        expiresAt: t0.add(const Duration(hours: 1)),
        firstFix: fix(41, 29),
        publish: (f) async {
          sent.add(f);
          return true;
        },
      );
      async.flushMicrotasks();

      now = t0.add(kLiveHeartbeat);
      async.elapse(kLiveHeartbeat);
      async.flushMicrotasks();

      // Silence is the correct signal. Viewers see the share go stale, which is
      // exactly what has happened — better than a position nobody can vouch for.
      expect(sent, isEmpty);
      expect(pub.isRunning, isTrue, reason: 'one bad fix is not the end');

      pub.stop();
      async.flushMicrotasks();
    });
  });

  test('starting a second share supersedes the first', () {
    fakeAsync((async) {
      final svc = _FakeLocationService();
      var now = t0;
      final pub = LiveLocationPublisher(service: svc, clock: () => now);

      pub.start(
        messageId: 'm1',
        roomId: 'r1',
        expiresAt: t0.add(const Duration(hours: 1)),
        firstFix: fix(41, 29),
        publish: (_) async => true,
      );
      async.flushMicrotasks();
      expect(pub.isRunningFor('m1'), isTrue);

      pub.start(
        messageId: 'm2',
        roomId: 'r2',
        expiresAt: t0.add(const Duration(hours: 1)),
        firstFix: fix(41, 29),
        publish: (_) async => true,
      );
      async.flushMicrotasks();

      // One publisher, one share: two would be two GPS consumers and two write
      // streams for a user who can only be in one place.
      expect(pub.isRunningFor('m1'), isFalse);
      expect(pub.isRunningFor('m2'), isTrue);
      expect(pub.activeRoomId, 'r2');

      pub.stop();
      async.flushMicrotasks();
    });
  });

  test('stopping the publisher does not itself end the share', () {
    fakeAsync((async) {
      final svc = _FakeLocationService();
      var now = t0;
      final pub = LiveLocationPublisher(service: svc, clock: () => now);
      var published = 0;

      pub.start(
        messageId: 'm1',
        roomId: 'r1',
        expiresAt: t0.add(const Duration(hours: 1)),
        firstFix: fix(41, 29),
        publish: (_) async {
          published++;
          return true;
        },
      );
      async.flushMicrotasks();
      pub.stop();
      async.flushMicrotasks();

      // Ending a share is a server call. Tearing this down happens for reasons
      // that are none of the share's business — the screen closing, the app
      // shutting down — and must not silently make somebody unfindable.
      expect(published, 0);
      expect(pub.isRunning, isFalse);
    });
  });
}
