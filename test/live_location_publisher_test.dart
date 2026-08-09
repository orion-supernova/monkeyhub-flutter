import 'dart:async';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monkeyhub/models/location_share.dart';
import 'package:monkeyhub/services/live_location_platform.dart';
import 'package:monkeyhub/services/live_location_publisher.dart';
import 'package:monkeyhub/services/live_share_resume_store.dart';
import 'package:monkeyhub/services/location_service.dart';

/// The publisher is the one piece of this feature that spends battery, so what
/// it is pinned on is what it *refuses* to do: publish faster than the ceiling,
/// keep publishing past the deadline, keep publishing after the server says the
/// share is over, and — the subtle one — pass off a cached position as a
/// current one on a heartbeat.
///
/// Since background sharing there is a second thing to pin, and it is the one
/// that cannot be checked on a device without a stopwatch and a battery meter:
/// that the power tier actually changes when the app leaves the screen, that it
/// changes back, and that the freshness contract does NOT change with it.
///
/// And a third: resume. Everything about surviving termination is untestable
/// here — no OS relaunches a Dart test — but the DECISION to resume is pure
/// logic over a persisted handle and a clock, and that is what the tests at the
/// bottom pin. A share that resumed after its deadline would be this feature's
/// worst bug, and it is exactly the one a unit test can catch.
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

  /// Every mode the publisher has opened a stream at, in order. The record of
  /// the OS-level settings changing, which is the only externally visible
  /// evidence that a tier switch did anything.
  final List<LiveLocationMode> streamModes = [];

  /// Every precision a heartbeat has asked for.
  final List<LocationPrecision> heartbeatPrecisions = [];

  @override
  Stream<LocationFix> fixStream({
    LiveLocationMode mode = LiveLocationMode.foreground,
  }) {
    streamModes.add(mode);
    return controller.stream;
  }

  @override
  Future<LocationFix?> currentFix({
    Duration timeout = const Duration(seconds: 15),
    LocationPrecision precision = LocationPrecision.fine,
  }) async {
    currentFixCalls++;
    heartbeatPrecisions.add(precision);
    return nextFix;
  }
}

/// An in-memory stand-in for the on-disk handle. Synchronous underneath so a
/// test can assert on [saved] without draining a platform channel that isn't
/// there.
class _FakeResumeStore extends LiveShareResumeStore {
  LiveShareHandle? saved;
  int clears = 0;

  @override
  Future<void> save(LiveShareHandle handle) async => saved = handle;

  @override
  Future<LiveShareHandle?> load() async => saved;

  @override
  Future<void> clear() async {
    clears++;
    saved = null;
  }
}

class _FakePlatform extends LiveLocationPlatform {
  int starts = 0;
  int stops = 0;
  bool? lastSignificantChanges;

  @override
  Future<void> startSharing({
    required String messageId,
    required String roomId,
    required int expiresAtMs,
    required String notificationTitle,
    required String notificationBody,
    required String stopActionLabel,
    required bool monitorSignificantChanges,
  }) async {
    starts++;
    lastSignificantChanges = monitorSignificantChanges;
  }

  @override
  Future<void> stopSharing() async => stops++;
}

