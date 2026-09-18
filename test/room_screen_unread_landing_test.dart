@TestOn('vm')
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// The screen half of the unread landing. The repository half — where the
/// cursor comes from and when it can be trusted — is exercised for real in
/// `room_unread_anchor_test.dart`; this pins the three things about
/// `RoomScreen` that a live room, repo and Convex client would be needed to
/// mount for.
///
/// What is being defended: the divider and the initial scroll are the same
/// decision, taken from a cursor the screen does not own. It must ask for that
/// cursor rather than snapshot it, must arm before `openRoom` (which marks the
/// room read), and must not conclude "nothing unread" from an answer that has
/// not arrived — that last one is what limited the whole feature to chat-list
/// taps, because a notification tap opens the room before its room list.
void main() {
  late String source;

  setUpAll(() {
    source = File('lib/screens/room_screen.dart').readAsStringSync();
  });

  test('the anchor is pinned before openRoom is called', () {
    final beginAt = source.indexOf('widget.repo.beginUnreadAnchor(widget.roomId);');
    final openRoomAt =
        source.indexOf('widget.repo.openRoom(widget.roomId, owner: this);');
    expect(beginAt, isNonNegative, reason: 'the anchor call was renamed or removed');
    expect(openRoomAt, isNonNegative, reason: 'the openRoom call site was renamed or moved');
    expect(
      beginAt,
      lessThan(openRoomAt),
      reason:
          'openRoom marks the room read; pinning the anchor any later risks '
          'capturing a cursor openRoom itself already advanced',
    );
  });

  test('the cursor is read through to the repo, never copied into a field', () {
    expect(
      source.contains('repo.unreadAnchorFor(widget.roomId)'),
      isTrue,
      reason:
          'a screen that mounts before the room list has to pick the answer up '
          'when it lands; a field assigned in initState never can',
    );
    expect(
      source.contains('DateTime? _unreadAnchorReadAt;'),
      isFalse,
      reason: 'the copied snapshot is what made this a chat-list-only feature',
    );
  });

  test('an unsettled cursor waits instead of landing at the bottom', () {
    final start = source.indexOf('void _settleUnreadDivider() {');
    expect(start, isNonNegative);
    final body = source.substring(start, source.indexOf('\n  }\n', start));
    final waitAt = body.indexOf('if (!repo.unreadAnchorSettled(widget.roomId)) return;');
    final readAt = body.indexOf('final anchor = repo.unreadAnchorFor(widget.roomId);');
    expect(waitAt, isNonNegative,
        reason: 'without this the room list losing the race disables the feature');
    expect(readAt, isNonNegative);
    expect(
      waitAt,
      lessThan(readAt),
      reason:
          '"not yet" and "nothing to land on" both read as a null cursor; the '
          'settled check is the only thing that tells them apart, so it has to '
          'come first',
    );
    expect(
      body.contains('repo.hasLiveMessages(widget.roomId)'),
      isTrue,
      reason:
          'a cache hydrate can predate everything this is looking for, so an '
          'empty search only settles once the subscription has spoken',
    );
  });

  test('the divider row is latched, never recomputed per pass', () {
    final start = source.indexOf('void _settleUnreadDivider() {');
    final body = source.substring(start, source.indexOf('\n  }\n', start));
    expect(
      body.startsWith('void _settleUnreadDivider() {\n'
          '    if (_unreadDividerSettled) return;'),
      isTrue,
      reason:
          'every message arriving after the room opens is newer than the '
          'cursor too — recomputing draws a fresh line above each of them, '
          'over messages the reader is watching arrive',
    );
  });

  test('the landing is bounded and aims at the divider\'s own row', () {
    final start = source.indexOf('void _maybeLandOnUnread() {');
    expect(start, isNonNegative);
    final body = source.substring(start, source.indexOf('\n  }\n', start));
    expect(
      body.contains('_unreadLandingDeadline'),
      isTrue,
      reason:
          'a wait with no bound is a viewport that can jump on its own long '
          'after the reader has settled somewhere else',
    );
    expect(
      body.contains('final id = _unreadDividerId;'),
      isTrue,
      reason:
          'the line and the viewport have to be the same message, not two '
          'answers that agree by construction',
    );
    expect(
      body.contains('_unreadDividerKey.currentContext'),
      isTrue,
      reason: 'the landing aims at the UNREAD line itself, not the row under it',
    );
    expect(
      body.contains('alignment: centredAlignment('),
      isTrue,
      reason:
          'the line lands in the middle of what the reader can see, clear of '
          'the floating header and composer, as far as the content allows',
    );
  });

  test('the item pass is keyed on the divider row it was built with', () {
    final start = source.indexOf('({List<RoomItem> items, Set<String> hidden}) _buildItems(');
    expect(start, isNonNegative);
    final body = source.substring(start, source.indexOf('\n  }\n', start));
    expect(
      body.contains('unreadBeforeId: _unreadDividerId'),
      isTrue,
      reason: 'the divider is drawn from the row the landing settled on',
    );
    expect(
      body.contains("|\${_unreadDividerId ?? ''}"),
      isTrue,
      reason:
          'the row fills in exactly once, mid-room, when the room list lands; '
          'a memo key without it serves the divider-less pass forever',
    );
    expect(
      body.indexOf('_settleUnreadDivider();'),
      isNonNegative,
      reason: 'the divider must not be a frame behind the scroll onto it',
    );
  });
}
