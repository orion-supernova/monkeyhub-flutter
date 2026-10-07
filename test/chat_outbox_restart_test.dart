import 'dart:async';
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
import 'package:monkeyhub/models/enums.dart';
import 'package:monkeyhub/models/friend_request.dart';
import 'package:monkeyhub/models/pending_upload.dart';

/// A message stuck on "sending" used to live only in memory, so restarting
/// the app threw it away without a word. These pin the outbox: it reaches the
/// disk, comes back after a restart as a failed bubble with retry and discard,
/// and is NOT sent behind the sender's back by the next reconnect.

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
  }) async =>
      _FakeSub();

  @override
  bool get isConnected => false;

  @override
  Stream<bool> get connectionState => const Stream<bool>.empty();
}

class _FakeApi extends Fake implements ChatApi {
  /// While true every send fails the way a dead socket does.
  bool offline = true;

  /// `clientId` of every send that got through.
  final List<String?> delivered = [];

  @override
  Future<String> sendMessage({
    required String roomId,
    required String userId,
    required String content,
    MessageType type = MessageType.text,
    String? mediaStorageId,
    double? mediaWidth,
    double? mediaHeight,
    String? fileName,
    int? fileSize,
    String? mimeType,
    int? mediaDurationMs,
    String? posterStorageId,
    String? senderName,
    String? replyToId,
    bool viewOnce = false,
    String? clientId,
    List<String> mentionedUserIds = const [],
    bool mentionsEveryone = false,
    dynamic formatting,
    double? latitude,
    double? longitude,
    double? locationAccuracyM,
    int? liveDurationMs,
    dynamic expression,
  }) async {
    if (offline) throw TimeoutException('MutationTimeout');
    delivered.add(clientId);
    return 'server_${delivered.length}';
  }

  @override
  Future<DateTime> serverNow() async => DateTime.now();

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

  @override
  Future<void> clearTyping({
    required String roomId,
    required String userId,
  }) async {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tmp;

  setUpAll(() async {
    tmp = await Directory.systemTemp.createTemp('chat_outbox');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/path_provider'),
          (_) async => tmp.path,
        );
  });

  tearDownAll(() async {
    if (await tmp.exists()) await tmp.delete(recursive: true);
  });

  setUp(CacheStore.instance.discardPendingWrites);

  File outboxOf(String userId) =>
      File('${tmp.path}/cache/$userId/outbox/outbox.json');

  /// Waits for the debounced, chained outbox write to leave [length] entries
  /// on disk — polled rather than slept, so a loaded machine is not a failure.
  Future<List<dynamic>> settled(String userId, int length) async {
    final f = outboxOf(userId);
    for (var i = 0; i < 200; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 25));
      if (!await f.exists()) continue;
      try {
        final list = jsonDecode(await f.readAsString()) as List;
        if (list.length == length) return list;
      } catch (_) {/* mid-rename */}
    }
    fail('the outbox never settled at $length');
  }

  test('a failed send survives a restart, held for the sender to decide',
      () async {
    const me = 'outbox_me';
    final api = _FakeApi();
    final before = ChatRepository(api: api, cv: _FakeCv());
    await before.attach(me);
    await before.sendText('r1', 'sent in a tunnel');
    final failed = before.messagesFor('r1').single;
    expect(failed.status, MessageStatus.error);
    final onDisk = await settled(me, 1);
    expect(onDisk.single['message']['content'], 'sent in a tunnel');
    await before.detach();

    // The restart: a fresh repository, same account, network still down.
    final after = ChatRepository(api: api, cv: _FakeCv());
    await after.attach(me);
    final back = after.messagesFor('r1').single;
    expect(back.id, failed.id);
    expect(back.content, 'sent in a tunnel');
    expect(back.status, MessageStatus.error);

    // The reconnect sweep leaves it alone — it is the sender's call.
    api.offline = false;
    await after.flushPending();
    expect(api.delivered, isEmpty);

    // SEND AGAIN reuses the id, so the server can collapse a copy that did
    // land before the restart.
    await after.retryPending(back.id);
    expect(api.delivered, [failed.id]);
    expect(back.status, MessageStatus.sent);
    await settled(me, 0);
    await after.detach();
  });

  test('a photo that never finished uploading comes back with its bytes',
      () async {
    const me = 'outbox_photo';
    final bytes = Uint8List.fromList(List<int>.generate(4096, (i) => i % 251));
    final photo = ChatMessage(
      id: 'tmp_1',
      roomId: 'r1',
      senderId: me,
      senderName: '',
      content: 'look',
      type: MessageType.image,
      createdAt: DateTime(2026, 10, 7, 12),
      status: MessageStatus.error,
      upload: PendingUpload(bytes: bytes, contentType: 'image/jpeg'),
    );
    CacheStore.instance.scheduleSaveOutbox(me, [photo]);
    await settled(me, 1);

    final back = (await CacheStore.instance.loadOutbox(me)).single;
    expect(back.id, 'tmp_1');
    expect(back.content, 'look');
    expect(back.status, MessageStatus.error);
    expect(back.upload?.bytes, bytes);
    expect(back.upload?.contentType, 'image/jpeg');

    // Gone from the outbox, gone from the disk — bytes included.
    CacheStore.instance.scheduleSaveOutbox(me, const []);
    await settled(me, 0);
    List<String> left() => Directory('${tmp.path}/cache/$me/outbox')
        .listSync()
        .map((f) => f.uri.pathSegments.last)
        .toList();
    for (var i = 0; i < 200 && left().length > 1; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 25));
    }
    expect(left(), ['outbox.json']);
  });

  test('discarding a restored send removes it from disk too', () async {
    const me = 'outbox_discard';
    final api = _FakeApi();
    final before = ChatRepository(api: api, cv: _FakeCv());
    await before.attach(me);
    await before.sendText('r1', 'never mind');
    await settled(me, 1);
    await before.detach();

    final after = ChatRepository(api: api, cv: _FakeCv());
    await after.attach(me);
    final back = after.messagesFor('r1').single;
    after.discardPending(back.id);
    expect(after.messagesFor('r1'), isEmpty);
    await settled(me, 0);

    // And a third launch finds nothing to bring back.
    final third = ChatRepository(api: api, cv: _FakeCv());
    await third.attach(me);
    expect(third.messagesFor('r1'), isEmpty);
    await after.detach();
    await third.detach();
  });
}
