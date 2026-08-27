import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:monkeyhub/backend/chat_api.dart';
import 'package:monkeyhub/backend/convex_client.dart';
import 'package:monkeyhub/data/chat_repository.dart';
import 'package:monkeyhub/models/chat_message.dart';
import 'package:monkeyhub/models/chat_room.dart';
import 'package:monkeyhub/models/chat_user.dart';
import 'package:monkeyhub/models/enums.dart';
import 'package:monkeyhub/models/friend_request.dart';
import 'package:monkeyhub/models/message_bookmark.dart';
import 'package:monkeyhub/models/room_capabilities.dart';

/// Saved messages — the per-reader bookmark, NOT the `dm:self:` Saved Messages
/// room.
///
/// The two things these have to keep apart are the whole reason the feature is
/// worth testing: a bookmark must stay scoped to one room and one reader, and it
/// must not outlive the message it points at. The second is enforced on the
/// server (`removeMessageAndFanout` drops the row with the message), so what is
/// testable here is the client's half of that contract — that the subscription
/// is the only source of truth and a vanished row leaves nothing behind.
///
/// The fake captures each subscription's `onData` so a test can deliver a
/// server frame itself. Nothing here waits on a real socket, timer or frame.

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

  /// `<query>/<roomId>` → the handler the repository registered, so a test can
  /// play the part of the server.
  final Map<String, void Function(dynamic)> feeds = {};

  /// Args the repository actually sent, keyed the same way. The scoping claim
  /// this feature makes is only true if `userId` is on the wire.
  final Map<String, Map<String, dynamic>> args = {};

  @override
  Future<Subscription> subscribe(
    String name,
    Map<String, dynamic> params, {
    required void Function(dynamic) onData,
    void Function(Object error)? onError,
  }) async {
    final label = '$name/${params['roomId'] ?? '-'}';
    feeds[label] = onData;
    args[label] = params;
    final sub = _FakeSub(label);
    issued.add(sub);
    // The transcript answers, the way a real backend does for an empty room.
    // `openRoom` holds the room's other subscriptions — bookmarks among them —
    // until it has, so a fake that never delivered left them unregistered and
    // every assertion below looking at an empty list.
    if (name == 'messages:list') {
      unawaited(Future<void>.delayed(Duration.zero, () => onData(const [])));
    }
    return sub;
  }

  @override
  bool get isConnected => true;

  @override
  Stream<bool> get connectionState => const Stream<bool>.empty();
}

class _FakeApi extends Fake implements ChatApi {
  /// What the next `saveMessage` should throw, if anything.
  Object? saveThrows;
  int saveCalls = 0;
  int unsaveCalls = 0;
  final List<String> savedIds = [];
  final List<String> unsavedIds = [];

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

  @override
  Future<void> saveMessage({
    required String messageId,
    required String userId,
  }) async {
    saveCalls++;
    savedIds.add(messageId);
    final e = saveThrows;
    if (e != null) throw e;
  }

  @override
  Future<void> unsaveMessage({
    required String messageId,
    required String userId,
  }) async {
    unsaveCalls++;
    unsavedIds.add(messageId);
  }
}

