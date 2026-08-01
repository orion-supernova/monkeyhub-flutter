import 'package:flutter_test/flutter_test.dart';
import 'package:monkeyhub/models/chat_message.dart';
import 'package:monkeyhub/models/enums.dart';
import 'package:monkeyhub/screens/room_items.dart';

/// Fixtures. `t` is minutes from an arbitrary epoch, so ordering and the
/// 5-minute grouping window are both easy to express.
final _epoch = DateTime(2026, 3, 1, 12, 0);

ChatMessage msg(
  String id, {
  required int t,
  String sender = 'alice',
  String? replyTo,
  String? root,
  MessageStatus status = MessageStatus.sent,
  MessageType type = MessageType.text,
}) =>
    ChatMessage(
      id: id,
      roomId: 'room',
      senderId: sender,
      senderName: sender,
      content: id,
      createdAt: _epoch.add(Duration(minutes: t)),
      type: type,
      status: status,
      replyToId: replyTo,
      replyToPreview: replyTo == null
          ? null
          : const ReplyPreview(
              senderId: 'alice',
              senderName: 'alice',
              contentPreview: 'parent',
              type: MessageType.text,
            ),
      rootId: root,
    );

({List<RoomItem> items, Set<String> hidden}) build(
  List<ChatMessage> messages, {
  bool ephemeral = false,
  bool Function(ChatMessage)? isPinned,
  int minFolded = kMinFoldedMessages,
  int maxRailLanes = kMaxRailLanes,
}) =>
    buildRoomItems(
      messages: messages,
      roomIsEphemeral: ephemeral,
      isPinned: isPinned ?? (_) => false,
      dayLabel: (d) => '${d.year}-${d.month}-${d.day}',
      minFolded: minFolded,
      maxRailLanes: maxRailLanes,
    );

List<String> visibleIds(List<RoomItem> items) => items
    .whereType<MessageItem>()
    .map((i) => i.message.id)
    .toList(growable: false);

MessageItem itemFor(List<RoomItem> items, String id) =>
    items.whereType<MessageItem>().firstWhere((i) => i.message.id == id);

/// The segment for the thread this row actually belongs to, ignoring rails
/// that merely pass it on their way down.
RailSegment? ownRail(List<RoomItem> items, String id) =>
    itemFor(items, id).memberRail;

bool crossedBy(List<RoomItem> items, String id) =>
    itemFor(items, id).rails.any((r) => r.kind == RailKind.across);

/// A 6-member thread (root m1 + replies) interleaved with unrelated messages.
/// Members: m1, m2, m4, m6, m8, m10. Unrelated: u3, u5, u7, u9.
List<ChatMessage> interleavedThread() => [
      msg('m1', t: 0),
      msg('m2', t: 1, sender: 'bob', replyTo: 'm1', root: 'm1'),
      msg('u3', t: 2, sender: 'carol'),
      msg('m4', t: 3, replyTo: 'm2', root: 'm1'),
      msg('u5', t: 4, sender: 'dave'),
      msg('m6', t: 5, sender: 'bob', replyTo: 'm4', root: 'm1'),
      msg('u7', t: 6, sender: 'carol'),
      msg('m8', t: 7, replyTo: 'm6', root: 'm1'),
      msg('u9', t: 8, sender: 'dave'),
      msg('m10', t: 9, sender: 'bob', replyTo: 'm8', root: 'm1'),
    ];

