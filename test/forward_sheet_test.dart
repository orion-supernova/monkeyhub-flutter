import 'package:flutter_test/flutter_test.dart';
import 'package:monkeyhub/backend/chat_api.dart';
import 'package:monkeyhub/data/chat_repository.dart';
import 'package:monkeyhub/models/chat_message.dart';
import 'package:monkeyhub/models/enums.dart';
import 'package:monkeyhub/screens/room_content_actions.dart';

/// What this pins: forwarding is fan-out, and fan-out fails in pieces.
///
/// One mutation per target room — a Convex mutation is one transaction, so a
/// single call for five rooms would roll all five back when one DM turns out to
/// be blocked. That makes partial success the normal outcome rather than an
/// exceptional one, and a bulk action that half worked and reported nothing is
/// worse than one that failed outright.
///
/// The refusal that matters most is `SOURCE_IS_EPHEMERAL`. `messages:send`
/// derives `expiresAt` from the TARGET room, so forwarding out of a Chamber of
/// Secrets room would land a message written to self-destruct in an hour as a
/// permanent one — the sender's expiry laundered away by whoever read it. The
/// server refuses it; this pins that the client says *why* rather than showing
/// a generic failure the user cannot act on.
///
/// Sibling: `room_content_selection_test.dart`, which pins what is forwarded.
class _FakeApi extends Fake implements ChatApi {
  /// Per-target outcome, keyed by target room id. A throwable is thrown; an
  /// int is returned as the forwarded count.
  final Map<String, Object> outcomes = {};
  final List<String> targetsCalled = [];
  final List<List<String>> clientIdsSeen = [];

  @override
  Future<({int forwarded, int refused})> forwardToRoom({
    required String sourceRoomId,
    required String targetRoomId,
    required String userId,
    required List<String> messageIds,
    List<String>? clientIds,
  }) async {
    targetsCalled.add(targetRoomId);
    if (clientIds != null) clientIdsSeen.add(clientIds);
    final outcome = outcomes[targetRoomId] ?? messageIds.length;
    if (outcome is int) {
      return (forwarded: outcome, refused: messageIds.length - outcome);
    }
    throw outcome;
  }

  @override
  Future<({int deleted, int refused})> deleteMessages({
    required String userId,
    required List<String> messageIds,
  }) async => (deleted: messageIds.length, refused: 0);
}

class _FakeRepo extends Fake implements ChatRepository {
  @override
  String? get userId => 'me';
}

void main() {
  late _FakeApi api;
  late _FakeRepo repo;

  ChatMessage photo(String id) => ChatMessage(
    id: id,
    roomId: 'source',
    senderId: 'me',
    senderName: 'ada',
    content: '',
    createdAt: DateTime(2026, 3, 1, 12),
    type: MessageType.image,
    mediaStorageId: 'stor_$id',
  );

  Future<BulkResult> forward(List<String> targets, {int messages = 2}) =>
      forwardMessages(
        api: api,
        repo: repo,
        sourceRoomId: 'source',
        targets: targets,
        messages: [for (var i = 0; i < messages; i++) photo('m$i')],
      );

  setUp(() {
    api = _FakeApi();
    repo = _FakeRepo();
  });

  group('fan-out', () {
    test('issues one call per target room', () async {
      await forward(['a', 'b', 'c']);
      expect(
        api.targetsCalled,
        ['a', 'b', 'c'],
        reason:
            'one transaction per room is what makes partial success '
            'possible at all',
      );
    });

    test('one failing room does not take the others with it', () async {
      api.outcomes['b'] = Exception('UNBLOCK_FIRST');
      final res = await forward(['a', 'b', 'c']);

      expect(api.targetsCalled, [
        'a',
        'b',
        'c',
      ], reason: 'the loop continues past a refusal');
      expect(res.ok, 2);
      expect(res.failed, 1);
      expect(res.summary, 'forwarded to 2, 1 failed');
    });

    test('carries a distinct idempotency key per message and room', () async {
      await forward(['a', 'b'], messages: 2);
      final flat = api.clientIdsSeen.expand((e) => e).toList();
      expect(flat.length, 4);
      expect(
        flat.toSet().length,
        4,
        reason:
            'a key reused across rooms would make the second room a '
            'no-op, because the server dedupes on (room, user, clientId)',
      );
    });
  });

  group('what the user is told', () {
    test('the ephemeral refusal names the actual reason', () async {
      api.outcomes['a'] = Exception('SOURCE_IS_EPHEMERAL');
      final res = await forward(['a']);
      expect(
        res.summary,
        "messages that fade can't be forwarded",
        reason:
            'a generic failure here reads as a bug, when it is the one '
            'refusal the user could not have predicted and cannot retry',
      );
    });

    test('a block is named as something the user can fix', () async {
      api.outcomes['a'] = Exception('UNBLOCK_FIRST');
      expect((await forward(['a'])).summary, 'unblock them first');
    });

    test('having left the room is named too', () async {
      api.outcomes['a'] = Exception('NOT_A_MEMBER');
      expect((await forward(['a'])).summary, "you're not in that chat anymore");
    });

    test('anything else is a plain failure rather than a raw error', () async {
      api.outcomes['a'] = Exception('ECONNRESET at 0x7f');
      final res = await forward(['a']);
      expect(res.summary, "couldn't forward that");
      expect(res.summary.contains('0x7f'), isFalse);
    });

    test('the happy paths read naturally', () async {
      expect((await forward(['a'])).summary, 'forwarded');
      api = _FakeApi();
      expect((await forward(['a', 'b'])).summary, 'forwarded to 2 chats');
    });

    test('a room that accepted nothing counts as failed', () async {
      // The server returns `{forwarded: 0}` when every message was refused —
      // all view-once, say. Reporting that as success would be a lie.
      api.outcomes['a'] = 0;
      final res = await forward(['a']);
      expect(res.ok, 0);
      expect(res.failed, 1);
    });
  });

  test('a signed-out client reports rather than throwing', () async {
    final res = await forwardMessages(
      api: api,
      repo: _SignedOutRepo(),
      sourceRoomId: 'source',
      targets: ['a'],
      messages: [photo('m1')],
    );
    expect(res.summary, 'not signed in');
    expect(api.targetsCalled, isEmpty);
  });

  group('delete reporting', () {
    test('a clean delete says so', () async {
      final res = await deleteMessages(
        api: api,
        repo: repo,
        messageIds: ['m1', 'm2'],
      );
      expect(res.summary, 'deleted 2');
    });

    test('a partial delete names what was refused', () async {
      final res = await deleteMessages(
        api: _RefusingApi(),
        repo: repo,
        messageIds: ['m1', 'm2', 'm3'],
      );
      expect(
        res.summary,
        'deleted 1, 2 not yours',
        reason:
            'the server skips rather than throwing, so the client has to '
            'be the one that notices',
      );
    });
  });
}

class _SignedOutRepo extends Fake implements ChatRepository {
  @override
  String? get userId => null;
}

class _RefusingApi extends Fake implements ChatApi {
  @override
  Future<({int deleted, int refused})> deleteMessages({
    required String userId,
    required List<String> messageIds,
  }) async => (deleted: 1, refused: 2);
}
