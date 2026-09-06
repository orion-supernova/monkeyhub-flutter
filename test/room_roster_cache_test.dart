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
import 'package:monkeyhub/models/friend_request.dart';
import 'package:monkeyhub/theme/speaker_colors.dart';

/// The transcript had a disk cache; the ROSTER did not. So a room the reader
/// had opened a hundred times still painted every bubble in theme ink with no
/// sender name and no avatar, and then repainted the lot the moment
/// `rooms:getMembers` answered — because who said something, what they look
/// like and what colour they speak in all come from that one query. That is
/// the "the colours arrive late" everybody sees, and it was never the
/// transcript's fault.
///
/// These pin the fix and, more importantly, the one property the fix is only
/// worth having if it holds: the palette settled from the cached seed must be
/// the SAME palette the live roster settles. A seed that painted a plausible
/// but different set of colours would have traded a fade-in for a reshuffle,
/// which is worse.

// ─────────────────────────────── fakes ───────────────────────────────

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
  final Map<String, Completer<void>> gates = {};

  /// `onData` for the last subscription registered under each query name, so a
  /// test can deliver a roster whenever it likes.
  final Map<String, void Function(dynamic)> sinks = {};

  /// When true the transcript subscription is registered but never delivers —
  /// a room opened offline, or one whose query the backend never answers.
  bool silentTranscript = false;

  @override
  Future<Subscription> subscribe(
    String name,
    Map<String, dynamic> args, {
    required void Function(dynamic) onData,
    void Function(Object error)? onError,
  }) async {
    final gate = gates[name];
    if (gate != null) await gate.future;
    final sub = _FakeSub('$name/${args['roomId'] ?? '-'}');
    issued.add(sub);
    sinks[name] = onData;
    // The transcript answers, the way a real backend does for an empty room.
    // `openRoom` holds the secondary subscriptions until it has, so a fake
    // that never delivered would leave every assertion here looking at an
    // unregistered roster sub.
    if (name == 'messages:list' && !silentTranscript) {
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
}

Future<void> _pump([int rounds = 8]) async {
  for (var i = 0; i < rounds; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

// ─────────────────────────────── fixtures ───────────────────────────────

/// Fourteen members whose JOIN order is the exact reverse of their ID order,
/// and enough of them to wrap past [kSpeakerSlotCount] into a second band.
///
/// Both halves of that are deliberate. The reversal makes join order
/// observable — `SpeakerSlots.forMembers` falls back to id order when every
/// `joinedAt` reads as zero, so a roster that lost the field settles to a
/// visibly different answer rather than the same one by luck. The wrap makes
/// the ordering matter twice over: a band boundary frees the whole wheel, and
/// which member is standing at that boundary is decided by the sort.
List<ChatUser> _roster() => [
      for (var i = 1; i <= 14; i++)
        ChatUser(
          id: 'u${i.toString().padLeft(2, '0')}',
          username: 'user$i',
          name: 'User $i',
          status: i.isEven ? 'online' : 'offline',
          lastSeen: DateTime(2026, 9, 6, 12, i),
          joinedAt: DateTime(2026, 1, 1).add(Duration(days: 14 - i)),
        ),
    ];

/// The same roster as a backend would send it — `_id`, epoch millis, no
/// `friendshipStatus` — so the parse under test is the real one.
List<Map<String, dynamic>> _wire(List<ChatUser> users) => [
      for (final u in users)
        {
          '_id': u.id,
          'username': u.username,
          'name': u.name,
          if (u.avatarStorageId != null) 'avatarStorageId': u.avatarStorageId,
          if (u.status != null) 'status': u.status,
          if (u.lastSeen != null)
            'lastSeen': u.lastSeen!.millisecondsSinceEpoch,
          if (u.role != null) 'role': u.role,
          if (u.joinedAt != null)
            'joinedAt': u.joinedAt!.millisecondsSinceEpoch,
        },
    ];

SpeakerSlots _slotsFor(
  List<ChatUser> members, {
  Map<String, int> pinned = const {},
}) =>
    SpeakerSlots.forMembers(
      [
        for (final u in members)
          (id: u.id, joinedAt: u.joinedAt?.millisecondsSinceEpoch ?? 0),
      ],
      exclude: 'me',
      pinned: pinned,
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tmp;

  setUpAll(() async {
    // CacheStore memoises the documents directory on first use, so the channel
    // has to answer before anything in this file touches it.
    tmp = await Directory.systemTemp.createTemp('room_roster_cache');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/path_provider'),
          (_) async => tmp.path,
        );
  });

  tearDownAll(() async {
    if (await tmp.exists()) await tmp.delete(recursive: true);
  });

  setUp(() {
    // Every test starts from an empty cache. The store is a singleton, so a
    // debounced write left over from the previous test would otherwise land in
    // the middle of the next one.
    CacheStore.instance.discardPendingWrites();
  });

  Future<Directory> cacheDirFor(String userId) async {
    final dir = Directory('${tmp.path}/cache/$userId');
    if (await dir.exists()) await dir.delete(recursive: true);
    await dir.create(recursive: true);
    return dir;
  }

  // ───────────────────────── the invariant ─────────────────────────

  group('a cached roster settles the palette the live one does', () {
    test('joinedAt survives toJson/fromJson', () {
      // The whole fix rests on this one field making it to disk. `toJson` did
      // not write it — nothing serialised a ROOM roster before, so nothing
      // noticed — and `fromJson` has always read it.
      final live = _roster();
      final restored = [
        for (final u in live) ChatUser.fromJson(u.toJson()),
      ];
      for (var i = 0; i < live.length; i++) {
        expect(
          restored[i].joinedAt,
          live[i].joinedAt,
          reason: 'a roster that loses its join instants settles a different '
              'palette than the live one, which is a reshuffle rather than a '
              'late paint',
        );
      }
    });

    test('the seed and the live roster agree, exactly', () {
      final live = _roster();
      final reloaded = [for (final u in live) ChatUser.fromJson(u.toJson())];
      expect(_slotsFor(reloaded), _slotsFor(live));
    });

    test('and they agree with pins applied too', () {
      // Pins are taken FIRST and absolutely, and the slots they occupy are
      // then off-limits to everybody the room places automatically — so they
      // do not merely decorate the assignment, they change it for people who
      // are not pinned. A cached roster restored without them settles a
      // different palette, which is why the pins are cached as well.
      const pinned = {'u03': 7, 'u11': 7, 'u02': 0};
      final live = _roster();
      final reloaded = [for (final u in live) ChatUser.fromJson(u.toJson())];
      expect(_slotsFor(reloaded, pinned: pinned), _slotsFor(live, pinned: pinned));
    });

    test('and the test would notice if joinedAt were dropped', () {
      // Guards the three above from passing vacuously. If this roster settled
      // the same way with and without its join instants, the assertions up
      // there would hold no matter what `toJson` did.
      final live = _roster();
      final orderLost = [
        for (final u in live)
          ChatUser(id: u.id, username: u.username, name: u.name),
      ];
      expect(_slotsFor(orderLost), isNot(_slotsFor(live)));
    });
  });

  // ───────────────────────── the file on disk ─────────────────────────

  group('CacheStore', () {
    test('round-trips a roster, keeping join order and dropping presence',
        () async {
      const userId = 'roster-round-trip';
      await cacheDirFor(userId);
      final live = _roster();

      CacheStore.instance.scheduleSaveMembers(userId, 'r1', live);
      // Past the write debounce.
      await Future<void>.delayed(const Duration(milliseconds: 700));

      final loaded = await CacheStore.instance.loadMembers(userId, 'r1');
      expect(loaded, hasLength(live.length));
      expect(_slotsFor(loaded), _slotsFor(live));

      // Presence describes where somebody was when the file was written. A
      // cold start hours later that painted it from disk would light a green
      // dot beside a person who is not there.
      expect(loaded.every((u) => u.status == null), isTrue);
      expect(loaded.every((u) => u.lastSeen == null), isTrue);
      // Everything identity-shaped does survive, because that is what the
      // bubbles are waiting for.
      expect(loaded.map((u) => u.id).toSet(), live.map((u) => u.id).toSet());
      expect(loaded.first.username, isNotEmpty);
      expect(loaded.every((u) => u.joinedAt != null), isTrue);
    });

    test('round-trips the speaker pins', () async {
      const userId = 'pins-round-trip';
      await cacheDirFor(userId);
      const pins = {
        'r1': {'u03': 7, 'u11': 2},
        'r2': {'u01': 5},
      };

      CacheStore.instance.scheduleSaveSpeakerColors(userId, pins);
      await Future<void>.delayed(const Duration(milliseconds: 700));

      expect(await CacheStore.instance.loadSpeakerColors(userId), pins);
    });

    test('a missing file is an empty answer, not a throw', () async {
      const userId = 'never-cached';
      await cacheDirFor(userId);
      expect(await CacheStore.instance.loadMembers(userId, 'nope'), isEmpty);
      expect(await CacheStore.instance.loadSpeakerColors(userId), isEmpty);
    });

    test('a corrupt file is an empty answer, not a throw', () async {
      const userId = 'corrupt-cache';
      final dir = await cacheDirFor(userId);
      await File('${dir.path}/members_r1.json').writeAsString('{not json');
      await File('${dir.path}/speaker_colors.json').writeAsString('[1,2,3]');
      expect(await CacheStore.instance.loadMembers(userId, 'r1'), isEmpty);
      expect(await CacheStore.instance.loadSpeakerColors(userId), isEmpty);
    });

    test('clearing drops writes that have not landed yet', () async {
      // Without this the timer fires ~600ms after the delete, `_ensureDir`
      // recreates the directory it just removed, and the departing account's
      // roster reappears under the next person's login.
      const userId = 'signed-out';
      await cacheDirFor(userId);
      CacheStore.instance.scheduleSaveMembers(userId, 'r1', _roster());
      await CacheStore.instance.clearFor(userId);
      await Future<void>.delayed(const Duration(milliseconds: 700));

      expect(
        await Directory('${tmp.path}/cache/$userId').exists(),
        isFalse,
        reason: 'a pending write resurrected the cleared cache directory',
      );
    });
  });

  // ───────────────────────── the repository ─────────────────────────

  group('openRoom', () {
    late _FakeCv cv;
    late _FakeApi api;
    late ChatRepository repo;
    late Object screenA;
    late Object screenB;

    setUp(() {
      cv = _FakeCv();
      api = _FakeApi();
      repo = ChatRepository(api: api, cv: cv);
      screenA = Object();
      screenB = Object();
    });

    tearDown(() async {
      await repo.detach();
    });

    test('seeds the roster from disk, before anything has answered', () async {
      const userId = 'seeded';
      final dir = await cacheDirFor(userId);
      await File('${dir.path}/members_r1.json')
          .writeAsString(jsonEncode([for (final u in _roster()) u.toJson()]));

      await repo.attach(userId);
      // Nothing delivers: this is a room opened with the socket down.
      cv.silentTranscript = true;
      await repo.openRoom('r1', owner: screenA);

      expect(
        repo.membersFor('r1'),
        hasLength(14),
        reason: 'the first frame of a re-opened room must know who is in it',
      );
      expect(_slotsFor(repo.membersFor('r1')), _slotsFor(_roster()));
    });

    test('a room never opened before seeds nothing and does not throw',
        () async {
      const userId = 'unseeded';
      await cacheDirFor(userId);
      await repo.attach(userId);
      cv.silentTranscript = true;
      await repo.openRoom('r1', owner: screenA);
      expect(repo.membersFor('r1'), isEmpty);
    });

    test('re-entering a room reuses the roster in hand, instance and all',
        () async {
      const userId = 'warm-reentry';
      final dir = await cacheDirFor(userId);
      await File('${dir.path}/members_r1.json')
          .writeAsString(jsonEncode([for (final u in _roster()) u.toJson()]));

      await repo.attach(userId);
      cv.silentTranscript = true;
      await repo.openRoom('r1', owner: screenA);
      final first = repo.membersFor('r1');
      expect(first, isNotEmpty);

      // The cache is gone; a re-entry that went back to disk would come up
      // empty and repaint the room in theme ink.
      await File('${dir.path}/members_r1.json').delete();

      repo.closeRoom(screenA);
      await repo.openRoom('r1', owner: screenB);

      expect(
        repo.membersFor('r1'),
        same(first),
        reason: 'a warm re-entry must not re-read, or re-notify — the screens '
            'gate their rebuild on this list instance',
      );
    });

    test('hydrates the speaker pins at attach', () async {
      const userId = 'pinned-reader';
      final dir = await cacheDirFor(userId);
      await File('${dir.path}/speaker_colors.json').writeAsString(
        jsonEncode({
          'r1': {'u03': 7},
        }),
      );

      await repo.attach(userId);
      expect(repo.speakerColorsFor('r1'), {'u03': 7});
    });
  });

  group('the roster subscription', () {
    late _FakeCv cv;
    late _FakeApi api;
    late ChatRepository repo;
    late Object screenA;
    late Object screenB;

    setUp(() async {
      cv = _FakeCv();
      api = _FakeApi();
      repo = ChatRepository(api: api, cv: cv);
      screenA = Object();
      screenB = Object();
      await cacheDirFor('me');
      await repo.attach('me');
    });

    tearDown(() async {
      await repo.detach();
    });

    List<_FakeSub> memberSubsFor(String roomId) =>
        cv.issued.where((s) => s.label == 'rooms:getMembers/$roomId').toList();

    test('waits for the transcript, then registers', () async {
      await repo.openRoom('a', owner: screenA);
      await _pump();
      expect(memberSubsFor('a'), hasLength(1));
      expect(memberSubsFor('a').single.cancelled, isFalse);
    });

    test('is registered before the rest of the furniture', () async {
      // It is the only deferred query that changes pixels already on screen.
      await repo.openRoom('a', owner: screenA);
      await _pump();
      final order = cv.issued.map((s) => s.label.split('/').first).toList();
      expect(
        order.indexOf('rooms:getMembers'),
        lessThan(order.indexOf('pins:listForRoom')),
      );
    });

    test('a transcript that never answers still gets one, on the fallback',
        () async {
      cv.silentTranscript = true;
      ChatRepository.secondaryFallback = const Duration(milliseconds: 10);
      addTearDown(() {
        ChatRepository.secondaryFallback = const Duration(milliseconds: 600);
      });

      await repo.openRoom('a', owner: screenA);
      await _pump();
      expect(memberSubsFor('a'), isEmpty);

      await Future<void>.delayed(const Duration(milliseconds: 30));
      await _pump();
      expect(memberSubsFor('a'), hasLength(1));
    });

    test('an open backed out mid-registration cancels it', () async {
      final gate = Completer<void>();
      cv.gates['rooms:getMembers'] = gate;
      final opening = repo.openRoom('b', owner: screenB);
      await _pump();

      repo.closeRoom(screenB);
      gate.complete();
      await opening;
      await _pump();

      for (final s in memberSubsFor('b')) {
        expect(
          s.cancelled,
          isTrue,
          reason: 'a superseded open must not publish a roster subscription',
        );
      }
    });

    test('a newer open cancels the parked one', () async {
      final gate = Completer<void>();
      cv.gates['rooms:getMembers'] = gate;
      final opening = repo.openRoom('b', owner: screenB);
      await _pump();

      cv.gates.remove('rooms:getMembers');
      final second = repo.openRoom('c', owner: screenA);

      gate.complete();
      await opening;
      await second;
      await _pump();

      for (final s in memberSubsFor('b')) {
        expect(s.cancelled, isTrue);
      }
      expect(repo.activeRoomId, 'c');
    });

    test('closing the room cancels it', () async {
      await repo.openRoom('a', owner: screenA);
      await _pump();
      expect(memberSubsFor('a').single.cancelled, isFalse);

      repo.closeRoom(screenA);

      expect(memberSubsFor('a').single.cancelled, isTrue);
    });

    test('publishes the roster it is delivered', () async {
      await repo.openRoom('a', owner: screenA);
      await _pump();

      cv.sinks['rooms:getMembers']!(_wire(_roster()));
      expect(repo.membersFor('a'), hasLength(14));
      expect(repo.membersFor('a').first.joinedAt, isNotNull);
      expect(_slotsFor(repo.membersFor('a')), _slotsFor(_roster()));
    });

    test('an identical redelivery changes nothing anybody can observe',
        () async {
      // `markRoomRead` writes a `roomMembers` row for every incoming message,
      // so this query refires constantly in an active group chat while saying
      // nothing this app renders. Both screens gate their rebuild on the list
      // INSTANCE, so holding it steady is what keeps a live conversation from
      // rebuilding the transcript once per message.
      await repo.openRoom('a', owner: screenA);
      await _pump();

      final sink = cv.sinks['rooms:getMembers']!;
      sink(_wire(_roster()));
      final first = repo.membersFor('a');

      var notified = 0;
      void count() => notified++;
      repo.addListener(count);
      addTearDown(() => repo.removeListener(count));

      sink(_wire(_roster()));

      expect(repo.membersFor('a'), same(first));
      expect(notified, 0);
    });

    test('a real change does come through', () async {
      await repo.openRoom('a', owner: screenA);
      await _pump();

      final sink = cv.sinks['rooms:getMembers']!;
      sink(_wire(_roster()));
      final first = repo.membersFor('a');

      final renamed = _roster();
      renamed[0].name = 'Renamed';
      sink(_wire(renamed));

      expect(repo.membersFor('a'), isNot(same(first)));
      expect(repo.membersFor('a').first.name, 'Renamed');
    });

    test('a member coming online comes through', () async {
      // Presence is the one thing the disk seed deliberately does not carry,
      // so the delivery that adds it must not be deduped away.
      await repo.openRoom('a', owner: screenA);
      await _pump();

      final sink = cv.sinks['rooms:getMembers']!;
      final offline = [
        for (final u in _roster())
          ChatUser(
            id: u.id,
            username: u.username,
            name: u.name,
            joinedAt: u.joinedAt,
          ),
      ];
      sink(_wire(offline));
      final first = repo.membersFor('a');
      expect(first.first.status, isNull);

      sink(_wire(_roster()));
      expect(repo.membersFor('a'), isNot(same(first)));
      expect(repo.membersFor('a').first.status, isNotNull);
    });

    test('signing out takes the roster with it', () async {
      // A `rooms:getMembers` row is scoped to a viewer who is a member, so
      // keeping it would hand the next person on this handset the membership
      // of a room they may not be in.
      await repo.openRoom('a', owner: screenA);
      await _pump();
      cv.sinks['rooms:getMembers']!(_wire(_roster()));
      expect(repo.membersFor('a'), isNotEmpty);

      await repo.detach();

      expect(repo.membersFor('a'), isEmpty);
      expect(memberSubsFor('a').single.cancelled, isTrue);
    });

    test('and the next account is not deduped against it', () async {
      // The signature has to go with the roster, or the new reader's first
      // delivery for the same room would compare equal to a roster they never
      // saw and never paint.
      await repo.openRoom('a', owner: screenA);
      await _pump();
      cv.sinks['rooms:getMembers']!(_wire(_roster()));
      await repo.detach();

      await cacheDirFor('someone-else');
      await repo.attach('someone-else');
      await repo.openRoom('a', owner: screenB);
      await _pump();
      cv.sinks['rooms:getMembers']!(_wire(_roster()));

      expect(repo.membersFor('a'), hasLength(14));
    });

    test('the delivered roster is written to disk', () async {
      await repo.openRoom('a', owner: screenA);
      await _pump();
      cv.sinks['rooms:getMembers']!(_wire(_roster()));

      await Future<void>.delayed(const Duration(milliseconds: 700));
      final onDisk = await CacheStore.instance.loadMembers('me', 'a');
      expect(onDisk, hasLength(14));
      expect(_slotsFor(onDisk), _slotsFor(_roster()));
    });
  });
}
