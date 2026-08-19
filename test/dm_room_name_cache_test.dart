import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monkeyhub/backend/chat_api.dart';
import 'package:monkeyhub/backend/convex_client.dart';
import 'package:monkeyhub/data/cache_store.dart';
import 'package:monkeyhub/data/chat_repository.dart';
import 'package:monkeyhub/models/chat_message.dart';
import 'package:monkeyhub/models/chat_room.dart';
import 'package:monkeyhub/models/chat_user.dart';
import 'package:monkeyhub/models/friend_request.dart';

/// A DM room carries no display name of its own — it's `dm:<id>_<id>`, and
/// `RoomCard`/`RoomGridTile`/the long-press preview all resolve the real name
/// and avatar client-side, against `ChatRepository.otherUserFor`, which reads
/// the friends list. `CacheStore` hydrated cached ROOMS on cold start but
/// never cached FRIENDS, so a launch that painted the room list before (or
/// without) a successful `friends:listFriends` round trip showed every DM by
/// its raw `dm:...` name — the "a lot of rooms show dm:xxx instead of the
/// real name" bug. These pin the fix: friends now hydrate from disk
/// alongside rooms, so a DM resolves even when the network never delivers.
class _OfflineApi extends Fake implements ChatApi {
  @override
  Future<List<ChatRoom>> listUserRooms(String userId) async =>
      throw StateError('offline');

  @override
  Future<List<ChatUser>> listFriends(String userId) async =>
      throw StateError('offline');

  @override
  Future<List<FriendRequest>> listIncomingDirectRequests(String userId) async =>
      throw StateError('offline');

  @override
  Future<List<FriendRequest>> listOutgoingDirectRequests(String userId) async =>
      throw StateError('offline');

  @override
  Future<List<ChatMessage>> listMessages({
    required String roomId,
    int limit = 100,
    String? viewerUserId,
  }) async => throw StateError('offline');
}

class _FakeSub extends Fake implements Subscription {
  @override
  void cancel() {}
}

class _FakeCv extends Fake implements ConvexBackend {
  @override
  Future<Subscription> subscribe(
    String name,
    Map<String, dynamic> args, {
    required void Function(dynamic) onData,
    void Function(Object error)? onError,
  }) async => _FakeSub();

  @override
  bool get isConnected => true;

  @override
  Stream<bool> get connectionState => const Stream<bool>.empty();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tmp;

  setUpAll(() async {
    // CacheStore memoises the documents directory on first use, so the
    // channel has to answer before anything in this file touches it.
    tmp = await Directory.systemTemp.createTemp('dm_room_name_cache');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/path_provider'),
          (_) async => tmp.path,
        );
  });

  tearDownAll(() async {
    if (await tmp.exists()) await tmp.delete(recursive: true);
  });

  final friend = ChatUser(
    id: 'friend1',
    username: 'friendo',
    name: 'Friend One',
    status: 'offline',
  );

  final dmRoom = ChatRoom(
    id: 'room1',
    name: 'dm:regular:friend1:me',
    createdBy: 'me',
    createdAt: DateTime(2026, 1, 1),
    isPrivate: true,
    memberCount: 2,
    participantIds: const ['me', 'friend1'],
  );

  test('ChatUser round-trips through toJson/fromJson', () {
    final restored = ChatUser.fromJson(friend.toJson());
    expect(restored.id, friend.id);
    expect(restored.username, friend.username);
    expect(restored.name, friend.name);
    expect(restored.status, friend.status);
    expect(restored.displayName, 'Friend One');
  });

  test('CacheStore round-trips a saved friends list', () async {
    final dir = Directory('${tmp.path}/cache/direct-friends-user');
    await dir.create(recursive: true);
    await File('${dir.path}/friends.json')
        .writeAsString(jsonEncode([friend.toJson()]));

    final loaded = await CacheStore.instance.loadFriends('direct-friends-user');
    expect(loaded, hasLength(1));
    expect(loaded.single.displayName, 'Friend One');
  });

  test(
    'a DM resolves its real name from cache even when the network never answers',
    () async {
      const userId = 'me';
      final dir = Directory('${tmp.path}/cache/$userId');
      await dir.create(recursive: true);
      await File('${dir.path}/rooms.json')
          .writeAsString(jsonEncode([dmRoom.toJson()]));
      await File('${dir.path}/friends.json')
          .writeAsString(jsonEncode([friend.toJson()]));

      final repo = ChatRepository(api: _OfflineApi(), cv: _FakeCv());
      await repo.attach(userId);

      final room = repo.rooms.singleWhere((r) => r.id == 'room1');
      // Before the fix this was null — friends were never hydrated from
      // disk, so `RoomCard` fell back to `room.name`: the raw
      // `dm:regular:friend1:me` string.
      expect(repo.otherUserFor(room)?.displayName, 'Friend One');
    },
  );
}
