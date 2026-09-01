import 'package:flutter_callkit_incoming/entities/entities.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monkeyhub/backend/call_api.dart';
import 'package:monkeyhub/backend/convex_client.dart';
import 'package:monkeyhub/backend/group_call_api.dart';
import 'package:monkeyhub/calls/call_service.dart';
import 'package:monkeyhub/calls/group_call_service.dart';
import 'package:monkeyhub/calls/native_call_handler.dart';

// What the resume-time sweep (`replayColdStartCalls`) and the plugin's
// decline echo do to a native card, pinned against the two ways a ringing
// call used to die within a second of ringing:
//
//   * a GROUP card read as a 1:1 ghost (no `calls` row can ever match it)
//     and was ended on every resume;
//   * ending an un-answered card comes back from the plugin as a DECLINE,
//     which the handler then reported to the backend as the user's — so the
//     app's own dismissal became `calls:reject` / `groupCalls:decline`.

class _FakeSubscription extends Fake implements Subscription {
  @override
  void cancel() {}
}

class _FakeCallApi extends Fake implements CallApi {
  Future<Map<String, dynamic>?> Function()? activeCall;
  final List<String> rejected = [];

  @override
  Future<Map<String, dynamic>?> getActiveCallOnce({required String userId}) {
    final f = activeCall;
    if (f == null) return Future.value(null);
    return f();
  }

  @override
  Future<String?> rejectCall({
    required String callId,
    required String userId,
    String? acceptingDeviceId,
  }) async {
    rejected.add(callId);
    return 'rejected';
  }

  @override
  Future<void> ackNativeDismissed({
    required String callId,
    required String userId,
    required String deviceId,
  }) async {}

  @override
  Future<Subscription> subscribeActiveCall({
    required String userId,
    required void Function(Map<String, dynamic>? call) onCall,
    void Function(Object error)? onError,
  }) async =>
      _FakeSubscription();
}

class _FakeGroupApi extends Fake implements GroupCallApi {
  Future<Map<String, dynamic>?> Function()? pendingInvite;
  final List<String> declined = [];
  final List<String> acked = [];

  @override
  Future<Map<String, dynamic>?> pendingInviteOnce({required String userId}) {
    final f = pendingInvite;
    if (f == null) return Future.value(null);
    return f();
  }

  @override
  Future<void> decline({
    required String groupCallId,
    required String userId,
    String? deviceId,
  }) async {
    declined.add(groupCallId);
  }

  @override
  Future<void> ackNativeDismissed({
    required String groupCallId,
    required String userId,
    required String deviceId,
  }) async {
    acked.add(groupCallId);
  }

  @override
  Future<Subscription> subscribeSignals({
    required String userId,
    String? deviceId,
    required void Function(List<Map<String, dynamic>> signals) onSignals,
    void Function(Object error)? onError,
  }) async =>
      _FakeSubscription();

  @override
  Future<Subscription> subscribePendingInvite({
    required String userId,
    required void Function(Map<String, dynamic>? invite) onInvite,
    void Function(Object error)? onError,
  }) async =>
      _FakeSubscription();
}

Future<void> _pump([int rounds = 12]) async {
  for (var i = 0; i < rounds; i++) {
    await Future<void>.delayed(const Duration(milliseconds: 2));
  }
}

Map<String, dynamic> _groupCard(String id, {bool accepted = false}) => {
      'id': NativeCallHandler.derivedUuid(id),
      'accepted': accepted,
      'extra': {'callId': id, 'groupCallId': id},
    };

Map<String, dynamic> _dmCard(String id, {bool accepted = false}) => {
      'id': 'uuid-$id',
      'accepted': accepted,
      'extra': {'callId': id},
    };

