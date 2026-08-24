@TestOn('vm')
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// What this pins: the unread-landing anchor has to be read off
/// `widget.repo.roomById(widget.roomId)` BEFORE `openRoom` is called, not
/// after and not "whenever" — `openRoom` marks the room read, and once that
/// mutation's round trip echoes back through `rooms:listUserRooms`, the same
/// room's `lastReadAt` has moved out from under a cursor taken any later.
/// Read it after, on a fast connection, and the cursor could already equal
/// (or be newer than) every message in the room — silently disabling the
/// feature the first time it would ever fire.
///
/// A source scan, like `room_content_jump_test.dart`, because `_RoomScreenState`
/// needs a live room, repo and Convex client to mount for real.
void main() {
  late String source;

  setUpAll(() {
    source = File('lib/screens/room_screen.dart').readAsStringSync();
  });

  test('the unread anchor is captured before openRoom is called', () {
    final anchorAt = source.indexOf('_unreadAnchorReadAt = roomAtOpen.lastReadAt;');
    final openRoomAt =
        source.indexOf('widget.repo.openRoom(widget.roomId, owner: this);');
    expect(anchorAt, isNonNegative, reason: 'the anchor snapshot was renamed or removed');
    expect(openRoomAt, isNonNegative, reason: 'the openRoom call site was renamed or moved');
    expect(
      anchorAt,
      lessThan(openRoomAt),
      reason:
          'openRoom marks the room read; capturing the anchor any later '
          'risks reading a cursor openRoom itself already advanced',
    );
  });

  test('the anchor only arms when there is a real cursor and real backlog', () {
    final start = source.indexOf('final roomAtOpen = widget.repo.roomById(widget.roomId);');
    expect(start, isNonNegative);
    final end = source.indexOf('widget.repo.openRoom(widget.roomId, owner: this);', start);
    expect(end, isNonNegative);
    final block = source.substring(start, end);
    expect(
      block.contains('roomAtOpen.lastReadAt != null'),
      isTrue,
      reason: 'a room that has never been read has no cursor to land relative to',
    );
    expect(
      block.contains('roomAtOpen.unreadCount > 0'),
      isTrue,
      reason: 'a fully-read room has nowhere to land that is not the bottom',
    );
  });

  test('buildRoomItems is called with the captured anchor, not a live read', () {
    final start = source.indexOf('({List<RoomItem> items, Set<String> hidden}) _buildItems(');
    expect(start, isNonNegative);
    final end = source.indexOf('\n  }\n', start);
    expect(end, isNonNegative);
    final body = source.substring(start, end);
    expect(
      body.contains('unreadAfter: _unreadAnchorReadAt'),
      isTrue,
      reason:
          'the divider and the initial scroll target must agree on where '
          '"unread" starts, which only holds if both read the same snapshot',
    );
  });
}
