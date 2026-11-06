import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:monkeyhub/backend/chat_api.dart';
import 'package:monkeyhub/backend/convex_client.dart';
import 'package:monkeyhub/data/chat_repository.dart';
import 'package:monkeyhub/models/chat_room.dart';
import 'package:monkeyhub/models/chat_user.dart';
import 'package:monkeyhub/models/friend_request.dart';

/// The server stopped sending the viewer's own `lastDeliveredAt` in
/// `rooms:listUserRooms` (it is null now: reading it re-ran the whole list on
/// every delivery report). The client's in-memory guard is therefore the only
/// thing that keeps it from reporting a room twice, and these pin it: at most
/// one delivery mutation per room per new `lastMessageTime`.

class _FakeSub extends Fake implements Subscription {
  @override
  void cancel() {}
}

class _FakeCv extends Fake implements ConvexBackend {
  void Function(dynamic)? onRooms;

  @override
  Future<Subscription> subscribe(
    String name,
    Map<String, dynamic> args, {
    required void Function(dynamic) onData,
    void Function(Object error)? onError,
  }) async {
    if (name == 'rooms:listUserRooms') onRooms = onData;
    return _FakeSub();
  }

  @override
  bool get isConnected => true;

  @override
  Stream<bool> get connectionState => const Stream<bool>.empty();
}

class _FakeApi extends Fake implements ChatApi {
  final List<({String roomId, DateTime? upTo})> deliveries = [];

  /// How many upcoming calls fail (they are still recorded in [deliveries]).
  int failNext = 0;

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

  @override
  Future<void> markRoomDelivered({
    required String roomId,
    required String userId,
    DateTime? upTo,
  }) async {
    deliveries.add((roomId: roomId, upTo: upTo));
    if (failNext > 0) {
      failNext--;
      throw Exception('offline');
    }
  }
}

Map<String, dynamic> _room(String id, int lastMessageTime, {int unread = 2}) => {
      '_id': id,
      'name': 'Room $id',
      'createdBy': 'u',
      'createdAt': 1000,
      'isPrivate': true,
      'memberCount': 3,
      'lastMessageTime': lastMessageTime,
      'unreadCount': unread,
      // The server's value since C1: always null.
      'lastDeliveredAt': null,
    };

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _FakeCv cv;
  late _FakeApi api;
  late ChatRepository repo;

  // Longer than `_kDeliveryDebounce` (1200ms).
  Future<void> settle() =>
      Future<void>.delayed(const Duration(milliseconds: 1400));

  setUp(() async {
    cv = _FakeCv();
    api = _FakeApi();
    ChatRepository.deliveryRetryDelay = const Duration(milliseconds: 300);
    repo = ChatRepository(api: api, cv: cv);
    await repo.attach('me');
  });

  test('a room with unread is reported once, without a server cursor', () async {
    cv.onRooms!([_room('a', 5000)]);
    await settle();
    expect(api.deliveries.map((d) => d.roomId), ['a']);
    expect(api.deliveries.single.upTo!.millisecondsSinceEpoch, 5000);
  });

  test('the same newest message is never reported twice', () async {
    cv.onRooms!([_room('a', 5000)]);
    await settle();
    // A different payload (the unread count moved) for the same newest message.
    cv.onRooms!([_room('a', 5000, unread: 3)]);
    await settle();
    expect(api.deliveries.length, 1);
  });

  test('a newer message is reported again, and only that room', () async {
    cv.onRooms!([_room('a', 5000), _room('b', 4000)]);
    await settle();
    expect(api.deliveries.length, 2);
    cv.onRooms!([_room('a', 6000), _room('b', 4000)]);
    await settle();
    expect(api.deliveries.map((d) => d.roomId), ['a', 'b', 'a']);
    expect(api.deliveries.last.upTo!.millisecondsSinceEpoch, 6000);
  });

  test('a read room (no unread) is not reported', () async {
    cv.onRooms!([_room('a', 5000, unread: 0)]);
    await settle();
    expect(api.deliveries, isEmpty);
  });

  test('a failed report is retried exactly once, then not again', () async {
    api.failNext = 1;
    cv.onRooms!([_room('a', 5000)]);
    await Future<void>.delayed(const Duration(milliseconds: 2000));
    // report fails, retry fires 300ms later and succeeds
    expect(api.deliveries.length, 2);
    expect(api.deliveries.every((d) => d.roomId == 'a'), isTrue);
    await Future<void>.delayed(const Duration(milliseconds: 600));
    expect(api.deliveries.length, 2);
  });

  test('a retry that also fails waits for the next trigger', () async {
    api.failNext = 2;
    cv.onRooms!([_room('a', 5000)]);
    await Future<void>.delayed(const Duration(milliseconds: 2000));
    expect(api.deliveries.length, 2);
    await Future<void>.delayed(const Duration(milliseconds: 600));
    expect(api.deliveries.length, 2); // no third timer
    // The next chat-list delivery (e.g. after a reconnect) reports it.
    cv.onRooms!([_room('a', 5000, unread: 3)]);
    await settle();
    expect(api.deliveries.length, 3);
  });

  test('a superseded report is not retried', () async {
    api.failNext = 1;
    cv.onRooms!([_room('a', 5000)]);
    await Future<void>.delayed(const Duration(milliseconds: 1300));
    expect(api.deliveries.length, 1); // failed, retry pending
    cv.onRooms!([_room('a', 6000)]); // newer message arrives before the retry
    await settle();
    // Only the 6000 report; the 5000 retry saw it was superseded.
    expect(api.deliveries.map((d) => d.upTo!.millisecondsSinceEpoch), [5000, 6000]);
  });
}
