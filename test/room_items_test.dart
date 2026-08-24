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
}) => ChatMessage(
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
  bool Function(ChatMessage)? mustKeepOwnRow,
  int minFolded = kMinFoldedMessages,
  DateTime? unreadAfter,
}) => buildRoomItems(
  messages: messages,
  roomIsEphemeral: ephemeral,
  mustKeepOwnRow: mustKeepOwnRow ?? (_) => false,
  dayLabel: (d) => '${d.year}-${d.month}-${d.day}',
  minFolded: minFolded,
  unreadAfter: unreadAfter,
);

List<String> visibleIds(List<RoomItem> items) => items
    .whereType<MessageItem>()
    .map((i) => i.message.id)
    .toList(growable: false);

MessageItem itemFor(List<RoomItem> items, String id) =>
    items.whereType<MessageItem>().firstWhere((i) => i.message.id == id);

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
    test(
      'folds the interior of an interleaved thread, keeps root and newest',
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
      },
    );

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
      // Every member keeps its own row, so the thread is still all there.
      expect(visibleIds(r.items), hasLength(10));
    });

    test('an interior member that must keep its own row is never folded', () {
      final r = build(interleavedThread(), mustKeepOwnRow: (m) => m.id == 'm4');
      expect(r.hidden, isNot(contains('m4')));
      expect(visibleIds(r.items), contains('m4'));
    });

    test(
      'a held row splits the interior; only the longer contiguous run folds',
      () {
        // Interior m2,m4,m6,m8 with m4 held → runs [m2] and [m6,m8].
        // [m2] is below threshold, so only m6+m8 fold.
        final r = build(
          interleavedThread(),
          mustKeepOwnRow: (m) => m.id == 'm4',
        );
        expect(r.hidden, {'m6', 'm8'});
        expect(r.items.whereType<ThreadFoldItem>().single.oldestHiddenId, 'm6');
      },
    );

    test('holding enough of the interior suppresses the fold entirely', () {
      final r = build(
        interleavedThread(),
        mustKeepOwnRow: (m) => m.id == 'm4' || m.id == 'm8',
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
        msg(
          'tmp_x',
          t: 1,
          replyTo: 'm1',
          root: 'm1',
          status: MessageStatus.pending,
        ),
        msg('m3', t: 2, replyTo: 'm1', root: 'm1', status: MessageStatus.error),
        msg('m4', t: 3, replyTo: 'm1', root: 'm1'),
        msg('m5', t: 4, replyTo: 'm1', root: 'm1'),
      ];
      // Mirrors room_screen's real _mustKeepOwnRow predicate.
      final r = build(
        ms,
        mustKeepOwnRow: (m) =>
            m.id.startsWith('tmp_') || m.status != MessageStatus.sent,
      );
      expect(r.hidden, isNot(contains('tmp_x')));
      expect(r.hidden, isNot(contains('m3')));
    });

    test(
      'an optimistic reply with no rootId is its own thread, never folded',
      () {
        // Pre-echo, chat_repository leaves rootId null, so threadKey == own id.
        final ms = [
          ...interleavedThread(),
          msg('tmp_new', t: 20, sender: 'bob'),
        ];
        final r = build(ms);
        expect(r.hidden, isNot(contains('tmp_new')));
        expect(visibleIds(r.items), contains('tmp_new'));
      },
    );
  });

  group('grouping and markers interact correctly with folds', () {
    test('the row after a fold shows the full card and does not group', () {
      // Use the contiguous variant so the fold lands immediately before the
      // tail; in the interleaved one m10 follows an unrelated message.
      final contiguous = build(
        interleavedThread().where((m) => !m.id.startsWith('u')).toList(),
      );
      final tail = itemFor(contiguous.items, 'm10');
      expect(
        tail.replyMarker,
        ReplyMarker.full,
        reason: 'its parent was folded away, so context must be restored',
      );
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
      expect(
        itemFor(r.items, 'a3').grouped,
        isFalse,
        reason: 'grouping here would erase the evidence of the fold',
      );
      expect(
        itemFor(r.items, 'a3').replyMarker,
        ReplyMarker.full,
        reason: 'its parent is folded away, so context must be restored',
      );
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

    test(
      'a reply to an older message gets the full card and breaks the run',
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
        expect(
          itemFor(r.items, 'c').grouped,
          isFalse,
          reason: 'the card needs a beat of its own',
        );
      },
    );

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
      expect(
        itemFor(r.items, 'c').lastInRun,
        isTrue,
        reason: 'the avatar belongs on the row that ends the block',
      );
    });

    test('a standalone message both opens and closes its run', () {
      final r = build([msg('solo', t: 0, sender: 'alice')]);
      final solo = itemFor(r.items, 'solo');
      expect(solo.grouped, isFalse);
      expect(
        solo.lastInRun,
        isTrue,
        reason: 'lastInRun && !grouped is what keeps the avatar top-aligned',
      );
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
      expect(
        itemFor(r.items, 'a0').lastInRun,
        isTrue,
        reason: 'the chip below it is a new beat, so a0 closes its own run',
      );
      expect(itemFor(r.items, 'a3').lastInRun, isTrue);
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
      final labels = r.items
          .whereType<DateDividerItem>()
          .map((d) => d.label)
          .toList();
      // Three: the chip standing in for day 2 is still content on day 2.
      expect(labels, hasLength(3));
      // And it lands under its own day's divider, not the previous one.
      final foldRow = r.items.indexWhere((i) => i is ThreadFoldItem);
      expect(r.items[foldRow - 1], isA<DateDividerItem>());
    });

    test('one divider per visible day', () {
      final ms = [msg('a', t: 0), msg('b', t: 1), msg('c', t: 60 * 24)];
      final r = build(ms);
      expect(r.items.whereType<DateDividerItem>(), hasLength(2));
    });
  });

  group('unread divider', () {
    test('no cursor, no divider', () {
      final ms = [msg('a', t: 0), msg('b', t: 1)];
      final r = build(ms);
      expect(r.items.whereType<UnreadDividerItem>(), isEmpty);
    });

    test('lands immediately before the first message newer than the cursor', () {
      final ms = [msg('a', t: 0), msg('b', t: 1), msg('c', t: 2)];
      final r = build(ms, unreadAfter: _epoch.add(const Duration(minutes: 1)));
      final dividerRow = r.items.indexWhere((i) => i is UnreadDividerItem);
      final cRow = r.items.indexOf(itemFor(r.items, 'c'));
      expect(dividerRow, cRow - 1);
      // b is not after the cursor (equal, not newer) so it stays read.
      expect(
        r.items.indexOf(itemFor(r.items, 'b')),
        lessThan(dividerRow),
      );
    });

    test('a cursor exactly at a message\'s timestamp does not mark it unread', () {
      // "newer than lastReadAt" — matches ChatRoom.unreadCount's own rule.
      final ms = [msg('a', t: 0), msg('b', t: 1)];
      final r = build(ms, unreadAfter: _epoch.add(const Duration(minutes: 1)));
      expect(r.items.whereType<UnreadDividerItem>(), isEmpty);
    });

    test('a cursor before every message lands the divider ahead of everything', () {
      // Day 1's own DateDividerItem also lands on `a`, so the two are not
      // strictly adjacent — this only pins the ordering.
      final ms = [msg('a', t: 0), msg('b', t: 1)];
      final r = build(ms, unreadAfter: _epoch.subtract(const Duration(minutes: 1)));
      final dividerRow = r.items.indexWhere((i) => i is UnreadDividerItem);
      final aRow = r.items.indexOf(itemFor(r.items, 'a'));
      expect(dividerRow, isNot(-1));
      expect(dividerRow, lessThan(aRow));
    });

    test('a cursor after every message inserts nothing', () {
      final ms = [msg('a', t: 0), msg('b', t: 1)];
      final r = build(ms, unreadAfter: _epoch.add(const Duration(minutes: 10)));
      expect(r.items.whereType<UnreadDividerItem>(), isEmpty);
    });

    test('emitted once, even with several messages past the cursor', () {
      final ms = [msg('a', t: 0), msg('b', t: 1), msg('c', t: 2), msg('d', t: 3)];
      final r = build(ms, unreadAfter: _epoch);
      expect(r.items.whereType<UnreadDividerItem>(), hasLength(1));
    });

    test('precedes a thread fold chip anchored at the first unread message', () {
      // The chip for the interior run [m2,m4,m6,m8] is anchored at m2 (the
      // oldest of the run) — landing the cursor just before m2 puts the
      // crossing on the very message the chip stands in for, so the marker
      // must show up ahead of it rather than after.
      final ms = interleavedThread();
      final r = build(
        ms,
        unreadAfter: _epoch.add(const Duration(seconds: 30)),
      );
      final dividerRow = r.items.indexWhere((i) => i is UnreadDividerItem);
      final foldRow = r.items.indexWhere((i) => i is ThreadFoldItem);
      expect(dividerRow, isNot(-1));
      expect(foldRow, isNot(-1));
      expect(dividerRow, lessThan(foldRow));
    });

    test('precedes the date divider for the day it lands in', () {
      final ms = [msg('a', t: 0), msg('b', t: 60 * 24)]; // b is a day later
      final r = build(ms, unreadAfter: _epoch.add(const Duration(hours: 1)));
      final unreadRow = r.items.indexWhere((i) => i is UnreadDividerItem);
      final dateRows = [
        for (var i = 0; i < r.items.length; i++)
          if (r.items[i] is DateDividerItem) i,
      ];
      // Two: day 1's (ahead of `a`, unrelated to the cursor) and day 2's
      // (the one the unread marker must precede).
      expect(dateRows, hasLength(2));
      expect(unreadRow, lessThan(dateRows[1]));
    });
  });

  test('an empty room still yields the intro row', () {
    final r = build([]);
    expect(r.items, hasLength(1));
    expect(r.items.single, isA<IntroItem>());
    expect(r.hidden, isEmpty);
  });

  /// Both of these were private to a State and are now shared — `humanDay` with
  /// the shared-content browser, `formatClockDuration` with the two places that
  /// had already copied it. Extraction is only worth it if it stays correct.
  group('humanDay', () {
    DateTime dayOf(DateTime d) => DateTime(d.year, d.month, d.day);

    test('names today and yesterday', () {
      final now = DateTime.now();
      expect(humanDay(dayOf(now)), 'TODAY');
      expect(
        humanDay(dayOf(now.subtract(const Duration(days: 1)))),
        'YESTERDAY',
      );
    });

    test('drops the year while it is obvious and adds it once it is not', () {
      final now = DateTime.now();
      final thisYear = DateTime(now.year, 3, 14);
      // Skip if that date happens to be today/yesterday, which have their own
      // labels and would make this assertion about the wrong branch.
      if (thisYear != dayOf(now) &&
          thisYear != dayOf(now.subtract(const Duration(days: 1)))) {
        expect(humanDay(thisYear), 'MAR 14');
      }
      expect(
        humanDay(DateTime(now.year - 3, 3, 14)),
        'MAR ${14} · ${now.year - 3}',
      );
    });

    test('only matches a date-only value', () {
      // The today/yesterday tests are exact equality, so a value carrying a
      // time of day silently falls through to the dated form. Callers must
      // pass `DateTime(y, m, d)` — `buildRoomItems` already does.
      final now = DateTime.now();
      final withTime = DateTime(now.year, now.month, now.day, 9, 30);
      expect(humanDay(withTime), isNot('TODAY'));
    });
  });

  group('formatClockDuration', () {
    test('pads seconds, never minutes', () {
      expect(formatClockDuration(const Duration(seconds: 7)), '0:07');
      expect(
        formatClockDuration(const Duration(minutes: 3, seconds: 42)),
        '3:42',
      );
      expect(formatClockDuration(Duration.zero), '0:00');
    });

    test('runs past an hour rather than growing a third field', () {
      expect(
        formatClockDuration(const Duration(minutes: 62, seconds: 3)),
        '62:03',
      );
    });

    test('truncates sub-second remainders', () {
      expect(formatClockDuration(const Duration(milliseconds: 1900)), '0:01');
    });
  });
}
