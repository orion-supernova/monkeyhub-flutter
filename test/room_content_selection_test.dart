import 'package:flutter_test/flutter_test.dart';
import 'package:monkeyhub/data/room_content_selection.dart';
import 'package:monkeyhub/models/chat_message.dart';
import 'package:monkeyhub/models/enums.dart';

/// What this pins: the list under a selection is live, and shrinks.
///
/// An ephemeral message self-destructs on the server's schedule, a bulk delete
/// removes rows while the sheet confirming it is still up, and the browser's
/// live half is re-derived from the transcript subscription on every notify.
/// So a selection is a set of ids pointing at a list that is allowed to change
/// underneath it.
///
/// The failure that matters is quiet: the action bar says "FORWARD 4" while
/// only three of those messages still exist, the user taps it, and three
/// arrive. Every count the UI shows therefore has to come from [resolve]
/// against the current list, never from the raw id count.
///
/// Sibling: `room_content_cursor_test.dart`, which pins the list this is
/// selecting from.
void main() {
  ChatMessage msg(String id) => ChatMessage(
        id: id,
        roomId: 'r1',
        senderId: 'u1',
        senderName: 'ada',
        content: '',
        createdAt: DateTime.utc(2026, 1, 1, 12, int.parse(id.substring(1))),
        type: MessageType.image,
        mediaStorageId: 'stor_$id',
      );

  late RoomContentSelection sel;
  late int notifies;

  setUp(() {
    sel = RoomContentSelection();
    notifies = 0;
    sel.addListener(() => notifies++);
  });

  group('entering and leaving', () {
    test('starts inactive and empty', () {
      expect(sel.active, isFalse);
      expect(sel.count, 0);
      expect(sel.isEmpty, isTrue);
    });

    test('begin turns the mode on, with or without a first pick', () {
      sel.begin('m1');
      expect(sel.active, isTrue);
      expect(sel.contains('m1'), isTrue);
    });

    test('deselecting the last item stays in selection mode', () {
      // Dropping out of the mode here makes correcting a mis-tap feel like the
      // screen closed itself.
      sel.begin('m1');
      sel.toggle('m1');
      expect(sel.isEmpty, isTrue);
      expect(sel.active, isTrue);
    });

    test('clear is the only thing that leaves the mode', () {
      sel.begin('m1');
      sel.clear();
      expect(sel.active, isFalse);
      expect(sel.isEmpty, isTrue);
    });

    test('clearing an already-clear selection notifies nobody', () {
      final before = notifies;
      sel.clear();
      expect(notifies, before, reason: 'no state changed, so no rebuild');
    });
  });

  group('select all', () {
    test('takes everything on offer', () {
      sel.selectAll(['m1', 'm2', 'm3']);
      expect(sel.count, 3);
    });

    test('is a toggle — pressing it again clears', () {
      sel.selectAll(['m1', 'm2']);
      sel.selectAll(['m1', 'm2']);
      expect(sel.isEmpty, isTrue);
      expect(sel.active, isTrue, reason: 'still selecting, just nothing picked');
    });

    test('a grown list re-selects rather than clearing', () {
      sel.selectAll(['m1', 'm2']);
      sel.selectAll(['m1', 'm2', 'm3']);
      expect(sel.count, 3,
          reason: 'the list is not the same list, so this is not a re-press');
    });
  });

  group('the list shrinking underneath', () {
    test('resolve drops ids whose message is gone', () {
      sel.selectAll(['m1', 'm2', 'm3']);
      // m2 self-destructed while the action bar was open.
      final alive = [msg('m1'), msg('m3')];

      expect(sel.count, 3, reason: 'the raw set still holds the stale id');
      expect(sel.resolve(alive).map((m) => m.id), ['m1', 'm3'],
          reason: 'THIS is what the action bar must count and act on');
    });

    test('resolve follows the list order, not the selection order', () {
      sel.toggle('m3');
      sel.toggle('m1');
      final ordered = [msg('m1'), msg('m2'), msg('m3')];
      expect(sel.resolve(ordered).map((m) => m.id), ['m1', 'm3']);
    });

    test('prune reconciles the set so the two counts agree', () {
      sel.selectAll(['m1', 'm2', 'm3']);
      sel.prune([msg('m1'), msg('m3')]);
      expect(sel.count, 2);
      expect(sel.contains('m2'), isFalse);
    });

    test('prune only notifies when something actually went', () {
      sel.selectAll(['m1', 'm2']);
      final before = notifies;
      sel.prune([msg('m1'), msg('m2')]);
      expect(notifies, before,
          reason: 'prune runs after every list settle — a no-op must not '
              'rebuild the grid');
    });

    test('prune on an empty selection is free', () {
      final before = notifies;
      sel.prune([msg('m1')]);
      expect(notifies, before);
    });

    test('everything vanishing leaves a selection that acts on nothing', () {
      sel.selectAll(['m1', 'm2']);
      expect(sel.resolve(const []), isEmpty);
      sel.prune(const []);
      expect(sel.isEmpty, isTrue);
      expect(sel.active, isTrue,
          reason: 'the mode outlives the content; only clear() leaves it');
    });
  });

  test('ids is a copy — a caller cannot mutate past notifyListeners', () {
    sel.toggle('m1');
    expect(() => sel.ids.add('m2'), throwsUnsupportedError);
  });
}
