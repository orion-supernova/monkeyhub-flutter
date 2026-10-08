import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:monkeyhub/models/reaction_limits.dart';
import 'package:monkeyhub/backend/chat_api.dart';
import 'package:monkeyhub/backend/convex_client.dart';
import 'package:monkeyhub/data/chat_repository.dart';
import 'package:monkeyhub/models/chat_message.dart';
import 'package:monkeyhub/models/message_formatting.dart';
import 'package:monkeyhub/push/push_manager.dart';

/// Delete, react and edit render locally before the server has answered.
///
/// All three used to be server-first. Delete and react had no local step at
/// all — `deleteMessage` was three lines and `toggleReaction` ended in
/// `catch (_) {/* swallow — live subscription will reconcile */}` — so nothing
/// happened on screen until `messages:list` refired. That is a whole round trip
/// spent looking at a bubble you have just asked to be gone, and on a backend
/// that can take a second to answer it reads as a broken feature rather than a
/// slow one. Worse for reactions: a second tap re-read the same unchanged row,
/// decided the reaction still was not there, and added it again.
///
/// Edit did have a local step, but it patched `_messages` by index only — and
/// `_olderPrefix` holds the SAME instances in a different list, so the next
/// subscription fire spliced the pre-edit copy back in front through
/// `_withOlderPrefix` and the edit visibly reverted. The prefix cases below are
/// the ones that bug lived in.
class _FakeSub extends Fake implements Subscription {
  bool cancelled = false;

  @override
  void cancel() => cancelled = true;
}

class _FakeCv extends Fake implements ConvexBackend {
  /// `<query>/<roomId>` → the handler the repository registered, so a test can
  /// play the part of the server.
  final Map<String, void Function(dynamic)> feeds = {};

  @override
  Future<Subscription> subscribe(
    String name,
    Map<String, dynamic> args, {
    required void Function(dynamic) onData,
    void Function(Object error)? onError,
  }) async {
    feeds['$name/${args['roomId'] ?? '-'}'] = onData;
    if (name == 'messages:list') {
      unawaited(Future<void>.delayed(Duration.zero, () => onData(const [])));
    }
    return _FakeSub();
  }

  @override
  bool get isConnected => true;

  @override
  Stream<bool> get connectionState => const Stream<bool>.empty();
}

class _FakeApi extends Fake implements ChatApi {
  Object? deleteThrows;
  Object? reactionThrows;
  String? editReturns;

  int deleteCalls = 0;
  final List<String> reactionCalls = [];

  /// What [listBefore] hands back, so a test can put a message into
  /// `_olderPrefix` the way a real scroll-back does.
  List<ChatMessage> olderPage = const [];

  @override
  Future<void> deleteMessage({
    required String messageId,
    required String userId,
  }) async {
    deleteCalls++;
    if (deleteThrows != null) throw deleteThrows!;
  }

  @override
  Future<void> addReaction({
    required String messageId,
    required String userId,
    required String emoji,
  }) async {
    reactionCalls.add('add/$emoji');
    if (reactionThrows != null) throw reactionThrows!;
  }

  @override
  Future<void> removeReaction({
    required String messageId,
    required String userId,
    required String emoji,
  }) async {
    reactionCalls.add('remove/$emoji');
    if (reactionThrows != null) throw reactionThrows!;
  }

  @override
  Future<String?> editMessage({
    required String messageId,
    required String userId,
    required String content,
    List<String> mentionedUserIds = const [],
    bool mentionsEveryone = false,
    List<FormattingEntity> formatting = const [],
  }) async =>
      editReturns;

  @override
  Future<List<ChatMessage>> listBefore({
    required String roomId,
    required DateTime before,
    int limit = 30,
    String? viewerUserId,
  }) async =>
      olderPage;

  /// The cursor the last `markRoomRead` carried, so a test can prove a push
  /// stub did not move it.
  DateTime? readUpTo;

  @override
  Future<void> markRoomRead({
    required String roomId,
    required String userId,
    DateTime? upTo,
  }) async {
    readUpTo = upTo;
  }
}

