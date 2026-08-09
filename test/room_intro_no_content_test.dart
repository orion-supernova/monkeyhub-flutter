@TestOn('vm')
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// What this pins: `_RoomIntro` — the card the transcript shows before the
/// first message — must render nothing once it has no description, no
/// member list and no ephemeral notice to show. System bot rooms and Saved
/// Messages zero `RoomCapabilities.hasDescription`/`hasMembers`, so without
/// this guard they got an empty decorated card floating above the first
/// message instead of nothing.
///
/// A source scan rather than a widget test because pumping `_RoomIntro`
/// for real needs the same repository/API plumbing `room_content_jump_test
/// .dart` avoids for the same reason — see its own note.
void main() {
  late String source;

  setUpAll(() {
    source = File('lib/screens/room_screen.dart').readAsStringSync();
  });

  String introBody() {
    final start = source.indexOf('class _RoomIntro extends StatelessWidget');
    expect(start, isNonNegative, reason: '_RoomIntro was renamed or removed');
    final end = source.indexOf('\nclass ', start + 1);
    expect(end, isNonNegative, reason: 'could not bound _RoomIntro');
    return source.substring(start, end);
  }

  test(
    'renders nothing once description, ephemeral notice and members are '
    'all absent',
    () {
      final body = introBody();
      final shrinkAt = body.indexOf('SizedBox.shrink()');
      final containerAt = body.indexOf('return Container(');

      expect(
        shrinkAt,
        isNonNegative,
        reason:
            'a room a bot or Saved Messages has nothing to show in this '
            'card, so it must collapse to nothing rather than empty padding',
      );
      expect(
        shrinkAt,
        lessThan(containerAt),
        reason:
            'the empty-content guard must return before the decorated '
            'card is built',
      );
    },
  );

  test('the guard covers description, ephemeral notice, and members together', () {
    final body = introBody();
    final guard = RegExp(
      r'if\s*\(!showDescription\s*&&\s*!showEphemeral\s*&&\s*!showMembers\)',
    );
    expect(
      guard.hasMatch(body),
      isTrue,
      reason:
          'dropping any one of the three flags from the guard would either '
          'hide the card while it still has something to show, or show an '
          'empty card when none of the three apply',
    );
  });
}
