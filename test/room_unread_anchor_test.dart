import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monkeyhub/backend/chat_api.dart';
import 'package:monkeyhub/backend/convex_client.dart';
import 'package:monkeyhub/data/chat_repository.dart';
import 'package:monkeyhub/models/chat_message.dart';
import 'package:monkeyhub/models/chat_room.dart';
import 'package:monkeyhub/models/chat_user.dart';
import 'package:monkeyhub/models/friend_request.dart';

/// The UNREAD MESSAGES divider and the scroll that lands on it only ever
/// appeared off a chat-list tap. Opening the same room from its own
/// notification banner put the reader at the bottom with no label, and left
/// the room badged afterwards even though they had just read it.
///
/// Both symptoms are one thing: the screen used to decide from the room list
/// in memory at the instant it mounted, and on a notification tap that list
/// has not caught up with the push that caused the open.
///
///   * cold start — the tap pushes the screen from `_bootstrap`, while
///     `attach` is still running. There is no room list at all, and no
///     `_userId` either, so the room came up subscribed read-blind: nothing
///     cached, nothing marked read, no notifications dismissed, for the rest
///     of the session. That is the badge that survives reading the room.
///   * warm start — the list is the one frozen when the app went away. Its
///     `lastReadAt` is still true; its `unreadCount` is the pre-push value,
///     which for a room you had just read is 0. The old
///     `unreadCount > 0` gate read that zero and disarmed itself.
///
/// These pin the repository half of the fix: the cursor is pinned before
/// anything can advance it, resolved from the room list whenever it arrives,
/// and a room opened before there was an account to open it as is repaired.

class _FakeSub extends Fake implements Subscription {
  _FakeSub(this.label, this.fireOnData);

  final String label;
  final void Function(dynamic) fireOnData;

  @override
  void cancel() {}
}

class _FakeCv extends Fake implements ConvexBackend {
  final List<_FakeSub> issued = [];

  @override
  Future<Subscription> subscribe(
    String name,
    Map<String, dynamic> args, {
    required void Function(dynamic) onData,
    void Function(Object error)? onError,
  }) async {
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
  /// Every read cursor this repo actually committed, in order.
  final List<({String roomId, DateTime? upTo})> reads = [];

  /// What `listUserRooms` answers during `attach`. Empty is the cold start
  /// that has to fall through to the subscription.
  List<ChatRoom> seedRooms = const [];

  @override
  Future<List<ChatRoom>> listUserRooms(String userId) async => seedRooms;

  @override
  Future<List<ChatUser>> listFriends(String userId) async => const [];

  /// Not a `Fake` miss: attach runs this alongside the seed above, inside one
  /// `Future.wait`, and an unimplemented member throws before `catchError` can
  /// be attached — which takes the whole seed with it and leaves the repo with
  /// no room list at all.
  @override
  Future<String> ensureSavedMessagesRoom({required String userId}) async => '';

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
  }) async {
    reads.add((roomId: roomId, upTo: upTo));
  }

  @override
  Future<void> clearTyping({
    required String roomId,
    required String userId,
  }) async {}
}

/// One `rooms:listUserRooms` row. Only the fields the anchor reads are
/// interesting; the rest are what `ChatRoom.fromJson` insists on.
Map<String, dynamic> roomRow(
  String id, {
  DateTime? lastReadAt,
  DateTime? lastMessageTime,
  int unreadCount = 0,
}) => {
  '_id': id,
  'name': id,
  'createdBy': 'someone-else',
  'createdAt': 0,
  'memberCount': 2,
  'isMember': true,
  if (lastReadAt != null) 'lastReadAt': lastReadAt.millisecondsSinceEpoch,
  if (lastMessageTime != null)
    'lastMessageTime': lastMessageTime.millisecondsSinceEpoch,
  'unreadCount': unreadCount,
};

/// Truncated to milliseconds, which is the precision the wire has: room rows
/// carry `millisecondsSinceEpoch`, so a `DateTime.now()` compared against its
/// own round trip differs by the microseconds it dropped on the way.
DateTime agoMs(Duration d) => DateTime.fromMillisecondsSinceEpoch(
      DateTime.now().subtract(d).millisecondsSinceEpoch,
    );

