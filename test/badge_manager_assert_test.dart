import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monkeyhub/backend/chat_api.dart';
import 'package:monkeyhub/backend/convex_client.dart';
import 'package:monkeyhub/data/chat_repository.dart';
import 'package:monkeyhub/models/chat_message.dart';
import 'package:monkeyhub/models/chat_room.dart';
import 'package:monkeyhub/models/chat_user.dart';
import 'package:monkeyhub/models/friend_request.dart';
import 'package:monkeyhub/push/badge_manager.dart';

/// The app icon kept the number a push had put there, on a room the reader had
/// just opened from that very push and read.
///
/// [BadgeManager] wrote to the platform only when its own total changed, and
/// its total is process state that starts at 0 and freezes while the app is
/// away. Every push carries an absolute `ios_badgeCount` which APNs applies
/// whether this process is running or not — so the icon says 1 while the
/// manager still holds the 0 it had when the app was backgrounded. A
/// notification tap then opens the room at once and `markRoomRead` can land
/// before `rooms:listUserRooms` has refired even once, so the first fire after
/// coming back already reads 0: unchanged, no write, icon stuck.
///
/// `sync()` was the intended correction, but it is behind a 500ms timer, a 30s
/// throttle and a signed-in check in app.dart — none of which the tap waits
/// for.

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
  List<ChatRoom> seedRooms = const [];

  @override
  Future<List<ChatRoom>> listUserRooms(String userId) async => seedRooms;

  @override
  Future<List<ChatUser>> listFriends(String userId) async => const [];

  @override
  Future<String> ensureSavedMessagesRoom({required String userId}) async => '';

  @override
  Future<List<FriendRequest>> listIncomingDirectRequests(String u) async =>
      const [];

  @override
  Future<List<FriendRequest>> listOutgoingDirectRequests(String u) async =>
      const [];

  @override
  Future<List<ChatMessage>> listMessages({
    required String roomId,
    int limit = 100,
    String? viewerUserId,
  }) async => throw StateError('offline');
}

Map<String, dynamic> roomRow(String id, {int unreadCount = 0}) => {
  '_id': id,
  'name': id,
  'createdBy': 'someone-else',
  'createdAt': 0,
  'memberCount': 2,
  'isMember': true,
  'unreadCount': unreadCount,
};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _FakeCv cv;
  late _FakeApi api;
  late ChatRepository repo;
  late List<int> written;

  setUp(() async {
    cv = _FakeCv();
    api = _FakeApi();
    repo = ChatRepository(api: api, cv: cv);
    written = [];
    // The channel each runner implements — iOS/macOS/Windows/Linux all land
    // here, and what it receives is the only observable this has.
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('monkeyhub/badge'),
          (call) async {
            if (call.method == 'set') {
              written.add(((call.arguments as Map)['count'] as num).toInt());
            }
            return null;
          },
        );
  });

  tearDown(() {
    BadgeManager.instance.unbind();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('monkeyhub/badge'),
          null,
        );
  });

  void fireRooms(List<Map<String, dynamic>> rows) => cv.issued
      .lastWhere((s) => s.label == 'rooms:listUserRooms/-')
      .fireOnData(rows);

  test('a room list that comes back already read still clears the icon', () async {
    await repo.attach('me');
    BadgeManager.instance.bind(repo);
    written.clear();

    // Away: a push set the icon to 1 behind our back, and nothing in this
    // process saw it.
    BadgeManager.instance.invalidatePlatformBadge();

    // Back, and the reader was quick: markRoomRead beat the subscription, so
    // its first fire since resuming already says nothing is unread.
    fireRooms([roomRow('a', unreadCount: 0)]);
    await Future<void>.delayed(Duration.zero);

    expect(
      written,
      contains(0),
      reason:
          'the number did not move, but the icon was never told — this is the '
          'badge that survives reading the room it belongs to',
    );
  });

  test('an unchanged count writes nothing once the icon is known', () async {
    await repo.attach('me');
    BadgeManager.instance.bind(repo);
    fireRooms([roomRow('a', unreadCount: 2)]);
    await Future<void>.delayed(Duration.zero);
    expect(written, contains(2));
    written.clear();

    // A room-list fire that changed no counts — a reaction, a preview, a
    // typing echo. The icon already shows 2 and this must not re-write it.
    fireRooms([roomRow('a', unreadCount: 2)]);
    await Future<void>.delayed(Duration.zero);

    expect(
      written,
      isEmpty,
      reason:
          'one assert per trip through the background, not one per delivery — '
          'this fires on every message in any room',
    );
  });

  test('a real change still writes, background trip or not', () async {
    await repo.attach('me');
    BadgeManager.instance.bind(repo);
    fireRooms([roomRow('a', unreadCount: 2)]);
    await Future<void>.delayed(Duration.zero);
    written.clear();

    fireRooms([roomRow('a', unreadCount: 5)]);
    await Future<void>.delayed(Duration.zero);

    expect(written, [5]);
    expect(BadgeManager.instance.total, 5);
  });

  test('the assert waits for the room list, not the resume edge', () async {
    api.seedRooms = [ChatRoom.fromJson(roomRow('a', unreadCount: 3))];
    await repo.attach('me');
    BadgeManager.instance.bind(repo);
    await Future<void>.delayed(Duration.zero);
    written.clear();

    BadgeManager.instance.invalidatePlatformBadge();
    // Repo traffic that is not a room list: typing, presence, a friend list.
    repo.notifyListeners();
    await Future<void>.delayed(Duration.zero);

    expect(
      written,
      isEmpty,
      reason:
          'asserting off the stale pre-background total would write it over a '
          "push's newer one; the room list answering is what makes it worth "
          'trusting',
    );
  });
}
