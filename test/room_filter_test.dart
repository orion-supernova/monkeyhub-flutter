import 'package:flutter_test/flutter_test.dart';
import 'package:monkeyhub/data/room_filter.dart';
import 'package:monkeyhub/models/chat_room.dart';
import 'package:monkeyhub/models/enums.dart';

ChatRoom room({
  String id = 'r1',
  String name = 'general',
  bool isPrivate = true,
  bool hasPassword = false,
  RoomType type = RoomType.regular,
  int unreadCount = 0,
  bool hasMention = false,
}) => ChatRoom(
  id: id,
  name: name,
  createdBy: 'u0',
  createdAt: DateTime(2026),
  isPrivate: isPrivate,
  memberCount: 2,
  hasPassword: hasPassword,
  type: type,
  unreadCount: unreadCount,
  hasMention: hasMention,
);

/// A DM is `name.startsWith('dm:')` and nothing else — not a type, not a member
/// count, since a group can have two members.
ChatRoom dm({String id = 'd1', int unreadCount = 0, bool hasMention = false}) =>
    room(
      id: id,
      name: 'dm:u0:u1',
      unreadCount: unreadCount,
      hasMention: hasMention,
    );

void main() {
  group('facet predicates', () {
    test('dms and groups split on the dm: name prefix', () {
      expect(RoomFacet.dms.matches(dm()), isTrue);
      expect(RoomFacet.groups.matches(dm()), isFalse);
      expect(RoomFacet.dms.matches(room()), isFalse);
      expect(RoomFacet.groups.matches(room()), isTrue);
    });

    test('public and private are exact complements', () {
      for (final r in [room(isPrivate: true), room(isPrivate: false)]) {
        expect(
          RoomFacet.public.matches(r),
          isNot(RoomFacet.private.matches(r)),
        );
      }
    });

    test('secret reads the room type, locked reads hasPassword', () {
      expect(RoomFacet.secret.matches(room(type: RoomType.secret)), isTrue);
      expect(RoomFacet.secret.matches(room(hasPassword: true)), isFalse);
      expect(RoomFacet.locked.matches(room(hasPassword: true)), isTrue);
      expect(RoomFacet.locked.matches(room(type: RoomType.secret)), isFalse);
    });
  });

  group('combination', () {
    test('empty filter matches everything', () {
      expect(RoomFilter.empty.matches(dm()), isTrue);
      expect(RoomFilter.empty.matches(room()), isTrue);
      final all = [dm(), room()];
      expect(RoomFilter.empty.apply(all), same(all));
    });

    test('facets in one dimension OR together', () {
      final f = RoomFilter({RoomFacet.dms, RoomFacet.groups});
      expect(f.matches(dm()), isTrue);
      expect(f.matches(room()), isTrue);
    });

    test('facets in different dimensions AND together', () {
      // The headline case: "dms + groups + unread" must mean
      // (isDm ∨ ¬isDm) ∧ hasUnread — every kind of chat, but only unread ones.
      final f = RoomFilter({RoomFacet.dms, RoomFacet.groups, RoomFacet.unread});
      expect(f.matches(dm(unreadCount: 3)), isTrue);
      expect(f.matches(room(unreadCount: 1)), isTrue);
      expect(f.matches(dm()), isFalse);
      expect(f.matches(room()), isFalse);
    });

    test('"unread dms" is expressible — a flat OR could not express it', () {
      final f = RoomFilter({RoomFacet.dms, RoomFacet.unread});
      expect(f.matches(dm(unreadCount: 2)), isTrue);
      // A read DM is excluded...
      expect(f.matches(dm()), isFalse);
      // ...and so is an unread group.
      expect(f.matches(room(unreadCount: 9)), isFalse);
    });

    test('apply preserves the server ordering', () {
      final rooms = [
        dm(id: 'a', unreadCount: 1),
        room(id: 'b', unreadCount: 1),
        dm(id: 'c', unreadCount: 1),
      ];
      final out = RoomFilter({RoomFacet.dms}).apply(rooms);
      expect(out.map((r) => r.id), ['a', 'c']);
    });

    test('toggle adds, removes, and collapses back to empty', () {
      var f = RoomFilter.empty.toggle(RoomFacet.dms);
      expect(f.has(RoomFacet.dms), isTrue);
      f = f.toggle(RoomFacet.unread);
      expect(f.facets, {RoomFacet.dms, RoomFacet.unread});
      f = f.toggle(RoomFacet.dms).toggle(RoomFacet.unread);
      expect(f.isEmpty, isTrue);
      expect(f, RoomFilter.empty);
    });

    test('equality ignores insertion order', () {
      expect(
        RoomFilter({RoomFacet.unread, RoomFacet.dms}),
        RoomFilter({RoomFacet.dms, RoomFacet.unread}),
      );
      expect(
        RoomFilter({RoomFacet.unread, RoomFacet.dms}).hashCode,
        RoomFilter({RoomFacet.dms, RoomFacet.unread}).hashCode,
      );
    });
  });

  group('persistence', () {
    test('round-trips every facet', () {
      final f = RoomFilter(RoomFacet.values);
      expect(RoomFilter.decode(f.encode()), f);
    });

    test('decodes null and empty as no filter', () {
      expect(RoomFilter.decode(null), RoomFilter.empty);
      expect(RoomFilter.decode(''), RoomFilter.empty);
    });

    test('drops unknown tokens rather than failing', () {
      // A facet removed in a later version must not wedge a user on a stored
      // filter that no longer parses.
      expect(
        RoomFilter.decode('dms,archived,unread'),
        RoomFilter({RoomFacet.dms, RoomFacet.unread}),
      );
      expect(RoomFilter.decode('archived,muted'), RoomFilter.empty);
    });

    test('summary reads as the cue the chat screen shows', () {
      expect(
        RoomFilter({RoomFacet.dms, RoomFacet.unread}).summary,
        'dms + unread',
      );
      expect(RoomFilter.empty.summary, '');
    });
  });

  group('counts', () {
    test('single pass agrees with a naive per-facet scan', () {
      final rooms = [
        dm(id: 'a', unreadCount: 3, hasMention: true),
        dm(id: 'b'),
        room(id: 'c', isPrivate: false, unreadCount: 1),
        room(id: 'd', hasPassword: true),
        room(id: 'e', type: RoomType.secret, unreadCount: 5),
      ];
      final counts = RoomFacetCounts.of(rooms);
      for (final f in RoomFacet.values) {
        expect(counts[f], rooms.where(f.matches).length, reason: f.name);
      }
    });

    test('folds in the unread aggregates the shell badges use', () {
      final counts = RoomFacetCounts.of([
        dm(id: 'a', unreadCount: 3),
        room(id: 'b', unreadCount: 4),
        room(id: 'c'),
      ]);
      expect(counts.total, 3);
      expect(counts.unreadRooms, 2);
      expect(counts.unreadMessages, 7);
    });

    test('empty room list yields zeroes', () {
      final counts = RoomFacetCounts.of(const []);
      expect(counts.total, 0);
      expect(counts.unreadMessages, 0);
      for (final f in RoomFacet.values) {
        expect(counts[f], 0);
      }
    });

    test('the zero singleton covers every facet', () {
      // It used to be eight literal zeroes. A ninth facet would have compiled
      // fine and then thrown RangeError on the empty-room path — i.e. on every
      // cold start, before the rooms subscription delivers.
      for (final f in RoomFacet.values) {
        expect(() => RoomFacetCounts.zero[f], returnsNormally, reason: f.name);
        expect(RoomFacetCounts.zero[f], 0);
      }
    });
  });

  group('projected counts', () {
    // Two DMs (one unread) and one locked group. With `dms` active, the raw
    // total for `locked` is 1 — but that room is a group, so tapping `locked`
    // would show nothing.
    final rooms = [
      dm(id: 'a', unreadCount: 2),
      dm(id: 'b'),
      room(id: 'c', hasPassword: true),
    ];

    test('with no filter they are the plain totals', () {
      final p = RoomFacetCounts.projected(rooms, RoomFilter.empty);
      final raw = RoomFacetCounts.of(rooms);
      for (final f in RoomFacet.values) {
        expect(p[f], raw[f], reason: f.name);
      }
    });

    test('a chip never promises rooms it would not show', () {
      final filter = RoomFilter({RoomFacet.dms});
      final p = RoomFacetCounts.projected(rooms, filter);
      // The honest answer for "dms + locked" is zero, not the raw total of 1.
      expect(RoomFacetCounts.of(rooms)[RoomFacet.locked], 1);
      expect(p[RoomFacet.locked], 0);
    });

    test('every projected count equals what tapping actually yields', () {
      for (final active in [
        RoomFilter.empty,
        RoomFilter({RoomFacet.dms}),
        RoomFilter({RoomFacet.unread}),
        RoomFilter({RoomFacet.dms, RoomFacet.unread}),
      ]) {
        final p = RoomFacetCounts.projected(rooms, active);
        for (final f in RoomFacet.values) {
          expect(
            p[f],
            active.toggle(f).apply(rooms).length,
            reason: '${active.encode()} + ${f.name}',
          );
        }
      }
    });

    test('an active facet reports what turning it off reveals', () {
      final filter = RoomFilter({RoomFacet.dms});
      final p = RoomFacetCounts.projected(rooms, filter);
      // Tapping the lit `dms` chip clears it, revealing all three rooms.
      expect(p[RoomFacet.dms], 3);
    });
  });

  group('constructor robustness', () {
    test('accepts a single-subscription Iterable', () {
      // The constructor consumed its argument twice — once to sort, once to
      // group by dimension. Anything that can only be walked once came out with
      // a full facet set but EMPTY groups, so matches() admitted every room
      // while isNotEmpty still claimed a filter was on.
      final once = RoomFacet.values.where((f) => f == RoomFacet.dms);
      final f = RoomFilter(once);
      expect(f.isNotEmpty, isTrue);
      expect(f.matches(dm()), isTrue);
      expect(f.matches(room()), isFalse, reason: 'groups were dropped');
    });

    test('a generator-built filter behaves like a set-built one', () {
      Iterable<RoomFacet> gen() sync* {
        yield RoomFacet.dms;
        yield RoomFacet.unread;
      }

      expect(RoomFilter(gen()), RoomFilter({RoomFacet.dms, RoomFacet.unread}));
      expect(RoomFilter(gen()).matches(dm(unreadCount: 1)), isTrue);
      expect(RoomFilter(gen()).matches(dm()), isFalse);
    });
  });
}
