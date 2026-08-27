import 'package:flutter_test/flutter_test.dart';
import 'package:monkeyhub/backend/chat_api.dart';
import 'package:monkeyhub/backend/convex_client.dart';
import 'package:monkeyhub/data/chat_repository.dart';
import 'package:monkeyhub/models/chat_message.dart';
import 'package:monkeyhub/models/chat_room.dart';
import 'package:monkeyhub/models/chat_user.dart';
import 'package:monkeyhub/models/friend_request.dart';

/// The sync half of manual speaker colours.
///
/// The palette maths is `speaker_colors_test.dart`'s business. What is at stake
/// here is the promise the FEATURE makes, which is a performance one and is
/// invisible from any screenshot: picking a colour must be one write that
/// nobody else in the room pays for, and holding the answers must be one
/// subscription for the whole app rather than one per room.
///
/// The server half of that lives in `speakerColors.ts` — its own table, every
/// read scoped to one `viewerId` — and cannot be asserted from Dart. What CAN
/// be asserted here is the client not undoing it: one subscription, opened
/// once, carrying the viewer and nothing room-shaped.

class _FakeSub extends Fake implements Subscription {
  _FakeSub(this.label);
  final String label;
  bool cancelled = false;
  @override
  void cancel() => cancelled = true;
}

class _FakeCv extends Fake implements ConvexBackend {
  final List<_FakeSub> issued = [];
  final Map<String, void Function(dynamic)> feeds = {};
  final Map<String, Map<String, dynamic>> args = {};

  @override
  Future<Subscription> subscribe(
    String name,
    Map<String, dynamic> params, {
    required void Function(dynamic) onData,
    void Function(Object error)? onError,
  }) async {
    // Keyed by NAME alone, so a second subscription to the same query — the
    // per-room mistake this feature exists to avoid — shows up as a second
    // entry in `issued` rather than quietly overwriting the first.
    feeds[name] = onData;
    args[name] = params;
    final sub = _FakeSub(name);
    issued.add(sub);
    return sub;
  }

  @override
  bool get isConnected => true;

  @override
  Stream<bool> get connectionState => const Stream<bool>.empty();
}

class _FakeApi extends Fake implements ChatApi {
  Object? setThrows;
  final List<Map<String, Object?>> setCalls = [];
  int clearCalls = 0;

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
  Future<void> setSpeakerSlot({
    required String viewerId,
    required String roomId,
    required String subjectId,
    required int? slot,
  }) async {
    setCalls.add({
      'viewerId': viewerId,
      'roomId': roomId,
      'subjectId': subjectId,
      'slot': slot,
    });
    final e = setThrows;
    if (e != null) throw e;
  }

  @override
  Future<void> clearSpeakerSlots({
    required String viewerId,
    required String roomId,
  }) async {
    clearCalls++;
  }
}

Future<void> _pump([int rounds = 8]) async {
  for (var i = 0; i < rounds; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _FakeCv cv;
  late _FakeApi api;
  late ChatRepository repo;

  setUp(() async {
    cv = _FakeCv();
    api = _FakeApi();
    repo = ChatRepository(api: api, cv: cv);
    await repo.attach('me');
    await _pump();
  });

  void feed(Map<String, dynamic> wire) {
    cv.feeds['speakerColors:mine']!(wire);
  }

  group('subscription', () {
    test('one app-wide subscription, carrying the viewer and no room',
        () async {
      final opened =
          cv.issued.where((s) => s.label == 'speakerColors:mine').toList();
      expect(opened, hasLength(1));
      final sent = cv.args['speakerColors:mine']!;
      expect(sent['viewerId'], 'me');
      // A roomId on the wire would mean this had become a per-room query — the
      // thing that would put a live subscription on every room entry, for a
      // feature most people never touch.
      expect(sent.containsKey('roomId'), isFalse);
    });

    test('opening rooms does not open more of them', () async {
      final screen = Object();
      await repo.openRoom('rA', owner: screen);
      await _pump();
      repo.closeRoom(screen);
      await repo.openRoom('rB', owner: screen);
      await _pump();

      expect(
        cv.issued.where((s) => s.label == 'speakerColors:mine'),
        hasLength(1),
        reason: 'the override subscription is app-wide; two rooms must not '
            'mean two of it',
      );
    });

    test('a frame lands as a per-room map', () async {
      feed({
        'rA': {'u1': 3, 'u2': 7},
        'rB': {'u1': 11},
      });
      expect(repo.speakerColorsFor('rA'), {'u1': 3, 'u2': 7});
      expect(repo.speakerColorsFor('rB'), {'u1': 11});
      expect(repo.speakerColorsFor('rC'), isEmpty);
    });

    test('signing out drops the previous account\'s pins', () async {
      feed({
        'rA': {'u1': 3},
      });
      expect(repo.speakerColorsFor('rA'), isNotEmpty);
      await repo.detach();
      expect(repo.speakerColorsFor('rA'), isEmpty);
    });
  });

  group('picking', () {
    test('applies before the round trip, and sends the right row', () async {
      final future = repo.setSpeakerSlot('rA', 'u1', 5);
      // Read BEFORE awaiting: a picker that only repaints once the server has
      // answered is a laggy picker, and this is a preference rather than
      // something being negotiated with anyone.
      expect(repo.speakerColorsFor('rA'), {'u1': 5});
      expect(await future, isNull);
      expect(api.setCalls.single, {
        'viewerId': 'me',
        'roomId': 'rA',
        'subjectId': 'u1',
        'slot': 5,
      });
    });

    test('clearing one pin sends a null slot and empties the room', () async {
      feed({
        'rA': {'u1': 5},
      });
      await repo.setSpeakerSlot('rA', 'u1', null);
      expect(repo.speakerColorsFor('rA'), isEmpty);
      expect(api.setCalls.single['slot'], isNull);
    });

    test('a refusal puts the old answer back', () async {
      feed({
        'rA': {'u1': 5},
      });
      api.setThrows = StateError('OVERRIDE_LIMIT');
      expect(await repo.setSpeakerSlot('rA', 'u2', 6), 'OVERRIDE_LIMIT');
      // Nothing was written, so nothing will invalidate and no corrective
      // frame is ever coming — the optimistic value has to be undone here or
      // it stands forever.
      expect(repo.speakerColorsFor('rA'), {'u1': 5});
    });

    test('any other failure reverts too, under its own code', () async {
      api.setThrows = StateError('boom');
      expect(await repo.setSpeakerSlot('rA', 'u1', 2), 'SPEAKER_COLOR_FAILED');
      expect(repo.speakerColorsFor('rA'), isEmpty);
    });

    test('resetting a room is one call, not one per pinned member', () async {
      feed({
        'rA': {'u1': 1, 'u2': 2, 'u3': 3},
      });
      await repo.clearSpeakerSlots('rA');
      expect(repo.speakerColorsFor('rA'), isEmpty);
      expect(api.clearCalls, 1);
      expect(api.setCalls, isEmpty);
    });

    test('resetting a room with nothing pinned writes nothing at all',
        () async {
      await repo.clearSpeakerSlots('rA');
      expect(api.clearCalls, 0);
    });
  });
}
