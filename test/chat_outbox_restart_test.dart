import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monkeyhub/models/expression_item.dart';
import 'package:monkeyhub/models/message_formatting.dart';
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

  /// A server refusal every send gets, like `MESSAGE_TOO_LONG`.
  String? refuseWith;

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
    bool mediaSpoiler = false,
    String? fileName,
    int? fileSize,
    String? mimeType,
    int? mediaDurationMs,
    String? posterStorageId,
    String? senderName,
    String? replyToId,
    bool replyToAlbum = false,
    int? replyAlbumCount,
    String? albumId,
    bool viewOnce = false,
    String? clientId,
    List<String> mentionedUserIds = const [],
    bool mentionsEveryone = false,
    double? latitude,
    double? longitude,
    double? locationAccuracyM,
    int? liveDurationMs,
    List<FormattingEntity> formatting = const [],
    ExpressionItem? expression,
  }) async {
    if (offline) throw TimeoutException('MutationTimeout');
    final refusal = refuseWith;
    if (refusal != null) throw Exception(refusal);
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

  test('a send the link failed keeps going on its own, across a restart',
      () async {
    const me = 'outbox_me';
    final api = _FakeApi();
    final before = ChatRepository(api: api, cv: _FakeCv());
    await before.attach(me);
    await before.sendText('r1', 'sent in a tunnel');
    final failed = before.messagesFor('r1').single;
    // No answer is not a "no": it still says sending, and retries itself.
    expect(failed.status, MessageStatus.pending);
    final onDisk = await settled(me, 1);
    expect(onDisk.single['message']['content'], 'sent in a tunnel');
    await before.detach();

    // The restart: a fresh repository, same account, network still down.
    final after = ChatRepository(api: api, cv: _FakeCv());
    await after.attach(me);
    final back = after.messagesFor('r1').single;
    expect(back.id, failed.id);
    expect(back.content, 'sent in a tunnel');

    // Minutes old, so it goes out by itself once the link is back, with the
    // same id, so the server can collapse a copy that did land before.
    api.offline = false;
    await after.flushPending();
    expect(api.delivered, [failed.id]);
    expect(back.status, MessageStatus.sent);
    await settled(me, 0);
    await after.detach();
  });

  test('messages typed after a stuck one wait behind it, in order', () async {
    const me = 'outbox_order';
    final api = _FakeApi();
    final repo = ChatRepository(api: api, cv: _FakeCv());
    await repo.attach(me);
    await repo.sendText('r1', 'first');
    api.offline = false;
    await repo.sendText('r1', 'second');
    final ids = [for (final m in repo.messagesFor('r1')) m.id];
    expect(ids, hasLength(2));
    // The second went out only after the first, in one sweep.
    expect(api.delivered, ids);
    await settled(me, 0);
    await repo.detach();
  });

  test('an unsent message from long ago waits for the sender to decide',
      () async {
    const me = 'outbox_old';
    final old = ChatMessage(
      id: 'tmp_old',
      roomId: 'r1',
      senderId: me,
      senderName: '',
      content: 'from yesterday',
      type: MessageType.text,
      createdAt: DateTime.now().subtract(const Duration(hours: 20)),
      status: MessageStatus.error,
    );
    CacheStore.instance.scheduleSaveOutbox(me, [old]);
    await settled(me, 1);

    final api = _FakeApi()..offline = false;
    final repo = ChatRepository(api: api, cv: _FakeCv());
    await repo.attach(me);
    final back = repo.messagesFor('r1').single;
    expect(back.status, MessageStatus.error);

    // The reconnect sweep leaves it alone: it is the sender's call.
    await repo.flushPending();
    expect(api.delivered, isEmpty);

    await repo.retryPending(back.id);
    expect(api.delivered, ['tmp_old']);
    expect(back.status, MessageStatus.sent);
    await settled(me, 0);
    await repo.detach();
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

  test('a text too long for one message goes as a text file, not a refusal',
      () async {
    const me = 'outbox_long';
    final api = _FakeApi()..offline = false;
    final repo = ChatRepository(api: api, cv: _FakeCv());
    await repo.attach(me);
    final text = 'x' * (kMaxMessageChars + 1);
    // Not awaited: the upload has no server behind it here. The bubble is
    // what the sender sees, and it is there before the first await.
    unawaited(repo.sendText('r1', text));
    final bubble = repo.messagesFor('r1').single;
    expect(bubble.type, MessageType.file);
    expect(bubble.fileName, kLongMessageFileName);
    expect(api.delivered, isEmpty);
    repo.discardPending(bubble.id);
    await repo.detach();
  });

  test('a refused send is reported in its own room only', () async {
    const me = 'outbox_limit';
    final api = _FakeApi()
      ..offline = false
      ..refuseWith = 'MESSAGE_TOO_LONG';
    final repo = ChatRepository(api: api, cv: _FakeCv());
    await repo.attach(me);
    await repo.sendText('r1', 'refused');
    // Opening another chat is not news about this one.
    expect(repo.takeSendLimit('r2'), isNull);
    expect(repo.takeSendLimit('r1'), 'MESSAGE_TOO_LONG');
    expect(repo.takeSendLimit('r1'), isNull);
    repo.discardPending(repo.messagesFor('r1').single.id);
    await repo.detach();
  });
}