Future<void> _pump([int rounds = 8]) async {
  for (var i = 0; i < rounds; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

/// One row as `bookmarks:listForRoom` sends it.
Map<String, dynamic> _wire(String messageId, {int savedAt = 1000}) => {
      'savedAt': savedAt,
      'message': {
        '_id': messageId,
        'roomId': 'rA',
        'senderId': 'alice',
        'senderName': 'alice',
        'content': 'keep this',
        'createdAt': 1,
        'type': 'text',
      },
    };

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _FakeCv cv;
  late _FakeApi api;
  late ChatRepository repo;
  late Object screen;

  setUp(() async {
    cv = _FakeCv();
    api = _FakeApi();
    repo = ChatRepository(api: api, cv: cv);
    screen = Object();
    await repo.attach('me');
  });

  void feed(String roomId, List<Map<String, dynamic>> rows) {
    cv.feeds['bookmarks:listForRoom/$roomId']!(rows);
  }

  group('subscription', () {
    test('opening a room subscribes, scoped to the room AND the reader', () async {
      await repo.openRoom('rA', owner: screen);
      await _pump();

      final args = cv.args['bookmarks:listForRoom/rA'];
      expect(args, isNotNull);
      // Both halves of the scope have to be on the wire. A room-only query
      // would hand this viewer everyone else's bookmarks.
      expect(args!['roomId'], 'rA');
      expect(args['userId'], 'me');
    });

    test('closing the room takes the subscription with it', () async {
      await repo.openRoom('rA', owner: screen);
      await _pump();
      final sub = cv.issued
          .firstWhere((s) => s.label == 'bookmarks:listForRoom/rA');
      expect(sub.cancelled, isFalse);

      repo.closeRoom(screen);
      expect(sub.cancelled, isTrue);
    });

    test('signing out drops the previous account‘s bookmarks', () async {
      await repo.openRoom('rA', owner: screen);
      await _pump();
      feed('rA', [_wire('m1')]);
      expect(repo.savedFor('rA'), hasLength(1));

      await repo.detach();
      expect(repo.savedFor('rA'), isEmpty);
    });
  });

  group('toggle round trip', () {
    test('save then unsave, each reflected once the server frame lands',
        () async {
      await repo.openRoom('rA', owner: screen);
      await _pump();

      // Nothing saved yet, and no optimistic write: the subscription is the
      // only source of truth.
      expect(repo.isMessageSaved('rA', 'm1'), isFalse);

      expect(await repo.saveMessage('rA', 'm1'), isNull);
      expect(api.saveCalls, 1);
      expect(api.savedIds, ['m1']);
      expect(repo.isMessageSaved('rA', 'm1'), isFalse,
          reason: 'nothing is saved until the server says so');

      feed('rA', [_wire('m1')]);
      expect(repo.isMessageSaved('rA', 'm1'), isTrue);
      expect(repo.savedFor('rA').single.message.content, 'keep this');

      await repo.unsaveMessage('rA', 'm1');
      expect(api.unsaveCalls, 1);
      expect(api.unsavedIds, ['m1']);

      feed('rA', const []);
      expect(repo.isMessageSaved('rA', 'm1'), isFalse);
      expect(repo.savedFor('rA'), isEmpty);
    });

    test('the cap is reported rather than thrown out of the menu handler',
        () async {
      await repo.openRoom('rA', owner: screen);
      await _pump();

      api.saveThrows = Exception('SAVE_LIMIT_REACHED');
      expect(await repo.saveMessage('rA', 'm1'), 'SAVE_LIMIT_REACHED');

      api.saveThrows = Exception('boom');
      expect(await repo.saveMessage('rA', 'm2'), 'SAVE_FAILED');
    });

    test('unsave swallows — the live subscription reconciles', () async {
      await repo.openRoom('rA', owner: screen);
      await _pump();
      // No throw escapes even though nothing was ever saved.
      await repo.unsaveMessage('rA', 'ghost');
      expect(api.unsaveCalls, 1);
    });
  });

  group('scoping', () {
    test('a room the viewer has not opened reads empty, never null', () {
      expect(repo.savedFor('never-opened'), isEmpty);
      expect(repo.isMessageSaved('never-opened', 'm1'), isFalse);
    });

    test('one room‘s saves never leak into another', () async {
      await repo.openRoom('rA', owner: screen);
      await _pump();
      feed('rA', [_wire('m1'), _wire('m2')]);

      expect(repo.savedFor('rA'), hasLength(2));
      // The map is room-keyed, so the room next door is untouched — this is the
      // "scoped to that room" half of what the section promises.
      expect(repo.savedFor('rB'), isEmpty);
      expect(repo.isMessageSaved('rB', 'm1'), isFalse);
    });
  });

  group('a saved message whose parent is gone', () {
    test('leaves no row behind when the server drops it', () async {
      await repo.openRoom('rA', owner: screen);
      await _pump();
      feed('rA', [_wire('m1'), _wire('m2')]);
      expect(repo.isMessageSaved('rA', 'm1'), isTrue);

      // What `removeMessageAndFanout` produces: the bookmark went with the
      // message, so the very next frame simply omits it. The client must hold
      // nothing of its own that could survive that — no orphan row, and no
      // stale "saved" state on the menu the next time it opens.
      feed('rA', [_wire('m2')]);

      expect(repo.isMessageSaved('rA', 'm1'), isFalse);
      expect(repo.savedFor('rA').map((b) => b.message.id), ['m2']);
    });

    test('a row the server could not resolve is never sent, so none is parsed',
        () async {
      await repo.openRoom('rA', owner: screen);
      await _pump();
      // `bookmarks:listForRoom` filters unresolvable rows out server-side; the
      // wire shape has no "message: null" case, and the client would throw if
      // one arrived. Feeding an empty frame is what that looks like here.
      feed('rA', const []);
      expect(repo.savedFor('rA'), isEmpty);
    });
  });

  group('MessageBookmark', () {
    test('parses the wire shape, epoch-ms and all', () {
      final b = MessageBookmark.fromJson(_wire('m1', savedAt: 1735689600000));
      expect(b.message.id, 'm1');
      expect(b.message.type, MessageType.text);
      expect(b.savedAt, DateTime.fromMillisecondsSinceEpoch(1735689600000));
    });

    test('a missing savedAt reads as epoch rather than throwing', () {
      final wire = _wire('m1')..remove('savedAt');
      expect(MessageBookmark.fromJson(wire).savedAt.millisecondsSinceEpoch, 0);
    });
  });

  group('capability', () {
    ChatRoom room(String name) => ChatRoom(
          id: 'r',
          name: name,
          createdBy: 'u0',
          createdAt: DateTime(2026),
          isPrivate: true,
          memberCount: 2,
          participantIds: const ['u0', 'u1'],
        );

    test('Saved Messages does not afford saving into itself', () {
      // The room already IS the pile of things you kept. Routed through the
      // capability table rather than an `isSavedMessages` check at the menu.
      expect(roomCapabilitiesFor(room('dm:self:u0')).canSaveMessages, isFalse);
      // ...and it is still the best place to forward TO, which is the other
      // feature and the one this must not be confused with.
      expect(roomCapabilitiesFor(room('dm:self:u0')).canReceiveForwards, isTrue);
    });

    test('ordinary rooms and DMs do', () {
      expect(roomCapabilitiesFor(room('general')).canSaveMessages, isTrue);
      expect(roomCapabilitiesFor(room('dm:regular:u0:u1')).canSaveMessages,
          isTrue);
    });

    test('a system room affords nothing, this included', () {
      final logs = ChatRoom(
        id: 'r',
        name: 'dm:regular:u0:bot',
        createdBy: 'u0',
        createdAt: DateTime(2026),
        isPrivate: true,
        memberCount: 2,
        systemRole: 'logs',
      );
      expect(roomCapabilitiesFor(logs).canSaveMessages, isFalse);
    });
  });
}
