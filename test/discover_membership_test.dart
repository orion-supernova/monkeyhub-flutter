import 'package:flutter_test/flutter_test.dart';
import 'package:monkeyhub/backend/chat_api.dart';
import 'package:monkeyhub/backend/convex_client.dart';
import 'package:monkeyhub/data/chat_repository.dart';
import 'package:monkeyhub/models/chat_room.dart';

/// Discover and search used to run the *join* flow against every room you
/// tapped, including ones you were already in: an approval gate for a child who
/// already had the grant, then a sheet re-asking for a password they had already
/// cleared, then a join the backend treats as a no-op. Nothing consulted
/// membership, because nothing on the client knew it.
///
/// These pin the two halves that fix it — the wire field, and the rule both
/// screens branch on.
void main() {
  ChatRoom room(String id, {bool isMember = false}) => ChatRoom(
    id: id,
    name: id,
    createdBy: 'someone',
    createdAt: DateTime.fromMillisecondsSinceEpoch(0),
    isPrivate: false,
    memberCount: 1,
    isMember: isMember,
  );

  // No network: the client initializes lazily, and none of this touches it.
  ChatRepository repo() {
    final cv = ConvexBackend.instance;
    return ChatRepository(api: ChatApi(cv), cv: cv);
  }

  group('ChatRoom.isMember decoding', () {
    test('reads the flag rooms:listPublic now sends', () {
      final decoded = ChatRoom.fromJson(const {
        '_id': 'r1',
        'name': 'lounge',
        'createdBy': 'u1',
        'createdAt': 0,
        'isPrivate': false,
        'memberCount': 3,
        'isMember': true,
      });
      expect(decoded.isMember, isTrue);
    });

    test('defaults to false when the field is absent', () {
      // Every other room source is by definition a list of rooms you're in and
      // doesn't send this. It must not decode to a truthy default, or search
      // would offer to "open" rooms the user has never joined.
      final decoded = ChatRoom.fromJson(const {
        '_id': 'r1',
        'name': 'lounge',
        'createdBy': 'u1',
        'createdAt': 0,
        'isPrivate': false,
        'memberCount': 3,
      });
      expect(decoded.isMember, isFalse);
    });
  });

  group('isJoined', () {
    test('is false for a room the user is not in', () {
      final r = repo()..debugSeedRooms([room('a'), room('b')]);
      expect(r.isJoined(room('c')), isFalse);
    });

    test('is true when the live room list contains it', () {
      final r = repo()..debugSeedRooms([room('a'), room('b')]);
      // Note the discover copy carries isMember:false — the live list alone has
      // to be enough, since that's what flips right after a join.
      expect(r.isJoined(room('b')), isTrue);
    });

    test(
      'is true from the server flag alone, before the list has hydrated',
      () {
        // The cold-start window: repo.rooms is still empty because the
        // subscription hasn't delivered, but listPublic already told us.
        final r = repo()..debugSeedRooms([]);
        expect(r.isJoined(room('a', isMember: true)), isTrue);
      },
    );

    test('an empty repo and an unflagged room means run the join flow', () {
      final r = repo()..debugSeedRooms([]);
      expect(r.isJoined(room('a')), isFalse);
    });
  });
}
