@TestOn('vm')
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// What this pins: "show in chat" travels back across TWO pops, and the screen
/// waiting for it can be dead by the time it lands.
///
/// The browser pops a `ChatMessage`, `RoomInfoScreen` forwards it untouched,
/// and `_openRoomInfo` in `room_screen.dart` does the travelling — because only
/// that screen owns the back-trail, the folded-thread fallback and the
/// `listAround` window fetch. Nothing on a route stacked above it can reach any
/// of that.
///
/// The sharp edge is that `RoomInfoScreen` already pops TWICE on leave and on
/// delete (`pop()` then `maybePop()`), which takes `RoomScreen` down with it.
/// On those paths the awaited future completes into a disposed `State`, so
/// `_openRoomInfo` must re-check `mounted` before touching `setState` —
/// `_travelTo` calls it. Both of those paths pop null, so the null guard is
/// what protects correctness and the `mounted` guard is what protects the
/// frame; losing either is a crash or a jump the user never asked for.
///
/// A source scan because reproducing it needs a real three-deep navigator with
/// a live repository, a Convex client and a scroll controller — see
/// `web_safe_apis_test.dart` for the same trade.
void main() {
  late String roomScreen;
  late String roomInfo;
  late String browser;

  setUpAll(() {
    roomScreen = File('lib/screens/room_screen.dart').readAsStringSync();
    roomInfo = File('lib/screens/room_info_screen.dart').readAsStringSync();
    browser = File('lib/screens/room_content_screen.dart').readAsStringSync();
  });

  String bodyOf(String source, String signature) {
    final start = source.indexOf(signature);
    expect(start, isNonNegative, reason: '$signature was renamed or removed');
    final end = source.indexOf('\n  }\n', start);
    expect(end, isNonNegative, reason: 'could not bound $signature');
    return source.substring(start, end);
  }

  test('_openRoomInfo awaits a ChatMessage rather than discarding the pop', () {
    final body = bodyOf(roomScreen, 'Future<void> _openRoomInfo(ChatRoom room)');
    expect(body.contains('push<ChatMessage>'), isTrue,
        reason: 'an untyped push discards the message the browser popped, and '
            '"show in chat" silently does nothing');
    expect(body.contains('_travelTo('), isTrue);
  });

  test('it re-checks mounted after the await, before travelling', () {
    final body = bodyOf(roomScreen, 'Future<void> _openRoomInfo(ChatRoom room)');
    final awaitAt = body.indexOf('await Navigator');
    final guardAt = body.indexOf('if (!mounted');
    final travelAt = body.indexOf('_travelTo(');

    expect(awaitAt, isNonNegative);
    expect(guardAt, greaterThan(awaitAt),
        reason: 'RoomInfoScreen pops twice on leave/delete, which disposes this '
            'State before the future completes');
    expect(guardAt, lessThan(travelAt),
        reason: '_travelTo calls setState — the guard has to come first');
  });

  test('a null result is a no-op, which is what leave and delete pop', () {
    final body = bodyOf(roomScreen, 'Future<void> _openRoomInfo(ChatRoom room)');
    expect(body.contains('jump == null'), isTrue,
        reason: 'RoomInfoScreen._leave and ._delete both pop null; travelling '
            'on that would jump a room the user just walked out of');
  });

  test('it pushes the back-trail entry captured BEFORE the travel', () {
    final body = bodyOf(roomScreen, 'Future<void> _openRoomInfo(ChatRoom room)');
    final originAt = body.indexOf('_topmostVisibleMessage');
    final travelAt = body.indexOf('_travelTo(');
    final pushAt = body.indexOf('_jumpBack.push');

    expect(originAt, isNonNegative);
    expect(originAt, lessThan(travelAt),
        reason: 'after the travel the transcript has moved, so this would '
            'record the destination as the origin — the same ordering '
            '_jumpToPin documents');
    expect(pushAt, greaterThan(travelAt));
    expect(body.contains('landed'), isTrue,
        reason: 'a trip that ended in the thread overlay must not leave a pill '
            'pointing into a transcript nobody is looking at');
  });

  test('RoomInfoScreen passes the message through without acting on it', () {
    final body = bodyOf(roomInfo, 'Future<void> _openContent(RoomContentTab tab)');
    expect(body.contains('push<ChatMessage>'), isTrue);
    expect(body.contains('Navigator.of(context).pop(jump)'), isTrue,
        reason: 'room info is a pass-through — it owns no travel machinery');
    expect(body.contains('if (!mounted || jump == null) return;'), isTrue);
  });

  test('the browser pops the whole message, not just an id', () {
    final body = bodyOf(browser, 'void _showInChat(ChatMessage m)');
    expect(body.contains('pop(m)'), isTrue,
        reason: '_travelTo needs `from.threadKey` for the folded-thread '
            'fallback, and a message old enough to be browsed for will not be '
            'in repo.findMessageInRoom to look up from an id');
  });

  test('the pager closes itself before handing the message up', () {
    // The pager is on the ROOT navigator, so popping the browser underneath it
    // would leave it floating over the transcript it just travelled to.
    expect(
      browser.contains('Navigator.of(context, rootNavigator: true).pop()'),
      isTrue,
      reason: 'onShowInChat from the fullscreen pager must dismiss the pager '
          'first — it was pushed with rootNavigator: true',
    );
  });
}
