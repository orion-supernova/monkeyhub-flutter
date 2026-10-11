import 'dart:convert';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monkeyhub/backend/call_api.dart';
import 'package:monkeyhub/backend/convex_client.dart';
import 'package:monkeyhub/calls/call_models.dart';
import 'package:monkeyhub/calls/call_service.dart';

/// The 2026-10-11 ghost ring: a cancelled call kept a MacBook and a Galaxy
/// ringing because the iPhone consumed the per-USER `cancel` row before the
/// slower siblings read it. A device now stops ringing from its own view of
/// the backend: the `activeCallForUser` watch every device holds, a status
/// poll for a ring the watch never showed, and a hard ceiling.

class _FakeSubscription extends Fake implements Subscription {
  @override
  void cancel() {}
}

class _FakeRingApi extends Fake implements CallApi {
  void Function(Map<String, dynamic>? call)? emitActive;

  /// What `getCallStatus` answers; null is a GC'd row.
  String? status = 'ringing';
  int statusPolls = 0;
  final List<String> events = [];

  @override
  Future<Subscription> subscribeActiveCall({
    required String userId,
    required void Function(Map<String, dynamic>? call) onCall,
    void Function(Object error)? onError,
  }) async {
    emitActive = onCall;
    return _FakeSubscription();
  }

  @override
  Future<String?> getCallStatus({
    required String callId,
    required String userId,
  }) async {
    statusPolls++;
    return status;
  }

  @override
  Future<void> markCallRinging({
    required String callId,
    required String userId,
  }) async {}

  @override
  Future<List<Map<String, dynamic>>> getIceConfig(String userId) async =>
      const [];

  @override
  Future<String?> endCall({required String callId, required String userId}) async {
    events.add('end');
    return 'ended';
  }

  @override
  Future<String?> rejectCall({
    required String callId,
    required String userId,
    String? acceptingDeviceId,
  }) async {
    events.add('reject');
    return 'rejected';
  }
}

Map<String, dynamic> _invite(String callId) => {
      '_id': 'invite-$callId',
      'callId': callId,
      'fromUserId': 'peer',
      'kind': 'invite',
      'payload': jsonEncode({'callerName': 'Zeynep', 'type': 'audio'}),
      'createdAt': DateTime.now().millisecondsSinceEpoch,
    };

Map<String, dynamic> _row(
  String callId,
  String status, {
  String? acceptingDeviceId,
}) =>
    {
      '_id': callId,
      'callerId': 'peer',
      'calleeId': 'me',
      'status': status,
      'acceptingDeviceId': acceptingDeviceId,
    };

