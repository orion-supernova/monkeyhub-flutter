import '../l10n/generated/app_localizations.dart';
import '../models/chat_room.dart';

/// The three independent axes a room can be filtered on.
///
/// Facets within one dimension OR together; dimensions AND together. So
/// `dms + groups + unread` reads `(isDm ∨ ¬isDm) ∧ hasUnread` — "unread
/// conversations of either kind" — rather than the union of three sets, which
/// is what a flat OR would give and which can't express "unread DMs" at all.
enum FacetDimension { type, nature, status }

/// The order the filter controls lay the dimensions out in, shared by the chip
/// row and the drawer panel so the two styles stay the same shape.
///
/// Status leads because `unread` is the one facet people reach for daily, and
/// it belongs directly after the 'all' reset rather than at the end of a row
/// that has to be scrolled to reach it.
///
/// Kept separate from the declaration order of [FacetDimension] on purpose:
/// this is presentation, and nothing about the filter's semantics should move
/// when the row is rearranged again.
const List<FacetDimension> facetDimensionOrder = [
  FacetDimension.status,
  FacetDimension.type,
  FacetDimension.nature,
];

/// A single filter facet. Every predicate is an O(1) field or getter read on
/// [ChatRoom], so a full pass over the room list stays cheap enough to run on
/// each repository push (see [RoomFacetCounts]).
///
/// `archived` and `pinned` now have backing data (`roomMembers.isArchived` /
/// `.isPinned`) but stay OUT of this enum on purpose: they aren't things a
/// user toggles to narrow a view, they're structural. Archived rooms are
/// hidden from the list outright ([ChatRepository.activeRooms]), and pinned
/// rooms float to a fixed section instead ([partitionPinned]) rather than
/// filtering anything in or out. `muted` still has no backing data at all.
enum RoomFacet {
  dms(FacetDimension.type),
  groups(FacetDimension.type),
  public(FacetDimension.nature),
  private(FacetDimension.nature),
  secret(FacetDimension.nature),
  locked(FacetDimension.nature),
  unread(FacetDimension.status),
  mentions(FacetDimension.status);

  const RoomFacet(this.dimension);

  final FacetDimension dimension;

  /// Lowercase display label. The UI uppercases it where the theme calls for
  /// mono-caps; keeping it lowercase here matches the app's copy voice.
  ///
  /// A method rather than a stored field — needs [AppLocalizations], which a
  /// const enum constructor can't take. Takes the resolved instance rather
  /// than a BuildContext so it stays plain-Dart testable (see
  /// test/room_filter_test.dart).
  String label(AppLocalizations l10n) {
    return switch (this) {
      RoomFacet.dms => l10n.roomFacetLabelDms,
      RoomFacet.groups => l10n.roomFacetLabelGroups,
      RoomFacet.public => l10n.roomFacetLabelPublic,
      RoomFacet.private => l10n.roomFacetLabelPrivate,
      RoomFacet.secret => l10n.roomFacetLabelSecret,
      RoomFacet.locked => l10n.roomFacetLabelLocked,
      RoomFacet.unread => l10n.roomFacetLabelUnread,
      RoomFacet.mentions => l10n.roomFacetLabelMentions,
    };
  }


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

  /// This filter with one whole dimension dropped — the rest still applied.
  ///
  /// The probe [RoomFacetCounts.projected] counts against: it answers "of the
  /// rooms the *other* dimensions allow, how many carry this facet?".
  RoomFilter without(FacetDimension dimension) {
    if (isEmpty) return empty;
    final next = facets.where((f) => f.dimension != dimension).toSet();
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
  String summary(AppLocalizations l10n) =>
      facets.map((f) => f.label(l10n)).join(' + ');

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

  /// How many rooms carry each facet *within the rest of the active filter* —
  /// the other dimensions applied, the facet's own dimension ignored.
  ///
  /// The plain [of] totals start lying the moment anything is selected, because
  /// facets AND across dimensions. With `dms` active, a `locked` chip showing
  /// the raw total of 3 means "3 locked rooms overall" — which may all be
  /// groups, so tapping it lands straight on the empty state. A count that
  /// promises rooms it cannot show is worse than showing no count at all.
  ///
  /// Ignoring the facet's *own* dimension is what keeps the number steady under
  /// the tap that sets it. Probing with [RoomFilter.toggle] instead — literally
  /// "what would this tap yield" — made the lit chip report the release rather
  /// than the selection: tapping `public` in a 7-room list narrowed it to the 1
  /// public room while the chip flipped from 1 to 7, since turning `public` back
  /// off is what reveals all seven. Facets OR within a dimension, so the same
  /// probe also inflated every unlit sibling by the rooms its lit neighbour had
  /// already claimed.
  ///
  /// For a facet whose dimension is otherwise untouched the two rules agree, so
  /// an unlit chip still reads as "what tapping me shows".
  factory RoomFacetCounts.projected(List<ChatRoom> rooms, RoomFilter filter) {
    final base = RoomFacetCounts.of(rooms);
    if (filter.isEmpty) return base;
    // One probe per dimension rather than one per facet: three filters built
    // instead of eight, and the room scan stays single-pass.
    final probes = <FacetDimension, RoomFilter>{
      for (final d in FacetDimension.values) d: filter.without(d),
    };
    final counts = List<int>.filled(RoomFacet.values.length, 0);
    for (final r in rooms) {
      for (final f in RoomFacet.values) {
        if (f.matches(r) && probes[f.dimension]!.matches(r)) counts[f.index]++;
      }
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

/// Splits [rooms] into a pinned-first group and everything else — a single
/// stable pass, not a re-sort, preserving [rooms]'s existing recency order in
/// both buckets for the same reason [RoomFilter.apply] doesn't re-sort.
///
/// Saved Messages ([ChatRoom.isSavedMessages]) leads the pinned group *while
/// it is pinned*, and it starts out that way (`rooms.ts`
/// ensureSavedMessagesRoom seeds `isPinned`). It is no longer forced there:
/// unpinning it drops it into `regular` with everything else, and archiving
/// it removes it from this list entirely (ChatRepository.activeRooms filters
/// archived rooms out upstream). A notes-to-self chat someone never writes in
/// shouldn't be nailed to the top of their list forever.
({List<ChatRoom> pinned, List<ChatRoom> regular}) partitionPinned(
  List<ChatRoom> rooms,
) {
  ChatRoom? saved;
  final pinned = <ChatRoom>[];
  final regular = <ChatRoom>[];
  for (final r in rooms) {
    if (r.isSavedMessages && r.isPinned) {
      saved = r;
    } else if (r.isPinned) {
      pinned.add(r);
    } else {
      regular.add(r);
    }
  }
  return (pinned: [?saved, ...pinned], regular: regular);
}
