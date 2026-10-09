import 'package:flutter_test/flutter_test.dart';
import 'package:monkeyhub/models/moment.dart';
import 'package:monkeyhub/models/moment_group.dart';

/// What this pins: **the highlights rail is one card per person, and a
/// person's day plays oldest first.** The rail drew a card per highlight,
/// newest first; the user wanted it the stories way: "grouping with people"
/// and "latest on last just like insta".
Moment _m(
  String id,
  String user,
  int hour, {
  bool seen = false,
  bool mine = false,
  bool picture = true,
}) => Moment(
  id: id,
  userId: user,
  dayKey: '2026-10-09',
  createdAt: DateTime(2026, 10, 9, hour),
  expiresAt: DateTime(2026, 10, 10, hour),
  authorName: user,
  authorUsername: user,
  mine: mine,
  seen: seen || mine,
  mediaStorageId: picture ? 'blob_$id' : null,
  mediaKind: picture ? MomentMedia.image : MomentMedia.none,
);

void main() {
  test("one group per person, each person's items oldest first", () {
    // The payload's order: newest first.
    final groups = MomentGroup.of([
      _m('a3', 'ada', 12),
      _m('b1', 'bo', 11),
      _m('a2', 'ada', 10),
      _m('a1', 'ada', 8),
    ]);
    expect(groups.map((g) => g.userId), ['ada', 'bo']);
    expect(groups.first.items.map((m) => m.id), ['a1', 'a2', 'a3']);
  });

  test('yours first, then new by latest, then seen-through by latest', () {
    final groups = MomentGroup.of([
      _m('s1', 'seen', 13, seen: true),
      _m('n1', 'new_early', 9),
      _m('n2', 'new_late', 12),
      _m('me', 'me', 7, mine: true),
    ]);
    expect(groups.map((g) => g.userId), [
      'me',
      'new_late',
      'new_early',
      'seen',
    ]);
  });

  test('a tap picks up at the first unseen item', () {
    final g = MomentGroup.of([
      _m('a3', 'ada', 12),
      _m('a2', 'ada', 10),
      _m('a1', 'ada', 8, seen: true),
    ]).single;
    expect(g.unseen, isTrue);
    expect(g.start.id, 'a2');
  });

  test('all seen: a tap starts from the top', () {
    final g = MomentGroup.of([
      _m('a2', 'ada', 10, seen: true),
      _m('a1', 'ada', 8, seen: true),
    ]).single;
    expect(g.unseen, isFalse);
    expect(g.start.id, 'a1');
  });

  test("a words-only item is skipped as a start when there are pictures", () {
    final g = MomentGroup.of([
      _m('a2', 'ada', 10),
      _m('a1', 'ada', 8, picture: false),
    ]).single;
    expect(g.start.id, 'a2');
  });

  test('flatten plays person by person in rail order', () {
    final groups = MomentGroup.of([
      _m('b2', 'bo', 12),
      _m('a1', 'ada', 11),
      _m('b1', 'bo', 9),
    ]);
    expect(MomentGroup.flatten(groups).map((m) => m.id), ['b1', 'b2', 'a1']);
  });
}
