import 'package:flutter_test/flutter_test.dart';
import 'package:monkeyhub/backend/chat_api.dart';
import 'package:monkeyhub/backend/convex_client.dart';
import 'package:monkeyhub/data/chat_repository.dart';
import 'package:monkeyhub/models/chat_room.dart';
import 'package:monkeyhub/models/enums.dart';
import 'package:monkeyhub/share/share_targets.dart';
import 'package:monkeyhub/theme/basic_theme.dart';

/// What this pins: which chats the OS is told about.
///
/// These suggestions leave the app. They are drawn by the system share sheet
/// and by Siri, they name people, and they outlive the process — so the two
/// rules that matter are that a chat which cannot receive a share is never
/// offered, and that the list is stable when nothing has changed (an unstable
/// list republishes on every message, refetching an avatar per chat).
void main() {
  final theme = BasicTheme();

  ChatRoom room(
    String id, {
    String? name,
    // False, because that is what `rooms:listUserRooms` actually returns:
    // only `rooms:listPublic` ever fills this in. A fixture that defaulted it
    // to true is what let an `if (!r.isMember) continue;` over `repo.rooms`
    // pass its tests while rejecting every real room.
    bool isMember = false,
    bool isArchived = false,
    RoomType type = RoomType.regular,
    int? lastMessageMs,
  }) =>
      ChatRoom(
        id: id,
        name: name ?? id,
        createdBy: 'someone',
        createdAt: DateTime.fromMillisecondsSinceEpoch(0),
        isPrivate: false,
        memberCount: 2,
        isMember: isMember,
        isArchived: isArchived,
        type: type,
        lastMessageTime: lastMessageMs == null
            ? null
            : DateTime.fromMillisecondsSinceEpoch(lastMessageMs),
      );

  // No network: the client initializes lazily and nothing here touches it.
  ChatRepository repo() {
    final cv = ConvexBackend.instance;
    return ChatRepository(api: ChatApi(cv), cv: cv);
  }

  List<ShareTarget> build(ChatRepository r) => buildShareTargets(
        repo: r,
        theme: theme,
        savedMessagesTitle: 'Saved Messages',
        directMessageFallbackTitle: 'Direct message',
      );

  group('buildShareTargets', () {
    test('offers the most recently active chats first', () {
      final r = repo()
        ..debugSeedRooms([
          room('old', lastMessageMs: 1000),
          room('newest', lastMessageMs: 3000),
          room('middle', lastMessageMs: 2000),
        ]);
      expect(build(r).map((t) => t.roomId), ['newest', 'middle', 'old']);
    });

    test('sinks a chat with no traffic below every chat that has some', () {
      final r = repo()
        ..debugSeedRooms([
          room('quiet'),
          room('busy', lastMessageMs: 1),
        ]);
      expect(build(r).map((t) => t.roomId), ['busy', 'quiet']);
    });

    test('offers the rooms the server actually sends', () {
      // `repo.rooms` is `rooms:listUserRooms` and nothing else — already the
      // list of rooms the viewer is in — and that query does not set
      // `isMember`, so every room in it reads as false. The guard that used to
      // stand here therefore rejected all of them, and the iOS extension
      // cached an empty picker: a share sheet that could only offer "Open
      // MonkeyHub", on an account with seventeen chats.
      final r = repo()..debugSeedRooms([room('a'), room('b')]);
      expect(build(r).map((t) => t.roomId), ['a', 'b']);
    });

    test('skips archived rooms', () {
      // Archiving is "stop showing me this". The system share sheet is a much
      // louder place to keep showing it than the chat list.
      final r = repo()
        ..debugSeedRooms([room('a'), room('archived', isArchived: true)]);
      expect(build(r).map((t) => t.roomId), ['a']);
    });

    test('never offers more than the cap', () {
      final r = repo()
        ..debugSeedRooms([
          for (var i = 0; i < kMaxShareTargets + 6; i++)
            room('r$i', lastMessageMs: 1000 - i),
        ]);
      expect(build(r), hasLength(kMaxShareTargets));
      // And it keeps the RIGHT ones — the newest, not the first N seeded.
      expect(build(r).first.roomId, 'r0');
    });

    test('titles a group by its name and Saved Messages by its own string', () {
      final r = repo()
        ..debugSeedRooms([
          room('g', name: 'Trip planning', lastMessageMs: 2),
          room('s', name: 'dm:self:me', lastMessageMs: 1),
        ]);
      final targets = build(r);
      expect(targets[0].title, 'Trip planning');
      expect(targets[0].isGroup, isTrue);
      expect(targets[1].title, 'Saved Messages');
    });

    test('falls back for a DM whose peer is not cached yet', () {
      // A DM's stored name is the internal `dm:<a>:<b>` key. Publishing that to
      // the system share sheet would put a database row in somebody's UI.
      final r = repo()..debugSeedRooms([room('d', name: 'dm:a:b')]);
      final target = build(r).single;
      expect(target.title, 'Direct message');
      expect(target.isGroup, isFalse);
    });

    test('gives a group and a DM different gradients', () {
      // The seed is the peer's id for a DM and the room's for a group — the
      // same two seeds the app's own avatars use, so a suggestion looks like
      // the row it stands for.
      final r = repo()
        ..debugSeedRooms([room('aaa'), room('zzz', lastMessageMs: 1)]);
      final targets = build(r);
      expect(targets[0].gradientStart, isNot(targets[1].gradientStart));
    });

    test('takes the initial from the rendered title, upper-cased', () {
      final r = repo()..debugSeedRooms([room('x', name: 'trip planning')]);
      expect(build(r).single.initial, 'T');
    });

    test('survives a title with no letters at all', () {
      final r = repo()..debugSeedRooms([room('x', name: '   ')]);
      expect(build(r).single.initial, isEmpty,
          reason: 'native draws a glyph for an empty initial');
    });
  });

  group('ShareTarget equality', () {
    // Load-bearing, not cosmetic. `ShareTargets.sync` skips the platform round
    // trip when the list is unchanged, and `rooms:listUserRooms` re-fires on
    // every message in every room — so a target that compares unequal to an
    // identical one republishes every shortcut, and refetches every avatar,
    // several times a second in an active group.
    const a = ShareTarget(
      roomId: 'r',
      title: 'Room',
      initial: 'R',
      gradientStart: 1,
      gradientEnd: 2,
    );

    test('two identical targets are equal', () {
      const b = ShareTarget(
        roomId: 'r',
        title: 'Room',
        initial: 'R',
        gradientStart: 1,
        gradientEnd: 2,
      );
      expect(a, b);
      expect(a.hashCode, b.hashCode);
      expect([a], [b]);
    });

    test('a renamed room is a different target', () {
      const renamed = ShareTarget(
        roomId: 'r',
        title: 'Room 2',
        initial: 'R',
        gradientStart: 1,
        gradientEnd: 2,
      );
      expect(a, isNot(renamed));
    });

    test('an avatar arriving is a different target', () {
      // The URL resolves in the background after the first publish, so this is
      // the comparison that makes the second pass actually carry the picture.
      const withAvatar = ShareTarget(
        roomId: 'r',
        title: 'Room',
        initial: 'R',
        gradientStart: 1,
        gradientEnd: 2,
        avatarUrl: 'https://example.test/a.jpg',
      );
      expect(a, isNot(withAvatar));
    });
  });

  test('toChannel carries every field native needs', () {
    // The keys are read by ShareShortcuts.kt (`id`, `title`, `initial`,
    // `gradientStart`, `gradientEnd`, `avatarUrl`) and by
    // AppDelegate.donateSendMessage (`id`, `title`, `avatarUrl`, `isGroup`).
    // A rename here is a silent no-op there.
    const target = ShareTarget(
      roomId: 'r1',
      title: 'Room',
      initial: 'R',
      gradientStart: 0xFF112233,
      gradientEnd: 0xFF445566,
      avatarUrl: 'https://example.test/a.jpg',
      isGroup: true,
    );
    expect(target.toChannel(), {
      'id': 'r1',
      'title': 'Room',
      'initial': 'R',
      'gradientStart': 0xFF112233,
      'gradientEnd': 0xFF445566,
      'avatarUrl': 'https://example.test/a.jpg',
      'isGroup': true,
    });
  });
}
