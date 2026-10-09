import 'moment.dart';

/// One person's highlights, the way a stories rail shows them: a single card
/// per person, their items played oldest first so the latest is the last
/// thing you see, the way every stories viewer tells a day.
class MomentGroup {
  MomentGroup._(this.userId, this.items);

  final String userId;

  /// Oldest first.
  final List<Moment> items;

  /// The newest item: what orders the person on the rail.
  Moment get latest => items.last;

  bool get mine => items.first.mine;

  /// Something here the viewer has not opened yet: the ring.
  bool get unseen => items.any((m) => !m.mine && !m.seen);

  /// Where a tap begins: the first item not yet seen, so coming back to
  /// someone picks up where you left off; from the top once all are seen.
  ///
  /// Only among the pictures when there are any. The full-screen viewer
  /// plays pictures alone, and a start on a words-only item would open that
  /// one item as a card instead of the person's run.
  Moment get start {
    final pictures = [
      for (final m in items)
        if (m.thumbStorageId != null) m,
    ];
    final pool = pictures.isEmpty ? items : pictures;
    for (final m in pool) {
      if (!m.mine && !m.seen) return m;
    }
    return pool.first;
  }

  /// Groups [moments] by author.
  ///
  /// Your own first, where you look for it. Then the people with something
  /// new, then those you have seen through; each of those two by their
  /// latest item, newest first. Ties keep [moments]' own order, so the rail
  /// does not shuffle between two payloads that agree.
  static List<MomentGroup> of(List<Moment> moments) {
    final byAuthor = <String, List<Moment>>{};
    for (final m in moments) {
      byAuthor.putIfAbsent(m.userId, () => []).add(m);
    }
    final groups = [
      for (final e in byAuthor.entries)
        MomentGroup._(
          e.key,
          List.unmodifiable(
            [...e.value]..sort((a, b) => a.createdAt.compareTo(b.createdAt)),
          ),
        ),
    ];
    int rank(MomentGroup g) => g.mine ? 0 : (g.unseen ? 1 : 2);
    final order = {for (var i = 0; i < groups.length; i++) groups[i]: i};
    groups.sort((a, b) {
      final r = rank(a).compareTo(rank(b));
      if (r != 0) return r;
      final t = b.latest.createdAt.compareTo(a.latest.createdAt);
      if (t != 0) return t;
      return order[a]!.compareTo(order[b]!);
    });
    return groups;
  }

  /// [groups] as one run, person after person: what the viewer plays, so a
  /// swipe past someone lands on the next card along the rail.
  static List<Moment> flatten(List<MomentGroup> groups) => [
        for (final g in groups) ...g.items,
      ];
}
