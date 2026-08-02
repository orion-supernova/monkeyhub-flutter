import '../models/chat_room.dart';

/// The three independent axes a room can be filtered on.
///
/// Facets within one dimension OR together; dimensions AND together. So
/// `dms + groups + unread` reads `(isDm ∨ ¬isDm) ∧ hasUnread` — "unread
/// conversations of either kind" — rather than the union of three sets, which
/// is what a flat OR would give and which can't express "unread DMs" at all.
enum FacetDimension { type, nature, status }

/// A single filter facet. Every predicate is an O(1) field or getter read on
/// [ChatRoom], so a full pass over the room list stays cheap enough to run on
/// each repository push (see [RoomFacetCounts]).
///
/// Deliberately absent: archived, muted and pinned. None of them have backing
/// data — `roomMembers` carries only `roomId, userId, joinedAt, role,
/// lastReadAt` — so they'd need a schema column and a mutation first.
enum RoomFacet {
  dms(FacetDimension.type, 'dms'),
  groups(FacetDimension.type, 'groups'),
  public(FacetDimension.nature, 'public'),
  private(FacetDimension.nature, 'private'),
  secret(FacetDimension.nature, 'secret'),
  locked(FacetDimension.nature, 'locked'),
  unread(FacetDimension.status, 'unread'),
  mentions(FacetDimension.status, 'mentions');

  const RoomFacet(this.dimension, this.label);

  final FacetDimension dimension;

  /// Lowercase display label. The UI uppercases it where the theme calls for
  /// mono-caps; keeping it lowercase here matches the app's copy voice.
  final String label;

  /// A DM is `name.startsWith('dm:')` and nothing else — not a [RoomType], not
  /// a member count, since a group can have two members. The backend uses the
  /// same test in `messages.ts`, `rooms.ts` and `childGuard.ts`.
  bool matches(ChatRoom r) => switch (this) {
    RoomFacet.dms => r.isDm,
    RoomFacet.groups => !r.isDm,
    RoomFacet.public => r.isPublic,
    RoomFacet.private => r.isPrivate,
    RoomFacet.secret => r.isEphemeral,
    RoomFacet.locked => r.hasPassword,
    RoomFacet.unread => r.hasUnread,
    RoomFacet.mentions => r.hasMention,
  };

  static final Map<String, RoomFacet> _byName = {
    for (final f in RoomFacet.values) f.name: f,
  };
}

/// Which facets are active on the chat list. Immutable — [toggle] returns a new
/// instance rather than mutating, so it can be compared cheaply and stored.
class RoomFilter {
  /// Materialises the input exactly once before using it twice.
  ///
  /// The previous form iterated `facets` in the initialiser and again in
  /// `_groupsOf(facets)`. For a single-subscription Iterable — anything built
  /// from a `.where()` or a generator — the second pass yields nothing, so
  /// `_groups` came out empty while `facets` was full: [matches] would then
  /// admit every room while [isNotEmpty] still reported a filter was on. Every
  /// current caller happens to pass a re-iterable Set, which is the only reason
  /// this never fired.
  factory RoomFilter(Iterable<RoomFacet> facets) {
    final sorted = facets.toList()..sort((a, b) => a.index.compareTo(b.index));
    return RoomFilter._(sorted);
  }

  RoomFilter._(List<RoomFacet> sorted)
    : facets = Set.unmodifiable(sorted),
      _groups = _groupsOf(sorted);

  const RoomFilter._empty()
    : facets = const <RoomFacet>{},
      _groups = const <List<RoomFacet>>[];

  /// The no-filter state: matches every room.
  static const RoomFilter empty = RoomFilter._empty();

  final Set<RoomFacet> facets;

  /// Active facets bucketed by dimension, with empty dimensions omitted.
  /// Precomputed so [matches] allocates nothing — it runs once per room on
  /// every rebuild, and the repository notifies on every typing keystroke.
  final List<List<RoomFacet>> _groups;

  static List<List<RoomFacet>> _groupsOf(Iterable<RoomFacet> facets) {
    if (facets.isEmpty) return const <List<RoomFacet>>[];
    final byDimension = <FacetDimension, List<RoomFacet>>{};
    for (final f in facets) {
      (byDimension[f.dimension] ??= <RoomFacet>[]).add(f);
    }
    return List.unmodifiable(
      byDimension.values.map(List<RoomFacet>.unmodifiable),
    );
  }

  bool get isEmpty => facets.isEmpty;
  bool get isNotEmpty => facets.isNotEmpty;
  bool has(RoomFacet f) => facets.contains(f);

  RoomFilter toggle(RoomFacet f) {
    final next = facets.toSet();
    if (!next.remove(f)) next.add(f);
    return next.isEmpty ? empty : RoomFilter(next);
  }

