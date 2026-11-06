import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monkeyhub/backend/chat_api.dart';
import 'package:monkeyhub/backend/convex_client.dart';
import 'package:monkeyhub/data/chat_repository.dart';
import 'package:monkeyhub/models/chat_room.dart';
import 'package:monkeyhub/models/chat_user.dart';
import 'package:monkeyhub/models/friend_request.dart';

/// The global typing subscription watches only the rooms on the chat list
/// (minus the open one), resubscribes only when that set changes, and is
/// paused while the app is backgrounded. The rooms list payload is deduped.

class _Sub extends Fake implements Subscription {
  bool cancelled = false;
  @override
  void cancel() => cancelled = true;
}

class _Cv extends Fake implements ConvexBackend {
  final typing = <({Map<String, dynamic> args, _Sub sub})>[];
  void Function(dynamic)? roomsOnData;

  @override
  Future<Subscription> subscribe(
    String name,
    Map<String, dynamic> args, {
    required void Function(dynamic) onData,
    void Function(Object error)? onError,
  }) async {
    final sub = _Sub();
    if (name == 'rooms:listUserRooms') roomsOnData = onData;
    if (name == 'typing:getTypingForUser') typing.add((args: args, sub: sub));
    return sub;
  }

  @override
  bool get isConnected => true;

  @override
  Stream<bool> get connectionState => const Stream<bool>.empty();
}

class _Api extends Fake implements ChatApi {
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
  Future<String> ensureSavedMessagesRoom({required String userId}) async => '';
}

Map<String, dynamic> _room(String id, {int unread = 0, bool archived = false}) => {
      '_id': id,
      'name': id,
      'createdBy': 'u',
      'createdAt': 1,
      'isPrivate': true,
      'memberCount': 2,
      'unreadCount': unread,
      'isArchived': archived,
    };

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('scoped to listed rooms, deduped, paused in background', () async {
    final cv = _Cv();
    final repo = ChatRepository(cv: cv, api: _Api());
    await repo.attach('u1');
    // Nothing on screen yet: no typing subscription at all.
    expect(cv.typing, isEmpty);

    cv.roomsOnData!([_room('a'), _room('b'), _room('z', archived: true)]);
    await Future<void>.delayed(Duration.zero);
    expect(cv.typing, hasLength(1));
    expect((cv.typing.last.args['roomIds'] as List).toSet(), {'a', 'b'});

    // Same ids, different unread: no resubscribe.
    cv.roomsOnData!([_room('a', unread: 3), _room('b'), _room('z', archived: true)]);
    await Future<void>.delayed(Duration.zero);
    expect(cv.typing, hasLength(1));

    // Backgrounded: dropped. Foregrounded: back with the same ids.
    repo.didChangeAppLifecycleState(AppLifecycleState.paused);
    expect(cv.typing.last.sub.cancelled, isTrue);
    repo.didChangeAppLifecycleState(AppLifecycleState.resumed);
    await Future<void>.delayed(Duration.zero);
    expect(cv.typing, hasLength(2));
    expect((cv.typing.last.args['roomIds'] as List).toSet(), {'a', 'b'});

    // A new room joins the list: the set changed, so one resubscribe.
    cv.roomsOnData!([_room('a'), _room('b'), _room('c')]);
    await Future<void>.delayed(Duration.zero);
    expect(cv.typing, hasLength(3));
    expect(cv.typing[1].sub.cancelled, isTrue);
    expect((cv.typing.last.args['roomIds'] as List).toSet(), {'a', 'b', 'c'});
    await repo.detach();
  });
}