void main() {
  final t0 = DateTime.utc(2026, 8, 9, 14, 0);

  const notice = LiveShareNotice(
    title: 'Sharing your live location',
    body: 'Tap to open the chat, or Stop to end it now',
    stopLabel: 'Stop sharing',
  );

  LocationFix fix(double lat, double lng, {DateTime? at}) => LocationFix(
        latitude: lat,
        longitude: lng,
        accuracyM: 10,
        timestamp: at ?? t0,
      );

  /// The publisher plus the three fakes it talks to, built together because no
  /// test wants one without the others.
  ({
    LiveLocationPublisher pub,
    _FakeLocationService svc,
    _FakeResumeStore store,
    _FakePlatform platform,
  }) build(DateTime Function() clock) {
    final svc = _FakeLocationService();
    final store = _FakeResumeStore();
    final platform = _FakePlatform();
    return (
      pub: LiveLocationPublisher(
        service: svc,
        store: store,
        platform: platform,
        clock: clock,
      ),
      svc: svc,
      store: store,
      platform: platform,
    );
  }

  test('the first fix is treated as already published', () {
    fakeAsync((async) {
      var now = t0;
      final h = build(() => now);
      final sent = <LocationFix>[];

      h.pub.start(
        messageId: 'm1',
        roomId: 'r1',
        expiresAt: t0.add(const Duration(hours: 1)),
        firstFix: fix(41, 29),
        notice: notice,
        publish: (f) async {
          sent.add(f);
          return true;
        },
      );
      async.flushMicrotasks();

      // `messages:send` already wrote this exact position onto the row, so
      // re-sending it would be a redundant write on the very first tick.
      expect(sent, isEmpty);
      expect(h.pub.isRunning, isTrue);
      expect(h.pub.activeMessageId, 'm1');
      h.pub.stop();
      async.flushMicrotasks();
    });
  });

  test('a second fix inside the interval ceiling is dropped', () {
    fakeAsync((async) {
      var now = t0;
      final h = build(() => now);
      final sent = <LocationFix>[];

      h.pub.start(
        messageId: 'm1',
        roomId: 'r1',
        expiresAt: t0.add(const Duration(hours: 1)),
        firstFix: fix(41, 29),
        notice: notice,
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
      h.svc.controller.add(fix(41.001, 29));
      async.flushMicrotasks();
      expect(sent, isEmpty, reason: '2s < kLiveMinPublishInterval');

      now = t0.add(kLiveMinPublishInterval + const Duration(seconds: 1));
      h.svc.controller.add(fix(41.002, 29));
      async.flushMicrotasks();
      expect(sent, hasLength(1));

      h.pub.stop();
      async.flushMicrotasks();
    });
  });

  test('it stops itself at the deadline without being told', () {
    fakeAsync((async) {
      var now = t0;
      final h = build(() => now);
      final sent = <LocationFix>[];

      h.pub.start(
        messageId: 'm1',
        roomId: 'r1',
        expiresAt: t0.add(const Duration(minutes: 15)),
        firstFix: fix(41, 29),
        notice: notice,
        publish: (f) async {
          sent.add(f);
          return true;
        },
      );
      async.flushMicrotasks();

      now = t0.add(const Duration(minutes: 15));
      h.svc.controller.add(fix(41.01, 29));
      async.flushMicrotasks();

      expect(sent, isEmpty, reason: 'a fix at the deadline is not published');
      expect(h.pub.isRunning, isFalse, reason: 'and the publisher shuts down');
      // And nothing is left on disk for the next launch to pick up: an expired
      // share is finished, not paused.
      expect(h.store.saved, isNull);
      expect(h.platform.stops, 1, reason: 'the notification goes with it');
    });
  });

  test('a server "no" shuts the publisher down rather than retrying', () {
    fakeAsync((async) {
      var now = t0;
      final h = build(() => now);
      var attempts = 0;

      h.pub.start(
        messageId: 'm1',
        roomId: 'r1',
        expiresAt: t0.add(const Duration(hours: 8)),
        firstFix: fix(41, 29),
        notice: notice,
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
      h.svc.controller.add(fix(41.01, 29));
      async.flushMicrotasks();
      expect(attempts, 1);
      expect(h.pub.isRunning, isFalse);
      expect(h.store.saved, isNull, reason: 'nothing left to resume');

      // And nothing more is attempted, because the stream subscription is gone.
      now = t0.add(const Duration(minutes: 2));
      h.svc.controller.add(fix(41.02, 29));
      async.flushMicrotasks();
      expect(attempts, 1);
    });
  });

  test('the heartbeat measures again instead of re-sending the cached fix', () {
    fakeAsync((async) {
      var now = t0;
      final h = build(() => now);
      final sent = <LocationFix>[];

      h.pub.start(
        messageId: 'm1',
        roomId: 'r1',
        expiresAt: t0.add(const Duration(hours: 1)),
        firstFix: fix(41, 29),
        notice: notice,
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
      h.svc.nextFix = fix(41.5, 29.5, at: t0.add(kLiveHeartbeat));
      now = t0.add(kLiveHeartbeat);
      async.elapse(kLiveHeartbeat);
      async.flushMicrotasks();

      expect(h.svc.currentFixCalls, 1);
      expect(sent, hasLength(1));
      expect(sent.single.latitude, 41.5);

      h.pub.stop();
      async.flushMicrotasks();
    });
  });

  test('a heartbeat that cannot get a fix publishes nothing', () {
    fakeAsync((async) {
      var now = t0;
      final h = build(() => now);
      h.svc.nextFix = null;
      final sent = <LocationFix>[];

      h.pub.start(
        messageId: 'm1',
        roomId: 'r1',
        expiresAt: t0.add(const Duration(hours: 1)),
        firstFix: fix(41, 29),
        notice: notice,
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
      expect(h.pub.isRunning, isTrue, reason: 'one bad fix is not the end');

      h.pub.stop();
      async.flushMicrotasks();
    });
  });

  test('starting a second share supersedes the first', () {
    fakeAsync((async) {
      var now = t0;
      final h = build(() => now);

      h.pub.start(
        messageId: 'm1',
        roomId: 'r1',
        expiresAt: t0.add(const Duration(hours: 1)),
        firstFix: fix(41, 29),
        notice: notice,
        publish: (_) async => true,
      );
      async.flushMicrotasks();
      expect(h.pub.isRunningFor('m1'), isTrue);

      h.pub.start(
        messageId: 'm2',
        roomId: 'r2',
        expiresAt: t0.add(const Duration(hours: 1)),
        firstFix: fix(41, 29),
        notice: notice,
        publish: (_) async => true,
      );
      async.flushMicrotasks();

      // One publisher, one share: two would be two GPS consumers and two write
      // streams for a user who can only be in one place.
      expect(h.pub.isRunningFor('m1'), isFalse);
      expect(h.pub.isRunningFor('m2'), isTrue);
      expect(h.pub.activeRoomId, 'r2');
      // And one handle, pointing at the survivor. A stale second handle would
      // have a rebooted device resume the share the user just replaced.
      expect(h.store.saved?.messageId, 'm2');

      h.pub.stop();
      async.flushMicrotasks();
    });
  });

  test('stopping the publisher does not itself end the share', () {
    fakeAsync((async) {
      var now = t0;
      final h = build(() => now);
      var published = 0;

      h.pub.start(
        messageId: 'm1',
        roomId: 'r1',
        expiresAt: t0.add(const Duration(hours: 1)),
        firstFix: fix(41, 29),
        notice: notice,
        publish: (_) async {
          published++;
          return true;
        },
      );
      async.flushMicrotasks();
      h.pub.stop();
      async.flushMicrotasks();

      // Ending a share is a server call. Tearing this down happens for reasons
      // that are none of the share's business — the screen closing, the app
      // shutting down — and must not silently make somebody unfindable.
      expect(published, 0);
      expect(h.pub.isRunning, isFalse);
      // And the handle SURVIVES: a plain stop is this process letting go, not
      // the share ending, so the next launch picks it back up.
      expect(h.store.saved?.messageId, 'm1');
      expect(h.store.clears, 0);
    });
  });

  test('stop(forget: true) is what erases the handle', () {
    fakeAsync((async) {
      var now = t0;
      final h = build(() => now);

      h.pub.start(
        messageId: 'm1',
        roomId: 'r1',
        expiresAt: t0.add(const Duration(hours: 1)),
        firstFix: fix(41, 29),
        notice: notice,
        publish: (_) async => true,
      );
      async.flushMicrotasks();
      h.pub.stop(forget: true);
      async.flushMicrotasks();

      expect(h.store.saved, isNull);
      expect(h.store.clears, 1);
    });
  });

  group('background tuning', () {
    test('backgrounding raises the filter and the interval ceiling', () {
      fakeAsync((async) {
        var now = t0;
        final h = build(() => now);
        final sent = <LocationFix>[];

        h.pub.start(
          messageId: 'm1',
          roomId: 'r1',
          expiresAt: t0.add(const Duration(hours: 8)),
          firstFix: fix(41, 29),
          notice: notice,
          publish: (f) async {
            sent.add(f);
            return true;
          },
        );
        async.flushMicrotasks();
        expect(h.svc.streamModes, [LiveLocationMode.foreground]);

        h.pub.setAppVisible(false);
        async.flushMicrotasks();
        expect(h.pub.mode, LiveLocationMode.background);
        // Re-opened, not merely re-labelled. Neither platform lets a running
        // location request change its distance filter, so the only way a tier
        // switch reaches the OS is a new stream.
        expect(h.svc.streamModes, [
          LiveLocationMode.foreground,
          LiveLocationMode.background,
        ]);

        // 15 s cleared the foreground ceiling and does not clear the background
        // one: this is the whole saving, six writes a minute becoming two.
        now = t0.add(const Duration(seconds: 15));
        h.svc.controller.add(fix(41.01, 29));
        async.flushMicrotasks();
        expect(sent, isEmpty);

        now = t0.add(const Duration(seconds: 31));
        h.svc.controller.add(fix(41.02, 29));
        async.flushMicrotasks();
        expect(sent, hasLength(1));

        h.pub.stop();
        async.flushMicrotasks();
      });
    });

    test('twenty minutes backgrounded drops to coarse fixes', () {
      fakeAsync((async) {
        var now = t0;
        final h = build(() => now);

        h.pub.start(
          messageId: 'm1',
          roomId: 'r1',
          expiresAt: t0.add(const Duration(hours: 8)),
          firstFix: fix(41, 29),
          notice: notice,
          publish: (_) async => true,
        );
        async.flushMicrotasks();

        h.pub.setAppVisible(false);
        async.elapse(kLiveDeepBackgroundAfter - const Duration(seconds: 1));
        now = t0.add(kLiveDeepBackgroundAfter - const Duration(seconds: 1));
        async.flushMicrotasks();
        expect(h.pub.mode, LiveLocationMode.background,
            reason: 'still fine a second before the threshold');

        async.elapse(const Duration(seconds: 2));
        now = t0.add(kLiveDeepBackgroundAfter + const Duration(seconds: 1));
        async.flushMicrotasks();
        expect(h.pub.mode, LiveLocationMode.deepBackground);
        expect(h.svc.streamModes.last, LiveLocationMode.deepBackground);
        expect(h.pub.mode.precision, LocationPrecision.coarse);

        // And the heartbeat follows the tier down: a coarse fix answered from
        // cell and Wi-Fi rather than a GPS lock. It publishes a wider
        // `accuracyM`, which the bubble draws as a wider ring — honest about
        // the precision it stopped paying for.
        h.svc.nextFix = fix(41.1, 29.1);
        async.elapse(kLiveHeartbeat);
        async.flushMicrotasks();
        expect(h.svc.heartbeatPrecisions.last, LocationPrecision.coarse);

        h.pub.stop();
        async.flushMicrotasks();
      });
    });

    test('coming back to the app restores the baseline at once', () {
      fakeAsync((async) {
        var now = t0;
        final h = build(() => now);

        h.pub.start(
          messageId: 'm1',
          roomId: 'r1',
          expiresAt: t0.add(const Duration(hours: 8)),
          firstFix: fix(41, 29),
          notice: notice,
          publish: (_) async => true,
        );
        async.flushMicrotasks();

        h.pub.setAppVisible(false);
        async.elapse(kLiveDeepBackgroundAfter + const Duration(minutes: 5));
        async.flushMicrotasks();
        expect(h.pub.mode, LiveLocationMode.deepBackground);

        h.pub.setAppVisible(true);
        async.flushMicrotasks();
        expect(h.pub.mode, LiveLocationMode.foreground,
            reason: 'no gradual climb back — the user is looking at it');

        // The deep-background timer is re-armed from scratch, not resumed. Half
        // the threshold after a fresh backgrounding must not trip it just
        // because the app was away for half an hour earlier.
        h.pub.setAppVisible(false);
        async.elapse(kLiveDeepBackgroundAfter ~/ 2);
        async.flushMicrotasks();
        expect(h.pub.mode, LiveLocationMode.background);

        h.pub.stop();
        async.flushMicrotasks();
      });
    });

    test('the heartbeat cadence is the same in every mode', () {
      fakeAsync((async) {
        var now = t0;
        final h = build(() => now);
        final sent = <LocationFix>[];

        h.pub.start(
          messageId: 'm1',
          roomId: 'r1',
          expiresAt: t0.add(const Duration(hours: 8)),
          firstFix: fix(41, 29),
          notice: notice,
          publish: (f) async {
            sent.add(f);
            return true;
          },
        );
        async.flushMicrotasks();
        h.pub.setAppVisible(false);

        // Six heartbeats over nine minutes, backgrounded throughout — the same
        // six a foregrounded share would produce. This is the contract that
        // makes `kLiveStaleAfter` mean one thing rather than three: a viewer has
        // no idea whether the sharer's app is on screen, so a staleness
        // threshold that quietly relaxed when they pocketed their phone would
        // change the badge's meaning without telling anybody.
        for (var i = 1; i <= 6; i++) {
          h.svc.nextFix = fix(41 + i / 100, 29, at: now);
          now = t0.add(kLiveHeartbeat * i);
          async.elapse(kLiveHeartbeat);
          async.flushMicrotasks();
        }
        expect(h.svc.currentFixCalls, 6);
        expect(sent, hasLength(6));

        h.pub.stop();
        async.flushMicrotasks();
      });
    });

    test('a share started while backgrounded opens at the background tier', () {
      fakeAsync((async) {
        var now = t0;
        final h = build(() => now);

        // The order a background relaunch produces: the app knows it is not
        // visible before it knows there is anything to publish.
        h.pub.setAppVisible(false);
        h.pub.resume(
          handle: LiveShareHandle(
            messageId: 'm1',
            roomId: 'r1',
            expiresAt: t0.add(const Duration(hours: 1)),
            notice: notice,
          ),
          publish: (_) async => true,
        );
        async.flushMicrotasks();

        expect(h.svc.streamModes, [LiveLocationMode.background]);
      });
    });
  });

  group('resume', () {
    LiveShareHandle handle(Duration until) => LiveShareHandle(
          messageId: 'm1',
          roomId: 'r1',
          expiresAt: t0.add(until),
          notice: notice,
        );

    test('it publishes immediately rather than waiting out the ceiling', () {
      fakeAsync((async) {
        var now = t0;
        final h = build(() => now);
        final sent = <LocationFix>[];
        h.svc.nextFix = fix(41.9, 29.9);

        h.pub.resume(
          handle: handle(const Duration(hours: 1)),
          publish: (f) async {
            sent.add(f);
            return true;
          },
        );
        async.flushMicrotasks();

        // The share has been silent for as long as the process was gone and is
        // almost certainly reading STALE to everybody watching. Making it wait
        // another ninety seconds to prove otherwise would be optimising the one
        // moment where latency actually costs something.
        expect(sent, hasLength(1));
        expect(sent.single.latitude, 41.9);
        expect(h.pub.isRunning, isTrue);
        expect(h.pub.activeMessageId, 'm1');
        expect(h.platform.starts, 1,
            reason: 'and the stoppable notification comes back with it');

        h.pub.stop();
        async.flushMicrotasks();
      });
    });

    test('an expired share never resumes', () {
      fakeAsync((async) {
        var now = t0;
        final h = build(() => now);
        var attempts = 0;
        h.svc.nextFix = fix(41.9, 29.9);

        // Left over from a share that ended while the phone was off. The store
        // would normally have erased it, but the publisher checks again anyway:
        // between the disk read and here is an await, and an eight-hour share
        // can expire inside an await if the device slept through the last of it.
        h.pub.resume(
          handle: LiveShareHandle(
            messageId: 'm1',
            roomId: 'r1',
            expiresAt: t0.subtract(const Duration(minutes: 1)),
            notice: notice,
          ),
          publish: (_) async {
            attempts++;
            return true;
          },
        );
        async.flushMicrotasks();

        expect(attempts, 0);
        expect(h.pub.isRunning, isFalse);
        expect(h.platform.starts, 0, reason: 'and no notification is posted');
        expect(h.svc.streamModes, isEmpty, reason: 'and no GPS is spent');
      });
    });

    test('a resumed share the server has ended stops and forgets it', () {
      fakeAsync((async) {
        var now = t0;
        final h = build(() => now);
        h.svc.nextFix = fix(41.9, 29.9);

        // Stopped from the user's other handset while this one was off, or the
        // message deleted, or a different account signed in here. The first
        // mutation is refused and that is the whole correction mechanism — which
        // is why resuming is allowed to be optimistic.
        h.pub.resume(
          handle: handle(const Duration(hours: 1)),
          publish: (_) async => false,
        );
        async.flushMicrotasks();

        expect(h.pub.isRunning, isFalse);
        expect(h.store.clears, greaterThan(0));
        expect(h.store.saved, isNull);
      });
    });

    test('it asks the platform for termination survival only when told to', () {
      fakeAsync((async) {
        var now = t0;
        final h = build(() => now);
        h.svc.nextFix = fix(41.9, 29.9);

        h.pub.resume(
          handle: handle(const Duration(hours: 1)),
          publish: (_) async => true,
          monitorSignificantChanges: true,
        );
        async.flushMicrotasks();
        expect(h.platform.lastSignificantChanges, isTrue);

        h.pub.stop();
        async.flushMicrotasks();

        h.pub.resume(
          handle: handle(const Duration(hours: 1)),
          publish: (_) async => true,
        );
        async.flushMicrotasks();
        // The default, and the ordinary case: a When-In-Use user gets every bit
        // of background publishing and no relaunch. Not a degraded mode.
        expect(h.platform.lastSignificantChanges, isFalse);

        h.pub.stop();
        async.flushMicrotasks();
      });
    });
  });
}