void main() {
  group('folding', () {
    test('folds the interior of an interleaved thread, keeps root and newest',
        () {
      final r = build(interleavedThread());

      // Interior is m2, m4, m6, m8 — all four fold.
      expect(r.hidden, {'m2', 'm4', 'm6', 'm8'});
      expect(visibleIds(r.items), ['m1', 'u3', 'u5', 'u7', 'u9', 'm10']);

      final folds = r.items.whereType<ThreadFoldItem>().toList();
      expect(folds, hasLength(1));
      expect(folds.single.count, 4);
      expect(folds.single.threadKey, 'm1');
      // Anchors the overlay on the folded content, not the top of the thread.
      expect(folds.single.oldestHiddenId, 'm2');
      // Distinct senders, oldest first: m2=bob, m4=alice, m6=bob, m8=alice.
      expect(folds.single.senderIds, ['bob', 'alice']);
    });

    test('the chip sits where the folded content belongs, not at the tail', () {
      final r = build(interleavedThread());
      final foldRow = r.items.indexWhere((i) => i is ThreadFoldItem);
      final m1Row = r.items.indexOf(itemFor(r.items, 'm1'));
      final u3Row = r.items.indexOf(itemFor(r.items, 'u3'));
      expect(foldRow, greaterThan(m1Row));
      expect(foldRow, lessThan(u3Row));
    });

    test('is invariant to adjacency — the core constraint', () {
      // Same thread, but with every unrelated message removed. The fold
      // decision must be identical: nothing may key off adjacency.
      final interleaved = build(interleavedThread());
      final contiguous = build(
        interleavedThread().where((m) => !m.id.startsWith('u')).toList(),
      );
      expect(contiguous.hidden, interleaved.hidden);
      expect(
        contiguous.items.whereType<ThreadFoldItem>().single.count,
        interleaved.items.whereType<ThreadFoldItem>().single.count,
      );
    });

    test('threshold: folds only once enough messages are hidden', () {
      // A thread of n members has n-2 interior. With minFolded=2 that means
      // folding starts at n=4.
      for (final n in [1, 2, 3, 4, 5]) {
        final ms = <ChatMessage>[msg('m0', t: 0)];
        for (var i = 1; i < n; i++) {
          ms.add(msg('m$i', t: i, replyTo: 'm${i - 1}', root: 'm0'));
        }
        final r = build(ms);
        if (n < 4) {
          expect(r.hidden, isEmpty, reason: 'n=$n should not fold');
        } else {
          expect(r.hidden, hasLength(n - 2), reason: 'n=$n');
        }
      }
    });

    test('never folds in an ephemeral room', () {
      final r = build(interleavedThread(), ephemeral: true);
      expect(r.hidden, isEmpty);
      expect(r.items.whereType<ThreadFoldItem>(), isEmpty);
      // Rails still apply — they hide nothing.
      expect(crossedBy(r.items, 'u5'), isTrue);
    });

    test('a pinned interior member is never folded', () {
      final r = build(
        interleavedThread(),
        isPinned: (m) => m.id == 'm4',
      );
      expect(r.hidden, isNot(contains('m4')));
      expect(visibleIds(r.items), contains('m4'));
    });

    test('pinning splits the interior; only the longer contiguous run folds',
        () {
      // Interior m2,m4,m6,m8 with m4 pinned → runs [m2] and [m6,m8].
      // [m2] is below threshold, so only m6+m8 fold.
      final r = build(interleavedThread(), isPinned: (m) => m.id == 'm4');
      expect(r.hidden, {'m6', 'm8'});
      expect(r.items.whereType<ThreadFoldItem>().single.oldestHiddenId, 'm6');
    });

    test('pinning enough of the interior suppresses the fold entirely', () {
      final r = build(
        interleavedThread(),
        isPinned: (m) => m.id == 'm4' || m.id == 'm8',
      );
      // Runs are [m2] and [m6], both below threshold.
      expect(r.hidden, isEmpty);
      expect(r.items.whereType<ThreadFoldItem>(), isEmpty);
    });

    test('a thread whose root was deleted keeps its oldest survivor', () {
      // No message has id == 'gone', so the bucket has no root.
      final ms = [
        msg('r1', t: 0, replyTo: 'gone', root: 'gone'),
        msg('r2', t: 1, replyTo: 'r1', root: 'gone'),
        msg('r3', t: 2, replyTo: 'r2', root: 'gone'),
        msg('r4', t: 3, replyTo: 'r3', root: 'gone'),
      ];
      final r = build(ms);
      expect(visibleIds(r.items), contains('r1')); // oldest survivor stays
      expect(visibleIds(r.items), contains('r4')); // newest stays
      expect(r.hidden, {'r2', 'r3'});
    });
  });

  group('safety guards', () {
    test('pending and failed messages are never folded', () {
      final ms = [
        msg('m1', t: 0),
        msg('tmp_x', t: 1, replyTo: 'm1', root: 'm1',
            status: MessageStatus.pending),
        msg('m3', t: 2, replyTo: 'm1', root: 'm1', status: MessageStatus.error),
        msg('m4', t: 3, replyTo: 'm1', root: 'm1'),
        msg('m5', t: 4, replyTo: 'm1', root: 'm1'),
      ];
      // Mirrors room_screen's real _isPinned predicate.
      final r = build(
        ms,
        isPinned: (m) =>
            m.id.startsWith('tmp_') || m.status != MessageStatus.sent,
      );
      expect(r.hidden, isNot(contains('tmp_x')));
      expect(r.hidden, isNot(contains('m3')));
    });

    test('an optimistic reply with no rootId is its own thread, never folded',
        () {
      // Pre-echo, chat_repository leaves rootId null, so threadKey == own id.
      final ms = [
        ...interleavedThread(),
        msg('tmp_new', t: 20, sender: 'bob'),
      ];
      final r = build(ms);
      expect(r.hidden, isNot(contains('tmp_new')));
      expect(visibleIds(r.items), contains('tmp_new'));
    });
  });

  group('grouping and markers interact correctly with folds', () {
    test('the row after a fold shows the full card and does not group', () {
      // Use the contiguous variant so the fold lands immediately before the
      // tail; in the interleaved one m10 follows an unrelated message.
      final contiguous = build(
        interleavedThread().where((m) => !m.id.startsWith('u')).toList(),
      );
      final tail = itemFor(contiguous.items, 'm10');
      expect(tail.replyMarker, ReplyMarker.full,
          reason: 'its parent was folded away, so context must be restored');
      expect(tail.grouped, isFalse, reason: 'a fold is a new visual beat');
    });

    test('a fold breaks a same-sender run rather than grouping across it', () {
      // Same sender either side of the fold, one minute apart — without the
      // chip barrier these would group and erase any sign of the fold.
      final ms = [
        msg('a0', t: 0, sender: 'alice'),
        msg('a1', t: 1, sender: 'alice', replyTo: 'a0', root: 'a0'),
        msg('a2', t: 2, sender: 'alice', replyTo: 'a0', root: 'a0'),
        msg('a3', t: 3, sender: 'alice', replyTo: 'a0', root: 'a0'),
      ];
      final r = build(ms);
      expect(r.hidden, {'a1', 'a2'});
      expect(itemFor(r.items, 'a3').grouped, isFalse,
          reason: 'grouping here would erase the evidence of the fold');
      expect(itemFor(r.items, 'a3').replyMarker, ReplyMarker.full,
          reason: 'its parent is folded away, so context must be restored');
    });

    test('a reply to the row directly above is marked, but compactly', () {
      // The reported bug in both directions: swipe-to-reply targets the
      // newest message, so this is the commonest shape there is. Drawing
      // nothing made replying look like it had done nothing; drawing the full
      // card put a second copy of the bubble above on screen.
      final ms = [
        msg('p', t: 0),
        msg('c', t: 1, sender: 'bob', replyTo: 'p', root: 'p'),
      ];
      final r = build(ms);
      expect(itemFor(r.items, 'c').replyMarker, ReplyMarker.compact);
    });

    test('a compact marker still groups with the run it continues', () {
      // Same sender inside the 5-minute window. One accent line fits the
      // tight within-run gap; a quote card would not.
      final ms = [
        msg('p', t: 0, sender: 'alice'),
        msg('c', t: 1, sender: 'alice', replyTo: 'p', root: 'p'),
      ];
      final r = build(ms);
      expect(itemFor(r.items, 'c').replyMarker, ReplyMarker.compact);
      expect(itemFor(r.items, 'c').grouped, isTrue);
    });

    test('a reply to an older message gets the full card and breaks the run',
        () {
      // An unrelated message sits between parent and reply, so the parent is
      // no longer the row above and the quote earns its space.
      final ms = [
        msg('p', t: 0, sender: 'alice'),
        msg('u', t: 1, sender: 'alice'),
        msg('c', t: 2, sender: 'alice', replyTo: 'p', root: 'p'),
      ];
      final r = build(ms);
      expect(itemFor(r.items, 'c').replyMarker, ReplyMarker.full);
      expect(itemFor(r.items, 'c').grouped, isFalse,
          reason: 'the card needs a beat of its own');
    });

    test('a plain message carries no marker', () {
      final r = build([msg('x1', t: 0), msg('x2', t: 1, sender: 'bob')]);
      expect(itemFor(r.items, 'x2').replyMarker, ReplyMarker.none);
    });

    test('normal grouping still works with no threads involved', () {
      final ms = [
        msg('x1', t: 0, sender: 'alice'),
        msg('x2', t: 1, sender: 'alice'),
        msg('x3', t: 2, sender: 'bob'),
      ];
      final r = build(ms);
      expect(itemFor(r.items, 'x2').grouped, isTrue);
      expect(itemFor(r.items, 'x3').grouped, isFalse);
    });
  });

  group('lastInRun brackets a run', () {
    test('only the newest row of a run closes it', () {
      final ms = [
        msg('a', t: 0, sender: 'alice'),
        msg('b', t: 1, sender: 'alice'),
        msg('c', t: 2, sender: 'alice'),
      ];
      final r = build(ms);
      expect(itemFor(r.items, 'a').lastInRun, isFalse);
      expect(itemFor(r.items, 'b').lastInRun, isFalse);
      expect(itemFor(r.items, 'c').lastInRun, isTrue,
          reason: 'the avatar belongs on the row that ends the block');
    });

    test('a standalone message both opens and closes its run', () {
      final r = build([msg('solo', t: 0, sender: 'alice')]);
      final solo = itemFor(r.items, 'solo');
      expect(solo.grouped, isFalse);
      expect(solo.lastInRun, isTrue,
          reason: 'lastInRun && !grouped is what keeps the avatar top-aligned');
    });

    test('a different sender ends the run above it', () {
      final ms = [
        msg('a', t: 0, sender: 'alice'),
        msg('b', t: 1, sender: 'alice'),
        msg('c', t: 2, sender: 'bob'),
      ];
      final r = build(ms);
      expect(itemFor(r.items, 'b').lastInRun, isTrue);
      expect(itemFor(r.items, 'c').lastInRun, isTrue);
    });

    test('a day boundary ends the run, even for the same sender', () {
      final ms = [
        msg('a', t: 0, sender: 'alice'),
        // Next calendar day, so a divider lands between them.
        msg('b', t: 60 * 20, sender: 'alice'),
      ];
      final r = build(ms);
      expect(itemFor(r.items, 'b').grouped, isFalse);
      expect(itemFor(r.items, 'a').lastInRun, isTrue);
    });

    test('a fold chip ends the run above it', () {
      final ms = [
        msg('a0', t: 0, sender: 'alice'),
        msg('a1', t: 1, sender: 'alice', replyTo: 'a0', root: 'a0'),
        msg('a2', t: 2, sender: 'alice', replyTo: 'a0', root: 'a0'),
        msg('a3', t: 3, sender: 'alice', replyTo: 'a0', root: 'a0'),
      ];
      final r = build(ms);
      expect(r.hidden, {'a1', 'a2'});
      expect(itemFor(r.items, 'a0').lastInRun, isTrue,
          reason: 'the chip below it is a new beat, so a0 closes its own run');
      expect(itemFor(r.items, 'a3').lastInRun, isTrue);
    });

    test('rails do not drop the flag when they rebuild a row', () {
      // Two visible members with a gap earns a rail, and _withRails replaces
      // every row it touches — lastInRun has to survive that copy.
      final ms = [
        msg('r0', t: 0, sender: 'alice'),
        msg('u1', t: 1, sender: 'bob'),
        msg('r1', t: 2, sender: 'alice', replyTo: 'r0', root: 'r0'),
        msg('r2', t: 3, sender: 'alice', root: 'r0'),
      ];
      final r = build(ms);
      expect(itemFor(r.items, 'r1').rails, isNotEmpty);
      expect(itemFor(r.items, 'r1').lastInRun, isFalse);
      expect(itemFor(r.items, 'r2').lastInRun, isTrue);
    });
  });

  group('date dividers', () {
    test('a fully folded day still gets a divider for its chip', () {
      // Thread spans two days; the entire second day is interior and folds.
      final day2 = 60 * 24;
      final ms = [
        msg('d1', t: 0),
        msg('d2', t: day2, replyTo: 'd1', root: 'd1'),
        msg('d3', t: day2 + 1, replyTo: 'd1', root: 'd1'),
        msg('d4', t: day2 * 2, replyTo: 'd1', root: 'd1'),
      ];
      final r = build(ms);
      expect(r.hidden, {'d2', 'd3'});
      final labels =
          r.items.whereType<DateDividerItem>().map((d) => d.label).toList();
      // Three: the chip standing in for day 2 is still content on day 2.
      expect(labels, hasLength(3));
      // And it lands under its own day's divider, not the previous one.
      final foldRow = r.items.indexWhere((i) => i is ThreadFoldItem);
      expect(r.items[foldRow - 1], isA<DateDividerItem>());
    });

    test('one divider per visible day', () {
      final ms = [
        msg('a', t: 0),
        msg('b', t: 1),
        msg('c', t: 60 * 24),
      ];
      final r = build(ms);
      expect(r.items.whereType<DateDividerItem>(), hasLength(2));
    });
  });

  group('rails', () {
    test('spans a thread across the unrelated rows between its members', () {
      final r = build(interleavedThread());
      // Visible members after folding: m1 (start) and m10 (end).
      expect(ownRail(r.items, 'm1')?.kind, RailKind.capTop);
      expect(ownRail(r.items, 'm10')?.kind, RailKind.capBottom);
      // Unrelated rows inside the span are crossed, not claimed.
      for (final id in ['u3', 'u5', 'u7', 'u9']) {
        expect(ownRail(r.items, id), isNull, reason: id);
        expect(crossedBy(r.items, id), isTrue, reason: id);
      }
      // The fold chip is thread content, so it draws solid.
      expect(
        r.items.whereType<ThreadFoldItem>().single.memberRail?.kind,
        RailKind.through,
      );
    });

    test('no rail when a thread has no gap between its members', () {
      final ms = [
        msg('a', t: 0),
        msg('b', t: 1, sender: 'bob', replyTo: 'a', root: 'a'),
      ];
      final r = build(ms);
      expect(itemFor(r.items, 'a').rails, isEmpty);
      expect(itemFor(r.items, 'b').rails, isEmpty);
    });

    test('a date divider between two members does not earn them a rail', () {
      // Adjacent parent and reply that straddle midnight. The divider takes a
      // row of its own, so measuring the span in raw indices used to put them
      // two apart and draw a connector between two rows already touching.
      final ms = [
        msg('a', t: 0),
        msg('b', t: 60 * 20, sender: 'bob', replyTo: 'a', root: 'a'),
      ];
      final r = build(ms);
      expect(r.items.whereType<DateDividerItem>(), hasLength(2),
          reason: 'the fixture must actually cross a day boundary');
      expect(itemFor(r.items, 'a').rails, isEmpty);
      expect(itemFor(r.items, 'b').rails, isEmpty);
    });

    test('a divider does not rob a genuinely gapped thread of its rail', () {
      // One unrelated message between the members, plus a day boundary. The
      // gap is real, so the rail must survive the new measurement.
      final ms = [
        msg('a', t: 0),
        msg('u', t: 60 * 20, sender: 'carol'),
        msg('b', t: 60 * 20 + 1, sender: 'bob', replyTo: 'a', root: 'a'),
      ];
      final r = build(ms);
      expect(ownRail(r.items, 'a')?.kind, RailKind.capTop);
      expect(crossedBy(r.items, 'u'), isTrue);
      expect(ownRail(r.items, 'b')?.kind, RailKind.capBottom);
    });

    test('no rail for a single-message thread', () {
      final r = build([msg('solo', t: 0)]);
      expect(itemFor(r.items, 'solo').rails, isEmpty);
    });

    test('rails draw for short threads that never fold', () {
      // 3 members: below the fold threshold, but still worth connecting.
      final ms = [
        msg('s1', t: 0),
        msg('u2', t: 1, sender: 'carol'),
        msg('s3', t: 2, sender: 'bob', replyTo: 's1', root: 's1'),
      ];
      final r = build(ms);
      expect(r.hidden, isEmpty);
      expect(ownRail(r.items, 's1')?.kind, RailKind.capTop);
      expect(crossedBy(r.items, 'u2'), isTrue);
      expect(ownRail(r.items, 's3')?.kind, RailKind.capBottom);
    });

    test('overlapping threads get separate lanes', () {
      final ms = [
        msg('A1', t: 0),
        msg('B1', t: 1, sender: 'bob'),
        msg('u', t: 2, sender: 'carol'),
        msg('A2', t: 3, replyTo: 'A1', root: 'A1'),
        msg('B2', t: 4, sender: 'bob', replyTo: 'B1', root: 'B1'),
      ];
      final r = build(ms);
      final laneA = ownRail(r.items, 'A1')?.lane;
      final laneB = ownRail(r.items, 'B1')?.lane;
      expect(laneA, isNotNull);
      expect(laneB, isNotNull);
      // B1 is also crossed by A's rail — that's exactly why a row needs a
      // list of segments rather than one.
      expect(crossedBy(r.items, 'B1'), isTrue);
      expect(laneA, isNot(equals(laneB)));
    });

    test('threads beyond the lane cap go without a rail', () {
      final ms = [
        msg('A1', t: 0),
        msg('B1', t: 1, sender: 'bob'),
        msg('C1', t: 2, sender: 'carol'),
        msg('u', t: 3, sender: 'dave'),
        msg('A2', t: 4, replyTo: 'A1', root: 'A1'),
        msg('B2', t: 5, sender: 'bob', replyTo: 'B1', root: 'B1'),
        msg('C2', t: 6, sender: 'carol', replyTo: 'C1', root: 'C1'),
      ];
      final r = build(ms, maxRailLanes: 2);
      final lanes = <int>{};
      for (final id in ['A1', 'B1', 'C1']) {
        final rail = ownRail(r.items, id);
        if (rail != null) lanes.add(rail.lane);
      }
      expect(lanes.length, lessThanOrEqualTo(2));
      // The third thread is dropped rather than crowding the gutter.
      expect(ownRail(r.items, 'C1'), isNull);
    });

    test('a lane is reused once its previous thread has ended', () {
      final ms = [
        msg('A1', t: 0),
        msg('u1', t: 1, sender: 'carol'),
        msg('A2', t: 2, sender: 'bob', replyTo: 'A1', root: 'A1'),
        msg('B1', t: 3, sender: 'dave'),
        msg('u2', t: 4, sender: 'carol'),
        msg('B2', t: 5, sender: 'eve', replyTo: 'B1', root: 'B1'),
      ];
      final r = build(ms);
      // Non-overlapping spans, so both sit in lane 0.
      expect(ownRail(r.items, 'A1')?.lane, 0);
      expect(ownRail(r.items, 'B1')?.lane, 0);
    });
  });

  test('an empty room still yields the intro row', () {
    final r = build([]);
    expect(r.items, hasLength(1));
    expect(r.items.single, isA<IntroItem>());
    expect(r.hidden, isEmpty);
  });
}