void main() {
  // The platform channels `openRoom` touches (push dismissal, path_provider
  // behind CacheStore) throw MissingPluginException without a binding, which is
  // the variety their call sites already swallow.
  TestWidgetsFlutterBinding.ensureInitialized();

  late _FakeCv cv;
  late _FakeApi api;
  late ChatRepository repo;
  late Object screen;

  Future<void> lifecycle(AppLifecycleState state) =>
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .handlePlatformMessage(
            'flutter/lifecycle',
            StringCodec().encodeMessage(state.toString()),
            (_) {},
          );

  /// Longer than `_kReadDebounce` (400ms), which coalesces a burst of arrivals
  /// into one mutation.
  Future<void> settleRead() =>
      Future<void>.delayed(const Duration(milliseconds: 550));

  void fireRooms(List<Map<String, dynamic>> rows) {
    cv.issued
        .lastWhere((s) => s.label == 'rooms:listUserRooms/-')
        .fireOnData(rows);
  }

  void deliver(String roomId, String messageId, DateTime at) {
    cv.issued.lastWhere((s) => s.label == 'messages:list/$roomId').fireOnData([
      {
        '_id': messageId,
        'roomId': roomId,
        'userId': 'someone-else',
        'createdAt': at.millisecondsSinceEpoch,
      },
    ]);
  }

  setUp(() async {
    cv = _FakeCv();
    api = _FakeApi();
    repo = ChatRepository(api: api, cv: cv);
    screen = Object();
    await lifecycle(AppLifecycleState.resumed);
  });

  tearDown(() => lifecycle(AppLifecycleState.resumed));

  test(
    'a warm tap anchors on the stale list\'s cursor, whatever its count says',
    () async {
      final read = agoMs(const Duration(hours: 1));
      // The room list as it stood when the app went to the background: the
      // cursor is still true, the count is the pre-push zero.
      api.seedRooms = [
        ChatRoom.fromJson(roomRow('a', lastReadAt: read, unreadCount: 0)),
      ];
      await repo.attach('me');

      repo.beginUnreadAnchor('a');

      expect(
        repo.unreadAnchorSettled('a'),
        isTrue,
        reason: 'the room is already known, so there is nothing to wait for',
      );
      expect(
        repo.unreadAnchorFor('a'),
        read,
        reason:
            'a stale unreadCount is the one field a backgrounded list gets '
            'wrong; the cursor it was frozen with is exactly what the divider '
            'is drawn from',
      );
    },
  );

  test('a cold tap waits for the room list rather than answering "none"', () async {
    // Nothing on disk, nothing from the seed: the notification tap has pushed
    // the room screen while attach is still running.
    await repo.attach('me');
    repo.beginUnreadAnchor('a');

    expect(
      repo.unreadAnchorSettled('a'),
      isFalse,
      reason:
          'answering now would mean landing at the bottom with no divider on '
          'exactly the entry the divider exists for',
    );
    expect(repo.unreadAnchorFor('a'), isNull);

    final read = agoMs(const Duration(hours: 1));
    fireRooms([roomRow('a', lastReadAt: read, unreadCount: 3)]);

    expect(repo.unreadAnchorSettled('a'), isTrue);
    expect(repo.unreadAnchorFor('a'), read);
  });

  test('the anchor latches once, so our own read cannot move it', () async {
    await repo.attach('me');
    repo.beginUnreadAnchor('a');

    final read = agoMs(const Duration(hours: 1));
    fireRooms([roomRow('a', lastReadAt: read, unreadCount: 3)]);

    // The echo of this device's own markRoomRead: same room, cursor now at the
    // newest message. Taking this would drop the divider below the messages it
    // is meant to be labelling.
    fireRooms([roomRow('a', lastReadAt: DateTime.now(), unreadCount: 0)]);

    expect(repo.unreadAnchorFor('a'), read);
  });

  test('re-entering the room takes a fresh cursor', () async {
    final first = agoMs(const Duration(hours: 2));
    api.seedRooms = [ChatRoom.fromJson(roomRow('a', lastReadAt: first))];
    await repo.attach('me');

    repo.beginUnreadAnchor('a');
    expect(repo.unreadAnchorFor('a'), first);

    // Read to the end, walked out, came back to a new message.
    final second = agoMs(const Duration(minutes: 1));
    fireRooms([roomRow('a', lastReadAt: second, unreadCount: 1)]);
    repo.beginUnreadAnchor('a');

    expect(
      repo.unreadAnchorFor('a'),
      second,
      reason: 'a second visit is a second reading session, not the first one',
    );
  });

  test('the anchor belongs to one room at a time', () async {
    final read = agoMs(const Duration(hours: 1));
    api.seedRooms = [ChatRoom.fromJson(roomRow('a', lastReadAt: read))];
    await repo.attach('me');

    repo.beginUnreadAnchor('a');
    expect(repo.unreadAnchorFor('b'), isNull);
    expect(repo.unreadAnchorSettled('b'), isFalse);
  });

  test('entering an unknown room holds the read that would erase the cursor',
      () async {
    await repo.attach('me');
    repo.beginUnreadAnchor('a');
    await repo.openRoom('a', owner: screen);
    await settleRead();

    expect(
      api.reads,
      isEmpty,
      reason:
          'with nothing held, the entry read marks the room read to its newest '
          'message — running it before the cursor has been captured erases the '
          'very thing the divider is drawn from',
    );
  });

  test('a room opened before attach is re-opened once there is an account',
      () async {
    // The cold start: the notification tap mounts the screen and calls
    // openRoom while the repo still has no user id.
    await repo.openRoom('a', owner: screen);
    expect(
      api.reads,
      isEmpty,
      reason: 'there is no account to read as yet',
    );
    final blind = cv.issued.where((s) => s.label == 'messages:list/a').length;
    expect(blind, 1);

    repo.beginUnreadAnchor('a');
    api.seedRooms = [
      ChatRoom.fromJson(roomRow('a', lastReadAt: agoMs(const Duration(hours: 1)))),
    ];
    await repo.attach('me');
    // The repair is unawaited inside attach, and openRoom itself awaits a disk
    // read, the push inbox and a subscribe before it registers anything.
    await Future<void>.delayed(const Duration(milliseconds: 100));

    expect(
      cv.issued.where((s) => s.label == 'messages:list/a').length,
      greaterThan(blind),
      reason:
          'a room subscribed with no user id caches nothing, marks nothing '
          'read and dismisses no notifications — it has to be re-opened, not '
          'left as it is for the rest of the session',
    );

    deliver('a', 'm1', DateTime.now());
    await settleRead();

    expect(
      api.reads.map((r) => r.roomId),
      contains('a'),
      reason: 'the room the reader came from a banner to read is now read',
    );
  });

  test('leaving the room keeps the anchor for the screen replacing it', () async {
    final read = agoMs(const Duration(hours: 1));
    api.seedRooms = [ChatRoom.fromJson(roomRow('a', lastReadAt: read))];
    await repo.attach('me');

    // The route transition: the incoming screen pins the room and opens it,
    // and only then is the outgoing screen disposed.
    repo.beginUnreadAnchor('a');
    await repo.openRoom('a', owner: screen);
    repo.closeRoom(Object());

    expect(
      repo.unreadAnchorFor('a'),
      read,
      reason:
          'the departing screen must not take the answer its replacement is '
          'waiting on',
    );
  });

  test('signing out drops the anchor with everything else', () async {
    api.seedRooms = [
      ChatRoom.fromJson(roomRow('a', lastReadAt: agoMs(const Duration(hours: 1)))),
    ];
    await repo.attach('me');
    repo.beginUnreadAnchor('a');
    expect(repo.unreadAnchorSettled('a'), isTrue);

    await repo.detach();

    expect(
      repo.unreadAnchorSettled('a'),
      isFalse,
      reason: 'the next account does not inherit this one\'s reading position',
    );
    expect(repo.unreadAnchorFor('a'), isNull);
  });

  test('the transcript marks read even before the re-open lands', () async {
    // The narrower window: attach has published an id, but its subscriptions
    // are still registering. The messages closure was made with a null `me`.
    await repo.openRoom('a', owner: screen);
    unawaited(repo.attach('me'));

    deliver('a', 'm1', DateTime.now());
    await settleRead();

    expect(
      api.reads.map((r) => r.roomId),
      contains('a'),
      reason:
          'the messages on screen are being read right now; the cursor cannot '
          'wait on five subscription registrations',
    );
  });
}
