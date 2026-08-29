import 'dart:async';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monkeyhub/backend/convex_client.dart';
import 'package:monkeyhub/backend/group_call_api.dart';
import 'package:monkeyhub/calls/call_models.dart';
import 'package:monkeyhub/calls/group_call_service.dart';

import 'fakes/fake_webrtc.dart';

/// A group card comes down from the LIVE app, and the app says so.
///
/// It used to come down by push alone: the `pendingInviteForUser`
/// subscription dropped the invite the instant the call ended, and the
/// CallKit / ConnectionService card kept ringing until `group_taken` made its
/// way through the scheduler, an action and APNs — the "stale ring for two
/// seconds" — after which, on iOS, a push arriving for a card that a live
/// app HAD taken down flashed a one-second phantom "Call". These pin the
/// client half of the fix, the same shape as `CallService`'s: end the card
/// the moment the invite leaves the subscription, ack it so the
/// grace-delayed push skips this device, and never do either for the call
/// the user just answered.
class _FakeSubscription extends Fake implements Subscription {
  @override
  void cancel() {}
}

class _FakeGroupApi extends Fake implements GroupCallApi {
  /// `groupCallId@deviceId`, in order.
  final List<String> acks = [];
  int declines = 0;
  int leaves = 0;

  /// Captured subscription callbacks — tests drive the server through them.
  void Function(Map<String, dynamic>? invite)? invite;
  void Function(Map<String, dynamic>? roster)? roster;

  @override
  Future<({String type, String roomId})> join({
    required String groupCallId,
    required String userId,
    String? deviceId,
  }) async =>
      (type: 'audio', roomId: 'room1');

  @override
  Future<void> leave({
    required String groupCallId,
    required String userId,
  }) async {
    leaves++;
  }

  @override
  Future<void> decline({
    required String groupCallId,
    required String userId,
    String? deviceId,
  }) async {
    declines++;
  }

  @override
  Future<void> ackNativeDismissed({
    required String groupCallId,
    required String userId,
    required String deviceId,
  }) async {
    acks.add('$groupCallId@$deviceId');
  }

  @override
  Future<String?> heartbeat({
    required String groupCallId,
    required String userId,
  }) async =>
      'ok';

  @override
  Future<void> sendSignal({
    required String groupCallId,
    required String fromUserId,
    required String toUserId,
    required String kind,
    required String payload,
    String? fromDeviceId,
    String? targetDeviceId,
  }) async {}

  @override
  Future<void> consumeSignals({
    required List<String> signalIds,
    required String userId,
  }) async {}

  @override
  Future<Subscription> subscribeSignals({
    required String userId,
    required void Function(List<Map<String, dynamic>> signals) onSignals,
    void Function(Object error)? onError,
  }) async =>
      _FakeSubscription();

  @override
  Future<Subscription> subscribeRoster({
    required String groupCallId,
    required String userId,
    required void Function(Map<String, dynamic>? roster) onRoster,
    void Function(Object error)? onError,
  }) async {
    roster = onRoster;
    return _FakeSubscription();
  }

  @override
  Future<Subscription> subscribePendingInvite({
    required String userId,
    required void Function(Map<String, dynamic>? invite) onInvite,
    void Function(Object error)? onError,
  }) async {
    invite = onInvite;
    return _FakeSubscription();
  }
}

Map<String, dynamic> _invite(String id, {String room = 'design crew'}) => {
      'groupCallId': id,
      'roomId': 'room1',
      'roomName': room,
      'type': 'audio',
      'starterUserId': 'ayse',
      'starterName': 'Ayşe',
      'joinedCount': 1,
    };

/// A service on a phone: native cards on, the card-ending seam recording
/// into [ended], attached as `me` on `phone-a`.
GroupCallService _newService(_FakeGroupApi api, List<String> ended) {
  final service = GroupCallService(api: api)
    ..leaveNotifyTimeout = const Duration(milliseconds: 20)
    ..nativeCardsEnabled = true
    ..endNativeCardFn = (id) async {
      ended.add(id);
    };
  service.getUserMediaFn = (kind, {tier = VideoQualityTier.auto}) async =>
      FakeMediaStream([FakeMediaStreamTrack(kind: 'audio')]);
  service.attach(userId: 'me', deviceId: 'phone-a');
  return service;
}