CallKitParams _paramsFor(Map<String, dynamic> card) => CallKitParams(
      id: card['id'] as String,
      extra: (card['extra'] as Map).cast<String, dynamic>(),
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final callApi = _FakeCallApi();
  final groupApi = _FakeGroupApi();
  late List<Map<String, dynamic>> cards;
  late List<String> ended;
  var endedAll = false;

  setUpAll(() {
    CallService.ensure(callApi).attach(userId: 'me', displayName: 'Me');
    GroupCallService.ensure(groupApi)
      ..nativeCardsEnabled = true
      ..attach(userId: 'me', deviceId: 'dev-1');
    NativeCallHandler.nativeCallUiOverride = true;
    NativeCallHandler.activeCallsFn = () async => cards;
    NativeCallHandler.endCallFn = (uuid) async => ended.add(uuid);
    NativeCallHandler.endAllCallsFn = () async => endedAll = true;
  });

  setUp(() {
    cards = [];
    ended = [];
    endedAll = false;
    callApi.activeCall = null;
    callApi.rejected.clear();
    groupApi.pendingInvite = null;
    groupApi.declined.clear();
    groupApi.acked.clear();
  });

  final handler = NativeCallHandler.instance;

  group('group cards', () {
    test('a ringing card the backend still offers is left up', () async {
      cards = [_groupCard('g-ringing')];
      groupApi.pendingInvite = () async => {'groupCallId': 'g-ringing'};
      await handler.replayColdStartCalls();
      await _pump();
      expect(ended, isEmpty);
      expect(endedAll, isFalse);
      expect(groupApi.declined, isEmpty);
    });

    test('a card with no invite behind it is cleared, acked, and its echo '
        'is not a decline', () async {
      final card = _groupCard('g-gone');
      cards = [card];
      groupApi.pendingInvite = () async => null;
      await handler.replayColdStartCalls();
      await _pump();
      expect(ended, [card['id']]);
      expect(groupApi.acked, ['g-gone']);
      // The plugin reports our own end of an un-answered card as DECLINE.
      await handler.handleEvent(CallEventActionCallDecline(_paramsFor(card)));
      await _pump();
      expect(groupApi.declined, isEmpty);
    });

    test('a card is left alone when the probe fails', () async {
      cards = [_groupCard('g-unknown')];
      groupApi.pendingInvite = () async => throw StateError('offline');
      await handler.replayColdStartCalls();
      await _pump();
      expect(ended, isEmpty);
      expect(endedAll, isFalse);
    });

    test('a card is left alone when a DIFFERENT invite is the newest',
        () async {
      cards = [_groupCard('g-older')];
      groupApi.pendingInvite = () async => {'groupCallId': 'g-newer'};
      await handler.replayColdStartCalls();
      await _pump();
      expect(ended, isEmpty);
    });

    test('a genuine decline from the card still reaches the backend',
        () async {
      final card = _groupCard('g-user-declined');
      await handler.handleEvent(CallEventActionCallDecline(_paramsFor(card)));
      await _pump();
      expect(groupApi.declined, ['g-user-declined']);
    });
  });

  group('1:1 cards', () {
    test('a ringing card matching the live call is left up', () async {
      cards = [_dmCard('c-live')];
      callApi.activeCall = () async => {'_id': 'c-live', 'status': 'ringing'};
      await handler.replayColdStartCalls();
      await _pump();
      expect(ended, isEmpty);
      expect(endedAll, isFalse);
    });

    test('a card is left up when the backend cannot be reached — and a '
        'later decline is still the user\'s', () async {
      final card = _dmCard('c-unreachable');
      cards = [card];
      callApi.activeCall = () async => throw StateError('reconnecting');
      await handler.replayColdStartCalls();
      await _pump();
      expect(ended, isEmpty);
      expect(endedAll, isFalse);
      expect(callApi.rejected, isEmpty);
      await handler.handleEvent(CallEventActionCallDecline(_paramsFor(card)));
      await _pump();
      expect(callApi.rejected, ['c-unreachable']);
    });

    test('a card with no live call behind it is cleared, and its echo is '
        'not a reject', () async {
      final card = _dmCard('c-stale');
      cards = [card];
      callApi.activeCall = () async => null;
      await handler.replayColdStartCalls();
      await _pump();
      expect(ended, [card['id']]);
      await handler.handleEvent(CallEventActionCallDecline(_paramsFor(card)));
      await handler.handleEvent(CallEventActionCallEnded(_paramsFor(card)));
      await handler.handleEvent(
          CallEventActionCallTimeout(card['id'] as String));
      await _pump();
      expect(callApi.rejected, isEmpty);
    });

    test('a group card beside a stale 1:1 card never triggers endAllCalls',
        () async {
      final stale = _dmCard('c-stale-2');
      cards = [_groupCard('g-beside'), stale];
      callApi.activeCall = () async => null;
      groupApi.pendingInvite = () async => {'groupCallId': 'g-beside'};
      await handler.replayColdStartCalls();
      await _pump();
      expect(ended, [stale['id']]);
      expect(endedAll, isFalse);
    });
  });
}
