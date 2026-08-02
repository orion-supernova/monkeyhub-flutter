import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:monkeyhub/backend/chat_api.dart';
import 'package:monkeyhub/backend/convex_client.dart';
import 'package:monkeyhub/data/chat_repository.dart';
import 'package:monkeyhub/models/chat_message.dart';
import 'package:monkeyhub/models/chat_room.dart';
import 'package:monkeyhub/models/chat_user.dart';
import 'package:monkeyhub/models/friend_request.dart';

/// Push banners kept firing for the room already on screen, and that room
/// sometimes stopped receiving messages entirely — both after arriving there
/// by tapping the notification.
///
/// Cause: `closeRoom` was a room-agnostic global teardown called from
/// `_RoomScreenState.dispose`, and Flutter runs the OUTGOING screen's dispose
/// well AFTER the incoming one's initState. `_openRoomFromPush` pops the old
/// route with an animation and pushes the new one synchronously, so the old
/// screen's dispose landed ~300ms into the new room's life and closed it:
/// subscriptions cancelled, `activeRoomId` nulled — and `activeRoomId` is the
/// only thing `PushManager._onWillDisplay` consults to suppress a banner.
///
/// These pin the ownership token that fixes it, plus the generation guard that
/// keeps a superseded open from publishing subscriptions after the fact.
///
/// The gated fake below is what makes the ordering deterministic: the TEST
/// decides whether an open's subscriptions land before or after the late
/// dispose, so nothing here waits on a real timer, socket or frame.

class _FakeSub extends Fake implements Subscription {
  _FakeSub(this.label);

  /// `<query>/<roomId>` — enough to tell one room's subscriptions from another's.
  final String label;
  bool cancelled = false;

  @override
  void cancel() => cancelled = true;
}

class _FakeCv extends Fake implements ConvexBackend {
  final List<_FakeSub> issued = [];

  /// Query name → gate. A gated `subscribe` parks until the test releases it.
  final Map<String, Completer<void>> gates = {};

  @override
  Future<Subscription> subscribe(
    String name,
    Map<String, dynamic> args, {
    required void Function(dynamic) onData,
    void Function(Object error)? onError,
  }) async {
    final gate = gates[name];
    if (gate != null) await gate.future;
    final sub = _FakeSub('$name/${args['roomId'] ?? '-'}');
    issued.add(sub);
    return sub;
  }

  @override
  bool get isConnected => true;

  @override
  Stream<bool> get connectionState => const Stream<bool>.empty();
}

class _FakeApi extends Fake implements ChatApi {
  @override
  Future<List<ChatRoom>> listUserRooms(String userId) async => const [];

  @override
  Future<List<ChatUser>> listFriends(String userId) async => const [];

  @override
  Future<List<FriendRequest>> listIncomingDirectRequests(String userId) async =>
      const [];

  @override
  Future<List<FriendRequest>> listOutgoingDirectRequests(String userId) async =>
      const [];

  /// Throwing takes `openRoom`'s documented offline branch, which keeps
  /// `CacheStore`'s save debounce (a real 600ms Timer) out of the test.
  @override
  Future<List<ChatMessage>> listMessages({
    required String roomId,
    int limit = 100,
    String? viewerUserId,
  }) async => throw StateError('offline');

  @override
  Future<void> markRoomRead({
    required String roomId,
    required String userId,
  }) async {}

  @override
  Future<void> clearTyping({
    required String roomId,
    required String userId,
  }) async {}
}

