@TestOn('vm')
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// What this pins: the compact (liquid) chat header's title capsule and its
/// right-hand controls.
///
/// * The title shows at most TWO lines and ellipsizes past that. It used to
///   grow to three lines on a first tap when the name overflowed, and only a
///   second tap opened Room Info — a tap on the title now always goes
///   straight there, and Room Info shows the full name anyway.
/// * There is no separate "info" circle: the title is Room Info's tap target.
///   In its place sit two call controls — video, then voice — with a tighter
///   gap between them than the 12 the header uses around the capsule.
///
/// A source scan, like `room_header_title_tap_test.dart`, because
/// `_LiquidHeader` is private to `room_screen.dart` and needs a live room,
/// repo and Convex client to mount for real.
void main() {
  late String source;

  setUpAll(() {
    source = File('lib/screens/room_screen.dart').readAsStringSync();
  });

  /// The source text of the `_LiquidHeader` class, bounded by the next
  /// top-level `class` declaration in the file.
  String liquidHeaderBody() {
    final start = source.indexOf('class _LiquidHeader extends StatelessWidget {');
    expect(start, isNonNegative, reason: '_LiquidHeader was renamed or removed');
    final next = source.indexOf('\nclass ', start + 1);
    expect(next, isNonNegative,
        reason: 'could not find the class after _LiquidHeader');
    return source.substring(start, next);
  }

  test('the title shows two lines at most, then ellipsizes', () {
    final body = liquidHeaderBody();
    expect(body.contains('maxLines: 2,'), isTrue,
        reason: 'a long room name wraps to a second line, no further');
    expect(body.contains('overflow: TextOverflow.ellipsis,'), isTrue,
        reason: 'past two lines the name is cut with an ellipsis');
  });

  test('a tap on the title goes straight to Room Info', () {
    final body = liquidHeaderBody();
    expect(body.contains('onTap: onOpenInfo,'), isTrue,
        reason: 'the capsule is Room Info\'s tap target');
    for (final relic in ['_expanded', '_collapseTimer', '_handleTitleTap']) {
      expect(body.contains(relic), isFalse,
          reason: '$relic is the old expand-on-first-tap machinery');
    }
  });

  test('there is no separate info button', () {
    expect(liquidHeaderBody().contains('Icons.info_outline'), isFalse,
        reason: 'the title already opens Room Info; the circle was redundant');
  });

  test('video sits left of voice, for both DMs and groups', () {
    final body = liquidHeaderBody();
    final dmVideo = body.indexOf('kind: CallMediaKind.video,');
    final dmAudio = body.indexOf('kind: CallMediaKind.audio,');
    expect(dmVideo, isNonNegative, reason: 'DM video button missing');
    expect(dmAudio, isNonNegative, reason: 'DM voice button missing');
    expect(dmVideo, lessThan(dmAudio),
        reason: 'the DM video button must come before the voice button');

    final groupVideo = body.indexOf('liquid: true, kind: CallMediaKind.video');
    final groupAudio = body.indexOf('liquid: true, kind: CallMediaKind.audio');
    expect(groupVideo, isNonNegative, reason: 'group video button missing');
    expect(groupAudio, isNonNegative, reason: 'group voice button missing');
    expect(groupVideo, lessThan(groupAudio),
        reason: 'the group video button must come before the voice button');
  });

  test('the two call controls sit closer than the header\'s other gaps', () {
    final body = liquidHeaderBody();
    final match =
        RegExp(r'static const _controlGap = ([\d.]+);').firstMatch(body);
    expect(match, isNotNull, reason: '_controlGap constant missing');
    final gap = double.parse(match!.group(1)!);
    expect(gap, lessThan(12),
        reason: '12 is the gap around the capsule; the pair should be tighter');
    expect(body.contains('const SizedBox(width: _controlGap),'), isTrue,
        reason: 'the gap between video and voice must use _controlGap');
  });
}