  /// True when every non-empty dimension has at least one passing facet.
  /// An empty filter has no groups, so the loop falls through to true.
  bool matches(ChatRoom r) {
    for (final group in _groups) {
      var any = false;
      for (final f in group) {
        if (f.matches(r)) {
          any = true;
          break;
        }
      }
      if (!any) return false;
    }
    return true;
  }

  /// Filters in place, preserving order. The server already sorts by recency
  /// (`rooms.ts` `listUserRooms`), so re-sorting here would fight it.
  List<ChatRoom> apply(List<ChatRoom> rooms) =>
      isEmpty ? rooms : rooms.where(matches).toList(growable: false);

  /// Human-readable active-filter cue, e.g. `dms + unread`. Empty string when
  /// no filter is active.
  String get summary => facets.map((f) => f.label).join(' + ');

  String encode() => facets.map((f) => f.name).join(',');

  /// Tolerates unknown tokens so a facet removed in a later version can't wedge
  /// a user on a persisted filter that no longer parses.
  factory RoomFilter.decode(String? raw) {
    if (raw == null || raw.isEmpty) return empty;
    final parsed = <RoomFacet>{};
    for (final token in raw.split(',')) {
      final f = RoomFacet._byName[token.trim()];
      if (f != null) parsed.add(f);
    }
    return parsed.isEmpty ? empty : RoomFilter(parsed);
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is RoomFilter &&
          other.facets.length == facets.length &&
          other.facets.containsAll(facets);

  @override
  int get hashCode => Object.hashAllUnordered(facets);

  @override
  String toString() => 'RoomFilter(${isEmpty ? 'all' : encode()})';
}

/// How many rooms match each facet, plus the two unread aggregates the shell
/// badges need — all from a single pass over the room list.
///
/// Exists because every aggregate on [ChatRepository] used to be recomputed per
/// getter call, and the filter UI wants eight more of them. Building all ten in
/// one loop and caching the result turns "eight scans per typing keystroke"
/// into "one scan per room push".
class RoomFacetCounts {
  const RoomFacetCounts._(
    this._byFacet,
    this.total,
    this.unreadRooms,
    this.unreadMessages,
  );

  /// Derived from [RoomFacet.values] rather than eight literal zeroes, which
  /// silently became a `RangeError` in [operator []] the moment a ninth facet
  /// was added — on the empty-room path, i.e. every cold start.
  static final RoomFacetCounts zero = RoomFacetCounts._(
    List.unmodifiable(List<int>.filled(RoomFacet.values.length, 0)),
    0,
    0,
    0,
  );

  final List<int> _byFacet;

  /// Total rooms, unfiltered — what the "show all N chats" escape hatch reports.
  final int total;

  /// Rooms with anything unread. Was `ChatRepository.unreadRoomCount`.
  final int unreadRooms;

  /// Sum of per-room unread counts. Was `ChatRepository.unreadMessageTotal`,
  /// and drives the OS icon badge.
  final int unreadMessages;

  int operator [](RoomFacet f) => _byFacet[f.index];

  /// What each facet would yield *given the rest of the active filter* — i.e.
  /// the number of rooms you'd actually see if you tapped that control.
  ///
  /// The plain [of] totals start lying the moment anything is selected, because
  /// facets AND across dimensions. With `dms` active, a `locked` chip showing
  /// the raw total of 3 means "3 locked rooms overall" — which may all be
  /// groups, so tapping it lands straight on the empty state. A count that
  /// promises rooms it cannot show is worse than showing no count at all.
  ///
  /// Uses [RoomFilter.toggle] as the probe, so the number is by construction
  /// exactly what the tap produces — including for an already-active facet,
  /// where the tap turns it off and the count is what that reveals.
  factory RoomFacetCounts.projected(List<ChatRoom> rooms, RoomFilter filter) {
    final base = RoomFacetCounts.of(rooms);
    if (filter.isEmpty) return base;
    final counts = List<int>.filled(RoomFacet.values.length, 0);
    for (final f in RoomFacet.values) {
      final probe = filter.toggle(f);
      var n = 0;
      for (final r in rooms) {
        if (probe.matches(r)) n++;
      }
      counts[f.index] = n;
    }
    return RoomFacetCounts._(
      List.unmodifiable(counts),
      base.total,
      base.unreadRooms,
      base.unreadMessages,
    );
  }

  factory RoomFacetCounts.of(List<ChatRoom> rooms) {
    if (rooms.isEmpty) return zero;
    final counts = List<int>.filled(RoomFacet.values.length, 0);
    var unreadRooms = 0;
    var unreadMessages = 0;
    for (final r in rooms) {
      for (final f in RoomFacet.values) {
        if (f.matches(r)) counts[f.index]++;
      }
      if (r.hasUnread) unreadRooms++;
      unreadMessages += r.unreadCount;
    }
    return RoomFacetCounts._(
      List.unmodifiable(counts),
      rooms.length,
      unreadRooms,
      unreadMessages,
    );
  }
}
