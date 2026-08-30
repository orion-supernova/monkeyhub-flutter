@TestOn('vm')
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// What this pins, for BOTH chat headers — classic `_Header` and compact
/// `_LiquidHeader`:
///
/// * The title is capped and ellipsizes past the cap — at two lines in the
///   liquid capsule, at ONE in the classic bar, which is a fixed-height row
///   with a subtitle under the title and grows when the title does. The
///   liquid capsule used to grow to three lines on a first tap when the name
///   overflowed, and only a second tap opened Room Info — a tap on the title
///   now always goes straight there, and Room Info shows the full name
///   anyway.
/// * The classic title is drawn below `displayMedium`'s own size. That style
///   is a SCREEN title, 22 to 28pt depending on the theme, and at full size
///   it made the chat's own header the loudest thing on the chat.
/// * There is no separate info control (the liquid "i" circle, the classic
///   "···"): the title is Room Info's tap target.
/// * In its place sit two call controls — video, then voice — always both on
///   show, closer together than the header's other gaps: the liquid pair
///   uses a gap smaller than the 12 around the capsule, the classic pair
///   uses compact-density icon buttons instead of the default 48px boxes.
///
/// A source scan, like `room_header_title_tap_test.dart`, because both
/// headers are private to `room_screen.dart` and need a live room, repo and
/// Convex client to mount for real.
void main() {
  late String source;

  setUpAll(() {
    source = File('lib/screens/room_screen.dart').readAsStringSync();
  });

  /// The source text of [declaration]'s class, bounded by the next top-level
  /// `class` declaration in the file.
  String classBody(String declaration) {
    final start = source.indexOf(declaration);
    expect(start, isNonNegative, reason: '$declaration was renamed or removed');
    final next = source.indexOf('\nclass ', start + 1);
    expect(next, isNonNegative,
        reason: 'could not find the class after $declaration');
    return source.substring(start, next);
  }

  final headers = <String, String Function()>{
    'classic': () => classBody('class _Header extends StatelessWidget {'),
    'liquid': () => classBody('class _LiquidHeader extends StatelessWidget {'),
  };

  /// How many lines each header gives the room name, which is NOT the same
  /// number for the two of them.
  ///
  /// The classic header is a fixed bar with a subtitle row under the title, so
  /// a second title line grows the bar and pushes the transcript down — it was
  /// already the tallest thing on the chat at one line. The liquid capsule
  /// floats over the transcript and carries no subtitle, so a second line
  /// costs it nothing. Room Info has the full name either way.
  const titleLines = {'classic': 1, 'liquid': 2};

  for (final entry in headers.entries) {
    group('${entry.key} header', () {
      test('the title is capped at ${titleLines[entry.key]}, then ellipsizes',
          () {
        final body = entry.value();
        expect(body.contains('maxLines: ${titleLines[entry.key]},'), isTrue,
            reason: 'a long room name is capped, not allowed to wrap on');
        expect(body.contains('overflow: TextOverflow.ellipsis,'), isTrue,
            reason: 'past the cap the name is cut with an ellipsis');
      });

      test('a tap on the title goes straight to Room Info', () {
        final body = entry.value();
        expect(body.contains('onTap: onOpenInfo,'), isTrue,
            reason: 'the title is Room Info\'s tap target');
        for (final relic in ['_expanded', '_collapseTimer', '_handleTitleTap']) {
          expect(body.contains(relic), isFalse,
              reason: '$relic is the old expand-on-first-tap machinery');
        }
      });

      test('there is no separate info control', () {
        final body = entry.value();
        expect(body.contains('Icons.info_outline'), isFalse,
            reason: 'the title already opens Room Info; the circle was redundant');
        expect(body.contains('Icons.more_horiz'), isFalse,
            reason: 'the title already opens Room Info; the "···" was redundant');
      });

      test('video sits left of voice, for both DMs and groups', () {
        final body = entry.value();
        final dmVideo = body.indexOf('kind: CallMediaKind.video,');
        final dmAudio = body.indexOf('kind: CallMediaKind.audio,');
        expect(dmVideo, isNonNegative, reason: 'DM video button missing');
        expect(dmAudio, isNonNegative, reason: 'DM voice button missing');
        expect(dmVideo, lessThan(dmAudio),
            reason: 'the DM video button must come before the voice button');

        final groupVideo = RegExp(r'GroupCallButton\([^)]*kind: CallMediaKind\.video')
            .firstMatch(body);
        final groupAudio = RegExp(r'GroupCallButton\([^)]*kind: CallMediaKind\.audio')
            .firstMatch(body);
        expect(groupVideo, isNotNull, reason: 'group video button missing');
        expect(groupAudio, isNotNull, reason: 'group voice button missing');
        expect(groupVideo!.start, lessThan(groupAudio!.start),
            reason: 'the group video button must come before the voice button');
      });
    });
  }

  test('the classic title is taken below displayMedium\'s own size', () {
    // Capped rather than replaced: the cap keeps each theme's face, weight and
    // tracking and only takes the size down, and the `min` leaves a theme
    // already below the cap alone instead of scaling it up.
    final body = headers['classic']!();
    expect(
      body.contains('math.min(theme.displayMedium.fontSize ?? 20, 20)'),
      isTrue,
      reason: 'the classic room title must not be drawn at full display size',
    );
  });

  test('the classic bar is not padded for a display-sized title', () {
    // The other half of taking the title down: the bar's height is the title's
    // line box plus this padding, and 12/14 was air measured against a 28pt
    // name. Pinned as an upper bound rather than an exact figure — the point
    // is that it never drifts back up, not that it is these two numbers.
    final body = headers['classic']!();
    final match = RegExp(
      r'padding: const EdgeInsets\.fromLTRB\((\d+), (\d+), (\d+), (\d+)\),\s*\n\s*child: Row\(',
    ).firstMatch(body);
    expect(match, isNotNull, reason: 'the header bar\'s padding moved');
    expect(int.parse(match!.group(2)!), lessThanOrEqualTo(8),
        reason: 'top padding');
    expect(int.parse(match.group(4)!), lessThanOrEqualTo(10),
        reason: 'bottom padding');
  });

  test('the liquid pair sits closer than the header\'s other gaps', () {
    final body = headers['liquid']!();
    final match =
        RegExp(r'static const _controlGap = ([\d.]+);').firstMatch(body);
    expect(match, isNotNull, reason: '_controlGap constant missing');
    final gap = double.parse(match!.group(1)!);
    expect(gap, lessThan(12),
        reason: '12 is the gap around the capsule; the pair should be tighter');
    expect(body.contains('const SizedBox(width: _controlGap),'), isTrue,
        reason: 'the gap between video and voice must use _controlGap');
  });

  test('the classic pair uses compact-density icon buttons', () {
    // The classic header's spacing lives in the buttons themselves: an
    // IconButton's default 48px hit box is what put 30px of air between two
    // 18px icons. Both classic call buttons must opt into compact density.
    final callButton = File('lib/calls/call_button.dart').readAsStringSync();
    final classicStart = callButton.indexOf('class _ClassicCallButton');
    expect(classicStart, isNonNegative, reason: '_ClassicCallButton missing');
    final classicEnd = callButton.indexOf('\nclass ', classicStart + 1);
    final classic = callButton.substring(classicStart, classicEnd);
    expect(classic.contains('visualDensity: VisualDensity.compact,'), isTrue,
        reason: 'the classic 1:1 call button must be compact');

    final groupButton =
        File('lib/calls/group_call_button.dart').readAsStringSync();
    final iconButton = groupButton.indexOf('return IconButton(');
    expect(iconButton, isNonNegative, reason: 'classic group button missing');
    expect(
      groupButton
          .substring(iconButton)
          .contains('visualDensity: VisualDensity.compact,'),
      isTrue,
      reason: 'the classic group call button must be compact',
    );
  });

  test('the call-kind picker is gone with nothing left pointing at it', () {
    expect(File('lib/calls/call_picker.dart').existsSync(), isFalse,
        reason: 'two direct buttons replaced the picker; it should not linger');
    final callButton = File('lib/calls/call_button.dart').readAsStringSync();
    expect(callButton.contains('showCallPicker'), isFalse,
        reason: 'no button opens a picker any more');
  });
}
