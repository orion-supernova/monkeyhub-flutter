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
  _FakeSub(this.label, this.fireOnData);

  /// `<query>/<roomId>` — enough to tell one room's subscriptions from another's.
  final String label;
  bool cancelled = false;

  /// Lets a test simulate the live subscription delivering — as opposed to
  /// the cache-hydrate branch that runs before it registers at all.
  final void Function(dynamic) fireOnData;

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
    final sub = _FakeSub('$name/${args['roomId'] ?? '-'}', onData);
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
    DateTime? upTo,
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
        // The tap mounts a SECOND RoomScreen for the same room. That is a new
        // reading session, so the room is genuinely re-opened — the previous
        // generation's subscriptions are replaced rather than kept, which is
        // what stops the new screen inheriting a transcript the frozen socket
        // has not caught up on (see `newReader` in [ChatRepository.openRoom]).
        // What must NOT change is who holds the room.
        final screenA2 = Object();
        await repo.openRoom('a', owner: screenA2);

        repo.closeRoom(screenA);

        // A roomId-only guard would have matched here and killed the live room
        // with nothing left to re-open it.
        expect(repo.activeRoomId, 'a');
        expect(
          subsFor('a').where((s) => !s.cancelled),
          isNotEmpty,
          reason:
              'the departing screen must leave its replacement a room that is '
              'still on the wire',
        );
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

  group('roomsLoaded', () {
    // The chat list cannot tell "you have no rooms" from "nobody has told me
    // yet" out of `rooms` alone — both are an empty list — so it guessed, and
    // on a slow connection it told people with a hundred rooms that they had
    // none for as long as the network took. This is the signal that replaces
    // the guess.

    /// The live rooms subscription, once `attach` has registered it.
    _FakeSub roomsSub() =>
        cv.issued.firstWhere((s) => s.label.startsWith('rooms:listUserRooms'));

    test('a repository nobody has attached has not been answered', () {
      final fresh = ChatRepository(api: _FakeApi(), cv: _FakeCv());
      addTearDown(fresh.dispose);
      expect(fresh.roomsLoaded, isFalse,
          reason: 'nothing has replied, so the list is pending, not empty');
    });

    test('the subscription delivering is the answer', () {
      // Note this is asserted BEFORE the delivery: the seed fetch behind
      // `_FakeApi` never completes here, and that is the honest shape of a
      // slow or failing network — a request that has not answered must leave
      // the list pending rather than quietly resolving it to empty.
      expect(repo.roomsLoaded, isFalse);

      roomsSub().fireOnData(const []);

      expect(repo.rooms, isEmpty);
      expect(repo.roomsLoaded, isTrue,
          reason: 'an empty answer is still an answer — a new account has to '
              'reach its empty state instead of shimmering at it');
    });

    test('signing out puts the next account back to pending', () async {
      roomsSub().fireOnData(const []);
      expect(repo.roomsLoaded, isTrue);

      await repo.detach();

      expect(repo.roomsLoaded, isFalse,
          reason: 'inheriting "answered" would show the next person an empty '
              'chat list while theirs was still loading');
    });
  });

  group('hasLiveMessages', () {
    test(
      'stays false until the subscription itself delivers, unlike hasLoadedInitial',
      () async {
        await repo.openRoom('a', owner: screenA);

        // Registration alone (what hasLoadedInitial also accepts, so a
        // never-cached room offline doesn't spin forever) is not enough —
        // nothing has actually come back from the server yet.
        expect(repo.hasLoadedInitial('a'), isTrue);
        expect(
          repo.hasLiveMessages('a'),
          isFalse,
          reason:
              'no onData has fired yet; a caller that needs to know the '
              "server's own view has landed (not just a maybe-stale disk "
              'cache) must not be told it has',
        );

        cv.issued.firstWhere((s) => s.label == 'messages:list/a').fireOnData([
          {
            '_id': 'm1',
            'roomId': 'a',
            'userId': 'someone',
            'createdAt': DateTime.now().millisecondsSinceEpoch,
          },
        ]);

        expect(repo.hasLiveMessages('a'), isTrue);
      },
    );

    test('clears for a NEW screen on the same room', () async {
      // The notification tap for the chat you were already inside when the app
      // went away. `openRoom` used to short-circuit on the roomId alone, so
      // this flag survived from the previous screen's session — and it is the
      // flag `RoomScreen._settleUnreadDivider` asks "has the transcript spoken
      // yet?". Told yes while the socket was still frozen, it read a transcript
      // that had not caught up, found nothing past the read cursor and settled
      // on "nothing unread" for good, one frame before the tapped message
      // landed. No UNREAD MESSAGES label, on the one entry that most needs one.
      await repo.openRoom('a', owner: screenA);
      cv.issued.firstWhere((s) => s.label == 'messages:list/a').fireOnData([
        {
          '_id': 'm1',
          'roomId': 'a',
          'userId': 'someone',
          'createdAt': DateTime.now().millisecondsSinceEpoch,
        },
      ]);
      expect(repo.hasLiveMessages('a'), isTrue);

      await repo.openRoom('a', owner: Object());

      expect(
        repo.hasLiveMessages('a'),
        isFalse,
        reason:
            'a second screen for the same room is a second reading session, '
            'and nothing the first one learned from the wire is still true of '
            'a socket that has been asleep since',
      );
    });

    test('clears on the next open, like hasLoadedInitial does', () async {
      await repo.openRoom('a', owner: screenA);
      cv.issued.firstWhere((s) => s.label == 'messages:list/a').fireOnData([
        {
          '_id': 'm1',
          'roomId': 'a',
          'userId': 'someone',
          'createdAt': DateTime.now().millisecondsSinceEpoch,
        },
      ]);
      expect(repo.hasLiveMessages('a'), isTrue);

      repo.closeRoom(screenA);
      await repo.openRoom('a', owner: screenB);

      expect(
        repo.hasLiveMessages('a'),
        isFalse,
        reason:
            'a fresh open has not heard from this subscription generation '
            'yet, regardless of what the last one delivered',
      );
    });
  });

  group('synchronous-notify safety', () {
    test(
      'openRoom never notifies before its first await, even with warm messages',
      () async {
        // `RoomScreen.initState` calls `repo.openRoom(...)` synchronously and
        // fire-and-forget, and can itself run mid-build (e.g. inside a
        // LayoutBuilder rebuild triggered during layout). If openRoom's
        // synchronous prefix could reach `notifyListeners()` before its
        // first await, a listener's `setState()` would run on that SAME
        // synchronous stack and crash with "setState() or markNeedsBuild()
        // called during build."
        //
        // The dangerous path is a room whose messages are already warm in
        // memory (closeRoom keeps them, for instant re-entry) — the cache
        // read that used to guarantee a yield is skipped entirely, and the
        // one-shot `listMessages` fetch that also used to guarantee one is
        // gone (see chat_repository.dart's openRoom).
        repo.debugSeedMessages('a', [
          ChatMessage(
            id: 'm1',
            roomId: 'a',
            senderId: 'someone',
            senderName: 'Someone',
            content: 'hi',
            createdAt: DateTime.now(),
          ),
        ]);

        var notifiedSynchronously = false;
        void listener() => notifiedSynchronously = true;
        repo.addListener(listener);

        // ignore: unawaited_futures
        repo.openRoom('a', owner: screenA);

        expect(
          notifiedSynchronously,
          isFalse,
          reason:
              'openRoom must yield at least once before its first '
              'notifyListeners(), or a listener can setState() on the '
              'caller\'s own synchronous stack mid-build',
        );

        repo.removeListener(listener);
        await _pump();
      },
    );
  });
}
