import 'package:flutter_test/flutter_test.dart';
import 'package:monkeyhub/models/moment.dart';

/// The standings arithmetic and the moment model's decoding.
///
/// Pure — no Flutter binding, no widget pumping. `MomentTally.from` is
/// extracted precisely so the ranking rules can be checked here rather than by
/// reading pixels off a leaderboard.
Moment _m({
  required String id,
  required String userId,
  MomentTag? tag,
  DateTime? createdAt,
  DateTime? expiresAt,
}) {
  final made = createdAt ?? DateTime(2026, 8, 7, 9);
  return Moment(
    id: id,
    userId: userId,
    dayKey: '2026-08-07',
    createdAt: made,
    expiresAt: expiresAt ?? made.add(const Duration(hours: 24)),
    authorName: 'Author $userId',
    authorUsername: userId,
    mine: false,
    seen: false,
    tag: tag,
  );
}

void main() {
  group('MomentTally.from', () {
    test('ignores untagged moments — a highlight is not a point', () {
      final t = MomentTally.from([
        _m(id: '1', userId: 'a'),
        _m(id: '2', userId: 'a', tag: MomentTag.jinx),
      ]);
      expect(t, hasLength(1));
      expect(t.single.total, 1);
      expect(t.single.of(MomentTag.jinx), 1);
    });

    test('returns nothing when nobody scored', () {
      expect(MomentTally.from([_m(id: '1', userId: 'a')]), isEmpty);
      expect(MomentTally.from(const []), isEmpty);
    });

    test('counts per category per person', () {
      final t = MomentTally.from([
        _m(id: '1', userId: 'a', tag: MomentTag.jinx),
        _m(id: '2', userId: 'a', tag: MomentTag.jinx),
        _m(id: '3', userId: 'a', tag: MomentTag.fate),
        _m(id: '4', userId: 'b', tag: MomentTag.npc),
      ]);
      final a = t.firstWhere((x) => x.userId == 'a');
      expect(a.of(MomentTag.jinx), 2);
      expect(a.of(MomentTag.fate), 1);
      expect(a.of(MomentTag.luck), 0);
      expect(a.total, 3);
      expect(t.firstWhere((x) => x.userId == 'b').total, 1);
    });

    test('ranks by total, highest first', () {
      final t = MomentTally.from([
        _m(id: '1', userId: 'low', tag: MomentTag.fate),
        _m(id: '2', userId: 'high', tag: MomentTag.jinx),
        _m(id: '3', userId: 'high', tag: MomentTag.luck),
      ]);
      expect(t.map((x) => x.userId), ['high', 'low']);
    });

    test('breaks ties deterministically', () {
      // The leaderboard animates rows between positions by identity, so an
      // unstable sort would make equal scores swap places on every rebuild —
      // rows sliding past each other for no reason.
      final input = [
        _m(id: '1', userId: 'zoe', tag: MomentTag.fate),
        _m(id: '2', userId: 'ada', tag: MomentTag.jinx),
      ];
      final first = MomentTally.from(input).map((x) => x.userId).toList();
      final second = MomentTally.from(input.reversed).map((x) => x.userId).toList();
      expect(first, second);
      expect(first, ['ada', 'zoe']);
    });
  });

  group('decay', () {
    final made = DateTime(2026, 8, 7, 12);
    final m = _m(
      id: '1',
      userId: 'a',
      createdAt: made,
      expiresAt: made.add(const Duration(hours: 24)),
    );

    test('runs 0 at birth to 1 at expiry', () {
      expect(m.decayProgress(made), 0);
      expect(m.decayProgress(made.add(const Duration(hours: 12))), closeTo(0.5, 0.001));
      expect(m.decayProgress(made.add(const Duration(hours: 24))), 1);
    });

    test('clamps past expiry', () {
      // Your own moments outlive their window on your own board, and
      // AppTheme.ephemeralSignature asserts outside 0..1.
      expect(m.decayProgress(made.add(const Duration(days: 3))), 1);
      expect(m.decayProgress(made.subtract(const Duration(hours: 1))), 0);
    });

    test('isLive flips exactly at expiry', () {
      expect(m.isLive(made.add(const Duration(hours: 23, minutes: 59))), isTrue);
      expect(m.isLive(made.add(const Duration(hours: 24))), isFalse);
    });
  });

  group('MomentTag.parse', () {
    test('round-trips every wire value', () {
      for (final t in MomentTag.values) {
        expect(MomentTag.parse(t.wire), t);
      }
    });

    test('unknown and absent both read as untagged', () {
      // A tag added by a newer client must render as a plain highlight on an
      // older one, not crash it.
      expect(MomentTag.parse(null), isNull);
      expect(MomentTag.parse('somethingNewer'), isNull);
      expect(MomentTag.parse(''), isNull);
    });
  });

  group('fromJson', () {
    test('never turns a null id into the string "null"', () {
      // The exact bug documented on ChatApi.getFileUrl: `null.toString()` is
      // the four-character string "null", which downstream code then treats as
      // a real storage id and caches.
      final m = Moment.fromJson({
        '_id': 'x',
        'userId': 'u',
        'dayKey': '2026-08-07',
        'createdAt': 1,
        'expiresAt': 2,
        'authorName': 'A',
        'authorUsername': 'a',
      });
      expect(m.authorAvatarStorageId, isNull);
      expect(m.mediaStorageId, isNull);
      expect(m.posterStorageId, isNull);
      expect(m.caption, isNull);
    });

    test('drops zero and negative reaction counts', () {
      final m = Moment.fromJson({
        '_id': 'x',
        'userId': 'u',
        'dayKey': '2026-08-07',
        'createdAt': 1,
        'expiresAt': 2,
        'authorName': 'A',
        'authorUsername': 'a',
        'reactionCounts': [
          {'emoji': '👏', 'count': 2},
          {'emoji': '💀', 'count': 0},
        ],
        'myReactions': ['👏'],
      });
      expect(m.reactionCounts, {'👏': 2});
      expect(m.myReactions, {'👏'});
    });

    // The wire shape is a LIST, never a map keyed by the emoji: Convex field
    // names must be non-control ASCII, so an emoji-keyed object serializes
    // fine until it doesn't and takes the whole query down with it. A map
    // arriving here means someone reintroduced that shape on the backend, and
    // silently reading zero reactions would hide it all over again.
    test('an emoji-keyed map is not mistaken for the wire shape', () {
      final m = Moment.fromJson({
        '_id': 'x',
        'userId': 'u',
        'dayKey': '2026-08-07',
        'createdAt': 1,
        'expiresAt': 2,
        'authorName': 'A',
        'authorUsername': 'a',
        'reactionCounts': {'👏': 2},
        'myReactions': const <String>[],
      });
      expect(m.reactionCounts, isEmpty);
    });

    test('reaction counts survive multi-codepoint emoji', () {
      // ❤️ is U+2764 U+FE0F — two codepoints, and the exact value that broke
      // the board.
      final m = Moment.fromJson({
        '_id': 'x',
        'userId': 'u',
        'dayKey': '2026-08-07',
        'createdAt': 1,
        'expiresAt': 2,
        'authorName': 'A',
        'authorUsername': 'a',
        'reactionCounts': [
          {'emoji': '❤️', 'count': 3},
        ],
        'myReactions': ['❤️'],
      });
      expect(m.reactionCounts, {'❤️': 3});
      expect(m.myReactions, {'❤️'});
    });
  });
}
