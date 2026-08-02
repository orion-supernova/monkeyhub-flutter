import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:monkeyhub/backend/call_api.dart';
import 'package:monkeyhub/backend/convex_client.dart';
import 'package:monkeyhub/calls/call_service.dart';
import 'package:monkeyhub/calls/signaling_subscriber.dart';

class _FakeSubscription extends Fake implements Subscription {
  @override
  void cancel() {}
}

class _FakeCallApi extends Fake implements CallApi {
  void Function(List<Map<String, dynamic>> signals)? emit;
  final List<List<String>> consumedBatches = [];

  @override
  Future<Subscription> subscribeCallSignals({
    required String userId,
    required void Function(List<Map<String, dynamic>> signals) onSignals,
    void Function(Object error)? onError,
  }) async {
    emit = onSignals;
    return _FakeSubscription();
  }

  @override
  Future<void> consumeCallSignals({
    required List<String> signalIds,
    required String userId,
  }) async {
    consumedBatches.add(List.of(signalIds));
  }
}

/// Records dispatch order; a gate on a kind blocks that handler until the
/// test releases it, proving later signals wait their turn.
class _RecordingCallService extends CallService {
  _RecordingCallService({required super.api});

  final List<String> started = [];
  final List<String> finished = [];
  final Map<String, Completer<void>> gates = {};

  @override
  Future<void> handleRemoteSignal(Map<String, dynamic> signal) async {
    final kind = signal['kind'] as String;
    started.add(kind);
    final gate = gates[kind];
    if (gate != null) await gate.future;
    finished.add(kind);
  }
}

Map<String, dynamic> _sig(String id, String kind, {String? targetDeviceId}) => {
  '_id': id,
  'callId': 'call1',
  'fromUserId': 'peer',
  'kind': kind,
  'payload': '{}',
  'createdAt': 0,
  'targetDeviceId': ?targetDeviceId,
};

Future<void> _pump([int rounds = 8]) async {
  for (var i = 0; i < rounds; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

void main() {
  late _FakeCallApi api;
  late _RecordingCallService service;
  late SignalingSubscriber sub;

  setUp(() async {
    api = _FakeCallApi();
    service = _RecordingCallService(api: api);
    sub = SignalingSubscriber(api: api, service: service);
    await sub.start('me', deviceId: 'dev1');
  });

  test(
    'signals dispatch strictly in order — bye waits for in-flight offer',
    () async {
      final gate = service.gates['offer'] = Completer<void>();
      api.emit!([_sig('s1', 'offer'), _sig('s2', 'bye')]);
      await _pump();
      // Offer is in flight; bye must not have started.
      expect(service.started, ['offer']);
      expect(service.finished, isEmpty);

      gate.complete();
      await _pump();
      expect(service.finished, ['offer', 'bye']);
      // One batched consume, ids in delivery order.
      expect(api.consumedBatches, [
        ['s1', 's2'],
      ]);
    },
  );

  test('re-delivered ids dispatch and consume only once', () async {
    api.emit!([_sig('s1', 'state')]);
    await _pump();
    api.emit!([_sig('s1', 'state'), _sig('s2', 'state')]);
    await _pump();
    expect(service.finished, ['state', 'state']);
    expect(api.consumedBatches.expand((b) => b), ['s1', 's2']);
  });

  test(
    'signals targeted at another device are consumed but not dispatched',
    () async {
      api.emit!([
        _sig('s1', 'handoff-takeover', targetDeviceId: 'otherDevice'),
        _sig('s2', 'state', targetDeviceId: 'dev1'),
      ]);
      await _pump();
      expect(service.finished, ['state']);
      expect(api.consumedBatches.single, ['s1', 's2']);
    },
  );

  test('a throwing handler does not stall the queue', () async {
    service.gates['offer'] = Completer<void>()
      ..completeError(StateError('boom'));
    api.emit!([_sig('s1', 'offer'), _sig('s2', 'bye')]);
    await _pump();
    expect(service.finished, ['bye']);
    expect(api.consumedBatches.single, ['s1', 's2']);
  });
}
