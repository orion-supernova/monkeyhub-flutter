/// One thing that happened today.
///
/// A moment is media + words + who + when. Whether it also *scores* is one
/// optional field, [tag]. Untagged, it is a highlight — a good sunset, a stray
/// cat, anything worth showing. Tagged, it additionally lands on the standings
/// board.
///
/// The collapse is deliberate: the standings board reads rows the composer
/// already writes, so it needs no write path of its own, and tagging a photo
/// you just took is one tap rather than a second feature.
library;

/// The scoring categories.
///
/// Wire values are mirrored in `backend/convex/feed.ts`'s `TAGS`. There is no
/// shared constants mechanism between Dart and TypeScript in this repo — error
/// codes are duplicated as literals on both sides too — so a change here is a
/// change in both files, and [MomentTag.parse] must keep failing soft.
enum MomentTag {
  /// The improbable coincidence. You ran into your dentist in Lisbon. What are
  /// the odds — no benefit implied, just the universe being strange.
  fate('fate'),

  /// You did a reasonable thing and the timing made it pointless. Washed the
  /// car; it rained at four. The English for "kerizlik" — the universe mocking
  /// your effort, self-inflicted rather than merely unlucky.
  jinx('jinx'),

  /// It went your way. Caught the train with two seconds to spare, found
  /// parking directly outside. The mirror of [jinx].
  luck('luck'),

  /// You said it would happen, everyone doubted you, it happened.
  calledIt('calledIt'),

  /// Brain fully off. Walked into a room and forgot why, said "you too" to the
  /// waiter, put the cereal in the fridge.
  npc('npc');

  const MomentTag(this.wire);

  /// The string stored on the backend. Kept explicit rather than using `.name`
  /// so renaming a Dart member can never silently orphan every stored row.
  final String wire;

  static final Map<String, MomentTag> _byWire = {
    for (final t in values) t.wire: t,
  };

  /// Resolves a stored tag. Returns null for absent AND for unknown, so a tag
  /// added by a newer client renders as a plain highlight on an older one
  /// rather than crashing it.
  static MomentTag? parse(String? s) => s == null ? null : _byWire[s];
}

/// What kind of media a moment carries, if any.
enum MomentMedia {
  none,
  image,
  video;

  static MomentMedia parse(String? s) => switch (s) {
    'image' => MomentMedia.image,
    'video' => MomentMedia.video,
    _ => MomentMedia.none,
  };
}

/// One person's reaction to a moment, with the name already attached — the
/// board never resolves a `users` document (see `feed.ts`'s `momentView`), so
/// the name has to already be riding on the row it's read from.
class MomentReactor {
  const MomentReactor({
    required this.emoji,
    required this.userId,
    required this.name,
  });

  final String emoji;
  final String userId;
  final String name;
}

class Moment {
  const Moment({
    required this.id,
    required this.userId,
    required this.dayKey,
    required this.createdAt,
    required this.expiresAt,
    required this.authorName,
    required this.authorUsername,
    required this.mine,
    required this.seen,
    this.tag,
    this.caption,
    this.mediaStorageId,
    this.posterStorageId,
    this.mediaKind = MomentMedia.none,
    this.authorAvatarStorageId,
    this.reactionCounts = const {},
    this.myReactions = const {},
    this.reactors = const [],
  });

  final String id;
  final String userId;

  /// `YYYY-MM-DD` in the AUTHOR's local zone — not the viewer's. Two friends in
  /// different timezones legitimately disagree about which day a moment
  /// belongs to, and the author's answer is the one that means something.
  final String dayKey;

  final DateTime createdAt;

  /// When this drops off friends' boards. The row and the blob both survive in
  /// the author's archive, so this is a listing rule and not a deletion
  /// deadline — see the note in `backend/convex/schema.ts`.
  final DateTime expiresAt;

  final String authorName;
  final String authorUsername;
  final String? authorAvatarStorageId;

  /// Whether the viewer wrote this.
  final bool mine;

  /// Whether the viewer has already opened it. Always true for your own.
  final bool seen;

  /// Null for a plain highlight.
  final MomentTag? tag;

  final String? caption;
  final String? mediaStorageId;
  final String? posterStorageId;
  final MomentMedia mediaKind;

  /// emoji → how many people reacted with it.
  final Map<String, int> reactionCounts;

  /// The emoji the viewer themselves added, for the filled/unfilled state.
  final Set<String> myReactions;

  /// Who's behind each count in [reactionCounts]. Sparser than the counts:
  /// reactions from before names were denormalized onto the row are dropped
  /// rather than shown with a blank name, so this can undercount briefly.
  final List<MomentReactor> reactors;

  /// Whether this still counts toward friends' boards at [now].
  ///
  /// Takes the instant rather than reading the clock so the expiry sweep and
  /// the widget tests agree on what "now" is.
  bool isLive(DateTime now) => now.isBefore(expiresAt);

