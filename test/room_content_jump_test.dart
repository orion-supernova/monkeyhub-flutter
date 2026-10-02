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

  /// [signature] is matched as a PREFIX and deliberately stops before the
  /// closing paren: what this test is about is the body of a named method, not
  /// its parameter list, and pinning the full list meant adding an unrelated
  /// optional flag to `_openRoomInfo` failed four assertions about pops and
  /// mounted checks that had not changed at all.
  String bodyOf(String source, String signature) {
    final start = source.indexOf(signature);
    expect(start, isNonNegative, reason: '$signature was renamed or removed');
    final end = source.indexOf('\n  }\n', start);
    expect(end, isNonNegative, reason: 'could not bound $signature');
    return source.substring(start, end);
  }

  /// [bodyOf] with comment lines removed.
  ///
  /// Prose explaining why a call is absent necessarily names that call, and a
  /// naïve `contains` then reads the explanation as the thing it forbids —
  /// which is exactly how this test first failed. Same carve-out
  /// `web_safe_apis_test.dart` makes: prose about the trap is the point of the
  /// trap, not a violation of it.
  String codeOf(String source, String signature) => bodyOf(source, signature)
      .split('\n')
      .where((l) {
        final t = l.trimLeft();
        return !t.startsWith('//') && !t.startsWith('*') && !t.startsWith('/*');
      })
      .join('\n');

  test('_openRoomInfo awaits a ChatMessage rather than discarding the pop', () {
    final body = bodyOf(
      roomScreen,
      'Future<void> _openRoomInfo(ChatRoom room',
    );
    expect(
      body.contains('push<ChatMessage>'),
      isTrue,
      reason:
          'an untyped push discards the message the browser popped, and '
          '"show in chat" silently does nothing',
    );
    expect(body.contains('_travelTo('), isTrue);
  });

  test('it re-checks mounted after the await, before travelling', () {
    final body = bodyOf(
      roomScreen,
      'Future<void> _openRoomInfo(ChatRoom room',
    );
    final awaitAt = body.indexOf('await Navigator');
    final guardAt = body.indexOf('if (!mounted');
    final travelAt = body.indexOf('_travelTo(');

    expect(awaitAt, isNonNegative);
    expect(
      guardAt,
      greaterThan(awaitAt),
      reason:
          'RoomInfoScreen pops twice on leave/delete, which disposes this '
          'State before the future completes',
    );
    expect(
      guardAt,
      lessThan(travelAt),
      reason: '_travelTo calls setState — the guard has to come first',
    );
  });

  test('a null result is a no-op, which is what leave and delete pop', () {
    final body = bodyOf(
      roomScreen,
      'Future<void> _openRoomInfo(ChatRoom room',
    );
    expect(
      body.contains('jump == null'),
      isTrue,
      reason:
          'RoomInfoScreen._leave and ._delete both pop null; travelling '
          'on that would jump a room the user just walked out of',
    );
  });

  test('it leaves NO back-trail entry, unlike the pin and reply jumps', () {
    final code = codeOf(
      roomScreen,
      'Future<void> _openRoomInfo(ChatRoom room',
    );
    expect(
      code.contains('_jumpBack.push'),
      isFalse,
      reason:
          'The pin banner and a reply tether jump from one place in the '
          'transcript to another, so "back" names the position you left. This '
          'arrives from two routes away — the reader was in the media library, '
          'not the transcript — so a back pill would offer to return them to '
          'wherever the transcript happened to be sitting before they opened '
          'room info. That is not somewhere they were.',
    );
  });

  test('the jumps that DO come from the transcript still leave one', () {
    // Guards the fix above from being over-applied: removing the trail
    // wholesale would break following a reply tether, which is what it is for.
    final pin = bodyOf(roomScreen, 'Future<void> _jumpToPin(RoomPin target)');
    expect(pin.contains('_jumpBack.push'), isTrue);
    expect(
      pin.indexOf('_topmostVisibleMessage'),
      lessThan(pin.indexOf('_travelTo(')),
      reason:
          'the origin is captured before the travel, or it records the '
          'destination as the origin',
    );
  });

  test('RoomInfoScreen passes the message through without acting on it', () {
    final body = bodyOf(
      roomInfo,
      'Future<void> _openContent(RoomContentTab tab)',
    );
    expect(body.contains('push<ChatMessage>'), isTrue);
    expect(
      body.contains('Navigator.of(context).pop(jump)'),
      isTrue,
      reason: 'room info is a pass-through — it owns no travel machinery',
    );
    expect(body.contains('if (!mounted || jump == null) return;'), isTrue);
  });

  group('saved messages now travel the same road as everything else', () {
    // They used to have their own: a `SavedMessagesSection` in room info with
    // its own `_jumpToSaved`, which popped ONCE where `_openContent` pops
    // twice. Two hand-offs to the same destination is two things to keep
    // right, and only one of them was ever exercised by the tests above.
    test('room info owns no second pop path', () {
      expect(
        roomInfo.contains('_jumpToSaved'),
        isFalse,
        reason: 'the SAVED tab pops through RoomContentScreen like the rest',
      );
      expect(roomInfo.contains('SavedMessagesSection'), isFalse);
    });

    test('the SAVED row is gated on the capability, not on a room name', () {
      final code = codeOf(
        roomInfo,
        'List<Widget> _sharedContentRows(AppTheme theme, RoomCapabilities caps)',
      );
      expect(
        code.contains('caps.canSaveMessages'),
        isTrue,
        reason:
            'Saved Messages is already the pile of things you kept — routed '
            'through the capability table, per room_capabilities.dart',
      );
      expect(
        code.contains('RoomContentTab.saved'),
        isTrue,
        reason: 'the fifth row is the whole point of the move',
      );
    });

    test('and the privacy caption survived the move', () {
      // The row label cannot carry it: "SAVED" beside MEDIA and FILES reads as
      // a fifth bucket of the room's stuff, which is exactly the wrong model.
      // Deleting the block that carried this sentence without rehoming it is
      // the regression this exists to catch.
      expect(
        roomInfo.contains('riSavedNote'),
        isTrue,
        reason: 'saved is per-reader, pinned is room state — say so somewhere',
      );
      expect(
        browser.contains('roomContentScreenEmptySaved'),
        isTrue,
        reason: 'and again where a reader is most likely to be wondering',
      );
    });
  });

  test('the browser pops the whole message, not just an id', () {
    final body = bodyOf(browser, 'void _showInChat(ChatMessage m)');
    expect(
      body.contains('pop(m)'),
      isTrue,
      reason:
          '_travelTo needs `from.threadKey` for the folded-thread '
          'fallback, and a message old enough to be browsed for will not be '
          'in repo.findMessageInRoom to look up from an id',
    );
  });

  test('the pager closes itself before handing the message up', () {
    // The pager is on the ROOT navigator, so popping the browser underneath it
    // would leave it floating over the transcript it just travelled to.
    expect(
      browser.contains('Navigator.of(context, rootNavigator: true).pop()'),
      isTrue,
      reason:
          'onShowInChat from the fullscreen pager must dismiss the pager '
          'first — it was pushed with rootNavigator: true',
    );
  });
}