CallService _newService(_FakeRingApi api) {
  final service = CallService(api: api)
    ..teardownUiHold = Duration.zero
    ..endNativeTimeout = const Duration(milliseconds: 20);
  service.attach(userId: 'me', displayName: 'Me', deviceId: 'mac');
  return service;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('watch-driven dismissal', () {
    test('a ring the watch showed and then dropped stops, with no backend echo',
        () {
      fakeAsync((async) {
        final api = _FakeRingApi();
        final service = _newService(api);
        async.flushMicrotasks();

        service.handleRemoteSignal(_invite('c1'));
        api.emitActive!(_row('c1', 'ringing'));
        async.flushMicrotasks();
        expect(service.session?.status, CallStatus.incomingRinging);

        // The iPhone consumed the cancel; this device never sees it. The
        // watch going empty is enough.
        api.emitActive!(null);
        async.flushMicrotasks();
        expect(service.session?.status, isNot(CallStatus.incomingRinging));
        async.elapse(const Duration(milliseconds: 50));
        expect(service.session, isNull);
        // Remote-settled: nothing told back to the backend.
        expect(api.events, isEmpty);
        service.dispose();
      });
    });

    test('answered on another device stops this one', () {
      fakeAsync((async) {
        final api = _FakeRingApi();
        final service = _newService(api);
        async.flushMicrotasks();

        service.handleRemoteSignal(_invite('c1'));
        api.emitActive!(_row('c1', 'ringing'));
        async.flushMicrotasks();
        api.emitActive!(_row('c1', 'active', acceptingDeviceId: 'iphone'));
        async.elapse(const Duration(milliseconds: 50));
        expect(service.session, isNull);
        service.dispose();
      });
    });

    test('answered HERE leaves the session alone', () {
      fakeAsync((async) {
        final api = _FakeRingApi();
        final service = _newService(api);
        async.flushMicrotasks();

        service.handleRemoteSignal(_invite('c1'));
        api.emitActive!(_row('c1', 'ringing'));
        async.flushMicrotasks();
        api.emitActive!(_row('c1', 'active', acceptingDeviceId: 'mac'));
        async.elapse(const Duration(milliseconds: 50));
        expect(service.session?.callId, 'c1');
        expect(service.session?.status, CallStatus.incomingRinging);
        service.dispose();
      });
    });

    test("the caller's own outgoing call is never touched", () {
      fakeAsync((async) {
        final api = _FakeRingApi();
        final service = _newService(api);
        async.flushMicrotasks();

        // A call I placed rings server-side; the watch going empty is my
        // own call ending, which the caller paths handle themselves.
        api.emitActive!({
          '_id': 'c9',
          'callerId': 'me',
          'calleeId': 'peer',
          'status': 'ringing',
        });
        api.emitActive!(null);
        async.flushMicrotasks();
        expect(api.statusPolls, 0);
        service.dispose();
      });
    });
  });

  group('ring watch', () {
    test('polls, and stops ringing once the backend says the call is over',
        () {
      fakeAsync((async) {
        final api = _FakeRingApi();
        final service = _newService(api)
          ..ringWatchInterval = const Duration(seconds: 4);
        async.flushMicrotasks();

        // The watch never showed this ring (attached late, stalled socket).
        service.handleRemoteSignal(_invite('c1'));
        async.flushMicrotasks();
        async.elapse(const Duration(seconds: 4));
        expect(api.statusPolls, 1);
        expect(service.session?.status, CallStatus.incomingRinging);

        api.status = 'cancelled';
        async.elapse(const Duration(seconds: 4));
        async.elapse(const Duration(milliseconds: 50));
        expect(service.session, isNull);
        service.dispose();
      });
    });

    test('a GC\'d row (null status) counts as over', () {
      fakeAsync((async) {
        final api = _FakeRingApi()..status = null;
        final service = _newService(api);
        async.flushMicrotasks();
        service.handleRemoteSignal(_invite('c1'));
        async.flushMicrotasks();
        async.elapse(service.ringWatchInterval);
        async.elapse(const Duration(milliseconds: 50));
        expect(service.session, isNull);
        service.dispose();
      });
    });

    test('the ceiling ends a ring nothing else could reach', () {
      fakeAsync((async) {
        final api = _FakeRingApi();
        final service = _newService(api);
        async.flushMicrotasks();
        service.handleRemoteSignal(_invite('c1'));
        async.flushMicrotasks();
        // Backend unreachable: every poll throws away its answer.
        api.status = 'ringing';
        async.elapse(service.ringCeiling - const Duration(seconds: 1));
        expect(service.session?.status, CallStatus.incomingRinging);
        async.elapse(const Duration(seconds: 5));
        async.elapse(const Duration(milliseconds: 50));
        expect(service.session, isNull);
        service.dispose();
      });
    });

    test('stops polling once the session leaves ringing', () {
      fakeAsync((async) {
        final api = _FakeRingApi();
        final service = _newService(api);
        async.flushMicrotasks();
        service.handleRemoteSignal(_invite('c1'));
        async.flushMicrotasks();
        service.reject();
        async.elapse(const Duration(milliseconds: 50));
        final polls = api.statusPolls;
        async.elapse(const Duration(seconds: 30));
        expect(api.statusPolls, polls);
        service.dispose();
      });
    });
  });

  group('answering a dead ring', () {
    test('no offer + a call that no longer rings: down at once, not after 20s',
        () {
      fakeAsync((async) {
        final api = _FakeRingApi()..status = 'cancelled';
        final service = _newService(api);
        async.flushMicrotasks();
        service.handleRemoteSignal(_invite('c1'));
        async.flushMicrotasks();

        service.acceptIncoming();
        async.elapse(const Duration(milliseconds: 100));
        expect(service.session, isNull);
        expect(service.acceptedNatively, isFalse);
        service.dispose();
      });
    });

    test('no offer yet but still ringing: the latch holds for the offer', () {
      fakeAsync((async) {
        final api = _FakeRingApi();
        final service = _newService(api);
        async.flushMicrotasks();
        service.handleRemoteSignal(_invite('c1'));
        async.flushMicrotasks();

        service.acceptIncoming();
        async.elapse(const Duration(milliseconds: 100));
        expect(service.session?.status, CallStatus.incomingRinging);
        expect(service.acceptedNatively, isTrue);
        service.dispose();
      });
    });
  });

  group('speaker toggle', () {
    test('answers on the tap, and a burst lands on the side it stopped on',
        () async {
      final api = _FakeRingApi();
      final service = _newService(api);
      addTearDown(service.dispose);
      await service.handleRemoteSignal(_invite('c1'));
      expect(service.session?.speakerOn, isFalse);

      // Three taps without waiting on any: each reads the flag the one
      // before it already moved.
      final a = service.toggleSpeaker();
      expect(service.session?.speakerOn, isTrue);
      final b = service.toggleSpeaker();
      expect(service.session?.speakerOn, isFalse);
      final c = service.toggleSpeaker();
      await Future.wait([a, b, c]);
      expect(service.session?.speakerOn, isTrue);
    });
  });
}
