@TestOn('vm')
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:monkeyhub/media/file_meta.dart';

/// What this pins: an oversized document must be refused at the picker, by
/// [kMaxFileUploadBytes], and never by `ChatRepository._maxRetainedUploadBytes`.
///
/// Those two look interchangeable and are not. The retained-bytes budget is a
/// cap on *all* unfinished sends at once, and its overflow path deliberately
/// throws the bytes away before showing the failure — so the bubble it leaves
/// offers no retry and `retryPending` refuses it. Reaching that path with a
/// single pick gives the user a dead end with no explanation, where refusing at
/// the picker names a size while they are still looking at the file browser.
///
/// A source scan rather than a behaviour test because the check lives in
/// `_pickAndSendFile`, a private method on a `State` whose first line opens an
/// OS file browser — there is nothing to drive from the VM. Same shape and same
/// reasoning as `web_safe_apis_test.dart`.
void main() {
  test('the send cap sits well under the retained-upload budget', () {
    final source = File('lib/data/chat_repository.dart').readAsStringSync();
    final match = RegExp(
      r'_maxRetainedUploadBytes\s*=\s*(\d+)\s*\*\s*1024\s*\*\s*1024',
    ).firstMatch(source);

    expect(match, isNotNull,
        reason: 'ChatRepository._maxRetainedUploadBytes moved or changed shape. '
            'It is the ceiling kMaxFileUploadBytes is chosen against, so this '
            'test has to keep being able to read it.');

    final retainedBytes = int.parse(match!.group(1)!) * 1024 * 1024;

    expect(
      kMaxFileUploadBytes,
      lessThan(retainedBytes),
      reason: 'A single pick that can exceed the whole-repository budget means '
          'the first document a user sends lands in the un-retryable failure '
          'path instead of being refused with a reason.',
    );

    // Headroom, not just ordering: the budget covers every concurrent send, so
    // a cap that ate most of it would make one document block a second one.
    expect(
      kMaxFileUploadBytes * 2,
      lessThanOrEqualTo(retainedBytes),
      reason: 'Two documents in flight must both fit inside the retained budget.',
    );
  });

  test('the pick path refuses on size before it hands anything to the send', () {
    final source = File('lib/screens/room_screen.dart').readAsStringSync();
    final start = source.indexOf('Future<void> _pickAndSendFile()');
    expect(start, isNonNegative, reason: '_pickAndSendFile was renamed');

    // Bounded by the next method so this cannot accidentally match the video
    // or gallery paths below it.
    final body = source.substring(start, source.indexOf('\n  /// ', start + 1));

    final capAt = body.indexOf('kMaxFileUploadBytes');
    final sendAt = body.indexOf('_sendMedia(');

    expect(capAt, isNonNegative,
        reason: 'The document pick no longer checks kMaxFileUploadBytes at all, '
            'so an oversized file now falls through to the retained-bytes cap '
            'and its un-retryable failure bubble.');
    expect(
      capAt,
      lessThan(sendAt),
      reason: 'The size check has to run BEFORE _sendMedia — checking after it '
          'has already queued the upload refuses nothing.',
    );
  });
}
