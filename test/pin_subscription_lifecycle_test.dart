import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:monkeyhub/backend/chat_api.dart';
import 'package:monkeyhub/backend/convex_client.dart';
import 'package:monkeyhub/data/chat_repository.dart';
import 'package:monkeyhub/models/chat_message.dart';
import 'package:monkeyhub/models/chat_room.dart';
import 'package:monkeyhub/models/chat_user.dart';
import 'package:monkeyhub/models/friend_request.dart';

/// The pins subscription is registered inside `openRoom` rather than by the
/// room screen, specifically so the `_openGen` generation guard and
/// `SubscriptionRegistry`'s reconnect rebinding cover it the way they cover
/// `messages:list`. Registering it anywhere else would reintroduce the bug
/// `room_lifecycle_test.dart` documents at length: a superseded open publishing
/// a live subscription that nobody holds a handle to, wired to the room the
/// user is no longer looking at.
///
/// These pin that it is genuinely inside the guard, that closing the room takes
/// it with it, and that `pinMessage` reports the per-room cap instead of
/// throwing out of the menu handler.
///
/// The gated fake makes the ordering deterministic — the TEST decides whether
/// the subscription lands before or after the late teardown, so nothing here
/// waits on a real timer, socket or frame.

class _FakeSub extends Fake implements Subscription {
  _FakeSub(this.label);

  /// `<query>/<roomId>`.
  final String label;
  bool cancelled = false;

  @override
  void cancel() => cancelled = true;
}

class _FakeCv extends Fake implements ConvexBackend {
  final List<_FakeSub> issued = [];
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
  /// What the next `pinMessage` should throw, if anything.
  Object? pinThrows;
  int pinCalls = 0;
  int unpinCalls = 0;

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

  /// Throwing takes `openRoom`'s offline branch, which keeps `CacheStore`'s
  /// 600ms save debounce out of the test.
  @override
  Future<List<ChatMessage>> listMessages({
    required String roomId,
    int limit = 100,
    String? viewerUserId,
  }) async =>
      throw StateError('offline');

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

  @override
  Future<void> pinMessage({
    required String messageId,
    required String userId,
  }) async {
    pinCalls++;
    final e = pinThrows;
    if (e != null) throw e;
  }

  @override
  Future<void> unpinMessage({
    required String messageId,
    required String userId,
  }) async {
    unpinCalls++;
  }
}

Future<void> _pump([int rounds = 8]) async {
  for (var i = 0; i < rounds; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _FakeCv cv;
  late _FakeApi api;
  late ChatRepository repo;
  late Object screenA;
  late Object screenB;

  setUp(() async {
    cv = _FakeCv();
    api = _FakeApi();
    repo = ChatRepository(api: api, cv: cv);
    screenA = Object();
    screenB = Object();
    await repo.attach('me');
  });

  List<_FakeSub> pinSubsFor(String roomId) => cv.issued
      .where((s) => s.label == 'pins:listForRoom/$roomId')
      .toList();

  group('registration', () {
    test('opening a room subscribes to its pins', () async {
      await repo.openRoom('a', owner: screenA);
      expect(pinSubsFor('a'), hasLength(1));
      expect(pinSubsFor('a').single.cancelled, isFalse);
    });

    test('an open backed out mid-registration cancels its pins sub', () async {
      // The owner's own close, landing while the open is still in flight —
      // backing out of a room before its subscriptions ever arrived.
      final gate = Completer<void>();
      cv.gates['pins:listForRoom'] = gate;
      final opening = repo.openRoom('b', owner: screenB);
      await _pump();

      repo.closeRoom(screenB);

      gate.complete();
      await opening;

      for (final s in pinSubsFor('b')) {
        expect(s.cancelled, isTrue,
            reason: 'a superseded open must not publish a pins subscription');
      }
    });

    test('a newer open cancels the parked one\'s pins sub', () async {
      // Room b parks where the real open waits on the network; room c
      // supersedes it before it lands.
      final gate = Completer<void>();
      cv.gates['pins:listForRoom'] = gate;
      final opening = repo.openRoom('b', owner: screenB);
      await _pump();

      cv.gates.remove('pins:listForRoom');
      final second = repo.openRoom('c', owner: screenA);

      gate.complete();
      await opening;
      await second;

      for (final s in pinSubsFor('b')) {
        expect(s.cancelled, isTrue,
            reason: 'the loser of the race must not publish');
      }
      expect(repo.activeRoomId, 'c');
    });

    test('closing the room cancels the pins sub', () async {
      await repo.openRoom('a', owner: screenA);
      expect(pinSubsFor('a').single.cancelled, isFalse);

      repo.closeRoom(screenA);

      expect(pinSubsFor('a').single.cancelled, isTrue);
    });

    test('switching rooms cancels the old room\'s pins sub', () async {
      await repo.openRoom('a', owner: screenA);
      await repo.openRoom('b', owner: screenB);

      expect(pinSubsFor('a').single.cancelled, isTrue);
      expect(pinSubsFor('b').single.cancelled, isFalse);
    });
  });

  group('accessors', () {
    test('a room with no pins reads as empty rather than null', () async {
      await repo.openRoom('a', owner: screenA);
      expect(repo.pinsFor('a'), isEmpty);
      expect(repo.isMessagePinned('a', 'm1'), isFalse);
    });

    test('an unopened room reads as empty', () {
      expect(repo.pinsFor('never-opened'), isEmpty);
    });
  });

  group('mutations', () {
    test('a successful pin reports no error', () async {
      await repo.openRoom('a', owner: screenA);
      expect(await repo.pinMessage('a', 'm1'), isNull);
      expect(api.pinCalls, 1);
    });

    test('the cap is reported, not thrown', () async {
      // The menu handler awaits this inline. Letting it throw would take out
      // the whole long-press flow instead of showing a message.
      api.pinThrows = Exception('PIN_LIMIT_REACHED');
      await repo.openRoom('a', owner: screenA);

      expect(await repo.pinMessage('a', 'm1'), 'PIN_LIMIT_REACHED');
    });

    test('any other failure reports a generic code', () async {
      api.pinThrows = Exception('NOT_A_MEMBER');
      await repo.openRoom('a', owner: screenA);

      expect(await repo.pinMessage('a', 'm1'), 'PIN_FAILED');
    });

    test('unpin swallows, leaving the subscription to reconcile', () async {
      await repo.openRoom('a', owner: screenA);
      await repo.unpinMessage('a', 'm1');
      expect(api.unpinCalls, 1);
    });
  });
}