Future<void> _pump([int rounds = 8]) async {
  for (var i = 0; i < rounds; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

/// Recent, not epoch-relative. `takePushedMessages` drops a stub older than the
/// push TTL, so fixtures dated 1970 would be discarded before they were tested.
/// Offsets below stay small and relative to this, so ordering reads the same.
final _base = DateTime.now().millisecondsSinceEpoch - 60000;

/// A server row, in the shape `ChatMessage.fromJson` reads.
Map<String, dynamic> _row(
  String id, {
  String content = 'hello',
  int atMs = 1000,
  List<Map<String, dynamic>> reactions = const [],
}) =>
    {
      '_id': id,
      'roomId': 'r',
      'userId': 'them',
      'senderName': 'Them',
      'content': content,
      'createdAt': _base + atMs,
      'type': 'text',
      'reactions': reactions,
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
    await repo.openRoom('r', owner: screen);
    await _pump();
  });

  /// Deliver a transcript, the way the live subscription does.
  void serve(List<Map<String, dynamic>> rows) =>
      cv.feeds['messages:list/r']!(rows);

  List<String> idsOnScreen() =>
      repo.messagesFor('r').map((m) => m.id).toList();

  group('delete', () {
    test('the bubble goes before the server answers', () async {
      serve([_row('m1'), _row('m2', atMs: 2000)]);
      expect(idsOnScreen(), ['m1', 'm2']);

      final pending = repo.deleteMessage('m1');
      // Deliberately NOT awaited yet: the whole point is that the row is gone
      // on the frame the user tapped, not on the frame the server replies.
      expect(idsOnScreen(), ['m2']);

      await pending;
      expect(api.deleteCalls, 1);
      expect(idsOnScreen(), ['m2']);
    });

    test('a refusal puts it back', () async {
      serve([_row('m1'), _row('m2', atMs: 2000)]);
      api.deleteThrows = StateError('NOT_ALLOWED');

      await expectLater(repo.deleteMessage('m1'), throwsStateError);
      expect(
        idsOnScreen(),
        ['m1', 'm2'],
        reason: 'nothing was written, so no delivery is coming to correct it',
      );
    });

    test('it also leaves the retained older pages', () async {
      // The case `_patchMessageEverywhere` exists for. `old` lives only in
      // `_olderPrefix`; removing it from `_messages` alone would let
      // `_withOlderPrefix` splice it straight back in on the next fire.
      serve([_row('m2', atMs: 2000)]);
      api.olderPage = [ChatMessage.fromJson(_row('old', atMs: 500))];
      await repo.loadOlder('r');
      expect(idsOnScreen(), ['old', 'm2']);

      await repo.deleteMessage('old');
      expect(idsOnScreen(), ['m2']);

      // The refire that follows any successful mutation must not resurrect it.
      serve([_row('m2', atMs: 2000)]);
      expect(idsOnScreen(), ['m2']);
    });
  });

  group('the live window is diffed, not rebuilt', () {
    test('an unchanged row keeps the object it already had', () async {
      serve([_row('m1'), _row('m2', atMs: 2000)]);
      final firstM1 = repo.messagesFor('r').firstWhere((m) => m.id == 'm1');

      // A third message arrives. Convex re-sends the whole window, so every
      // row comes back down the wire — but only the new one is new.
      serve([_row('m1'), _row('m2', atMs: 2000), _row('m3', atMs: 3000)]);
      final secondM1 = repo.messagesFor('r').firstWhere((m) => m.id == 'm1');

      expect(
        identical(firstM1, secondM1),
        isTrue,
        reason: 'm1 did not change, so it must not be re-parsed — that '
            'identity is what lets the transcript skip rebuilding the row',
      );
    });

    test('a row the server changed is re-parsed', () async {
      serve([_row('m1')]);
      final before = repo.messagesFor('r').firstWhere((m) => m.id == 'm1');

      serve([_row('m1', content: 'changed by someone else')]);
      final after = repo.messagesFor('r').firstWhere((m) => m.id == 'm1');

      expect(identical(before, after), isFalse);
      expect(after.content, 'changed by someone else');
    });

    test('a delivery mid-delete does not put the bubble back', () async {
      serve([_row('m1'), _row('m2', atMs: 2000)]);

      final pending = repo.deleteMessage('m1');
      expect(idsOnScreen(), ['m2']);

      // Something else touches the window — a reaction, someone else's send —
      // and the server, which has not processed the delete yet, dutifully
      // re-sends m1. Without a tombstone the bubble would reappear for a
      // round trip and then vanish again.
      serve([_row('m1'), _row('m2', atMs: 2000), _row('m3', atMs: 3000)]);
      expect(idsOnScreen(), ['m2', 'm3']);

      // And again. The tombstone must survive being USED — it is retired by
      // the server stopping sending the row, not by having hidden it once.
      serve([_row('m1'), _row('m2', atMs: 2000), _row('m3', atMs: 3000)]);
      expect(idsOnScreen(), ['m2', 'm3']);

      await pending;
      serve([_row('m2', atMs: 2000), _row('m3', atMs: 3000)]);
      expect(idsOnScreen(), ['m2', 'm3']);
    });

    test('a refused delete stops hiding the row', () async {
      serve([_row('m1'), _row('m2', atMs: 2000)]);
      api.deleteThrows = StateError('NOT_ALLOWED');

      await expectLater(repo.deleteMessage('m1'), throwsStateError);
      serve([_row('m1'), _row('m2', atMs: 2000)]);
      expect(idsOnScreen(), ['m1', 'm2']);
    });
  });

  group('push seeding', () {
    // The native handlers park an arriving push under `monkeyhub/notifications`
    // and Dart drains it. Standing in for them here is the whole of the seam.
    late List<Map<String, String>> inbox;

    setUp(() {
      inbox = [];
      PushManager.debugInboxReader = () async {
        final rows = inbox;
        inbox = [];
        return rows;
      };
    });

    tearDown(() => PushManager.debugInboxReader = null);

    Map<String, String> push(
      String id, {
      String type = 'text',
      String plain = 'true',
      int? atMs = 5000,
      String content = 'from the banner',
    }) =>
        {
          'kind': 'message',
          'roomId': 'r',
          'messageId': id,
          'senderId': 'them',
          'senderName': 'Them',
          'content': content,
          'type': type,
          if (atMs != null) 'createdAt': '${_base + atMs}',
          'plain': plain,
        };

    test('the pushed message is on screen before the network answers',
        () async {
      serve([_row('m1')]);
      inbox = [push('m2')];

      await repo.takePushedMessages();

      expect(idsOnScreen(), ['m1', 'm2']);
      expect(
        repo.messagesFor('r').last.content,
        'from the banner',
        reason: 'the push has carried the text all along — this is the whole '
            'point of seeding from it',
      );
    });

    test('the transcript supersedes it exactly once', () async {
      serve([_row('m1')]);
      inbox = [push('m2')];
      await repo.takePushedMessages();
      expect(idsOnScreen(), ['m1', 'm2']);

      // The server's own copy of the same message.
      serve([_row('m1'), _row('m2', content: 'from the banner', atMs: 5000)]);
      expect(
        idsOnScreen(),
        ['m1', 'm2'],
        reason: 'one bubble, not two — the stub carries the server id, so the '
            'live row is the same message rather than a lookalike',
      );
    });

    test('a stub is dropped even when the window does not contain it',
        () async {
      // Deleted between the push and the open, or pushed off the back of the
      // window by a backlog. Either way the server has spoken and the
      // stand-in's job is over — keeping it would show a message that is not
      // there.
      serve([_row('m1')]);
      inbox = [push('gone')];
      await repo.takePushedMessages();
      expect(idsOnScreen(), ['m1', 'gone']);

      serve([_row('m1')]);
      expect(idsOnScreen(), ['m1']);
    });

    test('only plain text is seeded', () async {
      serve([_row('m1')]);
      inbox = [
        // The push `content` for these is the room PREVIEW — "📷 Image" — so a
        // stub would be a photo bubble pointing at nothing.
        push('photo', type: 'image'),
        // Formatting, mentions or a reply tether do not fit in a push, and a
        // bubble that gained one a moment later would re-lay-out.
        push('rich', plain: 'false'),
        // Nothing says where this one goes.
        push('undated', atMs: null),
      ];

      await repo.takePushedMessages();
      expect(idsOnScreen(), ['m1']);
    });

    test('a stub does not move the read cursor', () async {
      // The sharpest trap in the feature. `markRoomRead` fires only when the
      // live delivery carries an id newer than the last one seen — so if a
      // stub could prime that baseline, the first delivery would look like it
      // carried nothing new and the message the reader came to read would stay
      // unread forever.
      inbox = [push('m2')];
      await repo.takePushedMessages();
      expect(idsOnScreen(), ['m2']);

      // The open itself already marked the (then empty) room read; this is
      // about what the DELIVERY does.
      api.readUpTo = null;
      serve([_row('m2', content: 'from the banner', atMs: 5000)]);
      // `markRoomRead` coalesces a burst of arrivals into one write, so the
      // assertion has to outlast that debounce rather than race it.
      await Future<void>.delayed(const Duration(milliseconds: 500));
      expect(
        api.readUpTo,
        DateTime.fromMillisecondsSinceEpoch(_base + 5000),
        reason: 'the cursor is primed from the live window only. Prime it '
            'from a stub instead and the first delivery looks like it carried '
            'nothing new, so this never fires and the message the reader came '
            'here to read stays unread forever',
      );
    });
  });

  group('reactions', () {
    List<String> emojisOn(String id) =>
        repo.messagesFor('r').firstWhere((m) => m.id == id).reactions
            .map((r) => r.emoji)
            .toList();

    test('mine appears before the server answers', () async {
      serve([_row('m1')]);

      final pending = repo.toggleReaction(messageId: 'm1', emoji: '❤️');
      expect(emojisOn('m1'), ['❤️']);

      await pending;
      expect(api.reactionCalls, ['add/❤️']);
    });

    test('a second tap removes it rather than adding it twice', () async {
      serve([_row('m1')]);

      await repo.toggleReaction(messageId: 'm1', emoji: '❤️');
      expect(emojisOn('m1'), ['❤️']);

      // Before this was optimistic, the row the second tap read was still the
      // server's unchanged one, so `mineExists` was false and it added again.
      await repo.toggleReaction(messageId: 'm1', emoji: '❤️');
      expect(emojisOn('m1'), isEmpty);
      expect(api.reactionCalls, ['add/❤️', 'remove/❤️']);
    });

    test('a failure rolls it back', () async {
      serve([_row('m1')]);
      api.reactionThrows = StateError('nope');

      await repo.toggleReaction(messageId: 'm1', emoji: '❤️');
      expect(emojisOn('m1'), isEmpty);
    });

    test('the cap refuses before painting, and says so', () async {
      serve([_row('m1')]);
      const ten = ['👍', '❤️', '😂', '😮', '😢', '🔥', '👏', '🎉', '🙏', '💯'];
      expect(ten, hasLength(kMaxMessageReactionsPerPerson));
      for (final e in ten) {
        expect(await repo.toggleReaction(messageId: 'm1', emoji: e), isNull);
      }

      final error = await repo.toggleReaction(messageId: 'm1', emoji: '🤯');
      expect(error, kReactionLimitError);
      expect(emojisOn('m1'), ten,
          reason: 'refused locally: nothing is painted and snatched back');
      expect(api.reactionCalls, hasLength(10),
          reason: 'and nothing is sent to be refused');

      // Taking one back still works at the cap.
      expect(await repo.toggleReaction(messageId: 'm1', emoji: '👍'), isNull);
      expect(emojisOn('m1'), isNot(contains('👍')));
    });

    test("the server's refusal rolls back and reports the cap", () async {
      serve([_row('m1')]);
      api.reactionThrows = Exception('Uncaught Error: REACTION_LIMIT');

      final error = await repo.toggleReaction(messageId: 'm1', emoji: '❤️');
      expect(error, kReactionLimitError);
      expect(emojisOn('m1'), isEmpty);
    });
  });

  group('edit', () {
    String contentOf(String id) =>
        repo.messagesFor('r').firstWhere((m) => m.id == id).content;

    test('an edit to a scrolled-back message survives the next fire', () async {
      // The revert bug, pinned. `old` is in `_olderPrefix`; patching only
      // `_messages` left the prefix holding the pre-edit copy, which
      // `_withOlderPrefix` then spliced back in front on the very next
      // delivery — so the edit undid itself a moment after it was made.
      serve([_row('m2', atMs: 2000)]);
      api.olderPage = [ChatMessage.fromJson(_row('old', atMs: 500))];
      await repo.loadOlder('r');

      final err = await repo.editMessage(
        roomId: 'r',
        message: repo.messagesFor('r').firstWhere((m) => m.id == 'old'),
        content: 'edited',
      );
      expect(err, isNull);
      expect(contentOf('old'), 'edited');

      serve([_row('m2', atMs: 2000)]);
      expect(contentOf('old'), 'edited');
    });

    test('a refused edit reverts everywhere', () async {
      serve([_row('m2', atMs: 2000)]);
      api.olderPage = [ChatMessage.fromJson(_row('old', atMs: 500))];
      await repo.loadOlder('r');
      api.editReturns = 'EDIT_WINDOW_CLOSED';

      final err = await repo.editMessage(
        roomId: 'r',
        message: repo.messagesFor('r').firstWhere((m) => m.id == 'old'),
        content: 'edited',
      );
      expect(err, 'EDIT_WINDOW_CLOSED');
      expect(contentOf('old'), 'hello');

      serve([_row('m2', atMs: 2000)]);
      expect(contentOf('old'), 'hello');
    });
  });
}
