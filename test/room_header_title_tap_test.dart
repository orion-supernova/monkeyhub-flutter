@TestOn('vm')
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// What this pins: in the classic chat header, tapping the room TITLE opens
/// Room Info — the same destination the liquid header's title capsule
/// (`_LiquidHeader`'s `onTap: onOpenInfo`) lands on.
///
/// Before this, the classic title's `GestureDetector.onTap` was
/// `dmUser != null ? onTapPeer : null` — a group room's title did nothing at
/// all, and even a DM's title bypassed Room Info for the peer's profile
/// directly. Only the separate "···" icon button opened Room Info, so the
/// two chat styles disagreed about what the header's main tap target does.
///
/// A source scan, like `room_content_jump_test.dart`, because `_Header` is a
/// private widget in `room_screen.dart` that needs a live room, repo and
/// Convex client to mount for real.
void main() {
  late String source;

  setUpAll(() {
    source = File('lib/screens/room_screen.dart').readAsStringSync();
  });

  /// The source text of the `_Header` class, bounded by the next top-level
  /// `class` declaration in the file.
  String headerClassBody() {
    final start = source.indexOf('class _Header extends StatelessWidget {');
    expect(start, isNonNegative, reason: '_Header was renamed or removed');
    final next = source.indexOf('\nclass ', start + 1);
    expect(next, isNonNegative, reason: 'could not find the class after _Header');
    return source.substring(start, next);
  }

  test('the title\'s tap target opens Room Info', () {
    final body = headerClassBody();
    expect(
      body.contains('onTap: onOpenInfo,'),
      isTrue,
      reason:
          'the title Row\'s GestureDetector must call onOpenInfo, matching '
          "the liquid header's title capsule",
    );
  });

  test('the old DM-only / no-op tap target is gone', () {
    final body = headerClassBody();
    expect(
      body.contains('onTap: dmUser != null ? onTapPeer : null'),
      isFalse,
      reason:
          'this left a group room\'s title doing nothing on tap, and a DM\'s '
          'title opening the peer profile instead of Room Info',
    );
  });

  test("the avatar keeps its own peer-profile tap, unlike the title", () {
    final body = headerClassBody();
    expect(
      body.contains('onTap: onTapPeer,'),
      isTrue,
      reason:
          "the avatar's dedicated GestureDetector is how a DM's peer profile "
          'stays reachable now that the title opens Room Info instead',
    );
  });
}