void main() {
  group('a group card comes down from the live app', () {
    test('the invite leaving the subscription ends the card and acks once', () {
      fakeAsync((async) {
        final api = _FakeGroupApi();
        final ended = <String>[];
        final service = _newService(api, ended);
        async.flushMicrotasks();

        api.invite!(_invite('gc1'));
        async.flushMicrotasks();
        expect(ended, isEmpty);

        // The starter hung up: the server stops offering the invite.
        api.invite!(null);
        async.flushMicrotasks();

        expect(ended, ['gc1']);
        expect(api.acks, ['gc1@phone-a']);
        expect(service.pendingInvite, isNull);
      });
    });

    test('a newer invite replacing it ends the OLD card', () {
      fakeAsync((async) {
        final api = _FakeGroupApi();
        final ended = <String>[];
        _newService(api, ended);
        async.flushMicrotasks();

        api.invite!(_invite('gc1'));
        async.flushMicrotasks();
        api.invite!(_invite('gc2'));
        async.flushMicrotasks();

        expect(ended, ['gc1']);
        expect(api.acks, ['gc1@phone-a']);
      });
    });

    test('but not when it left because WE answered it', () {
      fakeAsync((async) {
        final api = _FakeGroupApi();
        final ended = <String>[];
        final service = _newService(api, ended);
        async.flushMicrotasks();

        api.invite!(_invite('gc1'));
        async.flushMicrotasks();

        // Join, and let the server drop the invite BEFORE the join has
        // finished entering the call — the ordinary order: the mutation
        // lands, the subscription reacts, and only then does getUserMedia
        // resolve. The card is the call now; ending it would hang up on the
        // person who just pressed Answer.
        unawaited(service.joinCall('gc1'));
        api.invite!(null);
        async.flushMicrotasks();
        expect(service.inCall, isTrue);

        // And the late drop, after the call is fully up, is just as inert.
        api.invite!(null);
        async.flushMicrotasks();

        expect(ended, isEmpty);
        expect(api.acks, isEmpty);

        unawaited(service.leaveCall());
        async.flushMicrotasks();
      });
    });

    test('the in-app Dismiss ends the card and acks, and the follow-up drop does not repeat it', () {
      fakeAsync((async) {
        final api = _FakeGroupApi();
        final ended = <String>[];
        final service = _newService(api, ended);
        async.flushMicrotasks();

        api.invite!(_invite('gc1'));
        async.flushMicrotasks();

        unawaited(service.declineInvite());
        async.flushMicrotasks();
        expect(api.declines, 1);
        expect(ended, ['gc1']);
        expect(api.acks, ['gc1@phone-a']);

        // The decline lands and the subscription drops the invite. Same
        // card, already gone — not a second end, not a second ack.
        api.invite!(null);
        async.flushMicrotasks();
        expect(ended, ['gc1']);
        expect(api.acks, ['gc1@phone-a']);
      });
    });

    test('hanging up ends the answered card, with no ack', () {
      fakeAsync((async) {
        final api = _FakeGroupApi();
        final ended = <String>[];
        final service = _newService(api, ended);
        async.flushMicrotasks();

        api.invite!(_invite('gc1'));
        async.flushMicrotasks();
        unawaited(service.joinCall('gc1'));
        api.invite!(null);
        async.flushMicrotasks();
        expect(service.inCall, isTrue);

        unawaited(service.leaveCall());
        async.flushMicrotasks();

        // CallKit / ConnectionService hold an "ongoing" session for a card
        // answered natively, and a `left` participant is never sent a
        // `group_taken` — so this is the only thing that ever ends it, and
        // there is no push to spare this device from.
        expect(ended, ['gc1']);
        expect(api.acks, isEmpty);
        expect(api.leaves, 1);
      });
    });

    test('no ack when the card could not be ended', () {
      fakeAsync((async) {
        final api = _FakeGroupApi();
        final ended = <String>[];
        final service = _newService(api, ended)
          ..endNativeCardFn = (id) async {
            throw StateError('plugin channel busy');
          };
        async.flushMicrotasks();

        api.invite!(_invite('gc1'));
        async.flushMicrotasks();
        api.invite!(null);
        async.flushMicrotasks();

        // The card may still be up; the grace-delayed push is then the one
        // thing left that can clear it, and an ack would have waved it off.
        expect(api.acks, isEmpty);
        expect(service.pendingInvite, isNull);
      });
    });

    test('off a phone there is no card to end', () {
      fakeAsync((async) {
        final api = _FakeGroupApi();
        final ended = <String>[];
        _newService(api, ended).nativeCardsEnabled = false;
        async.flushMicrotasks();

        api.invite!(_invite('gc1'));
        async.flushMicrotasks();
        api.invite!(null);
        async.flushMicrotasks();

        expect(ended, isEmpty);
        expect(api.acks, isEmpty);
      });
    });
  });

  group('the in-call screen knows which room it is in', () {
    test('seeded from the invite, kept current by the roster, gone on leave', () {
      fakeAsync((async) {
        final api = _FakeGroupApi();
        final service = _newService(api, <String>[]);
        async.flushMicrotasks();

        api.invite!(_invite('gc1', room: 'design crew'));
        async.flushMicrotasks();
        unawaited(service.joinCall('gc1'));
        async.flushMicrotasks();
        expect(service.roomName, 'design crew');

        api.roster!({
          'groupCallId': 'gc1',
          'status': 'active',
          'roomName': 'design crew (renamed)',
          'roomAvatarStorageId': 'st_room',
          'participants': [
            {'userId': 'me', 'status': 'joined', 'name': 'Me'},
          ],
        });
        async.flushMicrotasks();
        expect(service.roomName, 'design crew (renamed)');
        expect(service.roomAvatarStorageId, 'st_room');

        unawaited(service.leaveCall());
        async.flushMicrotasks();
        expect(service.roomName, isNull);
        expect(service.roomAvatarStorageId, isNull);
      });
    });

    test('a call started from inside the room learns it from the roster', () {
      fakeAsync((async) {
        final api = _FakeGroupApi();
        final service = _newService(api, <String>[]);
        async.flushMicrotasks();

        // No invite to seed from — this phone pressed the button.
        unawaited(service.joinCall('gc1'));
        async.flushMicrotasks();
        expect(service.roomName, isNull);

        api.roster!({
          'groupCallId': 'gc1',
          'status': 'active',
          'roomName': 'design crew',
          'participants': [
            {'userId': 'me', 'status': 'joined', 'name': 'Me'},
          ],
        });
        async.flushMicrotasks();
        expect(service.roomName, 'design crew');

        unawaited(service.leaveCall());
        async.flushMicrotasks();
      });
    });
  });
}