  /// How far through its visible life this is, 0 (fresh) → 1 (expired).
  ///
  /// The exact argument `AppTheme.ephemeralSignature` takes. Clamped, because
  /// a moment can outlive its window on your own board.
  double decayProgress(DateTime now) {
    final total = expiresAt.difference(createdAt).inMilliseconds;
    if (total <= 0) return 1;
    final gone = now.difference(createdAt).inMilliseconds;
    return (gone / total).clamp(0.0, 1.0);
  }

  static Moment fromJson(Map<String, dynamic> j) {
    // The wire shape is a LIST of `{emoji, count}`, not a map keyed by the
    // emoji — Convex field names must be non-control ASCII, so an emoji-keyed
    // object serializes fine right up until it doesn't and takes the whole
    // query with it. Flattened into a map here because that is what every
    // consumer wants; the wire is the only place the shape matters.
    //
    // Pattern-matched rather than cast: a hard `as List` here would turn any
    // future wire drift into a thrown parse for EVERY moment in the payload,
    // which is the same "whole board goes blank" failure by another route.
    final counts = <String, int>{};
    final rawCounts = j['reactionCounts'];
    if (rawCounts is List) {
      for (final e in rawCounts) {
        if (e is! Map) continue;
        final emoji = e['emoji']?.toString();
        final n = (e['count'] as num?)?.toInt() ?? 0;
        if (emoji != null && emoji.isNotEmpty && n > 0) counts[emoji] = n;
      }
    }
    return Moment(
      id: j['_id'].toString(),
      userId: j['userId'].toString(),
      dayKey: j['dayKey']?.toString() ?? '',
      createdAt: DateTime.fromMillisecondsSinceEpoch(
        (j['createdAt'] as num?)?.toInt() ?? 0,
      ),
      expiresAt: DateTime.fromMillisecondsSinceEpoch(
        (j['expiresAt'] as num?)?.toInt() ?? 0,
      ),
      authorName: j['authorName']?.toString() ?? '',
      authorUsername: j['authorUsername']?.toString() ?? '',
      // Never `.toString()` a possibly-null id: `null.toString()` is the
      // four-character string "null", which then gets treated as a real
      // storage id downstream. That exact bug is documented on
      // `ChatApi.getFileUrl` and it poisoned a cache for the length of an
      // install.
      authorAvatarStorageId: j['authorAvatarStorageId']?.toString(),
      mine: j['mine'] == true,
      seen: j['seen'] == true,
      tag: MomentTag.parse(j['tag']?.toString()),
      caption: j['caption']?.toString(),
      mediaStorageId: j['mediaStorageId']?.toString(),
      posterStorageId: j['posterStorageId']?.toString(),
      mediaKind: MomentMedia.parse(j['mediaKind']?.toString()),
      reactionCounts: counts,
      myReactions: {
        for (final e in (j['myReactions'] as List?) ?? const []) e.toString(),
      },
      reactors: [
        for (final r in (j['reactors'] as List?) ?? const [])
          if (r is Map)
            MomentReactor(
              emoji: r['emoji']?.toString() ?? '',
              userId: r['userId']?.toString() ?? '',
              name: r['name']?.toString() ?? '',
            ),
      ],
    );
  }
}

/// Per-tag totals for one person on one day.
///
/// Derived on the client from the board payload rather than fetched: the rows
/// are already there, and a second query for a sum would be a second
/// subscription on a screen that is deliberately limited to one.
class MomentTally {
  const MomentTally({required this.userId, required this.counts});

  final String userId;
  final Map<MomentTag, int> counts;

  int get total => counts.values.fold(0, (a, b) => a + b);

  int of(MomentTag t) => counts[t] ?? 0;

  /// Groups [moments] into one tally per author, tagged rows only.
  ///
  /// Pure, and deliberately free of any Flutter binding, so the standings
  /// arithmetic can be unit-tested without pumping a widget — the discipline
  /// `RadialGeometry` and `pending_reconcile.dart` already follow here.
  static List<MomentTally> from(Iterable<Moment> moments) {
    final byUser = <String, Map<MomentTag, int>>{};
    for (final m in moments) {
      final tag = m.tag;
      if (tag == null) continue;
      final counts = byUser.putIfAbsent(m.userId, () => <MomentTag, int>{});
      counts[tag] = (counts[tag] ?? 0) + 1;
    }
    final out = [
      for (final e in byUser.entries)
        MomentTally(userId: e.key, counts: e.value),
    ];
    // Highest total first, then by userId so equal scores hold a stable order
    // instead of shuffling every time the board re-renders.
    out.sort((a, b) {
      final c = b.total.compareTo(a.total);
      return c != 0 ? c : a.userId.compareTo(b.userId);
    });
    return out;
  }
}
