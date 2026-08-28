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

/// The macOS Dock icon never badged, and this is the reason.
///
/// The open room's read cursor advanced on every arriving message, whether or
/// not anybody was there. Everywhere else that is a safe shortcut — a
/// backgrounded mobile app is suspended within seconds, its subscriptions stop
/// firing, and nothing arrives to be marked read. macOS breaks the assumption on
/// purpose: the red X and ⌘W hide the window and keep the process alive, because
/// the process IS the delivery path (macos/Runner/MainFlutterWindow.swift). So
/// messages kept landing in the open room and kept being marked read for
/// somebody who had put the window away hours ago — `unreadCount` never left
/// zero, the badge had nothing to draw, and the sender was told SEEN for a
/// message that had never been on a screen. A background browser tab had the
/// same hole.
///
/// These pin the rule that fixes it: the cursor only moves while somebody is
/// present, and the read that was held back is taken on the way back in.

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
  }) async {
    reads.add((roomId: roomId, upTo: upTo));
  }

  @override
  Future<void> clearTyping({
    required String roomId,
    required String userId,
  }) async {}
}

void main() {
  // The platform channels `openRoom` touches (push dismissal, path_provider
  // behind CacheStore) throw MissingPluginException without a binding, which is
  // the variety their call sites already swallow.
  TestWidgetsFlutterBinding.ensureInitialized();

  late _FakeCv cv;
  late _FakeApi api;
  late ChatRepository repo;
  late Object screen;

  /// Drives the real lifecycle channel rather than the binding's `@protected`
  /// handler, so this exercises the same path the OS does.
  ///
  /// Walked one state at a time on purpose: `resumed` → `hidden` is not a
  /// transition the framework will accept in one hop, and neither does macOS
  /// produce it — hiding a window goes through `inactive` first.
  Future<void> lifecycle(List<AppLifecycleState> path) async {
    for (final state in path) {
      await TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .handlePlatformMessage(
            'flutter/lifecycle',
            const StringCodec().encodeMessage(state.toString()),
            (_) {},
          );
    }
  }

  /// Longer than `_kReadDebounce` (400ms), which coalesces a burst of arrivals
  /// into one mutation.
  Future<void> settleRead() =>
      Future<void>.delayed(const Duration(milliseconds: 550));

  void deliver(String roomId, String messageId, DateTime at) {
    cv.issued.firstWhere((s) => s.label == 'messages:list/$roomId').fireOnData([
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
    await repo.attach('me');
    await lifecycle([AppLifecycleState.resumed]);
  });

  tearDown(() async {
    // Leave the binding where the next test expects to find it.
    await lifecycle([AppLifecycleState.resumed]);
  });

  /// Opens the room and lets its ENTRY read settle, then clears the log.
  ///
  /// Entering a room sends a read of its own (`_startSecondaryRoomSubscriptions`),
  /// which is correct and not what these tests are about — every assertion below
  /// is about what happens to messages arriving AFTER the room is established.
  Future<void> enterRoom() async {
    await repo.openRoom('a', owner: screen);
    deliver('a', 'm0', DateTime.now().subtract(const Duration(minutes: 5)));
    await settleRead();
    expect(api.reads, isNotEmpty, reason: 'entering a room reads it');
    api.reads.clear();
  }

  test('a message arriving while you are looking marks the room read', () async {
    await enterRoom();

    deliver('a', 'm1', DateTime.now());
    await settleRead();

    expect(
      api.reads.map((r) => r.roomId),
      ['a'],
      reason: 'the unchanged case: present, room open, cursor advances',
    );
  });

  test('a message arriving while the window is away does NOT', () async {
    await enterRoom();
    await lifecycle([AppLifecycleState.inactive, AppLifecycleState.hidden]);

    deliver('a', 'm1', DateTime.now());
    await settleRead();

    expect(
      api.reads,
      isEmpty,
      reason:
          'nobody is looking at the hidden window, so the room has to stay '
          'unread — this is the count the Dock badge is drawn from',
    );
  });

  test('coming back takes the read that was held', () async {
    await enterRoom();
    await lifecycle([AppLifecycleState.inactive, AppLifecycleState.hidden]);

    final arrived = DateTime.now();
    deliver('a', 'm1', arrived);
    await settleRead();
    expect(api.reads, isEmpty);

    await lifecycle([AppLifecycleState.inactive, AppLifecycleState.resumed]);
    repo.flushDeferredRead();
    await settleRead();

    expect(api.reads.length, 1);
    expect(api.reads.single.roomId, 'a');
    expect(
      api.reads.single.upTo!.millisecondsSinceEpoch,
      arrived.millisecondsSinceEpoch,
      reason:
          'the held cursor, not a fresh one — the messages on screen are '
          'exactly what coming back reads',
    );
  });

  test('only the newest held cursor is taken, not one per message', () async {
    await enterRoom();
    await lifecycle([AppLifecycleState.inactive, AppLifecycleState.hidden]);

    final first = DateTime.now();
    final last = first.add(const Duration(seconds: 30));
    deliver('a', 'm1', first);
    deliver('a', 'm2', last);
    await settleRead();

    await lifecycle([AppLifecycleState.inactive, AppLifecycleState.resumed]);
    repo.flushDeferredRead();
    await settleRead();

    expect(api.reads.length, 1);
    expect(
      api.reads.single.upTo!.millisecondsSinceEpoch,
      last.millisecondsSinceEpoch,
    );
  });

  test('leaving the room while away discards the held read', () async {
    await enterRoom();
    await lifecycle([AppLifecycleState.inactive, AppLifecycleState.hidden]);
    deliver('a', 'm1', DateTime.now());
    await settleRead();

    repo.closeRoom(screen);

    await lifecycle([AppLifecycleState.inactive, AppLifecycleState.resumed]);
    repo.flushDeferredRead();
    await settleRead();

    expect(
      api.reads,
      isEmpty,
      reason:
          'walking out of a chat you never looked at is the clearest possible '
          'statement that you did not read it',
    );
  });

  test('entering a room while away does not read it either', () async {
    // The reconnect case: the socket drops and re-subscribes while the window
    // is hidden, re-entering the room with a live window nobody has seen. The
    // on-entry read would otherwise walk straight around the deferral.
    await lifecycle([AppLifecycleState.inactive, AppLifecycleState.hidden]);

    await repo.openRoom('a', owner: screen);
    deliver('a', 'm1', DateTime.now());
    await settleRead();

    expect(api.reads, isEmpty);
  });

  test('flushing with nothing held sends nothing', () async {
    await enterRoom();
    repo.flushDeferredRead();
    await settleRead();

    expect(api.reads, isEmpty);
  });
}