Future<void> _pump([int rounds = 8]) async {
  for (var i = 0; i < rounds; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

void main() {
  // The platform channels `openRoom` touches (push dismissal, path_provider
  // behind CacheStore) throw MissingPluginException without a binding, which
  // is the variety their call sites already swallow.
  TestWidgetsFlutterBinding.ensureInitialized();

  late _FakeCv cv;
  late ChatRepository repo;

  /// Stand-ins for the `RoomScreen` states that own an open room.
  late Object screenA;
  late Object screenB;

  setUp(() async {
    cv = _FakeCv();
    repo = ChatRepository(api: _FakeApi(), cv: cv);
    screenA = Object();
    screenB = Object();
    await repo.attach('me');
  });

  List<_FakeSub> subsFor(String roomId) =>
      cv.issued.where((s) => s.label.endsWith('/$roomId')).toList();

  group('open-room ownership', () {
    test(
      'a superseded screen\'s dispose cannot close the room that replaced it',
      () async {
        await repo.openRoom('a', owner: screenA);

        // Room b's open parks mid-registration, exactly where the real one sits
        // waiting on the network while the outgoing route finishes animating.
        final gate = Completer<void>();
        cv.gates['messages:list'] = gate;
        final opening = repo.openRoom('b', owner: screenB);
        await _pump();

        // The old screen's dispose, landing late.
        repo.closeRoom(screenA);

        gate.complete();
        await opening;

        // Without the ownership guard this is null — which is precisely what let
        // PushManager banner the room the user was reading.
        expect(repo.activeRoomId, 'b');
        expect(subsFor('b').where((s) => s.cancelled), isEmpty);
      },
    );

    test(
      'a push tap into the room already on screen survives the old dispose',
      () async {
        await repo.openRoom('a', owner: screenA);
        // The tap mounts a SECOND RoomScreen for the same room; openRoom
        // short-circuits but must still hand ownership over.
        final screenA2 = Object();
        await repo.openRoom('a', owner: screenA2);

        repo.closeRoom(screenA);

        // A roomId-only guard would have matched here and killed the live room
        // with nothing left to re-open it.
        expect(repo.activeRoomId, 'a');
        expect(subsFor('a').where((s) => s.cancelled), isEmpty);
      },
    );

    test('the holder\'s own close still tears the room down', () async {
      await repo.openRoom('a', owner: screenA);
      expect(subsFor('a'), isNotEmpty);

      repo.closeRoom(screenA);

      expect(repo.activeRoomId, isNull);
      expect(subsFor('a').every((s) => s.cancelled), isTrue);
    });
  });

  group('open-room generation guard', () {
    test(
      'an open superseded mid-registration cancels the sub it created',
      () async {
        final gate = Completer<void>();
        cv.gates['messages:list'] = gate;
        final stale = repo.openRoom('a', owner: screenA);
        await _pump();

        // Let room b through unimpeded while a is still parked.
        cv.gates.remove('messages:list');
        await repo.openRoom('b', owner: screenB);

        gate.complete();
        await stale;

        // Publishing a's handle would have wired the room on screen to the wrong
        // query, with nobody holding the handle to cancel it.
        expect(
          cv.issued.firstWhere((s) => s.label == 'messages:list/a').cancelled,
          isTrue,
        );
        expect(
          cv.issued.firstWhere((s) => s.label == 'messages:list/b').cancelled,
          isFalse,
        );
        expect(repo.activeRoomId, 'b');
      },
    );

    test('closing while an open is in flight leaks no subscription', () async {
      final gate = Completer<void>();
      cv.gates['messages:list'] = gate;
      final opening = repo.openRoom('a', owner: screenA);
      await _pump();

      repo.closeRoom(screenA);

      gate.complete();
      await opening;

      expect(repo.activeRoomId, isNull);
      expect(subsFor('a').every((s) => s.cancelled), isTrue);
    });
  });

  group('resubscribe', () {
    test(
      're-registers the open room without ever blanking activeRoomId',
      () async {
        await repo.openRoom('a', owner: screenA);
        final before = subsFor('a').length;

        await repo.resubscribe();

        expect(repo.activeRoomId, 'a');
        // `force` had to re-register despite the same-room short-circuit.
        expect(subsFor('a').length, greaterThan(before));
        expect(
          subsFor('a').where((s) => !s.cancelled).length,
          before,
          reason: 'the previous generation should have been cancelled',
        );
      },
    );

    test(
      'does not resurrect a room the user left during the reconnect',
      () async {
        await repo.openRoom('a', owner: screenA);

        // Park inside attach(), which is four API calls and five subscriptions
        // of real wall-clock — plenty of room for the user to back out.
        final gate = Completer<void>();
        cv.gates['rooms:listUserRooms'] = gate;
        final reconnecting = repo.resubscribe();
        await _pump();

        repo.closeRoom(screenA);

        cv.gates.remove('rooms:listUserRooms');
        gate.complete();
        await reconnecting;

        // Trusting the pre-attach snapshot re-opened the old room and pointed
        // activeRoomId at a chat that was no longer on screen — suppressing
        // banners for a room the user had left while banner-ing the one they
        // were actually in.
        expect(repo.activeRoomId, isNull);
      },
    );
  });
}
